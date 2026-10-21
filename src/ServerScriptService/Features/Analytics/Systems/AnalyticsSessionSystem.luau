--!strict
--[=[
	AnalyticsSessionSystem: week-1 analytics' per-session shell, running in the hub and in the Shift place. It takes the
	client's platform report, logs each player's experiment assignment once per session, keeps the hub half of the
	first-time funnel (joined_hub, boarded_truck, next_shift) and builds the one context field every event carries.

	It is handed a Sender at `start` and never requires AnalyticsServiceServer (that service starts it).

	Spec-exempt shell (Players, ByteNet, Queue, PlayerData); the context, cohort, tags and dedupe are the specced
	AnalyticsContextUtils, AnalyticsContextTracker and ExperimentServiceServer.

	@class AnalyticsSessionSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsServer = ServerScriptService.Features.Analytics

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftPlatformRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftPlatformRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local AnalyticsConstants = require(AnalyticsServer.Data.AnalyticsConstants)
local AnalyticsTypes = require(AnalyticsServer.Data.AnalyticsTypes)
local AnalyticsFirstSeenSystem = require(AnalyticsServer.Systems.AnalyticsFirstSeenSystem)
local AnalyticsContextTracker = require(AnalyticsServer.State.AnalyticsContextTracker)
local AnalyticsContextUtils = require(AnalyticsServer.Utils.AnalyticsContextUtils)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)
local ExperimentServiceServer = require(ServerScriptService.Features.Experiment.ExperimentServiceServer)
local PlayerDataServiceServer = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)

local log = Logger.new("AnalyticsSessionSystem")
local build = AnalyticsContextUtils.build(AnalyticsConstants.BUILD_LABEL, game.PlaceVersion)
local tracker = AnalyticsContextTracker.new()

local sender: AnalyticsTypes.Sender? = nil
local partyResolver: ((Player) -> number)? = nil

local AnalyticsSessionSystem = {}

AnalyticsSessionSystem.tracker = tracker

--[=[
	Sets how a player's party size is found (the Shift place hands in its crew size). Nil goes back to 1.
]=]
function AnalyticsSessionSystem.setParty(resolver: ((Player) -> number)?)
	partyResolver = resolver
end

function AnalyticsSessionSystem.partyOf(player: Player): number
	local resolver = partyResolver
	if resolver == nil then
		return 1
	end
	return resolver(player)
end

--[=[
	Sets the player's cohort from the saved first-seen time (24 h window, so a first session that spans the hub and
	the Shift place reads "new" on both). A no-op while the stamp is not loaded yet: the cohort stays "unk".
]=]
local function refreshCohort(userId: number)
	local firstSeen = AnalyticsFirstSeenSystem.firstSeenAt(userId)
	if firstSeen ~= nil then
		tracker:setCohort(userId, AnalyticsContextUtils.cohort(firstSeen, os.time()))
	end
end

function AnalyticsSessionSystem.build(): string
	return build
end

--[=[
	The player's context: the variant tags of `experimentIds` (a crew experiment reads "-" on a hub server, which is
	not a crew), platform, party, cohort and build.
]=]
function AnalyticsSessionSystem.contextOf(
	player: Player,
	experimentIds: { string },
	party: number
): AnalyticsTypes.Context
	-- Signal order against the first-seen stamp is not guaranteed, so a still-unknown cohort is retried here.
	if tracker:cohortOf(player.UserId) == "unk" then
		refreshCohort(player.UserId)
	end
	local isCrew = QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)
	local variants: { string } = {}
	for _, id in experimentIds do
		local definition = ExperimentRegistry.get(id)
		if definition ~= nil and definition.unit == "crew" and not isCrew then
			table.insert(variants, "-")
		else
			table.insert(variants, ExperimentServiceServer:variantOf(player, id))
		end
	end
	return {
		tags = AnalyticsContextUtils.tags(variants),
		platform = tracker:platformOf(player.UserId),
		party = party,
		cohort = tracker:cohortOf(player.UserId),
		build = build,
	}
end

--[=[
	The packed `tags|platform|party|cohort|build` field for the player.
]=]
function AnalyticsSessionSystem.field(player: Player, experimentIds: { string }, party: number): string
	return AnalyticsContextUtils.field(AnalyticsSessionSystem.contextOf(player, experimentIds, party))
end

--[=[
	Logs funnel step `stepName` once per player per session, with the fields `{player tags}|{cohort}|{build}`, the
	detail ("-" when none) and `{platform}|{party}|{crew tags}`. False for an unknown step, a repeat, or before `start`.
]=]
function AnalyticsSessionSystem.funnelStep(player: Player, stepName: string, detail: string?): boolean
	local out = sender
	if out == nil then
		return false
	end
	local number = AnalyticsConstants.stepNumber(stepName)
	if number == nil or not tracker:markStep(player.UserId, number) then
		return false
	end
	local context = AnalyticsSessionSystem.contextOf(
		player,
		AnalyticsConstants.FUNNEL_EXPERIMENTS,
		AnalyticsSessionSystem.partyOf(player)
	)
	-- The crew experiments (a hub reads "-") ride in the tail, not field 1, which must match on every step.
	local crew = AnalyticsSessionSystem.contextOf(player, AnalyticsConstants.FUNNEL_CREW_EXPERIMENTS, context.party)
	-- Field 1 is stable across steps (so the funnel can be segmented); what changes per step rides in 2 and 3.
	out.funnel(player, number, stepName, {
		AnalyticsContextUtils.funnelField(context.tags, context.cohort, AnalyticsConstants.BUILD_LABEL),
		detail or "-",
		AnalyticsContextUtils.funnelTail(context.platform, context.party, crew.tags),
	})
	return true
end

-- The platform report: rate-limited, parsed from the fixed enum, first valid report wins.
local onPlatform = RequestHandler.wrap({
	name = "AnalyticsPlatform",
	rateLimit = { maxRequests = 3, windowSeconds = 10 },
	-- Count, don't warn: the default warn line carries the sender's UserId, and no analytics path logs one.
	onReject = "count",
	validate = function(data: number, _player: Player): (boolean, string?, ShiftTypes.Platform?)
		local platform: ShiftTypes.Platform? = ShiftPlatformRules.parse(data)
		if platform == nil then
			return false, "unknown platform", nil
		end
		return true, nil, platform
	end,
	handler = function(_data: number, player: Player, platform: ShiftTypes.Platform?)
		if platform ~= nil and tracker:setPlatform(player.UserId, platform) then
			log:debug(`platform {platform} reported`)
		end
	end,
})

local function logAssignments(out: AnalyticsTypes.Sender, player: Player)
	local includeCrew = QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)
	for _, assignment in ExperimentServiceServer:assignments(player, includeCrew) do
		out.custom(player, AnalyticsConstants.ASSIGNMENT_EVENT, nil, {
			assignment.experimentId,
			assignment.variant,
			`{assignment.unit}:{assignment.source}`,
		})
	end
end

--[=[
	Starts platform intake, the assignment log and the hub funnel triggers. Returns the stopper.
]=]
function AnalyticsSessionSystem.start(out: AnalyticsTypes.Sender): () -> ()
	sender = out
	local stopPlatform = ShiftEvents.packets.Platform.listen(function(data: number, player: Player?)
		if player then
			onPlatform(data, player)
		end
	end)
	local function onProfileLoaded(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return
		end
		refreshCohort(userId)
		if tracker:markAssigned(userId) then
			logAssignments(out, player)
		end
		if QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
			AnalyticsSessionSystem.funnelStep(player, "joined_hub")
		end
	end
	local loaded = PlayerDataServiceServer.profileLoaded:Connect(onProfileLoaded)
	-- Players whose profile loaded before this started (the tracker and the funnel dedupe repeats).
	for _, player in Players:GetPlayers() do
		if PlayerDataServiceServer:getProfile(player.UserId) ~= nil then
			onProfileLoaded(player.UserId)
		end
	end
	local departing = QueueServiceServer.departing:Connect(function(_pad: BasePart, party: { Player })
		for _, member in party do
			AnalyticsSessionSystem.funnelStep(member, "boarded_truck")
		end
	end)
	local returned = QueueServiceServer.returned:Connect(function(player: Player)
		AnalyticsSessionSystem.funnelStep(player, "next_shift", "hub")
	end)
	local removing = Players.PlayerRemoving:Connect(function(player: Player)
		-- Deferred so every other PlayerRemoving handler (the shift's "left" events) still reads this player's context.
		local userId = player.UserId
		task.defer(function()
			tracker:forget(userId)
		end)
	end)
	return function()
		stopPlatform()
		loaded:Disconnect()
		departing:Disconnect()
		returned:Disconnect()
		removing:Disconnect()
		sender = nil
	end
end

return AnalyticsSessionSystem
