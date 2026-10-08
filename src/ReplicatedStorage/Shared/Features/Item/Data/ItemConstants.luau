--!strict
--[=[
	ItemConstants: the ONE declaration site for the item rarity and kind registries, and the
	per-kind entry caps that bound a character slot's inventory size.

	Adding a rarity or a kind is an edit here (plus, for a kind, a new tagged-union variant in
	PlayerDataTypes and a validator branch wherever `kind` is switched on) — never a schema change.
	The slice validator (Task 3) rejects unknown rarities/kinds against this registry, same rule as
	CurrencyConstants/StatConstants.

	@class ItemConstants
]=]

-- Dynamic registry keys — same documented rationale as ProfilePath being `string` (limitations.md
-- #3). RARITIES/KINDS below are the enumerable, sorted stand-ins for these unions.
export type Rarity = string
export type ItemKind = string

-- The six rarities, Venture-flavoured: `cursed` ties to the Rot subsystem (see StatConstants) and
-- sits above `legendary` in flavour, not in a numeric tier — this registry does not rank rarities.
local RARITIES: { string } = {
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
	"cursed",
}
table.sort(RARITIES)

-- The four item kinds. `misc` is the catch-all for key items, drops, and materials — everything
-- that is not gear (weapon/armour) and not a consumable.
local KINDS: { string } = {
	"weapon",
	"armour",
	"consumable",
	"misc",
}
table.sort(KINDS)

--[=[
	Per-kind cap on ENTRIES in a character slot's inventory (a stack counts once regardless of its
	quantity; a unique item counts once per instance). Bounds profile size at the data layer —
	tunable here without touching validator code. Provisional values, carried from the design spec.
]=]
local KIND_CAPS: { [string]: number } = {
	weapon = 30,
	armour = 30,
	consumable = 40,
	misc = 40,
}

local ItemConstants = {
	RARITIES = RARITIES,
	KINDS = KINDS,
	KIND_CAPS = KIND_CAPS,
}

--[=[
	True if `value` names a registered rarity.
	@param value string -- A candidate rarity
	@return boolean
]=]
function ItemConstants.isValidRarity(value: string): boolean
	return table.find(RARITIES, value) ~= nil
end

--[=[
	True if `value` names a registered item kind.
	@param value string -- A candidate kind
	@return boolean
]=]
function ItemConstants.isValidKind(value: string): boolean
	return table.find(KINDS, value) ~= nil
end

return ItemConstants
