--!strict
--[=[
	HostServiceClient: crew hosting on this client. Sends the local player's Start, Cancel and Leave as `startTrip`,
	`cancelTrip` and `leaveTruck` (never `start`: that is the lifecycle hook), and the host's Kick and SetLock; the server checks they may
	(HostRules.canAct). The hosted trucks are read from HostStore. The hub's Next shift card (DepotPad) calls these.

	Spec-exempt shell (ByteNet); the state is the specced HostStore and HostSnapshotUtils.

	@class HostServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HostEvents = require(ReplicatedStorage.Shared.Features.Host.Net.HostEvents)
local HostStore = require(ReplicatedStorage.Client.Features.Host.State.HostStore)

export type HostServiceClient = {
	dependencies: { string },
	startTrip: (self: HostServiceClient) -> (),
	cancelTrip: (self: HostServiceClient) -> (),
	leaveTruck: (self: HostServiceClient) -> (),
	kick: (self: HostServiceClient, userId: number) -> (),
	setLock: (self: HostServiceClient, locked: boolean) -> (),
	getState: (self: HostServiceClient) -> { [string]: any },
}

local HostServiceClient: HostServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	-- The host starts their truck's countdown.
	startTrip = function(_self)
		HostEvents.packets.Start.send(true)
	end,

	-- The host stops it.
	cancelTrip = function(_self)
		HostEvents.packets.Cancel.send(true)
	end,

	-- Steps the local player out of their truck.
	leaveTruck = function(_self)
		HostEvents.packets.Leave.send(true)
	end,

	-- The host takes `userId` off their truck until it leaves.
	kick = function(_self, userId)
		HostEvents.packets.Kick.send(userId)
	end,

	-- The host turns friends only on or off.
	setLock = function(_self, locked)
		HostEvents.packets.SetLock.send(locked)
	end,

	getState = function(_self)
		local current = HostStore.snapshot()
		local trucks = 0
		if current ~= nil then
			for _ in current.trucks do
				trucks += 1
			end
		end
		return { trucks = trucks }
	end,
}

return HostServiceClient
