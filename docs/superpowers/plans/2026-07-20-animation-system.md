# Animation System — Phase 6 (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the animation system from scratch — registry (CI-enforced single source of ids),
`AnimationPlayer` (sole owner of tracks), `LocomotionAnimator` (replaces the forked Roblox `Animate`),
declared interruption, and the service/packet surface — with **developer verification as a first-class
gate at every stage**, per the developer's explicit condition on approving the spec.

**Architecture:** All new code; nothing in the base is replaced except the engine's auto-inserted
`Animate` script (suppressed by shipping our own). Pure logic speccable; the Instance-touching shells
are the documented exemptions (the Customization split).

Spec: `docs/superpowers/specs/2026-07-20-animation-handler-design.md` (v2 clean-slate, APPROVED).
Branch: `feat/animation` (cut off main after PR #12).

## Global Constraints

- **`--!strict`, no `any`, no casts** (a `::` cast needs justification + a comment at the site).
- **Spec-first TDD.** Every new module gets a `.spec.luau` sibling written FIRST; the Instance shells
  (`AnimationPlayer`'s animator-touching half, the `Animate` shell script, service shells) are exempt
  with a reason in `SpecRoots.EXEMPT_MODULES`.
- **Plain commit messages. NO trailers.**
- **Server-authoritative; no animation state on the spine.** ByteNet only for discrete requests.
- Gate = FULL `bash scripts/check.sh` (WITH `wally install` — `--skip-install` corrupts link files).
- **Test services via Cmdr commands in a Play session, never via command-bar `require`** (command-bar
  requires get FRESH module copies, not the live singletons).
- **Do not push or open the PR without the developer's explicit go-ahead.**
- ⚠ Keep `Venture[Test]` closed in Studio while CI may run (open place → Open Cloud 409).

## Developer verification model (the point of this plan)

The developer asked for **more testing and verification than previous phases**. Concretely:

- **Six Studio checkpoints (V1–V6)**, each a named gate: the next task does not start until the
  developer has run the checklist and said so. They are testable in ~minutes each because the agent
  ships the harness (Cmdr commands + a Debugger panel) *before* the systems that need verifying.
- **The agent builds observability first** (Task 4): an F4 Debugger "Animations" panel showing live
  tracks, registry keys, interruption classes, and cache hits/misses — so every later checkpoint is
  *observed*, not eyeballed.
- **A kill switch** (`Workspace` attribute `LocomotionEnabled`, default true): flipping it makes
  `LocomotionAnimator` stop all its tracks and go inert, isolating "is it our animator?" during any
  investigation.
- **A full-suite TestEZ run in Studio** (`RunTests = true`) before the PR, plus the developer's
  free-play soak (V6).
- Every checkpoint that involves *feel* (locomotion especially) is explicitly the developer's call —
  the agent verifies mechanics, the developer verifies feel and id choices.

---

### Task 1: Registry foundation (Spec Decision 1)

**Files:** `src/ReplicatedStorage/Shared/Modules/Constants/Animations/` — `AnimationTypes.luau`
(exported types incl. `InterruptionClass`), `Locomotion.luau` (first domain module),
`AnimationRegistry.luau` (composed index) — each with a spec sibling.

**Solution:** per-domain data modules composed by a pure index into frozen `byId` / `byDomain` views.
`Locomotion` is seeded from the ids that ACTUALLY play today — the 57 `Animation` config-children of
the running `StarterCharacterScripts.Animate` fork (the live truth), not the stale tables — trimmed to
the locomotion set this phase animates (idle, walk, run, jump, fall, climb, swim, sit, death; sneak /
slow-walk / sprint-jump seeded but unused until Movement). Every id is provisional until V5.

- [ ] **Step 1: Failing specs** — canonical `rbxassetid://N` format asserted for every entry; index is
  frozen; no duplicate ids across domains; `byDomain` returns exactly the domain modules' entries;
  variants arrays well-formed; composition never mutates the domain modules.
- [ ] **Step 2: Implement** types, `Locomotion` seed, index.
- [ ] **Step 3: Gate green. Commit** — `feat(animation): registry foundation + locomotion domain`

---

### Task 2: CI id-scatter gate (Spec Decision 1)

**Files:** the project-rules check scripts (the PR #3–4 gate infrastructure) + its own red test.

**Solution:** the build FAILS if an animation asset id appears in first-party source outside
`Constants/Animations/` (spec fixtures allowlisted). This is the "make the six-id-sources disease
impossible" enforcement — land it before any consumer exists so it never has a grace period.

- [ ] **Step 1:** add the check; prove it fires (temporarily plant an id in a service, watch it go
  red, remove it).
- [ ] **Step 2: Gate green. Commit** — `chore(ci): forbid animation ids outside the registry`

---

### Task 3: AnimationPlayer (Spec Decisions 2 + 4)

**Files:** `src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau` (+ spec) for the pure core;
`AnimationPlayerRuntime.luau` (exempt shell, reason documented) for the Animator-touching half.

**Solution:** the only code that calls `LoadAnimation`. Pure core owns: cache keying per
(animator-identity, animationId), play-options resolution (registry defaults → per-call overrides),
live-track bookkeeping, and class-based stop selection (`attack` / `protected` / `ambient`). The shell
owns: actual load/play/stop, marker signals, cleanup on animator ancestry removal. Handles expose
stop / adjustSpeed / marker subscription / an ended signal — consumers never see raw tracks.

Testability: the pure core takes an injected animator seam (the `CustomizationCompatibility` trick),
so cache hits, bookkeeping, and stop selection are unit-tested with a fake animator and no Studio.

- [ ] **Step 1: Failing specs** — same (animator, id) twice → one load; distinct animators don't share
  tracks; play resolves registry defaults and per-call overrides in the right precedence; variant
  entries roll one of their listed ids; stop-by-class stops exactly the declared class and never
  `protected`; bookkeeping drops entries when the seam reports the animator gone; unknown id → typed
  error result, no throw.
- [ ] **Step 2: Implement** core + runtime shell.
- [ ] **Step 3: Gate green. Commit** — `feat(animation): AnimationPlayer track ownership`

---

### Task 4: Harness BEFORE consumers — services, packet, commands, Debugger panel

**Files:** `AnimationEvents.luau` (ByteNet, `Shared/Events`); `AnimationServiceServer` +
`AnimationServiceClient` (+ specs for their pure logic, shells exempt); Cmdr commands
(`anim-play`, `anim-stop`, `anim-stop-class`, `anim-tracks`, `anim-report`); a Debugger overlay
**Animations panel** (F4) listing, for the local character: playing tracks with registry key, domain,
class, priority, looped, speed, and **cache hit/miss counters**.

**Solution:** the verification harness ships before the systems it will verify. Server-initiated
requests ride one typed packet (server → owning client); the client service routes them through
`AnimationPlayer`. `anim-report` runs the registry dead-id check (Decision 6's report path) on demand.

- [ ] **Step 1: Failing specs** for pure parts (command arg validation via registry enums, packet
  payload shape, report formatting).
- [ ] **Step 2: Implement** packet, services, commands, panel.
- [ ] **Step 3: Gate green. Commit** — `feat(animation): services, commands, debugger panel`

**⟶ V1 — STUDIO CHECKPOINT (developer): the harness itself.**
`anim-play` a locomotion id on your character (via Cmdr, not the command bar) → it plays, panel shows
it with the right key/class/priority; play it again → cache HIT increments, no new load; `anim-stop`
fades it; a variant entry rolls different ids across repeats; `anim-report` output names every
registry key it checked; respawn → panel empties and repopulates cleanly, counters reset.

**⟶ V2 — STUDIO CHECKPOINT (developer): server-initiated path.**
From the server console (or an admin command flagged server-side), fire a stop-class and a play
request at your character → the packet round-trips, the client obeys, `protected` entries survive a
bulk `anim-stop-class attack`. Kill the client mid-request (leave) → server logs, no error spam.

---

### Task 5: LocomotionAnimator + Animate shell (Spec Decision 3) — the replacement

**Files:** `src/ReplicatedStorage/Client/.../LocomotionAnimator.luau` (+ spec for the pure state→pose
core); `src/StarterPlayer/StarterCharacterScripts/Animate.client.luau` (exempt shell — its name is
load-bearing: it suppresses the engine default).

**Solution:** Humanoid state events → pose decisions in a pure, table-driven core (state + speed →
pose name + fade + speed scale), executed through `AnimationPlayer` against the `Locomotion` domain.
Ships: idle/walk/run (speed-scaled), jump, fall, climb, swim/swim-idle, sit, death. Explicitly NOT
shipped (spec): weighted random sets, chat `/e` hooks, tool anims, sound markers, dodge input, FOV.
The kill switch (`LocomotionEnabled` attribute) stops all locomotion tracks and disconnects when
false, re-arms when true. A pose API (`setPose` / `clearPose` surface) is the seam Movement will use
for parkour states later — editing the script is not.

- [ ] **Step 1: Failing specs** — state transitions produce the right pose (running fast → run,
  running slow → walk, airborne after jump window → fall, seated → sit, dead → death + everything
  stopped); speed scaling math; kill switch stops everything and blocks new plays; pose API overrides
  and restores; re-entrant state events don't double-play (cache makes replay a no-op, but the CORE
  must not thrash fades).
- [ ] **Step 2: Implement** core + shell.
- [ ] **Step 3: Gate green. Commit** — `feat(animation): LocomotionAnimator replaces default Animate`

**⟶ V3 — STUDIO CHECKPOINT (developer): mechanics.** In staging with the panel open:
- Every state in the matrix: stand, walk, run, jump (anim fires once, lands into idle/walk correctly),
  long fall, climb a ladder/truss, swim + float idle, sit, die → respawn.
- Panel shows exactly ONE locomotion track playing per pose (no stacking, no orphan tracks after
  rapid state flapping — jump-spam, jump-into-swim, die-mid-climb).
- Kill switch OFF → character T-poses/engine-defaults-free (proves the engine default really is
  suppressed and everything on screen is ours); ON → recovers without respawn.
- Respawn and slot switch → animator rebinds; counters reset; nothing leaks (repeat 5×, watch the
  panel).
**⟶ V4 — STUDIO CHECKPOINT (developer): interaction with existing systems.**
Customization applies over an animating character (cosmetics mount mid-walk, no fight with 5c's
`observeCharacter` seam); equipment stat reapplication (WalkSpeed changes) scales walk/run correctly;
F4 debugger overall still healthy.

**⟶ V5 — STUDIO CHECKPOINT (developer): FEEL + id sign-off.** The subjective gate, explicitly yours:
does each pose look right, are fades right, is run speed-scaling right? The `Locomotion` seed ids came
from the old fork's config children — **replace any you dislike now** (one-line registry edits;
`anim-play` A/Bs candidates live). This checkpoint ends with you declaring the locomotion id set
final-for-now.

---

### Task 6: Registry boot report + full-suite run + soak

**Files:** boot-time dead-id report wiring in `AnimationServiceClient.start` (the `anim-report` logic,
run once, Logger summary — REPORTS, never throws); any findings from V1–V5 folded in.

- [ ] **Step 1:** wire the boot report; plant a bad id in a spec fixture to prove report-not-throw.
- [ ] **Step 2:** full TestEZ suite in Studio (`RunTests = true` — remember a test session is never a
  play session) → all green, screenshot/log for the PR.
- [ ] **Step 3: Gate green. Commit** — `feat(animation): boot-time registry report`

**⟶ V6 — SOAK CHECKPOINT (developer): free play.** Play staging normally for as long as you like —
movement everywhere, respawns, slot switches, customization changes, F4 panel occasionally. Anything
odd → agent fixes → re-soak. **The PR does not open until you call V6 done.**

---

### Task 7: PR

- [ ] Whole-branch review pass (the 5b/5c discipline), then PR with: census summary, all six
  checkpoint results as a table, the TestEZ run evidence, and the CI gate red-test note.
- [ ] Merge only per repo rules (merge commit, `Merge PR #N: ...`), after developer approval.
