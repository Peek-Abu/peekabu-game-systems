--!strict
--[=[
	Unit tests for StateSyncServiceServer — the charm-sync replication transport.

	Mock strategy: patch the CharmSync.server function table inside beforeAll/afterAll (the service
	reads it at init() call time, and method lookup goes through the table — the same convention as
	patching PlayerDataService in the domain specs). The patched functions RECORD calls instead of
	starting the real Heartbeat interval, so no real replication runs during specs.

	What this file covers: transport find-or-create, ready-ping getter registration (including the
	per-player data-ISOLATION property — a client's getters must only ever read that client's own
	slices), the real RequestHandler rate limit on the ready ping, and teardown. What it cannot
	cover: the actual RemoteEvent wire (OnServerEvent/FireClient need live player connections), so
	the ready ping is invoked through the service's `_simulateClientReadyForTesting` seam and the
	leave-cleanup path (Observers.observePlayer) is untested here — both are only observable in
	Studio with a real client.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local SliceManifest = require(ReplicatedStorage.Shared.State.SliceManifest)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)
local ServerStore = require(ServerScriptService.State.ServerStore)
local StateSyncService = require(ServerScriptService.Services.StateSyncService.StateSyncServiceServer)

-- RequestHandler.wrap only reads player.UserId; unique IDs per test keep its module-level
-- rate-limit windows from bleeding between tests.
local function fakePlayer(userId: number)
	return { UserId = userId, Name = `FakePlayer{userId}` } :: any
end

return function()
	describe("StateSyncServiceServer", function()
		local prevLogLevel: Logger.LogLevel

		-- Call records for the patched CharmSync.server functions. removeClient is stubbed but not
		-- recorded: its only trigger (a real player leaving, via Observers.observePlayer) cannot
		-- happen in a spec run — that path is Studio-only territory (see file header).
		local connectCalls: { any } = {}
		local addSignalsCalls: { { client: any, getters: { [string]: () -> unknown } } } = {}
		local disconnectCalls = 0

		local _origConnect
		local _origAddSignals
		local _origRemoveClient
		local _origDisconnect

		beforeAll(function()
			prevLogLevel = Logger.getGlobalLevel()
			Logger.setGlobalLevel("NONE")

			_origConnect = CharmSync.server.connect
			_origAddSignals = CharmSync.server.addSignalsToClient
			_origRemoveClient = CharmSync.server.removeClient
			_origDisconnect = CharmSync.server.disconnect

			CharmSync.server.connect = function(onSync: any)
				table.insert(connectCalls, onSync)
			end
			CharmSync.server.addSignalsToClient = function(client: any, getters: any)
				table.insert(addSignalsCalls, { client = client, getters = getters })
			end
			CharmSync.server.removeClient = function(_client: any) end
			CharmSync.server.disconnect = function()
				disconnectCalls += 1
			end
		end)

		afterAll(function()
			CharmSync.server.connect = _origConnect
			CharmSync.server.addSignalsToClient = _origAddSignals
			CharmSync.server.removeClient = _origRemoveClient
			CharmSync.server.disconnect = _origDisconnect
			Logger.setGlobalLevel(prevLogLevel)
		end)

		beforeEach(function()
			connectCalls = {}
			addSignalsCalls = {}
			disconnectCalls = 0
		end)

		afterEach(function()
			-- stop() is idempotent enough for specs: disconnects (recorded), cleans the janitor,
			-- and destroys the transport so the next test's init starts from a clean tree.
			StateSyncService:stop()
		end)

		-- =====================================================================
		describe("init", function()
			it("creates the transport RemoteEvent and wires the charm-sync outbound callback", function()
				StateSyncService:init()
				local found = ReplicatedStorage:FindFirstChild(SyncState.REMOTE_NAME)
				expect(found).to.be.ok()
				expect(found and found:IsA("RemoteEvent")).to.equal(true)
				expect(#connectCalls).to.equal(1)
				expect(StateSyncService:getState().remoteReady).to.equal(true)
			end)

			it("adopts a pre-existing transport RemoteEvent instead of creating a duplicate", function()
				local existing = Instance.new("RemoteEvent")
				existing.Name = SyncState.REMOTE_NAME
				existing.Parent = ReplicatedStorage

				StateSyncService:init()

				expect(ReplicatedStorage:FindFirstChild(SyncState.REMOTE_NAME)).to.equal(existing)
				-- Exactly one child of that name (no duplicate created alongside).
				local count = 0
				for _, child in ReplicatedStorage:GetChildren() do
					if child.Name == SyncState.REMOTE_NAME then
						count += 1
					end
				end
				expect(count).to.equal(1)
			end)
		end)

		-- =====================================================================
		describe("client ready ping", function()
			it("registers one getter per manifest slice, keyed to the reporting player's UserId", function()
				StateSyncService:init()
				StateSyncService:_simulateClientReadyForTesting(fakePlayer(910001))

				expect(#addSignalsCalls).to.equal(1)
				local getters = addSignalsCalls[1].getters

				local keyCount = 0
				for _ in getters do
					keyCount += 1
				end
				expect(keyCount).to.equal(#SliceManifest.NAMES)

				for _, slice in SliceManifest.NAMES do
					expect(getters[SyncState.key(slice, 910001)]).to.be.ok()
				end
			end)

			it("ISOLATION: a player's getters read only that player's own slice data", function()
				StateSyncService:init()
				ServerStore.set("currency", 910002, { gold = 7 })
				ServerStore.set("currency", 910003, { gold = 9999 })

				StateSyncService:_simulateClientReadyForTesting(fakePlayer(910002))
				local getters = addSignalsCalls[1].getters

				local value = getters[SyncState.key("currency", 910002)]() :: any
				expect(value.gold).to.equal(7)
				-- And no getter for any OTHER user's key was registered for this client.
				expect(getters[SyncState.key("currency", 910003)]).to.equal(nil)

				ServerStore.remove(910002)
				ServerStore.remove(910003)
			end)

			it("rate limits the ready ping via the real RequestHandler (5 per 10s window)", function()
				StateSyncService:init()
				local player = fakePlayer(910004)
				for _ = 1, 6 do
					StateSyncService:_simulateClientReadyForTesting(player)
				end
				-- The 6th ping inside the window is silently dropped before the handler runs.
				expect(#addSignalsCalls).to.equal(5)
			end)
		end)

		-- =====================================================================
		describe("stop", function()
			it("disconnects charm-sync and destroys the transport", function()
				StateSyncService:init()
				local remoteBefore = ReplicatedStorage:FindFirstChild(SyncState.REMOTE_NAME)
				expect(remoteBefore).to.be.ok()

				StateSyncService:stop()

				expect(disconnectCalls).to.equal(1)
				expect(ReplicatedStorage:FindFirstChild(SyncState.REMOTE_NAME)).to.equal(nil)
				expect(StateSyncService:getState().remoteReady).to.equal(false)
			end)

			it("refuses a simulated ready ping after stop (handler seam is cleared)", function()
				StateSyncService:init()
				StateSyncService:stop()
				expect(function()
					StateSyncService:_simulateClientReadyForTesting(fakePlayer(910005))
				end).to.throw()
			end)
		end)
	end)
end
