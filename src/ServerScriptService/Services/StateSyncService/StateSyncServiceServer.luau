--!strict
--[=[
	StateSyncServiceServer: charm-sync transport for the server.

	Owns the RemoteEvent that carries charm-sync payloads, registers each player's per-slice
	getters (reading ServerStore) once the client signals it is ready, and tears the client
	down on leave. Auto-discovered and booted by ServerHandler via the `*ServiceServer` suffix.

	Transport note: this is a dedicated RemoteEvent, NOT a ByteNet packet — a documented exception
	to the "events are ByteNet packets under Shared/Events" rule. The charm-sync payload is
	dynamically shaped, so no static ByteNet struct can describe it; `ByteNet.unknown` would ship
	it via Roblox's default serializer anyway (no encoding benefit) while adding a coalescing frame
	and coupling charm-sync to ByteNet.

	Hydration handshake:
	1. Client registers its setters, then fires the RemoteEvent (ready ping).
	2. The ready handler (rate-limited via RequestHandler) marks the client's keys PENDING; the next
	   flush sends a full "init" payload, and subsequent changes send "patch" deltas.
	Registering only after the client is ready guarantees the client's setters exist before the
	first payload arrives.

	@class StateSyncServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local ServerStore = require(ServerScriptService.State.ServerStore)

local log = Logger.new("StateSyncServiceServer")

-- Module-level state (not part of the service table). Session connections live on this janitor and
-- are released in stop(); `remote` is lifted here so stop()/getState() can reach it.
local janitor = Janitor.new()
local remote: RemoteEvent? = nil

-- The RequestHandler-wrapped ready handler, lifted here for the test seam below. Tests cannot fire
-- OnServerEvent as a real client, so the spec invokes this directly with a shaped fake player.
local readyHandler: ((data: unknown, player: Player) -> any)? = nil

export type StateSyncServiceServer = {
	dependencies: { string },
	init: (self: StateSyncServiceServer) -> (),
	stop: (self: StateSyncServiceServer) -> (),
	getState: (self: StateSyncServiceServer) -> { [string]: any },
	_simulateClientReadyForTesting: (self: StateSyncServiceServer, player: Player) -> (),
}

local StateSyncServiceServer: StateSyncServiceServer = {
	dependencies = {},

	--[=[
		Creates (or reuses) the transport RemoteEvent, wires charm-sync's outbound callback to it,
		and registers per-player getters when each client reports ready.
		@param self StateSyncServiceServer -- The service instance
	]=]
	init = function(_self)
		local server = CharmSync.server

		-- Find-or-create the transport RemoteEvent so a re-init/hot-reload can't leave a duplicate.
		local existing = ReplicatedStorage:FindFirstChild(SyncState.REMOTE_NAME)
		local transport: RemoteEvent
		if existing and existing:IsA("RemoteEvent") then
			transport = existing
		else
			local created = Instance.new("RemoteEvent")
			created.Name = SyncState.REMOTE_NAME
			created.Parent = ReplicatedStorage
			transport = created
		end
		remote = transport

		-- charm-sync hands us (client, payloads) whenever a tracked slice changes; forward to the
		-- owning client. The interval flush is driven internally on Heartbeat until disconnect().
		server.connect(function(player, payloads)
			transport:FireClient(player, payloads)
		end)

		-- The client fires the ready ping once its setters are registered. Routed through
		-- RequestHandler for per-player rate limiting (registration is idempotent, so this just caps
		-- spam) and xpcall isolation. RemoteEvent hands us the Player first, so flip the argument
		-- order into RequestHandler's (data, player) contract.
		readyHandler = RequestHandler.wrap({
			name = "CharmSyncReady",
			rateLimit = { maxRequests = 5, windowSeconds = 10 },
			handler = function(_data: unknown, player: Player)
				-- Register one getter per synced slice, driven by SyncState.SLICES so this service
				-- never names a slice. ServerStore owns the slice→atom mapping via getterFor.
				local getters: { [string]: () -> unknown } = {}
				for _, slice in SyncState.SLICES do
					getters[SyncState.key(slice, player.UserId)] = ServerStore.getterFor(slice, player.UserId)
				end
				server.addSignalsToClient(player, getters)
				log:debug("Registered charm-sync signals for userId:", player.UserId)
			end,
		})
		janitor:Add(
			transport.OnServerEvent:Connect(function(player)
				local handler = readyHandler
				if handler then
					handler(nil, player)
				end
			end),
			"Disconnect"
		)

		-- Stop tracking/replicating to a client once they leave. Routed through observePlayer like
		-- the data layer; ServerStore.remove is handled by PlayerDataServiceServer's cleanup path.
		janitor:Add(
			Observers.observePlayer(function(player)
				return function()
					server.removeClient(player)
				end
			end),
			true
		)
	end,

	--[=[
		Stops the charm-sync interval, disconnects all session connections, and removes the transport.
		@param self StateSyncServiceServer -- The service instance
	]=]
	stop = function(_self)
		CharmSync.server.disconnect()
		janitor:Cleanup()
		readyHandler = nil
		if remote then
			remote:Destroy()
			remote = nil
		end
		log:debug("Service stopped, connections cleaned up")
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			remoteReady = remote ~= nil,
		}
	end,

	--[=[
		TEST SEAM — not for use in game code (same convention as PlayerDataServiceServer's
		`_setProfileForTesting`). Invokes the RequestHandler-wrapped ready handler directly, exactly
		as the OnServerEvent connection would. Specs run without real player connections, so they
		cannot fire the RemoteEvent as a client; this covers the handler logic and rate limiting —
		the actual wire is only observable in Studio with a live client.
		@param player Player -- The (possibly fake, UserId-shaped) player reporting ready
	]=]
	_simulateClientReadyForTesting = function(_self, player)
		local handler = readyHandler
		assert(handler, "StateSyncServiceServer.init must run before simulating a client ready ping")
		handler(nil, player)
	end,
}

return StateSyncServiceServer
