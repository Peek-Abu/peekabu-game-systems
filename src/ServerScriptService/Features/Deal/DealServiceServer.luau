--!strict
--[=[
	DealServiceServer: the one-time deals (DealConstants, owner 11-09): Pick a Legendary and Pick a New Hire, Robux
	developer products bought once per account.

	- **Exactly once.** A deal's receipt (MarketplaceServiceServer:onProduct) marks it bought and adds one waiting pick
	  to the buyer's `deals` account slice, plus the deal's Gleam, in the SAME save that records the receipt.
	- **Choosing.** The client's chooser sends DealEvents.Choose; DealRules.canChoose checks a pick waits and the
	  choice is offered (only what the player does not own; Pick a Legendary only for employees they have hired). ONE
	  transaction spends the pick and grants the choice with its bundle (CosmeticServiceServer:grantOps), then the
	  reveal plays (CosmeticServiceServer:announce, source "shop").
	- **Buy once.** The shop hides a bought deal (DealRules.offered). A second receipt that slips through still adds a
	  pick, so a purchase is never lost.

	Until the owner creates the products (DealConstants product ids), no receipt can arrive and the cards say "Soon".

	Spec-exempt shell (Marketplace, PlayerData, Cosmetic wiring); the decisions are the specced DealRules.

	@class DealServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealEvents = require(ReplicatedStorage.Shared.Features.Deal.Net.DealEvents)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)

type DealId = DealConstants.DealId

local dealsSlice = PlayerDataSliceSystem.registerAccount(DealConstants.SLICE, DealRules.fresh(), function(account)
	return account.deals
end, DealRules.validate)

for _, id in DealConstants.ORDER do
	local deal = DealRules.deal(id)
	local productId = deal.productId
	if productId ~= nil and MarketplaceRegistry.product(deal.productKey) == nil then
		MarketplaceRegistry.registerProduct(deal.productKey, { productId = productId })
	end
end

local log = Logger.new("DealServiceServer")
-- One choice per player at a time, and not faster than this.
local CHOOSE_GAP = 0.5

local stoppers: { () -> () } = {}
local lastChoose: { [number]: number } = {}
local counters = { bought = 0, chosen = 0, refused = 0 }

-- A receipt's ops: the deal bought + one pick, and the deal's Gleam (saved with the receipt).
local function purchaseOps(userId: number, id: DealId): { PlayerDataService.TransactionOperation }
	local ops: { PlayerDataService.TransactionOperation } = {
		dealsSlice.op(userId, function(value): boolean
			DealRules.applyPurchase(value, id)
			return true
		end),
	}
	local gleam = DealRules.deal(id).gleam
	if gleam > 0 then
		table.insert(
			ops,
			MarketplaceServiceServer:premiumOp(userId, function(premium): boolean
				premium.balance += gleam
				return true
			end)
		)
	end
	return ops
end

local function chooseImpl(userId: number, dealValue: string, choice: string): (boolean, string?)
	local id = DealRules.parseDeal(dealValue)
	if id == nil then
		return false, "unknown deal"
	end
	local slice = dealsSlice.get(userId)
	if slice == nil then
		return false, "no profile loaded"
	end
	local function owns(item: string): boolean
		return CosmeticServiceServer:owns(userId, item)
	end
	local allowed, refusal = DealRules.canChoose(id, choice, slice, owns)
	if not allowed then
		return false, refusal
	end
	local granted = DealRules.grants(id, choice)
	local ops: { PlayerDataService.TransactionOperation } = {
		dealsSlice.op(userId, function(value): boolean
			return DealRules.spend(value, id)
		end),
	}
	for _, item in granted do
		for _, op in CosmeticServiceServer:grantOps(userId, item) do
			table.insert(ops, op)
		end
	end
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	log:audit(`userId={userId}`, "DEAL_CHOSEN", id, choice)
	CosmeticServiceServer:announce(userId, granted, "shop")
	return true, nil
end

export type DealServiceServer = {
	dependencies: { string },
	start: (self: DealServiceServer) -> (),
	stop: (self: DealServiceServer) -> (),
	choose: (self: DealServiceServer, userId: number, deal: string, choice: string) -> (boolean, string?),
	getState: (self: DealServiceServer) -> { [string]: any },
	-- TEST SEAM (specs and Studio checks, where no Robux receipt can arrive): applies a deal's receipt ops.
	_grantPurchase: (self: DealServiceServer, userId: number, deal: string) -> boolean,
}

local DealServiceServer: DealServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"MarketplaceServiceServer",
		"CosmeticServiceServer",
	},

	start = function(_self)
		for _, id in DealConstants.ORDER do
			local key = DealRules.deal(id).productKey
			if MarketplaceRegistry.product(key) ~= nil then
				MarketplaceServiceServer:onProduct(key, function(player: Player)
					counters.bought += 1
					log:audit(`userId={player.UserId}`, "DEAL_BOUGHT", id)
					return purchaseOps(player.UserId, id)
				end)
			end
		end
		local choosing = DealEvents.packets.Choose.listen(function(value, player: Player?)
			if player == nil then
				return
			end
			local now = os.clock()
			local last = lastChoose[player.UserId]
			if last ~= nil and now - last < CHOOSE_GAP then
				return
			end
			lastChoose[player.UserId] = now
			local ok, refusal = chooseImpl(player.UserId, value.deal, value.choice)
			if ok then
				counters.chosen += 1
			else
				counters.refused += 1
				log:debug(`Choose refused for {player.Name}: {refusal or "?"}`)
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			lastChoose[player.UserId] = nil
		end)
		table.insert(stoppers, function()
			choosing()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
		table.clear(lastChoose)
	end,

	choose = function(_self, userId, deal, choice)
		return chooseImpl(userId, deal, choice)
	end,

	getState = function(_self)
		return { counters = table.clone(counters) }
	end,

	_grantPurchase = function(_self, userId, deal)
		local id = DealRules.parseDeal(deal)
		if id == nil then
			return false
		end
		local committed = PlayerDataService:transaction(purchaseOps(userId, id))
		return committed
	end,
}

return DealServiceServer
