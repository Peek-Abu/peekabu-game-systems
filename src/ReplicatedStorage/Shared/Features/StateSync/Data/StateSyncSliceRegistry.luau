--!strict
--[=[
	StateSyncSliceRegistry: the ONE declaration site for replicated profile slices.

	Every layer of the reactive spine derives from this table:
	- `StateSyncConstants.SLICES` (the shared server/client contract) is built from `NAMES`.
	- `StateSyncServerStore` creates one atom per entry and mirrors profiles through each entry's `read`.
	- Both StateSync services already iterate `StateSyncConstants.SLICES`, so they inherit new slices for free.

	Adding a replicated slice is therefore:
	1. Add the field to `PlayerDataTypes.PlayerSlot` (slot-scoped) or `PlayerAccount` (account-wide).
	2. Add ONE entry to `DEFINITIONS` below.
	3. Declare its client atom in `StateSyncClientStore` (one atom + one registry line — kept there so the
	   UI-facing atoms stay narrowly typed in the client realm).
	4. Register via `PlayerDataSliceSystem.registerSlot` / `registerAccount` in the owning domain service (which
	   a new slice needs anyway — that's where its domain logic lives).
	StateSyncConstants, StateSyncServerStore, StateSyncServiceServer, and StateSyncServiceClient need no edits.

	`read` returns `unknown` (not a per-slice type): this registry is inherently string-keyed and
	dynamic, so types are erased at this generic boundary — the same documented rationale as
	`ProfilePath` being `string` (limitations.md #3). Narrow typing lives with the consumers: the
	owning service's `PlayerDataSliceSystem` accessor (server) and the `StateSyncClientStore` atoms (client).

	@class StateSyncSliceRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type SliceDefinition = {
	-- Reads this slice's value off a full profile; drives StateSyncServerStore's mirroring.
	read: (profile: PlayerDataTypes.PlayerProfile) -> unknown,
}

-- The replicated slices. One entry here is the manifest edit when adding a slice.
--
-- A SLOT-SCOPED slice reads through `profile.slots[profile.slotState.active]`, so the atom — and
-- therefore everything charm-sync ships to the client — holds the ACTIVE slot only. Inactive
-- slots' data never leaves the server. An ACCOUNT-WIDE slice reads through `profile.account` instead.
local DEFINITIONS: { [string]: SliceDefinition } = {
	currency = {
		read = function(profile)
			return profile.slots[profile.slotState.active].currency
		end,
	},
	inventory = {
		read = function(profile)
			return profile.slots[profile.slotState.active].inventory
		end,
	},
	-- ACCOUNT-WIDE: what a player has EARNED is about the player, once, shared by every slot — reads
	-- through `profile.account` (see the header's scope note).
	titles = {
		read = function(profile)
			return profile.account.titles
		end,
	},
	-- SLOT-SCOPED: which title the active slot wears; inactive slots' choices never leave the server.
	equippedTitle = {
		read = function(profile)
			return profile.slots[profile.slotState.active].equippedTitle
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
