--!strict
--[=[
	DepotPlaceSystem: the places a player owns (p1-places-menu), split out of DepotServiceServer.

	- Owns the account's `places` slice (PlayerDataTypes.Places, validated by DepotPlaceRules.validate) and syncs it to
	  its owner (StateSync "places"), so the places menu shows what is open.
	- A player buys a place with DepotEvents.BuyPlace: DepotPlaceRules.canBuy checks it is for sale to them (a priced
	  place not owned yet), the Shop's payment prices it (ShopServiceServer:payOps, injected with `setPayer`
	  because Depot cannot require the Shop: the Shop already reaches Depot through Cosmetic and Shift; Credits, with
	  Gleam paying the rest when they are short and said yes to that much), then ONE PlayerData transaction pays and
	  unlocks the place. With no payer set (the Shop not started) nothing is sold.
	  Either all of it happens or none: a player never pays without the place, or gets it without paying.
	- `owns` is what DepotMapSystem asks before a host's pick counts: a truck plays only a place its host owns.

	Spec-exempt shell (ByteNet, PlayerData and Shop wiring); the decisions are the specced DepotPlaceRules.

	@class DepotPlaceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotPlaceConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotPlaceConstants)
local DepotPlaceRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotPlaceRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)

local log = Logger.new("DepotPlaceSystem")

local placesSlice = PlayerDataSliceSystem.registerAccount(
	DepotPlaceConstants.SLICE,
	DepotPlaceRules.fresh(),
	function(account)
		return account.places
	end,
	DepotPlaceRules.validate
)

-- Places bought since start, for the Debugger.
local bought = 0

-- The operations that pay `price` Credits for `userId`, `gleam` Gleam at most paying the rest, or why not
-- (ShopServiceServer:payOps, set by the Shop).
export type Payer = (
	userId: number,
	price: number,
	gleam: number
) -> ({ PlayerDataService.TransactionOperation }?, string?)

local payer: Payer? = nil

local function buyImpl(userId: number, value: string, gleam: number): (boolean, string?)
	local map: ShiftTypes.MapId? = DepotPlaceRules.parse(value)
	if map == nil then
		return false, "unknown place"
	end
	local allowed, refusal = DepotPlaceRules.canBuy(placesSlice.get(userId), map)
	if not allowed then
		return false, refusal
	end
	local price = DepotPlaceRules.price(map)
	local pay = payer
	if pay == nil then
		return false, "no payment"
	end
	local payment, short = pay(userId, price, gleam)
	if payment == nil then
		return false, short or "cannot pay"
	end
	local ops: { PlayerDataService.TransactionOperation } = table.clone(payment)
	table.insert(
		ops,
		placesSlice.op(userId, function(places): boolean
			return DepotPlaceRules.unlock(places, map)
		end)
	)
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	bought += 1
	log:audit(`userId={userId}`, "PLACE_BOUGHT", map, price, gleam)
	return true, nil
end

local onBuyPlace = RequestHandler.wrap({
	name = "DepotBuyPlace",
	rateLimit = DepotPlaceConstants.BUY_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		local request, malformed = DepotPlaceRules.parseBuy(data)
		if request == nil then
			log:debug(`bad BuyPlace from {player.Name}: {malformed or "?"}`)
			return
		end
		local ok, refusal = buyImpl(player.UserId, request.map, request.gleam)
		if not ok then
			log:debug(`BuyPlace refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

local DepotPlaceSystem = {}

-- Listens for purchases. Returns the stop.
function DepotPlaceSystem.start(): () -> ()
	local buying = DepotEvents.packets.BuyPlace.listen(function(data: { map: string, gleam: number }, player: Player?)
		if player then
			onBuyPlace(data, player)
		end
	end)
	return function()
		buying()
		bought = 0
	end
end

-- Sets (or clears) how a place is paid for: the Shop's payOps.
function DepotPlaceSystem.setPayer(value: Payer?)
	payer = value
end

-- Whether `userId` may play `map` (the free Office always; another place once bought and their profile is loaded).
function DepotPlaceSystem.owns(userId: number, map: ShiftTypes.MapId): boolean
	return DepotPlaceRules.owns(placesSlice.get(userId), map)
end

-- Buys `map` for `userId`, `gleam` Gleam at most paying the rest (the request's path; also the admin and
-- Studio-check seam). Whether it was bought, else why not.
function DepotPlaceSystem.buy(userId: number, map: string, gleam: number?): (boolean, string?)
	return buyImpl(userId, map, gleam or 0)
end

-- Places bought since start.
function DepotPlaceSystem.bought(): number
	return bought
end

return DepotPlaceSystem
