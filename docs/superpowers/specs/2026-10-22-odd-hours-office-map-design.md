# Odd Hours: the office map (outside + procedural interior) design

Date: 2026-10-22. Status: draft for owner approval. Builds on the mock-room art test of 2026-10-21/22
(Shift place, `Workspace.ClaudeMockRoom`) and the `texture-pipeline` skill.

## Intent

The current shift map plays fine but **reads as a generator, not an office**: rooms feel the same, there
are no real doors, the hallways have no variety, and a player can tell the building is procedural. The
owner wants a map that feels like a real, slightly uncanny corporate office at night, built for the
co-op horror loop (clean, loot, hide from Mr. Harlow, bank at the truck). It must still change every
run.

The model is **Lethal Company**:
- A hand-built exterior that is the same every visit.
- An interior assembled per run from **hand-built rooms**. Randomness picks which rooms appear and how
  they connect; it never builds a room's contents from scratch.

## Goals

1. **The outside: a short, hand-built threshold.**
   - The oversized, slightly uncanny B1 HQ (concept `art/office-concepts/B1_v1.png`) looms over a
     loading dock and an empty night car park.
   - About 15–30 s walk from the truck to the door. The truck is home base: the banking zone, as today.
2. **Two entrances:** the loading dock (main) and the lobby (second), giving a loop. Owner decision.
3. **The outside previews the shift.** A few exterior details switch on from this run's settings:
   - Gloom oozing under the dock door on a dirty shift.
   - A lit floor when something special is awake.
4. **Anomaly pool:** each run, 1–2 odd exterior details switch on from a pool. Pure atmosphere, no new
   systems. Starting pool:
   - a window silhouette that vanishes when looked at again;
   - automatic doors opening for nobody;
   - one parked car with its engine ticking;
   - a lobby welcome screen looping "WE VALUE YOUR TIME" with one word wrong;
   - the security booth TV on;
   - a WET FLOOR sign standing in the rain;
   - an upside-down motivational banner.
5. **A real office structure inside:**
   - corridors as the spine, with rooms off them (not a grid of touching rooms);
   - reception at the lobby entrance;
   - a core of lifts, toilets and stairs as **set dressing only** (see floors);
   - meeting rooms on the outer walls.
6. **Hand-built room kits, five types at launch (owner pick):**
   - open-plan desk pods;
   - conference room (glass walls, one door, big table);
   - breakout lounge;
   - storage / janitor closet;
   - server room (a landmark).

   Plus reception as the fixed entry room.
7. **Variation per room**, four layers:
   - 2–3 hand-built layout variants per type, and mirroring;
   - size slots (S/M/L) the generator offers;
   - per-run toggles inside a room: prop groups on or off, door states, lights on, off or flickering;
   - random dressing: clutter and goo on marked spots, plus valuables as today.
8. **Real doors with light gameplay** (owner-approved rules):
   - Players open and close doors with one interact, with a short swing of about 0.3 s.
   - A **closed door blocks sight** both ways. Glass doors do not.
   - **Mr. Harlow is never blocked by a door.** Doors are not obstacles to his pathfinding. When he
     reaches one it swings open on its own, costing him a short beat of about 0.5 s.
   - **Chase rule:** if he saw a player enter a door, he goes to that door and keeps hunting from there.
     Closing it breaks sight, not his memory of where you went.
   - Optional if cheap: a slam makes a small noise he can hear.
   - Some doors start locked as set dressing. No keys, no locking or barricading by players.
9. **Hallway variety:**
   - straights, corners, T-junctions;
   - wide and narrow sections;
   - glass walls looking into rooms;
   - a lobby/atrium node;
   - dead ends with a cupboard.
10. **One playable floor at launch**, built so more floors are a later content update. Each room carries
    a floor number from day one. Height is shown without gameplay:
    - an atrium or mezzanine you look into;
    - a glass lift that moves on its own (also an anomaly);
    - a locked stairwell door signed "Floors 2–14".
11. **One consistent style everywhere, inside and out:**
    - the S2 clean + S1 moody finish approved in the mock room;
    - props built per the `texture-pipeline` skill: hard furniture hand-built, soft props as repaired
      AI meshes, every surface with colour + normal + roughness;
    - simple shapes with drawn detail, not ultra-detailed models (owner, 2026-10-22).

## Non-goals (for launch)

- More than one playable floor; stairs or lifts players can use.
- Outdoor enemies, outdoor puzzles or outdoor loot. The outside is the safe zone, as the loading bay is
  today: Mr. Harlow has no patrol points there.
- Keys, lockable or barricadable doors, door health.
- New AI states for Mr. Harlow beyond the door rule above.
- The truck redesign. It is being regenerated separately; this design only needs a parking spot at the
  dock and the banking zone beside it.
- Room types beyond the five + reception. Kitchen and records are the first additions after launch.

## Anti-goals (failure even if it works)

- **The building still reads as procedural:** repeated identical rooms, rooms with no reason to be where
  they are, corridors that go nowhere for no reason.
- **Inconsistent style:** a room or prop with AI tells (seams, white lines, painted-on detail, wobbly
  edges) or a finish that does not match the rest.
- **Mr. Harlow cannot properly traverse a generated layout:** stuck on a door, a corner or furniture;
  unreachable rooms; losing a chase because of a door. This is the owner's explicit bar.
- **Not scary:** flat, evenly lit, cheerful rooms. The S1 moody side must survive in every kit.
- **The outside becomes content:** a long walk, a maze, things to do out there.
- **Furniture clipping** (seen in the mock room): whiteboards in walls, desks inside desks, chairs not
  tucked in. Kits are authored clean, so placement is designed, not rolled.

## Constraints

- **Launch about Nov 26, 2026** (pre-launch plan doc). The MVP must not slip for map ambition.
- **Shift length is 8:30** (`ShiftConstants.SHIFT_SECONDS = 510`; owner raised it from 7:00 on 2026-10-22 after
  the stage 1 play-check, because the corridor office walks further: about 177 studs truck-to-pile one way).
  Layout size and banking walks must fit that.
- **Hideable furniture fits the largest employee in the knee-hug pose:**
  - Free space under a desk is at least `HideConstants.HUG_FREE_MIN` = 3.6 W × 4.2 H × 4.3 D studs.
  - The furniture grows to fit; characters never shrink (memory `hide-furniture-sizing`).
- **Roblox limits:**
  - 20,000 triangles per mesh;
  - mobile performance;
  - art lives in the Studio place, never in Rojo (`AGENTS.md`, deployment model).
- **Windows show no outside from inside:** the interior is procedural, so a view out would contradict
  it. Use closed blinds over opaque night glass, as in the mock room.
- **Assets upload only to Icey Labs (group 189923277)**, with the owner's OK per batch. Never use group
  9738205.
- **Repo rules:** spec-first TDD, `--!strict`, module placement per `docs/project-structure.md`, plain
  commits.

## What exists today (builder context)

- **Server feature `Office`** (`src/ServerScriptService/Features/Office`):
  - `OfficeLayoutGenerationUtils.generate(base, seed)` makes a fresh layout from a seeded graph on a 5×5
    grid (16–24 rooms) via `OfficeLayoutGraphRules`.
  - `OfficeLayoutRoomUtils` places furniture **by rule per zone** (the part this design replaces for kit
    rooms).
  - `OfficeBuildSystem` and `OfficeDecorSystem` build it.
  - Doorways are open gaps (`OfficeDoorwayVisualSystem` adds trim only).
- **Data shapes** (`OfficeTypes`):
  - `Room` (box + zone);
  - `Door` (a, b, x, z, width);
  - `Marker` (`pile | item | desk | locker | spawn | patrol | rest | shelf | counter | plant | board |
    cabinet | table | closet`);
  - `Truck` (banking footprint + clock);
  - `Layout` (start room `"bay"`, Mr. Harlow's patrol `route` + `rest`).
- **Gameplay reads markers:** spawns, items, piles, hide desks, lockers, closets, patrol. Kits must keep
  supplying them.
- **Art from the mock-room test** (Icey Labs IDs in `art/office-concepts/MOCKROOM_ASSET_IDS.json`):
  - hand-built desk, chair, conference table, reception, coffee bar, lockers, filing, bookshelf,
    partition, whiteboard, copier, floor lamp, monitor set, window bay, blinds, cooler;
  - repaired sofa, plants, bin, vending;
  - surface materials (plaster, oak, carpet tiles, ceiling tiles, troffer panels).
- Reusable workflow: the `texture-pipeline` skill.

## Decided how (owner or this conversation)

- **Generator approach:** keep the seeded generator; change what it places. It lays out a corridor graph
  with room slots, then fills each slot with a hand-built kit of a fitting type and size, then picks
  toggles and dressing. Rooms are no longer furnished by rule.
- **Kits carry their own markers.** Each kit variant is authored in Studio with its gameplay markers
  (desk hide spots, lockers, item and pile spots, patrol-safe points, door sockets). The generator reads
  them instead of rolling furniture.
- **Doors live at sockets** shared by a kit and a corridor piece. A socket says width, glass or solid,
  and whether a locked variant is allowed.
- **The outside is one hand-built set in the Shift place:**
  - the dock where the truck parks (the banking zone moves to the truck there);
  - the lobby doors as the second entrance;
  - the anomaly pool as named, toggleable groups.
- **Landmarks:** the server room appears in every run. At most one rare set piece per run once more
  exist. *Builder's call:* exact odds.

## Settled in review (my calls unless marked; the owner can overrule)

- **Launch art scope: the lean set (owner, 2026-10-22).**
  - All 5 room types with **1–2 hand-built layouts each** (about 7 kit rooms), plus reception and the
    finished outside.
  - More layouts ship as post-launch updates.
  - Launch variety leans on mirroring, size slots, toggles and random dressing. Those layers must be in
    place at launch.
  - This narrows goal 7's "2–3 layouts per type" to the post-launch target.

- **How Mr. Harlow moves (from the code):** he uses PathfindingService (`NpcMoverSystem`, with costs).
  The office already places PathfindingModifiers (`OfficeBuildSystem`).
  - Door leaves carry a PathfindingModifier with `PassThrough = true`, so a door is never an obstacle to
    his path. The builder must verify this against the Roblox docs.
  - A door swings open when he is within a short distance.
  - Validation in two layers:
    1. a pure check in specs: the room/door graph is connected, every required marker's room is
       reachable;
    2. a Studio/Open Cloud check: `ComputeAsync` from his spawn to every patrol point and room, with
       every door closed.
- **Locked doors never gate anything.** A locked door is only ever a facade: placed on a wall with no
  room behind it, or as a second door into a room that also has an unlocked one. Players and Mr. Harlow
  can always reach every room, item, pile and spawn.
- **Quotas keep today's economy.**
  - The contract is tuned on about 730–1495 Gloom per site (4–6 dirty rooms of 3–5 piles); see
    `ShiftConstants`. `OfficeSpawnUtils` already tops a thin site up with piles. Kits must supply enough
    pile/item markers that the same rolls work.
  - **Hide spots:** at least 8 per run (2 × the max crew of 4); the generator re-rolls a layout that
    falls short.
- **Size:** keep today's scale, because the economy was tuned on it.
  - About 14–20 kit rooms plus corridors, with total floor area near today's.
  - The farthest room should be no more than about 40 s of walking from the truck.
  - The builder measures today's map and matches it.
- **Entrances:** both the dock and the lobby are always open, so the loop exists every run. The crew
  arrives at the truck, as today.
- **Exterior previews use what exists.**
  - "Dirty shift" maps to the generated site's total Gloom against the 730–1495 range: no ooze, a little,
    or a lot under the dock door.
  - "Something special awake" has no system behind it today, so it is **dropped for launch**. No new
    systems for the outside.
- **The server room is a landmark, not required content.** It appears in every run and carries normal
  markers like any kit.
- **Order of work:** code against **greybox kits first** (generator, doors, validation, one real kit end
  to end), then art for the remaining kits, then the outside, then toggles and anomalies. This way
  gameplay is testable early, and art never waits on generator bugs.

## Left to the builder

- **Kit authoring format:** Studio models with tagged parts or attachments, or a data module per kit
  plus art; and where kits live (artist-owned, so not in Rojo).
- **How the corridor graph is generated:** the spine-and-branch shape, a node count that fits a 7-minute
  shift, how slots map to S/M/L, and how mirroring is applied.
- **Mr. Harlow and doors:** the mechanism that keeps doors off his path (collision group, door leaf not
  in the navmesh) and how "the door he saw you take" is stored.
- **Validation per layout:** an automated check that every room and patrol point is reachable on the
  navmesh with all doors closed. The owner's traversal bar should be a test, not hope.
- **How shift settings map to exterior previews,** and the anomaly odds.
- **The order of work** (suggested: generator + doors + one kit end to end, then the other kits, then
  the outside, then toggles and anomalies) and how it is split into plans.
