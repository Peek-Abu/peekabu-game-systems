# Animation system

The onboarding doc for anyone touching animations — programmers, animators, modelers. Built in
Phase 6 as a NEW system (the old game's animation code was evidence, not source; see the spec:
`docs/superpowers/specs/2026-07-20-animation-handler-design.md`).

## The one-paragraph version

Every animation id lives in **one registry** (`Shared/Features/Animation/Data/`, enforced by CI). Everything
that plays goes through **one track owner** (`AnimationPlayerSystem` — load once, cache, reuse).
Character movement animations (idle/walk/run/jump/…) are driven by **`AnimationLocomotionSystem`**, our
replacement for Roblox's default `Animate` script. **Every client animates the rigs it shows**: its own
rig from its Humanoid, and every other player's puppet from the movement records it already receives.
**Server-granted actions** (`AnimationServiceServer:play`) reach the owner and every viewer as timed
body state and play in sync, with the server's variant and speed. What may stop what is **declared per
animation**, not guessed from names.

## Map — where everything lives

| Piece | Path | Job |
|---|---|---|
| Registry | `src/ReplicatedStorage/Shared/Features/Animation/Data/` | THE home of animation ids. One module per domain (`AnimationLocomotionRegistry.luau`, `AnimationActionRegistry.luau` (R3 stand-ins); Combat/Emotes/Npc/... arrive with their phases) + `AnimationRegistry.luau` composing them into one lookup (and resolving wire ids), + `AnimationTypes.luau` (types, layers, guards) |
| Track owner | `Shared/Features/Animation/Systems/AnimationPlayerSystem.luau` | The ONLY code that may call `LoadAnimation`. Per-Animator track cache, typed play handles, bookkeeping, class-based stops, `warm()` preloading, a chosen `variant`, a `startAt` seek, `setPaused` (puppet LOD) |
| Runtime shell | `Shared/Features/Animation/Systems/AnimationPlayerEngineSystem.luau` | Wraps a real `Animator` for the player; memoizes ONE player per Animator so every consumer shares one truth |
| Locomotion | `Client/Features/Animation/Systems/AnimationLocomotionSystem.luau` | Pure state→pose core: which pose, fades, speed scaling, jump window, kill switch, pose-override seam |
| Locomotion binding | `Client/Features/Animation/Systems/AnimationLocomotionHumanoidSystem.luau` | Thin adapter: Humanoid events → AnimationLocomotionSystem, plus a Heartbeat `update` (the jump-window fall). Bound by `ReplicationOwnerRigSystem` to the client-built rig (no engine character exists, so no stock Animate script either) |
| Client service | `Client/Features/Animation/AnimationServiceClient.luau` | Local play/stop API on your own rig + the diagnostic listeners + boot-time preload/dead-id report |
| Server service | `ServerScriptService/Features/Animation/AnimationServiceServer.luau` | **Grants**: `play` / `stop` / `stopAttacks` / `stopAll` on a player's body (rules in `AnimationActionGrantSystem`), carried as timed body state by the replication service; `playOnRig` for server-owned rigs (NPCs, later) |
| Rig animation (client) | `Client/Features/Replication/Systems/ReplicationRigAnimationSystem.luau` | Plays granted actions on the owner rig and every puppet (`ReplicationActionTracker`), drives each puppet's AnimationLocomotionSystem (`ReplicationPuppetLocomotionSystem`), and puppet LOD (`ReplicationAnimationRules`) |
| Packets | `Shared/Features/Replication/Net/ReplicationEvents.luau` (`ActionStarted` / `ActionStopped`) + `Shared/Features/Animation/Net/AnimationEvents.luau` (diagnostics) | Typed reliable structs; actions ride the replication service's reliable channel, so a viewer's `Enter` always precedes the actions replayed to it |
| Debug panel | F4 → **Anims** tab; F4 → **Services** | Anims: live tracks on YOUR character (registry id, domain/class, priority, weight, speed, asset id). Services: `ReplicationServiceClient.animation` (action counters, length mismatches, drift, puppets per LOD tier), `ReplicationServiceServer.bodyStates` and `AnimationServiceServer` (grants) |
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
- **From the server, on a player's body (everyone sees it):**
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

## Replicated actions

A grant is **timed body state** of kind `"action"` (ReplicationServiceServer), keyed by layer:

- **One grant per layer per body.** A new grant on a layer replaces the old one, unless the old one is
  `protected` and the new one is not (an attack cannot cut a dodge; a hit reaction can cut an attack).
- **Everyone plays the same thing.** `ActionStarted` carries the entry's wire id, the server's variant and
  speed, the server start time and the duration (`durationMs / speed`; none for a looped entry). The owner
  plays it on its own rig, every viewer on its puppet: one path, no double plays.
- **Start alignment, no re-sync.** A clip starts `(now − start) × speed` seconds in. The owner's "now" is
  the session clock; a puppet's is its render time, so the clip lines up with the motion being drawn. A
  viewer that walks into range mid-action gets the action replayed right after the body's `Enter` and
  joins at the right point. F4 shows drift as a readout only.
- **Ending.** An early stop sends `ActionStopped`; a one-shot simply ends; an open-ended grant nobody stops
  ends at the 30 s safety cap on every screen. Respawn, slot switch and leaving clear grants silently.
- **Length check.** Each client compares a clip's real length with its `durationMs` once and counts a
  mismatch (F4, and a log warning naming the entry).

## Puppets: locomotion and LOD

Every puppet runs the owner's code path: an `AnimationPlayerSystem` and an `AnimationLocomotionSystem` per puppet,
fed by `ReplicationPuppetLocomotionSystem` from the interpolated movement state (no extra network traffic), with the
walk/run play rate clamped to 0.7-1.4. **Puppet LOD**: the engine does not throttle client-built rigs,
so a puppet off screen or beyond 275 studs (back within 250 to unfreeze; 25 studs of hysteresis) is frozen:
its pose is held and its position keeps updating. The pause detaches the puppet's Animator (measured on 40
rigs: 0.214 ms per animation step vs 0.331 ms playing; zeroing track speeds saved nothing, 0.325 ms).
Set the Workspace attribute `PuppetLodEnabled = false` to keep every puppet animating (measurement). The
`LocomotionEnabled` kill switch stops puppet locomotion too.

For the later Death and Ragdoll phases, `AnimationServiceServer:stopAll(player)` ends every action grant on
that body and sends the Stopped messages (`AnimationPlayerSystem:stopAll` is only the client-side track stop).

## Locomotion (movement animations)

`AnimationLocomotionSystem` decides poses from Humanoid state: idle / walk / run (speed-scaled) / jump
(with a window before fall) / fall / climb / swim / swimidle / sit. On death it plays NOTHING —
it stops its tracks and latches until respawn (the old game deprecated its death animation; what
death looks like belongs to the future Death/Ragdoll phase). Tuning knobs sit at the top of the module (`walkRunThreshold`, per-pose speed scales,
fades). Two things to know:

- **Walk vs run is a speed threshold FOR NOW** (default WalkSpeed 16 = walk; >18 = run). The old
  game used the movement system's sprint flag; when the Movement phase ports sprinting it
  replaces the threshold. Movement adds parkour poses through
  `setPoseOverride`/`clearPoseOverride` — nobody edits the Animate script (that's how the old
  1,601-line fork happened).
- **Kill switch:** set the Workspace attribute `LocomotionEnabled = false` and every locomotion
  track stops — instantly answers "is the weirdness on screen ours?". `true` recovers, no respawn.

## The Retargeting gotcha (check this FIRST if poses ever look wrong)

`Workspace.Retargeting` MUST be `Disabled`. Our rig is custom-proportioned but uses standard R15
joint names, and Roblox's retargeting "helpfully" remaps animations to standard proportions —
which visibly wrecks every pose. `default.project.json` owns the property (a property-only
`Workspace` node; Rojo still cannot touch Workspace *content*), so a Rojo-synced place is always
correct — but a place copy that was never synced will show exactly "all animations look broken".

## Verification tools

| Tool | What it answers |
|---|---|
| F4 → **Anims** | What is playing on my character right now, at what priority/weight/speed, from which registry entry? Are loads cached (`loads` plateaus, `hits` climbs)? |
| `animationplay <player> <id> [speed] [variant]` / `animationstop <player> <id or layer>` | Does this action play on every screen, in sync, with the same clip and speed? Does it stop everywhere? |
| `animationstopclass <player> attack` | Do the interruption rules hold? (only `attack` grants end; `protected` and `ambient` are refused) |
| `animationtracks` | Dump my client's live bookkeeping to the client log |
| `animationreport` | Registry census + probe every asset id, dead ones named by registry key |
| `LocomotionEnabled=false` | Is what I'm seeing ours at all? |

## What this system deliberately does NOT do (yet)

Owned by later phases, arriving as new registry domains + consumers of the same primitives:
emotes (wheel/ownership/gating), combat swings & skill casts (each calls `AnimationServiceServer:play`
after its own permission checks; client-requested actions with owner prediction arrive with the first of
them), NPC playback (via `playOnRig`), parkour poses (Movement, via the pose-override seam),
footstep/equipment sounds and marker effects on puppets (Sound/VFX phase, via the `onMarker` hook on play
handles), aim pitch on puppets (Combat), foot locking (later polish).
