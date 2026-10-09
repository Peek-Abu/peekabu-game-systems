--!strict
--[=[
	MarketplaceReceiptRules: the account's bounded purchase-id history, and the data-layer validators for
	the two Marketplace slices (`receipts`, `premium`). Pure.

	@class MarketplaceReceiptRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)

type PurchaseReceipts = PlayerDataTypes.PurchaseReceipts

local MarketplaceReceiptRules = {}

function MarketplaceReceiptRules.has(receipts: PurchaseReceipts, purchaseId: string): boolean
	return table.find(receipts.ids, purchaseId) ~= nil
end

--[=[
	Records `purchaseId` (in place), dropping the oldest ids beyond `cap`. False when it is already there.
]=]
function MarketplaceReceiptRules.record(receipts: PurchaseReceipts, purchaseId: string, cap: number): boolean
	if MarketplaceReceiptRules.has(receipts, purchaseId) then
		return false
	end
	table.insert(receipts.ids, purchaseId)
	while #receipts.ids > cap do
		table.remove(receipts.ids, 1)
	end
	return true
end

--[=[
	The `receipts` slice invariant: a list of distinct strings no longer than RECEIPT_HISTORY.
]=]
function MarketplaceReceiptRules.validateReceipts(receipts: PurchaseReceipts): (boolean, string?)
	local ids = receipts.ids
	if type(ids) ~= "table" then
		return false, "receipts.ids must be a list"
	end
	if #ids > MarketplaceConstants.RECEIPT_HISTORY then
		return false, `receipts.ids holds more than {MarketplaceConstants.RECEIPT_HISTORY} ids`
	end
	local seen: { [string]: true } = {}
	for _, id in ids do
		if type(id) ~= "string" then
			return false, "receipts.ids must hold strings"
		end
		if seen[id] then
			return false, `duplicate purchase id "{id}"`
		end
		seen[id] = true
	end
	return true, nil
end

--[=[
	The `premium` slice invariant: a whole-number balance from 0 to MAX_PREMIUM.
]=]
function MarketplaceReceiptRules.validatePremium(premium: PlayerDataTypes.Premium): (boolean, string?)
	local balance = premium.balance
	if type(balance) ~= "number" or balance ~= math.floor(balance) then
		return false, "premium.balance must be a whole number"
	end
	if balance < 0 or balance > MarketplaceConstants.MAX_PREMIUM then
		return false, `premium.balance must be between 0 and {MarketplaceConstants.MAX_PREMIUM}`
	end
	return true, nil
end

return MarketplaceReceiptRules
