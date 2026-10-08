# Customization 5b — Appearance surface (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Finish the player-visible customization surface on 5a's mechanism — head type, hair↔head-type
compatibility (mechanism **and** the authored data), clothing/backpacks/shoes, and Soul Color.

**Architecture:** Purely additive. Extend `Appearance`, add `CosmeticRegistry` rows/descriptor kinds,
extend `CustomizationValidation` + `CustomizationPlan`, add methods to `CustomizationServiceServer`, and
teach the spec-exempt `CustomizationApplication` shell the new operations. No new architecture.

Spec: `docs/superpowers/specs/2026-07-19-customization-5b-design.md` (Decisions 1–5, grounded against
the live rig 2026-07-19). Branch: `feat/customization-5b` (cut off main after PR #10).

## Global Constraints

- **`--!strict`, no `any`, no casts** (a `::` cast needs justification + a comment at the site).
- **Spec-first TDD.** Every new module gets a `.spec.luau` sibling written FIRST;
  `CustomizationApplication` stays the one documented exemption.
- **Plain commit messages. NO trailers.**
- **Server-authoritative.** Clients read the synced slices; every write is a server method.
- Gate = FULL `bash scripts/check.sh`. TestEZ runs in Studio / on Open Cloud on the PR. There is **no
  headless runner**, so specs are unverified until a Studio or CI run — plan a run before the PR.
- **No migrations** (pre-launch, data wiped); schema growth is free.
- **Do not push without the developer's go-ahead.**

## ⚠ File-length constraint (plan for it, don't discover it)

The 400 **code**-line gate is close on two files that 5b necessarily grows:

| File | Raw lines today | 5b pressure |
|---|---|---|
| `CustomizationServiceServer.luau` | 444 | +5 methods (`setHeadType`, clothing, backpack, shoes, soul color) |
| `CosmeticRegistry.luau` | 314 | + `headTypes`, clothing/backpack/shoe/texture rows, new descriptor kinds |

**Mitigation, applied up front rather than as a scramble:**
- Keep the service a THIN method surface — push logic into pure shared modules, which is already the
  established split. Specifically, the "which equipped cosmetics are incompatible with head type X"
  computation (Task 3) goes in a pure module and is unit-tested there, NOT inlined into `setHeadType`.
- `SoulColorRegistry` is its OWN module (Task 6), never folded into `CosmeticRegistry`.
- If `CosmeticRegistry` still crowds the gate after Task 5, split the catalog DATA from the accessor
  functions (`CosmeticCatalog` data + `CosmeticRegistry` accessors) — a mechanical move, no behavior
  change. Decide this at Task 5's gate step, not at the end.

---

### Task 1: Head-type data model

**Files:** `CosmeticRegistry` (head-type set), `PlayerDataTypes` (`Appearance.headType`),
`PlayerDataConstants` (skeleton default) + spec, `CustomizationValidation` + spec.

**Solution to Decision 1:** `headType` is a REQUIRED validated string. The registry declares the set
(`HEAD_TYPES = { Uncovered = true, Covered = true }` + an `isHeadType(value)` accessor); the skeleton
stamps `"Uncovered"`; the validator rejects absent/unregistered.

- [ ] **Step 1: Failing specs first** — registry head-type accessors; `validateAppearance` rejects a
  missing `headType`, rejects an unregistered one, accepts each registered one; `PlayerDataConstants`
  spec asserts every slot skeleton carries the default.
- [ ] **Step 2: Implement.** Note `Appearance.headType` is NOT optional, so adding it will surface
  typecheck errors in every existing appearance literal (skeleton + spec fixtures) — fix them in this
  task, the same sweep 5a's slice-wiring needed.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): head type on appearance + validator`

---

### Task 2: Head-type application (the visible half)

**Files:** `CustomizationPlan` (+ spec), `CustomizationApplication` (spec-exempt).

**Solution:** the plan gains a `headType` directive listing which rig parts to show/hide; the shell
applies it. Grounded targets: `Head.Skin ColorCovered` vs `Head.Skin ColorUncovered`, the
`Head.FacemaskLower` subtree (`Facemask1` + `Color 1`), and `Head.Color 1`. Touch ONLY those named
parts — the head also carries ParticleEmitters, `OxygenUI`, `HeadHitbox`, `ClimbPart` that are not ours.

- [ ] **Step 1: Failing spec** — `CustomizationPlan` emits the expected show/hide directive per head
  type, deterministically (pure; no Instance access).
- [ ] **Step 2: Implement** the plan directive + the shell's toggling.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): apply head type (covered/uncovered)`

**⟶ STUDIO CHECKPOINT (required):** `setheadtype <you> Covered` / `Uncovered` visibly swaps the face,
survives a respawn and a slot switch, and leaves the non-cosmetic head parts alone.

---

### Task 3: Hair↔head-type compatibility (mechanism)

**Files:** `CosmeticRegistry` (`headTypes` on mount entries), a pure compatibility module (+ spec),
`CustomizationValidation` (+ spec), `CustomizationServiceServer`.

**Solution to Decision 2 (cross-field, validator-enforced):** because `cosmetics` and `headType` are in
the SAME slice, `validateAppearance` can reject an incompatible pair on ANY write path — strictly
stronger than 5a's ownership gate. Absent `headTypes` = compatible with both.

**Solution to Decision 3 (auto-clear):** `setHeadType` computes the incompatible set via the pure module
and clears those cosmetics **in the same mutation** as the head-type write, so the validator never
observes the invalid intermediate state. The returned reason names what was cleared.

- [ ] **Step 1: Failing specs** — the pure module's incompatible-set computation; the validator rejects
  an incompatible pair **driven through a raw `appearanceOp`** (not just the service method — that is
  the point of validator enforcement); `setHeadType` auto-clears the offender, leaves compatible
  cosmetics untouched, reports what it cleared, and leaves the slice valid.
- [ ] **Step 2: Implement.** Keep `setHeadType` thin — the computation lives in the pure module.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): hair/head-type compatibility + auto-clear`

---

### Task 4: CONTENT PASS — author the `headTypes` data (in scope, developer-driven)

**Files:** `CosmeticRegistry` rows only.

**Solution to "the data exists nowhere":** author it by OBSERVATION, which is why it comes after Tasks
1–3. This is a joint task — the agent drives the harness, the developer makes the calls.

- [ ] **Step 1:** In Studio, walk the matrix: for each head cosmetic (10 hairs, 4 eyebrows, 3
  eyelashes) × each head type, `equipcosmetic` + `setheadtype` and observe. Record clipping/breakage.
- [ ] **Step 2:** **Developer decides** each verdict (Covered-only / Uncovered-only / both). Only
  restricted entries need a row; absent stays "both".
- [ ] **Step 3:** Bake the verdicts into `CosmeticRegistry` rows; add a spec asserting a couple of known
  restricted entries so the data cannot silently regress.
- [ ] **Step 4: Gate green. Commit** — `feat(customization): author hair head-type compatibility data`

**⟶ STUDIO CHECKPOINT (required):** a restricted hair is refused (or auto-cleared) on the wrong head
type, and every combination the developer marked compatible actually looks right.

---

> **OUTCOME:** shipped as clothing + backpacks only. **SHOES MOVED TO 5c** — they are a model mount
> across two sockets (`ShoeLeft`/`ShoeRight`), so they depend on the mounting mechanism 5c reworks;
> building bespoke two-socket welding for one shoe option would have been immediately redone.

### Task 5: Clothing, backpacks, shoes

**Files:** `CosmeticRegistry` (rows + new descriptor kinds), `PlayerDataTypes`,
`CustomizationValidation`, `CustomizationPlan`, `CustomizationApplication`, service (+ specs).

**Solution to Decision 4:** these are descriptor rows, not new architecture — but application DIFFERS
from accessories: clothing/backpack patterns are `SurfaceAppearance` swaps on MeshParts and textures are
`Texture` id assignments, not attachment mounts. Model them as distinct descriptor KINDS so the
plan-builder stays pure and the shell switches on kind.

Content reality (accepted, not a bug): clothing patterns **1**, shoes **1**, backpacks **5**, textures
**12**.

- [ ] **Step 1: Failing specs** — registry rows; validator rejects unregistered ids; plan emits the
  right directive kind per channel.
- [ ] **Step 2: Implement** registry + types + validation + plan + shell + service methods.
- [ ] **Step 3:** Re-check `CosmeticRegistry` against the file-length gate; split catalog data from
  accessors here if it is crowding (see the constraint section).
- [ ] **Step 4: Gate green. Commit** — `feat(customization): clothing, backpack and shoe channels`

---

### Task 6: Soul Color

**Files:** `SoulColorRegistry` (new, + spec), `PlayerDataTypes` (`Appearance.soulColor`),
`CustomizationValidation`, service (+ specs).

**Solution to Decision 5:** ONE per-slot value, never a collection. Port only the OLD module's PURE
resolution math — dominant `Color3`, the two `ColorSequence`s, multi-hue composition by splitting on
`-` — because that part is genuinely correct and is not Instance-mutation. The weighted gacha roll is
NOT ported.

- [ ] **Step 1: Failing spec** — registry resolves a single id and a multi-hue id (`"blue-green"`) to
  the expected composed sequence + dominant color, deterministically; unknown id → nil.
- [ ] **Step 2: Implement** the registry, the `soulColor` field, its validator rule, and `setSoulColor`.
- [ ] **Step 3: Gate green. Commit** — `feat(customization): soul color as a per-character value`

---

### Task 7: Client facade + admin commands

**Files:** `CustomizationServiceClient` (+ spec), new Cmdr command pairs (+ server specs), `SpecRoots`.

**Solution:** extend the 5a facade with the new channels; add `setheadtype`, `setclothing`,
`setbackpack`, `setshoes`, `setsoulcolor` following the established definition+server pattern with
`EXEMPT_MODULES` entries for the definitions.

> **NOTE:** `setheadtype` and `equipcosmetic` are what Task 4's content pass depends on, so if Task 4
> runs before this task, land those two commands early (they are trivial) rather than blocking the pass.

- [ ] **Step 1–4:** specs first → implement → exemptions → gate green.
- [ ] **Commit** — `feat(customization): client facade + head-type/clothing/soul-color commands`

## Done when

- FULL `bash scripts/check.sh` green; TestEZ green in Studio AND on the PR.
- Both Studio checkpoints signed off, including the authored `headTypes` data behaving correctly.
- **No push without the developer's go-ahead.**

## Deliberately NOT in 5b

- Asset reorganization, attachment offsets + live tuning, conformance checker → **5c**.
- The Soul Color gacha roll / spinner → economy phase.
- Authoring more clothing/shoe content → content, not code.
- Customization UI → the UI-framework phase.
