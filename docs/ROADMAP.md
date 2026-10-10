# Roadmap — the shared game-systems base

> Living document. Update the status column as systems land.

This repo is the **shared base** every game starts from: the rodeo-stampede / steal-an-egg / ride-a-pet
game, the cleaning-sim × co-op horror game, the night-shift horror game, and whatever comes next. A system
belongs here only if **at least two of those games need it unchanged**; anything game-specific lives in
that game's own repo or branch, built on top.

Each system follows the same cycle: design spec (`docs/superpowers/specs/`) → plan → spec-first
implementation → review → PR.

## Governing principles

- **Generic or it doesn't go in.** A base system takes the game's data as registrations/config (items,
  currencies, scenes, HUD widgets, animations), never hard-codes one game's content.
- **Native engine characters.** Characters are the engine's own; the base never fights Tools, Seats,
  physics ownership or engine animation replication. Gameplay authority stays on the server.
- **Slots dormant.** `MAX_SLOTS = 1`: one save per player. The multi-slot data layer stays intact (and its
  specs re-enable) for a game that wants multiple save files.

## In the base today

Re-seeded from `venture-game-systems` (main at `bb33e81`), which itself began as a copy of this repo.

| System | What it is |
|---|---|
| Core | ServiceController (lifecycle, dependency sort), Guard, Logger, SignalTyped, RequestHandler (token-bucket rate limiting, validation, `xpcall` isolation), SpecRoots, ProfileStoreTyped |
| PlayerData | ProfileStore profiles; `mutate` / multi-profile `transaction` with rollback; per-slice data-layer validators; account vs slot scope; dormant slots + epochs; schema migrations |
| StateSync | Charm atoms mirrored to the owning client via charm-sync; the public-player slice (every player sees every player by default); the world slice (named match / server entries every client syncs) |
| Currency | Capped soft currencies (placeholder `coins`), shared validator, transaction ops |
| Item + Inventory | Item registry (declared stackability), stacks + unique items with atomically minted uids, per-instance `attrs`, per-kind caps, reusable container rules for a second container |
| Title | Earned (account) + equipped (slot) titles, registry composed per domain |
| Animation | One id registry (CI-enforced), one track owner per Animator, locomotion core replacing `Animate`, interruption classes, server-granted actions to the owning client, `playOnRig` for NPCs |
| Input | Named actions with keyboard/mouse + gamepad bindings, a context stack (a menu silences gameplay actions), session rebinding overrides, and the UI `movement` suppression handler |
| Camera | A prioritized mode stack (engine default with first-person / spectate, fixed shots, smoothed follow, custom) plus trauma shake, FOV kicks and custom modifiers; the UI `cameraState` handler |
| Sound | A validated sound registry, volume groups, 2D / positional playback with pitch variance and per-id caps, crossfading music and ambience layers, and server-requested sounds by radius |
| VFX | Effect recipes over artist templates (with sound and distance-scaled shake), combined screen effects (blur, colour, depth of field) eased per frame, and atmosphere presets blended over Lighting, synced from the server |
| Interaction | Tag + kind on world objects → engine ProximityPrompts; every trigger re-checked on the server (distance, enabled, cooldown) before the kind's handler; prompts follow the `interact` binding; channels give a continuous hold with server-side progress (`registerChannel`, `channel`, `resetChannel`) |
| Carry | Pick up / drop / throw tagged world objects: one per player, welded to the character, weight slows you, published to everyone, dropped on death or leave; `pickedUp` / `dropped(reason)` signals tell a game what happened |
| Round | Lobby → countdown → run → results as a pure, configurable phase machine (inert until a game opts in); run-only participants, eliminations, team counters and targets, scores and run containers on the inventory rules; synced to every client through the StateSync world slice |
| Marketplace | Exactly-once developer-product grants (purchase id recorded in the same persisted transaction as the grant), cached gamepass ownership published as a public field, and an account-scoped premium currency |
| Entitlements | Account-wide "you own this" by category and id (suits, skins, unlocks): registered catalogue, structure-validated slice replicated to the owner, `grantOp` so a purchase and its unlock are one atomic write |
| Settings | A shared settings registry (number / boolean / choice / keybinds), an account slice storing only non-default values, one validated client request with local preview, and the base settings applied to Sound volumes, camera shake and Input rebinds |
| NPC / AI | Registered NPC kinds (passive / hostile / timid) spawned from artist templates or adopted by tag; a pure brain (attack, chase, flee, patrol, wander, idle) over sight-cone perception with memory; PathfindingService movement; damage through Death; poses via `playOnRig`; a game can replace a kind's brain (`setBrain`), send an NPC to a point (`goTo`), tune one NPC (`setTuning`) and avoid zones (`pathCosts`) |
| Death | Damage credit and kill info, ragdolls on native Humanoids (players and NPCs), an `auto` / `manual` respawn policy, the public `dead` field, client-side spectating of living players, a game-chosen spawn point (`setSpawnPoint`) and a launch on `kill` |
| Voice | Audio API proximity voice on native characters: server-made microphone inputs with server-enforced access lists, routing over the public `dead` / `radio` fields (spatial, radio, the dead channel), client wiring of emitters and radio / direct chains |
| Small services | Leaderstats (registered player-list columns), Badges (award by key, cached, retried), Analytics (a safe AnalyticsService wrapper), Daily rewards (an account streak claimed in one transaction with its reward), weighted Loot tables (pure, seedable rolls and drop chances) |
| UI framework | React layers (respawn-safe), scene stack with Escape / gamepad-B pop and per-scene toggle keys, world-suppression contract, HUD widget registry, primitives + tokens, UI Labs stories |
| Toast | Server-sent toasts (`ToastServiceServer:send`) to one player or all, with registered styles (`info` ships), text cut at 140 characters, 1 to 15 seconds, and a HUD stack showing 4 at a time |
| Debugger | F4 overlay: logs, services, live state tree, animations, UI stack |
| Admin | Cmdr with a fail-closed allowlist; currency, inventory, title, animation, round, premium, entitlement, NPC and daily-reward commands |
| Tooling | `--!strict`, selene, stylua, luau-lsp typecheck, layout rules + module map, file-length cap, cast/trailer/asset-id/UI CI gates, TestEZ on Open Cloud |

## Left in venture-game-systems (on purpose)

| System | Why it is not in the base |
|---|---|
| Custom character replication (client-only bodies, puppets, codecs), Collision, its Voice wiring | Built for a 60-player PvP parkour MMO. It gives up Tools, Seats, server `Touched` / ProximityPrompt events and engine-owned physics props, which all three games need. Port as an optional module only for a game that measures a need. |
| Customization | Tied to Venture's custom rig, soul colour and head types. Its account-scoped entitlement model is the seed of the base's Entitlements system (below). |
| Bank, Equipment, Stat (XP/level/investments), Slot switching, item affixes | RPG systems. Their reusable patterns (a second container, a one-transaction container move, level derived from total XP, a weighted roll at mint) are noted where the base systems below would reuse them. |

## Next — shared systems (in order)

Ordered so each builds on the ones before it. Every one is a NEW, generic design.

| # | System | Scope | Games |
|---|---|---|---|
| 1 | **Input** ✅ built (`docs/superpowers/specs/2026-10-09-input-design.md`) | Named actions ("Interact", "Sprint", "Flashlight") with keyboard / gamepad / touch bindings, rebindable via Settings; a context stack (gameplay, menu, riding, spectating, cutscene) wired to the UI scene stack's `movement` suppression seam. Evaluate Roblox's Input Action System as the backend. | all |
| 2 | **Camera** ✅ built (`docs/superpowers/specs/2026-10-09-camera-design.md`) | A mode stack (third-person, locked first-person, ride/follow, spectate, cutscene/rail, CCTV/monitor view, fixed jumpscare) plus additive modifiers (trauma-based shake from many sources, FOV kicks, head bob, sway, lean). Fills the UI suppression `cameraState` seam. | all |
| 3 | **Sound** ✅ built (`docs/superpowers/specs/2026-10-09-sound-design.md`) | Sound registry (ids, groups Music/SFX/UI/Ambient, pitch variance, concurrency caps); pooled 2D + positional playback; music/ambience with crossfades; a typed server packet only for sounds a client cannot derive. Decide Sound instances vs the Audio API (filters, reverb, occlusion — strong for horror). | all |
| 4 | **VFX** ✅ built (`docs/superpowers/specs/2026-10-09-vfx-design.md`) | Split, not one blob: (a) effect *recipes* — named combinations of particles, beams, trails, highlights, light flicker, a sound and a camera-shake request, pooled, triggered by one typed packet to nearby players; (b) *screen effects* — blur, colour correction, vignette, depth of field as a refcounted stack (fills the UI `blur` seam); (c) *lighting / atmosphere presets* with blends (night, power outage), synced via StateSync when shared. UI motion stays in the UI framework. | all |
| 5 | **Interaction** ✅ built (`docs/superpowers/specs/2026-10-09-interaction-design.md`) | Server-validated ProximityPrompt / click interactions: distance + rate checks through RequestHandler, per-object handlers, hold-to-interact. | all |
| 6 | **Carry** ✅ built (`docs/superpowers/specs/2026-10-09-carry-design.md`; held *items* stay engine Tools) | Carry an object or hold an item (egg, flashlight, scrap) with weight, drop/throw, server-owned props with client-predicted grab, network-ownership rules. | all |
| 7 | **Round / match lifecycle** ✅ built (`docs/superpowers/specs/2026-10-09-round-design.md`) | Lobby → run → results with non-persistent run state (run-scoped containers reusing the inventory container rules; a team quota / shared wallet). | 2, 3 (1 for events) |
| 8 | **Marketplace** ✅ built (`docs/superpowers/specs/2026-10-09-marketplace-design.md`) | `ProcessReceipt` that grants each purchase exactly once inside a profile transaction; gamepass ownership cache; a premium currency as its own ACCOUNT slice. | 1, 2 |
| 9 | **Entitlements** ✅ built (`docs/superpowers/specs/2026-10-09-entitlement-design.md`) | Account-scoped "you own this" (`{ [category]: { [id]: true } }`): cosmetics, suits, pet skins, night unlocks; fed by Marketplace and gameplay. | all |
| 10 | **Settings** ✅ built (`docs/superpowers/specs/2026-10-09-settings-design.md`) | Account slice, client-writable through a validated request: volumes, sensitivity, keybinds, accessibility. | all |
| 11 | **NPC / AI** ✅ built (`docs/superpowers/specs/2026-10-09-npc-design.md`) | Server-owned NPCs with a simple behaviour layer (wander, chase, flee, patrol) and pathfinding; animated via `playOnRig`. | all |
| 12 | **Death, ragdoll, spectate** ✅ built (`docs/superpowers/specs/2026-10-09-death-design.md`) | Ragdoll on native Humanoids, death flow, spectate camera mode; hooks `AnimationServiceServer:stopAll`. | 2, 3 |
| 13 | **Voice** ✅ built (`docs/superpowers/specs/2026-10-09-voice-design.md`) | Audio-API proximity voice anchored to `Character.Head`, with routing (radio, dead-player channel). | 2 |
| 14 | Leaderstats, badges, analytics, daily rewards, weighted loot tables ✅ built (`docs/superpowers/specs/2026-10-09-small-services-design.md`) | Small shared services. | as needed |

## Queue — planned before Cleanup Crew M4

Party pads and reserved servers: a group gathers on a pad and is teleported together into a reserved server. It follows the base game hooks in its own PR.

## Game demos

Each game is its own repo or branch on top of this base and owns its systems (mounts and lassos, the
egg/base steal loop, cleaning tools and monsters, the night clock and anomalies).

## Games on this base

| Game | Branch | Built so far |
|---|---|---|
| Cleanup Crew (cleaning sim × co-op horror) | `game/cleanup-crew` | M1 graybox loop: code-built office with seeded spawns and guarantees (Office), vacuum and canister (Vacuum), 13 cargo kinds with handling traits, pockets, search and banking (Cargo), Round-driven shift with quota, clock out, results and vote (Shift). Spec: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md`. |

Game features live only on their game branch; nothing in this table belongs in the base unless a second
game needs it unchanged (see the rule at the top).
