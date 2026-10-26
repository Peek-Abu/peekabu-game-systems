--!strict
--[=[
	LockerServiceServer: owns the account-wide `lockers` slice (keys held per Locker, pity counter per Locker, total
	opens) and runs Locker opens and restricted direct purchases in a single PlayerData transaction (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- `open`: checks not in a shift, cooldown (1 open/s), profile loaded, pool non-empty, PolicyService restriction for
	  paid random Lockers, and key or currency balance. Rolls with the server's Random (pity forces Epic+ at `pityAt`),
	  then commits key/currency spend + duplicate refund + item/bundle grant + pity update in ONE transaction.
	- `buyDirect`: for players restricted from paid random items (`PolicyServiceServer:paidRandomItemsRestricted`),
	  sells a paid Locker's item directly at `LockerRules.directPrice(item)` in one transaction and announces the
	  reveal.

	@class LockerServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerConstants = require(Locker.Data.LockerConstants)
local LockerEvents = require(Locker.Net.LockerEvents)
local LockerRequestRules = require(Locker.Rules.LockerRequestRules)
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PolicyServiceServer = require(ServerScriptService.Features.Policy.PolicyServiceServer)

type LockerId = LockerTypes.LockerId
type Outcome = LockerTypes.Outcome

local GLOOM_CURRENCY: CurrencyConstants.CurrencyType = "gloom"

local lockersSlice = PlayerDataSliceSystem.registerAccount(
	LockerConstants.SLICE,
	LockerConstants.defaultLockers(),
	function(account)
		return account.lockers
	end,
	LockerRules.validate
)

export type Deps = {
	isLocked: () -> boolean,
	restricted: (player: Player) -> boolean,
	pool: (locker: LockerTypes.Locker) -> { CosmeticTypes.Item },
	nextNumber: () -> number,
	now: () -> number,
	sendOpened: (player: Player, outcome: Outcome) -> (),
	sendRefused: (player: Player, locker: string, reason: string) -> (),
	sendStatus: (player: Player, restricted: boolean) -> (),
}

local log = Logger.new("LockerServiceServer")
local janitor = Janitor.new()
local rng = Random.new()
local lastOpen: { [number]: number } = {}

local defaults: Deps = {
	isLocked = function()
		return CosmeticServiceServer:isLocked()
	end,
	restricted = function(player)
		return PolicyServiceServer:paidRandomItemsRestricted(player)
	end,
	pool = function(locker)
		return LockerRules.pool(locker)
	end,
	nextNumber = function()
		return rng:NextNumber()
	end,
	now = os.clock,
	sendOpened = function(player, outcome)
		if typeof(player) == "Instance" then
			LockerEvents.packets.Opened.sendTo(outcome, player)
		end
	end,
	sendRefused = function(player, locker, reason)
		if typeof(player) == "Instance" then
			LockerEvents.packets.Refused.sendTo({ locker = locker, reason = reason }, player)
		end
	end,
	sendStatus = function(player, restricted)
		if typeof(player) == "Instance" then
			LockerEvents.packets.Status.sendTo({ restricted = restricted }, player)
		end
	end,
}
local deps: Deps = defaults

local function balanceOf(userId: number, currency: LockerTypes.Currency): number?
	if currency == "gleam" then
		return MarketplaceServiceServer:getPremium(userId)
	end
	if CurrencyServiceServer:getCurrency(userId) == nil then
		return nil
	end
	return CurrencyServiceServer:getCurrencyAmount(userId, GLOOM_CURRENCY)
end

local function currencyDeltaOp(
	userId: number,
	currency: LockerTypes.Currency,
	spend: number,
	refund: number
): PlayerDataService.TransactionOperation
	if currency == "gleam" then
		return MarketplaceServiceServer:premiumOp(userId, function(premium): boolean
			if premium.balance < spend then
				return false
			end
			premium.balance = premium.balance - spend + refund
			return true
		end)
	end
	return CurrencyServiceServer:currencyOp(userId, function(wallet): boolean
		local have = wallet[GLOOM_CURRENCY] or 0
		if have < spend then
			return false
		end
		wallet[GLOOM_CURRENCY] = math.min(have - spend + refund, CurrencyConstants.MAX_CURRENCY)
		return true
	end)
end

local function openImpl(player: Player, lockerId: string): (Outcome?, string?)
	local userId = player.UserId
	Guard.userId(userId)
	if deps.isLocked() then
		return nil, "locked during a shift"
	end
	local now = deps.now()
	local previous = lastOpen[userId]
	if previous ~= nil and now - previous < LockerConstants.OPEN_COOLDOWN then
		return nil, "too soon"
	end
	local locker = LockerRules.get(lockerId)
	if locker == nil then
		return nil, "unknown locker"
	end
	local state = lockersSlice.get(userId)
	local balance = balanceOf(userId, locker.currency)
	if state == nil or balance == nil then
		return nil, "no profile loaded"
	end
	local pool = deps.pool(locker)
	local keys = state.keys[locker.id] or 0
	local pity = state.pity[locker.id] or 0
	local restricted = deps.restricted(player)
	local allowed, refusal = LockerRules.checkOpen(locker, #pool, keys, balance, restricted)
	if not allowed then
		return nil, refusal
	end
	local item, guaranteed = LockerRules.roll(locker, pity, deps.nextNumber(), deps.nextNumber(), pool)
	if item == nil then
		return nil, "empty"
	end
	local owned = CosmeticServiceServer:owns(userId, item.id)
	local outcome = LockerRules.outcome(locker, item, owned, pity, guaranteed)
	local useKey = keys > 0
	local spend = if useKey then 0 else locker.keyPrice

	local ops: { PlayerDataService.TransactionOperation } = {
		lockersSlice.op(userId, function(saved): boolean
			local held = saved.keys[locker.id] or 0
			if useKey then
				if held < 1 then
					return false
				end
				saved.keys[locker.id] = held - 1
			end
			saved.pity[locker.id] = outcome.pity
			saved.opened += 1
			return true
		end),
	}
	if spend > 0 or outcome.refund > 0 then
		table.insert(ops, currencyDeltaOp(userId, locker.currency, spend, outcome.refund))
	end
	if not outcome.duplicate then
		for _, op in CosmeticServiceServer:grantOps(userId, item.id) do
			table.insert(ops, op)
		end
	end
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return nil, result.rejectionReason or "transaction failed"
	end
	lastOpen[userId] = now
	log:audit(`userId={userId}`, "LOCKER_OPENED", locker.id, item.id, outcome.duplicate, outcome.pity)
	if not outcome.duplicate then
		CosmeticServiceServer.changed:Fire(userId)
	end
	return outcome, nil
end

local function findInPool(pool: { CosmeticTypes.Item }, itemId: string): CosmeticTypes.Item?
	for _, entry in pool do
		if entry.id == itemId then
			return entry
		end
	end
	return nil
end

local function buyDirectImpl(player: Player, lockerId: string, itemId: string): (boolean, string?)
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
	CosmeticServiceServer.changed:Fire(userId)
	CosmeticServiceServer:announce(userId, { item.id }, "locker")
	return true, nil
end

local onOpenRequest = RequestHandler.wrap({
	name = "LockerOpenRequest",
	rateLimit = { maxRequests = 5, windowSeconds = 5 },
	handler = function(payload: unknown, player: Player)
		local lockerId = LockerRequestRules.parseOpen(payload)
		if lockerId == nil then
			log:warn(`bad OpenRequest from {player.Name}`)
			return
		end
		local outcome, refusal = openImpl(player, lockerId)
		if outcome ~= nil then
			deps.sendOpened(player, outcome)
		else
			deps.sendRefused(player, lockerId, refusal or "failed")
		end
	end,
})

local onBuyRequest = RequestHandler.wrap({
	name = "LockerBuyRequest",
	rateLimit = { maxRequests = 5, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local lockerId, itemId = LockerRequestRules.parseBuy(payload)
		if lockerId == nil or itemId == nil then
			log:warn(`bad BuyRequest from {player.Name}`)
			return
		end
		local ok, refusal = buyDirectImpl(player, lockerId, itemId)
		deps.sendRefused(player, lockerId, if ok then "" else refusal or "failed")
	end,
})

export type LockerServiceServer = {
	dependencies: { string },
	init: (self: LockerServiceServer) -> (),
	stop: (self: LockerServiceServer) -> (),
	getLockers: (self: LockerServiceServer, userId: number) -> LockerTypes.Lockers?,
	addKeys: (self: LockerServiceServer, userId: number, lockerId: LockerId, amount: number) -> boolean,
	open: (self: LockerServiceServer, player: Player, lockerId: LockerId) -> (Outcome?, string?),
	buyDirect: (self: LockerServiceServer, player: Player, lockerId: LockerId, itemId: string) -> (boolean, string?),
	getState: (self: LockerServiceServer) -> { [string]: any },
	-- TEST SEAMS
	_setDeps: (replacement: Deps?) -> (),
	_onOpenRequest: (payload: unknown, player: Player) -> any,
	_onBuyRequest: (payload: unknown, player: Player) -> any,
}

local LockerServiceServer: LockerServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"CosmeticServiceServer",
		"CurrencyServiceServer",
		"MarketplaceServiceServer",
		"PolicyServiceServer",
	},

	init = function(_self)
		janitor:Add(
			LockerEvents.packets.OpenRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onOpenRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			LockerEvents.packets.BuyRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onBuyRequest(payload, player)
				end
			end),
			true
		)
		local function announceStatus(player: Player)
			task.spawn(function()
				local restricted = deps.restricted(player)
				if player.Parent ~= nil then
					deps.sendStatus(player, restricted)
				end
			end)
		end
		for _, player in Players:GetPlayers() do
			announceStatus(player)
		end
		janitor:Add(Players.PlayerAdded:Connect(announceStatus), "Disconnect")
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				lastOpen[player.UserId] = nil
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
		table.clear(lastOpen)
	end,

	getLockers = function(_self, userId)
		return lockersSlice.get(userId)
	end,

	addKeys = function(_self, userId, lockerId, amount)
		Guard.userId(userId)
		Guard.positiveAmount(amount)
		assert(LockerRules.get(lockerId) ~= nil, `unknown locker "{lockerId}"`)
		local changed = lockersSlice.mutate(userId, function(state): boolean
			state.keys[lockerId] = (state.keys[lockerId] or 0) + amount
			return true
		end)
		return changed
	end,

	open = function(_self, player, lockerId)
		return openImpl(player, lockerId)
	end,

	buyDirect = function(_self, player, lockerId, itemId)
		return buyDirectImpl(player, lockerId, itemId)
	end,

	getState = function(_self)
		return {
			gloomPool = #LockerRules.pool(LockerConstants.LOCKERS.gloom),
			gleamPool = #LockerRules.pool(LockerConstants.LOCKERS.gleam),
		}
	end,

	_setDeps = function(replacement)
		deps = replacement or defaults
		table.clear(lastOpen)
	end,

	_onOpenRequest = onOpenRequest,
	_onBuyRequest = onBuyRequest,
}

return LockerServiceServer
