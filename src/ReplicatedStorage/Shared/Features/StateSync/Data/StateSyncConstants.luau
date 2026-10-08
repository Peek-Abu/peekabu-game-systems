--!strict
--[=[
	StateSyncConstants: the shared contract between the charm-sync server and client.

	charm-sync tracks state by a STRING KEY that must be identical on both ends, and (critically)
	each key may map to only ONE underlying signal process-wide — see `trackSignal` in
	charm-sync/server.luau. Player data is per-player, so keys MUST be scoped by `UserId`; the
	server builds them from `player.UserId` and the client from `Players.LocalPlayer.UserId`, and
	they line up because both call `key` below.

	This module owns the transport name (`REMOTE_NAME`) and re-exports WHICH slices replicate
	(`SLICES`) — derived from `StateSyncSliceRegistry`, the one declaration site for replicated slices. Both
	StateSync services iterate `SLICES`, so adding a replicated slice never touches them (or this
	file) — it wires from the manifest plus the per-slice getter/setter the stores expose
	(`StateSyncServerStore.getterFor` / `StateSyncClientStore.setterFor`).

	@class StateSyncConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateSyncSliceRegistry = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncSliceRegistry)

-- The profile slices replicated to their owning client — derived from the manifest so this file is
-- never an edit site when a slice is added.
local SLICES: { string } = StateSyncSliceRegistry.NAMES

local StateSyncConstants = {
	-- The name of the dedicated RemoteEvent charm-sync payloads travel over. Defined once here (the
	-- shared contract) so the server and client can never disagree on it.
	REMOTE_NAME = "CharmSyncRemote",
	SLICES = SLICES,
}

--[=[
	The player-scoped charm-sync key for a slice. Both realms build keys from this helper so they
	can never drift, and the `{slice}:` prefix keeps different slices from colliding for one user.
	@param slice string -- The profile slice name (e.g. "currency")
	@param userId number -- The owning player's UserId
	@return string -- A stable, player-scoped charm-sync key
]=]
function StateSyncConstants.key(slice: string, userId: number): string
	return `{slice}:{userId}`
end

--[=[
	The public slice (other players' public data, `StateSyncPublicPlayerStore` on the server, `StateSyncClientStore.publicPlayers`
	on the client). Not a profile slice, so it is not in `SLICES`: each client syncs ONE key holding the map of
	players relevant to it.
]=]
StateSyncConstants.PUBLIC_SLICE = "publicPlayers"

function StateSyncConstants.publicKey(viewerUserId: number): string
	return StateSyncConstants.key(StateSyncConstants.PUBLIC_SLICE, viewerUserId)
end

-- The public map's key for one player.
function StateSyncConstants.publicEntryKey(userId: number): string
	return tostring(userId)
end

return StateSyncConstants
