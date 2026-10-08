# Affix Rolling (Phase 3c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give unique gear (weapon/armour) a per-instance rolled, named affix — the modernized successor to the old game's `Equipment.Boosts` pool — rolled once at mint, stored on the reserved `UniqueEntry.affixes` field, and folded into derived stats alongside fixed `statBonuses`. Build Tier 2 (conditional pool affixes) fully; RESERVE Tier 1 (guaranteed base-stat variance, the PoE "implicit") schema + aggregation path for combat to activate later.

**Architecture:** Two new leaf modules — `AffixConstants` (the one declaration site: named pool per kind + drop-chance per rarity, plus `get`/`displayPrefix` helpers) and `AffixRoller` (a pure `roll(itemType, random)` function). Rolling hooks into `InventoryServiceServer.addUnique` (one call per minted copy, inside the existing mint transaction). Consumption is one addition to `EquipmentBonuses.aggregate` (map affixId → stat, add the stored absolute value). Validation lives in the existing slice validators (`validateInventory`, `validateEquipment`), **lenient on retired keys, strict on value type** — the corrected policy that keeps retiring an affix post-launch safe (PoE disable-don't-delete). No new service, no new slice, no new networking (affixes ride the existing `inventory`/`equipment` mirrors).

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Cmdr, TestEZ. `Random` (Roblox built-in, seedable) for rolls.

Spec: `docs/superpowers/specs/2026-07-17-affix-rolling-design.md`
Branch: `feat/affix-rolling` (already created off `main` tip `c90d19a`, the PR #7 merge). Stacks BEFORE `feat/bank-per-slot-stash` — Bank rebases onto 3c after it merges.

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification, a comment at the site, and human sign-off — escalate before adding one.
- **Spec-first TDD.** `SpecRoots.assertAllModulesSpecced` fails the build for an unspecced first-party module. Every new module gets a `.spec.luau` sibling written FIRST.
- **Plain commit messages. NO `Co-Authored-By:` / `Claude-Session:` trailers.**
- **Server-authoritative.** Affixes are rolled server-side at mint; clients read the synced entry only, never write.
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH `wally install` — `wally-package-types` is NOT idempotent; a stale `--skip-install` run gives spurious `'REQUIRED_MODULE' is not a function call` errors). TestEZ runs on Open Cloud on a PR into `main` only.
- **No migrations** (pre-launch, data wiped) — schema changes are free.
- File-length gate: 400 code lines/module. Project-rules gate judges added lines.
- **No circular-require hazard this phase** (unlike 3b): `AffixConstants` and `AffixRoller` are leaves (require only `ItemDefinitions`/`StatConstants`, themselves leaves). `EquipmentBonuses` (already a leaf) adds an `AffixConstants` require — still a leaf. Nothing new requires a service.
- **Old-code-is-evidence, not source** (design spec, Governing principles): the old `Stats`/`Boosts` tables are disentangled, not ported. Affix stats target the EXISTING `StatConstants.STAT_IDS` registry (never free-form strings); named unique-effect flags (`Doombringer = 1`) are OUT (combat). Do not reintroduce either.
- **Absolute value storage** (spec Decision 1): the roller stores the concrete rolled integer, not a normalized quality. The validator never range-checks a stored value (legacy values are legitimate).

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Constants/AffixConstants.luau` | **New.** The one declaration site: `AffixDef` type, `POOLS` (named pool per kind), `AFFIX_CHANCE_BY_RARITY`, `get(affixId)`, `displayPrefix(affixes)`; load-time asserts. |
| `src/ReplicatedStorage/Shared/Modules/AffixRoller.luau` | **New.** Pure `roll(itemType, random): { [string]: number }?`. |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | `UniqueEntry` gains reserved `statRolls?`; comment on `affixes` corrected (populated in 3c, absolute value keyed by affixId). `WeaponDefinition`/`ArmourDefinition` gain reserved `statRanges?`. |
| `src/ReplicatedStorage/Shared/Modules/Utils/InventoryUtils.luau` | Gains `validateModifierMap(map): (boolean, string?)` — the shared "values are finite numbers; keys tolerated" check both slice validators call. |
| `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` | `addUnique` rolls an affix per minted copy; `validateInventory` validates `affixes`/`statRolls` on unique entries via `validateModifierMap`. |
| `src/ReplicatedStorage/Shared/Modules/Utils/EquipmentBonuses.luau` | `aggregate` folds each entry's `affixes` (affixId → stat) and pre-wires the `statRolls` fold (nil until combat). |
| `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` | `validateEquipment` validates equipped entries' `affixes`/`statRolls` via the same shared helper. |
| `src/ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient.luau` | Gains `getAffixes(entry)` + `displayName(entry)` UI helpers (thin, over `AffixConstants`). |
| `src/ServerScriptService/Commands/RollPreview.luau` + `RollPreviewServer.luau` | **New.** Admin Cmdr command: prints N sample rolls for an itemType. |
| `src/ServerScriptService/Modules/SpecRoots.luau` | `EXEMPT_MODULES` entry for the `RollPreview` Cmdr definition. |

---

### Task 1: `AffixConstants` — the declaration site

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/Constants/AffixConstants.luau` (+ `.spec.luau`)

**Interfaces (produces):**

```lua
export type AffixDef = { stat: string, min: number, max: number, displayName: string, weight: number? }
AffixConstants.POOLS: { [string]: { [string]: AffixDef } }          -- keyed [itemKind][affixId]
AffixConstants.AFFIX_CHANCE_BY_RARITY: { [string]: number }         -- rarity -> [0,1] drop chance
AffixConstants.get(affixId: string): AffixDef?                      -- searches all kind pools; nil if retired
AffixConstants.displayPrefix(affixes: { [string]: number }?): string?  -- deterministic; nil if no affix
```

**Content** (provisional, from spec Decision 3 — every `.stat` MUST be a real `StatConstants` id):

```lua
POOLS = {
    weapon = {
        warriors = { stat = "strength",     min = 1, max = 3, displayName = "Titan's" },
        vigorous = { stat = "staminaRegen", min = 1, max = 2, displayName = "Vigorous" },
    },
    armour = {
        warded   = { stat = "rotEndurance",    min = 1, max = 2, displayName = "Warded" },
        mending  = { stat = "healthRegen",     min = 1, max = 2, displayName = "Mending" },
        renewing = { stat = "rotRejuvenation", min = 1, max = 2, displayName = "Renewing" },
    },
}
AFFIX_CHANCE_BY_RARITY = { common = 0, uncommon = 0.10, rare = 0.20, epic = 0.35, legendary = 0.50, cursed = 0.75 }
```

**Load-time asserts** (module scope, mirroring how `ItemConstants`/`StatConstants` self-check — fail LOUD at boot, not silently at roll time):
1. every `POOLS[kind][affixId].stat` satisfies `StatConstants.isValidStatId`;
2. every affix has `min <= max` (both integers);
3. every kind with `AFFIX_CHANCE_BY_RARITY` value > 0 for ANY rarity has a non-empty pool (a "hit" must have something to pick) — since chance is per-rarity not per-kind, restate as: every kind present in `POOLS` is non-empty, AND no rarity has chance > 0 unless at least the weapon/armour pools exist. Keep it simple: assert each `POOLS[kind]` is non-empty.

**`get`** searches each kind pool for the affixId (affixIds are unique across kinds by construction — a load-time assert can also enforce global affixId uniqueness so `get` is unambiguous; add that assert).

**`displayPrefix`** collects present affixIds, **sorts them** (`table.sort`, declared/alphabetical order — NOT map-iteration order, which Lua does not guarantee), resolves the first via `get`, returns its `displayName`; `nil` if the map is nil/empty or the sole affix is retired.

- [ ] **Step 1: Failing spec — `AffixConstants.spec.luau`.** Cover: `POOLS` weapon/armour keys present; `AFFIX_CHANCE_BY_RARITY` has all six rarities with `common == 0`; `get` returns a known affix and `nil` for an unknown id; `displayPrefix(nil)`/`displayPrefix({})` → nil, `displayPrefix({ warriors = 2 })` → `"Titan's"`, `displayPrefix({ retiredId = 2 })` → nil, and a two-affix map returns a STABLE prefix across repeated calls (determinism).
- [ ] **Step 2: Gate fails** (`bash scripts/check.sh`) — module missing.
- [ ] **Step 3: Implement `AffixConstants.luau`**, house style matching `ItemConstants.luau` (class doc comment explaining it is the `Equipment.Boosts` successor and the one declaration site; the load-time asserts run at module scope so a bad config fails boot).
- [ ] **Step 4: Gate passes** (full `bash scripts/check.sh`).
- [ ] **Step 5: Commit** — `feat(affix): AffixConstants pool + drop-chance registry`

---

### Task 2: `AffixRoller` — the pure roller

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/AffixRoller.luau` (+ `.spec.luau`)

**Interfaces:**
- Consumes: `ItemDefinitions.get`, `AffixConstants.POOLS`/`AFFIX_CHANCE_BY_RARITY`.
- Produces: `AffixRoller.roll(itemType: string, random: Random): { [string]: number }?`

**Algorithm** (spec Decision 5): resolve def; no `POOLS[kind]` → `nil`; drop roll `random:NextNumber() >= AFFIX_CHANCE_BY_RARITY[rarity]` (default 0) → `nil`; pick ONE affixId uniformly from the kind pool; `value = random:NextInteger(def.min, def.max)`; return `{ [affixId] = value }`.

Uniform pick: collect the pool's affixIds into a stable array (sorted, so a seeded test is reproducible), index by `random:NextInteger(1, #ids)`.

- [ ] **Step 1: Failing spec — `AffixRoller.spec.luau`** (seeded `Random.new(seed)` for determinism):
  - `common` weapon/armour → always `nil` (chance 0), over many trials.
  - a consumable/misc itemType (no pool) → `nil`.
  - a high-chance rarity over many trials: hit rate ≈ `AFFIX_CHANCE_BY_RARITY[rarity]` (assert within a tolerance band, environment-robust — mirror the currency subscription-count spec's tolerance style, do NOT assert an exact count).
  - on a hit: exactly one key; the key is an affixId in that kind's pool; the value is an integer within `[min,max]`.
  - two calls with the SAME itemType and a shared RNG stream can produce different results (independent draws) — assert not-all-identical over several draws.
  - **Fixtures:** needs a weapon/armour definition with a nonzero-chance rarity. `phoenix-blade` is `legendary` (chance 0.50) and `chambered-helmet` is `epic` (0.35) — use those real GameItems fixtures (call `GameItems.init()` in the spec's setup, as other specs do). `common` cases use `rusted-saw`.
- [ ] **Step 2: Gate fails.**
- [ ] **Step 3: Implement `AffixRoller.luau`** (pure; no module-scope `Random`; class doc noting the injected-Random pattern for testability).
- [ ] **Step 4: Gate passes.**
- [ ] **Step 5: Commit** — `feat(affix): pure AffixRoller.roll`

---

### Task 3: Type reservations + shared modifier validation

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/Utils/InventoryUtils.luau` (+ spec)

**PlayerDataTypes changes:**
- `UniqueEntry`: correct the stale comment (`affixes` is populated in 3c, storing the ABSOLUTE rolled value keyed by affixId — no longer "unread until 3b"), and add the reserved Tier-1 field:
  ```lua
  affixes: { [string]: number }?,  -- per-instance rolled affix: absolute value keyed by AffixConstants affixId (Phase 3c)
  statRolls: { [string]: number }?, -- reserved (Tier 1 base-stat variance): absolute value keyed by StatConstants id; unwritten until combat
  ```
- `WeaponDefinition` and `ArmourDefinition` (keep FLAT per 3a Decision 5 — do NOT re-intersect): add
  ```lua
  statRanges: { [string]: { min: number, max: number } }?,  -- reserved (Tier 1); each key a StatConstants id. No current item declares one.
  ```

**InventoryUtils change** — the shared, DRY validation both slice validators call (spec Decision 8):
```lua
-- Validates a modifier map (affixes or statRolls) rides on a UniqueEntry: every VALUE must be a
-- finite number (real corruption is rejected). Keys are DELIBERATELY tolerated — an affixId retired
-- from the pool, or a stat id removed from the registry, is config-drift not corruption, and
-- rejecting it would make every item carrying it un-saveable (PoE disable-don't-delete). nil map = ok.
function InventoryUtils.validateModifierMap(map: { [string]: number }?): (boolean, string?)
```
Checks: `map == nil` → ok; else each value `type(v) == "number"` and not NaN/inf (`v == v and v ~= math.huge and v ~= -math.huge`). Returns `(false, reason)` on the first non-number value.

- [ ] **Step 1: Failing spec** — add a `describe("validateModifierMap", ...)` to `InventoryUtils.spec.luau`: nil → ok; `{ warriors = 3 }` → ok; `{ retiredId = 3 }` → **ok** (key tolerated); `{ warriors = "x" }` → `(false, ...)`; a NaN value → `(false, ...)`.
- [ ] **Step 2: Add the `PlayerDataTypes` fields.** Run `bash scripts/check.sh --skip-install` — the type additions are optional fields, so NO existing literal breaks (unlike 3b's required `equipSlot`); expect green except the missing `validateModifierMap` (spec red).
- [ ] **Step 3: Implement `InventoryUtils.validateModifierMap`.**
- [ ] **Step 4: Gate passes** (full run).
- [ ] **Step 5: Commit** — `feat(affix): reserve statRolls/statRanges types and add shared modifier validation`

---

### Task 4: Roll at mint + inventory-side validation

**Files:**
- Modify: `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` (+ spec)

**Read the existing `addUnique` and `validateInventory` first** (already in the file) — this task extends both minimally.

**`addUnique` change** (spec Decision 5): a module-level `local affixRng = Random.new()` (one stream, distinct draws), and inside the `inventorySlice.op` insert loop, roll **per copy**:
```lua
inventorySlice.op(userId, function(inventory)
    for _, uid in mintedUids do
        table.insert(inventory.items, {
            itemType = itemType,
            uid = uid,
            affixes = AffixRoller.roll(itemType, affixRng),  -- nil when no affix drops; absent field
        })
    end
    return true
end),
```
Add `local AffixRoller = require(ReplicatedStorage.Shared.Modules.AffixRoller)` to the top requires.

**`validateInventory` change** (spec Decision 8): in the UNIQUE-entry branch (after the uid checks), validate both modifier maps via the shared helper:
```lua
local okAffixes, affixReason = InventoryUtils.validateModifierMap(asUnique.affixes)
if not okAffixes then
    return false, `inventory.items[{index}] ("{entry.itemType}"): {affixReason}`
end
local okStatRolls, statRollReason = InventoryUtils.validateModifierMap(asUnique.statRolls)
if not okStatRolls then
    return false, `inventory.items[{index}] ("{entry.itemType}"): {statRollReason}`
end
```

- [ ] **Step 1: Failing specs** — add to `InventoryServiceServer.spec.luau`:
  - minting a `phoenix-blade` (legendary) via `addItem`, over enough mints, produces at least one entry WITH an `affixes` map whose single key is a weapon-pool affixId and whose value is in range (use a tolerance/"eventually" assertion — chance 0.50 — not an exact-count assertion; environment-robust).
  - minting a `rusted-saw` (common, chance 0) never attaches affixes (`entry.affixes == nil`) over many mints.
  - **mint atomicity unchanged:** the existing addUnique kind-cap-rejection/`nextUid`-rollback test still passes with affixes present (rolled affixes roll back with the entry).
  - **validator (direct-call, in the same place `validateInventory`'s other direct cases live):** an entry with a retired affixId still validates OK (leniency); an entry with a non-number affix value is rejected; likewise for `statRolls`.
- [ ] **Step 2: Gate fails.**
- [ ] **Step 3: Implement** the `addUnique` + `validateInventory` changes.
- [ ] **Step 4: Gate passes** (full run).
- [ ] **Step 5: Commit** — `feat(affix): roll an affix per minted unique and validate modifiers`

---

### Task 5: Aggregation + equipment-side validation

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Utils/EquipmentBonuses.luau` (+ spec)
- Modify: `src/ServerScriptService/Services/EquipmentService/EquipmentServiceServer.luau` (+ spec)

**`EquipmentBonuses.aggregate` change** (spec Decision 6) — after the existing `statBonuses` fold, add the two layers (require `AffixConstants` at top — still a leaf, no cycle):
```lua
-- Tier 1 (reserved): nil on every entry until combat; folds by stat id directly when present.
if entry.statRolls then
    for statId, value in entry.statRolls do
        bonuses[statId] = (bonuses[statId] or 0) + value
    end
end
-- Tier 2 (this phase): map affixId -> stat, add the stored absolute value. A retired affixId
-- resolves to nil and is skipped (matches the validator's leniency / PoE disable-don't-delete).
if entry.affixes then
    for affixId, value in entry.affixes do
        local affixDef = AffixConstants.get(affixId)
        if affixDef then
            bonuses[affixDef.stat] = (bonuses[affixDef.stat] or 0) + value
        end
    end
end
```

**`EquipmentServiceServer.validateEquipment` change:** for each occupied slot's entry, run the same `InventoryUtils.validateModifierMap` on `entry.affixes` and `entry.statRolls` (defense in depth — an equipped entry re-enters through this validator on every equip/unequip). Add the check alongside the existing per-slot rules.

- [ ] **Step 1: Failing specs.**
  - `EquipmentBonuses.spec.luau`: `statBonuses` only (existing 3b behaviour still passes); an equipped entry with `affixes = { warriors = 2 }` adds `+2 strength` ON TOP of any `statBonuses`; a **retired** affixId contributes nothing and does NOT error; a hand-built entry with `statRolls = { strength = 4 }` sums (proves the reserved Tier-1 path); both a `statBonuses` and an `affixes` contribution to the SAME stat id sum.
  - `EquipmentServiceServer.spec.luau` (where `validateEquipment`'s direct cases live): an equipped entry with a non-number affix value is rejected by `validateEquipment`; a retired affixId passes.
- [ ] **Step 2: Gate fails.**
- [ ] **Step 3: Implement** both changes.
- [ ] **Step 4: Gate passes** (full run — `StatsServiceServer.getDerived` already folds `getAggregatedBonuses`, so an equipped affix now flows into derived stats with NO change to StatsService; confirm its existing specs still pass).
- [ ] **Step 5: Commit** — `feat(affix): fold rolled affixes into equipment stat aggregation`

---

### Task 6: Client helpers + `rollpreview` admin command

**Files:**
- Modify: `src/ReplicatedStorage/Client/Services/InventoryService/InventoryServiceClient.luau` (+ spec)
- Create: `src/ServerScriptService/Commands/RollPreview.luau` + `RollPreviewServer.luau` (+ spec)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau`

**InventoryServiceClient additions** (thin, over `AffixConstants` — display is a client concern, spec Decision 9):
```lua
getAffixes: (self, entry: PlayerDataTypes.UniqueEntry) -> { [string]: number }?,   -- entry.affixes passthrough
displayName: (self, entry: PlayerDataTypes.UniqueEntry) -> string,  -- prefix + definition name, e.g. "Titan's Rusted Saw Blade"
```
`displayName` = `AffixConstants.displayPrefix(entry.affixes)` (if any) prepended to `ItemDefinitions.get(entry.itemType).name`.

**`RollPreview` Cmdr command** (admin group, fail-closed, mirroring `GiveItem`/`RemoveItem` structure and the reason-surfacing pattern):
- `RollPreview.luau`: `Name = "rollpreview"`, Group `"Admins"`, Args: `{ Type = "string", Name = "itemType" }`, `{ Type = "number", Name = "samples" }` (or default via an optional arg).
- `RollPreviewServer.luau`: rolls `samples` times with a fresh `Random.new()`, formats each as hit/miss + affix `displayName` + rolled value, returns the joined string. Read-only — mints nothing.

- [ ] **Step 1: Failing spec — `InventoryServiceClient.spec.luau`:** seed an entry `{ itemType = "rusted-saw", uid = "1_1", affixes = { warriors = 3 } }`; assert `getAffixes` returns it and `displayName` returns `"Titan's Rusted Saw Blade"`; an entry with no affixes → `displayName` returns the plain definition name.
- [ ] **Step 2: Implement `InventoryServiceClient` additions.**
- [ ] **Step 3: Create `RollPreview.luau` + `RollPreviewServer.luau`**, and `RollPreviewServer.spec.luau` (mock/assert the formatted output contains a rolled value line for a high-chance itemType; assert a no-pool itemType reports misses/none).
- [ ] **Step 4: Add the `EXEMPT_MODULES` entry** for `ServerScriptService.Commands.RollPreview` (the Cmdr DEFINITION file — server impl is specced), same reason string convention as the existing `GiveItem`/`RemoveItem` entries.
- [ ] **Step 5: Gate passes** (full run — last task, entirely clean).
- [ ] **Step 6: Commit** — `feat(affix): client displayName helper and rollpreview admin command`

---

## Done when

- FULL `bash scripts/check.sh` green (file-length + project-rules gates included, no new allowlist entries beyond the one `RollPreview` SpecRoots exemption, no new `::` casts anywhere in this plan's files).
- TestEZ green on the PR into `main` (baseline: Phase 3b/interlude's last passing count, plus this phase's additions).
- In Studio: `giveitem <you> phoenix-blade` a few times, then inspect the inventory slice in the F4 Debugger — at least one copy carries an `affixes` map; equipping an affixed weapon visibly moves the derived stat (via `getDerived` → `getAggregatedBonuses`); `giveitem <you> rusted-saw` never carries an affix; `rollpreview phoenix-blade 20` prints a mix of hits (with a rolled value) and misses; `rollpreview rusted-saw 20` prints all misses.
- Commit messages clean; no new casts (gates enforce both).

## Deliberately NOT in this phase (from the spec)

Tier 1 base-stat ROLLER (schema reserved, roller/content activated with combat — the `statRolls` aggregation path IS built and tested against hand-built entries, so activation is content + a mint-time roll, not a schema/aggregate change); multiple affixes per item (one slot now — the field is already a map, so expanding is config + roller only); spawn weighting (the `weight` field, biasing WHICH affix — reserved); named unique-effect abilities (`Doombringer = 1` / `Enchantments` — combat behaviours, own domain); temporary/consumable boosts (timed buffs, own domain); mutual-exclusion groups; value tiers gated by item level; currency/material reroll & crafting (also the sanctioned answer to rebalancing absolute values post-launch); rich weapon combat affixes (blocked on combat stat ids); rebalancing/populating existing item definitions with tuned affix content.
```
