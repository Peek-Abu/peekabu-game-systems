# Design — Inventory & Item Model (Refactor Phase 3a)

**Status:** approved · **Date:** 2026-07-15 · **Phase:** 3a of the Venture port (Phase 3 = Inventory + Equipment, decomposed: 3a items/inventory → 3b equipment/stats → later affix-effects/transmog/bank/trading)

## Purpose

The item model every later system stands on — equipment (3b), drops, shops, bank, trading. 3a is a
**foundation phase**: visible behaviour barely changes (the reference InventoryService can already
add/remove items), but after it, items are **dupe-safe and rebalance-friendly by construction**.

## Governing principle — and an explicit evidence warning

Old code is evidence, not a source (see the Phase 1 spec). **For this domain specifically the
evidence gets extra suspicion:** the old equipment/weapon/armour system was the first system the
developer built while learning to code — likely the worst code in the old game. From it we keep only
bare feature facts: *weapons and armour exist; there are rarities; consumables stack; transmog is a
liked feature; gear affects stats.* Every structural choice it made is rejected unexamined:

| Rejected from the old game | Why |
|---|---|
| Seven inventory buckets (`Weapons/Armours/Appearances/Items/Tames/Tomes/Emotes`) | Grouping is a UI concern, not a storage concern |
| GUID string identity inside deep-copied tables | Identity was advisory; nothing prevented two copies of one item |
| Equip = two separate datastore writes | Non-atomic; a failure between them drops or dupes an item |
| Dual definition registries (server + client copies that drift) | One source of truth or none |
| Full definition deep-copied into every saved item | Bloat, and rebalancing became impossible — nerfs never reached granted items |
| Per-instance `Level`/`Experience` on gear | Aspirational schema; nothing consumed it (see Future extensions) |

## Decision 1 — Ownership is structural: container-owns-item

An item **is** an entry in exactly one container array inside the profile (the `inventory` slice
now; an equipment slot in 3b; the bank later). There is no item lookup table and no reference
indirection — **ownership is physical location in the profile tree.**

Moving an item is one `mutate`/`transaction` that removes it from one container and inserts it into
another, all inside the same ProfileStore key → atomic, and **duplication is structurally
impossible** — the identical argument that made cross-slot dupes impossible in Phase 1. When 3b adds
equipping, it is ONE transaction moving an entry from the inventory array into an equipment field —
never the old game's two writes with a crash window between them.

Rejected alternative: item map + uid references (`items = { [uid]: item }` + containers holding uid
lists). O(1) lookup, but two structures that can disagree — the "identity is advisory" disease with
better hygiene.

## Decision 2 — Saved vs static: an instance is a reference plus a delta

> **Persist only what cannot be re-derived from `itemType → definition`.**

| | Where it lives | Examples |
|---|---|---|
| **Static** (never saved) | `ItemDefinitions` | name, rarity, kind, stack rules, description, asset ids; (3b:) base stats, affix pools, equip slot + requirements |
| **Per-instance** (saved) | the inventory entry | `itemType` (the pointer), `quantity` or `uid`, (3b:) `affixes` — the *rolled outcomes* only |

Consequence, stated so nobody is surprised: **editing a definition retroactively rebalances every
existing item** (same property as the XP-curve change re-levelling everyone). Pre-launch free;
post-launch it is exactly how live games patch. The only thing a nerf cannot touch is the rolled
delta — correct, because the roll is that instance's identity.

## Decision 3 — Item identity: string uids, account-scoped counter, opaque

Unique items carry `uid = "{mintingUserId}_{counter}"` (e.g. `"8317_42"`).

- **The counter is ACCOUNT-scoped** (one `nextUid` in the account slice, minted via an atomic
  cross-slice transaction). NOT per-slot: a per-slot counter mints `"8317_7"` twice (once per
  character), and the two collide the moment items cross slots (shared stash, bank withdrawals).
  Account-scoped uids are unique per player forever — across slots, slot rerolls, and storage.
- **Why a string with the userId prefix:** global uniqueness at mint that **survives transfer**. A
  traded item cannot collide with the recipient's uids (theirs have a different prefix), so identity
  is stable for the item's lifetime — trade receipts, market listings, and audit trails keep a
  permanent reference. (This removes the re-mint-on-transfer contract an integer uid would force.)
- **Uids are OPAQUE.** Nothing may parse the prefix for logic — provenance display, if ever wanted,
  becomes an explicit field. (Also: Studio test players have negative UserIds — `"-1_7"` — which
  strings carry fine and a naive parser would not.)
- **Size is a non-issue** (recorded because it was asked): numbers/strings serialize as decimal
  digits, so cost grows logarithmically — a counter at 315 billion (a tryhard minting 1000
  items/second for ten years) stores in 12 characters; Luau integers are exact to 2^53.

## Decision 4 — One flat container; stackable/unique union shape

```lua
-- account slice (new): the mint counter
itemMint = { nextUid = 1 }

-- slot-scoped `inventory` slice (replaces the reference shape)
inventory = {
	items = {
		{ itemType = "wood",       quantity = 12 },              -- stackable
		{ itemType = "rusted_saw", uid = "8317_42" },             -- unique; 3b adds `affixes?`
	},
}
```

- One flat array. UI tabs derive from the definition's `kind` — presentation, not storage.
- Exactly-one-of shape: a stackable entry has `quantity` and no `uid`; a unique entry has `uid` and
  no `quantity`. The definition's kind decides which shape an `itemType` uses.
- The `affixes?` field is **reserved in the schema in 3a** (typed, documented) but nothing writes or
  reads it until 3b — per the decomposition decision.

## Decision 5 — Definitions: one registry, tagged unions over a base intersection

One `ItemDefinitions` module (shared realm — a single source, replacing the base's placeholder
registries; explicitly rejecting the old dual server/client worlds). No class hierarchies — tagged
unions, with common fields DRY'd through an intersection:

```lua
type ItemDefinitionBase = {
	name: string,
	rarity: Rarity,        -- "common" | "uncommon" | "rare" | "epic" | "legendary" | "cursed"
	description: string?,
}

export type WeaponDefinition     = ItemDefinitionBase & { kind: "weapon" }     -- 3b: stats, slot, requirements
export type ArmourDefinition     = ItemDefinitionBase & { kind: "armour" }     -- 3b: same
export type ConsumableDefinition = ItemDefinitionBase & { kind: "consumable", stackMax: number, maxStacks: number? }
export type MiscDefinition       = ItemDefinitionBase & { kind: "misc", stackMax: number?, questItem: boolean? }

export type ItemDefinition = WeaponDefinition | ArmourDefinition | ConsumableDefinition | MiscDefinition
```

- `misc` is the catch-all for key items, drops, materials — everything that is not gear and not a
  consumable. Adding a kind later (tomes, tames) is one union member + one validator branch.
- Rarities: the six, including `cursed` (Venture-flavoured; ties to the Rot theme).
- Caveat on record: if Luau's checker chokes on deep unions-of-intersections, the fallback is
  flattening the variants — same runtime shape, purely a type-authoring change. The strict gate
  decides.

## Decision 6 — Capacity and add semantics

- **Per-kind caps, in config, validator-enforced** (e.g. 30 weapons, 30 armour, N consumable
  stacks — one table in `ItemConstants`, tunable without code changes). Bounds profile size at the
  data layer.
- **`addItem` is all-or-nothing.** If the whole grant does not fit (stack caps, kind caps), it
  refuses with a reason and writes NOTHING. Callers (drops, shops, quests) decide how to handle a
  refusal. No partial grants, no silent overflow.

## The slice validator (data layer; holds for ANY write path)

1. Every `itemType` is registered in `ItemDefinitions` (unknown → rejected; same rule as currency/stats).
2. Entry shape matches the definition's kind (stackable xor unique).
3. Quantities are positive integers ≤ `stackMax`; per-type stack counts ≤ `maxStacks`.
4. Per-kind caps respected.
5. Uids well-formed and **unique within the profile** — belt-and-braces on top of structural
   ownership: an operations bug that duplicated a uid would make the write unstorable.
6. `itemMint.nextUid` a positive integer (its own account-slice validator).

## Service surface — `InventoryServiceServer` (evolving the reference implementation)

```
getInventory(userId)                          -> { InventoryEntry }?
addItem(userId, itemType, count?)             -> (boolean, string?)   -- all-or-nothing; mints uids for uniques
removeItem(userId, { uid } | { itemType, quantity }) -> (boolean, string?)
hasItem(userId, itemType, quantity?)          -> boolean
inventoryOp(userId, fn)                       -> TransactionOperation
```

Uid minting reads/increments `itemMint.nextUid` (account) and inserts the item (slot inventory) in
ONE transaction. The Cmdr test surface: `giveitem`, `removeitem` (admin group, as usual). The client
half remains a read facade over the synced slice.

## Testing (spec-first, the cases that matter)

- Stack merge/spill/caps; all-or-nothing refusal writes nothing (balance unchanged after refusal).
- Uid minting: sequential, account-scoped — minting on slot 1 then slot 2 never repeats a uid; the
  mint transaction is atomic (counter and item commit or roll back together).
- Validator: unknown type, malformed shape (stackable with uid, unique with quantity), duplicate
  uid, cap violations — each rejected and rolled back.
- Slot isolation re-proven for the new shape; the migrated reference-InventoryService tests survive
  with meaning intact (rename-level churn only).

## Future extensions (named so intent isn't lost; NOT in 3a)

- **Item leveling / evolutionary weapons** — discussed, no design yet. Lands as an optional
  per-instance field (`level: number?`) on the relevant kinds when designed; readers default nil →
  base. No migration needed then; no dead schema now.
- **Provenance display** ("crafted by X") — an explicit field stamped at mint, never parsed from uid.
- Affix rolling/effects (3b), equipment (3b), transmog/enchantments/set bonuses (post-3b), bank +
  shared stash, trading (which inherits the stable-uid contract above).
