--!strict
--[=[
	RoundServiceServer: the server's match lifecycle — lobby, countdown, run, results — and the run-only
	state games read and write during a run (design: docs/superpowers/specs/2026-10-09-round-design.md).

	The phase machine is the pure RoundPhaseRules, stepped every RoundConstants.TICK_INTERVAL; the run state
	is RoundRunTracker. Every change republishes the snapshot as the `round` StateSync world entry (coalesced
	to once per frame), so every client sees the round through the charm-sync spine.

	Nothing here is saved. A game pays out at the end from its `runEnded` / `results` handler through the
	persistent services (Currency, Inventory), which keeps the data layer's guarantees.

	Spec-exempt shell (Players, RunService, signals); the rules are the specced RoundPhaseRules,
	RoundRunTracker and RoundContainerUtils.

	@class RoundServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundServer = ServerScriptService.Features.Round
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local RoundPhaseRules = require(RoundServer.Rules.RoundPhaseRules)
local RoundContainerUtils = require(RoundServer.Utils.RoundContainerUtils)
local RoundRunTracker = require(RoundServer.State.RoundRunTracker)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

type RoundState = RoundTypes.RoundState
type RoundConfig = RoundTypes.RoundConfig
type InventoryEntry = PlayerDataTypes.InventoryEntry

local log = Logger.new("RoundServiceServer")

local phaseChanged: SignalTyped.Signal<RoundState> = SignalTyped.new()
local runStarted: SignalTyped.Signal<{ Player }> = SignalTyped.new()
local runEnded: SignalTyped.Signal<string> = SignalTyped.new()

local config: RoundConfig = table.clone(RoundConstants.DEFAULT_CONFIG)
local state: RoundState = RoundPhaseRules.initial()
local tracker = RoundRunTracker.new()
local publishScheduled = false
local accumulated = 0
local connections: { RBXScriptConnection } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	if publishScheduled then
		return
	end
	publishScheduled = true
	task.defer(function()
		publishScheduled = false
		StateSyncWorldStore.set(RoundConstants.WORLD_ENTRY, tracker:snapshot(state))
	end)
end

local function isEligible(player: Player): boolean
	local eligible = config.eligible
	if eligible == nil then
		return true
	end
	local ok, result = pcall(function()
		return eligible(player)
	end)
	if not ok then
		log:error(`eligible({player.Name}) errored: {result}`)
		return false
	end
	return result == true
end

local function participantPlayers(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if tracker:isParticipant(player.UserId) then
			table.insert(list, player)
		end
	end
	return list
end

-- Moves the machine to `nextState` and runs the transition's side effects.
local function apply(nextState: RoundState)
	local previous = state
	state = nextState
	local entered = nextState.phase ~= previous.phase
	if entered and nextState.phase == "running" then
		local ids: { number } = {}
		for _, player in Players:GetPlayers() do
			if isEligible(player) then
				table.insert(ids, player.UserId)
			end
		end
		tracker:reset(ids, nextState.round)
		runStarted:Fire(participantPlayers())
	end
	if entered and nextState.phase == "results" then
		runEnded:Fire(nextState.outcome or RoundConstants.OUTCOME_CANCELLED)
	end
	-- Back in the lobby: the finished run's state has been shown; clear it.
	if entered and nextState.phase == "lobby" then
		tracker:reset({}, nextState.round)
	end
	log:debug(`phase {previous.phase} -> {nextState.phase} (round {nextState.round})`)
	publish()
	phaseChanged:Fire(table.clone(nextState))
end

local function step()
	local nextState = RoundPhaseRules.tick(state, config, tracker:counts(#Players:GetPlayers()), now())
	if nextState ~= nil then
		apply(nextState)
	end
end

local function containerItems(name: string): { InventoryEntry }
	return tracker:container(name)
end

export type RoundServiceServer = {
	dependencies: { string },
	phaseChanged: SignalTyped.Signal<RoundState>,
	runStarted: SignalTyped.Signal<{ Player }>,
	runEnded: SignalTyped.Signal<string>,

	start: (self: RoundServiceServer) -> (),
	stop: (self: RoundServiceServer) -> (),
	getState: (self: RoundServiceServer) -> { [string]: any },

	configure: (self: RoundServiceServer, update: RoundTypes.RoundConfigUpdate) -> (),
	getConfig: (self: RoundServiceServer) -> RoundConfig,
	getPhase: (self: RoundServiceServer) -> RoundState,
	startCountdown: (self: RoundServiceServer) -> boolean,
	startNow: (self: RoundServiceServer) -> boolean,
	endRound: (self: RoundServiceServer, outcome: string) -> boolean,

	isParticipant: (self: RoundServiceServer, player: Player) -> boolean,
	participants: (self: RoundServiceServer) -> { Player },
	eliminate: (self: RoundServiceServer, player: Player) -> boolean,
	revive: (self: RoundServiceServer, player: Player) -> boolean,
	isEliminated: (self: RoundServiceServer, player: Player) -> boolean,

	addTeam: (self: RoundServiceServer, counter: string, amount: number) -> number,
	spendTeam: (self: RoundServiceServer, counter: string, amount: number) -> boolean,
	teamValue: (self: RoundServiceServer, counter: string) -> number,
	setTarget: (self: RoundServiceServer, counter: string, target: number?) -> (),
	targetMet: (self: RoundServiceServer, counter: string) -> boolean,
	addScore: (self: RoundServiceServer, player: Player, counter: string, amount: number) -> number,
	scoreOf: (self: RoundServiceServer, player: Player, counter: string) -> number,

	bagName: (self: RoundServiceServer, player: Player) -> string,
	addToContainer: (
		self: RoundServiceServer,
		name: string,
		itemType: string,
		count: number?,
		attrs: { [string]: PlayerDataTypes.AttrValue }?
	) -> (boolean, string?),
	removeFromContainer: (
		self: RoundServiceServer,
		name: string,
		itemType: string,
		count: number?
	) -> (boolean, string?),
	removeUniqueFromContainer: (self: RoundServiceServer, name: string, uid: string) -> boolean,
	containerOf: (self: RoundServiceServer, name: string) -> { InventoryEntry },
}

local RoundServiceServer: RoundServiceServer = {
	dependencies = { "StateSyncServiceServer" },
	phaseChanged = phaseChanged,
	runStarted = runStarted,
	runEnded = runEnded,

	--[=[
		Publishes the lobby, follows players joining (late join) and leaving, and starts the clock.
	]=]
	start = function(_self)
		publish()
		table.insert(
			connections,
			Players.PlayerAdded:Connect(function(player)
				if state.phase == "running" and config.lateJoin and isEligible(player) then
					tracker:addParticipant(player.UserId)
					publish()
				end
			end)
		)
		table.insert(
			connections,
			Players.PlayerRemoving:Connect(function(player)
				if tracker:isParticipant(player.UserId) then
					tracker:removeParticipant(player.UserId)
					publish()
				end
			end)
		)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(deltaTime)
				accumulated += deltaTime
				if accumulated >= RoundConstants.TICK_INTERVAL then
					accumulated = 0
					step()
				end
			end)
		)
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		StateSyncWorldStore.clear(RoundConstants.WORLD_ENTRY)
	end,

	--[=[
		Changes the configuration (only the fields given). Asserts the result is valid. Takes effect from the
		next step; a running timer keeps the end time it started with.
	]=]
	configure = function(_self, update)
		local nextConfig = table.clone(config)
		for key, value in update do
			nextConfig[key] = value
		end
		local ok, reason = RoundPhaseRules.validateConfig(nextConfig)
		assert(ok, `RoundServiceServer:configure: {reason}`)
		config = nextConfig
	end,

	getConfig = function(_self)
		return table.clone(config)
	end,

	getPhase = function(_self)
		return table.clone(state)
	end,

	--[=[
		Starts the countdown from the lobby (for autoStart = false). False outside the lobby or below
		minPlayers.
	]=]
	startCountdown = function(_self)
		local nextState = RoundPhaseRules.startCountdown(state, config, tracker:counts(#Players:GetPlayers()), now())
		if nextState == nil then
			return false
		end
		apply(nextState)
		return true
	end,

	--[=[
		Starts the run now, skipping the countdown. False while running or showing results.
	]=]
	startNow = function(_self)
		local nextState = RoundPhaseRules.startNow(state, config, now())
		if nextState == nil then
			return false
		end
		apply(nextState)
		return true
	end,

	--[=[
		Ends the run with `outcome` ("quota", "survived", any string). False when no run is going.
	]=]
	endRound = function(_self, outcome)
		local nextState = RoundPhaseRules.finish(state, config, now(), outcome)
		if nextState == nil then
			return false
		end
		apply(nextState)
		return true
	end,

	isParticipant = function(_self, player)
		return tracker:isParticipant(player.UserId)
	end,

	participants = function(_self)
		return participantPlayers()
	end,

	--[=[
		Marks a participant as out of the run (dead, caught). When nobody is left alive the run ends
		"wiped" on the next step. False when they are not a live participant.
	]=]
	eliminate = function(_self, player)
		local changed = tracker:eliminate(player.UserId)
		if changed then
			publish()
		end
		return changed
	end,

	revive = function(_self, player)
		local changed = tracker:revive(player.UserId)
		if changed then
			publish()
		end
		return changed
	end,

	isEliminated = function(_self, player)
		return tracker:isEliminated(player.UserId)
	end,

	addTeam = function(_self, counter, amount)
		local value = tracker:addTeam(counter, amount)
		publish()
		return value
	end,

	spendTeam = function(_self, counter, amount)
		local ok = tracker:spendTeam(counter, amount)
		if ok then
			publish()
		end
		return ok
	end,

	teamValue = function(_self, counter)
		return tracker:teamValue(counter)
	end,

	setTarget = function(_self, counter, target)
		tracker:setTarget(counter, target)
		publish()
	end,

	targetMet = function(_self, counter)
		return tracker:targetMet(counter)
	end,

	addScore = function(_self, player, counter, amount)
		local value = tracker:addScore(player.UserId, counter, amount)
		publish()
		return value
	end,

	scoreOf = function(_self, player, counter)
		return tracker:scoreOf(player.UserId, counter)
	end,

	--[=[
		The container name of a player's own run bag.
	]=]
	bagName = function(_self, player)
		return tostring(player.UserId)
	end,

	--[=[
		Adds to a run container ("team", or a `bagName`). A stackable item adds `count` (default 1); a
		unique item adds one entry with a run-local uid and optional attrs (count must be 1 or nil).
	]=]
	addToContainer = function(_self, name, itemType, count, attrs)
		local items = containerItems(name)
		local ok, reason
		if ItemRegistry.isStackable(itemType) then
			if attrs ~= nil then
				return false, "a stackable item cannot carry attrs"
			end
			ok, reason = RoundContainerUtils.addStack(items, itemType, count or 1, config.containerCapacity)
		else
			if count ~= nil and count ~= 1 then
				return false, "a unique item is added one at a time"
			end
			ok, reason =
				RoundContainerUtils.addUnique(items, itemType, tracker:nextUid(), attrs, config.containerCapacity)
		end
		if ok then
			publish()
		end
		return ok, reason
	end,

	--[=[
		Removes `count` (default 1) of a stackable item from a run container.
	]=]
	removeFromContainer = function(_self, name, itemType, count)
		local ok, reason = RoundContainerUtils.removeStack(containerItems(name), itemType, count or 1)
		if ok then
			publish()
		end
		return ok, reason
	end,

	removeUniqueFromContainer = function(_self, name, uid)
		local ok = RoundContainerUtils.removeUnique(containerItems(name), uid)
		if ok then
			publish()
		end
		return ok
	end,

	--[=[
		A copy of a run container's entries.
	]=]
	containerOf = function(_self, name)
		local copy: { InventoryEntry } = {}
		for _, entry in containerItems(name) do
			table.insert(copy, table.clone(entry))
		end
		return copy
	end,

	getState = function(_self)
		return {
			phase = state.phase,
			round = state.round,
			endsAt = state.endsAt,
			outcome = state.outcome,
			counts = tracker:counts(#Players:GetPlayers()),
			minPlayers = config.minPlayers,
			duration = config.duration,
		}
	end,
}

return RoundServiceServer
