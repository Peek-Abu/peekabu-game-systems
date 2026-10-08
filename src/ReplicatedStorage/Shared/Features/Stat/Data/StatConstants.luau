--!strict
--[=[
	StatConstants: the ONE declaration site for progression tuning and the stat registry.

	EVERY number here is provisional — carried from the old game as a starting point, expected to be
	retuned. That is the point of this module: retuning is an edit here, never a schema change. The
	persisted slice stores only { totalXp, investments }; everything a stat definition drives (max
	health, regen rates, point pools) is DERIVED by StatFormulas from these constants, so changing a
	base/perPoint/curve value re-derives everywhere with no migration.

	Adding or renaming a stat = one DEFINITIONS entry. The slice validator rejects unknown investment
	keys against this registry (same rule as CurrencyConstants), so a typo'd stat id fails loudly.

	@class StatConstants
]=]

--[=[
	One investable stat.
	@interface StatDefinition
	.pool PoolName -- Which point pool buys it ("main" = the big survivability stats, "sub" = fine-tuning)
	.base number -- The derived value at zero investment
	.perPoint number -- Derived-value gain per invested point (linear, like the old game)
]=]
export type PoolName = "main" | "sub"
export type StatDefinition = {
	pool: PoolName,
	base: number,
	perPoint: number,
}
-- Dynamic registry key — same documented rationale as ProfilePath being `string` (limitations.md #3).
export type StatId = string

local DEFINITIONS: { [string]: StatDefinition } = {
	-- main pool: raw survivability
	health = { pool = "main", base = 200, perPoint = 5 },
	stamina = { pool = "main", base = 100, perPoint = 2 },
	-- sub pool: fine-tuning + the Rot subsystem (Venture's signature mitigation mechanic:
	-- rotEndurance sizes the rot bar, rotStrength scales the spell shield, rotRejuvenation regens it)
	healthRegen = { pool = "sub", base = 1, perPoint = 1 },
	staminaRegen = { pool = "sub", base = 1, perPoint = 1 },
	rotStrength = { pool = "sub", base = 1, perPoint = 1 },
	rotEndurance = { pool = "sub", base = 1, perPoint = 1 },
	rotRejuvenation = { pool = "sub", base = 1, perPoint = 1 },
	strength = { pool = "sub", base = 1, perPoint = 1 },
}

local STAT_IDS: { string } = {}
for id in DEFINITIONS do
	table.insert(STAT_IDS, id)
end
table.sort(STAT_IDS)

local StatConstants = {
	DEFINITIONS = DEFINITIONS,
	STAT_IDS = STAT_IDS,

	-- Progression tuning (provisional; from the old game). XP to advance FROM level L is
	-- L * XP_PER_LEVEL_FACTOR — linear, like the old curve. levelOf/xpForLevel in StatFormulas are
	-- the only readers, so swapping the curve for a steeper one is a one-function change there.
	MAX_LEVEL = 30,
	XP_PER_LEVEL_FACTOR = 25,
	POINTS_PER_LEVEL = { main = 1, sub = 3 },
}

--[=[
	True if `id` names a registered stat. The slice validator uses this to reject unknown investment
	keys — the registry is the single source of truth for what stats exist.
	@param id string -- A candidate stat id
	@return boolean
]=]
function StatConstants.isValidStatId(id: string): boolean
	return DEFINITIONS[id] ~= nil
end

return StatConstants
