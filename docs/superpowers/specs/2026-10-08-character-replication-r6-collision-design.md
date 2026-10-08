# Character replication R6 — player collision

**Status:** DRAFT for developer review (2026-10-08).
**Branch:** `feature/replication-collision`, based on `feature/module-layout` (#40). It merges after #40.
**Builds on:** the master design `2026-09-22-character-replication-design.md`, CP7 (player collision,
decided 2026-09-25) and its follow-ups 1–6, and R2–R5 as shipped.

## 1. Decisions

1. **Players are solid to each other by default, everywhere.** Each client stops its own body against
   where it sees everyone else. Nobody simulates or pushes anyone else's body.
2. **The CP7 design ships as decided:**
   - a primitive capsule blocker (cylinder + two spheres), welded into the puppet's anchored assembly;
   - solid only near the local player;
   - no stance resizing;
   - slide-off push and frictionless blockers, so heads aren't standable.
3. **Not in R6 (developer, 2026-10-08: "hybrid later, no unnecessary logic"):**
   - spawn-overlap ghosting, stuck release, and any `isSolidFor` zone or relationship rule. These are
     §10's later work.
   - Server-side collision rules. The server only registers the collision groups. The CP7 rule "the
     server counts players as ground and walls" becomes the shared size table (§3), which is the
     contract a later anti-cheat phase reads.
4. **R7 (lag compensation) is deferred** to the combat core, per the roadmap.
5. **The puppet move path is not R6's business.** CP9 measured a Motor6D move joint at about half the
   cost of `BulkMoveTo`. Retesting it is #41. Blockers are welded into the puppet, so they ride whichever
   path moves it.
6. **Players are immovable** (developer, 2026-10-08, after the Studio test): a moving player never shoves another. Contact velocity was built, measured and removed: each velocity write on a just-moved puppet costs ~27 µs, and immovable bodies felt better (spike and R6 test) and remove ledge-shove griefing. Blocking doorways is the later hybrid's job (§10).

## 2. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Collision | shared | Data | `CollisionConstants` | The size table, range, slide-off and group values (§3) |
| Collision | shared | Utils | `CollisionShapeUtils` | Pure geometry: part offsets and sizes, feet-on-head check, push direction, range band |
| Collision | server | (root) | `CollisionServiceServer` | Registers the two collision groups at boot |
| Collision | client | (root) | `CollisionServiceClient` | Subscribes to the body API, runs the per-frame step, exposes F4 state |
| Collision | client | Systems | `CollisionBlockerSystem` | Builds, welds, gates and removes capsules on puppets and the local rig |
| Collision | client | Systems | `CollisionSlideOffSystem` | Pushes the local root off a head |

- No existing module changes. `ReplicationServiceClient` (386 of 400 lines) is not touched.
  Collision consumes its public body API: `bodySpawned` / `bodyDespawned (Player, Model)`,
  `getLocalRig()`. That's the same API VoiceServiceClient uses.
- `CollisionServiceClient` lists `ReplicationServiceClient` in `dependencies`.
- `python3 scripts/python/module_map.py --write` after adding them.

## 3. The size table (`CollisionConstants`)

All offsets are relative to the HumanoidRootPart, in studs. They were measured on the Venture rig
(2026-09-24).

| Constant | Value | Meaning |
|---|---|---|
| `RADIUS` | 1.1 | Capsule radius |
| `BOTTOM` | −4.05 | The bottom of the feet |
| `TOP` | 1.53 | The top of the head |
| `SOLID_RANGE` | 20 | A blocker turns solid at this distance or closer |
| `RELEASE_RANGE` | 22 | A solid blocker turns off beyond this (a 2-stud buffer) |
| `RANGE_CHECK_HZ` | 10 | How often the range is checked |
| `SLIDE_OFF_SPEED` | 12 | Studs/s outward while the feet rest on a head (under WalkSpeed 16) |
| `REST_GAP` | 0.6 | ± tolerance between my feet and their head top for "resting on" |
| `REST_MAX_RISE` | 1 | Only pushes while my vertical speed is at most this (not mid-jump) |
| `CENTRE_EPSILON` | 0.2 | Below this horizontal offset, push the way I'm facing |
| `PUPPET_GROUP` | `"CollisionPuppetBlocker"` | Group for other players' blockers |
| `SELF_GROUP` | `"CollisionSelfCollider"` | Group for the local rig's collider |
| `FRICTIONLESS` | density 0.7, friction 0, elasticity 0, FrictionWeight 100, ElasticityWeight 1 | The spike's values: friction 0, and it wins the contact |

All of these are the CP7 spike's values (`SpikePlayerCollider`, `CollisionCP7.client`), carried over
unchanged. The buffer zone and the 10 Hz check are new (§5, §6).

## 4. Shape and connection

Three parts, each a primitive (Roblox has no capsule primitive, and a union buys nothing, per CP7
follow-up 6):

| Part | Shape | Size | Centre (root-relative Y) |
|---|---|---|---|
| Bottom cap | Ball | 2.2 | −2.95 |
| Middle | Cylinder, rotated 90° about Z (cylinder axis is X) | length 3.38, diameter 2.2 | −1.26 |
| Top cap | Ball | 2.2 | +0.43 |

`CollisionShapeUtils` derives these from `RADIUS` / `BOTTOM` / `TOP`. Nothing is hand-typed.

Every part: `CanCollide` (gated, §5), `CanQuery = false`, `CanTouch = false`, `Massless = true`,
`Transparency = 1`, `CustomPhysicalProperties = FRICTIONLESS`, smooth surfaces, the group from §3.

**The connection, exactly as the spike measured it (`puppet` mount):**

1. Place the part at `root.CFrame * offset`.
2. Set `Anchored = false`.
3. Create a `WeldConstraint` with `Part0 = root` and `Part1 = part`, parented to the part.
4. Parent the part into the body model (the puppet or the local rig).

A `WeldConstraint` keeps the offset it sees when it's created. Placing the part first (step 1) makes
that offset exact wherever the root happens to be, including a pooled puppet parked at
`HIDDEN_CFRAME`.

- **Puppets:** the root is anchored, so the welded parts join its anchored assembly. The existing single
  `BulkMoveTo` moves them with the puppet, so R6 writes no CFrames.
- **Local rig:** the same three parts in `SELF_GROUP`, welded to your root. They're `Massless` and
  aren't the assembly root, so the rig's mass and handling don't change. The rig's own parts keep their
  current groups and still do all the world collision.

## 5. Lifecycle and per-frame step

**Body events:**

- `bodySpawned(player, rig)`:
  - for another player, build a puppet blocker, initially **not solid**;
  - for the local player (including every respawn), build the self-collider.
- `bodyDespawned(player, rig)`: destroy that body's capsule parts and forget it. A pooled puppet reused
  for another player arrives as despawn → spawn, so it never carries an old blocker.
- At `init`, bodies that already exist get the same treatment, with the same approach as
  VoiceServiceClient.

**Each frame, on `RunService.PreSimulation`:**

1. **Range (10 Hz, timed by an accumulator):** for each puppet, compute the squared distance
   from the local root to the puppet root.
   - A blocker turns solid at ≤ `SOLID_RANGE`² and off at > `RELEASE_RANGE`².
   - `CanCollide` is written **only when the state changes**.
   - A hidden puppet is far away, so it's never solid.
2. **Slide-off (every frame, solid puppets only):**
   - The local root is pushed when all of these hold:
     - it is horizontally within `2 × RADIUS` of a solid puppet;
     - the gap between my feet (`root.Y + BOTTOM`) and their head top (`their.Y + TOP`) is within ±`REST_GAP`;
     - my vertical velocity is at most `REST_MAX_RISE`.
   - **The push:** raise the outward horizontal component of my velocity to at least `SLIDE_OFF_SPEED`.
     - "Outward" is away from their centre.
     - If I'm within `CENTRE_EPSILON` of their centre, I'm pushed along my horizontal look vector.
   - One push per frame (the first match).
3. **No local rig:** steps 1–2 do nothing.

**Debug view:** a Workspace attribute `CollisionDebug = true` makes the capsule parts visible: others
red (235, 70, 70), yours blue (70, 140, 235), transparency 0.6. It's read via the attribute-changed
signal, and each new capsule is painted when built. Nothing is checked per frame.

**Collision groups (server, at boot):**

- Register `PUPPET_GROUP` and `SELF_GROUP`.
- They collide with each other, and with **no** other group. Each is set non-collidable with every
  group in `PhysicsService:GetRegisteredCollisionGroups()` (including `Default` and themselves),
  then `PUPPET_GROUP` ↔ `SELF_GROUP` is set collidable.
  - Blockers never touch the map, so they can't snag while being moved.
  - Your self-collider doesn't touch the map, so world movement is unchanged.
  - Anchored blockers never pair with each other.
- Groups registered on the server replicate to clients.
- A group the place's art registers is covered by the boot-time walk.
- A group registered by code after boot must set itself non-collidable with the two collision groups.
  No such code exists today.

**F4 (`getState`):**

- puppets tracked;
- solid now;
- solid/not-solid flips in the last second (each flip writes `CanCollide` on 3 parts);
- slide-off pushes in the last second;
- step time (ms, average over the last second).

## 6. Performance

CP7 follow-up 6 measured this exact setup (capsule, welded into the puppet, range 20) at **+0.4 ms
physics, +0.3 ms script** over the baseline, with 59 moving bots. The script figure was mostly the
spike's own per-frame scan and distance checks.

**R6 targets: script ≤ +0.1 ms, physics ≤ +0.4 ms.** It should come in better than CP7, not just
match it:

| Lever | Effect |
|---|---|
| Range check at 10 Hz, squared distances, no scan of the workspace | Most of CP7's script cost goes away |
| Slide-off only over the solid set (typically 0–5) | Per-frame work stays proportional to who's near |
| Change-only `CanCollide` writes plus the 20/22 buffer | The physics broadphase is updated only when a puppet really crosses the line |
| One self-collider, and group rules that exclude everything else | Physics only ever checks your 3 parts against nearby blockers |
| Debug painting only on change | Zero cost when off |

**The range switch must not make things worse.** A player pacing along the edge must not flip
`CanCollide` every frame. The buffer zone and the change-only writes guarantee that, and the churn test
below proves it.

**The 10 Hz check is safe:** it adds at most 0.1 s of delay. At a 30 studs/s closing speed that's
3 studs, so a blocker is solid long before anyone is within reach (contact is at 2.2 studs).

**Under `BulkMoveTo`, each blocker adds 3 parts to the teleported assembly** (about 3% on a 106-part
puppet). That cost is included in the end check. #41 would make it near-free.

### End check (required before the PR is marked ready)

A throwaway probe (a plan attachment, never shipped) builds 30 puppets the way the pool does, moves them
with one `BulkMoveTo` per frame, and runs **the same scene with collision off and on** in one Studio
session, two rounds each. Script cost is the probe's own timing of the collision step; physics is the
difference in `Stats.PhysicsStepTimeMs`. The F4 microprofiler is the cross-check.

1. **Busy:** 30 puppets moving, 8 of them within 20 studs. Δ physics ≤ 0.4 ms, collision step ≤ 0.1 ms.
2. **Churn:**
   - puppets jittering inside the buffer (20.1–21.9 studs): **0** flips per second after the first check;
   - puppets sweeping 18–24 studs every 4 s: at most one flip per puppet per crossing (≤ 15/s for 30),
     never one per puppet per frame.
3. **Idle:** all puppets beyond 22 studs. Δ physics within run-to-run noise, collision step ≤ 0.05 ms.

A miss on any line means R6 isn't done. Fix it before asking the developer to verify.

**Result (2026-10-08):** TestEZ 1966/0 before the contact-velocity removal. Probe after the contact-range fix: busy Δphysics +0.13/+0.18 ms, step 0.106 ms (velocity writes for 2 puppets in contact range); jitter 0 flips with 30 solid; sweep 15 flips/s; idle step 0.017 ms. Each `AssemblyLinearVelocity` write on a just-moved ~100-part puppet measured ~27 µs (busy step 0.31 ms with all solid, 0.106 ms with the contact range of 8, about 0.05 ms without writes). Re-measured after the removal: see the PR description.

## 7. Cases

| Case | Behaviour |
|---|---|
| Spawning inside someone | Physics pushes you out. The trade-off of solid with no ghosting; §10's spawn-overlap ghosting is the later fix |
| A puppet walks into you | Its blocker stops you like a post; it never shoves you (decision 6). While both move, the other body is drawn slightly in the past and can overlap you briefly; physics separates you by a few hundredths of a stud |
| Two screens disagree briefly | Each client collides with the others' past (about 1.6 studs behind at running speed, CP7 close-out). Nothing authoritative depends on it in R6 |
| Feet on a head | Pushed off at ≥ 12 studs/s. Heads are never standable: the Humanoid never treats a blocker as floor, and friction is 0 |
| Respawn | Despawn destroys the old self-collider with the old rig, and spawn builds a new one |
| Puppet hidden (held, no sample) | Moved to `HIDDEN_CFRAME` by the existing code. It's out of range, so not solid |
| Raycasts, camera, clicks, touch | Unaffected: `CanQuery` and `CanTouch` are false |

## 8. Testing

**Specs (TestEZ, spec-first):**

- `CollisionConstants`: release range > solid range > 2 × radius; bottom < top; the span is at least
  2 × radius.
- `CollisionShapeUtils`:
  - part offsets and sizes join into exactly `BOTTOM`…`TOP` at `RADIUS`;
  - resting-on is true and false at the `REST_GAP` edges, at 2 × radius, and when rising;
  - the push direction is outward, with the facing fallback below `CENTRE_EPSILON`;
  - the range band: becomes solid at ≤ 20, stays solid at 21, releases at > 22, stays off at 21.
- `CollisionBlockerSystem` (real Parts on a fake rig with an anchored root):
  - build gives 3 parts with groups, flags and `WeldConstraint`s to the root;
  - a capsule built on a root parked far away still sits at the right offset after the root moves;
  - despawn destroys the parts;
  - despawn → spawn on the same model leaves exactly one capsule;
  - range updates write `CanCollide` only on change (a write counter);
  - the self-collider is `Massless` in `SELF_GROUP`.
- `CollisionSlideOffSystem` (a fake root):
  - pushes to ≥ 12 outward when resting;
  - leaves velocity alone when already moving out faster, when beside rather than on top, and when
    rising.
- `CollisionServiceServer` / `CollisionServiceClient`: spec-exempt shells, with a reason in
  `SpecRoots.EXEMPT_MODULES`, like VoiceServiceClient.

**Studio checklist (two players):**

- [ ] Walk into each other head-on and at an angle: blocked, no trip, no fling.
- [ ] Walk into a moving player and a standing one: stopped, never shoved.
- [ ] Jump onto a head: slid off, never stand.
- [ ] Walk away past 22 studs, then come back: solid again at 20 (F4 solid count).
- [ ] Respawn and rejoin: one capsule per body, `CollisionDebug` shows them in the right place.
- [ ] Camera, clicks and tools are unaffected near other players.
- [ ] The end check, §6.

## 9. Docs

- `docs/ROADMAP.md`: mark R6.
- The master spec's R6 row now reads "capsule blockers; the server-side size table is the anti-cheat
  contract" (decision 3).
- `docs/project-structure.md`: the regenerated module map.

## 10. Later (recorded, not built)

- **Anti-grief hybrid** (developer: "hybrid later"):
  - **spawn-overlap ghosting:** a player spawning inside someone is not solid until they separate;
  - **stuck release:** two players overlapping for a while stop colliding until apart;
  - an **`isSolidFor(viewer, other)`** policy hook for zones (hubs) and relationships (party, team).
- **Slide into each other: no FallingDown**, when the Movement phase adds slide.
- **Anti-cheat:** reads `CollisionConstants` for players as ground and walls.
- **#41:** the Motor6D move path. It also makes blockers near-free to move.
