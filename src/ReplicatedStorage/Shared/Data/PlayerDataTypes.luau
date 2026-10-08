--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

export type CurrencyType = CurrencyConstants.CurrencyType

--[=[
	An inventory entry is either a STACK (a quantity of a fungible itemType) or a UNIQUE instance
	(one physical item, identified by `uid`). A unique instance carries two per-instance modifier maps
	(see the affix-rolling design spec): `affixes` — Phase 3c's rolled Tier-2 pool affix — and
	`statRolls` — the reserved Tier-1 base-stat variance, unwritten until combat. Both store the
	ABSOLUTE rolled value and are optional (absent = none).
]=]
export type StackEntry = {
	itemType: string, -- the internal definition key
	quantity: number,
}
export type UniqueEntry = {
	itemType: string, -- the internal definition key
	uid: string, -- identifies this specific physical instance
	affixes: { [string]: number }?, -- Phase 3c: rolled affix, absolute value keyed by ItemAffixConstants affixId
	statRolls: { [string]: number }?, -- reserved (Tier 1): absolute value keyed by StatConstants id; unwritten until combat
}
export type InventoryEntry = StackEntry | UniqueEntry

--[=[
	A character slot's inventory: a wrapper around the entry array (not a bare `{ InventoryEntry }`)
	so a future account-level or metadata field (e.g. a capacity override) can be added to this type
	without reshaping every `PlayerSlot.inventory` reader/writer in the codebase.
]=]
export type Inventory = { items: { InventoryEntry } }

--[=[
	Account-wide item-minting state: the monotonic counter InventoryServiceServer draws from (see its
	`addUnique`) to stamp a fresh, collision-proof `uid` onto every newly-created UniqueEntry.
	Account-scoped (not per-slot) because a uid must stay unique across a player's ENTIRE account, not
	just one character — two characters minting concurrently must never be able to collide.
]=]
export type ItemMint = {
	nextUid: number,
}

--[=[
	A character slot's equipped gear: which UniqueEntry occupies each equip slot (EquipmentConstants
	slot id -> the item mint's `uid`-bearing entry). Wrapped in a table (not a bare
	`{ [string]: UniqueEntry }`) on the same terms as `Inventory` above — so a future field can be
	added without reshaping every `PlayerSlot.equipment` reader/writer.
]=]
export type Equipment = { slots: { [string]: UniqueEntry } }

--[=[
	A character slot's bank: a second, per-slot container for overflow storage of BOTH items and
	currency. Reuses `InventoryEntry` and `Currency` verbatim — not parallel types — so the bank's
	validator reuses the same shape/currency checks (see the bank design spec). Per-slot, isolated from
	every other slot's bank (Decision 1); bank items still live in exactly one slot's self-contained
	subtree, so they open no cross-slot dupe surface.
]=]
export type Bank = {
	items: { InventoryEntry },
	currency: Currency,
}

--[=[
	A color a player picked for a cosmetic or body channel. A TAGGED UNION (customization design spec,
	Decision 7 — the hybrid dye model): either a reference to an unlockable palette dye, or a free RGB
	triple. Which channels permit free RGB is per-channel policy carried on the CustomizationCosmeticRegistry
	descriptor rows; the validator enforces it, so a free value cannot be stored on a palette-only
	channel. RGB components are 0..255 integers — ONE convention, replacing the old game's inconsistent
	0-255/0-1 mix. Ids stay `string` here to keep this Types module free of a Constants dependency
	(same rationale as ItemDefinition's `rarity`).
]=]
export type Color =
	{
		source: "dye",
		id: string,
	}
	| {
		source: "rgb",
		r: number,
		g: number,
		b: number,
	}

--[=[
	One chosen cosmetic: a registered id plus the colors the player picked for it. `colors` length must
	match that cosmetic's registered `colorChannels` (enforced by the validator). Used both for the
	single-selection categories (hair/eyebrows/eyelashes) and for each generic accessory slot.
]=]
export type CosmeticSelection = {
	id: string,
	colors: { Color },
}

--[=[
	A character slot's equipped appearance — what THIS character looks like (per-slot; the account-wide
	record of what is UNLOCKED is `Entitlements`).

	Deliberately MAP-keyed rather than a fixed record, the same pattern StatsSlice.investments already
	uses: adding a cosmetic category or a body-color channel is then a CustomizationCosmeticRegistry descriptor row,
	not a type change plus new validator/plan code (design spec, Decision 10). Unknown keys are not a
	hole — the data-layer validator rejects any key that is not a registered category/channel.

	- `cosmetics`: category ("hair"/"eyebrows"/"eyelashes") -> the chosen cosmetic. An ABSENT key means
	  "none" (the old game's blank index-1 accessory is not modeled — nothing mounted is nothing stored).
	- `accessories`: the generic accessory slots, at most CustomizationCosmeticRegistry.ACCESSORY_SLOTS of them.
	- `body`: body-channel key ("color1"/"skin"/...) -> the color applied to every rig part of that
	  channel. Absent = the rig's authored default.
	- `headType`: which head mode the rig shows ("Covered"/"Uncovered"). REQUIRED, unlike every other
	  channel — a character always has a head, so there is no "none" and the skeleton stamps a default.
	  A plain `string` (not a literal union) so this Types module stays free of a Constants dependency,
	  the same rationale as `ItemDefinition.rarity`; it is validated against CustomizationCosmeticRegistry.
]=]
export type SurfaceSelection = {
	pattern: string?,
	texture: string?,
}

export type Appearance = {
	cosmetics: { [string]: CosmeticSelection },
	accessories: { CosmeticSelection },
	body: { [string]: Color },
	headType: string,
	-- Restyleable part-groups (clothing/backpack): a `SurfaceAppearance` pattern and/or a `Texture`
	-- applied to every rig part of the group. Keyed by registered surface-channel key; absent = the
	-- rig's authored surface, and either field may be absent on its own.
	surfaces: { [string]: SurfaceSelection },
	-- The character's soul colour: ONE value (possibly multi-hue, e.g. "blue-green"), which a roll
	-- REPLACES. Deliberately not an owned collection in Entitlements — see CustomizationSoulColorRegistry. Absent
	-- means none yet.
	soulColor: string?,
}

--[=[
	Account-wide customization entitlements: what the player has UNLOCKED, earned once and usable on
	every character (the WoW/GW2/ESO wardrobe model — see the design spec's research appendix).

	Only LOCKABLE ids are ever stored: a cosmetic that is free needs no entitlement row, which keeps
	this slice small and makes "is it owned" a pure registry+set question. Keyed by category so a
	category's unlock scope can later move per-slot without reshaping callers (Decision 1a).

	Soul color is deliberately NOT here: a character has ONE soul color (itself possibly multi-hued,
	e.g. "blue-green"), and rolling REPLACES it — that is a per-character value, not an owned
	collection. It lives on the per-slot `Appearance` as `soulColor` (landed in 5b). A "keep every soul
	you've rolled" collection is only modeled if a gamepass ever needs one; schema changes are free
	pre-launch.
]=]
export type Entitlements = {
	cosmetics: { [string]: { [string]: boolean } },
}

--[=[
	Item definitions: a tagged union over a common base, keyed by `kind`. No class hierarchy — the
	base carries what every item has; each kind's variant adds only what that kind needs. Rarity is
	`string` here (not `ItemConstants.Rarity` re-exported) to avoid a Types -> Constants dependency;
	it is validated against `ItemConstants.isValidRarity` at registration (Task 2).
]=]
export type ItemDefinitionBase = {
	name: string,
	rarity: string, -- validated against ItemConstants at registration
	description: string?,
	icon: string?,
}

-- NOTE: these are FLAT (not `ItemDefinitionBase & { kind: ... }` intersections) by deliberate
-- design, per Decision 5 of the item-definition-model spec: Luau's expected-type propagation does
-- not reach through an intersection into a table constructor, which forced literal-to-literal
-- `:: "weapon"` casts on every item definition. Flattening (repeating ItemDefinitionBase's fields
-- in each variant — same runtime shape, verified with luau-lsp) lets every item literal typecheck
-- with zero casts. Keep these flat; do not re-intersect with ItemDefinitionBase.
export type WeaponDefinition = {
	name: string,
	rarity: string,
	description: string?,
	icon: string?,
	kind: "weapon",
	requiredLevel: number?,
	equipSlot: string, -- validated against EquipmentConstants at registration
	statBonuses: { [string]: number }?, -- keyed by StatConstants stat id
	statRanges: { [string]: { min: number, max: number } }?, -- reserved (Tier 1): guaranteed base-stat roll ranges; unused until combat
}
export type ArmourDefinition = {
	name: string,
	rarity: string,
	description: string?,
	icon: string?,
	kind: "armour",
	requiredLevel: number?,
	equipSlot: string, -- validated against EquipmentConstants at registration
	statBonuses: { [string]: number }?, -- keyed by StatConstants stat id
	statRanges: { [string]: { min: number, max: number } }?, -- reserved (Tier 1): guaranteed base-stat roll ranges; unused until combat
}
export type ConsumableDefinition = {
	name: string,
	rarity: string,
	description: string?,
	icon: string?,
	kind: "consumable",
	stackMax: number,
	maxStacks: number?,
}
export type MiscDefinition = {
	name: string,
	rarity: string,
	description: string?,
	icon: string?,
	kind: "misc",
	stackMax: number?,
	maxStacks: number?,
	questItem: boolean?,
}

export type ItemDefinition = WeaponDefinition | ArmourDefinition | ConsumableDefinition | MiscDefinition

-- Currency uses CurrencyType as keys
export type Currency = {
	[CurrencyType]: number,
}

--[=[
	The persisted progression state — deliberately TWO fields. Level is DERIVED from totalXp
	(StatFormulas.levelOf) and unspent point pools are DERIVED (earned - invested), so neither can
	desync and neither can be inflated. Do not add stored level/pool counters back.
]=]
export type StatsSlice = {
	totalXp: number,
	investments: { [string]: number },
}

--[=[
	The account-wide titles slice: which titles the player has EARNED, once, about the player
	themselves (titles design spec, Decision 2). A wrapper map keyed by title id with values always
	`true` — the same set-shape Entitlements.cosmetics uses. Ids are plain strings (not a registry
	union) because retirement must stay migration-free; the validator tolerates unknown ids on
	purpose (the retired-cosmetic rule) while rejecting malformed structure.
]=]
export type Titles = {
	earned: { [string]: boolean },
}

--[=[
	A character slot's equipped-title wrapper (titles design spec, Decision 2): WHICH of the
	account's earned titles THIS character wears. Wrapped in a table (not a bare `equipped:
	string?` field) on the same terms as `Inventory`/`Equipment` — so a future field can be added
	without reshaping every `PlayerSlot.equippedTitle` reader/writer. Absent `equipped` = wearing
	nothing.
]=]
export type EquippedTitle = {
	equipped: string?,
}

--[=[
	One character slot. Every slot-scoped domain slice registers a field here.

	INVARIANT: a slot is a SELF-CONTAINED SUBTREE — it must never hold a reference into another slot.
	That is what keeps a slot liftable into its own DataStore key later, if one ever outgrows the
	shared 4MB budget, without reshaping domain code.
]=]
export type PlayerSlot = {
	currency: Currency,
	inventory: Inventory,
	stats: StatsSlice,
	equipment: Equipment,
	bank: Bank,
	appearance: Appearance,
	-- What THIS character wears of the account's earned titles (per-slot by design — different
	-- characters wear different titles; see PlayerDataTypes.EquippedTitle).
	equippedTitle: EquippedTitle,
	-- Extend with other SLOT-SCOPED slices here (hotbar, ...)
}

--[=[
	Account-wide data: entitlements and collections — "you own this". Idempotent by nature, therefore
	safe to share across characters. Quantities and item instances do NOT belong here (see the
	character-slots design: they must live under exactly one atomic owner).
]=]
export type PlayerAccount = {
	unlockedSlots: { number },
	itemMint: ItemMint,
	entitlements: Entitlements,
	-- Account-wide earned titles: earning a title is about the player, once (titles design spec,
	-- Decision 2).
	titles: Titles,
	-- Extend with other ACCOUNT-WIDE slices here (settings, ...)
}

--[=[
	Which character the player is currently playing.

	A TABLE, not a bare `activeSlot: number`, for a load-bearing reason: `mutate` hands a mutator the
	VALUE at a path and expects in-place mutation (its return value is only a "did anything change"
	flag). A number cannot be mutated by reference, so a scalar path is READ-ONLY through the data
	layer — a bare `activeSlot` could never be switched. Wrapping it in a table makes it writable
	without changing the atomicity core's contract. DO NOT "simplify" this back into a scalar: that
	silently breaks the slot switch.

	Core profile state, not a domain slice: PlayerDataService and StateSyncSliceRegistry both read it, and
	neither can depend on SlotService (SlotService depends on PlayerDataService — the reverse would
	invert the dependency).
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

-- NOTE: the old InventoryItem/ExpandedInventoryItem display-merge types are DELETED as of the
-- { items } inventory wrapper (Task 3 of the item-definition-model spec). Their consumers
-- (InventoryUtils, InventoryServiceServer, and the display-expansion path) are rewritten against
-- StackEntry/UniqueEntry in Tasks 4-5.

export type PlayerDataServiceConfigs = {
	useMock: boolean,
	storeName: string,
	template: PlayerProfile,
}

-- This module is types-only at runtime — every export above is an `export type`. Consumers
-- `require()` it purely for type annotations (e.g. `PlayerDataTypes.Currency`), never for a value.
return {}
