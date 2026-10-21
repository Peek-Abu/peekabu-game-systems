--!strict
--[=[
	ShiftPhaseRules: a Cleanup Crew shift as pure functions over ShiftState (spec §3, §4 "Pacing", §6.5). The
	shift follows Round's phases (lobby → starting → running → results) but keeps `results` itself until the
	crew votes: Round is configured to leave results at once (it cannot be held or cut short).

	While running, two things move independently: the truck's clock-out countdown (`sub`, ShiftClockOutRules) and the
	pacing `stage`.
	Meeting the quota starts the Manager's break (a regroup window); `advance` ends it at its deadline, back to the
	normal stage. Overtime is opt-in (docs/cleanup-crew-lore.md "Contract sequence"): only `startOvertime`, a crew
	member's deliberate action at the truck, begins the overtime warning, which `advance` turns into overtime at its
	deadline. The clock alone never starts overtime. `advance` also keeps the pressure tier current (one more at each
	TIER_TIMES mark from the shift's start; overtime is the top tier).

	Every function returns the NEXT state, or nil when nothing changes; `tick` returns what the service should
	do on this clock step.

	@class ShiftPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftClockOutRules = require(script.Parent.ShiftClockOutRules)

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
	The transit begins (ShiftTransitSystem: the load screen while the office is rebuilt and the crew placed): from the
	lobby or a finished shift's results (Another shift) into `starting`, which ends at the transit's deadline `endsAt`.
	Round's `running` then follows as usual. Nil while starting or running.
]=]
function ShiftPhaseRules.transit(state: ShiftState, endsAt: number): ShiftState?
	if state.phase ~= "lobby" and state.phase ~= "results" then
		return nil
	end
	local nextState = ShiftPhaseRules.toLobby(state)
	nextState.phase = "starting"
	nextState.endsAt = endsAt
	return nextState
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
			outcome = round.outcome or RoundConstants.OUTCOME_TIMEOUT,
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
	Marks the quota met the first time clearance reaches it during a running shift, and starts the Manager's
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
	Whether the crew may start overtime now: a running shift whose quota is met, not clocking out, and not already
	in the overtime warning or overtime (during the break, or after it).
]=]
function ShiftPhaseRules.canStartOvertime(state: ShiftState): boolean
	return state.phase == "running"
		and state.quotaMet
		and state.sub ~= "clockout"
		and (state.stage == "break" or state.stage == "normal")
end

--[=[
	A crew member chose overtime (the truck's Start overtime prompt): the overtime warning starts now and overtime
	follows WARNING_SECONDS later, time to bank and regroup. Ends the break early. Nil when it cannot start
	(`canStartOvertime`).
]=]
function ShiftPhaseRules.startOvertime(state: ShiftState, now: number): ShiftState?
	if not ShiftPhaseRules.canStartOvertime(state) then
		return nil
	end
	local nextState = table.clone(state)
	nextState.stage = "warning"
	nextState.stageEndsAt = now + ShiftConstants.WARNING_SECONDS
	return nextState
end

--[=[
	Moves the pacing on to `now`: the break ends at its deadline (back to normal, never into overtime), the
	warning becomes overtime at its deadline, and the tier. Nil when nothing changed or the shift is not running.
]=]
function ShiftPhaseRules.advance(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" then
		return nil
	end
	local stage: ShiftStage = state.stage
	local stageEndsAt = state.stageEndsAt
	if stage == "break" and stageEndsAt ~= nil and now >= stageEndsAt then
		stage = "normal"
		stageEndsAt = nil
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
	What to do on this clock step: start a countdown (someone is waiting in the lobby), end the shift (the
	truck left: ShiftClockOutRules.countdownOver), resolve the vote (its time is up), or nothing.
]=]
function ShiftPhaseRules.tick(state: ShiftState, now: number, present: number): ShiftTypes.TickAction
	if state.phase == "lobby" and present >= ShiftConstants.MIN_PLAYERS then
		return "start"
	end
	if ShiftClockOutRules.countdownOver(state, now) then
		return "endShift"
	end
	local voteEndsAt = state.voteEndsAt
	if state.phase == "results" and voteEndsAt ~= nil and now >= voteEndsAt then
		return "resolveVote"
	end
	return "none"
end

return ShiftPhaseRules
