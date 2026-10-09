--!strict
--[=[
	CurrencyUtils module: shared currency utility functions

	Provides currency read, check, and display formatting operations.
	For currency type validation, use `CurrencyConstants.isValidCurrencyType()` directly.

	@class CurrencyUtils
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)

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
	Validates a currency table against the registry: every key a registered CurrencyType, every value a
	non-negative number `<= MAX_CURRENCY`. The DATA-LAYER invariant shared by EVERY currency-holding
	slice (a slot's `currency` and a bank's `currency`), so a raw op can never persist an unknown key or
	an out-of-range balance on either. Pure; safe to call inside a slice validator's no-yield region.
	@param currency PlayerDataTypes.Currency -- The currency table to validate
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function CurrencyUtils.validateCurrency(currency: PlayerDataTypes.Currency): (boolean, string?)
	-- Leading table-guard, matching validateInventory/validateEquipment/validateBank: a slice validator
	-- runs in transaction()'s no-yield region, so it must RETURN a rejection for a malformed (non-table)
	-- value rather than throw on `for in nil`.
	if type(currency) ~= "table" then
		return false, `currency must be a table, got {type(currency)}`
	end
	for key, value in currency do
		if not CurrencyConstants.isValidCurrencyType(key) then
			return false, `currency key "{key}" is not a registered currency`
		end
		if type(value) ~= "number" then
			return false, `currency "{key}" must be a number, got {type(value)}`
		end
		if value < 0 then
			return false, `currency "{key}" is negative ({value})`
		end
		if value > CurrencyConstants.MAX_CURRENCY then
			return false, `currency "{key}" exceeds MAX_CURRENCY ({value} > {CurrencyConstants.MAX_CURRENCY})`
		end
	end
	return true
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
