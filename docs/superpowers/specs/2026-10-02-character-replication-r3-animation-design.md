# Design — Character replication R3: animation and actions

**Status:** DRAFT 2026-10-02, for developer review.
**Parent spec:** `docs/superpowers/specs/2026-09-22-character-replication-design.md` (Verdict, §6.8, §7, CP4, CP11).
**Branch:** `feature/replication-animation`, stacked on R2 (`feature/replication-bodies`, PR #29). The stack R2–R5
merges together once R5 is verified.

## Purpose

After R2, other players' bodies move correctly but slide around in a frozen pose. R3 makes them **animate**:

- **Locomotion** (idle, walk, run, jump, fall, climb, swim, seated) on every puppet, derived from the movement
  records R2 already sends — no new network traffic.
- **Actions**: server-granted one-off or looping animations that everyone in range sees, in sync with the body,
  including a viewer who walks into range mid-action.
- **Puppet animation LOD**, because the engine gives client-built rigs none (measured below).

**Success looks like** (developer two-client check): other players walk, run, jump and fall with matching animation,
long falls never T-pose; `animplay` on a player plays in sync on every screen with the same variant and speed; a
viewer entering range mid-action joins at the right point; turning away freezes far/off-screen puppets and they
resume correctly; F4 shows zero load failures and zero length mismatches.

## Scope

**In:** locomotion on puppets; server-requested actions (Cmdr `animplay`, and the entry point combat, abilities,
emotes and NPC-driven player animations will call later); layered grants; a general **timed body state** in the
replication service with relevance helpers; puppet animation LOD; F4 animation counters; the freefall T-pose fix in
`LocomotionAnimator`.

**Out (deferred, with home):**

| Item | Home |
|---|---|
| Client-requested actions (key press → request → permission → grant), owner prediction, cooldown mirror | The first ability / combat / emote system — each owns its permission rules |
| Look-at / aim pitch on puppets (record carries 6-bit pitch; R2 sends 0) | Combat (aim matters there) |
| Animation-marker sound/VFX on puppets (footsteps, whooshes) | Sound / VFX phase — markers fire locally, no network |
| Body-independent effects ("explosion here") | Sound / VFX phase — uses this phase's `observersNear` / `sendToObservers` |
| Continuous action re-sync (re-seek past 40 ms drift) | Only if F4 drift readouts exceed ~40 ms on real actions |
| Foot locking, inertialisation | Movement phase / later animation polish |
| Venture `MovementState` enum on the record (replacing `HumanoidStateType % 32`) | Movement phase (issue #26); `PuppetLocomotion` maps whatever enum the record carries |

## Decisions (developer, 2026-10-02)

1. **Actions are infrastructure plus stand-ins.** No real actions exist yet; R3 proves the pipeline with the
   existing registry entries (e.g. `sprintjump`, a looping pose) through Cmdr.
2. **Architecture: split by job ("D").** Gameplay owners (combat, abilities, emotes, Cmdr) decide *whether* and
   *what*; `AnimationServiceServer` is the single "play on a body" entry and owns **grants**; the replication service
   only carries and syncs. Cooldowns never live on animation definitions.
3. **Delivery: reliable messages, not the record tag.** A grant becomes **timed body state**: a reliable,
   timestamped "started" message to everyone who can see that body (and the owner), a "stopped" message on an early
   stop, and a replay of every active state to a viewer the moment the body enters their range. Movement records stay
   exactly as in R2; the record's 2-byte action extension stays reserved and unused.
4. **Timed body state is general**, owned by `CharacterReplicationServiceServer`, keyed by `(kind, key)`. Actions are
   its first kind (`key` = animation layer). Future kinds (e.g. VFX statuses, `key` = status name) reuse it.
5. **Grants are layered**: one grant per layer per body; a new grant on the same layer replaces the old under the
   existing interruption classes.
6. **Duration is declared, optional, and checked.** `durationMs` on the animation definition; the grant's duration is
   `durationMs / speed`; open-ended actions omit it and run until stopped; a safety cap ends forgotten grants; clients
   warn when a clip's real length disagrees with its declaration.
7. **Speed and variant are chosen by the server** and travel in the grant.
8. **Puppet animation reuses the owner's code path**: one `AnimationPlayer` + one `LocomotionAnimator` per puppet,
   fed by a new pure `PuppetLocomotion` instead of Humanoid signals.
9. **No continuous re-sync**: clips are aligned once at start (`now − startMs`); F4 shows drift as a readout.
10. **Own puppet LOD** (engine LOD measured useless for client rigs), with the pause mechanism chosen by measurement.
11. **Extras in R3:** freefall fix (developer asked to see the exact code change), LOD, F4 counters.

## Architecture

```
Gameplay layer       Cmdr animplay · (later) combat, abilities, emotes        decides WHETHER and WHAT
       │  AnimationServiceServer.play(player, id, {speed?, variant?})
Presentation layer   AnimationServiceServer — grants                           decides HOW it plays
       │  CharacterReplicationServiceServer:setBodyState(player, "action", layer, data, startMs, durationMs?)
Transport layer      CharacterReplicationService — timed body state            decides WHO receives it and WHEN
       │  reliable Started / Stopped to observers (+ owner); replay on Enter
Clients              owner rig and every viewer's puppet play it at (now − startMs)
```

Locomotion bypasses all of this: movement record (R2) → `RemoteBodies` interpolation → `PuppetLocomotion` →
`LocomotionAnimator` → puppet's `AnimationPlayer`.

### Transport choice rule (for this and future phases)

| Transport | Shape | Examples |
|---|---|---|
| Custom replication, unreliable records | Continuous, body-tied, nearby-only | Position, movement state, ragdoll pose |
| Custom replication, reliable timed body state | A timed state on a body that observers (incl. late) must see | Actions, lasting VFX statuses |
| Custom replication, `sendToObservers` / `observersNear` | One-off, nearby-only events | Explosion at a point, a hit spark |
| charm-sync | Queryable state (own data, or relevance-filtered public slice) | Inventory, stats, cooldown timers, equipped title |
| ByteNet reliable to one player | Outcomes for one player | Purchase result, denial reasons |

*What it looks like* rides replication; *what it means* (damage, items) is a reliable, server-decided outcome owned by
the gameplay system.

## Server

### `CharacterReplicationServiceServer` additions

- `setBodyState(player, kind, key, data, startMs, durationMs?)` / `clearBodyState(player, kind, key)`.
  - One active state per `(kind, key)`; at most `MAX_BODY_STATES` (config, e.g. 8) per body.
  - Each kind registers once at init with its own typed reliable ByteNet struct packets for Started / Stopped
    (strict types, no `ByteNet.unknown`).
  - Started goes to `observersOf(player)` plus the owner; Stopped likewise, only for an early stop (a state that runs
    out its duration needs no message — every receiver knows the duration).
  - **Replay on Enter:** after the reliable `Enter` for a body, every active state on it is sent to that viewer with
    its original `startMs`. Reliable ordering on one channel guarantees Enter precedes it.
  - **Automatic clearing** on death, respawn (epoch bump), slot switch and leave; expired durations are cleared
    lazily when touched (no per-state timers).
  - Safety cap: a state with no duration expires after `MAX_OPEN_STATE_MS` (config, e.g. 30 000) with a warning.
- `observersOf(player) -> { Player }`, `observersNear(position, radius) -> { Player }`,
  `sendToObservers(player, packet, data)` — read the R2 relevant set; reusable by future phases.
- Pure core: a new `BodyStates` module (spec-first) owns the per-body table, replace/expiry/cap rules and the replay
  list; the service shell wires packets and lifecycle.

### `AnimationServiceServer`

- `play(player, id, options?: { speed: number?, variant: number? }) -> (boolean, string?)`:
  validate id (registry, and that it is marked replicable — see Registry), clamp speed to a sane range, pick the
  variant server-side when not given, compute `durationMs = def.durationMs / speed` (nil for open-ended), apply the
  layer's interruption rule against the current grant, then `setBodyState(player, "action", def.layer, …)`.
- `stop(player, idOrLayer)` and the existing bulk attack stop → `clearBodyState`.
- **Replaces** today's owner-only `PlayRequest` / `StopRequest` path: the owner receives the same Started message as
  viewers and plays it on its own rig — one path, no double plays.
- `playOnRig` (server-owned NPC rigs) unchanged.
- Cmdr `animplay` / `animstop` route through `play` / `stop`.

### Registry (`Shared/Modules/Constants/Animations/`, `AnimationTypes`)

`AnimationDef` gains:

- `wireId: number` — a stable small integer per replicable definition (never reused), so adding an animation never
  renumbers others. Uniqueness asserted by the registry spec.
- `layer: string` — one of a fixed set (`"full"`, `"upper"`, `"overlay"`; final names in the plan).
- `durationMs: number?` — the base clip length; omitted for looped / open-ended definitions.
- `replicable: boolean?` — only replicable definitions can be granted (locomotion entries stay ambient and local).

## Viewer and owner client

- **`PuppetLocomotion`** (new, pure, spec-first): per visible puppet per frame, map interpolated `state`, speed and
  `grounded` to `LocomotionAnimator` events (running at speed, jumping, freefall, landed, climbing, swimming, seated);
  emit only on change (pose change, or speed change beyond a play-rate threshold). Play rate = speed / clip stride
  speed, clamped 0.7–1.4 (§6.8).
- **Per puppet:** on acquire from the pool, an `AnimationPlayer` (via `AnimationPlayerRuntime`) and a
  `LocomotionAnimator`; on release, stop all tracks and reset both.
- **Body state receiver:** Started → `AnimationPlayer:play(id, { variant, speed, startAt = now − startMs })` on the
  puppet (or the owner's rig); Stopped → stop that layer; a state that arrives before its puppet is built waits and
  applies on acquire; a state past its duration is ignored.
- **`AnimationPlayer` additions:** `play` accepts `variant` (instead of a random roll), `speed` and `startAt`; the
  animator seam gains time position and length. The length check compares real length to `durationMs` on first load
  and warns (Output + F4).
- **Frame order:** animation events are issued in the same `PreRender` pass that writes puppet placement (R2), so pose
  and position come from the same interpolated moment; the engine evaluates animation afterwards.
- **Freefall fix** in `LocomotionAnimator`: a `freefall` event inside the jump window is remembered and applied when
  the window ends, so a fall longer than the 1.2 s jump clip plays the fall pose instead of nothing. The exact
  before/after code is shown to the developer during implementation review.

## Puppet animation LOD

**Measured 2026-10-02** (replication spike place, play session, 40 client-built rigs playing a looping walk at
10–790 studs): `Animator.PreferLodEnabled` exists and defaults on, but `EvaluationThrottled` was never true at any
distance, setting on or off, on or off screen; a 790-stud off-screen rig kept animating. Cost with the camera facing
away: 26.5 ms/frame playing vs 22.3 ms stopped ≈ **0.1 ms per rig per frame** (PC, Studio, noisy) — about 6 ms at 59
puppets. The parent spec's assumption (no engine LOD for client rigs) holds.

| Tier | When | Behaviour |
|---|---|---|
| Full | On screen and ≤ `LOD_FULL_STUDS` (config, ~250) | Animate every frame |
| Frozen | Off screen, or beyond `LOD_FULL_STUDS + LOD_HYSTERESIS` | Animation paused, pose held; position still updates (R2) |
| Reduced (optional) | Only if measurement shows Full→Frozen pops visibly | Lower update rate |

- On-screen test: a cheap camera test per puppet, re-evaluated `LOD_RATE_HZ` (config, ~4) times a second, with
  distance hysteresis and a screen-edge margin.
- Unfreezing resumes locomotion and resumes an in-progress action at `now − startMs`.
- Pooled hidden puppets: all tracks stopped.
- **Pause mechanism: "detach"** (measured 2026-10-02, 40 client rigs, animation step PreAnimation to PreSimulation,
  median): playing 0.331 ms; track speed 0 = 0.325 ms (no saving); Animator detached = 0.214 ms (equal to all
  tracks stopped, 0.220 ms). Both modes held the pose with no snap. Detaching the puppet's Animator is the shipped
  mode.
- **Thresholds as shipped:** frozen when off screen or beyond 275 studs; unfreezes within 250 (25-stud hysteresis).
- **59 puppets, LOD off / on** (measured 2026-10-02 in Studio on PC, client play session, still camera. The rigs run
  locomotion at radii of 20–380 studs around the camera. The animation step is timed from PreAnimation to
  PreSimulation over 6 s per phase):

  | Phase | Frozen | Step median | Step p90 |
  |---|---|---|---|
  | LOD off | 0 / 59 | 0.543 ms | 1.220 ms |
  | LOD on | 48 / 59 | 0.406 ms | 0.653 ms |
  | LOD off again | 0 / 59 | 0.488 ms | 0.903 ms |

  Freezing 48 rigs cuts the step median by about 0.1 ms (20–25%) and roughly halves the p90 spikes. The 11 on-screen
  rigs within 250 studs still animate. Studio frame times (19–26 ms) were noisy and are not used. Phone numbers come
  with the mobile pass.

## F4 (debugger) additions

Viewer: actions started / stopped / replayed-on-enter / pending-puppet; clip load failures; length mismatches; action
drift (max, readout only); puppets per LOD tier. Server: active body states per kind; grants created / replaced /
expired / capped.

## Testing

- **Specs (TestEZ, Studio):** `PuppetLocomotion`; `LocomotionAnimator` freefall fix; `BodyStates` (set, replace, multi-key,
  clear, lazy expiry, cap, replay list, lifecycle clears); `AnimationServiceServer` grants (unknown id, non-replicable id,
  server variant, duration from length and speed, open-ended, interruption per layer, Cmdr routing); `AnimationPlayer`
  (variant, speed, `startAt`, seam length); LOD tier decisions with hysteresis; registry `wireId` uniqueness. Existing
  suites stay green (R1/R2 harness numbers unchanged).
- **Measurements:** the LOD pause mechanism; frame cost of 59 puppets with LOD off/on.
- **Developer two-client checklist:** locomotion incl. a long fall; `animplay` sync with variant and speed; late
  viewer joins mid-action at the right point; two layers at once; stop and respawn mid-action; LOD freeze/resume with
  F4 tier counts; F4 counters (zero load failures, zero mismatches, small drift).

## Changes from the spike (CP4, CP11)

| Spike | R3 | Why |
|---|---|---|
| Owner key press → ActionRequest → grant/deny, owner cooldown mirror | Removed; server-requested actions only | No real player-triggered actions yet; permission belongs to future ability/combat/emote systems |
| Action on the record's 2-byte tag, relayed from the grant | Reliable Started/Stopped to observers + replay on Enter; records untouched | The downlink has no acknowledgements; a tag-only start could be lost |
| Grant ended by a blanket 4 s timeout | Declared `durationMs` (optional), safety cap, length check | The timeout cut long clips and kept short ones alive |
| Clips loaded directly on the puppet Animator | Through `AnimationPlayer` | One code path for owner and puppets |
| Re-seek past 40 ms drift | Dropped; drift readout in F4 | Start alignment suffices; re-add on evidence |
| Owner rolled its own variant (mismatch seen) | Server picks; everyone plays it | Same swing for everyone |
| Viewers played at speed 1 | Speed travels in the grant | Speed-modified actions match |
| CP4: every puppet animated every frame | LOD tiers | No engine LOD; ~0.1 ms per rig measured |
| CP4: puppet locomotion via `LocomotionAnimator` | Same, plus the freefall fix | — |

## Critique (every decision, harshly)

| Decision | Weakness | Strongest alternative | Reverse if |
|---|---|---|---|
| D: split by job | Two services and an interface for what is, today, "play an animation"; the permission layer is empty in R3, so the split is untested by a real consumer | B (AnimationService owns cooldowns too) — fewer pieces now | The first real ability system finds calling `AnimationServiceServer.play` awkward or needs data the grant cannot carry |
| Reliable timed body state instead of the record tag | Reliable ByteNet shares one ordered channel: a lost packet stalls everything behind it (head-of-line), delaying starts on lossy links; actions now arrive on a different path from the body they belong to | Record tag + forced resends; or acknowledgements on the downlink | Measured start delay on the lossy profile becomes visible (clips regularly start noticeably mid-way) |
| General `(kind, key)` body state | Built for one consumer; generality may be wrong for VFX (statuses may prefer charm-sync's public slice, which already gives late arrivals for free) | Action-specific state inside AnimationService; statuses on the public slice | The VFX phase finds the public slice fits statuses better — then this stays action-only |
| Layered grants | Layer names are a guess with no real actions to validate them; wrong layers mean a registry migration | Single active action per body | Real combat/emote clips need a layering the fixed set cannot express |
| Declared `durationMs` | Manual data that can rot; every new clip needs a measured length | Clients report real length at first load and the server learns it | Length mismatches show up in F4 in practice |
| No continuous re-sync | Long looping actions can drift after big render-delay jumps | Keep the 40 ms re-seek | F4 drift exceeds ~40 ms on real actions |
| Reuse `AnimationPlayer` + `LocomotionAnimator` on puppets | The Animator is the expensive part (~0.1 ms/rig); reuse does not reduce it | Custom joint-writing animation runtime | LOD cannot keep 59 puppets within budget on phones |
| Own LOD, frozen tier | Frozen far puppets glide in a held pose; on open maps with long sightlines that may look wrong | Reduced-rate tier always on | Developer sees it in the two-client or published test |
| Dropping client-requested actions | R3 never exercises the latency-sensitive path (owner prediction, deny handling) that combat needs most | Keep the stand-in request path | The first ability system needs prediction semantics the grant model cannot support |
| `wireId` on definitions | Hand-assigned ids are error-prone | Generated from a sorted registry with a CI check | Id collisions or gaps cause bugs in practice |

## Settled by the plan (`docs/superpowers/plans/2026-10-02-character-replication-r3-animation.md`)

- Layers `full` / `upper` / `overlay` (wire index 1-3). No locomotion entry is replicable; the stand-ins are a
  new `Actions` domain reusing locomotion seed assets at Action priority: `testleap` (full, attack, one
  variant), `testguard` (full, protected), `testpose` (upper, looped, open-ended).
- Kind "action" packets (typed ByteNet structs): `ActionStarted` = userId f64 · epoch u8 · layer u8 · wireId
  u16 · variant u8 · speed u16 (thousandths) · startMs u32 · durationMs optional u32 = 20 B (24 B with a
  duration); `ActionStopped` = userId f64 · epoch u8 · layer u8 · startMs u32 = 14 B. `MAX_BODY_STATES` = 8
  per body per kind; `MAX_OPEN_STATE_MS` = 30 000.
- Stand-in `durationMs` (measured in Studio, plan Task 3, Step 1): testleap 1200 ms (both variants), testguard
  1433 ms.
- LOD thresholds, pause mechanism ("detach") and measurements: see "Puppet animation LOD" above.

## Plan-time corrections (2026-10-02, approved with the plan)

The implementation plan (`docs/superpowers/plans/2026-10-02-character-replication-r3-animation.md`) corrected this
spec where the code made the original wording wrong. These supersede the sections above:

1. **Typed body-state channels.** `setBodyState(player, kind, key, …)` with a string kind cannot be strictly typed per
   kind without `any` or casts. Instead `defineBodyState(kind, senders)` returns a typed `Channel<D>` with `set` /
   `clear` / `get`; the 8-state cap is per body per kind.
2. **Puppets align actions to their render time**, not the raw session clock: `now − startMs` taken literally would
   play a puppet's clip one render delay ahead of where its body is drawn. The owner's own rig uses the session clock.
3. **No death hook in R3** — there is no server death or ragdoll event yet. Clearing covers respawn, slot switch and
   leave. **Hard requirement for the Death and Ragdoll phases:** refuse grants on a dead or ragdolled body and clear its
   active grants (R3 exposes a clear-all call for this).
4. **The owner learns its epoch from its own slot-table row**, not from `Spawn`, which can lag the epoch bump by up to
   5 s while the server streams around the spawn point; grants in that gap would otherwise be discarded as stale.
5. **Grants carry no cooldown or legality checks** beyond "the body is alive": permission and cooldowns belong to the
   calling gameplay system (decision 2). The spike's fixed 300 ms cooldown and dead/ragdoll refusal are not carried.
6. **Deferred, added:** richer locomotion (directional walk blending, torso lean, turn-in-place) — animation content
   and polish for the Movement phase or later; R3 keeps the owner's existing `LocomotionAnimator`.
7. **Requirement for the first ability system (owner prediction):** the presser's own body must not wait a round trip.
   The client plays the action immediately and sends its press time; the server grants with that press time as
   `startMs` (bounded, e.g. ≤ 150 ms back) so viewers align with the presser; the owner's receiver must recognise its
   own predicted action in the returning Started and not restart it, and stop it on a denial. R3's grant `startMs` and
   start-time playback are the foundation; the prediction and the "don't replay my own" check are not built in R3.
