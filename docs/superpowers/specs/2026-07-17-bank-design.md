# Design — Bank / Per-Slot Stash (Refactor Phase 4)

**Status:** draft · **Date:** 2026-07-17 · **Phase:** 4 of the Venture port (follows 3a Inventory, 3b
Equipment; the roadmap's "Bank (per-slot stash)" entry)

## Purpose

A second container a character can move items and currency into and out of — overflow storage that
isn't part of the character's active loadout/bag. Inherits every structural guarantee 3a/3b already
built (stable account-scoped uids, container-owns-item, atomic cross-container moves) rather than
inventing new ones.

## Governing principle — an explicit evidence warning (reaffirmed, not just inherited)

Per [[old-code-is-evidence-not-source]] (project memory): the old game's bank (`BankHandler` +
a parallel, never-fully-migrated `Services.BankingService`) is evidence of the FEATURE ("players want
overflow storage for items and gold"), not of the SHAPE — its actual scope (account-wide vs. per-slot)
is a live dispute (this doc's own discovery-pass inventory calls it "per-account," but that description
was never confirmed against a read of the actual module source, and the developer's recollection is
the opposite — per-slot). **This is deliberately NOT re-litigated by re-reading the live Studio place**,
because the scope decision below does not depend on the answer either way: whatever the old game did,
Decision 1 is a from-first-principles call, not a port. Two parallel legacy implementations existing
side-by-side (`BankHandler` legacy vs. `Services.BankingService` Knit) is itself a symptom of exactly
the kind of drift this refactor exists to prevent — neither is a reference to port, regardless of scope.

## Decision 1 — Bank is per-slot (character-scoped), not account-wide

**Chosen (developer's explicit call):** each character slot gets its own `bank`, isolated from every
other slot on the account — the same slot-scoping as `inventory`, `equipment`, and `currency`. A player
with three character slots has three independent banks.

**Rejected alternative — one shared account-wide bank.** A shared stash all characters on an account
can pull from (the more common "stash box" pattern in genre precedent, and what this doc's own
discovery-pass inventory *believed* the old game did — see the caveat above). Was raised and explicitly
declined: this game's characters are meant to stay independent, not share a back-door item/gold pipe
between slots. (Note the tension this creates with the existing account-scoped uid-mint counter — that
counter's job is only "no uid collision ever," not "items are transferable between slots"; a per-slot
bank does not reopen the cross-slot-dupe question 3a's design closed, because bank items still live in
exactly one slot's subtree at a time, satisfying `PlayerSlot`'s self-contained-subtree invariant.)

## Decision 2 — Bank slice shape: items AND currency, mirroring their slot-scoped sources exactly

```lua
-- PlayerDataTypes.luau addition
export type Bank = {
	items: { InventoryEntry },       -- same union Inventory uses; no new entry shape
	currency: Currency,              -- same shape as PlayerSlot.currency; every CurrencyType storable
}

-- PlayerSlot gains:
bank: Bank,
```

Raised and folded in during brainstorming (not in the original roadmap one-liner): the bank stores
**both** items and currency (e.g. jaku), not items alone. Reusing `InventoryEntry` and `Currency`
verbatim — not parallel types — means the bank's validator can reuse Inventory's and Currency's
existing shape-checking logic almost entirely (Decision 5) instead of re-deriving entry/currency rules
from scratch.

## Decision 3 — Capacity: items get a flat total-entry cap; currency reuses the existing per-type cap

**Items — flat cap, not per-kind (chosen over Inventory's model):** `BankConstants.CAPACITY` is one
number (e.g. 60) bounding the TOTAL entry count in `bank.items`, regardless of kind — a stack entry and
a unique entry each count once, identical counting rule to Inventory's per-kind cap ("a stack counts
once regardless of quantity"), just summed across all kinds instead of bucketed per kind. Chosen over
mirroring Inventory's per-kind caps because a stash is conceptually one storage pool, not
kind-partitioned bag space; a flat cap is also the simpler, more common "bank slots" mental model
(matches how many MMOs present bank space to players).

**Currency — no bank-specific cap; reuses `CurrencyConstants.MAX_CURRENCY` per currency type,** the
same ceiling `currency` already enforces. No separate "how much gold can the bank hold" concept — a
bank currency balance is bounded exactly like a slot currency balance is.

## Decision 4 — Item transfers move a whole holding, never a partial quantity

**Chosen:** deposit/withdraw of a stackable `itemType` always moves the caller's ENTIRE holding of
that itemType (summed across however many stack entries it happens to be split into on the source
side — see `stackLimitsOf`/`maxStacks`, which can already spill one itemType across multiple stack
entries) in one operation. There is no quantity parameter for items. On the destination side, the moved
total is placed using the exact same merge-then-spill placement rule `InventoryServiceServer`'s
`planStackPlacement` already implements (merge into any existing same-itemType stack up to `stackMax`,
open additional stacks only if the itemType's own `maxStacks` and the container's cap allow it) — see
Decision 5, this is generalized and reused, not reimplemented.

**Rejected alternative — a quantity parameter, partial-stack transfers.** Explicitly declined during
brainstorming: it would require splitting one stack entry into two mid-transaction and answering a new
question ("does a stack mid-split count as 1 or 2 entries against the cap, and at what point in the
transaction") that whole-holding transfer never raises. Deferred, not foreclosed — nothing about this
schema blocks adding a quantity parameter later; `depositItem`/`withdrawItem`'s signature would just
grow an optional argument.

Unique entries transfer by `uid`, identical to how `removeItem`/`equip` already address a specific
instance — no ambiguity, no change from the existing pattern.

## Decision 5 — Shared placement/validation logic, extracted from `InventoryServiceServer`

Bank's items are the exact same `InventoryEntry` union Inventory already validates and places. Rather
than re-deriving shape checks and stack-placement math for a second container, this phase extracts two
pure modules FROM the current `InventoryServiceServer` internals (both already exist there as private
functions — `validateInventory`'s shape-checking loop and `planStackPlacement`) and parameterizes the
one policy question that actually differs between the two containers: **how a container decides
whether it has room for more entries.**

```lua
-- ContainerValidation.luau (new, ReplicatedStorage.Shared.Modules) — shape checks only, no cap policy
export type ShapeCheckResult = {
	kindCounts: { [string]: number },        -- caller applies its OWN cap policy over this
	stackCountsByType: { [string]: number }, -- maxStacks-per-itemType check happens HERE (intrinsic to
	                                          -- the item definition, not a container policy — same
	                                          -- split the current code already has between its two
	                                          -- separate validation loops)
}
function ContainerValidation.checkEntryShapes(items: { InventoryEntry }): (boolean, string?, ShapeCheckResult?)

-- ContainerPlacement.luau (new, ReplicatedStorage.Shared.Modules) — merge-then-spill planner
export type RoomCheck = (currentItems: { InventoryEntry }, kind: string, newEntriesNeeded: number) -> (boolean, string?)
function ContainerPlacement.planStackPlacement(
	items: { InventoryEntry }, itemType: string, count: number,
	stackMax: number, maxStacks: number?, kind: string, hasRoom: RoomCheck
): StackPlacement
```

- `InventoryServiceServer.validateInventory` becomes: call `checkEntryShapes`, then apply
  `ItemConstants.KIND_CAPS` per kind over the returned `kindCounts` — same behavior, same rejection
  messages, now sourced from the shared module.
- `InventoryServiceServer`'s `hasRoom` callback checks the per-kind cap (its existing rule, unchanged).
- `BankServiceServer.validateBank` calls the same `checkEntryShapes`, then applies ONE check: `sum of
  all kindCounts + newEntries <= BankConstants.CAPACITY`.
- `BankServiceServer`'s `hasRoom` callback checks the flat total cap instead of a per-kind one.

This is the second container with this exact entry shape (Bank after Inventory) — real, present
duplication, not a hypothetical future one, which is what justifies extracting now rather than
speculatively. `InventoryServiceServer`'s public behavior and test-observable rejection reasons do not
change; this is a pure internal refactor of already-shipped code, covered by its existing spec (Task 1
of the implementation plan re-runs those tests against the extracted module to prove it).

## Decision 6 — Deposit/withdraw as atomic transactions, mirroring Equipment's container-move pattern

Same shape as 3b's equip/unequip: a 2-op `PlayerDataService:transaction()`, one op per slice, applied
sequentially and rolled back together on any rejection.

**`depositItem(userId, spec: { uid: string } | { itemType: string })`:**

```lua
-- unique case
PlayerDataService:transaction({
	InventoryServiceServer:inventoryOp(userId, function(inventory)
		-- remove the `uid` entry; return false if not found
	end),
	bankSlice.op(userId, function(bank)
		table.insert(bank.items, movedEntry)  -- movedEntry captured via upvalue from the inventory op
		return true
	end),
})

-- stackable case: read total-held quantity of itemType INSIDE the inventory op (live profile read,
-- not a pre-fetch), remove every matching stack entry, then place the total into bank.items using
-- ContainerPlacement.planStackPlacement with Bank's hasRoom callback
```

`withdrawItem` is the exact inverse (bank -> inventory) and, per the same trick `unequip` already uses,
**re-enters through `InventoryServiceServer`'s own registered validator for free** — a withdrawal that
would breach the inventory's per-kind cap is refused automatically, no new cap-checking code in Bank.

**`depositCurrency(userId, currencyType, amount)` / `withdrawCurrency(...)`:** a 2-op transaction
moving a plain numeric amount between `currency` and `bank.currency`, the same shape as
`CurrencyServiceServer.currencyOp`'s own trade example in its doc comment — refuses (rolls back both
ops) if the source side doesn't have `amount`, or if the destination would exceed `MAX_CURRENCY`.

## The slice validator — `validateBank` (data layer; holds for ANY write path)

1. `bank.items`: `ContainerValidation.checkEntryShapes`, then total entry count `<=
   BankConstants.CAPACITY`.
2. `bank.currency`: identical rule to `validateCurrency` (registered type, non-negative, `<=
   MAX_CURRENCY`) — reused directly, not reimplemented (it takes a `Currency` value and has no
   Inventory-specific coupling).

## Service surface — `BankServiceServer` (new)

```
getBank(userId)                                -> Bank?
depositItem(userId, spec)                      -> (boolean, string?)   -- spec: {uid} | {itemType}
withdrawItem(userId, spec)                     -> (boolean, string?)
depositCurrency(userId, currencyType, amount)   -> (boolean, string?)
withdrawCurrency(userId, currencyType, amount)  -> (boolean, string?)
bankOp(userId, fn)                              -> TransactionOperation
```

**Registration:** `bankSlice = SliceOwner.registerSlot("bank", { items = {}, currency = {} },
reader, validateBank)`. `dependencies = { "PlayerDataServiceServer", "InventoryServiceServer",
"CurrencyServiceServer" }` (needs `InventoryServiceServer:inventoryOp` and
`CurrencyServiceServer:currencyOp` the same way `EquipmentServiceServer` needed
`InventoryServiceServer:inventoryOp`).

## Client facade + Cmdr commands

```lua
-- BankServiceClient.luau (new) — thin read facade, same shape as InventoryServiceClient/EquipmentServiceClient
getBank: (self) -> PlayerDataTypes.Bank,
```

New Cmdr commands `deposititem <target> <uid|itemType>` / `withdrawitem <target> <uid|itemType>`,
`depositcurrency <target> <currencyType> <amount>` / `withdrawcurrency <target> <currencyType>
<amount>` — admin group, surfacing the specific `(ok, reason)` string per the established pattern
(`GiveItem`/`RemoveItem`/`equipitem`/`unequipitem`).

## Testing (spec-first, the cases that matter)

- `ContainerValidation.checkEntryShapes` extraction: Inventory's FULL existing validator test suite
  re-passes unchanged against the refactored `validateInventory` (proves the extraction preserved
  behavior byte-for-byte before Bank ever touches it).
- `ContainerPlacement.planStackPlacement` generalization: Inventory's existing stack-merge/spill/cap
  tests re-pass with the `hasRoom` callback wired to the per-kind check.
- Bank validator: unknown itemType, malformed entry shape, duplicate uid, total-cap breach, unknown
  currency key, currency cap breach — each rejected and rolled back.
- Deposit/withdraw unique: moves the exact entry (uid intact); atomicity (force a rejection — e.g. bank
  at total cap — and assert nothing moved on EITHER side, real deep-equal).
- Deposit/withdraw stackable: entire holding moves (multiple source stacks of one itemType collapse
  into the destination's merge-then-spill placement); a withdrawal that would breach the inventory's
  per-kind cap is refused (re-entry through Inventory's own validator, no new Bank code).
- Deposit/withdraw currency: insufficient-balance refusal; `MAX_CURRENCY` breach refusal; both ops roll
  back together.
- Slot isolation: two character slots' banks never see each other's items/currency.

## Deliberately NOT in this phase

- **Account-wide/shared bank** (Decision 1) — per-slot only; revisit only if the developer reverses
  this explicit call.
- **NPC/location-gated access** — the developer's stated plan is a future presentation/interaction-layer
  gate (proximity to a bank NPC), not a data-layer concern; this phase's service methods are callable
  any time, the same access model Inventory/Equipment already have. Gating is layered on top later
  without touching this phase's schema or validator.
- **Partial-quantity item transfers** (Decision 4) — whole-holding only; a quantity parameter can be
  added later without a schema change.
- **Transfer fees/cooldowns** — explicitly declined; no currency deduction or cooldown timestamp state
  in this phase.
- **Per-kind bank caps** — flat total cap only (Decision 3).
