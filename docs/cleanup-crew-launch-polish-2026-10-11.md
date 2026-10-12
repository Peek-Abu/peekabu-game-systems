# Cleanup Crew launch polish â€” 2026-10-11

This is the continuation of the user's original review. It distinguishes implemented repairs, proposed launch scope, and unfinished production art. The original handoff describes historical context; it does not authorize publishing, uploads or paid services.

## Implemented repairs

- Idle root cause fixed earlier: inherited idle clip, not Workspace retargeting. The game has a custom locomotion replacement for Animate; stock tool poses therefore do not automatically solve held-vacuum contact.
- Approved compact shift HUD and server-owned vacuum Tool were implemented in the preceding pass. Cargo controls are contextual; crew is collapsed. Button press/hover/focus feedback and measured prompt-key width are included; existing menu PaperButtons now also show immediate hover/press/focus ink treatment without motion.
- The current pass ranks eligible prompts by character reach, visibility, aim and distance; stable one-stud score hysteresis prevents flicker. Cargo pickup hints reach 6 studs, other prompts at most 8 (or their original smaller reach). Only the selected prompt retains a native activation range; holds release on switching. One selected cargo price label replaces independent camera-distance labels across the room. Server reach/enabled/carry checks remain unchanged.
- Contract, result and personal-review boards use SurfaceGui on the physical front-facing board surface. Typed GUI-root bookkeeping supports both surface and billboard lifetimes. Truck tags, selected item hints and Harlow cues remain camera-facing.
- Depot has a physical roof and lights; every office room has a ceiling. Camera service bounds native orbit to 0.5â€“16 studs and uses Zoom occlusion; it restores prior values on stop. Workspace remains artist-owned and unmounted.
- Office geometry now regenerates from a server seed before each shift: the seven-room core plus service corridor, meeting, accounts, training and supply rooms. Wing width, partitions and doors vary. Additional doors form loops; markers expand the spawn choices and Harlow's patrol. This is modular generation around a stable core, not arbitrary building generation. Core spawn/bay/rest positions stay stable.

## Which UI container fits

Wall screens, leaderboards, work orders and pinned reviews should be SurfaceGui: face, canvas/aspect, lighting and occlusion are explicit. A name/rank tag, selected-item hint, alert cue or reward floater can legitimately face the camera. Neither GUI's MaxDistance establishes interaction reach; that comes from native prompts plus server validation. See [Roblox world UI](https://create.roblox.com/docs/ui/in-experience-containers), [SurfaceGui](https://create.roblox.com/docs/reference/engine/classes/SurfaceGui), [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt) and [camera behavior](https://create.roblox.com/docs/workspace/camera). These rules are recorded in .agents/skills/cleanup-crew-ui/SKILL.md.

## Animations to commission or author

| Priority | Motion | Contact/behavior requirement |
|---|---|---|
| First | Vacuum held idle / suction loop | Upper-body pose keeps grip/nozzle aligned while legs use native locomotion; no full-body idle overwrite. |
| First | Vacuum equip / stow | Short, interruptible; Tool exists and server equip state determines gameplay. |
| First | Light carry / heavy carry / bulky push | Three readable weight silhouettes; hand attachments match cargo geometry. |
| First | Pickup / load / drop / throw | Contact/release timing matches server action; visual markers never grant items or money. |
| First | Harlow patrol / chase | Office-worker gait plus readable chase silhouette. Existing custom slots are still PENDING. |
| First | Harlow look / grab / throw | Head/clipboard search and catch action match existing state changes. |
| Next | Rummage / pocket / unpocket | Short actions that cancel on death, catch or target loss. |
| Next | Clipboard tapping / writing / break idle | Match his existing office-habit sounds. |
| Later | Clock punch / shift reactions / crew emotes | Polish after the loop and core contacts work. |

Use the existing animation registry and single track owner (docs/animation.md). Stage source clips with rig, joints keyed, priority/layer, loop boundaries, duration and markers. Validate block R15 plus supported proportions; avoid reintroducing the inherited-idle arm problem. Author directly with the free [Studio Animation Editor](https://create.roblox.com/docs/animation/editor), or Blender for refined contacts. No new animation was uploaded or represented as finished in this pass.

## First-launch hub proposal

Keep trucks/dispatch the primary action. Give the hub four small shortcuts: Work order, Handbook, Gear locker, Settings. Add a compact company ID with next milestone, and keep the performance board as the last-shift review destination. These shortcuts open the same physical destinations; they do not replace the world with permanent panels.

The screenshot-backed Figma proposal is [Launch hub, node 81:2792](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=81-2792). It uses the actual 1192x588 enclosed Roblox hub and labels progression/shortcuts as proposed. The user explicitly approved adding this screenshot and mockup to the alternative Figma bridge. That approval is not approval of the new design or progression economy. No new hub menu has been implemented yet.

| Destination | First-launch content |
|---|---|
| Work order / dispatch | Current objective, crew/queue state, departure flow. |
| Handbook | Five visual steps: equip, vacuum, pick up, load, clock out; controller/touch examples. |
| Gear locker | Vacuum appearance and optional company outfit; show selected loadout. |
| Company ID | Server-owned level/rank, next cosmetic milestone, completed shifts. |
| Settings | Sound/music levels, input help/rebinds, reduced motion, readability. |
| Performance board | Last run's clearance, salvage and team awards. |

Persistence/XP/ranks are new gameplay scope: define save schema, award rules, reconnect behavior and cosmetic ownership before showing real progression numbers. Do not invent a rank from client values. Avoid daily chores or paid advantages until the co-op loop is fun.

## Uniform, nametag and ranktag

Recommend an optional company vest/apron, badge and gloves that preserve the player's head, hair, body and identity. Full coveralls can be an opt-in cosmetic. The same vest silhouette with patches and restrained color variants conveys progression. Use a short nearby overhead DisplayName and a smaller server-derived rank line; hide at long range and behind walls, avoid multiple independent tags. Uniform identity may help attachment; improved retention is a hypothesis, not an established result.

Roblox explicitly supports partial avatar changes. Edit an up-to-date Humanoid:GetAppliedDescription(), preserve unrelated fields, handle respawn, and restore when leaving the shift. Test supported bodies/layered clothing before promising universal fit. [Character appearance](https://create.roblox.com/docs/characters/appearance). The vest mesh/texture and progression data are not ready, so this pass does not force a placeholder outfit on users.

## Cohesive commercial assets without an AI look

Choose one art direction: chunky office realism, simple rounded silhouettes, restrained cream/gray/teal company colors, dark graphite hardware, small yellow safety accents. Props share bevel width, surface treatment, texture density and scale. Dirt is a separate selective layer. Dress one representative room and one truck first, then propagate the kit.

The free starting candidate is [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit): its own page lists 140 files and CC0. Treat this as a sample-kit candidate, not a promise that all needed office/truck assets exist. Preserve its supplied license and provenance in an asset manifest. A matching set is more effective than mixing unrelated marketplace packs.

| Asset family | Suggested source/work | Acceptance check |
|---|---|---|
| Walls, doors, ceiling, lights | Authored modular kit; common stud grid and connector sizes. | Door widths and seams work for Harlow and bulky carry. |
| Desk/chair/locker/shelves | Evaluate one licensed pack and edit consistently in Blender. | One-room style approval before mass import. |
| Truck | Original hero mesh with shared company palette and readable queue bed. | Native camera/boarding/load zones remain usable. |
| Vacuum | Original hero mesh, grip/nozzle contact built for the chosen animation rig. | Prototype Tool dimensions/attachments tested before art swap. |
| Cargo/recycling/bags | Matching silhouettes/material library; value differences readable. | Collisions, carry/pocket sizes and fragile indicators preserved. |
| Uniform/badge/rank patches | Original authored clothing, optional variants. | Avatar fit and appearance restoration. |
| Harlow/clipboard | Original readable office-worker silhouette, strong face/pose language. | Patrol/chase/catch readable in dim lighting. |

A later artist commission is the cleanest premium route if a budget is approved; this pass uses no paid service. Raw generated meshes are not a substitute for authored hero assets with clean topology, deliberate silhouettes, UVs and contact surfaces. The present code-built furniture, trucks and vacuum remain graybox/prototype art.

## Tools/access that would help

- Existing Studio MCP: enough for geometry, instance properties, scripts, screenshots and runtime path tests. More Studio bridges are not required for this functional pass. [Official bridge capabilities](https://create.roblox.com/docs/studio/mcp).
- [MCP for Blender](https://github.com/ahujasid/mcp-for-blender): optional community modeling bridge for repeatable mesh/material/scene edits. It is not affiliated with Blender Foundation. Useful if Blender is available and the user enables its add-on; it does not supply art direction or a room-generation algorithm. Current project documents a Codex configuration and manual add-on setup. Do not blindly run a remote installer.
- Studio Animation Editor: sufficient for the first R15 contact poses; refined animation can be authored in Blender and imported.
- UI Labs + alternative Figma Desktop Bridge: preserve the existing workflow; all future HUD mockups should contain an actual game screenshot with viewport/state labels.
- Optional builder/artist access: a cohesive modular asset kit and an animator are more valuable now than another general coding MCP.

No new MCP/add-on was installed and no asset was imported/uploaded by this research pass.

## Verification and remaining production work

The first expanded-layout suite passed 2,141 tests, zero failed; 30 seeds covered connectivity, route/capacity and spawn guarantees. Live Studio pathfinding reached all four new wing rooms from the archive for two generated seeds. Depot/office ceilings, physical boards and one native prompt were inspected. The camera-service adjustment was verified in a fresh session at 16 studs. Final suite: **2,144 passed, zero failed**, including three menu-button feedback specs. All static gates passed. Live tests confirmed one native E target, no prompts at 12 studs or through a wall, menu-button press/click behavior and personal/shared review root replacement. Details are in the implementation plan.

Still required for launch: final mesh/animation authoring, avatar/device fit, real touch/controller gestures, multi-player review isolation and co-op runs, larger seed/path stress testing, timing/balance after the expanded wing, and approved hub/progression implementation. These are separate from the functional repairs delivered here.


## Icon-led correction

The user's 2026-10-11 follow-up rejected the word-led hub treatment. Frame 81:2792 now uses large teal ink icons and short Jobs/Guide/Gear/Settings labels; the previous proposal is retained at 82:2810. Original vector components are on sheet 82:2856, with 14 matching local SVG sources in design/cleanup-crew/icons/. This family should extend to HUD counters and contextual actions while preserving necessary values/labels. Runtime Image IDs/PaperIcon integration and Roblox uploads are not yet done. The exact original-request checklist is docs/cleanup-crew-original-request-status.md.
