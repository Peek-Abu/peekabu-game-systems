--!strict
--[=[
	DebuggerServiceServer: assembles and streams the debug snapshot to subscribed admin overlays.

	This is the server half of the in-game Service & State Debugger (the client half mounts the F4
	overlay). It is the first system to put BOTH provisioned dependencies to real work:
	- **ByteNet** (`DebuggerEvents`) carries the discrete subscribe packet and the snapshot stream.
	- **Promise** isolates each service's `getState()` during assembly: a `getState` that yields or
	  hangs can't stall the snapshot, because its call is wrapped in `Promise.try():timeout()` and a
	  timeout is reported as a per-service `stateError` rather than freezing every panel.

	Refresh model (server-interval subscription, change-gated):
	1. The overlay sends `SetSubscription(true)` on open; the handler (rate-limited + `isAdmin`-gated
	   via RequestHandler) adds the player to `subscribers`.
	2. A single Heartbeat loop, throttled to ~`SNAPSHOT_INTERVAL`, assembles ONE server-global snapshot
	   per tick (the debug data is identical for every viewer) and sends it only to subscribers whose
	   last-sent hash differs — so an idle server streams nothing after the first frame.
	3. `SetSubscription(false)` / leaving drops the player; the loop idles when nobody is subscribed.

	Dependency-free by design (`dependencies = {}`): it boots at topological level 0 so a downstream
	service hanging can never stop the debugger from coming up — you want it MOST when things are
	broken. It only ever READS `ServiceController` (never calls peer service methods), so it is safe at
	every lifecycle phase.

	@class DebuggerServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Admin = require(ReplicatedStorage.Shared.Modules.Admin)
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)
local DebuggerEvents = require(ReplicatedStorage.Shared.Events.DebuggerEvents)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local ServerStore = require(ServerScriptService.State.ServerStore)

local log = Logger.new("DebuggerServiceServer")

type ServiceSnapshot = DebuggerEvents.ServiceSnapshot
type RateLimitSnapshot = DebuggerEvents.RateLimitSnapshot
type AtomSnapshot = DebuggerEvents.AtomSnapshot
type PlayerInfo = DebuggerEvents.PlayerInfo
type Snapshot = DebuggerEvents.Snapshot

-- Tunables. ~4 Hz is smooth enough for a live inspector without flooding the wire; a getState that
-- runs longer than the timeout is reported as errored rather than allowed to stall the frame.
local SNAPSHOT_INTERVAL = 0.25
local GETSTATE_TIMEOUT = 1

-- Module-level state (not part of the service table), mirroring StateSyncServiceServer's convention.
local janitor = Janitor.new()
local subscribers: { [Player]: true } = {}
local sentHash: { [Player]: string } = {} -- last snapshot hash delivered to each subscriber
local assembling = false -- reentrancy guard so a slow assembly can't overlap the next tick
local accumulator = 0 -- Heartbeat time accumulator for interval throttling
local unhashableCounter = 0 -- makes the fallback hash unique per tick when a snapshot can't be encoded

--[=[
	Lists the players currently on the server for the State tab's entity sidebar.
	@return { PlayerInfo } -- One entry per player
]=]
local function collectPlayers(): { PlayerInfo }
	local result: { PlayerInfo } = {}
	for _, player in Players:GetPlayers() do
		table.insert(result, {
			userId = player.UserId,
			name = player.Name,
		})
	end
	return result
end

--[=[
	Collects every player's per-slice state from ServerStore (all players, not just the viewer — this
	is admin introspection). Uses the public `getterFor`, so no ServerStore change is needed.
	@return { AtomSnapshot } -- One entry per (player, slice)
]=]
local function collectAtoms(): { AtomSnapshot }
	local result: { AtomSnapshot } = {}
	for _, player in Players:GetPlayers() do
		for _, slice in SyncState.SLICES do
			local getter = ServerStore.getterFor(slice, player.UserId)
			table.insert(result, {
				slice = slice,
				userId = player.UserId,
				value = getter(),
			})
		end
	end
	return result
end

--[=[
	Collects every tracked rate-limit counter from RequestHandler.
	@return { RateLimitSnapshot } -- One entry per tracked (user, action)
]=]
local function collectRateLimits(): { RateLimitSnapshot }
	local result: { RateLimitSnapshot } = {}
	for _, entry in RequestHandler.getAllRateLimitStatus() do
		table.insert(result, {
			userId = entry.userId,
			action = entry.action,
			requestsInWindow = entry.requestsInWindow,
		})
	end
	return result
end

--[=[
	Builds one promise per registered service that resolves to its ServiceSnapshot. Each service's
	optional `getState()` is wrapped so a throw OR a hang is contained to that one service (reported as
	`stateError`) instead of failing or stalling the whole snapshot.
	@return { any } -- Array of Promises, each resolving to a ServiceSnapshot
]=]
local function assembleServices(): { any }
	local promises: { any } = {}
	for name, entry in ServiceController:getAllServices() do
		local base: ServiceSnapshot = {
			name = name,
			initialized = entry.initialized,
			started = entry.started,
			dependencies = entry.dependencies,
			initDurationMs = entry.initDurationMs,
			startDurationMs = entry.startDurationMs,
			initError = entry.initError,
			startError = entry.startError,
		}

		local getState = entry.module.getState
		if getState then
			local promise = Promise.try(function()
				return getState(entry.module)
			end)
				:timeout(GETSTATE_TIMEOUT)
				:andThen(function(state: { [string]: any })
					base.state = state
					return base
				end)
				:catch(function(err)
					base.stateError = tostring(err)
					return base
				end)
			table.insert(promises, promise)
		else
			table.insert(promises, Promise.resolve(base))
		end
	end
	return promises
end

--[=[
	Assembles the full server-global snapshot. Returns a Promise so the per-service getState isolation
	above stays asynchronous; the synchronous panels (atoms, rate limits, logs) are gathered once all
	service states have settled.
	@return any -- A Promise resolving to a Snapshot
]=]
local function assembleSnapshot(): any
	return Promise.all(assembleServices()):andThen(function(services: { ServiceSnapshot }): Snapshot
		return {
			realm = "server",
			phase = ServiceController:getPhase(),
			clock = os.clock(),
			players = collectPlayers(),
			services = services,
			atoms = collectAtoms(),
			rateLimits = collectRateLimits(),
			logs = Logger.getHistory(),
		}
	end)
end

--[=[
	A cheap change signal for a snapshot. Excludes the volatile top-level `clock` so an otherwise
	identical frame hashes the same (that's what makes change-gating work); per-log-entry clocks stay
	in, so a genuinely new log line still changes the hash. Falls back to a per-tick unique token if
	the snapshot can't be JSON-encoded (e.g. a service exposes a non-encodable value in getState) so we
	simply send every tick rather than crash or wrongly dedupe.
	@param snapshot Snapshot -- The snapshot to fingerprint
	@return string -- A comparable hash
]=]
local function hashOf(snapshot: Snapshot): string
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode({
			phase = snapshot.phase,
			services = snapshot.services,
			atoms = snapshot.atoms,
			rateLimits = snapshot.rateLimits,
			logs = snapshot.logs,
		})
	end)
	if ok then
		return encoded
	end
	unhashableCounter += 1
	return `unhashable:{unhashableCounter}`
end

--[=[
	Re-validates every subscriber's admin status and drops any that no longer pass. The subscribe-time
	gate alone is not enough: `Admin.isAdmin` is explicitly designed to be swappable for a dynamic
	(group-rank / DataStore) lookup, and the snapshot stream carries EVERY player's currency/inventory
	plus server logs — a subscriber whose privilege is revoked mid-session must stop receiving it on
	the next frame, not keep it until they unsubscribe or leave. Runs before each dispatch; with the
	static default allowlist it never prunes, so it is pure future-proofing at ~zero cost.
]=]
local function pruneUnauthorizedSubscribers()
	for player in subscribers do
		if not Admin.isAdmin(player) then
			subscribers[player] = nil
			sentHash[player] = nil
			log:warn("Debugger subscriber is no longer an admin; unsubscribed:", player.Name)
		end
	end
end

--[=[
	Sends a snapshot to every current subscriber whose last delivered hash differs. A newly-subscribed
	player has no prior hash (`nil`), so they always receive the current frame. Subscribers whose
	admin status lapsed since they subscribed are pruned first and receive nothing.
	@param snapshot Snapshot -- The assembled snapshot
]=]
local function dispatch(snapshot: Snapshot)
	pruneUnauthorizedSubscribers()
	local hash = hashOf(snapshot)
	for player in subscribers do
		if sentHash[player] ~= hash then
			DebuggerEvents.packets.Snapshot.sendTo(snapshot, player)
			sentHash[player] = hash
		end
	end
end

--[=[
	The throttled stream driver. Does nothing while nobody is subscribed; otherwise assembles and
	dispatches one snapshot per `SNAPSHOT_INTERVAL`, never overlapping a still-running assembly.
	@param deltaTime number -- Heartbeat delta
]=]
local function onHeartbeat(deltaTime: number)
	if next(subscribers) == nil then
		accumulator = 0
		return
	end

	accumulator += deltaTime
	if accumulator < SNAPSHOT_INTERVAL then
		return
	end
	accumulator = 0

	if assembling then
		return
	end
	assembling = true
	assembleSnapshot()
		:andThen(function(snapshot: Snapshot)
			dispatch(snapshot)
		end)
		:catch(function(err)
			log:error("Snapshot assembly failed:", tostring(err))
		end)
		:finally(function()
			assembling = false
		end)
end

-- The single admin gate for every debugger request (subscription + log clear). The client's local
-- isAdmin check is UX only; this server-side validate is the real, authoritative gate. Named (not
-- inlined per-wrap) so both handlers share one definition and the spec exercises the same function
-- production runs.
local function validateAdmin(_data: boolean, player: Player): (boolean, string?)
	if Admin.isAdmin(player) then
		return true
	end
	return false, "not authorized for debugger"
end

-- The subscribe/unsubscribe handler, gated exactly like an admin command: RequestHandler applies the
-- rate limit + xpcall isolation, and `validate` refuses non-admins.
local onSetSubscription = RequestHandler.wrap({
	name = "DebugSetSubscription",
	rateLimit = { maxRequests = 20, windowSeconds = 10 },
	validate = validateAdmin,
	handler = function(subscribe: boolean, player: Player)
		if subscribe then
			subscribers[player] = true
			sentHash[player] = nil -- force a fresh full snapshot on the next tick
			log:debug("Debugger subscribed:", player.Name)
		else
			subscribers[player] = nil
			sentHash[player] = nil
			log:debug("Debugger unsubscribed:", player.Name)
		end
	end,
})

-- Clears the server log buffer on request (the overlay's Clear button in server context). Same admin
-- gate as subscription. After clearing, force every subscriber's next frame so the emptied buffer
-- replicates immediately.
local onClearServerLogs = RequestHandler.wrap({
	name = "DebugClearServerLogs",
	rateLimit = { maxRequests = 10, windowSeconds = 10 },
	validate = validateAdmin,
	handler = function(_data: boolean, player: Player)
		Logger.clearHistory()
		table.clear(sentHash)
		log:debug("Server logs cleared by:", player.Name)
	end,
})

export type DebuggerServiceServer = {
	dependencies: { string },
	init: (self: DebuggerServiceServer) -> (),
	stop: (self: DebuggerServiceServer) -> (),
	getState: (self: DebuggerServiceServer) -> { [string]: any },

	-- TEST SEAMS — the RequestHandler-wrapped packet handlers above, exposed so specs can drive
	-- the rate-limit + admin-validate + handler pipeline without ByteNet. init() wires the packets
	-- to these same functions. Plain functions taking (data, player), not methods.
	_onSetSubscription: (subscribe: boolean, player: Player) -> any,
	_onClearServerLogs: (data: boolean, player: Player) -> any,
	-- TEST SEAM — the pre-dispatch admin re-check, exposed so specs can drive the revocation path
	-- (subscribe as admin, revoke, prune) without assembling/sending a real snapshot over ByteNet.
	_pruneUnauthorizedSubscribers: () -> (),
}

local DebuggerServiceServer: DebuggerServiceServer = {
	dependencies = {},

	--[=[
		Wires the subscription listener, the Heartbeat stream driver, and per-player cleanup.
		@param self DebuggerServiceServer -- The service instance
	]=]
	init = function(_self)
		-- ByteNet hands us (data, player); player is the sender on the server. Guard it and forward
		-- into RequestHandler's (data, player) contract.
		janitor:Add(
			DebuggerEvents.packets.SetSubscription.listen(function(subscribe: boolean, player: Player?)
				if player then
					onSetSubscription(subscribe, player)
				end
			end),
			true
		)

		janitor:Add(
			DebuggerEvents.packets.ClearServerLogs.listen(function(data: boolean, player: Player?)
				if player then
					onClearServerLogs(data, player)
				end
			end),
			true
		)

		janitor:Add(RunService.Heartbeat:Connect(onHeartbeat), "Disconnect")

		janitor:Add(
			Players.PlayerRemoving:Connect(function(player)
				subscribers[player] = nil
				sentHash[player] = nil
			end),
			"Disconnect"
		)

		log:debug("DebuggerServiceServer initialized")
	end,

	--[=[
		Releases connections and clears subscriber state.
		@param self DebuggerServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		table.clear(subscribers)
		table.clear(sentHash)
		log:debug("DebuggerServiceServer stopped")
	end,

	--[=[
		Returns the current state of the service for debugging (it appears in its own service panel).
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		local count = 0
		for _ in subscribers do
			count += 1
		end
		return {
			subscriberCount = count,
			assembling = assembling,
		}
	end,

	_onSetSubscription = onSetSubscription,
	_onClearServerLogs = onClearServerLogs,
	_pruneUnauthorizedSubscribers = pruneUnauthorizedSubscribers,
}

return DebuggerServiceServer
