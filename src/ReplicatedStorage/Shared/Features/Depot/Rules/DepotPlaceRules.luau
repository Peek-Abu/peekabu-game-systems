--!strict
--[=[
	DepotPlaceRules: who may play which place (p1-places-menu). The Office is free for everyone; any other place
	(the School) is owned once bought with Credits and saved in the account's `places` slice (PlayerDataTypes.Places).
	`owns` reads it, `canBuy` decides whether a place is for sale to the player (known, not free, not owned; paying is
	ShopServiceServer:payOps', Gleam paying the rest when Credits are short), `unlock` is the slice
	mutator of a purchase, `validate` the slice's validator, `danger` a place's DANGER level, `parse` reads a place id off
	anything untrusted (exact ids only). A truck may only play a place its host owns (DepotMapSystem checks it). Pure.

	@class DepotPlaceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local DepotPlaceConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotPlaceConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type MapId = ShiftTypes.MapId
type Places = PlayerDataTypes.Places

-- A BuyPlace request: the place, and the most Gleam the player said yes to for the rest (0: Credits only).
export type BuyRequest = { map: MapId, gleam: number }

-- The most Gleam a request may agree to (a bound on an untrusted number).
local MAX_GLEAM = 100000

local function placeOf(map: string): DepotPlaceConstants.Place?
	if map == "office" then
		return DepotPlaceConstants.PLACES.office
	elseif map == "school" then
		return DepotPlaceConstants.PLACES.school
	end
	return nil
end

export type DepotPlaceRules = {
	fresh: () -> Places,
	parse: (value: unknown) -> MapId?,
	parseBuy: (payload: unknown) -> (BuyRequest?, string?),
	price: (map: MapId) -> number,
	danger: (map: MapId) -> number,
	owns: (places: Places?, map: MapId) -> boolean,
	canBuy: (places: Places?, map: string) -> (boolean, string?),
	unlock: (places: Places, map: string) -> boolean,
	validate: (value: Places) -> (boolean, string?),
}

local DepotPlaceRules: DepotPlaceRules = {
	-- A new account's slice: nothing bought.
	fresh = function()
		return { owned = {} }
	end,

	-- The place `value` names exactly, or nil.
	parse = function(value)
		if value == "office" then
			return "office"
		elseif value == "school" then
			return "school"
		end
		return nil
	end,

	-- A BuyPlace payload from a client, shape-checked: an exact place id and a whole, bounded Gleam.
	parseBuy = function(payload)
		if type(payload) ~= "table" then
			return nil, "payload is not a table"
		end
		local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the fields are shape-checked below (ShopRequestRules.parseBuy's pattern)
		local map: MapId? = nil
		if fields.map == "office" then
			map = "office"
		elseif fields.map == "school" then
			map = "school"
		end
		if map == nil then
			return nil, "unknown place"
		end
		local gleam = fields.gleam
		if gleam == nil then
			return { map = map, gleam = 0 }, nil
		end
		if
			type(gleam) ~= "number"
			or gleam ~= gleam
			or gleam < 0
			or gleam > MAX_GLEAM
			or math.floor(gleam) ~= gleam
		then
			return nil, "malformed gleam"
		end
		return { map = map, gleam = gleam }, nil
	end,

	-- Credits to unlock `map` (0: free).
	price = function(map)
		local place = placeOf(map)
		return if place ~= nil then place.price else 0
	end,

	-- `map`'s DANGER level (1 for an unknown one).
	danger = function(map)
		local place = placeOf(map)
		return if place ~= nil then place.danger else 1
	end,

	-- Whether the player whose slice is `places` (nil: not loaded) may play `map`: a free place always, any other once bought.
	owns = function(places, map)
		local place = placeOf(map)
		if place == nil then
			return false
		end
		if place.price <= 0 then
			return true
		end
		return places ~= nil and places.owned[map] == true
	end,

	-- Whether a player with `places` may buy `map`, else why not (the price is paid by ShopServiceServer:payOps).
	canBuy = function(places, map)
		local place = placeOf(map)
		if place == nil then
			return false, "unknown place"
		end
		if place.price <= 0 then
			return false, "free place"
		end
		if places == nil then
			return false, "no profile loaded"
		end
		if places.owned[map] == true then
			return false, "already owned"
		end
		return true, nil
	end,

	-- Records `map` as bought in `places`. Whether it changed (a free, unknown or owned place changes nothing).
	unlock = function(places, map)
		local place = placeOf(map)
		if place == nil or place.price <= 0 or places.owned[map] == true then
			return false
		end
		places.owned[map] = true
		return true
	end,

	-- A saved slice is valid when `owned` lists only priced places, each flagged true.
	validate = function(value)
		if type(value) ~= "table" or type(value.owned) ~= "table" then
			return false, "places.owned must be a table"
		end
		for map, flag in value.owned do
			local place = placeOf(map)
			if place == nil or place.price <= 0 then
				return false, `places.owned lists a place that cannot be bought: {map}`
			end
			if flag ~= true then
				return false, `places.owned.{map} must be true`
			end
		end
		return true, nil
	end,
}

return DepotPlaceRules
