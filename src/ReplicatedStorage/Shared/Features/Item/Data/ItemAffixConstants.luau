--!strict
--[=[
	ItemAffixConstants: the ONE declaration site for the affix pool and the flat affix drop chance.

	This is the modernized successor to the old game's `ReplicatedStorage.Modules.Equipment.Boosts`
	module — a named, per-kind pool of rolled modifiers that rename the item ("Titan's Lightbane").
	The old free-form string stats (`"Rot Defense"`) are rejected: every affix's `stat` is a real
	`StatConstants.STAT_IDS` id (asserted at load), the same rule gear `statBonuses` already follows.

	An affix is stored on a `UniqueEntry.affixes` map as `{ [affixId]: rolledValue }` — the ABSOLUTE
	rolled value (see the affix-rolling design spec, Decision 1), keyed by the stable affixId so its
	identity (and display name) survive. Rolling itself lives in `ItemAffixFormulas`; consumption (fold into
	derived stats) in `EquipmentBonusFormulas.aggregate`.

	Adding an affix or retuning a chance is an edit here — never a schema change. Retiring an affix is
	safe: `get` returns nil for a removed id, and both the slice validators and `aggregate` tolerate
	that (they skip it), so items minted with a since-retired affix stay valid and simply stop
	contributing it (matching Path of Exile's disable-don't-delete).

	@class ItemAffixConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

--[=[
	One rollable affix.
	@interface AffixDef
	.stat StatId -- The StatConstants id this affix contributes to
	.min number -- Inclusive integer floor of the rolled value
	.max number -- Inclusive integer ceiling of the rolled value
	.displayName string -- The prefix shown on the item ("Titan's")
	.weight number? -- Reserved (the old `chance`): biases the PICK when weighting lands. Ignored now.
]=]
export type AffixDef = {
	stat: string,
	min: number,
	max: number,
	displayName: string,
	weight: number?,
}

-- Named affixes eligible PER ITEM KIND, keyed by a stable affixId. Weapons roll from `weapon`, armour
-- from `armour`; the pools do not bleed. Provisional content — retune freely.
local POOLS: { [string]: { [string]: AffixDef } } = {
	weapon = {
		warriors = { stat = "strength", min = 1, max = 3, displayName = "Titan's" },
		vigorous = { stat = "staminaRegen", min = 1, max = 2, displayName = "Vigorous" },
	},
	armour = {
		warded = { stat = "rotEndurance", min = 1, max = 2, displayName = "Warded" },
		mending = { stat = "healthRegen", min = 1, max = 2, displayName = "Mending" },
		renewing = { stat = "rotRejuvenation", min = 1, max = 2, displayName = "Renewing" },
	},
}

-- CHANCE that a weapon/armour rolls its single affix — FLAT across ALL rarities (Terraria-style: an
-- affix is an independent "did you get lucky" axis, NOT a rarity amplifier). Higher-rarity gear already
-- carries better base stats / statBonuses, so scaling this by rarity too would double-dip the gap. Any
-- item, common included, has the same shot. Provisional; tune freely (or reintroduce a per-rarity
-- table here later with no schema change if the design shifts).
local AFFIX_CHANCE = 0.30

-- Load-time validation: fail LOUD at boot rather than silently at roll time. Enforces that every
-- affix targets a real stat with a sane range, every kind pool is non-empty, and affixIds are globally
-- unique (so `get`'s cross-pool search is unambiguous).
local seenAffixIds: { [string]: boolean } = {}
for kind, pool in POOLS do
	assert(
		next(pool) ~= nil,
		`[ItemAffixConstants] POOLS["{kind}"] is empty — a dropped affix would have nothing to pick`
	)
	for affixId, def in pool do
		assert(
			not seenAffixIds[affixId],
			`[ItemAffixConstants] affixId "{affixId}" is declared in more than one kind pool — ids must be globally unique`
		)
		seenAffixIds[affixId] = true
		assert(
			StatConstants.isValidStatId(def.stat),
			`[ItemAffixConstants] affix "{affixId}" targets "{def.stat}", which is not a registered StatConstants stat id`
		)
		assert(
			def.min == math.floor(def.min) and def.max == math.floor(def.max) and def.min <= def.max,
			`[ItemAffixConstants] affix "{affixId}" has an invalid integer range [{def.min}, {def.max}]`
		)
	end
end
assert(
	AFFIX_CHANCE >= 0 and AFFIX_CHANCE <= 1,
	`[ItemAffixConstants] AFFIX_CHANCE must be a probability in [0, 1], got {AFFIX_CHANCE}`
)

local ItemAffixConstants = {
	POOLS = POOLS,
	AFFIX_CHANCE = AFFIX_CHANCE,
}

--[=[
	The definition for `affixId`, searched across every kind pool, or nil if no such affix is registered
	(a retired id). affixIds are globally unique (asserted at load), so the first match is the only one.
	@param affixId string -- A candidate affix id
	@return AffixDef?
]=]
function ItemAffixConstants.get(affixId: string): AffixDef?
	for _, pool in POOLS do
		local def = pool[affixId]
		if def then
			return def
		end
	end
	return nil
end

--[=[
	The display prefix for an item carrying `affixes` (e.g. "Titan's"), or nil if it has no resolvable
	affix. Deterministic: affixIds are sorted (NOT map-iteration order, which Lua does not guarantee) and
	the first one that still resolves wins — so the prefix is stable across calls and when more than one
	affix lands later. Retired ids are skipped.
	@param affixes { [string]: number }? -- The entry's rolled affixes
	@return string?
]=]
function ItemAffixConstants.displayPrefix(affixes: { [string]: number }?): string?
	if not affixes then
		return nil
	end
	local ids: { string } = {}
	for affixId in affixes do
		table.insert(ids, affixId)
	end
	if #ids == 0 then
		return nil
	end
	table.sort(ids)
	for _, affixId in ids do
		local def = ItemAffixConstants.get(affixId)
		if def then
			return def.displayName
		end
	end
	return nil
end

return ItemAffixConstants
