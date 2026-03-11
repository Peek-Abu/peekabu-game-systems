--!strict
--[=[
	SliceManifest: the ONE declaration site for replicated profile slices.

	Every layer of the reactive spine derives from this table:
	- `SyncState.SLICES` (the shared server/client contract) is built from `NAMES`.
	- `ServerStore` creates one atom per entry and mirrors profiles through each entry's `read`.
	- Both StateSync services already iterate `SyncState.SLICES`, so they inherit new slices for free.

	Adding a replicated slice is therefore:
	1. Add the field to `PlayerDataTypes.PlayerProfile`.
	2. Add ONE entry to `DEFINITIONS` below.
	3. Declare its client atom in `ClientStore` (one atom + one registry line — kept there so the
	   UI-facing atoms stay narrowly typed in the client realm).
	4. Register the slice's default via `SliceOwner.register` in the owning domain service (which a
	   new slice needs anyway — that's where its domain logic lives).
	SyncState, ServerStore, StateSyncServiceServer, and StateSyncServiceClient need no edits.

	`read` returns `unknown` (not a per-slice type): this registry is inherently string-keyed and
	dynamic, so types are erased at this generic boundary — the same documented rationale as
	`ProfilePath` being `string` (limitations.md #3). Narrow typing lives with the consumers: the
	owning service's `SliceOwner` accessor (server) and the `ClientStore` atoms (client).

	@class SliceManifest
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

export type SliceDefinition = {
	-- Reads this slice's value off a full profile; drives ServerStore's mirroring.
	read: (profile: PlayerDataTypes.PlayerProfile) -> unknown,
}

-- The replicated slices. One entry here is the manifest edit when adding a slice.
local DEFINITIONS: { [string]: SliceDefinition } = {
	currency = {
		read = function(profile)
			return profile.currency
		end,
	},
	inventory = {
		read = function(profile)
			return profile.inventory
		end,
	},
}

-- Stable name list derived from the definitions, sorted so every consumer iterates in the same
-- deterministic order regardless of hash-map iteration.
local NAMES: { string } = {}
for name in DEFINITIONS do
	table.insert(NAMES, name)
end
table.sort(NAMES)

return {
	DEFINITIONS = DEFINITIONS,
	NAMES = NAMES,
}
