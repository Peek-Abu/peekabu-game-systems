--!strict
--[=[
	RankRules: the stored rank's rules (Cleanup Crew "Clearance Level"). Pure; every write is in place on the state it
	is handed, so the same rules drive the profile slice (through PlayerDataService's mutate) and the session copy.

	- `reconcileSeason`: a rank from another season resets to level 1 / 0 XP (RankConstants.RANK_SEASON).
	- `canAward` / `applyAward`: adds a shift's XP once per run id (`lastAwardedRunId`); XP never goes down, so neither
	  does rank. `canAward` is the read-only check, for deciding before a write.
	- `validate`: the slice's data-layer validator.

	@class RankRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)

type RankState = RankTypes.RankState

local function isWhole(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local RankRules = {}

-- A new rank in `season`: level 1, 0 XP, never awarded.
function RankRules.fresh(season: string): RankState
	return { season = season, xp = 0, lastAwardedRunId = "" }
end

-- Resets `state` (in place) when it was earned in another season. True when it changed.
function RankRules.reconcileSeason(state: RankState, season: string): boolean
	if state.season == season then
		return false
	end
	state.season = season
	state.xp = 0
	state.lastAwardedRunId = ""
	return true
end

--[=[
	Whether `applyAward(state, runId, gain)` would change `state`, without changing it: false when the run already
	paid out, the run id is empty, or the gain is not a whole number >= 0. Callers check this before opening a
	profile write, so a refused award costs no mutate (and no audit line).
]=]
function RankRules.canAward(state: RankState, runId: string, gain: number): boolean
	return runId ~= "" and runId ~= state.lastAwardedRunId and isWhole(gain)
end

--[=[
	Adds `gain` XP for run `runId` (in place), capped at MAX_XP. False (and no change) when `canAward` refuses it.
]=]
function RankRules.applyAward(state: RankState, runId: string, gain: number): boolean
	if not RankRules.canAward(state, runId, gain) then
		return false
	end
	state.xp = math.min(RankConstants.MAX_XP, state.xp + gain)
	state.lastAwardedRunId = runId
	return true
end

function RankRules.validate(state: RankState): (boolean, string?)
	local season: unknown = state.season
	local runId: unknown = state.lastAwardedRunId
	if type(season) ~= "string" or season == "" or #season > RankConstants.MAX_SEASON_LENGTH then
		return false, "rank.season must be a non-empty short string"
	end
	if not isWhole(state.xp) or state.xp > RankConstants.MAX_XP then
		return false, "rank.xp must be a whole number from 0 to MAX_XP"
	end
	if type(runId) ~= "string" or #runId > RankConstants.MAX_RUN_ID_LENGTH then
		return false, "rank.lastAwardedRunId must be a short string"
	end
	return true, nil
end

return RankRules
