--!strict
--[=[
	MarketplaceServiceServer: Robux purchases granted exactly once, cached gamepass ownership, and the
	account-wide premium currency (design: docs/superpowers/specs/2026-10-09-marketplace-design.md).

	- Owns `MarketplaceService.ProcessReceipt`. Each receipt goes through MarketplaceReceiptSystem: the
	  purchase id is recorded in the account's `receipts` history in the SAME persisted transaction as the
	  product's grant ops (from `onProduct`), and only a confirmed durable save is acknowledged.
	- Gamepasses are checked on join (with retries) and on purchase; ownership is cached
	  (MarketplacePassTracker), published as the public field `pass:<key> = true`, and announced to
	  `onPass` handlers.
	- `premium` is an ACCOUNT slice validated by the data layer; `premiumOp` composes it into transactions
	  (spend premium + grant an item atomically).

	Spec: MarketplaceServiceServer.spec covers the premium slice through the real data layer; the receipt
	flow is MarketplaceReceiptSystem.spec, the history and validators MarketplaceReceiptRules.spec.

	@class MarketplaceServiceServer
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MarketplaceData = ReplicatedStorage.Shared.Features.Marketplace.Data
local MarketplaceServer = ServerScriptService.Features.Marketplace
local Observers = require(ReplicatedStorage.Packages.Observers)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local MarketplaceConstants = require(MarketplaceData.MarketplaceConstants)
local MarketplaceRegistry = require(MarketplaceData.MarketplaceRegistry)
local MarketplaceTypes = require(MarketplaceData.MarketplaceTypes)
local MarketplaceReceiptRules = require(MarketplaceServer.Rules.MarketplaceReceiptRules)
local MarketplaceReceiptSystem = require(MarketplaceServer.Systems.MarketplaceReceiptSystem)
local MarketplacePassTracker = require(MarketplaceServer.State.MarketplacePassTracker)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type TransactionOperation = PlayerDataService.TransactionOperation
type Receipt = MarketplaceTypes.Receipt

-- ACCOUNT slices: Robux-bought value must survive every save slot.
local premiumSlice = PlayerDataSliceSystem.registerAccount("premium", {
	balance = 0,
}, function(account)
	return account.premium
end, MarketplaceReceiptRules.validatePremium)

local receiptsSlice = PlayerDataSliceSystem.registerAccount("receipts", {
	ids = {},
}, function(account)
	return account.receipts
end, MarketplaceReceiptRules.validateReceipts)

export type ProductGrant = (player: Player, receipt: Receipt) -> { TransactionOperation }

local log = Logger.new("MarketplaceServiceServer")

local productGranted: SignalTyped.Signal<Player, string> = SignalTyped.new()
local productHandlers: { [string]: ProductGrant } = {}
local passHandlers: { [string]: { (player: Player) -> () } } = {}
local passes = MarketplacePassTracker.new()
local inFlight: { [string]: true } = {}
local counters = { granted = 0, regranted = 0, retried = 0, passesFound = 0 }
local stoppers: { () -> () } = {}

-- Narrows the engine's receipt table (typed `{ [string]: any }`) to the fields the base reads.
local function receiptFrom(info: { [string]: any }): Receipt?
	local purchaseId = info.PurchaseId
	local playerId = info.PlayerId
	local productId = info.ProductId
	local currencySpent = info.CurrencySpent
	if type(purchaseId) ~= "string" or type(playerId) ~= "number" or type(productId) ~= "number" then
		return nil
	end
	return {
		purchaseId = purchaseId,
		playerId = playerId,
		productId = productId,
		currencySpent = if type(currencySpent) == "number" then currencySpent else 0,
	}
end

-- Runs one onPass handler on its own thread; an error is logged, never thrown into the caller.
local function runPassHandler(key: string, handler: (player: Player) -> (), player: Player)
	task.spawn(function()
		local ok, err = pcall(function()
			handler(player)
		end)
		if not ok then
			log:error(`onPass("{key}") handler errored for {player.Name}: {err}`)
		end
	end)
end

local function runPassHandlers(player: Player, key: string)
	local handlers = passHandlers[key]
	if handlers == nil then
		return
	end
	for _, handler in handlers do
		runPassHandler(key, handler, player)
	end
end

-- Records ownership; on first sight publishes it and runs the pass's handlers.
local function grantPass(player: Player, key: string)
	if not passes:grant(player.UserId, key) then
		return
	end
	counters.passesFound += 1
	StateSyncPublicPlayerStore.set(player.UserId, { [MarketplaceConstants.passField(key)] = true })
	runPassHandlers(player, key)
end

local function checkPass(player: Player, key: string, passId: number)
	for attempt = 1, MarketplaceConstants.PASS_CHECK_ATTEMPTS do
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			if owned and player.Parent ~= nil then
				grantPass(player, key)
			end
			return
		end
		log:warn(`pass check "{key}" failed for {player.Name} (attempt {attempt}): {owned}`)
		task.wait(MarketplaceConstants.PASS_CHECK_RETRY_SECONDS)
	end
end

local function commit(ops: { TransactionOperation }): boolean
	local _, result = PlayerDataService:transaction(ops, { persist = true })
	return result.committed and result.persisted
end

local receiptDeps: MarketplaceReceiptSystem.ReceiptDeps<TransactionOperation> = {
	productKeyFor = MarketplaceRegistry.productKeyFor,
	isPresent = function(userId)
		return Players:GetPlayerByUserId(userId) ~= nil
	end,
	readReceipts = function(userId)
		return receiptsSlice.get(userId)
	end,
	recordOp = function(userId, purchaseId)
		return receiptsSlice.op(userId, function(receipts)
			-- Idempotent on purpose: an id already recorded still "succeeds", so the history is re-saved.
			MarketplaceReceiptRules.record(receipts, purchaseId, MarketplaceConstants.RECEIPT_HISTORY)
			return true
		end)
	end,
	grantOps = function(userId, key, receipt)
		local handler = productHandlers[key]
		local player = Players:GetPlayerByUserId(userId)
		if handler == nil then
			return nil, `product "{key}" has no onProduct handler`
		end
		if player == nil then
			return nil, "buyer left"
		end
		return handler(player, receipt), nil
	end,
	commit = commit,
}

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local receipt = receiptFrom(info)
	if receipt == nil then
		log:error("malformed receipt; asking Roblox to retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local decision, reason, granted = MarketplaceReceiptSystem.process(receipt, receiptDeps, inFlight)
	if decision == "granted" then
		if granted then
			counters.granted += 1
			local player = Players:GetPlayerByUserId(receipt.playerId)
			local key = MarketplaceRegistry.productKeyFor(receipt.productId)
			if player ~= nil and key ~= nil then
				productGranted:Fire(player, key)
			end
		else
			counters.regranted += 1
		end
		log:info(`receipt {receipt.purchaseId}: {reason}`)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	counters.retried += 1
	log:warn(`receipt {receipt.purchaseId} not processed yet: {reason}`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

export type MarketplaceServiceServer = {
	dependencies: { string },
	productGranted: SignalTyped.Signal<Player, string>,

	start: (self: MarketplaceServiceServer) -> (),
	stop: (self: MarketplaceServiceServer) -> (),
	getState: (self: MarketplaceServiceServer) -> { [string]: any },

	onProduct: (self: MarketplaceServiceServer, key: string, grant: ProductGrant) -> (),
	onPass: (self: MarketplaceServiceServer, key: string, handler: (player: Player) -> ()) -> (),
	ownsPass: (self: MarketplaceServiceServer, player: Player, key: string) -> boolean,
	promptProduct: (self: MarketplaceServiceServer, player: Player, key: string) -> (),
	promptPass: (self: MarketplaceServiceServer, player: Player, key: string) -> (),

	getPremium: (self: MarketplaceServiceServer, userId: number) -> number?,
	addPremium: (self: MarketplaceServiceServer, userId: number, amount: number) -> (boolean, string?),
	spendPremium: (self: MarketplaceServiceServer, userId: number, amount: number) -> (boolean, string?),
	premiumOp: (
		self: MarketplaceServiceServer,
		userId: number,
		mutator: (premium: PlayerDataTypes.Premium) -> boolean
	) -> TransactionOperation,
	_processReceipt: (self: MarketplaceServiceServer, info: { [string]: any }) -> Enum.ProductPurchaseDecision,
}

local MarketplaceServiceServer: MarketplaceServiceServer = {
	dependencies = { "PlayerDataServiceServer", "StateSyncServiceServer" },
	productGranted = productGranted,

	--[=[
		Takes over ProcessReceipt, checks registered passes for every player, and follows pass purchases.
	]=]
	start = function(_self)
		MarketplaceService.ProcessReceipt = processReceipt

		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				for _, key in MarketplaceRegistry.passKeys() do
					local def = MarketplaceRegistry.pass(key)
					if def ~= nil then
						task.spawn(checkPass, player, key, def.passId)
					end
				end
				return function()
					passes:forget(player.UserId)
				end
			end)
		)

		local purchased = MarketplaceService.PromptGamePassPurchaseFinished:Connect(
			function(player: Player, passId: number, wasPurchased: boolean)
				local key = MarketplaceRegistry.passKeyFor(passId)
				if wasPurchased and key ~= nil then
					grantPass(player, key)
				end
			end
		)
		table.insert(stoppers, function()
			purchased:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Declares what a registered product grants: a function returning the transaction ops to commit with
		the receipt (they run atomically and are saved before the purchase is acknowledged). One handler
		per product. Keep it free of side effects — it may run again after a failed save; use
		`productGranted` for sounds and effects.
	]=]
	onProduct = function(_self, key, grant)
		assert(MarketplaceRegistry.product(key) ~= nil, `onProduct: "{key}" is not a registered product`)
		assert(productHandlers[key] == nil, `onProduct: "{key}" already has a handler`)
		productHandlers[key] = grant
	end,

	--[=[
		Runs `handler(player)` when a player is found to own the pass: on join, on purchase, and at once for
		owners already present.
	]=]
	onPass = function(_self, key, handler)
		assert(MarketplaceRegistry.pass(key) ~= nil, `onPass: "{key}" is not a registered pass`)
		local list = passHandlers[key]
		if list == nil then
			list = {}
			passHandlers[key] = list
		end
		table.insert(list, handler)
		for _, player in Players:GetPlayers() do
			if passes:owns(player.UserId, key) then
				runPassHandler(key, handler, player)
			end
		end
	end,

	ownsPass = function(_self, player, key)
		return passes:owns(player.UserId, key)
	end,

	--[=[
		Prompts a purchase from the server (a shop counter's interaction handler). Clients can prompt
		themselves with MarketplaceServiceClient.
	]=]
	promptProduct = function(_self, player, key)
		local def = MarketplaceRegistry.product(key)
		assert(def ~= nil, `promptProduct: "{key}" is not a registered product`)
		MarketplaceService:PromptProductPurchase(player, def.productId)
	end,

	promptPass = function(_self, player, key)
		local def = MarketplaceRegistry.pass(key)
		assert(def ~= nil, `promptPass: "{key}" is not a registered pass`)
		if not passes:owns(player.UserId, key) then
			MarketplaceService:PromptGamePassPurchase(player, def.passId)
		end
	end,

	--[=[
		The account's premium balance, or nil when the profile is not loaded.
	]=]
	getPremium = function(_self, userId)
		local premium = premiumSlice.get(userId)
		return if premium ~= nil then premium.balance else nil
	end,

	--[=[
		Adds premium (a whole, positive amount). Refused by the data layer past MAX_PREMIUM.
	]=]
	addPremium = function(_self, userId, amount)
		Guard.positiveAmount(amount)
		return premiumSlice.mutate(userId, function(premium)
			premium.balance += amount
			return true
		end)
	end,

	--[=[
		Spends premium. False (nothing spent) when the balance is short or the profile is not loaded.
	]=]
	spendPremium = function(_self, userId, amount)
		Guard.positiveAmount(amount)
		local changed, reason = premiumSlice.mutate(userId, function(premium)
			if premium.balance < amount then
				return false
			end
			premium.balance -= amount
			return true
		end)
		return changed, reason
	end,

	--[=[
		A typed transaction op over the premium slice, for atomic multi-slice writes (spend premium and
		grant an item, or a product that grants premium).
	]=]
	premiumOp = function(_self, userId, mutator)
		return premiumSlice.op(userId, mutator)
	end,

	-- Exposed for specs and the admin path; the engine calls it through ProcessReceipt.
	_processReceipt = function(_self, info)
		return processReceipt(info)
	end,

	getState = function(_self)
		local products = 0
		for _ in productHandlers do
			products += 1
		end
		return {
			productHandlers = products,
			passes = MarketplaceRegistry.passKeys(),
			inFlight = inFlight,
			counters = table.clone(counters),
		}
	end,
}

return MarketplaceServiceServer
