--!strict
--[=[
	QueueStore: the queue as this client sees it, for the HUD. `snapshot` decodes the `queue` world entry
	(QueueSnapshotUtils); `widgetEnabled` lets a game hide the base's placeholder pad widget and draw its
	own (QueueServiceClient:setDefaultWidget). A read-only mirror of server state.

	@class QueueStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueShared = ReplicatedStorage.Shared.Features.Queue
local Charm = require(ReplicatedStorage.Packages.Charm)
local QueueConstants = require(QueueShared.Data.QueueConstants)
local QueueTypes = require(QueueShared.Data.QueueTypes)
local QueueSnapshotUtils = require(QueueShared.Utils.QueueSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): QueueTypes.QueueSnapshot?
	return QueueSnapshotUtils.decode(StateSyncClientStore.world()[QueueConstants.WORLD_ENTRY])
end)

local widgetEnabled = Charm.atom(true)

local QueueStore = {
	snapshot = snapshot,
	widgetEnabled = widgetEnabled,
}

-- The pad `userId` is aboard, as this client sees it (its id and snapshot), or nil.
function QueueStore.padFor(userId: number): (string?, QueueTypes.PadSnapshot?)
	return QueueSnapshotUtils.padOf(snapshot(), userId)
end

return QueueStore
