--!strict
--[=[
	ShiftServiceServer: one Cleanup Crew shift, start to vote (spec §3, §6.5). It configures Round (the 7:00 run,
	late join; results handed straight back, because Round cannot hold them) and follows its phases through
	ShiftPhaseRules. Around them:

	- the transit (ShiftTransitSystem): a shift never starts in front of anyone. The crew's arrival, Another shift and
	  the next shift begin a transit (`starting`): the crew is held (anchored) behind the load screen, and only once
	  every screen is covered does the transit reset the last shift and prepare this one (ShiftSiteSystem: the variant,
	  the quota for the crew, the clearance target and the office rebuilt and spawned), then place the crew in the truck.
	  Once the whole crew's clients are ready (or the transit times out) Round's run starts (startNow), so the clock
	  starts with the crew in; Occupant hears `running` only after the office is built.
	  A member arriving on their own (late, or with a second party) is admitted into the transit or held on their own;
	- run start: the crew respawns in the loading bay (anyone else respawns at the depot where this server runs
	  it; DeathServiceServer:setSpawnPoint);
	- the contract (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md): ShiftGloomSystem adds
	  the Gloom of every cleared pile and every cleaning step to Round's `clearance` counter, live, and stamps CONTRACT
	  MET once; banking (Cargo's `onBanked`, ShiftBankingSystem) adds the valuables' Credits to `bonus` and keeps
	  per-player scores, but never Gloom;
	- pacing (M2): meeting the quota starts the Manager's break, which the clock ends; overtime is opt-in: any
	  crew member holding the overtime sheet's Start overtime prompt at the truck starts the overtime warning for
	  the whole crew, then overtime (assets x1.5, the top tier). The sheet's prompt shows only while overtime may
	  start (ShiftPhaseRules.canStartOvertime). The clock raises the pressure tier at 2:00 and 4:00
	  (ShiftPhaseRules.advance); each change is announced (ShiftNoticeUtils) and fired on `changed`;
	- clock out (ShiftClockOutSystem, ShiftClockOutRules): each crew member punches their own card at the truck's time
	  clock and waits in the truck's box; half or more of the crew still in punched starts the truck's 30 s countdown,
	  and the run ends when it runs out or once everyone still in has punched (a solo punch ends it at once);
	- analytics and the A/B variant (M5): each run's variant comes from ShiftAnalyticsSystem.pickVariant;
	  ShiftAnalyticsWatchSystem turns the shift's and the other features' signals into the spec §6.6 events;
	- results: ShiftResultsUtils builds the review; ShiftPaySystem pays the crew still present when it opens; the crew votes Another shift / Back to depot (ShiftVoteSystem;
	  Back to depot sends the crew home through ShiftTripSystem with the review as its result card);
	- the crew (M4): a shift starts only for the party that arrived through the Queue (ShiftTripSystem); only
	  the crew takes part in Round's run, votes and respawns in the loading bay;
	- the review (M3 UI): ShiftReviewSystem counts piles, drops, noise and times heard for the review;
	- role: the shift runs only where the shift role runs (QueueServiceServer:runsRole); a hub-only server
	  publishes no `shift` entry and starts none of this;
	- reset: Office, Vacuum and Cargo clear everything the shift made. `resetShift` mid-run (Studio test
	  runs) ends Round's run first and skips the review.

	State rides the `shift` world entry (ShiftSnapshotUtils). Spec-exempt shell (Players, RunService, the
	services it drives); the decisions are the specced ShiftPhaseRules, ShiftVoteRules (through
	ShiftVoteSystem), ShiftResultsUtils and ShiftSnapshotUtils.

	@class ShiftServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local ShiftServer = ServerScriptService.Features.Shift
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftNoticeUtils = require(ShiftServer.Utils.ShiftNoticeUtils)
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)
local ShiftGloomSystem = require(ShiftServer.Systems.ShiftGloomSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local ShiftTransitSystem = require(ShiftServer.Systems.ShiftTransitSystem)
local ShiftSiteSystem = require(ShiftServer.Systems.ShiftSiteSystem)
local ShiftVoteSystem = require(ShiftServer.Systems.ShiftVoteSystem)
local ShiftOvertimeSystem = require(ShiftServer.Systems.ShiftOvertimeSystem)
local ShiftTimeClockSystem = require(ShiftServer.Systems.ShiftTimeClockSystem)
local ShiftClockOutSystem = require(ShiftServer.Systems.ShiftClockOutSystem)
local ShiftAnalyticsWatchSystem = require(ShiftServer.Systems.ShiftAnalyticsWatchSystem)
local ShiftReviewSystem = require(ShiftServer.Systems.ShiftReviewSystem)
local ShiftCrewStatusSystem = require(ShiftServer.Systems.ShiftCrewStatusSystem)
local ShiftLivesSystem = require(ShiftServer.Systems.ShiftLivesSystem)
local ShiftPaySystem = require(ShiftServer.Systems.ShiftPaySystem)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

-- Registered at load, before any toast names them (the server's ToastRules falls back to "info" otherwise).
for name, style in ShiftConstants.TOAST_STYLES do
	if not ToastRegistry.has(name) then
		ToastRegistry.register(name, style)
	end
end

local log = Logger.new("ShiftServiceServer")

local state: ShiftTypes.ShiftState = ShiftPhaseRules.initial(ShiftConstants.QUOTA, ShiftConstants.VARIANT)
local results: ShiftTypes.ShiftResults? = nil
-- The office as this run's site: its variant, quota and build, and what its roll offered.
local site = ShiftSiteSystem.new()
-- True once `start` got past the shift-role gate; `stop` does nothing otherwise.
local started = false
local resetPending = false
-- Set once the clock-out has ended Round's run: tick repeats `endShift` until Round leaves running.
local endingRun = false
-- Every crew member's run so far, kept past leaving so their work stays in the crew totals.
local roster = ShiftRosterTracker.new()
-- The load screen between the depot and the office and between shifts; built below, once its steps exist.
local transit: ShiftTransitSystem.ShiftTransitSystem
-- Gloom lives (ShiftLivesSystem); built below, once isRunning exists.
local lives: ShiftLivesSystem.ShiftLivesSystem
-- The clock step (below); an arrival in the lobby runs it to start the crew's transit.
local step: () -> ()
-- The crew and the trips between the depot and the office (Queue); only the crew starts, takes part and votes.
local trip = ShiftTripSystem.new({
	admit = function(player: Player)
		-- A late joiner gets the starting lives (nothing unless the shift is running).
		lives:admit(player)
		if state.phase == "lobby" and not transit:active() then
			-- The crew's transit starts on the next step and holds them with everyone else.
			task.defer(step)
			return
		end
		transit:admit(player)
	end,
})
-- The results vote (ShiftVoteSystem); built below, once finishReset exists.
local voting: ShiftVoteSystem.ShiftVoteSystem
local publishScheduled = false
local stoppers: { () -> () } = {}
-- Every state change (a copy), for Occupant (Harlow follows the run, its break and its tier).
local changed: SignalTyped.Signal<ShiftTypes.ShiftState> = SignalTyped.new()
-- Every counted catch with the lives the player has left after it (0 = knocked out), for analytics.
local caught: SignalTyped.Signal<Player, number> = SignalTyped.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isRunning(): boolean
	return state.phase == "running"
end

lives = ShiftLivesSystem.new({
	isRunning = isRunning,
	markOut = function(userId: number, name: string)
		roster:markOut(userId, name)
	end,
})

-- The crew members in the server (`except`: one who is leaving; Players still lists them during PlayerRemoving).
local function presentIds(except: number?): { number }
	return trip:crewIds(except)
end

-- Republishes the `shift` world entry, coalesced to once per frame.
local function publish()
	if publishScheduled then
		return
	end
	publishScheduled = true
	task.defer(function()
		publishScheduled = false
		local another, depot = voting:tally()
		local review = results
		-- During results Round has already cleared its counters, so the review carries the totals.
		local cleared = if review ~= nil then review.cleared else RoundServiceServer:teamValue(ShiftConstants.CLEARANCE)
		local bonus = if review ~= nil then review.bonus else RoundServiceServer:teamValue(ShiftConstants.BONUS)
		StateSyncWorldStore.set(
			ShiftConstants.WORLD_ENTRY,
			ShiftSnapshotUtils.build(state, cleared, bonus, another, depot, review, trip:crewIds(), trip:truck())
		)
	end)
end

-- The one way the state changes: tells the crew what the pacing did, tells listeners, republishes.
local function setState(nextState: ShiftTypes.ShiftState)
	local before = state
	state = nextState
	changed:Fire(table.clone(nextState))
	publish()
	-- Overtime begins: Office spawns its once-per-shift batch of shimmering loot (Shift already depends on Office).
	if nextState.phase == "running" and nextState.stage == "overtime" and before.stage ~= "overtime" then
		site:startOvertime()
	end
	-- Last, each in its own guard: a throwing toast cannot skip the signal or the publish.
	for _, notice in ShiftNoticeUtils.notices(before, nextState) do
		xpcall(function()
			ToastServiceServer:send("all", notice)
		end, function(err: unknown)
			log:error(`pacing notice failed: {err}`)
		end)
	end
end

-- Forgets the last run's vote, roster and review; brings knocked-out players back and clears the lives.
local function clearRun()
	lives:clear()
	voting:clear()
	roster:clear()
	results = nil
	endingRun = false
end

-- Clears everything the shift made (each step guarded: a throwing reset never stops the next shift).
local function clearShift()
	site:clear()
	clearRun()
	resetPending = false
end

-- Clears everything the shift made and waits in the lobby (the tick starts the next transit). Always
-- reaches the lobby, even when a reset step throws.
local function finishReset()
	transit:cancel()
	clearShift()
	setState(ShiftPhaseRules.toLobby(state))
end

-- Under the transit's cover: clears the last shift, then picks the next run's variant and the quota for the crew,
-- and rebuilds and spawns the office. The run itself starts when the transit settles.
local function prepareShift()
	clearShift()
	local choice = site:prepare(RoundServiceServer:getPhase().round + 1, #trip:crewIds())
	local nextState = table.clone(state)
	nextState.variant = choice.variant
	nextState.quota = choice.quota
	setState(nextState)
end

-- Begins the crew's transit (from the lobby, or from results for Another shift). False when nobody is here to go.
local function startTransit(): boolean
	if transit:active() then
		return true
	end
	local crew = trip:crew()
	if #crew == 0 then
		return false
	end
	local nextState = ShiftPhaseRules.transit(state, now() + ShiftConstants.TRANSIT_TIMEOUT)
	if nextState == nil then
		return false
	end
	setState(nextState)
	return transit:begin(crew)
end

-- The run has started. After a transit the office is already built and the crew placed; a run started some other way
-- (an admin's round start) builds it here and moves the crew into the truck.
local function beginRun(wasPrepared: boolean)
	clearRun()
	lives:begin(RoundServiceServer:participants())
	if not wasPrepared then
		site:build({ variant = state.variant, quota = state.quota }, RoundServiceServer:participants())
	end
	log:info(`shift {state.shift} started: variant {state.variant}, quota {state.quota}`)
	VacuumServiceServer:setCrew(RoundServiceServer:participants())
	ToastServiceServer:send("all", {
		text = `Shift {state.shift}: remove {state.quota} Gloom before the clock runs out. Vacuum the dust; clean valuables, then bank them for Credits.`,
		style = ShiftConstants.TOAST_STICKY,
		duration = 6,
	})
end

-- The review (ShiftReviewSystem.results: never throws, so the shift can always end), from Round's counters, which are
-- cleared once Round returns to its lobby; leavers stay from the roster.
local function safeResults(outcome: string): ShiftTypes.ShiftResults
	return ShiftReviewSystem.results({
		outcome = outcome,
		quota = state.quota,
		quotaMet = state.quotaMet,
		crew = trip:crew(),
		roster = roster,
		offered = site:offered(),
	})
end

local function onRoundPhase(roundState: RoundTypes.RoundState)
	local before = state.phase
	local nextState = ShiftPhaseRules.follow(state, roundState, now())
	if nextState == nil then
		return
	end
	if nextState.phase == "results" and resetPending then
		finishReset()
		return
	end
	-- A clock out built the review before ending the run; a timeout builds it here (counters still intact).
	if nextState.phase == "results" and results == nil then
		results = safeResults(roundState.outcome or "timeout")
	end
	local starting = nextState.phase == "running" and before ~= "running"
	local ready = if starting then site:take() else nil
	if starting then
		-- Chosen by the transit (prepareShift), which built the office for them; else chosen now, before anyone hears.
		local choice = ready or site:choose(nextState.shift, #RoundServiceServer:participants())
		nextState.variant = choice.variant
		nextState.quota = choice.quota
		-- A run started while the transit still holds the crew (an admin's start) releases them.
		transit:cancel()
	end
	if before == "running" and nextState.phase ~= "running" then
		VacuumServiceServer:setCrew({})
	end
	setState(nextState)
	if starting then
		beginRun(ready ~= nil)
	end
end

-- Cargo's banking handler (ShiftBankingSystem): overtime loot pays x1.5, everything else x1. Its gate and its re-check are the contract's
-- too (ShiftGloomSystem, in `start`): meeting the contract starts the break
-- (its notice comes from setState, ShiftNoticeUtils); returns the bonus credited, which Cargo's Banked floater shows.
local banking: ShiftBankingSystem.Deps = {
	roster = roster,
	canBank = trip.eligible,
	isOpen = function(): boolean
		return state.phase == "running" and not endingRun
	end,
	afterBank = function()
		local met = ShiftPhaseRules.markQuota(state, RoundServiceServer:teamValue(ShiftConstants.CLEARANCE), now())
		if met ~= nil then
			setState(met)
		else
			publish()
		end
	end,
}

local function getState(): ShiftTypes.ShiftState
	return state
end

-- Each crew member's own time card; a member who punched waits in the truck and may no longer sign for overtime.
local clockOuts = ShiftClockOutSystem.new({
	getState = getState,
	setState = setState,
	now = now,
	crew = function(): { Player }
		return trip:crew()
	end,
	eligible = trip.eligible,
	isKnockedOut = function(player: Player): boolean
		return lives:isKnockedOut(player)
	end,
})
-- The truck's time clock: a crew member who reaches it punches their card.
local timeClock = ShiftTimeClockSystem.new({ clockOut = clockOuts.punch, eligible = trip.eligible })

local overtime = ShiftOvertimeSystem.new({
	getState = getState,
	setState = setState,
	eligible = clockOuts.working,
	now = now,
	changed = changed,
})

voting = ShiftVoteSystem.new({
	isOpen = function(): boolean
		return state.phase == "results"
	end,
	eligible = trip.eligible,
	presentIds = presentIds,
	publish = publish,
	-- Back to depot: the crew rides home with the review. Another shift (or a refused trip home): the transit covers
	-- the crew's screens before the last shift is cleared and the next one built.
	decided = function(depot: boolean)
		if depot and trip:sendHome(results, state.shift, now()) then
			finishReset()
			return
		end
		if not startTransit() then
			finishReset()
		end
	end,
})

transit = ShiftTransitSystem.new({
	prepare = prepareShift,
	abandoned = finishReset,
	slip = function(): (string?, number?)
		return trip:client(), trip:truck()
	end,
})

function step()
	local advanced = ShiftPhaseRules.advance(state, now())
	if advanced ~= nil then
		setState(advanced)
	end
	local action = ShiftPhaseRules.tick(state, now(), trip:startable(now()))
	if action == "start" then
		startTransit()
	elseif action == "endShift" then
		if endingRun then
			return
		end
		-- Built before Round clears its counters; onRoundPhase keeps it. Never throws, so a bad build cannot
		-- leave the shift unable to end.
		results = safeResults(ShiftConstants.OUTCOME_CLOCKOUT)
		endingRun = true
		if not RoundServiceServer:endRound(ShiftConstants.OUTCOME_CLOCKOUT) then
			results = nil
			endingRun = false
		end
	elseif action == "resolveVote" then
		voting:resolve(true)
	end
end

export type ShiftServiceServer = {
	dependencies: { string },
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	caught: SignalTyped.Signal<Player, number>,
	start: (self: ShiftServiceServer) -> (),
	stop: (self: ShiftServiceServer) -> (),
	getState: (self: ShiftServiceServer) -> { [string]: any },
	getShift: (self: ShiftServiceServer) -> ShiftTypes.ShiftState,
	clockOut: (self: ShiftServiceServer, player: Player?) -> boolean,
	vote: (self: ShiftServiceServer, player: Player, choice: ShiftTypes.Vote) -> boolean,
	resetShift: (self: ShiftServiceServer) -> (),
	noteCatch: (self: ShiftServiceServer, player: Player) -> boolean,
	spendLife: (self: ShiftServiceServer, player: Player) -> boolean,
	addLivesModifier: (self: ShiftServiceServer, modify: (number) -> number) -> () -> (),
}

local ShiftServiceServer: ShiftServiceServer = {
	changed = changed,
	caught = caught,
	dependencies = {
		"RoundServiceServer",
		"OfficeServiceServer",
		"VacuumServiceServer",
		"CargoServiceServer",
		"ToastServiceServer",
		"DeathServiceServer",
		"InteractionServiceServer",
		"StateSyncServiceServer",
		"QueueServiceServer",
		"DepotServiceServer",
		"CurrencyServiceServer",
		"AnalyticsServiceServer",
	},

	--[=[
		Configures Round and Death, takes over banking and the time clock, follows Round,
		listens for votes and starts the clock.
	]=]
	start = function(_self)
		if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			log:info("not a shift server: the shift does not run here")
			return
		end
		started = true
		RoundServiceServer:configure({
			minPlayers = ShiftConstants.MIN_PLAYERS,
			countdown = ShiftConstants.ARRIVAL_SECONDS,
			duration = ShiftConstants.SHIFT_SECONDS,
			resultsDuration = 0,
			autoStart = false,
			lateJoin = true,
			eligible = trip.eligible,
		})
		DeathServiceServer:setSpawnPoint(trip.spawnFor)
		trip:start(publish)
		table.insert(stoppers, transit:start())
		CargoServiceServer:onBanked(ShiftBankingSystem.new(banking))
		-- The contract's progress: every cleared pile and cleaning step adds its Gloom live (same gate and re-check).
		table.insert(stoppers, ShiftGloomSystem.start(banking.isOpen, banking.afterBank))
		table.insert(stoppers, ShiftAnalyticsWatchSystem.start(changed, caught, trip))
		table.insert(stoppers, ShiftReviewSystem.start(roster, isRunning))
		-- Pay: every crew member still here gets the full Credits and saved Gloom when the review opens.
		table.insert(
			stoppers,
			ShiftPaySystem.start({
				changed = changed,
				results = function()
					return results
				end,
				present = function()
					return trip:crewIds()
				end,
			}, function(userId: number, amounts)
				return CurrencyServiceServer:grant(userId, amounts, "shiftPay")
			end)
		)
		table.insert(stoppers, ShiftCrewStatusSystem.start(trip, isRunning))
		table.insert(stoppers, timeClock.start())
		table.insert(stoppers, overtime.start())
		table.insert(stoppers, clockOuts.start())

		local phases = RoundServiceServer.phaseChanged:Connect(onRoundPhase)
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= ShiftConstants.TICK_INTERVAL then
				elapsed = 0
				step()
			end
		end)
		table.insert(stoppers, function()
			phases:Disconnect()
			ticking:Disconnect()
		end)
		table.insert(stoppers, voting:start())
		publish()
	end,

	stop = function(_self)
		-- Inert in a hub-only server: leave Depot's spawn resolver (Death) alone.
		if not started then
			return
		end
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		trip:stop()
		DeathServiceServer:setSpawnPoint(nil)
		lives:clear()
		StateSyncWorldStore.clear(ShiftConstants.WORLD_ENTRY)
		started = false
	end,

	getShift = function(_self)
		return table.clone(state)
	end,

	--[=[
		Punches `player`'s time card (the time clock's prompt; ShiftClockOutSystem): they wait in the truck, and the
		truck's countdown or the end follows. False when refused (no player, not running, not crew, already punched).
	]=]
	clockOut = function(_self, player)
		return player ~= nil and clockOuts.punch(player)
	end,

	--[=[
		Records a results vote (replacing the player's earlier one) and resolves the vote if it is decided.
	]=]
	vote = function(_self, player, choice)
		return voting:vote(player, choice)
	end,

	--[=[
		Clears the shift and returns to the lobby (Another shift; Studio test runs). Mid-run it ends Round's
		run first; the reset then happens when Round reports results.
	]=]
	resetShift = function(_self)
		transit:cancel()
		if RoundServiceServer:getPhase().phase == "running" then
			resetPending = true
			RoundServiceServer:endRound(ShiftConstants.OUTCOME_RESET)
			return
		end
		finishReset()
	end,

	--[=[
		Counts a catch by the Manager against the player (the review's roster) and fires `caught` with the lives they have
		left (the catch spent one first, `spendLife`). False outside a running shift.
	]=]
	noteCatch = function(_self, player)
		if state.phase ~= "running" then
			return false
		end
		roster:record(player.UserId, player.DisplayName, { caught = 1 })
		publish()
		local livesLeft = lives:livesLeft(player)
		if livesLeft ~= nil then
			caught:Fire(player, livesLeft)
		end
		return true
	end,

	--[=[
		Spends one of `player`'s lives for a catch (ShiftLivesSystem). True when it was the last: the player is out for
		the shift (kept down, out of the round, marked in the review). False when the shift is not running, the player is
		unknown or already out, or lives remain.
	]=]
	spendLife = function(_self, player)
		return lives:spend(player)
	end,

	--[=[
		Shapes the lives each player starts a shift with: `modify` takes the lives so far and returns the new count (see
		ShiftLivesRules.starting). Returns the function that removes it. Applies from the next run start or admit.
	]=]
	addLivesModifier = function(_self, modify)
		return lives:addModifier(modify)
	end,

	getState = function(_self)
		local another, depot = voting:tally()
		return {
			phase = state.phase,
			sub = state.sub,
			shift = state.shift,
			quota = state.quota,
			quotaMet = state.quotaMet,
			overtimeOpen = ShiftPhaseRules.canStartOvertime(state),
			stage = state.stage,
			stageEndsAt = state.stageEndsAt,
			tier = state.tier,
			variant = state.variant,
			cleared = RoundServiceServer:teamValue(ShiftConstants.CLEARANCE),
			bonus = RoundServiceServer:teamValue(ShiftConstants.BONUS),
			votesAnother = another,
			votesDepot = depot,
			hasResults = results ~= nil,
			resetPending = resetPending,
			crew = #trip:crewIds(),
			leaving = trip:isLeaving(now()),
			transit = transit:active(),
		}
	end,
}

return ShiftServiceServer
