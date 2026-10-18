# Death, ragdoll, spectate — design

Status: built with this spec. Roadmap item #12 (docs/ROADMAP.md).

## Goal

One death flow for players and NPCs: who killed whom, a ragdoll instead of the engine's joint break, a
respawn policy the game chooses, and spectating living players while dead.

## Decisions

1. **Credit is tagged at damage time.** `DeathServiceServer:damage(humanoid, amount, source)` records the
   source (`{ userId?, name }`) and applies the damage; the last source within `creditWindow` seconds is
   the killer. `kill(player, cause)` sets an explicit cause. `died(player, info)` fires for players and
   `humanoidDied(model, info)` for every tracked rig (players and NPCs), with `info = { killerUserId?,
   killerName?, cause? }`.
2. **Ragdoll on native Humanoids.** Characters get `BreakJointsOnDeath = false`; on death every Motor6D
   is disabled and replaced by a BallSocketConstraint between attachments at the joint's C0/C1, with
   per-joint limits (`DeathRagdollUtils.limitsFor`: a stiff neck, wide shoulders, knee-like hips), limbs
   collide and the root goes non-colliding and massless. `ragdoll(model)` is public, and NPCs call
   `track(model)` so their deaths use the same flow. On a player's death, `AnimationServiceServer:stopAll`
   ends every granted action.
3. **Respawn is a policy.** `configure({ respawn = "auto" | "manual", respawnDelay, ragdoll })`. `auto`
   (default) is the engine's own respawn after `respawnDelay` (`Players.RespawnTime`). `manual` turns
   `CharacterAutoLoads` off: joining players are still loaded, but after a death only the game's
   `respawn(player)` brings them back — horror runs where the dead stay dead until the round ends.
4. **Everyone knows who is dead**: the public field `dead = true` from death until the next spawn.
5. **Spectate is client-side** (`DeathServiceClient`): while the local player is dead, the camera
   follows a living player (`CameraServiceClient` `default` mode with `subject`); `spectateNext` /
   `spectatePrev` (Right / Left arrows, d-pad right / left) cycle; the target is replaced when it dies or
   leaves; respawning ends it. `DeathSpectateRules` picks and cycles candidates (pure). A game turns it
   off with `setSpectateEnabled(false)` or narrows candidates with `setSpectateFilter(fn)`.

Not now: death screens (UI, game-specific), revives (a game calls `respawn` or its own logic), kill feeds.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Death | shared | Data | DeathTypes | Types only: DeathConfig, DeathInfo, DamageSource, JointLimits |
| Death | shared | Data | DeathConstants | Public field, default config, credit window, joint limits, spectate actions |
| Death | shared | Utils | DeathRagdollUtils | Pure: the ragdoll limits for a joint name |
| Death | shared | Rules | DeathSpectateRules | Pure: living candidates, next / previous target |
| Death | server | State | DeathCreditTracker | Last damage source per humanoid, within the credit window |
| Death | server | root | DeathServiceServer | Damage and credit, ragdoll, respawn policy, the public `dead` field, signals |
| Death | client | root | DeathServiceClient | Spectating while dead |

## 2026-10-10 additions

A game now chooses where characters appear. `DeathServiceServer:setSpawnPoint(resolver?)` sets a resolver for the spawn position. If the resolver errors or returns something that is not a CFrame, Death warns and falls back to the default spawn. `kill(humanoid, cause?, { launch: Vector3? })` takes an options table, and `launch` throws the body as it dies.
