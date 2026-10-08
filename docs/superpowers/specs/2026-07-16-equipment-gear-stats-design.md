# Design — Equipment & Gear Stats (Refactor Phase 3b)

**Status:** approved · **Date:** 2026-07-16 · **Phase:** 3b of the Venture port (Phase 3 = Inventory + Equipment, decomposed: 3a items/inventory → 3b equipment/stats → later affix-effects/transmog/bank/trading)

## Purpose

Lets players equip weapon/armour items into slots, gates equipping on requirements, and wires
equipped gear's stat bonuses into the player's live derived stats (`StatFormulas.derive`). Closes
the two prerequisites recorded when Phase 3a's plan was written (see Prerequisites below) — both are
folded into this phase's own plan, not bolted on after.

## Governing principle — an explicit evidence warning (reaffirmed, not just inherited)

Per [[old-code-is-evidence-not-source]] (project memory): the old equipment/weapon/armour system was
the **first system the developer ever built while learning to code — likely the worst code in the
game**. Every structural choice from it (`AllWeapons`/`AllArmours`/`AllItems`, the `Hotbar` module)
is suspect until re-justified from first principles. This was reaffirmed explicitly during this
phase's brainstorming: gear stat bonuses in the old game are free-form string-keyed tables
(`Stats = { ["Rot Defense"] = {min=20,max=28} }`) built ad-hoc per item, called out by name as
something to actively question rather than port, alongside the instruction "the old codebase is
trash, everything should be questioned! this isn't just a basic refactor!" This applies project-wide,
not just to this phase.

One piece of old-game evidence DID change this design, and is recorded so the reasoning isn't lost:
the old game's `Hotbar` module (`ServerScriptService.Modules.Hotbar`) physically removes an item from
inventory when hotbarred (`RemoveFromInventory`/`AddToInventory`) rather than just referencing it —
i.e. it already uses a container-move pattern, not a reference. This corrected an initial assumption
during brainstorming that hotbar/quickslot assignment would be reference-based; checking the actual
code disproved that assumption. Hotbar itself is still out of scope for 3b (see below) — but when it
is designed, it should not be assumed exempt from container-owns-item.

## Prerequisites (recorded when Phase 3a's plan was written; folded into this phase)

**1. Seal-time "every declared slice is owned" assert.** `PlayerDataConstants.emptySlots()` /
`emptyAccount()` stamp type-satisfying placeholders, and the owning service's
`SliceOwner.registerSlot`/`registerAccount` overwrites the real default at module load. Nothing
currently asserts that a declared `PlayerSlot`/`PlayerAccount` field was actually registered. This
already happened once — `unlockedSlots` was hardcoded in the skeleton and owned by nobody until
Phase 1b caught it. This phase adds `equipment` to `PlayerSlot`, walking straight back into the trap
unless closed.

**2. Stat reapplication moves from imperative to mirror-subscription.** `StatsServiceServer`
currently calls `reapplyToOnlineCharacter` imperatively from `invest`/`respec`/`addExperience`. That
only covers writes going through those methods. Equipment forces the issue structurally: the writer
of an equip/unequip change is `EquipmentServiceServer`, not `StatsService`, so the imperative pattern
would require every future stat-affecting write path (in any service) to remember to poke Stats.
Switch to subscribing to the committed slice mirrors instead.

## Decision 1 — Extensible slot registry (not a fixed slot-name union)

The user's stated goal: match the old game's real slot granularity (helmet/pauldrons/chestplate/
greaves, weapon) now, without impeding future slots (trinkets, rings, cloaks, ranged weapons) later.
A closed union of slot names would make each new slot a schema change; a registry does not.

```lua
-- EquipmentConstants.luau (new) — mirrors ItemConstants' registry pattern exactly
export type EquipSlotId = string  -- dynamic registry key, same rationale as ItemKind (limitations.md #3)

SLOTS: { [EquipSlotId]: { acceptsKind: string } } = {
	weapon     = { acceptsKind = "weapon" },
	helmet     = { acceptsKind = "armour" },
	pauldrons  = { acceptsKind = "armour" },
	chestplate = { acceptsKind = "armour" },
	greaves    = { acceptsKind = "armour" },
	-- later: trinket, ring, cloak, ranged — each is one new entry, nothing else changes
}
```

Adding a slot later is one registry entry, matching how adding an item kind or rarity is one
registry entry in `ItemConstants`.

## Decision 2 — Weapon subtype deferred

The old game's weapon `Type` field (`One-HandSword`/`Polearm`/`Greatsword`/`Fist`/`Shield`, driving
mainhand/offhand/dual-wield/two-handed slot assignment) is **not** modeled in 3b. A single generic
`weapon` kind and one `weapon` slot is enough until combat — explicitly the LAST phase of the entire
refactor — actually needs subtype-specific behavior. Revisit then, not now.

## Decision 3 — Container-owns-item, continued: equip is a container move

Phase 3a's whole architecture is container-owns-item: an item exists in exactly one container,
making dupes structurally impossible by construction, not by validation. Equipment continues this
principle rather than introducing a reference/pointer model:

**Rejected alternative — reference by uid, item stays in `inventory.items`.** Two structures
(inventory's cap/shape validator and the equipment slice) would both need to agree on what "equipped"
means, but neither owns that fact alone. A raw `removeItem` call could delete an equipped item out
from under the equipment slot with nothing to stop it, short of new cross-slice checks bolted onto
every inventory mutation path — manually-maintained invariants, not structural ones. It also raises
an unresolved double-counting question (does an equipped item still count against the inventory kind
cap?) that the move model sidesteps entirely.

**Chosen: equipping physically relocates the entry.** `Equipment.slots: { [EquipSlotId]:
PlayerDataTypes.UniqueEntry }` — the slot holds the actual moved `UniqueEntry` (uid and all), not a
uid string. Only unique entries (weapon/armour) can ever be equipped; stacks never move here (see
Decision 6, hotbar).

## Decision 4 — Fixed stat bonuses now; affix rolling deferred, with research first

`UniqueEntry.affixes?: { [string]: number }` was reserved (unread) in Phase 3a specifically for this.
3b uses it to store a **fixed, deterministic** bonus per equipped instance — no rolling/RNG yet. Full
affix rolling (min/max ranges rolled at grant time, matching the old game's `Stats = {name =
{min,max}}` mechanic) is deferred to its own future phase, explicitly so it gets a proper
cross-game-precedent research pass before a schema is committed to, rather than reverse-engineering
one arbitrary old-game table. Deferring the mechanism does not require deferring the field: swapping
"fixed" for "rolled" later needs no schema change, only a different value at grant time.

**Bonuses target the existing `StatConstants` registry, not a parallel key space.** A gear bonus is
`{ [StatConstants.STAT_IDS entry]: number }` — validated the same way `stats.investments` already
validates unknown keys. This was an explicit decision to NOT repeat the old game's ad-hoc
free-form string keys (`"Rot Defense"`), per the governing principle above.

```lua
-- PlayerDataTypes.luau additions
export type Equipment = { slots: { [string]: PlayerDataTypes.UniqueEntry } }

-- WeaponDefinition / ArmourDefinition gain:
requiredLevel: number?,                  -- gates equip via StatFormulas.levelOf(stats.totalXp)
equipSlot: string,                       -- an EquipmentConstants.SLOTS key
statBonuses: { [string]: number }?,      -- StatConstants.STAT_IDS key -> flat bonus (fixed, not rolled)

-- PlayerSlot gains (the field name PlayerSlot's own comment already reserved):
equipment: Equipment,
```

## Decision 5 — `StatFormulas.derive` gains a `sources` parameter, per its own doc comment's plan

`StatFormulas`'s header already states: *"Phase 3 (equipment) will extend `derive` with a `sources`
parameter (named modifier layers) — an extension of this module, not a parallel system."* This phase
fulfills that:

```lua
function StatFormulas.derive(investments: {[string]: number}, sources: {{[string]: number}}?): {[string]: number}
	local derived = {}
	for id, definition in StatConstants.DEFINITIONS do
		local value = definition.base + (investments[id] or 0) * definition.perPoint
		if sources then
			for _, source in sources do
				value += source[id] or 0
			end
		end
		derived[id] = value
	end
	return derived
end
```

`StatsServiceServer.getDerived` gains a dependency on `EquipmentServiceServer` and passes its
aggregated equipped-bonus map as the one `sources` entry:

```lua
getDerived = function(self, userId)
	local stats = self:getStats(userId)
	if not stats then return nil end
	local bonuses = EquipmentServiceServer:getAggregatedBonuses(userId)
	return StatFormulas.derive(stats.investments, { bonuses })
end,
```

**Nothing derived is ever stored or replicated** — unchanged from Phase 2. Only the raw `stats`
(`{totalXp, investments}`) and `equipment` (`{slots}`) slices sync via charm-sync; both realms call
the same pure `derive` locally over their own copy. `getAggregatedBonuses` sums each equipped entry's
`statBonuses` (looked up via `ItemDefinitions.get(entry.itemType)`) — cheap, recomputed on demand,
never cached.

## Decision 6 — Mirror-subscription replaces imperative reapplication

`StatsServiceServer.applyToCharacter` (unchanged) reads `getDerived` and sets
`Humanoid.MaxHealth`. What changes is *when* it re-runs: instead of imperative calls scattered across
`invest`/`respec`/`addExperience`, subscribe per-player to both the `stats` and `equipment` mirrors:

```lua
start = function(self)
	janitor:Add(Observers.observeCharacter(function(player, _character)
		self:applyToCharacter(player)  -- existing spawn-time application, unchanged

		local userId = player.UserId
		local statsSelector = Charm.computed(function() return ServerStore.stats()[userId] end)
		local equipmentSelector = Charm.computed(function() return ServerStore.equipment()[userId] end)
		local unsubStats = Charm.subscribe(statsSelector, function() self:applyToCharacter(player) end)
		local unsubEquip = Charm.subscribe(equipmentSelector, function() self:applyToCharacter(player) end)
		return function() unsubStats(); unsubEquip() end  -- torn down on character removal
	end))
end,
```

`Charm.computed` selectors only notify subscribers when the *computed value itself* changes
(shallow-equal), so a per-player selector over the whole-map atom solves the "naive subscribe fires
for every player on any player's change" wrinkle recorded when this prerequisite was first noted —
without inventing new machinery (Charm is already a dependency). The imperative
`reapplyToOnlineCharacter` calls in `invest`/`respec`/`addExperience` are deleted entirely — every
committed write to either slice, through any path (including a future raw `transaction()` op neither
service anticipated), now triggers reapplication structurally.

## Decision 7 — Seal-time ownership assert

```lua
-- PlayerDataConstants.seal() — extended
function PlayerDataConstants.seal()
	sealed = true

	for slotField in PlayerDataConstants.PROFILE_TEMPLATE.slots[1] do
		assert(registeredSliceNames[slotField] ~= nil,
			`[PlayerDataConstants] slot field "{slotField}" is declared in PlayerSlot but was never `
				.. "registered via registerSlotPath — this would ship an ownerless, unvalidated slice "
				.. "to every player.")
	end
	for accountField in PlayerDataConstants.PROFILE_TEMPLATE.account do
		assert(registeredSliceNames[accountField] ~= nil,
			`[PlayerDataConstants] account field "{accountField}" is declared in PlayerAccount but was `
				.. "never registered via registerAccountPath.")
	end
end
```

Works because `PlayerDataConstants` already tracks `registeredSliceNames` (slice name → registration
pattern) for exactly this kind of check. This closes the `unlockedSlots`-was-ownerless-until-caught
class of bug permanently, not just for `equipment` — every slice declared after this, in any future
phase, is covered by the same assert.

## Service surface — `EquipmentServiceServer` (new)

```
getEquipment(userId)                  -> Equipment?
equip(userId, uid)                    -> (boolean, string?)   -- all-or-nothing; auto-swaps an occupied slot
unequip(userId, slotId)               -> (boolean, string?)
equipmentOp(userId, fn)               -> TransactionOperation
```

**Registration:** `equipmentSlice = SliceOwner.registerSlot("equipment", { slots = {} }, reader,
validateEquipment)` — slot-scoped, same as `inventory`. `equipmentOp` is `equipmentSlice.op`'s public
wrapper, the same shape as `InventoryServiceServer.inventoryOp` — the mechanism 3a already built for
exactly this composition need.

**`equip(userId, uid)`:** finds the entry by uid (`InventoryUtils.findByUid`), refuses if not found,
refuses if the item's kind doesn't match any `EquipmentConstants.SLOTS` entry's `acceptsKind`,
refuses if `requiredLevel` exceeds `StatFormulas.levelOf(stats.totalXp)`. Then a **3-op**
`PlayerDataService:transaction()` (chosen over refuse-if-occupied, for one-call swap UX). Note:
`equipmentSlice` is a private module-level local inside `EquipmentServiceServer.luau` — it can build
ops on itself directly — but `EquipmentServiceServer` has no access to `InventoryServiceServer`'s
private `inventorySlice` local, so the inventory-side ops go through `InventoryServiceServer`'s
already-public `inventoryOp(userId, fn)` method instead (the same composition mechanism 3a's own
service surface already exposes for this purpose):

```lua
local previousOccupant: PlayerDataTypes.UniqueEntry? = nil
local ok, reason = PlayerDataService:transaction({
	InventoryServiceServer:inventoryOp(userId, function(inventory)
		-- remove the `uid` entry from inventory.items
		return true
	end),
	equipmentSlice.op(userId, function(equipment)
		previousOccupant = equipment.slots[slotId]  -- upvalue; nil if the slot was empty
		equipment.slots[slotId] = newEntry
		return true
	end),
	InventoryServiceServer:inventoryOp(userId, function(inventory)
		if previousOccupant then
			table.insert(inventory.items, previousOccupant)
		end
		return true  -- no-op when the slot was empty; still one consistent 3-op shape
	end),
})
```

This touches the `inventory` slice twice in one transaction (remove-new, then conditionally
insert-old) via two separate `inventoryOp` calls — a new usage shape compared to 3a's mint
transaction (which always alternated between exactly two *different* slices). Still safe under the
same mechanism (ops apply sequentially against the live profile, rollback-together on any
rejection) — flagged here because it needs explicit test coverage, not because the guarantee is in
doubt. `EquipmentServiceServer` gains a `dependencies = { "PlayerDataServiceServer",
"InventoryServiceServer" }` entry for this.

**`unequip(userId, slotId)`:** the inverse move, back into `inventory.items`. Because it re-enters
through the *same* registered `inventory` validator, an unequip that would breach a kind cap (bag
already full) is refused automatically — no new cap-checking code needed.

**`validateEquipment`:** each occupied slot's entry matches that slot's `acceptsKind` (defense in
depth beyond the service-level check), and no uid appears in more than one slot.

## Client facade + Cmdr commands

```lua
-- EquipmentServiceClient.luau (new) — thin read facade, same shape as InventoryServiceClient
getEquipment: (self) -> PlayerDataTypes.Equipment,
getEquippedInSlot: (self, slotId: string) -> PlayerDataTypes.UniqueEntry?,
```

New Cmdr commands `equipitem <target> <uid>` / `unequipitem <target> <slotId>`, following
`GiveItem`/`RemoveItem`'s exact pattern (admin group, surfacing the specific `(ok, reason)` string —
per the fix applied to those commands during Phase 3a's PR review, not the generic-message mistake
that shipped first).

## Testing (spec-first, the cases that matter)

- Validator direct-call cases: unknown slot, kind mismatch (armour in the weapon slot), duplicate
  uid across two slots.
- The 3-op transaction: equip into an empty slot; equip-with-swap into an occupied slot (assert the
  old entry lands back in `inventory.items` intact); atomicity (force a rejection — e.g. a
  level-requirement or kind-mismatch the validator itself catches — and assert nothing moved:
  inventory AND equipment both unchanged, real deep-equal).
- Unequip triggering inventory's own kind-cap validator (bag already at cap → unequip refused,
  equipment unchanged).
- Seal-time assert: positive case (current tree, nothing ownerless) and negative case (a synthetic
  declared-but-unregistered field throws) — mirroring `SpecRoots.spec`'s own test style for its
  analogous guard.
- `Charm.computed` subscription fires `applyToCharacter` on a `stats` change AND on an `equipment`
  change independently (not just one), and does NOT fire for an unrelated player's change.
- `StatFormulas.derive`'s `sources` parameter: no sources (unchanged behavior, existing Phase 2
  tests still pass), one source, multiple stat ids in one source, a source with an unknown stat id
  (ignored, not an error — bonuses are additive contributions, not new stat declarations).

## Deliberately NOT in this phase

- **Weapon subtype / dual-wield / two-handed** (Decision 2) — single generic weapon slot until
  combat needs otherwise.
- **Affix rolling** (Decision 4) — fixed bonuses only; rolling needs its own future phase with
  cross-game research first, not a port of the old game's ad-hoc table.
- **Hotbar / consumable quickslot** — a distinct container-owning domain (stack-splitting semantics
  a `StackEntry` doesn't have a uid for) that deserves its own dedicated design pass when combat
  actually needs a "use in combat" verb — not exempt from container-owns-item when it lands (see the
  governing-principle section above).
- **Transmog / enchantments / set bonuses** — post-3b, unchanged from 3a's original scoping. Note for
  whoever picks this up: the old game's `chambered helmet/pauldrons/chestplate/greaves` really is a
  4-piece set (`Set = "chambered"` in the real data) — relevant when set bonuses are eventually
  designed, not before.
- **Bank / stash / trading** — unchanged from 3a's original scoping.
