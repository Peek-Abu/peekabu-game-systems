--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

export type CurrencyType = CurrencyConstants.CurrencyType

--[=[
	An inventory entry is either a STACK (a quantity of a fungible itemType) or a UNIQUE instance
	(one physical item, identified by `uid`). A unique instance may carry `attrs`: per-instance data
	stamped at mint and owned by the game (a pet's level or mutation, a tool's durability, a rolled
	modifier). Values are a finite number or a short string; absent = none. Unknown keys are tolerated
	on read so a retired attribute never breaks a save.
]=]
export type StackEntry = {
	itemType: string, -- the internal definition key
	quantity: number,
}
export type AttrValue = number | string
export type UniqueEntry = {
	itemType: string, -- the internal definition key
	uid: string, -- identifies this specific physical instance
	attrs: { [string]: AttrValue }?, -- per-instance data stamped at mint (see above)
}
export type InventoryEntry = StackEntry | UniqueEntry

--[=[
	A character slot's inventory: a wrapper around the entry array (not a bare `{ InventoryEntry }`)
	so a future metadata field (e.g. a capacity override) can be added to this type without
	reshaping every `PlayerSlot.inventory` reader/writer in the codebase.
]=]
export type Inventory = { items: { InventoryEntry } }

--[=[
	Account-wide item-minting state: the monotonic counter InventoryServiceServer draws from (see its
	`addUnique`) to stamp a fresh, collision-proof `uid` onto every newly-created UniqueEntry.
	Account-scoped (not per-slot) because a uid must stay unique across a player's ENTIRE account.
]=]
export type ItemMint = {
	nextUid: number,
}

--[=[
	Item definitions: one flat shape for every kind. `kind` and `rarity` are plain strings validated
	against ItemConstants at registration (keeping this Types module free of a Constants dependency).
	STACKABILITY IS DECLARED, NOT INFERRED FROM KIND: a definition with `stackMax` is fungible and lives
	in stacks; one without is unique and minted with a `uid`. A game that needs kind-specific fields
	adds them here as optional fields and validates them in its own registration step.
]=]
export type ItemDefinition = {
	name: string,
	rarity: string, -- validated against ItemConstants at registration
	kind: string, -- validated against ItemConstants at registration
	description: string?,
	icon: string?,
	stackMax: number?, -- present = stackable (max quantity per stack); absent = unique instances
	maxStacks: number?, -- optional cap on how many stacks of this itemType one container may hold
}

-- Currency uses CurrencyType as keys
export type Currency = {
	[CurrencyType]: number,
}

--[=[
	The account-wide titles slice: which titles the player has EARNED. A wrapper map keyed by title
	id with values always `true`. Ids are plain strings (not a registry union) because retirement must
	stay migration-free; the validator tolerates unknown ids on purpose while rejecting malformed
	structure.
]=]
export type Titles = {
	earned: { [string]: boolean },
}

--[=[
	The account-wide premium currency (bought with Robux, so it must survive across every save slot). A
	wrapper (not a bare number) because the data layer mutates tables in place. Validated by the data
	layer: a whole number from 0 to MarketplaceConstants.MAX_PREMIUM.
]=]
export type Premium = {
	balance: number,
}

--[=[
	The account's recent developer-product purchase ids, oldest first, capped at
	MarketplaceConstants.RECEIPT_HISTORY. Recorded in the same transaction as a purchase's grant, so a
	receipt Roblox retries is recognised and never granted twice. Server-only (never replicated).
]=]
export type PurchaseReceipts = {
	ids: { string },
}

--[=[
	A slot's equipped-title wrapper: WHICH of the account's earned titles is shown. Wrapped in a table
	(not a bare `equipped: string?` field) so a future field can be added without reshaping every
	reader/writer. Absent `equipped` = wearing nothing.
]=]
export type EquippedTitle = {
	equipped: string?,
}

--[=[
	One save slot. Every slot-scoped domain slice registers a field here.

	Games without multiple characters run with `PlayerDataConstants.MAX_SLOTS = 1`: there is then
	exactly one slot and "slot-scoped" simply means "the player's save".

	INVARIANT: a slot is a SELF-CONTAINED SUBTREE — it must never hold a reference into another slot.
	That is what keeps a slot liftable into its own DataStore key later without reshaping domain code.
]=]
export type PlayerSlot = {
	currency: Currency,
	inventory: Inventory,
	equippedTitle: EquippedTitle,
	-- Extend with other SLOT-SCOPED slices here
}

--[=[
	Account-wide data: entitlements and collections — "you own this". Idempotent by nature, therefore
	safe to share across slots. Quantities and item instances do NOT belong here: they must live under
	exactly one atomic owner.
]=]
export type PlayerAccount = {
	itemMint: ItemMint,
	titles: Titles,
	premium: Premium,
	receipts: PurchaseReceipts,
	-- Extend with other ACCOUNT-WIDE slices here (settings, entitlements, ...)
}

--[=[
	Which character the player is currently playing.

	A TABLE, not a bare `activeSlot: number`, for a load-bearing reason: `mutate` hands a mutator the
	VALUE at a path and expects in-place mutation (its return value is only a "did anything change"
	flag). A number cannot be mutated by reference, so a scalar path is READ-ONLY through the data
	layer — a bare `activeSlot` could never be switched. Wrapping it in a table makes it writable
	without changing the atomicity core's contract. DO NOT "simplify" this back into a scalar: that
	silently breaks the slot switch.

	Core profile state, not a domain slice: PlayerDataService and StateSyncSliceRegistry both read it.
	With MAX_SLOTS = 1 it never changes (active = 1, epoch = 1); the machinery stays dormant so a game
	that wants multiple save files can turn it on without reshaping the data layer.
]=]
export type SlotState = {
	active: number,

	--[=[
		The GENERATION counter of the active character — monotonic, starts at 1, bumped by every
		successful slot switch, and NEVER reset. It is not a slot index and must not be derived from
		one: switching 1 → 2 → 1 lands back on slot 1 with a strictly HIGHER epoch.

		What it is FOR: a transaction op's profile path is baked at MINT time (`slots.1.currency` — see
		PlayerDataSliceSystem.op). A caller that mints ops and then yields before committing them (a trade awaiting
		the other side's confirmation) can have the player switch character in that window; the op then
		commits to the slot they LEFT, and because the mirror only replicates the ACTIVE slot, the client
		never sees it. Capturing the epoch at mint and re-checking it at commit is what makes such an op
		detectably STALE. DO NOT remove this as "unused" — it is the guard's whole basis.
	]=]
	epoch: number,
}

--[=[
	The whole profile: one ProfileStore key per player, with every character slot nested INSIDE it.
	That is what makes cross-slot item movement a single atomic UpdateAsync — and therefore makes
	cross-slot duplication structurally impossible rather than merely unlikely.
]=]
export type PlayerProfile = {
	_schemaVersion: number?, -- Managed by PlayerDataMigrationSystem; absent on client-built profiles
	slotState: SlotState,
	account: PlayerAccount,
	slots: { PlayerSlot },
}

-- Dynamically registered strings
export type ProfilePath = string

export type PlayerDataServiceConfigs = {
	useMock: boolean,
	storeName: string,
	template: PlayerProfile,
}

-- This module is types-only at runtime — every export above is an `export type`. Consumers
-- `require()` it purely for type annotations (e.g. `PlayerDataTypes.Currency`), never for a value.
return {}
