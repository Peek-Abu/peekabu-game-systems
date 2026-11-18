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
	- Night Shift (ShiftNightSystem): the run's mode, night, week and carried coats outlive each shift's clearing; every
	  state change is stamped with the run's fields (runMode, night, week, weekBonus, runOver,
	  nightReached); Next night / Clock out is the vote, and a fired or wiped crew skips it and goes home;
	- results: ShiftResultsUtils builds the review; ShiftPaySystem pays the crew still present when it opens; the crew votes Another shift / Back to depot (ShiftVoteSystem;
	  Back to depot sends the crew home through ShiftTripSystem with the review as its result card);
	- the crew (M4): a shift starts only for the party that arrived through the Queue (ShiftTripSystem); only
	  the crew takes part in Round's run, votes and respawns in the loading bay;
	- the review (M3 UI): ShiftReviewSystem counts piles, drops, noise and times heard for the review;
	- role: the shift runs only where the shift role runs (QueueServiceServer:runsRole); a hub-only server
	  publishes no `shift` entry and starts none of this;
	- reset: Office, Vacuum and Cargo clear everything the shift made. `resetShift` mid-run (Studio test
	  runs) ends Round's run first and skips the review.

	The run's lifecycle (clearing, reset, transit start, run start, the review, following Round and the clock's tick) is
	ShiftRunSystem's; the start-up wiring of the subsystems is ShiftWiringSystem's; what the service remembers about the
	run (the review, a pending reset, coffee, training) is ShiftRunTracker's.

	State rides the `shift` world entry (ShiftSnapshotUtils). Spec-exempt shell (Players, RunService, the
	services it drives); the decisions are the specced ShiftPhaseRules, ShiftVoteRules (through
	ShiftVoteSystem), ShiftResultsUtils and ShiftSnapshotUtils.

	@class ShiftServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local ShiftServer = ServerScriptService.Features.Shift
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftNoticeUtils = require(ShiftServer.Utils.ShiftNoticeUtils)
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftRunTracker = require(ShiftServer.State.ShiftRunTracker)
local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local ShiftTransitSystem = require(ShiftServer.Systems.ShiftTransitSystem)
local ShiftSiteSystem = require(ShiftServer.Systems.ShiftSiteSystem)
local ShiftVoteSystem = require(ShiftServer.Systems.ShiftVoteSystem)
local ShiftOvertimeSystem = require(ShiftServer.Systems.ShiftOvertimeSystem)
local ShiftTimeClockSystem = require(ShiftServer.Systems.ShiftTimeClockSystem)
local ShiftClockOutSystem = require(ShiftServer.Systems.ShiftClockOutSystem)
local ShiftLivesSystem = require(ShiftServer.Systems.ShiftLivesSystem)
local ShiftNightSystem = require(ShiftServer.Systems.ShiftNightSystem)
local ShiftRunSystem = require(ShiftServer.Systems.ShiftRunSystem)
local ShiftWiringSystem = require(ShiftServer.Systems.ShiftWiringSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftLeavingSystem = require(ServerScriptService.Features.Shift.Systems.ShiftLeavingSystem)
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
-- What the service remembers about the run: its review, a pending reset, the clock-out, coffee and training.
local run = ShiftRunTracker.new()
-- The office as this run's site: its variant, quota and build, and what its roll offered.
local site = ShiftSiteSystem.new()
-- True once `start` got past the shift-role gate; `stop` does nothing otherwise.
local started = false
-- Every crew member's run so far, kept past leaving so their work stays in the crew totals.
local roster = ShiftRosterTracker.new()
-- The load screen between the depot and the office and between shifts; built below, once its steps exist.
local transit: ShiftTransitSystem.ShiftTransitSystem
-- Gloom lives (ShiftLivesSystem); built below, once isRunning exists.
local lives: ShiftLivesSystem.ShiftLivesSystem
-- The run's lifecycle (ShiftRunSystem); built below, once publish and setState exist. An arrival in the lobby runs its
-- clock step to start the crew's transit.
local runs: ShiftRunSystem.ShiftRunSystem
-- The crew and the trips between the depot and the office (Queue); only the crew starts, takes part and votes.
local trip = ShiftTripSystem.new({
	admit = function(player: Player)
		-- A late joiner gets the starting lives (nothing unless the shift is running).
		lives:admit(player)
		if state.phase == "lobby" and not transit:active() then
			-- The crew's transit starts on the next step and holds them with everyone else.
			task.defer(runs.step)
			return
		end
		transit:admit(player)
	end,
})
-- The results vote (ShiftVoteSystem); built below, once the run's lifecycle exists.
local voting: ShiftVoteSystem.ShiftVoteSystem
local publishScheduled = false
local stoppers: { () -> () } = {}
-- Every state change (a copy), for Occupant (Harlow follows the run, its break and its tier).
local changed: SignalTyped.Signal<ShiftTypes.ShiftState> = SignalTyped.new()
-- Every counted catch with the lives the player has left after it (0 = knocked out) and the seconds into the shift at
-- the catch, for analytics.
local caught: SignalTyped.Signal<Player, number, number> = SignalTyped.new()

-- The Night Shift run: its mode from the crew's trip, its night, week and carried coats (outside the run's clearing).
local nights = ShiftNightSystem.new({
	mode = function()
		return trip:mode()
	end,
	crewIds = function()
		return trip:crewIds()
	end,
	training = function()
		return run.training
	end,
})

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
		local review = run.results
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
	-- The Night Shift run's fields, and a running night's start tier.
	nextState = nights:stamp(nextState)
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

local function getState(): ShiftTypes.ShiftState
	return state
end

runs = ShiftRunSystem.new({
	getState = getState,
	setState = setState,
	run = run,
	now = now,
	site = site,
	lives = lives,
	roster = roster,
	trip = trip,
	nights = nights,
	voting = function()
		return voting
	end,
	transit = function()
		return transit
	end,
})

-- Cargo's banking handler (ShiftBankingSystem): overtime loot pays x1.5, everything else x1. Its gate and its re-check are the contract's
-- too (ShiftGloomSystem, in `start`): meeting the contract starts the break
-- (its notice comes from setState, ShiftNoticeUtils); returns the bonus credited, which Cargo's Banked floater shows.
local banking: ShiftBankingSystem.Deps = {
	roster = roster,
	canBank = trip.eligible,
	isOpen = function(): boolean
		return state.phase == "running" and not run.endingRun
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

local entrances = ShiftWiringSystem.entrances(isRunning, clockOuts.working, lives)

local overtime = ShiftOvertimeSystem.new({
	getState = getState,
	setState = setState,
	eligible = clockOuts.working,
	now = now,
	changed = changed,
})

voting = ShiftVoteSystem.new({
	-- A Night Shift run that is over (fired or wiped) has no vote: the crew goes home when its time runs out.
	isOpen = function(): boolean
		return state.phase == "results" and state.runOver == nil
	end,
	eligible = trip.eligible,
	presentIds = presentIds,
	publish = publish,
	-- Back to depot (Night Shift: Clock out, or a run that is over): the crew rides home with the review. Another shift
	-- (Night Shift: Next night; or a refused trip home): the transit covers the crew's screens before the last shift is
	-- cleared and the next one built.
	decided = function(depot: boolean)
		if nights:decide(depot) == "home" and trip:sendHome(run.results, state.shift, now()) then
			runs.finishReset()
			return
		end
		if not runs.startTransit() then
			runs.finishReset()
		end
	end,
})

transit = ShiftTransitSystem.new({
	prepare = runs.prepareShift,
	abandoned = runs.finishReset,
	slip = function(): (string?, number?, ShiftTypes.MapId?)
		return trip:client(), trip:truck(), trip:map()
	end,
})

-- What `start` wires up (ShiftWiringSystem).
local wiring: ShiftWiringSystem.Deps = {
	changed = changed,
	caught = caught,
	banking = banking,
	run = run,
	roster = roster,
	trip = trip,
	isRunning = isRunning,
	timeClock = timeClock,
	entrances = entrances,
	overtime = overtime,
	clockOuts = clockOuts,
	voting = voting,
	onRoundPhase = runs.onRoundPhase,
	step = runs.step,
}

export type ShiftServiceServer = {
	dependencies: { string },
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	caught: SignalTyped.Signal<Player, number, number>,
	start: (self: ShiftServiceServer) -> (),
	stop: (self: ShiftServiceServer) -> (),
	getState: (self: ShiftServiceServer) -> { [string]: any },
	getShift: (self: ShiftServiceServer) -> ShiftTypes.ShiftState,
	-- The current shift's review, once it has one (from the clock out or the timeout until the next shift starts).
	getResults: (self: ShiftServiceServer) -> ShiftTypes.ShiftResults?,
	clockOut: (self: ShiftServiceServer, player: Player?) -> boolean,
	vote: (self: ShiftServiceServer, player: Player, choice: ShiftTypes.Vote) -> boolean,
	resetShift: (self: ShiftServiceServer) -> (),
	forceOvertime: (self: ShiftServiceServer) -> boolean,
	noteCatch: (self: ShiftServiceServer, player: Player) -> boolean,
	spendLife: (self: ShiftServiceServer, player: Player) -> boolean,
	setLivesFloor: (self: ShiftServiceServer, floor: number) -> (),
	setTraining: (self: ShiftServiceServer, on: boolean) -> (),
	addCoffee: (self: ShiftServiceServer, buyer: string, seconds: number) -> (),
	coffee: (self: ShiftServiceServer) -> string?,
	isTraining: (self: ShiftServiceServer) -> boolean,
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
		"WorkOrderServiceServer",
	},

	--[=[
		Configures Round and Death, takes over banking and the time clock, follows Round,
		listens for votes and starts the clock.
	]=]
	start = function(_self)
		-- Every server, the hub too: the load screen comes up in the place being left the moment a teleport is decided.
		table.insert(stoppers, ShiftLeavingSystem.start())
		if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			log:info("not a shift server: the shift does not run here")
			return
		end
		ShiftWiringSystem.workOrders(wiring, stoppers)
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
		ShiftWiringSystem.start(wiring, stoppers)
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

	getResults = function(_self)
		return run.results
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
			run.resetPending = true
			RoundServiceServer:endRound(ShiftConstants.OUTCOME_RESET)
			return
		end
		runs.finishReset()
	end,

	--[=[
		A filmmaker's skip straight into overtime (the `shiftovertime` command, Admins only; ShiftPhaseRules.forceOvertime).
		False when it cannot.
	]=]
	forceOvertime = function(_self)
		local nextState = ShiftPhaseRules.forceOvertime(state, now())
		if nextState == nil then
			return false
		end
		setState(nextState)
		return true
	end,

	--[=[
		Counts a catch by the Manager against the player (the review's roster) and fires `caught` with the lives they have
		left (the catch spent one first, `spendLife`) and the shift seconds at the catch. False outside a running shift.
	]=]
	noteCatch = function(_self, player)
		if state.phase ~= "running" then
			return false
		end
		roster:record(player.UserId, player.DisplayName, { caught = 1 })
		publish()
		local livesLeft = lives:livesLeft(player)
		if livesLeft ~= nil then
			caught:Fire(player, livesLeft, math.max(0, now() - (state.startedAt or now())))
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
		The fewest lives a catch can leave a player (0, the default: the last catch knocks them out). Training sets 1,
		so a catch there never knocks anyone out. Holds until set again.
	]=]
	setLivesFloor = function(_self, floor)
		lives:setFloor(floor)
	end,

	--[=[
		Marks this server's run as a training run (TrainingServiceServer): the pressure tier stays 0, so the clock
		never speeds the Manager up, and a catch leaves its feedback to training (OccupantCatchUtils.feedback). Holds
		until set again.
	]=]
	setTraining = function(_self, on)
		run.training = on
	end,

	--[=[
		Coffee for the crew (CoffeeServiceServer): `buyer`'s coffee ran for `seconds` more of this shift, so the review
		pays 2x for that part of the shift (CoffeeRules.payScale). Counts only while the shift runs; forgotten when the
		run is cleared.
	]=]
	addCoffee = function(_self, buyer, seconds)
		if not isRunning() or seconds <= 0 then
			return
		end
		run.coffeeBy = run.coffeeBy or buyer
		run.coffeeSeconds += seconds
	end,

	--[=[
		Whose coffee ran first this shift (addCoffee), or nil.
	]=]
	coffee = function(_self)
		return run.coffeeBy
	end,

	--[=[
		Whether this server's run is a training run (setTraining).
	]=]
	isTraining = function(_self)
		return run.training
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
			hasResults = run.results ~= nil,
			resetPending = run.resetPending,
			crew = #trip:crewIds(),
			leaving = trip:isLeaving(now()),
			transit = transit:active(),
			runMode = state.runMode,
			night = state.night,
			weekBonus = state.weekBonus,
			runOver = state.runOver,
		}
	end,
}

return ShiftServiceServer
