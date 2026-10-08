# Customization 5a — Foundation + Attachment Cosmetics + Body Color (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Stand up the Customization domain end-to-end for its architecture-proving subset: the two-scope
slice model (per-slot `appearance` + account-scoped `entitlements`), the data-only registries, the typed
`Appearance` record (attachment cosmetics + body color only), server-authoritative validation + equip
methods with an ownership gate, and application on the `observeCharacter` seam. This is the vertical slice
that proves the whole design; 5b (clothing/backpacks/shoes/head-type) and 5c (Soul Color) extend it with
no new architecture.

**Architecture:** Mirrors the reference services. Two slices registered by one service — exactly the
`InventoryServiceServer` pattern (`inventory` per-slot + `itemMint` account-scoped via
`SliceOwner.registerSlot`/`registerAccount`). Application reuses the `StatsServiceServer:start()` seam
verbatim: `Observers.observeCharacter` applies on spawn + a `Charm.subscribe` on the `appearance` mirror
reapplies on change. The messy Instance-mutation is isolated behind a **pure plan-builder** (shared to
`ReplicatedStorage`, so the future client UI reuses it for local preview) + a thin, spec-exempt
application shell.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Observers, Cmdr,
TestEZ.

Spec: `docs/superpowers/specs/2026-07-18-customization-design.md` (Decisions 1–11; body-scope B verified
against the live game 2026-07-18). Branch: `feat/customization` (already cut; opening commits landed the
Rojo 7.7.0 bump + roadmap Bank→Completed tidy + the design spec).

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification, a comment at
  the site, and human sign-off. `Color` being a tagged union (Decision 7) is deliberately typed so
  application narrows on `source`, not a cast.
- **Spec-first TDD.** `SpecRoots.assertAllModulesSpecced` fails the build for an unspecced first-party
  module. Every new module gets a `.spec.luau` sibling written FIRST. The Instance-mutation application
  shell is the one exemption (needs a real rig — no headless runtime), added to `EXEMPT_MODULES` with
  that reason.
- **Plain commit messages. NO `Co-Authored-By:` / `Claude-Session:` trailers.**
- **Server-authoritative.** Clients read the synced `appearance`/`entitlements`; equip/unlock are server
  methods. Appearance visibility to OTHER players rides native character-instance replication, NOT
  charm-sync (Decision 8).
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH `wally install`). TestEZ runs on
  Open Cloud on the PR. On Windows, prefix python-touching gate runs with `PYTHONUTF8=1`.
- **No migrations** (pre-launch, data wiped). The `Appearance` type is deliberately implemented as the
  5a SUBSET (attachment cosmetics + body color); 5b/5c grow it — schema growth is free.
- File-length gate: 400 code lines/module. Project-rules gate judges added lines.
- **Old-code-is-evidence.** The 636-line `RequireableCustomization` is the channel-list source only; its
  shape is discarded (Decision 2 / governing principle).

## Scope boundary (what 5a's `Appearance` covers)

```lua
-- CustomizationTypes.luau — 5a subset (5b adds headType/clothing/backpack/shoes; 5c adds soulColor)
export type Color =
    { source: "dye", id: string }
  | { source: "rgb", r: number, g: number, b: number }
export type AccessorySlot = { id: string, colors: { Color } }
export type Appearance = {
  hair:      { id: string?, color: Color? },
  eyebrows:  { id: string?, color: Color? },
  eyelashes: { id: string?, color: Color? },
  accessories: { AccessorySlot },
  body: { color1: Color?, color2: Color?, skin: Color?, rope: Color?, belt: Color?, eye: Color?, wrap: Color? },
}
export type Entitlements = {
  cosmetics: { [string]: { [string]: true } },  -- category -> owned lockable ids (incl. "dye")
}
```

## Rig grounding (read-only live inspection, 2026-07-18 — the active `StarterCharacter`, confirmed accurate)

Verified facts the implementation binds to (grounded, not inferred from the old script):

- **Body-color channels are UNIFORM name-scans — no exclusion rule.** Each channel is ONE dye spanning
  many MeshParts, colored identically: `Color 1` (×9), `Color 2` (×7), `Skin Color` (×4), plus single-part
  `Belt Color`, `Eye Color`, `Rope Color`. Some `Color 1`/skin parts also sit on the head/facemask;
  coloring them with the same channel color is CORRECT (it's the same outfit color) — their
  covered/uncovered *visibility* is a separate head-type concern (5b), never a coloring one. So 5a colors
  every part whose name matches a channel, full stop. Matching is EXACT, so `Skin Color` catches
  hands/feet but not the head's `Skin ColorCovered`/`Skin ColorUncovered` (those are 5b).
- **No separate `RigContract` module.** The only rig binding 5a needs — "channel → part-name to scan" and
  "accessory category → socket name" — rides directly on the channel descriptor rows in `CosmeticRegistry`
  (Decision 10). A dedicated rig-structural module is introduced only if 5b's head-type covered/uncovered
  part-sets actually require it — not speculatively now.
- **Cosmetics mount by standard `AddAccessory` attachment-match, and the assets EXIST.** Real items carry
  a `Handle` + a socket-named `Attachment`: `Hair2/Hair5 → Hair` socket, `Eyebrows2 → Eyebrows` socket,
  `Eyelashes2 → Eyes` socket, and asset-backed misc accessories (`WizardHat → Head`, `Round Glasses →
  Eyes`, `FaceWrap → Mouth`). Every socket exists on the rig.
- **Index-1 of hair/eyebrows/eyelashes is the intentional "None" option** (a blank Accessory, 0
  descendants — bald / no facial hair), NOT missing art. In the typed model "none" is simply `id = nil`
  (nothing mounted), so 5a doesn't carry the blank accessory at all.
- **Dyes:** no `Dyes` textures pre-exist on the rig, so 5a tints a part by setting its `.Color` directly
  (the simple path that works today). The old fabric-dye LOOK (a semi-transparent `Dyes` Texture laid over
  the part, tinted) is a later visual upgrade, not needed for 5a — it changes only HOW a dye renders, not
  the data model.

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Types/CustomizationTypes.luau` | **New.** `Color`, `AccessorySlot`, `Appearance` (5a subset), `Entitlements`. |
| `src/ReplicatedStorage/Shared/Modules/Constants/CosmeticRegistry.luau` | **New.** Catalog per category (`hair`,`eyebrows`,`eyelashes`,`accessory`,`dye`): valid ids, `lockable` flag, per-accessory color-channel count; the **channel descriptor table** (Decision 10) — each row also carries its rig binding (dye channel → part-name to scan; accessory category → attachment socket), so no separate `RigContract` module. Seeds lockables from the live `Customs.Locked` set. |
| `src/ReplicatedStorage/Shared/Modules/CustomizationValidation.luau` | **New.** Pure `validateAppearance` + `validateEntitlements` (Decision 11) — registered ids, well-formed `Color` per union + `allowFreeRgb`, accessory count/shape. |
| `src/ReplicatedStorage/Shared/Modules/CustomizationPlan.luau` | **New.** Pure plan-builder: `(Appearance, registries) -> ApplicationPlan` (accessory mounts, dye assignments). Shared so the client previews with it (Decision 9). |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | `PlayerSlot.appearance: Appearance`; `PlayerAccount.entitlements: Entitlements`. |
| `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` | `emptySlots()` stamps a minimal valid `appearance` literal; `emptyAccount()` stamps `entitlements = { cosmetics = {} }` (skeleton declares, registration owns). |
| `src/ReplicatedStorage/Shared/State/SliceManifest.luau` | Add `appearance` (slot reader) + `entitlements` (account reader) entries. |
| `src/ReplicatedStorage/Client/State/ClientStore.luau` | Add `appearance` + `entitlements` atoms + registry lines. |
| `src/ServerScriptService/Services/CustomizationService/CustomizationServiceServer.luau` | **New.** Registers both slices; `getAppearance`/`getEntitlements`; equip setters (hair/eyebrows/eyelashes/accessory/body) with the ownership gate; `unlockCosmetic`; `appearanceOp`; `start()` application seam. |
| `src/ServerScriptService/Services/CustomizationService/CustomizationApplication.luau` | **New, SPEC-EXEMPT.** The Instance-mutation shell: consumes a plan, clones/welds accessories via `AccessoryUtilities`-equivalent, sets part colors by scanning per `RigContract`. |
| `src/ReplicatedStorage/Client/Services/CustomizationService/CustomizationServiceClient.luau` | **New.** Thin read facade over `ClientStore.appearance`/`entitlements`. |
| `src/ServerScriptService/Commands/EquipCosmetic*.luau`, `UnlockCosmetic*.luau`, `SetBodyColor*.luau` | **New.** Cmdr admin commands (definition + server pairs), mirroring `GiveItem`/`equipitem`. |
| `src/ServerScriptService/Modules/SpecRoots.luau` | `EXEMPT_MODULES` entries for `CustomizationApplication` (needs a real rig) + the new Cmdr definition files. |

---

### Task 1: Types + registries (data-only) + pure validation/plan modules

**Files:** create `CustomizationTypes`, `CosmeticRegistry`, `CustomizationValidation`, `CustomizationPlan`
(+ specs). No slice wiring yet — these are pure and independently testable.

- [ ] **Step 1: Failing specs FIRST** — `CosmeticRegistry.spec` (id lookup, lockable flag, descriptor
  rows well-formed incl. their rig binding), `CustomizationValidation.spec`
  (unregistered id rejected; `rgb` out of range rejected; `rgb` on a non-`allowFreeRgb` channel rejected;
  `dye` id unregistered rejected; over-length accessory list rejected; wrong accessory color-count
  rejected; `validateEntitlements` rejects a non-lockable/unregistered id), `CustomizationPlan.spec`
  (an `Appearance` + registry → expected accessory-mount + dye-assignment plan; `id = nil` → nothing
  mounted; deterministic, no Instance access).
- [ ] **Step 2: Implement the four modules.** Seed `CosmeticRegistry` from the live catalog facts (hair,
  eyebrows, eyelashes real items = index 2+; index 1 is "None" → modeled as `id = nil`, not a catalog
  entry; the `Customs.Locked` set as lockable). Each channel descriptor carries its rig binding: dye
  channels → exact part-name to scan (`Color 1`,`Color 2`,`Skin Color`,`Belt Color`,`Rope Color`,
  `Eye Color`); accessory categories → attachment socket (hair→`Hair`, eyebrows→`Eyebrows`,
  eyelashes→`Eyes`, misc→its own socket). `CustomizationPlan` iterates the descriptors (Decision 10).
- [ ] **Step 3: Gate passes** (full `bash scripts/check.sh`).
- [ ] **Step 4: Commit** — `feat(customization): types, cosmetic registry, validation + plan (pure)`

**⟶ STUDIO CHECKPOINT (pause for developer):** none needed yet (pure logic) — but a good spot to confirm
the seeded `CosmeticRegistry` id list matches what the developer wants exposed before building on it.

---

### Task 2: Two-scope slice wiring (types, skeleton, manifest, client atoms)

**Files:** modify `PlayerDataTypes`, `PlayerDataConstants` (+ spec), `SliceManifest`, `ClientStore`.

- [ ] **Step 1:** Add `PlayerSlot.appearance: Appearance` + `PlayerAccount.entitlements: Entitlements`.
  Run `bash scripts/check.sh --skip-install` once (fresh links) — expect NEW errors in
  `PlayerDataConstants` (skeleton doesn't supply the fields) — fixed in Step 2, same task.
- [ ] **Step 2:** `emptySlots()` stamps a minimal valid `appearance` literal (all groups empty, colors
  `nil`); `emptyAccount()` stamps `entitlements = { cosmetics = {} }`. Same
  "skeleton declares, registration owns" split as `bank`/`inventory`. NB: the seal-time
  `assertAllSlicesOwned()` will now REQUIRE `appearance` + `entitlements` registrations — those arrive in
  Task 3, so do not run a full boot/seal between this task and Task 3 (the unit gate doesn't seal).
- [ ] **Step 3:** Add `appearance` (slot reader) + `entitlements` (account reader) to `SliceManifest.DEFINITIONS`.
- [ ] **Step 4:** Add `appearance` + `entitlements` atoms + registry lines to `ClientStore`.
- [ ] **Step 5:** Update `PlayerDataConstants.spec` to assert the slot template carries `appearance` and
  the account template carries `entitlements`.
- [ ] **Step 6: Gate passes.**
- [ ] **Step 7: Commit** — `feat(customization): appearance (per-slot) + entitlements (account) slices`

---

### Task 3: `CustomizationServiceServer` + application seam — the centerpiece

**Files:** create `CustomizationServiceServer` (+ spec), `CustomizationApplication` (spec-exempt).
**Read `StatsServiceServer:start()` and `InventoryServiceServer`'s two-slice registration first.**

**Registration:** `appearanceSlice = SliceOwner.registerSlot("appearance", DEFAULT_APPEARANCE, reader,
CustomizationValidation.validateAppearance)`; `entitlementsSlice = SliceOwner.registerAccount("entitlements",
{ cosmetics = {} }, reader, CustomizationValidation.validateEntitlements)`.
`dependencies = { "PlayerDataServiceServer" }`.

**Ownership gate (Decision 11):** equip setters resolve the category's scope policy → the right
entitlement store → refuse a lockable id that isn't owned, with a specific `(ok, reason)`. Free ids pass.

**Application seam (mirror `StatsServiceServer:start()` exactly):** `Observers.observeCharacter` →
`applyToCharacter(player)` on spawn + `Charm.subscribe` on the `appearance` mirror selector → reapply.
`applyToCharacter` reads the active `appearance`, builds the plan via `CustomizationPlan` (pure), and
hands it to `CustomizationApplication` (shell). Full-reapply per change is correct because appearance
writes are coarse commits (Decision 9).

- [ ] **Step 1: Failing spec — `CustomizationServiceServer.spec`** (seed via `_setProfileForTesting`, the
  pattern Inventory/Equipment specs use): equip a free cosmetic → persisted; equip a lockable not owned →
  refused, nothing written; `unlockCosmetic` then equip → allowed; `setBodyColor` with an out-of-range
  rgb → refused by the validator; account `entitlements` shared across two slots while `appearance`
  differs per slot; **scope-policy extensibility test** — flip one category's policy to `slot` and assert
  the ownership check consults a per-slot store (guards Decision 1a without building the store for real).
  The `observeCharacter` application is NOT unit-driven (documented in the spec, same limitation
  StatsService's spec notes) — its correctness is the Studio checkpoint below.
- [ ] **Step 2: Implement** registration, getters, equip setters + ownership gate, `unlockCosmetic`,
  `appearanceOp`, and `start()`'s seam. Put `CustomizationApplication` in `EXEMPT_MODULES` (needs a real
  rig). Keep both files under the 400-line gate (split helpers into the plan/validation modules if tight).
- [ ] **Step 3: Gate passes.**
- [ ] **Step 4: Commit** — `feat(customization): CustomizationServiceServer + observeCharacter application`

**⟶ STUDIO CHECKPOINT (pause for developer — REQUIRED before Task 4):** `rojo serve` into the Studio place
and confirm on a spawned character that (a) **body colors** apply to the right parts (limbs recolor
uniformly per channel), (b) a **hair/eyebrow/eyelash** selection (index 2+) mounts on its socket and
`id = nil` clears it, (c) an **asset-backed accessory** (WizardHat → Head / Round Glasses → Eyes /
FaceWrap → Mouth) mounts correctly, (d) it survives a slot switch (respawn reapplies), and (e) a second
player sees it (native replication, Decision 8). This is the first genuinely visual verification and the
point of the small-interval cadence.

---

### Task 4: Client facade + Cmdr commands

**Files:** create `CustomizationServiceClient` (+ spec), the three command definition+server pairs (+ server
specs), modify `SpecRoots`.

- [ ] **Step 1: Failing spec — `CustomizationServiceClient.spec`** (seed `ClientStore.appearance({...})`,
  assert `getAppearance()`/`getEntitlements()` return them).
- [ ] **Step 2: Implement `CustomizationServiceClient`** (thin read facade).
- [ ] **Step 3:** `equipcosmetic <target> <category> <id>`, `unlockcosmetic <target> <category> <id>`,
  `setbodycolor <target> <part> <r> <g> <b>` — admin group, surfacing the specific reason string on
  failure (mock the service in the server specs, assert the exact reason). Add `EXEMPT_MODULES` entries
  for the three Cmdr DEFINITION files.
- [ ] **Step 4: Gate passes** (full run — clean).
- [ ] **Step 5: Commit** — `feat(customization): client facade + equip/unlock admin commands`

**⟶ STUDIO CHECKPOINT (pause for developer):** drive the full loop through the commands —
`equipcosmetic <you> hair Hair3`, `setbodycolor <you> skin 200 120 90`, `unlockcosmetic <you> accessory
WizardHat` then equip it, and confirm the F4 State panel shows `appearance`/`entitlements` updating and
the character reflects each change.

## Done when

- FULL `bash scripts/check.sh` green (file-length + project-rules; no new `::` casts; only the documented
  new SpecRoots exemptions: `CustomizationApplication` + the three Cmdr definitions).
- TestEZ green on the PR into `main` (baseline: Phase 4 count + 5a additions).
- Studio checkpoints above signed off by the developer (visual confirmation — the reason for the
  small-interval cadence). **No push without developer sign-off.**

## Deliberately NOT in 5a (deferred within the phase)

- **Head type, clothing patterns, backpacks, shoes** → 5b (extend `Appearance` + the plan/application).
- **Soul Color** (registry, `soulColors` population, `soulColor` channel, VFX tint) → 5c.
- **Customization UI** → later UI-framework phase (5a ships the data layer + admin commands to drive it).
- **Per-slot entitlements** → the model is extensible to them (Decision 1a); no per-slot store built yet.
- **The artist rig model** → art, owned in the Studio place; 5a owns only the `RigContract` convention.
