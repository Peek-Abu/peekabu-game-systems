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

-- Define the type explicitly (must match CURRENCIES keys)
export type CurrencyType = "gold" | "gems"

-- Add new currencies here. Typed by CurrencyType keys so iteration yields CurrencyType (no cast)
-- and adding a key that isn't in the CurrencyType union below is a compile error.
local CURRENCIES: { [CurrencyType]: CurrencyDefinition } = {
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

-- Runtime mirror of the CurrencyType union. Luau types are erased at runtime, so the union itself
-- can't be enumerated — this list is the enumerable stand-in, and every drift direction is caught:
--   - a member removed from the union but not from here → compile error (the literal no longer
--     fits { CurrencyType });
--   - a key added to CURRENCIES but not to the union → compile error (the CURRENCIES literal is
--     keyed by CurrencyType);
--   - a union member (and mirror entry) with no CURRENCIES entry, or a mirror that fell behind a
--     grown union+CURRENCIES → validateCurrencyTypes() below errors at boot.
-- When adding a currency, update all three: CURRENCIES, CurrencyType, and this list.
local CURRENCY_TYPE_MEMBERS: { CurrencyType } = { "gold", "gems" }

-- Pure core of validateCurrencyTypes, split out (and exported) so the drift failure modes are
-- spec-testable with synthetic inputs — the real inputs can't drift in a test without failing
-- compilation first. Returns ok plus a message describing the first mismatch.
local function validateSync(currencyKeys: { string }, unionMembers: { string }): (boolean, string?)
	for _, member in unionMembers do
		if not table.find(currencyKeys, member) then
			return false, `CurrencyType union member "{member}" has no CURRENCIES entry`
		end
	end
	if #currencyKeys ~= #unionMembers then
		return false,
			`CURRENCIES has {#currencyKeys} entries but the CurrencyType mirror lists {#unionMembers}`
				.. " — keep CURRENCIES, CurrencyType, and CURRENCY_TYPE_MEMBERS in sync"
	end
	return true, nil
end

-- Boot-time guard against CurrencyType/CURRENCIES drift (called from CurrencyServiceServer.init):
-- errors loudly on startup instead of letting a mismatch surface at first use. See
-- docs/limitations.md #1 for why the union is hand-maintained at all.
local function validateCurrencyTypes()
	local currencyKeys: { string } = {}
	for key in CURRENCIES do
		table.insert(currencyKeys, key)
	end
	local unionMembers: { string } = {}
	for _, member in CURRENCY_TYPE_MEMBERS do
		table.insert(unionMembers, member)
	end
	local ok, message = validateSync(currencyKeys, unionMembers)
	assert(ok, message)
end

-- Helper to get all valid currency types
local function getValidCurrencies(): { CurrencyType }
	local types: { CurrencyType } = {}
	for key in CURRENCIES do
		table.insert(types, key)
	end
	return types
end

-- Helper to check if a string is a valid currency type
local function isValidCurrencyType(currencyType: string): boolean
	for key in CURRENCIES do
		if key == currencyType then
			return true
		end
	end
	return false
end

-- Narrows a wire/untyped string to a typed CurrencyType (or nil if it isn't one). Iterating
-- CURRENCIES yields keys typed as CurrencyType, so the returned value is the real union with no
-- cast — the disciplined way to cross a network boundary where the value arrives as `string`.
local function toCurrencyType(currencyType: string): CurrencyType?
	-- Annotate the loop key: generalized iteration otherwise widens it back to `string`, which a
	-- direct `return` would reject against the CurrencyType? result.
	for key: CurrencyType in CURRENCIES do
		if key == currencyType then
			return key
		end
	end
	return nil
end

-- Helper to get currency definition
local function getCurrencyDefinition(currencyType: CurrencyType): CurrencyDefinition
	local def = CURRENCIES[currencyType]
	assert(def, `no definition registered for currency "{currencyType}"`)
	return def
end

return {
	CURRENCIES = CURRENCIES,
	MAX_CURRENCY = 1_000_000_000,
	validateSync = validateSync,
	validateCurrencyTypes = validateCurrencyTypes,
	getValidCurrencies = getValidCurrencies,
	isValidCurrencyType = isValidCurrencyType,
	toCurrencyType = toCurrencyType,
	getCurrencyDefinition = getCurrencyDefinition,
}
