# Inventory & Item Model (Phase 3a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The item model everything later stands on — tagged-union item definitions, the `{ items }` inventory slice with stackable/unique entries, string uids minted from an ACCOUNT-scoped counter, and all-or-nothing inventory operations. Dupe-safe and rebalance-friendly by construction.

**Architecture:** Container-owns-item: an item IS an entry in exactly one container array in the profile; ownership is physical location, so duplication is structurally impossible (Phase 1's argument reapplied). A saved item is a *reference + delta* (`itemType` pointer + `quantity` or `uid`); definitions are never copied into saves, so a definition edit rebalances every granted item. Uid = `"{userId}_{counter}"`, counter in a new ACCOUNT slice (`itemMint`) so uids stay unique across character slots forever; minting is an atomic cross-slice transaction.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Cmdr, TestEZ.

Spec: `docs/superpowers/specs/2026-07-15-inventory-item-model-design.md`
Branch: `feat/inventory-item-model` (off main; the spec is already committed on it).

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A cast to `any` in production **fails a CI gate**. If one seems forced, STOP and escalate.
- **Spec-first TDD.** `SpecRoots.assertAllModulesSpecced` fails the build for an unspecced module. Spec files are intentionally untyped.
- **Plain commit messages. NO `Co-Authored-By:` / `Claude-Session:` trailers** — fails a CI gate.
- **Server-authoritative.** Clients read the synced slice only.
- **Service shape: lean annotated literal**; services auto-discovered by filename suffix.
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH wally install — `wally-package-types` is NOT idempotent; `--skip-install` on stale links gives spurious `'REQUIRED_MODULE' is not a function call` errors). TestEZ runs on Open Cloud only on a PR into main. Baseline: **593 + 4 (PR #4) ≈ 597 tests passing** — confirm the exact number from the first CI run. Accepted warning: `DeprecatedApi` on `Player:LoadCharacter`.
- **No migrations** (pre-launch, data wiped).
- File-length gate: 400 code lines/module. Project-rules gate judges added lines.
- **HAND-TRACE every spec fixture you touch** through mutate → validator → mirror → manifest reader. This codebase has been bitten FIVE times by fixtures that typechecked green and failed at runtime. The inventory slice SHAPE changes (`{}` array → `{ items = {} }` wrapper), so EVERY inventory fixture in the repo is affected — this plan's biggest risk.

## Decisions already made (do not relitigate — from the spec)

- Rarities: `"common" | "uncommon" | "rare" | "epic" | "legendary" | "cursed"`.
- Kinds: `"weapon" | "armour" | "consumable" | "misc"` (tagged unions over a base intersection).
- Uids: opaque strings `"{userId}_{counter}"`; account-scoped counter; never parsed for logic.
- Per-kind capacity caps in config; `addItem` all-or-nothing.
- `affixes?` field reserved on unique entries, typed, unread until 3b.
- No per-instance level/xp (named future extension).

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Constants/ItemConstants.luau` | **New.** Rarity + kind unions, per-kind caps, `isValidRarity`/`isValidKind`. |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | Definition tagged-union types; `InventoryEntry` union; `Inventory = { items }`; `ItemMint = { nextUid }`; `PlayerAccount.itemMint`. |
| `src/ReplicatedStorage/Shared/Modules/ItemDefinitions.luau` | Evolves: typed register (per-kind shape asserts), keeps `get`/`isValidItemType`/`getAllTypes` (Cmdr enum feeds off it). |
| `src/ReplicatedStorage/Shared/Modules/GameItems.luau` | Starter definitions: at least one per kind, replacing the two placeholders. |
| `src/ReplicatedStorage/Shared/Modules/Utils/InventoryUtils.luau` | Rewritten for the entry union (count/find helpers, pure). |
| `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` | Owns BOTH slices (`inventory` slot-scoped + `itemMint` account); validator; all-or-nothing ops; atomic uid minting. |
| `src/ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient.luau` | Read facade updated to the new shape. |
| `src/ReplicatedStorage/Client/State/ClientStore.luau` | `inventory` atom type update only. |
| `src/ServerScriptService/Commands/GiveItem*.luau`, `RemoveItem*.luau` | Admin test surface (create or update to the new ops). |
| Every spec with an inventory fixture | THE SWEEP: `inventory = {}` → `inventory = { items = {} }`. |

`SliceManifest`'s reader needs NO change (it returns `slot.inventory` whole; the wrapper rides along). `PlayerDataConstants.emptySlots()`'s placeholder changes to `{ items = {} }`.

---

### Task 1: `ItemConstants` + definition types

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/Constants/ItemConstants.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` (definition types only — the slice types come in Task 3)

**Interfaces (produces):**

```lua
-- ItemConstants
ItemConstants.RARITIES: { string }               -- sorted; the six
ItemConstants.KINDS: { string }                  -- sorted: armour, consumable, misc, weapon
ItemConstants.isValidRarity(value: string) -> boolean
ItemConstants.isValidKind(value: string) -> boolean
ItemConstants.KIND_CAPS: { [string]: number }    -- per-kind max ENTRIES in a slot's inventory
export type Rarity = string                      -- dynamic-registry rationale, limitations.md #3
export type ItemKind = string
```

`KIND_CAPS` provisional values: `weapon = 30, armour = 30, consumable = 40, misc = 40` (entry count = stacks for stackables, instances for uniques).

```lua
-- PlayerDataTypes (replacing the placeholder ItemDefinition)
type ItemDefinitionBase = {
	name: string,
	rarity: string,        -- validated against ItemConstants at registration
	description: string?,
	icon: string?,
}
export type WeaponDefinition = ItemDefinitionBase & { kind: "weapon" }
export type ArmourDefinition = ItemDefinitionBase & { kind: "armour" }
export type ConsumableDefinition = ItemDefinitionBase & { kind: "consumable", stackMax: number, maxStacks: number? }
export type MiscDefinition = ItemDefinitionBase & { kind: "misc", stackMax: number?, maxStacks: number?, questItem: boolean? }
export type ItemDefinition = WeaponDefinition | ArmourDefinition | ConsumableDefinition | MiscDefinition
```

**Caveat on record (from the spec):** if luau-lsp chokes on the unions-of-intersections (narrowing on `kind`), FLATTEN the variants — same runtime shape; note the flattening in the report. Do not fight the checker with casts.

- [ ] **Step 1: Failing spec** — `ItemConstants.spec.luau`: six rarities incl. `cursed`; four kinds; `isValidRarity("cursed") == true`, `isValidRarity("mythic") == false`; every `KIND_CAPS` key is a valid kind with a positive integer cap.
- [ ] **Step 2: Gate fails** (`bash scripts/check.sh`) — module missing.
- [ ] **Step 3: Implement** — mirror `CurrencyConstants`/`StatConstants` house style (doc comments explain the registry role; sorted name lists derived from the definition tables).
- [ ] **Step 4: Gate passes.**
- [ ] **Step 5: Commit** — `feat(items): add ItemConstants and tagged-union item definition types`

---

### Task 2: `ItemDefinitions` typed registration + real `GameItems`

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/ItemDefinitions.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Shared/Modules/GameItems.luau` (+ spec)

**Interfaces:**
- Consumes: Task 1's types + `ItemConstants`.
- Produces (keep existing names — the Cmdr `itemType` enum and InventoryUtils already consume them):
  - `ItemDefinitions.register(itemType: string, definition: PlayerDataTypes.ItemDefinition)` — now VALIDATES at registration: known `kind`, known `rarity`, consumables have integer `stackMax >= 1`, `maxStacks >= 1` when present; **rejects double registration** (the old `register` silently overwrote — that is how dual-registry drift starts).
  - `ItemDefinitions.get`, `isValidItemType`, `getAllTypes` — unchanged signatures.
  - `ItemDefinitions.kindOf(itemType: string) -> string?` — convenience the validator and service use.
  - `ItemDefinitions.isStackable(itemType: string) -> boolean` — true iff the def carries `stackMax` (consumable always; misc when declared).

`GameItems.init()` registers a starter set (provisional content, real shapes) — at least: 2 weapons (e.g. `rusted-saw`, `phoenix-blade`), 1 armour (`chambered-helmet`), 2 consumables (`healing-tonic` stackMax 10, `throwing-knife` stackMax 10 maxStacks 1), 2 misc (`wood` stackMax 30; `crypt-key` questItem, non-stackable). Rarities across the range incl. one `cursed`.

- [ ] **Step 1: Failing spec** — registration validation cases: unknown kind rejected, unknown rarity rejected, consumable without stackMax rejected, double registration rejected; `kindOf`/`isStackable` behave per the defs; GameItems.spec asserts the starter set registers and `getAllTypes` includes them.
- [ ] **Step 2: Gate fails.**
- [ ] **Step 3: Implement.** Registration asserts are developer-error contracts (loud throws at boot, not runtime refusals).
- [ ] **Step 4: Gate passes.** NOTE: the old placeholder items (`iron-sword`, `phoenix-blade` with `rarity = "Common"` capital-C) die here — grep for their names in specs/commands and update every consumer (`InventoryUtils.spec`, service specs, the Cmdr enum is dynamic so it self-updates).
- [ ] **Step 5: Commit** — `feat(items): typed item registration with per-kind validation and a real starter set`

---

### Task 3: The slice shapes (`inventory` wrapper + `itemMint`) — THE FIXTURE SWEEP

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` (entry union, `Inventory`, `ItemMint`, `PlayerSlot.inventory`, `PlayerAccount.itemMint`)
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` (`emptySlots()` placeholder → `{ items = {} }`; `emptyAccount()` gains `itemMint = { nextUid = 1 }` placeholder)
- Modify: `src/ReplicatedStorage/Client/State/ClientStore.luau` (atom type)
- Test: every spec fixture in the repo that builds an inventory

**Interfaces (produces):**

```lua
export type StackEntry = { itemType: string, quantity: number }
export type UniqueEntry = { itemType: string, uid: string, affixes: { [string]: number }? } -- affixes reserved; unread until 3b
export type InventoryEntry = StackEntry | UniqueEntry
export type Inventory = { items: { InventoryEntry } }
export type ItemMint = { nextUid: number }
-- PlayerSlot.inventory: Inventory   (was { InventoryItem })
-- PlayerAccount.itemMint: ItemMint
-- The old InventoryItem/ExpandedInventoryItem types are DELETED (their consumers are rewritten in Tasks 4-5).
```

**THE SWEEP (this task's entire risk):** `grep -rn "inventory = " src/ --include=*.spec.luau` and `grep -rn "inventory" src/ --include=*.luau | grep -v spec` — every fixture `inventory = {}` becomes `inventory = { items = {} }`; every fixture with entries wraps them in `items`. Every `#inventory` read becomes `#inventory.items`. Every account fixture gains `itemMint = { nextUid = 1 }`. Expect hits in: `PlayerDataServiceServer.spec`, `ServerStore.spec`, `SliceManifest.spec`, `CurrencyServiceServer.spec`, `InventoryServiceServer.spec`, `SlotServiceServer.spec`, `StatsServiceServer.spec`, `InventoryUtils.spec`, `ClientStore.spec` (if it seeds inventory), `PlayerDataConstants.spec` (account default assert). **HAND-TRACE each through `syncFromProfile` → the `inventory` manifest reader → `setSlice` copyDeep** — a fixture left as a bare array typechecks in specs and CRASHES nothing (it's still a table!) but silently breaks `.items` reads: trace the actual test assertions, not just nil-safety.
This task leaves `InventoryServiceServer`/`InventoryUtils` mid-migration — typecheck errors THERE are expected and fixed in Tasks 4-5; errors anywhere else are yours. (Same "red between tasks" protocol as Phase 1a, approved then.)

- [ ] **Steps: spec additions first** (SliceManifest.spec: reader returns the wrapper; PlayerDataConstants.spec: account has `itemMint`) → gate shows ONLY the expected InventoryService/InventoryUtils errors → sweep + implement → commit.
- [ ] **Commit** — `feat(items): inventory becomes { items } with stack/unique entries; account gains itemMint`

---

### Task 4: `InventoryUtils` for the entry union

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Utils/InventoryUtils.luau` (+ spec, rewritten)

**Interfaces (produces — pure, both realms):**

```lua
InventoryUtils.countOf(inventory: Inventory, itemType: string) -> number      -- total qty (stacks summed) or instance count
InventoryUtils.findByUid(inventory: Inventory, uid: string) -> (number?, UniqueEntry?)  -- index + entry
InventoryUtils.entriesOfKind(inventory: Inventory, kind: string) -> { InventoryEntry }  -- via ItemDefinitions.kindOf; the UI-tab helper
InventoryUtils.countEntriesOfKind(inventory: Inventory, kind: string) -> number         -- the KIND_CAPS meter
InventoryUtils.hasItem(inventory: Inventory, itemType: string, quantity: number?) -> boolean
```

- [ ] **Steps: failing spec first** (stacks summed across multiple stacks; uid found/missing; kind filtering; hasItem quantity semantics) → implement → gate green (InventoryServiceServer errors may remain until Task 5) → commit.
- [ ] **Commit** — `feat(items): rewrite InventoryUtils for stack/unique entries`

---

### Task 5: `InventoryServiceServer` — validator, atomic mint, all-or-nothing ops

The centrepiece. **Read `CurrencyServiceServer` + `StatsServiceServer` for the house pattern first.**

**Files:**
- Modify: `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` (+ spec, substantially rewritten)

**Interfaces:**
- Consumes: `SliceOwner.registerSlot` + `registerAccount`, `ItemDefinitions`, `ItemConstants`, `InventoryUtils`, `PlayerDataService:transaction`.
- Produces:

```lua
getInventory(userId) -> Inventory?
addItem(userId, itemType: string, count: number?) -> (boolean, string?)      -- all-or-nothing
removeItem(userId, spec: { uid: string } | { itemType: string, quantity: number }) -> (boolean, string?)
hasItem(userId, itemType, quantity?) -> boolean
inventoryOp(userId, fn) -> TransactionOperation                               -- epoch-stamped via SliceOwner
```

**Registration** (module scope): `inventorySlice = SliceOwner.registerSlot("inventory", { items = {} }, reader, validateInventory)` and `itemMintSlice = SliceOwner.registerAccount("itemMint", { nextUid = 1 }, reader, validateItemMint)`.

**The validator** (spec rules 1-6, verbatim intent):
- every `itemType` registered; entry shape matches `ItemDefinitions.isStackable` (stackable: integer `quantity >= 1 and <= stackMax`, NO uid; unique: non-empty string `uid`, NO quantity);
- per-type stack count `<= maxStacks` when the def declares it;
- per-kind entry counts `<= ItemConstants.KIND_CAPS[kind]`;
- uid uniqueness within the array. (`validateItemMint`: `nextUid` integer `>= 1`.)

**Atomic minting — the pattern, exactly:** unique adds run ONE `transaction()` whose ops execute in array order (sequential, synchronous — an upvalue carries the minted uids from the account op to the inventory op):

```lua
	local mintedUids: { string } = {}
	local ok = PlayerDataService:transaction({
		itemMintSlice.op(userId, function(mint)
			for _ = 1, count do
				table.insert(mintedUids, `{userId}_{mint.nextUid}`)
				mint.nextUid += 1
			end
			return true
		end),
		inventorySlice.op(userId, function(inventory)
			for _, uid in mintedUids do
				table.insert(inventory.items, { itemType = itemType, uid = uid })
			end
			return true
		end),
	})
```

Rollback of either op rolls back both — counter and items commit together or not at all. Stackable adds are a single `inventorySlice.mutate` (merge into existing stacks up to `stackMax`, spill into new stacks, respect `maxStacks` + kind caps — **compute feasibility FIRST inside the mutator and return false without writing if the whole `count` does not fit**; the mutate rollback also protects a partial write, but do not rely on it for the normal path).

**All-or-nothing:** every refusal path returns `(false, reason)` with a specific reason (unknown item, kind cap, stack caps). Guard numeric inputs with asserts (developer contract), refuse game-state problems with `(false, reason)` — the same split Stats used.

**Spec cases (the required set):** stack merge; spill into a second stack; refusal when count exceeds remaining stack space (AND inventory unchanged after — assert the whole array deep-equal); refusal at kind cap; unique mint: sequential uids `"1_1", "1_2"`, count>1 mints distinct uids; **mint atomicity: force the inventory op to fail (e.g. a kind-cap violation caught by the validator) and assert `nextUid` did NOT advance**; cross-slot uid uniqueness (mint on slot 1, switch fixture's active slot, mint on slot 2 → no repeat); removeItem by uid removes exactly that instance; removeItem type+quantity across stacks (partial-stack decrement, multi-stack consumption, refusal when short — unchanged after); validator direct-call cases (unknown type, stackable-with-uid, unique-with-quantity, dup uid, cap breach); slot isolation (add on slot 1, slot 2 untouched).

- [ ] **Steps: spec first → gate fails → implement → FULL gate green (repo-wide — this task ends the mid-migration red) → commit.**
- [ ] **Commit** — `feat(items): all-or-nothing inventory ops with atomic account-scoped uid minting`

---

### Task 6: Client facade + Cmdr commands

**Files:**
- Modify: `src/ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient.luau` (+ spec) — read facade over the atom, updated to `Inventory`/entry union; add `getEntriesOfKind(kind)` via InventoryUtils (the UI-tab call).
- Create/Modify: `src/ServerScriptService/Commands/GiveItem.luau` + `GiveItemServer.luau`, `RemoveItem.luau` + `RemoveItemServer.luau` — check what exists first (`ls src/ServerScriptService/Commands/`); update or create following the `AddCurrency`/`GiveXp` pattern; `Group = "Admins"`; implementations surface `(ok, reason)`. The Cmdr `itemType` enum already builds from `ItemDefinitions.getAllTypes` — verify it still resolves.
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` — exempt new command files per the existing precedent.

- [ ] **Steps: spec first (client facade: seeded atom → counts/kind filters; nil before sync) → implement → full gate green → commit.**
- [ ] **Commit** — `feat(items): client inventory facade and giveitem/removeitem admin commands`

---

## Done when

- FULL `bash scripts/check.sh` green (file-length + project-rules gates included; no new allowlist entries).
- TestEZ green on the PR (baseline ~597 + this phase's additions; note the exact count).
- `grep -rn "InventoryItem\b" src/` returns nothing (old type fully replaced).
- In Studio: `giveitem <you> wood 45` → two stacks (30+15); `giveitem <you> rusted-saw 2` → two instances with uids `"<id>_1"`, `"<id>_2"`; a 3rd `giveitem` past a cap refuses with a reason and changes nothing; items persist per-slot; uids never repeat across slots.
- No `::` casts added; commit messages clean (the gates enforce both).

## Deliberately NOT in this phase (from the spec)

Equipment/equipping/gear-stats/requirements (3b, with the two recorded prerequisites — seal-time ownership assert, mirror-subscription); affix rolling (3b; only the schema field exists); transmog/enchantments/set bonuses; bank/stash/trading (trading inherits the stable-uid contract); item leveling (named future extension); provenance display.
