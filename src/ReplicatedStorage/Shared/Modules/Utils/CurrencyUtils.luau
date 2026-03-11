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

local CurrencyUtils = {}

--[=[
	Gets a specific currency amount from a currency table.
	@param currency Currency? -- The currency table
	@param currencyType string -- The currency type
	@return number -- The amount, 0 if not found/invalid
]=]
function CurrencyUtils.getCurrencyAmount(currency: PlayerDataTypes.Currency?, currencyType: string): number
	if not currency or not CurrencyConstants.isValidCurrencyType(currencyType) then
		return 0
	end
	return currency[currencyType] or 0
end

--[=[
	Checks if the currency table has at least a given amount of the currency.
	@param currency Currency? -- The currency table
	@param currencyType string -- The currency type
	@param amount number -- The minimum amount
	@return boolean -- True if enough, false otherwise
]=]
function CurrencyUtils.hasEnoughCurrency(
	currency: PlayerDataTypes.Currency?,
	currencyType: string,
	amount: number
): boolean
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)
	return CurrencyUtils.getCurrencyAmount(currency, currencyType) >= amount
end

--[=[
	Formats a currency amount for display.
	@param amount number -- The amount to format
	@param currencyType string? -- Optional: type for icon/suffix
	@return string -- Formatted display string
]=]
function CurrencyUtils.formatCurrency(amount: number, currencyType: string?): string
	assert(type(amount) == "number", `amount must be a number, got {type(amount)}`)

	local floored = math.floor(amount)
	local formatted = tostring(floored)
	if floored >= 1000 then
		formatted = string.gsub(string.reverse(tostring(floored)), "(%d%d%d)", "%1,")
		formatted = string.reverse(formatted)
		formatted = string.gsub(formatted, "^,", "")
	end

	if currencyType and CurrencyConstants.isValidCurrencyType(currencyType) then
		local def = CurrencyConstants.getCurrencyDefinition(currencyType :: CurrencyConstants.CurrencyType)
		formatted = formatted .. " " .. def.icon
	end

	return formatted
end

return CurrencyUtils
