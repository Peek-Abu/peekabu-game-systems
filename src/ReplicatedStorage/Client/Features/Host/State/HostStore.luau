--!strict
--[=[
	HostStore: the hosted trucks as this client sees it, for the hub's Next shift card. `snapshot` decodes the
	`host` world entry (HostSnapshotUtils). A read-only mirror of server state.

	@class HostStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HostShared = ReplicatedStorage.Shared.Features.Host
local Charm = require(ReplicatedStorage.Packages.Charm)
local HostConstants = require(HostShared.Data.HostConstants)
local HostTypes = require(HostShared.Data.HostTypes)
local HostSnapshotUtils = require(HostShared.Utils.HostSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): HostTypes.HostSnapshot?
	return HostSnapshotUtils.decode(StateSyncClientStore.world()[HostConstants.WORLD_ENTRY])
end)

local HostStore = {
	snapshot = snapshot,
}

-- The host of the truck on Queue pad `padId`, as this client sees it, or nil.
function HostStore.hostOf(padId: string): number?
	return HostSnapshotUtils.hostOf(snapshot(), padId)
end

return HostStore
