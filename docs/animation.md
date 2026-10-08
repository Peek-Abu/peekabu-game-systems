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
- **Kill switch:** set the Workspace attribute `LocomotionEnabled = false` and every locomotion
  track stops — instantly answers "is the weirdness on screen ours?". `true` recovers, no respawn.

## Retargeting (check this FIRST if poses ever look wrong)

`Workspace.Retargeting` is a per-place setting this base leaves at its default. A game whose rig is
custom-proportioned but uses standard R15 joint names usually wants it `Disabled` (retargeting remaps
animations to standard proportions, which visibly wrecks every pose on such a rig). Set it with a
property-only `Workspace` node in that game's `default.project.json`, so a Rojo-synced place is always
correct; a place copy that was never synced will show exactly "all animations look broken".

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
