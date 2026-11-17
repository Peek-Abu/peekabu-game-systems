--!strict
--[=[
	AnalyticsVisitSystem: the visit events, each behind its own switch (AnalyticsSwitchSystem):
	- quits: `left_game` when a player really quits (not a truck ride): where they were (hub, training, shift, results)
	  and what it came right after (a knock-out, a catch or a chase within AFTER_WINDOW, else nothing);
	- hubTime: `hub_visit` when a hub stay ends: its seconds, how it ended (a real truck, the Training truck, quitting)
	  and whether it was the visit's first hub stay or a return;
	- shiftsPerVisit: `visit_ended` on a real quit: the shifts worked this visit (the value) and the lifetime total's
	  bucket;
	- training: the `training` funnel (the Training truck, the run starting, each stop, done) and `training_skipped`.

	A visit spans the truck rides between the hub and the Shift place. It owns the saved, server-only "visit" account
	slice (AnalyticsVisitRules): a truck ride stamps it, and the next server's load continues the visit when the stamp
	is fresh, so the count never trusts anything a client carries. The slice registers at module load
	(AnalyticsServiceServer requires this module at the top, before PlayerData inits).

	The Shift and Training features report what only they see (a catch, a chase, a knock-out, the results screen, a
	training stop, a worked shift) through AnalyticsServiceServer; this system never requires them.

	Spec-exempt shell (Players, Queue, PlayerData); the decisions are the specced AnalyticsVisitUtils,
	AnalyticsVisitRules and AnalyticsVisitTracker.

	@class AnalyticsVisitSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsServer = ServerScriptService.Features.Analytics

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local AnalyticsConstants = require(AnalyticsServer.Data.AnalyticsConstants)
local AnalyticsTypes = require(AnalyticsServer.Data.AnalyticsTypes)
local AnalyticsVisitRules = require(AnalyticsServer.Rules.AnalyticsVisitRules)
local AnalyticsVisitTracker = require(AnalyticsServer.State.AnalyticsVisitTracker)
local AnalyticsSessionSystem = require(AnalyticsServer.Systems.AnalyticsSessionSystem)
local AnalyticsSwitchSystem = require(AnalyticsServer.Systems.AnalyticsSwitchSystem)
local AnalyticsContextUtils = require(AnalyticsServer.Utils.AnalyticsContextUtils)
local AnalyticsVisitUtils = require(AnalyticsServer.Utils.AnalyticsVisitUtils)
local PlayerDataServiceServer = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)

type Place = AnalyticsTypes.Place
type Moment = AnalyticsTypes.Moment
type HubEnd = AnalyticsTypes.HubEnd

local log = Logger.new("AnalyticsVisitSystem")

local visitSlice = PlayerDataSliceSystem.registerAccount(
	"visit",
	{ shifts = 0, current = 0, handoffAt = 0 },
	function(account)
		return account.visit
	end,
	AnalyticsVisitRules.validate
)

local tracker = AnalyticsVisitTracker.new()
local sender: AnalyticsTypes.Sender? = nil

local AnalyticsVisitSystem = {}

AnalyticsVisitSystem.tracker = tracker

local function isHub(): boolean
	return QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT)
end

local function cohortOf(player: Player): string
	return AnalyticsSessionSystem.tracker:cohortOf(player.UserId)
end

-- Whether the visit slice is needed at all: only hub time and shifts per visit read it.
local function visitTracked(): boolean
	return AnalyticsSwitchSystem.isOn("hubTime") or AnalyticsSwitchSystem.isOn("shiftsPerVisit")
end

-- Mirrors the saved counts into the tracker (a quit reads them after the save may be gone).
local function mirror(userId: number, slice: PlayerDataTypes.Visit)
	tracker:setShifts(userId, slice.current, slice.shifts)
end

-- hub_visit for a hub stay that is still open (each stay is reported once).
local function endHubStay(player: Player, ended: HubEnd)
	local out = sender
	local since = tracker:takeHub(player.UserId)
	if out == nil or since == nil or not AnalyticsSwitchSystem.isOn("hubTime") then
		return
	end
	-- Widened to the fields' `string` (a table's values are invariant).
	local how: string = ended
	out.custom(player, AnalyticsConstants.HUB_EVENT, AnalyticsVisitUtils.seconds(since, os.time()), {
		how,
		if tracker:isAgain(player.UserId) then "again" else "first",
		cohortOf(player),
	})
end

-- A save loaded on this server: the visit goes on (a fresh truck-ride stamp) or starts; a hub stay opens.
local function onProfileLoaded(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end
	if visitTracked() then
		local ran = false
		local continued = false
		local final: PlayerDataTypes.Visit? = nil
		visitSlice.mutate(userId, function(slice)
			ran = true
			local before = slice.current
			local stamped = slice.handoffAt
			continued = AnalyticsVisitRules.arrive(slice, os.time())
			final = table.clone(slice)
			return stamped ~= 0 or before ~= slice.current
		end)
		local loaded = final
		if ran and loaded ~= nil then
			tracker:setAgain(userId, continued)
			mirror(userId, loaded)
		end
	end
	if isHub() then
		tracker:setPlace(userId, "hub")
		if AnalyticsSwitchSystem.isOn("hubTime") then
			tracker:enterHub(userId, os.time())
		end
	end
end

-- A truck ride was decided: not a quit. Ends a hub stay and stamps the visit so the next server continues it.
local function onLeaving(party: { Player }, _role: string, payload: QueueTypes.QueuePayload)
	local training = payload[TrainingConstants.MODE_KEY] == TrainingConstants.MODE
	local fromHub = isHub()
	local stamp = visitTracked()
	local now = os.time()
	for _, player in party do
		tracker:setLeaving(player.UserId, true)
		if fromHub then
			endHubStay(player, if training then "training" else "boarded")
			if training then
				AnalyticsVisitSystem.trainingStep(player, "truck")
			end
		end
		if stamp then
			local ok = visitSlice.mutate(player.UserId, function(slice)
				slice.handoffAt = now
				return true
			end)
			if not ok then
				log:debug("a visit stamp was not written; the next server starts a new visit")
			end
		end
	end
end

-- A truck ride gave up: they are still here (a hub stay starts again).
local function onStayed(party: { Player }, _role: string)
	for _, player in party do
		tracker:setLeaving(player.UserId, false)
		if isHub() and AnalyticsSwitchSystem.isOn("hubTime") then
			tracker:enterHub(player.UserId, os.time())
		end
	end
end

-- A player left this server: a quit unless a truck ride is taking them.
local function onRemoving(player: Player)
	local userId = player.UserId
	local out = sender
	if out ~= nil and not tracker:isLeaving(userId) then
		local where: Place = tracker:placeOf(userId)
		-- Widened to the fields' `string` (a table's values are invariant).
		local place: string = where
		local cohort = cohortOf(player)
		if AnalyticsSwitchSystem.isOn("quits") then
			local after: string = AnalyticsVisitUtils.after(tracker:momentsOf(userId), os.time())
			out.custom(player, AnalyticsConstants.LEFT_EVENT, nil, { place, after, cohort })
		end
		if where == "hub" then
			endHubStay(player, "quit")
		end
		if AnalyticsSwitchSystem.isOn("shiftsPerVisit") then
			local shifts = tracker:shiftsOf(userId)
			out.custom(player, AnalyticsConstants.VISIT_EVENT, shifts.visit, {
				AnalyticsVisitUtils.bucket(shifts.lifetime),
				place,
				cohort,
			})
		end
	end
	-- Deferred, like the session's own bookkeeping, so other PlayerRemoving handlers still read it.
	task.defer(function()
		tracker:forget(userId)
	end)
end

--[=[
	Where the player is now (the Shift feature reports the results screen; Training reports a run).
]=]
function AnalyticsVisitSystem.place(player: Player, place: Place)
	tracker:setPlace(player.UserId, place)
end

--[=[
	Something that just happened to the player in a shift (a catch, a chase, a knock-out): a quit soon after it says so.
]=]
function AnalyticsVisitSystem.moment(player: Player, moment: Moment)
	if AnalyticsSwitchSystem.isOn("quits") then
		tracker:note(player.UserId, moment, os.time())
	end
end

--[=[
	The player worked one shift (not training): into this visit's count and the lifetime total (saved).
]=]
function AnalyticsVisitSystem.worked(player: Player)
	if not AnalyticsSwitchSystem.isOn("shiftsPerVisit") then
		return
	end
	local userId = player.UserId
	local final: PlayerDataTypes.Visit? = nil
	visitSlice.mutate(userId, function(slice)
		AnalyticsVisitRules.worked(slice)
		final = table.clone(slice)
		return true
	end)
	local counted = final
	if counted ~= nil then
		mirror(userId, counted)
	end
end

--[=[
	A training funnel step (AnalyticsConstants.TRAINING_STEPS), once per player per server.
]=]
function AnalyticsVisitSystem.trainingStep(player: Player, stepName: string)
	local out = sender
	if out == nil or not AnalyticsSwitchSystem.isOn("training") then
		return
	end
	local number = AnalyticsConstants.trainingStepNumber(stepName)
	if number == nil or not tracker:markTraining(player.UserId, number) then
		return
	end
	local context = AnalyticsSessionSystem.contextOf(
		player,
		AnalyticsConstants.FUNNEL_EXPERIMENTS,
		AnalyticsSessionSystem.partyOf(player)
	)
	out.funnel(player, AnalyticsConstants.TRAINING_FUNNEL, number, stepName, {
		AnalyticsContextUtils.funnelField(context.tags, context.cohort, AnalyticsConstants.BUILD_LABEL),
		"-",
		AnalyticsContextUtils.funnelTail(context.platform, context.party, "-"),
	})
end

--[=[
	The player skipped training.
]=]
function AnalyticsVisitSystem.trainingSkipped(player: Player)
	local out = sender
	if out == nil or not AnalyticsSwitchSystem.isOn("training") then
		return
	end
	out.custom(player, AnalyticsConstants.TRAINING_SKIPPED_EVENT, nil, { cohortOf(player) })
end

--[=[
	Starts the visit events. Returns the stopper.
]=]
function AnalyticsVisitSystem.start(out: AnalyticsTypes.Sender): () -> ()
	sender = out
	local loaded = PlayerDataServiceServer.profileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		if visitSlice.get(player.UserId) ~= nil then
			onProfileLoaded(player.UserId)
		end
	end
	local leaving = QueueServiceServer.leaving:Connect(onLeaving)
	local stayed = QueueServiceServer.stayed:Connect(onStayed)
	local removing = Players.PlayerRemoving:Connect(onRemoving)
	return function()
		loaded:Disconnect()
		leaving:Disconnect()
		stayed:Disconnect()
		removing:Disconnect()
		sender = nil
	end
end

return AnalyticsVisitSystem
