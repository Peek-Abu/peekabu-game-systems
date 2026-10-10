--!strict
--[=[
	ShiftPhaseRules: a Cleanup Crew shift as pure functions over ShiftState (spec §3, §4 "Pacing", §6.5). The
	shift follows Round's phases (lobby → starting → running → results) but keeps `results` itself until the
	crew votes: Round is configured to leave results at once (it cannot be held or cut short).

	While running, two things move independently: the clock-out countdown (`sub`) and the pacing `stage`.
	Meeting the quota starts Harlow's break; `advance` steps break → overtime warning → overtime at their
	deadlines, and keeps the pressure tier current (one more at each TIER_TIMES mark from the shift's start;
	overtime is the top tier).

	Every function returns the NEXT state, or nil when nothing changes; `tick` returns what the service should
	do on this clock step.

	@class ShiftPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftState = ShiftTypes.ShiftState
type ShiftStage = ShiftTypes.ShiftStage

-- The tier for a stage at `now`, counting from `startedAt`.
local function tierFor(stage: ShiftStage, startedAt: number?, now: number): number
	if stage == "overtime" then
		return ShiftConstants.TOP_TIER
	end
	if startedAt == nil then
		return 0
	end
	local elapsed = now - startedAt
	local tier = 0
	for _, mark in ShiftConstants.TIER_TIMES do
		if elapsed >= mark then
			tier += 1
		end
	end
	return math.min(tier, ShiftConstants.TOP_TIER)
end

local ShiftPhaseRules = {}

function ShiftPhaseRules.initial(quota: number, variant: ShiftTypes.Variant): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 0,
		quota = quota,
		quotaMet = false,
		variant = variant,
	}
end

--[=[
	Back to waiting, keeping the shift count, quota and variant (a cancelled countdown, or a reset after the
	vote).
]=]
function ShiftPhaseRules.toLobby(state: ShiftState): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = state.shift,
		quota = state.quota,
		quotaMet = false,
		variant = state.variant,
	}
end

--[=[
	Follows a Round phase change. Results are held until the vote even after Round returns to its lobby.
]=]
function ShiftPhaseRules.follow(state: ShiftState, round: RoundTypes.RoundState, now: number): ShiftState?
	if round.phase == "starting" and state.phase == "lobby" then
		local nextState = table.clone(state)
		nextState.phase = "starting"
		nextState.endsAt = round.endsAt
		return nextState
	end
	if round.phase == "running" and state.phase ~= "running" then
		return {
			phase = "running",
			sub = "normal",
			stage = "normal",
			tier = 0,
			shift = round.round,
			startedAt = now,
			endsAt = round.endsAt,
			quota = state.quota,
			quotaMet = false,
			variant = state.variant,
		}
	end
	if round.phase == "results" and state.phase == "running" then
		return {
			phase = "results",
			sub = "normal",
			stage = "normal",
			tier = 0,
			shift = state.shift,
			voteEndsAt = now + ShiftConstants.VOTE_SECONDS,
			quota = state.quota,
			quotaMet = state.quotaMet,
			variant = state.variant,
		}
	end
	if round.phase == "lobby" and state.phase == "starting" then
		return ShiftPhaseRules.toLobby(state)
	end
	return nil
end

--[=[
	Starts the clock-out countdown. Only while running and not already counting down. The pacing stage is
	untouched (overtime still pays ×1.5 during the countdown).
]=]
function ShiftPhaseRules.clockOut(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" or state.sub == "clockout" then
		return nil
	end
	local nextState = table.clone(state)
	nextState.sub = "clockout"
	nextState.clockOutAt = now + ShiftConstants.CLOCK_OUT_SECONDS
	return nextState
end

--[=[
	Marks the quota met the first time clearance reaches it during a running shift, and starts Harlow's
	break (BREAK_SECONDS from `now`).
]=]
function ShiftPhaseRules.markQuota(state: ShiftState, cleared: number, now: number): ShiftState?
	if state.phase ~= "running" or state.quotaMet or cleared < state.quota then
		return nil
	end
	local nextState = table.clone(state)
	nextState.quotaMet = true
	if state.stage == "normal" then
		nextState.stage = "break"
		nextState.stageEndsAt = now + ShiftConstants.BREAK_SECONDS
	end
	return nextState
end

--[=[
	Moves the pacing on to `now`: break → warning (WARNING_SECONDS) → overtime at their deadlines, and the
	tier. Nil when nothing changed or the shift is not running.
]=]
function ShiftPhaseRules.advance(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" then
		return nil
	end
	local stage: ShiftStage = state.stage
	local stageEndsAt = state.stageEndsAt
	if stage == "break" and stageEndsAt ~= nil and now >= stageEndsAt then
		stage = "warning"
		stageEndsAt = stageEndsAt + ShiftConstants.WARNING_SECONDS
	end
	if stage == "warning" and stageEndsAt ~= nil and now >= stageEndsAt then
		stage = "overtime"
		stageEndsAt = nil
	end
	local tier = tierFor(stage, state.startedAt, now)
	local sameStage = stage == state.stage
	if sameStage and stageEndsAt == state.stageEndsAt and tier == state.tier then
		return nil
	end
	local nextState = table.clone(state)
	nextState.stage = stage
	nextState.stageEndsAt = stageEndsAt
	nextState.tier = tier
	return nextState
end

--[=[
	The pressure tier at `now` (0 outside a running shift).
]=]
function ShiftPhaseRules.tierAt(state: ShiftState, now: number): number
	if state.phase ~= "running" then
		return 0
	end
	return tierFor(state.stage, state.startedAt, now)
end

--[=[
	What salvage is multiplied by when banked now: ×1.5 in overtime, else ×1.
]=]
function ShiftPhaseRules.salvageMultiplier(state: ShiftState): number
	if state.stage == "overtime" then
		return ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	end
	return ShiftConstants.SALVAGE_MULTIPLIER
end

--[=[
	What to do on this clock step: start a countdown (someone is waiting in the lobby), end the shift (the
	clock-out countdown ran out), resolve the vote (its time is up), or nothing.
]=]
function ShiftPhaseRules.tick(state: ShiftState, now: number, present: number): ShiftTypes.TickAction
	if state.phase == "lobby" and present >= ShiftConstants.MIN_PLAYERS then
		return "start"
	end
	local clockOutAt = state.clockOutAt
	if state.phase == "running" and state.sub == "clockout" and clockOutAt ~= nil and now >= clockOutAt then
		return "endShift"
	end
	local voteEndsAt = state.voteEndsAt
	if state.phase == "results" and voteEndsAt ~= nil and now >= voteEndsAt then
		return "resolveVote"
	end
	return "none"
end

return ShiftPhaseRules
