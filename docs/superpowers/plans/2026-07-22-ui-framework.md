# UI Framework — Phase 7 (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the React-lua UI framework from scratch — typed layers owning React roots, a scene
stack driving visibility from reactive state, a refcounted world-suppression contract with seams for
the unbuilt Input and Camera systems, and a pure view-model / dumb component split — proven against
**two screen classes**: the Vitals HUD and the Inventory panel.

**Architecture:** All new code. Nothing in the base is replaced; the existing F4 Debugger root is
folded into the new layer table rather than left standalone. Pure logic (scene stack, suppression
union, view-models) is fully specced; Instance-touching shells are documented exemptions, per the
`CustomizationPlan`/`CustomizationApplication` and `AnimationPlayer`/`AnimationPlayerRuntime`
precedent.

**No old UI code is ported.** The old `UIControllers` tree is evidence and an anti-pattern catalog,
nothing more. The *visual design* is preserved via the developer's instance→Roact conversion plugin,
whose output is scaffolding that never lands (Spec Decision 10).

Spec: `docs/superpowers/specs/2026-07-22-ui-framework-design.md`.
Branch: `feat/ui-framework` (cut off main after PR #13).

## Global Constraints

- **`--!strict`, no `any`, no casts** (a `::` cast needs justification + a comment at the site).
- **Spec-first TDD.** Every new module gets a `.spec.luau` sibling written FIRST. React *screen*
  components are exempt via the new directory rule; **their view-models are not** and carry the logic.
- **Plain commit messages. NO trailers.** No AI attribution anywhere, including the PR body.
- **Server-authoritative.** The UI never writes authoritative state; `ClientStore` is read-only to it.
- Gate = FULL `bash scripts/check.sh` (WITH `wally install` — `--skip-install` corrupts link files).
- **Test via Cmdr commands in a Play session, never via command-bar `require`** (command-bar requires
  get FRESH module copies, not the live singletons).
- **Converted plugin output is NEVER committed.** It goes to scratch, gets decomposed, and is deleted.
  `--!strict` + no-`any` + the file-length gate already make a raw dump unmergeable — do not fight
  them, decompose.
- **🚦 VISUAL SIGN-OFF GATE (developer, 2026-07-22).** This is a visual-heavy phase and the developer
  passes off on the work personally. Concretely:
  - **NEVER push without explicit go-ahead.** Non-negotiable.
  - **Treat every checkpoint (V1–V6) as a hard stop** — the developer verifies in Staging *by looking
    at it* before the next task starts. Mechanics the agent can confirm; visual parity and feel are
    the developer's call, always.
  - **Prefer `git commit --amend` over stacking `fix:` commits** while a task is still under visual
    review. Visual iteration means the same commit gets refined repeatedly; keep history clean by
    amending the task's commit until the developer signs off on that checkpoint, THEN move on. (Safe
    because nothing is pushed until go-ahead — amending unpushed local commits rewrites nothing shared.)
  - When in doubt whether a commit is "done", it isn't — leave it amendable and ask.
- ⚠ `VentureTestingPlace` is **READ-ONLY**. Inspection only — never create, delete, move, or set a
  property, and never publish.
- ⚠ Keep `Venture[Test]` closed in Studio while CI may run (open place → Open Cloud 409).

## Developer verification model

This is the first phase whose output can only really be judged by **looking at it**, so Studio
verification is the primary gate, not a final step. Six checkpoints (V1–V6); the next task does not
start until the developer has run the checklist and said so.

- **Staging is the verification loop.** `rojo serve` into the Staging place and Play. Visual parity
  and feel are the developer's call at every checkpoint; the agent verifies mechanics.
- **The harness ships before the screens** (Task 7), so every later checkpoint is *observed* — scene
  stack depth, suppression refcounts, mounted roots, and render counts are all visible in the F4
  Debugger rather than eyeballed.
- **The `ResetOnSpawn` trap gets its own checkpoint (V1)** because it has already cost this project a
  debugging round, and a slot switch respawns the character. Every checkpoint from V1 on includes
  "die, and switch slots — is the UI still there?"

---

### Task 1: Studio reconnaissance — resolve the two pending unknowns

**Requires:** the `Roblox_Studio` MCP. It attaches at session start, so this task needs a session
that started with Studio open and the plugin running. **Read-only.**

**Solution:** close the spec's last open question and de-risk the conversion pipeline before any
design commits to it.

- [x] **Step 1: Trace the root `SurfaceGui`** — ✅ DONE 2026-07-22. **Abandoned world-space
      experiment, no design impact** — adornee is a junk VFX-anchor part, nothing references it, the
      live inventory is the ScreenGui path. The layer table needs no world-space class; Task 2 stands.
      Full evidence in the spec's resolved-questions section. (Adds one more cutover-cleanup item.)
- [ ] **Step 2: Conversion-plugin dry run — DEVELOPER-RUN.** The plugin is a Studio plugin the agent
      cannot invoke over MCP. The developer converts ONE small authored subtree (a single item slot or
      button, not a screen) and shares the output. Record concretely: Roact-17 vs legacy syntax, how it
      names things, whether image ids are inlined or referenced, how layout/constraints come across.
      This calibrates Tasks 9–10 — the difference between the plugin saving days or costing them.
      **Blocks Task 9 Step 2 and Task 10 Step 2; does not block Tasks 2–8.**
- [ ] **Step 3:** Fold the plugin-calibration notes into the spec (the `SurfaceGui` finding is already
      recorded). **Commit** — `docs(phase-7): calibrate the conversion plugin`

---

### Task 2: `UILayers` — typed ladder, lazy roots (Spec Decision 2)

**Files:** `src/ReplicatedStorage/Client/UI/UILayers.luau` (+ spec), `UILayerConstants.luau` (+ spec).

**Solution:** the full `DisplayOrder` ladder as constants (`Hud` 10, `Panel` 100, `Wheel` 200,
`Overlay` 300, `Debug` 1000); a layer's `ScreenGui` and `ReactRoblox.createRoot` are created **lazily,
on first screen registration**, so `Wheel` and `Overlay` mount nothing this phase.

Every layer root is a `ScreenGui` parented **directly to `PlayerGui`** with `ResetOnSpawn = false`,
`ZIndexBehavior = Sibling`. This is the engine constraint documented at
`DebuggerServiceClient.luau:106` — a `ScreenGui` nested in a Folder is invisible to the engine's
reset scan, dies on respawn, and never returns because `start()` mounts once.

- [x] **Step 1: Failing specs** — ladder values distinct and ordered; requesting a layer twice returns
      the same root; no root exists until a screen registers; teardown destroys the container AFTER
      unmounting the React tree (the leak `DebuggerServiceClient.stop()` documents). `UILayerConstants.spec`
      + `UILayers.spec` written (run in Studio / Task 11 — no headless runner).
- [x] **Step 2: Implement.** `UILayerConstants` (ladder) + `UILayers` (pure core, injectable factory)
      specced; `UILayerHost` (Instance/ReactRoblox factory) and `UIRoot` (shared-singleton wiring) are
      the exempt shells, with reasons in `SpecRoots.EXEMPT_MODULES`.
- [x] **Step 3:** Migrated the Debugger root onto the `Debug` layer — it now `UIRoot.acquire("Debug")`s
      instead of newing its own ScreenGui + ReactRoblox root.
- [x] **Step 4: Gate green** (selene / stylua / luau-analyze / PR-rules / file-length all clean).
      **Commit** — `feat(ui): typed layer ladder with lazy React roots`

**🔍 CHECKPOINT V1 — the respawn trap. ✅ PASSED 2026-07-22.** Developer verified in Staging: F4
debugger opens, survives death and slot switch, `UILayer_Debug` is a direct PlayerGui child at
`DisplayOrder = 1000`. Full TestEZ suite 1134/1134 (up from 1102 — the two new UILayer specs run and
pass, confirming the pure core).

---

### Task 3: CI gates (Spec Decision 7)

**Files:** the project-rules check scripts (PR #3–4 gate infrastructure) + red tests.

**Solution:** land all three gates **before any consumer exists**, so they never have a grace period
— the Phase 6 lesson from the animation-id gate.

1. No `Instance.new("ScreenGui")` outside `UILayers`.
2. No `.Enabled` / `.Visible` assignment on GUI objects outside `UILayers`.
3. No `:FireServer` / `:InvokeServer` / direct ByteNet send from `Client.UI.React.*`.

- [x] **Step 1:** Added all three to `check_pr_rules.py` as whole-tree invariants (the tree was clean
      when they landed, so no past to grandfather — same basis as the Phase 6 asset-id gate). **Red-
      tested all three**: each fired on a planted violation, tree passes clean.
- [x] **Step 2:** Spec fixtures exempt (`_iter_luau` skips `.spec.luau`); `UILayerHost` allowlisted as
      the one module that may new a ScreenGui and own layer-root instances.
- [x] **Step 3: Gate green. Commit** — `feat(ui): CI gates for the three UI anti-patterns`

---

### Task 4: `UIState` + scene registry + the scene stack (Spec Decisions 3 + 4)

**Files:** `Client/State/UIState.luau` (+ spec), `Client/UI/SceneRegistry.luau` (+ spec),
`Client/UI/SceneStack.luau` (+ spec).

**Solution:** Charm atoms are the single source of truth for what is open. A **scene** is a
declarative record: which screens, in which layers, and what it suppresses. The stack holds scenes,
not screens — `Bank` is one scene showing two co-visible container panels, which is why.

`push` / `pop` / `replace`; Escape pops the top; **no `escapeBlocking` opt-out** (cut — zero
consumers). Pushing suspends the scene below rather than racing it.

- [x] **Step 1: Failing specs** — push/pop/replace ordering; pop on empty is a no-op; duplicate push
      does not stack twice; suspension observable (top never suspended); unregistered push/replace
      errors; registry duplicate-register errors; atom round-trip + empty default. `UIState.spec` +
      `SceneRegistry.spec` + `SceneStack.spec` written.
- [x] **Step 2: Implement.** All pure — no Instances, no React. `UIState` (the sceneStack atom),
      `SceneRegistry` (register/get/has + the SceneDef/SuppressionRecord data shapes), `SceneStack`
      (push/pop/replace/top/depth/isActive/isSuspended over the atom). Fully specced, no exemption.
- [x] **Step 3: Gate green** (selene / stylua / analyze / PR-rules / file-length all clean).
      **Commit** — `feat(ui): scene registry and stack over reactive state`

---

### Task 5: `UIWorldSuppression` — refcounted, with registration seams (Spec Decision 5)

**Files:** `Client/UI/UIWorldSuppression.luau` (+ spec), `UISuppressionHandlers.luau` (exempt shell).

**Solution:** the union of every stacked scene's suppression record, **refcounted**, so co-open and
nested scenes compose. This directly fixes the old game's non-refcounted `InputManager.setState`,
adopting the refcounted shape its own unused `pushInputLock`/`popInputLock` already had.

Ships handlers that **can** exist today: mouse behavior, `UserInputService.ModalEnabled`, Lighting
blur/DOF. `movement`, `cameraState`, and `characterRotation` are **declared but unhandled** — logged
once at boot, never silently no-oped. Input and Camera register theirs in their own phases with no
change to any scene.

- [x] **Step 1: Failing specs** — compose (two scenes → engage once, release only on the last);
      disengage when unrequested; counts reflect requesting scenes; scenes with no record ignored;
      unhandled capability warns exactly once; late handler registration adopts already-active state;
      a handler for an inactive capability does not engage. `UIWorldSuppression.spec` written.
- [x] **Step 2: Implement.** `UIWorldSuppression` (pure refcount/union core, specced) +
      `UISuppression` (shared shell: built-in mouse/blur handlers + core instance) +
      `UISuppressionServiceClient` (subscribes sceneStack → reconcile). The two shells are exempt;
      the mouse handler restores the prior `ModalEnabled`, the blur handler owns a lazily-created
      client BlurEffect. Placed under `Client/Services/` not `Client/UI/` so the BlurEffect `.Enabled`
      toggle isn't a false positive for gate 2 — verified the gate stays clean.
- [x] **Step 3: Gate green** (selene / stylua / analyze / PR-rules / file-length all clean).
      **Commit** — `feat(ui): refcounted world suppression with registration seams`

---

### Task 6: `UIInput` shim (Spec Decision 4)

**Files:** `Client/Services/UIInputService/UIInputServiceClient.luau` (exempt shell — input-bound).

**Solution:** the `DebuggerServiceClient` F4 pattern, in one place, with a header stating plainly that
the Input phase DELETES it. **Escape → pop the top scene** is the whole Task 6 deliverable (it's what
V2 exercises). The open-key that *pushes* a scene is deferred to Task 10 — it's a binding with nothing
to open until the first real scene exists, and that scene (Inventory) is its first consumer
(no-consumer-no-mechanism). Two shim caveats resolved by the real Input phase, noted in the header: it
does not sink Escape (the Roblox menu still opens), and it gates on a focused TextBox rather than
`gameProcessed` (the engine marks Escape processed for its own menu, which would swallow the handler).

- [x] **Step 1: Implement.** `UIInputServiceClient` — a lifecycle service (connect/disconnect) doing
      Escape → `SceneStack.pop()`. Exempt with a reason.
- [x] **Step 2: Gate green** (all clean). **Commit** — `feat(ui): minimal input shim for escape-to-pop`

---

### Task 7: Harness BEFORE screens — Debugger UI panel + debug scenes

**Files:** `Client/UI/React/Debugger/UIPanel.luau`, `Client/UI/Scenes/UIDebugScenes.luau`, DebuggerOverlay wiring.

**Solution:** mirrors Phase 6's "observability before consumers". An F4 Debugger **UI** tab showing
the current scene stack (top-down, active vs suspended) and the live suppression counts per
capability (unhandled ones flagged), with buttons that push/pop the throwaway `UIDebugScenes` so the
stack + refcounted union can be driven **without a real screen**.

**Deviation from the plan (deliberate):** scenes live in **client** UIState, so the Cmdr route — a
server command round-tripping to the client (the animation-command shape) — would be backwards.
Buttons in the client React debugger drive `SceneStack` directly: simpler, correct, and where the
developer is already looking (F4). Because no Cmdr command is added, `CmdrTypes` is NOT touched, so
the parked `anim-*` registry-enum chore **stays parked** (its trigger is "next time CmdrTypes is
touched" — forcing it here would be backwards too).

**Render counter deferred to Task 9** (no-consumer-no-mechanism): there are no mounted screens yet,
so nothing to count. It lands with the Vitals HUD, its first consumer, where V4 needs it.

- [x] **Step 1:** `UIDebugScenes` — three harness scenes (PanelA: mouse+blur, PanelB: mouse, Movement:
      an unhandled capability), chosen so composition and the unhandled-seam are both visible. Exempt.
- [x] **Step 2:** The Debugger **UI** tab (`UIPanel`) — reactive stack + suppression display + drive
      buttons; wired into `DebuggerOverlay` as a client-only tab (hidden in Server context, like Anims;
      tab width now scales to the count so 5 tabs fit). Component exempt.
- [x] **Step 3: Gate green** (all clean). **Commit** — `feat(ui): debugger UI panel and debug scenes for V2`

**🔍 CHECKPOINT V2 — the framework, with no screens yet.** Developer in Staging: `ui-scene push` a
dummy scene → panel shows stack depth 1, suppression refcounts increment, mouse unlocks, blur
appears. Push a second → refcounts compose, not overwrite. Escape → pops one, not all. Pop to empty →
every suppression released and the world is exactly as it started. Die + switch slots → still sane.

---

### Task 8: Design tokens + the universal primitives (Spec Decisions 9 + 11)

**Files:** `Client/UI/React/Tokens.luau`, `Client/UI/React/Primitives/{Button,Panel}.luau`.

**Solution (built broad-first, at the developer's direction):** the developer's steer was that the
bigger risk is *overfitting* primitives to one screen, so the base should be broad and well-designed
rather than extracted from a single screen. So this task builds the design SYSTEM — `Tokens` (a
semantic colour/space/radius/type scale, no literals at call sites ever) and the genuinely-UNIVERSAL
primitives `Button` (variants + `selected` covers tab-pills too) and `Panel` (titled surface). Both
are presentational; screen LOGIC lives in specced view-models, not here.

**Deliberately deferred (the nuance):** `Slot` and `Tab` are *domain-shaped* — a `Slot` only means
anything in terms of items/stacks/rarity. Building them broad-up-front would *guess*, which overfits
worse than building them with their domain. `Slot` ships with Inventory (Task 10); `Tab` is already
covered by `Button`'s `selected` state. Gamepad navigation is NOT built (Decision 9) — the primitives
just don't assume mouse-only, so it can be added in one place later.

- [x] **Step 1: Test approach resolved and recorded in `docs/testing.md`.** Presentational primitives
      are exempt (logic-free; a mounted test would assert only "it rendered"); the **mounted-test
      harness is deferred** until a component has assertable logic that can't be a pure view-model —
      building it now buys complexity without coverage. `react-testing-library-lua` rejected (needs
      Jest, not TestEZ); `createRoot`+`act` is the path when we do need it.
- [x] **Step 2: Kept per-file `SpecRoots` exemptions** (Tokens, Button, Panel) rather than a blanket
      `Client.UI.React.*` directory rule — a directory rule silently exempts any logic a component
      grows, and the per-file list isn't painful yet. Revisit if it becomes so (no-consumer rule).
- [x] **Step 3: Built `Button` + `Panel` from Tokens.** Validated `Button` immediately by refactoring
      the F4 UI panel's hand-rolled button onto it (a real consumer, proving the API now).
- [x] **Step 4: Gate green** (all clean). **Commit** — `feat(ui): design tokens and universal primitives`

**🔍 CHECKPOINT V3 — the primitives look right.** No authored-vs-converted comparison (we built fresh,
didn't convert), so this is simpler: developer opens F4 → UI tab in Staging and confirms the buttons
(now the `Button` primitive) read well — hover, spacing, corner radius. Token *values* are a starting
palette and get tuned when a real authored screen is converted; the checkpoint is about whether the
primitive shapes and the token scale feel right. Feel is the developer's call.

---

### Task 9: Vitals HUD — the HUD class (Spec Decision 8)

**Files:** `Client/UI/React/Screens/Vitals/{VitalsHud.luau, VitalsViewModel.luau}` (+ view-model spec).

**Solution:** proves the always-on, never-input-capturing, high-frequency class. Deliberately stresses
**both** update paths: level/XP from the `stats` atom via `useAtom`, and health from
`Humanoid.HealthChanged`.

**The load-bearing technique (Decision 11): health uses `React.createBinding`, not `useState`.** A
health bar driven through state re-renders the tree on every change; a binding updates the one
property with no reconciliation. The Task 7 render counter must show the HUD's render count staying
flat while health changes.

- [x] **Step 1: view-model specs** — `VitalsViewModel.spec`: level/XP derivation across the curve
      (zero, mid-level, the level-2 boundary, the cap → "MAX"), health fraction/label with the two
      cases a live Humanoid actually produces (MaxHealth 0 → no divide-by-zero; overheal/negative →
      clamped), and the pre-sync `nil` stats case → a loading state, never a bogus zero.
- [x] **Step 2: Built fresh, not converted.** A HUD health/XP bar is simple enough that the conversion
      plugin isn't worth the round-trip; the plugin's value is the complex authored layouts (Inventory,
      Task 10). Styled entirely from Tokens, using the `Panel` primitive (its first real consumer).
- [x] **Step 3: Implemented on the `Hud` layer**, rebinding the Humanoid across respawn/slot-switch.
      Health rides a `React.useBinding` (writes the bar's Size/Text properties directly, no re-render);
      level/XP ride `useAtom`. `UIRenderCounters` (built here, its first consumer) tallies renders and
      the F4 UI tab displays them, making the no-re-render-storm claim checkable.
- [x] **Step 3b: HUD-hide implemented as agreed** — a scene declares `hud = "hidden"`; the HUD reads
      the stack (`SceneStack.hudHiddenIn`, specced) and derives its own `Visible` prop. The HUD is NOT
      a scene: it never opens, closes, suppresses, or participates in Escape.
- [x] **Step 3c: Services merged 3 → 1.** Rather than add a third service to mount the HUD, folded
      `UISuppressionServiceClient` + `UIInputServiceClient` into one `UIServiceClient` (stack
      subscription + Escape shim + HUD mount) — the consolidation the developer flagged. Suppression
      also moved to `Client/UI/Suppression/`, now that demoting blur removed the reason it sat outside.
- [x] **Step 4: Gate green** (all clean). **Commit** — `feat(ui): vitals HUD proving the high-frequency screen class`

**🔍 CHECKPOINT V4 — HUD class.** Developer in Staging: take damage → bar moves smoothly, **render
count stays flat** in the debugger panel. Die → HUD survives and rebinds to the new character. Switch
slots → same. Open a panel scene → HUD behaves per its declared dim/hide rule. Visual parity vs the
old vitals UI is the developer's call.

---

### Task 10: Inventory panel — the panel class (Spec Decision 8)

**Files:** `Client/UI/React/Screens/Inventory/{InventoryPanel.luau, InventoryViewModel.luau,
ItemGrid.luau, CategoryTabs.luau, ItemTooltip.luau}` (+ view-model specs).

**Solution:** proves the transient, input-capturing, slice-reading class. The old game's per-panel
sub-managers (`ItemFrameManager`, `SortManager`, `SearchManager`, `CategoryTabsManager`,
`ItemInfoDisplay`, `ItemOptionsMenu`) were already `(container, onChange, state)` — an evidence-backed
component decomposition, free.

**`ItemGrid` must be container-agnostic** (it takes items + a container id), because Bank reuses it
for two co-visible sides later. That is the client echo of the server-side
`ContainerValidation`/`ContainerPlacement` extraction Phase 4 already did.

**Keyed children**, so React reconciles instead of the census's destroy-all-and-rebuild.

- [ ] **Step 1: Failing view-model specs** — category filtering, sorting, search, empty states, the
      pre-sync empty-inventory case; what is actionable per item. All pure over the `inventory` atom.
- [ ] **Step 2:** Convert the authored inventory tree via the plugin → scratch → decompose → **delete
      the dump**. Per screen, never wholesale (`GUI` is 2,574 descendants).
- [ ] **Step 3:** Implement as a scene on the `Panel` layer, with its suppression record declared
      (`mouse`, `blur`, `ModalEnabled` active; `movement`/`cameraState`/`characterRotation` declared
      and logged as unhandled).
- [ ] **Step 4:** Actions route through `InventoryServiceClient` — **never** a direct remote call from
      a component (CI gate 3 enforces it).
- [ ] **Step 5: Gate green. Commit** — `feat(ui): inventory panel proving the panel screen class`

**🔍 CHECKPOINT V5 — panel class, and the phase's real test.** Developer in Staging: open/close via
key and Escape; mouse unlocks and blur applies; items render from real slice data; add/remove an item
via Cmdr → grid updates **incrementally** (render count rises by roughly one row, not the whole grid);
category/sort/search behave; die and switch slots mid-open. Visual parity and feel are the developer's
call.

---

### Task 11: Full-suite run, soak, docs

- [ ] **Step 1:** Full TestEZ run in Studio (`RunTests = true`). All green.
- [ ] **Step 2:** `docs/ui.md` — the framework doc, mirroring `docs/animation.md`: layers, scenes,
      the suppression contract and its open seams, how to add a screen, the view-model rule, the
      conversion pipeline, and the `ResetOnSpawn` gotcha. Add it to the AGENTS.md doc table.
- [ ] **Step 3:** Update `docs/ROADMAP.md` — Phase 7 status.
- [ ] **Step 4: Commit** — `docs(ui): framework guide`

**🔍 CHECKPOINT V6 — soak.** Developer free-plays Staging: open/close panels repeatedly, die, switch
slots, alt-tab, resize. Watch for leaked roots, stuck suppression (mouse never re-locks, blur never
clears), or orphaned `ScreenGui`s accumulating under `PlayerGui`.

---

### Task 12: PR

- [ ] **Step 1:** Whole-branch self-review against the spec's anti-pattern catalog — all ten. Any
      rebuilt anti-pattern is a bug, not a style note.
- [ ] **Step 2:** Confirm no converted plugin output was committed anywhere.
- [ ] **Step 3:** **Ask the developer for explicit go-ahead**, then push and open the PR. Body carries
      **no AI attribution**.
- [ ] **Step 4:** Merge with a merge commit (never squash), subject `Merge PR #N: Phase 7 — UI framework`.
      Rebase any open stacked branches onto the new main afterward.

---

## Deliberately NOT in this plan

Per the spec, and per the standing **no consumer, no mechanism** rule: screens for bank / equipment /
customization / stats / currency; gamepad navigation; mobile-touch layout; transitions beyond a basic
fade; Camera, Input, and movement-suppression handlers; vanity slots and hotbar affordances; the
`escapeBlocking` opt-out; eager roots for the `Wheel` and `Overlay` layers.
