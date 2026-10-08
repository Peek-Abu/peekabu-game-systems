# Customization 5c — Asset pipeline, mounting & fit (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Close out customization — make art findable and verifiable, own the mounting mechanism, ship
shoes, and make cosmetics fit properly.

**Architecture:** Mostly additive, with ONE replacement: `Humanoid:AddAccessory` gives way to an
explicit `RigidConstraint` mount (Decision 1). Everything else extends what 5a/5b built — registry rows
carry an art folder, a socket LIST and an offset; a new pure conformance module; the validator relaxes
on retired ids. The pure-plan / spec-exempt-shell split is unchanged.

Spec: `docs/superpowers/specs/2026-07-20-customization-5c-design.md` (Decisions 1–5 + the two 5b
carry-overs, grounded against the live rig and art tree 2026-07-20).
Branch: `feat/customization-5c` (cut off main after PR #11).

## Global Constraints

- **`--!strict`, no `any`, no casts** (a `::` cast needs justification + a comment at the site).
- **Spec-first TDD.** Every new module gets a `.spec.luau` sibling written FIRST;
  `CustomizationApplication` stays the one documented exemption.
- **Plain commit messages. NO trailers.**
- **Server-authoritative.** Clients read the synced slices; every write is a server method.
- Gate = FULL `bash scripts/check.sh` (WITH its `wally install` step — `--skip-install` corrupts the
  link files). TestEZ runs in Studio / on Open Cloud, so specs are unverified until a run — plan one
  before the PR.
- **Do not push without the developer's go-ahead.**
- ⚠ **Keep `Venture[Test]` CLOSED in Studio while CI may run** — an open place makes the Open Cloud
  upload fail with 409 "Server is busy", which looks identical to a real test failure.

## Human-in-the-loop work (developer, not agent)

Two tasks need Studio work in the working place, and the agent cannot do them:

- **Task 1** — reorganising `Customs` into purpose-grouped folders and **unlinking the package**.
- **Task 5** — deciding the final offset values (the agent supplies the tuning command).

Both are the same shape as 5b's content pass: the agent builds the harness, the developer makes the
calls. Sequence them so the agent is never blocked waiting.

---

### Task 1: Asset layout + explicit lookup (Decision 2)

**Files:** `CosmeticRegistry` (an art folder per category/channel), `CustomizationApplication`
(`findCosmeticModel` / `findArt`), plus registry spec updates.

**Solution:** every catalog entry resolves from a DECLARED folder, read as a direct child. The 5a
recursive `FindFirstChild(id, true)` and every root fallback are removed — that recursion is what makes
today's inconsistent layout work, and it already caused one real bug (`clothing1`/`clothing2` both
contain `Skin2`).

- [ ] **Step 1: Failing specs first** — the registry exposes a folder per category; a lookup helper
  resolves only within its folder. Keep the Instance-touching half in the shell.
- [ ] **Step 2: Implement** the registry field + explicit lookup.
- [ ] **Step 3: DEVELOPER** — regroup `Customs` in the working place to match, and unlink the package.
- [ ] **Step 4: Gate green. Commit** — `feat(customization): explicit per-folder art lookup`

> **NOTE:** Task 2 is what makes Step 3 verifiable, so land Task 2 before judging whether the regroup
> is complete. Expect the checker's first run to be a to-do list.

---

### Task 2: Art conformance checker (Decision 3)

**Files:** a new pure `CustomizationConformance` module (+ spec), a boot-time call in
`CustomizationServiceServer.start`, and an admin command for on-demand re-checks (+ spec).

**Solution:** walk the catalog and report per entry — art resolves in its declared folder, is an
`Accessory`, has a `Handle`, the Handle carries an Attachment named for its socket, and the socket
exists on the rig. **It REPORTS; it never asserts or throws** (place-owned art; a missing hat must not
stop a server booting).

Testability: the checker takes the art root and the rig as INJECTED arguments — the same trick
`CustomizationCompatibility` uses for its head-types lookup — so the logic is unit-tested against a
fabricated tree with no real rig.

- [ ] **Step 1: Failing specs** — reports a missing entry, a non-`Accessory`, a Handle with no
  socket-named Attachment, and a socket absent from the rig; reports CLEAN on a well-formed fixture;
  never throws on a malformed tree.
- [ ] **Step 2: Implement** the module, the boot-time summary log, and the admin command.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): art conformance checker`

**⟶ STUDIO CHECKPOINT (required):** run it in the working place. It should name every gap; when the
regroup from Task 1 is finished it should report clean. **Do not start Task 5 until it is clean** — a
missing asset and a bad offset look identical on screen, which is the trap 5b hit.

---

### Task 3: Own the mount (Decision 1) — the replacement

**Files:** `CustomizationApplication` (spec-exempt), `CustomizationPlan` if socket resolution moves
into the plan (+ spec).

**Solution:** find the rig Attachment by NAME anywhere in the character, then bind the cosmetic
Handle's Attachment to it with a `RigidConstraint` (`Attachment0` = rig socket, `Attachment1` = handle).
Depth stops mattering: `Hair` (2), `Eyes` (3) and `ShoeLeft` (2) become identical code.

Keep cosmetics as `Accessory` instances tagged with the existing attribute so `clearApplied` stays
idempotent. Massless still applies.

- [ ] **Step 1: Failing specs** for whatever is pure (socket resolution, offset composition). The
  Instance binding itself stays in the exempt shell.
- [ ] **Step 2: Implement** the mount; delete the `AddAccessory` path.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): own the mount via RigidConstraint`

**⟶ STUDIO CHECKPOINT (required):** hair (depth 2), eyelashes, an `Eyes`-socket accessory (depth 3) and
a `Head`-socket accessory (depth 1) all mount; cosmetics survive respawn and slot switch; nothing
duplicates on reapply. **This is the checkpoint that retires the 5b "UNPROVEN mounting" question.**

---

### Task 4: Shoes as a multi-socket mount (Decision 4)

**Files:** `CosmeticRegistry` (socket LIST on mount descriptors), `CustomizationPlan` (+ spec),
`CustomizationApplication`, service + command surface.

**Solution:** a descriptor carries one or more sockets; each becomes its own constraint. `ShoeLeft` and
`ShoeRight` both sit on `Skin Color`. Content is a single shoe option — a known gap, not a bug.

- [ ] **Step 1: Failing specs** — a two-socket descriptor emits two mounts; a one-socket descriptor is
  unchanged (no regression for every existing cosmetic).
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gate green. Commit** — `feat(customization): shoes as a multi-socket mount`

---

### Task 5: Per-cosmetic offsets + live tuning (Decision 5)

**Files:** `CosmeticRegistry` (optional offset on mount descriptors), `CustomizationPlan` (+ spec),
`CustomizationApplication`, a tuning command (+ spec).

**Solution:** the offset is applied to the constraint. The command nudges a spawned character's offset
and PRINTS the resulting value to paste into the registry — **it never writes**. The registry stays the
source of truth: a value nudged into a place file is invisible to review and lost at the next art sync.

- [ ] **Step 1: Failing specs** — offset composition is deterministic; absent offset = identity.
- [ ] **Step 2: Implement** the field, its application, and the tuning command.
- [ ] **Step 3: DEVELOPER** — tune eyebrows/eyelashes (confirmed off in both head modes) and paste the
  values back.
- [ ] **Step 4: Gate green. Commit** — `feat(customization): per-cosmetic offsets + live tuning`

**⟶ STUDIO CHECKPOINT (required):** eyebrow/eyelash fit is visibly correct in BOTH head modes.

---

### Task 5b: ASSET PASSTHROUGH — audit every piece of art (developer-driven)

**Files:** `CosmeticRegistry` rows; art in `Venture[Staging]`.

**Solution:** the same "old code is evidence, not source" principle applied to ART. The 5c reorg already
deleted two folders the refactor had replaced in code (`Dyes` — dyes are RGB in the registry; `Locked`
— superseded by the `lockable` flag) and quarantined uncatalogued art in `_Unsorted`. This task
finishes the job deliberately rather than opportunistically.

Open questions the passthrough decides, each already surfaced:
- **`Mechanics Goggles`** — art is UNASSEMBLED (loose Models/Unions/Parts, no Handle, no Attachment),
  so it is currently uncatalogued. Finish the art (Handle + `Eyes` Attachment + welds) and re-add the
  row, or discard it.
- **`TabardBackup`** — catalogued, and a near-duplicate of `Tabard`. Keep or drop?
- **`_Unsorted`** (`Blind Fold 1`, `Cowl 1 2`, `Cowl 2 2`) — these are SECOND TONES of two-tone
  accessories, not standalone items. Either model them as multi-piece cosmetics (see Task 4, which
  already generalises a descriptor to N art pieces) or delete them.
- **`Blindfold 2` / `FaceWrap2`** — same shape; moved into `Accessories` but deliberately NOT
  catalogued as separately equippable, which would put half-pieces in the picker.
- Ids with SPACES (`Round Glasses`, `Hat Wrap`) — Cmdr handles them with quotes, verified live. Leave
  them; renaming churns art and registry for a solved problem.
- **The art carries more colour tones than the catalog can express.** `Round Glasses` contains a
  `Handle` AND a `Color2` MeshPart — two colourable parts — while its row declares ONE colour channel
  (accessory rows default to 1, and none override it, so every `colorChannels` value in the catalog is
  a default rather than an observed fact). The `_Unsorted` pieces (`Cowl 1 2`, `Blind Fold 1`) are the
  same problem in a different shape: a second tone the catalog has no way to reference. Decide per
  accessory whether it is 1-channel, 2-channel, or multi-piece — and note the numbers should come from
  the ART, not from the default.
- **Cosmetic colours have NO live test path.** `equipCosmetic`/`equipAccessory` accept a `colors`
  argument and `colorCosmetic` applies it, but no command passes one, and services cannot be driven
  from the command bar (requiring them there yields a fresh module copy with no loaded profiles —
  verified 2026-07-20). So `colorCosmetic` — still commented "provisional, refined against real art at
  the Studio checkpoint" — has never run on a real character. Either add colour arguments to
  `equipcosmetic` when the offsets land, or accept it stays unexercised.
- Anything in `Assets/Weapons` — another domain's, parked there rather than deleted.

- [ ] **Step 1: DEVELOPER** — walk the checker's report plus the list above; decide keep / drop / merge.
- [ ] **Step 2:** apply the verdicts (registry rows here; art in Studio).
- [ ] **Step 3: Gate green + `checkart` clean. Commit** — `chore(customization): asset passthrough`

---

### Task 6: Retired cosmetics must not freeze the slice (5b carry-over)

**Files:** `CustomizationValidation` (+ spec).

**Solution:** `validateAppearance` tolerates unregistered COSMETIC ids — services pre-check on equip and
clients never write, so leniency costs nothing and matches the affix precedent (PR #8).
`validateEntitlements` stays STRICT: a retired id there is dead weight, not a rendering concern.

- [ ] **Step 1: Failing spec** — an appearance holding a retired cosmetic still accepts an unrelated
  write (the actual regression); entitlements still reject one.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gate green. Commit** — `fix(customization): retired cosmetics no longer freeze the slice`

---

### Task 7: `--!strict` across all seven CmdrTypes (5b carry-over)

**Files:** `CmdrTypes/{currencyType,itemType,statId,headType,soulHue,surfaceChannel,surfaceTexture}`.

**Solution:** the set moves together. The Cmdr-internal `registry` argument is untyped — **type the
boundary rather than suppressing it**; if that proves impossible, a documented `--!nocheck` with a
reason at the site is the fallback, not a silent omission.

- [ ] **Step 1:** enable strict on all seven; fix what surfaces.
- [ ] **Step 2: Gate green. Commit** — `chore(cmdr): enable --!strict across the Cmdr argument types`

## Done when

- FULL `bash scripts/check.sh` green; TestEZ green in Studio AND on the PR.
- All three Studio checkpoints signed off — conformance clean, every socket depth mounting, fit correct.
- **No push without the developer's go-ahead.**

## Deliberately NOT in 5c

- **Re-tuning offsets for the NEW rig** — the redo's own work; this phase ships the mechanism and the
  checker that reports what moved.
- **Restructuring `Customs` in the base-game devs' place** — we unlink and own our copy.
- **The Soul Color gacha roll / spinner** → economy phase.
- **Customization UI** → the UI-framework phase.
