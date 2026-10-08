--!strict
--[=[
	StateSyncServiceClient: charm-sync transport for the client.

	Registers StateSyncClientStore atoms as charm-sync setters, applies inbound payloads, and fires the
	ready handshake so the server begins replicating. Auto-discovered and booted by ClientHandler
	via the `*ServiceClient` suffix.

	@class StateSyncServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local log = Logger.new("StateSyncServiceClient")

-- Module-level state (not part of the service table). The inbound connection lives on this janitor
-- and is released in stop().
local janitor = Janitor.new()

export type StateSyncServiceClient = {
	dependencies: { string },
	init: (self: StateSyncServiceClient) -> (),
	stop: (self: StateSyncServiceClient) -> (),
	getState: (self: StateSyncServiceClient) -> { [string]: any },
}

local StateSyncServiceClient: StateSyncServiceClient = {
	dependencies = {},

	--[=[
		Registers setters, subscribes to inbound payloads, and signals readiness.
		@param self StateSyncServiceClient -- The service instance
	]=]
	init = function(_self)
		local client = CharmSync.client
		local userId = Players.LocalPlayer.UserId

		-- Register one setter per synced slice, driven by StateSyncConstants.SLICES so this service never
		-- names a slice. StateSyncClientStore owns the slice→atom mapping via setterFor.
		local setters: { [string]: StateSyncClientStore.SliceSetter } = {}
		for _, slice in StateSyncConstants.SLICES do
			setters[StateSyncConstants.key(slice, userId)] = StateSyncClientStore.setterFor(slice)
		end
		setters[StateSyncConstants.publicKey(userId)] = StateSyncClientStore.setterFor(StateSyncConstants.PUBLIC_SLICE)
		client.addSignals(setters)

		-- Instance-boundary narrowing: WaitForChild returns Instance, but the server creates this
		-- child as a RemoteEvent (see StateSyncServiceServer). Same justified-cast pattern the boot
		-- loaders use at their dynamic-require boundary.
		local remote = ReplicatedStorage:WaitForChild(StateSyncConstants.REMOTE_NAME) :: RemoteEvent
		janitor:Add(
			remote.OnClientEvent:Connect(function(payloads)
				-- Client trust boundary: only hand well-formed payloads to charm-sync. The server is
				-- authoritative, but a malformed value would otherwise flow straight into the atoms.
				if type(payloads) ~= "table" then
					log:warn("Ignoring non-table charm-sync payload:", typeof(payloads))
					return
				end
				-- Wire diagnostic (history-only debug): one line per inbound batch, so the F4 Logs
				-- tab shows whether the server's payloads reach this client and of which type.
				-- Paired with the server's "charm-sync ->" line, this splits any future sync bug
				-- into sent-vs-received in one glance (it found the 2026-07-17 transport bug).
				local kinds = {}
				for _, payload in payloads do
					table.insert(kinds, tostring(payload.type))
				end
				log:debug("charm-sync <- payloads:", #payloads, table.concat(kinds, ","))
				client.patch(payloads)
			end),
			"Disconnect"
		)

		-- Tell the server we are ready to receive the initial sync.
		remote:FireServer()
		log:debug("charm-sync client ready for userId:", userId)
	end,

	--[=[
		Disconnects the inbound payload connection.
		@param self StateSyncServiceClient -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("Service stopped, connections cleaned up")
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			hasCurrency = StateSyncClientStore.currency() ~= nil,
			inventoryCount = #StateSyncClientStore.inventory().items,
		}
	end,
}

return StateSyncServiceClient
