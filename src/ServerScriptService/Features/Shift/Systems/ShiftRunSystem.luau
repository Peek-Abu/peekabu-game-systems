--!strict
--[=[
	ShiftRunSystem: the shift's run lifecycle, moved out of ShiftServiceServer: clearing the last run and shift,
	finishing a reset, preparing the next shift under the transit's cover, starting the crew's transit, beginning a run,
	building the review (`safeResults`), following Round's phases (`onRoundPhase`) and the clock's tick (`step`). The
	service's state, its one way to change it, the run's record (ShiftRunTracker) and the systems it drives are handed in
	as Deps; the transit and the vote are handed in as functions, because they are built after this system (they call
	its `prepareShift`, `finishReset` and `startTransit`). The decisions are the specced ShiftPhaseRules and
	ShiftReviewSystem.results; spec-exempt shell.

	@class ShiftRunSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftServer = ServerScriptService.Features.Shift
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftRunTracker = require(ShiftServer.State.ShiftRunTracker)
local ShiftLivesSystem = require(ShiftServer.Systems.ShiftLivesSystem)
local ShiftReviewSystem = require(ShiftServer.Systems.ShiftReviewSystem)
local ShiftSiteSystem = require(ShiftServer.Systems.ShiftSiteSystem)
local ShiftTransitSystem = require(ShiftServer.Systems.ShiftTransitSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local ShiftVoteSystem = require(ShiftServer.Systems.ShiftVoteSystem)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local log = Logger.new("ShiftServiceServer")

export type Deps = {
	-- The shift's state now, and the service's one way to change it (notices, publish, `changed`).
	getState: () -> ShiftTypes.ShiftState,
	setState: (nextState: ShiftTypes.ShiftState) -> (),
	run: ShiftRunTracker.ShiftRunTracker,
	-- Server time.
	now: () -> number,
	site: ShiftSiteSystem.ShiftSiteSystem,
	lives: ShiftLivesSystem.ShiftLivesSystem,
	roster: ShiftRosterTracker.ShiftRosterTracker,
	trip: ShiftTripSystem.ShiftTripSystem,
	-- Built after this system.
	voting: () -> ShiftVoteSystem.ShiftVoteSystem,
	transit: () -> ShiftTransitSystem.ShiftTransitSystem,
}

export type ShiftRunSystem = {
	-- Clears everything the shift made and waits in the lobby (the tick starts the next transit). Always reaches the
	-- lobby, even when a reset step throws.
	finishReset: () -> (),
	-- Under the transit's cover: clears the last shift, picks the next run's variant and the quota for the crew, and
	-- rebuilds and spawns the office. The run itself starts when the transit settles.
	prepareShift: () -> (),
	-- Begins the crew's transit (from the lobby, or from results for Another shift). False when nobody is here to go.
	startTransit: () -> boolean,
	-- Follows Round's phase changes.
	onRoundPhase: (roundState: RoundTypes.RoundState) -> (),
	-- The clock's tick: pacing, the lobby start, the clock out and the vote's deadline.
	step: () -> (),
}

local ShiftRunSystem = {}

function ShiftRunSystem.new(deps: Deps): ShiftRunSystem
	local getState = deps.getState
	local setState = deps.setState
	local run = deps.run
	local now = deps.now
	local site = deps.site
	local lives = deps.lives
	local roster = deps.roster
	local trip = deps.trip
	local voting = deps.voting
	local transit = deps.transit

	-- Forgets the last run's vote, roster and review; brings knocked-out players back and clears the lives.
	local function clearRun()
		lives:clear()
		voting():clear()
		roster:clear()
		run.results = nil
		run.endingRun = false
		run.coffeeBy = nil
		run.coffeeSeconds = 0
	end

	-- Clears everything the shift made (each step guarded: a throwing reset never stops the next shift).
	local function clearShift()
		site:clear()
		clearRun()
		run.resetPending = false
	end

	local function finishReset()
		transit():cancel()
		clearShift()
		setState(ShiftPhaseRules.toLobby(getState()))
	end

	local function prepareShift()
		clearShift()
		local choice = site:prepare(RoundServiceServer:getPhase().round + 1, #trip:crewIds(), trip:map())
		local nextState = table.clone(getState())
		nextState.variant = choice.variant
		nextState.quota = choice.quota
		setState(nextState)
	end

	local function startTransit(): boolean
		if transit():active() then
			return true
		end
		local crew = trip:crew()
		if #crew == 0 then
			return false
		end
		local nextState = ShiftPhaseRules.transit(getState(), now() + ShiftConstants.TRANSIT_TIMEOUT)
		if nextState == nil then
			return false
		end
		setState(nextState)
		return transit():begin(crew)
	end

	-- The run has started. After a transit the office is already built and the crew placed; a run started some other way
	-- (an admin's round start) builds it here and moves the crew into the truck.
	local function beginRun(wasPrepared: boolean)
		clearRun()
		lives:begin(RoundServiceServer:participants())
		if not wasPrepared then
			-- An admin's round start plays the office.
			local state = getState()
			site:build(
				{ variant = state.variant, quota = state.quota, map = "office" },
				RoundServiceServer:participants()
			)
		end
		local state = getState()
		log:info(`shift {state.shift} started: variant {state.variant}, quota {state.quota}`)
		VacuumServiceServer:setCrew(RoundServiceServer:participants())
	end

	-- The review (ShiftReviewSystem.results: never throws, so the shift can always end), from Round's counters, which are
	-- cleared once Round returns to its lobby; leavers stay from the roster.
	local function safeResults(outcome: string): ShiftTypes.ShiftResults
		local state = getState()
		local built = ShiftReviewSystem.results({
			outcome = outcome,
			quota = state.quota,
			quotaMet = state.quotaMet,
			crew = trip:crew(),
			roster = roster,
			offered = site:offered(),
			ranFor = math.max(0, now() - (state.startedAt or now())),
		})
		-- Coffee for the crew (CoffeeServiceServer:addCoffee): the buyer, and 2x pay for the part of the shift it ran.
		built.coffee = run.coffeeBy
		built.payScale = CoffeeRules.payScale(run.coffeeSeconds, built.ranFor or 0)
		return built
	end

	local function onRoundPhase(roundState: RoundTypes.RoundState)
		local state = getState()
		local before = state.phase
		local nextState = ShiftPhaseRules.follow(state, roundState, now())
		if nextState == nil then
			return
		end
		if nextState.phase == "results" and run.resetPending then
			finishReset()
			return
		end
		-- A clock out built the review before ending the run; a timeout builds it here (counters still intact).
		if nextState.phase == "results" and run.results == nil then
			run.results = safeResults(roundState.outcome or "timeout")
		end
		local starting = nextState.phase == "running" and before ~= "running"
		local ready = if starting then site:take() else nil
		if starting then
			-- Chosen by the transit (prepareShift), which built the office for them; else chosen now, before anyone hears.
			local choice = ready or site:choose(nextState.shift, #RoundServiceServer:participants())
			nextState.variant = choice.variant
			nextState.quota = choice.quota
			-- A run started while the transit still holds the crew (an admin's start) releases them.
			transit():cancel()
		end
		if before == "running" and nextState.phase ~= "running" then
			VacuumServiceServer:setCrew({})
		end
		setState(nextState)
		if starting then
			beginRun(ready ~= nil)
		end
	end

	local function step()
		local advanced = ShiftPhaseRules.advance(getState(), now(), run.training)
		if advanced ~= nil then
			setState(advanced)
		end
		local action = ShiftPhaseRules.tick(getState(), now(), trip:startable(now()))
		if action == "start" then
			startTransit()
		elseif action == "endShift" then
			if run.endingRun then
				return
			end
			-- Built before Round clears its counters; onRoundPhase keeps it. Never throws, so a bad build cannot
			-- leave the shift unable to end.
			run.results = safeResults(ShiftConstants.OUTCOME_CLOCKOUT)
			run.endingRun = true
			if not RoundServiceServer:endRound(ShiftConstants.OUTCOME_CLOCKOUT) then
				run.results = nil
				run.endingRun = false
			end
		elseif action == "resolveVote" then
			voting():resolve(true)
		end
	end

	return {
		finishReset = finishReset,
		prepareShift = prepareShift,
		startTransit = startTransit,
		onRoundPhase = onRoundPhase,
		step = step,
	}
end

return ShiftRunSystem
