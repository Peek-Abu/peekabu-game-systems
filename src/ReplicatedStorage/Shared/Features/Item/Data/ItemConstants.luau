--!strict
--[=[
	ItemConstants: the ONE declaration site for the item rarity and kind registries, and the
	per-kind entry caps that bound a character slot's inventory size.

	Adding a rarity or a kind is an edit here — never a schema change. Kinds are a CATEGORY (UI tabs,
	per-kind caps), not behaviour: whether an item stacks is declared on its definition (`stackMax`),
	so a new kind needs no validator branch. The values below are the base's placeholders; each game
	replaces them with its own. ItemRegistry rejects unknown rarities/kinds against this registry.

	@class ItemConstants
]=]

-- Dynamic registry keys — same documented rationale as ProfilePath being `string` (limitations.md
-- #3). RARITIES/KINDS below are the enumerable, sorted stand-ins for these unions.
export type Rarity = string
export type ItemKind = string

-- Placeholder rarities. This registry does not rank them — a game that needs an order (drop weights,
-- UI sorting) declares it next to the code that uses it.
local RARITIES: { string } = {
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
}
table.sort(RARITIES)

-- Placeholder item kinds. `misc` is the catch-all for key items, drops, and materials.
local KINDS: { string } = {
	"tool",
	"wearable",
	"consumable",
	"misc",
}
table.sort(KINDS)

--[=[
	Per-kind cap on ENTRIES in a slot's inventory (a stack counts once regardless of its quantity; a
	unique item counts once per instance). Bounds profile size at the data layer — tunable here
	without touching validator code. A kind with no entry here is uncapped. Placeholder values.
]=]
local KIND_CAPS: { [string]: number } = {
	tool = 30,
	wearable = 30,
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
