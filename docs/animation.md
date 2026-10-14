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
Only arm chains are driven; no joint, attachment or Transform is written.

- **Carried cargo** (`AnimationCarrySystem`, planned by `AnimationCarryContactUtils`): `measure` reads the
  carrier from its rig in root space (shoulders, reach from shoulder to the palm point the IK drives, torso
  front, head front and bottom, floor). The item sits just in front of the torso at chest/belly height (half
  an arm below the shoulders), under the head or, when too tall, out past the face, never into the floor.
  Each hand takes the first reachable contact on the item: its side near the body, the near vertical edge,
  then flat on the near face. Pippa at 1.25x (arms ~1 stud, a round torso, a head hanging just above the
  shoulders) used to get the old fixed 0.44-stud near distance, which put the box's near face inside her
  torso and her palms with it: the arms read as hanging at her sides with the box floating at her hip.
  Every cargo kind is held with two hands on both her and a stock R15 rig (spec'd). A caller-owned
  `holdOffset` (the bulky cart) is kept, and gets no hands when they cannot reach it.
  **The hold is planned on what can be seen** (`AnimationCarrySystem.visibleBox`: the item's parts with
  Transparency below 1, boxed in its pivot frame). Cargo is an invisible size-class proxy (`CargoRegistry`
  partSize, 2-3 studs) with its art welded inside it, uniformly fitted and standing on its floor, so the art
  is smaller than the proxy on two axes: up to 0.86 studs shallower (monitor), 1.5 shorter (printer), 0.67
  narrower (plaque). Planning on the proxy put the palms 0.15-0.86 studs off the art, in the air, and the art
  up to 0.96 studs out from the belly. Measured in play on Pippa (2026-10-14): palms within 0.01 (recycling
  box) to 0.14 studs (water jug, held out past her face) of their targets at idle, 0.12-0.24 walking. `CarryGripRight` / `CarryGripLeft` attachments on a template still
  override the box contacts when reachable.
- **The vacuum** (`VacuumHoldFormulas`, `AnimationVacuumHoldSystem`): the same full-size vacuum for
  everyone. Its body hangs ~1.5 studs and its floor head ~1.9 below the grip, where a stock avatar's
  hanging hand holds it upright. For a shorter holder the hold is fitted, not the vacuum: it is tilted
  front-up about the grip, as little as clears the floor, up to 25 degrees; past that, the right hand is
  lifted by an arm IK (target on the root, beside the torso, oriented so the vacuum stands upright) for
  the rest. Pippa (hang 0.86) gets 6.75 degrees and a 0.89-stud lift; the lowest point stays 0.04-0.11
  studs above the floor at idle, walk and run. No IK smoothing: 0.1 s let the walk bob dip it 0.15 below.

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

## What this system deliberately does NOT do (yet)

Each game adds these as new registry domains + consumers of the same primitives: emotes
(wheel/ownership/gating), combat swings and ability casts (each calls `AnimationServiceServer:play` after
its own permission checks), NPC and creature playback (via `playOnRig`), special movement poses (via the
pose-override seam), footstep sounds and marker effects (via the `onMarker` hook on play handles).
