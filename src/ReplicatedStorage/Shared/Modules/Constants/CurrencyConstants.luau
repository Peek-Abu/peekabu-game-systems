--!strict
--[=[
	CurrencyConstants: Single source of truth for currency definitions.
	
	Add new currencies here - types and validation derive from this.
	
	@class CurrencyConstants
]=]

export type CurrencyDefinition = {
	name: string,
	icon: string,
}

-- Add new currencies here
local CURRENCIES = {
	gold = {
		name = "Gold",
		icon = "🪙",
	},
	gems = {
		name = "Gems",
		icon = "💎",
	},
	-- Add more currencies as needed:
	-- tickets = {
	-- 	name = "Tickets",
	-- 	icon = "🎟️",
	-- },
}

-- Define the type explicitly (must match CURRENCIES keys)
export type CurrencyType = "gold" | "gems"

-- Helper to get all valid currency types
local function getValidCurrencies(): { CurrencyType }
	local types = {}
	for key in CURRENCIES do
		table.insert(types, key)
	end
	return types
end

-- Helper to check if a string is a valid currency type
local function isValidCurrencyType(currencyType: string): boolean
	return CURRENCIES[currencyType] ~= nil
end

-- Helper to get currency definition
local function getCurrencyDefinition(currencyType: CurrencyType): CurrencyDefinition
	return CURRENCIES[currencyType]
end

return {
	CURRENCIES = CURRENCIES,
	MAX_CURRENCY = 1_000_000_000,
	getValidCurrencies = getValidCurrencies,
	isValidCurrencyType = isValidCurrencyType,
	getCurrencyDefinition = getCurrencyDefinition,
}
