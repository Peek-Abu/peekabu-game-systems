--!strict
--[=[
	AnalyticsEconomyUtils: the pure decision behind an economy event. A currency change becomes the Roblox economy
	call, or nothing: no change, a non-finite amount, a currency without a name or a reason that is not logged.

	@class AnalyticsEconomyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

return table.freeze(AnalyticsEconomyUtils)
