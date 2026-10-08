# Character Replication R3 — Animation and Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Other players' puppets animate (locomotion derived from the movement records R2 already sends), server-granted actions play in sync on the owner's rig and every viewer's puppet (including a viewer who walks into range mid-action), far and off-screen puppets freeze under our own animation LOD, F4 shows the counters, and long falls never T-pose.

**Architecture:** Split by job. Gameplay callers (Cmdr `animplay` now; combat, abilities and emotes later) decide whether and what; `AnimationServiceServer:play` decides how (pure `ActionGrants`: replicable only, clamped speed, the server's variant, duration from the declared length, the layer's interruption rule) and hands the grant to `CharacterReplicationServiceServer` as **timed body state** of kind `"action"` (pure `BodyStates` store, `BodyStateRelay` routing: Started to the owner and observers, Stopped on an early stop, replay right after every `Enter`). On every client, `RigAnimation` plays the same `ActionStarted` on the owner rig and on puppets through the pure `BodyActions` core and the existing `AnimationPlayer`, drives one `LocomotionAnimator` per puppet from the pure `PuppetLocomotion` mapping of interpolated movement state, and freezes puppets by the pure `PuppetLod` tiers.

**Tech Stack:** Luau `--!strict`, ByteNetMax (typed reliable structs), SignalPlus via `SignalTyped`, TestEZ specs (Studio `RunTests`), Rojo 7.7, selene 0.31, StyLua 2.5, luau-lsp 1.68.1.

**Spec:** `docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md` (binding, approved). Tasks come only from its Scope "In", Decisions, Server, Viewer and owner client, LOD, F4 and Testing sections; nothing from its "Out" table. Parent: `docs/superpowers/specs/2026-09-22-character-replication-design.md` (§6.8, CP4, CP11). Format and conventions: the R2 plan `docs/superpowers/plans/2026-10-01-character-replication-r2-bodies-on-screen.md`.

## Global Constraints

- `--!strict` in every module; specs are intentionally untyped (repo rule). **No `any`** except mirroring an existing repo interface (`getState: (self) -> { [string]: any }`), **no `::` casts** in production code (`scripts/python/check_pr_rules.py` rejects `:: any` and warns on any uncommented `::`).
- **Service shape: lean annotated literal** — `export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax (AGENTS.md, `docs/conventions.md`).
- Discovery by filename: `*ServiceServer` under `ServerScriptService/Services`, `*ServiceClient` under `ReplicatedStorage/Client/Services`. Helper modules in those folders must NOT contain the word `Service`.
- **Pure core + thin shell.** Pure modules are written spec-first (`<Name>.spec.luau` before `<Name>.luau`). Every module under a spec root has a `.spec` sibling or an `EXEMPT_MODULES` entry with a reason in `src/ServerScriptService/Modules/SpecRoots.luau` (the suite fails otherwise).
- Max **400 code lines** per module (`scripts/python/check_file_length.py`; comments and blank lines don't count). `CharacterReplicationServiceServer` ends this plan at 390 code lines: do not grow it further without moving code out.
- Specs are TestEZ and run **only in Studio** (`RunTests` Workspace attribute). Specs under `ReplicatedStorage.Client` run on the SERVER during the suite, so client cores must not touch `Players.LocalPlayer` at require time.
- **Typed ByteNet structs** for every new reliable packet; no `ByteNet.unknown` in new code (this plan removes the last `ByteNet.unknown` packets from `AnimationEvents`).
- **Never run `bash scripts/check.sh` or `wally install`** anywhere. The developer serves the R2/R3 worktrees with `rojo serve` while testing: **never run any `rojo` command in a served worktree** (see Commands for the scratch-copy typecheck). The controller runs the Studio TestEZ suite; implementers run the static checks only.
- Never name other games or studios, or allude to "another game", in code comments, docs or commit messages. Library names (ByteNet, Charm, charm-sync, Chickynoid, SignalPlus) are fine.
- Commits: plain messages, **no `Co-Authored-By:` or `Claude-Session:` trailers** (AGENTS.md).
- **Server-authoritative.** Only the server grants actions (variant, speed, start time, duration); clients play what they are told and never write authoritative state.
- Each task header says **Runtime behaviour: yes/no**. The developer verifies "yes" tasks in Studio before the stack merges (developer rule: never merge runtime changes unverified).
- R2–R5 are stacked with no feature flag; do not add dual paths. The old owner-only `PlayRequest` path is replaced, not kept beside the new one.

## Review Focus

1. **A respawn mid-action, where the new epoch's Started reaches a client before its rig is rebuilt** (the owner's `Spawn` waits on a stream request; a puppet waits for the pool) — the old epoch's clip must stop and the new one must play on the rebuilt rig (Task 6 test `plays a new epoch's action on the rebuilt rig after a respawn mid-action`; Task 6 wires the owner's epoch from its own slot row, not from `Spawn`).
2. **A Stopped that arrives while the puppet is LOD-frozen** — the held track must stop, and unfreezing must not resume it (Task 6 test `stops a held clip when a Stopped arrives while frozen, and does not re-play it`).
3. **A body that leaves range and comes back while its action is still running** — the viewer drops it on Leave and must rejoin at the right point from the server's replay after Enter (Task 6 test `resumes at the right point when the body leaves range and comes back mid-action`).
4. **One player alone in the server** — with no observers, the owner must still receive and play its own grant (Task 5 test `sends Started to the owner even when nobody observes the body`).
5. **`animplay` asking for a variant the entry does not have** (`animplay me testpose 1 1`) — refused server-side with a reason, nothing reaches the wire (Task 7 test `refuses a variant the entry does not have, before anything reaches the channel`).

## Rulings this plan makes (where the spec was silent or conflicted)

Each is binding for the implementer. Format: ruling — why — cost if wrong.

1. **Typed channel instead of `setBodyState(player, kind, key, data, …)`.** `CharacterReplicationServiceServer:defineBodyState(kind, senders)` returns a typed `BodyStateRelay.Channel<D>` with `set(player, key, data, startMs, durationMs?)`, `clear(player, key)`, `get(player, key)`. — A string `kind` cannot type `data` per kind without `any` or casts; a generic channel does (verified with luau-lsp 1.68.1: a wrong data shape is a type error at the call). — Callers hold a handle instead of passing a kind string; a thin wrapper can be added later at no cost.
2. **`MAX_BODY_STATES` = 8 per body per kind** (one `BodyStates` store per kind), **`MAX_OPEN_STATE_MS` = 30 000**. — One typed store per kind; there is one kind today. — A body could hold 8 × kinds states; harmless.
3. **Puppets play actions at their render time; the owner at the session clock.** A puppet's clock is `sessionNow − renderDelay`, so an action whose start is still ahead of render time stays pending until the render clock reaches it, and `startAt = (renderTime − startMs) × speed`. — The spec's "`now − startMs`" read literally starts the clip a render delay (100–300 ms) ahead of the motion being drawn; the spec's own frame-order rule ("pose and position come from the same interpolated moment") and the spike (CP11 played the clip "when the render clock reaches it") both mean render time. — If wrong, puppets' actions start one render delay later than the owner's, which is exactly where their bodies are drawn.
4. **The owner's body epoch comes from its own `SlotEntry` row, not from `Spawn`.** — The server bumps the epoch and broadcasts the slot row synchronously, but sends `Spawn` only after `RequestStreamAroundAsync` (up to 5 s); a grant in that gap would otherwise reach the owner as "stale". — None.
5. **Stand-ins are a new `Actions` domain**: `testleap` (full, attack, one variant, Action2; sprintjump's two assets), `testguard` (full, protected, Action2; jumpland's asset), `testpose` (upper, looped, open-ended, Action; sneakidle's asset), wire ids 1–3. Locomotion entries stay non-replicable. — The spec's Registry section keeps locomotion local, and locomotion entries are Core priority (CP11: an action at Core blends at half weight with locomotion). — Three entries to delete when real actions land; their wire ids are retired forever.
6. **Layer interruption rule:** a new grant replaces the layer's current grant unless the current one is `protected` and the new one is not. — The existing classes, applied per layer: an attack cannot cut a dodge or hit reaction; a hit reaction can cut an attack; an `ambient` action yields to anything. — A combat design that needs a different matrix edits one pure function (`ActionGrants.canReplace`).
7. **Registry rules:** a replicable entry needs an integer `wireId` 1–65535 unique across the registry, a known `layer`, and (one-shots only) `durationMs > 0`; a looped replicable entry must omit `durationMs`; a local entry carries none of the three; a replicable entry has at most 255 variants. All asserted at compose time. — Fails at require, like the existing registry rules. — None.
8. **Speed is clamped to 0.25–4 and quantised to thousandths on the server**, and the wire carries that exact value; `animplay` gains an optional `variant` argument. — The server's duration and every client's clip time are computed from the same number. — None.
9. **Clients never stop a one-shot when its grant's time is up** (the clip ends by itself); they stop only open-ended grants (at the safety cap), early stops, epoch changes, released puppets, and a held (frozen) clip whose time has run out. — Stopping at the declared duration would cut a clip whose declaration is slightly short. — A clip longer than declared plays its tail while the layer is already free.
10. **The safety cap is a shared constant** (`BodyStateTiming.MAX_OPEN_STATE_MS`) applied by both ends without a message: the server prunes lazily (and warns when it prunes a capped state), clients stop the loop in their per-frame step. — The spec's "cleared lazily, no per-state timers" plus "every screen must end it" leaves no other way without a message. — The server's warning fires when the capped state is next touched (a grant, stop or replay on that body), not at the 30 s mark.
11. **No death hook in R3.** There is no server-side death in R2/R3 (body health has no damage source). Clearing is wired to respawn (epoch bump), slot switch (a respawn) and leave. The Death phase adds a clear-with-stop call where it decides death. — Nothing to hook. — None until that phase.
12. **The whole old request path goes:** `PlayRequest`, `StopRequest` **and** `StopClassRequest` packets, `Shared/Modules/AnimationRequests.luau` (+spec), `playOnCharacter`, `stopOnCharacter`, `stopAttacksOnCharacter`, `validatePlay`. The service API becomes `play` / `stop` / `stopAttacks`; `stopAttacks` takes no fade (Stopped carries none; clients use the player's default fade). — The spec routes the bulk attack stop through `clearBodyState` too, which leaves `StopClassRequest` dead. — None.
13. **F4 "replayed-on-enter":** counted exactly on the server (`bodyStates.action.replayed`). The viewer counts `joinedLate` (an action that started more than 250 ms into its clip): a client cannot tell a replay from a fresh Started without correlating it with `Enter`, and for puppets a fresh Started starts at ~0. — Good enough for the checklist. — None.
14. **Readout constants:** length-check tolerance 50 ms, checked once per (entry, variant) per client after the clip has loaded (`Length` is 0 until then); drift sampled at 4 Hz; late-join threshold 250 ms.
15. **`PuppetLocomotion` maps by state alone** (grounded unused: the owner's animator also decides by state), sends on change only (another event, or a speed change of at least max(0.25 studs/s, 5 %)), and the §6.8 0.7–1.4 play-rate clamp applies to walk and run strides only (`LocomotionAnimator` gains optional `minRate` / `maxRate`; climb and swim stay unclamped, so a still climber does not crawl).
16. **The freefall fix adds `LocomotionAnimator:update(now)`**, driven every Heartbeat by `LocomotionBinding` on the owner and every frame by `RigAnimation` on puppets. The fall pose starts when the jump window (0.31 s) ends — not at the end of the 1.2 s jump clip as the spec's wording suggests; the window is what the stock script does and what the existing tests pin.
17. **LOD:** the Reduced tier is not built (the spec makes it conditional on visible pops; the checklist asks). Hysteresis 25 studs, edge margin 64 px, checks staggered at 4 Hz. Unfreezing recreates the puppet's `LocomotionAnimator` so the current pose re-plays whatever the engine did with the held tracks. The Workspace attribute `PuppetLodEnabled = false` keeps every puppet full (for the LOD-off measurement). The pause mechanism is a constant (`LOD_PAUSE_MODE`, both modes implemented) set by the Task 9 measurement.
18. **`ActionStarted` addresses the body by `userId` and carries its `epoch`**, not a slot, so the owner and viewers share one receiver and stale epochs are dropped.
19. **`sendToObservers(player, …)` includes the player itself**; `observersOf(player)` never does.
20. **Line cap:** `observeBodies` moves verbatim into `BodyObservers` (specced); `BodyStateRelay` logs its two warnings through `Logger` directly.
21. **Puppets always have an Animator** (`PuppetPool` creates one when the template lacks it), and each puppet warms the locomotion set on attach (a pooled puppet keeps its cache).

## Changes from the spike this plan adds (not in the spec's "Changes from the spike" table)

| Spike | This plan | Why |
|---|---|---|
| The server's grant checked a 300 ms cooldown and refused dead or ragdolled bodies | The grant checks only "has a live body" | Decision 2: cooldowns and permission belong to the calling gameplay system; dead/ragdoll belong to the Death and Ragdoll phases, which have no events in R3 |
| A grant ended on ragdoll or death | Grants end on early stop, duration, safety cap, respawn, slot switch, leave | No ragdoll or death events exist yet (ruling 11) |
| Viewers treated a start that moved by more than 150 ms as a new play | Every `ActionStarted` is a new grant (replace on its layer); `ActionStopped` names its start | The start time is explicit on a reliable message; no latch tolerance is needed |
| Stand-ins `sprintjump` and `sit` played from the locomotion domain at Core | A new `Actions` domain at Action/Action2 priority, reusing sprintjump's, jumpland's and sneakidle's assets | Ruling 5 |
| The spike wrapped `AnimationServiceServer.playOnCharacter` in place | `play` / `stop` / `stopAttacks`; `playOnCharacter`, `stopOnCharacter`, `stopAttacksOnCharacter` and the `StopClassRequest` packet are removed | Ruling 12 |
| The owner learned its epoch from its own spawn | The owner's action epoch comes from its own slot row | Ruling 4 |

## File Structure

```
src/ReplicatedStorage/Client/Services/AnimationService/
  LocomotionAnimator.luau(+spec)            (T1) freefall fix + update(now); (T8) minRate/maxRate stride clamp
  LocomotionBinding.luau                    (T1) Heartbeat update
  AnimationServiceClient.luau               (T7) request listeners removed
src/ReplicatedStorage/Shared/Modules/
  AnimationPlayer.luau(+spec)               (T2) variant, startAt, setPaused, handle timePosition/length
  AnimationPlayerRuntime.luau               (T2) seam setTimePosition/timePosition/length
  AnimationRequests.luau(+spec)             (T7) deleted
  Constants/Animations/AnimationTypes.luau(+spec)     (T3) layers, wire fields, lookups
  Constants/Animations/AnimationRegistry.luau(+spec)  (T3) replication checks, idForWire, Actions domain
  Constants/Animations/Actions.luau(+spec)            (T3) NEW stand-in actions
  Constants/Animations/Locomotion.spec.luau           (T3) "no locomotion entry is replicable"
  CharacterReplication/BodyStateTiming.luau(+spec)    (T4) NEW shared end-time rule + safety cap
  CharacterReplication/CharacterInterpolator.luau(+spec) (T8) motionAt
src/ReplicatedStorage/Shared/Events/
  CharacterReplicationEvents.luau           (T5) ActionStarted / ActionStopped
  AnimationEvents.luau                      (T7) request packets removed
src/ServerScriptService/Services/CharacterReplicationService/
  BodyStates.luau(+spec)                    (T4) NEW pure per-kind store
  ObserverQuery.luau(+spec)                 (T5) NEW observersOf / observersNear / sendToObservers
  BodyStateRelay.luau(+spec)                (T5) NEW kinds, routing, replay, clearing
  BodyObservers.luau(+spec)                 (T5) NEW observeBodies moved out of the shell
  CharacterReplicationServiceServer.luau    (T5) body-state API, replay on Enter, clears
src/ServerScriptService/Services/AnimationService/
  ActionGrants.luau(+spec)                  (T7) NEW pure grant rules
  AnimationServiceServer.luau(+spec)        (T7) play / stop / stopAttacks over the "action" channel
src/ServerScriptService/Commands/
  AnimPlay.luau, AnimPlayServer.luau(+spec)            (T7) routes to play, optional variant
  AnimStop.luau, AnimStopServer.luau(+spec)            (T7) id or layer
  AnimStopClass.luau, AnimStopClassServer.luau(+spec)  (T7) stopAttacks
src/ReplicatedStorage/Client/Services/CharacterReplicationService/
  BodyActions.luau(+spec)                   (T6) NEW pure action receiver
  RigAnimation.luau                         (T6) NEW shell [spec-exempt]; (T8) puppet locomotion; (T9) LOD
  PuppetPool.luau                           (T6) Animator on every puppet
  CharacterReplicationServiceClient.luau    (T6) wiring; (T8) frame args
  RemoteBodies.luau(+spec)                  (T8) motion fields per placed body
  PuppetLocomotion.luau(+spec)              (T8) NEW pure state → event mapping
  PuppetLod.luau(+spec)                     (T9) NEW pure LOD tiers
src/ServerScriptService/Modules/SpecRoots.luau      (T6) RigAnimation exemption
docs/animation.md, docs/architecture.md, docs/ROADMAP.md, the R3 spec   (T10)
```

## Commands

Run from the worktree root `B:\Projects\venture-game-systems\.claude\worktrees\replication-animation` (Git Bash). Branch `feature/replication-animation`, stacked on R2 `feature/replication-bodies` (PR #29). The package folders and `globalTypes.d.luau` are already in this worktree (gitignored); never run `wally install`.

| Purpose | Command |
|---|---|
| Format | `stylua <touched paths>` then `stylua --check src` |
| Lint | `selene src` |
| Typecheck | see below — no NEW diagnostics anywhere (the tree is clean before R3) |
| File length | `python scripts/python/check_file_length.py` |
| Project rules | `python scripts/python/check_pr_rules.py feature/replication-bodies` (casts, trailers, asset ids) |
| Tests | Studio only, run by the controller: the developer serves THIS worktree with `rojo serve` and connects; set the Workspace boolean attribute `RunTests = true`, press Play, read Output. Expected tail: `<N> passed, 0 failed, 0 skipped`. Remove the attribute afterwards (a test session destroys live singletons; never play in it). |

**Typecheck without touching a served worktree.** `luau-lsp` needs a sourcemap, and `rojo sourcemap` must not run in a worktree the developer is serving.

- A task that only **modifies** existing files: use the worktree's existing `sourcemap.json`:
  `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src`
- A task that **adds or deletes** files: regenerate the sourcemap in the worktree only when the controller confirms the worktree is not being served; otherwise typecheck a scratch copy (it carries the packages, `rokit.toml` and `globalTypes.d.luau`):

```bash
SCRATCH="$TEMP/r3-typecheck"   # or the session scratchpad
rm -rf "$SCRATCH" && mkdir -p "$SCRATCH" && tar --exclude=.git -cf - . | (cd "$SCRATCH" && tar xf -)
cd "$SCRATCH" && rojo sourcemap default.project.json --output sourcemap.json \
  && luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src
```

Every task's code below was typechecked, linted, formatted and length-checked stage by stage in such a scratch copy while writing this plan (all ten stages clean).

**Applying the code.** New files are given in full. Changes to existing files are given as unified diffs against the tree as the previous task leaves it: apply each with `git apply` (save the block to a file in your scratchpad, then `git apply <file>` from the worktree root), or make the same edit by hand. A diff that does not apply means the tree is not where the previous task left it: stop and report.

Each task's "run the tests" step means the Studio run above. When an implementer cannot drive Studio, stop at that step and hand it to the controller with the exact spec names expected to fail or pass. Steps marked **(controller, Studio)** are measurements the controller runs and hands back.

---
### Task 1: `LocomotionAnimator` — the long-fall T-pose fix

**Runtime behaviour: yes** — on the owner's own rig, a fall that starts inside the jump window now plays the fall pose when the window (0.31 s) ends, instead of nothing once the one-shot jump clip finishes.

The bug: the Humanoid fires `FreeFalling` once per fall, usually a few frames after `Jumping`. `handleEvent("freefall")` ignored it inside the jump window, and nothing re-sent it, so `pose` stayed `"jump"`; when the 1.2 s jump clip ended, no track played (T-pose) for the rest of the fall. The fix remembers that freefall and applies it from a per-frame `update(now)`. **The developer asked to see this exact before/after change: show the implementation diff in Step 3 at review.**

**Files:**
- Modify: `src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau`
- Modify: `src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau`
- Test: `src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau`

**Interfaces:**
- Produces: `LocomotionAnimator:update(now: number) -> ()` (on the `LocomotionAnimator` type). Puppets call it every frame in Task 8.

- [ ] **Step 1: Write the failing specs**

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
index d83492a..4452819 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
@@ -127,6 +127,90 @@ return function()
 		end)
 	end)
 
+	-- The long-fall T-pose fix: the Humanoid reports Freefall ONCE, usually inside the jump window. Before
+	-- the fix that freefall was dropped, and once the one-shot jump clip ended nothing played at all.
+	describe("a freefall inside the jump window", function()
+		it("plays the fall pose when the jump window ends", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
+			animator:handleEvent("jumping", nil, 10)
+			animator:handleEvent("freefall", nil, 10.1)
+			animator:update(10.2)
+			expect(animator:currentPose()).to.equal("jump")
+			animator:update(10.31)
+			expect(animator:currentPose()).to.equal("fall")
+		end)
+
+		it("plays the fall pose once, not on every later update", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
+			animator:handleEvent("jumping", nil, 10)
+			animator:handleEvent("freefall", nil, 10.1)
+			animator:update(10.31)
+			animator:update(10.5)
+			animator:update(12)
+			expect(#fake.plays).to.equal(2) -- jump, then fall
+			expect(lastPlay(fake).id).to.equal("fall")
+		end)
+
+		it("forgets the remembered fall when the body lands inside the window", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
+			animator:handleEvent("jumping", nil, 10)
+			animator:handleEvent("freefall", nil, 10.1)
+			animator:handleEvent("running", 0, 10.2)
+			animator:update(10.5)
+			expect(animator:currentPose()).to.equal("idle")
+		end)
+
+		it("a second jump restarts the window and the fall waits for it", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
+			animator:handleEvent("jumping", nil, 10)
+			animator:handleEvent("freefall", nil, 10.1)
+			animator:handleEvent("jumping", nil, 10.25)
+			animator:handleEvent("freefall", nil, 10.3)
+			animator:update(10.5)
+			expect(animator:currentPose()).to.equal("jump")
+			animator:update(10.6)
+			expect(animator:currentPose()).to.equal("fall")
+		end)
+
+		it("does nothing on update when no fall is remembered", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake)
+			animator:handleEvent("running", 20, 0)
+			animator:update(5)
+			expect(animator:currentPose()).to.equal("run")
+			expect(#fake.plays).to.equal(1)
+		end)
+
+		it("forgets the remembered fall when disabled, overridden or dead", function()
+			local disabled = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
+			disabled:handleEvent("jumping", nil, 10)
+			disabled:handleEvent("freefall", nil, 10.1)
+			disabled:setEnabled(false)
+			disabled:setEnabled(true)
+			disabled:update(11)
+			expect(disabled:currentPose()).to.equal("idle")
+
+			local overridden = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
+			overridden:handleEvent("jumping", nil, 10)
+			overridden:handleEvent("freefall", nil, 10.1)
+			overridden:setPoseOverride("sneakidle")
+			overridden:clearPoseOverride()
+			overridden:update(11)
+			expect(overridden:currentPose()).to.equal("idle")
+
+			local dead = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
+			dead:handleEvent("jumping", nil, 10)
+			dead:handleEvent("freefall", nil, 10.1)
+			dead:handleEvent("died", nil, 10.2)
+			dead:update(11)
+			expect(dead:currentPose()).to.equal(nil)
+		end)
+	end)
+
 	describe("other states", function()
 		it("swims when moving and swim-idles when not", function()
 			local fake = makeFakePlayer()
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected: the six tests under `a freefall inside the jump window` FAIL (`update` is nil); every other test passes.

- [ ] **Step 3: Implement the fix (the before/after for the developer)**

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
index 7c527ea..bed4b36 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
@@ -64,6 +64,7 @@ export type LocomotionEvent =
 
 export type LocomotionAnimator = {
 	handleEvent: (self: LocomotionAnimator, event: LocomotionEvent, speed: number?, now: number) -> (),
+	update: (self: LocomotionAnimator, now: number) -> (),
 	currentPose: (self: LocomotionAnimator) -> string?,
 	setEnabled: (self: LocomotionAnimator, enabled: boolean) -> (),
 	isEnabled: (self: LocomotionAnimator) -> boolean,
@@ -135,6 +136,10 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 	local pose: string? = nil
 	local handle: AnimationPlayer.PlayHandle? = nil
 	local jumpUntil = -math.huge
+	-- A freefall reported INSIDE the jump window, applied by `update` once the window ends. The Humanoid
+	-- reports Freefall once per fall, usually a few frames after Jumping, so without this memory the fall
+	-- pose never plays: the one-shot jump clip ends (~1.2 s) and a longer fall shows no pose at all.
+	local pendingFall = false
 
 	-- Switches to `nextPose`, or just retunes speed when the pose is unchanged (replaying a
 	-- looped pose would thrash its fade — the failure V3's pose-flap check watches for).
@@ -182,12 +187,17 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 					handle = nil
 				end
 				stopPose(FADE_BY_POSE.died)
+				pendingFall = false
 				dead = true
 				return
 			end
 			if not enabled or overridePose ~= nil then
 				return
 			end
+			-- Any other state supersedes a remembered fall (a landing, a second jump, a climb).
+			if event ~= "freefall" then
+				pendingFall = false
+			end
 			if event == "running" then
 				local moveSpeed = speed or 0
 				if moveSpeed <= IDLE_SPEED then
@@ -203,6 +213,8 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 			elseif event == "freefall" then
 				if now >= jumpUntil then
 					setPose("fall")
+				else
+					pendingFall = true
 				end
 			elseif event == "climbing" then
 				setPose("climb", (speed or 0) / climbScale)
@@ -219,6 +231,20 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 			end
 		end,
 
+		--[=[
+			Per-frame tick: applies a freefall that arrived inside the jump window once the window has
+			ended. Cheap when nothing is pending; the binding calls it every Heartbeat.
+		]=]
+		update = function(_self: LocomotionAnimator, now: number)
+			if not pendingFall or destroyed or dead or not enabled or overridePose ~= nil then
+				return
+			end
+			if now >= jumpUntil then
+				pendingFall = false
+				setPose("fall")
+			end
+		end,
+
 		currentPose = function(_self: LocomotionAnimator): string?
 			return if overridePose ~= nil then overridePose else pose
 		end,
@@ -233,6 +259,7 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 				return
 			end
 			enabled = nextEnabled
+			pendingFall = false
 			if not enabled then
 				-- Stop the override BEFORE forgetting it (Qodo PR #13): stopPose only knows the
 				-- state-driven pose, so clearing overridePose first would orphan its track.
@@ -264,6 +291,7 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 				return false, "disabled"
 			end
 			stopPose(DEFAULT_FADE)
+			pendingFall = false
 			local overrideHandle, reason = player:play(id, opts)
 			if overrideHandle == nil then
 				-- Refusal falls back to the state-driven pose so the character is never frozen.
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau
index 0f81ade..6ca6a60 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau
@@ -19,6 +19,7 @@
 ]=]
 
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local RunService = game:GetService("RunService")
 local Workspace = game:GetService("Workspace")
 
 local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
@@ -95,6 +96,10 @@ function LocomotionBinding.bind(character: Model): (() -> ())?
 		humanoid.Died:Connect(function()
 			animator:handleEvent("died", nil, os.clock())
 		end),
+		-- Applies a freefall that arrived inside the jump window once the window ends.
+		RunService.Heartbeat:Connect(function()
+			animator:update(os.clock())
+		end),
 	}
 
 	-- Start at idle (the stock script's "initialize to idle").
```

- [ ] **Step 4: Static checks**

Run: `stylua src/ReplicatedStorage/Client/Services/AnimationService && stylua --check src && selene src`, the typecheck (existing sourcemap: no files added), `python scripts/python/check_file_length.py`.
Expected: clean.

- [ ] **Step 5: Run the tests (controller, Studio) — expect all to pass**

Expected tail: `<N> passed, 0 failed, 0 skipped`.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/AnimationService
git commit -m "fix(animation): play the fall pose after the jump window on long falls"
```

---

### Task 2: `AnimationPlayer` — chosen variant, start point, pause, time and length on the seam

**Runtime behaviour: no** — new options and verbs; no existing caller passes them.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau`
- Test: `src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau`

**Interfaces:**
- Produces:
  - `SeamTrack` gains `setTimePosition: (seconds: number) -> ()`, `timePosition: () -> number`, `length: () -> number` (0 until loaded).
  - `PlayOpts` gains `variant: number?` (0 = the entry's own asset, k = `variants[k]`; nil rolls) and `startAt: number?` (clip seconds; wrapped for a looped entry).
  - `AnimationPlayer:play` returns `nil, "bad-variant"` for a variant out of range or not whole, and `nil, "elapsed"` for a one-shot whose `startAt` is past its length. An already-playing looped track with `startAt` is re-seeked, not restarted.
  - `PlayHandle` gains `timePosition(self) -> number` (0 once superseded) and `length(self) -> number`.
  - `AnimationPlayer` gains `setPaused(self, paused: boolean)` and `isPaused(self) -> boolean`: every live track held at speed 0, each restored to its own speed; plays while paused start held; `adjustSpeed` while paused is remembered.

- [ ] **Step 1: Write the failing specs**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau b/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau
index 2d36ee9..2a35e2f 100644
--- a/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau
+++ b/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau
@@ -46,6 +46,9 @@ local function makeSeam(options)
 			looped = nil,
 			endedCallbacks = {},
 			markerCallbacks = {},
+			timePos = 0,
+			seeks = {},
+			clipLength = options.length or 0, -- 0 = not loaded yet, like a real track
 		}
 		track.play = function(fadeTime, weight, speed)
 			track.playCalls += 1
@@ -84,6 +87,16 @@ local function makeSeam(options)
 				track.markerCallbacks[markerName] = nil
 			end
 		end
+		track.setTimePosition = function(seconds)
+			track.timePos = seconds
+			table.insert(track.seeks, seconds)
+		end
+		track.timePosition = function()
+			return track.timePos
+		end
+		track.length = function()
+			return track.clipLength
+		end
 		table.insert(seam.tracks, track)
 		return track
 	end
@@ -235,6 +248,148 @@ return function()
 		end)
 	end)
 
+	-- R3: a replicated action plays the SERVER's variant on every screen (the spike saw owner and viewers
+	-- roll different clips).
+	describe("chosen variant", function()
+		it("plays the requested variant instead of rolling", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam, function(_count)
+				error("a requested variant must not roll")
+			end)
+			player:play("reaction", { variant = 2 })
+			expect(seam.tracks[1].assetId).to.equal("rbxassetid://12")
+		end)
+
+		it("treats variant 0 as the entry's own asset", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam, function(_count)
+				return 3
+			end)
+			player:play("reaction", { variant = 0 })
+			expect(seam.tracks[1].assetId).to.equal("rbxassetid://10")
+		end)
+
+		it("refuses a variant out of range or not whole, before loading anything", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam)
+			local handle, reason = player:play("reaction", { variant = 3 })
+			expect(handle).to.equal(nil)
+			expect(reason).to.equal("bad-variant")
+			expect(select(2, player:play("reaction", { variant = 1.5 }))).to.equal("bad-variant")
+			expect(select(2, player:play("reaction", { variant = -1 }))).to.equal("bad-variant")
+			expect(select(2, player:play("swing", { variant = 1 }))).to.equal("bad-variant")
+			expect(#seam.loads).to.equal(0)
+		end)
+	end)
+
+	-- R3: a viewer joining an action mid-way starts the clip at the owner's point in it.
+	describe("start point", function()
+		it("starts a one-shot that many seconds into the clip", function()
+			local seam = makeSeam({ length = 1.2 })
+			local player = makePlayer(seam)
+			player:play("swing", { startAt = 0.4 })
+			expect(seam.tracks[1].playCalls).to.equal(1)
+			expect(seam.tracks[1].timePos).to.be.near(0.4, 1e-6)
+		end)
+
+		it("wraps the start point of a looped clip", function()
+			local seam = makeSeam({ length = 1 })
+			local player = makePlayer(seam)
+			player:play("idle", { startAt = 2.25 })
+			expect(seam.tracks[1].timePos).to.be.near(0.25, 1e-6)
+		end)
+
+		it("refuses a one-shot whose start point is past its end, without playing", function()
+			local seam = makeSeam({ length = 1 })
+			local player = makePlayer(seam)
+			local handle, reason = player:play("swing", { startAt = 1.5 })
+			expect(handle).to.equal(nil)
+			expect(reason).to.equal("elapsed")
+			expect(seam.tracks[1].playCalls).to.equal(0)
+			expect(#player:playing()).to.equal(0)
+		end)
+
+		it("seeks as asked while the clip's length is not known yet", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam)
+			player:play("swing", { startAt = 0.4 })
+			expect(seam.tracks[1].timePos).to.be.near(0.4, 1e-6)
+		end)
+
+		it("does not seek when no start point is given", function()
+			local seam = makeSeam({ length = 1 })
+			local player = makePlayer(seam)
+			player:play("swing")
+			expect(#seam.tracks[1].seeks).to.equal(0)
+		end)
+
+		it("re-seeks an already-playing looped clip instead of restarting it", function()
+			local seam = makeSeam({ length = 2 })
+			local player = makePlayer(seam)
+			player:play("idle")
+			player:play("idle", { startAt = 0.5 })
+			expect(seam.tracks[1].playCalls).to.equal(1)
+			expect(seam.tracks[1].timePos).to.be.near(0.5, 1e-6)
+		end)
+	end)
+
+	describe("handle time and length", function()
+		it("reads the track's time position and length through the handle", function()
+			local seam = makeSeam({ length = 1.5 })
+			local player = makePlayer(seam)
+			local handle = player:play("swing", { startAt = 0.3 })
+			expect(handle:timePosition()).to.be.near(0.3, 1e-6)
+			expect(handle:length()).to.equal(1.5)
+		end)
+
+		it("reports time position 0 from a superseded handle", function()
+			local seam = makeSeam({ length = 1.5 })
+			local player = makePlayer(seam)
+			local first = player:play("swing", { startAt = 0.3 })
+			player:play("swing", { startAt = 0.6 })
+			expect(first:timePosition()).to.equal(0)
+		end)
+	end)
+
+	-- R3 puppet LOD (speed mode): a frozen puppet holds its pose with every track at speed 0.
+	describe("pause", function()
+		it("holds every live track at speed 0 and resumes each at its own speed", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam)
+			player:play("swing", { speed = 2 })
+			player:play("idle", { speed = 0.5 })
+			player:setPaused(true)
+			expect(player:isPaused()).to.equal(true)
+			expect(seam.tracks[1].speed).to.equal(0)
+			expect(seam.tracks[2].speed).to.equal(0)
+			player:setPaused(false)
+			expect(seam.tracks[1].speed).to.equal(2)
+			expect(seam.tracks[2].speed).to.equal(0.5)
+		end)
+
+		it("starts a play made while paused held at speed 0", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam)
+			player:setPaused(true)
+			player:play("swing", { speed = 1.5 })
+			expect(seam.tracks[1].speed).to.equal(0)
+			player:setPaused(false)
+			expect(seam.tracks[1].speed).to.equal(1.5)
+		end)
+
+		it("remembers a speed change made while paused", function()
+			local seam = makeSeam()
+			local player = makePlayer(seam)
+			local handle = player:play("swing")
+			player:setPaused(true)
+			handle:adjustSpeed(3)
+			expect(seam.tracks[1].speed).to.equal(0)
+			player:setPaused(false)
+			expect(seam.tracks[1].speed).to.equal(3)
+			expect(player:playing()[1].speed).to.equal(3)
+		end)
+	end)
+
 	describe("asset aliasing", function()
 		-- Qodo PR #13 finding: the cache is per (registry id, asset), so two entries sharing an
 		-- asset id get INDEPENDENT tracks — no priority/looped/stop cross-talk.
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected FAIL: every new test under `chosen variant`, `start point`, `handle time and length` and `pause`, except `does not seek when no start point is given` (true before the change too). The existing tests still pass (the fake seam only gained fields).

- [ ] **Step 3: Implement**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau b/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau
index a704272..bb485f1 100644
--- a/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau
+++ b/src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau
@@ -37,6 +37,10 @@ export type SeamTrack = {
 	isPlaying: () -> boolean,
 	onEnded: (callback: () -> ()) -> () -> (),
 	onMarker: (markerName: string, callback: (param: string?) -> ()) -> () -> (),
+	setTimePosition: (seconds: number) -> (),
+	timePosition: () -> number,
+	-- The clip length in seconds; 0 until the engine has loaded the asset.
+	length: () -> number,
 }
 
 --[=[
@@ -58,6 +62,12 @@ export type PlayOpts = {
 	speed: number?,
 	weight: number?,
 	priority: Enum.AnimationPriority?,
+	-- Which asset: 0 = the entry's own assetId, k = variants[k]. Nil rolls (local-only plays); a
+	-- replicated action always passes the server's choice so every screen plays the same clip.
+	variant: number?,
+	-- Seconds into the clip (clip time, i.e. TimePosition) to start from: a viewer joining an action
+	-- mid-way. Wrapped for a looped entry; a one-shot already past its end is refused ("elapsed").
+	startAt: number?,
 }
 
 --[=[
@@ -71,6 +81,8 @@ export type PlayHandle = {
 	adjustSpeed: (self: PlayHandle, speed: number) -> (),
 	isPlaying: (self: PlayHandle) -> boolean,
 	onMarker: (self: PlayHandle, markerName: string, callback: (param: string?) -> ()) -> () -> (),
+	timePosition: (self: PlayHandle) -> number,
+	length: (self: PlayHandle) -> number,
 }
 
 --[=[
@@ -103,6 +115,8 @@ export type AnimationPlayer = {
 	stop: (self: AnimationPlayer, id: string, fadeTime: number?) -> boolean,
 	stopClass: (self: AnimationPlayer, class: InterruptionClass, fadeTime: number?) -> StopClassResult,
 	stopAll: (self: AnimationPlayer, fadeTime: number?) -> (),
+	setPaused: (self: AnimationPlayer, paused: boolean) -> (),
+	isPaused: (self: AnimationPlayer) -> boolean,
 	playing: (self: AnimationPlayer) -> { PlayingInfo },
 	counters: (self: AnimationPlayer) -> Counters,
 	destroy: (self: AnimationPlayer) -> (),
@@ -122,6 +136,22 @@ type LiveEntry = {
 
 local DEFAULT_FADE = 0.1
 
+-- Where a clip `startAt` seconds in really is: wrapped for a loop, nil for a one-shot already over. A track
+-- whose asset has not loaded yet reports length 0; it is seeked as asked (the engine clamps).
+local function resolveStart(track: SeamTrack, startAt: number, looped: boolean): number?
+	local length = track.length()
+	if startAt <= 0 or length <= 0 then
+		return math.max(startAt, 0)
+	end
+	if looped then
+		return startAt % length
+	end
+	if startAt >= length then
+		return nil
+	end
+	return startAt
+end
+
 local AnimationPlayerModule = {}
 
 --[=[
@@ -144,6 +174,8 @@ function AnimationPlayerModule.new(
 	local live: { [string]: LiveEntry } = {}
 	local counters: Counters = { loads = 0, hits = 0 }
 	local destroyed = false
+	-- Puppet LOD's freeze: every live track held at speed 0; each entry keeps its requested speed.
+	local paused = false
 	local disconnectRemoved: (() -> ())? = nil
 
 	local function dropLive(id: string)
@@ -196,7 +228,9 @@ function AnimationPlayerModule.new(
 					return
 				end
 				entry.speed = speed
-				entry.track.adjustSpeed(speed)
+				if not paused then
+					entry.track.adjustSpeed(speed)
+				end
 			end,
 			isPlaying = function(_self: PlayHandle): boolean
 				return isCurrent() and entry.track.isPlaying()
@@ -207,6 +241,12 @@ function AnimationPlayerModule.new(
 				end
 				return entry.track.onMarker(markerName, callback)
 			end,
+			timePosition = function(_self: PlayHandle): number
+				return if isCurrent() then entry.track.timePosition() else 0
+			end,
+			length = function(_self: PlayHandle): number
+				return entry.track.length()
+			end,
 		}
 	end
 
@@ -220,20 +260,37 @@ function AnimationPlayerModule.new(
 				return nil, "unknown-id"
 			end
 
-			-- Roll the asset: the entry's own id plus its variants, one pool.
+			-- The asset: the requested variant, or a roll over the entry's own id plus its variants.
 			local assetId = def.assetId
 			local variants = def.variants
-			if variants ~= nil and #variants > 0 then
+			local requested = if opts ~= nil then opts.variant else nil
+			if requested ~= nil then
+				local count = if variants ~= nil then #variants else 0
+				if requested ~= math.floor(requested) or requested < 0 or requested > count then
+					return nil, "bad-variant"
+				end
+				if requested > 0 and variants ~= nil then
+					assetId = variants[requested]
+				end
+			elseif variants ~= nil and #variants > 0 then
 				local index = pickIndex(#variants + 1)
 				if index > 1 then
 					assetId = variants[index - 1]
 				end
 			end
+			local startAt = if opts ~= nil then opts.startAt else nil
 
 			local existing = live[id]
 			if existing ~= nil and existing.assetId == assetId and def.looped and existing.track.isPlaying() then
 				-- Re-playing a looped track that is already playing is a no-op: re-Play would
-				-- restart the loop and thrash the fade (the pose-flap failure V3 watches for).
+				-- restart the loop and thrash the fade (the pose-flap failure V3 watches for). A
+				-- requested start point re-seeks it instead (an action resuming after a freeze).
+				if startAt ~= nil then
+					local seekTo = resolveStart(existing.track, startAt, true)
+					if seekTo ~= nil then
+						existing.track.setTimePosition(seekTo)
+					end
+				end
 				return makeHandle(id, existing), nil
 			end
 
@@ -253,6 +310,14 @@ function AnimationPlayerModule.new(
 				track = loaded
 			end
 
+			local start: number? = nil
+			if startAt ~= nil then
+				start = resolveStart(track, startAt, def.looped)
+				if start == nil then
+					return nil, "elapsed"
+				end
+			end
+
 			local priority = if opts ~= nil and opts.priority ~= nil then opts.priority else def.priority
 			track.setPriority(priority)
 			track.setLooped(def.looped)
@@ -284,7 +349,10 @@ function AnimationPlayerModule.new(
 			live[id] = entry
 
 			local fadeTime = if opts ~= nil and opts.fadeTime ~= nil then opts.fadeTime else DEFAULT_FADE
-			track.play(fadeTime, entry.weight, entry.speed)
+			track.play(fadeTime, entry.weight, if paused then 0 else entry.speed)
+			if start ~= nil and start > 0 then
+				track.setTimePosition(start)
+			end
 
 			return makeHandle(id, entry), nil
 		end,
@@ -352,6 +420,22 @@ function AnimationPlayerModule.new(
 			stopAllTracks(fadeTime)
 		end,
 
+		-- Holds every live track at speed 0 (the pose stays where it is), or resumes each at its own
+		-- requested speed. A play while paused starts held. Puppet LOD's freeze (speed mode).
+		setPaused = function(_self: AnimationPlayer, nextPaused: boolean)
+			if destroyed or paused == nextPaused then
+				return
+			end
+			paused = nextPaused
+			for _, entry in live do
+				entry.track.adjustSpeed(if paused then 0 else entry.speed)
+			end
+		end,
+
+		isPaused = function(_self: AnimationPlayer): boolean
+			return paused
+		end,
+
 		playing = function(_self: AnimationPlayer): { PlayingInfo }
 			local snapshot: { PlayingInfo } = {}
 			for id, entry in live do
```

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau b/src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau
index def24a2..d8f1a34 100644
--- a/src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau
+++ b/src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau
@@ -70,6 +70,15 @@ local function makeSeam(animator: Animator): AnimationPlayer.AnimatorSeam
 						connection:Disconnect()
 					end
 				end,
+				setTimePosition = function(seconds: number)
+					track.TimePosition = seconds
+				end,
+				timePosition = function(): number
+					return track.TimePosition
+				end,
+				length = function(): number
+					return track.Length
+				end,
 			}
 		end,
 		onRemoved = function(callback: () -> ()): () -> ()
```

- [ ] **Step 4: Static checks**

Run: `stylua src/ReplicatedStorage/Shared/Modules && stylua --check src && selene src`, the typecheck (existing sourcemap), `python scripts/python/check_file_length.py` (`AnimationPlayer` lands at 361 code lines).
Expected: clean.

- [ ] **Step 5: Run the tests (controller, Studio) — expect all to pass**

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/AnimationPlayer.luau src/ReplicatedStorage/Shared/Modules/AnimationPlayer.spec.luau src/ReplicatedStorage/Shared/Modules/AnimationPlayerRuntime.luau
git commit -m "feat(animation): chosen variant, start point and pause on AnimationPlayer"
```

---

### Task 3: Registry — layers, wire ids, declared durations, the stand-in actions

**Runtime behaviour: no** — new registry entries and fields; nothing grants them until Task 7.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/Constants/Animations/Actions.luau`
- Test: `AnimationTypes.spec.luau`, `AnimationRegistry.spec.luau`, `Locomotion.spec.luau` (modify), `Actions.spec.luau` (create), all in `src/ReplicatedStorage/Shared/Modules/Constants/Animations/`

**Interfaces:**
- Produces (AnimationTypes):
  - `export type AnimationLayer = "full" | "upper" | "overlay"`
  - `AnimationDef` gains `replicable: boolean?`, `wireId: number?`, `layer: AnimationLayer?`, `durationMs: number?`
  - `AnimationTypes.ANIMATION_LAYERS` (frozen, wire order 1..3), `MAX_WIRE_ID = 65535`, `MAX_VARIANTS = 255`
  - `AnimationTypes.isAnimationLayer(value: unknown): boolean`
  - `AnimationTypes.layerIndex(layer: string): number?` (wire index, nil for no layer)
  - `AnimationTypes.layerAt(index: number): AnimationLayer?`
  - `AnimationTypes.layerNamed(name: string): AnimationLayer?`
- Produces (AnimationRegistry): `ComposedIndex.byWireId: { [number]: string }`; `AnimationRegistry.idForWire(wireId: number): string?`; the `actions` domain.
- Produces (Actions): `testleap` (wire 1, full, attack, one variant, one-shot), `testguard` (wire 2, full, protected, one-shot), `testpose` (wire 3, upper, ambient, looped, open-ended).

- [ ] **Step 1: Measure the stand-in clip lengths (controller, Studio)**

`durationMs` is each clip's length at speed 1. In a Play session of this build (any place where the owner rig spawns), paste into the **client** command bar:

```lua
task.spawn(function()
	local clips = {
		{ "testleap v0", "rbxassetid://11525667271" },
		{ "testleap v1", "rbxassetid://128472778455853" },
		{ "testguard v0", "rbxassetid://11525764926" },
	}
	local humanoid = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	for _, clip in clips do
		local animation = Instance.new("Animation")
		animation.AnimationId = clip[2]
		local track = animator:LoadAnimation(animation)
		local waited = 0
		while track.Length == 0 and waited < 10 do
			waited += task.wait()
		end
		print(string.format("[ClipLength] %s %s = %d ms", clip[1], clip[2], math.floor(track.Length * 1000 + 0.5)))
		track:Destroy()
		animation:Destroy()
	end
end)
```

Hand the three `[ClipLength]` lines to the implementer. In Step 3 the implementer writes `testguard`'s value into `testguard.durationMs` and `testleap v0`'s into `testleap.durationMs`, replacing the provisional `600` and `1000`. If the two testleap clips differ by more than 50 ms, keep v0's value and note it in the task report: F4 will then show exactly one length mismatch (testleap variant 1), which Task 10 records in the spec. If the controller cannot measure yet, the provisional values stay; Task 10's checklist (zero length mismatches) catches them before merge.

- [ ] **Step 2: Write the failing specs**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.spec.luau b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.spec.luau
index df3455b..00f94c4 100644
--- a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.spec.luau
+++ b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.spec.luau
@@ -26,6 +26,53 @@ return function()
 		end)
 	end)
 
+	describe("ANIMATION_LAYERS", function()
+		it("lists full, upper and overlay in wire order", function()
+			local layers = AnimationTypes.ANIMATION_LAYERS
+			expect(#layers).to.equal(3)
+			expect(layers[1]).to.equal("full")
+			expect(layers[2]).to.equal("upper")
+			expect(layers[3]).to.equal("overlay")
+		end)
+
+		it("is frozen — the wire order is data, not a mutable table", function()
+			expect(table.isfrozen(AnimationTypes.ANIMATION_LAYERS)).to.equal(true)
+		end)
+	end)
+
+	describe("layer lookups", function()
+		it("isAnimationLayer accepts each layer and rejects anything else", function()
+			for _, layer in AnimationTypes.ANIMATION_LAYERS do
+				expect(AnimationTypes.isAnimationLayer(layer)).to.equal(true)
+			end
+			expect(AnimationTypes.isAnimationLayer("legs")).to.equal(false)
+			expect(AnimationTypes.isAnimationLayer(nil)).to.equal(false)
+			expect(AnimationTypes.isAnimationLayer(1)).to.equal(false)
+		end)
+
+		it("layerIndex and layerAt round-trip, and refuse what is no layer", function()
+			for index, layer in AnimationTypes.ANIMATION_LAYERS do
+				expect(AnimationTypes.layerIndex(layer)).to.equal(index)
+				expect(AnimationTypes.layerAt(index)).to.equal(layer)
+			end
+			expect(AnimationTypes.layerIndex("legs")).to.equal(nil)
+			expect(AnimationTypes.layerAt(0)).to.equal(nil)
+			expect(AnimationTypes.layerAt(4)).to.equal(nil)
+		end)
+
+		it("layerNamed narrows a layer name and refuses anything else", function()
+			expect(AnimationTypes.layerNamed("upper")).to.equal("upper")
+			expect(AnimationTypes.layerNamed("testleap")).to.equal(nil)
+		end)
+	end)
+
+	describe("wire limits", function()
+		it("fits wire ids in a uint16 and variant indexes in a uint8", function()
+			expect(AnimationTypes.MAX_WIRE_ID).to.equal(65535)
+			expect(AnimationTypes.MAX_VARIANTS).to.equal(255)
+		end)
+	end)
+
 	describe("isInterruptionClass", function()
 		it("accepts each declared class", function()
 			expect(AnimationTypes.isInterruptionClass("attack")).to.equal(true)
```

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.spec.luau b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.spec.luau
index 03b7b39..b615e7b 100644
--- a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.spec.luau
+++ b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.spec.luau
@@ -80,6 +80,109 @@ return function()
 		end)
 	end)
 
+	describe("replicated actions (R3)", function()
+		-- A replicable one-shot; `omit` lists fields to leave out.
+		local function replicable(overrides, omit)
+			local def = {
+				assetId = "rbxassetid://123",
+				priority = Enum.AnimationPriority.Action,
+				looped = false,
+				interruption = "attack",
+				replicable = true,
+				wireId = 7,
+				layer = "full",
+				durationMs = 500,
+			}
+			for key, value in overrides or {} do
+				def[key] = value
+			end
+			for _, key in omit or {} do
+				def[key] = nil
+			end
+			return def
+		end
+
+		it("gives every replicable entry in the real registry a unique wire id that resolves back", function()
+			local seen = {}
+			local count = 0
+			for _, id in AnimationRegistry.ids() do
+				local def = AnimationRegistry.get(id)
+				if def.replicable then
+					count += 1
+					expect(seen[def.wireId]).to.equal(nil)
+					seen[def.wireId] = id
+					expect(AnimationRegistry.idForWire(def.wireId)).to.equal(id)
+				end
+			end
+			expect(count > 0).to.equal(true)
+		end)
+
+		it("resolves no entry for an unused wire id", function()
+			expect(AnimationRegistry.idForWire(60000)).to.equal(nil)
+		end)
+
+		it("indexes replicable entries by wire id", function()
+			local composed = AnimationRegistry.composeDomains({ alpha = { leap = replicable() } })
+			expect(composed.byWireId[7]).to.equal("leap")
+		end)
+
+		it("rejects two entries sharing a wire id, even across domains", function()
+			expect(function()
+				AnimationRegistry.composeDomains({
+					alpha = { leap = replicable() },
+					beta = { guard = replicable() },
+				})
+			end).to.throw()
+		end)
+
+		it("rejects a replicable entry without a whole wire id from 1 to 65535", function()
+			for _, bad in { 0, 1.5, 70000 } do
+				expect(function()
+					AnimationRegistry.composeDomains({ alpha = { leap = replicable({ wireId = bad }) } })
+				end).to.throw()
+			end
+			expect(function()
+				AnimationRegistry.composeDomains({ alpha = { leap = replicable(nil, { "wireId" }) } })
+			end).to.throw()
+		end)
+
+		it("rejects a replicable entry with an unknown layer", function()
+			expect(function()
+				AnimationRegistry.composeDomains({ alpha = { leap = replicable({ layer = "legs" }) } })
+			end).to.throw()
+		end)
+
+		it("rejects a replicable one-shot without durationMs", function()
+			expect(function()
+				AnimationRegistry.composeDomains({ alpha = { leap = replicable(nil, { "durationMs" }) } })
+			end).to.throw()
+		end)
+
+		it("rejects a looped replicable entry that declares durationMs, and accepts one without", function()
+			expect(function()
+				AnimationRegistry.composeDomains({ alpha = { pose = replicable({ looped = true }) } })
+			end).to.throw()
+			expect(function()
+				AnimationRegistry.composeDomains({ alpha = { pose = replicable({ looped = true }, { "durationMs" }) } })
+			end).never.to.throw()
+		end)
+
+		it("rejects wireId, layer or durationMs on an entry that is not replicable", function()
+			for _, field in { "wireId", "layer", "durationMs" } do
+				local plain = {
+					assetId = "rbxassetid://123",
+					priority = Enum.AnimationPriority.Core,
+					looped = false,
+					interruption = "ambient",
+				}
+				plain[field] = replicable()[field]
+				expect(function()
+					AnimationRegistry.composeDomains({ alpha = { walkish = plain } })
+				end).to.throw()
+			end
+		end)
+	end)
+
 	describe("composeDomains (the pure core, on fabricated domains)", function()
 		it("indexes entries from multiple domains", function()
 			local composed = AnimationRegistry.composeDomains({
```

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/Locomotion.spec.luau b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/Locomotion.spec.luau
index dd6a30a..e19d056 100644
--- a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/Locomotion.spec.luau
+++ b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/Locomotion.spec.luau
@@ -61,6 +61,13 @@ return function()
 			expect(Locomotion.jump.looped).to.equal(false)
 		end)
 
+		it("declares no locomotion entry replicable — locomotion stays local (R3)", function()
+			for _, def in Locomotion do
+				expect(def.replicable).to.equal(nil)
+				expect(def.wireId).to.equal(nil)
+			end
+		end)
+
 		it("declares NO death entry — the old game deprecated its death animation (V5 decision)", function()
 			expect(Locomotion.death).to.equal(nil)
 		end)
```

Create `src/ReplicatedStorage/Shared/Modules/Constants/Animations/Actions.spec.luau`:

```luau
--[=[
	Unit tests for the Actions domain — the replicated-action stand-ins R3 proves the pipeline with
	(`animplay` until combat, abilities and emotes bring real actions).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animations = ReplicatedStorage.Shared.Modules.Constants.Animations
local Actions = require(Animations.Actions)
local AnimationTypes = require(Animations.AnimationTypes)

return function()
	describe("stand-ins", function()
		it("declares testleap, testguard and testpose", function()
			expect(Actions.testleap).to.be.ok()
			expect(Actions.testguard).to.be.ok()
			expect(Actions.testpose).to.be.ok()
		end)

		it("makes every entry a replicable action above locomotion's Core priority", function()
			for _, def in Actions do
				expect(def.replicable).to.equal(true)
				expect(def.wireId).to.be.a("number")
				expect(AnimationTypes.isAnimationLayer(def.layer)).to.equal(true)
				-- Core is the base locomotion plays at: an action there blends at half weight with it.
				expect(def.priority).never.to.equal(Enum.AnimationPriority.Core)
			end
		end)

		it("declares durationMs for exactly the one-shots", function()
			for _, def in Actions do
				if def.looped then
					expect(def.durationMs).to.equal(nil)
				else
					expect(def.durationMs > 0).to.equal(true)
				end
			end
		end)

		it("covers what the two-client checklist needs: a variant, two layers, attack vs protected", function()
			expect(#Actions.testleap.variants >= 1).to.equal(true)
			expect(Actions.testleap.layer).to.equal("full")
			expect(Actions.testleap.interruption).to.equal("attack")
			expect(Actions.testguard.layer).to.equal("full")
			expect(Actions.testguard.interruption).to.equal("protected")
			expect(Actions.testpose.layer).to.equal("upper")
			expect(Actions.testpose.looped).to.equal(true)
		end)
	end)

	describe("frozen data", function()
		it("is frozen at every level", function()
			expect(table.isfrozen(Actions)).to.equal(true)
			expect(table.isfrozen(Actions.testleap)).to.equal(true)
			expect(table.isfrozen(Actions.testleap.variants)).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 3: Run the tests (controller, Studio) — expect failures**

Expected: `Actions.spec` errors (no `Actions` module); the new `ANIMATION_LAYERS`, `layer lookups`, `wire limits` and `replicated actions (R3)` tests FAIL, except the "accepts one without" half of the looped test, which passes already. The new Locomotion test passes already.

- [ ] **Step 4: Implement**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.luau b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.luau
index a5495d1..2d51e2d 100644
--- a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.luau
+++ b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationTypes.luau
@@ -22,6 +22,18 @@
 ]=]
 export type InterruptionClass = "attack" | "protected" | "ambient"
 
+--[=[
+	The grant slot a replicated action occupies on a body (character replication R3): one grant per layer
+	per body, and a new grant on a layer replaces the old one under the interruption rules. Engine
+	blending is still decided by each entry's `priority`; the layer only decides what replaces what.
+
+	- `full` — whole-body actions: attacks, dodges, hit reactions, emotes.
+	- `upper` — upper-body actions layered over locomotion: casting while moving, carrying, aiming.
+	- `overlay` — small additive or cosmetic clips that never block the others (a flinch, a hand pose).
+	@type AnimationLayer "full" | "upper" | "overlay"
+]=]
+export type AnimationLayer = "full" | "upper" | "overlay"
+
 --[=[
 	One registered animation.
 	@interface AnimationDef
@@ -30,6 +42,10 @@ export type InterruptionClass = "attack" | "protected" | "ambient"
 	.looped boolean
 	.interruption InterruptionClass
 	.variants { string }? -- optional extra asset ids; a play rolls ONE of assetId + variants
+	.replicable boolean? -- true = the server may grant it as a replicated action (R3); locomotion stays local
+	.wireId number? -- replicable only: a stable 1-65535 id on the wire, never reused or renumbered
+	.layer AnimationLayer? -- replicable only: the grant slot it occupies
+	.durationMs number? -- replicable one-shots only: the clip's length at speed 1 (looped entries omit it)
 ]=]
 export type AnimationDef = {
 	assetId: string,
@@ -37,6 +53,10 @@ export type AnimationDef = {
 	looped: boolean,
 	interruption: InterruptionClass,
 	variants: { string }?,
+	replicable: boolean?,
+	wireId: number?,
+	layer: AnimationLayer?,
+	durationMs: number?,
 }
 
 --[=[
@@ -56,8 +76,24 @@ for _, class in INTERRUPTION_CLASSES do
 	CLASS_SET[class] = true
 end
 
+-- Order is the wire encoding (index 1..3): append only, never reorder.
+local layerList: { AnimationLayer } = { "full", "upper", "overlay" }
+local ANIMATION_LAYERS = table.freeze(layerList)
+
+local LAYER_INDEX: { [string]: number } = {}
+for index, layer in ANIMATION_LAYERS do
+	LAYER_INDEX[layer] = index
+end
+-- Spelled out: a loop over the list widens each layer to `string`, which no longer narrows to the type.
+local LAYER_BY_NAME: { [string]: AnimationLayer } = { full = "full", upper = "upper", overlay = "overlay" }
+
 local AnimationTypes = {
 	INTERRUPTION_CLASSES = INTERRUPTION_CLASSES,
+	ANIMATION_LAYERS = ANIMATION_LAYERS,
+	-- The largest wire id a uint16 carries.
+	MAX_WIRE_ID = 65535,
+	-- The largest variant count a uint8 variant index carries (0 = the entry's own asset).
+	MAX_VARIANTS = 255,
 }
 
 --[=[
@@ -81,4 +117,40 @@ function AnimationTypes.isCanonicalAssetId(value: unknown): boolean
 	return type(value) == "string" and string.match(value, "^rbxassetid://%d+$") ~= nil
 end
 
+--[=[
+	True iff `value` names a declared animation layer.
+	@param value unknown
+	@return boolean
+]=]
+function AnimationTypes.isAnimationLayer(value: unknown): boolean
+	return type(value) == "string" and LAYER_BY_NAME[value] ~= nil
+end
+
+--[=[
+	The layer named `name`, or nil (narrows a string from a command or a channel key to the type).
+	@param name string
+	@return AnimationLayer?
+]=]
+function AnimationTypes.layerNamed(name: string): AnimationLayer?
+	return LAYER_BY_NAME[name]
+end
+
+--[=[
+	A layer's wire index (1-based, the order of `ANIMATION_LAYERS`), or nil for a name that is no layer.
+	@param layer string
+	@return number?
+]=]
+function AnimationTypes.layerIndex(layer: string): number?
+	return LAYER_INDEX[layer]
+end
+
+--[=[
+	The layer at a wire index, or nil for an index no layer has (a malformed packet).
+	@param index number
+	@return AnimationLayer?
+]=]
+function AnimationTypes.layerAt(index: number): AnimationLayer?
+	return ANIMATION_LAYERS[index]
+end
+
 return AnimationTypes
```

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.luau b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.luau
index dd364d2..97e789c 100644
--- a/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.luau
+++ b/src/ReplicatedStorage/Shared/Modules/Constants/Animations/AnimationRegistry.luau
@@ -18,6 +18,7 @@
 
 local AnimationTypes = require(script.Parent.AnimationTypes)
 local Locomotion = require(script.Parent.Locomotion)
+local Actions = require(script.Parent.Actions)
 
 type AnimationDef = AnimationTypes.AnimationDef
 type AnimationDomain = AnimationTypes.AnimationDomain
@@ -27,17 +28,57 @@ type AnimationDomain = AnimationTypes.AnimationDomain
 	@interface ComposedIndex
 	.byId { [string]: AnimationDef } -- entry key -> definition, across all domains
 	.domainOf { [string]: string } -- entry key -> the domain that declared it
+	.byWireId { [number]: string } -- replicable entries: wire id -> entry key
 ]=]
 export type ComposedIndex = {
 	byId: { [string]: AnimationDef },
 	domainOf: { [string]: string },
+	byWireId: { [number]: string },
 }
 
 -- Every registered domain. Future phases append here — nowhere else.
 local DOMAIN_MODULES: { [string]: AnimationDomain } = table.freeze({
 	locomotion = Locomotion,
+	actions = Actions,
 })
 
+-- The replicated-action fields (R3): a replicable entry carries a unique wire id and a layer, and a
+-- one-shot declares its length; a local entry carries none of them. Throws on a violation.
+local function checkReplication(key: string, def: AnimationDef, wireOwner: { [number]: string })
+	if def.replicable ~= true then
+		assert(
+			def.wireId == nil and def.layer == nil and def.durationMs == nil,
+			`[AnimationRegistry] "{key}" sets wireId/layer/durationMs but is not replicable`
+		)
+		return
+	end
+	local wireId = def.wireId
+	if wireId == nil or wireId ~= math.floor(wireId) or wireId < 1 or wireId > AnimationTypes.MAX_WIRE_ID then
+		error(`[AnimationRegistry] replicable "{key}" needs an integer wireId 1-{AnimationTypes.MAX_WIRE_ID}`)
+	end
+	local owner = wireOwner[wireId]
+	assert(
+		owner == nil,
+		`[AnimationRegistry] wireId {wireId} is used by both "{owner}" and "{key}" — wire ids are unique and never reused`
+	)
+	wireOwner[wireId] = key
+	assert(
+		AnimationTypes.isAnimationLayer(def.layer),
+		`[AnimationRegistry] replicable "{key}" declares unknown layer "{tostring(def.layer)}"`
+	)
+	local durationMs = def.durationMs
+	if def.looped then
+		assert(durationMs == nil, `[AnimationRegistry] looped "{key}" runs until stopped: omit durationMs`)
+	elseif durationMs == nil or durationMs <= 0 then
+		error(`[AnimationRegistry] replicable one-shot "{key}" must declare durationMs > 0`)
+	end
+	local variants = def.variants
+	assert(
+		variants == nil or #variants <= AnimationTypes.MAX_VARIANTS,
+		`[AnimationRegistry] replicable "{key}" has more than {AnimationTypes.MAX_VARIANTS} variants`
+	)
+end
+
 local AnimationRegistry = {}
 
 --[=[
@@ -45,14 +86,15 @@ local AnimationRegistry = {}
 	validation rules are unit-testable against fabricated domains; the module-level index below is
 	this function applied to the real domains.
 
-	Throws on: a key declared by two domains, a non-canonical asset or variant id, or an unknown
-	interruption class.
+	Throws on: a key declared by two domains, a non-canonical asset or variant id, an unknown
+	interruption class, or a malformed replicated-action field (see `checkReplication`).
 	@param domains { [string]: AnimationDomain }
 	@return ComposedIndex
 ]=]
 function AnimationRegistry.composeDomains(domains: { [string]: AnimationDomain }): ComposedIndex
 	local byId: { [string]: AnimationDef } = {}
 	local domainOf: { [string]: string } = {}
+	local byWireId: { [number]: string } = {}
 	for domainName, domain in domains do
 		for key, def in domain do
 			assert(
@@ -83,11 +125,12 @@ function AnimationRegistry.composeDomains(domains: { [string]: AnimationDomain }
 					`[AnimationRegistry] "{key}" variants must be a dense array (no holes / non-sequential keys)`
 				)
 			end
+			checkReplication(key, def, byWireId)
 			byId[key] = def
 			domainOf[key] = domainName
 		end
 	end
-	return { byId = table.freeze(byId), domainOf = table.freeze(domainOf) }
+	return { byId = table.freeze(byId), domainOf = table.freeze(domainOf), byWireId = table.freeze(byWireId) }
 end
 
 local INDEX = AnimationRegistry.composeDomains(DOMAIN_MODULES)
@@ -126,6 +169,15 @@ function AnimationRegistry.domain(name: string): AnimationDomain?
 	return DOMAIN_MODULES[name]
 end
 
+--[=[
+	Resolves a replicated action's wire id to its entry key.
+	@param wireId number
+	@return string? -- nil when no replicable entry has that id
+]=]
+function AnimationRegistry.idForWire(wireId: number): string?
+	return INDEX.byWireId[wireId]
+end
+
 --[=[
 	Every entry key across all domains, sorted — the Cmdr enum / UI list source.
 	@return { string }
```

Create `src/ReplicatedStorage/Shared/Modules/Constants/Animations/Actions.luau` (write the Step 1 measurements into `durationMs`):

```luau
--!strict
--[=[
	Actions: the replicated-action domain (character replication R3). Entries here are granted by the
	server (`AnimationServiceServer:play`) and played on the owner's rig and on every viewer's puppet, in
	sync, with the server's variant and speed.

	R3 has no real actions yet, so this domain holds STAND-INS that prove the pipeline through Cmdr
	`animplay` until combat, abilities and emotes bring their own domains. They reuse locomotion seed
	assets at Action priority: the locomotion entries themselves stay ambient, Core and local (an action
	at Core blends at half weight with locomotion, which the spike's observer-animation run showed).

	- `testleap` — a full-body one-shot with a variant (variant sync, speed, start alignment, stop-attacks).
	- `testguard` — a protected full-body one-shot (an attack on the same layer cannot replace it).
	- `testpose` — an open-ended looped upper-layer pose (two layers at once, explicit stop, safety cap).

	`durationMs` is each clip's length at speed 1, measured in Studio (R3 plan, Task 3 Step 1). The F4
	length check warns when a real clip disagrees with it. Wire ids are permanent: never reuse or
	renumber one, even after deleting its entry.

	@class Actions
]=]

local AnimationTypes = require(script.Parent.AnimationTypes)

type AnimationDomain = AnimationTypes.AnimationDomain
type AnimationDef = AnimationTypes.AnimationDef

local function freezeDef(def: AnimationDef): AnimationDef
	if def.variants ~= nil then
		table.freeze(def.variants)
	end
	return table.freeze(def)
end

local Actions: AnimationDomain = table.freeze({
	testleap = freezeDef({
		assetId = "rbxassetid://11525667271",
		variants = { "rbxassetid://128472778455853" },
		priority = Enum.AnimationPriority.Action2,
		looped = false,
		interruption = "attack",
		replicable = true,
		wireId = 1,
		layer = "full",
		durationMs = 1000,
	}),
	testguard = freezeDef({
		assetId = "rbxassetid://11525764926",
		priority = Enum.AnimationPriority.Action2,
		looped = false,
		interruption = "protected",
		replicable = true,
		wireId = 2,
		layer = "full",
		durationMs = 600,
	}),
	testpose = freezeDef({
		assetId = "rbxassetid://11868152140",
		priority = Enum.AnimationPriority.Action,
		looped = true,
		interruption = "ambient",
		replicable = true,
		wireId = 3,
		layer = "upper",
	}),
})

return Actions
```

- [ ] **Step 5: Static checks**

Run: `stylua src/ReplicatedStorage/Shared/Modules/Constants && stylua --check src && selene src`, the typecheck (a file was added: scratch copy or a regenerated sourcemap, see Commands), `python scripts/python/check_file_length.py`, `python scripts/python/check_pr_rules.py feature/replication-bodies` (asset ids are allowed only under `Constants/`, which is where they are).
Expected: clean.

- [ ] **Step 6: Run the tests (controller, Studio) — expect all to pass**

- [ ] **Step 7: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/Constants/Animations
git commit -m "feat(animation): replicable registry entries with layers, wire ids and durations"
```

---

### Task 4: `BodyStateTiming` and the `BodyStates` core

**Runtime behaviour: no** — pure modules with no caller yet.

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Services/CharacterReplicationService/BodyStates.luau` (+ `.spec.luau`)

**Interfaces:**
- Produces (BodyStateTiming, shared): `MAX_OPEN_STATE_MS = 30000`; `endMs(startMs: number, durationMs: number?): number`; `isOver(startMs: number, durationMs: number?, nowMs: number): boolean`.
- Produces (BodyStates, server, generic over the kind's data `D`):
  - `export type Entry<D> = { key: string, data: D, startMs: number, durationMs: number? }`
  - `export type SetResult = "created" | "replaced" | "full"`
  - `export type Counters = { created: number, replaced: number, cleared: number, expired: number, capped: number, refused: number }`
  - `export type Store<D> = { maxStates: number, onCapped: ((userId: number, entry: Entry<D>) -> ())?, bodies: { [number]: { [string]: Entry<D> } }, counters: Counters }`
  - `BodyStates.DEFAULT_MAX_STATES = 8`
  - `new<D>(maxStates: number?, onCapped: ((userId, Entry<D>) -> ())?): Store<D>`
  - `set<D>(store, userId, key, data: D, startMs, durationMs: number?, nowMs): SetResult`
  - `get<D>(store, userId, key, nowMs): Entry<D>?`
  - `clear<D>(store, userId, key, nowMs): Entry<D>?` (the cleared live entry; nil if nothing live)
  - `clearBody<D>(store, userId): number`
  - `active<D>(store, userId, nowMs): { Entry<D> }` (oldest first, ties by key)
  - `size<D>(store): number`

- [ ] **Step 1: Write the failing specs**

Create `src/ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BodyStateTiming = require(ReplicatedStorage.Shared.Modules.CharacterReplication.BodyStateTiming)

return function()
	local MAX = BodyStateTiming.MAX_OPEN_STATE_MS

	it("keeps the safety cap at 30 s", function()
		expect(MAX).to.equal(30000)
	end)

	it("ends a timed state at start + duration", function()
		expect(BodyStateTiming.endMs(1000, 250)).to.equal(1250)
		expect(BodyStateTiming.isOver(1000, 250, 1249)).to.equal(false)
		expect(BodyStateTiming.isOver(1000, 250, 1250)).to.equal(true)
	end)

	it("ends an open-ended state at the safety cap", function()
		expect(BodyStateTiming.endMs(1000, nil)).to.equal(1000 + MAX)
		expect(BodyStateTiming.isOver(1000, nil, 1000 + MAX - 1)).to.equal(false)
		expect(BodyStateTiming.isOver(1000, nil, 1000 + MAX)).to.equal(true)
	end)
end
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyStates.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BodyStateTiming = require(ReplicatedStorage.Shared.Modules.CharacterReplication.BodyStateTiming)
local BodyStates = require(ServerScriptService.Services.CharacterReplicationService.BodyStates)

local MAX_OPEN = BodyStateTiming.MAX_OPEN_STATE_MS

return function()
	describe("set", function()
		it("creates a state and reads it back", function()
			local store = BodyStates.new()
			expect(BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)).to.equal("created")
			local entry = BodyStates.get(store, 1, "full", 1100)
			expect(entry.data).to.equal("leap")
			expect(entry.startMs).to.equal(1000)
			expect(entry.durationMs).to.equal(500)
			expect(store.counters.created).to.equal(1)
		end)

		it("replaces the state on the same key", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			expect(BodyStates.set(store, 1, "full", "guard", 1100, 300, 1100)).to.equal("replaced")
			expect(BodyStates.get(store, 1, "full", 1100).data).to.equal("guard")
			expect(store.counters.replaced).to.equal(1)
		end)

		it("holds one state per key and several keys per body", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			BodyStates.set(store, 1, "upper", "pose", 1000, nil, 1000)
			expect(BodyStates.get(store, 1, "full", 1100).data).to.equal("leap")
			expect(BodyStates.get(store, 1, "upper", 1100).data).to.equal("pose")
			expect(#BodyStates.active(store, 1, 1100)).to.equal(2)
		end)

		it("keeps bodies apart", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			BodyStates.set(store, 2, "full", "guard", 1000, 500, 1000)
			BodyStates.clear(store, 1, "full", 1100)
			expect(BodyStates.get(store, 1, "full", 1100)).to.equal(nil)
			expect(BodyStates.get(store, 2, "full", 1100).data).to.equal("guard")
		end)
	end)

	describe("clear", function()
		it("returns the cleared live state, so the shell can send a stop", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			local entry = BodyStates.clear(store, 1, "full", 1100)
			expect(entry.startMs).to.equal(1000)
			expect(BodyStates.get(store, 1, "full", 1100)).to.equal(nil)
			expect(store.counters.cleared).to.equal(1)
		end)

		it("returns nil for a key that holds nothing", function()
			local store = BodyStates.new()
			expect(BodyStates.clear(store, 1, "full", 1000)).to.equal(nil)
		end)

		it("returns nil for a state that already ran out (no stop is owed)", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			expect(BodyStates.clear(store, 1, "full", 1600)).to.equal(nil)
			expect(store.counters.expired).to.equal(1)
		end)
	end)

	describe("lazy expiry", function()
		it("drops a timed state once its duration has run out", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			expect(BodyStates.get(store, 1, "full", 1499)).to.be.ok()
			expect(BodyStates.get(store, 1, "full", 1500)).to.equal(nil)
			expect(store.counters.expired).to.equal(1)
			expect(store.counters.capped).to.equal(0)
		end)

		it("drops an open-ended state at the safety cap and reports it", function()
			local capped = {}
			local store = BodyStates.new(nil, function(userId, entry)
				table.insert(capped, { userId = userId, key = entry.key })
			end)
			BodyStates.set(store, 3, "upper", "pose", 1000, nil, 1000)
			expect(BodyStates.get(store, 3, "upper", 1000 + MAX_OPEN - 1)).to.be.ok()
			expect(BodyStates.get(store, 3, "upper", 1000 + MAX_OPEN)).to.equal(nil)
			expect(#capped).to.equal(1)
			expect(capped[1].userId).to.equal(3)
			expect(capped[1].key).to.equal("upper")
			expect(store.counters.capped).to.equal(1)
		end)
	end)

	describe("per-body cap (MAX_BODY_STATES)", function()
		it("defaults to 8 live states per body", function()
			expect(BodyStates.new().maxStates).to.equal(8)
		end)

		it("refuses a new key once the body holds maxStates live states", function()
			local store = BodyStates.new(2)
			BodyStates.set(store, 1, "a", 1, 1000, nil, 1000)
			BodyStates.set(store, 1, "b", 2, 1000, nil, 1000)
			expect(BodyStates.set(store, 1, "c", 3, 1000, nil, 1000)).to.equal("full")
			expect(BodyStates.get(store, 1, "c", 1000)).to.equal(nil)
			expect(store.counters.refused).to.equal(1)
		end)

		it("still replaces an existing key when the body is full", function()
			local store = BodyStates.new(2)
			BodyStates.set(store, 1, "a", 1, 1000, nil, 1000)
			BodyStates.set(store, 1, "b", 2, 1000, nil, 1000)
			expect(BodyStates.set(store, 1, "a", 9, 1100, nil, 1100)).to.equal("replaced")
		end)

		it("counts only live states toward the cap", function()
			local store = BodyStates.new(2)
			BodyStates.set(store, 1, "a", 1, 1000, 100, 1000)
			BodyStates.set(store, 1, "b", 2, 1000, nil, 1000)
			expect(BodyStates.set(store, 1, "c", 3, 1200, nil, 1200)).to.equal("created")
		end)
	end)

	describe("active (the replay list)", function()
		it("lists every live state oldest first, ties by key, with its original start time", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 2000, 5000, 2000)
			BodyStates.set(store, 1, "upper", "pose", 1000, nil, 2000)
			BodyStates.set(store, 1, "overlay", "wave", 1000, 5000, 2000)
			local list = BodyStates.active(store, 1, 2100)
			expect(#list).to.equal(3)
			expect(list[1].key).to.equal("overlay")
			expect(list[2].key).to.equal("upper")
			expect(list[3].key).to.equal("full")
			expect(list[3].startMs).to.equal(2000)
		end)

		it("leaves out states that have ended", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			BodyStates.set(store, 1, "upper", "pose", 1000, nil, 1000)
			local list = BodyStates.active(store, 1, 2000)
			expect(#list).to.equal(1)
			expect(list[1].key).to.equal("upper")
		end)

		it("is empty for a body with no states", function()
			expect(#BodyStates.active(BodyStates.new(), 9, 1000)).to.equal(0)
		end)
	end)

	describe("clearBody (death, respawn, slot switch, leave)", function()
		it("drops every state on the body and nothing else", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			BodyStates.set(store, 1, "upper", "pose", 1000, nil, 1000)
			BodyStates.set(store, 2, "full", "guard", 1000, 500, 1000)
			expect(BodyStates.clearBody(store, 1)).to.equal(2)
			expect(#BodyStates.active(store, 1, 1100)).to.equal(0)
			expect(BodyStates.get(store, 2, "full", 1100).data).to.equal("guard")
			expect(store.counters.cleared).to.equal(2)
		end)
	end)

	describe("size", function()
		it("counts the states held across bodies", function()
			local store = BodyStates.new()
			BodyStates.set(store, 1, "full", "leap", 1000, 500, 1000)
			BodyStates.set(store, 2, "upper", "pose", 1000, nil, 1000)
			expect(BodyStates.size(store)).to.equal(2)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected: both specs error on the missing modules.

- [ ] **Step 3: Implement**

Create `src/ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming.luau`:

```luau
--!strict
--[=[
	BodyStateTiming: when a timed body state ends (character replication R3). Shared so the server's store
	and every client agree without a message: a state with a duration ends at `startMs + durationMs`; an
	open-ended one (no duration, e.g. a looping pose) ends at the safety cap, `startMs + MAX_OPEN_STATE_MS`,
	so a grant nobody stops cannot run forever on any screen.

	Times are session ms (the replication session clock both ends share). Pure.

	@class BodyStateTiming
]=]

local BodyStateTiming = {}

-- The safety cap for an open-ended state (a forgotten looping action ends here on every screen).
BodyStateTiming.MAX_OPEN_STATE_MS = 30000

--[=[
	When a state ends: start + duration, or start + the safety cap when it has no duration.
]=]
function BodyStateTiming.endMs(startMs: number, durationMs: number?): number
	return startMs + (if durationMs ~= nil then durationMs else BodyStateTiming.MAX_OPEN_STATE_MS)
end

--[=[
	True once `nowMs` has reached the state's end.
]=]
function BodyStateTiming.isOver(startMs: number, durationMs: number?, nowMs: number): boolean
	return nowMs >= BodyStateTiming.endMs(startMs, durationMs)
end

return BodyStateTiming
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyStates.luau`:

```luau
--!strict
--[=[
	BodyStates: the server's table of timed body states for ONE kind (character replication R3 spec,
	"Timed body state"). A kind (actions today; later e.g. lasting VFX statuses) owns one store; within it
	each body holds at most one state per key (for actions, the key is the animation layer).

	Rules:
	- `set` on a key the body already holds REPLACES that state; a new key is refused once the body holds
	  `maxStates` live states (the per-body safety cap, `MAX_BODY_STATES`).
	- Ended states are cleared LAZILY, whenever the body is touched (no per-state timers). A state with a
	  duration ends at `startMs + durationMs` and is counted `expired`; an open-ended one ends at the shared
	  safety cap (`BodyStateTiming.MAX_OPEN_STATE_MS`), is counted `capped`, and reported to `onCapped` so
	  the shell can warn about a grant somebody forgot to stop.
	- `active` is the replay list for a viewer the body just entered: every live state, oldest first.
	- `clearBody` drops everything (death, respawn, slot switch, leave): receivers clear on their own, so
	  no message is owed.

	Pure: time is passed in (session ms); the data is opaque to the store.

	@class BodyStates
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyStateTiming = require(ReplicatedStorage.Shared.Modules.CharacterReplication.BodyStateTiming)

local BodyStates = {}

-- MAX_BODY_STATES: live states one body may hold per kind (3 action layers today, room for growth).
BodyStates.DEFAULT_MAX_STATES = 8

export type Entry<D> = {
	key: string,
	data: D,
	startMs: number,
	durationMs: number?,
}

export type SetResult = "created" | "replaced" | "full"

export type Counters = {
	created: number,
	replaced: number,
	cleared: number,
	expired: number,
	capped: number,
	refused: number,
}

export type Store<D> = {
	maxStates: number,
	onCapped: ((userId: number, entry: Entry<D>) -> ())?,
	bodies: { [number]: { [string]: Entry<D> } },
	counters: Counters,
}

function BodyStates.new<D>(maxStates: number?, onCapped: ((userId: number, entry: Entry<D>) -> ())?): Store<D>
	return {
		maxStates = maxStates or BodyStates.DEFAULT_MAX_STATES,
		onCapped = onCapped,
		bodies = {},
		counters = { created = 0, replaced = 0, cleared = 0, expired = 0, capped = 0, refused = 0 },
	}
end

-- Drops this body's ended states and returns how many live states it still holds.
local function prune<D>(store: Store<D>, userId: number, nowMs: number): number
	local states = store.bodies[userId]
	if states == nil then
		return 0
	end
	local live = 0
	for key, entry in states do
		if BodyStateTiming.isOver(entry.startMs, entry.durationMs, nowMs) then
			states[key] = nil
			if entry.durationMs ~= nil then
				store.counters.expired += 1
			else
				store.counters.capped += 1
				local onCapped = store.onCapped
				if onCapped ~= nil then
					onCapped(userId, entry)
				end
			end
		else
			live += 1
		end
	end
	if live == 0 then
		store.bodies[userId] = nil
	end
	return live
end

--[=[
	Set the state on `key`: replaces a live state on the same key, refuses a new key past `maxStates`.
]=]
function BodyStates.set<D>(
	store: Store<D>,
	userId: number,
	key: string,
	data: D,
	startMs: number,
	durationMs: number?,
	nowMs: number
): SetResult
	local live = prune(store, userId, nowMs)
	local states = store.bodies[userId]
	local replacing = states ~= nil and states[key] ~= nil
	if not replacing and live >= store.maxStates then
		store.counters.refused += 1
		return "full"
	end
	if states == nil then
		states = {}
		store.bodies[userId] = states
	end
	states[key] = { key = key, data = data, startMs = startMs, durationMs = durationMs }
	if replacing then
		store.counters.replaced += 1
		return "replaced"
	end
	store.counters.created += 1
	return "created"
end

--[=[
	The live state on `key`, or nil.
]=]
function BodyStates.get<D>(store: Store<D>, userId: number, key: string, nowMs: number): Entry<D>?
	prune(store, userId, nowMs)
	local states = store.bodies[userId]
	return if states ~= nil then states[key] else nil
end

--[=[
	End the live state on `key` early. Returns it (the shell owes its receivers a stop), or nil when the
	key held nothing live.
]=]
function BodyStates.clear<D>(store: Store<D>, userId: number, key: string, nowMs: number): Entry<D>?
	prune(store, userId, nowMs)
	local states = store.bodies[userId]
	if states == nil then
		return nil
	end
	local entry = states[key]
	if entry == nil then
		return nil
	end
	states[key] = nil
	if next(states) == nil then
		store.bodies[userId] = nil
	end
	store.counters.cleared += 1
	return entry
end

--[=[
	Drop every state on a body (death, respawn, slot switch, leave). Returns how many were dropped.
]=]
function BodyStates.clearBody<D>(store: Store<D>, userId: number): number
	local states = store.bodies[userId]
	if states == nil then
		return 0
	end
	local count = 0
	for _ in states do
		count += 1
	end
	store.bodies[userId] = nil
	store.counters.cleared += count
	return count
end

--[=[
	Every live state on a body, oldest first (ties by key): the replay list for a viewer it just entered.
]=]
function BodyStates.active<D>(store: Store<D>, userId: number, nowMs: number): { Entry<D> }
	prune(store, userId, nowMs)
	local list: { Entry<D> } = {}
	local states = store.bodies[userId]
	if states == nil then
		return list
	end
	for _, entry in states do
		table.insert(list, entry)
	end
	table.sort(list, function(a: Entry<D>, b: Entry<D>): boolean
		if a.startMs ~= b.startMs then
			return a.startMs < b.startMs
		end
		return a.key < b.key
	end)
	return list
end

--[=[
	States held across all bodies, including ended ones not yet pruned (a read-only count for F4).
]=]
function BodyStates.size<D>(store: Store<D>): number
	local count = 0
	for _, states in store.bodies do
		for _ in states do
			count += 1
		end
	end
	return count
end

return BodyStates
```

- [ ] **Step 4: Static checks**

Run: `stylua <the four files> && stylua --check src && selene src`, the typecheck (files added: see Commands), `python scripts/python/check_file_length.py`.
Expected: clean.

- [ ] **Step 5: Run the tests (controller, Studio) — expect all to pass**

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/BodyStateTiming.spec.luau src/ServerScriptService/Services/CharacterReplicationService/BodyStates.luau src/ServerScriptService/Services/CharacterReplicationService/BodyStates.spec.luau
git commit -m "feat(replication): timed body state store with lazy expiry and a safety cap"
```

---

### Task 5: Server transport — relevance helpers, the relay, action packets, replay on Enter

**Runtime behaviour: no** — the service gains the body-state API and calls the relay on Enter, respawn and leave, but no kind is defined until Task 7, so nothing is sent yet. `observeBodies` behaves exactly as before (moved, not changed).

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ObserverQuery.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Services/CharacterReplicationService/BodyStateRelay.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Services/CharacterReplicationService/BodyObservers.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau`
- Modify: `src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau`

**Interfaces:**
- Consumes: `BodyStates` (Task 4); `ReplicationFanout.Body` (R2: `userId`, `ready`, `alive`, `position`, `relevant`, `epoch.value`).
- Produces (ObserverQuery):
  - `export type Sendable<T> = { sendTo: (data: T, target: Player) -> () }` (a typed ByteNet packet is one)
  - `observersOf(bodies: { [number]: Body }, players: { [number]: Player }, subjectUserId: number): { Player }`
  - `observersNear(bodies, players, position: Vector3, radius: number): { Player }`
  - `sendToObservers<T>(bodies, players, player: Player, packet: Sendable<T>, data: T): number`
- Produces (BodyStateRelay):
  - `export type Senders<D> = { started: (target: Player, subject: Player, epoch: number, key: string, data: D, startMs: number, durationMs: number?) -> (), stopped: (target: Player, subject: Player, epoch: number, key: string, startMs: number) -> () }`
  - `export type SetResult = BodyStates.SetResult | "no-body"`
  - `export type Channel<D> = { kind: string, set: (self, player: Player, key: string, data: D, startMs: number, durationMs: number?) -> SetResult, clear: (self, player: Player, key: string) -> boolean, get: (self, player: Player, key: string) -> BodyStates.Entry<D>? }`
  - `export type KindStats = { active: number, replayed: number, counters: BodyStates.Counters }`
  - `new(bodies, players, nowMs: () -> number, maxStates: number?): Relay`; `define<D>(relay, kind, senders: Senders<D>): Channel<D>`; `replayTo(relay, subjectUserId, viewer: Player): number`; `clearBody(relay, userId)`; `stats(relay): { [string]: KindStats }`
- Produces (BodyObservers): `export type LiveBody = { player: Player, epoch: number }`; `observe(bodySpawned, bodyDespawned, liveBodies: () -> { LiveBody }, callback): () -> ()`.
- Produces (CharacterReplicationServiceServer):
  - `defineBodyState: <D>(self, kind: string, senders: BodyStateRelay.Senders<D>) -> BodyStateRelay.Channel<D>`
  - `observersOf: (self, player: Player) -> { Player }`
  - `observersNear: (self, position: Vector3, radius: number) -> { Player }`
  - `sendToObservers: <T>(self, player: Player, packet: ObserverQuery.Sendable<T>, data: T) -> number`
  - `nowMs: (self) -> number` (the session clock)
  - `getState()` gains `bodyStates = BodyStateRelay.stats(relay)`
- Produces (CharacterReplicationEvents): `ActionStarted` struct `{ userId: float64, epoch: uint8, layer: uint8, wireId: uint16, variant: uint8, speedMilli: uint16, startMs: uint32, durationMs: optional(uint32) }` (20 B, 24 B with a duration) and `ActionStopped` struct `{ userId: float64, epoch: uint8, layer: uint8, startMs: uint32 }` (14 B), both reliable.

- [ ] **Step 1: Write the failing specs**

Create `src/ServerScriptService/Services/CharacterReplicationService/ObserverQuery.spec.luau`:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local Folder = ServerScriptService.Services.CharacterReplicationService
local ReplicationFanout = require(Folder.ReplicationFanout)
local ObserverQuery = require(Folder.ObserverQuery)

-- A ready, live body (slot = userId) and its fake player.
local function addBody(bodies, players, userId, position)
	local body = ReplicationFanout.newBody(userId, userId, 0, position or Vector3.zero)
	body.ready = true
	body.alive = true
	bodies[userId] = body
	players[userId] = { UserId = userId, Name = `P{userId}` }
	return body
end

local function userIdsOf(list)
	local ids = {}
	for _, player in list do
		table.insert(ids, player.UserId)
	end
	table.sort(ids)
	return ids
end

return function()
	describe("observersOf", function()
		it("lists the ready viewers that have the body loaded", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			addBody(bodies, players, 2).relevant[1] = true
			addBody(bodies, players, 3)
			local ids = userIdsOf(ObserverQuery.observersOf(bodies, players, 1))
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal(2)
		end)

		it("never lists the body's own player (its relevant set holds itself)", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			expect(#ObserverQuery.observersOf(bodies, players, 1)).to.equal(0)
		end)

		it("skips a viewer that is not ready or has no player", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			local unready = addBody(bodies, players, 2)
			unready.relevant[1] = true
			unready.ready = false
			addBody(bodies, players, 3).relevant[1] = true
			players[3] = nil
			expect(#ObserverQuery.observersOf(bodies, players, 1)).to.equal(0)
		end)
	end)

	describe("observersNear", function()
		it("lists the ready, live bodies within the radius", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1, Vector3.new(0, 0, 0))
			addBody(bodies, players, 2, Vector3.new(50, 0, 0))
			addBody(bodies, players, 3, Vector3.new(700, 0, 0))
			local ids = userIdsOf(ObserverQuery.observersNear(bodies, players, Vector3.zero, 600))
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
		end)

		it("skips bodies that are not live or not ready", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1).alive = false
			addBody(bodies, players, 2).ready = false
			expect(#ObserverQuery.observersNear(bodies, players, Vector3.zero, 600)).to.equal(0)
		end)
	end)

	describe("sendToObservers", function()
		it("sends to the observers plus the body's player and returns the count", function()
			local bodies, players = {}, {}
			addBody(bodies, players, 1)
			addBody(bodies, players, 2).relevant[1] = true
			addBody(bodies, players, 3)
			local sent = {}
			local packet = {
				sendTo = function(data, target)
					table.insert(sent, { data = data, target = target })
				end,
			}
			expect(ObserverQuery.sendToObservers(bodies, players, players[1], packet, "spark")).to.equal(2)
			expect(#sent).to.equal(2)
			expect(sent[1].data).to.equal("spark")
			local targets = {}
			for _, entry in sent do
				table.insert(targets, entry.target)
			end
			local ids = userIdsOf(targets)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
		end)
	end)
end
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyStateRelay.spec.luau`:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local Folder = ServerScriptService.Services.CharacterReplicationService
local ReplicationFanout = require(Folder.ReplicationFanout)
local BodyStateRelay = require(Folder.BodyStateRelay)

-- A relay over fresh maps with a settable clock.
local function world(maxStates)
	local bodies, players = {}, {}
	local clock = { ms = 1000 }
	local relay = BodyStateRelay.new(bodies, players, function()
		return clock.ms
	end, maxStates)
	return relay, bodies, players, clock
end

-- A ready, live body (slot = userId) and its fake player.
local function addBody(bodies, players, userId)
	local body = ReplicationFanout.newBody(userId, userId, 0, Vector3.zero)
	body.ready = true
	body.alive = true
	bodies[userId] = body
	players[userId] = { UserId = userId, Name = `P{userId}` }
	return body, players[userId]
end

-- Senders that record every message.
local function recorder()
	local log = { started = {}, stopped = {} }
	local senders = {
		started = function(target, subject, epoch, key, data, startMs, durationMs)
			table.insert(log.started, {
				target = target,
				subject = subject,
				epoch = epoch,
				key = key,
				data = data,
				startMs = startMs,
				durationMs = durationMs,
			})
		end,
		stopped = function(target, subject, epoch, key, startMs)
			table.insert(
				log.stopped,
				{ target = target, subject = subject, epoch = epoch, key = key, startMs = startMs }
			)
		end,
	}
	return senders, log
end

local function targetIds(messages)
	local ids = {}
	for _, message in messages do
		table.insert(ids, message.target.UserId)
	end
	table.sort(ids)
	return ids
end

-- Subject 1 (epoch 4), observer 2 (has 1 loaded), bystander 3.
local function scene(maxStates)
	local relay, bodies, players, clock = world(maxStates)
	local subjectBody, subject = addBody(bodies, players, 1)
	subjectBody.epoch.value = 4
	local observerBody = addBody(bodies, players, 2)
	observerBody.relevant[1] = true
	addBody(bodies, players, 3)
	local senders, log = recorder()
	local channel = BodyStateRelay.define(relay, "action", senders)
	return relay, channel, log, bodies, players, clock, subject
end

return function()
	describe("define", function()
		it("refuses to define a kind twice", function()
			local relay = world()
			local senders = recorder()
			BodyStateRelay.define(relay, "action", senders)
			expect(function()
				BodyStateRelay.define(relay, "action", senders)
			end).to.throw()
		end)
	end)

	describe("set", function()
		it("sends Started to the owner and every observer, with the body's epoch", function()
			local _, channel, log, _, _, _, subject = scene()
			expect(channel:set(subject, "full", "leap", 1000, 600)).to.equal("created")
			local ids = targetIds(log.started)
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
			for _, message in log.started do
				expect(message.subject).to.equal(subject)
				expect(message.epoch).to.equal(4)
				expect(message.key).to.equal("full")
				expect(message.data).to.equal("leap")
				expect(message.startMs).to.equal(1000)
				expect(message.durationMs).to.equal(600)
			end
		end)

		-- Review Focus 4: one player alone in the server still sees their own action.
		it("sends Started to the owner even when nobody observes the body", function()
			local relay, bodies, players = world()
			local _, subject = addBody(bodies, players, 1)
			local senders, log = recorder()
			local channel = BodyStateRelay.define(relay, "action", senders)
			channel:set(subject, "full", "leap", 1000, 600)
			expect(#log.started).to.equal(1)
			expect(log.started[1].target).to.equal(subject)
		end)

		it("skips an owner whose client is not ready", function()
			local _, channel, log, bodies, _, _, subject = scene()
			bodies[1].ready = false
			channel:set(subject, "full", "leap", 1000, 600)
			local ids = targetIds(log.started)
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal(2)
		end)

		it("refuses a player with no live body and sends nothing", function()
			local _, channel, log, bodies, _, _, subject = scene()
			bodies[1].alive = false
			expect(channel:set(subject, "full", "leap", 1000, 600)).to.equal("no-body")
			expect(#log.started).to.equal(0)
		end)

		it("sends Started again on a replace, and no Stopped", function()
			local _, channel, log, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:set(subject, "full", "guard", 1100, 300)).to.equal("replaced")
			expect(#log.started).to.equal(4)
			expect(#log.stopped).to.equal(0)
		end)

		it("refuses past the per-body cap and sends nothing for the refused state", function()
			local _, channel, log, _, _, _, subject = scene(1)
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:set(subject, "upper", "pose", 1000, nil)).to.equal("full")
			expect(#log.started).to.equal(2)
		end)
	end)

	describe("clear (an early stop)", function()
		it("sends Stopped with the cleared state's start to the owner and observers", function()
			local _, channel, log, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:clear(subject, "full")).to.equal(true)
			local ids = targetIds(log.stopped)
			expect(#ids).to.equal(2)
			expect(log.stopped[1].startMs).to.equal(1000)
			expect(log.stopped[1].key).to.equal("full")
			expect(log.stopped[1].epoch).to.equal(4)
		end)

		it("sends nothing for a key that holds nothing or already ran out", function()
			local _, channel, log, _, _, clock, subject = scene()
			expect(channel:clear(subject, "upper")).to.equal(false)
			channel:set(subject, "full", "leap", 1000, 100)
			clock.ms = 1200
			expect(channel:clear(subject, "full")).to.equal(false)
			expect(#log.stopped).to.equal(0)
		end)
	end)

	describe("replayTo (right after a viewer's Enter)", function()
		it("sends every live state, with its original start time, to that one viewer", function()
			local relay, channel, log, _, players, clock, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			channel:set(subject, "upper", "pose", 1500, nil)
			clock.ms = 3000
			local before = #log.started
			expect(BodyStateRelay.replayTo(relay, 1, players[3])).to.equal(2)
			expect(#log.started).to.equal(before + 2)
			expect(log.started[before + 1].target).to.equal(players[3])
			expect(log.started[before + 1].startMs).to.equal(1000)
			expect(log.started[before + 2].startMs).to.equal(1500)
			expect(BodyStateRelay.stats(relay).action.replayed).to.equal(2)
		end)

		it("replays nothing for a body without states or without a live body", function()
			local relay, channel, _, bodies, players, _, subject = scene()
			expect(BodyStateRelay.replayTo(relay, 1, players[3])).to.equal(0)
			channel:set(subject, "full", "leap", 1000, 5000)
			bodies[1].alive = false
			expect(BodyStateRelay.replayTo(relay, 1, players[3])).to.equal(0)
		end)

		it("leaves out states that ended before the viewer arrived", function()
			local relay, channel, _, _, players, clock, subject = scene()
			channel:set(subject, "full", "leap", 1000, 500)
			clock.ms = 2000
			expect(BodyStateRelay.replayTo(relay, 1, players[3])).to.equal(0)
		end)
	end)

	describe("clearBody (respawn, slot switch, leave)", function()
		it("drops the body's states without a message", function()
			local relay, channel, log, _, players, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			BodyStateRelay.clearBody(relay, 1)
			expect(channel:get(subject, "full")).to.equal(nil)
			expect(#log.stopped).to.equal(0)
			expect(BodyStateRelay.replayTo(relay, 1, players[3])).to.equal(0)
		end)
	end)

	describe("stats", function()
		it("reports active states and counters per kind", function()
			local relay, channel, _, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			channel:set(subject, "full", "guard", 1100, 5000)
			local stats = BodyStateRelay.stats(relay).action
			expect(stats.active).to.equal(1)
			expect(stats.counters.created).to.equal(1)
			expect(stats.counters.replaced).to.equal(1)
		end)
	end)
end
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyObservers.spec.luau`:

```luau
--[=[
	BodyObservers carries `observeBodies` (moved out of the service shell in R3, unchanged). SignalPlus delivers
	deferred, so each step yields once (`task.wait()`) before asserting.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local BodyObservers = require(ServerScriptService.Services.CharacterReplicationService.BodyObservers)

local playerA = { UserId = 1, Name = "A" }
local playerB = { UserId = 2, Name = "B" }

-- Observes with a callback that records spawns and counts cleanups.
local function observe(live)
	local spawned, despawned = SignalTyped.new(), SignalTyped.new()
	local record = { calls = {}, cleaned = 0 }
	local disconnect = BodyObservers.observe(spawned, despawned, function()
		return live or {}
	end, function(player, epoch)
		table.insert(record.calls, { player = player, epoch = epoch })
		return function()
			record.cleaned += 1
		end
	end)
	return spawned, despawned, record, disconnect
end

return function()
	it("calls back for every live body, then for each later spawn", function()
		local spawned, _, record, disconnect = observe({ { player = playerA, epoch = 3 } })
		task.wait()
		expect(#record.calls).to.equal(1)
		expect(record.calls[1].epoch).to.equal(3)
		spawned:Fire(playerB, 1)
		task.wait()
		expect(#record.calls).to.equal(2)
		expect(record.calls[2].player).to.equal(playerB)
		disconnect()
	end)

	it("runs a body's cleanup when it despawns", function()
		local spawned, despawned, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		task.wait()
		despawned:Fire(playerA, 1)
		task.wait()
		expect(record.cleaned).to.equal(1)
		disconnect()
	end)

	it("cleans up the previous body when the same player spawns again", function()
		local spawned, _, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		spawned:Fire(playerA, 2)
		task.wait()
		expect(#record.calls).to.equal(2)
		expect(record.cleaned).to.equal(1)
		disconnect()
	end)

	it("disconnecting runs every cleanup and stops listening", function()
		local spawned, _, record, disconnect = observe()
		spawned:Fire(playerA, 1)
		task.wait()
		disconnect()
		expect(record.cleaned).to.equal(1)
		spawned:Fire(playerA, 2)
		task.wait()
		expect(#record.calls).to.equal(1)
	end)
end
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected: the three specs error on their missing modules; everything else passes.

- [ ] **Step 3: Implement the pure modules**

Create `src/ServerScriptService/Services/CharacterReplicationService/ObserverQuery.luau`:

```luau
--!strict
--[=[
	ObserverQuery: who can see what, read from the R2 relevant sets (character replication R3 spec,
	"observersOf / observersNear"). The answers every future body-tied or place-tied effect needs:

	- `observersOf` — the ready viewers that have a body loaded (its observers). Never the body's own
	  player: the owner sees its own rig, and callers add it when they mean "everyone who sees this body".
	- `observersNear` — the ready players with a live body within `radius` studs of a point (an explosion
	  here is seen by whoever is near enough to have this area loaded; pass the 600-stud relevance radius
	  for "anyone who could see it").
	- `sendToObservers` — one packet to a body's observers plus its own player (a hit spark on this body).

	Pure: reads the service's body and player maps, which are keyed by userId.

	@class ObserverQuery
]=]

local ReplicationFanout = require(script.Parent.ReplicationFanout)

type Body = ReplicationFanout.Body

local ObserverQuery = {}

-- Anything with a ByteNet packet's `sendTo` (a typed ByteNet packet is one).
export type Sendable<T> = { sendTo: (data: T, target: Player) -> () }

function ObserverQuery.observersOf(
	bodies: { [number]: Body },
	players: { [number]: Player },
	subjectUserId: number
): { Player }
	local out: { Player } = {}
	for userId, viewer in bodies do
		if userId ~= subjectUserId and viewer.ready and viewer.relevant[subjectUserId] then
			local player: Player? = players[userId]
			if player ~= nil then
				table.insert(out, player)
			end
		end
	end
	return out
end

function ObserverQuery.observersNear(
	bodies: { [number]: Body },
	players: { [number]: Player },
	position: Vector3,
	radius: number
): { Player }
	local out: { Player } = {}
	for userId, viewer in bodies do
		if viewer.ready and viewer.alive and (viewer.position - position).Magnitude <= radius then
			local player: Player? = players[userId]
			if player ~= nil then
				table.insert(out, player)
			end
		end
	end
	return out
end

--[=[
	Send `data` through `packet` to everyone who sees `player`'s body: its observers plus the player.
	Returns how many received it.
]=]
function ObserverQuery.sendToObservers<T>(
	bodies: { [number]: Body },
	players: { [number]: Player },
	player: Player,
	packet: Sendable<T>,
	data: T
): number
	local targets = ObserverQuery.observersOf(bodies, players, player.UserId)
	table.insert(targets, player)
	for _, target in targets do
		packet.sendTo(data, target)
	end
	return #targets
end

return ObserverQuery
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyStateRelay.luau`:

```luau
--!strict
--[=[
	BodyStateRelay: carries timed body states to the screens that show the body (character replication R3
	spec, "Timed body state"). The replication service owns one relay over its body and player maps; each
	kind (actions today) is defined once and gets a typed channel.

	Who receives what:
	- `set` sends the kind's Started message to the body's owner (when its client is ready) and to every
	  observer (`ObserverQuery.observersOf`). A replaced state needs no stop: the new Started replaces it.
	- `clear` (an EARLY stop) sends Stopped to the same set. A state that runs out its duration sends
	  nothing: every receiver knows the duration and the shared safety cap (`BodyStateTiming`).
	- `replayTo` sends every live state on a body, with its original start time, to one viewer: the
	  service calls it right after that viewer's reliable `Enter`, so ordering on the one reliable channel
	  puts Enter first.
	- `clearBody` drops a body's states silently (respawn, slot switch, leave): receivers clear on the
	  slot table's epoch change or the body leaving, so no message is owed.

	Kinds supply their own send functions (typed ByteNet structs); the relay decides only WHO and WHEN.
	No services: time comes from the injected clock, packets go out through the kind's senders, and the two
	warnings (a refused state, a state ended by the safety cap) go to the Logger.

	@class BodyStateRelay
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local BodyStates = require(script.Parent.BodyStates)
local ObserverQuery = require(script.Parent.ObserverQuery)
local ReplicationFanout = require(script.Parent.ReplicationFanout)

type Body = ReplicationFanout.Body

local log = Logger.new("BodyStateRelay")

local BodyStateRelay = {}

--[=[
	A kind's packet senders. `target` receives a message about `subject`'s body in body epoch `epoch`.
]=]
export type Senders<D> = {
	started: (
		target: Player,
		subject: Player,
		epoch: number,
		key: string,
		data: D,
		startMs: number,
		durationMs: number?
	) -> (),
	stopped: (target: Player, subject: Player, epoch: number, key: string, startMs: number) -> (),
}

export type SetResult = BodyStates.SetResult | "no-body"

--[=[
	The typed handle a kind's owner keeps (AnimationServiceServer keeps the "action" channel).
]=]
export type Channel<D> = {
	kind: string,
	set: (
		self: Channel<D>,
		player: Player,
		key: string,
		data: D,
		startMs: number,
		durationMs: number?
	) -> SetResult,
	clear: (self: Channel<D>, player: Player, key: string) -> boolean,
	get: (self: Channel<D>, player: Player, key: string) -> BodyStates.Entry<D>?,
}

export type KindStats = {
	active: number,
	replayed: number,
	counters: BodyStates.Counters,
}

-- One defined kind, erased to the operations the relay runs across all kinds.
type KindOps = {
	replay: (subjectUserId: number, viewer: Player) -> number,
	clearBody: (userId: number) -> (),
	stats: () -> KindStats,
}

export type Relay = {
	bodies: { [number]: Body },
	players: { [number]: Player },
	nowMs: () -> number,
	maxStates: number,
	kinds: { [string]: KindOps },
}

function BodyStateRelay.new(
	bodies: { [number]: Body },
	players: { [number]: Player },
	nowMs: () -> number,
	maxStates: number?
): Relay
	return {
		bodies = bodies,
		players = players,
		nowMs = nowMs,
		maxStates = maxStates or BodyStates.DEFAULT_MAX_STATES,
		kinds = {},
	}
end

-- The owner (when ready) plus every observer of a live body; empty when the body is gone.
local function audience(relay: Relay, subject: Player): { Player }
	local body = relay.bodies[subject.UserId]
	if body == nil or not body.alive then
		return {}
	end
	local targets = ObserverQuery.observersOf(relay.bodies, relay.players, subject.UserId)
	if body.ready then
		table.insert(targets, subject)
	end
	return targets
end

--[=[
	Define a kind once (errors on a second definition). Returns its typed channel.
]=]
function BodyStateRelay.define<D>(relay: Relay, kind: string, senders: Senders<D>): Channel<D>
	assert(relay.kinds[kind] == nil, `[BodyStateRelay] body-state kind "{kind}" is already defined`)
	local store: BodyStates.Store<D> = BodyStates.new(
		relay.maxStates,
		function(userId: number, entry: BodyStates.Entry<D>)
			log:warn(`body state "{kind}/{entry.key}" on user {userId} reached the safety cap without a stop; cleared`)
		end
	)
	local replayed = 0

	relay.kinds[kind] = {
		replay = function(subjectUserId: number, viewer: Player): number
			local body = relay.bodies[subjectUserId]
			local subject: Player? = relay.players[subjectUserId]
			if body == nil or not body.alive or subject == nil then
				return 0
			end
			local entries = BodyStates.active(store, subjectUserId, relay.nowMs())
			for _, entry in entries do
				senders.started(
					viewer,
					subject,
					body.epoch.value,
					entry.key,
					entry.data,
					entry.startMs,
					entry.durationMs
				)
			end
			replayed += #entries
			return #entries
		end,
		clearBody = function(userId: number)
			BodyStates.clearBody(store, userId)
		end,
		stats = function(): KindStats
			return { active = BodyStates.size(store), replayed = replayed, counters = table.clone(store.counters) }
		end,
	}

	local channel: Channel<D> = {
		kind = kind,
		set = function(
			_self: Channel<D>,
			player: Player,
			key: string,
			data: D,
			startMs: number,
			durationMs: number?
		): SetResult
			local body = relay.bodies[player.UserId]
			if body == nil or not body.alive then
				return "no-body"
			end
			-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
			local result: BodyStates.SetResult =
				BodyStates.set(store, player.UserId, key, data, startMs, durationMs, relay.nowMs())
			if result == "full" then
				log:warn(`body state "{kind}/{key}" refused for {player.Name}: {relay.maxStates} states already live`)
				return result
			end
			for _, target in audience(relay, player) do
				senders.started(target, player, body.epoch.value, key, data, startMs, durationMs)
			end
			return result
		end,
		clear = function(_self: Channel<D>, player: Player, key: string): boolean
			local entry = BodyStates.clear(store, player.UserId, key, relay.nowMs())
			if entry == nil then
				return false
			end
			local body = relay.bodies[player.UserId]
			if body ~= nil then
				for _, target in audience(relay, player) do
					senders.stopped(target, player, body.epoch.value, key, entry.startMs)
				end
			end
			return true
		end,
		get = function(_self: Channel<D>, player: Player, key: string): BodyStates.Entry<D>?
			return BodyStates.get(store, player.UserId, key, relay.nowMs())
		end,
	}
	return channel
end

--[=[
	Send every live state of every kind on `subjectUserId`'s body to `viewer`. Returns how many went.
]=]
function BodyStateRelay.replayTo(relay: Relay, subjectUserId: number, viewer: Player): number
	local sent = 0
	for _, ops in relay.kinds do
		sent += ops.replay(subjectUserId, viewer)
	end
	return sent
end

--[=[
	Drop every state of every kind on a body, silently (respawn, slot switch, leave).
]=]
function BodyStateRelay.clearBody(relay: Relay, userId: number)
	for _, ops in relay.kinds do
		ops.clearBody(userId)
	end
end

function BodyStateRelay.stats(relay: Relay): { [string]: KindStats }
	local out: { [string]: KindStats } = {}
	for kind, ops in relay.kinds do
		out[kind] = ops.stats()
	end
	return out
end

return BodyStateRelay
```

Create `src/ServerScriptService/Services/CharacterReplicationService/BodyObservers.luau`:

```luau
--!strict
--[=[
	BodyObservers: `CharacterReplicationServiceServer:observeBodies` (plan R2 Task 9), moved out of the service
	shell unchanged in R3 to keep the shell under the 400-line cap.

	`observe` runs `callback(player, epoch)` for every live body now (deferred, one thread each) and for every
	body that spawns later; the cleanup a callback returns runs when that body despawns, when the same player
	spawns again, or when the observer is disconnected. The returned function disconnects the observer.

	@class BodyObservers
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)

export type LiveBody = { player: Player, epoch: number }

local BodyObservers = {}

function BodyObservers.observe(
	bodySpawned: SignalTyped.Signal<Player, number>,
	bodyDespawned: SignalTyped.Signal<Player, number>,
	liveBodies: () -> { LiveBody },
	callback: (player: Player, epoch: number) -> (() -> ())?
): () -> ()
	local cleanups: { [Player]: () -> () } = {}
	local function spawned(player: Player, epoch: number)
		local previous = cleanups[player]
		if previous ~= nil then
			cleanups[player] = nil
			previous()
		end
		local cleanup = callback(player, epoch)
		if cleanup ~= nil then
			cleanups[player] = cleanup
		end
	end
	local function despawned(player: Player, _epoch: number)
		local cleanup = cleanups[player]
		if cleanup ~= nil then
			cleanups[player] = nil
			cleanup()
		end
	end
	local spawnConnection = bodySpawned:Connect(spawned)
	local despawnConnection = bodyDespawned:Connect(despawned)
	for _, live in liveBodies() do
		task.spawn(spawned, live.player, live.epoch)
	end
	return function()
		spawnConnection:Disconnect()
		despawnConnection:Disconnect()
		for _, cleanup in cleanups do
			cleanup()
		end
		table.clear(cleanups)
	end
end

return BodyObservers
```

- [ ] **Step 4: Add the action packets**

```diff
diff --git a/src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau b/src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau
index d42f411..1d43013 100644
--- a/src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau
+++ b/src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau
@@ -19,6 +19,12 @@
 	- `Spawn`          to the owner: build your rig here, in this epoch.
 	- `Enter`/`Leave`  to a viewer: a body entered / left its visibility set. `Enter` carries a full-state
 	                   record (age relative to `batchTimeMs`) so the body can be placed at once.
+	- `ActionStarted`  R3 timed body state, kind "action": a server-granted animation on `userId`'s body in
+	                   body epoch `epoch`, on layer index `layer` (AnimationTypes.ANIMATION_LAYERS), the
+	                   registry entry `wireId`, asset `variant` (0 = the entry's own), speed in thousandths,
+	                   session `startMs`, and `durationMs` (absent = open-ended). To the owner and every
+	                   observer; replayed to a viewer right after its `Enter`. 20 B (24 B with a duration).
+	- `ActionStopped`  the grant on that layer that started at `startMs` ended early. 14 B.
 
 	Boot timing: the client waits for the namespace value the server creates when it requires this module
 	(same guard as DebuggerEvents).
@@ -95,6 +101,28 @@ local CharacterReplicationEvents = ByteNet.defineNamespace(NAMESPACE, function()
 				}),
 				reliabilityType = "reliable",
 			}),
+			ActionStarted = ByteNet.definePacket({
+				value = ByteNet.struct({
+					userId = ByteNet.float64,
+					epoch = ByteNet.uint8,
+					layer = ByteNet.uint8,
+					wireId = ByteNet.uint16,
+					variant = ByteNet.uint8,
+					speedMilli = ByteNet.uint16,
+					startMs = ByteNet.uint32,
+					durationMs = ByteNet.optional(ByteNet.uint32),
+				}),
+				reliabilityType = "reliable",
+			}),
+			ActionStopped = ByteNet.definePacket({
+				value = ByteNet.struct({
+					userId = ByteNet.float64,
+					epoch = ByteNet.uint8,
+					layer = ByteNet.uint8,
+					startMs = ByteNet.uint32,
+				}),
+				reliabilityType = "reliable",
+			}),
 		},
 		queries = {},
 		structs = {},
```

- [ ] **Step 5: Wire the service shell**

The relay is cleared synchronously inside `spawnBody` (not on the deferred `bodyDespawned`), so a grant made right after a respawn is never wiped by a late signal. The replay goes right after `Enter` in the visibility hook (hooks may send packets; they never add or remove bodies). A repeated `Ready` replays the owner's own states to the owner.

```diff
diff --git a/src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau b/src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau
index f093322..25782de 100644
--- a/src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau
+++ b/src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau
@@ -19,6 +19,11 @@
 	`observeBodies`, `hasBody`, `getBodyPosition`, `respawn`, `setMaxHealth`. No system reads
 	`player.Character` for a body.
 
+	Timed body state (R3): `defineBodyState(kind, senders)` returns a typed channel (`set` / `clear` / `get`)
+	carried by BodyStateRelay: Started to the owner and observers, Stopped on an early stop, a replay after
+	every `Enter`, silent clearing on respawn / slot switch / leave. Relevance helpers for later effects:
+	`observersOf`, `observersNear`, `sendToObservers`; `nowMs` is the session clock states are stamped with.
+
 	Spec-exempt shell (Players, ByteNet, Instances); the logic lives in the specced cores beside it.
 
 	@class CharacterReplicationServiceServer
@@ -43,6 +48,9 @@ local ReplicationSlots = require(script.Parent.ReplicationSlots)
 local ReplicationFanout = require(script.Parent.ReplicationFanout)
 local ReplicationInstances = require(script.Parent.ReplicationInstances)
 local ReplicationPackets = require(script.Parent.ReplicationPackets)
+local BodyObservers = require(script.Parent.BodyObservers)
+local BodyStateRelay = require(script.Parent.BodyStateRelay)
+local ObserverQuery = require(script.Parent.ObserverQuery)
 
 type Body = ReplicationFanout.Body
 
@@ -71,6 +79,8 @@ local function sessionNowMs(): number
 	return math.floor((Workspace:GetServerTimeNow() - sessionEpochSeconds) * 1000)
 end
 
+local relay = BodyStateRelay.new(bodiesByUserId, playersByUserId, sessionNowMs)
+
 -- The epoch spacing (250 ms) needs a clock that never steps back; GetServerTimeNow can be corrected.
 local function monotonicMs(): number
 	return math.floor(os.clock() * 1000)
@@ -125,6 +135,7 @@ local function spawnBody(player: Player, body: Body, reason: string): boolean
 	if wasAlive then
 		bodyDespawned:Fire(player, previousEpoch)
 	end
+	BodyStateRelay.clearBody(relay, body.userId) -- receivers drop them on the new epoch
 	local position = ReplicationInstances.spawnPoint()
 	body.position = position
 	ReplicationFanout.respawned(body)
@@ -170,6 +181,7 @@ local hooks: ReplicationFanout.Hooks = {
 					ReplicationFanout.enterPayload(subject, sessionNowMs()),
 					player
 				)
+				BodyStateRelay.replayTo(relay, subject.userId, player) -- after Enter on the one reliable channel
 			end
 		else
 			viewer.relevant[subject.userId] = nil
@@ -199,6 +211,7 @@ local function onReady(player: Player)
 	for _, other in bodiesByUserId do
 		CharacterReplicationEvents.packets.SlotEntry.sendTo(slotEntryOf(other, true), player)
 	end
+	BodyStateRelay.replayTo(relay, player.UserId, player) -- a repeated handshake: the owner's own states
 	if not body.alive then
 		spawnBody(player, body, "join")
 	end
@@ -265,6 +278,7 @@ local function onPlayer(player: Player): (() -> ())?
 		end
 		-- A same-account rejoin can interleave with this cleanup: only clear what is still this body's.
 		if bodiesByUserId[userId] == body then
+			BodyStateRelay.clearBody(relay, userId)
 			bodiesByUserId[userId] = nil
 			playersByUserId[userId] = nil
 			focusParts[userId] = nil
@@ -298,6 +312,20 @@ export type CharacterReplicationServiceServer = {
 	getBodyPosition: (self: CharacterReplicationServiceServer, player: Player) -> Vector3?,
 	respawn: (self: CharacterReplicationServiceServer, player: Player, reason: string) -> boolean,
 	setMaxHealth: (self: CharacterReplicationServiceServer, userId: number, maxHealth: number) -> (),
+	defineBodyState: <D>(
+		self: CharacterReplicationServiceServer,
+		kind: string,
+		senders: BodyStateRelay.Senders<D>
+	) -> BodyStateRelay.Channel<D>,
+	observersOf: (self: CharacterReplicationServiceServer, player: Player) -> { Player },
+	observersNear: (self: CharacterReplicationServiceServer, position: Vector3, radius: number) -> { Player },
+	sendToObservers: <T>(
+		self: CharacterReplicationServiceServer,
+		player: Player,
+		packet: ObserverQuery.Sendable<T>,
+		data: T
+	) -> number,
+	nowMs: (self: CharacterReplicationServiceServer) -> number,
 	getState: (self: CharacterReplicationServiceServer) -> { [string]: any },
 }
 
@@ -379,41 +407,16 @@ local CharacterReplicationServiceServer: CharacterReplicationServiceServer = {
 		function disconnects the observer.
 	]=]
 	observeBodies = function(_self, callback)
-		local cleanups: { [Player]: () -> () } = {}
-		local function spawned(player: Player, epoch: number)
-			local previous = cleanups[player]
-			if previous ~= nil then
-				cleanups[player] = nil
-				previous()
-			end
-			local cleanup = callback(player, epoch)
-			if cleanup ~= nil then
-				cleanups[player] = cleanup
-			end
-		end
-		local function despawned(player: Player, _epoch: number)
-			local cleanup = cleanups[player]
-			if cleanup ~= nil then
-				cleanups[player] = nil
-				cleanup()
-			end
-		end
-		local spawnConnection = bodySpawned:Connect(spawned)
-		local despawnConnection = bodyDespawned:Connect(despawned)
-		for userId, body in bodiesByUserId do
-			local player: Player? = playersByUserId[userId]
-			if body.alive and player ~= nil then
-				task.spawn(spawned, player, body.epoch.value)
-			end
-		end
-		return function()
-			spawnConnection:Disconnect()
-			despawnConnection:Disconnect()
-			for _, cleanup in cleanups do
-				cleanup()
+		return BodyObservers.observe(bodySpawned, bodyDespawned, function(): { BodyObservers.LiveBody }
+			local live: { BodyObservers.LiveBody } = {}
+			for userId, body in bodiesByUserId do
+				local player: Player? = playersByUserId[userId]
+				if body.alive and player ~= nil then
+					table.insert(live, { player = player, epoch = body.epoch.value })
+				end
 			end
-			table.clear(cleanups)
-		end
+			return live
+		end, callback)
 	end,
 
 	hasBody = function(_self, player)
@@ -450,6 +453,33 @@ local CharacterReplicationServiceServer: CharacterReplicationServiceServer = {
 		end
 	end,
 
+	--[=[
+		Define a timed body-state kind once (at a consumer's start): returns its typed channel. Kinds bring
+		their own typed reliable packets through `senders`; this service decides who receives them and when.
+	]=]
+	defineBodyState = function(_self, kind, senders)
+		return BodyStateRelay.define(relay, kind, senders)
+	end,
+
+	-- The ready viewers that have this player's body loaded (never the player).
+	observersOf = function(_self, player)
+		return ObserverQuery.observersOf(bodiesByUserId, playersByUserId, player.UserId)
+	end,
+
+	-- The ready players with a live body within `radius` studs of `position`.
+	observersNear = function(_self, position, radius)
+		return ObserverQuery.observersNear(bodiesByUserId, playersByUserId, position, radius)
+	end,
+
+	-- Send `data` to everyone who sees this player's body: its observers plus the player. Returns the count.
+	sendToObservers = function(_self, player, packet, data)
+		return ObserverQuery.sendToObservers(bodiesByUserId, playersByUserId, player, packet, data)
+	end,
+
+	nowMs = function(_self)
+		return sessionNowMs()
+	end,
+
 	getState = function(_self)
 		local ingest: { [string]: UplinkIngest.Counters } = {}
 		local bodies = 0
@@ -467,6 +497,7 @@ local CharacterReplicationServiceServer: CharacterReplicationServiceServer = {
 			downlinkBatches = stats.batches,
 			downlinkBytes = stats.bytes,
 			ingest = ingest,
+			bodyStates = BodyStateRelay.stats(relay),
 		}
 	end,
 }
```

- [ ] **Step 6: Static checks**

Run: `stylua src/ServerScriptService/Services/CharacterReplicationService src/ReplicatedStorage/Shared/Events && stylua --check src && selene src`, the typecheck (files added), `python scripts/python/check_file_length.py` (the shell lands at 390 code lines).
Expected: clean.

- [ ] **Step 7: Run the tests (controller, Studio) — expect all to pass**

The R1/R2 harness numbers must be unchanged (no record, fan-out or interpolation code changed).

- [ ] **Step 8: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau
git commit -m "feat(replication): timed body state relay with replay on enter and relevance helpers"
```

---
### Task 6: Client receiver — `BodyActions`, `RigAnimation`, puppet Animators

**Runtime behaviour: yes** — every puppet gets an Animator and an `AnimationPlayer` (all tracks stopped when it returns to the pool), the client listens for `ActionStarted` / `ActionStopped` and plays them on the owner rig and on puppets, and F4 → Services → `CharacterReplicationServiceClient.animation` appears. Nothing is granted until Task 7, so no action plays yet.

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/BodyActions.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau` (spec-exempt shell)
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau`
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau`

**Interfaces:**
- Consumes: `AnimationPlayer.PlayOpts.variant/startAt`, `PlayHandle:timePosition/length` (Task 2); `AnimationRegistry.idForWire`, `AnimationTypes.layerAt` (Task 3); `BodyStateTiming` (Task 4); the `ActionStarted` / `ActionStopped` packets (Task 5); R2's `RemoteBodies.SlotEntry`, `SlotChange`, `Body`.
- Produces (BodyActions):
  - `export type Started = { userId, epoch, layer, wireId, variant, speedMilli, startMs: number, durationMs: number? }` and `export type Stopped = { userId, epoch, layer, startMs: number }` (the packet payloads)
  - `export type Target = { play: (self, id: string, opts: AnimationPlayer.PlayOpts?) -> (PlayHandle?, string?), stop: (self, id: string, fadeTime: number?) -> boolean }` (an `AnimationPlayer` is one)
  - `export type Outcome = "played" | "pending" | "expired" | "stale" | "unknown" | "failed"`
  - `export type Counters = { started, stopped, played, joinedLate, pendingRig, expired, stale, unknown, loadFailures, lengthMismatches, capped, maxDriftMs: number }`
  - `new(resolveWire: (wireId) -> (string?, AnimationDef?), clock: (userId) -> number): State`
  - `started(state, Started): Outcome`, `stopped(state, Stopped): boolean`, `resetBody(state, userId, epoch)`, `attach(state, userId, epoch, Target)`, `detach(state, userId)`, `setLive(state, userId, live: boolean)`, `forget(state, userId)`, `remove(state, userId)`, `step(state)`, `sampleDrift(state): number`, `counts(state): (number, number)`; `state.warnings: { string }`, `state.counters`; constants `LENGTH_TOLERANCE_MS = 50`, `LATE_JOIN_MS = 250`
- Produces (RigAnimation, Task 6 shape; Tasks 8 and 9 extend it): `start(sessionClock: () -> number?, renderDelay: () -> number)`, `stop()`, `slotEntry(entry, change, previous)`, `bodyLeft(userId)`, `attachPuppet(userId, epoch, puppet)`, `detachPuppet(userId)`, `attachOwner(model, epoch)`, `detachOwner()`, `frame()`, `getState(): { [string]: any }`
- Produces (PuppetPool): `Puppet.animator: Animator`.

- [ ] **Step 1: Write the failing spec**

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/BodyActions.spec.luau`:

```luau
--[=[
	BodyActions against a fake registry, a settable clock and fake rigs. User 2's body is in epoch 1 unless a
	test says otherwise; wire 1 is a 1000 ms one-shot on the full layer, wire 3 an open-ended loop on upper.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BodyActions = require(ReplicatedStorage.Client.Services.CharacterReplicationService.BodyActions)
local BodyStateTiming = require(ReplicatedStorage.Shared.Modules.CharacterReplication.BodyStateTiming)

local DEFS = {
	[1] = { id = "leap", def = { looped = false, layer = "full", durationMs = 1000, interruption = "attack" } },
	[3] = { id = "pose", def = { looped = true, layer = "upper", interruption = "ambient" } },
}

local function resolveWire(wireId)
	local entry = DEFS[wireId]
	if entry == nil then
		return nil, nil
	end
	return entry.id, entry.def
end

-- A fake rig: records plays and stops; handles expose a settable time and length.
local function makeTarget(options)
	options = options or {}
	local target = { plays = {}, stops = {} }
	target.play = function(_self, id, opts)
		if options.fail then
			return nil, options.fail
		end
		local handle =
			{ id = id, opts = opts, stopped = false, time = opts.startAt or 0, clipLength = options.length or 0 }
		handle.stop = function()
			handle.stopped = true
		end
		handle.isPlaying = function()
			return not handle.stopped
		end
		handle.timePosition = function()
			return handle.time
		end
		handle.length = function()
			return handle.clipLength
		end
		handle.adjustSpeed = function() end
		handle.onMarker = function()
			return function() end
		end
		table.insert(target.plays, handle)
		return handle, nil
	end
	target.stop = function(_self, id)
		table.insert(target.stops, id)
		return true
	end
	return target
end

local function started(overrides)
	local message = {
		userId = 2,
		epoch = 1,
		layer = 1,
		wireId = 1,
		variant = 0,
		speedMilli = 1000,
		startMs = 10000,
		durationMs = 1000,
	}
	for key, value in overrides or {} do
		message[key] = value
	end
	return message
end

local POSE = { layer = 2, wireId = 3, durationMs = nil }

local function pose(overrides)
	local message = started(POSE)
	message.durationMs = nil
	for key, value in overrides or {} do
		message[key] = value
	end
	return message
end

-- A state whose clock reads `clock.ms` for every body, with user 2 known in epoch 1.
local function setup()
	local clock = { ms = 10000 }
	local state = BodyActions.new(resolveWire, function(_userId)
		return clock.ms
	end)
	BodyActions.resetBody(state, 2, 1)
	return state, clock
end

return function()
	describe("arrival", function()
		it("plays a Started on an attached rig at once, with the server's variant and speed", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			expect(BodyActions.started(state, started({ variant = 1, speedMilli = 2000, durationMs = 500 }))).to.equal(
				"played"
			)
			local play = target.plays[1]
			expect(play.id).to.equal("leap")
			expect(play.opts.variant).to.equal(1)
			expect(play.opts.speed).to.equal(2)
			expect(play.opts.startAt).to.equal(0)
		end)

		it("starts a late arrival that far into the clip, at its speed", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			clock.ms = 10400
			BodyActions.started(state, started({ speedMilli = 1500 }))
			expect(target.plays[1].opts.startAt).to.be.near(0.6, 1e-6)
			expect(state.counters.joinedLate).to.equal(1)
		end)

		it("keeps an action pending until its body has a rig, then plays it from the right point", function()
			local state, clock = setup()
			expect(BodyActions.started(state, started())).to.equal("pending")
			expect(state.counters.pendingRig).to.equal(1)
			clock.ms = 10300
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			expect(target.plays[1].opts.startAt).to.be.near(0.3, 1e-6)
		end)

		it("waits for the body's clock to reach the start (a puppet's render time)", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			expect(BodyActions.started(state, started({ startMs = 10200 }))).to.equal("pending")
			BodyActions.step(state)
			expect(#target.plays).to.equal(0)
			clock.ms = 10200
			BodyActions.step(state)
			expect(#target.plays).to.equal(1)
			expect(target.plays[1].opts.startAt).to.equal(0)
		end)

		it("ignores a Started that is already past its duration", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			clock.ms = 11500
			expect(BodyActions.started(state, started())).to.equal("expired")
			expect(#target.plays).to.equal(0)
		end)

		it("ignores a Started from another body epoch", function()
			local state = setup()
			expect(BodyActions.started(state, started({ epoch = 2 }))).to.equal("stale")
			expect(state.counters.stale).to.equal(1)
		end)

		it("refuses an unknown wire id, or a layer that does not match the entry", function()
			local state = setup()
			expect(BodyActions.started(state, started({ wireId = 99 }))).to.equal("unknown")
			expect(BodyActions.started(state, started({ layer = 2 }))).to.equal("unknown")
			expect(state.counters.unknown).to.equal(2)
		end)
	end)

	describe("replace and stop", function()
		it("replaces the action on a layer with a newer Started", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			clock.ms = 10100
			BodyActions.started(state, started({ startMs = 10100 }))
			expect(#target.plays).to.equal(2)
			expect(target.stops[1]).to.equal("leap")
		end)

		it("plays actions on different layers together", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.started(state, pose())
			expect(#target.plays).to.equal(2)
			expect(#target.stops).to.equal(0)
		end)

		it("stops the action a Stopped names", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			expect(BodyActions.stopped(state, { userId = 2, epoch = 1, layer = 1, startMs = 10000 })).to.equal(true)
			expect(target.stops[1]).to.equal("leap")
			expect(state.counters.stopped).to.equal(1)
		end)

		it("leaves a newer action alone when a Stopped names an older start", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			clock.ms = 10100
			BodyActions.started(state, started({ startMs = 10100 }))
			expect(BodyActions.stopped(state, { userId = 2, epoch = 1, layer = 1, startMs = 10000 })).to.equal(false)
		end)
	end)

	describe("body lifecycle", function()
		it("drops the old epoch's actions when the body's epoch changes", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.resetBody(state, 2, 2)
			expect(target.stops[1]).to.equal("leap")
			expect((BodyActions.counts(state))).to.equal(0)
		end)

		it("drops pending actions of the old epoch when a rig of a new epoch attaches", function()
			local state = setup()
			BodyActions.started(state, started())
			local target = makeTarget()
			BodyActions.attach(state, 2, 2, target)
			expect(#target.plays).to.equal(0)
		end)

		it("keeps actions pending across a detach and plays them on the next rig", function()
			local state, clock = setup()
			BodyActions.attach(state, 2, 1, makeTarget())
			BodyActions.started(state, started())
			BodyActions.detach(state, 2)
			clock.ms = 10200
			local nextTarget = makeTarget()
			BodyActions.attach(state, 2, 1, nextTarget)
			expect(nextTarget.plays[1].opts.startAt).to.be.near(0.2, 1e-6)
		end)

		it("forget drops the actions but keeps the epoch (the body left range)", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.forget(state, 2)
			expect(target.stops[1]).to.equal("leap")
			expect(BodyActions.started(state, started({ epoch = 2 }))).to.equal("stale")
		end)

		-- Review Focus 1: the slot table's new epoch arrives first, the new epoch's Started next, and the owner
		-- rig (or the puppet) is rebuilt only later.
		it("plays a new epoch's action on the rebuilt rig after a respawn mid-action", function()
			local state, clock = setup()
			local oldRig = makeTarget()
			BodyActions.attach(state, 2, 1, oldRig)
			BodyActions.started(state, started())
			BodyActions.resetBody(state, 2, 2)
			BodyActions.detach(state, 2)
			clock.ms = 10100
			expect(BodyActions.started(state, started({ epoch = 2, startMs = 10100 }))).to.equal("pending")
			local newRig = makeTarget()
			BodyActions.attach(state, 2, 2, newRig)
			expect(oldRig.stops[1]).to.equal("leap")
			expect(#newRig.plays).to.equal(1)
		end)

		-- Review Focus 3: the server replays the action after the next Enter, with its original start.
		it("resumes at the right point when the body leaves range and comes back mid-action", function()
			local state, clock = setup()
			BodyActions.attach(state, 2, 1, makeTarget())
			BodyActions.started(state, started())
			BodyActions.detach(state, 2)
			BodyActions.forget(state, 2)
			clock.ms = 10600
			local again = makeTarget()
			BodyActions.attach(state, 2, 1, again)
			expect(BodyActions.started(state, started())).to.equal("played")
			expect(again.plays[1].opts.startAt).to.be.near(0.6, 1e-6)
		end)

		it("remove forgets the body entirely (its slot was released)", function()
			local state = setup()
			BodyActions.remove(state, 2)
			expect(BodyActions.started(state, started({ epoch = 2 }))).to.equal("pending")
		end)
	end)

	describe("step", function()
		it("drops a one-shot when its time is up without stopping it (the clip ends by itself)", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			clock.ms = 11000
			BodyActions.step(state)
			expect(#target.stops).to.equal(0)
			expect((BodyActions.counts(state))).to.equal(0)
		end)

		it("stops an open-ended action at the safety cap", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, pose())
			clock.ms = 10000 + BodyStateTiming.MAX_OPEN_STATE_MS
			BodyActions.step(state)
			expect(target.stops[1]).to.equal("pose")
			expect(state.counters.capped).to.equal(1)
		end)
	end)

	describe("LOD freeze", function()
		it("re-plays running actions at their current point when the body unfreezes", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, pose())
			BodyActions.setLive(state, 2, false)
			clock.ms = 10500
			BodyActions.setLive(state, 2, true)
			expect(#target.plays).to.equal(2)
			expect(target.plays[2].opts.startAt).to.be.near(0.5, 1e-6)
		end)

		it("keeps an action that arrives while frozen pending until the body unfreezes", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.setLive(state, 2, false)
			expect(BodyActions.started(state, started())).to.equal("pending")
			BodyActions.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		it("stops a held clip once its time is up while frozen, so unfreezing cannot resume it", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.setLive(state, 2, false)
			clock.ms = 11500
			BodyActions.step(state)
			expect(target.stops[1]).to.equal("leap")
			BodyActions.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		-- Review Focus 2: a Stopped for a frozen puppet must stop its held track, or unfreezing resumes it.
		it("stops a held clip when a Stopped arrives while frozen, and does not re-play it", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, pose())
			BodyActions.setLive(state, 2, false)
			expect(BodyActions.stopped(state, { userId = 2, epoch = 1, layer = 2, startMs = 10000 })).to.equal(true)
			expect(target.stops[1]).to.equal("pose")
			BodyActions.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		it("drops an action that ended while frozen when the body unfreezes", function()
			local state, clock = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.setLive(state, 2, false)
			clock.ms = 11500
			BodyActions.setLive(state, 2, true)
			expect(target.stops[1]).to.equal("leap")
			expect(#target.plays).to.equal(1)
		end)
	end)

	describe("play failures", function()
		it("counts a clip that fails to load and drops the action", function()
			local state = setup()
			BodyActions.attach(state, 2, 1, makeTarget({ fail = "load-failed" }))
			expect(BodyActions.started(state, started())).to.equal("failed")
			expect(state.counters.loadFailures).to.equal(1)
			expect((BodyActions.counts(state))).to.equal(0)
		end)

		it("drops a one-shot the player says has already ended", function()
			local state = setup()
			BodyActions.attach(state, 2, 1, makeTarget({ fail = "elapsed" }))
			expect(BodyActions.started(state, started())).to.equal("expired")
		end)
	end)

	describe("readouts", function()
		it("reports a clip whose real length disagrees with its declaration, once per clip", function()
			local state, clock = setup()
			BodyActions.attach(state, 2, 1, makeTarget({ length = 1.3 }))
			BodyActions.started(state, started())
			BodyActions.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
			expect(#state.warnings).to.equal(1)
			clock.ms = 10100
			BodyActions.started(state, started({ startMs = 10100 }))
			BodyActions.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
		end)

		it("passes a clip within the tolerance", function()
			local state = setup()
			BodyActions.attach(state, 2, 1, makeTarget({ length = 1.03 }))
			BodyActions.started(state, started())
			BodyActions.step(state)
			expect(state.counters.lengthMismatches).to.equal(0)
		end)

		it("waits for the clip to load before checking its length", function()
			local state = setup()
			local target = makeTarget()
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			BodyActions.step(state)
			expect(state.counters.lengthMismatches).to.equal(0)
			target.plays[1].clipLength = 1.3
			BodyActions.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
		end)

		it("samples the gap between a track and its start time as drift", function()
			local state, clock = setup()
			local target = makeTarget({ length = 1 })
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, started())
			target.plays[1].time = 0.05
			clock.ms = 10100
			expect(BodyActions.sampleDrift(state)).to.be.near(50, 1e-6)
			expect(state.counters.maxDriftMs).to.equal(50)
		end)

		it("measures a looped clip's drift across the loop seam", function()
			local state, clock = setup()
			local target = makeTarget({ length = 1 })
			BodyActions.attach(state, 2, 1, target)
			BodyActions.started(state, pose())
			target.plays[1].time = 0.01
			clock.ms = 10990
			expect(BodyActions.sampleDrift(state)).to.be.near(20, 1e-6)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected: `BodyActions.spec` errors on the missing module.

- [ ] **Step 3: Implement the core**

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/BodyActions.luau`:

```luau
--!strict
--[=[
	BodyActions: what this client knows about server-granted actions on the bodies it shows, and what it
	plays on their rigs (character replication R3 spec, "Body state receiver"). One path for the owner's own
	rig and for every puppet: both receive the same `ActionStarted` / `ActionStopped` messages.

	- A body holds at most one action per layer; a new Started on a layer replaces the old one.
	- An action plays only when its body has a rig (`attach`) that is live (not LOD-frozen) AND the body's
	  clock has reached the action's start: until then it is pending. The clock is per body (injected): the
	  owner plays at the session clock; a puppet at its render time, so the clip lines up with the motion
	  the viewer is drawing (the same moment its placement comes from).
	- It starts `(clock − startMs) × speed` seconds into the clip, so a viewer that walks into range
	  mid-action (the server's replay after `Enter`) joins at the right point. No continuous re-sync.
	- An action past its duration is ignored on arrival and dropped when its time is up (a one-shot clip
	  ends by itself; an open-ended one is stopped at the shared safety cap).
	- Messages from another body epoch than the one the slot table (or the owner's Spawn) announced are
	  stale and ignored.

	Readouts for F4: counters, the worst start-alignment drift, and a length check (a clip whose real length
	disagrees with its declared `durationMs` is counted and reported once per clip).

	Pure: the registry lookup, the clocks and the rigs' players are injected.

	@class BodyActions
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPlayer = require(ReplicatedStorage.Shared.Modules.AnimationPlayer)
local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)
local BodyStateTiming = require(ReplicatedStorage.Shared.Modules.CharacterReplication.BodyStateTiming)

type AnimationDef = AnimationTypes.AnimationDef

local BodyActions = {}

-- A real clip within this many ms of its declared length passes the length check.
BodyActions.LENGTH_TOLERANCE_MS = 50
-- A start more than this far into the clip counts as joining late (the replay-on-enter case).
BodyActions.LATE_JOIN_MS = 250

-- The `ActionStarted` payload (CharacterReplicationEvents).
export type Started = {
	userId: number,
	epoch: number,
	layer: number,
	wireId: number,
	variant: number,
	speedMilli: number,
	startMs: number,
	durationMs: number?,
}

-- The `ActionStopped` payload.
export type Stopped = {
	userId: number,
	epoch: number,
	layer: number,
	startMs: number,
}

--[=[
	The slice of AnimationPlayer this module drives (structural, so specs fake two functions).
]=]
export type Target = {
	play: (self: Target, id: string, opts: AnimationPlayer.PlayOpts?) -> (AnimationPlayer.PlayHandle?, string?),
	stop: (self: Target, id: string, fadeTime: number?) -> boolean,
}

export type Outcome = "played" | "pending" | "expired" | "stale" | "unknown" | "failed"

export type Counters = {
	started: number,
	stopped: number,
	played: number,
	joinedLate: number,
	pendingRig: number,
	expired: number,
	stale: number,
	unknown: number,
	loadFailures: number,
	lengthMismatches: number,
	capped: number,
	maxDriftMs: number,
}

type Action = {
	id: string,
	def: AnimationDef,
	variant: number,
	speed: number,
	startMs: number,
	durationMs: number?,
	handle: AnimationPlayer.PlayHandle?,
}

type Body = {
	epoch: number?,
	target: Target?,
	live: boolean,
	actions: { [number]: Action }, -- by layer index
}

export type State = {
	resolveWire: (wireId: number) -> (string?, AnimationDef?),
	clock: (userId: number) -> number,
	bodies: { [number]: Body },
	checkedClips: { [string]: boolean },
	warnings: { string }, -- length-check reports, drained by the shell into the log
	counters: Counters,
}

function BodyActions.new(
	resolveWire: (wireId: number) -> (string?, AnimationDef?),
	clock: (userId: number) -> number
): State
	return {
		resolveWire = resolveWire,
		clock = clock,
		bodies = {},
		checkedClips = {},
		warnings = {},
		counters = {
			started = 0,
			stopped = 0,
			played = 0,
			joinedLate = 0,
			pendingRig = 0,
			expired = 0,
			stale = 0,
			unknown = 0,
			loadFailures = 0,
			lengthMismatches = 0,
			capped = 0,
			maxDriftMs = 0,
		},
	}
end

local function bodyOf(state: State, userId: number): Body
	local body = state.bodies[userId]
	if body == nil then
		body = { epoch = nil, target = nil, live = false, actions = {} }
		state.bodies[userId] = body
	end
	return body
end

local function stopAction(body: Body, action: Action)
	local target = body.target
	if target ~= nil and action.handle ~= nil then
		target:stop(action.id)
	end
	action.handle = nil
end

local function dropAll(body: Body)
	for layer, action in body.actions do
		stopAction(body, action)
		body.actions[layer] = nil
	end
end

-- Clip seconds since the action started, at its speed (never negative).
local function clipTime(action: Action, nowMs: number): number
	return math.max(nowMs - action.startMs, 0) / 1000 * action.speed
end

-- Plays an action on its body's rig if the rig is live and the body's clock has reached the start.
local function tryPlay(state: State, userId: number, body: Body, layer: number, action: Action): Outcome
	local target = body.target
	local nowMs = state.clock(userId)
	if target == nil or not body.live or nowMs < action.startMs then
		return "pending"
	end
	local startAt = clipTime(action, nowMs)
	local handle, reason = target:play(action.id, { variant = action.variant, speed = action.speed, startAt = startAt })
	if handle == nil then
		body.actions[layer] = nil
		if reason == "elapsed" then
			state.counters.expired += 1
			return "expired"
		end
		if reason == "load-failed" then
			state.counters.loadFailures += 1
		end
		return "failed"
	end
	action.handle = handle
	state.counters.played += 1
	if startAt * 1000 / action.speed > BodyActions.LATE_JOIN_MS then
		state.counters.joinedLate += 1
	end
	return "played"
end

--[=[
	An `ActionStarted` arrived. Returns what happened to it.
]=]
function BodyActions.started(state: State, message: Started): Outcome
	local body = bodyOf(state, message.userId)
	if body.epoch ~= nil and body.epoch ~= message.epoch then
		state.counters.stale += 1
		return "stale"
	end
	local id, def = state.resolveWire(message.wireId)
	local layer = AnimationTypes.layerAt(message.layer)
	if id == nil or def == nil or layer == nil or def.layer ~= layer or message.speedMilli <= 0 then
		state.counters.unknown += 1
		return "unknown"
	end
	if BodyStateTiming.isOver(message.startMs, message.durationMs, state.clock(message.userId)) then
		state.counters.expired += 1
		return "expired"
	end
	local current = body.actions[message.layer]
	if current ~= nil then
		stopAction(body, current)
	end
	local action: Action = {
		id = id,
		def = def,
		variant = message.variant,
		speed = message.speedMilli / 1000,
		startMs = message.startMs,
		durationMs = message.durationMs,
		handle = nil,
	}
	body.actions[message.layer] = action
	state.counters.started += 1
	if body.target == nil then
		state.counters.pendingRig += 1
	end
	return tryPlay(state, message.userId, body, message.layer, action)
end

--[=[
	An `ActionStopped` arrived: stops the action it names (same layer and start), if still held.
]=]
function BodyActions.stopped(state: State, message: Stopped): boolean
	local body = state.bodies[message.userId]
	if body == nil or body.epoch ~= message.epoch then
		return false
	end
	local action = body.actions[message.layer]
	if action == nil or action.startMs ~= message.startMs then
		return false
	end
	stopAction(body, action)
	body.actions[message.layer] = nil
	state.counters.stopped += 1
	return true
end

--[=[
	The body's epoch, from the slot table (a puppet) or a Spawn (the owner). Another epoch's actions are dropped.
]=]
function BodyActions.resetBody(state: State, userId: number, epoch: number)
	local body = bodyOf(state, userId)
	if body.epoch ~= epoch then
		dropAll(body)
		body.epoch = epoch
	end
end

--[=[
	A rig now shows this body (a puppet acquired, the owner rig built): pending actions start.
]=]
function BodyActions.attach(state: State, userId: number, epoch: number, target: Target)
	BodyActions.resetBody(state, userId, epoch)
	local body = bodyOf(state, userId)
	body.target = target
	body.live = true
	for layer, action in body.actions do
		tryPlay(state, userId, body, layer, action)
	end
end

--[=[
	The rig is gone (the shell already stopped its tracks): actions stay, pending a new rig.
]=]
function BodyActions.detach(state: State, userId: number)
	local body = state.bodies[userId]
	if body == nil then
		return
	end
	body.target = nil
	body.live = false
	for _, action in body.actions do
		action.handle = nil
	end
end

--[=[
	LOD freeze (false) and unfreeze (true). Unfreezing re-plays every action still running at its current
	point (the shell held the tracks while frozen) and drops the ones that ended meanwhile.
]=]
function BodyActions.setLive(state: State, userId: number, live: boolean)
	local body = state.bodies[userId]
	if body == nil or body.live == live or body.target == nil then
		return
	end
	body.live = live
	if not live then
		return
	end
	local nowMs = state.clock(userId)
	for layer, action in body.actions do
		if BodyStateTiming.isOver(action.startMs, action.durationMs, nowMs) then
			stopAction(body, action)
			body.actions[layer] = nil
		else
			tryPlay(state, userId, body, layer, action)
		end
	end
end

--[=[
	The body left this viewer's range: its actions go (the server replays them on the next Enter); the
	epoch stays (the slot table still knows the body).
]=]
function BodyActions.forget(state: State, userId: number)
	local body = state.bodies[userId]
	if body ~= nil then
		dropAll(body)
		body.target = nil
		body.live = false
	end
end

--[=[
	The body is gone from the slot table (released): forget everything about it.
]=]
function BodyActions.remove(state: State, userId: number)
	local body = state.bodies[userId]
	if body ~= nil then
		dropAll(body)
		state.bodies[userId] = nil
	end
end

local function checkLength(state: State, action: Action)
	local durationMs = action.def.durationMs
	local handle = action.handle
	if durationMs == nil or handle == nil then
		return
	end
	local clipKey = `{action.id}#{action.variant}`
	if state.checkedClips[clipKey] then
		return
	end
	local length = handle:length()
	if length <= 0 then
		return -- not loaded yet; checked on a later step
	end
	state.checkedClips[clipKey] = true
	local realMs = math.floor(length * 1000 + 0.5)
	if math.abs(realMs - durationMs) > BodyActions.LENGTH_TOLERANCE_MS then
		state.counters.lengthMismatches += 1
		table.insert(
			state.warnings,
			`"{action.id}" variant {action.variant} is {realMs} ms long but declares durationMs = {durationMs}`
		)
	end
end

--[=[
	Once per frame: starts pending actions whose time has come, drops actions whose time is up (stopping an
	open-ended one at the safety cap), and runs the length check on newly loaded clips.
]=]
function BodyActions.step(state: State)
	for userId, body in state.bodies do
		local nowMs = state.clock(userId)
		for layer, action in body.actions do
			if BodyStateTiming.isOver(action.startMs, action.durationMs, nowMs) then
				if action.durationMs == nil then
					stopAction(body, action)
					state.counters.capped += 1
				elseif not body.live then
					stopAction(body, action) -- a held (frozen) clip must not resume past its end
				end
				body.actions[layer] = nil
			elseif action.handle == nil then
				tryPlay(state, userId, body, layer, action)
			else
				checkLength(state, action)
			end
		end
	end
end

--[=[
	Readout only (no re-seek, spec decision 9): the worst gap, in clip ms, between where each live action's
	track is and where its start time says it should be. Updates `counters.maxDriftMs`; returns this
	sample's worst.
]=]
function BodyActions.sampleDrift(state: State): number
	local worst = 0
	for userId, body in state.bodies do
		if not body.live then
			continue
		end
		local nowMs = state.clock(userId)
		for _, action in body.actions do
			local handle = action.handle
			if handle == nil or not handle:isPlaying() then
				continue
			end
			local length = handle:length()
			local expected = clipTime(action, nowMs)
			if length > 0 then
				if action.def.looped then
					expected %= length
				elseif expected >= length then
					continue
				end
			end
			local drift = math.abs(handle:timePosition() - expected)
			if length > 0 and action.def.looped then
				drift = math.min(drift, length - drift) -- across the loop seam
			end
			worst = math.max(worst, drift * 1000)
		end
	end
	state.counters.maxDriftMs = math.max(state.counters.maxDriftMs, math.floor(worst + 0.5))
	return worst
end

--[=[
	How many actions are held and how many are playing on a rig (F4).
]=]
function BodyActions.counts(state: State): (number, number)
	local held, playing = 0, 0
	for _, body in state.bodies do
		for _, action in body.actions do
			held += 1
			if action.handle ~= nil then
				playing += 1
			end
		end
	end
	return held, playing
end

return BodyActions
```

- [ ] **Step 4: Give every puppet an Animator**

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau
index 678968a..b13ab2b 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau
@@ -9,7 +9,8 @@
 
 	A puppet: scripts stripped, every part non-colliding / non-query / non-touch, an anchored root moved by
 	the client service's single BulkMoveTo, `EvaluateStateMachine = false`, the display name set per player.
-	R2 draws the default look with no animation (R3 and R4 add them).
+	Every puppet has an Animator (created if the template lacks one) so RigAnimation can play on it at once.
+	R4 adds the look.
 
 	Spec-exempt shell (Instances).
 
@@ -27,6 +28,7 @@ export type Puppet = {
 	model: Model,
 	root: BasePart,
 	humanoid: Humanoid,
+	animator: Animator,
 }
 
 export type Pool = {
@@ -58,12 +60,15 @@ local function build(pool: Pool): Puppet?
 	end
 	humanoid.EvaluateStateMachine = false
 	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
+	local found = humanoid:FindFirstChildOfClass("Animator")
+	local animator: Animator = if found ~= nil then found else Instance.new("Animator")
+	animator.Parent = humanoid
 	root.Anchored = true
 	model.Name = "Puppet"
 	model:PivotTo(PuppetPool.HIDDEN_CFRAME)
 	model.Parent = pool.container
 	pool.built += 1
-	return { model = model, root = root, humanoid = humanoid }
+	return { model = model, root = root, humanoid = humanoid, animator = animator }
 end
 
 function PuppetPool.beginFrame(pool: Pool)
```

- [ ] **Step 5: Create the shell**

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau`:

```luau
--!strict
--[=[
	RigAnimation: plays server-granted actions on the rigs this client shows (character replication R3).
	The owner's rig and every puppet go through the same core (BodyActions) and the same per-Animator
	AnimationPlayer the rest of the game uses.

	- `start` connects `ActionStarted` / `ActionStopped` (ByteNet listeners cannot be disconnected, so they
	  route through `active`).
	- The client service reports what it learns about bodies: slot-table rows (`slotEntry`: the epoch of
	  every body, the owner's included; a released slot), a body leaving range (`bodyLeft`), a puppet
	  acquired or released (`attachPuppet` / `detachPuppet`), the owner rig built or dropped
	  (`attachOwner` / `detachOwner`).
	- `frame` runs in the client service's PreRender pass, right after puppet placement: pending actions
	  start, finished ones drop, length-check warnings reach the log, and drift is sampled at 4 Hz.

	Clocks: the owner plays at the session clock; a puppet at its render time (session clock minus the
	render delay), so its actions line up with the motion the viewer draws.

	Spec-exempt shell (ByteNet, Instances); the rules live in BodyActions.

	@class RigAnimation
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPlayer = require(ReplicatedStorage.Shared.Modules.AnimationPlayer)
local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local BodyActions = require(script.Parent.BodyActions)
local PuppetPool = require(script.Parent.PuppetPool)
local RemoteBodies = require(script.Parent.RemoteBodies)

local DRIFT_SAMPLE_SECONDS = 0.25

type PuppetRig = {
	puppet: PuppetPool.Puppet,
	player: AnimationPlayer.AnimationPlayer,
}

local log = Logger.new("RigAnimation")

local active = false
local listening = false
local sessionNowMs: () -> number? = function(): number?
	return nil
end
local renderDelayMs: () -> number = function(): number
	return 0
end
local puppets: { [number]: PuppetRig } = {} -- by userId
local ownerSeq = 0
local nextDriftAt = 0

local function resolveWire(wireId: number): (string?, AnimationTypes.AnimationDef?)
	local id = AnimationRegistry.idForWire(wireId)
	if id == nil then
		return nil, nil
	end
	return id, AnimationRegistry.get(id)
end

-- The owner plays at the session clock; a puppet at its render time. Before the session: never yet.
local function clockFor(userId: number): number
	local nowMs = sessionNowMs()
	if nowMs == nil then
		return -math.huge
	end
	if userId == Players.LocalPlayer.UserId then
		return nowMs
	end
	return nowMs - renderDelayMs()
end

local actions = BodyActions.new(resolveWire, clockFor)

local RigAnimation = {}

function RigAnimation.start(sessionClock: () -> number?, renderDelay: () -> number)
	sessionNowMs = sessionClock
	renderDelayMs = renderDelay
	active = true
	if listening then
		return
	end
	listening = true
	local packets = CharacterReplicationEvents.packets
	packets.ActionStarted.listen(function(data)
		if active then
			BodyActions.started(actions, data)
		end
	end)
	packets.ActionStopped.listen(function(data)
		if active then
			BodyActions.stopped(actions, data)
		end
	end)
end

function RigAnimation.stop()
	active = false
	for userId in puppets do
		RigAnimation.detachPuppet(userId)
	end
	RigAnimation.detachOwner()
	table.clear(actions.bodies)
end

--[=[
	A slot-table row: every active row carries its body's epoch (the owner's own row included, so its
	actions for a new epoch are accepted even before its rig is rebuilt); a released or replaced slot
	forgets the body that held it.
]=]
function RigAnimation.slotEntry(
	entry: RemoteBodies.SlotEntry,
	change: RemoteBodies.SlotChange?,
	previous: RemoteBodies.Body?
)
	if (change == "released" or change == "replaced") and previous ~= nil then
		BodyActions.remove(actions, previous.userId)
	end
	if entry.active then
		BodyActions.resetBody(actions, entry.userId, entry.epoch)
	end
end

-- The body left this viewer's range: the server replays its actions on the next Enter.
function RigAnimation.bodyLeft(userId: number)
	BodyActions.forget(actions, userId)
end

function RigAnimation.attachPuppet(userId: number, epoch: number, puppet: PuppetPool.Puppet)
	local player = AnimationPlayerRuntime.forAnimator(puppet.animator)
	puppets[userId] = { puppet = puppet, player = player }
	BodyActions.attach(actions, userId, epoch, player)
end

-- The puppet goes back to the pool: every track on it stops (a pooled puppet shows nothing).
function RigAnimation.detachPuppet(userId: number)
	local rig = puppets[userId]
	if rig == nil then
		return
	end
	puppets[userId] = nil
	rig.player:stopAll(0)
	BodyActions.detach(actions, userId)
end

-- The owner rig is built. Resolving its Animator may yield, so attach in a thread; a newer rig wins.
function RigAnimation.attachOwner(model: Model, epoch: number)
	ownerSeq += 1
	local mine = ownerSeq
	task.spawn(function()
		local player = AnimationPlayerRuntime.forCharacter(model)
		if mine ~= ownerSeq then
			return
		end
		if player == nil then
			log:warn("the owner rig has no Animator; actions will not play on it")
			return
		end
		BodyActions.attach(actions, Players.LocalPlayer.UserId, epoch, player)
	end)
end

function RigAnimation.detachOwner()
	ownerSeq += 1
	BodyActions.detach(actions, Players.LocalPlayer.UserId)
end

--[=[
	Once per rendered frame, after puppet placement.
]=]
function RigAnimation.frame()
	if not active then
		return
	end
	BodyActions.step(actions)
	if #actions.warnings > 0 then
		for _, warning in actions.warnings do
			log:warn(`length check: {warning}`)
		end
		table.clear(actions.warnings)
	end
	local now = os.clock()
	if now >= nextDriftAt then
		nextDriftAt = now + DRIFT_SAMPLE_SECONDS
		BodyActions.sampleDrift(actions)
	end
end

function RigAnimation.getState(): { [string]: any }
	local held, playing = BodyActions.counts(actions)
	local animated = 0
	for _ in puppets do
		animated += 1
	end
	return {
		actionsHeld = held,
		actionsPlaying = playing,
		puppetsAnimated = animated,
		actions = table.clone(actions.counters),
	}
end

return RigAnimation
```

- [ ] **Step 6: Wire it into the client service**

The owner's epoch reaches `BodyActions` through its own slot row (ruling 4). `RigAnimation.frame()` runs at the end of the PreRender pass, right after `BulkMoveTo`.

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
index 856cf9f..6889dae 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
@@ -10,6 +10,10 @@
 	Viewer half: the slot table, enter/leave and downlink batches feed RemoteBodies; every PreRender it gives
 	each visible body a pooled puppet (PuppetPool) and moves all puppets with ONE `Workspace:BulkMoveTo`.
 
+	Animation (R3): RigAnimation plays server-granted actions on the owner rig and the puppets; this shell
+	tells it about slot rows, bodies leaving, puppets acquired / released and the owner rig, and runs its
+	frame in the same PreRender pass, right after placement.
+
 	The handshake (`Ready`) goes once every listener is connected.
 
 	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, rig) fire for every rig
@@ -37,6 +41,7 @@ local OwnerRig = require(script.Parent.OwnerRig)
 local UplinkSender = require(script.Parent.UplinkSender)
 local RemoteBodies = require(script.Parent.RemoteBodies)
 local PuppetPool = require(script.Parent.PuppetPool)
+local RigAnimation = require(script.Parent.RigAnimation)
 
 local TEMPLATE_NAME = "CharacterRigTemplate"
 local TEMPLATE_WAIT_SECONDS = 30
@@ -148,6 +153,7 @@ local function dropOwnerRig()
 		return
 	end
 	ownerRig = nil
+	RigAnimation.detachOwner()
 	unregisterRig(Players.LocalPlayer, rig.model)
 	OwnerRig.destroy(rig)
 end
@@ -179,6 +185,7 @@ local function buildOwnerRig(position: Vector3, epoch: number)
 	respawnRetryAt = nil
 	UplinkSender.reset(sender)
 	registerRig(Players.LocalPlayer, rig.model)
+	RigAnimation.attachOwner(rig.model, epoch)
 	refreshGroundFilter()
 	log:info(`owner rig built (epoch {epoch})`)
 end
@@ -223,6 +230,7 @@ local function releasePuppet(slot: number)
 		return
 	end
 	held[slot] = nil
+	RigAnimation.detachPuppet(entry.player.UserId)
 	unregisterRig(entry.player, entry.puppet.model)
 	local activePool = pool
 	if activePool ~= nil then
@@ -246,6 +254,7 @@ local function renderPuppets()
 				if puppet ~= nil then
 					held[slot] = { puppet = puppet, player = player }
 					registerRig(player, puppet.model)
+					RigAnimation.attachPuppet(body.userId, body.epoch, puppet)
 				end
 			end
 		end
@@ -274,6 +283,7 @@ local function renderPuppets()
 	if #moveParts > 0 then
 		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
 	end
+	RigAnimation.frame()
 end
 
 export type CharacterReplicationServiceClient = {
@@ -306,17 +316,21 @@ local CharacterReplicationServiceClient: CharacterReplicationServiceClient = {
 			task.spawn(buildOwnerRig, data.position, data.epoch)
 		end)
 		packets.SlotEntry.listen(function(entry)
-			local change = RemoteBodies.applySlot(state, entry)
+			-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
+			local change: RemoteBodies.SlotChange?, previous = RemoteBodies.applySlot(state, entry)
 			if change == "replaced" or change == "released" then
 				releasePuppet(entry.slot)
 			end
+			RigAnimation.slotEntry(entry, change, previous)
 		end)
 		packets.Enter.listen(function(data)
 			RemoteBodies.enter(state, data.slot, data.generation, data.batchTimeMs, data.record)
 		end)
 		packets.Leave.listen(function(data)
-			if RemoteBodies.leave(state, data.slot, data.generation) ~= nil then
+			local body = RemoteBodies.leave(state, data.slot, data.generation)
+			if body ~= nil then
 				releasePuppet(data.slot)
+				RigAnimation.bodyLeft(body.userId)
 			end
 		end)
 		packets.Downlink.listen(function(batch)
@@ -326,6 +340,10 @@ local CharacterReplicationServiceClient: CharacterReplicationServiceClient = {
 			end
 		end)
 
+		RigAnimation.start(sessionNowMs, function(): number
+			return state.delayMs
+		end)
+		janitor:Add(RigAnimation.stop, true)
 		janitor:Add(RunService.Heartbeat:Connect(sampleOwner), "Disconnect")
 		janitor:Add(RunService.PreRender:Connect(renderPuppets), "Disconnect")
 		janitor:Add(dropOwnerRig, true)
@@ -388,6 +406,7 @@ local CharacterReplicationServiceClient: CharacterReplicationServiceClient = {
 			clock = RenderClock.stats(current.clock),
 			starving = current.starving,
 			counters = table.clone(current.stats),
+			animation = RigAnimation.getState(),
 		}
 	end,
 }
```

- [ ] **Step 7: Exempt the shell**

```diff
diff --git a/src/ServerScriptService/Modules/SpecRoots.luau b/src/ServerScriptService/Modules/SpecRoots.luau
index 506a1cc..0003df9 100644
--- a/src/ServerScriptService/Modules/SpecRoots.luau
+++ b/src/ServerScriptService/Modules/SpecRoots.luau
@@ -165,6 +165,9 @@ local EXEMPT_MODULES: { [string]: string } = {
 	["ReplicatedStorage.Client.Services.CharacterReplicationService.OwnerRig"] = "Instance shell (needs a live rig, camera and Humanoid)",
 	["ReplicatedStorage.Client.Services.CharacterReplicationService.PuppetPool"] = "Instance shell (builds and moves rigs)",
 	["ReplicatedStorage.Client.Services.AnimationService.LocomotionBinding"] = "Humanoid-event adapter (core is specced in LocomotionAnimator.spec)",
+	-- R3: plays actions and puppet locomotion on live rigs, behind ByteNet listeners and the camera. Its rules
+	-- live in BodyActions, PuppetLocomotion and PuppetLod, which are specced; verified by the Studio checklist.
+	["ReplicatedStorage.Client.Services.CharacterReplicationService.RigAnimation"] = "ByteNet/Instance/camera shell (cores are specced)",
 
 	-- Thin typed wrappers over vendored libraries — they add types, not behavior; the one `any` cast
 	-- each isolates is the whole point, and there is nothing of ours to assert.
```

- [ ] **Step 8: Static checks**

Run: `stylua src/ReplicatedStorage/Client/Services/CharacterReplicationService src/ServerScriptService/Modules && stylua --check src && selene src`, the typecheck (files added), `python scripts/python/check_file_length.py` (`BodyActions` 341, client service 346 code lines).
Expected: clean.

- [ ] **Step 9: Run the tests (controller, Studio) — expect all to pass**

`SpecRoots.assertAllModulesSpecced` must pass (BodyActions has its spec; RigAnimation is exempt).

- [ ] **Step 10: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(replication): play server-granted actions on the owner rig and puppets"
```

---

### Task 7: Grants — `ActionGrants`, `AnimationServiceServer:play/stop/stopAttacks`, Cmdr routing; the old request path removed

**Runtime behaviour: yes** — `animplay <player> <id> [speed] [variant]` now grants a replicated action that the owner and every viewer play in sync; `animstop` takes an id or a layer; `animstopclass <player> attack` ends attack-class grants. The owner-only `PlayRequest` / `StopRequest` / `StopClassRequest` path and `AnimationRequests` are gone.

**Files:**
- Create: `src/ServerScriptService/Services/AnimationService/ActionGrants.luau` (+ `.spec.luau`)
- Replace: `src/ServerScriptService/Services/AnimationService/AnimationServiceServer.luau` (+ `.spec.luau`)
- Replace: `src/ServerScriptService/Commands/AnimPlay.luau`, `AnimPlayServer.luau` (+ `.spec.luau`), `AnimStop.luau`, `AnimStopServer.luau` (+ `.spec.luau`), `AnimStopClassServer.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Commands/AnimStopClass.luau`
- Modify: `src/ReplicatedStorage/Shared/Events/AnimationEvents.luau`
- Modify: `src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau`
- Delete: `src/ReplicatedStorage/Shared/Modules/AnimationRequests.luau`, `src/ReplicatedStorage/Shared/Modules/AnimationRequests.spec.luau`

**Interfaces:**
- Consumes: `AnimationTypes.layerIndex/layerNamed/ANIMATION_LAYERS`, `AnimationRegistry.get` (Task 3); `CharacterReplicationServiceServer:defineBodyState/nowMs`, `BodyStateRelay.Channel/Senders` (Task 5); the `ActionStarted` / `ActionStopped` packets (Task 5).
- Produces (ActionGrants): `MIN_SPEED = 0.25`, `MAX_SPEED = 4`; `export type Options = { speed: number?, variant: number? }`; `export type ActionData = { id: string, wireId: number, variant: number, speedMilli: number }`; `export type Grant = { def: AnimationDef, layer: AnimationLayer, data: ActionData, durationMs: number? }`; `decide(id, def: AnimationDef?, options: Options?, roll: (count) -> number): (Grant?, string?)`; `canReplace(current: AnimationDef?, incoming: AnimationDef): boolean`.
- Produces (AnimationServiceServer): `dependencies = { "CharacterReplicationServiceServer" }`; `play(self, player, id, options?: ActionGrants.Options): (boolean, string?)`; `stop(self, player, idOrLayer: string): (boolean, string?)`; `stopAttacks(self, player): number`; `validateStopClass` (unchanged); `requestTrackReport`, `requestAssetProbe`, `playOnRig` (unchanged); `getState()` → `{ granted, refused, stopped }`; test seams `_setActionChannel(channel?) -> previous`, `_setRoll(roll?)`.
- Removed: `validatePlay`, `playOnCharacter`, `stopOnCharacter`, `stopAttacksOnCharacter`; `AnimationEvents.packets.PlayRequest/StopRequest/StopClassRequest`; `AnimationRequests`.

- [ ] **Step 1: Write the failing specs**

Create `src/ServerScriptService/Services/AnimationService/ActionGrants.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local ActionGrants = require(ServerScriptService.Services.AnimationService.ActionGrants)

-- Always the last option (the highest variant).
local function lastRoll(count)
	return count
end

local function decide(id, options, roll)
	return ActionGrants.decide(id, AnimationRegistry.get(id), options, roll or lastRoll)
end

return function()
	describe("decide", function()
		it("refuses an unregistered id", function()
			local grant, reason = decide("no-such-action")
			expect(grant).to.equal(nil)
			expect(reason:find("not a registered", 1, true)).to.be.ok()
		end)

		it("refuses an entry that is not replicable (locomotion stays local)", function()
			local grant, reason = decide("idle")
			expect(grant).to.equal(nil)
			expect(reason:find("not a replicable", 1, true)).to.be.ok()
		end)

		it("grants a replicable one-shot on its layer, with its wire id", function()
			local def = AnimationRegistry.get("testleap")
			local grant = decide("testleap")
			expect(grant.layer).to.equal("full")
			expect(grant.def).to.equal(def)
			expect(grant.data.id).to.equal("testleap")
			expect(grant.data.wireId).to.equal(def.wireId)
		end)

		it("derives the duration from the declared length and the speed", function()
			local def = AnimationRegistry.get("testleap")
			expect(decide("testleap").durationMs).to.equal(def.durationMs)
			expect(decide("testleap", { speed = 2 }).durationMs).to.equal(math.floor(def.durationMs / 2 + 0.5))
		end)

		it("leaves a looped entry open-ended", function()
			local grant = decide("testpose")
			expect(grant.durationMs).to.equal(nil)
			expect(grant.layer).to.equal("upper")
		end)

		it("clamps the speed to 0.25-4 and quantises it to thousandths", function()
			expect(decide("testleap", { speed = 10 }).data.speedMilli).to.equal(4000)
			expect(decide("testleap", { speed = 0.1 }).data.speedMilli).to.equal(250)
			expect(decide("testleap", { speed = 1.23456 }).data.speedMilli).to.equal(1235)
			expect(decide("testleap").data.speedMilli).to.equal(1000)
		end)

		it("refuses a speed that is not a positive number", function()
			for _, bad in { 0, -1, 0 / 0, math.huge } do
				local grant, reason = decide("testleap", { speed = bad })
				expect(grant).to.equal(nil)
				expect(reason).to.be.ok()
			end
		end)

		it("rolls the variant on the server when none is asked for", function()
			expect(decide("testleap", nil, lastRoll).data.variant).to.equal(#AnimationRegistry.get("testleap").variants)
			expect(decide("testleap", nil, function()
				return 1
			end).data.variant).to.equal(0)
			expect(decide("testpose").data.variant).to.equal(0) -- no variants: always the entry's own
		end)

		it("honours a requested variant and refuses one out of range", function()
			expect(decide("testleap", { variant = 0 }).data.variant).to.equal(0)
			expect(decide("testleap", { variant = 1 }).data.variant).to.equal(1)
			expect(decide("testleap", { variant = 2 })).to.equal(nil)
			expect(decide("testleap", { variant = 0.5 })).to.equal(nil)
		end)
	end)

	describe("canReplace (one grant per layer)", function()
		local attack = { interruption = "attack" }
		local protected = { interruption = "protected" }
		local ambient = { interruption = "ambient" }

		it("lets anything take an empty layer", function()
			expect(ActionGrants.canReplace(nil, attack)).to.equal(true)
		end)

		it("lets an attack replace an attack or an ambient action", function()
			expect(ActionGrants.canReplace(attack, attack)).to.equal(true)
			expect(ActionGrants.canReplace(ambient, attack)).to.equal(true)
		end)

		it("never lets a non-protected action cut a protected one", function()
			expect(ActionGrants.canReplace(protected, attack)).to.equal(false)
			expect(ActionGrants.canReplace(protected, ambient)).to.equal(false)
		end)

		it("lets a protected action cut anything", function()
			expect(ActionGrants.canReplace(attack, protected)).to.equal(true)
			expect(ActionGrants.canReplace(protected, protected)).to.equal(true)
		end)
	end)
end
```

Replace `src/ServerScriptService/Services/AnimationService/AnimationServiceServer.spec.luau` with:

```luau
--[=[
	AnimationServiceServer's grant surface against a fake "action" channel (the test seam), so no body,
	packet or replication session is needed. The channel stands in for CharacterReplicationServiceServer's:
	one state per layer key, `set` / `get` / `clear`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

local function fakeChannel()
	local channel = { kind = "action", states = {}, sets = {}, clears = {}, nextResult = nil }
	channel.set = function(_self, player, key, data, startMs, durationMs)
		table.insert(
			channel.sets,
			{ player = player, key = key, data = data, startMs = startMs, durationMs = durationMs }
		)
		if channel.nextResult ~= nil then
			return channel.nextResult
		end
		local replacing = channel.states[key] ~= nil
		channel.states[key] = { key = key, data = data, startMs = startMs, durationMs = durationMs }
		return if replacing then "replaced" else "created"
	end
	channel.get = function(_self, _player, key)
		return channel.states[key]
	end
	channel.clear = function(_self, _player, key)
		local had = channel.states[key] ~= nil
		channel.states[key] = nil
		if had then
			table.insert(channel.clears, key)
		end
		return had
	end
	return channel
end

return function()
	local channel, previous

	beforeEach(function()
		channel = fakeChannel()
		previous = AnimationService:_setActionChannel(channel)
		AnimationService:_setRoll(function(count)
			return count -- always the highest variant
		end)
	end)

	afterEach(function()
		AnimationService:_setActionChannel(previous)
		AnimationService:_setRoll(nil)
	end)

	describe("play (grants)", function()
		it("refuses an unknown id before anything reaches the channel", function()
			local ok, reason = AnimationService:play(fakePlayer, "no-such-action")
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
			expect(#channel.sets).to.equal(0)
		end)

		it("refuses a registered entry that is not replicable", function()
			local ok = AnimationService:play(fakePlayer, "idle")
			expect(ok).to.equal(false)
			expect(#channel.sets).to.equal(0)
		end)

		it("grants on the entry's layer with the server's variant, stamped by the session clock", function()
			local def = AnimationRegistry.get("testleap")
			expect(AnimationService:play(fakePlayer, "testleap")).to.equal(true)
			local set = channel.sets[1]
			expect(set.player).to.equal(fakePlayer)
			expect(set.key).to.equal("full")
			expect(set.data.wireId).to.equal(def.wireId)
			expect(set.data.variant).to.equal(#def.variants)
			expect(set.startMs).to.be.a("number")
			expect(set.durationMs).to.equal(def.durationMs)
		end)

		it("honours a requested variant and speed, and shortens the duration with the speed", function()
			local def = AnimationRegistry.get("testleap")
			AnimationService:play(fakePlayer, "testleap", { speed = 2, variant = 0 })
			local set = channel.sets[1]
			expect(set.data.variant).to.equal(0)
			expect(set.data.speedMilli).to.equal(2000)
			expect(set.durationMs).to.equal(math.floor(def.durationMs / 2 + 0.5))
		end)

		it("grants a looped action open-ended", function()
			AnimationService:play(fakePlayer, "testpose")
			expect(channel.sets[1].key).to.equal("upper")
			expect(channel.sets[1].durationMs).to.equal(nil)
		end)

		-- Review Focus 5: `animplay x testpose 1 1` asks for a variant the entry does not have.
		it("refuses a variant the entry does not have, before anything reaches the channel", function()
			local ok, reason = AnimationService:play(fakePlayer, "testpose", { variant = 1 })
			expect(ok).to.equal(false)
			expect(reason:find("variant", 1, true)).to.be.ok()
			expect(#channel.sets).to.equal(0)
		end)

		it("refuses a non-protected action while a protected one holds the layer", function()
			expect(AnimationService:play(fakePlayer, "testguard")).to.equal(true)
			local ok, reason = AnimationService:play(fakePlayer, "testleap")
			expect(ok).to.equal(false)
			expect(reason:find("protected", 1, true)).to.be.ok()
			expect(#channel.sets).to.equal(1)
		end)

		it("lets a protected action replace an attack on its layer", function()
			AnimationService:play(fakePlayer, "testleap")
			expect(AnimationService:play(fakePlayer, "testguard")).to.equal(true)
		end)

		it("keeps layers independent", function()
			AnimationService:play(fakePlayer, "testguard")
			expect(AnimationService:play(fakePlayer, "testpose")).to.equal(true)
		end)

		it("reports a player with no live body", function()
			channel.nextResult = "no-body"
			local ok, reason = AnimationService:play(fakePlayer, "testleap")
			expect(ok).to.equal(false)
			expect(reason:find("no body", 1, true)).to.be.ok()
		end)
	end)

	describe("stop", function()
		it("stops by layer name", function()
			AnimationService:play(fakePlayer, "testpose")
			expect(AnimationService:stop(fakePlayer, "upper")).to.equal(true)
			expect(channel.clears[1]).to.equal("upper")
		end)

		it("stops by action id only while that action holds its layer", function()
			AnimationService:play(fakePlayer, "testleap")
			expect(AnimationService:stop(fakePlayer, "testguard")).to.equal(false)
			expect(AnimationService:stop(fakePlayer, "testleap")).to.equal(true)
		end)

		it("refuses something that is neither a layer nor a replicable action", function()
			local ok, reason = AnimationService:stop(fakePlayer, "idle")
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("reports an empty layer", function()
			expect(AnimationService:stop(fakePlayer, "overlay")).to.equal(false)
		end)
	end)

	describe("stopAttacks (the stop-attacks verb)", function()
		it("ends only attack-class actions", function()
			AnimationService:play(fakePlayer, "testleap")
			AnimationService:play(fakePlayer, "testpose")
			expect(AnimationService:stopAttacks(fakePlayer)).to.equal(1)
			expect(channel.clears[1]).to.equal("full")
			expect(channel.states.upper).to.be.ok()
		end)
	end)

	describe("validateStopClass", function()
		it("refuses to bulk-stop protected and ambient, accepts attack", function()
			expect(AnimationService:validateStopClass("protected")).to.equal(false)
			expect(AnimationService:validateStopClass("ambient")).to.equal(false)
			expect(AnimationService:validateStopClass("attack")).to.equal(true)
		end)

		it("refuses an unknown class string outright", function()
			expect(AnimationService:validateStopClass("sometimes")).to.equal(false)
		end)
	end)
end
```

Replace `src/ServerScriptService/Commands/AnimPlayServer.spec.luau` with:

```luau
--[=[
	Unit tests for the AnimPlay Cmdr command implementation. Mock strategy: patch AnimationService.play
	(the AddCurrencyServer.spec pattern) — the command's own logic is arg forwarding and message shaping.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)
local animPlayCommand = require(ServerScriptService.Commands.AnimPlayServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimPlayServer", function()
		local _origPlay
		local calls = {}
		local nextOk = true
		local nextReason = nil

		beforeAll(function()
			_origPlay = AnimationService.play
			AnimationService.play = function(_self, player, id, options)
				table.insert(calls, { player = player, id = id, options = options })
				return nextOk, nextReason
			end
		end)

		afterAll(function()
			AnimationService.play = _origPlay
		end)

		beforeEach(function()
			calls = {}
			nextOk = true
			nextReason = nil
		end)

		it("routes through the grant entry point with the target, id, speed and variant", function()
			local message = animPlayCommand(nil, fakePlayer, "testleap", 1.5, 1)
			expect(#calls).to.equal(1)
			expect(calls[1].player).to.equal(fakePlayer)
			expect(calls[1].id).to.equal("testleap")
			expect(calls[1].options.speed).to.equal(1.5)
			expect(calls[1].options.variant).to.equal(1)
			expect(message:find("Granted", 1, true)).to.be.ok()
		end)

		it("leaves the variant to the server when it is omitted", function()
			animPlayCommand(nil, fakePlayer, "testleap", 1, nil)
			expect(calls[1].options.variant).to.equal(nil)
		end)

		it("surfaces the service's refusal reason", function()
			nextOk = false
			nextReason = '"idle" is not a replicable action (locomotion stays local)'
			local message = animPlayCommand(nil, fakePlayer, "idle", 1, nil)
			expect(message:find("not a replicable action", 1, true)).to.be.ok()
		end)
	end)
end
```

Replace `src/ServerScriptService/Commands/AnimStopServer.spec.luau` with:

```luau
--[=[
	Unit tests for the AnimStop Cmdr command implementation (patched-service pattern).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)
local animStopCommand = require(ServerScriptService.Commands.AnimStopServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimStopServer", function()
		local _origStop
		local calls = {}
		local nextOk = true
		local nextReason = nil

		beforeAll(function()
			_origStop = AnimationService.stop
			AnimationService.stop = function(_self, player, idOrLayer)
				table.insert(calls, { player = player, idOrLayer = idOrLayer })
				return nextOk, nextReason
			end
		end)

		afterAll(function()
			AnimationService.stop = _origStop
		end)

		beforeEach(function()
			calls = {}
			nextOk = true
			nextReason = nil
		end)

		it("forwards the target and the id or layer", function()
			local message = animStopCommand(nil, fakePlayer, "upper")
			expect(#calls).to.equal(1)
			expect(calls[1].player).to.equal(fakePlayer)
			expect(calls[1].idOrLayer).to.equal("upper")
			expect(message:find("Stopped", 1, true)).to.be.ok()
		end)

		it("surfaces the service's refusal reason", function()
			nextOk = false
			nextReason = '"idle" is neither a layer nor a replicable action'
			local message = animStopCommand(nil, fakePlayer, "idle")
			expect(message:find("neither a layer", 1, true)).to.be.ok()
		end)
	end)
end
```

Replace `src/ServerScriptService/Commands/AnimStopClassServer.spec.luau` with:

```luau
--[=[
	Unit tests for the AnimStopClass Cmdr command implementation. The refusal rule (only `attack` is
	bulk-stoppable) is asserted through the REAL validateStopClass — only the grant-ending half is patched.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)
local animStopClassCommand = require(ServerScriptService.Commands.AnimStopClassServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

return function()
	describe("AnimStopClassServer", function()
		local _origStopAttacks
		local calls = {}

		beforeAll(function()
			_origStopAttacks = AnimationService.stopAttacks
			AnimationService.stopAttacks = function(_self, player)
				table.insert(calls, { player = player })
				return 2
			end
		end)

		afterAll(function()
			AnimationService.stopAttacks = _origStopAttacks
		end)

		beforeEach(function()
			calls = {}
		end)

		it("ends attack-class actions and reports how many", function()
			local message = animStopClassCommand(nil, fakePlayer, "attack")
			expect(#calls).to.equal(1)
			expect(message:find("Stopped 2", 1, true)).to.be.ok()
		end)

		it("refuses protected without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "protected")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)

		it("refuses ambient without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "ambient")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)

		it("refuses an unknown class without ending anything", function()
			local message = animStopClassCommand(nil, fakePlayer, "sometimes")
			expect(#calls).to.equal(0)
			expect(message:find("Refused", 1, true)).to.be.ok()
		end)
	end)
end
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected: `ActionGrants.spec` errors (no module); every `AnimationServiceServer.spec` test fails (`_setActionChannel` is nil in `beforeEach`); the routing tests of the three Cmdr specs fail (they patch `play` / `stop` / `stopAttacks`, which the commands do not call yet); the `animstopclass` refusal tests pass already.

- [ ] **Step 3: Implement the grant core**

Create `src/ServerScriptService/Services/AnimationService/ActionGrants.luau`:

```luau
--!strict
--[=[
	ActionGrants: how a server-granted action plays (character replication R3 spec, "AnimationServiceServer").
	Gameplay owners decide WHETHER and WHAT; this decides HOW, before anything reaches the wire:

	- only a registered, replicable entry can be granted (locomotion stays local);
	- the speed is clamped to `MIN_SPEED`–`MAX_SPEED` and quantised to thousandths, the exact value every
	  receiver gets, so the grant's duration and the clients' clip times agree;
	- the variant is the caller's (checked) or the server's roll, never the client's;
	- the duration is `durationMs / speed` for a one-shot, nil (open-ended) for a looped entry;
	- a new grant on a layer replaces the current one unless the current one is `protected` and the new one
	  is not (an attack cannot cut a dodge or a hit reaction; a hit reaction can cut an attack).

	Pure: the registry entry and the roll are passed in.

	@class ActionGrants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)

type AnimationDef = AnimationTypes.AnimationDef
type AnimationLayer = AnimationTypes.AnimationLayer

local ActionGrants = {}

ActionGrants.MIN_SPEED = 0.25
ActionGrants.MAX_SPEED = 4

export type Options = {
	speed: number?,
	variant: number?,
}

-- What rides the "action" body-state channel, and from there the ActionStarted packet.
export type ActionData = {
	id: string,
	wireId: number,
	variant: number,
	speedMilli: number,
}

export type Grant = {
	def: AnimationDef,
	layer: AnimationLayer,
	data: ActionData,
	durationMs: number?,
}

--[=[
	Decide a grant for `id` (its registry entry `def`, nil when unregistered). `roll(count)` returns 1..count.
	Returns the grant, or nil and the reason.
]=]
function ActionGrants.decide(
	id: string,
	def: AnimationDef?,
	options: Options?,
	roll: (count: number) -> number
): (Grant?, string?)
	if def == nil then
		return nil, `"{id}" is not a registered animation`
	end
	local wireId = def.wireId
	local layer: AnimationLayer? = def.layer
	if def.replicable ~= true or wireId == nil or layer == nil then
		return nil, `"{id}" is not a replicable action (locomotion stays local)`
	end
	local speed = if options ~= nil and options.speed ~= nil then options.speed else 1
	if speed ~= speed or speed <= 0 or speed == math.huge then
		return nil, "speed must be a positive number"
	end
	local speedMilli = math.floor(math.clamp(speed, ActionGrants.MIN_SPEED, ActionGrants.MAX_SPEED) * 1000 + 0.5)
	local count = if def.variants ~= nil then #def.variants else 0
	local variant: number
	local requested = if options ~= nil then options.variant else nil
	if requested ~= nil then
		if requested ~= math.floor(requested) or requested < 0 or requested > count then
			return nil, `variant must be a whole number from 0 to {count} for "{id}"`
		end
		variant = requested
	else
		variant = roll(count + 1) - 1
	end
	local baseMs = def.durationMs
	return {
		def = def,
		layer = layer,
		data = { id = id, wireId = wireId, variant = variant, speedMilli = speedMilli },
		durationMs = if baseMs ~= nil then math.floor(baseMs * 1000 / speedMilli + 0.5) else nil,
	},
		nil
end

--[=[
	Whether a new grant `incoming` may replace the live grant `current` on the same layer.
]=]
function ActionGrants.canReplace(current: AnimationDef?, incoming: AnimationDef): boolean
	return current == nil or current.interruption ~= "protected" or incoming.interruption == "protected"
end

return ActionGrants
```

- [ ] **Step 4: Replace the service**

Replace `src/ServerScriptService/Services/AnimationService/AnimationServiceServer.luau` with:

```luau
--!strict
--[=[
	AnimationServiceServer: the server's animation surface (Phase 6 spec, Decision 5; character replication
	R3, decisions 2-7).

	- **Grants: play on a player's body.** `play(player, id, { speed?, variant? })` is THE entry point for a
	  replicated action: Cmdr `animplay` today; combat, abilities, emotes and NPC-driven player animations
	  later. Those callers decide WHETHER and WHAT (permission, cooldowns); this decides HOW (ActionGrants:
	  replicable only, clamped speed, the server's variant, duration from the declared length, the layer's
	  interruption rule) and hands the grant to CharacterReplicationServiceServer as timed body state of kind
	  "action". The owner's client and every viewer receive the same ActionStarted and play it on their rig
	  of that body: one path, no double plays. `stop` / `stopAttacks` end grants early (ActionStopped).
	- **Server-owned rigs.** NPCs and world models animate server-side through `playOnRig` — consumers
	  arrive with the NPC phase; the path exists so nothing ever grows a second one.
	- **Diagnostics to one client.** `requestTrackReport` / `requestAssetProbe` (the anim-tracks and
	  anim-report read paths).

	No animation state on the charm-sync spine: grants are timed body state, not queryable state.

	@class AnimationServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationEvents = require(ReplicatedStorage.Shared.Events.AnimationEvents)
local AnimationPlayer = require(ReplicatedStorage.Shared.Modules.AnimationPlayer)
local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)
local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local CharacterReplicationServiceServer =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
local BodyStateRelay = require(ServerScriptService.Services.CharacterReplicationService.BodyStateRelay)
local ActionGrants = require(script.Parent.ActionGrants)

type ActionData = ActionGrants.ActionData
type ActionChannel = BodyStateRelay.Channel<ActionData>

local log = Logger.new("AnimationService")

local actionChannel: ActionChannel? = nil
local roll: (count: number) -> number = function(count: number): number
	return math.random(1, count)
end
local counters = { granted = 0, refused = 0, stopped = 0 }

-- The "action" kind's packets: a grant on `key` (a layer name) of `subject`'s body, to `target`.
local actionSenders: BodyStateRelay.Senders<ActionData> = {
	started = function(target, subject, epoch, key, data, startMs, durationMs)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		CharacterReplicationEvents.packets.ActionStarted.sendTo({
			userId = subject.UserId,
			epoch = epoch,
			layer = layer,
			wireId = data.wireId,
			variant = data.variant,
			speedMilli = data.speedMilli,
			startMs = startMs,
			durationMs = durationMs,
		}, target)
	end,
	stopped = function(target, subject, epoch, key, startMs)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		CharacterReplicationEvents.packets.ActionStopped.sendTo({
			userId = subject.UserId,
			epoch = epoch,
			layer = layer,
			startMs = startMs,
		}, target)
	end,
}

local function refuse(reason: string): (boolean, string?)
	counters.refused += 1
	return false, reason
end

export type AnimationServiceServer = {
	dependencies: { string },
	start: (self: AnimationServiceServer) -> (),

	play: (
		self: AnimationServiceServer,
		player: Player,
		id: string,
		options: ActionGrants.Options?
	) -> (boolean, string?),
	stop: (self: AnimationServiceServer, player: Player, idOrLayer: string) -> (boolean, string?),
	stopAttacks: (self: AnimationServiceServer, player: Player) -> number,
	validateStopClass: (self: AnimationServiceServer, class: string) -> boolean,
	requestTrackReport: (self: AnimationServiceServer, player: Player) -> (),
	requestAssetProbe: (self: AnimationServiceServer, player: Player) -> (),

	playOnRig: (
		self: AnimationServiceServer,
		rig: Model,
		id: string,
		opts: AnimationPlayer.PlayOpts?
	) -> (AnimationPlayer.PlayHandle?, string?),
	getState: (self: AnimationServiceServer) -> { [string]: any },

	-- Test seams (specs only): a fake channel instead of the replication service's, a fixed roll.
	_setActionChannel: (self: AnimationServiceServer, channel: ActionChannel?) -> ActionChannel?,
	_setRoll: (self: AnimationServiceServer, nextRoll: ((count: number) -> number)?) -> (),
}

local AnimationServiceServer: AnimationServiceServer = {
	dependencies = { "CharacterReplicationServiceServer" },

	--[=[
		Defines the "action" body-state kind (a cross-service call, so at start, not init).
	]=]
	start = function(_self)
		if actionChannel == nil then
			actionChannel = CharacterReplicationServiceServer:defineBodyState("action", actionSenders)
		end
	end,

	--[=[
		Grants a replicated action on `player`'s body. False and a reason when refused: unknown or
		non-replicable id, bad speed or variant, a protected action holding the layer, no live body.
	]=]
	play = function(_self, player, id, options)
		local grant, reason = ActionGrants.decide(id, AnimationRegistry.get(id), options, roll)
		if grant == nil then
			return refuse(reason or "refused")
		end
		local channel = actionChannel
		if channel == nil then
			return refuse("actions are not ready (the service has not started)")
		end
		local current = channel:get(player, grant.layer)
		if current ~= nil and not ActionGrants.canReplace(AnimationRegistry.get(current.data.id), grant.def) then
			return refuse(`the {grant.layer} layer is held by protected "{current.data.id}"`)
		end
		local result =
			channel:set(player, grant.layer, grant.data, CharacterReplicationServiceServer:nowMs(), grant.durationMs)
		if result == "no-body" then
			return refuse(`{player.Name} has no body`)
		elseif result == "full" then
			return refuse(`{player.Name} already holds the maximum number of body states`)
		end
		counters.granted += 1
		return true, nil
	end,

	--[=[
		Ends a grant early: by layer name ("full" / "upper" / "overlay"), or by action id (only while that id
		holds its layer).
	]=]
	stop = function(_self, player, idOrLayer)
		local channel = actionChannel
		if channel == nil then
			return false, "actions are not ready (the service has not started)"
		end
		local layer: AnimationTypes.AnimationLayer? = AnimationTypes.layerNamed(idOrLayer)
		if layer == nil then
			local def = AnimationRegistry.get(idOrLayer)
			if def == nil or def.layer == nil then
				return false, `"{idOrLayer}" is neither a layer nor a replicable action`
			end
			local current = channel:get(player, def.layer)
			if current == nil or current.data.id ~= idOrLayer then
				return false, `"{idOrLayer}" is not playing on {player.Name}`
			end
			layer = def.layer
		end
		if layer == nil or not channel:clear(player, layer) then
			return false, `nothing is playing on {player.Name}'s {idOrLayer} layer`
		end
		counters.stopped += 1
		return true, nil
	end,

	--[=[
		The stop-attacks verb: ends every grant whose action is `attack`-class. Returns how many ended.
	]=]
	stopAttacks = function(_self, player)
		local channel = actionChannel
		if channel == nil then
			return 0
		end
		local stopped = 0
		for _, layer in AnimationTypes.ANIMATION_LAYERS do
			local current = channel:get(player, layer)
			local def = if current ~= nil then AnimationRegistry.get(current.data.id) else nil
			if def ~= nil and def.interruption == "attack" and channel:clear(player, layer) then
				stopped += 1
			end
		end
		counters.stopped += stopped
		return stopped
	end,

	--[=[
		Whether `class` is bulk-stoppable. Only `attack` is: `protected` is protected by definition, and
		`ambient` dying to a combat verb is the old bug class the declared model exists to kill.
	]=]
	validateStopClass = function(_self, class)
		return AnimationTypes.isInterruptionClass(class) and class == "attack"
	end,

	--[=[
		Asks the client to log its live animation bookkeeping (playback state lives on the client).
	]=]
	requestTrackReport = function(_self, player)
		AnimationEvents.packets.ReportTracks.sendTo(true, player)
	end,

	--[=[
		Asks the client to probe every registry asset id and log failures (PreloadAsync only means
		anything on a client).
	]=]
	requestAssetProbe = function(_self, player)
		AnimationEvents.packets.ProbeAssets.sendTo(true, player)
	end,

	--[=[
		Plays on a server-owned rig (NPC/world model) through the shared runtime. The NPC phase's
		entry point; nothing else should grow a second server playback path.
	]=]
	playOnRig = function(_self, rig, id, opts)
		local player = AnimationPlayerRuntime.forCharacter(rig)
		if player == nil then
			log:warn(`playOnRig: no Animator found on "{rig.Name}"`)
			return nil, "no-animator"
		end
		return player:play(id, opts)
	end,

	-- Grant counters for the F4 Services tab (body-state counts live on the replication service).
	getState = function(_self)
		return table.clone(counters)
	end,

	-- Returns the channel it replaced, so a spec can restore it.
	_setActionChannel = function(_self, channel)
		local previous = actionChannel
		actionChannel = channel
		return previous
	end,

	_setRoll = function(_self, nextRoll)
		roll = nextRoll or function(count: number): number
			return math.random(1, count)
		end
	end,
}

return AnimationServiceServer
```

- [ ] **Step 5: Route the Cmdr commands**

Replace `src/ServerScriptService/Commands/AnimPlay.luau` with:

```luau
--!strict
return {
	Name = "animplay",
	Aliases = { "anim-play" },
	Description = "Grants a replicated action on a player's body: the owner and every viewer play it in sync (character replication R3).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose body plays it" },
		{
			Type = "string",
			Name = "id",
			Description = "A replicable registry action (e.g. testleap, testguard, testpose)",
		},
		{
			Type = "number",
			Name = "speed",
			Description = "Playback speed multiplier (clamped to 0.25-4)",
			Default = 1,
		},
		{
			Type = "number",
			Name = "variant",
			Description = "Which clip: 0 = the entry's own, k = its k-th variant (omit and the server picks)",
			Optional = true,
		},
	},
}
```

Replace `src/ServerScriptService/Commands/AnimPlayServer.luau` with:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)

return function(_context, target: Player, id: string, speed: number, variant: number?)
	local ok, reason = AnimationService:play(target, id, { speed = speed, variant = variant })
	if ok then
		local variantText = if variant ~= nil then `, variant {variant}` else ""
		return `Granted "{id}" on {target.Name}'s body (speed {speed}{variantText}).`
	end
	return `Failed: {reason or "unknown reason"}.`
end
```

Replace `src/ServerScriptService/Commands/AnimStop.luau` with:

```luau
--!strict
return {
	Name = "animstop",
	Aliases = { "anim-stop" },
	Description = "Ends a replicated action on a player's body early, by action id or by layer (full | upper | overlay).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose body stops it" },
		{ Type = "string", Name = "idOrLayer", Description = "A replicable action id, or a layer name" },
	},
}
```

Replace `src/ServerScriptService/Commands/AnimStopServer.luau` with:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)

return function(_context, target: Player, idOrLayer: string)
	local ok, reason = AnimationService:stop(target, idOrLayer)
	if ok then
		return `Stopped "{idOrLayer}" on {target.Name}'s body.`
	end
	return `Failed: {reason or "unknown reason"}.`
end
```

Replace `src/ServerScriptService/Commands/AnimStopClassServer.luau` with:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationService = require(ServerScriptService.Services.AnimationService.AnimationServiceServer)

return function(_context, target: Player, class: string)
	-- Refused HERE: `protected` is protected by definition and `ambient` must never die to a combat
	-- verb. The command still exists for both so the refusal is DEMONSTRABLE, not folklore.
	if not AnimationService:validateStopClass(class) then
		return `Refused: "{class}" is not bulk-stoppable (only "attack" is — protected/ambient by design).`
	end
	local stopped = AnimationService:stopAttacks(target)
	return `Stopped {stopped} attack action(s) on {target.Name}'s body.`
end
```

```diff
diff --git a/src/ServerScriptService/Commands/AnimStopClass.luau b/src/ServerScriptService/Commands/AnimStopClass.luau
index 5d545e8..eba97cd 100644
--- a/src/ServerScriptService/Commands/AnimStopClass.luau
+++ b/src/ServerScriptService/Commands/AnimStopClass.luau
@@ -2,7 +2,7 @@
 return {
 	Name = "animstopclass",
 	Aliases = { "anim-stop-class" },
-	Description = "Bulk-stops a declared interruption class on a player's character. Only 'attack' is actionable — 'protected' and 'ambient' are refused by design (the V2 verification path).",
+	Description = "Ends every attack-class action granted on a player's body. Only 'attack' is actionable — 'protected' and 'ambient' are refused by design.",
 	Group = "Admins",
 	Args = {
 		{ Type = "player", Name = "target", Description = "The player whose character is bulk-stopped" },
```

- [ ] **Step 6: Remove the old owner-only request path**

```diff
diff --git a/src/ReplicatedStorage/Shared/Events/AnimationEvents.luau b/src/ReplicatedStorage/Shared/Events/AnimationEvents.luau
index f7751fe..6bfb48f 100644
--- a/src/ReplicatedStorage/Shared/Events/AnimationEvents.luau
+++ b/src/ReplicatedStorage/Shared/Events/AnimationEvents.luau
@@ -1,15 +1,11 @@
 --!strict
 --[=[
-	AnimationEvents: the ByteNet packet contract for animation requests (Phase 6 spec, Decision 5).
+	AnimationEvents: the ByteNet packet contract for animation diagnostics (Phase 6 spec, Decision 5).
 
-	Server → owning client only. The network owner plays its own character's animations, so a
-	server-INITIATED animation (a hit reaction, a forced stop, an asset probe) is a REQUEST to that
-	client — a discrete event, ByteNet's sanctioned role. No animation state rides the charm-sync
-	spine; there is nothing queryable here.
-
-	Payloads are `ByteNet.unknown` with the real shapes enforced by `AnimationRequests` (the
-	DebuggerEvents `Snapshot` precedent): the client shape-guards then narrows at the trust
-	boundary, and the build/parse pair is specced against itself so the contract cannot drift.
+	Server → one client: the anim-tracks and anim-report read paths (playback state and asset loading
+	live on the client, so the client reports them). Playing an animation on a player's body is NOT here:
+	since character replication R3 a server-granted action is timed body state (`ActionStarted` /
+	`ActionStopped` in CharacterReplicationEvents), delivered to the owner and every viewer alike.
 
 	Boot-timing note (same as DebuggerEvents): the client waits for the per-namespace replicated
 	value the server creates when IT requires this module (at AnimationServiceServer init).
@@ -31,24 +27,6 @@ end
 local AnimationEvents = ByteNet.defineNamespace(NAMESPACE, function()
 	return {
 		packets = {
-			-- server -> client: play a registry animation on your character
-			-- (shape: AnimationRequests.PlayRequest)
-			PlayRequest = ByteNet.definePacket({
-				value = ByteNet.unknown,
-				reliabilityType = "reliable",
-			}),
-			-- server -> client: stop one animation by registry id
-			-- (shape: AnimationRequests.StopRequest)
-			StopRequest = ByteNet.definePacket({
-				value = ByteNet.unknown,
-				reliabilityType = "reliable",
-			}),
-			-- server -> client: bulk-stop a declared interruption class
-			-- (shape: AnimationRequests.StopClassRequest)
-			StopClassRequest = ByteNet.definePacket({
-				value = ByteNet.unknown,
-				reliabilityType = "reliable",
-			}),
 			-- server -> client: log your live animation bookkeeping (the anim-tracks command's
 			-- read path — playback state lives on the owning client, so the CLIENT reports it).
 			-- Payload unused; the packet is the signal.
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau b/src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau
index f34d460..fda210d 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau
@@ -2,13 +2,13 @@
 --[=[
 	AnimationServiceClient: the client's animation surface (Phase 6 spec, Decision 5).
 
-	The network owner plays its own character's animations. This service is where that happens:
-	local consumers (LocomotionAnimator, UI, the F4 panel) and server requests (typed ByteNet
-	packets, parsed at the trust boundary by `AnimationRequests`) both land on the SAME
-	per-Animator `AnimationPlayer`, so bookkeeping is one truth.
+	Local plays on this client's own rig: local consumers (UI, the F4 panel) land on the SAME
+	per-Animator `AnimationPlayer` that LocomotionBinding and the replicated actions use, so bookkeeping
+	is one truth. Server-granted actions do not come through here: since character replication R3 they
+	are timed body state, played on the owner rig and every puppet by RigAnimation.
 
 	Spec-exempt: a network-bound client shell (the DebuggerServiceClient precedent) — every rule it
-	routes to lives in specced modules (`AnimationPlayer`, `AnimationRequests`, the registry).
+	routes to lives in specced modules (`AnimationPlayer`, the registry).
 
 	@class AnimationServiceClient
 ]=]
@@ -21,7 +21,6 @@ local AnimationEvents = require(ReplicatedStorage.Shared.Events.AnimationEvents)
 local AnimationPlayer = require(ReplicatedStorage.Shared.Modules.AnimationPlayer)
 local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
 local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
-local AnimationRequests = require(ReplicatedStorage.Shared.Modules.AnimationRequests)
 local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)
 local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
 
@@ -209,46 +208,9 @@ local AnimationServiceClient: AnimationServiceClient = {
 	end,
 
 	--[=[
-		Wires the server-request listeners. Every packet lands on the same per-Animator player the
-		local consumers use.
+		Wires the diagnostic listeners (anim-tracks, anim-report) and runs the boot-time asset probe.
 	]=]
 	start = function(self)
-		AnimationEvents.packets.PlayRequest.listen(function(payload: unknown)
-			local request, reason = AnimationRequests.parsePlay(payload)
-			if request == nil then
-				log:warn(`bad PlayRequest: {reason or "?"}`)
-				return
-			end
-			self:play(request.id, {
-				fadeTime = request.fadeTime,
-				speed = request.speed,
-				weight = request.weight,
-			})
-		end)
-
-		AnimationEvents.packets.StopRequest.listen(function(payload: unknown)
-			local request, reason = AnimationRequests.parseStop(payload)
-			if request == nil then
-				log:warn(`bad StopRequest: {reason or "?"}`)
-				return
-			end
-			self:stop(request.id, request.fadeTime)
-		end)
-
-		AnimationEvents.packets.StopClassRequest.listen(function(payload: unknown)
-			local request, reason = AnimationRequests.parseStopClass(payload)
-			if request == nil then
-				log:warn(`bad StopClassRequest: {reason or "?"}`)
-				return
-			end
-			local result = self:stopClass(request.class, request.fadeTime)
-			if result.refused then
-				log:warn(`refused bulk stop of class "{request.class}"`)
-			elseif #result.stopped > 0 then
-				log:info(`stopped {#result.stopped} {request.class} track(s): {table.concat(result.stopped, ", ")}`)
-			end
-		end)
-
 		AnimationEvents.packets.ReportTracks.listen(function(_payload: boolean)
 			self:reportTracks()
 		end)
```

```bash
git rm src/ReplicatedStorage/Shared/Modules/AnimationRequests.luau src/ReplicatedStorage/Shared/Modules/AnimationRequests.spec.luau
```

Then confirm nothing references the removed names: `grep -rn "AnimationRequests\|PlayRequest\|StopClassRequest\|playOnCharacter\|stopOnCharacter\|stopAttacksOnCharacter\|validatePlay" src` must print nothing (docs are updated in Task 10).

- [ ] **Step 7: Static checks**

Run: `stylua src/ServerScriptService src/ReplicatedStorage && stylua --check src && selene src`, the typecheck (files added and deleted), `python scripts/python/check_file_length.py`, `python scripts/python/check_pr_rules.py feature/replication-bodies`.
Expected: clean.

- [ ] **Step 8: Run the tests (controller, Studio) — expect all to pass**

- [ ] **Step 9: Quick two-client check (developer)**

Studio Test → Clients and Servers, 2 players. In Cmdr (as an admin): `animplay Player1 testleap 1 1` — both screens play the leap (variant 1) at once; `animplay Player1 testpose` then `animstop Player1 upper` — the pose starts and stops on both. (Puppet locomotion arrives in Task 8, so client 2 sees the leap on a still puppet.)

- [ ] **Step 10: Commit**

```bash
git add -A src/ServerScriptService/Services/AnimationService src/ServerScriptService/Commands src/ReplicatedStorage/Shared/Events/AnimationEvents.luau src/ReplicatedStorage/Client/Services/AnimationService/AnimationServiceClient.luau src/ReplicatedStorage/Shared/Modules
git commit -m "feat(animation): server grants replicated actions; animplay routes through them"
```

---

### Task 8: Puppet locomotion — `PuppetLocomotion`, motion at render time, a `LocomotionAnimator` per puppet

**Runtime behaviour: yes** — other players' puppets idle, walk, run, jump, fall, climb, swim and sit with the owner's animations (walk/run play rate clamped 0.7–1.4); the `LocomotionEnabled` kill switch stops puppet locomotion too.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLocomotion.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau`
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau`

**Interfaces:**
- Consumes: `LocomotionAnimator.new/handleEvent/update/setEnabled/destroy` (Task 1), `RigAnimation` (Task 6).
- Produces:
  - `CharacterInterpolator.motionAt(b: Buffer, timeMs: number, hint: Hint): (number, boolean, Vector3)` — the nearest sample's state, grounded, velocity
  - `RemoteBodies.Body` gains `motionState: number`, `motionGrounded: boolean`, `motionVelocity: Vector3`, written by `frame` for every placed body
  - `LocomotionAnimator.Config` gains `minRate: number?`, `maxRate: number?` (walk/run only)
  - `PuppetLocomotion`: `MIN_SPEED_STEP = 0.25`, `RATE_STEP = 0.05`, `MIN_RATE = 0.7`, `MAX_RATE = 1.4`; `export type Tracker`; `new(): Tracker`; `reset(tracker)`; `step(tracker, state: number, velocity: Vector3): (LocomotionEvent?, number?)`
  - `RigAnimation.attachPuppet(userId, slot, epoch, puppet)` (adds `slot`); `RigAnimation.frame(bodies: { [number]: RemoteBodies.Body }, placed: { [number]: boolean })`

- [ ] **Step 1: Write the failing specs**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau b/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau
index 5820376..b2b9dae 100644
--- a/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau
+++ b/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau
@@ -229,6 +229,42 @@ return function()
 		end)
 	end)
 
+	describe("motionAt (puppet locomotion, R3)", function()
+		local function jump()
+			local b = Interp.newBuffer()
+			Interp.push(b, 0, sample(0, 0))
+			Interp.push(b, 0, sample(20, 0.3, { state = 5, grounded = false, velocity = Vector3.new(16, -20, 0) }))
+			return b
+		end
+
+		it("reports the nearest sample's state, grounded flag and velocity", function()
+			local b = jump()
+			local hint = Interp.newHint()
+			local state, grounded, velocity = Interp.motionAt(b, 9, hint)
+			expect(state).to.equal(8)
+			expect(grounded).to.equal(true)
+			expect(velocity.Y).to.equal(0)
+			state, grounded, velocity = Interp.motionAt(b, 11, hint)
+			expect(state).to.equal(5)
+			expect(grounded).to.equal(false)
+			expect(velocity.Y).to.equal(-20)
+		end)
+
+		it("uses the edge samples outside the buffer", function()
+			local b = jump()
+			local hint = Interp.newHint()
+			expect((Interp.motionAt(b, -50, hint))).to.equal(8)
+			expect((Interp.motionAt(b, 500, hint))).to.equal(5)
+		end)
+
+		it("reports a standing default on an empty buffer", function()
+			local state, grounded, velocity = Interp.motionAt(Interp.newBuffer(), 0, Interp.newHint())
+			expect(state).to.equal(0)
+			expect(grounded).to.equal(true)
+			expect(velocity).to.equal(Vector3.zero)
+		end)
+	end)
+
 	describe("evaluatePose", function()
 		it("matches evaluate's position and yaw while turning across ±π", function()
 			local b = Interp.newBuffer()
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.spec.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.spec.luau
index e294200..1160646 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.spec.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.spec.luau
@@ -185,6 +185,19 @@ return function()
 			expect(math.atan2(-look.X, -look.Z)).to.be.near(0.5, 0.03)
 		end)
 
+		it("leaves each placed body's movement state at render time, for puppet locomotion", function()
+			local state = visibleState(1000)
+			local airborne = { state = 5, grounded = false, velocity = Vector3.new(16, -10, 0) }
+			RemoteBodies.onBatch(state, batch(1, 1017, { airborne }), 1030, 0)
+			state.clock.delayMs = 0 -- white-box: render time = now
+			state.clock.targetMs = 0
+			RemoteBodies.frame(state, 1016, {}, {}, nil)
+			local body = state.bodies[5]
+			expect(body.motionState).to.equal(5)
+			expect(body.motionGrounded).to.equal(false)
+			expect(body.motionVelocity.Y < 0).to.equal(true)
+		end)
+
 		it("skips hidden and empty bodies", function()
 			local state = RemoteBodies.new(LOCAL_USER)
 			RemoteBodies.applySlot(state, entry())
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
index 4452819..d9ed3ee 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.spec.luau
@@ -211,6 +211,34 @@ return function()
 		end)
 	end)
 
+	describe("stride play-rate clamp (puppets, spec §6.8)", function()
+		it("clamps the walk and run rate to the configured range", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(
+				fake,
+				{ walkRunThreshold = 18, walkScale = 16, runScale = 16, minRate = 0.7, maxRate = 1.4 }
+			)
+			animator:handleEvent("running", 4, 0)
+			expect(lastPlay(fake).opts.speed).to.be.near(0.7, 1e-6)
+			animator:handleEvent("running", 40, 1)
+			expect(lastPlay(fake).opts.speed).to.be.near(1.4, 1e-6)
+		end)
+
+		it("leaves the rate unclamped by default (the owner's rig)", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { walkScale = 16 })
+			animator:handleEvent("running", 4, 0)
+			expect(lastPlay(fake).opts.speed).to.be.near(0.25, 1e-6)
+		end)
+
+		it("does not clamp climbing", function()
+			local fake = makeFakePlayer()
+			local animator = makeAnimator(fake, { climbScale = 5, minRate = 0.7, maxRate = 1.4 })
+			animator:handleEvent("climbing", 1, 0)
+			expect(lastPlay(fake).opts.speed).to.be.near(0.2, 1e-6)
+		end)
+	end)
+
 	describe("other states", function()
 		it("swims when moving and swim-idles when not", function()
 			local fake = makeFakePlayer()
```

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLocomotion.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PuppetLocomotion = require(ReplicatedStorage.Client.Services.CharacterReplicationService.PuppetLocomotion)

local S = Enum.HumanoidStateType

local function step(tracker, state, velocity)
	return PuppetLocomotion.step(tracker, state.Value, velocity or Vector3.zero)
end

return function()
	describe("state to event", function()
		it("maps each owner state to the event its Humanoid would fire", function()
			local cases = {
				{ S.Running, "running" },
				{ S.RunningNoPhysics, "running" },
				{ S.Landed, "running" },
				{ S.Jumping, "jumping" },
				{ S.Freefall, "freefall" },
				{ S.Climbing, "climbing" },
				{ S.Swimming, "swimming" },
				{ S.Seated, "seated" },
				{ S.GettingUp, "gettingUp" },
				{ S.PlatformStanding, "platformStanding" },
				{ S.Dead, "died" },
			}
			for _, case in cases do
				local event = step(PuppetLocomotion.new(), case[1])
				expect(event).to.equal(case[2])
			end
		end)

		it("sends nothing for states with no locomotion pose, so the current pose holds", function()
			for _, state in { S.Physics, S.FallingDown, S.Ragdoll } do
				expect(step(PuppetLocomotion.new(), state)).to.equal(nil)
			end
			expect(PuppetLocomotion.step(PuppetLocomotion.new(), 29, Vector3.zero)).to.equal(nil)
		end)
	end)

	describe("speed", function()
		it("carries horizontal speed running, vertical climbing and full speed swimming", function()
			local _, running = step(PuppetLocomotion.new(), S.Running, Vector3.new(3, 9, 4))
			expect(running).to.be.near(5, 1e-6)
			local _, climbing = step(PuppetLocomotion.new(), S.Climbing, Vector3.new(1, -6, 0))
			expect(climbing).to.be.near(6, 1e-6)
			local _, swimming = step(PuppetLocomotion.new(), S.Swimming, Vector3.new(2, 3, 6))
			expect(swimming).to.be.near(7, 1e-6)
			local _, jumping = step(PuppetLocomotion.new(), S.Jumping, Vector3.new(0, 50, 0))
			expect(jumping).to.equal(nil)
		end)
	end)

	describe("send on change only", function()
		it("sends an event once, then again only when it changes", function()
			local tracker = PuppetLocomotion.new()
			expect(step(tracker, S.Freefall)).to.equal("freefall")
			expect(step(tracker, S.Freefall)).to.equal(nil)
			expect(step(tracker, S.Running, Vector3.new(10, 0, 0))).to.equal("running")
		end)

		it("re-sends running when the speed moves by at least 5 % of the last sent speed", function()
			local tracker = PuppetLocomotion.new()
			step(tracker, S.Running, Vector3.new(10, 0, 0))
			expect(step(tracker, S.Running, Vector3.new(10.4, 0, 0))).to.equal(nil)
			local event, speed = step(tracker, S.Running, Vector3.new(10.6, 0, 0))
			expect(event).to.equal("running")
			expect(speed).to.be.near(10.6, 1e-6)
		end)

		it("re-sends from a standstill after a step of at least 0.25 studs/s", function()
			local tracker = PuppetLocomotion.new()
			step(tracker, S.Running, Vector3.zero)
			expect(step(tracker, S.Running, Vector3.new(0.2, 0, 0))).to.equal(nil)
			expect(step(tracker, S.Running, Vector3.new(0.3, 0, 0))).to.equal("running")
		end)

		it("reset makes the next step send again", function()
			local tracker = PuppetLocomotion.new()
			step(tracker, S.Running, Vector3.new(10, 0, 0))
			PuppetLocomotion.reset(tracker)
			expect(step(tracker, S.Running, Vector3.new(10, 0, 0))).to.equal("running")
		end)
	end)

	it("gives puppets the 0.7-1.4 stride-rate clamp", function()
		expect(PuppetLocomotion.MIN_RATE).to.equal(0.7)
		expect(PuppetLocomotion.MAX_RATE).to.equal(1.4)
	end)
end
```

- [ ] **Step 2: Run the tests (controller, Studio) — expect failures**

Expected FAIL: `motionAt (puppet locomotion, R3)`, `leaves each placed body's movement state at render time, for puppet locomotion`, `clamps the walk and run rate to the configured range`; `PuppetLocomotion.spec` errors (no module). The other two clamp tests already pass (no clamp configured / climbing).

- [ ] **Step 3: Implement the cores**

```diff
diff --git a/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau b/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau
index 7c78251..e7084d3 100644
--- a/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau
+++ b/src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau
@@ -256,6 +256,38 @@ function CharacterInterpolator.evaluatePose(b: Buffer, timeMs: number, hint: Hin
 	return position, lerpAngle(a.yaw, c.yaw, s), mode
 end
 
+--[=[
+	The movement state at `timeMs` for puppet animation (R3): the NEAREST sample's state, grounded flag and
+	sent velocity (the nearest-sample rule `evaluate` uses for state); past the newest sample the newest,
+	before the oldest the oldest. Allocation-free; shares `evaluatePose`'s hint.
+]=]
+function CharacterInterpolator.motionAt(b: Buffer, timeMs: number, hint: Hint): (number, boolean, Vector3)
+	local samples = b.samples
+	local count = #samples
+	if count == 0 then
+		return 0, true, Vector3.zero
+	end
+	local first = samples[1]
+	if timeMs <= first.timeMs then
+		return first.state, first.grounded, first.velocity
+	end
+	local last = samples[count]
+	if timeMs >= last.timeMs then
+		return last.state, last.grounded, last.velocity
+	end
+	local i = math.clamp(hint.index, 1, count - 1)
+	while i > 1 and samples[i].timeMs > timeMs do
+		i -= 1
+	end
+	while i < count - 1 and samples[i + 1].timeMs <= timeMs do
+		i += 1
+	end
+	hint.index = i
+	local a, c = samples[i], samples[i + 1]
+	local nearest = if timeMs - a.timeMs < c.timeMs - timeMs then a else c
+	return nearest.state, nearest.grounded, nearest.velocity
+end
+
 function CharacterInterpolator.evaluate(b: Buffer, timeMs: number): Evaluation
 	local samples = b.samples
 	local count = #samples
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau
index b6e37b0..0d8394e 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau
@@ -14,7 +14,8 @@
 	  stragglers never vote.
 	- `frame` advances the render clock (starving = some body was in `hold`; `behind` never counts), then
 	  evaluates every visible body on the allocation-free path, dead-reckoning (gravity, ground) when it runs
-	  past its newest sample.
+	  past its newest sample. Each placed body also gets its movement state at the same render time
+	  (`motionState`, `motionGrounded`, `motionVelocity`), which puppet locomotion reads (R3).
 
 	Pure: time is passed in (session ms); the caller supplies the ground query.
 
@@ -52,6 +53,10 @@ export type Body = {
 	samples: CharacterInterpolator.Buffer,
 	hint: CharacterInterpolator.Hint,
 	visible: boolean,
+	-- The nearest sample's state at the last rendered frame (puppet locomotion, R3).
+	motionState: number,
+	motionGrounded: boolean,
+	motionVelocity: Vector3,
 }
 
 export type Stats = {
@@ -112,6 +117,9 @@ local function newBody(entry: SlotEntry): Body
 		samples = samples,
 		hint = CharacterInterpolator.newHint(),
 		visible = false,
+		motionState = 0,
+		motionGrounded = true,
+		motionVelocity = Vector3.zero,
 	}
 end
 
@@ -288,6 +296,8 @@ function RemoteBodies.frame(
 				position = reckoned
 			end
 		end
+		body.motionState, body.motionGrounded, body.motionVelocity =
+			CharacterInterpolator.motionAt(body.samples, renderTime, body.hint)
 		count += 1
 		outSlots[count] = slot
 		outCFrames[count] = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
index bed4b36..3688f1b 100644
--- a/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
+++ b/src/ReplicatedStorage/Client/Services/AnimationService/LocomotionAnimator.luau
@@ -49,6 +49,9 @@ export type Config = {
 	climbScale: number?,
 	swimScale: number?,
 	jumpDuration: number?,
+	-- Optional clamp on the walk / run play rate (puppets: 0.7-1.4, spec §6.8). Unset = unclamped (the owner).
+	minRate: number?,
+	maxRate: number?,
 }
 
 export type LocomotionEvent =
@@ -128,6 +131,19 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 	local jumpDuration = if config ~= nil and config.jumpDuration ~= nil
 		then config.jumpDuration
 		else DEFAULTS.jumpDuration
+	local minRate = if config ~= nil then config.minRate else nil
+	local maxRate = if config ~= nil then config.maxRate else nil
+
+	-- A stride's play rate, inside the configured clamp.
+	local function strideRate(rate: number): number
+		if minRate ~= nil and rate < minRate then
+			return minRate
+		end
+		if maxRate ~= nil and rate > maxRate then
+			return maxRate
+		end
+		return rate
+	end
 
 	local enabled = true
 	local destroyed = false
@@ -203,9 +219,9 @@ function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): Loco
 				if moveSpeed <= IDLE_SPEED then
 					setPose("idle")
 				elseif moveSpeed < walkRunThreshold then
-					setPose("walk", moveSpeed / walkScale)
+					setPose("walk", strideRate(moveSpeed / walkScale))
 				else
-					setPose("run", moveSpeed / runScale)
+					setPose("run", strideRate(moveSpeed / runScale))
 				end
 			elseif event == "jumping" then
 				jumpUntil = now + jumpDuration
```

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLocomotion.luau`:

```luau
--!strict
--[=[
	PuppetLocomotion: turns a puppet's interpolated movement into LocomotionAnimator events (character
	replication R3 spec, "Viewer and owner client"; parent spec §6.8). Puppets reuse the owner's animation
	code path (an AnimationPlayer and a LocomotionAnimator each); this replaces the Humanoid signals the
	owner's binding forwards, with no new network traffic: the movement record already carries the state.

	- The record's state (`HumanoidStateType % 32`, the nearest sample at render time) picks the event the
	  owner's Humanoid would have fired: running (Running, RunningNoPhysics, Landed), jumping, freefall,
	  climbing, swimming, seated, gettingUp, platformStanding, died. Any other state (ragdoll, physics,
	  falling down) sends nothing, so the current pose holds.
	- Speed is what the owner's signal carries: horizontal speed for running, vertical for climbing, full
	  speed for swimming.
	- An event goes out only on change: another event, or for a speed-carrying one a speed change of at
	  least `MIN_SPEED_STEP` studs/s or `RATE_STEP` of the last sent speed (no per-frame retuning).
	- The grounded flag is deliberately not used: the owner's animator decides by state alone, and the
	  puppet must play exactly what the owner plays.

	Pure.

	@class PuppetLocomotion
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocomotionAnimator = require(ReplicatedStorage.Client.Services.AnimationService.LocomotionAnimator)

type LocomotionEvent = LocomotionAnimator.LocomotionEvent

local PuppetLocomotion = {}

PuppetLocomotion.MIN_SPEED_STEP = 0.25
PuppetLocomotion.RATE_STEP = 0.05
-- The stride play-rate clamp puppets give their LocomotionAnimator (§6.8).
PuppetLocomotion.MIN_RATE = 0.7
PuppetLocomotion.MAX_RATE = 1.4

local STATE = Enum.HumanoidStateType
local EVENT_BY_STATE: { [number]: LocomotionEvent } = {
	[STATE.Running.Value] = "running",
	[STATE.RunningNoPhysics.Value] = "running",
	[STATE.Landed.Value] = "running",
	[STATE.Jumping.Value] = "jumping",
	[STATE.Freefall.Value] = "freefall",
	[STATE.Climbing.Value] = "climbing",
	[STATE.Swimming.Value] = "swimming",
	[STATE.Seated.Value] = "seated",
	[STATE.GettingUp.Value] = "gettingUp",
	[STATE.PlatformStanding.Value] = "platformStanding",
	[STATE.Dead.Value] = "died",
}

export type Tracker = {
	lastEvent: LocomotionEvent?,
	lastSpeed: number,
}

function PuppetLocomotion.new(): Tracker
	return { lastEvent = nil, lastSpeed = 0 }
end

--[=[
	Forget what was sent, so the next step re-sends the current event (a fresh LocomotionAnimator, an
	unfrozen puppet).
]=]
function PuppetLocomotion.reset(tracker: Tracker)
	tracker.lastEvent = nil
	tracker.lastSpeed = 0
end

local function speedFor(event: LocomotionEvent, velocity: Vector3): number?
	if event == "running" then
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	elseif event == "climbing" then
		return math.abs(velocity.Y)
	elseif event == "swimming" then
		return velocity.Magnitude
	end
	return nil
end

--[=[
	This frame's event for the puppet, or nil when nothing changed enough. `state` is the record's state
	value, `velocity` the sample's sent velocity.
]=]
function PuppetLocomotion.step(tracker: Tracker, state: number, velocity: Vector3): (LocomotionEvent?, number?)
	local event: LocomotionEvent? = EVENT_BY_STATE[state]
	if event == nil then
		return nil, nil
	end
	local speed = speedFor(event, velocity)
	if event == tracker.lastEvent then
		if speed == nil then
			return nil, nil
		end
		local last = tracker.lastSpeed
		if math.abs(speed - last) < math.max(PuppetLocomotion.MIN_SPEED_STEP, last * PuppetLocomotion.RATE_STEP) then
			return nil, nil
		end
	end
	tracker.lastEvent = event
	tracker.lastSpeed = speed or 0
	return event, speed
end

return PuppetLocomotion
```

- [ ] **Step 4: Drive puppet locomotion from the shell**

A respawn (new body epoch) gives the puppet a fresh `LocomotionAnimator`: death latches the old one.

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
index fb9f346..9b12bad 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
@@ -1,8 +1,13 @@
 --!strict
 --[=[
-	RigAnimation: plays server-granted actions on the rigs this client shows (character replication R3).
-	The owner's rig and every puppet go through the same core (BodyActions) and the same per-Animator
-	AnimationPlayer the rest of the game uses.
+	RigAnimation: animates the rigs this client shows (character replication R3). The owner's rig and every
+	puppet go through the same per-Animator AnimationPlayer the rest of the game uses.
+
+	- Actions: server-granted, through BodyActions, on the owner rig and every puppet alike.
+	- Puppet locomotion: each puppet gets its own LocomotionAnimator (the owner's code path, with the §6.8
+	  stride-rate clamp), fed by PuppetLocomotion from the movement state RemoteBodies interpolated for the
+	  frame. The owner's own locomotion stays with LocomotionBinding (Humanoid signals). The
+	  `LocomotionEnabled` kill switch reaches puppets too.
 
 	- `start` connects `ActionStarted` / `ActionStopped` (ByteNet listeners cannot be disconnected, so they
 	  route through `active`).
@@ -10,19 +15,22 @@
 	  every body, the owner's included; a released slot), a body leaving range (`bodyLeft`), a puppet
 	  acquired or released (`attachPuppet` / `detachPuppet`), the owner rig built or dropped
 	  (`attachOwner` / `detachOwner`).
-	- `frame` runs in the client service's PreRender pass, right after puppet placement: pending actions
+	- `frame` runs in the client service's PreRender pass, right after puppet placement: each placed puppet's
+	  locomotion is stepped from the same interpolated moment its placement came from, pending actions
 	  start, finished ones drop, length-check warnings reach the log, and drift is sampled at 4 Hz.
 
 	Clocks: the owner plays at the session clock; a puppet at its render time (session clock minus the
 	render delay), so its actions line up with the motion the viewer draws.
 
-	Spec-exempt shell (ByteNet, Instances); the rules live in BodyActions.
+	Spec-exempt shell (ByteNet, Instances); the rules live in BodyActions, PuppetLocomotion and
+	LocomotionAnimator.
 
 	@class RigAnimation
 ]=]
 
 local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local Workspace = game:GetService("Workspace")
 
 local AnimationPlayer = require(ReplicatedStorage.Shared.Modules.AnimationPlayer)
 local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
@@ -30,15 +38,22 @@ local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Ani
 local AnimationTypes = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationTypes)
 local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
 local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
+local LocomotionAnimator = require(ReplicatedStorage.Client.Services.AnimationService.LocomotionAnimator)
 local BodyActions = require(script.Parent.BodyActions)
+local PuppetLocomotion = require(script.Parent.PuppetLocomotion)
 local PuppetPool = require(script.Parent.PuppetPool)
 local RemoteBodies = require(script.Parent.RemoteBodies)
 
 local DRIFT_SAMPLE_SECONDS = 0.25
+local LOCOMOTION_ENABLED_ATTRIBUTE = "LocomotionEnabled"
 
 type PuppetRig = {
 	puppet: PuppetPool.Puppet,
 	player: AnimationPlayer.AnimationPlayer,
+	slot: number,
+	epoch: number,
+	locomotion: LocomotionAnimator.LocomotionAnimator,
+	tracker: PuppetLocomotion.Tracker,
 }
 
 local log = Logger.new("RigAnimation")
@@ -54,6 +69,31 @@ end
 local puppets: { [number]: PuppetRig } = {} -- by userId
 local ownerSeq = 0
 local nextDriftAt = 0
+local killSwitchConnection: RBXScriptConnection? = nil
+
+local function locomotionEnabled(): boolean
+	return Workspace:GetAttribute(LOCOMOTION_ENABLED_ATTRIBUTE) ~= false
+end
+
+local function newLocomotion(player: AnimationPlayer.AnimationPlayer): LocomotionAnimator.LocomotionAnimator
+	local locomotion = LocomotionAnimator.new(player, {
+		minRate = PuppetLocomotion.MIN_RATE,
+		maxRate = PuppetLocomotion.MAX_RATE,
+	})
+	locomotion:setEnabled(locomotionEnabled())
+	return locomotion
+end
+
+-- A pose's first play must be a cache hit (Phase 6 decision 6); a pooled puppet keeps its cache.
+local function warmLocomotion(player: AnimationPlayer.AnimationPlayer)
+	local domain = AnimationRegistry.domain("locomotion")
+	if domain == nil then
+		return
+	end
+	for id in domain do
+		player:warm(id)
+	end
+end
 
 local function resolveWire(wireId: number): (string?, AnimationTypes.AnimationDef?)
 	local id = AnimationRegistry.idForWire(wireId)
@@ -83,6 +123,14 @@ function RigAnimation.start(sessionClock: () -> number?, renderDelay: () -> numb
 	sessionNowMs = sessionClock
 	renderDelayMs = renderDelay
 	active = true
+	if killSwitchConnection == nil then
+		killSwitchConnection = Workspace:GetAttributeChangedSignal(LOCOMOTION_ENABLED_ATTRIBUTE):Connect(function()
+			local enabled = locomotionEnabled()
+			for _, rig in puppets do
+				rig.locomotion:setEnabled(enabled)
+			end
+		end)
+	end
 	if listening then
 		return
 	end
@@ -102,6 +150,11 @@ end
 
 function RigAnimation.stop()
 	active = false
+	local connection = killSwitchConnection
+	if connection ~= nil then
+		connection:Disconnect()
+		killSwitchConnection = nil
+	end
 	for userId in puppets do
 		RigAnimation.detachPuppet(userId)
 	end
@@ -132,9 +185,17 @@ function RigAnimation.bodyLeft(userId: number)
 	BodyActions.forget(actions, userId)
 end
 
-function RigAnimation.attachPuppet(userId: number, epoch: number, puppet: PuppetPool.Puppet)
+function RigAnimation.attachPuppet(userId: number, slot: number, epoch: number, puppet: PuppetPool.Puppet)
 	local player = AnimationPlayerRuntime.forAnimator(puppet.animator)
-	puppets[userId] = { puppet = puppet, player = player }
+	warmLocomotion(player)
+	puppets[userId] = {
+		puppet = puppet,
+		player = player,
+		slot = slot,
+		epoch = epoch,
+		locomotion = newLocomotion(player),
+		tracker = PuppetLocomotion.new(),
+	}
 	BodyActions.attach(actions, userId, epoch, player)
 end
 
@@ -145,6 +206,7 @@ function RigAnimation.detachPuppet(userId: number)
 		return
 	end
 	puppets[userId] = nil
+	rig.locomotion:destroy()
 	rig.player:stopAll(0)
 	BodyActions.detach(actions, userId)
 end
@@ -171,13 +233,39 @@ function RigAnimation.detachOwner()
 	BodyActions.detach(actions, Players.LocalPlayer.UserId)
 end
 
+-- One placed puppet's locomotion for this frame. A new body epoch (a respawn) gets a fresh animator: death
+-- latches the old one.
+local function stepLocomotion(rig: PuppetRig, body: RemoteBodies.Body, now: number)
+	if body.epoch ~= rig.epoch then
+		rig.locomotion:destroy()
+		rig.locomotion = newLocomotion(rig.player)
+		PuppetLocomotion.reset(rig.tracker)
+		rig.epoch = body.epoch
+	end
+	-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
+	local event: LocomotionAnimator.LocomotionEvent?, speed =
+		PuppetLocomotion.step(rig.tracker, body.motionState, body.motionVelocity)
+	if event ~= nil then
+		rig.locomotion:handleEvent(event, speed, now)
+	end
+	rig.locomotion:update(now)
+end
+
 --[=[
-	Once per rendered frame, after puppet placement.
+	Once per rendered frame, after puppet placement. `bodies` is RemoteBodies' table (by slot); `placed`
+	marks the slots placed this frame (a puppet whose buffer a respawn just emptied is not).
 ]=]
-function RigAnimation.frame()
+function RigAnimation.frame(bodies: { [number]: RemoteBodies.Body }, placed: { [number]: boolean })
 	if not active then
 		return
 	end
+	local now = os.clock()
+	for _, rig in puppets do
+		local body = bodies[rig.slot]
+		if body ~= nil and placed[rig.slot] then
+			stepLocomotion(rig, body, now)
+		end
+	end
 	BodyActions.step(actions)
 	if #actions.warnings > 0 then
 		for _, warning in actions.warnings do
@@ -185,7 +273,6 @@ function RigAnimation.frame()
 		end
 		table.clear(actions.warnings)
 	end
-	local now = os.clock()
 	if now >= nextDriftAt then
 		nextDriftAt = now + DRIFT_SAMPLE_SECONDS
 		BodyActions.sampleDrift(actions)
```

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
index 6889dae..a3ce910 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau
@@ -254,7 +254,7 @@ local function renderPuppets()
 				if puppet ~= nil then
 					held[slot] = { puppet = puppet, player = player }
 					registerRig(player, puppet.model)
-					RigAnimation.attachPuppet(body.userId, body.epoch, puppet)
+					RigAnimation.attachPuppet(body.userId, slot, body.epoch, puppet)
 				end
 			end
 		end
@@ -283,7 +283,7 @@ local function renderPuppets()
 	if #moveParts > 0 then
 		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
 	end
-	RigAnimation.frame()
+	RigAnimation.frame(state.bodies, placedSlots)
 end
 
 export type CharacterReplicationServiceClient = {
```

- [ ] **Step 5: Static checks**

Run: `stylua src/ReplicatedStorage && stylua --check src && selene src`, the typecheck (a file was added), `python scripts/python/check_file_length.py`.
Expected: clean.

- [ ] **Step 6: Run the tests (controller, Studio) — expect all to pass**

The R1/R2 harness numbers must be unchanged: `motionAt` only reads the buffer, and `frame`'s placement output is the same.

- [ ] **Step 7: Commit**

```bash
git add src/ReplicatedStorage
git commit -m "feat(replication): puppets animate locomotion from the movement records"
```

---

### Task 9: Puppet animation LOD

**Runtime behaviour: yes** — a puppet off screen or beyond 275 studs freezes (pose held, position still updates) and unfreezes back on screen within 250 studs, resuming locomotion and any running action at its current point; F4 shows puppets per tier.

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLod.luau` (+ `.spec.luau`)
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau`

**Interfaces:**
- Consumes: `AnimationPlayer:setPaused` (Task 2), `BodyActions.setLive` (Task 6), `PuppetLocomotion.reset` (Task 8).
- Produces (PuppetLod): `export type Tier = "full" | "frozen"`; `export type Config = { fullStuds, hysteresisStuds, rateHz, edgeMarginPx: number }`; `DEFAULT_CONFIG` (250, 25, 4, 64; frozen); `isOnScreen(viewport: Vector3, viewportSize: Vector2, marginPx: number): boolean`; `decide(current: Tier, distance: number, onScreen: boolean, config: Config): Tier`; `nextCheckAt(now: number, rateHz: number, phase: number?): number`.
- Produces (RigAnimation): `getState().lod = { full, frozen, pauseMode }` (replaces `puppetsAnimated`); the Workspace attribute `PuppetLodEnabled` (false = every puppet full).

- [ ] **Step 1: Measure the pause mechanism (controller, Studio)**

Spec: "(a) all track speeds 0, or (b) detach the puppet's Animator … pick the one with near-zero cost and no pose snap". In a Play session of this build, paste into the **client** command bar. Run it twice: once with the camera turned AWAY from the probe rigs (the cost numbers), once looking AT them (the pose: watch for a snap to the bind pose).

```lua
task.spawn(function()
	local RunService = game:GetService("RunService")
	local template = game:GetService("ReplicatedStorage"):WaitForChild("CharacterRigTemplate")
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position + camera.CFrame.LookVector * 30
	local folder = Instance.new("Folder")
	folder.Name = "LodPauseProbe"
	folder.Parent = workspace
	local rigs = {}
	for i = 1, 40 do
		local model = template:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		humanoid.EvaluateStateMachine = false
		model:FindFirstChild("HumanoidRootPart").Anchored = true
		model:PivotTo(CFrame.new(origin + Vector3.new((i % 8) * 5 - 20, 0, math.floor(i / 8) * 5)))
		model.Parent = folder
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://11257118786" -- the registry's walk
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play()
		rigs[i] = { humanoid = humanoid, animator = animator, track = track, model = model }
	end
	local function shoulderAngle()
		local motor = rigs[1].model:FindFirstChild("RightShoulder", true)
		if motor ~= nil and motor:IsA("Motor6D") then
			local _, angle = motor.Transform:ToAxisAngle()
			return angle
		end
		return -1
	end
	local function measure(label)
		task.wait(1)
		local frames, total = 0, 0
		local connection = RunService.PreRender:Connect(function(dt)
			frames += 1
			total += dt
		end)
		task.wait(5)
		connection:Disconnect()
		print(string.format("[LodPause] %-22s %.2f ms/frame (%d frames), shoulder %.3f rad", label, total / frames * 1000, frames, shoulderAngle()))
	end
	measure("playing")
	print(string.format("[LodPause] (a) shoulder at freeze %.3f rad", shoulderAngle()))
	for _, rig in rigs do
		rig.track:AdjustSpeed(0)
	end
	measure("(a) track speed 0")
	for _, rig in rigs do
		rig.track:AdjustSpeed(1)
	end
	measure("(a) resumed")
	print(string.format("[LodPause] (b) shoulder at freeze %.3f rad", shoulderAngle()))
	for _, rig in rigs do
		rig.animator.Parent = nil
	end
	measure("(b) Animator detached")
	for _, rig in rigs do
		rig.animator.Parent = rig.humanoid
	end
	measure("(b) reattached")
	print("[LodPause] (b) track still playing after reattach:", rigs[1].track.IsPlaying)
	for _, rig in rigs do
		rig.track:Stop(0)
	end
	measure("stopped")
	folder:Destroy()
end)
```

Decision rule: a mode qualifies when its frozen ms/frame is within noise of `stopped` and its frozen shoulder angle equals its "at freeze" angle (pose held, no snap; the camera-facing run confirms it visually). If both qualify, choose (a) `"speed"` (no reparenting). Hand the `[LodPause]` lines and the choice to the implementer; Task 10 records them in the spec. `RigAnimation` recreates the puppet's locomotion animator and re-plays actions on unfreeze, so either mode resumes correctly even if (b) reports the track stopped.

- [ ] **Step 2: Write the failing spec**

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLod.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PuppetLod = require(ReplicatedStorage.Client.Services.CharacterReplicationService.PuppetLod)

local C = PuppetLod.DEFAULT_CONFIG
local SIZE = Vector2.new(800, 600)

return function()
	describe("decide", function()
		it("keeps a near, on-screen puppet full", function()
			expect(PuppetLod.decide("full", 100, true, C)).to.equal("full")
		end)

		it("freezes a puppet that leaves the screen, however near", function()
			expect(PuppetLod.decide("full", 10, false, C)).to.equal("frozen")
		end)

		it("freezes a full puppet only past fullStuds + hysteresis", function()
			expect(PuppetLod.decide("full", C.fullStuds + C.hysteresisStuds, true, C)).to.equal("full")
			expect(PuppetLod.decide("full", C.fullStuds + C.hysteresisStuds + 1, true, C)).to.equal("frozen")
		end)

		it("unfreezes only on screen and within fullStuds", function()
			expect(PuppetLod.decide("frozen", C.fullStuds + 10, true, C)).to.equal("frozen")
			expect(PuppetLod.decide("frozen", C.fullStuds, true, C)).to.equal("full")
			expect(PuppetLod.decide("frozen", 100, false, C)).to.equal("frozen")
		end)

		it("does not flicker for a puppet pacing inside the hysteresis band", function()
			local tier = "full"
			for _, distance in { 240, 255, 270, 255, 240, 270 } do
				tier = PuppetLod.decide(tier, distance, true, C)
				expect(tier).to.equal("full")
			end
			tier = "frozen"
			for _, distance in { 270, 260, 255, 270 } do
				tier = PuppetLod.decide(tier, distance, true, C)
				expect(tier).to.equal("frozen")
			end
		end)
	end)

	describe("isOnScreen", function()
		it("accepts a point inside the viewport", function()
			expect(PuppetLod.isOnScreen(Vector3.new(400, 300, 10), SIZE, 64)).to.equal(true)
		end)

		it("accepts a point just outside the edge, inside the margin", function()
			expect(PuppetLod.isOnScreen(Vector3.new(-50, 300, 10), SIZE, 64)).to.equal(true)
			expect(PuppetLod.isOnScreen(Vector3.new(850, 300, 10), SIZE, 64)).to.equal(true)
		end)

		it("rejects a point beyond the margin", function()
			expect(PuppetLod.isOnScreen(Vector3.new(-70, 300, 10), SIZE, 64)).to.equal(false)
			expect(PuppetLod.isOnScreen(Vector3.new(400, 700, 10), SIZE, 64)).to.equal(false)
		end)

		it("rejects a point behind the camera", function()
			expect(PuppetLod.isOnScreen(Vector3.new(400, 300, -5), SIZE, 64)).to.equal(false)
		end)
	end)

	describe("nextCheckAt", function()
		it("spaces checks at the configured rate", function()
			expect(PuppetLod.nextCheckAt(10, 4)).to.be.near(10.25, 1e-9)
		end)

		it("staggers a first check by its phase", function()
			expect(PuppetLod.nextCheckAt(10, 4, 0.5)).to.be.near(10.125, 1e-9)
		end)
	end)

	it("uses the spec's defaults: full within 250 studs, re-evaluated 4 times a second", function()
		expect(C.fullStuds).to.equal(250)
		expect(C.rateHz).to.equal(4)
		expect(table.isfrozen(C)).to.equal(true)
	end)
end
```

- [ ] **Step 3: Run the tests (controller, Studio) — expect failures**

Expected: `PuppetLod.spec` errors on the missing module.

- [ ] **Step 4: Implement the tiers**

Create `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetLod.luau`:

```luau
--!strict
--[=[
	PuppetLod: which puppets animate (character replication R3 spec, "Puppet animation LOD"). The engine gives
	client-built rigs no animation LOD (measured 2026-10-02: `EvaluationThrottled` never true, a 790-stud
	off-screen rig kept animating, ~0.1 ms per rig per frame), so puppets get their own:

	| Tier | When | Behaviour |
	|---|---|---|
	| full | on screen and within `fullStuds` | animate every frame |
	| frozen | off screen, or beyond `fullStuds + hysteresisStuds` | animation paused, pose held; position still updates |

	A frozen puppet unfreezes only once it is back on screen AND within `fullStuds` (the hysteresis band stops a
	puppet pacing at the edge from flickering). "On screen" is the camera viewport grown by `edgeMarginPx` on
	every side and in front of the camera. Each puppet is re-evaluated `rateHz` times a second, staggered.

	Pure: the shell supplies distances and viewport points.

	@class PuppetLod
]=]

local PuppetLod = {}

export type Tier = "full" | "frozen"

export type Config = {
	fullStuds: number, -- LOD_FULL_STUDS
	hysteresisStuds: number, -- LOD_HYSTERESIS
	rateHz: number, -- LOD_RATE_HZ
	edgeMarginPx: number,
}

local defaultConfig: Config = {
	fullStuds = 250,
	hysteresisStuds = 25,
	rateHz = 4,
	edgeMarginPx = 64,
}
PuppetLod.DEFAULT_CONFIG = table.freeze(defaultConfig)

--[=[
	Whether a point the camera projected to `viewport` (pixels X/Y, depth Z, as WorldToViewportPoint returns)
	is on screen: in front of the camera and inside the viewport grown by `marginPx`.
]=]
function PuppetLod.isOnScreen(viewport: Vector3, viewportSize: Vector2, marginPx: number): boolean
	return viewport.Z > 0
		and viewport.X >= -marginPx
		and viewport.X <= viewportSize.X + marginPx
		and viewport.Y >= -marginPx
		and viewport.Y <= viewportSize.Y + marginPx
end

--[=[
	The tier a puppet moves to from `current`, at `distance` studs from the camera.
]=]
function PuppetLod.decide(current: Tier, distance: number, onScreen: boolean, config: Config): Tier
	if current == "full" then
		if not onScreen or distance > config.fullStuds + config.hysteresisStuds then
			return "frozen"
		end
		return "full"
	end
	if onScreen and distance <= config.fullStuds then
		return "full"
	end
	return "frozen"
end

--[=[
	When a puppet is next evaluated: one period after `now` (seconds). `phase` in [0, 1) staggers a new puppet's
	first check so checks spread across frames.
]=]
function PuppetLod.nextCheckAt(now: number, rateHz: number, phase: number?): number
	local period = 1 / rateHz
	return now + period * (if phase ~= nil then phase else 1)
end

return PuppetLod
```

- [ ] **Step 5: Apply LOD in the shell**

Set `LOD_PAUSE_MODE` to the Step 1 choice (`"speed"` below; write `"detach"` if the measurement chose (b)).

```diff
diff --git a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
index 9b12bad..da1cf5d 100644
--- a/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
+++ b/src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigAnimation.luau
@@ -8,6 +8,11 @@
 	  stride-rate clamp), fed by PuppetLocomotion from the movement state RemoteBodies interpolated for the
 	  frame. The owner's own locomotion stays with LocomotionBinding (Humanoid signals). The
 	  `LocomotionEnabled` kill switch reaches puppets too.
+	- Puppet LOD (PuppetLod): a puppet off screen or far away is FROZEN: its tracks are held (pause mode
+	  "speed": every track at speed 0; "detach": its Animator unparented, chosen by the R3 Task 9
+	  measurement) and its locomotion is not stepped; its position still updates. Unfreezing resumes
+	  locomotion and re-plays running actions at their current point. The Workspace attribute
+	  `PuppetLodEnabled = false` keeps every puppet full (the LOD-off measurement).
 
 	- `start` connects `ActionStarted` / `ActionStopped` (ByteNet listeners cannot be disconnected, so they
 	  route through `active`).
@@ -22,8 +27,8 @@
 	Clocks: the owner plays at the session clock; a puppet at its render time (session clock minus the
 	render delay), so its actions line up with the motion the viewer draws.
 
-	Spec-exempt shell (ByteNet, Instances); the rules live in BodyActions, PuppetLocomotion and
-	LocomotionAnimator.
+	Spec-exempt shell (ByteNet, Instances, the camera); the rules live in BodyActions, PuppetLocomotion,
+	LocomotionAnimator and PuppetLod.
 
 	@class RigAnimation
 ]=]
@@ -41,11 +46,17 @@ local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.Chara
 local LocomotionAnimator = require(ReplicatedStorage.Client.Services.AnimationService.LocomotionAnimator)
 local BodyActions = require(script.Parent.BodyActions)
 local PuppetLocomotion = require(script.Parent.PuppetLocomotion)
+local PuppetLod = require(script.Parent.PuppetLod)
 local PuppetPool = require(script.Parent.PuppetPool)
 local RemoteBodies = require(script.Parent.RemoteBodies)
 
 local DRIFT_SAMPLE_SECONDS = 0.25
 local LOCOMOTION_ENABLED_ATTRIBUTE = "LocomotionEnabled"
+local LOD_ENABLED_ATTRIBUTE = "PuppetLodEnabled"
+-- How a frozen puppet holds its pose, chosen by the R3 Task 9 measurement (Step 1): "speed" = every track
+-- at speed 0 (AnimationPlayer:setPaused); "detach" = the puppet's Animator unparented while frozen.
+local LOD_PAUSE_MODE: "speed" | "detach" = "speed"
+local LOD_CONFIG = PuppetLod.DEFAULT_CONFIG
 
 type PuppetRig = {
 	puppet: PuppetPool.Puppet,
@@ -54,6 +65,8 @@ type PuppetRig = {
 	epoch: number,
 	locomotion: LocomotionAnimator.LocomotionAnimator,
 	tracker: PuppetLocomotion.Tracker,
+	tier: PuppetLod.Tier,
+	nextLodAt: number,
 }
 
 local log = Logger.new("RigAnimation")
@@ -195,10 +208,30 @@ function RigAnimation.attachPuppet(userId: number, slot: number, epoch: number,
 		epoch = epoch,
 		locomotion = newLocomotion(player),
 		tracker = PuppetLocomotion.new(),
+		tier = "full",
+		nextLodAt = PuppetLod.nextCheckAt(os.clock(), LOD_CONFIG.rateHz, math.random()),
 	}
 	BodyActions.attach(actions, userId, epoch, player)
 end
 
+-- Freeze (hold every track, stop stepping locomotion) or unfreeze (resume, re-send the current locomotion
+-- event, re-play running actions at their current point).
+local function setFrozen(userId: number, rig: PuppetRig, frozen: boolean)
+	rig.tier = if frozen then "frozen" else "full"
+	if LOD_PAUSE_MODE == "speed" then
+		rig.player:setPaused(frozen)
+	else
+		rig.puppet.animator.Parent = if frozen then nil else rig.puppet.humanoid
+	end
+	if not frozen then
+		-- A fresh animator re-plays the current pose, whatever the engine did with the held tracks.
+		rig.locomotion:destroy()
+		rig.locomotion = newLocomotion(rig.player)
+		PuppetLocomotion.reset(rig.tracker)
+	end
+	BodyActions.setLive(actions, userId, not frozen)
+end
+
 -- The puppet goes back to the pool: every track on it stops (a pooled puppet shows nothing).
 function RigAnimation.detachPuppet(userId: number)
 	local rig = puppets[userId]
@@ -206,6 +239,9 @@ function RigAnimation.detachPuppet(userId: number)
 		return
 	end
 	puppets[userId] = nil
+	if rig.tier == "frozen" then
+		setFrozen(userId, rig, false) -- a pooled puppet goes back whole: Animator attached, tracks unpaused
+	end
 	rig.locomotion:destroy()
 	rig.player:stopAll(0)
 	BodyActions.detach(actions, userId)
@@ -251,6 +287,25 @@ local function stepLocomotion(rig: PuppetRig, body: RemoteBodies.Body, now: numb
 	rig.locomotion:update(now)
 end
 
+-- Re-evaluates one puppet's LOD tier when its check is due.
+local function updateLod(userId: number, rig: PuppetRig, camera: Camera?, lodOn: boolean, now: number)
+	if now < rig.nextLodAt then
+		return
+	end
+	rig.nextLodAt = PuppetLod.nextCheckAt(now, LOD_CONFIG.rateHz)
+	local tier: PuppetLod.Tier = "full"
+	if lodOn and camera ~= nil then
+		local position = rig.puppet.root.Position
+		local viewport = camera:WorldToViewportPoint(position)
+		local onScreen = PuppetLod.isOnScreen(viewport, camera.ViewportSize, LOD_CONFIG.edgeMarginPx)
+		local distance = (camera.CFrame.Position - position).Magnitude
+		tier = PuppetLod.decide(rig.tier, distance, onScreen, LOD_CONFIG)
+	end
+	if tier ~= rig.tier then
+		setFrozen(userId, rig, tier == "frozen")
+	end
+end
+
 --[=[
 	Once per rendered frame, after puppet placement. `bodies` is RemoteBodies' table (by slot); `placed`
 	marks the slots placed this frame (a puppet whose buffer a respawn just emptied is not).
@@ -260,10 +315,15 @@ function RigAnimation.frame(bodies: { [number]: RemoteBodies.Body }, placed: { [
 		return
 	end
 	local now = os.clock()
-	for _, rig in puppets do
+	local camera = Workspace.CurrentCamera
+	local lodOn = Workspace:GetAttribute(LOD_ENABLED_ATTRIBUTE) ~= false
+	for userId, rig in puppets do
 		local body = bodies[rig.slot]
 		if body ~= nil and placed[rig.slot] then
-			stepLocomotion(rig, body, now)
+			updateLod(userId, rig, camera, lodOn, now)
+			if rig.tier == "full" then
+				stepLocomotion(rig, body, now)
+			end
 		end
 	end
 	BodyActions.step(actions)
@@ -281,14 +341,18 @@ end
 
 function RigAnimation.getState(): { [string]: any }
 	local held, playing = BodyActions.counts(actions)
-	local animated = 0
-	for _ in puppets do
-		animated += 1
+	local full, frozen = 0, 0
+	for _, rig in puppets do
+		if rig.tier == "full" then
+			full += 1
+		else
+			frozen += 1
+		end
 	end
 	return {
 		actionsHeld = held,
 		actionsPlaying = playing,
-		puppetsAnimated = animated,
+		lod = { full = full, frozen = frozen, pauseMode = LOD_PAUSE_MODE },
 		actions = table.clone(actions.counters),
 	}
 end
```

- [ ] **Step 6: Static checks**

Run: `stylua src/ReplicatedStorage/Client/Services/CharacterReplicationService && stylua --check src && selene src`, the typecheck (a file was added), `python scripts/python/check_file_length.py`.
Expected: clean.

- [ ] **Step 7: Run the tests (controller, Studio) — expect all to pass**

- [ ] **Step 8: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService
git commit -m "feat(replication): freeze far and off-screen puppets (animation LOD)"
```

---

### Task 10: Docs, the 59-puppet measurement, and the developer's two-client checklist

**Runtime behaviour: no** (docs and measurements).

**Files:**
- Modify: `docs/animation.md`, `docs/architecture.md`, `docs/ROADMAP.md`
- Modify: `docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md` (record the plan's answers and the measurements)

- [ ] **Step 1: Measure 59 puppets with LOD off and on (controller, Studio)**

The spec asks for the frame cost of 59 puppets with LOD off and on. Studio cannot host 59 players, so this probe builds 59 puppets from the rig template and drives them through the shipped modules (`AnimationPlayerRuntime`, `LocomotionAnimator` with the puppet clamp, `PuppetLod` at 4 Hz, the chosen pause mode), in a ring 20–380 studs around the camera. In a Play session of this build, paste into the **client** command bar; keep the camera still while it runs.

```lua
task.spawn(function()
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
	local LocomotionAnimator = require(ReplicatedStorage.Client.Services.AnimationService.LocomotionAnimator)
	local PuppetLod = require(ReplicatedStorage.Client.Services.CharacterReplicationService.PuppetLod)
	local MODE = "speed" -- RigAnimation's LOD_PAUSE_MODE after Task 9
	local template = ReplicatedStorage:WaitForChild("CharacterRigTemplate")
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local folder = Instance.new("Folder")
	folder.Name = "LodProbe59"
	folder.Parent = workspace
	local rigs = {}
	for i = 1, 59 do
		local model = template:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		humanoid.EvaluateStateMachine = false
		local root = model:FindFirstChild("HumanoidRootPart")
		root.Anchored = true
		local angle = i / 59 * math.pi * 2
		local radius = 20 + (i % 10) * 40
		model:PivotTo(CFrame.new(origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)))
		model.Parent = folder
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local player = AnimationPlayerRuntime.forAnimator(animator)
		local locomotion = LocomotionAnimator.new(player, { minRate = 0.7, maxRate = 1.4 })
		locomotion:handleEvent("running", 12, os.clock())
		rigs[i] = { root = root, humanoid = humanoid, animator = animator, player = player, locomotion = locomotion, tier = "full" }
	end
	local lodOn = false
	local nextCheck = 0
	local connection = RunService.PreRender:Connect(function()
		if not lodOn or os.clock() < nextCheck then
			return
		end
		nextCheck = os.clock() + 1 / PuppetLod.DEFAULT_CONFIG.rateHz
		for _, rig in rigs do
			local position = rig.root.Position
			local onScreen = PuppetLod.isOnScreen(camera:WorldToViewportPoint(position), camera.ViewportSize, PuppetLod.DEFAULT_CONFIG.edgeMarginPx)
			local tier = PuppetLod.decide(rig.tier, (camera.CFrame.Position - position).Magnitude, onScreen, PuppetLod.DEFAULT_CONFIG)
			if tier ~= rig.tier then
				rig.tier = tier
				if MODE == "speed" then
					rig.player:setPaused(tier == "frozen")
				else
					rig.animator.Parent = if tier == "frozen" then nil else rig.humanoid
				end
			end
		end
	end)
	local function measure(label)
		task.wait(2)
		local frames, total = 0, 0
		local sampler = RunService.PreRender:Connect(function(dt)
			frames += 1
			total += dt
		end)
		task.wait(6)
		sampler:Disconnect()
		local frozen = 0
		for _, rig in rigs do
			if rig.tier == "frozen" then
				frozen += 1
			end
		end
		print(string.format("[Lod59] %-8s %.2f ms/frame (%d frames), frozen %d / 59", label, total / frames * 1000, frames, frozen))
	end
	measure("LOD off")
	lodOn = true
	measure("LOD on")
	connection:Disconnect()
	for _, rig in rigs do
		rig.locomotion:destroy()
	end
	folder:Destroy()
end)
```

Hand the two `[Lod59]` lines to the implementer (PC Studio; if the developer can also run it on a phone build, add that line).

- [ ] **Step 2: Update the docs**

````diff
diff --git a/docs/animation.md b/docs/animation.md
index e88129d..1e08008 100644
--- a/docs/animation.md
+++ b/docs/animation.md
@@ -9,23 +9,26 @@ Phase 6 as a NEW system (the old game's animation code was evidence, not source;
 Every animation id lives in **one registry** (`Constants/Animations/`, enforced by CI). Everything
 that plays goes through **one track owner** (`AnimationPlayer` — load once, cache, reuse).
 Character movement animations (idle/walk/run/jump/…) are driven by **`LocomotionAnimator`**, our
-replacement for Roblox's default `Animate` script. The **client that owns a character plays its
-animations**; the server plays NPC rigs and sends typed requests for anything else. What may stop
-what is **declared per animation**, not guessed from names.
+replacement for Roblox's default `Animate` script. **Every client animates the rigs it shows**: its own
+rig from its Humanoid, and every other player's puppet from the movement records it already receives.
+**Server-granted actions** (`AnimationServiceServer:play`) reach the owner and every viewer as timed
+body state and play in sync, with the server's variant and speed. What may stop what is **declared per
+animation**, not guessed from names.
 
 ## Map — where everything lives
 
 | Piece | Path | Job |
 |---|---|---|
-| Registry | `src/ReplicatedStorage/Shared/Modules/Constants/Animations/` | THE home of animation ids. One module per domain (`Locomotion.luau` today; Combat/Emotes/Npc/... arrive with their phases) + `AnimationRegistry.luau` composing them into one lookup, + `AnimationTypes.luau` (types/guards) |
-| Track owner | `Shared/Modules/AnimationPlayer.luau` | The ONLY code that may call `LoadAnimation`. Per-Animator track cache, typed play handles, bookkeeping, class-based stops, `warm()` preloading |
+| Registry | `src/ReplicatedStorage/Shared/Modules/Constants/Animations/` | THE home of animation ids. One module per domain (`Locomotion.luau`, `Actions.luau` (R3 stand-ins); Combat/Emotes/Npc/... arrive with their phases) + `AnimationRegistry.luau` composing them into one lookup (and resolving wire ids), + `AnimationTypes.luau` (types, layers, guards) |
+| Track owner | `Shared/Modules/AnimationPlayer.luau` | The ONLY code that may call `LoadAnimation`. Per-Animator track cache, typed play handles, bookkeeping, class-based stops, `warm()` preloading, a chosen `variant`, a `startAt` seek, `setPaused` (puppet LOD) |
 | Runtime shell | `Shared/Modules/AnimationPlayerRuntime.luau` | Wraps a real `Animator` for the player; memoizes ONE player per Animator so every consumer shares one truth |
 | Locomotion | `Client/Services/AnimationService/LocomotionAnimator.luau` | Pure state→pose core: which pose, fades, speed scaling, jump window, kill switch, pose-override seam |
-| Locomotion binding | `Client/Services/AnimationService/LocomotionBinding.luau` | Thin adapter: Humanoid events → LocomotionAnimator. Bound by `OwnerRig` to the client-built rig (no engine character exists, so no stock Animate script either) |
-| Client service | `Client/Services/AnimationService/AnimationServiceClient.luau` | Local play/stop API + listens for server requests + boot-time preload/dead-id report |
-| Server service | `ServerScriptService/Services/AnimationService/AnimationServiceServer.luau` | Validates + sends requests to owning clients; `playOnRig` for server-owned rigs (NPCs, later) |
-| Packets | `Shared/Events/AnimationEvents.luau` + `Shared/Modules/AnimationRequests.luau` | Server→client requests (discrete events over ByteNet); build/parse contract enforced at the boundary |
-| Debug panel | F4 → **Anims** tab | Live tracks on YOUR character: registry id, domain/class, priority, weight, speed, asset id (click row to expand). Client-only — the server holds no playback state |
+| Locomotion binding | `Client/Services/AnimationService/LocomotionBinding.luau` | Thin adapter: Humanoid events → LocomotionAnimator, plus a Heartbeat `update` (the jump-window fall). Bound by `OwnerRig` to the client-built rig (no engine character exists, so no stock Animate script either) |
+| Client service | `Client/Services/AnimationService/AnimationServiceClient.luau` | Local play/stop API on your own rig + the diagnostic listeners + boot-time preload/dead-id report |
+| Server service | `ServerScriptService/Services/AnimationService/AnimationServiceServer.luau` | **Grants**: `play` / `stop` / `stopAttacks` on a player's body (rules in `ActionGrants`), carried as timed body state by the replication service; `playOnRig` for server-owned rigs (NPCs, later) |
+| Rig animation (client) | `Client/Services/CharacterReplicationService/RigAnimation.luau` | Plays granted actions on the owner rig and every puppet (`BodyActions`), drives each puppet's LocomotionAnimator (`PuppetLocomotion`), and puppet LOD (`PuppetLod`) |
+| Packets | `Shared/Events/CharacterReplicationEvents.luau` (`ActionStarted` / `ActionStopped`) + `Shared/Events/AnimationEvents.luau` (diagnostics) | Typed reliable structs; actions ride the replication service's reliable channel, so a viewer's `Enter` always precedes the actions replayed to it |
+| Debug panel | F4 → **Anims** tab; F4 → **Services** | Anims: live tracks on YOUR character (registry id, domain/class, priority, weight, speed, asset id). Services: `CharacterReplicationServiceClient.animation` (action counters, length mismatches, drift, puppets per LOD tier), `CharacterReplicationServiceServer.bodyStates` and `AnimationServiceServer` (grants) |
 | Admin commands | `animplay` `animstop` `animstopclass` `animtracks` `animreport` | The Cmdr verification harness (see below) |
 
 ## "I want to add an animation" (animators start here)
@@ -47,8 +50,28 @@ myanimation = {
 },
 ```
 
-4. In Studio (Cmdr console, a Play session): `animplay yourname myanimation` to see it,
-   `animreport` to confirm the asset loads. The F4 Anims tab shows it live with all its fields.
+4. In Studio (Cmdr console, a Play session): `animreport` to confirm the asset loads. A replicable
+   action (below) plays on everyone's screen with `animplay yourname myanimation`.
+
+**A replicated action** (something the server grants and everyone sees: attacks, reactions, emotes)
+also declares, in its domain module (see `Actions.luau`):
+
+```luau
+myaction = {
+	assetId = "rbxassetid://N",
+	priority = Enum.AnimationPriority.Action, -- never Core: Core is locomotion's base
+	looped = false,
+	interruption = "attack",
+	replicable = true,
+	wireId = 4,          -- the next unused integer, 1-65535; PERMANENT (never reuse or renumber)
+	layer = "full",      -- full | upper | overlay: the grant slot it occupies
+	durationMs = 900,    -- one-shots only: the clip's length at speed 1, measured in Studio
+},
+```
+
+The registry refuses a replicable entry without a unique `wireId`, a known `layer`, or (for a one-shot)
+`durationMs`, and refuses those fields on a local entry. Measure `durationMs` with the snippet in the R3
+plan (Task 3, Step 1); a wrong value shows up in F4 as a length mismatch.
 
 **Rules the build enforces (you cannot get these wrong silently):**
 - An asset id ANYWHERE outside the registry folder fails CI (the old game had ids in 6+ places;
@@ -66,9 +89,12 @@ game's disease and the CI gate + review will bounce it. Instead:
 - **On the local character (client code):** `AnimationServiceClient:play("id", opts?)` → returns a
   handle (`stop` / `adjustSpeed` / `onMarker` / `isPlaying`). Options: `fadeTime`, `speed`,
   `weight`, `priority` (registry defaults apply otherwise).
-- **From the server, on a player's character:** `AnimationServiceServer:playOnCharacter(player,
-  "id", opts?)` — validated server-side, delivered as a typed packet to the owning client (the
-  network owner plays; that's the authority rule).
+- **From the server, on a player's body (everyone sees it):**
+  `AnimationServiceServer:play(player, "id", { speed?, variant? })` → `(ok, reason?)`. Only replicable
+  entries; the server clamps the speed (0.25-4), picks the variant when you do not, and applies the
+  layer's interruption rule. `stop(player, idOrLayer)` and `stopAttacks(player)` end grants early.
+  Gameplay systems (combat, abilities, emotes) call `play` after their OWN permission and cooldown
+  checks; cooldowns never live on animation definitions.
 - **On a server-owned rig (NPCs/world models):** `AnimationServiceServer:playOnRig(model, "id")`.
 - **On any character/model you hold directly (advanced):**
   `AnimationPlayerRuntime.forCharacter(model)` → the shared per-Animator player.
@@ -89,6 +115,33 @@ Individual `stop("id")` works on anything. Bulk stops act on `attack` only, refu
 else (command, server, and core all enforce it — try `animstopclass yourname protected` to watch
 the refusal).
 
+## Replicated actions
+
+A grant is **timed body state** of kind `"action"` (CharacterReplicationServiceServer), keyed by layer:
+
+- **One grant per layer per body.** A new grant on a layer replaces the old one, unless the old one is
+  `protected` and the new one is not (an attack cannot cut a dodge; a hit reaction can cut an attack).
+- **Everyone plays the same thing.** `ActionStarted` carries the entry's wire id, the server's variant and
+  speed, the server start time and the duration (`durationMs / speed`; none for a looped entry). The owner
+  plays it on its own rig, every viewer on its puppet: one path, no double plays.
+- **Start alignment, no re-sync.** A clip starts `(now − start) × speed` seconds in. The owner's "now" is
+  the session clock; a puppet's is its render time, so the clip lines up with the motion being drawn. A
+  viewer that walks into range mid-action gets the action replayed right after the body's `Enter` and
+  joins at the right point. F4 shows drift as a readout only.
+- **Ending.** An early stop sends `ActionStopped`; a one-shot simply ends; an open-ended grant nobody stops
+  ends at the 30 s safety cap on every screen. Respawn, slot switch and leaving clear grants silently.
+- **Length check.** Each client compares a clip's real length with its `durationMs` once and counts a
+  mismatch (F4, and a log warning naming the entry).
+
+## Puppets: locomotion and LOD
+
+Every puppet runs the owner's code path: an `AnimationPlayer` and a `LocomotionAnimator` per puppet,
+fed by `PuppetLocomotion` from the interpolated movement state (no extra network traffic), with the
+walk/run play rate clamped to 0.7-1.4. **Puppet LOD**: the engine does not throttle client-built rigs,
+so a puppet off screen or beyond 250 studs (back within 250 to unfreeze) is frozen: its pose is held and
+its position keeps updating. Set the Workspace attribute `PuppetLodEnabled = false` to keep every puppet
+animating (measurement). The `LocomotionEnabled` kill switch stops puppet locomotion too.
+
 ## Locomotion (movement animations)
 
 `LocomotionAnimator` decides poses from Humanoid state: idle / walk / run (speed-scaled) / jump
@@ -118,8 +171,8 @@ correct — but a place copy that was never synced will show exactly "all animat
 | Tool | What it answers |
 |---|---|
 | F4 → **Anims** | What is playing on my character right now, at what priority/weight/speed, from which registry entry? Are loads cached (`loads` plateaus, `hits` climbs)? |
-| `animplay` / `animstop` | Does this entry play/stop correctly? (A/B candidate ids live) |
-| `animstopclass` | Do the interruption rules hold? (`protected` must survive an `attack` sweep) |
+| `animplay <player> <id> [speed] [variant]` / `animstop <player> <id or layer>` | Does this action play on every screen, in sync, with the same clip and speed? Does it stop everywhere? |
+| `animstopclass <player> attack` | Do the interruption rules hold? (only `attack` grants end; `protected` and `ambient` are refused) |
 | `animtracks` | Dump my client's live bookkeeping to the client log |
 | `animreport` | Registry census + probe every asset id, dead ones named by registry key |
 | `LocomotionEnabled=false` | Is what I'm seeing ours at all? |
@@ -127,6 +180,8 @@ correct — but a place copy that was never synced will show exactly "all animat
 ## What this system deliberately does NOT do (yet)
 
 Owned by later phases, arriving as new registry domains + consumers of the same primitives:
-emotes (wheel/ownership/gating), combat swings & skill casts, NPC playback (via `playOnRig`),
-parkour poses (Movement, via the pose-override seam), footstep/equipment sounds (Sound phase,
-via the `onMarker` hook on play handles).
+emotes (wheel/ownership/gating), combat swings & skill casts (each calls `AnimationServiceServer:play`
+after its own permission checks; client-requested actions with owner prediction arrive with the first of
+them), NPC playback (via `playOnRig`), parkour poses (Movement, via the pose-override seam),
+footstep/equipment sounds and marker effects on puppets (Sound/VFX phase, via the `onMarker` hook on play
+handles), aim pitch on puppets (Combat), foot locking (later polish).
````

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index d1fe50d..cba9f23 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -295,6 +295,25 @@ slot table, `Spawn` → the owner builds its rig and streams send-on-change samp
 through `RequestHandler`). Every Heartbeat the server relays bodies to the viewers that have them loaded
 (600 studs in, 630 out; reliable `Enter` / `Leave`; unreliable `Downlink` ≤ 700 B per viewer-frame).
 
+**Timed body state (R3).** A timed state on a body that every observer, including a late one, must see
+(an action today; lasting VFX statuses later). A consumer defines its kind once at start,
+`defineBodyState(kind, senders)`, and gets a typed channel (`set(player, key, data, startMs, durationMs?)`,
+`clear`, `get`); the kind brings its own typed reliable packets, the service decides who receives them and
+when (`BodyStates` core, `BodyStateRelay`): Started to the owner and its observers, Stopped only on an
+early stop, a replay right after every `Enter`, silent clearing on respawn, slot switch and leave, at most
+8 states per body per kind, and a 30 s safety cap on open-ended states. Relevance helpers for later
+effects: `observersOf(player)`, `observersNear(position, radius)`, `sendToObservers(player, packet, data)`;
+`nowMs()` is the session clock states are stamped with. Animation is the first consumer: see
+[animation.md](animation.md), "Replicated actions".
+
+| Transport | Shape | Examples |
+|---|---|---|
+| Replication, unreliable records | Continuous, body-tied, nearby only | Position, movement state, ragdoll pose |
+| Replication, reliable timed body state | A timed state on a body that observers (incl. late ones) must see | Actions, lasting VFX statuses |
+| Replication, `sendToObservers` / `observersNear` | One-off, nearby-only events | An explosion at a point, a hit spark |
+| charm-sync | Queryable state | Inventory, stats, cooldown timers, public slice |
+| ByteNet reliable to one player | Outcomes for one player | Purchase result, denial reasons |
+
 **Public data.** What any client may know about another player (R2: health) rides charm-sync as the
 public slice: `PublicPlayerState` on the server, `ClientStore.publicPlayers` on the client, filtered to the
 players relevant to that client (its loaded bodies plus itself). A body whose entry has not arrived yet
```

```diff
diff --git a/docs/ROADMAP.md b/docs/ROADMAP.md
index b677ff6..1d6f8d3 100644
--- a/docs/ROADMAP.md
+++ b/docs/ROADMAP.md
@@ -96,7 +96,7 @@ consumes all of them):**
 | Camera handling | Old game has camera systems (`CameraWrapper` under PlayerModule customizations) |
 | Models/asset registry | Registry-module pattern (like `ItemDefinitions`) for equipment models, customization parts, mutation visuals, skill VFX |
 | Input handling | Old `InputManager`/keymaps tree |
-| **Character replication** | Custom replication with client-only bodies, decided by a spike (`docs/superpowers/specs/2026-09-22-character-replication-design.md`, Verdict 2026-09-30). Phases R1–R7: R1 core library (codec, interpolator, render clock, send policy, harness as acceptance spec) — plan `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md`; R2 bodies on screen (client-only bodies, uplink through RequestHandler, encode-once fan-out, pooled puppets, public slice, lifecycle rewires) — plan `docs/superpowers/plans/2026-10-01-character-replication-r2-bodies-on-screen.md`, stacked with R3–R5 (merged together once R5 is verified); results are compared with the saved scorecard; R3 animation and actions; R4 appearance; R5 chat and voice; R6 player collision; R7 lag compensation (with the combat core). Anti-cheat is its own phase consuming this system's hooks, and must land before cutover. Movement / Traversal builds on R2; Ragdoll (its own system) uses the record's ragdoll variant. |
+| **Character replication** | Custom replication with client-only bodies, decided by a spike (`docs/superpowers/specs/2026-09-22-character-replication-design.md`, Verdict 2026-09-30). Phases R1–R7: R1 core library (codec, interpolator, render clock, send policy, harness as acceptance spec) — plan `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md`; R2 bodies on screen (client-only bodies, uplink through RequestHandler, encode-once fan-out, pooled puppets, public slice, lifecycle rewires) — plan `docs/superpowers/plans/2026-10-01-character-replication-r2-bodies-on-screen.md`, stacked with R3–R5 (merged together once R5 is verified); results are compared with the saved scorecard; R3 animation and actions (puppet locomotion from the movement records, server-granted actions as timed body state with replay on enter, layered grants, puppet animation LOD, the long-fall pose fix) — plan `docs/superpowers/plans/2026-10-02-character-replication-r3-animation.md`; R4 appearance; R5 chat and voice; R6 player collision; R7 lag compensation (with the combat core). Anti-cheat is its own phase consuming this system's hooks, and must land before cutover. Movement / Traversal builds on R2; Ragdoll (its own system) uses the record's ragdoll variant. |
 | **Movement / Traversal** (was missing) | 20-module parkour system — the largest missing item; own phase |
 | **Ragdoll** (was missing) | Discovered 2026-07-17 |
 | **Death handling** (was missing) | Discovered 2026-07-17 |
```

- [ ] **Step 3: Record the plan's answers and the measurements in the spec**

Apply the diff below, then replace each capitalised name with the measured value from the steps named in it: `TESTLEAP_MS`, `TESTLEAP_V1_MS`, `TESTGUARD_MS` (Task 3 Step 1), `MEASURED_LOD_RESULT` (Task 9 Step 1: the chosen mode plus the frozen and stopped ms/frame of both modes), `LOD_OFF_MS`, `LOD_ON_MS` (Step 1 above). If a measurement was not run, write "not measured" and say so in the task report.

```diff
diff --git a/docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md b/docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md
index bed101f..cd0a229 100644
--- a/docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md
+++ b/docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md
@@ -223,8 +223,16 @@ expired / capped.
 | Dropping client-requested actions | R3 never exercises the latency-sensitive path (owner prediction, deny handling) that combat needs most | Keep the stand-in request path | The first ability system needs prediction semantics the grant model cannot support |
 | `wireId` on definitions | Hand-assigned ids are error-prone | Generated from a sorted registry with a CI check | Id collisions or gaps cause bugs in practice |
 
-## Open questions for the plan
-
-- Final layer names and which existing entries are marked replicable for the stand-in tests.
-- Exact Started/Stopped packet layouts per kind (byte counts) and `MAX_BODY_STATES`.
-- `durationMs` values for the stand-in clips (measured from the assets).
+## Settled by the plan (`docs/superpowers/plans/2026-10-02-character-replication-r3-animation.md`)
+
+- Layers `full` / `upper` / `overlay` (wire index 1-3). No locomotion entry is replicable; the stand-ins are a
+  new `Actions` domain reusing locomotion seed assets at Action priority: `testleap` (full, attack, one
+  variant), `testguard` (full, protected), `testpose` (upper, looped, open-ended).
+- Kind "action" packets (typed ByteNet structs): `ActionStarted` = userId f64 · epoch u8 · layer u8 · wireId
+  u16 · variant u8 · speed u16 (thousandths) · startMs u32 · durationMs optional u32 = 20 B (24 B with a
+  duration); `ActionStopped` = userId f64 · epoch u8 · layer u8 · startMs u32 = 14 B. `MAX_BODY_STATES` = 8
+  per body per kind; `MAX_OPEN_STATE_MS` = 30 000.
+- Stand-in `durationMs`: measured in Studio (plan Task 3, Step 1): testleap TESTLEAP_MS (variant 1:
+  TESTLEAP_V1_MS), testguard TESTGUARD_MS.
+- LOD pause mechanism (plan Task 9, Step 1): MEASURED_LOD_RESULT. 59 puppets (plan Task 10): LOD off
+  LOD_OFF_MS ms/frame, LOD on LOD_ON_MS ms/frame.
```

- [ ] **Step 4: Check and commit**

Run: `grep -rn "playOnCharacter\|AnimationRequests\|PlayRequest" docs/animation.md docs/architecture.md` (must print nothing), `python scripts/python/check_pr_rules.py feature/replication-bodies`.

```bash
git add docs/animation.md docs/architecture.md docs/ROADMAP.md docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md
git commit -m "docs(replication): R3 animation and actions, measurements"
```

- [ ] **Step 5: Developer two-client checklist (the merge gate for R3)**

Studio Test → Clients and Servers, 2 players (Player1 acts, Player2 watches; F4 → Services on Player2 shows `CharacterReplicationServiceClient.animation`, on the server `CharacterReplicationServiceServer.bodyStates` and `AnimationServiceServer`). Client command bar snippets move Player1's own rig (the owner simulates its body).

| # | Do | Pass when |
|---|---|---|
| 1 | Player1 walks, then runs (`game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 24` on Player1), jumps, climbs a truss if the place has one | Player2 sees idle / walk / run / jump / climb on the puppet, in step with the motion |
| 2 | Long fall: on Player1, `game.Players.LocalPlayer.Character:PivotTo(CFrame.new(0, 300, 0))` | Both screens show the jump then the fall pose for the whole fall; never a T-pose; idle on landing |
| 3 | `animplay Player1 testleap 1 1`, then `animplay Player1 testleap 0.5` | Same clip (variant 1) at the same moment on both screens; the second at half speed on both |
| 4 | Late viewer: Player2 moves over 630 studs away; `animplay Player1 testleap 0.25` (about 4 s); Player2 comes back within 600 studs during it. Repeat with `animplay Player1 testpose` | Player2's puppet joins the leap mid-way at the right point; the pose is playing on arrival; `joinedLate` ≥ 1, server `bodyStates.action.replayed` ≥ 1 |
| 5 | Two layers: `animplay Player1 testpose`, then `animplay Player1 testleap`; then `animplay Player1 testguard` followed within its length by `animplay Player1 testleap`; then `animplay Player1 testleap` and `animstopclass Player1 attack` | Pose and leap together, pose continues after the leap; the leap during the guard is refused with a reason; the attack sweep ends the leap on both screens |
| 6 | Stop and respawn: `animplay Player1 testpose`, `animstop Player1 upper`; `animplay Player1 testpose` again, then respawn Player1 (fall plane: `game.Players.LocalPlayer.Character:PivotTo(CFrame.new(0, workspace.FallenPartsDestroyHeight - 10, 0))`) | The pose stops on both screens; after the respawn the pose is gone on both and the new body animates normally |
| 7 | Safety cap: `animplay Player1 testpose`, wait 31 s | The pose ends on both screens at 30 s (`capped` +1 on Player2) |
| 8 | LOD: `animplay Player1 testpose`; Player2 turns the camera away from Player1 for 5 s, then back; repeat with `animplay Player1 testleap 0.25` turning away for 5 s | F4 `lod.frozen` 1 while away, `lod.full` 1 after; locomotion and the pose resume at the right point; the leap that ended while frozen does not resume; no visible pop worth a Reduced tier (if there is one, note it: the spec's Reduced tier is then a follow-up) |
| 9 | F4 counters on Player2 after all of the above | `loadFailures` 0, `lengthMismatches` 0 (or exactly 1 for testleap variant 1 if Task 3 recorded differing variant lengths), `maxDriftMs` under 40 |
| 10 | Kill switch on Player2: Workspace attribute `LocomotionEnabled = false`, then `true` | Puppet locomotion stops, then resumes, with no respawn |

Any failure goes back to the owning task before the R2–R5 stack merges.

---

## After R3

R4 (appearance) builds on the same rigs: puppets keep their Animator and `AnimationPlayer` through the pool, so cosmetics mount on rigs that already animate. The first ability, combat or emote system calls `AnimationServiceServer:play` after its own permission checks, and owns client-requested actions and owner prediction (the spec's "Out" table).
