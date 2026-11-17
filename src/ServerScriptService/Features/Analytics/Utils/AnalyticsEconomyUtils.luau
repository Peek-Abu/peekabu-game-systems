--!strict
--[=[
	AnalyticsEconomyUtils: the pure decision behind an economy event. A currency change becomes the Roblox economy
	call, or nothing: no change, a non-finite amount, a currency without a name or a reason that is not logged.
	`record` does the same for a move a feature reports (AnalyticsTypes.EconomyRecord): the call plus its three
	custom fields, item id, rarity and `where|cohort`, every one a cleaned token.

	@class AnalyticsEconomyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local AnalyticsConstants = require(ServerScriptService.Features.Analytics.Data.AnalyticsConstants)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local AnalyticsEconomyUtils = {}

--[=[
	The economy call for a currency change; nil when it must not be logged. The amount is always positive (a
	sink's `amount` is already the absolute spend) and the ending balance is the change's balance.
]=]
function AnalyticsEconomyUtils.call(change: CurrencyConstants.CurrencyChange): AnalyticsTypes.EconomyCall?
	if not isFinite(change.amount) or change.amount <= 0 or not isFinite(change.balance) then
		return nil
	end
	local currency = AnalyticsConstants.CURRENCY_NAMES[change.currency]
	local transactionType = AnalyticsConstants.TRANSACTION_TYPES[change.reason]
	if currency == nil or transactionType == nil then
		return nil
	end
	-- Widen the reason to the call's `sku: string?` here: a table field is invariant, so the literal union will not fit.
	local sku: string = change.reason
	return {
		flow = change.flow,
		currency = currency,
		amount = change.amount,
		endingBalance = change.balance,
		transactionType = transactionType,
		sku = sku,
	}
end

--[=[
	A catalogue id's economy sku group and rarity: `kind:rarity` for an item ("skin:rare"), `bundle:rarity` for a bundle,
	"other" (no rarity) for anything else. Grouping keeps the sku list far under Roblox's 100; the exact id rides in a
	custom field.
]=]
function AnalyticsEconomyUtils.item(id: string): (string, string?)
	local item = CosmeticRegistry.get(id)
	if item ~= nil then
		return `{item.kind}:{item.rarity}`, item.rarity
	end
	local bundle = CosmeticBundleRegistry.get(id)
	if bundle ~= nil then
		return `bundle:{bundle.rarity}`, bundle.rarity
	end
	return "other", nil
end

--[=[
	`value` as a custom-field token: only letters, digits and _ . : - kept, capped at TOKEN_MAX; "-" when empty.
]=]
function AnalyticsEconomyUtils.token(value: string?): string
	if value == nil then
		return "-"
	end
	local cleaned = string.sub(string.gsub(value, "[^%w_%.:%-]", ""), 1, AnalyticsConstants.TOKEN_MAX)
	if cleaned == "" then
		return "-"
	end
	return cleaned
end

--[=[
	The economy call and its fields for a reported move; nil when it must not be logged (no positive finite amount,
	no finite balance, an empty sku, or a currency without a name).
]=]
function AnalyticsEconomyUtils.record(
	record: AnalyticsTypes.EconomyRecord,
	balance: number?,
	cohort: AnalyticsTypes.Cohort
): (AnalyticsTypes.EconomyCall?, { string }?)
	if not isFinite(record.amount) or record.amount <= 0 then
		return nil, nil
	end
	if balance == nil or not isFinite(balance) then
		return nil, nil
	end
	local currency = AnalyticsConstants.CURRENCY_NAMES[record.currency]
	local sku = AnalyticsEconomyUtils.token(record.sku)
	if currency == nil or sku == "-" then
		return nil, nil
	end
	-- Widen the kind to the call's `transactionType: string` (a table field is invariant).
	local transactionType: string = record.kind
	return {
		flow = record.flow,
		currency = currency,
		amount = record.amount,
		endingBalance = balance,
		transactionType = transactionType,
		sku = sku,
	}, {
		AnalyticsEconomyUtils.token(record.item),
		AnalyticsEconomyUtils.token(record.rarity),
		`{AnalyticsEconomyUtils.token(record.where)}|{cohort}`,
	}
end

return table.freeze(AnalyticsEconomyUtils)
