--!strict
--[=[
	LockerPurchaseSystem: the Locker purchases that are not opens, split out of LockerServiceServer: one key to a Locker
	for the live event's money (`buyKey`), the restricted-player direct purchase of a paid Locker's item (`buyDirect`),
	and the `currencyDeltaOp` that spends and refunds a Locker's currency in a transaction (shared with the open in the
	service). Each runs in ONE PlayerData transaction. The service passes its `deps` and its `lockers` slice in, so the
	shift lock, restriction, pool and live event stay the service's test seams.

	@class LockerPurchaseSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local AnalyticsServiceServer = require(ServerScriptService.Features.Analytics.AnalyticsServiceServer)
local AnalyticsEconomyUtils = require(ServerScriptService.Features.Analytics.Utils.AnalyticsEconomyUtils)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)

-- The part of the service's Deps the purchases read (the service's Deps has these fields and more).
export type PurchaseDeps = {
	isLocked: () -> boolean,
	restricted: (player: Player) -> boolean,
	pool: (locker: LockerTypes.Locker) -> { CosmeticTypes.Item },
	live: () -> string?,
}

type LockersSlice = PlayerDataSliceSystem.SliceAccessor<LockerTypes.Lockers>

local log = Logger.new("LockerServiceServer")

local function currencyDeltaOp(
	userId: number,
	currency: LockerTypes.Currency,
	spend: number,
	refund: number
): PlayerDataService.TransactionOperation
	local slot: CurrencyConstants.CurrencyType? = CurrencyConstants.toCurrencyType(currency)
	if slot == nil then
		return MarketplaceServiceServer:premiumOp(userId, function(premium): boolean
			if premium.balance < spend then
				return false
			end
			premium.balance = premium.balance - spend + refund
			return true
		end)
	end
	local key: CurrencyConstants.CurrencyType = slot
	return CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
		local have = wallet[key] or 0
		if have < spend then
			return false
		end
		wallet[key] = math.min(have - spend + refund, CurrencyConstants.MAX_CURRENCY)
		return true
	end)
end

-- One key to `lockerId`, paid in the live event's money at the event's price (EventRegistry keys).
local function buyKey(
	deps: PurchaseDeps,
	lockersSlice: LockersSlice,
	player: Player,
	lockerId: string
): (boolean, string?)
	local userId = player.UserId
	Guard.userId(userId)
	if deps.isLocked() then
		return false, "locked during a shift"
	end
	local locker = LockerRules.get(lockerId)
	if locker == nil then
		return false, "unknown locker"
	end
	local live = deps.live()
	local event = if live ~= nil then EventRegistry.get(live) else nil
	local price: number? = nil
	if event ~= nil then
		for _, offer in event.keys do
			if offer.locker == locker.id then
				price = offer.price
			end
		end
	end
	if event == nil or price == nil then
		return false, "not on sale"
	end
	local currency: CurrencyConstants.CurrencyType = event.currency
	local cost: number = price
	if lockersSlice.get(userId) == nil or CurrencyServiceServer:getCurrency(userId) == nil then
		return false, "no profile loaded"
	end
	if CurrencyServiceServer:getCurrencyAmount(userId, currency) < cost then
		return false, "short"
	end
	local committed, result = PlayerDataService:transaction({
		CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
			local have = wallet[currency] or 0
			if have < cost then
				return false
			end
			wallet[currency] = have - cost
			return true
		end),
		lockersSlice.op(userId, function(saved): boolean
			saved.keys[locker.id] = (saved.keys[locker.id] or 0) + 1
			return true
		end),
	})
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	log:audit(`userId={userId}`, "LOCKER_KEY_BOUGHT", locker.id, event.id, cost)
	AnalyticsServiceServer:recordEconomy(userId, {
		currency = currency,
		flow = "sink",
		amount = cost,
		kind = "Shop",
		sku = "locker_key",
		item = locker.id,
		where = event.id,
	})
	return true, nil
end

local function findInPool(pool: { CosmeticTypes.Item }, itemId: string): CosmeticTypes.Item?
	for _, entry in pool do
		if entry.id == itemId then
			return entry
		end
	end
	return nil
end

local function buyDirect(
	deps: PurchaseDeps,
	lockersSlice: LockersSlice,
	player: Player,
	lockerId: string,
	itemId: string
): (boolean, string?)
	local userId = player.UserId
	Guard.userId(userId)
	if deps.isLocked() then
		return false, "locked during a shift"
	end
	local locker = LockerRules.get(lockerId)
	if locker == nil then
		return false, "unknown locker"
	end
	local state = lockersSlice.get(userId)
	local balance = MarketplaceServiceServer:getPremium(userId)
	if state == nil or balance == nil then
		return false, "no profile loaded"
	end
	local item = findInPool(deps.pool(locker), itemId)
	if item == nil then
		return false, "not in this locker"
	end
	local owned = CosmeticServiceServer:owns(userId, item.id)
	local restricted = deps.restricted(player)
	local allowed, refusal = LockerRules.checkDirect(locker, item, owned, balance, restricted)
	if not allowed then
		return false, refusal
	end
	local price = LockerRules.directPrice(item)
	local ops: { PlayerDataService.TransactionOperation } = {
		currencyDeltaOp(userId, "gleam", price, 0),
	}
	for _, op in CosmeticServiceServer:grantOps(userId, item.id) do
		table.insert(ops, op)
	end
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	log:audit(`userId={userId}`, "LOCKER_DIRECT_BOUGHT", locker.id, item.id, price)
	local sku, rarity = AnalyticsEconomyUtils.item(item.id)
	AnalyticsServiceServer:recordEconomy(userId, {
		currency = "gleam",
		flow = "sink",
		amount = price,
		kind = "Shop",
		sku = sku,
		item = item.id,
		rarity = rarity,
		where = `direct:{locker.id}`,
	})
	CosmeticServiceServer.changed:Fire(userId)
	CosmeticServiceServer:announce(userId, { item.id }, "locker")
	return true, nil
end

local LockerPurchaseSystem = {}

LockerPurchaseSystem.currencyDeltaOp = currencyDeltaOp
LockerPurchaseSystem.findInPool = findInPool
LockerPurchaseSystem.buyKey = buyKey
LockerPurchaseSystem.buyDirect = buyDirect

return LockerPurchaseSystem
