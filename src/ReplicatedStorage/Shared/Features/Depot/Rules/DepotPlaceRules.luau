--!strict
--[=[
	DepotPlaceRules: who may play which place (p1-places-menu). The Office is free for everyone; any other place
	(the School) is owned once bought with Credits and saved in the account's `places` slice (PlayerDataTypes.Places).
	`owns` reads it, `canBuy` decides a purchase (known, not free, not owned, enough Credits), `unlock` is the slice
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
	price: (map: MapId) -> number,
	danger: (map: MapId) -> number,
	owns: (places: Places?, map: MapId) -> boolean,
	canBuy: (places: Places?, map: string, credits: number) -> (boolean, string?),
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

	-- Whether a player with `places` and `credits` may buy `map`, else why not.
	canBuy = function(places, map, credits)
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
		if credits < place.price then
			return false, "not enough Credits"
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
