# Animation system

The onboarding doc for anyone touching animations — programmers, animators, modelers. The design record
behind it is `docs/superpowers/specs/2026-07-20-animation-handler-design.md` (historical; written for the
RPG this base came from).

## The one-paragraph version

Every animation id lives in **one registry** (`Shared/Features/Animation/Data/`, enforced by CI). Everything
that plays goes through **one track owner** (`AnimationPlayerSystem` — load once, cache, reuse).
Character movement animations (idle/walk/run/jump/…) are driven by **`AnimationLocomotionSystem`**, our
replacement for Roblox's default `Animate` script, running on each player's own native character.
**The engine replicates what the owner plays**, so every client sees every character animate with no
extra code. **Server-granted actions** (`AnimationServiceServer:play`) are one packet to the owning client,
which plays them with the server's variant and speed. What may stop what is **declared per
animation**, not guessed from names.

## Map — where everything lives

| Piece | Path | Job |
|---|---|---|
| Registry | `src/ReplicatedStorage/Shared/Features/Animation/Data/` | THE home of animation ids. One module per domain (`AnimationLocomotionRegistry.luau`, `AnimationActionRegistry.luau` (stand-ins); a game adds Combat/Emotes/Npc/... domains) + `AnimationRegistry.luau` composing them into one lookup (and resolving wire ids), + `AnimationTypes.luau` (types, layers, guards) |
| Track owner | `Shared/Features/Animation/Systems/AnimationPlayerSystem.luau` | The ONLY code that may call `LoadAnimation`. Per-Animator track cache, typed play handles, bookkeeping, class-based stops, `warm()` preloading, a chosen `variant`, a `startAt` seek, `setPaused` (a level-of-detail freeze) |
| Runtime shell | `Shared/Features/Animation/Systems/AnimationPlayerEngineSystem.luau` | Wraps a real `Animator` for the player; memoizes ONE player per Animator so every consumer shares one truth |
| Locomotion | `Client/Features/Animation/Systems/AnimationLocomotionSystem.luau` | Pure state→pose core: which pose, fades, speed scaling, jump window, kill switch, pose-override seam |
| Locomotion binding | `Client/Features/Animation/Systems/AnimationLocomotionHumanoidSystem.luau` | Thin adapter: Humanoid events → AnimationLocomotionSystem, plus a Heartbeat `update` (the jump-window fall). Bound per character by `StarterCharacterScripts/Animate.client.luau`, whose name also suppresses the engine's stock Animate script |
| Client service | `Client/Features/Animation/AnimationServiceClient.luau` | Local play/stop API on your own character + plays server-granted actions (one handle per layer) + the diagnostic listeners + boot-time preload/dead-id report |
| Server service | `ServerScriptService/Features/Animation/AnimationServiceServer.luau` | **Grants**: `play` / `stop` / `stopAttacks` / `stopAll` on a player's character (rules in `AnimationActionGrantSystem`, live grants in `AnimationGrantTracker`); `playOnRig` for server-owned rigs (NPCs) |
| Packets | `Shared/Features/Animation/Net/AnimationEvents.luau` | Typed reliable structs, server → owning client only: `ActionStarted` / `ActionStopped` (grants) and the two diagnostics |
| Debug panel | F4 → **Anims** tab; F4 → **Services** | Anims: live tracks on YOUR character (registry id, domain/class, priority, weight, speed, asset id). Services: `AnimationServiceServer` (granted / refused / stopped counters) |
| Admin commands | `animationplay` `animationstop` `animationstopclass` `animationtracks` `animationreport` | The Cmdr verification harness (see below) |

## "I want to add an animation" (animators start here)

1. Upload the animation to Roblox; get its asset id `N`.
2. Open the domain module it belongs to under `Features/Animation/Data/` (today: `AnimationLocomotionRegistry.luau`;
   a new feature area gets its own file + one line in `AnimationRegistry`'s `DOMAIN_MODULES`).
3. Add an entry:

```luau
myanimation = entry("rbxassetid://N", looped),
-- or, in a future domain module, the full shape:
myanimation = {
	assetId = "rbxassetid://N",   -- canonical form ONLY (no www.roblox.com/asset URLs)
	priority = Enum.AnimationPriority.Action, -- where it layers (locomotion = Core, the base)
	looped = false,
	interruption = "attack",      -- see "Interruption classes" below
	variants = { "rbxassetid://M" }, -- optional: play rolls ONE of assetId + variants
},
```

4. In Studio (Cmdr console, a Play session): `animationreport` to confirm the asset loads. A replicable
   action (below) plays on everyone's screen with `animationplay yourname myanimation`.

**A replicated action** (something the server grants and everyone sees: attacks, reactions, emotes)
also declares, in its domain module (see `AnimationActionRegistry.luau`):

```luau
myaction = {
	assetId = "rbxassetid://N",
	priority = Enum.AnimationPriority.Action, -- never Core: Core is locomotion's base
	looped = false,
	interruption = "attack",
	replicable = true,
	wireId = 4,          -- the next unused integer, 1-65535; PERMANENT (never reuse or renumber)
	layer = "full",      -- full | upper | overlay: the grant slot it occupies
	durationMs = 900,    -- one-shots only: the clip's length at speed 1, measured in Studio
},
```

The registry refuses a replicable entry without a unique `wireId`, a known `layer`, or (for a one-shot)
`durationMs`, and refuses those fields on a local entry. Measure `durationMs` in a play session: load
the clip on an Animator (`animator:LoadAnimation(...)`), wait until the track's `Length > 0`, and use
`Length * 1000`. A wrong value shows up in F4 as a length mismatch.

**Rules the build enforces (you cannot get these wrong silently):**
- An asset id ANYWHERE outside the registry folder fails CI (the old game had ids in 6+ places;
  never again). Spec-file fixtures and the item registry (`ItemContentRegistry`) are the only exceptions.
- A malformed entry (wrong id format, unknown class, duplicate key across domains) fails at
  require time — the first test run or boot catches it.
- A dead/unloadable id does NOT break anything: the boot-time probe logs it BY REGISTRY KEY
  (client log, F4 → Logs) and the fix is a one-line registry edit.

## "I want to play an animation" (programmers)

Never touch `Instance.new("Animation")` or `LoadAnimation` — that per-play pattern is the old
game's disease and the CI gate + review will bounce it. Instead:

- **On the local character (client code):** `AnimationServiceClient:play("id", opts?)` → returns a
  handle (`stop` / `adjustSpeed` / `onMarker` / `isPlaying`). Options: `fadeTime`, `speed`,
  `weight`, `priority` (registry defaults apply otherwise).
- **From the server, on a player's character (everyone sees it):**
  `AnimationServiceServer:play(player, "id", { speed?, variant? })` → `(ok, reason?)`. Only replicable
  entries; the server clamps the speed (0.25-4), picks the variant when you do not, and applies the
  layer's interruption rule. `stop(player, idOrLayer)` and `stopAttacks(player)` end grants early.
  Gameplay systems (combat, abilities, emotes) call `play` after their OWN permission and cooldown
  checks; cooldowns never live on animation definitions.
- **On a server-owned rig (NPCs/world models):** `AnimationServiceServer:playOnRig(model, "id")`.
- **On any character/model you hold directly (advanced):**
  `AnimationPlayerEngineSystem.forCharacter(model)` → the shared per-Animator player.

Tracks are cached: playing the same id twice costs one load, ever. The F4 panel's
`loads`/`hits` counters prove it.

## Interruption classes (what may stop what)

Declared per registry entry — never inferred from names (the old game matched substrings like
`"dodge"` at runtime; a rename silently changed combat behavior):

- `attack` — killed by the bulk stop-attacks verb (combat interrupts).
- `protected` — NEVER bulk-stopped: dodges, blocks, hit reactions, death, emotes.
- `ambient` — locomotion-level; bulk stops ignore it (a combat verb must never kill your walk).

Individual `stop("id")` works on anything. Bulk stops act on `attack` only, refused everywhere
else (command, server, and core all enforce it — try `animationstopclass yourname protected` to watch
the refusal).

## Server-granted actions

The server remembers what it granted per player, per layer (`AnimationGrantTracker`), and sends the owner
one packet per change:

- **One grant per layer per character.** A new grant on a layer replaces the old one, unless the old one
  is `protected` and the new one is not (an attack cannot cut a dodge; a hit reaction can cut an attack).
- **The owner plays it; the engine replicates it.** `ActionStarted` carries the entry's wire id, the
  server's variant and the clamped speed. The owner plays it on its character's Animator (stopping
  whatever its previous grant on that layer was), and the engine shows that track to every other client.
- **Ending.** An early stop sends `ActionStopped`; a one-shot simply ends (the server's record expires
  after `durationMs / speed`); an open-ended (looped) grant lasts until it is stopped or replaced.
  Respawn and leaving clear the server's record silently (the character's tracks died with it).
- **Death / ragdoll hook.** `AnimationServiceServer:stopAll(player)` ends every action grant on that
  character and tells the owner (`AnimationPlayerSystem:stopAll` is only the client-side track stop).

**NPCs and creatures** animate through `playOnRig` on the server (or the same `AnimationPlayerSystem` on
a client-owned rig). `AnimationLocomotionSystem` takes an optional walk/run rate clamp for rigs driven from
an estimated speed rather than a local Humanoid.

## Locomotion (movement animations)

`AnimationLocomotionSystem` decides poses from Humanoid state: idle / walk / run (speed-scaled) / jump
(with a window before fall) / fall / climb / swim / swimidle / sit. On death it plays NOTHING —
it stops its tracks and latches until respawn (what
death looks like belongs to a game's death/ragdoll system). Tuning knobs sit at the top of the module (`walkRunThreshold`, per-pose speed scales,
fades). Two things to know:

- **Walk vs run is a speed threshold** (default WalkSpeed 16 = walk; >18 = run). A game with a
  sprint system replaces the threshold with its sprint flag, and adds special poses (riding,
  carrying, crouching) through `setPoseOverride`/`clearPoseOverride` — nobody edits the Animate
  script itself (forks of it are how animation code rots).
- **A character's own clip set:** the core's `poseIds` config maps a logical pose to a registry id
  (`{ idle = "pippaidle", walk = "pippawalk", run = "pipparun" }`); poses it leaves out play the stock
  entry. `Animate.client.luau` passes it to `AnimationLocomotionHumanoidSystem.bind(character, config)`.
  Cleanup Crew: an employee's `EmployeeRegistry` entry carries `locomotion` (registry keys in the
  `employee` domain plus planted speeds and rate caps); `EmployeeLocomotionUtils.forName` turns the
  character's `EmployeeName` attribute into the config, and an employee without one keeps the stock set.
- **Speed matching:** for such a set, `walkScale` / `runScale` are the clips' planted speeds (studs/s at
  which the feet do not slide at 1x), so a stride plays at `clamp(speed / plantedSpeed, minRate,
  walkMaxRate | runMaxRate)`. Pippa: walk 1.27 st/s capped at 2.5x, run 1.52 st/s capped at 2.2x, floor
  0.6x. Those are measured on the template; an employee spawns at its registry `scale` (Model:ScaleTo at
  install: joints, attachments and HipHeight scale, and clips play scaled on the scaled rig, verified in
  Studio 2026-10-13), so the planted speeds are multiplied by it (Pippa at 1.25: 1.59 / 1.9). At WalkSpeed 16 both are at their cap, so the feet slide (accepted for the MVP: her 0.68-stud
  legs cannot plant at 16 st/s at any sane cadence). The walk/run switch stays the 18 st/s threshold,
  so with no sprint in the game yet her run only shows above WalkSpeed 18.
- **Jump and fall clips must suit a native Humanoid.** `Jumping` fires at takeoff (the character is already
  rising), and landing switches straight to `running`, so a jump clip must not open on a ground crouch and a
  fall clip must not drop the hips: the inherited custom-controller clips did both (hips 0.6-0.9 studs down),
  which crouched in mid-air and drove the feet through the floor on every landing (fixed 2026-10-13 with the
  stock R15 jump 507765000 and fall 507767968). A replacement clip is checked the same way: feet never below
  the floor through a jump, measured on the rig.
- **Kill switch:** set the Workspace attribute `LocomotionEnabled = false` and every locomotion
  track stops — instantly answers "is the weirdness on screen ours?". `true` recovers, no respawn.

## Holding things (IK over locomotion)

Holds are native `IKControl`s the server creates under the holder's Humanoid (every client's Animator solves
them), weight 1 over whatever locomotion clip plays, so idle, walk and run all keep the hands on the object.
Only arm joints are driven; no rig joint's C0/C1 or attachment is written.

- **Carried cargo**: one system decides and shows every hold, for any item, with no per-item tuning. A new prop
  needs only a template that keeps the contract below; the validator then proves it on both test carriers.

  **The pipeline** (all in the carrier's HumanoidRootPart space at the rig's REST pose):
  1. `AnimationCarryMeasureSystem.measure` reads the carrier from its rig: each arm bone by bone (joint pivots,
     rest frames, the palm from the hand and its grip), through Motor6Ds or the upgraded avatar joints'
     AnimationConstraints (a stock R15 built in this place has those, with BallSocketConstraint limits); the torso and
     head as stacked slices of their REAL surface (rays at eight heights; a round body is narrow at the shoulders and
     wide at the belly, and its box's ellipsoid put Pippa's arms "into" a chest she does not have); the floor.
  2. `AnimationCarrySurfaceSystem` probes the item's VISIBLE surface (rays against its parts with Transparency below
     1, made queryable only while planning). The hold is planned on that surface, never on a box round it.
  3. `AnimationCarryHoldRules.choose` picks the styles to try from the item's visible size, carry weight and handle,
     against this carrier's arms and head (below).
  4. `AnimationCarryContactUtils.plan` places the item and finds each palm's contact on the real surface
     (`AnimationCarrySurfaceUtils`: under the bottom, cupping a lower side, flat on a face, the top), solves both arms
     in full (`AnimationCarryArmUtils.solve`) and judges every candidate with `AnimationCarryPoseRules`; the first
     that passes is the hold (else the least bad, which the validator then fails).
  5. `AnimationCarrySystem.mount` joins the item to the body part its hold rides; `bind` drives the arms.

  **The hold rules** (`AnimationCarryHoldRules`; thresholds there and in `AnimationCarryContactUtils`):
  - **push** only, for anything as heavy as furniture (weight >= 10: the filing cabinet). It stands on the floor in
    front, its near face just off the belly (and clear of the head, judged on the head's real surface), both palms
    flat on that face a little below the shoulders, fingers up and turned in, elbows bent.
  - **hand** first, for a light item (weight <= 1.5) a hand can close round: a `CarryHandle`, or a level side no
    wider than 1.6 hand lengths (the plaque, the stapler). It hangs from the relaxed right arm (10-30 degrees out,
    8 forward, never raised) with its handle in the fist (the hand's GripAttachment), turned so its longer level side
    runs front to back, and swings (CarrySwaySystem). Not offered when it would not clear the floor and the body from
    a relaxed arm: on Pippa every 2-stud bag goes on to `under`; a stock R15 hangs them.
  - **under** for everything else: the recycling-box hold. The near side against the belly, the palms on the real
    bottom (palm up, a little in from the near edge, wide first so a round body's arms angle out round the belly),
    as low as the arms comfortably reach; where no bottom is in reach or flat enough (a 2-stud sack on 1-stud arms, a
    pot narrower than the shoulders) the palms cup the item's lower sides instead, so it rides lower.
  - **push** before **under** for a heavy item (weight >= 7) whose top would rise past the middle of the carrier's
    head if lifted (the water jug and the coffee machine): it would hide the carrier's eyes. Push is always the last
    resort.
  - An art can pin its own (`CarryHold` attribute on the template: "hand", "under" or "push"), tried first;
    `AnimationCarryRegistry` can pin a kind the same way (empty: no kind needs it).
  - **Too big for the arms**: nothing is scaled. A lifted item may cover the face, and press into the face of a toon
    whose head overhangs its belly by up to 0.2 stud: Pippa's face plate is 0.45 in front of her belly, so a box taller
    than ~1 stud held at her belly meets her muzzle 0.13-0.18 deep (the recycling box the playtest approved does; her
    1-stud arms cannot hold it lower or further out). A heavy item that would hide the eyes is pushed instead when the
    arms can reach its face (not the fish tank: its face is below her reach). Scaling an item down while it is held
    would clear the face; it is not done (it changes how big the item looks in the hands).

  **Joint safety** (`AnimationCarryArmUtils`, limits in `LIMITS`): the elbow is a hinge fixed in the upper arm
  (square to the forearm and forward at rest), so the upper arm is turned to carry the bend in that hinge and it
  never bends sideways; the forearm then rolls within pronation 85 / supination 95 of the palm-in neutral; the wrist
  bends (flexion / extension only) up to 65 for what the forearm could not turn (palms flat on a pushed face, or
  under a tray on straight arms). `AnimationCarryPoseRules` checks elbow flexion (-5..150) and side bend (15),
  forearm roll, wrist (70, 15 sideways, 10 twist), the upper arm (35 above level, 45 behind, no forward-pointing
  elbow), the palm ON the visible surface (0.06 stud, 45 degrees; one hand: the fist 0.06 from the handle), the arm
  out of the torso (0.15 of the way into a slice; Pippa's own idle reaches 0.12) and the item, the item out of the
  torso (0.06) and head (0.2 lifted, 0.03 pushed, measured as how far the body's surface is sunk into the item; the
  head includes everything joined to it: face plate, ears, glasses), and off the floor (0.1; pushed: on it).

  **Driving the arms (IK research and decision, 2026-10-15).** The engine's `IKControl` stays the solver: it
  replicates, every client's Animator solves it over whatever locomotion plays, and it reaches a 6-DoF target to
  0.0001 stud. What it cannot do is pick anatomy: a two-bone 6-DoF chain keeps the animation's upper-arm roll, which
  bent Pippa's elbows ~50 degrees out of their hinge with the forearm twisted ~86 (measured live). So the anatomy is
  solved analytically (`AnimationCarryArmUtils.solve`) and each joint gets its own single-joint Transform control
  (`bind`: shoulder, elbow, wrist; priorities 20-23 resolve in that order), so the solver has nothing left to choose.
  The targets ride the UpperTorso at their rest-pose place (an item on the torso or the hand never chases itself);
  a pushed item's ride the item, with a two-bone re-reach onto it after the torso's bob, and CarryPushSystem slides
  the item level after the torso (a stock walk leans the torso a stud forward of the root). Findings that shaped
  this: an end effector AT its joint's pivot (a stock R15 hand's WristRigAttachment) has no lever and returns NaN,
  so the hand is driven by its grip; IKControl honours BallSocketConstraint / HingeConstraint limits in its model
  (the IK joint-constraint feature), and against the upgraded avatar joints' ball sockets a single-joint 6-DoF
  control returns NaN, so `bind` lifts those limits while the arm is driven (the planned pose is already inside
  anatomical limits) and puts them back on release; `SmoothTime` is 0: a 0.08 s spring trailed the hands behind a
  walking torso. Hinge constraints were not used for the elbow: a pure hinge forbids the forearm roll a carry needs.

  **The template contract** (cargo kits: `ReplicatedStorage.Assets.CleanupCrew.ArtKits.<kit>.cargo.<kind>`):
  - Every visible MeshPart uses `CollisionFidelity = PreciseConvexDecomposition`: its collision is the "visible
    surface" the palms go on (Default was measured up to 0.44 stud off it: the monitor; 0.36 the coffee machine).
  - `FrontAxis` as ArtVisualSystem expects; nothing invisible needs authoring.
  - Optional, only where automation cannot decide: `CarryHandle` (Attachment: the point a fist holds it by; else the
    top of its surface), `CarryBodyFront` (Attachment: the depth held against the body, a pot under wider leaves),
    `CarryHold` (attribute on the template model). `CarryGripLeft` / `CarryGripRight` are not read.

  **The validator** (`AnimationCarryHarness`, carriers from `AnimationCarryRigHarness`, clips from
  `AnimationCarryClipHarness`): every template in the cargo
  folder, on Pippa (built from her art as EmployeeSpawnSystem installs her) and a stock R15, planned and LIVE (the
  engine's IK over each carrier's own idle and two walk frames), judged by the same rules, plus the contract. A frame
  is sampled only after its clip has loaded and is checked shown at its time and full weight: a track's `Length` is 0
  until the asset arrives and a `TimePosition` set before then is lost, so the first hold of a session once judged
  frame 0 or the rest pose and the result depended on suite order. Its spec
  runs in the TestEZ suite (`Workspace.RunTests = true`) and prints a report; from a server Script in play:
  `print(Harness.format(Harness.run({})))` (`{ record = true }` keeps every live pose). A template, rig or rule change
  that would show a hold wrong fails it.
- **The vacuum** (`VacuumHoldFormulas`, `VacuumVisualSystem`, `AnimationVacuumHoldSystem`): a backpack canister
  and a hand wand held in both hands, the right hand on the wand skin's `GripUpper`, the left on its `GripLower`
  (the grip contract, `characters/vacuum/README.md`); the wand telescopes so its floor head rests on the floor from
  the holder's grip. The hold is planned once, when the shift's Tool is made, from the holder's arms read at the
  rig's **rest pose** (`VacuumVisualSystem.arm`: the shoulder through `AnimationCarryMeasureSystem.restFrame`, never
  the pose of the moment): the Tool is made while the crew, just placed in the truck, is falling onto its bed, and a
  plan read from that pose (torso 0.36 forward, pitched 23 degrees) put Pippa's left hand out of reach, so that arm
  hung at full stretch, swaying with the idle, 0.2-0.3 stud off the wand. Two Transform IKControls (shoulder to
  grip attachment) hold the arms to targets fixed on the root, no smoothing, so the floor head glides level.

  **The validator** (`AnimationVacuumHarness`): Pippa in every vacuum skin, the hold planned mid-fall (the stock
  fall clip), then judged live over her idle, walk and run (two frames each) and vacuuming (the use clip when one
  is registered, else the locomotion it plays over): each hand's grip attachment must be on its wand grip within
  0.05 stud. Runs in the TestEZ suite; from a server Script in play: `print(Harness.format(Harness.run({})))`. A
  stock R15 is not validated (every player spawns as an employee): its left hand does not reach `GripLower`.

## Retargeting (check this FIRST if poses ever look wrong)

`Workspace.Retargeting` is a per-place setting this base leaves at its default. A game whose rig is
custom-proportioned but uses standard R15 joint names usually wants it `Disabled` (retargeting remaps
animations to standard proportions, which visibly wrecks every pose on such a rig). Set it with a
property-only `Workspace` node in that game's `default.project.json`, so a Rojo-synced place is always
correct; a place copy that was never synced will show exactly "all animations look broken".

**The exception: a rig whose rest pose is not the stock one.** Retargeting maps a clip through the
rig's own rest pose, so a rig authored in a T-pose (arms along ±X) NEEDS it. Cleanup Crew's employees
(Pippa) are exactly that, and were tested both ways in Studio (2026-10-13) with the stock idle and
walk: with `Default` (retargeting on) the arms hang and swing normally (the shoulder gets about −70°
of roll on top of the clip); with `Disabled` the clip plays its raw joint rotations on the T-pose and
the arms stay straight out. So that game leaves `Retargeting` at `Default` (ideally pinned to
`Enabled` with a property-only `Workspace` node). Check the rig's rest pose before choosing.

## Verification tools

| Tool | What it answers |
|---|---|
| F4 → **Anims** | What is playing on my character right now, at what priority/weight/speed, from which registry entry? Are loads cached (`loads` plateaus, `hits` climbs)? |
| `animationplay <player> <id> [speed] [variant]` / `animationstop <player> <id or layer>` | Does the action play on the character (and show on every other client)? Does it stop? |
| `animationstopclass <player> attack` | Do the interruption rules hold? (only `attack` grants end; `protected` and `ambient` are refused) |
| `animationtracks` | Dump my client's live bookkeeping to the client log |
| `animationreport` | Registry census + probe every asset id, dead ones named by registry key |
| `LocomotionEnabled=false` | Is what I'm seeing ours at all? |
| Carry validator (`AnimationCarryHarness`, in the TestEZ suite) | Does every carry template show right on Pippa and a stock R15, planned and live, idle and walking? Prints a per-hold report |

## What this system deliberately does NOT do (yet)

Each game adds these as new registry domains + consumers of the same primitives: emotes
(wheel/ownership/gating), combat swings and ability casts (each calls `AnimationServiceServer:play` after
its own permission checks), NPC and creature playback (via `playOnRig`), special movement poses (via the
pose-override seam), footstep sounds and marker effects (via the `onMarker` hook on play handles).
