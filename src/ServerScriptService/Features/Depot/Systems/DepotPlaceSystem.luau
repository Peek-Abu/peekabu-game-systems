--!strict
--[=[
	DepotPlaceSystem: the places a player owns (p1-places-menu), split out of DepotServiceServer.

	- Owns the account's `places` slice (PlayerDataTypes.Places, validated by DepotPlaceRules.validate) and syncs it to
	  its owner (StateSync "places"), so the places menu shows what is open.
	- A player buys a place with DepotEvents.BuyPlace: DepotPlaceRules.canBuy checks it (a priced place not owned yet,
	  enough Credits), then ONE PlayerData transaction spends the Credits (CurrencyServiceServer:currencyOp, the server
	  spend path the Shop uses) and unlocks the place. Either both happen or neither: a player never pays without the
	  place, or gets it without paying.
	- `owns` is what DepotMapSystem asks before a host's pick counts: a truck plays only a place its host owns.

	Spec-exempt shell (ByteNet, PlayerData and Currency wiring); the decisions are the specced DepotPlaceRules.

	@class DepotPlaceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotPlaceConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotPlaceConstants)
local DepotPlaceRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotPlaceRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)

local log = Logger.new("DepotPlaceSystem")

local CREDITS: CurrencyConstants.CurrencyType = "credits"

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

local function buyImpl(userId: number, value: string): (boolean, string?)
	local map: ShiftTypes.MapId? = DepotPlaceRules.parse(value)
	if map == nil then
		return false, "unknown place"
	end
	local credits = CurrencyServiceServer:getCurrencyAmount(userId, CREDITS)
	if credits == nil then
		return false, "no profile loaded"
	end
	local allowed, refusal = DepotPlaceRules.canBuy(placesSlice.get(userId), map, credits)
	if not allowed then
		return false, refusal
	end
	local price = DepotPlaceRules.price(map)
	local ops: { PlayerDataService.TransactionOperation } = {
		CurrencyServiceServer:currencyOp(userId, function(currency): boolean
			local have = currency[CREDITS] or 0
			if have < price then
				return false
			end
			currency[CREDITS] = have - price
			return true
		end),
		placesSlice.op(userId, function(places): boolean
			return DepotPlaceRules.unlock(places, map)
		end),
	}
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	bought += 1
	log:audit(`userId={userId}`, "PLACE_BOUGHT", map, price)
	return true, nil
end

local onBuyPlace = RequestHandler.wrap({
	name = "DepotBuyPlace",
	rateLimit = DepotPlaceConstants.BUY_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if type(data) ~= "string" then
			return
		end
		local ok, refusal = buyImpl(player.UserId, data)
		if not ok then
			log:debug(`BuyPlace refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

local DepotPlaceSystem = {}

-- Listens for purchases. Returns the stop.
function DepotPlaceSystem.start(): () -> ()
	local buying = DepotEvents.packets.BuyPlace.listen(function(data: string, player: Player?)
		if player then
			onBuyPlace(data, player)
		end
	end)
	return function()
		buying()
		bought = 0
	end
end

-- Whether `userId` may play `map` (the free Office always; another place once bought and their profile is loaded).
function DepotPlaceSystem.owns(userId: number, map: ShiftTypes.MapId): boolean
	return DepotPlaceRules.owns(placesSlice.get(userId), map)
end

-- Buys `map` for `userId` (the request's path; also the admin and Studio-check seam). Whether it was bought, else why not.
function DepotPlaceSystem.buy(userId: number, map: string): (boolean, string?)
	return buyImpl(userId, map)
end

-- Places bought since start.
function DepotPlaceSystem.bought(): number
	return bought
end

return DepotPlaceSystem
