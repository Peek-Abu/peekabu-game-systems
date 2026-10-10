--!strict
--[=[
	ShiftServiceServer: one Cleanup Crew shift, start to vote (spec §3, §6.5). It configures Round (a 5 s
	arrival countdown, the 7:00 run, late join; results handed straight back, because Round cannot hold
	them) and follows its phases through ShiftPhaseRules. Around them:

	- run start: the clearance target, the office's spawns (OfficeServiceServer:beginShift), the crew moved
	  to the loading bay, which is also where everyone respawns (DeathServiceServer:setSpawnPoint);
	- banking: Cargo's `onBanked` (ShiftBankingSystem) adds trash to Round's `clearance` counter and salvage
	  to `bonus`, keeps per-player scores, and stamps QUOTA MET once;
	- pacing (M2): meeting the quota starts Harlow's break; the clock steps break -> overtime warning ->
	  overtime (salvage x1.5) and raises the pressure tier at 2:00 and 4:00 (ShiftPhaseRules.advance), each
	  change announced (ShiftNoticeUtils) and fired on `changed`;
	- clock out: the time clock at the truck starts a 10 s countdown for everyone, then ends the run;
	- results: ShiftResultsUtils builds the review; the crew votes Another shift / Back to depot (Back to depot
	  sends the crew home through ShiftTripSystem with the review as its result card);
	- the crew (M4): a shift starts only for the party that arrived through the Queue (ShiftTripSystem); only
	  the crew takes part in Round's run, votes and respawns in the loading bay;
	- reset: Office, Vacuum and Cargo clear everything the shift made. `resetShift` mid-run (Studio test
	  runs) ends Round's run first and skips the review.

	State rides the `shift` world entry (ShiftSnapshotUtils). Spec-exempt shell (Players, RunService, the
	services it drives); the decisions are the specced ShiftPhaseRules, ShiftVoteRules, ShiftResultsUtils and
	ShiftSnapshotUtils.

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
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftVoteRules = require(ShiftServer.Rules.ShiftVoteRules)
local ShiftNoticeUtils = require(ShiftServer.Utils.ShiftNoticeUtils)
local ShiftResultsUtils = require(ShiftServer.Utils.ShiftResultsUtils)
local ShiftRosterTracker = require(ShiftServer.State.ShiftRosterTracker)
local ShiftBankingSystem = require(ShiftServer.Systems.ShiftBankingSystem)
local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

-- Registered at load: the office's time clock carries this kind from the moment it is built.
if not InteractionRegistry.has(ShiftConstants.CLOCK_OUT_KIND) then
	InteractionRegistry.register(ShiftConstants.CLOCK_OUT_KIND, { actionText = "Clock out", objectText = "Time clock" })
end

local log = Logger.new("ShiftServiceServer")

local state: ShiftTypes.ShiftState = ShiftPhaseRules.initial(ShiftConstants.QUOTA, ShiftConstants.VARIANT)
local votes: { [number]: ShiftTypes.Vote } = {}
local results: ShiftTypes.ShiftResults? = nil
local resetPending = false
-- Set once the clock-out has ended Round's run: tick repeats `endShift` until Round leaves running.
local endingRun = false
-- Every crew member's run so far, kept past leaving so their work stays in the crew totals.
local roster = ShiftRosterTracker.new()
-- The crew and the trips between the depot and the office (Queue); only the crew starts, takes part and votes.
local trip = ShiftTripSystem.new()
local rng = Random.new()
local publishScheduled = false
local stoppers: { () -> () } = {}
-- Every state change (a copy), for Occupant (Harlow follows the run, its break and its tier).
local changed: SignalTyped.Signal<ShiftTypes.ShiftState> = SignalTyped.new()

local function now(): number
	return Workspace:GetServerTimeNow()
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
		local another, depot = ShiftVoteRules.tally(votes, presentIds())
		local review = results
		-- During results Round has already cleared its counters, so the review carries the totals.
		local cleared = if review ~= nil then review.cleared else RoundServiceServer:teamValue(ShiftConstants.CLEARANCE)
		local bonus = if review ~= nil then review.bonus else RoundServiceServer:teamValue(ShiftConstants.BONUS)
		StateSyncWorldStore.set(
			ShiftConstants.WORLD_ENTRY,
			ShiftSnapshotUtils.build(state, cleared, bonus, another, depot, review)
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
	table.clear(votes)
	roster:clear()
	results = nil
	endingRun = false
	resetPending = false
	setState(ShiftPhaseRules.toLobby(state))
end

local function beginRun()
	table.clear(votes)
	roster:clear()
	results = nil
	endingRun = false
	RoundServiceServer:setTarget(ShiftConstants.CLEARANCE, state.quota)
	local plan = OfficeServiceServer:beginShift({
		seed = rng:NextInteger(1, 1000000000),
		variant = state.variant,
		quota = state.quota,
	})
	log:info(
		`shift {state.shift} started: variant {state.variant}, greed {if plan.greed ~= nil then plan.greed.kind else "?"}`
	)
	for index, player in RoundServiceServer:participants() do
		local character = player.Character
		if character ~= nil then
			character:PivotTo(OfficeServiceServer:spawnCFrame(index))
		end
	end
	ToastServiceServer:send("all", {
		text = `Shift {state.shift}: clear {state.quota} of trash before the clock runs out. Load it on the truck.`,
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
	setState(nextState)
	if nextState.phase == "running" and before ~= "running" then
		beginRun()
	end
end

-- Cargo's banking handler (ShiftBankingSystem): salvage x1.5 in overtime; meeting the quota starts the break
-- (its notice comes from setState, ShiftNoticeUtils).
local onBanked = ShiftBankingSystem.new({
	roster = roster,
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

local function resolveVote(timedOut: boolean, leaving: number?)
	local decision = ShiftVoteRules.decide(votes, presentIds(leaving), timedOut)
	if decision == nil then
		return
	end
	-- Back to depot: the crew rides home with the review; if the trip is refused, the reset is another shift.
	if decision == "depot" then
		trip:sendHome(results, state.shift, now())
	end
	finishReset()
end

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
		resolveVote(true)
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

local ShiftServiceServer: ShiftServiceServer

local onVote = RequestHandler.wrap({
	name = "ShiftVote",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	validate = function(data: string, _player: Player): (boolean, string?, ShiftTypes.Vote?)
		local choice: ShiftTypes.Vote? = ShiftVoteRules.parse(data)
		if not choice then
			return false, "unknown vote", nil
		end
		return true, nil, choice
	end,
	handler = function(_data: string, player: Player, choice: ShiftTypes.Vote?)
		if choice ~= nil then
			ShiftServiceServer:vote(player, choice)
		end
	end,
})

ShiftServiceServer = {
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
		Configures Round and Death, takes over banking and the time clock, follows Round, counts piles,
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
		InteractionServiceServer:onInteract(ShiftConstants.CLOCK_OUT_KIND, function(player, _target)
			self:clockOut(player)
		end)

		local phases = RoundServiceServer.phaseChanged:Connect(onRoundPhase)
		local piles = VacuumServiceServer.pileCleared:Connect(function(_pile, players)
			if state.phase ~= "running" then
				return
			end
			for _, player in players do
				if player.Parent ~= nil then
					RoundServiceServer:addScore(player, ShiftConstants.SCORE_PILES, 1)
					roster:record(player.UserId, player.DisplayName, { piles = 1 })
				end
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			votes[player.UserId] = nil
			publish()
			-- Their absence may decide the vote (everyone left has voted, or a majority now exists).
			if state.phase == "results" then
				task.defer(function()
					if state.phase == "results" then
						resolveVote(false, player.UserId)
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
			piles:Disconnect()
			leaving:Disconnect()
			ticking:Disconnect()
		end)
		table.insert(
			stoppers,
			ShiftEvents.packets.Vote.listen(function(data: string, player: Player?)
				if player then
					onVote(data, player)
				end
			end)
		)
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
			text = `{who} clocked out. The shift ends in {ShiftConstants.CLOCK_OUT_SECONDS} s: cargo not on the truck is lost.`,
			duration = ShiftConstants.CLOCK_OUT_SECONDS,
		})
		return true
	end,

	--[=[
		Records a results vote (replacing the player's earlier one) and resolves the vote if it is decided.
	]=]
	vote = function(_self, player, choice)
		if state.phase ~= "results" then
			return false
		end
		votes[player.UserId] = choice
		publish()
		resolveVote(false)
		return true
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
		Counts a catch by Mr. Harlow against the player (the review's roster). False outside a running shift.
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
		local another, depot = ShiftVoteRules.tally(votes, presentIds())
		return {
			phase = state.phase,
			sub = state.sub,
			shift = state.shift,
			quota = state.quota,
			quotaMet = state.quotaMet,
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
