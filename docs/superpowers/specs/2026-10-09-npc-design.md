# NPC / AI — design

Status: built with this spec. Roadmap item #11 (docs/ROADMAP.md).

## Goal

Server-owned characters — a stampeding animal, a lurking monster, a patrolling guard — with one small,
data-driven behaviour layer, pathfinding, animation and death, so a game describes a kind and spawns it.

## Decisions

1. **Kinds are registered data.** `NpcRegistry.register(kind, { template?, attitude, walkSpeed,
   runSpeed, sightRange, sightAngle, loseSightTime, wanderRadius, fleeRange, attackRange, attackDamage,
   attackCooldown, animations? })`. `attitude` is `passive` (ignores players), `hostile` (chases and attacks
   what it sees) or `timid` (flees from players in range).
2. **Two ways in.** `spawn(kind, cframe)` clones `ServerStorage.Assets.Npcs.<template>` (artist-owned,
   never synced by Rojo); a model placed in the map tagged `Npc` with an `NpcKind` attribute is adopted.
   Either way the root's network owner is the server, and Death `track`s the model so it ragdolls and
   reports `humanoidDied`.
3. **A pure brain.** Every tick (staggered) the service builds a context (position, the remembered
   target, the nearest threat, patrol state) and `NpcBrainRules.decide` returns one intent: `attack`,
   `chase`, `flee`, `patrol`, `wander` or `idle` — in that priority, by attitude.
4. **Perception** is `NpcSenseRules`: inside `sightRange` and the `sightAngle` cone, then one raycast for
   line of sight (the shell). A seen target is remembered for `loseSightTime`, so a monster keeps hunting
   briefly around a corner. Candidates are players with a living character, passing an optional game
   filter (`setTargetFilter`, e.g. only round participants who are alive).
5. **Movement** uses PathfindingService through `NpcMoverSystem`, re-pathing only when the goal moved
   more than a threshold or the path is old (`NpcPathRules.shouldRepath`), with a direct `MoveTo` fallback
   when no path exists. Patrol points are the BaseParts in the Folder named by the model's `NpcPatrol`
   attribute, visited in name order. Wander and flee goals are pure (`NpcPathRules`).
6. **Attacks** happen in range after the kind's cooldown: by default `DeathServiceServer:damage` with the
   kind as the credited source; `onAttack(kind, fn)` replaces that (a grab, a jumpscare).
7. **Animation** through `AnimationServiceServer:playOnRig` from the kind's optional `animations = { idle,
   walk, run, attack }` registry ids, chosen by speed (`NpcBrainRules.poseFor`); a template may instead
   carry its own Animate script.
8. Dead NPCs are removed after `corpseTime`. `spawned(model, kind)` and `died(model, kind, info)` signals.

A game can point an NPC at a player directly with `setTarget(npc, player)` (a noise, a trap), limit who
NPCs hunt with `setTargetFilter`, and remove them with `despawn` / `clear`.

Not now: group tactics, a hearing model, flying or swimming agents.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Npc | server | Data | NpcTypes | Types only: NpcDef, Attitude, Intent, BrainContext |
| Npc | server | Data | NpcConstants | Tag and attribute names, tick, repath and corpse tuning |
| Npc | server | Data | NpcRegistry | The NPC kinds, validated |
| Npc | server | Rules | NpcSenseRules | Pure: sight cone, nearest candidate, memory |
| Npc | server | Rules | NpcBrainRules | Pure: the intent for this tick, the locomotion pose |
| Npc | server | Rules | NpcPathRules | Pure: wander / flee goals, when to re-path |
| Npc | server | State | NpcRosterTracker | Live NPCs by id, model and kind |
| Npc | server | Systems | NpcBehaviourSystem | One NPC's think: perception, decision, acting, attacks, pose |
| Npc | server | Systems | NpcMoverSystem | PathfindingService path following for one NPC |
| Npc | server | root | NpcServiceServer | Spawn / adopt, the tick, perception, attacks, animation |

Plus admin commands `npcspawn <kind>` and `npcclear`.

## 2026-10-10 additions

A game can now replace what a kind decides. `NpcServiceServer:setBrain(kind, brain?)` swaps in a `Brain` for a registered kind (nil removes it; a brain that returns nil for a tick uses the default). A brain can return the new `goTo` intent, `{ kind = "goTo", position, run }`, to send an NPC to a point. `setTuning(npc, tuning?)` overrides an `NpcTuning` for one NPC at runtime and returns whether the NPC was found. A kind def may set `pathCosts` so pathfinding avoids marked zones.
