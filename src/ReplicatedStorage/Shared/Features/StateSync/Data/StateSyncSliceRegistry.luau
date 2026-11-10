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
	-- ACCOUNT-WIDE: the premium balance (MarketplaceServiceServer). The `receipts` history is deliberately
	-- NOT listed: it is server-only bookkeeping.
	premium = {
		read = function(profile)
			return profile.account.premium
		end,
	},
	-- ACCOUNT-WIDE: what the player owns (EntitlementServiceServer).
	entitlements = {
		read = function(profile)
			return profile.account.entitlements
		end,
	},
	-- ACCOUNT-WIDE: the player's preferences (SettingServiceServer).
	settings = {
		read = function(profile)
			return profile.account.settings
		end,
	},
	-- ACCOUNT-WIDE: the daily reward streak (DailyRewardServiceServer).
	dailyReward = {
		read = function(profile)
			return profile.account.dailyReward
		end,
	},
	-- ACCOUNT-WIDE: this week's timecard (TimecardServiceServer); owner-only like every profile slice.
	workOrder = {
		read = function(profile)
			return profile.account.workOrder
		end,
	},
	timecard = {
		read = function(profile)
			return profile.account.timecard
		end,
	},
	-- ACCOUNT-WIDE: what the player wears (CosmeticServiceServer); owner-only like every profile slice.
	loadout = {
		read = function(profile)
			return profile.account.loadout
		end,
	},
	-- ACCOUNT-WIDE: the social perks (SocialServiceServer); owner-only.
	social = {
		read = function(profile)
			return profile.account.social
		end,
	},
	-- ACCOUNT-WIDE: whether the player has finished training (TrainingServiceServer); owner-only.
	training = {
		read = function(profile)
			return profile.account.training
		end,
	},
	-- ACCOUNT-WIDE: the buyer's Coffee for the crew time left (CoffeeServiceServer); owner-only.
	coffee = {
		read = function(profile)
			return profile.account.coffee
		end,
	},
	-- ACCOUNT-WIDE: one-time deals bought and picks waiting (DealServiceServer); owner-only.
	deals = {
		read = function(profile)
			return profile.account.deals
		end,
	},
	-- ACCOUNT-WIDE: keys and pity per Locker (LockerServiceServer); owner-only.
	lockers = {
		read = function(profile)
			return profile.account.lockers
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
