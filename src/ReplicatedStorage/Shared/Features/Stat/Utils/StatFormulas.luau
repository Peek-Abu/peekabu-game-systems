--!strict
--[=[
	StatFormulas: the ONE place progression math lives — pure functions over the persisted stats
	slice ({ totalXp, investments }).

	NOTHING derived is ever stored or replicated. The server calls these to apply Humanoid values and
	answer queries; the client calls the SAME functions on the charm-synced slice for UI. Both realms
	always agree because there is exactly one implementation and its inputs are the synced slice.

	Level is DERIVED from totalXp (levelOf), so there is no level-up carry loop and level/xp cannot
	disagree. Unspent points are DERIVED (earned(level) - spent(investments)), so there is no pool
	counter to corrupt — conservation of points is true by construction.

	Phase 3 (equipment) extends `derive` with an optional `sources` parameter (named modifier
	layers, e.g. equipment bonuses) — an extension of this module, not a parallel system.

	@class StatFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

export type PoolTotals = { main: number, sub: number }
export type Progress = { level: number, xpIntoLevel: number, xpToNext: number? }

local StatFormulas = {}

--[=[
	Cumulative XP at which `level` begins. xpForLevel(1) == 0. With the linear curve (xp to advance
	FROM level L is L * FACTOR), this is the closed-form sum FACTOR * (L-1) * L / 2.
	@param level number -- 1..MAX_LEVEL
	@return number
]=]
function StatFormulas.xpForLevel(level: number): number
	return StatConstants.XP_PER_LEVEL_FACTOR * (level - 1) * level / 2
end

--[=[
	The clamp for addExperience: total XP at which MAX_LEVEL begins. XP beyond this is discarded by
	design (chosen over banking overflow) — raising MAX_LEVEL later does NOT retro-credit capped XP.
	@return number
]=]
function StatFormulas.maxTotalXp(): number
	return StatFormulas.xpForLevel(StatConstants.MAX_LEVEL)
end

--[=[
	The level a lifetime XP total corresponds to, clamped to 1..MAX_LEVEL. Iterative walk of the
	boundaries: MAX_LEVEL is small (30) and this is not hot-path code, so clarity wins over a
	closed-form inverse.
	@param totalXp number -- Lifetime XP (>= 0)
	@return number
]=]
function StatFormulas.levelOf(totalXp: number): number
	local level = 1
	while level < StatConstants.MAX_LEVEL and totalXp >= StatFormulas.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

--[=[
	UI-facing progress: the level, xp into it, and xp needed for the next (nil at max level).
	@param totalXp number
	@return Progress
]=]
function StatFormulas.progress(totalXp: number): Progress
	local level = StatFormulas.levelOf(totalXp)
	local xpIntoLevel = totalXp - StatFormulas.xpForLevel(level)
	local xpToNext: number? = if level >= StatConstants.MAX_LEVEL
		then nil
		else level * StatConstants.XP_PER_LEVEL_FACTOR
	return { level = level, xpIntoLevel = xpIntoLevel, xpToNext = xpToNext }
end

--[=[
	Points earned by reaching `level`: (level - 1) per-level grants — level 1 has earned nothing.
	@param level number
	@return PoolTotals
]=]
function StatFormulas.pointsEarned(level: number): PoolTotals
	local levelsGained = level - 1
	return {
		main = levelsGained * StatConstants.POINTS_PER_LEVEL.main,
		sub = levelsGained * StatConstants.POINTS_PER_LEVEL.sub,
	}
end

--[=[
	Points spent, summed per pool from the investments map. Unknown keys are ignored here — the slice
	validator rejects them before they can be stored, so tolerating them keeps this function total.
	@param investments { [string]: number }
	@return PoolTotals
]=]
function StatFormulas.pointsSpent(investments: { [string]: number }): PoolTotals
	local spent = { main = 0, sub = 0 }
	for id, points in investments do
		local definition = StatConstants.DEFINITIONS[id]
		if definition then
			spent[definition.pool] += points
		end
	end
	return spent
end

--[=[
	Unspent = earned(levelOf(totalXp)) - spent(investments). DERIVED, never stored: there is no pool
	counter to inflate, which is what makes point conservation structural rather than checked.
	@param totalXp number
	@param investments { [string]: number }
	@return PoolTotals
]=]
function StatFormulas.pointsUnspent(totalXp: number, investments: { [string]: number }): PoolTotals
	local earned = StatFormulas.pointsEarned(StatFormulas.levelOf(totalXp))
	local spent = StatFormulas.pointsSpent(investments)
	return { main = earned.main - spent.main, sub = earned.sub - spent.sub }
end

--[=[
	The derived stat values for a build: base + points * perPoint for EVERY registered stat (a
	missing investment key means zero points), plus the sum of any named modifier layers in
	`sources` (e.g. equipment bonuses). This is the single funnel every consumer reads through —
	Humanoid application, future combat, and client UI all call this. An unknown stat id inside a
	source is ignored rather than erroring, for the same reason `pointsSpent` tolerates unknown
	investment keys: it keeps this function total over whatever the caller hands it.
	@param investments { [string]: number }
	@param sources { { [string]: number } }? -- modifier layers, summed on top of the derived base
	@return { [string]: number } -- keyed by stat id
]=]
function StatFormulas.derive(
	investments: { [string]: number },
	sources: { { [string]: number } }?
): { [string]: number }
	local derived: { [string]: number } = {}
	for id, definition in StatConstants.DEFINITIONS do
		local value = definition.base + (investments[id] or 0) * definition.perPoint
		if sources then
			for _, source in sources do
				value += source[id] or 0
			end
		end
		derived[id] = value
	end
	return derived
end

return StatFormulas
