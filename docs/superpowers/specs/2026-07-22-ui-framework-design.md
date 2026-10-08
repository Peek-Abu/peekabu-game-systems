# Design — UI Framework (Refactor Phase 7)

**Status:** DRAFT — awaiting developer approval · **Date:** 2026-07-22 · **Phase:** 7 of the Venture
port — the second system of the presentation/infrastructure track, after Animation (Phase 6).

**Framing — reinvention, stated at the developer's explicit direction (2026-07-22).** The old
`UIControllers` tree and its supporting UI code are **bad enough that a redo is faster and easier
than a port**, and that is the developer's call, not an inference. This is a NEW system built with
modern React-lua technique. The old game's UI is 21 top-level `ScreenGui`s and 14 imperative Knit
controllers driving ~2,500 descendant instances by hand. What it contributes here is exactly three
things: one genuinely good idea that React already implements better (a declarative screen→context
solver), one contract we must reproduce because gameplay depends on it (the world-suppression
handshake when a panel opens), and an anti-pattern catalog so we don't rebuild its mistakes by
accident. **No old UI code is ported. None.**

**What IS preserved: the visual design.** The UI is maintained as a look — layout, art, proportions,
the authored `ScreenGui` trees stay the reference for how screens should appear. The developer has a
plugin that converts instance trees into Roact, which makes that fidelity nearly free (Decision 10).
The design is kept; the code is reinvented. These are separable and this phase separates them
deliberately.

**Scope, per the developer's direction:** the *framework* plus a two-class proving set — one panel
screen and one HUD screen. Screens for the remaining built domains ship as part of their own
phases, or as follow-on work; this phase does not attempt all of them. Features behind those screens
are deliberately partial: the point is the framework, not feature completeness.

## Purpose

One system that answers, for every current and future screen:

1. **Where does a screen live in the layer stack, and who owns its root?** One typed layer table —
   never `Instance.new("ScreenGui")` at a call site again.
2. **How does a screen know whether it is open?** Derived from reactive state, never commanded by
   imperative `.Enabled` toggling.
3. **What happens to the world when a panel opens?** One declarative, refcounted suppression record
   — not six side effects monkey-patched in at startup.
4. **Where does a screen get its data?** `ClientStore` atoms via `useAtom`. There is no second path.
5. **What is testable, and what is exempt?** A structural pure/shell split, so the spec-exemption
   list does not grow with every component.

## Grounding — read-only census of `VentureTestingPlace` (2026-07-22)

### The layer that already tried to be this

`ReplicatedStorage.Modules.UI` holds a three-module attempt at exactly this framework. It is worth
understanding precisely, because its good idea is now free and its failure mode is instructive.

- **`UIRegistry`** (56 ln) — 38 static entries: `{ScreenPath, VisibleIn = {ctx=true}, Requires,
  TweenTime}`. Entries do not target `ScreenGui`s; many point at deep frames
  (`{"Shop","ItemShopMenu","SellAllButton"}`). Resolved against `PlayerGui` at runtime with a
  `StarterGui` fallback.
- **`UIManager`** (415 ln) — a **declarative visibility solver**, not an open/close stack. State is a
  flat set of string flags plus one `ModalContext`. `Evaluate()` iterates the *entire* registry on
  every state change and tweens each screen toward its computed boolean.
- **`UIContexts`** (117 ln) — `{ [context] = {onEnter, onExit} }` lifecycle hooks.

**The good idea:** `Evaluate()` is a full re-solve of declared intent into instance state on every
change. That is a reconciler. The previous developers arrived at React's core idea from first
principles — which is precisely why we do not port any of it. React *is* this module, done properly.

**The failure modes**, all confirmed:

| Symptom | Evidence |
|---|---|
| Half-adopted, and inverted | 4/14 `UIControllers` require `UIManager`; **0/14** require `UIRegistry`. Meanwhile 18 non-UI modules drive it — combat, death, input, camera, dialogue. The layer meant to own UI is operated from everywhere except UI. |
| Behavior invisible at the definition site | `UIContexts` ships almost entirely empty stubs; `GUIController:KnitInit` **monkey-patches** `MainUI.onEnter/onExit` at runtime. Load order silently decides correctness. |
| Authored state disagrees with runtime state by design | `GUIController` L62–87 imperatively corrects `Enabled`/`Visible` on nine screens at startup. |
| Duplicated truth | `UIManager.ExclusiveSets` and `UIContexts.ExclusiveSets` are separate tables that must agree by convention. |
| Dead scaffolding | `ContextStack` declared, never read or written. `RegisterDynamicScreen` never called. ~100 commented lines inside the fader — it was rewritten at least twice. |
| An arity bug shipped | `EndModal("ToggleUIVisibility")` against `function UIManager:EndModal()`. |

### How old screens got their data — three parallel paths

1. **Knit service promise, once** — `InventoryService:GetAllItems():andThen(...)` hydrates a client
   cache at `KnitStart`.
2. **Raw `RemoteEvent` deltas** — `Events.InventoryUpdate.OnClientEvent` with a string-tag switch
   (`"AddItem"` / `"RemoveItem"` / `"resetInventory"`). UI code also calls
   `Events.Equipment:InvokeServer("Dismantle", …)` **directly from the UI controller**, bypassing the
   service layer entirely.
3. **Instance value objects + `.Changed`** — the HUD reads `player.PlayerStats.Rot.Current/Max` and
   `.Stamina.{Stamina,Max,Exhausted}` ValueObjects, plus `Humanoid.HealthChanged`.

Refresh is **destroy-all-and-rebuild**: every `BankChanged` event clears every item frame and
recreates one per item, even for a single add. The incremental path sits commented out.

The sharpest smell: **`InventoryController._inventories` is keyed by a GUI Instance.**
`GetAllItems(context)` takes `context = PlayerGui.GUI.MainGUI.InventoryGUI.Inventory.InventoryFrame`.
The client's item model is namespaced by the widget that displays it — data identity and view
identity are fused, so Bank must reach into Inventory's frame path just to read the player's items.

There is also a hand-rolled store: five near-identical 66-line singletons
(`BaseInventoryUIState`, `InventoryUIState`, `BankUIState`, `ShopBuyUIState`, `ShopSellUIState`)
holding `currentCategory`, `sort`, `searchQuery`, `isVanityPanelOpen`, `activeTooltip`. **They have
no subscription mechanism** — mutation fires a manual `InventoryUIEvents.UpdateHighlights:Fire()`, or
the caller threads an explicit `populate` closure through. That is exactly the shape `useAtom`
replaces, and it is the strongest single argument that this phase is subtraction, not addition.

A **third** state store, `Modules.State.ClientStateStore`, appears in `VitalsUIController` with its
subscriptions commented out — tried and reverted. Unread; why it was abandoned is unknown.

### Layering, as it actually exists

21 top-level `StarterGui` children (19 `ScreenGui`, 1 `SurfaceGui`, 1 `LocalScript`), three of them
junk empties literally named `ScreenGui`. `GUI` is a mega-container: 32 children, **2,574
descendants, containing 30 nested `ScreenGui`s**.

Explicit `DisplayOrder` values in the entire game: wheels (`EmoteWheelUI`, `ConsumableWheelUI`) = 50,
`PVP` = 5, `Settings` / `FadeBlack` = 1, `RedoUITest` = 10 (disabled). **Everything else is 0.**
Layering is therefore emergent from Explorer sibling order, not designed — which is why startup
fixup code exists at all.

### The world-suppression contract (reproduce this exactly)

Opening the main panel is one call — `UIManager:EnableExclusive("MainUI", "GameUI")` — which fires
the runtime-patched `UIContexts.MainUI.onEnter`. That hook does exactly six things:

1. `CameraManager.enableState("MainGUIOpen")`
2. `MouseUtilities:saveMouseIcon(player)`
3. `InputManager.setState("MainUI")`
4. `Lighting.UIBlur.Enabled = true`, `Lighting.UIDepthOfField.Enabled = true`
5. `Events.InventoryRotate:FireServer("Server")` — hands character rotation authority to the server
6. `UserInputService.ModalEnabled = true`

`onExit` mirrors all six and plays a close sound parented to `CurrentCamera`.

Two details matter for our design:

- **Movement suppression is entirely `InputManager.setState("MainUI")`**, whose keymap is a pure
  sink: it blocks every `Enum.PlayerActions` plus `KeyCode.M` via one ContextAction at
  `High + 1` returning `Sink`. `setState` is **not refcounted**, so nested or co-open panels cannot
  compose — last write wins. A second, *refcounted* mechanism (`pushInputLock`/`popInputLock`)
  exists in `InputManager` and the UI path does not use it.
- **`Camera.States.MainGUIOpen` writes to the character.** It is a priority-150 override whose
  `Update` rotates `HumanoidRootPart` by the camera's X delta. The open-inventory camera *drives
  character rotation* — a genuine UI→character write, and the reason for the `InventoryRotate`
  server call above.

### Anti-pattern catalog (what the census forbids us from rebuilding)

1. Screen state keyed by, or reachable only through, an Instance path.
2. A state store with no subscription mechanism, refreshed by threading `populate` closures.
3. Destroy-all-and-rebuild as the update strategy.
4. More than one path from server state to a screen.
5. UI code calling `:FireServer` / `:InvokeServer` directly.
6. Lifecycle hooks declared as stubs and monkey-patched at runtime.
7. Non-refcounted world suppression.
8. Exclusion rules duplicated across two tables that must agree by convention.
9. `DisplayOrder` left at 0 and layering left to sibling order.
10. Startup code that corrects authored instance state.

## Decision 1 — React is the reconciler; `UIManager` is not ported

`UIRegistry` + `Evaluate()` is a hand-rolled reconciler over a declarative registry. React replaces
it wholesale, and every line of the fader, the transparency cache, and the per-object tween
cancellation goes with it.

Three responsibilities that React does **not** subsume, and which are therefore the actual content
of this phase:

- **Root and layer ownership** (Decision 2) — React needs a host; the engine constrains what that
  host may be.
- **Screen-visibility policy** (Decisions 3 and 4) — React renders what you tell it; *what should be
  open* is domain state.
- **The world-suppression contract** (Decision 5) — entirely outside React's model.

## Decision 2 — one React root per typed LAYER, never per screen

**The engine constraint is load-bearing and already cost this project a debugging round.**
`ResetOnSpawn = false` is only honored on a `LayerCollector` that is a **direct child of
`PlayerGui`** — the engine scans `PlayerGui`'s own children. A `ScreenGui` nested inside a Folder is
invisible to that scan, gets destroyed on respawn, and since `start()` mounts once, never returns.
This is documented at `DebuggerServiceClient.luau:106` and it bites harder here than in the old game,
because **a slot switch respawns the character**.

Therefore:

- A single `UILayers` module declares a **fixed, typed set of layers**, each one `ScreenGui`
  parented directly to `PlayerGui`, with `ResetOnSpawn = false`, an **explicit** `DisplayOrder`, and
  `ZIndexBehavior = Sibling`.
- Each layer hosts exactly one `ReactRoblox.createRoot`. Roots are independent, so a fault in the
  HUD tree cannot unmount panels. Cross-root state sharing is free because Charm atoms live outside
  React entirely — this is a direct argument for atom-based state over React context.
- **Components never render a `ScreenGui`.** The existing `-- selene: allow(...)` comment and the
  warning in `DebuggerOverlay` become a framework-wide rule with a CI gate (Decision 7).

Proposed layers, `DisplayOrder` as data rather than emergence:

| Layer | Order | Contains |
|---|---|---|
| `Hud` | 10 | Always-on, never input-capturing: vitals, currency, crosshair |
| `Panel` | 100 | Open/close screens that capture input: inventory, bank, equipment |
| `Wheel` | 200 | Radial selectors — matches the old game's deliberate 50 |
| `Overlay` | 300 | Full-screen modality: fades, loading, confirmations |
| `Debug` | 1000 | The existing F4 debugger root, folded in rather than left standalone |

**Declare the whole ladder; instantiate only what has screens.** The proving set populates `Hud`,
`Panel`, and `Debug` only — `Wheel` and `Overlay` would otherwise be two live `ScreenGui`s hosting
two React roots with nothing in them. So the constants table declares all five (the *ladder* is the
design — mapping the order space is exactly what prevents the census's "everything is
`DisplayOrder = 0`, ordering emerges from Explorer sibling order" failure), but a layer's `ScreenGui`
and root are **created lazily, on first screen registration**. No dead roots, no lost design.

## Decision 3 — visibility is DERIVED from state, never commanded

A `UIState` module of Charm atoms is the single source of truth for what is open. Screens read it
with `useAtom`, exactly as they read `ClientStore`. There is no `:Show()`, no `:Hide()`, no
`.Enabled` assignment anywhere outside `UILayers`.

This kills anti-patterns 1, 2, 3, and 10 at once: there is no instance-keyed state because there is
no instance-keyed anything; subscription is what an atom *is*; React diffs instead of rebuilding;
and there is no authored instance state to correct because the tree is rendered, not authored.

`ClientStore` (currency, inventory, stats, equipment, bank, appearance, entitlements) is the **only**
path from server state to a screen. UI-local state — category, sort, search query, tooltip target —
lives in `UIState` atoms or React `useState`, and never round-trips through the server.

## Decision 4 — the stack holds SCENES, and Escape pops it

The old game declared `ContextStack` and never used it; closing is per-panel and there is no generic
back. We build the stack for real — but a plain stack of *screens* is the wrong shape, and the
evidence says so: `BankUIController` instantiates **two full panel sets side by side**, one per side
of the transfer.

So the stack holds **scenes**. A scene is a named, declarative record: which screens it shows, in
which layers, and what it suppresses. `Bank` is one scene showing two container panels. This
subsumes the four hardcoded `ExclusiveSets` groups — mutual exclusion stops being a separate table
that must agree with another table, and becomes a consequence of a scene being one entry on one
stack.

- `push(scene)` / `pop()` / `replace(scene)`; Escape pops the top.
- **Escape semantics (developer decision, 2026-07-22): pop one scene. Nothing more.** A per-scene
  `escapeBlocking` opt-out was specced and then **cut before implementation — it had zero
  consumers.** No screen in this phase, or in any built domain, must resist dismissal; the first
  real case (death screen, tutorial) is several phases away and the opt-out is one field plus one
  branch in `pop()` when it arrives. Do not pre-build it.
- **Why the stack itself is not the same YAGNI case.** When the Input phase lands the seam is:
  *Input decides which key triggers a dismiss* (the binding, which `UIInput` hands over), *UI decides
  whether a dismiss is legal and what it dismisses* (the stack, which stays here). The stack survives
  that refactor untouched. It is also not speculative on its own terms — composition is immediate,
  not hypothetical: Bank is two co-visible panels, and the old game needed four `ExclusiveSets`
  groups across 38 registry entries to fake it.
- HUD screens are not on the stack — they are always mounted and read `UIState` to decide whether to
  dim or hide.
- **Conflict resolution is defined**, unlike the old game's last-write-wins: pushing a scene
  suspends the one below it rather than racing it.

**Input for the stack (developer decision, 2026-07-22): a minimal in-phase shim, not the Input
system.** Phase 7 needs exactly two bindings — a key to open the panel scene and Escape to pop —
plus `gameProcessed` honoring. That is the F4 debugger pattern (`DebuggerServiceClient`'s direct
`UserInputService.InputBegan`), lifted into one tiny `UIInput` module so it has a single home. It is
explicitly the thing the future Input phase replaces: when keymaps-as-data arrive, these two
bindings move there and `UIInput` is deleted. The full Input system (binding registry, context
sinks, gamepad, rebinding) stays its own Wave 1 phase — Movement needs it too, and half-building it
here would leave another system's skeleton in our closet.

## Decision 5 — suppression is one declarative record, refcounted, with seams for systems that don't exist yet

**This is the most important decision in the phase**, because it is where the framework touches
systems that are not built and must not be guessed at.

Each scene declares what it suppresses as data at the definition site — never a runtime-patched hook:

```
suppress = {
    movement = true,
    mouse = "unlock",
    blur = true,
    cameraState = "PanelOpen",
    characterRotation = "server",
}
```

The framework applies the **union across the whole stack, refcounted**, so co-open and nested scenes
compose correctly. This fixes the old game's non-refcounted `setState` directly, and adopts the
refcounted `pushInputLock`/`popInputLock` shape its own `InputManager` already had but the UI path
never used.

**The seam.** VFX/post-processing, Camera, and Input are all systems that do not exist yet. So
`UIWorldSuppression` defines the contract now and exposes `registerHandler(capability, handler)`.
**This phase ships exactly ONE handler — the mouse (`ModalEnabled`), which is unambiguously UI's own
job.** `blur`, `movement`, `cameraState`, and `characterRotation` are **declared but unhandled** —
logged once rather than silently no-oped — because their mechanisms belong to specialist systems
(a VFX/post-fx system owns blur, Input owns movement, Camera owns the rest). Those systems call
`registerHandler` and the declarations light up with **zero change to any scene or to the UI
framework**. (Revised 2026-07-22 at the developer's prompt: blur was briefly handled here via a
client `BlurEffect`; it was demoted to a seam so the UI phase does not reach into VFX territory — and
the demotion itself, a one-file change with nothing else touched, is the proof the seam is real.)

This mirrors Phase 6 exactly, which left the `LocomotionAnimator` pose API as a seam for the
Movement phase rather than guessing at parkour.

**Recorded for the Camera phase:** `MainGUIOpen` rotates `HumanoidRootPart` from camera X delta and
hands rotation authority to the server via a remote. Whether the rewrite keeps a UI-driven character
rotation at all is a Camera-phase decision, not ours — we record the old contract and declare the
intent (`characterRotation = "server"`), nothing more.

## Decision 6 — pure view-model, dumb component

`SpecRoots.EXEMPT_MODULES` currently lists every Debugger component individually. Extending that
per-file would balloon the list with each screen and quietly erode the spec-first rule.

The project already has the right pattern in two places — `CustomizationPlan` (pure, specced) +
`CustomizationApplication` (Instance shell, exempt), and `AnimationPlayer` (pure core, specced) +
`AnimationPlayerRuntime` (Animator shell, exempt). Applied here, structurally rather than by
convention:

- **`<Screen>ViewModel.luau`** — pure. Selectors over atoms, filtering, sorting, grouping, and what
  is actionable. Fully specced, no Instances, no React.
- **`<Screen>.luau`** — a React component that renders a view-model result. Exempt.

`SpecRoots` grows a **directory rule** for `Client.UI.React.*` instead of one entry per component,
with the pure/shell split as the stated justification. The rule is only sound because the view-model
split guarantees the exempt half holds no logic — that is why these are one decision, not two.

**Mounted component tests (added 2026-07-22, developer prompt).** The exemption is weaker than it
was in Phase 6, because our TestEZ suite runs in a **real Roblox runtime** (Studio / Open Cloud) —
there is no missing-DOM problem. `ReactRoblox.createRoot` + `act()` can mount a component into real
Instances inside a spec today, with zero new dependencies. Survey of the ecosystem:

- `Roblox/react-testing-library-lua` (the full `render()`/query/user-event port) **requires Jest
  Roblox and does not run under TestEZ**, and installs via Rotriever, not Wally. A second test
  runner is not worth this phase — rejected.
- `jsdotlua/react-test-renderer@17.2.1` is the same family and version as our React. Candidate for
  snapshot-style tree assertions without touching PlayerGui.

Policy: the **view-model split stands** — pure logic as plain functions is still the primary test
surface. On top of it, **shared primitives and the framework plumbing (scene stack, layer mounting,
suppression union) get mounted smoke tests** via `createRoot` + `act`. The implementation plan
carries a task to verify `react-test-renderer` resolves from Wally and pick between it and plain
`createRoot` mounting; whichever wins, the directory exemption then covers only *screen* components,
whose logic lives in their specced view-models.

## Decision 7 — CI gates the anti-patterns, as Phase 6 gated animation ids

Phase 6 established that an architectural rule worth stating is worth enforcing. Three gates, all
cheaply greppable:

1. **No `Instance.new("ScreenGui")`** outside `UILayers` — the `ResetOnSpawn` trap (Decision 2).
2. **No `.Enabled` / `.Visible` assignment on GUI objects** outside `UILayers` — visibility is
   derived (Decision 3).
3. **No `:FireServer` / `:InvokeServer` / direct `ByteNet` send from `Client.UI.React.*`** —
   components render; services talk to the server. This is anti-pattern 5, which the old
   `BankUIController` committed directly.

## Decision 8 — the proving set is one panel and one HUD

An abstraction proven against one class overfits to it. The two classes have opposite requirements —
panels are transient, input-capturing, and read mostly-static slice data; HUDs are permanent, never
capture input, and update at high frequency. Proving both now is barely more work and is the
difference between the framework absorbing combat's HUD later or fighting it.

- **Panel: Inventory.** The old game's per-panel sub-managers — `ItemFrameManager`, `SortManager`,
  `SearchManager`, `CategoryTabsManager`, `ScrollingItemInventoryManager`, `ItemInfoDisplay`,
  `ItemOptionsMenu` — were constructed as `(container, onChange, state)`. That is already
  component-shaped, and it is a free, evidence-backed component decomposition. It also proves
  reuse: the same grid component must serve inventory and bank, which is the client-side echo of the
  `ContainerValidation`/`ContainerPlacement` extraction Phase 4 already did on the server.
- **HUD: Vitals.** Deliberately chosen to stress *both* update paths — level and XP from the `stats`
  atom, health from `Humanoid.HealthChanged`. Not every HUD input is an atom, and the framework
  needs to prove it handles a high-frequency non-atom source without a per-frame re-render.

## Decision 9 — shared primitives now, gamepad navigation later

The old game has **no UI focus or selection model** — no `GuiService.SelectedObject` usage was found
anywhere. Whether pad navigation was ever supported is unknown.

Building navigation now, against two screens, would be speculative. Deferring it naively would mean
retrofitting focus into every screen later. The hedge: interactive elements are built as a small set
of shared primitives (`Button`, `Slot`, `Tab`, `Panel`), so navigation is added in **one place**
rather than N. Primitives must not assume mouse-only input.

## Decision 10 — the conversion plugin is SCAFFOLDING, not code generation

The developer has a plugin that converts authored UI instance trees into Roact. It is a genuine
accelerant and it changes the shape of the work, so its role is defined here rather than improvised
at implementation time.

**What it gives us, and it is the expensive half:** exact visual fidelity for free — every `UDim2`,
`Color3`, font, image id, corner radius, and layout constraint, transcribed without transcription
error. Hand-porting a screen is where visual drift creeps in silently, and there is a lot of surface
(`MainGUI` alone is 1,291 descendants). This is precisely the "UI is maintained" half of the
developer's direction, mechanized.

**What it does NOT give us**, and must not be mistaken for: plugin output is a flat mirror of the
instance tree — one enormous function, magic numbers throughout, no props, no state, no types, no
theme tokens, no reuse, no `--!strict`. It is a transcription, not an architecture. Landing it as-is
would rebuild the old game's problems in a new syntax, which is the one outcome this phase exists to
prevent.

**Therefore: converted output is an intermediate artifact that never lands.** Per screen:

1. Convert the authored tree → raw Roact dump, into scratch. **Not committed.**
2. Extract repeated subtrees → the shared primitives (`Button`, `Slot`, `Tab`, `Panel`).
3. Replace hardcoded colors, fonts, and sizes → theme tokens. The old game has no token layer at
   all; this is where it gets one.
4. Hoist every behavior into the view-model (Decision 6). The component ends as props-in, tree-out.
5. Delete the dump.

**Convert per screen and per component, never wholesale.** `GUI` is 2,574 descendants containing 30
nested `ScreenGui`s. A whole-tree conversion is unusable by construction.

**The existing CI gates already enforce this, which is a useful accident.** `--!strict` everywhere,
no `any`, no casts, and the file-length gate (PRs #3–4) mean a raw dump *cannot* merge — it would
fail on all four. The guardrail against "just commit the plugin output" is already installed and
needs no new rule.

## Decision 11 — what "modern technique" means here, concretely

Named so it is reviewable rather than aspirational. All of it is already available in the packages we
ship (`jsdotlua/react@17.2.1`, `react-roblox`, `react-charm`), and the Debugger overlay is a working
reference for most of it:

- **Function components and hooks only.** No legacy Roact class components, no `setState` merging
  semantics, no lifecycle methods.
- **Atom-driven state** via `useAtom` over `ClientStore` / `UIState` — subscription is what an atom
  *is*, replacing the old game's five subscription-less state singletons and hand-threaded `populate`
  closures.
- **Keyed children** so React reconciles a changed list. This is the direct structural answer to the
  census's destroy-every-frame-and-rebuild refresh strategy.
- **`useMemo` on view-model selectors**, so filtering, sorting, and grouping don't rerun on unrelated
  renders.
- **Bindings — not state — for high-frequency values.** This matters most for the Vitals HUD
  (Decision 8): a health bar driven by `Humanoid.HealthChanged` through `useState` re-renders the
  tree on every change. A `React.createBinding` updates the one property directly, no reconciliation.
  Proving this path is a large part of why the HUD is in the proving set at all.
- **Theme tokens** for every color, font, and spacing value — one module, no literals at call sites.
- **Composition over per-screen controllers.** The old game's unit of reuse was a 300–1,300-line
  controller class per screen; ours is a small primitive composed many times.

## What survives from the old game

- The **declarative screen→context mapping** idea — reborn as scenes, with React as the solver.
- **Named exclusive groups** as first-class data — subsumed into the scene stack, deduplicated.
- **Context lifecycle hooks as the single seam** where UI touches camera/input/lighting/mouse. When
  it was actually used, the entire suppression contract was six lines in one place. That
  concentration is right; the runtime patching is not.
- The **per-panel sub-manager decomposition** — a ready-made component tree.
- **Keymaps as data modules**, auto-registered by folder scan, with per-binding `prereq` predicates —
  recorded for the Input phase, not built here.

## Deliberately NOT in this phase

- **Screens for every built domain** — bank, equipment, customization, stats, currency. They follow,
  each with its own view-model; the framework is what is being proven here.
- **Gamepad / controller navigation** (Decision 9) and **mobile / touch layout** — no responsive
  evidence was examined, and the old `createTouchButton` path is unassessed.
- **Camera, Input, and movement-suppression handlers** — declared as contract, registered by their
  own phases (Decision 5).
- **Transitions beyond a basic fade.** The old fader was rewritten at least twice and is ~60%
  commented-out corpses. Motion design is not the unknown this phase exists to resolve.
- **Vanity slots, hotbar, and trading affordances** in the inventory panel — Vanity is an unbuilt
  Wave 1 system and Hotbar is genuinely blocked on combat's "use" verb. The gear screen gains those
  slots when they exist; that is a layout revision inside a proven framework, and it is the accepted
  cost of doing the framework first.
- **The 30 nested `ScreenGui`s under `GUI`** and the three junk empties — cutover cleanup, not port
  targets.
- **Anything with no consumer in this phase.** Standing rule, applied twice already (the
  `escapeBlocking` opt-out; eagerly-created roots for the `Wheel` and `Overlay` layers). A framework
  phase is where speculative infrastructure hides most easily, because "the framework should support
  it" always sounds like the responsible answer. It isn't: an unused seam is untested, undocumented
  by any call site, and gets redesigned the moment it acquires a real consumer. Declare the shape
  where the shape is load-bearing (the layer ladder); build the mechanism only when something calls
  it.

## Open questions — RESOLVED 2026-07-22

1. **Escape semantics** → pop one scene, full stop. The per-scene escape-blocking opt-out was
   specced and then cut: zero consumers (Decision 4).
2. **Panel camera rotating the character** → record the intent in the scene declaration
   (`characterRotation = "server"`); whether the behavior survives is decided at the Camera phase.
3. **`ClientStateStore`** → not investigated. It is an abandoned experiment and Charm has already
   won that argument; nothing in this design depends on why it failed.
4. **The root `SurfaceGui`** → ✅ RESOLVED 2026-07-22 (read-only Studio trace): **abandoned
   world-space experiment, no design impact.** Evidence: (a) its adornee is
   `Workspace.VFXParts.Part`, a generic folder of 43 anonymous transparent VFX-anchor parts all named
   `Part` — a scratch part, not a placed UI surface; (b) **no script references `VFXParts`**, this
   `SurfaceGui`, or its `Inventory` subtree, and nothing sets its `Adornee` at runtime (the only
   `SurfaceGui` refs in the codebase are the character stance indicator, leaderboards, and status
   billboards); (c) the live inventory the controllers actually drive is the ScreenGui path
   `PlayerGui.GUI.MainGUI.InventoryGUI…`. The 374-descendant match with `Banker` was coincidence —
   the trees are unrelated (this one is an inventory: `VanityFrames`, `Consumables`, `InventoryFrame`,
   `ItemInfo`, `EquipmentFrames`). **The layer table needs no world-space class**; Decision 2 stands
   unchanged. (Noted for later: this dead `SurfaceGui` is one more manual-cleanup item for cutover,
   alongside the 30 nested `ScreenGui`s under `GUI`.)

## Absorbed housekeeping

Per the standing agreement that small parked chores ride in a phase's opening commits rather than a
standalone PR:

- **Roadmap tidy** — move Phase 6 (Animation) from "In flight" to Completed / PR #13; put Phase 7
  in "In flight". Add the systems this phase's census confirms are missing from the inventory doc.
- **Registry-derived Cmdr enums for `anim-*`** — only if `CmdrTypes` is touched in this phase.
