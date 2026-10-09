# Design — Animation System (Refactor Phase 6)

**Status:** v2 APPROVED 2026-07-20 (incl. in-phase Animate replacement), with the developer's
standing condition: **extra testing and verification checkpoints throughout** — the plan treats
developer Studio verification as a first-class gate, not a final step. · **Date:** 2026-07-20 ·
**Phase:** 6 of the Venture port — the first system of the presentation/infrastructure track.

**v2 note:** v1 framed this as a port of the old `AnimationHandler`-and-friends. The developer's
direction, plus a full census of the live place, killed that framing. **This is a NEW system.** The
old code contributes three things only: asset-id *values* (evidence, re-verified per consumer), an
anti-pattern catalog (below, so we never rebuild them by accident), and exactly one module worth
learning from (`AnimationUtilities`). Nothing else survives.

## Purpose

One system that answers, for every current and future domain (movement, combat, skills, emotes,
NPCs, interactions):

1. **Where do animation ids live?** In ONE registry — enforced, not hoped for.
2. **How does an animation get played?** Through one track-owning player — never a hand-rolled
   `Instance.new("Animation")` + `LoadAnimation` again.
3. **Who animates the character's locomotion?** Our own script, replacing the forked Roblox
   `Animate` outright.
4. **What may stop what?** Declared per-entry policy, not name sniffing.

## Grounding — full census of `VentureTestingPlace` (read-only, 2026-07-20)

A DataModel-wide sweep (every `LuaSourceContainer` + every `Animation` instance), not just the
known modules:

- **81 scripts** load or reference animations (`LoadAnimation` / `Instance.new("Animation")` /
  `AnimationId`), spread across every container. The "animation system" (`AnimationHandler`,
  `AnimationService`, `AnimationController`) accounts for 3 of them.
- **445 `Animation` instances sit in the tree as data**, and ids live in **at least six distinct
  sources**: (1) `AnimationHandler`'s ~14 tables — which also *mutate themselves at require time*,
  merging three tables into `bothAnimations`; (2) the running `Animate` fork's internal `animNames`
  table; (3) **57 `Animation` config-children** under that same fork (per-pose overrides); (4)
  Animation instances under weapon modules — `RS.Modules.Weapon` (136) **duplicated** in
  `SSS.Modules.WeaponHandler` (94); (5) mob models — five coexisting copies of Starved Amalgam,
  each with its own embedded `Animate` script (54 instances); (6) hardcoded ids scattered through
  the other ~75 scripts (`HeightHandler`, dialogue, camera, chests, doors…).
- **Two diverged forks of the Roblox `Animate` script coexist**:
  `StarterCharacterScripts.Animate` (1601 ln — the one that runs, **and it carries a
  `PackageLink`**, so the fork is itself a shared Package) and `RS.Modules.Animate` (1368 ln,
  stale — first divergence at line 3). The running fork has accreted movement poses (`combatrun`,
  `sprintturn*`, sneak/tool-walk-by-held-key), footstep/equipment sound markers, dodge input
  handling, camera FOV coupling, and `Player.PlayerStats.*` Instance-value reads. Developer's own
  verdict: "it is now my script and if Roblox updates it that's a wrap."
- **Per-play `LoadAnimation` is the norm, not the exception** (developer-confirmed: every slide
  re-loads). `Movement.ClimbHandler.AnimationController` alone makes 15 `LoadAnimation` calls;
  `EmoteAnimationHandler` destroys its `Animation` instance immediately after `Play()`; the Animate
  fork's own `trackTable` cache `Destroy()`s tracks on every pose switch, defeating itself.
- **Preloading is a workspace hack**: warm-up by loading tracks onto `Workspace.Statue`'s Animator
  plus cloning a lootbox crate and camera rig into workspace, then `PreloadAsync`.
- **Interruption is substring matching on track names** (`AnimationInterrupter`: `"lighthit"` →
  attack, `"dodge"` → protected; the priority fallback is commented out). The Knit
  `AnimationService`/`AnimationController` pair exists solely to route "stop attack animations."
- **Naming is colliding**: three unrelated modules are called `AnimationController` (the Knit
  controller, `ClimbHandler`'s, `MountManager`'s), and `AnimateUtilities` is a tween/Bezier helper
  with nothing to do with animation tracks.
- **The one good module:** `RS.Modules.Utilities.AnimationUtilities` (from the developer's own
  Traversal rewrite era) — typed `loadSet(character, idMap) → { [name]: AnimationTrack }` with
  cached `Animation` children and a `play(tracks, name, opts)` API. It is a proto-version of
  Decision 2 and the only piece whose *shape* this design keeps.

### Anti-pattern catalog (what the census forbids us from rebuilding)

| Old pattern | Rule here |
|---|---|
| Ids in 6+ places, incl. `Animation` instances as data | One registry folder; **CI-enforced** (Decision 1) |
| Per-play `LoadAnimation`, destroy-on-stop | One track owner with a cache (Decision 2) |
| Forking Roblox's `Animate` and drifting for years | Own locomotion script, engine script suppressed (Decision 3) |
| Interruption by name substring | Declared class per entry (Decision 4) |
| Statue/workspace-clone preload | Cache + spawn-time set + lazy load (Decision 6) |
| Require-time table mutation / merged views | Pure data modules, lookup by id |
| Three modules named `AnimationController` | One name per concept, service-suffix convention |

## Decision 1 — one registry, split by domain, enforced by CI

`Shared/Modules/Constants/Animations/` — a folder of per-domain data modules (`Locomotion.luau`,
later `Combat.luau`, `Skills.luau`, `Emotes.luau`, `Npc.luau`, …) plus an `AnimationRegistry.luau`
index that composes them into one typed, frozen lookup. Entry shape:

```luau
export type AnimationDef = {
	assetId: string,        -- canonical "rbxassetid://N" only (spec-asserted)
	priority: Enum.AnimationPriority,
	looped: boolean,
	interruption: InterruptionClass, -- Decision 4
	variants: { string }?,  -- roll-a-random-variant sets (old `reactories` shape)
}
```

- **Split-by-domain from day one** (v1 said one module; reversed). Every future phase adds a file,
  not 200 lines to a shared one — which also keeps the file-length CI gate honest instead of
  fighting it.
- **Composition is pure**: the index requires the domain modules and builds `byId` / `byDomain`
  views without mutating them (no `bothAnimations` re-run).
- **CI enforcement, not convention:** a project-rules check (the PR #3–4 gate infrastructure) that
  fails the build if an animation asset id (`rbxassetid://` in an `AnimationId`-ish context)
  appears in first-party source outside `Constants/Animations/`. The old game didn't scatter ids
  because anyone chose to; it scattered because nothing stopped it. **No `Animation` instances as
  data anywhere** — instances are created transiently by the player (Decision 2) from registry ids.
- **Populated per consuming phase.** Phase 6 seeds `Locomotion` (Decision 3 needs it) and a small
  general set for specs/admin commands. Combat/skill/emote/NPC ids enter with their phases,
  re-verified against their consumer — of the old sources, only the id *values* are evidence, and
  several are provably dead or duplicated.

**Rejected — port the full old tables now:** freezes dead ids, two URL formats, and six-source
duplication into the new base with no consumer to validate against.
**Rejected — single registry module (v1):** guarantees a future dumping ground and a file-length
fight; splitting later is a rename, so do it while it's free.

## Decision 2 — `AnimationPlayer` owns every track

The only code in the codebase that calls `Animator:LoadAnimation`. Generalizes the one good old
module (`AnimationUtilities.loadSet`) with ownership and cleanup it lacked:

- **Cache per (animator, animationId)** — first play loads, later plays reuse. A slide costs one
  load per character lifetime, not one per slide.
- **Typed play options** (fade, speed, weight, priority override) returning a **handle**
  (stop/adjust/marker subscription). Consumers never hold raw tracks or `Animation` instances.
- **Bookkeeping**: the player records what it is playing per animator + registry entry — this is
  what makes Decision 4 work without `GetPlayingAnimationTracks()` + name parsing.
- **Owned cleanup** on character/animator removal: cache dropped, connections disconnected. Never
  `Destroy()` a track to "save memory" mid-lifetime (the fork's self-defeating cache).

**Rejected — per-play load (old norm):** marker-connection churn, warm-up loss, and the entire
reason the Statue preload hack existed.

## Decision 3 — replace `Animate`, don't leverage it

The developer's direct question: what's the best way to override default Roblox animations while
still leveraging their `Animate` script? Answer after weighing every override surface: **don't
leverage it — replace it.**

Ship our own `StarterCharacterScripts` LocalScript named `Animate` (its presence is the supported
way to suppress the engine's auto-inserted default) as a **thin shell** over a shared, speccable
`LocomotionAnimator` module: Humanoid state events (`Running`, `Jumping`, `FreeFalling`,
`Climbing`, `Swimming`, `Seated`, `Died`) → registry-declared locomotion set (idle / walk / run /
jump / fall / climb / swim / sit + speed scaling), all playback through `AnimationPlayer`.

- **Rejected — stock `Animate` + `HumanoidDescription` animation overrides.** Covers only the
  stock slots (idle/walk/run/jump/fall/climb/swim/mood); Venture's poses (sneak, sprint-turn,
  combat-run, tool-walk…) don't fit, the rig is custom, and the coming controller-based rig redo
  makes the stock script's assumptions the *least* stable dependency available.
- **Rejected — stock `Animate` + `Animation` config-children.** This is the mechanism the old fork
  half-uses (the 57 children). It keeps ids as tree data (violates Decision 1), keeps the stock
  script's weighted-set/chat-emote/tool machinery running for nothing, and any genuinely new pose
  still forces a fork — which is exactly how the current script came to exist.
- **Rejected — maintained fork.** The status quo, named by the developer as the failure: two
  diverged copies, a PackageLink on a script Roblox designed to be replaceable wholesale, and
  years of accreted non-animation responsibilities (dodge input, FOV, footstep sounds).

**What deliberately does NOT come along:** weighted random animation sets (unused in practice —
every non-stock set is a single entry), chat `/e` emote hooks (Emotes phase, via its own surface),
tool animations (combat phase), footstep/equipment sound markers (Sound phase — the *marker
mechanism* is exposed on play handles, the sound system is not built here), dodge/input handling
(Movement phase — input does not belong in an animation script), and camera coupling (Camera
phase). The Movement/Traversal phase later adds parkour poses through `LocomotionAnimator`'s pose
API instead of editing the script — that is the test the old fork failed.

## Decision 4 — interruption is declared, not inferred

Each registry entry carries an `interruption` class replacing `AnimationInterrupter`'s substring
matching: `"attack"` (bulk-stoppable by the stop-attacks verb), `"protected"` (never bulk-stopped:
reactions, dodges, blocks, death, emotes), `"ambient"` (locomotion-level; bulk stops ignore it).
Stop verbs walk `AnimationPlayer`'s own bookkeeping and match on the *declared* class. The old
classification (attack vs protected) was the right idea executed as name-luck — `"blocking"`
matched `"block"` by accident and a rename silently flips combat semantics; here a rename can't
touch behavior.

## Decision 5 — ownership: the network owner plays

- **Own character** → that client plays it (replicates automatically). Server-*initiated* character
  animations (hit reactions, forced stops) are **requests to the owning client** via a typed
  ByteNet packet (`AnimationEvents`) — a discrete event, ByteNet's sanctioned role. The old game's
  split (server `LoadAnimation` directly on player characters for reactions, client for the rest)
  followed no principle; this one line replaces it.
- **NPCs / world models** → `AnimationServiceServer` plays server-side (consumers arrive with the
  NPC phase).
- **No animation state on the charm-sync spine.** Animations are presentation; the authoritative
  facts (equipped weapon, casting, stunned) live in their own domains already.

Both services are thin shells over the shared registry + player (pure logic speccable; Instance
shell spec-exempt with reason, the Customization split).

## Decision 6 — caching makes preloading almost unnecessary

With tracks cached (Decision 2), "preload" reduces to: load the locomotion set at character spawn
(it's about to play anyway), everything else on first use. A per-entry `preloadAtBoot: true` flag
exists for the rare genuinely-latency-sensitive set (a cutscene's first frame), batched through
`ContentProvider:PreloadAsync` on transient `Animation` instances — no Statue, no workspace
clones, no Humanoid needed. Dead or failing ids are **reported** through the Logger
(conformance-checker style, naming the registry key) and never stop a boot.

## What survives from the old game

- **`AnimationUtilities`'s shape** → generalized into `AnimationPlayer` (Decision 2).
- **The attack/protected classification idea** → as declared classes (Decision 4).
- **The marker-driven sound idea** → the marker *hook* on play handles; the sound system itself is
  the Sound phase's.
- **Asset-id values** → evidence only, admitted per consuming phase after re-verification.

Everything else — the six id sources, the forks, the per-play loads, the Statue, the name
matching — is in the anti-pattern catalog to stay dead.

## Deliberately NOT in this phase

- **Emote system** (wheel, ownership, gating) — own roadmap row; becomes a thin consumer.
- **Combat / skill / NPC playback and their registry entries** — arrive with their phases.
- **Parkour/traversal poses** — Movement phase, via the `LocomotionAnimator` pose API.
- **Footstep/equipment sound system** — Sound phase, consuming the marker hook.
- **Mob-model embedded `Animate` scripts** — replaced when the NPC phase decides how NPC rigs
  animate (ideally reusing `LocomotionAnimator` for humanoid NPCs).
