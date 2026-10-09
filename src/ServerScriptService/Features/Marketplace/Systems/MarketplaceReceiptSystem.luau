--!strict
--[=[
	MarketplaceReceiptSystem: the exactly-once decision for one developer-product receipt (design:
	docs/superpowers/specs/2026-10-09-marketplace-design.md). Everything it touches is injected, so the
	whole flow is specced without a DataStore:

	1. Unknown product, buyer not on this server, or profile not loaded → "retry" (Roblox asks again).
	2. A second callback for a purchase id still being processed → "retry".
	3. The purchase id is recorded in the account's receipt history IN THE SAME TRANSACTION as the
	   product's grant operations. An id already in the history adds no grant: only the history is
	   re-saved.
	4. "granted" only when that transaction is durably saved (`commit` returns true); otherwise "retry" —
	   the next callback finds the id recorded and grants nothing again.

	ProfileStore's session lock keeps the profile (and so the history) on one server at a time.

	@class MarketplaceReceiptSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local MarketplaceTypes = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceTypes)
local MarketplaceReceiptRules = require(ServerScriptService.Features.Marketplace.Rules.MarketplaceReceiptRules)

type Receipt = MarketplaceTypes.Receipt
type ReceiptDecision = MarketplaceTypes.ReceiptDecision

--[=[
	What the flow needs from the world, generic over the transaction operation type `Op`.
	- productKeyFor: the registered key for a product id.
	- isPresent: the buyer is on this server.
	- readReceipts: the buyer's receipt history; nil when their profile is not loaded.
	- recordOp: an op recording the purchase id (idempotent: it must succeed when the id is already there,
	  so the history can be re-saved).
	- grantOps: the product's grant as ops, or nil plus a reason when it cannot be granted now.
	- commit: runs the ops as ONE transaction and returns true only once it is durably saved.
]=]
export type ReceiptDeps<Op> = {
	productKeyFor: (productId: number) -> string?,
	isPresent: (userId: number) -> boolean,
	readReceipts: (userId: number) -> PlayerDataTypes.PurchaseReceipts?,
	recordOp: (userId: number, purchaseId: string) -> Op,
	grantOps: (userId: number, key: string, receipt: Receipt) -> ({ Op }?, string?),
	commit: (ops: { Op }) -> boolean,
}

local MarketplaceReceiptSystem = {}

--[=[
	Decides one receipt. `inFlight` is the caller's set of purchase ids being processed right now.
	@return ReceiptDecision -- "granted" (acknowledge) or "retry" (NotProcessedYet)
	@return string -- why, for the log
	@return boolean -- true only when this call newly granted the product
]=]
function MarketplaceReceiptSystem.process<Op>(
	receipt: Receipt,
	deps: ReceiptDeps<Op>,
	inFlight: { [string]: true }
): (ReceiptDecision, string, boolean)
	local key = deps.productKeyFor(receipt.productId)
	if key == nil then
		return "retry", `unregistered product id {receipt.productId}`, false
	end
	if not deps.isPresent(receipt.playerId) then
		return "retry", "buyer is not on this server", false
	end
	local receipts = deps.readReceipts(receipt.playerId)
	if receipts == nil then
		return "retry", "buyer's profile is not loaded", false
	end
	if inFlight[receipt.purchaseId] then
		return "retry", "this purchase is already being processed", false
	end

	inFlight[receipt.purchaseId] = true
	local alreadyGranted = MarketplaceReceiptRules.has(receipts, receipt.purchaseId)
	local ops: { Op } = { deps.recordOp(receipt.playerId, receipt.purchaseId) }
	if not alreadyGranted then
		-- A game's grant handler is isolated: an error means "not now", never a stuck in-flight mark.
		local ok, grant, reason = pcall(function()
			return deps.grantOps(receipt.playerId, key, receipt)
		end)
		if not ok or grant == nil then
			inFlight[receipt.purchaseId] = nil
			local why = if ok then reason else tostring(grant)
			return "retry", why or `product "{key}" could not be granted`, false
		end
		table.move(grant, 1, #grant, #ops + 1, ops)
	end
	local committed, saved = pcall(function()
		return deps.commit(ops)
	end)
	inFlight[receipt.purchaseId] = nil

	if not committed then
		return "retry", `the purchase's transaction errored: {saved}`, false
	end
	if not saved then
		return "retry", "the purchase's save was not confirmed", false
	end
	if alreadyGranted then
		return "granted", "already granted; history re-saved", false
	end
	return "granted", `granted "{key}"`, true
end

return MarketplaceReceiptSystem
