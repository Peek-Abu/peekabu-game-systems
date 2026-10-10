--!strict
--[=[
	ShiftPhaseRules: a Cleanup Crew shift as pure functions over ShiftState (spec §3, §6.5). The shift
	follows Round's phases (lobby → starting → running → results) but keeps `results` itself until the crew
	votes: Round is configured to leave results at once (it cannot be held or cut short). While running, the
	sub-state is `normal` or `clockout`; M2 adds break, warning and overtime here.

	Every function returns the NEXT state, or nil when nothing changes; `tick` returns what the service
	should do on this clock step.

	@class ShiftPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftState = ShiftTypes.ShiftState

local ShiftPhaseRules = {}

function ShiftPhaseRules.initial(quota: number, variant: ShiftTypes.Variant): ShiftState
	return { phase = "lobby", sub = "normal", shift = 0, quota = quota, quotaMet = false, variant = variant }
end

--[=[
	Back to waiting, keeping the shift count, quota and variant (a cancelled countdown, or a reset after the
	vote).
]=]
function ShiftPhaseRules.toLobby(state: ShiftState): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
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
			shift = round.round,
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
	Starts the clock-out countdown. Only while running and not already counting down.
]=]
function ShiftPhaseRules.clockOut(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" or state.sub ~= "normal" then
		return nil
	end
	local nextState = table.clone(state)
	nextState.sub = "clockout"
	nextState.clockOutAt = now + ShiftConstants.CLOCK_OUT_SECONDS
	return nextState
end

--[=[
	Marks the quota met the first time clearance reaches it during a running shift.
]=]
function ShiftPhaseRules.markQuota(state: ShiftState, cleared: number): ShiftState?
	if state.phase ~= "running" or state.quotaMet or cleared < state.quota then
		return nil
	end
	local nextState = table.clone(state)
	nextState.quotaMet = true
	return nextState
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
