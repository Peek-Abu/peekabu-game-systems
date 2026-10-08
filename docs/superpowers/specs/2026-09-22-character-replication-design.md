# Design — Custom character replication

**Status:** DECIDED 2026-09-30 (see Verdict) · v2 draft 2026-09-22 — revised after a five-reviewer read-only review (engine, netcode math,
repo fit, exploit red team, cold read). · **Date:** 2026-09-22 · **Phase:** pre-Movement spike (branch
`claude/peaceful-bardeen-wcqxpr`). Brief: the "Custom character replication" section of
`docs/superpowers/handoffs/2026-09-22-replication-debugger-backport-handoff.md`.

## Verdict (2026-09-30)

**Build it: custom character replication with client-only bodies (option A), to the "v3" design.** The spike
(branch `spike/character-replication`, frozen as reference, never merged) answered every open question, and a
harness comparison of several replication techniques, including our own first design (v2), chose v3.

**Evidence** (appendix, last sections):

- Option A holds (CP1–CP3). Voice uses the client-wired route (CP3). No engine character exists at any point.
- Against the strongest alternative technique tried (positions on a reliable ordered stream with spline playout), both Venture designs win every
  measured column on every network. At 75 ms / 3 % loss over eight runs: the alternative 460 pops and 2,947
  freezes, Venture none; mean error 0.03 studs against 1.04; downlink 830 B/s against 2,988; encode 1.30 µs
  against 2.70, decode 1.13 against 3.02, render step 0.29 against 0.45.
- v3 over v2: resending the last changed record twice, 50 ms apart, removes a failure where a body stayed up to
  97 studs off for a second (1 in 32 mobile runs, v2; 0 in 32, v3). Send-on-change uplink cuts owner packets
  and server movement checks by 15 % (moving) to 74 % (AFK) for about 0.02 studs of typical error on mobile.
- Server movement check: 18–20 µs per record with real casts; at 60 players about 1.1 ms of every server frame
  for v2, 0.3–0.9 ms for v3.

**Decisions closed by the spike:** O1 → option A. O2 → client-wired voice. O3 → the per-viewer budget stays at the
24 KB/s default with the 700 B hard cap per viewer-frame (CP0 real network passed; no measurement argued for a
different number). C6 stands: phase-1 visibility is distance-only. The appendix's "occlusion in phase 1" is
withdrawn (developer decision, 2026-09-30): occlusion's value is anti-wallhack, so it moves to the anti-cheat
phase as "do not send hidden enemies in PvP arenas", with a corner margin.

**Found by the developer runs after the A/B, required in the real build:**

- A local stall (window in the background, a long frame) must not raise the render delay: batches processed
  right after one feed the buffer but not the lateness statistics (tab-out froze every puppet for ~4 s).
- The render delay must never exceed what the sample buffer holds.
- A real network stall (both machines healthy, packets ~1 s late in both directions) is external and must only
  be recovered from well. The uplink flood limit must pace by the owner's sample timestamps, not arrival time:
  a released backlog was dropped as Flood, then flagged as Speed, and the honest owner was corrected 7 times.
- Puppets cost 25–50 ms to build and 10–30 ms to unparent or reparent (the rig has ~109 parts): bodies are
  pooled, and hidden by moving them away, never by unparenting. Accessories bind with a RigidConstraint per
  piece (same per-frame cost as the engine's Weld, 0.5–0.8 µs a piece); a dressed-body cache per outfit copies
  in 0.2–1.3 ms against 3–5 ms to dress from scratch.

**Build phases** (one implementation plan each, written when the phase before it lands):

| Phase | Scope |
|---|---|
| R1 — core library | Pure, spec-first shared modules: record codec, interpolator with dead reckoning, render clock (delay controller), send policy; the harness as an acceptance spec. Plan: `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md` |
| R2 — bodies on screen | `CharacterReplicationService` server + client: slot table, owner rig, uplink/ingest with basic validation, scheduler (encode once, 700 B cap), distance visibility, puppet pool, `CharacterAutoLoads = false`, `SlotService` without `LoadCharacter`, rewiring Stats, Animate/Locomotion, Admin, TuneOffset, Debugger |
| R3 — animation and actions | Locomotion from the record, server-granted actions with elapsed-time seek, variants, puppet animation LOD. Design: `docs/superpowers/specs/2026-10-02-character-replication-r3-animation-design.md` (client-requested actions and the owner cooldown mirror move to the first ability system) |
| R4 — appearance | Client-side `CustomizationApplication` in Shared with explicit RigidConstraint binding, outfit cache, appearance on the slot table |
| R5 — chat and voice | Bubble chat and spatial voice on client-built bodies (§5.1, §5.1.3, C4): chat bubbles and the voice emitter attach to the puppet head; voice is verified in a published experience |
| R6 — player collision | Capsule blockers welded into puppets, solid within 20 studs, slide-off; the server registers the groups and the shared size table is the anti-cheat contract (R6 spec 2026-10-08, decision 3) |
| R7 — lag compensation | History ring, sent-seq brackets, rewind; lands with the combat core (last, per the roadmap) |

**Anti-cheat is its own roadmap phase** (developer, 2026-09-30), not a replication step: it ports the old game's anti-cheat, adds new checks, and consumes hooks this system exposes (`MovementRules` full envelope with Venture `MovementState`, motion grants such as wall-hop, `AntiCheatServiceServer` policy, PvP occlusion). R2 keeps basic ingest validation and the timestamp-paced flood limit. Anti-cheat must land before the live cutover.

**Decided for the R2 plan (developer, 2026-09-30):**

- **One body API.** Systems never read `player.Character` for another player's body: the replication service
  exposes `bodySpawned` / `bodyDespawned` and a rig lookup, documented once in `docs/architecture.md`.
- **Other players' public data rides charm-sync**, not a custom packet: a public slice (a map of userId →
  public fields such as appearance and equipped title; never private data) whose per-player getter returns
  what that viewer may see. Titles need the same thing for nameplates. Built properly, relevance included:
  the getter filters by the replication service's per-viewer relevant set, held as an atom that changes only
  on enter/leave (600/630 studs), so movement never re-runs it. Deltas still ship on charm-sync's normal
  Heartbeat flush; a player entering range gets their entry on the next flush. A body whose entry has not
  arrived yet renders with the default look.
- **Uplink goes through an extended `RequestHandler.wrap`** (developer, 2026-10-01). The limiter becomes a
  token bucket for every caller (`maxRequests` = bucket size, refill `maxRequests / windowSeconds` per second;
  existing configs keep their fields), constant time and allocation-free. New optional fields: `clock` (seconds the
  bucket refills by; the uplink uses a full u32 send time written at the start of each uplink packet, clamped to
  server session time + 64 ms and never moving backwards), a third `validate` return passed to `handler` as a third
  argument (decode once), and `onReject = "count"` (count drops for the Debugger instead of a warn each). `xpcall`
  receives the handler and its arguments directly, with no closure per call. With the send-time clock the uplink
  bucket can be small (about 10), because a backlog after a freeze pays for itself.
- **Stacked R2–R5, no feature flag** (developer, 2026-10-01): R2 renders other players in the default look,
  without animation, chat bubbles or voice; R3–R5 close that gap, and the stack merges once R5 is verified.
- **Downlink scheduling is a priority accumulator** (developer, 2026-10-01), not rotation and not §6.4's full
  error prediction: each frame every due body's score grows by a closeness weight, the highest scores fill the
  700 B batch, and a sent body's score resets, so near bodies go first in crowds and far bodies still climb
  until sent. A gentle far cap (beyond 300 studs, at most one record per 33 ms, i.e. 30 Hz) saves download
  even with room to spare; 30 Hz is the floor the single render delay covers. All numbers are config, measured
  in R2's last task.
- **Blind review** (developer, 2026-10-01): once the stack is complete (after R5), and again after the anti-cheat
  phase lands occlusion, an independent reviewer scores this system against the alternatives tried, both
  anonymised, on measured numbers and a fixed rubric. Results stay outside the repository.
- **Measure the integrated build** at the end of R2: the harness profiles against the saved v2/v3 results, plus
  server µs per uplink packet through `RequestHandler`, garbage per second, and a two-client Studio run.
- Separately tracked: typing the older `ByteNet.unknown` payloads (issue #27).

**R2 must carry (from the R1 final review):**

- epoch reset through the reliable slot table (the interpolator drops any epoch other than current + 1, so a lost bump needs it);
- owner-time alias detection at ingest (a sample ≥ 960 ms old unwraps into the future; e.g. unwrap against the last accepted owner time and drop "ahead" samples that arrive after a ~900 ms receive gap);
- `isNew` derived from what `push` actually did (accepted / flushed / dropped), not recomputed;
- repair restamp semantics for a body still for over 1 s (downlink age clamps at 1023 ms);
- what `starving` means (hold only, or hold + behind — "behind" is not lateness) and make the docs agree;
- loss counting under true reorder (arrivals 5, 7, 6, 8): DECIDED in R2 — reorder counts toward the delay margin like loss, by design (a gap filled late is still a late batch). A "takeback" was tried and measured on the mobile profile: mean error 0.175 and a freeze, against 0.104 and none without it;
- decode-side checks: exact size before decoding, batch `count` against buffer length, action index against the registry, and reject state 29 (ragdoll) on the uplink (ragdoll is server-granted).

Ragdoll is not a replication phase. It is its own system on the roadmap (presentation track, "Ragdoll (was
missing)"). Replication already carries it: R1's record has the ragdoll variant (a rotation instead of
velocity), and the server-granted ragdoll proven in CP6 lands with that system, on top of R2.

## Decisions

### Closed

| # | Decision | Why |
|---|---|---|
| C1 | **Body strategy: client-only body (option A).** The Camera trick (B′) is the fallback only. | §5 |
| C2 | **Server Authority rejected.** | It is not custom replication, and its blast radius is game-wide (§5.6) |
| C3 | **Chickynoid, native (±augment), and "anchored replicated + local clone" rejected.** | §5.3–5.5 |
| C4 | **Spatial voice chat is required.** It is on in the live game. | §5.1.3 |
| C5 | **Movement enforcement and anti-cheat judgement are separate** (`MovementRules` / replication ingest / `AntiCheatServiceServer`). | §7 |
| C6 | **Visibility in phase 1 is distance-only**, with no occlusion. | Third-person game: the camera sees over walls anyway (§6.5) |
| C7 | **Motion rides ByteNet**, as a typed **unreliable** packet. `docs/architecture.md`'s rule of thumb gets one amendment (§6.1). | Charm-sync is reliable, diffs every frame, and is not per-viewer |
| C8 | **Player-count target: as many as possible.** The design is sized for 60 (`MaxPlayers`). | |

### Open, decided by the checkpoints in §11

- **O1** — A holds, or fall back to B′ (checkpoints CP1–CP3).
- **O2** — Voice route: client-wired, or server speaker part (CP3).
- **O3** — Final per-viewer budget, set from measured mobile throughput (CP0).

### Deferred to the Movement phase

- **D1** — Each parkour system gets its own constraints instead of sharing the HRP `AlignOrientation`.
  Default: yes.

---

## Glossary

| Term | Meaning |
|---|---|
| **Body** | A player's physical presence in the world. Under A there is no server body, only a validated history. |
| **Rig** | A clone of `StarterCharacter`. |
| **Owner rig** | The rig a client builds for itself and simulates with a normal Humanoid. `LocalPlayer.Character` points at it. |
| **Puppet** | The rig a client builds for *another* player. It is anchored, runs no Humanoid physics, and is moved by the interpolator. |
| **Sample** | One snapshot of a body: position, velocity, yaw, pitch, state, and time. |
| **Record** | A sample encoded for the wire (16 B). |
| **History** | The server's 1 s ring of accepted samples per player. It is the source of truth for hits and interactions. |
| **Visibility set** | Which bodies a viewer has loaded. It doubles as the anti-ESP rule and the damage whitelist. |
| **Epoch** | A server-owned counter bumped on respawn or teleport. It tells receivers "don't interpolate across this jump". |

## Data flow

```
 OWNER CLIENT                         SERVER                                   VIEWER CLIENT
 ────────────                         ──────                                   ─────────────
 owner rig (native Humanoid)
   │ sample per Heartbeat
   ▼
 codec → uplink ──unreliable──►  decode → MovementRules (enforce) ──► history ring
 (current + 2 redundant)                  │ violations                 │
                                          ▼                            ▼
                                  AntiCheatService (judge)     scheduler per viewer
                                                               (visibility set,
                                                                error-driven priority,
                                                                700 B/frame budget)
                                                                       │
                                                  ──unreliable──►  decode → buffer → interpolator
                                                                   (render clock, Hermite)
                                                                       │
                                                                       ▼
                                                               puppet (BulkMoveTo, pose driver)
 shot/melee ──reliable──► lag comp: rewind the target on exactly the samples that viewer rendered
```

---

## Purpose

Movement authority sits under every physical system still on the roadmap: Movement/Traversal, Camera,
Ragdoll, Death, Spectating, Mounts, and combat hit detection. This spec chooses that authority and its
transport **before** the parkour port.

The developer's bar: our replication and rendering must be **clearly better than the common
Camera-trick / anchored-puppet baseline (§1) in every dimension**. That means bytes, latency, smoothness,
animation timing, anti-cheat, and maintenance tail.

Sources:

- **Old Venture** (`VentureTestingPlace`), read-only.
- **Engine docs**: `Roblox/creator-docs` source and staff DevForum posts.
- **Community libraries**: Chrono, BetterReplication, and Chickynoid, read from source.
- **Netcode literature**: Gaffer on Games, industry netcode write-ups, and GDC summaries.
- **This repo**: `main` @ `d973c80`.

Venture's implementation is written fresh on this base.

### Direct answers

- **Is there a property that lets a game take over character replication?** **No.** We swept Workspace,
  Players, Player, StarterPlayer, Humanoid, BasePart, Model, RunService, Camera, Animator, and
  UnreliableRemoteEvent:
  - `ReplicationFocus`, `ModelStreamingMode`, and `AddPersistentPlayer` only control what a *viewer*
    streams in.
  - `ImprovedPhysicsReplication` has no knobs.
  - The only authority switch is `AuthorityMode = Server`.
- **Is Server Authority custom replication?** **No.** It is engine-managed replication under a different
  authority model. It has no per-viewer tiers, no interpolation control, and no visibility set.

---

## 1. The baseline: Camera trick plus anchored puppets

The most common custom-replication technique in the Roblox community (Chrono uses it) works like this:

- **Server:** a per-character `Camera` holds an **anchored** part jointed to the HumanoidRootPart.
  - Anchoring makes that part the assembly root.
  - Camera descendants don't replicate, so clients never receive the root, and Roblox stops streaming the
    character's transform.
  - The Model itself still replicates.
- **Owner:** sends its position to the server.
- **Server:** clamps the position, writes it to the hidden root, and relays it.
- **Receiving clients:** anchor the remote root and CFrame-drive it.

A **typical baseline implementation** looks like this:

| Direction | Content | Rate | Size | Channel |
|---|---|---|---|---|
| Owner → server | position + yaw | 60 Hz | ≈ 15 B | reliable |
| Server → viewer | untyped position records | fixed distance bands | tens of bytes per record | reliable |
| Owner → server → others | movement-intent attributes (Running, Sliding, Airborne, …) | on change | | relayed |

It also typically has:

- **server validation:** clamp-and-flag;
- **visibility:** server-computed per viewer (distance plus occlusion), doubling as the damage whitelist;
- **receivers:** a short buffer, uniform Catmull-Rom about 2 intervals behind, and animation derived from
  position deltas plus relayed attributes.

**The one idea we keep:** a server-computed per-viewer loaded set that doubles as the **damage whitelist**.

### 1.1 Known failure modes of the anchored-puppet model

| Symptom | Cause |
|---|---|
| Remote Humanoids stuck in Freefall | an anchored Humanoid never resolves contact, so intent attributes are needed to fake "grounded" |
| `FloorMaterial` = Air on the server | the server copy is welded to an anchored part |
| Server velocity writes erased | the assembly is anchored, so knockback and ragdoll need special release paths |
| A weld armed mid-air never lands | the hidden root is snapshotted at arming |
| The owner loses ownership of its own body | `SetNetworkOwner` fails on anything welded to an anchored part |
| Ghost animation tracks after reparenting | the engine re-applies a stale replicated snapshot |
| Players trap each other | remote bodies are anchored static colliders |
| Attribute echo loops | server attribute writes replicate back to the owner |
| Head-of-line bursts | a reliable channel carries a position stream |

**Does the trick still work?** Community libraries built on it were still being updated in September 2026,
after the June 2026 physics-replication re-plumb. We have not tested it ourselves; that is B′'s job (§5.2).

---

## 2. Old Venture: what exists today

From `VentureTestingPlace`, read-only.

**Movement:**

- Parkour is client-side on the stock Humanoid.
- Slide, sprint-jump, vault, wallrun, and dodge use client velocity movers.
- Knife-climb, ledge pull-up, slide yaw, and wall-align write the root CFrame directly under PlatformStand.
- One shared HRP `AlignOrientation` is re-pointed by about six systems. That is the source of the documented
  freelock and slide/vault fights; see D1.
- The rig's `ControllerManager` + `SwimController` is dead code.

**Replication is native and client-authoritative:**

- Animate's `UnreliableRemoteEvent` is a validated footstep relay capped at 12/s. **That pattern is worth
  keeping.**
- `ReplicateRigEvent` relays poses from any client to everyone, **unvalidated**.
- Animations use native replication, and the server also plays tracks on player Animators.

**No movement validation works:**

- `AntiTp` never runs.
- Mount checks are never connected.
- Speed, fly, teleport, and fall-damage cheats are open.
- Clients self-report climb stamina, toggle their own HRP ownership, and report NPC positions.

**Keep:**

- the feel, tuned through about 70 Workspace attributes (`SLIDE_*`, `WALLRUN_*`, `VAULT_*`, …);
- momentum carry;
- `Gravity = 185`;
- the momentum ragdoll;
- rider-owned mounts;
- ghost spectate;
- the footstep relay.

This design **is** the server-side movement authority the old game never had.

**Census** (read-only): the map has **0 Seats, 0 ProximityPrompts, and 0 Workspace scripts using
`.Touched`**.

- The ~1,235 unanchored parts are leftover character models, not map props.
- StarterGui holds 21 old-game ScreenGuis. That is cutover cleanup; the new UI mounts from PlayerScripts.
- `VoiceChatService.EnableDefaultVoice = true`.

---

## 3. Venture's rig and place (confirmed in Studio, read-only)

| Item | Value |
|---|---|
| Rig | `StarterPlayer.StarterCharacter`: custom R15 in Parts and Unions, 17 Motor6Ds with standard R15 names (+2 hand-holder hinges), a `PackageLink` (v55) |
| HRP | 0.86 × 0.53 × 0.43, `RootPriority = 1`, not massless, `PlayerHitbox` MeshPart child |
| Humanoid | R15, `HipHeight = 3.8`, `UseJumpPower` (50), `BreakJointsOnDeath = false`, `AutomaticScalingEnabled = false`; children `Animator` and `ControllerManager` (dead) |
| Workspace | `StreamingEnabled = true`, `Retargeting = Disabled` (mandatory), `Gravity = 185`, `FallenPartsDestroyHeight = -500` |
| Players | `CharacterAutoLoads = true` (becomes `false`, §8), `RespawnTime = 3`, `MaxPlayers = 60` |
| Map extents | X −2735…278, Y 2…921, Z −1452…726. Quantisation centre (−1228, *, −363). |

---

## 4. Engine facts that constrain the design

| Fact | Status | Source |
|---|---|---|
| Locally created instances don't replicate. A locally created Animator's tracks don't replicate. `LoadAnimation` needs the Animator in Workspace. | documented | [Animator](https://create.roblox.com/docs/reference/engine/classes/Animator) |
| **StarterCharacterScripts are copied only into engine-spawned characters.** StarterGui is copied into PlayerGui "when a Player.Character spawns". | documented / reasoning | [StarterGui](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/StarterGui.yaml) |
| `CharacterAutoLoads = false` means no character spawns until `LoadCharacterAsync` | documented | [Players](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Players.yaml) |
| `ReplicationFocus` is server-set; when nil it falls back to the character's PrimaryPart | documented | [Player](https://create.roblox.com/docs/reference/engine/classes/Player) |
| **Client physics runs only in streamed areas, "even for locally created instances"**. `StreamingIntegrityMode` watches the *replication focus*. | documented | [Streaming](https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/streaming/index.md) |
| Client-side `LocalPlayer.Character = rig`: Chickynoid ships it, **but its rig is anchored and moved by `BulkMoveTo`, and it sets `CameraSubject` by hand**. A physically simulated Humanoid under a client-assigned Character has no precedent. | de facto, **unproven for our case** | [Chickynoid](https://github.com/easy-games/chickynoid) `ClientModule.lua` L629-644 |
| Input Action System: full release 2026-06; the converted PlayerModule has **no public API**; default-on early 2027; property removed mid-2027 | staff | [IAS](https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416), [migration](https://devforum.roblox.com/t/new-playermodule-migration-guide-for-playerscripts-useinputactionsystem/4681909) |
| Default voice parents an `AudioEmitter` to `Player.Character`. Client-built voice wiring: community reports unanswered or failed. | documented / community | [VoiceChatService](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/VoiceChatService.yaml), [DF](https://devforum.roblox.com/t/how-to-route-voice-chat-input-directly-to-an-audioemitter-without-humanoid-character/3254039) |
| Automatic network ownership goes to the client whose *character* is nearest | documented | [Network ownership](https://create.roblox.com/docs/physics/network-ownership) |
| `Humanoid.EvaluateStateMachine = false` disables its internal physics and state machine | documented | [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid) |
| Engine animation LOD (`PreferLodEnabled`, `ClientAnimatorThrottling`) targets *remotely simulated* models, **not local puppets** | documented | [Animator](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Animator.yaml) |
| `UnreliableRemoteEvent`: unordered, droppable, **payload > 1000 B dropped**, ~500 req/s per client shared. The size check applies **after** buffer compression. | documented | [URE](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UnreliableRemoteEvent.yaml) |
| `GetServerTimeNow()` returns **Unix seconds**. It is smoothed and monotonic, and it **slews** (runs within 0.6 % of the local clock rate). | documented | [Workspace](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| Camera descendants don't replicate physics | **undocumented** (2023 staff reply) — relevant to B′ only | [DF 2023](https://devforum.roblox.com/t/physic-replication-bug-camera-hack-does-not-work-in-all-circumstances-some-data-still-replicates-when-using-certain-instances/2315760) |
| July 2026 IPR bug: respawning characters placed at the origin on the server | staff repro — relevant to B′ only | [DF](https://devforum.roblox.com/t/character-replication-mismatch-with-improvedphysicsreplication-enabled/4734415) |
| Frame order: PreRender → PreAnimation → PreSimulation → PostSimulation → Heartbeat | documented | [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService) |

**ByteNet** (`elitriare_bytenet-max@0.2.7`, `process/server.luau` L240-255) batches **every** unreliable
packet for a player into one `FireClient` per Heartbeat. If the batch exceeds 1000 B, **all of it** is
dropped. The client side does the same on the uplink. So character records get a **hard 700 B per
viewer-frame cap**, which is an engine limit, not a tunable.

---

## 5. Body strategies

Everything in §6 is shared between the strategies. Only the body layer differs.

### 5.1 Option A: client-only body (chosen)

**Server:**

- **No engine characters.** `CharacterAutoLoads = false`, set by a property-only Rojo node on `Players`
  (§8), so no join can race the service boot. Any server character that appears anyway is destroyed and
  logged.
- **Per player it holds:**
  - the validated history (§6.9);
  - the server state automaton (§7);
  - a **streaming focus that does not leak** (§5.1.2).
- **Server-side hits and interactions** query the history with state-derived capsules.

**Owner client** (the client service builds the rig):

- clones `StarterCharacter` and parents it to Workspace;
- assigns `LocalPlayer.Character = rig` and **sets `CameraSubject` explicitly**;
- **starts `LocomotionAnimator` on the rig itself** (StarterCharacterScripts never reach a client-built
  rig), so `Animate.client.luau`'s role moves into the client service;
- mirrors server health onto the local Humanoid (display only), so `VitalsHud` and death animation keep
  working;
- watches `AncestryChanged` for the local fall-plane destroy.

Movement feel equals native, because it *is* a native Humanoid.

**Other clients** build a **puppet** per remote player:

- **anchored root**, with every puppet moved by **one `workspace:BulkMoveTo` per frame**;
- `EvaluateStateMachine = false`;
- `CanCollide`, `CanQuery`, and `CanTouch` off, so there are no collisions and parkour raycasts don't
  wallrun off other players;
- `DisplayName` / `DisplayDistanceType` set explicitly;
- a local Animator driven by the state word (§6.8);
- our own distance/screen **animation LOD**, since the engine gives local puppets none;
- chat bubbles through `TextChatService:DisplayBubble(puppetHead)`.

**Why A beats the baseline structurally.** Every row of §1.1 disappears by construction:

- there is no server assembly to anchor, arm, own, or repair;
- local Animators never replicate, so there are no ghost tracks and exactly one writer per rig;
- puppets don't collide;
- intent rides the typed state word, never attributes.

#### 5.1.1 What A costs (all accounted for)

| Engine feature tied to server-spawned characters | Resolution |
|---|---|
| StarterCharacterScripts | The client service starts locomotion on rigs it builds (above) |
| StarterGui copy into PlayerGui | New UI mounts from PlayerScripts. The 21 old ScreenGuis are cutover cleanup. |
| Spawn, respawn, SpawnLocations, fall plane | Server-owned death and spawn. It pre-streams the target with `RequestStreamAroundAsync` before the client places its rig. |
| Auto network ownership of props | Census: no props or Seats today. Future physics props are server-owned, or client-predicted with server-validated events. |
| Tools / Backpack | Custom weapons (combat redesign). |
| Server `Touched`, ProximityPrompt `Triggered` | History queries. Prompts use client `PromptTriggered` plus a history-validated remote (census: 0 prompts today). |
| `GetPlayerFromCharacter`, `DistanceFromCharacter` | A rig ↔ player registry in the client and server services. |
| Spatial voice | §5.1.3 |
| Bubble chat | `DisplayBubble` on the puppet head. |

#### 5.1.2 Streaming focus without an ESP leak

A plain anchored part in Workspace would stream to every client within the 1024-stud target radius, which
is **map-wide ESP**. Two candidate routes, decided at CP2:

1. **Preferred:** focus parts in a **non-replicating container** (a server-side Camera or equivalent), if
   `ReplicationFocus` still drives streaming from there.
2. **Otherwise:** no focus part at all. Drive streaming with `Player:RequestStreamAroundAsync` along the
   validated path, plus `AddReplicationFocus` only where needed.

The focus trails the rig by about RTT × speed (≈ 5 studs at 50 studs/s and 100 ms). That is well inside
`StreamingMinRadius` (64), so normal play stays streamed. Spawn and teleport pre-stream (§5.1.1).

**Acceptance test:** a client enumerating Workspace finds no per-player focus objects.

#### 5.1.3 Voice (required)

Tried in order at CP3:

1. **Client-wired voice.** Each client wires the remote player's replicated `AudioDeviceInput` to an
   `AudioEmitter` on that player's **puppet head**. No leak. Unproven.
2. **Server speaker part.** `EnableDefaultVoice = false` and `UseAudioApi` on. The server creates an
   `AudioEmitter` on an anchored speaker part per player and wires that player's `AudioDeviceInput` to it
   (the documented custom-voice path). It works, but **the part replicates, so it leaks a coarse position**
   to clients streaming that area. The leak is bounded:
   - the part moves at low rate (≤ 5 Hz) and coarse precision;
   - it exists only while some listener is within voice range, and is parked otherwise;
   - inside 600 studs the visibility set already reveals positions, so the net leak is the 600–1024 ring
     at coarse precision. Native Roblox characters leak more.
3. **Only if 1 and 2 both fail:** voice becomes a B′ trigger.

### 5.2 Option B′: refined Camera trick (fallback)

B′ is the baseline's primitive minus its failure modes:

- the anchored cube lives in a per-character Camera **inside the rig**;
- **one ownership rule, in one module**;
- arming waits for ground contact and the first packet;
- **remote roots are anchored locally and moved with `BulkMoveTo`**, exactly like A's puppets.

B′ keeps a real server character, so voice, props, prompts, and StarterGui work natively.

**B′ triggers** (any one of them):

- CP1 fails, meaning a client-assigned Character can't run a physically simulated Humanoid under
  PlayerModule;
- CP2 can't hide the focus;
- CP3's voice routes 1 and 2 both fail;
- a future indispensable feature needs a server character.

**B′ adds its own tests:**

- the trick on the current engine;
- the ownership pin;
- respawn against the July 2026 IPR origin bug.

### 5.3 Native (± augment): rejected

Native offers no per-viewer tiers, no interpolation control, and no lag-comp history. It also leaves
client-owned physics open to teleport, noclip, fly, and NaN exploits (per the docs).

Augmenting (BetterReplication) pays for native bandwidth *and* our own, and jitters at the handover.

### 5.4 Anchored replicated character + local clone: rejected

It is strictly worse than A: native bandwidth on every server write, plus two characters sharing one
identity.

### 5.5 Chickynoid: rejected

- It replaces the Humanoid, so all parkour would be reimplemented.
- It has been dormant since 2024-01.
- We keep its one idea: client-assigned `Character`.

### 5.6 Roblox Server Authority: rejected (C2)

It forces the following game-wide:

- Deferred signals;
- IAS;
- fixed simulation;
- `BindToSimulation` movement;
- 64-attribute and 8-track caps.

It also:

- has unverified support for custom-proportioned rigs;
- provides no visibility set.

### 5.7 Community libraries

| Library | Mechanism | Verdict |
|---|---|---|
| Chrono (MIT, 2026-09-20) | Camera trick (`RootPriority = 126` part in a Camera); 14–18 B URE packets at 20 Hz; tiers <50/50–100/none; dynamic buffer 0.09–0.5 s; **no validation, only a hook** | Reference for B′. Not adopted: `const` keyword, not strict, not on ByteNet. |
| BetterReplication | native + per-frame override | Rejected (§5.3). No licence file. |
| Zap / Blink / Squash | IDL / serialisers | Not needed: one hand-packed buffer inside a ByteNet packet. |

---

## 6. The pipeline (shared by A and B′)

### 6.1 Transport (C7)

Motion uses two ByteNet packets in a new `Shared/Events/CharacterReplicationEvents` namespace, each with
`reliabilityType = "unreliable"` and a single `buffer` payload:

- **uplink** (owner → server);
- **downlink** (server → viewer, one batch per viewer per frame).

A **reliable** ByteNet packet carries:

- the **slot table**: slot → userId, generation, 8-bit epoch, and the session time epoch;
- join-in-progress full state;
- despawn.

**Amendment to `docs/architecture.md` Networking** (lands with the implementation):

> *Continuous, high-rate, per-viewer state (character motion) is a third case: it rides typed **unreliable**
> ByteNet packets owned by the character replication service. It is not an atom, because charm-sync is
> reliable-ordered, diffs every frame, and is identical for every viewer. It is not a one-off event either.*

This is the repo's first unreliable ByteNet packet.

### 6.2 Record layout v2 (16 bytes)

The box is centred on (−1228, 0, −363) and is configurable per place.

| Field | Bits | Encoding | Resolution / range |
|---|---:|---|---|
| slot | 7 | index into the reliable slot table | 128 (60 players + future NPCs) |
| generation | 2 | slot reuse guard (low bits; the full value is in the slot table) | |
| epoch | 3 | low bits of the server-owned epoch | "newer" = +1 only (§6.7) |
| sample age | 10 | batch time − sample time, ms | 0–1023 ms; the scheduler never holds > 400 ms |
| pos X, Z | 18 + 18 | `(x − cx + 2048) × 64` | 1/64 stud, ±2048 |
| pos Y | 16 | `(y + 512) × 32` | 1/32 stud, −512…+1536 |
| yaw | 8 | | 1.4° (body facing on a capsule) |
| aim pitch | 6 | | 2.9° (look-at only, never used for hits) |
| velocity X, Y, Z | 11 × 3 | sign + 10-bit **sqrt-companded** magnitude: `q = round(1023·√(|v|/768))` | 0.15 studs/s at 8 studs/s, 1.4 at 700; ±768 studs/s (a full-height fall at gravity 185 is ~725) |
| locomotion state | 5 | idle, walk, run, sprint, jump, fall, land, wallrunL/R, vault, slide, climb, ledge, clamber, zipline, roll, stagger, ragdoll, mounted, … | 32 |
| grounded | 1 | | |
| hasAction | 1 | appends an action extension: action id 7 b + normalised phase 6 b | |
| **Total** | **128** | | **16 B** (≈ 17.6 B with an action) |

Checksum: 7+2+3+10+18+18+16+8+6+33+5+1+1 = **128**. If CP0 shows `writebits` is too slow, use the
**byte-aligned 22 B fallback**, which carries every field at full width (yaw 12, pitch 12, slot 8).

Ragdoll and other free-rotation states use a variant **implied by `state = ragdoll`**: the velocity bits
are swapped for a 29-bit smallest-three quaternion, so no flag bit is needed.

**Batch header:** `u16 seq | u32 batchTime (ms since the session epoch, wrap-aware) | u8 count` = 7 B.

**Rules:**

- **Quantise in the codec only.** Never write quantised values back onto the owner's Humanoid (it would
  fight the solver). Server, viewers, and history all consume the same encoded bytes.
- **The history stores the exact bytes that were sent** (§6.9).

### 6.3 Uplink (owner → server)

- **One sample per Heartbeat**, at least 15 ms apart (≤ 60 Hz), with true timestamps. There is no
  accumulator emitting duplicate positions.
- **Packet:** the current sample plus the **two previous, delta-coded with explicit 6-bit ages**. About
  40 B, or about 2.4 KB/s. Survives two consecutive losses. It shares the client's ByteNet unreliable batch
  with the footstep relay, so it stays well under 1000 B.
- **Server ingest:**
  - checks the exact packet size **before** decoding, and clamps every field to its range;
  - dedupes by seq; the **first accepted version of a sample is final**, and a mismatched duplicate is a
    violation;
  - keeps a reorder window of 4 and uses serial-number arithmetic on seq.
- **Timestamp window:** `[arrival − min(RTT_min/2 + 3σ + 50 ms, 150 ms), arrival + 10 ms]`, monotonic per
  seq. `RTT_min` is the minimum over a window, not the mean.
- **Drift-slope check:** `(sampleTime − arrivalTime)` must have a slope ≈ 1 over 1–2 s. This closes time
  banking.
- **Movement budget** is charged against **server arrival time**, never client dt.

### 6.4 Downlink scheduler: error-driven priority

For each viewer and each body in its visibility set, the server keeps **the last record it sent that
viewer**. It runs the **shared interpolator/extrapolator** on that record to see where the viewer thinks
the body is now, and compares it to the truth:

```
priority = error(viewer's picture, truth) / 0.25 stud  +  small age term
```

In plain words: **each frame, send updates for the players whose picture on your screen is most wrong.**

- A player standing still has zero error, so they cost nothing (send-on-change comes for free).
- A player who just changed direction jumps to the top.

This replaces fixed distance bands *and* the earlier multiplier formula. Each frame:

1. Sort by priority. Pack records until **700 B** (hard cap) or the **per-viewer budget** (24 KB/s default,
   O3) is reached.
2. **Forced sends** go through a per-viewer queue inside the cap: state changes (take-off, wall contact,
   vault start) and new epochs. They are rate-limited per body.
3. **No single body gets more than 15 % of a viewer's budget.** This blocks priority-pumping griefers.
4. A **1 Hz repair tick** per body.
5. **Never resend a sample seq that viewer already has.**
6. **Ranged-combat override:** if the viewer is aiming a ranged weapon at a body, that body gets a priority
   floor, so a 400-stud sniper duel isn't starved.

**Capacity:**

- **12 players:** 11 × 16 + 7 = 183 B/frame (11 KB/s). **Everyone updates at 60 Hz.**
- **60 players:** 24 KB/s ≈ 1,500 records/s, ≈ 25 Hz on average. Error-driven priority puts the rate where
  motion is.
- **Per frame:** 700 B holds at most 43 records.

**Comparison with the baseline.** A baseline band schedule, modelled as a worst case (all 59 players inside a
450-stud freeze), costs ~85 KB/s. The same schedule with our records costs ~33 KB/s. The baseline's *real* cost is lower,
because it freezes far players. The §10 harness compares both at the same radius.

**Join-in-progress / entering relevance:** a small **reliable** full-state record (slot, generation, epoch,
position, state, appearance reference), sent once.

**Leave / despawn:** a reliable slot release, then a generation bump.

### 6.5 Visibility set (C6)

**Phase 1:**

- **Distance hysteresis:** relevant within 600 studs, released at 630.
- **Same-team override.**
- **Mutual combat loading.** If A can hit B, B has A loaded. It decays unless it is renewed by a
  server-validated hit.

The set is the **damage whitelist**. Grace for a target that just left it is `RTT + delay + 100 ms`, not a
flat 0.5 s.

**Known leak.** Inside 600 studs, through walls, a cheater sees position, aim, and state. That is acceptable
for a third-person game, where the camera sees over walls anyway. Footstep relays go only to viewers within
hearing range who have the body loaded.

**Phase 2**, only on a named trigger: ESP complaints, or detected aim-through-walls tracking from the
anti-cheat service. It would add competitive-shooter-style occlusion: a 5–10 Hz pass over a velocity-expanded AABB,
within ≤ 2 % of the server frame. Occluded-but-relevant bodies then get reduced precision, with aim, state,
and action stripped.

### 6.6 Time base and rendering

**Time.** All times are **ms since a session epoch** announced in the slot table, taken from
`GetServerTimeNow` on the owner. It is documented to slew, not step.

**Render clock.** There is **one per viewer**. It advances at `dt × rate`, `rate ∈ [0.97, 1.03]`, steered by
a PI controller:

- `Kp = 0.3 s⁻¹`, `Ki = 0.05 s⁻²`, with anti-windup;
- target `now − delay`;
- snap once if the gap exceeds 250 ms.

**Per-entity offsets** slew at ≤ 3 %/s toward each entity's needed delay, with hysteresis. This replaces v1's
two clocks: nothing pops when a body enters combat.

**Delay.** `J97 + (L+1)·I_eff + 8 ms`:

- J97 is the 97th-percentile jitter;
- I_eff is the 90th-percentile spacing received;
- L ∈ {0, 1, 2} is set from measured loss.

It grows fast and shrinks slowly. It is **capped at 120 ms**. Bodies updating below about 8 Hz dead-reckon
from their sent velocity rather than raising the delay.

Target buffering on top of transit, for a 5 ms p97 jitter link:

| Rate | Recommended (L=0 / L=1) | Baseline (2 intervals, no margin) |
|---|---:|---:|
| 60 Hz | ≈ 30 / 46 ms | 33 ms (underruns under jitter) |
| 40 Hz | ≈ 38 / 63 ms | 50 ms |
| 20 Hz | ≈ 63 / 113 ms (capped at 120) | 100 ms |

**Interpolation: Hermite with the sent velocity.**

- It saves one interval over uniform Catmull-Rom: −16.7 ms at 60 Hz, −50 ms at 20 Hz.
- **No landing dip.** Catmull-Rom sinks 0.185 studs into the floor on a 50 studs/s landing at 20 Hz.
- It is immune to loss and irregular spacing (`m = v × Δt`).
- **Tangents are monotone-clamped to the chord** on segments where the state or `grounded` changes.
- All tangents are capped at `min(|m|, 1.5·chord + 0.25 stud)`.
- Yaw and pitch use shortest-arc lerp.
- On platforms, interpolation is platform-relative (§7).

**Underrun handling, in order:**

1. clock dilation;
2. state-aware dead reckoning for ≤ 100 ms (airborne: gravity 185; grounded: one ground ray; wallrun: the
   wall plane), with one sweep that stops at geometry;
3. a damped hold;
4. recovery by a critically damped spring over ~120 ms. Snap only past 8 studs or on a new epoch.

### 6.7 Teleports and discontinuities

- **The epoch is server-owned.** The client never supplies it.
- **What bumps it:** respawn, server teleport, mount/grapple attach, and slot switch. It is **not** bumped
  by ordinary clamps (§7), and bumps are at least 250 ms apart.
- **On the wire:** 3 low bits. "Newer" means exactly +1 mod 8; anything else from an older epoch is
  dropped. The full 8-bit value is in the reliable slot table.
- **A new epoch:** flushes the buffer, snaps the puppet, and resets that body's delay statistics (superseded: the render clock is per viewer — see Verdict).
- **Lag comp at a boundary:** tests the samples on **both** sides of the boundary rather than returning "no
  target".

### 6.8 Animation on remotes

**Locomotion is derived locally** from the interpolated velocity plus the state word. Play rate = speed ÷ the
clip's stride speed (clamped 0.7–1.4). *Foot locking and inertialisation come later.*

**Discrete actions are server-granted** (§7):

- The owner requests an action and plays it immediately on its own screen.
- The server checks cooldown and legality, then grants it with a server start time.
- The relay **drops any action extension without a live grant** and **rewrites its phase from the grant
  time**. Wind-ups can't be skipped or faked.
- Receivers **latch** `actionStart` from the first record and re-seek only on more than 40 ms of drift.

**One writer per rig:**

- the owner's Animator on its own rig;
- the local pose driver on each puppet;
- the server never plays tracks on player rigs (already true today: `AnimationServiceServer` sends requests
  to clients).

Server-requested animations become action events that reach every client with that rig loaded.

**Look-at / IK** is derived from yaw and pitch on the puppet. Old Venture's unvalidated
`ReplicateRigEvent` is gone.

### 6.9 History and lag compensation

**History.** Per player, a 1 s ring `buffer` of the exact 16 B records sent (60 × 60 players ≈ 58 KB), plus
server-derived velocity.

**Per-viewer sent-seq ring.** The last 16 seqs sent per body (~113 KB at 60 players). It records exactly
what each viewer could have rendered.

**Render-clock tracker.** The server models each viewer's render clock from what it sent and when. A shot's
`renderTime` must track that model within ±20 ms, and must be monotonic with slope ≈ 1. This stops
backtracking.

**Shot / melee request** (reliable):

- per candidate target, its `renderTime` and **the two bracketing seqs it rendered between**;
- plus origin, direction, and weapon.

**Validation, before any rewind:**

- fire rate and cooldowns;
- the bracketing seqs were actually sent to this viewer;
- the origin is within ε of a muzzle/eye derived from the **validated** history at shot time;
- line of sight eye → origin → ray against the server world.

**Rewind:**

- the target is evaluated on **exactly those two samples** with the shared Hermite code, which agrees with
  the shooter's screen to within quantisation;
- **cap:** `250 ms + RTT_min/2`, at most 400 ms;
- beyond ~200 ms RTT, favour-the-shooter scales down, so high-ping players pay rather than their victims;
- broad phase: a swept AABB;
- narrow phase: state-derived capsules (a state not confirmed by the server uses the **larger** capsule);
- inflation: server-derived `|v| × 8 ms`, plus the viewer's reported recovery-spring offset (capped).

**Melee** rewinds the *victim* to the attacker's `renderTime`. The attacker's pose comes from the history at
swing time, and reach comes from the server's weapon definition.

**Stale players** (§7) can't deal damage.

---

## 7. Enforcement and anti-cheat (C5)

### Three pieces, with dependencies in one direction

1. **`MovementRules`**: a pure module under `Shared/Modules`, spec-first, with no Roblox services.
   - **Input:** the state automaton, the tuning constants, a history window, and a world-query interface.
   - **Output:** accept, or clamp to X plus a typed violation.
   - Combat and interaction reuse it.
2. **Enforcement inside replication ingest.** It decides what enters the history and what gets relayed. It
   is deterministic, cheap, and **fail-closed**, and it **works with the anti-cheat service switched off**.
3. **`AntiCheatServiceServer`**: a real service that **judges**.
   - It subscribes to replication's typed `violation` signal and to link statistics.
   - It owns:
     - strike scoring and decay;
     - long-window detectors: time at the cap, clock drift, lag gaps that coincide with combat,
       `renderTime` offsets, silent aim, budget-share outliers;
     - kick policy;
     - an F4 panel.
   - Its only writes back are **tightening**: `setScrutiny(strict)`, `freeze`, `forceCorrection`,
     `respawn`. **It can never loosen anything.**
   - **Phase-1 policy:** log, show in F4, and kick at a threshold (tuned later).

### Invariants

1. No client-supplied field (time, velocity, epoch, action, phase) reaches the history or downlink without
   being re-derived or checked by the server.
2. Every tolerance is a **budget over a window**, not an allowance per sample.
3. Every network-derived window has a **hard cap**.
4. Anti-cheat can only tighten.

### `MovementRules` checks

- **State automaton.** Every state has an entry precondition against the **server** world, a maximum
  duration, a cooldown, and legal exits.
  - Ragdoll, stagger, mounted, and zipline are **server-granted only**.
  - A state the client can't justify falls back to the strictest envelope.
  - Client geometry is never authoritative.
- **Dynamic envelopes from the tuning constants the owner simulates with.** For example, slide speed decays
  from its entry speed, and sprint needs server-simulated stamina. Budgets are checked over 1 s and 5 s
  windows.
- **Grounded / climb / ledge** need a server shapecast at HipHeight 3.8 against the server world (with a
  cached result per surface patch).
- **The whole airborne arc** is validated from take-off (gravity 185), not per step. Take-off velocity is
  capped from the constants. **Fall damage** is computed server-side from the validated arc.
- **Noclip:** a **capsule shapecast** from the last accepted pose, including server-moved colliders at
  their pose at sample time.
  - **Moving platforms** are tagged, and samples on them are encoded relative to the platform.
  - The server enforces its own death plane.
- **Velocity** must be within ε of the finite difference of accepted positions; otherwise it is replaced
  by the server's derivation.
- **Impulses** (knockback, launch pads) define an **expected trajectory**, integrated under gravity, with a
  **floor and a ceiling**. Root and stun set the envelope to about zero.
- **Corrections carry an id.**
  - Samples that don't acknowledge the correction within RTT + ε are rejected, and the player is held in
    place.
  - Clamps pull toward the **last accepted** point.
  - The owner blends toward the correction over ~120 ms (snapping past 8 studs).
- **Lag switch:** after ~150 ms of silence the player is **stale**.
  - They can't deal damage or interact.
  - Held samples go into the history, so they stay hittable where others see them.
  - Resuming requires a sweep over the whole gap and a settle window. Movement credit is capped.
- **Raycast budget** per player per second. Over budget, the sample is rejected (fail closed).
- **Skewed-clock fallback** uses stricter tolerances, grants zero lag-comp credit, and counts as a
  violation.
- **Spawn:** the first sample after a respawn must be within ε of the server-chosen spawn. Samples from
  dead or spectating players are dropped.

---

## 8. Blast radius in this repo (option A), verified against `src/`

| Module | Today | Change | Size |
|---|---|---|---|
| **New** `CharacterReplicationServiceServer` / `…Client` | — | Server: slot table, focus (§5.1.2), ingest + enforcement, history, visibility, scheduler, lag comp, **body lifecycle signal** (`bodySpawned` / `bodyDespawned`). Client: owner rig build + `Character` + `CameraSubject`, locomotion start, health mirror, uplink, puppet pool + LOD, interpolator, render clock, rig ↔ player registry. | L |
| **New** `AntiCheatServiceServer` | — | Judge (§7). | M |
| **New** pure modules: `CharacterRecordCodec`, `MovementRules`, `CharacterInterpolator`, `ReplicationScheduler`, `RenderClock` | — | Spec-first. The codec and interpolator are **shared by client and server**. | L |
| **New** `Shared/Events/CharacterReplicationEvents` | — | Unreliable uplink/downlink plus the reliable slot table. | S |
| `StatsServiceServer` (`start()` L135-160, `applyToCharacter`) | `Observers.observeCharacter` → writes `Humanoid.MaxHealth/Health` | Rewire to `bodySpawned`. Health is server state; the client mirrors it. The whole `start()` lifecycle changes. | L |
| `CustomizationServiceServer` (`start()` L216-238) | same `observeCharacter` seam | Rewire to `bodySpawned`. Appearance is applied **client-side** on every rig a client builds. | L |
| `CustomizationApplication` (spec-exempt) | server mounts accessories (engine auto-binding, L414-418) | Runs on the client. Spike the depth-3 `Eyes` socket and WrapLayer, with an explicit-constraint fallback. | M |
| `Animate.client.luau` + `LocomotionAnimator` | engine copies `Animate` into spawned characters; `humanoid.Died` drives the death pose | The client service starts locomotion on the rig. Death comes from the server event / health mirror. A puppet pose driver is added. | M |
| `VitalsHud` (L62-116) | binds the local Humanoid's health | Works through the health mirror; no code change if the mirror lands. | S |
| `AnimationServiceServer` | sends play/stop requests to the owning client (already correct) | Requests become action events to every client that has the rig loaded. | M |
| `AnimationServiceClient` / `AnimationPlayerRuntime.forCharacter` | reads `LocalPlayer.Character` | Unchanged, once the client-built rig carries a Humanoid + Animator. | S |
| `SlotServiceServer.switchSlot` (L198-293) | synchronous `LoadCharacter`; "true = committed" | Asynchronous: bump the epoch, rebuild, reset history. **The return contract changes.** | L |
| `AdminServiceClient` (L46-48) | unbounded `CharacterAdded:Wait()` | Bounded; CP1 checks it. | S |
| `TuneOffsetServer` (Cmdr) | reads server `target.Character` | Route through the rig registry, or tune a client preview. | S |
| Debugger `StatePanel` (L200-218) | highlights `player.Character` | Reads rigs through the client service. Add a replication panel. | S |
| `SceneRegistry` / `UIWorldSuppression` | declare `movement` / `characterRotation = "server"` | They now have a handler. | S |
| `default.project.json` | `Players` unmounted | Add a **property-only** node `Players.$properties.CharacterAutoLoads = false`. No `$path`, per the AGENTS.md pattern. | S |
| `docs/architecture.md` | two-channel rule | The §6.1 amendment. | S |

**Confirmed unaffected:**

- Currency, Inventory, Bank, Equipment, Titles;
- PlayerData / StateSync (they use `observePlayer`);
- `CustomizationConformance` (it checks the template).

---

## 9. Scenarios

| Scenario | Handling |
|---|---|
| Join in progress / entering relevance | Reliable full-state record once, then the stream |
| Leave | Reliable slot release, generation bump, puppet destroyed |
| AFK / crash / freeze | Stale after ~150 ms (§7). Puppet holds, then fades. Despawn after a timeout |
| Respawn / slot switch | Server-chosen spawn, pre-stream, epoch bump, owner rebuilds its rig |
| High ping (> ~200 ms) | Rewind is capped (≤ 400 ms). Favour-the-shooter scales down, so the high-ping player leads their shots |
| Spectating (ghost spectate) | The spectator gets a visibility override and a priority floor for the spectated body. The ghost is its own local-only rig |
| Mounts / zipline / grapple | Server-granted attach carries the entity id and an epoch bump. The rider's record says `mounted`, and the mount is its own replicated entity (its own spec, Mounts phase) |
| Carry / grab another player | Not in old Venture. **Out of scope** for phase 1 |
| Cross-server teleport | Out of scope (session teardown) |
| NPCs | Reuse the codec, interpolator, and scheduler, under a separate spec when NPCs are ported |
| Cmdr dev fly/noclip | Implemented as server-granted exemption states in `MovementRules` (admin allowlist), never as client bypasses |
| 144 Hz / low-end mobile clients | The uplink is capped at 60 Hz. Puppet LOD scales animation and IK rate; CP4 measures it |

---

## 10. Proving it

**Minimal harness first**, expanded only if results are contested:

- pure Luau: owner-truth traces from real parkour runs → codec → network model → receiver;
- one profile (150 ± 30 ms, 3 % loss, 1 % reorder);
- three metrics (below);
- A/B against the baseline model.

| Metric | Target |
|---|---|
| Position error vs owner truth (excluding reckoning and held frames, which are reported separately) | mean < 0.05, p95 < 0.25, p99.9 < 1 stud |
| Bandwidth | 0 character batches > 700 B; ≤ budget per viewer |
| Pops | < 1 per player-minute |

Later: error by state, jerk, action alignment, lag-comp agreement (p95 < 0.1 stud), and four network
profiles.

---

## 11. Checkpoints (the developer tests; decisions wait for them)

**The code under test is venture-game-systems**, including its existing refactored services (Stats,
Customization, Slots, Animation, VitalsHud, Admin/Cmdr, the debugger), with the §8 changes. The design must
work with those systems. The old game only supplies **art** and **stress conditions**.

**Test place: `VentureReplicationSpike`.**

1. The developer makes a local **Save to File** copy of VentureTestingPlace (never Publish over it).
2. Strip the copy of old code that could run: StarterGui ScreenGuis/LocalScripts and leftover Workspace
   character models. The agent lists these and may strip them via MCP once the developer confirms, since
   the copy is not the protected place.
3. `rojo serve` venture-game-systems plus the spike branch into it. The real map (≈3000 × 2200 studs) and the
   real rig package (v55) make streaming and puppet tests meaningful.
4. For CP0 (phone) and CP3 (voice), publish the copy to a **new private experience**
   (`Venture[ReplicationSpike]`), not the CI place, staging, or live.

Systems that venture-game-systems doesn't have yet (parkour, ragdoll) are exercised through **minimal spike
stand-ins**, deleted afterwards:

- one client-mover move (slide);
- one CFrame-write move (wall-hop);
- a ragdoll toggle;
- agent-written exploit scripts.

They prove the *mechanisms* the real ports will use. The real systems are ported later as refactored pieces
on whatever this proves.

The agent builds each spike on a **throwaway branch** `spike/character-replication`. Spike code is listed
in `SpecRoots.EXEMPT_MODULES` with the reason *"spike — deleted after the replication decision"*.

At each checkpoint, **the developer runs the test** with Studio's Test → Clients and Servers (2 players,
plus a phone for CP0/CP4) and reports what they see. The agent records pass/fail and evidence in a table
appended here. **No decision is taken until the checkpoint reports.**

| CP | What the developer tests | Pass means | Decides |
|---|---|---|---|
| **CP0 — transport** | Run a bandwidth soak: 24 bodies' records at 60 Hz, sustained 24 KB/s for 60 s, on PC **and phone**. Watch the F4 counters: batches > 700 B, dropped UREs, frame time for `writebits`, `GetServerTimeNow` transit variance. | No drops; bit-packing ≤ 0.1 ms per viewer-frame; clock variance a few ms | O3 budget; 16 B bit-packed vs the 22 B byte-aligned record |
| **CP1 — the owner rig (make-or-break)** | Join with no engine character. Your local rig should spawn under your control: walk, sprint, jump, swim, fall; the camera follows. venture-game-systems' own systems must work on it: the Vitals HUD shows health, customization is applied, a slot switch rebuilds the body, and F2 still opens Cmdr. The spike slide and wall-hop stand-ins work. Run it **twice: IAS off and IAS on.** | It feels exactly like native, both times, and the existing systems behave | **O1** (A holds, or B′) |
| **CP2 — streaming + no leak** | Sprint and zipline at top speed across the map; teleport; respawn. Then run the provided "exploiter" script on client 2: it lists everything in Workspace. | No freezes or holes; the script finds **no** per-player focus or speaker objects | O1; focus route (§5.1.2) |
| **CP3 — voice** | Two accounts with voice enabled. Walk apart and together; talk. Route 1 first; if silent, route 2. | You hear each other, spatially, and it follows the puppet | **O2**; voice as a B′ trigger |
| **CP4 — puppets** | Client 2 watches client 1 run, jump, land, and use the slide and wall-hop stand-ins, plus an animation played through AnimationService. Customization looks right (eyes included). Then 59 bot puppets in the hub on your **phone**. | Smooth, no floor sink, correct look; phone holds frame rate | Puppet LOD settings; customization fallback |
| **CP5 — cheat smoke test** | Run the agent's exploit scripts on client 2: speed within the cap, a fake state, lag switch, fake action, backdated shot. | Each is clamped, rejected, or flagged in F4 | Guard readiness for phase 1 |
| **CP6 — ragdoll** | Trigger the ragdoll stand-in and get back up while client 2 watches. | Readable on client 2 | Ragdoll record variant |
| **CP7 — player collision** | Walk, slide, and jump into other players and bots. | Solid, no tripping, no corrections | Blocker shape and mount |
| **CP8 — server load** | 60-player-equivalent validation + fan-out. | Frame budget holds | Server optimisation list |
| **CP9 — native A/B** | The same 59 bodies as puppets vs native characters; frame time, bandwidth, memory. | At or better than native | Move path (`BulkMoveTo` vs joint) |
| **CP10 — lifecycle** | Join/leave; bodies leaving and re-entering range; bots removed; respawn and death; a **real `SlotService` slot switch**; health and appearance applied by the real `StatsService` / `CustomizationService`. | Puppets appear, release and return cleanly; no engine character ever spawns; the real services' effects reach the body | The body-service seams the real services must call |
| **CP11 — observer animations** | Client 2 watches client 1 play an animation through AnimationService, and action events. | The action reads correctly on client 2 | Action extension (`hasAction`) |

**Only if a B′ trigger fires:**

| CP | What the developer tests |
|---|---|
| CP-B1 | The trick stops a 25-stud server move on the current engine |
| CP-B2 | The owner keeps control after arming; log the network owner before and after |
| CP-B3 | Respawn places you correctly (the July 2026 IPR bug) |

---

## 12. Phase-1 scope

**In:**

- option A with §5.1.1–§5.1.3;
- the v2 record;
- uplink with redundancy;
- the full §7 enforcement;
- server-granted actions;
- the error-driven scheduler with its caps;
- distance and combat visibility;
- one render clock with per-entity offsets;
- Hermite;
- recovery;
- state-derived locomotion;
- lag comp with sent-seq brackets and the render-clock tracker;
- `AntiCheatServiceServer` with basic policy;
- the minimal harness.

**Later:**

- foot locking and inertialisation;
- a 12 B far-body record;
- occlusion and the ESP mask (on the §6.5 trigger);
- delta baselines;
- the full harness;
- escalation tuning;
- the NPC and Mounts specs.

---

## Appendix: checkpoint results

### CP0 — transport soak, Studio half (2026-09-22)

**Setup:** Studio Play, 1 server + 1 client, on the `VentureReplicationSpike` copy. It ran through the real
16 B bit-packed codec and unreliable ByteNet. The runs were driven through the Studio MCP.

**Caveat:** the Studio client ran at about **25 fps** (unfocused window). Transit and jitter are therefore
dominated by client frame time, and uplink rate equals client frame rate. The phone and real-network half
is still to run.

| Run | Load | Downlink | Lost | Codec error (pos mean / max; vel max) | Server pack (avg / max per batch) | Client decode (avg / max) | Probes |
|---|---|---|---|---|---|---|---|
| A | 24 bodies, 391 B | 60 /s, 23 KB/s | 0 | 0.0104 / 0.019 studs; 0.41 studs/s | 0.215 / 0.83 ms* | 0.17 / 0.49 ms* | — |
| B | 43 bodies, 695 B (the cap) | 60 /s, 40.7 KB/s | 0 | 0.0104 / 0.019; 0.42 | 0.32 / 1.26 ms* | 0.30 / 0.85 ms* | — |
| C2 | 43 + **250 B random** probe (≈ 950 B raw) | 60 /s | **0** | unchanged | | | **5/5 received** |
| D2 | 43 + **400 B random** probe (≈ 1,100 B raw) | 60 /s | **5** (exactly the probe frames) | unchanged | | | **0/5 received** |
| D | 43 + 400 B **zero** probe | 60 /s | 0 | | | | 5/5 (it compressed below the limit) |

\* Soak timings include computing the synthetic motion (trig) per record, plus the error check on the client.

**Isolated micro-benchmark** (server, 43 records):

| Operation | Cost per batch | Cost per record |
|---|---:|---:|
| `bit32` pack | 0.120 ms | **2.8 µs** |
| read | 0.123 ms | 2.9 µs |
| byte-aligned write | 0.013 ms | ≈ 0.3 µs |

**Findings:**

1. **The codec round-trips correctly** across the whole range, including 222 studs/s falls. Position error
   of 0.010 mean and 0.019 max is inside the quantisation bound. Velocity error of ≤ 0.42 studs/s at
   ~220 studs/s matches the sqrt-compand step.
2. **The 1000 B all-or-nothing drop is real, and it applies after compression.** An incompressible shared
   batch over the limit loses *every* packet in that send, including character records. The **700 B hard
   cap is confirmed necessary.** Budget on raw size, because records barely compress.
3. **Encode once, copy many (new rule for §6.4).** Bit-packing costs 2.8 µs per record. Re-packing per
   viewer at 60 players would be 60 × 43 × 2.8 µs ≈ 7 ms per server frame, which is too slow. Instead:
   - pack each body's accepted sample **once per frame**;
   - `buffer.copy` those bytes into every viewer batch (about 60 × 2.8 µs ≈ 0.17 ms per frame, plus
     copies);
   - these are the same bytes the history stores (§6.9).

   The bit-packed 16 B layout **stays** on those terms.
4. **Client decode** of about 0.12 ms per full 43-record batch is borderline against the 0.1 ms target.
   Optimise the reader, which currently uses a table cursor, when building for real: plain locals, and a
   word-at-a-time decode.
5. **Unreliable delivery on loopback:** zero loss and zero reordering at 60 Hz. The URE path itself is sound.
   Real-network loss and reorder come from the phone half.

**Still open in CP0:** a published private experience, phone plus PC, sustained 24 KB/s, and real transit and
jitter. That also sets **O3**, the per-viewer budget.

### CP1 — owner rig, single-player half (2026-09-23)

**Setup:** Studio Play (1 server + 1 client), driven through the Studio MCP. The code under test is
venture-game-systems plus the CP1 spike.

The server sets `CharacterAutoLoads = false` and publishes a rig template: StarterCharacter plus the
**real** `StarterCharacterScripts`, which carries Venture's own `Animate`. The client clones the template,
assigns `LocalPlayer.Character`, and sets `CameraSubject`.

| Check | Result |
|---|---|
| Client-assigned `Character` | ✅ `Character == rig`. `CharacterAdded` fired **locally** (1, then 2 after respawn) |
| Server view | ✅ `Player.Character = nil` on the server throughout. **0 engine characters** spawned |
| Camera | ✅ `CameraSubject` is our Humanoid |
| Humanoid physics | ✅ It walks 23.9 studs in 1.5 s at exactly WalkSpeed 16. Jump 7.7 studs with states `Jumping > Freefall > Landed > Running`, so none of the anchored-puppet Freefall-stuck problem |
| Venture locomotion | ✅ The real `Animate` runs on the client-built rig, and locomotion tracks play while walking |
| Venture UI and admin | ✅ `UILayer_Debug/Hud/Panel` mounted. **Cmdr loaded** (AdminServiceClient's bounded wait held) |
| Server-owned health | ✅ Server 100 → 60 → 0, mirrored onto the local Humanoid. `Died` fired and the state went to Dead |
| Respawn / rebuild | ✅ The server bumped the epoch to 2 and the client rebuilt the rig. `CharacterAdded` fired again, health went back to 100, Animate re-ran, and the server still had no character |
| Client-created mover (slide mechanism) | ✅ `LinearVelocity`: 34 studs in 0.6 s, peak 57.5 studs/s |
| Direct CFrame write (climb/ledge mechanism) | ✅ +6 studs immediately; a velocity kick afterwards held |
| Streaming | ✅ The server pre-streamed the spawn point (`RequestStreamAroundAsync`) and the rig landed on the map. **The focus part is still a plain Workspace part, so the ESP leak is still present** (that is CP2's job) |

**Still for the developer's two-player run:**

1. PlayerModule **keyboard and camera feel** by hand, with IAS off *and* on.
2. **F2** opens Cmdr.
3. Press C and F by hand.
4. **Client 2 must not see client 1's rig at all.** That proves the rig is local-only; puppets arrive in
   CP4.

### CP1 — two-player run (developer, 2026-09-23, Studio Test → Clients and Servers)

The test windows do **not** register with the Studio MCP, so the developer ran this one by hand.

| Check | Result |
|---|---|
| Both clients: client-built rig as `Character`, `CharacterAdded` fired, Animate running | ✅ (developer screenshots) |
| Both clients: server `Player.Character = nil`, 0 engine characters | ✅ |
| F2 opens Cmdr | ✅ |
| Camera (arrow keys) and movement | ✅ basic. A full feel pass is pending (remote-desktop latency) |
| C slide (client mover) | ✅ works, but see the collision finding below |
| F wall-hop (CFrame write) | ✅ mostly |
| Client 2 must not see client 1's rig | ✅ no body visible on client 2, so the rig is local-only |
| IAS on (`PlayerScriptsUseInputActionSystem` = Enabled) | ✅ both clients: `Character == rig`; WASD, jump and camera respond well; F2 opens Cmdr |

**Collision and stuck-state finding: it also reproduces with native characters in VentureTestingPlace, so it is
not caused by replication.**

- Symptoms: while sliding or jumping near thin geometry (the `Workspace.Railing` `Cube.005` meshes behind the
  spawn, 0.7 studs thick with Box fidelity), the body sinks into floors and walls. The Humanoid goes into
  FallingDown/Freefall and sometimes sticks half inside the geometry.
- Evidence (read-only inspection of the rig):
  - Only **3 parts collide with the world** (`Players` group ↔ Default, Terrain, Chests): HumanoidRootPart
    **0.86 × 0.53 × 0.43** (a standard HRP is 2 × 2 × 1), LowerTorso 1.5 × 0.3 × 0.3, and UpperTorso (a
    Union) 2.1 × 1.9 × **0.3**.
  - The collision body is a few paper-thin slabs; legs and arms don't collide.
  - `PlayerHitbox` (a 3 × 6.2 × 3.1 cylinder) is **not** involved: the `Cylinder` group only collides with
    itself.
- Also: `Animate` doesn't map `Humanoid.FallingDown` to any locomotion pose, which plausibly explains the
  T-pose while stuck.
- The spike's slide stand-in (a 55 studs/s `LinearVelocity`, MaxForce 1e6) is deliberately crude and
  aggravates the problem. It proves the *mechanism*, not the feel.
- **Owner:** the rig redo / Movement phase. Give the rig a proper collision hull (a correctly sized HRP or a
  dedicated capsule-like collider) and map FallingDown in LocomotionAnimator. This does not change the
  replication design.

**CP1 verdict (2026-09-23): PASS, with the Input Action System both off and on.** The client-assigned
`Character` drives a physically simulated Humanoid under PlayerModule (both versions), with camera, Cmdr,
Venture's Animate, server-owned health, death, and rebuild all working. The rig is local-only (client 2
sees nothing). **O1 so far: option A holds.** CP2 (focus with no leak) and CP3 (voice) can still trigger B′.

### CP2 + CP4 — single-player automated half (2026-09-23)

**Setup:** Studio Play, 1 client, plus **3 server bots**. Bots are synthetic bodies that walk circles around
the spawn and jump every 4 s. They go through the *same* pack-once / copy-many fan-out and the same
unreliable ByteNet downlink as real owners.

Puppets are built from the rig template:

- scripts stripped, root anchored;
- `EvaluateStateMachine = false`;
- no collide, query, or touch;
- moved by one `BulkMoveTo` per frame;
- Hermite interpolation at `serverNow − 100 ms`;
- animated by Venture's own LocomotionAnimator from the replicated state and speed.

**Test-harness finding:** an unfocused Studio client (driven through the MCP) **does not render, so
`PreRender` never fires** (0 in 2 s against 120 Heartbeats). Automated runs drive puppets on Heartbeat
(`ReplicationSpikeDriveOn`). Real clients keep PreRender.

| Check | Result |
|---|---|
| Puppets built per remote slot | ✅ 3 puppets. 59 batches/s, 177 records/s |
| Render mode | ✅ **100 % interpolating**, 0 % extrapolate or hold, 16-sample buffers |
| Motion fidelity (Bot 2, programmed speed 16 studs/s) | ✅ measured median **16.0** (p10 13.9, p90 18.5 as it rounds the circle) |
| Ground contact | ✅ root height min **4.02**, where 4.07 is expected on flat ground, so **no floor sink**. Jumps rise about 7 studs |
| Animation on puppets | ✅ Venture's walk and jump tracks play at full weight through LocomotionAnimator, with no Humanoid physics |
| **CP2: focus under a server Camera** | ✅ an exploiter-style enumeration of `Workspace.SpikeFocus` finds **nothing**. Streaming still works (about 700 parts streamed within 150 studs) |
| CP2 contrast: focus as a plain Workspace part | ❌ as predicted: enumeration finds `Workspace.SpikeFocus.Focus` **with the player's live position**. This confirms both the leak and the Camera-container fix |

**Still for the developer:**

- a two-player run: seeing each other as puppets, smoothness in a rendering client, moving far apart;
- 59 bots on a phone once the copy is published privately.

### CP2 + CP4 — two-player run (developer, 2026-09-23)

| Check | Result |
|---|---|
| Each client sees the other player plus 3 bots as puppets | ✅ 4 puppets on each client (1 remote player + 3 bots; your own rig is never a puppet) |
| Puppets run, jump, and slide at the right speed, animated | ✅ |
| Focus parts visible to a client | ✅ 0 |
| Moving > 600 studs apart | ⚠ puppets freeze in place and stop animating. **Expected spike gap:** the spike only stops sending updates. The design (§6.4 "Leave / despawn", §6.5 visibility) sends a reliable release when a body leaves the visibility set, and the viewer hides or removes the puppet. Build that in the real implementation. |

**CP4 verdict (motion half): PASS.** Remaining: customization on puppets (needs the art folders in the copy),
and 59 bots on a phone (needs a private publish).

### CP5 — cheat smoke test, automated (2026-09-23)

**Setup:** Studio Play in the published private place `Venture[ReplicationSpike]`, driven through the MCP.
Every uplink sample passes these checks, in order:

1. an exact-size check, done before decoding;
2. a token bucket (90 samples/s);
3. `SpikeMovementRules`, a pure enforcement module.

Only the **accepted** position reaches the focus, the relay, and every viewer. A clamp of more than 2 studs
sends the owner a reliable `Correction`.

Exploits are forged in the client's uplink the way an executor would do it (`ReplicationSpikeExploit`). The
real rig is never moved by the forgery. Respawn between runs.

**Harness notes.** With the Input Action System on, the PlayerModule re-issues `Humanoid:Move` every frame,
even on an unfocused client. Automated walking therefore uses `MoveTo`. An automation hook
(`SpikeTrigger`) fires the real slide and wall-hop code paths.

**Honest baseline, run first on every build:** walk → slide → walk → slide → slide-jump over about 100 studs
produced **0 movement violations and 0 corrections**. Both slides were granted from **server-derived**
speed (18.2 and 14.8 studs/s). `StaleGap` also counts session-start and client hitches, so it is a signal
for the judge, not an enforcement action.

| Attack (forged uplink) | Caught by | Outcome for the cheater |
|---|---|---|
| **Speed:** +30 studs/s, sustained | Speed (window budget), corrections | Horizontal **22.2 studs/s** against 16.1 honest. Capped at the envelope, but **~38 % gain remains** (see finding 2) |
| **Teleport:** a 40-stud jump every 2 s | Speed, corrections | The jumps are clamped. The gain is only the envelope allowance |
| **Fake state:** claim slide forever from a standstill | SlideState (entry denied), Speed | Held to the **running** envelope. **Before the fix it gained 100.9 studs in 3 s** (finding 1) |
| **Fly:** claim `grounded` while rising 10 studs/s | GroundedClaim (server raycast), Fly (apex cap) | **0 height gained** |
| **Noclip:** claim a position 2.5 studs behind the nearest wall | Noclip (sphere sweep), 100/100 | The rig never entered the rock (it stayed 3.9 studs outside the face) |
| **Lag switch:** silent 2 s, then resume 30 studs ahead | StaleGap (each silence), Speed (gap credit capped at 250 ms) | About **6 studs per silence instead of 30** |
| **Flood:** 10 extra samples per frame plus malformed packets | Flood (token bucket), Malformed (size check before decode) | 803 dropped, 101 rejected before decode. No movement effect |

**Findings:**

1. **Found live: a state claim with no entry conditions is an exploit.** The first rules version let a
   stationary cheater *claim* the slide state and gain the slide envelope (100.9 studs in 3 s). This is
   the red team's CRITICAL R1. The fix is slide **entry conditions**, judged once on the transition:
   - server-derived speed ≥ 10 studs/s;
   - a 300 ms anti-spam cooldown.

   It was verified against the honest baseline.
   - A first attempt with an invented 1 s cooldown **flagged honest play**.
   - Rule: every envelope and entry condition must come from the **same tuning constants the movement code
     uses**, never from numbers made up in the validator.
2. **Max-envelope abuse is real.** A speed cheater is clamped to the envelope, but still gains about 38 %
   over honest walking (25 % slack plus the constant 2-stud tolerance). The real build needs:
   - tighter slack, derived per state from the real constants;
   - the tolerance scaled by time, not a flat 2 studs;
   - `AntiCheatServiceServer` flagging sustained time at the cap (the "judge").
3. **The momentum decay rule removed a false-positive class.** Honest players coasting out of a slide are
   never flagged: the permitted speed decays at 80 studs/s², and each window entry keeps the allowance it
   earned under its own state.
4. **Not covered by the spike, by design:**
   - timestamp and backtrack attacks (the spike stamps samples on server arrival; client timestamps and the
     render-clock tracker come with lag compensation);
   - server-granted actions and phases;
   - impulse trajectories (knockback floors);
   - correction acknowledgement ids (the spike snaps instead of blending).

   These all need the combat and lag-comp layers, which are specced in §6.9 and §7, and are the real
   build's job.

**CP5 verdict: PASS for movement enforcement.** Every forged movement attack was clamped, rejected, or
flagged, and the honest baseline stays clean.

### CP3 — voice, published private experience (developer, 2026-09-23)

**Route 1, client-wired voice: ✅ WORKS.** Setup: `EnableDefaultVoice = false`, `UseAudioApi = Enabled`, and
a server-created `AudioDeviceInput` per player. Each client wires every remote player's replicated input to an
`AudioEmitter` on that player's **puppet head**, and listens through its own camera `AudioListener`. Two real
accounts heard each other, spatially, with volume falling off with distance.

- **O2 decided: the client-wired route.** It leaks no positions. The server speaker-part route is not needed.
- **Voice does not trigger B′. Option A holds** through CP1–CP3.

**Setup gotcha:** the second account first saw "experience not available". Private experiences need that
collaborator to have Play/Edit permission, and there is a known bug where the default Tester role can't join.
Giving the account Edit fixed it.

**UX findings (expected, fixed in the spike):**

1. **Range felt too large.** The engine's default `AudioEmitter` falloff is generous. The fix is
   `SetDistanceAttenuation`, tunable through the `ReplicationSpikeVoiceFull` (10) and
   `ReplicationSpikeVoiceRange` (80) attributes.
2. **No microphone icon above heads.** The engine's speaking indicator belongs to default voice plus an
   engine character, so under A we draw our own: an `AudioAnalyzer` on each remote mic drives a
   BillboardGui icon on the puppet head.

**CP3 retest (developer, 2026-09-23):**

- The proximity range of **full to 10 studs, silent at 80** is approved ("perfect").
- The custom speaking icon worked, but the developer **chose not to ship it**, so it was removed from the
  spike. It is noted here as proven-feasible (a per-remote-mic `AudioAnalyzer` driving a head
  BillboardGui) in case it's wanted later.

**CP3 verdict: PASS.**

### CP4 — customization half, automated single-player (2026-09-23)

Under option A, CustomizationServiceServer's `observeCharacter` path never fires, because there is no server
character. The spike proves the §8 replacement.

**How the spike does it:**

- **The real `CustomizationApplication` module runs on the client, unchanged.** Its only dependencies are
  ReplicatedStorage modules, so the server clones it into ReplicatedStorage and clients require it.
- **Appearance is published per player.** The server reads it through the live service and fills defaults on
  a **copy**, never mutating the profile. It is published as a replicated attribute. The real build ships it
  on the reliable slot table.
- **Clients apply it** to their own rig and to every puppet. Puppet parts are forced back to no
  collide/query/touch after mounting.

| Check | Result |
|---|---|
| Owner rig dressed client-side | ✅ applied 1, failed 0, **no warnings**: hair (Hair9), eyebrows, boots, from the defaults-filled appearance |
| 59 bot puppets (Studio client, 1 player) | ✅ 2,579 records/s (~44 updates per bot per second under the 700 B cap via round-robin), **100 % interpolating**, focus still leak-free |
| Puppets of *other players* dressed | ⏳ needs two real accounts |

**For the real build:**

- **Move** `CustomizationApplication` into `ReplicatedStorage/Shared`. The spike's cloned copy needs a
  documented cast at the dynamic require.
- **Ship appearance on the reliable slot table**, not an attribute.

### CP4 — 59 bots on PC and phone (developer, published), plus three fixes (2026-09-23)

**Developer run:**

- **PC:** 59 bots perfect. The microprofiler and performance stats were clean, at 100 % interpolating.
- **Phone:** not laggy, but interpolating dipped (30 %, 5 %, 60 %).
- **Both:** visible "teleporting / glitchiness", which looked like "route done, they TP around" rather than lag.
  Spam-sliding also glitched.

**Root causes, measured rather than guessed:**

1. **Bot teleports came from the bot SOURCE data, not replication.** Bots followed the ground with a
   downward raycast and snapped onto railings, walls and roofs: **640 jumps over 2 studs across 56 of 59
   bots in 10 s, the worst 79 studs.** Replication was faithfully showing them.
   - **Fix:** bots walk on a flat plane at spawn height.
   - **Result:** **0 puppet moves over 3 studs per frame** in 4 s with 59 bots.
2. **Spam-slide snaps were a client/server rules mismatch.** The client stand-in let you slide from a
   standstill or back-to-back, and the server's rules refused it. The refusal clamped the player, and the
   correction snap showed up as a teleport on every screen.
   - **Fix:** the owner checks the **same** `MovementRules` entry conditions before sliding (a shared module,
     with a +2 studs/s margin because the server judges from its own derived speed).
   - **Result:** **32 presses in 3 s while running, 0 corrections.**
   - **Design rule confirmed:** the rules module is shared, and the owner never attempts what the server
     would refuse.
3. **Phone interpolation dips came from a fixed 100 ms delay against real mobile jitter.**
   - **Fix:** a spike version of the §6.6 adaptive delay. It grows 6 ms per late frame (up to 250) and
     shrinks 15 ms/s back to the floor. The readout now shows the live delay.
   - **To re-verify on the phone.**

**Leftover false flag (no correction):** sliding past an edge produced `GroundedClaim` / `SlideState` flags.
The server's grounded check is one thin ray under the root, and it misses when the feet are on an edge. The
real build uses a **wide shapecast** of the foot footprint for grounded checks (§7), and this confirms why.

### CP4 — phone rerun, the delay fix done properly, and a PC stress / fidelity harness (2026-09-23)

**The phone rerun exposed two spike bugs:**

1. **The adaptive delay sat pinned at 248 ms with 85 % interpolating.** v1 grew a delay measured from
   server time and capped it at 250 ms, so it could never cover a phone's one-way latency. **Fixed as the
   spec intends:**
   - **Target** = p97(**lateness**) + p90(**gap**) + 8 ms. *Lateness* is the time from sample to arrival on
     this client; *gap* is the time between consecutive samples of the same body.
   - **Behaviour:** it rises to the target at once, falls at 15 ms/s, and is capped at 600 ms.
   - A second bug was found while testing this: "render time older than the whole buffer" was counted as
     *late*, a runaway loop that pinned 600 ms. It is now a separate `behind` state that snaps the delay
     down.
2. **False enforcement flags on an honest phone player: `GroundedClaim 183 · Fly 64`.** A single thin
   ray under the root missed ground on edges and stair lips, so the player was deemed "airborne". Walking
   up stairs "while airborne" then exceeded the jump apex and read as Fly. **Fixed:** grounded is now a
   footprint `Blockcast` (2.2 × 1.6).

**Fidelity harness.** The bots' motion is a shared pure function, so each viewer measures
|rendered − true position at render time| for every bot, every frame.

| PC stress, 59 bots, Studio | Result |
|---|---|
| Interpolating | **100 %** |
| **Position error vs true path** | **mean 0.013 · p95 0.014 · max 0.33 studs** (the max is at jump take-off and landing) |
| Network (loopback) | lateness p50 42, p97 62 ms; per-bot sample gap p90 34 ms; delay target ≈ 104 ms |
| Bandwidth | about 2,560 records/s into one viewer (≈ 41 KB/s) through the 700 B cap by round-robin |

**CPU breakdown for 59 puppets (client):**

| Piece | Cost per frame |
|---|---|
| Our pipeline: decode, Hermite evaluate for 59 bodies | **0.045 ms** |
| LocomotionAnimator refresh, all 59 in one frame (now staggered) | ≈ 1.6 ms spike, per 0.1 s |
| **Engine moving the rigs** (`BulkMoveTo`, real movement), **full StarterCharacter, 106 parts each** | **3.0–4.6 ms** |
| Same move, **limb-only rigs** (16 parts each) | **1.3 ms** |

**Verdict on "is it worth the complexity":**

- Fidelity is essentially exact, and our own code costs well under 0.1 ms.
- The dominant client cost is the **rig's weight**. The package carries 106 parts, 19 ParticleEmitters, 8
  lights, 4 trails, 8 GUIs, 90 textures, 90 WeldConstraints, and leftover old-game values (`Conditions`,
  `BankoraiOffset`).
- Native replication would pay the same per-rig transform and animation cost. It just hides it inside the
  engine, and gives no way to reduce it.

**For the real build:**

- **Puppet LOD:** a lighter visual for far puppets (limb-only past N studs, with effects stripped), and
  animation rate by distance and screen. That lever *only exists because* puppets are ours.
- **Track the rig clean-up** with the rig redo, which also benefits the owner rig and every native system.

### CP0 real-network half + CP4 phone, rerun on the fixed build (developer, published, 2026-09-24)

**Phone, 59 bots:**

| Measure | Result |
|---|---|
| Interpolating | **100 %** (lowest seen: 97 %) |
| Delay | **settled at 84 ms, equal to its target** |
| Lateness | p50 41, p97 42 ms |
| Sample gap | p90 33 ms |
| **Fidelity against the true path** | **mean 0.013, p95 0.014, max 0.40 studs** |
| Puppet CPU | **1.7 ms/frame** |

**CP0 (real network) and CP4 (phone): PASS.**

**Remaining false flags (`Fly 130 · GroundedClaim 129`, 0 corrections) were traced to the CLIENT.**

- **Diagnostics:** the server now records where each ground miss happens. A 20 s random walk with jumps
  in Studio reproduced 32 GroundedClaim misses. **All of them were in Freefall, 5.6–8.2 studs above real,
  colliding ground.** The server was right.
- **Cause:** the spike client derived `grounded` from `Humanoid.FloorMaterial`, which **lags a jump by
  several frames**. Mid-jump samples still read `floor=Plastic`.
- **Fix:** `grounded` now comes from the Humanoid **state machine** (not Jumping / Freefall / FallingDown /
  Flying / Ragdoll) *and* the floor material.
- **Rule for the real build:** every field the owner reports must come from the most authoritative local
  signal. The validator can only be as right as its inputs.
- **Re-verification is pending** (the Studio Play start hung at the time of writing).

### Grounded-flag fix verified (2026-09-24)

The same 20 s seeded random walk (11 jumps): **0 GroundedClaim, 0 Fly, 0 corrections**, against 32 / 6
before the fix. Only session-start and hitch `StaleGap` entries remain.

### CP8 — server load, 60-player equivalent (automated, 2026-09-24)

**Setup:**

- 59 bots fed through the **full validation path** (every `MovementRules.check`, with the real Blockcast
  ground / Spherecast sweep / wall-ray world queries).
- 59 **virtual viewers** whose batches are built exactly like real ones (relevance filter, round-robin,
  header, copies) but not sent.
- 1 real player.
- Server: Studio on the developer's PC.

| Measure | Result |
|---|---|
| Validation | **≈ 2.8 ms/frame** (p95 ≈ 4.2), 3,600 checks/s ≈ 50 µs each |
| Fan-out, 60 viewers | **≈ 4.7 ms/frame** (0.46 ms with 1 viewer) |
| **Total replication server cost** | **≈ 7.5 ms of a 16.7 ms frame (≈ 45 %)** |
| Server frame rate | 60 fps held; worst frame 19.5 ms |

**Finding: the first measured scaling risk.** Production servers are likely slower per core than a dev PC.
Planned fixes for the real build:

1. **Validate at ≤ 30 Hz per owner** (every other sample). The window budgets are time-based, so accuracy
   is unaffected.
2. **A spatial hash for relevance**, instead of 60 × 59 distance tests per frame.
3. **Relevance lists reused** across frames (they change slowly).
4. **Cached ground results** per surface patch (spec §7 already suggests it).
5. **The fan-out budget watched in F4.**

Target: **< 3 ms/frame** at 60 players.

### Chickynoid study (public MIT library): what transfers

- **It has no player-vs-player collision.** Other players exist only as server-side raycast boxes. The
  reason: players are only ever seen in the past, and rollback can't replay moving targets. That is our
  exact problem, so there is no precedent to copy.
- **Transfers to the real build:**
  1. **A clock-budget speed check.** The client's summed dt may not run more than 150 ms ahead of server
     time, with drop / reset rules. This formalises §6.3's drift-slope check.
  2. **One redundant previous sample per uplink packet.** This lets the server tell "a good drop" from "a
     bad drop".
  3. **A visual-only correction offset.** Snaps are applied to the model and decay, never to the physics
     state. This improves on the spike's snap.
  4. **The rewind API shape:** push every other target to time *t*, test, then pop. Unlike Chickynoid,
     **validate the requested time** against RTT and delay.
  5. **A shared encode cache** if per-recipient deltas are ever added.
- **Does not transfer:** deterministic resimulation and rollback, its custom Minkowski hull collision, and
  server-simulated movement.

### Queued follow-ups, as separate tasks AT THE END of the checkpoint work (developer request, 2026-09-24)

1. **Project skills** for venture-game-systems' repeatable patterns: add a service (lean literal +
   discovery + spec), add a data slice, add a ByteNet namespace, spec-first TDD + SpecRoots, read-only
   Studio inspection, and the spike workflow.
2. **A/B cost comparison** of this system against native Roblox replication and against the
   Camera-trick baseline, on equal content.
3. **Latency and scaling improvements** (queued 2026-09-25, after the CP9 analysis):
   - **the error-driven priority scheduler.** Near, moving, most-wrong puppets are updated every frame
     under the 700 B cap. This removes the 47 ms turn-taking gap measured at 59 bots.
   - **a cheaper delay:** target the p90 lateness instead of p97, plus a capped velocity-based look-ahead
     (records carry real velocity, so brief extrapolation is accurate). Measure the extrapolation rate
     with the existing readout.
   - **release by unparenting** (`Parent = nil`, instance kept) for out-of-range bodies, instead of
     destroy and rebuild. Returning is instant, with no rebuild churn.
   - **update-rate bands by distance**, as the scheduler's floor.
   - **a lighter far-puppet rig** (a 16-part limb-only body beyond N studs). This belongs with the rig
     redo: an `AnimationConstraint` rig with ragdoll sockets built in.
   - **Measure** at 59 bots and at a realistic ~20 nearby players.

### CP7 — player-vs-player collision, automated half (2026-09-24)

**Model:**

- **Owner-side only**, against the **rendered** puppet positions (what the player sees; never extrapolated).
- **No server involvement.** The server is at most a referee: sustained deep overlaps in history get
  flagged.

**Modes** (`ReplicationSpikeCollision`):

- **`soft`:** a cylinder push-apart, contact 2.3 studs, K = 25/s, capped at 8 studs/s (half WalkSpeed), so a
  crowd can be squeezed through but never walls you in.
- **`hard`:** a solid capsule per puppet, touching only the local rig through collision group
  `SpikePuppetCollider` ↔ `Players`.
- **Both:** a **one-way head cap** you can stand on, carrying the puppet's velocity.

**Automated results:**

- **Head cap: ✅.** Dropped from +9, the owner settles standing on the bot's head (+6.1 above its root,
  Running).
- **Hard: ✅ blocks**, as designed.
- **The first head-cap version was always solid.** It sat exactly at torso height, so walking into anyone
  hit a plate and blocked. It is now **one-way**: solid only while the owner's feet are above it.
- **Soft: inconclusive in automation.**
  - `Humanoid:MoveTo` **cancels itself whenever the root is repositioned**, so every push-apart nudge
    stopped the scripted walk. Real players steer by move input, not MoveTo.
  - The IAS PlayerModule overrides `Humanoid:Move` on the unfocused test client.
  - **Soft-mode feel needs the developer's hands-on test.**

**Design note for the real build:** apply separation through **the movement system's input vector**:

- remove the component pointing into the puppet;
- add a small outward bias.

That is instead of CFrame nudges. The Movement phase owns input anyway, and this cannot fight MoveTo,
IAS, or physics. The spike's CFrame nudge only stands in for it.

### CP7 — developer verdict on soft/hard, and the SOLID A/B (2026-09-24)

**Developer verdict (hands-on):**

- **Soft: rejected.** It clips by design (you always out-walk an 8 studs/s push), which reads as a bug in
  Venture.
- **Hard: closer, but it still clipped.** Two causes:
  - the stand-in was 1.9 studs wide against the rig's paper-thin colliding parts, so bodies overlapped
    visibly;
  - the one-way head cap sat at +6.1 above the root, but the **measured head top is +1.53**, so it floated
    about 4.5 studs above the head.
- **Standing on or jumping from a head glitched.** Server evidence: **Fly 261 · GroundedClaim 8115 ·
  93 corrections**. The server's rules didn't know players are solid, so standing on one looked like
  hovering and jumping from one looked like a super-jump. Every correction snapped the player down.
- **Head-standing is not wanted.** Old Venture's `PlayerHitbox` cylinders slide you off, and that feels
  right.

**The rule this establishes:** anything a client can collide with, the server's movement rules must
also count as solid. A client-only surface is a correction generator.

**Measured rig** (root-relative, studs):

- feet bottom −4.05, head top +1.53 (5.6 tall);
- shoulders ±1.05, hands ±1.33;
- old `PlayerHitbox`: 3.0 × 6.2 × 3.1, from −4.15 to +2.05, so about 0.4 studs oversized all round. It
  is in group `Cylinder`, which collides only with itself.

**SOLID A/B.** Nobody simulates anyone else's body: each client collides its own body against where it
*sees* everyone else, and puppets are immovable obstacles. Shapes are data in `SpikePlayerCollider`, and
the knobs are Workspace attributes read live:

| `ReplicationSpikeColliderShape` | Models | Construction |
|---|---|---|
| `capsule` (default) | the common modern character-vs-character shape | cylinder + two spheres, radius 1.1, feet to head top; a massless twin welded to your own root; group pair `SpikePuppetCollider` ↔ `SpikeSelfCollider` |
| `box` | the classic axis-aligned hull | a 2.2 × 5.6 × 2.2 box that never turns; flat top, so heads are standable |
| `hitbox` | old Venture as-is | a copy of `PlayerHitbox` per puppet, group `Cylinder`, against the rig's own |
| `body` | anchored remote bodies as static colliders | the puppet's own world-colliding parts (group `SpikePuppetBody` ↔ `Players`) against your rig's parts |

- `ReplicationSpikeColliderStance` (default true) shrinks the capsule and box to 3.0 tall while sliding.
  The puppet's state word carries the slide.
- `ReplicationSpikeCollision = "off"` disables all of it.
- **Server:** in `solid` mode, `groundBelow` also counts another body's collider top under the feet,
  using the same extents. Standing on or sliding off a player is not a correction.

**Automated walk** straight at a frozen bot, aimed 0.3 studs off centre:

| Shape | Closest approach, root to root (visible contact ≈ 2.2) | Result |
|---|---|---|
| capsule | **2.18**: touching, 0.02 clip | blocked head-on (a round body, pushed dead-centre; a steering player rolls off) |
| box | 2.37 | slid along the flat face and past |
| hitbox | **3.08**: stops about 0.9 studs before the bodies touch | slid round and past |
| body | **1.11**: about 1 stud inside the other body | passed through the gaps between limbs. **ClimbState 268**: the Humanoid *climbs* other players' parts, and the server rightly flagged it |

Server corrections: 0 for all four.

- **Early reads:**
  - `body` is out: it clips, and it turns other players into ladders.
  - `hitbox` never visibly clips, because it stops early, but the gap is visible.
  - `capsule` is the tightest fit.
- **Hands-on feel is the developer's call.** Head/jump behaviour on `box` and while sliding can't be
  automated reliably.
- **Harness note:** frozen bots 4 and 5 hang over a drop at the flat bot plane. Test against bots 1–3.

#### CP7 follow-up: developer test of the A/B, and three changes (2026-09-24)

- **Developer finding (capsule):** you usually slide off heads and are always in Freefall, since you can't
  really stand. The head-jump glitch doesn't reproduce. But **a dead-centre landing sometimes balances
  on the apex.**
  - **Cause:** the Humanoid never treats a blocker as floor (the blocker groups don't collide with the
    root's `Players` group), so it sits in Freefall. Nothing pushes it off a perfectly balanced contact.
- **Change 1: slide-off push.** While your feet rest on a blocker whose shape is not `standable`, your
  root gets an outward velocity of at least 12 studs/s away from the other player's centre (your facing,
  if dead-centre). Engines that forbid standing on characters do the same. `standable` is data per shape:
  `box` true (the classic hull allows head-standing), the rest false.
- **Change 2: frictionless blockers** (`CustomPhysicalProperties` friction 0, FrictionWeight 100).
- **Change 3: debug drawing.** `ReplicationSpikeColliderVisible = true` draws blockers: others red, yours
  blue.
- **Renamed** shape `hitbox` → **`legacy`**, and adopted a vocabulary:
  - **world collider:** you vs the map;
  - **blocker:** player vs player, client-side;
  - **hurtbox:** where attacks can hit you, server-side and rewound;
  - **hitbox:** the attack's own volume.

  Old Venture's `PlayerHitbox` is a blocker by that vocabulary.
- **Freefall T-pose (analysis only; the fix belongs to the animation system, not this spike):**
  - `Animate.client.luau` forwards `Humanoid.Jumping` / `FreeFalling` to `LocomotionAnimator:handleEvent`.
  - A `freefall` event inside the 0.31 s jump window is **dropped** (`if now >= jumpUntil`).
  - `FreeFalling` fires once on entry, which is about 0.1 s after `Jumping`, so after any jump the fall
    pose is never set.
  - The non-looped jump animation ends, and the rig T-poses until it lands. That's why it shows up on
    long falls and while balanced on a head, with the state still reading Freefall.
  - The stock Animate script avoids this by polling each frame (`if pose == FreeFall and jumpAnimTime <= 0
    then play fall`).
  - Also: the handler ignores `FreeFalling`'s `active` argument, so *leaving* freefall also sends
    `freefall`.
  - Puppets inherit both problems, because they drive the same core.

#### CP7 follow-up 2: freefall measured, Humanoid dependency, validation per ability (2026-09-24)

**Freefall T-pose: measured in the developer's session.**

- Timeline: `Jumping` at 0.013 s, then **`FreeFalling(true)` at 0.031 s**, 18 ms later and inside the
  0.31 s jump window, so it is dropped.
- For the whole airtime only the jump track plays: 9126863232, **1.20 s long, not looped**.
- The fall track (11525896362) starts only at **landing**, because `FreeFalling(false)` is also forwarded
  as "freefall", now outside the window.
- **Consequence:** any airtime longer than 1.2 s after a jump T-poses, and every landing flashes the fall
  pose. Tracked as a separate task, not the spike.

**Humanoid dependency.** Tracked in Peek-Abu/venture-game-systems#26.

- **Decision for the real build:** the wire record and the rules carry a Venture `MovementState` enum, not
  `HumanoidStateType` values.
- A Humanoid adapter maps into that enum today, and a `ControllerManager` or custom controller can map
  into it later.
- Animation consumes the same enum.

**Validation per ability, made systematic (proposal, owned by the enforcement layer):** abilities never
write rules; they declare a **motion grant** as data, the same constants their client code uses.

- There are a handful of generic grant kinds:
  - `speed`: raise the horizontal cap for N ms;
  - `impulse`: a velocity kick, bounded by a ballistic trajectory;
  - `toPoint`: move to a target the server can check (grapple, blink);
  - `free`: server-scripted motion such as cutscenes or knockback the server itself applied.
- `SpikeMovementRules` becomes a generic judge of "base locomotion ∪ active grants".
- A new ability means one data entry plus requesting the grant, with zero validator code.
- An ability that fits no kind gets a new *kind* (a rare, reviewed change), never a one-off rule.
- The slide is already this shape: its entry speed and cooldown are shared constants.

**Server rules, second pass:**

- Rounded tops (capsule, legacy) count as ground anywhere on the dome, down to one radius below the apex.
  Before, jumping off a shoulder read as Fly: the developer session showed Fly 86.
- Other players count as walls for the climb check: the session showed ClimbState 21 against players.

#### CP7 follow-up 3: `legacy` vs `capsule` slide test, and the single-part cylinder (2026-09-24)

**Developer test.** Sliding into a bot:

- **`capsule`:** trips into FallingDown with glitchy movement.
- **`legacy`:** does not trip, but deflection is "sporadic", sometimes faster depending on where you hit.
- **Both:** after sliding into someone, **speeding up and jumping** drew a server correction that slowed
  the player and made the height glitch.

**Analysis:**

- **Rounded bottoms lift and tip.** The spike's slide is a planar `LinearVelocity`, 55 studs/s at
  MaxForce 1e6. Against the capsule's bottom sphere, the contact normal has a vertical component, so the
  push becomes lift and torque, and the Humanoid falls. Straight walls push only sideways.
- **Stance shrink lowered the contact** below the centre of mass, which adds more tipping.
- **Rebuilding a blocker mid-contact** (on slide start and end) spawned it overlapping its neighbour, and
  the solver popped the two apart.
- **`legacy` is a mesh cylinder.** Meshes collide as a faceted convex hull, so a slide is redirected
  along whichever facet it hits. That explains the sporadic deflection. Primitive shapes (Block, Ball,
  Cylinder) collide exactly.
- **The correction is a momentum problem, not a slide-grant problem.** Speed gained from the collision
  and slide was *carried into a jump*. The rules model speed as caps per state that decay over time, so
  they have no notion of conserved momentum: legitimate carried speed reads as Speed, and Y gets clamped.
  - **Validation spec, requirement 1:** momentum is first-class. Horizontal speed at take-off is conserved
    ballistically, with bounded air control, and it is judged as a trajectory, not a per-state cap.

**Change: a `cylinder` shape and the new default.**

- It is **one primitive Cylinder part per player** (plus one welded to you), radius 1.1, from the feet to
  the head top.
- Straight walls: no lift, no tipping. Exact collision: no facets.
- Its top is flat, but heads still aren't standable: the Humanoid never treats a blocker as floor, and the
  slide-off push moves you away.

**Other changes:**

- **Stance sizing is now OFF by default.** It belongs to hurtboxes, not blockers.
- Blockers rebuild only when their size really changes, so there are no mid-contact pops.
- The server's rounded-top ground tolerance now applies only to `capsule`. Flat tops use the rim.
- **Part count:** only one shape is ever live. Cylinder = 1 part per player; capsule = 3, since Roblox has
  no capsule primitive; legacy = 1 mesh. The losing shapes are deleted after the decision.

#### CP7 follow-up 4: the trip is stance resizing, measured (2026-09-24)

**Setup.** The developer's second test ran on code *without* the cylinder change: Rojo had stopped when
Studio was reopened. So "cylinder" fell back to `capsule`, with stance ON (saved `Stance = true`). We
reproduced it by automation: walk at 16 studs/s toward a frozen bot, then trigger the real slide 8 studs
out.

| Shape | Stance | Result |
|---|---|---|
| capsule | on (×2) | **FallingDown** 0.15 s after the slide; flipped 134° / 173°; passed within 0.1–0.4 studs of the bot's centre |
| box | on | **FallingDown**; flipped 139°; launched 8.8 studs up |
| capsule | off (×2) | stopped at contact (2.00 studs), tilt 16–19°, Running |
| box | off | stopped at contact (2.03), tilt 8°, Running |
| legacy | n/a (never resizes) | stopped at 2.56, tilt 16°, Running |

**Conclusion:** the trip is caused by **resizing the blocker while sliding**, not by the shape.

- It is 3/3 with stance on and 0/5 with stance off or `legacy`.
- The earlier "rounded bottoms lift you" theory is **refuted**: capsule with stance off doesn't trip, and
  the legacy mesh is itself pill-shaped.
- **Mechanism (consistent with the numbers, not separately isolated):**
  - `PlayerHitbox` carries 20.6 of the rig's 24.2 mass units, so the centre of mass sits at the hitbox
    centre, root −1.05.
  - A slide-shrunk blocker spans −4.05 to −1.05, entirely *below* the centre of mass.
  - The 1e6 slide force against a contact below the centre of mass flips the body. Once flipped, the
    blockers no longer face each other, so the body passes through.
- **Stance sizing is now off by default** (`373106a`).
- The `cylinder` shape is still untested on a synced Studio.

#### CP7 follow-up 5: performance, moving contact, and a validation "log" switch (2026-09-24)

**Developer feel (all three stance-free):** close. `capsule` preferred. `legacy` "collides with air" (it
is 0.4 studs oversized all round and reaches 0.5 studs above the head).

**Cost with 59 moving bots, all in range at once** (Studio Play, MCP client; two rounds each, ms per
frame):

| Collision | Blocker parts | Physics step | Script upkeep |
|---|---|---|---|
| off (baseline) | 0 | 5.1 / 5.3 | 0.9 / 1.0 (the spike's per-frame scan) |
| cylinder | 59 | 7.8 / 7.2 (**+2.0–2.7**) | 2.9 / 2.6 (**+1.6–2.0**) |
| legacy | 59 | 8.3 / 8.0 (**+2.7–3.2**) | 3.1 / 3.3 (**+2.1–2.3**) |
| capsule | 177 | 11.1 / 12.4 (**+6.0–7.1**) | 5.4 / 5.6 (**+4.4–4.6**) |

- **Reading:** cost scales with **parts moved per frame**. The capsule is about 3× the cylinder because
  it is 3 parts. `legacy` (one mesh) sits between them.
- **This is the worst case the real build avoids:**
  - blockers are welded into each puppet and moved by the puppet's existing `BulkMoveTo`, so there is no
    per-part CFrame or velocity writing;
  - blockers are solid only within about 20 studs of the local player. In play that is typically 0–5
    blockers, not 59.

**Moving contact.** Walking head-on into a moving bot, three shapes × two rounds:

- no state changes;
- speed during contact stays at walking speed (16–17 studs/s);
- tilt ≤ 8°;
- 0 corrections.

**One unreproduced outlier:** standing still in a bot's path with `legacy` once measured **41 studs/s
horizontal and 41 up**, a fling, while the bot passed 0.85 studs away, probably mid-jump. It did not
recur in the head-on runs. The two-player test should watch for it.

**Validation switch for diagnosis:** Workspace `ReplicationSpikeValidation = "log"`.

- The server judges and counts every sample exactly as before, but never corrects.
- The client's position is taken as-is, and the track follows it.
- This separates "the rules are wrong" from "the physics is wrong". For example: the slide → collision →
  jump snap should vanish in `log` if it is the momentum rule, as §follow-up 3 predicts.

**Blockers vs animation, a design position:**

- Blockers deliberately do **not** follow animation. A body-following collision volume is unstable
  (limbs sweep into neighbours) and produces exactly the trips seen with `body`.
- Animation-accurate volumes are **hurtboxes**: per-limb, server-side, rewound for lag compensation.
- Blockers may change between a few **stance profiles**, chosen by `MovementState`, only at state
  transitions. They grow only when there is room (a clearance check before standing back up), and they
  keep the centre of mass inside the blocker.
- The measured trip (follow-up 4) came from breaking that last condition under a 1e6-force slide mover.

#### CP7 follow-up 6: blocker benchmark — shape × mount × range (2026-09-24)

**Knobs added:**

- `ReplicationSpikeColliderMount`:
  - `separate`: each part anchored and CFrame-written on its own;
  - `welded`: one anchored part, the rest welded to it;
  - `puppet`: welded into the puppet's anchored assembly, so its existing `BulkMoveTo` carries it.
- `ReplicationSpikeColliderRange`: blockers farther than this are non-solid.
- Shape **`union`**: the capsule unioned once on the server (`SpikeCapsuleUnion`, fidelity Default).
- Debug painting now runs only on change.

**Benchmark.** 59 moving bots, Studio Play, MCP client, two rounds. The baseline with collision off is
physics 4.84–4.92 ms and script 0.97–1.00 ms. Figures below are **deltas over that baseline**, per frame:

| Shape | Mount | Range | Solid parts | Δ physics | Δ script |
|---|---|---|---|---|---|
| cylinder | separate | all | 59 | +2.5 / +2.6 | +1.7 / +1.5 |
| cylinder | puppet | all | 59 | +1.4 / +1.7 | +1.2 / +1.4 |
| **capsule** | **separate** | all | 177 | **+5.9 / +6.5** | **+4.0 / +3.8** |
| capsule | welded | all | 177 | +1.8 / +2.9 | +1.3 / +1.8 |
| **capsule** | **puppet** | all | 177 | **+1.7 / +1.6** | **+1.0 / +1.2** |
| union | separate | all | 59 | +2.5 | +1.6 |
| union | puppet | all | 59 | +1.6 / +1.5 | +1.2 / +1.2 |
| legacy | separate | all | 59 | +2.2 / +2.5 | +1.6 / +1.7 |
| capsule | separate | 20 | 12 | +1.0 | +0.6 |
| capsule | welded | 20 | 6 | +0.4 | +0.3 |
| **capsule** | **puppet** | **20** | 15 | **+0.4** | **+0.3** |
| cylinder | puppet | 20 | 4 | +0.3 | +0.3 |

**Findings:**

1. **The capsule's cost came from moving its three parts separately, not from having three parts.**
   Welded into the puppet, 177 capsule parts cost the same as 59 cylinders or 59 unions, within run-to-run
   noise.
2. **A union buys nothing:** it costs the same as the welded capsule and collides as a faceted mesh.
3. **Range gating is the biggest lever:** from roughly +1.5 ms to **+0.3–0.4 ms**. The remaining script
   delta is mostly the spike's own per-frame scan and distance checks.
4. **Decision candidate:** a primitive **capsule, welded into the puppet, solid only within about
   20 studs**. That gives the preferred feel at cylinder cost.

#### CP7 close-out (2026-09-25)

- **Developer feel check:** capsule, welded into the puppet, solid within 20 studs. "Everything looks
  perfect."
- **`log` retest:**
  - The slide → collision → jump **snaps never happened** with corrections off.
  - That confirms the snap came from the **server rules** (the missing momentum model, follow-up 3), not
    from physics.
  - Owner: the validation spec.
- **Two players:** one moving, one still, was tested by hand. Both moving at once hasn't been: the MCP
  cannot drive a second client (Studio's multi-client windows don't register with it).
  - **What that test would add beyond the bot runs:** each client resolves only its own body, so
    one-sided contact is fully covered by walking into moving bots.
  - **What's left is the asymmetry:**
    - Each player collides with the other's past, about 1.6 studs behind at running speed.
    - A runner can be *stopped* on their own screen while *shoving* the other player on the other screen.
    - Bots are the worst case of this, because they never stop.
  - **Suggested check (low priority, before the real build ships):** PC plus phone on the second
    account, run into each other.
- **CP7 status: decided.**
  - A primitive **capsule** blocker (cylinder + two spheres), welded into the puppet assembly;
  - solid only within about 20 studs; no stance resizing;
  - slide-off push; frictionless;
  - the server rules count players as ground and walls, from the same size table.

### CP9 — native A/B, viewer cost (automated half, 2026-09-25)

**Setup:**

- **Same content both ways:** 59 full StarterCharacter rigs (106 parts each) walking identical
  `SpikeBots` paths.
- **A (ours):** `ReplicationSpikeBots = 59`.
- **B (native):** `ReplicationSpikeNativeBots = 59` (`NativeBotsCP9.server.luau`).
  - Server-owned Humanoids steered along the paths.
  - A server-played run track.
  - An invisible floor that only they collide with, so they cross the same walls and drops as the puppets.
- Each side ran in a **fresh** session: in a shared session, the puppets from A would stay in the world
  frozen, because despawn is CP10.
- Measured on the MCP client: `Stats.HeartbeatTimeMs` and `PhysicsStepTimeMs`, two rounds of 6 s each.
- **Not measurable in Studio:** receive bandwidth (the local connection reports 0 KB/s) and render cost
  (the MCP client doesn't render).

| Session | Heartbeat | Physics | Sum | Δ over empty |
|---|---|---|---|---|
| empty (no bots) | 0.69 | 1.50 | 2.18 | — |
| **A ours, `BulkMoveTo`** | 7.9 | 5.0 | 12.9 | **+10.7** |
| **B native** | 0.97 | 7.2 | 8.1 | **+6.0** |
| **A ours, `motor`** | 1.55 | 6.45 | 8.0 | **+5.8** |

**Breakdown of A with `BulkMoveTo`**, per frame:

- evaluate 0.21–0.27 ms;
- animation feed 0.20–0.24 ms;
- **engine move 6.3–6.8 ms, which is 95 % of our cost.**

Teleporting 59 anchored 106-part assemblies every frame is the expensive path.

**Correction to the CP4 verdict.** "Native replication would pay the same per-rig transform cost" was
**wrong**: the engine moves replicated assemblies far more cheaply than `BulkMoveTo` does.

**Fix: the `motor` move mode** (`ReplicationSpikeMoveMode = "motor"`).

- Each puppet hangs off a fixed anchored part (`SpikeMoveAnchors`) by a Motor6D, and is positioned by
  writing that joint's `Transform`. That is the engine's own kinematic and animation path.
- Engine move drops to **0.09 ms**, and the viewer total matches native (+5.8 vs +6.0 ms).
- Verified: puppets move at path speed (6.5 studs in 0.5 s); the walk track plays; 13 limb joints
  animate.
- **Gotcha, found by measurement:** the anchor and joint must live **outside** the puppet model. The rig's
  Animator resets the `Transform` of every joint under the model it animates, so the first motor run
  moved 0.00 studs.
- **For the real build:** write the Transform in PreSimulation, after animation, to avoid one frame of
  latency.

**Where that leaves us:** at equal content we're at native parity on viewer CPU. Then we have levers
native doesn't:

- update rate by distance (far puppets at 20–30 Hz);
- lighter far rigs (limb-only: 16 parts instead of 106);
- range-gated collision.

**Still open (developer, published):**

- receive bandwidth, A vs B;
- focused frame time, including render;
- the phone.

The readout now carries a `CP9 client: receive … KB/s · frame … ms (fps)` line.

#### CP9 follow-up: write timing and joint type (2026-09-25)

**Knobs:**

- `ReplicationSpikeDriveOn = "PreSimulation"`: evaluate and write before physics.
- `ReplicationSpikeMoveMode = "constraint"`: a kinematic `AnimationConstraint` (attachment-based) instead of
  a Motor6D.
- The readout adds a **joint placement error**: the root's distance from the last written target, measured
  at Heartbeat.

**Documentation (Motor6D / AnimationConstraint API reference):**

- Motor6D `Transform` is "recommended … for custom animations"; transforms are "applied as a batch in a
  parallel job after RunService.PreSimulation, immediately before physics steps".
- The Animator overwrites `Transform` for joints inside an animated model, which confirms the anchor must
  live outside the model.
- `AnimationConstraint` is documented as the **replacement for Motor6D in R15 rigs**. With `IsKinematic`
  (the default), parts "follow the Transform perfectly without participating in physics simulation".
  Turned off, it is force-based and supports physical simulation, which is a possible ragdoll/knockback
  lever.

**Results** (fresh session each, 59 moving bots, ms per frame; run-to-run noise is about ±0.7 ms on the
physics figure):

| Joint | Drive | Heartbeat | Physics | Sum | Puppet CPU | Placement error | Moved in 0.5 s |
|---|---|---|---|---|---|---|---|
| Motor6D | Heartbeat | 1.85 | 7.30 | 9.15 | 0.71 | 0.0000 | 6.7 studs |
| Motor6D | PreSimulation | 0.92 | 7.68 | 8.61 | 0.74 | 0.0000 | 5.0 studs |
| AnimationConstraint | PreSimulation | 0.99 | 7.84 | 8.84 | 0.78 | 0.0000 | 6.7 studs |

**Reading:**

1. Both joints place the rig **exactly**, and cost the same within noise. The walk track plays on both.
2. PreSimulation moves our work out of the Heartbeat bucket without changing the total.
3. **Its benefit is latency, by documented frame order,** not cost:
   - written at PreSimulation, the Transform is applied in *this* frame's batch and rendered this frame;
   - written at PreRender or Heartbeat, it applies in the *next* frame's batch, one frame (about 16 ms)
     late.

   The MCP client doesn't render, so the frame of latency can't be measured here.
4. **Decision candidate for the real build:** a kinematic `AnimationConstraint` move joint, written in
   PreSimulation. It is the same type Roblox is moving R15 rigs to, and it can later go force-based for
   ragdoll or knockback blending.

**Delay comparison, a correction:**

- The baseline technique's "3-interval playout" (about 33 ms at 60 Hz) is counted from packet
  **arrival**. Ours is counted from the owner's **send**, so it includes one-way latency.
- Like for like, our buffer beyond latency in the 59-bot Studio run was about 124 − 50 ≈ **74 ms**.
- Most of that is the 47 ms p90 gap forced by 59 records per player taking turns under the 700 B cap.
- **Fixes, in order:**
  1. the error-driven priority scheduler, so near puppets update every frame;
  2. a capped look-ahead (render slightly toward live, extrapolate briefly);
  3. re-measure at realistic nearby-player counts.

#### CP9 published run: receive bandwidth, ours vs native (developer, PC, 2026-09-25)

**Setup:**

- Published `Venture[ReplicationSpike]`, one player (the developer), standing near spawn, 59 moving bots.
- **A:** our puppets (kinematic `AnimationConstraint` move joint, written in PreSimulation; capsule
  blockers).
- **B:** native (`ReplicationSpikeNativeBots = 59`).
- Two readout snapshots per side, plus the F9 performance bar.

| Measure | A: ours | B: native |
|---|---|---|
| Readout receive (1 s averages, two snapshots) | **42.5 / 70.1 KB/s** | **102.3 / 190.0 KB/s** |
| F9 bar "Recv" | **94.5 KB/s** | **224.7 KB/s** |
| F9 bar CPU / GPU | 14.4 / 12.9 ms | 16.6 / 10.0 ms |
| Frame | 16.65–16.69 ms (60 fps) | 16.65–16.93 ms (59–60 fps) |
| Client memory | 1627 MB | 1633 MB |
| Records received | 2665 / 2321 per s | — |
| Delay (target) | 117 (117) / 167 (136) ms | — |
| Lateness p50 / p97; gap p90 | 41–44 / 75–94 ms; 33–34 ms | — |

**Reading:**

- **Native costs about 2.4–2.7× our receive bandwidth** for the same 59 moving bodies. Snapshot means are
  about 56 vs 146 KB/s; the F9 bar reads 94.5 vs 224.7.
- Our record stream accounts for the lower snapshot exactly: 2665 records/s × 16 B = 42.6 KB/s.
- Our number is also the **worst case of our scheme:** every bot within 600 studs is sent, under
  turn-taking. The queued scheduler and distance bands reduce it further; native has no such lever.
- **CPU:** both hold 60 fps. The frame CPU bar reads slightly lower for ours (14.4 vs 16.6 ms).
- **Memory:** a wash.
- **Delay:** consistent with the queued fix (follow-up 3). About 75–120 ms of buffer beyond p50 lateness,
  driven by the 33 ms turn-taking gap and the p97 margin.

**Caveats:**

- These are snapshot readings from a single run.
- The native bots are server-owned NPCs, a proxy for player-owned characters reaching a viewer.
- The F9 figures include all other traffic (voice, attributes, assets settling after join).

**CP9 status: measured.** Ours is at native parity or better on viewer CPU (after the `motor`/`constraint`
fix), and uses **about 2.5× less bandwidth**.

### CP6 — ragdoll (automated half, 2026-09-25)

**Design:**

- **Server-granted only.**
  - The owner sends `RagdollRequest` (R, or `SpikeTrigger = "ragdoll"`).
  - The server grants a 2.5 s window plus a 0.4 s get-up grace, and a launch of 45 up and 25 back.
  - During the window the owner's samples are accepted as-is, since a tumbling body has no envelope.
  - At the window's end the track is re-seeded where the body landed.
  - An ungranted ragdoll record is flagged (`UngrantedRagdoll`) and demoted to Freefall.
- **Record variant:** state `STATE_RAGDOLL = 29`. The 33 velocity bits carry a smallest-three quaternion
  (2 + 3 × 10 + 1 spare), so a record is still 16 B.
- **Owner** (`SpikeRagdoll`):
  - every Motor6D except the root joint → a BallSocketConstraint at the same pivot (70° cone, ±45° twist);
  - limbs collidable; a NoCollisionConstraint per jointed pair;
  - Humanoid → Physics, Animate disabled;
  - momentum kept, plus the launch;
  - getting up restores everything exactly and re-enables Animate.
- **Viewers:**
  - the torso (root + LowerTorso) follows the replicated position and **full rotation** kinematically;
  - limbs go limp in group `SpikeRagdollLimb` (world only) and are **simulated locally**;
  - interpolation is linear in position with rotation slerp (a zero-velocity Hermite would stutter).
- **Bots:** `ReplicationSpikeBotRagdoll = true` makes each bot ragdoll 2.5 s out of every 8 (staggered),
  so the viewer side runs without a second player.

**Results:**

| Check | Result |
|---|---|
| Codec round trip, 2000 random rotations | **mean 0.078°, worst 0.198°**; every other field exact; normal records unchanged |
| Viewer, 5 bots over 9 s | each entered and left ragdoll on its 2.5 s schedule; lying flat (90°); 16 sockets per puppet |
| Viewer limbs | 7/7 sampled limbs on their **own physics assembly**; farthest 3.1 studs from the root (attached, no explosion) |
| Owner: request → grant → limp | Physics state; rose 4.2 studs; tumbled to **171°**; carried 18 studs |
| Owner: get-up | at **2.6 s** (2.5 s grant); upright 0°; `Physics > GettingUp > Running` |
| Server during and after | **0 corrections, 0 new violations** |
| After get-up | idle then walk tracks play; 17/17 motors re-enabled; 0 ragdoll leftovers; 16 studs/s |

**Tooling gotcha:** a command-bar `require` of a module Rojo had just updated returned a **stale cached**
copy (it had no `STATE_RAGDOLL`). Require a `:Clone()` of the module to test fresh code.

**Open, for the developer's hands-on test:** the feel of the owner ragdoll (launch strength, limb limits),
and watching another player ragdoll (the bots float at the path height, so their limbs dangle rather
than lie on the floor).

#### CP6 follow-up: developer verdict and the rebuild (2026-09-25)

**Developer verdict on v1:**

- far too loose;
- the launch went in the wrong direction instead of carrying the body's own velocity;
- joints made moves a body can't;
- bots "anchored in place with their parts collapsing into a black hole".

**Root causes, each measured:**

1. **Joint shape.**
   - One 70° ball socket per joint, with the axes copied from the motor frames. Every cone axis sat **90°
     off its limb**.
   - Elbows and knees bent in any direction, and wrists, ankles and even the weapon holders flopped.
   - No joint friction.
2. **Collision and mass.** The rig's own 0.28-stud slabs collided, and the distal limbs weighed about
   0.06 each (shin + forearm + hand = 0.19 total).
3. **Motion.** A fixed launch "up and back" instead of the body's momentum.
4. **The bot "black hole": the viewer's limbs were flung off and deleted by the fall-kill height.**
   - Every puppet was down to 1 of 17 motors within a minute.
   - Refuted in turn, by controlled experiments on the play client:
     - overlapping hulls;
     - crushing a kinematic torso into the floor;
     - CP7's per-frame velocity writes (collision off: same loss);
     - the animated entry pose;
     - NaN momentum input (logged entry velocities were sane).
   - **The actual cause:** `applyMomentum` spun the puppet's torso, which belongs to the **kinematic
     assembly rooted at the move anchor**, parked at the template's original spot. Rotating that assembly
     about the far-away anchor gave about 1.4 rad/s × ~500 studs = 700+ studs/s, and the limbs left at
     **1,200–4,300 studs/s on the first limp frame**. The controlled experiments had their anchor at the
     rig, so there was no lever arm.
   - **Fix:** momentum touches only **simulated** assemblies (`not AssemblyRootPart.Anchored`).

**The rebuild** (Venture's tuned momentum ragdoll, reproduced and checked rather than copied):

- **Joints:**
  - kept rigid: Root, Holder Hinges, wrists and ankles (fused);
  - elbows (5..100) and knees (−100..−5) are **hinges**;
  - hip 60°, shoulder 105°, neck 55° and waist 50° are ball sockets with per-joint twist and friction
    (0.3–2.2), restitution 0.
- **Hinge axes:**
  - the authored knee and elbow orientation put the hinge axis ⟂ the body's lateral axis (axis·bodyRight
    = 0.00), which bends sideways;
  - identity rotation puts it on the lateral axis (±1.00), with flexion signs matching the limits;
  - verified live: knees flex **back** (−1.00 / −0.98), elbows **forward** (+0.09 / +0.07).
- **Collision:** hulls from `ReplicatedStorage.Models.RagdollSkeletonR`, placed via
  `RagdollSkeletonCharacterReal` (whose proportions match this rig exactly), with a density profile.
  - Group `SpikeRagdollHull` collides with the world and itself; a NoCollisionConstraint covers each
    jointed pair.
  - Also exempted: hand↔thigh, the only non-adjacent overlap at rest (measured). It was not by itself the
    explosion.
- **Momentum:**
  - horizontal = max(MoveDirection × WalkSpeed, physics), plus physics Y, capped at 80;
  - random topple, a forward lead proportional to speed, and a 50 % arm splay;
  - the server launch is 0 for a plain ragdoll (`ReplicationSpikeRagdollLaunch` is a test knob for hit
    knockback).
- **Viewer guard:** a puppet goes limp only after its torso has been placed at the replicated pose. A jump
  of more than 8 studs in one frame while limp re-forms the body first.
- **Bots:** they keep their walking velocity, pitch face-down onto the floor, slide to a stop, and are
  eased back onto their scripted path over the last 0.5 s (a harness-only pop removed).

**Verified:**

| Check | Result |
|---|---|
| Owner, ragdoll mid-run at 15.4 studs/s | carried **11.2 studs forward**; worst part spread 4.0; back up and Running; **0 corrections** |
| Bots, 45 s and 40 s runs (~36–39 ragdolls) | **17/17 motors on all 5**; worst limb speed 35–40 studs/s (was 1,200–6,000); lying 0.6–1.1 above the floor |
| Torso jumps over 6 studs in one frame while limp (20 s) | **0** |

**Open:** the viewer readout's "teleports while limp" counter (it compares interpolated *targets*) still
registers about 1 per ragdoll, although the rendered torso never jumps. It is harmless (the guard only
re-forms the body) but unexplained.

#### CP6 follow-up 2: developer notes → changes (2026-09-25)

- **"NPCs teleport after unragdolling":**
  - This is the bot harness, not replication. The scripted path clock kept running while the bot lay down.
  - Bots now **pause their path clock** while ragdolled, get up where they fell, and blend the slide offset
    back onto the path over 0.6 s.
  - `log` validation would not have changed it: validation only judges real owners' uplink.
- **Readout clutter:** **H** toggles every spike readout (LocalPlayer `SpikeHudHidden`).
- **"Head moves way too much":** neck 55° / ±50° / friction 1.7 → **30° / ±25° / 3.0**.
- **Do limbs collide with the floor and each other?**
  - Yes: the floor near spawn is `Default`, and hulls self-collide.
  - The hull group now also collides with the map's `Terrain` and `Chests` groups, matching `Players`.
  - Bots lay with the root 0.6 above the floor, pressing the 1.15-deep chest hull into it (the "sunk,
    crushed" look). Now 1.0.
- **Research notes for the real build:**
  - **Active / powered ragdoll** (Euphoria-style physical animation middleware; Unreal "physical animation"): joints are *driven*
    toward the animation pose by per-joint spring-dampers with a torque budget, so a body braces and
    stumbles instead of going instantly limp.
  - Roblox now supports this natively. A **non-kinematic `AnimationConstraint`** applies force- and
    torque-limited tracking. The Avatar Joint Upgrade (opt-in, January 2026) swaps R15 Motor6Ds for
    them, and `Workspace.ImprovedAnimationConstraint` fixed chain stability.
  - **Getting up:** read the root orientation (face-up vs face-down), pose-match the get-up clip to the
    lying pose, and blend physics → animation over 0.2–0.5 s. The spike snaps instantly, hence the
    "explosive" get-up.
  - **Random impulses:** they break symmetry (a perfectly balanced body folds straight down, identical
    every time) and convey the hit direction. Momentum plus a small topple is enough for a plain ragdoll;
    hits add a directional impulse.

#### CP6 closed: replication proven, feel deferred (2026-09-25)

- **The developer's call:** stop tuning feel inside the replication spike. CP6's question was "readable
  on client 2", and it is answered:
  - the rotation record variant (16 B);
  - the server grant, with 0 corrections;
  - viewer local limbs.
- Feel belongs to the Ragdoll/Death phase: a powered ragdoll, pose-matched get-up, neck behaviour.

**Notes for that phase:**

- **Mass:** only the physics parts (body/root, limb bodies) carry mass; every cosmetic is `Massless`.
  Today's rig has it backwards: `PlayerHitbox` carries 85 % of the mass.
- **Hulls are the standard approach**, but the better fix is limbs of real thickness in the rig redo (as
  for example 1-stud limbs), which removes hulls entirely. If hulls stay, they live on
  the rig permanently and are toggled, not created and destroyed.
- **Viewer ragdolls:** physics limbs hanging from a kinematically placed torso are a known fling hazard
  (we hit it; the studied baseline documents the same thing). Candidate for the real build: a
  **physics-free procedural limb swing** (pendulum through joint `Transform`) for remote bodies, which
  cannot fling and needs no extra data. Owners keep real physics.
- **Reference comparison:**
  - the baseline's player ragdoll uses the standard R15 ball-socket set;
  - it hands physics ownership to the owner, so viewers get native physics replication (exact limbs, at
    native bandwidth);
  - its rig is lean (18 parts, default masses).

### CP10 — lifecycle (automated half, 2026-09-25)

**Built:** viewer-side **release**.

- No record for 1.5 s (out of range, player gone, bot removed): the puppet is unparented and kept (its
  move anchor too).
- A record arriving again brings it back instantly, with a **fresh buffer** so it doesn't slide across
  the map from its old samples.
- Released for 60 s: destroyed.
- The readout shows a `CP10 lifecycle: …` line.

**Results:**

| Test | Result |
|---|---|
| 5 bots → 2 | the 3 removed puppets **released within 0.8 s** (unparented, kept) |
| 2 → 5 | they **returned instantly** (0.01 s); worst step over their first 20 frames 0.14–0.67 studs, so no slide |
| Load-time stall | every puppet released and returned once while the client loaded (a > 1.5 s stall). Harmless; the release window may need to be longer than a load hitch |
| Death (100 damage) → respawn | Died fired; rebuilt (build 2, epoch 2); health back to 100; **0 engine characters** |
| **The real `SlotService` seam** | `switchSlot` ends with `player:LoadCharacter()`. Called directly, it **spawns an engine character even with `CharacterAutoLoads = false`**: the client's `Character` and camera jump to it, and our rig is orphaned (two models named the player). **Conflict confirmed.** Recovered by destroying it plus a spike respawn |

**The real services:** CP10 confirms §8's blast-radius table rather than adding to it. A fresh sweep of
`src/` for `.Character`, `CharacterAdded`, `LoadCharacter`, and `observeCharacter` finds only modules §8
already lists. CP10 adds one fact to §8's `SlotServiceServer` row: `LoadCharacter()` does not merely
change the return contract. It spawns an engine character even with `CharacterAutoLoads = false`, so it
must be removed rather than wrapped.

**Still to test by hand:**

- a real `switchslot` via Cmdr (F2), which is expected to reproduce the conflict;
- a player leaving and rejoining with two clients;
- riding a moving platform: **deferred, nothing needs it yet** (below).

**Mounts and moving things in the old game** (read-only inspection of the old Venture place):

- **The only mount is `BirdMount`**, reachable only through a chat command (`!mount`). It is a
  **body swap**, not a ride: the server clones the mount model, sets `player.Character` to it, gives the
  owner network ownership, and the player appears as a welded, massless rider dummy. The mount has its
  own Humanoid and walks, sprints and jumps. A `flight` speed is configured but no flight code exists.
- **Moving platforms: none.** The map has no seats, vehicle seats, actuated hinges or prismatic
  constraints, and nothing named like a boat, lift, cart or train. `BoatTween` is a tween library.
- **Ziplines exist.** A zipline is a static line, so world-space records already draw a rider correctly.

For this design a body-swap mount is simpler than §9's "rider plus separate mount entity": the owner
builds the mount rig as its body, the record stream is unchanged, and viewers need to know which rig
to build. So the slot table carries a **rig kind**, and a swap bumps the epoch like a respawn.
Platform-relative records wait until the game has a moving platform.

#### CP10 hand checks (developer, 2026-09-29)

| Test | Result |
|---|---|
| Real `switchslot` through Cmdr (F2) | **Reproduces the conflict.** `SlotServiceServer.switchSlot`'s `LoadCharacter()` spawns an engine character over the client-built rig. It must be removed, not wrapped (§8) |
| Two players; one leaves and rejoins | The leaver's puppet is cleaned up. **One leak seen:** the CP3 voice readout listed the rejoined player's name **twice** |
| Occasional lag: 5 bots and 1 other player; bots stop, then teleport, or the frame rate drops; MicroProfiler averages fine | Not reproduced yet. Instrumented (below) |

**The duplicate name, root cause.** `VoiceCP3.client` keyed its wirings by `Player` and swept only the
players still in the game. A leaver's entry was never revisited, and a rejoin (a new `Player` object)
added a second. Fixed: the entry is unwired on `PlayerRemoving`.

**Cleanup sweep: other leave, rejoin and respawn leaks** (all spike code; the real services use
janitor-managed observers and hold no per-player tables):

| Leak | Trigger | Fix |
|---|---|---|
| **Slot reuse:** puppets were keyed by slot alone, and the lowest free slot is reused at once. The next owner inherited the old puppet (its name, buffer and epoch). A late record from a leaver built a nameless "Bot N" puppet, which a rejoiner then inherited, losing voice and appearance (both looked the puppet up by name) | leave + join or rejoin within 60 s; bot removal | The spec's **slot generation** (§6.2), now real: bumped on every release and carried in every record. A puppet whose generation differs is destroyed and rebuilt. Records for a slot that is neither a player nor a known bot build nothing. Puppets carry `SpikeOwnerUserId`; voice and customization resolve owners by id, not display name |
| **Ragdoll carried into the respawned body:** the client kept the ragdoll handle, and the old delayed get-up lifted and re-stated the new rig. The server kept the ragdoll window, so the new body skipped the movement rules for up to ~2.9 s | death or respawn while limp | Cleared on rebuild (client) and on `spawnBody` (server). The delayed get-up only acts on its own handle |
| A slow build (the Animator wait yields) could build two puppets for one slot and orphan the first | a build that yields | A per-slot "building" guard |
| The customization cache kept every destroyed rig or puppet until the next appearance change | every respawn / puppet destroy | Dropped on `Destroying` |
| Bot validation tracks (CP8) were never cleared | bot removal | Dropped with the slot |

**Lesson for the real build:** a slot is an identity only together with its generation, and viewers must
find a body's owner by id through the rig ↔ player registry (§8), never by instance name.

**The lag: diagnosis, not yet a verdict.** The code rules out transport overflow (a 5-bot batch is
103 B) and server fan-out cost at this scale. The most likely mechanism is the **puppet interpolator**,
which has almost no cushion and no smooth recovery:

- The measured delay on a good link is ~25–40 ms (1–2 samples). `ReplicationSpikeDelayMs` isn't set in
  the place, so there is no floor.
- Past the newest sample, a puppet extrapolates for 100 ms, then **holds**, then **jumps** to the next
  record. §6.6's underrun ladder (clock dilation, damped hold, ~120 ms spring recovery) isn't built in
  the spike.
- The render delay moves **globally and instantly**: any puppet "behind" (a first build, a CP10 return,
  an epoch flush) snaps every puppet's timeline. §6.6 specifies a PI clock limited to ±3 % instead.
- So any delivery gap over ~130 ms (a client frame hitch, a server stall, a network burst) reads
  exactly as "bots stop, then teleport".

Two client frame costs were also removed as suspects:

- CP7 scanned all 479 top-level Workspace children every physics step, allocating a substring each.
  It now keeps a puppet set from child events.
- The CP2 streaming probe (up to 5000 parts) ran every second; it now runs every 10 s.

**Instrumented**, to tell the three sources apart. The CP4 readout has three new `HITCH` lines:

- the max inter-batch gap, max client frame, and puppets that ran dry, per second;
- a timestamped client log of batch gaps > 150 ms, frames > 50 ms, delay jumps > 20 ms, and dry
  puppets;
- the server's own worst frame and its > 50 ms hitches (`SpikeServerHitch`), in the same session
  seconds.

**Next:** reproduce, and read which log line comes first.

- "batch gap" with no server hitch → the network.
- "server frame" → a server stall.
- "client frame" → a local hitch; the MicroProfiler should catch that frame.
- "ran dry" alone at a steady frame rate → the cushion is too thin. `ReplicationSpikeDelayMs = 100`
  should make it disappear.

The fix itself (§6.6's clock and recovery) belongs to the real interpolator.

### CP11 — observer animations (built 2026-09-29, awaiting the developer run)

**What it proves.** A server-granted action reaches every viewer inside the record stream (§6.2's
`hasAction` extension), lines up with the body's motion on the viewer's render clock, and can't be
forged.

**Built:**

- **The grant** (server). Two entry points, one grant:
  - the owner presses **G**. It plays `sprintjump` at once through the real `AnimationServiceClient`
    and sends `ActionRequest`. The server checks the registry, a 300 ms cooldown, dead and ragdolled,
    then grants it or sends `ActionDenied`, which makes the owner stop it;
  - the server calls `AnimationServiceServer.playOnCharacter`, e.g. Cmdr `animplay <player> sit`. The
    spike wraps the service's verbs in place: play grants, `animstop` and the stop-attacks verb end the
    grant.
- **What ends a grant:**
  - a stop;
  - ragdoll, death, or respawn;
  - for a one-shot, 4 s after its start (the server doesn't know clip lengths).
- **The wire:** 2 bytes after a record whose `hasAction` bit is set, so records are 16 or 18 B.
  - The relay writes it from the grant, never the owner. An owner setting the bit counts `ForgedAction`
    and is cleared.
  - Fan-out packs batches record by record. The per-batch cap assumes 18 B records, so a batch never
    crosses 700 B.
- **Viewers:**
  - latch the grant's start (the record's sample time minus the elapsed field);
  - play the clip on the puppet's Animator when the render clock reaches it, seeked to the elapsed
    time;
  - re-seek only past 40 ms of drift; a start that moves more than 150 ms is a new play;
  - stop the clip once records stop carrying it, or when the puppet goes limp or is released.

**Findings from building it** (real-build requirements, recorded before the run):

1. **Elapsed time, not normalised phase.** §6.2's "normalised phase" needs the clip length, and the
   registry has none; a server can't know it without loading the track. The extension carries elapsed
   time (6 bits, 32 ms steps, saturating at ~2 s). That is exactly what a receiver needs to latch the
   start.
   - Layout: id 7 · variant 3 · elapsed 6 = 16 bits.
   - The real build should add a declared `durationMs` to `AnimationDef` if it wants phase.
2. **The variant must be chosen by the server.** `AnimationPlayer` rolls variants with `math.random`
   on each machine, so an owner and its viewers can play different clips. The spike's grant picks the
   variant and viewers honour it, but the owner still rolls its own. The real build needs `play(id,
   { variant = n })`, and the variant must ride the play request.
3. **Viewers need seek.** A viewer that sees an action mid-flight must start the clip at the owner's
   point in it. The `AnimationPlayer` seam has no `TimePosition` or `Length`, so the spike loads action
   clips on the puppet's Animator directly. The real build adds seek/length to the seam.
4. **Play options don't travel.** `animplay`'s `speed` (and `fadeTime`/`weight`) aren't carried, so
   viewers play at speed 1. If speed matters, the extension or the grant table needs it.
5. **There are no real actions yet.** The registry is the locomotion domain only (all `ambient`), so
   `sprintjump` and `sit` stand in until combat and emotes land.

**Developer run:**

- Two clients, and watch client 2.
- Client 1 presses G, alone and while running; then `animplay <client1> sit`, then
  `animstop <client1> sit`.
- Pass means the action reads correctly on client 2: right clip, in sync with the motion, stops
  when stopped.
- Readouts:
  - owner CP1 line `CP11 action`: requests, denials, the server's last grant;
  - viewer CP4 line `CP11 actions`: latched, started, re-seeks (should stay near 0), ended.

#### CP10 + CP11 — agent pass before the developer run (Studio Play via MCP, 1 client + 5 bots, 2026-09-29)

| Check | Result |
|---|---|
| Boot | 5 bot puppets · 0 engine characters · fidelity mean 0.012 studs |
| Bots 5 → 2 → 5 | 3 released, then rebuilt on return as **3 slot handovers** (new generation); no duplicate or misnamed puppets |
| Ragdoll, then respawn while limp | rebuilt (build 2, epoch 2) standing, `Running`; **no pop** when the old get-up would have fired; 0 corrections |
| HITCH, 30 s steady state | render delay 123–140 ms · 0 puppets ran dry · max batch gap 68–86 ms. Frames are slow in single-Studio Play: client ~30 fps, server worst frame 27–48 ms/s. Client and server share one process there, so their hitches coincide (e.g. 90 ms server / 88 ms client at 41.0 s); the separate-process run is the real test |
| G (owner action) | granted `sprintjump` (owner source) |
| **Bug found and fixed:** spam G | a refused press replayed the clip, then its denial stopped the id, killing the GRANTED play on the owner while viewers kept it. Fix: the owner mirrors the shared cooldown (the slide rule). Re-run: 1 requested · 3 skipped · 0 denied · the owner's clip keeps playing |
| **Variant mismatch, live** | the owner rolled the base clip while the server granted variant 1 (finding 2, confirmed) |
| Cmdr `animplay <me> sit` → wait 2.5 s → `animstop` | granted (server source) · still live at 2.5 s (looped) · `ended sit (stopped)` |
| Forged action bit (new exploit mode `fakeaction`) | `ForgedAction` counted every sample (55 in 1 s); the relay re-encodes from grants only |
| Viewer playback (latch, start, re-seek, end) | **not testable with one client** (bots carry no actions): the developer's two-client run |

**Harness note:** the MCP's `require` returns its own copy of a module, not the game's. Calling
`AnimationServiceServer` from `execute_luau` bypassed the spike's wrapper. Server paths are exercised
through the real Cmdr remote instead.

#### CP11 — developer two-client run (Studio Test, 2026-09-29)

| Check | Result |
|---|---|
| G standing still | ✅ shows on client 2 **at the same moment** |
| G while walking | ✅ lines up with the motion |
| `animplay sit` / `animstop sit` | ✅ both screens |
| G then R | ✅ the action stops when the owner goes limp |
| Client 2's viewer counters | ✅ latched 2 · started 2 · **re-seeks 0** · ended 2 · load failures 0 |
| "No jump" | expected: an action is an animation; the jump's MOTION belongs to the Movement phase |
| `sprintjump` reads weak, blended | expected for the stand-in: the locomotion domain declares everything `Core`, so it blends with idle/run at equal priority, on both screens identically. Real actions will register at `Action` |

**CP11 verdict: PASS.** The action extension carries server-granted actions to viewers, in sync, with no
re-seeks. The findings recorded above (server-chosen variant, seek on the seam, elapsed rather than phase,
play options not carried) are the real build's requirements.

#### Found during CP11: cosmetics no longer mount on client-built rigs (2026-09-29)

The developer saw bald players. **It is not the defaults:** the published appearance is correct
(`Hair9`, `Eyebrows4`, `Boots1`, head type `Uncovered`, from `DEFAULT_COSMETICS`).

**It is the mount.** On the client-built rig, measured in Studio Play:

- parenting a cosmetic Accessory creates **no** `AccessoryRigidConstraint`;
- `Humanoid:AddAccessory` does not bind it either;
- the pieces stay where the art sits (hair ~1090 studs, shoes ~1430 studs from their sockets) and fall.
  Hair and eyebrows cross the fall height and are deleted; the shoes were still falling.

**Root cause, isolated (same day).** Nothing broke. **The engine only binds accessories on the
SERVER**, and under option A cosmetics are applied on the client. The controls, all measured, each a
minimal model with a Humanoid, a `Head` carrying a socket, and an Accessory whose Handle carries the same
attachment name:

| Where | Result |
|---|---|
| Server, runtime (Play) | binds in 0.00 s (Weld) |
| **Client, runtime (Play)** | **never**, even for the minimal control. `AddAccessory` never; `BuildRigFromAttachments` never (it leaves the rig's 17 Motor6Ds untouched, but creates no accessory weld) |
| Edit mode, the real rig | never, because of the rig's `PackageLink`: with it removed, it binds in 0.25 s. A Studio package-edit behaviour, irrelevant at runtime (stripping the link on the client changes nothing) |

The engine docs say the same: accessory welds "are created on the server", and client-side
`AddAccessory` "may not always produce the desired behavior".

**CP4's ✅ was a false pass.** It read `applied 1 · failed 0 · no warnings`, but `apply()` counts as
applied even when every mount is skipped, and the skip reasons log at debug level, which the place's
`LogLevel = Warning` hides. Nobody looked at the rig. The pieces were parented, unbound, and fell away.
Lesson: a customization check must assert that each piece's attachment sits **on** its socket, not that
`apply()` returned.

**Consequence for §8:** `CustomizationApplication` must bind explicitly (a RigidConstraint from the
Handle's socket attachment to the rig socket). This is the "explicit-constraint fallback" §8 already
names. Its current comment records the manual binding as removed because the engine did it; on
client-built rigs, the engine demonstrably does not.

#### Spike stand-in: explicit cosmetic binding (2026-09-29)

`CustomizationCP4.client` now welds each mounted piece's Handle to its rig socket after the real
`apply()`, using the same C0/C1 as the engine's accessory weld. It is **spike-only**: the real
`CustomizationApplication` is untouched, and the proper binding belongs to the replication build.

**Verified in Studio Play:** 4 pieces bound, 0 unbound. `Hair9`, `Eyebrows4`, and both `Boots1`
pieces each sit **0.000 studs** from their socket, and the capture shows the hair on the head.

**The real build's check** must assert piece-on-socket, as this one does, never `apply()` returning.

#### `Fly` on an honest player: reproduced (2026-09-29)

An honest F wall-hop (the CFrame +6 studs plus a 45 studs/s upward kick) rises **12.3 studs** above
take-off against the rules' 9.4-stud cap. Each hop flags `Fly` about 3 times and sends 1 correction.
The diagnostic now shows it on the owner readout (`CP5 last Fly`):
`state Freefall · 12.3 studs above take-off (cap 9.4) · vy 30`.

So client 2's `Fly 51` is roughly 17 wall-hops, and possibly a ladder climb: `Climbing` has no floor
material, so the server treats it as airborne from the bottom. The map has 6 parts named
ladder/climb, and no trusses or water.

**Cause:** the spike's rules model the slide's entry and envelope, but not the wall-hop's vertical
write. §7 already says a CFrame-write move must be **server-granted** with its own envelope, like the
ragdoll. That is the anti-cheat phase's work, and nothing more is done in the spike.

#### Tooling: `check.sh` breaks a live `rojo serve` (2026-09-29)

`scripts/check.sh` runs `wally install`, which deletes and recreates `Packages/` under the served tree.
Measured: that either froze Rojo's watcher (it kept serving its last read) or crashed it. Studio then
ran stale code while looking connected. Rewriting the link files alone (`wally-package-types`) is
harmless.

While a developer is synced, typecheck with `rojo sourcemap` plus `luau-lsp analyze` only.

### Technique comparison, measured (2026-09-29)

Queued follow-up #2 is done: this system against alternative techniques on equal content. It is also §10's
minimal harness, built.

- **Harness:** `src/ReplicatedStorage/Shared/Spike/Harness/`. A deterministic 60 Hz parkour trace (18 s) and
  four network profiles (studio / good / spec §10 / mobile), with a reliable-channel model including
  head-of-line blocking. System-agnostic scoring: fitted latency, shape error, error vs now, pops, freezes,
  and real encoded bytes. Five seeds per cell.
- **The strongest alternative technique tried** ("alternative" below):
  - every position on a reliable ordered stream, without timestamps;
  - generic table records, about 2.5 times the size of ours;
  - spline playout on the arrival grid;
  - fixed distance bands;
  - camera aim sent as a separate stream.

**Result.** The "final" design (`HarnessFinal`) wins every column on every network: latency, mean, p95,
p99 and max shape error, error vs now, pops, freezes, downlink, uplink and resends. The gap is largest
under loss. On spec §10 (75 ms, 3 %), the alternative shows 298 pops and 1,781 freezes per five runs; final
shows 1 and 0.

**CPU, measured on real code:**

| | Venture | Alternative |
|---|---|---|
| Encode a record | 1.30 µs | 2.70 µs (generic table serializer) |
| Decode a record | 1.13 µs | 3.02 µs |
| Render step per body | 0.29 µs | 0.45 µs |
| Server encode per tick, 60 players in view | 0.08 ms + byte copies | 9.6 ms (one serialization per viewer) |

**Found and fixed on the way:**

- The spike stamped samples on server arrival, so uplink jitter became position noise. Fix: the owner's
  timestamp rides the record's age field on the uplink.
- A lost landing packet drew the body through the floor at 178 studs/s. Fix: gravity dead reckoning that
  stops at a ground query (§6.6).
- A 0.25 s loss window read one lost packet as 6.7 % loss and added 33 ms of delay. Fix: a 240-batch
  sliding window.
- An instant delay rise stepped the timeline. Fix: glide at 60 ms/s with 6 ms hysteresis; jump only when
  starving or 25 ms or more away.
- The codec allocated a cursor table per record. Now module locals, with byte-identical output.
  `evaluatePosition` is an allocation-free fast path with identical positions.
- **Tooling:** Studio's `require` cache keeps the first loaded copy of a module. Every harness run
  therefore requires a fresh clone of the Harness folder.

**Techniques considered and where they land:**

1. **Occlusion culling** (distance plus line of sight): its value is
   anti-wallhack, so it goes to the anti-cheat phase (Verdict).
2. **Accessory binding through a server character:** not available without an engine character; the real
   build binds explicitly with a RigidConstraint per piece (same per-frame cost, measured).
3. **A minimal owner encode with fewer fields:** not worth it; the full record costs 1.3 µs per frame and the
   uplink is still smaller in total (1,020 B/s against 1,240 or more).

**Real-build requirements implied by these numbers:**

- the 17 B uplink with the owner timestamp;
- send-on-change with a 1 Hz repair;
- the p95-lateness delay, with the glide/jump clock and the 4 s loss window;
- gravity plus ground dead reckoning;
- the zero-allocation codec and interpolation path.

---

### CP12 — engine features through a client-set `Character`, voice culling (2026-10-04)

**Question.** If each client sets every *remote* player's `Player.Character` to that player's puppet, do
engine features keyed off `Character` start working (bubble chat, default voice), and what breaks? Plus:
can the server cull who is sent each microphone stream, from the visibility data it already has? Probe:
`CharacterCP12.client` + a cull knob in `VoiceCP3.server` (spike branch, throwaway). Studio 3-client run,
then the developer's two published accounts.

| Probe | Result |
|---|---|
| Assign a remote player's `Character` on a client | ✅ No error, never overridden (0 foreign changes over 7 rebuilds in one run). `CharacterAdded` / `CharacterRemoving` fire on that client; `GetPlayerFromCharacter(puppet)` works. The server keeps `Character = nil` and spawns no engine character |
| Respawn rebuild, rejoin, out of range and back | ✅ `Character` follows the rebuilt puppet; a rejoiner gets one clean assignment |
| Side effects | None seen: no errors, the engine adds nothing to the puppet, the state machine stays off, the owner's own rig is untouched. Our code reads only `LocalPlayer.Character` |
| Bubble chat (published) | ✅ With `Character` assigned, the engine treats the whole puppet model as a legal character: real chat shows the native bubble above it. A plain model is refused (`partOrCharacter is not a legal character`). **Open:** with the knob switched off the developer still saw bubbles once; a run with it off from join recorded none for the other player. Unresolved, irrelevant while bubbles are off |
| Default voice through the assigned `Character` (published) | ❌ The engine creates the `AudioDeviceInput` and shows the speaking icon to others, but nobody hears anything and no emitter appears on the puppet: it wires the server's `Character` (nil). **Custom wiring (CP3) stays** |
| Mute (published) | ✅ The top-bar mic and per-player mute work with the custom route (independent of `Character`) |
| **T5a** native speaking icon, published: engine voice OFF, our CP3 wiring, `Character` assigned | ✅ The engine's own speaking icon shows and animates over the puppet while our wiring carries the audio. Spatial audio, top-bar and per-player mute, volume sliders and rejoin all pass. The icon follows the player's voice state + `Character`, not the engine's audio setup |
| **T5c** bubble chat off (`BubbleChatConfiguration.Enabled = false`) with T5a | ✅ The voice icon stays: bubbles off does not remove it |
| Server voice culling (`SetUserIdAccessList`, allow list by validated distance) | ✅ after one fix: the speaker must be on its own allow list (run 1 left it off; the mic showed "on" with no level, silent even up close), and the list is written only when it changes |

**Decisions.**
- Voice keeps the CP3 client-wired route. Culling is proven but not needed yet (bandwidth only).
- Bubbles are off for now (old Venture had none). If wanted later, a client-set `Character` gives native
  bubbles cheaply. Rules for that day: one writer (the puppet pool: set on acquire, clear on release,
  clear the previous owner first on reuse), the rig registry stays the source of truth.
- ~~`Character` assignment is not shipped in R5~~ — **reversed by T5 (2026-10-05): it ships in R5**, because
  it gives the native speaking icon for free (no icon code, no analyzers). One writer: the client rig
  registry sets a remote player's `Character` when its puppet is registered and clears it when unregistered.
  Bubbles stay off (`BubbleChatConfiguration.Enabled = false`), which T5c showed keeps the icon.

**Two prototype failures seen in the published runs (both prototype-only, root causes found).**
1. *Bodies lying on the ground; another player invisible after some joins.* The place still ran the CP9
   `constraint` move mode: the puppet root is **unanchored**, driven by a kinematic `AnimationConstraint`.
   On some joins the joint stops driving it (`joint placement error` 85.9 studs vs 0.0000 healthy), physics
   takes over and the bodies fall. The real build anchors the root and uses one `BulkMoveTo`, which cannot
   fall. **The CP9 "decision candidate" constraint joint is withdrawn until that failure is understood.**
2. *Puppets vanish for a moment, even in front of you.* The prototype releases a puppet after 1.5 s with no
   record (`RELEASE_SECONDS`). The runs had whole-connection stalls: batch gaps to 1.7 s with the reliable
   stream silent too (1.5 s), ping 549 ms, uplink silences to 2.5 s; `releases 43 · returns 43`. The real
   build hides a body only on the server's reliable `Leave`; a stall holds it in place. That hold path is
   covered by specs but has not been exercised under a real stall: part of the R5 robustness pass.

## 13. R4 — Appearance (2026-10-03)

**Status:** DRAFT for developer review. Builds on the master design (CP1–CP3, CP4–CP11) and R3 animation.
Branch: `feature/replication-appearance`, stacked on R3. R4 scope is **appearance only**; the equipped title
and nameplates are deferred (they ride the same public slice but are not dressed by R4). Distance and
appearance tiers are deferred until cosmetics with motion or cloth physics arrive.

### 13.1 Architecture summary

| Layer | Responsibility |
|---|---|
| **Server** (`CustomizationServiceServer`) | Validates appearance writes. On every active-appearance change (edit, slot switch, spawn defaults) publishes a **deep copy** plus a bumped `appearanceVersion` to the player's public-slice entry. A plain respawn (same slot, defaults already filled) publishes nothing. The profile is never mutated. |
| **Public slice** (`PublicPlayerState`) | Carries `appearance` + `appearanceVersion` per player, beside health. Charm-sync ships deltas, filtered per viewer by relevance; late joiners get the entry on the initial sync. |
| **Shared, pure** | `CustomizationPlan` (existing) resolves an Appearance. `OutfitDiff.target` turns it into an `Outfit` (the full look, keyed per slot); `OutfitDiff.compute(worn, target)` lists only the changes. |
| **Shared — `RigOutfit`** | Per rig, for the rig's whole life: the worn `Outfit` (always true to the rig), the mounted pieces by mount key, owner + version (`UNDRESSED` = -1), failure reasons, and part/socket indexes built once. |
| **Shared — `PiecePool`** | Spare cosmetic sets (all pieces of one copy) keyed by id, parked anchored and far away, constraints stripped, transparency untouched. Take first, clone on a miss; capped per id. |
| **Shared — `CustomizationApplication` / `RigLook`** | Executes a diff. Binds with **`RigidConstraint`**, piece Handle attachment → rig attachment of the exact same name. A piece that cannot bind (`noArt / noHandle / noSocket / nameMismatch`) is never floated: the category default is mounted instead when there is one, the reason goes on the rig (`CustomizationFailures`) and into per-reason F4 counters. `RigLook` restores the authored colour / transparency / surface for a nil in the diff. |
| **Shared — `AppearanceQueue`** | One pending job per rig, newest version wins. When a job's turn comes it is dropped if the rig changed owner or is already at that version; the diff is computed then, against what the rig wears. ~2 ms per frame, always at least one job; a job is one whole dress. |
| **Client — `PuppetPool` owner affinity** | Each puppet owns its `RigOutfit`. `acquire(player)` prefers the idle rig that last drew that player (its record is still current: no redress); otherwise the least-recently-used spare, which `RigOutfit.assign` marks undressed for the new owner. Idle cap 16. |
| **Client — `PuppetOutfit`** | Owner rig: dressed synchronously on build from `ClientStore.appearance`, later changes through the queue. Puppets: dressed from the public entry; undressed puppets stay parked (the dressed rule); default look after 1 s with no entry, replaced by the real one. |
| **Client — `tuneoffset`** | Cmdr `ClientRun` (`TuneOffsetClient`): nudges a mounted piece on the caller's own rig; the RigidConstraint follows live. Client-only and visual-only, so the server-side allowlist hook does not gate it. |

### 13.2 Public-slice appearance shape

```luau
export type PublicPlayer = {
    health: number,
    maxHealth: number,
    appearance: PlayerDataTypes.Appearance, -- the stored slice value, copied
    appearanceVersion: number, -- bumped by the server on every active-appearance change
}
```

The appearance is the same table the profile stores (`cosmetics`, `accessories`, `body`, `headType`,
`surfaces`); viewers resolve it with `CustomizationPlan` locally. `appearanceVersion` is the only field a
viewer compares for "has the look changed" — health updates on the same entry cost a lookup.

### 13.3 `OutfitDiff`

| Op kind | Fields | When |
|---|---|---|
| `removeCosmetic` | `mountKey` | Worn mount absent from the target, or replaced (id, fallback or fit offset changed) |
| `addCosmetic` | `mountKey`, `mount` | Target mount not worn, or replaced |
| `recolourCosmetic` | `mountKey`, `colors` | Same mount, only colours differ |
| `setBodyColour` | `part`, `color?` | Differs; nil = the rig's authored colour |
| `setSurface` | `channelKey`, `surface` | Differs; both aspects nil = authored surface |
| `setHeadPart` | `part`, `visible?` | Differs; nil = authored transparency |

Mount keys: the category for single-selection cosmetics, `accessory:N` for the Nth accessory. Order is
fixed (removals sorted, then target mount order, body channels and surface channels in registry order,
head parts sorted). Retired ids and dyes are dropped by `CustomizationPlan`, so they never reach the diff.

### 13.4 Contracts

- **`RigOutfit`** — `new(rig)` indexes a fresh rig; `partsFor(name)` (exact or `name-suffix`, cached);
  `socket(name)`; `assign(owner)` (new owner → `UNDRESSED`, worn kept); `isDressed`; `setWorn(worn, version)`.
  Only `CustomizationApplication` mounts or removes cosmetics, or the record stops being true.
- **`PiecePool`** — `take(id) -> { Accessory }?`, `release(id, pieces)`, `destroy`; `hits / misses / parked`.
- **`AppearanceQueue`** — `request(outfit, owner, version, target)`, `cancel`, `pendingVersion`,
  `step(dress, clock?)`, `size`; `applied / dropped / lastStepMs`.
- **`CustomizationApplication`** — `apply(outfit, ops, pool)`, `strip(outfit, pool)` (park everything
  before a rig is destroyed), `nudgeOffset(rig, id, offset)`, `counters()`.

### 13.5 PuppetPool owner affinity

1. `byOwner[userId]` holds the idle rig that last drew that player → returned as is (`affinityHits`).
2. Miss → least-recently-used idle rig (`spareReuses`), reassigned: undressed until its diff (which
   takes the old owner's look off) lands.
3. Pool empty → build one (one per frame). Over the idle cap → destroy the least-recently-used.

Measurements (R4 spike): rig clone 19–46 ms, destroy 24 at once froze ~1 s → pooling is the win.

### 13.6 Client wiring (`CharacterReplicationServiceClient`)

- `init`: `CosmeticPieces` folder in Workspace, the `PiecePool`, and `PuppetOutfit.new` over
  `ClientStore.appearance` / `ClientStore.publicPlayers`.
- Owner rig built → `PuppetOutfit.attachOwner` (dressed before `bodySpawned` fires). Dropped →
  `detachOwner` parks its pieces for the next rig.
- Puppet acquired → `attachPuppet`; released → `detachPuppet` (job cancelled, outfit kept on the rig).
- PreRender: `PuppetOutfit.frame` (timeouts + queue step) BEFORE placement; a held puppet that is not
  dressed is moved with the hidden ones (`unheldFrames.undressed`).
- F4 (`getState`): `appearance` (queue, timeouts, piece-pool hits), `mounts` (per-reason counters),
  `poolAffinityHits`, `poolSpareReuses`.

### 13.7 59-puppet appearance probe — placeholder tables

The 59-puppet probe is a **Studio measurement run** (developer runs it — not headless). It mirrors the R3 CP4
measurement structure but focuses on **dress-step cost** and **PreRender rate** for appearance.

> ⚠ **PreRender rate check reminder**: Before debugging any anomaly, verify the client is actually running
> at 60 Hz (laptop awake, not throttled, Studio window focused). The R3 CP4 automated half ran on
> Heartbeat because an unfocused MCP client does not fire PreRender.

#### 13.7.1 PC probe (Studio, play session, 59 puppets)

| Metric | Result |
|---|---|
| Dress-step median (ms/frame) | — |
| Dress-step p90 (ms/frame) | — |
| Dress-step p99 (ms/frame) | — |
| `AppearanceQueue` budget used (ms/frame) | — |
| PiecePool hit rate (%) | — |
| Rig clone avoided by affinity (%) | — |
| PreRender rate (Hz) | — |
| Frame time with 59 dressed puppets (ms) | — |
| Memory delta (MB) | — |

*Run procedure: two clients in Studio Test (Clients and Servers). Client 1 stands still. Client 2 acquires 59
puppets (bots or joined players) with varied outfits. Measure over 10 s steady state after all dressed.
Read `appearance.lastStepMs` (F4) for the dress step; MicroProfiler for frame time.*

#### 13.7.2 Phone probe (published private experience, 59 puppets)

| Metric | Result |
|---|---|
| Dress-step median (ms/frame) | — |
| Dress-step p90 (ms/frame) | — |
| Dress-step p99 (ms/frame) | — |
| `AppearanceQueue` budget used (ms/frame) | — |
| PiecePool hit rate (%) | — |
| Rig clone avoided by affinity (%) | — |
| PreRender rate (Hz) | — |
| Frame time with 59 dressed puppets (ms) | — |
| Memory delta (MB) | — |

*Run procedure: publish the replication spike place privately. Developer joins on PC, 59 bots on phone (or
vice versa). Measure over 10 s steady state. Phone must be on charger, not thermal-throttled.*

### 13.8 Developer two-client checklist

**Run 2026-10-04** (character-replication.rbxl with the real art; single Play + a 2-player Clients and
Servers test). Ticked = observed in Studio. Found and fixed on the way: fallen-rig pieces poisoning the pool
(cea8db8), and Studio's negative test-player ids failing `Guard.userId`, which stopped every appearance
publish so puppets wore the empty placeholder (2579c6e). Not yet run: the 59-puppet probe.

Studio Test (Clients and Servers), two clients. F4 → Services → CharacterReplicationServiceClient for the
counters. "Sits on its socket" means the Handle attachment is within 0.01 studs of the rig socket.

- [x] **TestEZ** (1857/1857 at 2579c6e): `RunTests = true`, Play, all green (incl. OutfitDiff, RigOutfit, RigLook, PiecePool,
  AppearanceQueue, CustomizationApplication, PuppetPool, PuppetOutfit, TuneOffsetClient).
- [x] **Owner dressed**: your rig spawns dressed (hair, eyebrows, boots), every piece on its socket, no bald frame.
- [x] **Puppet dressed** (both screens, 0.000 studs): the other client appears dressed, never undressed first; `undressedPuppets` returns to 0.
- [x] **Look change** (seen in place by the other client; pool hands back the same instance): `equipcosmetic <you> hair Hair10` — both clients see it in place; `pieceHits` rise on re-equips.
- [x] **Missing / broken art** (`checkart` clean; no-art place showed skip + record, spec covers fallback): `checkart` names any registered id whose art is broken; equip it — no
  floating piece, the default shows in its place, `mounts.noArt`/`noHandle` and `fallback` rise, the rig's
  `CustomizationFailures` attribute names it. (If `checkart` is clean, the spec covers this path.)
- [x] **Stale outfit on reuse** (same rig back, 0 undressed frames; a change made out of range lands before the rig shows. Three-player run: a spare dressed as Player1 — Hair10, WizardHat, green skin — handed to Player2 came up undressed, then exactly Player2's look with the authored skin and the old pieces parked. The handover was driven by an in-client probe on the real pool/outfit code, because a Studio test cannot produce a never-seen player while a spare is idle): walk the other client out of range and back — same rig back, no redress
  (`poolAffinityHits` rises). With a third player, a reused spare shows the NEW owner's look only.
- [x] **TuneOffset** (live on own rig; refuses another player's): `tuneoffset <you> Eyebrows4 0 0.1` — the piece moves live on your rig only; the other
  client does not see it move.
- [x] **Slot switch** (owner and remote, 0 bald frames): `switchslot <you> 2` — rig rebuilds in slot 2's look (new version), no bald frame.
- [x] **Respawn** (fall, owner and remote, 0 bald frames): fall off the map — the new rig re-takes the parked pieces (`pieceHits`), puppets see it dressed.

---

*End of R4 appearance section. Probe results and checklist to be filled in by the developer during R4
verification.*
