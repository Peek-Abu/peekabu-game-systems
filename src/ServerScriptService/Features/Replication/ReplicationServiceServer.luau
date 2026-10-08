--!strict
--[=[
	ReplicationServiceServer: the server side of client-only bodies (spec 2026-09-22 §5.1 option A,
	§6; plan R2 Task 9).

	There is no engine character: `Players.CharacterAutoLoads` is false (default.project.json) and any
	character that appears anyway is destroyed and logged. Per player the server holds a replication slot,
	a body epoch, the validated newest sample, server-owned health, and a streaming focus part inside a
	server-side Camera (a Camera's descendants never replicate, so the focus leaks no position — spike CP2).

	Lifecycle: join → slot claimed, slot entry broadcast → the client's `Ready` → `Session`, the slot table,
	and the first spawn. A spawn bumps the epoch (≥ 250 ms apart), picks the spawn point, pre-streams it,
	then sends `Spawn` to the owner, who builds its rig. `respawn` (slot switch, fall plane) does the same.

	Every Heartbeat `ReplicationFanoutSystem.step` relays bodies to viewers. The uplink runs through
	`ReplicationUplinkReceiver` (RequestHandler: decode once, send-time bucket, counted rejects).

	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, epoch),
	`observeBodies`, `hasBody`, `getBodyPosition`, `respawn`, `setMaxHealth`. No system reads
	`player.Character` for a body.

	Timed body state (R3): `defineBodyState(kind, senders)` returns a typed channel (`set` / `clear` / `get`)
	carried by ReplicationBodyStateSender: Started to the owner and observers, Stopped on an early stop, a replay after
	every `Enter`, silent clearing on respawn / slot switch / leave. Relevance helpers for later effects:
	`observersOf`, `observersNear`, `sendToObservers`; `nowMs` is the session clock states are stamped with.

	Spec-exempt shell (Players, ByteNet, Instances); the logic lives in the specced cores beside it.

	@class ReplicationServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ReplicationServer = ServerScriptService.Features.Replication
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ReplicationEvents = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationEvents)
local ReplicationFallRules = require(ReplicatedStorage.Shared.Features.Replication.Rules.ReplicationFallRules)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local ReplicationUplinkRules = require(ReplicationServer.Rules.ReplicationUplinkRules)
local ReplicationUplinkReceiver = require(ReplicationServer.Net.ReplicationUplinkReceiver)
local ReplicationSlotTracker = require(ReplicationServer.State.ReplicationSlotTracker)
local ReplicationFanoutSystem = require(ReplicationServer.Systems.ReplicationFanoutSystem)
local ReplicationInstanceSystem = require(ReplicationServer.Systems.ReplicationInstanceSystem)
local ReplicationReceiver = require(ReplicationServer.Net.ReplicationReceiver)
local ReplicationSlotSender = require(ReplicationServer.Net.ReplicationSlotSender)
local ReplicationBodyObserverSystem = require(ReplicationServer.Systems.ReplicationBodyObserverSystem)
local ReplicationBodyStateSender = require(ReplicationServer.Net.ReplicationBodyStateSender)
local ReplicationObserverUtils = require(ReplicationServer.Utils.ReplicationObserverUtils)

type Body = ReplicationFanoutSystem.Body

local log = Logger.new("ReplicationServiceServer")

local STREAM_TIMEOUT_SECONDS = 5

local janitor = Janitor.new()
local world = ReplicationFanoutSystem.newWorld()
local slots = ReplicationSlotTracker.new()
local bodiesByUserId: { [number]: Body } = {}
-- Lookups are read into `Player?` / `Part?` locals: an indexer read is typed non-optional, and Luau refuses
-- to compare an Instance type with nil.
local playersByUserId: { [number]: Player } = {}
local focusParts: { [number]: Part } = {}
local focusHolder: Camera? = nil
-- Each owner's current run of refused respawn requests; cleared by an accepted sample, a spawn or a leave.
local fallRuns = ReplicationFallRules.newRuns()
-- Set when the place has no rig: the service stays inert (no packets, no bodies) instead of failing the boot.
local inert = false
local sessionEpochSeconds = 0
local stats = { frames = 0, fanoutSeconds = 0, batches = 0, bytes = 0 }

local bodySpawned: SignalTyped.Signal<Player, number> = SignalTyped.new()
local bodyDespawned: SignalTyped.Signal<Player, number> = SignalTyped.new()

local function sessionNowMs(): number
	return math.floor((Workspace:GetServerTimeNow() - sessionEpochSeconds) * 1000)
end

local relay = ReplicationBodyStateSender.new(bodiesByUserId, playersByUserId, sessionNowMs)

-- The epoch spacing (250 ms) needs a clock that never steps back; GetServerTimeNow can be corrected.
local function monotonicMs(): number
	return math.floor(os.clock() * 1000)
end

-- Every ready viewer learns which body holds `body`'s slot (ReplicationSlotSender).
local function broadcastSlot(body: Body, active: boolean)
	ReplicationSlotSender.broadcast(ReplicationEvents.packets.SlotEntry, body, active, bodiesByUserId, playersByUserId)
end

local function publishVitals(body: Body)
	StateSyncPublicPlayerStore.set(body.userId, { health = body.health, maxHealth = body.maxHealth })
end

local function publishRelevant(body: Body)
	local userIds: { number } = {}
	for userId in body.relevant do
		table.insert(userIds, userId)
	end
	StateSyncPublicPlayerStore.setRelevant(body.userId, userIds)
end

local function moveFocus(body: Body, position: Vector3)
	local focus: Part? = focusParts[body.userId]
	if focus ~= nil then
		focus.Position = position
	end
end

local function spawnBody(player: Player, body: Body, reason: string): boolean
	local wasAlive = body.alive
	local previousEpoch = body.epoch.value
	if not ReplicationSlotTracker.bumpEpoch(body.epoch, monotonicMs()) then
		log:debug(`spawn for {player.Name} ({reason}) ignored: the body is under 250 ms old`)
		return false
	end
	ReplicationFallRules.clear(fallRuns, player.UserId)
	if wasAlive then
		bodyDespawned:Fire(player, previousEpoch)
	end
	ReplicationBodyStateSender.clearBody(relay, body.userId) -- receivers drop them on the new epoch
	local position = ReplicationInstanceSystem.spawnPoint()
	body.position = position
	ReplicationFanoutSystem.respawned(body)
	moveFocus(body, position)
	publishVitals(body)
	broadcastSlot(body, true)
	local epoch = body.epoch.value
	task.spawn(function()
		if Workspace.StreamingEnabled then
			local ok, err = pcall(function()
				player:RequestStreamAroundAsync(position, STREAM_TIMEOUT_SECONDS)
			end)
			if not ok then
				log:warn(`RequestStreamAroundAsync failed for {player.Name}: {err}`)
			end
		end
		if bodiesByUserId[body.userId] == body and body.epoch.value == epoch and player.Parent ~= nil then
			ReplicationEvents.packets.Spawn.sendTo({ position = position, epoch = epoch }, player)
		end
	end)
	log:info(`spawn {player.Name} epoch {epoch} ({reason})`)
	bodySpawned:Fire(player, epoch)
	return true
end

local hooks: ReplicationFanoutSystem.Hooks = {
	send = function(viewer: Body, batch: buffer)
		local player: Player? = playersByUserId[viewer.userId]
		if player ~= nil then
			ReplicationEvents.packets.Downlink.sendTo(batch, player)
			stats.batches += 1
			stats.bytes += buffer.len(batch)
		end
	end,
	-- Hooks run mid-iteration inside ReplicationFanoutSystem.step / removeBody: they send packets and update the
	-- viewer's own relevant set, but never add or remove bodies (no removeBody, no spawn) - defer such work.
	visibility = function(viewer: Body, subject: Body, entered: boolean)
		local player: Player? = playersByUserId[viewer.userId]
		if entered then
			viewer.relevant[subject.userId] = true
			if player ~= nil then
				ReplicationEvents.packets.Enter.sendTo(
					ReplicationFanoutSystem.enterPayload(subject, sessionNowMs()),
					player
				)
				ReplicationBodyStateSender.replayTo(relay, subject.userId, player) -- after Enter on the one reliable channel
			end
		else
			viewer.relevant[subject.userId] = nil
			if player ~= nil then
				ReplicationEvents.packets.Leave.sendTo({ slot = subject.slot, generation = subject.generation }, player)
			end
		end
		publishRelevant(viewer)
	end,
}

local function onReady(player: Player)
	local body = bodiesByUserId[player.UserId]
	if body == nil then
		return
	end
	if body.ready then
		-- A repeated handshake: the client lost its view; start its stream over.
		ReplicationFanoutSystem.resetViewer(body)
		publishRelevant(body)
	end
	body.ready = true
	ReplicationEvents.packets.Session.sendTo({ epochSeconds = sessionEpochSeconds }, player)
	for _, other in bodiesByUserId do
		ReplicationEvents.packets.SlotEntry.sendTo(ReplicationSlotSender.entryOf(other, true), player)
	end
	ReplicationBodyStateSender.replayTo(relay, player.UserId, player) -- a repeated handshake: the owner's own states
	if not body.alive then
		spawnBody(player, body, "join")
	end
end

-- A fall-plane respawn is honoured near the plane (the owner's last accepted samples were falling), or once
-- refused requests have kept coming for ReplicationFallRules.STRANDED_MS with no accepted sample between them.
local function onRespawnRequest(player: Player)
	local userId = player.UserId
	local body = bodiesByUserId[userId]
	if body == nil or not body.alive then
		return
	end
	local verdict = ReplicationFallRules.answer(
		fallRuns,
		userId,
		body.position.Y,
		Workspace.FallenPartsDestroyHeight,
		monotonicMs()
	)
	if verdict == "refuse" then
		log:debug(`respawn request from {player.Name} refused: last accepted Y {body.position.Y}`)
		return
	end
	if verdict == "stranded" then
		log:warn(`{player.Name} has no rig but was last seen at Y {body.position.Y}; respawning at a spawn point`)
	end
	spawnBody(player, body, verdict)
end

local function onPlayer(player: Player): (() -> ())?
	local holder = focusHolder
	if holder == nil then
		return nil -- the service is stopped
	end
	local userId = player.UserId
	local slot = ReplicationSlotTracker.claim(slots)
	if slot == nil then
		log:error(`no replication slot left for {player.Name}; they get no body`)
		return nil
	end
	local generation = ReplicationSlotTracker.generationOf(slots, slot)
	local body = ReplicationFanoutSystem.newBody(userId, slot, generation, ReplicationInstanceSystem.spawnPoint())
	ReplicationFanoutSystem.addBody(world, body)
	bodiesByUserId[userId] = body
	playersByUserId[userId] = player

	local focus = ReplicationInstanceSystem.createFocus(holder, body.position)
	player.ReplicationFocus = focus
	focusParts[userId] = focus

	publishVitals(body)
	publishRelevant(body)
	broadcastSlot(body, true)

	local characterConnection = player.CharacterAdded:Connect(function(character: Model)
		log:warn(`an engine character appeared for {player.Name}; destroying it (bodies are client-only)`)
		character:Destroy()
	end)

	return function()
		characterConnection:Disconnect()
		ReplicationFallRules.clear(fallRuns, userId)
		if body.alive then
			bodyDespawned:Fire(player, body.epoch.value)
		end
		body.alive = false
		-- removeBody sends a leave to every viewer that had the body loaded (which drops it from their
		-- relevant set); the sweep below catches any viewer still listing it, so no viewer keeps a
		-- subscription to the atom `StateSyncPublicPlayerStore.remove` is about to drop.
		ReplicationFanoutSystem.removeBody(world, slot, hooks)
		for otherId, other in bodiesByUserId do
			if otherId ~= userId and other.relevant[userId] then
				other.relevant[userId] = nil
				publishRelevant(other)
			end
		end
		-- A same-account rejoin can interleave with this cleanup: only clear what is still this body's.
		if bodiesByUserId[userId] == body then
			ReplicationBodyStateSender.clearBody(relay, userId)
			bodiesByUserId[userId] = nil
			playersByUserId[userId] = nil
			focusParts[userId] = nil
			StateSyncPublicPlayerStore.remove(userId)
		end
		ReplicationSlotTracker.release(slots, slot)
		broadcastSlot(body, false)
		focus:Destroy()
	end
end

local function step()
	local started = os.clock()
	ReplicationFanoutSystem.step(world, sessionNowMs(), hooks)
	stats.frames += 1
	stats.fanoutSeconds += os.clock() - started
end

export type ReplicationServiceServer = {
	dependencies: { string },
	init: (self: ReplicationServiceServer) -> (),
	start: (self: ReplicationServiceServer) -> (),
	stop: (self: ReplicationServiceServer) -> (),
	bodySpawned: SignalTyped.Signal<Player, number>,
	bodyDespawned: SignalTyped.Signal<Player, number>,
	observeBodies: (
		self: ReplicationServiceServer,
		callback: (player: Player, epoch: number) -> (() -> ())?
	) -> () -> (),
	hasBody: (self: ReplicationServiceServer, player: Player) -> boolean,
	getBodyPosition: (self: ReplicationServiceServer, player: Player) -> Vector3?,
	respawn: (self: ReplicationServiceServer, player: Player, reason: string) -> boolean,
	setMaxHealth: (self: ReplicationServiceServer, userId: number, maxHealth: number) -> (),
	defineBodyState: <D>(
		self: ReplicationServiceServer,
		kind: string,
		senders: ReplicationBodyStateSender.Senders<D>
	) -> ReplicationBodyStateSender.Channel<D>,
	observersOf: (self: ReplicationServiceServer, player: Player) -> { Player },
	observersNear: (self: ReplicationServiceServer, position: Vector3, radius: number) -> { Player },
	sendToObservers: <T>(
		self: ReplicationServiceServer,
		player: Player,
		packet: ReplicationObserverUtils.Sendable<T>,
		data: T
	) -> number,
	nowMs: (self: ReplicationServiceServer) -> number,
	getState: (self: ReplicationServiceServer) -> { [string]: any },
}

local ReplicationServiceServer: ReplicationServiceServer = {
	dependencies = {},
	bodySpawned = bodySpawned,
	bodyDespawned = bodyDespawned,

	--[=[
		Turns engine characters off (loudly, if the place lacks the project's Players node), publishes the rig
		template, creates the focus container, and wires the packets. A place without the rig logs an error and leaves
		the service inert (init returns normally; start and the body API are no-ops).
	]=]
	init = function(_self)
		if Players.CharacterAutoLoads then
			log:error(
				"Players.CharacterAutoLoads was true: the default.project.json Players node is not applied; turning it off"
			)
			Players.CharacterAutoLoads = false
		end
		sessionEpochSeconds = math.floor(Workspace:GetServerTimeNow())

		local template = ReplicationInstanceSystem.publishRigTemplate()
		if template == nil then
			inert = true
			log:error(
				"StarterPlayer.StarterCharacter (the rig) is missing from this place: character replication is inert (no bodies)"
			)
			return
		end
		inert = false
		janitor:Add(template, "Destroy")
		local folder, holder = ReplicationInstanceSystem.createFocusHolder()
		focusHolder = holder
		janitor:Add(folder, "Destroy")

		ReplicationReceiver.connect({
			uplink = ReplicationUplinkReceiver.wrap(
				function(player: Player): ReplicationUplinkRules.State?
					local body = bodiesByUserId[player.UserId]
					return if body ~= nil and body.alive then body.ingest else nil
				end,
				sessionNowMs,
				function(player: Player, state: ReplicationUplinkRules.State)
					local body = bodiesByUserId[player.UserId]
					local latest = state.latest
					if body ~= nil and latest ~= nil then
						ReplicationFallRules.clear(fallRuns, player.UserId)
						body.position = latest.position
						moveFocus(body, latest.position)
					end
				end
			),
			ready = onReady,
			respawnRequest = onRespawnRequest,
		})
	end,

	--[=[
		Starts tracking players and the per-frame fan-out.
	]=]
	start = function(_self)
		if inert then
			return
		end
		janitor:Add(Observers.observePlayer(onPlayer), true)
		janitor:Add(RunService.Heartbeat:Connect(step), "Disconnect")
		log:debug("ReplicationServiceServer started")
	end,

	stop = function(_self)
		janitor:Cleanup()
		ReplicationReceiver.disconnect()
		focusHolder = nil
	end,

	--[=[
		Runs `callback(player, epoch)` for every live body now and for every body that spawns later. The
		cleanup it returns runs when that body despawns (or the observer is disconnected). The returned
		function disconnects the observer.
	]=]
	observeBodies = function(_self, callback)
		return ReplicationBodyObserverSystem.observe(
			bodySpawned,
			bodyDespawned,
			function(): { ReplicationBodyObserverSystem.LiveBody }
				local live: { ReplicationBodyObserverSystem.LiveBody } = {}
				for userId, body in bodiesByUserId do
					local player: Player? = playersByUserId[userId]
					if body.alive and player ~= nil then
						table.insert(live, { player = player, epoch = body.epoch.value })
					end
				end
				return live
			end,
			callback
		)
	end,

	hasBody = function(_self, player)
		local body = bodiesByUserId[player.UserId]
		return body ~= nil and body.alive
	end,

	getBodyPosition = function(_self, player)
		local body = bodiesByUserId[player.UserId]
		return if body ~= nil and body.alive then body.position else nil
	end,

	--[=[
		Respawns a live body (new epoch, server-chosen spawn, the owner rebuilds). Does not yield. False when
		the player has no live body yet (their first spawn happens at their handshake) or the previous spawn
		is under 250 ms old.
	]=]
	respawn = function(_self, player, reason)
		local body = bodiesByUserId[player.UserId]
		if body == nil or not body.alive then
			return false
		end
		return spawnBody(player, body, reason)
	end,

	--[=[
		The body's maximum health (StatServiceServer pushes the derived value). A full body stays full;
		a damaged one keeps its health (clamped down); the public entry follows.
	]=]
	setMaxHealth = function(_self, userId, maxHealth)
		local body = bodiesByUserId[userId]
		if body ~= nil and ReplicationFanoutSystem.setMaxHealth(body, maxHealth) then
			publishVitals(body)
		end
	end,

	--[=[
		Define a timed body-state kind once (at a consumer's start): returns its typed channel. Kinds bring
		their own typed reliable packets through `senders`; this service decides who receives them and when.
	]=]
	defineBodyState = function(_self, kind, senders)
		return ReplicationBodyStateSender.define(relay, kind, senders)
	end,

	-- The ready viewers that have this player's body loaded (never the player).
	observersOf = function(_self, player)
		return ReplicationObserverUtils.observersOf(bodiesByUserId, playersByUserId, player.UserId)
	end,

	-- The ready players with a live body within `radius` studs of `position`.
	observersNear = function(_self, position, radius)
		return ReplicationObserverUtils.observersNear(bodiesByUserId, playersByUserId, position, radius)
	end,

	-- Send `data` to everyone who sees this player's body: its observers plus the player. Returns the count.
	sendToObservers = function(_self, player, packet, data)
		return ReplicationObserverUtils.sendToObservers(bodiesByUserId, playersByUserId, player, packet, data)
	end,

	nowMs = function(_self)
		return sessionNowMs()
	end,

	getState = function(_self)
		local ingest: { [string]: ReplicationUplinkRules.Counters } = {}
		local bodies = 0
		for userId, body in bodiesByUserId do
			bodies += 1
			local player: Player? = playersByUserId[userId]
			local counters = table.clone(body.ingest.counters)
			counters.maxAcceptedAgeMs = ReplicationUplinkRules.maxAcceptedAgeMs(body.ingest)
			ingest[if player ~= nil then player.Name else tostring(userId)] = counters
		end
		return {
			bodies = bodies,
			slotsUsed = ReplicationSlotTracker.count(slots),
			fanoutMsAvg = if stats.frames > 0 then stats.fanoutSeconds / stats.frames * 1000 else 0,
			downlinkBatches = stats.batches,
			downlinkBytes = stats.bytes,
			ingest = ingest,
			bodyStates = ReplicationBodyStateSender.stats(relay),
		}
	end,
}

return ReplicationServiceServer
