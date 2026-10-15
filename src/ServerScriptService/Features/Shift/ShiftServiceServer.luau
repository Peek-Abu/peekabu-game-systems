--!strict
--[=[
	ShiftServiceServer: one Cleanup Crew shift, start to vote (spec §3, §6.5). It configures Round (a 5 s
	arrival countdown, the 7:00 run, late join; results handed straight back, because Round cannot hold
	them) and follows its phases through ShiftPhaseRules. Around them:

	- run start: the clearance target, the office's spawns (OfficeServiceServer:beginShift), the crew moved
	  to the loading bay, where the crew respawns (anyone else respawns at the depot where this server runs
	  it; DeathServiceServer:setSpawnPoint);
	- banking: Cargo's `onBanked` (ShiftBankingSystem) adds trash to Round's `clearance` counter and salvage
	  to `bonus`, keeps per-player scores, and stamps QUOTA MET once;
	- pacing (M2): meeting the quota starts the Manager's break, which the clock ends; overtime is opt-in: any
	  crew member holding the overtime sheet's Start overtime prompt at the truck starts the overtime warning for
	  the whole crew, then overtime (assets x1.5, the top tier). The sheet's prompt shows only while overtime may
	  start (ShiftPhaseRules.canStartOvertime). The clock raises the pressure tier at 2:00 and 4:00
	  (ShiftPhaseRules.advance); each change is announced (ShiftNoticeUtils) and fired on `changed`;
	- clock out: the time clock at the truck starts a 10 s countdown for everyone, then ends the run;
	- analytics and the A/B variant (M5): each run's variant comes from ShiftAnalyticsSystem.pickVariant;
	  ShiftAnalyticsWatchSystem turns the shift's and the other features' signals into the spec §6.6 events;
	- results: ShiftResultsUtils builds the review; the crew votes Another shift / Back to depot (ShiftVoteSystem;
	  Back to depot sends the crew home through ShiftTripSystem with the review as its result card);
	- the crew (M4): a shift starts only for the party that arrived through the Queue (ShiftTripSystem); only
	  the crew takes part in Round's run, votes and respawns in the loading bay;
	- the review (M3 UI): ShiftReviewSystem counts piles, drops, noise and times heard for the review;
	- reset: Office, Vacuum and Cargo clear everything the shift made. `resetShift` mid-run (Studio test
	  runs) ends Round's run first and skips the review.

	State rides the `shift` world entry (ShiftSnapshotUtils). Spec-exempt shell (Players, RunService, the
	services it drives); the decisions are the specced ShiftPhaseRules, ShiftVoteRules (through
	ShiftVoteSystem), ShiftResultsUtils and ShiftSnapshotUtils.

	@class ShiftServiceServer
]=]

local Players = game:GetService("Players")
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
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftNoticeUtils = require(ShiftServer.Utils.ShiftNoticeUtils)
local ShiftResultsUtils = require(ShiftServer.Utils.ShiftResultsUtils)
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local ShiftVoteSystem = require(ShiftServer.Systems.ShiftVoteSystem)
local ShiftOvertimeSystem = require(ShiftServer.Systems.ShiftOvertimeSystem)
local ShiftTimeClockSystem = require(ShiftServer.Systems.ShiftTimeClockSystem)
local ShiftAnalyticsSystem = require(ShiftServer.Systems.ShiftAnalyticsSystem)
local ShiftAnalyticsWatchSystem = require(ShiftServer.Systems.ShiftAnalyticsWatchSystem)
local ShiftReviewSystem = require(ShiftServer.Systems.ShiftReviewSystem)
local ShiftCrewStatusSystem = require(ShiftServer.Systems.ShiftCrewStatusSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local OfficeSpawnUtils = require(ServerScriptService.Features.Office.Utils.OfficeSpawnUtils)
local ShiftQuotaFormulas = require(ShiftServer.Utils.ShiftQuotaFormulas)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
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
-- Salvage this run's roll offered (the review's "salvage found N of M").
local offered = 0
local resetPending = false
-- Set once the clock-out has ended Round's run: tick repeats `endShift` until Round leaves running.
local endingRun = false
-- Every crew member's run so far, kept past leaving so their work stays in the crew totals.
local roster = ShiftRosterTracker.new()
-- The crew and the trips between the depot and the office (Queue); only the crew starts, takes part and votes.
local trip = ShiftTripSystem.new()
-- The results vote (ShiftVoteSystem); built below, once finishReset exists.
local voting: ShiftVoteSystem.ShiftVoteSystem
local rng = Random.new()
local publishScheduled = false
local stoppers: { () -> () } = {}
-- Every state change (a copy), for Occupant (Harlow follows the run, its break and its tier).
local changed: SignalTyped.Signal<ShiftTypes.ShiftState> = SignalTyped.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isRunning(): boolean
	return state.phase == "running"
end

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

-- Runs one step; a throwing step is logged (not rethrown) and false is returned.
local function guarded(label: string, step: () -> ()): boolean
	return xpcall(step, function(err: unknown): unknown
		log:error(`{label} failed: {err}`)
		return err
	end)
end

-- The one way the state changes: tells the crew what the pacing did, tells listeners, republishes.
local function setState(nextState: ShiftTypes.ShiftState)
	local before = state
	state = nextState
	changed:Fire(table.clone(nextState))
	publish()
	-- Last, each in its own guard: a throwing toast cannot skip the signal or the publish.
	for _, notice in ShiftNoticeUtils.notices(before, nextState) do
		guarded("pacing notice", function()
			ToastServiceServer:send("all", notice)
		end)
	end
end

-- Clears everything the shift made and waits in the lobby (the tick starts the next countdown). Always
-- reaches the lobby, even when a reset step throws.
local function finishReset()
	guarded("office reset", function()
		OfficeServiceServer:reset()
	end)
	guarded("vacuum reset", function()
		VacuumServiceServer:reset()
	end)
	guarded("cargo reset", function()
		CargoServiceServer:reset()
	end)
	voting:clear()
	roster:clear()
	results = nil
	endingRun = false
	resetPending = false
	setState(ShiftPhaseRules.toLobby(state))
end

local function beginRun()
	voting:clear()
	roster:clear()
	results = nil
	endingRun = false
	RoundServiceServer:setTarget(ShiftConstants.CLEARANCE, state.quota)
	local plan = OfficeServiceServer:beginShift({
		seed = rng:NextInteger(1, 1000000000),
		variant = state.variant,
		quota = state.quota,
	})
	offered = OfficeSpawnUtils.salvageCount(plan)
	log:info(
		`shift {state.shift} started: variant {state.variant}, greed {if plan.greed ~= nil then plan.greed.kind else "?"}`
	)
	VacuumServiceServer:setCrew(RoundServiceServer:participants())
	for index, player in RoundServiceServer:participants() do
		local character = player.Character
		if character ~= nil then
			character:PivotTo(OfficeServiceServer:spawnCFrame(index))
		end
	end
	ToastServiceServer:send("all", {
		text = `Shift {state.shift}: bank {state.quota} of site value before the clock runs out. Clean what you find: it is worth more.`,
		style = ShiftConstants.TOAST_STICKY,
		duration = 6,
	})
end

-- The review, from Round's counters (they are cleared once Round returns to its lobby).
local function buildResults(outcome: string): ShiftTypes.ShiftResults
	-- Everyone taking part is listed, even with nothing done yet; leavers stay from the roster.
	for _, player in trip:crew() do
		roster:record(player.UserId, player.DisplayName, {})
	end
	return ShiftResultsUtils.build({
		outcome = outcome,
		quota = state.quota,
		cleared = RoundServiceServer:teamValue(ShiftConstants.CLEARANCE),
		bonus = RoundServiceServer:teamValue(ShiftConstants.BONUS),
		quotaMet = state.quotaMet,
		crew = roster:list(),
		offered = offered,
		lookup = CargoRegistry.get,
	})
end

-- The review, or a bare one when building it throws: the shift must always be able to end.
local function safeResults(outcome: string): ShiftTypes.ShiftResults
	local ok, built = pcall(buildResults, outcome)
	if ok then
		return built
	end
	log:error(`building the results failed: {built}`)
	return ShiftResultsUtils.bare(outcome, state.quota, state.quotaMet)
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
	if nextState.phase == "running" and before ~= "running" then
		-- Each run's A/B variant (spec §4; rewards never read it), chosen before anyone hears of the run.
		nextState.variant = ShiftAnalyticsSystem.pickVariant(nextState.shift)
		-- The quota scales with the crew (ShiftQuotaFormulas); everything banked counts toward it.
		nextState.quota = ShiftQuotaFormulas.quota(#RoundServiceServer:participants())
	end
	if before == "running" and nextState.phase ~= "running" then
		VacuumServiceServer:setCrew({})
	end
	setState(nextState)
	if nextState.phase == "running" and before ~= "running" then
		beginRun()
	end
end

-- Cargo's banking handler (ShiftBankingSystem): assets x1.5 in overtime; meeting the quota starts the break
-- (its notice comes from setState, ShiftNoticeUtils); returns the bonus credited, which Cargo's Banked floater shows.
local onBanked = ShiftBankingSystem.new({
	roster = roster,
	canBank = trip.eligible,
	isOpen = function(): boolean
		return state.phase == "running" and not endingRun
	end,
	multiplier = function(): number
		return ShiftPhaseRules.salvageMultiplier(state)
	end,
	afterBank = function()
		local met = ShiftPhaseRules.markQuota(state, RoundServiceServer:teamValue(ShiftConstants.CLEARANCE), now())
		if met ~= nil then
			setState(met)
		else
			publish()
		end
	end,
})

local overtime = ShiftOvertimeSystem.new({
	getState = function(): ShiftTypes.ShiftState
		return state
	end,
	setState = setState,
	eligible = trip.eligible,
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
	-- Back to depot: the crew rides home with the review; if the trip is refused, the reset is another shift.
	decided = function(depot: boolean)
		if depot then
			trip:sendHome(results, state.shift, now())
		end
		finishReset()
	end,
})

local function step()
	local advanced = ShiftPhaseRules.advance(state, now())
	if advanced ~= nil then
		setState(advanced)
	end
	local action = ShiftPhaseRules.tick(state, now(), trip:startable(now()))
	if action == "start" then
		RoundServiceServer:startCountdown()
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
	start: (self: ShiftServiceServer) -> (),
	stop: (self: ShiftServiceServer) -> (),
	getState: (self: ShiftServiceServer) -> { [string]: any },
	getShift: (self: ShiftServiceServer) -> ShiftTypes.ShiftState,
	clockOut: (self: ShiftServiceServer, player: Player?) -> boolean,
	vote: (self: ShiftServiceServer, player: Player, choice: ShiftTypes.Vote) -> boolean,
	resetShift: (self: ShiftServiceServer) -> (),
	noteCatch: (self: ShiftServiceServer, player: Player) -> boolean,
}

local ShiftServiceServer: ShiftServiceServer = {
	changed = changed,
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
	},

	--[=[
		Configures Round and Death, takes over banking and the time clock, follows Round,
		listens for votes and starts the clock.
	]=]
	start = function(self)
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
		CargoServiceServer:onBanked(onBanked)
		table.insert(stoppers, ShiftAnalyticsWatchSystem.start(changed, trip))
		table.insert(stoppers, ShiftReviewSystem.start(roster, isRunning))
		table.insert(stoppers, ShiftCrewStatusSystem.start(trip, isRunning))
		local function clockOutBy(player: Player)
			self:clockOut(player)
		end
		table.insert(stoppers, ShiftTimeClockSystem.new({ clockOut = clockOutBy }).start())
		table.insert(stoppers, overtime.start())

		local phases = RoundServiceServer.phaseChanged:Connect(onRoundPhase)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			voting:forget(player.UserId)
			publish()
			-- Their absence may decide the vote (everyone left has voted, or a majority now exists).
			if state.phase == "results" then
				task.defer(function()
					if state.phase == "results" then
						voting:resolve(false, player.UserId)
					end
				end)
			end
		end)
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
			leaving:Disconnect()
			ticking:Disconnect()
		end)
		table.insert(stoppers, voting:start())
		publish()
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		trip:stop()
		DeathServiceServer:setSpawnPoint(nil)
		StateSyncWorldStore.clear(ShiftConstants.WORLD_ENTRY)
	end,

	getShift = function(_self)
		return table.clone(state)
	end,

	--[=[
		Starts the 10 s clock-out countdown (the time clock's prompt). False when it cannot (not running, or
		already counting down).
	]=]
	clockOut = function(_self, player)
		local nextState = ShiftPhaseRules.clockOut(state, now())
		if nextState == nil then
			return false
		end
		setState(nextState)
		local who = if player ~= nil then player.DisplayName else "Someone"
		ToastServiceServer:send("all", {
			text = `{who} is clocking out!`,
			style = ShiftConstants.TOAST_STICKY,
			duration = ShiftConstants.CLOCK_OUT_SECONDS,
		})
		return true
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
		if RoundServiceServer:getPhase().phase == "running" then
			resetPending = true
			RoundServiceServer:endRound(ShiftConstants.OUTCOME_RESET)
			return
		end
		finishReset()
	end,

	--[=[
		Counts a catch by the Manager against the player (the review's roster). False outside a running shift.
	]=]
	noteCatch = function(_self, player)
		if state.phase ~= "running" then
			return false
		end
		roster:record(player.UserId, player.DisplayName, { caught = 1 })
		publish()
		return true
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
		}
	end,
}

return ShiftServiceServer
