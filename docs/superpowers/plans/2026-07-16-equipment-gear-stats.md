# Equipment & Gear Stats (Phase 3b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players equip weapon/armour items into an extensible slot registry, gate equipping on level/kind requirements, and wire equipped gear's fixed stat bonuses into the player's live derived stats — closing the two prerequisites recorded when Phase 3a's plan was written (seal-time ownership assert, mirror-subscription for stat reapplication).

**Architecture:** Equipment continues Phase 3a's container-owns-item principle: equip/unequip is an atomic move of a `UniqueEntry` between the `inventory` and a new slot-scoped `equipment` slice, never a reference. A new `EquipmentServiceServer` owns the `equipment` slice; `StatFormulas.derive` gains a `sources` parameter so equipped bonuses fold into derived stats without a parallel system; `StatsServiceServer` switches from imperative reapplication calls to subscribing to the committed `stats`/`equipment` mirrors via `Charm.computed`/`Charm.subscribe`.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm (`littensy/charm@0.11.0`) + charm-sync, Observers (`sleitnick/observers@0.5.0`), Cmdr, TestEZ.

Spec: `docs/superpowers/specs/2026-07-16-equipment-gear-stats-design.md`
Branch: create `feat/equipment-gear-stats` off `main` (current tip after Phase 3a merge, commit `371d216` or later).

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification, a comment at the site, and human sign-off — do not add one without escalating first, the way Phase 3a's two approved cast sets were explicitly signed off.
- **Spec-first TDD.** `SpecRoots.assertAllModulesSpecced` fails the build for an unspecced first-party module.
- **Plain commit messages. NO `Co-Authored-By:` / `Claude-Session:` trailers.**
- **Server-authoritative.** Clients read synced slices only.
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH `wally install` — `wally-package-types` is NOT idempotent; a stale `--skip-install` run gives spurious `'REQUIRED_MODULE' is not a function call` errors). TestEZ runs on Open Cloud on a PR into `main` only.
- **No migrations** (pre-launch, data wiped) — schema changes are free.
- File-length gate: 400 code lines/module. Project-rules gate judges added lines.
- **Old-code-is-evidence, not source** (see the design spec's governing principle). Do not port the old game's `Stats = {name = {min,max}}` free-form bonus tables, weapon `Type` subtype field, or hotbar's mechanics into this phase — those are explicitly deferred, and gear bonuses target the EXISTING `StatConstants.STAT_IDS` registry, never a parallel key space.
- **Circular-require hazard (read before Tasks 3–4):** `EquipmentServiceServer` needs to read `StatsServiceServer:getStats(userId)` (for the equip-time level check) and `StatsServiceServer` needs to read `EquipmentServiceServer:getAggregatedBonuses(userId)` (for derived stats). A normal top-of-file `require()` in BOTH directions is a genuine Lua circular-require bug (one side gets a partial module table), not just an ordering nicety — `dependencies` arrays only affect ServiceController's init/start ordering, they do NOT prevent this. Task 3 requires `StatsServiceServer` normally, at the top of `EquipmentServiceServer.luau`. Task 4 MUST require `EquipmentServiceServer` LAZILY (inside the function body of `getDerived`, not at the top of `StatsServiceServer.luau`) to break the cycle. Do not "fix" this by adding a `dependencies` entry instead — it does not address the actual hazard.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Constants/EquipmentConstants.luau` | **New.** Extensible slot registry (`SLOTS: { [slotId]: { acceptsKind } }`). |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | Gains `Equipment` type, `PlayerSlot.equipment`; `WeaponDefinition`/`ArmourDefinition` gain `requiredLevel?`, `equipSlot`, `statBonuses?`. |
| `src/ReplicatedStorage/Shared/Modules/GameItems.luau` | Existing weapon/armour literals (`rusted-saw`, `phoenix-blade`, `chambered-helmet`) gain the new required `equipSlot` field; `chambered-helmet` gains a real `requiredLevel`/`statBonuses` fixture matching the live game's actual data. |
| `src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.luau` | `derive` gains an optional `sources` parameter, per its own doc comment's plan. |
| `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` | Gains `emptySlots()`'s `equipment = { slots = {} }` placeholder; `seal()` calls a new, separately-testable `assertAllSlicesOwned()`. |
| `src/ReplicatedStorage/Shared/State/SliceManifest.luau` | Gains an `equipment` entry. |
| `src/ReplicatedStorage/Client/State/ClientStore.luau` | Gains an `equipment` atom + registry entry. |
| `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` | **New.** Owns the `equipment` slice: validator, `getEquipment`/`equip`/`unequip`/`equipmentOp`/`getAggregatedBonuses`. |
| `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` | `getDerived` folds in equipment bonuses; `start()` switches to `Charm.computed`/`Charm.subscribe`; imperative `reapplyToOnlineCharacter` calls deleted. |
| `src/ReplicatedStorage/Client/Services/EquipmentService/EquipmentServiceClient.luau` | **New.** Thin read facade over `ClientStore.equipment`, mirroring `InventoryServiceClient`. |
| `src/ServerScriptService/Commands/EquipItem*.luau`, `UnequipItem*.luau` | **New.** Cmdr admin commands, mirroring `GiveItem`/`RemoveItem`. |
| `src/ServerScriptService/Modules/SpecRoots.luau` | Gains `EXEMPT_MODULES` entries for the two new Cmdr command definitions. |

---

### Task 1: `EquipmentConstants` + type additions + real starter-set fixture

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/Constants/EquipmentConstants.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/GameItems.luau` (+ `.spec.luau`)

**Interfaces (produces):**

```lua
-- EquipmentConstants
export type EquipSlotId = string  -- dynamic registry key, same rationale as ItemConstants.ItemKind
EquipmentConstants.SLOTS: { [EquipSlotId]: { acceptsKind: string } }
EquipmentConstants.isValidSlot(slotId: string) -> boolean

-- PlayerDataTypes additions
export type Equipment = { slots: { [string]: PlayerDataTypes.UniqueEntry } }
-- WeaponDefinition / ArmourDefinition (both currently FLAT literals, per Phase 3a's Decision 5 —
-- keep them flat, do not re-intersect with ItemDefinitionBase) gain:
requiredLevel: number?,
equipSlot: string,
statBonuses: { [string]: number }?,
-- PlayerSlot gains (the field name its own comment already reserved):
equipment: Equipment,
```

**`EquipmentConstants.SLOTS` initial content** (matches the real live game's armour granularity per the design spec's Decision 1):

```lua
weapon     = { acceptsKind = "weapon" },
helmet     = { acceptsKind = "armour" },
pauldrons  = { acceptsKind = "armour" },
chestplate = { acceptsKind = "armour" },
greaves    = { acceptsKind = "armour" },
```

**GameItems.luau fixture updates** — every existing weapon/armour literal gains the new REQUIRED `equipSlot` field (a missing required field is a type error, so this task cannot skip any of them):
- `rusted-saw` (`WeaponDefinition`): `equipSlot = "weapon"`.
- `phoenix-blade` (`WeaponDefinition`): `equipSlot = "weapon"`.
- `chambered-helmet` (`ArmourDefinition`): `equipSlot = "helmet"`, PLUS `requiredLevel = 8` and `statBonuses = { rotEndurance = 8 }` — real values from the live game's `AllArmours.Chambered` module (`Required Level = 8`, `Stats = { ["Rot Defense"] = {min=20,max=28} }`; `rotEndurance` is the closest existing `StatConstants` id conceptually, and 8 is a reasonable fixed-bonus midpoint of the old range's floor — this is the ONE piece of gear this phase needs a non-nil `statBonuses`/`requiredLevel` fixture on, for Tasks 3–4's tests to exercise real behavior against).

- [ ] **Step 1: Failing spec — `EquipmentConstants.spec.luau`.**

```lua
local EquipmentConstants = require(script.Parent.EquipmentConstants)

return function()
	describe("SLOTS", function()
		it("has the five starting slots, each accepting a valid kind", function()
			local expectedSlots = { "weapon", "helmet", "pauldrons", "chestplate", "greaves" }
			for _, slotId in expectedSlots do
				expect(EquipmentConstants.SLOTS[slotId]).to.be.ok()
			end
		end)

		it("assigns weapon to the weapon kind and the rest to armour", function()
			expect(EquipmentConstants.SLOTS.weapon.acceptsKind).to.equal("weapon")
			expect(EquipmentConstants.SLOTS.helmet.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.pauldrons.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.chestplate.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.greaves.acceptsKind).to.equal("armour")
		end)
	end)

	describe("isValidSlot", function()
		it("accepts every registered slot id", function()
			for slotId in EquipmentConstants.SLOTS do
				expect(EquipmentConstants.isValidSlot(slotId)).to.equal(true)
			end
		end)

		it("rejects an unknown slot id", function()
			expect(EquipmentConstants.isValidSlot("trinket")).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Gate fails** (`bash scripts/check.sh`) — module missing.
- [ ] **Step 3: Implement `EquipmentConstants.luau`**, mirroring `ItemConstants.luau`'s house style exactly (doc comment explaining the registry role, `isValidSlot` implemented via `EquipmentConstants.SLOTS[value] ~= nil`).
- [ ] **Step 4: Add the `PlayerDataTypes.luau` type changes** (`Equipment`, `PlayerSlot.equipment`, the three new fields on `WeaponDefinition`/`ArmourDefinition`). Run `bash scripts/check.sh --skip-install` (typecheck-only pass to iterate quickly) — expect NEW errors in `GameItems.luau` (`equipSlot` missing from every weapon/armour literal) and `PlayerDataConstants.luau` (`PlayerSlot` requires `equipment`, `emptySlots()` doesn't supply it yet — this is expected, fixed in this same task's Step 5, not deferred).
- [ ] **Step 5: Add `emptySlots()`'s placeholder** in `PlayerDataConstants.luau`: change the per-slot literal from `{ currency = {}, inventory = { items = {} }, stats = { totalXp = 0, investments = {} } }` to also include `equipment = { slots = {} }`. This is the SAME "skeleton declares, registration owns" pattern the other three fields already use — the real default/validator is stamped by `EquipmentServiceServer`'s registration in Task 3, exactly like `inventory`'s real validator arrives via `InventoryServiceServer`'s registration. Do NOT add the seal-time assert yet (Task 5) — adding it now, before Task 3 registers `"equipment"`, would break EVERY test that boots the data layer, not just equipment's own.
- [ ] **Step 6: Update `GameItems.luau`'s three existing literals** with the `equipSlot` field (and `chambered-helmet`'s `requiredLevel`/`statBonuses`) per the fixture spec above.
- [ ] **Step 7: Update `GameItems.spec.luau`** — extend the existing "registers an armour piece" test to also assert `helmet.equipSlot == "helmet"`, `helmet.requiredLevel == 8`, and `helmet.statBonuses.rotEndurance == 8`; extend the weapon tests to assert `rustedSaw.equipSlot == "weapon"` and `phoenixBlade.equipSlot == "weapon"`.
- [ ] **Step 8: Gate passes** (`bash scripts/check.sh`, full run WITH `wally install`).
- [ ] **Step 9: Commit** — `feat(equipment): add EquipmentConstants slot registry and gear-stat type fields`

---

### Task 2: `StatFormulas.derive` gains a `sources` parameter

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.luau` (+ spec)

**Interfaces:**
- Consumes: `StatConstants.DEFINITIONS` (unchanged).
- Produces: `StatFormulas.derive(investments: {[string]: number}, sources: {{[string]: number}}?): {[string]: number}` — the SAME function name and first parameter, extended with an optional second parameter, so every existing call site (`StatsServiceServer.getDerived`, `StatFormulas.spec`'s existing tests) that omits it keeps working unchanged.

This task is self-contained and independent of the `equipment` slice existing — it only changes a pure function's signature.

- [ ] **Step 1: Failing spec** — add to `StatFormulas.spec.luau`'s existing `describe("derive", ...)` block:

```lua
it("with no sources argument, behaves exactly as before", function()
	local derived = StatFormulas.derive({ health = 2 })
	expect(derived.health).to.equal(StatConstants.DEFINITIONS.health.base + 2 * StatConstants.DEFINITIONS.health.perPoint)
end)

it("adds a single source's contribution on top of the derived base", function()
	local derived = StatFormulas.derive({ health = 2 }, { { health = 10 } })
	expect(derived.health).to.equal(StatConstants.DEFINITIONS.health.base + 2 * StatConstants.DEFINITIONS.health.perPoint + 10)
end)

it("sums MULTIPLE sources for the same stat id", function()
	local derived = StatFormulas.derive({}, { { health = 5 }, { health = 3 } })
	expect(derived.health).to.equal(StatConstants.DEFINITIONS.health.base + 5 + 3)
end)

it("ignores an unknown stat id in a source rather than erroring", function()
	expect(function()
		StatFormulas.derive({}, { { notARealStat = 100 } })
	end).never.to.throw()
end)

it("a source can contribute to a stat the player has zero investment in", function()
	local derived = StatFormulas.derive({}, { { stamina = 7 } })
	expect(derived.stamina).to.equal(StatConstants.DEFINITIONS.stamina.base + 7)
end)
```

- [ ] **Step 2: Run to verify RED.** `derive`'s current signature takes only `investments` — Luau will typecheck-reject a second argument, and (if run under an untyped context) the extra source contribution would silently not apply. Run `bash scripts/check.sh --skip-install`; expect `TypeError` on the new spec's second-argument call sites.
- [ ] **Step 3: Implement.**

```lua
function StatFormulas.derive(investments: { [string]: number }, sources: { { [string]: number } }?): { [string]: number }
	local derived: { [string]: number } = {}
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

- [ ] **Step 4: Gate passes** (full `bash scripts/check.sh`).
- [ ] **Step 5: Commit** — `feat(stats): StatFormulas.derive accepts modifier sources`

---

### Task 3: `EquipmentServiceServer` — the centerpiece

**Files:**
- Create: `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Shared/State/SliceManifest.luau`
- Modify: `src/ReplicatedStorage/Client/State/ClientStore.luau`

**Read `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` and `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` first** — mirror their house pattern (lean annotated-literal service shape, `SliceOwner` registration, `Guard`/assert split between developer-contract and game-state refusals).

**Interfaces:**
- Consumes: `SliceOwner.registerSlot`, `InventoryServiceServer.getInventory`/`.inventoryOp` (public methods — do NOT reach for `InventoryServiceServer`'s private `inventorySlice` local, it isn't exported), `InventoryUtils.findByUid`, `ItemDefinitions.get`, `EquipmentConstants.SLOTS`/`.isValidSlot`, `StatsServiceServer.getStats` (top-of-file `require` — this direction is safe; see Global Constraints), `StatFormulas.levelOf`.
- Produces:

```lua
getEquipment(userId) -> PlayerDataTypes.Equipment?
equip(userId, uid: string) -> (boolean, string?)
unequip(userId, slotId: string) -> (boolean, string?)
equipmentOp(userId, fn) -> PlayerDataService.TransactionOperation
getAggregatedBonuses(userId) -> { [string]: number }   -- sums every equipped entry's statBonuses; {} if nothing equipped or no profile
```

**Registration** (module scope): `equipmentSlice = SliceOwner.registerSlot("equipment", { slots = {} }, function(slot) return slot.equipment end, validateEquipment)`.

**`validateEquipment(equipment)`** — mirrors `validateInventory`'s rigor:
1. Every occupied slot key is a valid `EquipmentConstants.SLOTS` id.
2. Every occupied slot's entry's registered kind (`ItemDefinitions.kindOf(entry.itemType)`) matches that slot's `acceptsKind` (defense in depth beyond the service-level check in `equip`).
3. No `uid` appears in more than one slot.

**`equip(userId, uid)`:**
1. `Guard.userId(userId)`.
2. Read-only pre-flight (before building any transaction), capturing `definition` for use in Step 3 — `InventoryUtils.findByUid` returns TWO values, `(index: number?, entry: UniqueEntry?)`, so capture the entry with `local _, foundEntry = InventoryUtils.findByUid(inventory, uid)` (the index isn't needed here — the transaction's own op re-derives it fresh at commit time in Step 3, matching `removeByUid`'s re-lookup-inside-the-mutator pattern for freshness):

```lua
local inventory = InventoryServiceServer:getInventory(userId)
if not inventory then
	return false, `no profile loaded for userId {userId}`
end
local _, foundEntry = InventoryUtils.findByUid(inventory, uid)
if not foundEntry then
	return false, `no item with uid "{uid}"`
end
local definition = ItemDefinitions.get(foundEntry.itemType)
assert(definition, `"{foundEntry.itemType}" is in an inventory but has no ItemDefinition`)
if definition.kind ~= "weapon" and definition.kind ~= "armour" then
	return false, `"{foundEntry.itemType}" is not equippable`
end
local slotConfig = EquipmentConstants.SLOTS[definition.equipSlot]
assert(slotConfig and slotConfig.acceptsKind == definition.kind,
	`"{foundEntry.itemType}"'s equipSlot "{definition.equipSlot}" is misconfigured`)
if definition.requiredLevel then
	local stats = StatsServiceServer:getStats(userId)
	local level = if stats then StatFormulas.levelOf(stats.totalXp) else 0
	if level < definition.requiredLevel then
		return false, `requires level {definition.requiredLevel}, you are level {level}`
	end
end
```

(The `slotConfig`/`assert` above is a developer-contract check, not a player-facing refusal — it can only fail from a bad `ItemDefinitions.register` call, never from player action, so it asserts rather than returning `(false, reason)`.)

3. The 3-op swap transaction from the design spec's Decision 3/Service surface section — `movedEntry` is captured fresh INSIDE the first op (re-derived from the live inventory at commit time, not reused from the pre-flight read above, exactly like `removeByUid` re-derives its target rather than trusting a snapshot taken before the lock):

```lua
local previousOccupant: PlayerDataTypes.UniqueEntry? = nil
local movedEntry: PlayerDataTypes.UniqueEntry? = nil
local ok, reason = PlayerDataService:transaction({
	InventoryServiceServer:inventoryOp(userId, function(inv)
		local index, entry = InventoryUtils.findByUid(inv, uid)
		if not index then
			return false
		end
		movedEntry = entry
		table.remove(inv.items, index)
		return true
	end),
	equipmentSlice.op(userId, function(equipment)
		previousOccupant = equipment.slots[definition.equipSlot]
		equipment.slots[definition.equipSlot] = movedEntry
		return true
	end),
	InventoryServiceServer:inventoryOp(userId, function(inv)
		if previousOccupant then
			table.insert(inv.items, previousOccupant)
		end
		return true
	end),
})
if not ok and reason == nil then
	reason = "mutation rejected (see server logs)"
end
return ok, reason
```

**`unequip(userId, slotId)`:**
1. `Guard.userId(userId)`. Refuse `` `"{slotId}" is not a valid equipment slot` `` if `not EquipmentConstants.isValidSlot(slotId)`.
2. Refuse `"no profile loaded for userId {userId}"` if `not PlayerDataService:getActiveSlot(userId)` (checked BEFORE mutating, same pattern as `InventoryServiceServer`'s `removeByUid`).
3. Single `equipmentSlice.mutate` reading the occupant and clearing the slot, capturing it via an upvalue exactly like `removeByUid`'s pattern; refuse `` `slot "{slotId}" is empty` `` if nothing was equipped there.
4. Then `InventoryServiceServer:inventoryOp`-based insertion of the freed entry back into `inventory.items`, via a SECOND `PlayerDataService:transaction()` call composed of the equipment-clear op and the inventory-insert op (two-op, no swap needed here) — because re-entering through `InventoryServiceServer`'s registered validator is what makes a kind-cap-full bag correctly refuse the unequip with NO new cap-checking code (per the design spec's Decision 3).

**`equipmentOp`/`getAggregatedBonuses`:**

```lua
equipmentOp = function(_self, userId, fn)
	return equipmentSlice.op(userId, fn)
end,

getAggregatedBonuses = function(self, userId)
	local equipment = self:getEquipment(userId)
	local bonuses: { [string]: number } = {}
	if not equipment then
		return bonuses
	end
	for _, entry in equipment.slots do
		local definition = ItemDefinitions.get(entry.itemType)
		if definition and (definition.kind == "weapon" or definition.kind == "armour") and definition.statBonuses then
			for statId, amount in definition.statBonuses do
				bonuses[statId] = (bonuses[statId] or 0) + amount
			end
		end
	end
	return bonuses
end,
```

**`dependencies = { "PlayerDataServiceServer", "InventoryServiceServer", "StatsServiceServer" }`.**

**Required spec cases (write these FIRST, per TDD):**
- `getEquipment`/`getAggregatedBonuses` on an empty/no-profile case.
- `equip` into an empty slot (weapon and armour).
- `equip` refusals: unknown uid, wrong kind for the target slot (can't happen validly via a well-formed `ItemDefinitions` entry, so construct this via a raw slice mutation to prove the VALIDATOR catches a misconfigured entry, not the service-level check), below `requiredLevel` (use `chambered-helmet`'s real `requiredLevel = 8` fixture from Task 1 — seed a level-1 stats slice, assert refusal with the exact reason string, assert BOTH inventory and equipment unchanged via real deep-equal).
- `equip` with SWAP: equip into an already-occupied slot, assert the old entry lands back in `inventory.items` intact (deep-equal on the specific entry, not just presence).
- `equip` atomicity: force a rejection the validator itself catches (e.g. seed a duplicate-uid scenario or an invalid slot via a raw op) and assert NOTHING moved — inventory AND equipment both byte-for-byte unchanged from a pre-call snapshot.
- `unequip` moving an item back to inventory; `unequip` refusing when the bag is already at its kind cap (seed 30 armour entries via `InventoryServiceServer`, seed one equipped helmet, assert unequip refuses and the equipment slot is STILL occupied — nothing moved).
- `unequip` refusing an empty slot; refusing an invalid slot id.
- `validateEquipment` direct-call cases (via `PlayerDataServiceServer.spec.luau`'s "slice invariant validators" describe block, matching where `validateInventory`'s direct-call cases already live per Phase 3a's precedent): unknown slot, kind mismatch, duplicate uid across two slots.
- Slot isolation: equip on slot 1, switch active slot, slot 2's equipment is untouched.

- [ ] **Steps: spec first → gate fails → implement (registration, validator, `equip`, `unequip`, `equipmentOp`, `getAggregatedBonuses`) → add the `equipment` entry to `SliceManifest.DEFINITIONS` (`read = function(profile) return profile.slots[profile.slotState.active].equipment end`) → add the `equipment` atom + registry line to `ClientStore.luau` (`Charm.atom({ slots = {} } :: PlayerDataTypes.Equipment)`) → gate green (repo-wide; `StatsServiceServer` is untouched by this task, so there should be zero unexpected errors anywhere) → commit.**
- [ ] **Commit** — `feat(equipment): EquipmentServiceServer with atomic equip/unequip and gear-stat aggregation`

---

### Task 4: `StatsServiceServer` mirror-subscription refactor

**Files:**
- Modify: `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` (+ spec)

**Read the Global Constraints' circular-require note again before starting this task.**

**Interfaces:**
- Consumes: `EquipmentServiceServer.getAggregatedBonuses` (LAZY `require` — see below), `Charm.computed`/`Charm.subscribe` (`ReplicatedStorage.Packages.Charm`), `ServerStore.getterFor(slice: string, userId: number): () -> unknown` (verified in `ServerStore.luau:161` — returns `function() return entry.atom()[userId] end`, exactly the per-user reader `Charm.computed` needs; no named `stats`/`equipment` convenience export exists on `ServerStore`, only `currencies`/`inventories` do, so this generic accessor is the correct path per `ServerStore.luau`'s own header — "NOT required for new slices — generic access goes through `getterFor`/`snapshot`").
- Produces: `StatsServiceServer.getDerived` unchanged signature, new behavior; `applyToCharacter` unchanged; `reapplyToOnlineCharacter` DELETED.

**Timing, verified against the actual Charm source (`Packages/_Index/littensy_charm@0.11.0/charm/src/init.luau`):** `signalSetter` (the underlying write path for `atom(value)`) calls `propagate(subs)` then `flush()` synchronously in the same function — not deferred via `task.defer`/`RunService`. `flush()` only bails if `batchDepth ~= 0` (an active `Charm.batch(...)` wrapper, which this plan doesn't use). So `Charm.subscribe`'s callback fires SYNCHRONOUSLY, inside the same call stack as whatever committed write triggered the atom update — by the time `statsSlice.mutate(...)`/`ServerStore`'s mirroring call returns, the subscription has already fired and `applyToCharacter` has already run. This is functionally equivalent to the deleted imperative calls' timing (both guarantee `Humanoid.MaxHealth` is current by the time the outer service method returns) — existing `invest`/`respec`/`addExperience` tests that assert on post-call Humanoid state need no changes for timing reasons.

- [ ] **Step 1: Failing spec.** Add to `StatsServiceServer.spec.luau`:

```lua
it("getDerived folds in equipment's aggregated bonuses on top of investments", function()
	-- Seed a profile with stats.investments = {} and an equipped chambered-helmet (statBonuses.rotEndurance = 8, from Task 1's fixture)
	-- via the same _setProfileForTesting seam InventoryServiceServer.spec/PlayerDataServiceServer.spec use.
	local derived = StatsServiceServer:getDerived(userId)
	expect(derived.rotEndurance).to.equal(StatConstants.DEFINITIONS.rotEndurance.base + 8)
end)

it("applyToCharacter re-runs when the equipment slice changes for an ONLINE character", function()
	-- Seed a spawned character (mirroring the existing applyToCharacter tests' fixture), equip
	-- an item that grants a health bonus, and assert Humanoid.MaxHealth updates WITHOUT calling
	-- applyToCharacter directly — i.e. the subscription itself fired.
end)

it("does NOT re-apply for an unrelated player's equipment change", function()
	-- Two online players; changing player A's equipment must not trigger a Humanoid update for
	-- player B (assert B's MaxHealth is untouched / no extra applyToCharacter side effect observed).
end)
```

(Write the full seeding code by reading the existing `applyToCharacter`/`getDerived` tests already in `StatsServiceServer.spec.luau` for the established character/profile fixture pattern — reuse it exactly, do not invent a new one.)

- [ ] **Step 2: Run to verify RED** (`bash scripts/check.sh --skip-install`) — `getDerived` doesn't yet read equipment; the subscription tests fail because `start()` doesn't yet wire it.

- [ ] **Step 3: Implement `getDerived`** with a LAZY require (function-body, not top-of-file) to avoid the circular-require hazard:

```lua
getDerived = function(self, userId)
	local stats = self:getStats(userId)
	if not stats then
		return nil
	end
	local EquipmentServiceServer = require(ServerScriptService.Services.EquipmentService.EquipmentServiceServer)
	local bonuses = EquipmentServiceServer:getAggregatedBonuses(userId)
	return StatFormulas.derive(stats.investments, { bonuses })
end,
```

- [ ] **Step 4: Implement the subscription in `start()`**, replacing the current body:

```lua
start = function(self)
	janitor:Add(
		Observers.observeCharacter(function(player, _character)
			self:applyToCharacter(player)

			local userId = player.UserId
			-- Charm.computed's getter type is `(previousValue: T?) -> T` (one parameter);
			-- ServerStore.getterFor returns a zero-arg `() -> unknown`. Wrap explicitly rather than
			-- pass it directly, to avoid relying on Luau's function-arity permissiveness typechecking
			-- a mismatched parameter count.
			local readStats = ServerStore.getterFor("stats", userId)
			local readEquipment = ServerStore.getterFor("equipment", userId)
			local statsSelector = Charm.computed(function(_previous)
				return readStats()
			end)
			local equipmentSelector = Charm.computed(function(_previous)
				return readEquipment()
			end)
			local unsubStats = Charm.subscribe(statsSelector, function()
				self:applyToCharacter(player)
			end)
			local unsubEquipment = Charm.subscribe(equipmentSelector, function()
				self:applyToCharacter(player)
			end)

			return function()
				unsubStats()
				unsubEquipment()
			end
		end),
		true
	)
	log:debug("StatsServiceServer started")
end,
```

`ServerStore.getterFor(slice, userId)` already returns the exact `() -> unknown` shape `Charm.computed`'s getter parameter needs (`Getter<T> = (previousValue: T?) -> T`, and the returned closure ignores its argument, which Luau permits) — no wrapper closure needed.

Add `local ServerStore = require(ServerScriptService.State.ServerStore)` and `local Charm = require(ReplicatedStorage.Packages.Charm)` to the file's top-of-file requires (these are NOT the circular one — `ServerStore`/`Charm` don't require `StatsServiceServer`).

- [ ] **Step 5: Delete the imperative reapplication calls** — remove `reapplyToOnlineCharacter(self, userId)` from `addExperience`, `invest`, and `respec` bodies, and delete the now-unused `reapplyToOnlineCharacter` local function entirely.

- [ ] **Step 6: Run the existing StatsServiceServer spec suite** to confirm no regression. This should need no changes: `Charm`'s `signalSetter` (verified above) calls `flush()` synchronously in the same call as the write, so `invest`/`respec`/`addExperience`'s existing post-call Humanoid assertions see the same timing as the deleted imperative calls provided.

- [ ] **Step 7: Gate passes** (full `bash scripts/check.sh`, repo-wide).
- [ ] **Step 8: Commit** — `feat(equipment): StatsServiceServer folds in gear bonuses and reapplies via mirror subscription`

---

### Task 5: Seal-time ownership assert

**Files:**
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` (+ spec)

**Why this task is LAST-but-one, not earlier:** `seal()`'s new check would throw at real boot for ANY declared-but-unregistered slot/account field. Since Task 1 already added `equipment` to the `PlayerSlot` skeleton and Task 3 already registered it via `EquipmentServiceServer`, the positive case (current tree) genuinely passes by the time this task runs. Adding the assert any earlier would break every test that boots the data layer, not just equipment's.

**Interfaces:**
- Produces: `PlayerDataConstants.assertAllSlicesOwned()` — a NEW, separately-callable function (do not fold the check directly into `seal()` only — `seal()` has no "unseal", so a test calling the real `seal()` would permanently lock out every OTHER spec's `registerSlotPath`/`registerAccountPath` calls for the rest of that TestEZ process run; splitting the check out lets it be exercised directly in tests without ever flipping `sealed`).

```lua
function PlayerDataConstants.assertAllSlicesOwned()
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

function PlayerDataConstants.seal()
	PlayerDataConstants.assertAllSlicesOwned()
	sealed = true
end
```

- [ ] **Step 1: Failing spec.** Add to `PlayerDataConstants.spec.luau`:

```lua
describe("assertAllSlicesOwned", function()
	it("does not throw for the current tree (every declared field is registered)", function()
		expect(function()
			PlayerDataConstants.assertAllSlicesOwned()
		end).never.to.throw()
	end)

	it("throws when a slot field is declared but never registered", function()
		PlayerDataConstants.PROFILE_TEMPLATE.slots[1].bogusUnregisteredField = "x"
		local ok = pcall(function()
			expect(function()
				PlayerDataConstants.assertAllSlicesOwned()
			end).to.throw()
		end)
		PlayerDataConstants.PROFILE_TEMPLATE.slots[1].bogusUnregisteredField = nil
		expect(ok).to.equal(true)
	end)

	it("throws when an account field is declared but never registered", function()
		PlayerDataConstants.PROFILE_TEMPLATE.account.bogusUnregisteredField = "x"
		local ok = pcall(function()
			expect(function()
				PlayerDataConstants.assertAllSlicesOwned()
			end).to.throw()
		end)
		PlayerDataConstants.PROFILE_TEMPLATE.account.bogusUnregisteredField = nil
		expect(ok).to.equal(true)
	end)
end)
```

(The `pcall`-wrapped cleanup ensures `bogusUnregisteredField` is always removed from the SHARED `PROFILE_TEMPLATE` even if the inner `expect` assertion itself fails — leaving it behind would break every OTHER spec that reads `PROFILE_TEMPLATE.slots[1]`/`.account` for the rest of the run, exactly the kind of test-pollution hazard this project has been bitten by before.)

- [ ] **Step 2: Run to verify RED** — `assertAllSlicesOwned` doesn't exist yet.
- [ ] **Step 3: Implement** the two functions above (note `seal()` itself is NOT directly tested by calling it for real, for the reason stated above — its only change is the one-line call to the now-separately-tested `assertAllSlicesOwned()`).
- [ ] **Step 4: Gate passes** (full `bash scripts/check.sh`).
- [ ] **Step 5: Commit** — `feat(data-layer): assert every declared slice field has a registered owner`

---

### Task 6: Client facade + Cmdr commands

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/EquipmentService/EquipmentServiceClient.luau` (+ spec)
- Create: `src/ServerScriptService/Commands/EquipItem.luau` + `EquipItemServer.luau` (+ spec)
- Create: `src/ServerScriptService/Commands/UnequipItem.luau` + `UnequipItemServer.luau` (+ spec)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau`

**Interfaces:**
- Produces:

```lua
-- EquipmentServiceClient
getEquipment: (self) -> PlayerDataTypes.Equipment,
getEquippedInSlot: (self, slotId: string) -> PlayerDataTypes.UniqueEntry?,
```

- [ ] **Step 1: Failing spec — `EquipmentServiceClient.spec.luau`**, mirroring `InventoryServiceClient.spec.luau`'s seeded-atom pattern exactly: seed `ClientStore.equipment({ slots = { helmet = {...} } })`, assert `getEquipment()` returns it, assert `getEquippedInSlot("helmet")` returns the entry and `getEquippedInSlot("weapon")` returns `nil`.
- [ ] **Step 2: Implement `EquipmentServiceClient.luau`**, same shape as `InventoryServiceClient.luau`:

```lua
export type EquipmentServiceClient = {
	dependencies: { string },
	getEquipment: (self: EquipmentServiceClient) -> PlayerDataTypes.Equipment,
	getEquippedInSlot: (self: EquipmentServiceClient, slotId: string) -> PlayerDataTypes.UniqueEntry?,
}

local EquipmentServiceClient: EquipmentServiceClient = {
	dependencies = {},
	getEquipment = function(_self)
		return ClientStore.equipment()
	end,
	getEquippedInSlot = function(self, slotId)
		return self:getEquipment().slots[slotId]
	end,
}
```

- [ ] **Step 3: Create `EquipItem.luau`** (Cmdr definition, mirroring `GiveItem.luau`):

```lua
--!strict
return {
	Name = "equipitem",
	Aliases = {},
	Description = "Equips an item (by uid) from a player's inventory.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to equip the item for" },
		{ Type = "string", Name = "uid", Description = "The uid of the unique item to equip" },
	},
}
```

- [ ] **Step 4: Create `EquipItemServer.luau`**, mirroring `RemoveItemServer.luau`'s reason-surfacing pattern (the fix already applied to `GiveItemServer`/`RemoveItemServer` during Phase 3a's PR review — do not repeat that mistake here):

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local EquipmentService = require(ServerScriptService.Services.EquipmentService.EquipmentServiceServer)

return function(_context, target: Player, uid: string)
	local success, reason = EquipmentService:equip(target.UserId, uid)
	if success then
		return `Successfully equipped uid {uid} for {target.Name}.`
	else
		return `Failed to equip item for {target.Name}: {reason or "unknown reason"}.`
	end
end
```

- [ ] **Step 5: Write `EquipItemServer.spec.luau`**, mirroring `RemoveItemServer.spec.luau`'s mock-and-assert-reason-string pattern, including a case asserting the specific reason string is surfaced on failure (not a generic message).
- [ ] **Step 6: Repeat Steps 3–5 for `UnequipItem`/`UnequipItemServer`** (`Args`: `target`, `slotId: string`; calls `EquipmentService:unequip(target.UserId, slotId)`).
- [ ] **Step 7: Add `EXEMPT_MODULES` entries** in `SpecRoots.luau` for the two new Cmdr definition files (`ServerScriptService.Commands.EquipItem`, `ServerScriptService.Commands.UnequipItem`), same reason string as the existing `GiveItem`/`RemoveItem` entries: `"Cmdr command definition (server impl is specced)"`.
- [ ] **Step 8: Gate passes** (full `bash scripts/check.sh`, repo-wide — this is the last task, so this run should be entirely clean).
- [ ] **Commit** — `feat(equipment): client facade and equipitem/unequipitem admin commands`

---

## Done when

- FULL `bash scripts/check.sh` green (file-length + project-rules gates included, no new allowlist entries, no new `::` casts anywhere in this plan's files).
- TestEZ green on the PR (baseline: confirm the exact passing count from Phase 3a's last CI run, plus this phase's additions).
- In Studio: `equipitem <you> <uid of a rusted-saw>` moves it from inventory to the weapon slot; a second `equipitem` with a chambered-helmet moves it to the helmet slot and (if your character is online) visibly changes `Humanoid.MaxHealth` via `rotEndurance`'s bonus feeding into `getDerived`; `equipitem` with a second weapon auto-swaps the first one back to inventory; `unequipitem` returns gear to the bag; equipping below `chambered-helmet`'s level-8 requirement refuses with a specific reason and moves nothing.
- Commit messages clean (the gates enforce this); no new casts (the gates enforce this too).

## Deliberately NOT in this phase (from the spec)

Weapon subtype / dual-wield / two-handed slot assignment (single generic weapon slot until combat needs otherwise); affix ROLLING (fixed bonuses only — rolling needs its own future phase with cross-game research first); hotbar / consumable quickslot (a distinct container-owning domain with stack-splitting semantics a `StackEntry` doesn't have a uid for); transmog / enchantments / set bonuses (post-3b; note for whoever picks this up — the old game's `chambered helmet/pauldrons/chestplate/greaves` really is a 4-piece set, `Set = "chambered"` in the real data); bank / stash / trading.
