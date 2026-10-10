--!strict
--[=[
	ShiftStore: the shift as the local client sees it. `snapshot` is a Charm computed atom over the `shift`
	world entry, decoded by ShiftSnapshotUtils (nil before the first sync); `myVote` is the results choice the
	results panel writes and ShiftServiceClient sends. React reads both with useAtom; the client never writes
	the shift.

	@class ShiftStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): ShiftTypes.ShiftSnapshot?
	return ShiftSnapshotUtils.decode(StateSyncClientStore.world()[ShiftConstants.WORLD_ENTRY])
end)

local initialVote: ShiftTypes.Vote? = nil
local myVote = Charm.atom(initialVote)

return {
	snapshot = snapshot,
	myVote = myVote,
}
