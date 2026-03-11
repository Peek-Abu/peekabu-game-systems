--!strict
--[=[
	CurrencyUtils module: shared currency utility functions

	Provides currency read, check, and display formatting operations.
	For currency type validation, use `CurrencyConstants.isValidCurrencyType()` directly.

	@class CurrencyUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)

local CurrencyUtils = {}

--[=[
	Gets a specific currency amount from a currency table.
	@param currency Currency? -- The currency table
	@param currencyType CurrencyConstants.CurrencyType -- The currency type
	@return number -- The amount, 0 if the currency table is nil or the key is absent
]=]
function CurrencyUtils.getCurrencyAmount(
	currency: PlayerDataTypes.Currency?,
	currencyType: CurrencyConstants.CurrencyType
): number
	if not currency then
		return 0
	end
	return currency[currencyType] or 0
end

--[=[
	Checks if the currency table has at least a given amount of the currency.
	@param currency Currency? -- The currency table
	@param currencyType CurrencyConstants.CurrencyType -- The currency type
	@param amount number -- The minimum amount
	@return boolean -- True if enough, false otherwise
]=]
function CurrencyUtils.hasEnoughCurrency(
	currency: PlayerDataTypes.Currency?,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number
): boolean
	Guard.positiveAmount(amount)
	return CurrencyUtils.getCurrencyAmount(currency, currencyType) >= amount
end

--[=[
	Formats a currency amount for display.
	@param amount number -- The amount to format
	@param currencyType CurrencyConstants.CurrencyType? -- Optional: type for icon/suffix
	@return string -- Formatted display string
]=]
function CurrencyUtils.formatCurrency(amount: number, currencyType: CurrencyConstants.CurrencyType?): string
	-- Non-negative only: the comma-grouping below (reverse → group threes → strip a leading comma)
	-- has no sign handling and would misplace the minus/comma for a negative. Currencies are capped
	-- non-negative anyway, so a negative here is a caller bug — fail loud rather than format wrong.
	Guard.nonNegativeAmount(amount)

	local floored = math.floor(amount)
	local formatted = tostring(floored)
	if floored >= 1000 then
		formatted = string.gsub(string.reverse(tostring(floored)), "(%d%d%d)", "%1,")
		formatted = string.reverse(formatted)
		formatted = string.gsub(formatted, "^,", "")
	end

	if currencyType and CurrencyConstants.isValidCurrencyType(currencyType) then
		local def = CurrencyConstants.getCurrencyDefinition(currencyType)
		formatted = formatted .. " " .. def.icon
	end

	return formatted
end

return CurrencyUtils
