--!strict
--[=[
	RoundPhaseRules: the round lifecycle as pure functions over RoundState (design:
	docs/superpowers/specs/2026-10-09-round-design.md). The service steps `tick` on a clock and calls the
	others on request; every function returns the NEXT state, or nil when nothing changes or the request is
	refused. The clock (`now`, server time) and the headcounts are passed in.

	lobby → starting → running → results → lobby

	@class RoundPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)

type RoundState = RoundTypes.RoundState
type RoundConfig = RoundTypes.RoundConfig
type RoundCounts = RoundTypes.RoundCounts

local RoundPhaseRules = {}

local function running(state: RoundState, config: RoundConfig, now: number): RoundState
	local duration = config.duration
	return {
		phase = "running",
		round = state.round + 1,
		endsAt = if duration ~= nil then now + duration else nil,
	}
end

local function results(state: RoundState, config: RoundConfig, now: number, outcome: string): RoundState
	return { phase = "results", round = state.round, endsAt = now + config.resultsDuration, outcome = outcome }
end

local function lobby(state: RoundState): RoundState
	return { phase = "lobby", round = state.round }
end

function RoundPhaseRules.initial(): RoundState
	return { phase = "lobby", round = 0 }
end

--[=[
	Checks a configuration: minPlayers a whole number ≥ 1, capacity a whole number ≥ 1, countdown and
	results ≥ 0, a duration (when given) > 0.
	@return boolean
	@return string? -- the reason when invalid
]=]
function RoundPhaseRules.validateConfig(config: RoundConfig): (boolean, string?)
	if config.minPlayers < 1 or config.minPlayers ~= math.floor(config.minPlayers) then
		return false, "minPlayers must be a whole number of at least 1"
	end
	if config.countdown < 0 then
		return false, "countdown must not be negative"
	end
	local duration = config.duration
	if duration ~= nil and duration <= 0 then
		return false, "duration must be positive (or nil for an untimed run)"
	end
	if config.resultsDuration < 0 then
		return false, "resultsDuration must not be negative"
	end
	if config.containerCapacity < 1 or config.containerCapacity ~= math.floor(config.containerCapacity) then
		return false, "containerCapacity must be a whole number of at least 1"
	end
	return true, nil
end

--[=[
	One clock step. Returns the next state, or nil when the phase does not change.
]=]
function RoundPhaseRules.tick(state: RoundState, config: RoundConfig, counts: RoundCounts, now: number): RoundState?
	local endsAt = state.endsAt
	local due = endsAt ~= nil and now >= endsAt
	if state.phase == "lobby" then
		if config.autoStart and counts.present >= config.minPlayers then
			return { phase = "starting", round = state.round, endsAt = now + config.countdown }
		end
	elseif state.phase == "starting" then
		if counts.present < config.minPlayers then
			return lobby(state)
		end
		if due then
			return running(state, config, now)
		end
	elseif state.phase == "running" then
		if counts.participants == 0 then
			return results(state, config, now, RoundConstants.OUTCOME_ABANDONED)
		end
		if counts.alive == 0 then
			return results(state, config, now, RoundConstants.OUTCOME_WIPED)
		end
		if due then
			return results(state, config, now, RoundConstants.OUTCOME_TIMEOUT)
		end
	elseif state.phase == "results" then
		if due then
			return lobby(state)
		end
	end
	return nil
end

--[=[
	Starts the countdown by request (autoStart off: a lever, a ready pad). Only from the lobby, and only
	with at least minPlayers present.
]=]
function RoundPhaseRules.startCountdown(
	state: RoundState,
	config: RoundConfig,
	counts: RoundCounts,
	now: number
): RoundState?
	if state.phase ~= "lobby" or counts.present < config.minPlayers then
		return nil
	end
	return { phase = "starting", round = state.round, endsAt = now + config.countdown }
end

--[=[
	Starts the run immediately, skipping (or cutting short) the countdown.
]=]
function RoundPhaseRules.startNow(state: RoundState, config: RoundConfig, now: number): RoundState?
	if state.phase ~= "lobby" and state.phase ~= "starting" then
		return nil
	end
	return running(state, config, now)
end

--[=[
	Ends the run with the game's outcome. Only while running.
]=]
function RoundPhaseRules.finish(state: RoundState, config: RoundConfig, now: number, outcome: string): RoundState?
	if state.phase ~= "running" then
		return nil
	end
	return results(state, config, now, outcome)
end

return RoundPhaseRules
