# Office Map Stage 1: Kit-Room Generator, Real Doors, Harlow Traversal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace today's rule-furnished grid office with a corridor network whose rooms are hand-authored greybox kits, add real doors players open and close, and prove Mr. Harlow traverses every generated layout with every door shut.

**Architecture:** The seeded generator stays pure and data-only. `OfficeCorridorUtils` lays a corridor network on a jittered lattice (spine dock→lobby, branches, a loop, wide/narrow segments, one atrium). `OfficeLayoutGenerationUtils` then lines the corridor segments with kit rooms from `OfficeKitRegistry`, transformed by `OfficeKitUtils.place` (four facings × mirror). The output is still an `OfficeTypes.Layout`, so spawns, hiding, decor and the patrol route keep working. Doors become `Door.kind = "solid" | "glass"` leaves built by `OfficeDoorSystem`. Each leaf carries a `PathfindingModifier { PassThrough = true }`, so a door is never in Harlow's path. He opens doors within reach as he thinks, and pauses for a short beat (`OccupantDoorRules.hold`). Glass panes and glass leaves carry a sight-through tag that Harlow's sight ray excludes.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ specs (Studio, `RunTests`), ServiceController, PathfindingService, CollectionService.

**Spec:** `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md` (owner-approved 2026-10-22). This plan is **stage 1** of its "Order of work": generator, doors, validation and greybox kits. Kit art (stage 2), the hand-built outside (stage 3), and per-run toggles and anomalies (stage 4) get their own plans.

## Global Constraints

- `--!strict`, no `any`, no casts. Follow `AGENTS.md` and `docs/project-structure.md`.
- Every new module gets a `.spec.luau` sibling or a reasoned `SpecRoots.EXEMPT_MODULES` entry. After adding, moving or deleting a module, run `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no trailers**. Stage files by name. Never stage `src/ServerScriptService/Core/Testing/SpecRoots.luau` except your own hunk: it carries someone else's uncommitted edit, so stage with `git add -p` and pick only your lines.
- Do not push. Do not run `wally`, `rokit`, `rojo build` or `scripts/check.sh`. Run `selene` and `stylua` on the files you touch.
- Rojo serves this worktree live to Studio: never `git checkout`, `reset` or `stash`.
- Specs run only in Studio (the Shift place on Rojo port 34872, `Workspace.RunTests = true`, Play). **The controller runs them**; implementers write specs and report.
- Art never goes into Rojo. Greybox kits are data. Their art arrives in stage 2.
- Spec values used verbatim:
  - shift is 420 s;
  - `HideConstants.HUG_FREE_MIN` = 3.6 W × 4.2 H × 4.3 D;
  - at least 8 hide spots per run;
  - 14–20 kit rooms;
  - farthest room ≤ 40 s of walking from the truck;
  - door swing about 0.3 s;
  - Harlow's door beat about 0.5 s;
  - one playable floor; every room carries `floor = 1`.
- Locked doors are only ever facades. A facade is a closed leaf on an **unbroken** wall, so it never gates a room, item, pile or spawn.
- Windows show no outside. Nothing in this plan cuts an exterior window.

## Rulings made while planning (the spec left these to the builder)

- **Kit format:** a kit is a **data entry** in `OfficeKitRegistry`: footprint, front door, glass span, and markers in kit-local studs. The registry is the source of truth. Stage 2 adds the art model per kit and an exporter that keeps the two in sync. Generated rooms skip `OfficeFurniturePlacementUtils.normalize` and `dropUnfit`: kits are authored clean, and `OfficeKitRules` proves it.
- **Kit frame:** origin at the kit's front-left corner. +X runs along the front wall; +Z runs into the room (the front wall is local `z = 0`). The single door is on the front wall. Extra sockets and locked second doors are post-launch.
- **Corridor shape:** a lattice of `LATTICE_COLS × LATTICE_ROWS` junctions with jittered spacing.
  - Two anchor junctions have **fixed** coordinates so stage 3's hand-built outside can wrap a stable dock and lobby: the dock is col 3 / row 1, the lobby col 1 / row 3.
  - The spine is a seeded shortest lattice path from dock to lobby. Branches grow until the edge target, then `LOOPS` extra edges close cycles.
  - Empty leaf branches are pruned after rooms are placed. A surviving dead end gets a supply-cabinet `closet` marker (the spec's "dead end with a cupboard").
- **Lobby entrance until stage 3:** reception's back wall carries an `"entrance"` facade (locked glass doors). Stage 3 turns it into a real exit. The crew still arrives at the truck in the loading bay, attached south of the dock junction exactly as `OfficeLoadingBayUtils` does today.
- **Doors and pathfinding:**
  - The leaf keeps `CanQuery = true` with a `PathfindingModifier` (`Label = DOOR_PATH_LABEL`, `PassThrough = true`).
  - It collides only while closed.
  - Harlow opens every closed door within `DOOR_AUTO_OPEN_RADIUS` at each think. If the Task 8 harness shows PassThrough does not keep paths through closed leaves, the fallback is one `PathfindingLink` per door across the doorway. That is the controller's ruling to make, recorded in the ledger.
- **Chase rule:** already true today. `lastSeen` is the last point he saw you; losing sight sends him there and then searches from there. A closed door breaks sight, not that memory. Task 7 pins this with a spec; it needs no new state.
- **Slam noise:** closing a door emits `NoiseServiceServer:emit(position, DOOR_SLAM_RADIUS, "door", {userId})`.
- **Doors start closed** this stage. Per-run door states are stage 4 toggles.
- **Floor area:** measure today's mean generated floor area once (Task 4, step 1) and keep the new mean within ±30 %.

## Review Focus

- **A seed where kits cannot fill the lattice** (too few rooms, no server room, no breakout, under 8 hide spots, or a capacity failure): the generator retries derived seeds and never builds a broken layout. Pinned in Task 4 (`200 seeds all pass every check`).
- **Furniture clipping after mirror or rotation:** a kit that is clean in one orientation clips in another. Pinned in Task 2 (every kit × 4 facings × mirror passes `OfficeKitRules.check` and `OfficeLayoutRules.validate`).
- **A player standing in a doorway when someone closes the door:** the close is refused, never trapping or flinging them. Pinned in Task 6 (`OfficeDoorUtils.canClose`).
- **Glass leaves and glass walls:** they must block bodies but not Harlow's sight. A solid closed leaf must block his sight. Pinned in Task 5 (sight exclusion spec) and Task 6 (leaf tags).
- **Harlow reaching a closed door mid-chase:** he opens it, pauses about 0.5 s, and keeps chasing; he is never blocked or stuck. Pinned in Task 7 (`hold`) and Task 8 (closed-door traversal harness).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Utils | OfficeKitUtils | Place a kit in the layout: footprint, door, glass span and markers for a facing and mirror |
| Office | server | Data | OfficeKitRegistry | The greybox kit catalogue, looked up by id and by room type |
| Office | server | Rules | OfficeKitRules | Is a kit authored clean: markers inside, no overlaps, door approach and chair space clear |
| Office | server | Utils | OfficeCorridorUtils | The seeded corridor network: junctions, segments, open links, atrium, anchors |
| Office | server | Utils | OfficeDoorUtils | Door maths: leaf frame at a swing fraction, doors near a point, whether a doorway is clear to close |
| Office | server | Systems | OfficeDoorSystem | Builds door leaves and facades; opens and closes them (Instance shell) |
| Office | server | Testing | OfficeTraversalHarness | Builds seeds in Studio and paths Harlow to every room and patrol point with all doors closed |
| Occupant | server | Rules | OccupantDoorRules | Whether Harlow holds still for his door beat |

Deleted: `Office/Rules/OfficeLayoutGraphRules` and `Office/Utils/OfficeLayoutRoomUtils`, with their specs. Nothing else uses them after Task 4; check with `grep`.

---

### Task 1: Kit types and `OfficeKitUtils.place`

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeKitUtils.luau` and `OfficeKitUtils.spec.luau`

**Interfaces:**
- Produces, in `OfficeTypes`:
  - `DoorKind = "open" | "solid" | "glass"`.
  - `Door.kind: DoorKind?`, where nil means open (authored layouts are unchanged).
  - `Room.floor: number?`, `Room.kit: string?`, `Room.roomType: RoomType?`.
  - `RoomType = "pods" | "conference" | "breakout" | "storage" | "server" | "reception"`.
  - `Facade = { room: string, x: number, z: number, width: number, kind: "entrance" | "stairwell" }`.
  - `Layout.facades: { Facade }?` and `Layout.panes: { Segment }?` (glass wall spans).
  - `KitMarker = { kind: MarkerKind, x: number, z: number, rotation: number? }`.
  - `Kit = { id: string, roomType: RoomType, name: string, size: "S" | "M" | "L", width: number, depth: number, door: { offset: number, width: number, kind: DoorKind }, glass: { from: number, to: number }?, markers: { KitMarker } }`.
    - `door.offset` and the glass span are measured along the front wall from local x = 0.
  - `Placement = { room: Room, doorX: number, doorZ: number, doorWidth: number, doorKind: DoorKind, pane: Segment?, markers: { Marker } }`.
- Produces `OfficeKitUtils.place(kit: Kit, roomId: string, frontX: number, frontZ: number, facing: Edge, mirrored: boolean): Placement`.
  - `facing` names which edge of the placed room is its front wall.
  - `(frontX, frontZ)` is where the kit's local origin lands: the front-left corner seen from inside the room.
  - Rotation θ by facing: minZ 0, minX π/2, maxZ π, maxX −π/2.
  - A world point is `(frontX, frontZ) + R(θ)·(x', z')`, where `x' = if mirrored then width − x else x`.
  - A marker's yaw is `θ + (if mirrored then −r else r)`.
  - `R(θ)` is `CFrame.Angles(0, θ, 0)` applied to `(x', 0, z')`.
  - Marker ids are `<roomId>.<kind>.<n>`, with n counting per kind in kit order.
  - The room gets `floor = OfficeConstants.FLOOR_NUMBER`, `kit = kit.id`, `roomType`, `name = kit.name` and `zone = kit.roomType`.

- [ ] **Step 1: Write the failing spec** `OfficeKitUtils.spec.luau`. Use a fixture kit (not the registry): width 20, depth 10, door offset 5 width 6 solid, glass span 12–18, markers `{ kind = "desk", x = 2, z = 3, rotation = 0 }` and `{ kind = "pile", x = 4, z = 8 }`.
  - `it("facing minZ is the identity")`: `place(kit, "r1", 100, 50, "minZ", false)` gives:
    - room `minX=100, maxX=120, minZ=50, maxZ=60`;
    - door at `(105, 50)`, width 6;
    - desk marker `r1.desk.1` at `(102, 53)` with rotation 0;
    - pane `{ x1=112, z1=50, x2=118, z2=50 }`.
  - `it("mirroring flips x and negates yaw")`: with mirrored true and the desk rotation `0.5`, the desk lands at `(118, 53)` with rotation `-0.5`, and the door at `(115, 50)`.
  - `it("every facing keeps the door on the front edge and every marker inside")`: for each facing in `{ "minZ", "maxZ", "minX", "maxX" }`, with mirrored false and true:
    - `OfficeLayoutUtils.doorEdge(placement.room, { a = "r1", b = "x", x = placement.doorX, z = placement.doorZ, width = 6 })` equals `facing`;
    - every marker is inside the room bounds;
    - the room's area is 200.
  - `it("facing minX turns local +Z into world +X")`: placing at `(0, 0)` facing `"minX"` puts the pile marker (local 4, 8) at world `x = 8`.
  - `it("rooms carry floor 1 and their kit")`: `room.floor == 1`, `room.kit == "fixture"`, `room.roomType == "pods"`.
- [ ] **Step 2:** Controller runs the specs: FAIL, the module is missing.
- [ ] **Step 3:** Add the types to `OfficeTypes` and `FLOOR_NUMBER = 1` to `OfficeConstants`, then implement `place`.
- [ ] **Step 4:** Controller runs the specs: PASS. Existing Office specs still pass (the new fields are optional).
- [ ] **Step 5:** Run `module_map.py --write`, selene and stylua, then commit: `Office: kit types and OfficeKitUtils.place (facing, mirror)`.

### Task 2: `OfficeKitRules` and the greybox `OfficeKitRegistry`

**Files:**
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeKitRules.luau` (+ spec)
- Create: `src/ServerScriptService/Features/Office/Data/OfficeKitRegistry.luau` (+ spec, so the catalogue is validated like `OfficeLayoutConstants` is)

**Interfaces:**
- Consumes: Task 1 types and `OfficeKitUtils.place`.
- Produces:
  - `OfficeKitRules.check(kit: Kit): (boolean, { string })`.
  - `OfficeKitRegistry.KITS: { Kit }`.
  - `OfficeKitRegistry.get(id: string): Kit?`.
  - `OfficeKitRegistry.ofType(roomType: RoomType): { Kit }`.

`check` lists every problem:
- a marker footprint outside the walls (the same test as `OfficeLayoutRules` `markerInside`, with sizes from `OfficeConstants`; pile, item, patrol and rest use `MARKER_MARGIN`);
- two furniture footprints overlapping, for desk, locker, closet, shelf, counter, cabinet, table, board and plant;
- any furniture footprint inside the door approach: a box `door.width + 2` wide and `DOOR_APPROACH = 5` deep behind the door;
- a desk without its chair strip clear: `DESK_SIZE.X` wide, `OFFICE_CHAIR_SIZE.Z + OFFICE_CHAIR_GAP` deep, on the desk's local +Z side, inside the walls and free of other footprints;
- a desk whose free space under it is smaller than `HideConstants.HUG_FREE_MIN` (compare `DESK_SIZE` minus a 0.3 top against it);
- a `rest` or `patrol` marker missing (every kit needs `patrol` ≥ 1);
- under 3 `pile` markers (`PILES_PER_ROOM.min`);
- a pile or item marker inside a furniture footprint grown by `SURFACE_ITEM_CLEAR`.

Greybox kits: the implementer authors the coordinates. The counts are minimums.

| id | roomType | name | size | W × D | door (offset, width, kind) | glass | markers (at least) |
|---|---|---|---|---|---|---|---|
| pods_a | pods | Desk pods | L | 36 × 28 | 18, 6, solid | – | desk 6, pile 5, item 3, patrol 1, plant 1, cabinet 1 |
| pods_b | pods | Desk pods | M | 28 × 22 | 6, 6, solid | – | desk 4, pile 4, item 2, patrol 1, board 1 |
| conference_a | conference | Conference room | M | 28 × 20 | 6, 6, glass | 10–26 | table 1, pile 4, item 2, board 1, patrol 1 |
| conference_b | conference | Meeting room | S | 18 × 16 | 4, 6, glass | 8–16 | table 1, pile 3, item 1, patrol 1 |
| breakout_a | breakout | Breakout lounge | M | 26 × 22 | 20, 6, solid | – | counter 1, table 2, pile 5, item 3, rest 1, patrol 1, plant 1 |
| storage_a | storage | Storage closet | S | 16 × 14 | 8, 6, solid | – | closet 2, locker 2, shelf 1, pile 3, item 1, patrol 1 |
| server_a | server | Server room | M | 24 × 20 | 12, 6, solid | – | shelf 3 (server racks, greybox), closet 1, pile 4, item 2, patrol 1 |
| reception_a | reception | Reception | L | 32 × 26 | 16, 10, open | – | counter 1, plant 2, cabinet 1, pile 4, item 2, patrol 1 |

- [ ] **Step 1: Write the failing `OfficeKitRules.spec`.**
  - A clean fixture kit passes with `{}`.
  - The fixture with a desk moved onto a shelf fails with a message containing `overlaps`.
  - A desk 1 stud from the back wall facing it (no chair strip) fails with `chair`.
  - A plant in the door approach fails with `door approach`.
  - A kit with no patrol marker fails with `patrol`.
  - 2 pile markers fails with `pile`.
- [ ] **Step 2: Write the failing `OfficeKitRegistry.spec`.**
  - `it("every kit passes OfficeKitRules in every facing and mirror")`: for each kit, `check` is ok.
  - For each facing × mirrored, a one-room layout (the placed room, `startRoom` = that room, the truck zeroed inside it, no doors) passes `OfficeLayoutRules.validate` except the truck message, and `OfficeLayoutRules.markerFits` for every marker.
  - `it("covers the lean set")`: `ofType` is non-empty for all six room types, with exactly one `reception` and at least one `server` and one `breakout`. A `rest` marker exists only in breakout kits.
  - `it("ids are unique")`.
- [ ] **Step 3:** Controller runs: FAIL.
- [ ] **Step 4:** Implement `OfficeKitRules`, then author the 8 kits until both specs pass.
- [ ] **Step 5:** Controller runs: PASS. Commit: `Office: greybox kit catalogue and OfficeKitRules`.

### Task 3: `OfficeCorridorUtils.network`

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeCorridorUtils.luau` (+ spec)
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`

**Interfaces:**
- Produces:
  - `export type Segment = { room: Room, horizontal: boolean, from: number, to: number }`. `from` and `to` are the span along the corridor between junction faces.
  - `export type Network = { rooms: { Room }, doors: { Door }, segments: { Segment }, junctions: { [string]: Room }, dock: Room, lobby: Room, leaves: { Room } }`.
  - `OfficeCorridorUtils.network(rng: Random): Network`.
  - Junction ids are `hallJ<col>_<row>` and segment ids `hallS<n>`. Every corridor room has `zone = "hallway"` and `floor = 1`. Segment rooms are named `"Corridor"`, junctions `"Corridor"`, and the atrium `"Atrium"`.
  - Doors between corridor rooms are `kind = "open"`, with width equal to the segment's width.

Constants added to `OfficeConstants` (values verbatim):

```lua
LATTICE_COLS = 5, LATTICE_ROWS = 4,
LATTICE_STEP_X = 56, LATTICE_STEP_Z = 52, LATTICE_JITTER = 6,
DOCK_NODE = { col = 3, row = 1 }, LOBBY_NODE = { col = 1, row = 3 },
CORRIDOR_WIDE = 10, CORRIDOR_NARROW = 6, NARROW_CHANCE = 0.35, ATRIUM_SIZE = 26,
CORRIDOR_EDGES = { min = 9, max = 12 }, LOOPS = { min = 1, max = 2 },
```

Algorithm:
1. **Lattice lines.** Line `c` sits at `(c − 1) · STEP + jitter`, with jitter in `[−JITTER, JITTER]`. Jitter is 0 on the dock's column line, the dock's row line, the lobby's column line and the lobby's row line.
2. **Spine.** A seeded shortest lattice path from dock to lobby; ties break randomly.
3. **Branches.** Add random lattice edges touching the graph until the edge count is `rng:NextInteger(CORRIDOR_EDGES.min, max)`.
4. **Loops.** Add up to `rng:NextInteger(LOOPS.min, max)` lattice edges between two in-graph nodes not yet joined.
5. **Widths.** Spine edges are `CORRIDOR_WIDE`. Others are narrow with `NARROW_CHANCE`.
6. **Junctions.** A junction square's side is the widest incident edge. One junction with degree ≥ 3, other than dock or lobby, becomes the atrium (`ATRIUM_SIZE`) when one exists.
7. **Segments.** Each segment runs from junction face to junction face, centred on the lattice line, as wide as its edge.
8. **Leaves.** `leaves` lists junctions of degree 1, other than dock and lobby.

- [ ] **Step 1: Write the failing spec**, over seeds 1–100 (yield every 10 seeds with `task.wait()`).
  - It is deterministic per seed.
  - No two corridor rooms overlap (use the same overlap test as `OfficeLayoutRules.validate`).
  - Every door passes `doorEdge` for both rooms.
  - BFS over doors from `dock` reaches every corridor room.
  - `dock` and `lobby` have identical coordinates across all seeds.
  - The edge count is in `[9, 12 + 2]`.
  - At least one cycle exists (edges ≥ junctions).
  - The spine (dock→lobby path) uses only width-10 segments.
  - Both widths appear across the seeds, and an atrium appears in at least 80 of the 100 seeds.
- [ ] **Step 2:** Controller runs: FAIL.
- [ ] **Step 3:** Implement `network`.
- [ ] **Step 4:** Controller runs: PASS. Commit: `Office: seeded corridor network (spine, branches, loop, atrium, fixed anchors)`.

### Task 4: The kit generator replaces the grid generator

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutGenerationUtils.luau`; rewrite its spec.
- Modify: `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau` (+ spec): add `checkHideSpots` and `checkWalk`.
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`, `rebuild` only.
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`.
- Delete: `Rules/OfficeLayoutGraphRules(.spec).luau` and `Utils/OfficeLayoutRoomUtils(.spec).luau`.

**Interfaces:**
- Consumes:
  - `OfficeCorridorUtils.network`;
  - `OfficeKitUtils.place`;
  - `OfficeKitRegistry.ofType`;
  - `OfficeLoadingBayUtils.bay`, `truck`, `arrivals` and `patrolPoint`.
- Produces:
  - `OfficeLayoutGenerationUtils.generate(base: Layout, seed: number): Layout` (same signature).
  - `OfficeLayoutRules.checkHideSpots(layout): (boolean, string?)`: counts `desk` and `closet` markers against `HIDE_SPOTS_MIN`.
  - `OfficeLayoutRules.checkWalk(layout, maxStuds: number): (boolean, string?)`. It runs Dijkstra over door centres from the bay's door, adds the step from the last door to each room's centre, and fails naming the farthest room when its distance is over `maxStuds`.

Constants:

```lua
KIT_ROOMS = { min = 14, max = 20 }, ROOM_MARGIN = 30, ROOM_STEP = 4,
KIT_WEIGHTS = { pods = 45, conference = 25, storage = 20, breakout = 10 }, PERIMETER_CONFERENCE_BOOST = 3,
GENERATE_ATTEMPTS = 8, HIDE_SPOTS_MIN = 8, WALK_SPEED = 16, MAX_WALK_SECONDS = 40,
TARGET_FLOOR_AREA = <measured in step 1>,
```

`generate`:
1. **Try seeds.** For `attempt = 0, GENERATE_ATTEMPTS − 1`, build from `Random.new(seed * 31 + attempt)`. Return the first build that passes:
   - `validate`, `checkCapacity` and `checkRoute`;
   - `checkHideSpots`;
   - `checkWalk(WALK_SPEED * MAX_WALK_SECONDS)`;
   - a room count in `KIT_ROOMS`;
   - exactly one server room, at least one breakout and exactly one reception.

   If no attempt passes, `error` with the reasons.
2. **Corridors.** Run `network`, then attach the bay: `Bay.bay(3, network.dock)`, plus the truck, arrivals and bay patrol as today.
3. **Reception.** Place `reception_a` facing `maxX`, with its front on the lobby junction's `minX` and its door centre on the junction's centre z. Add a `Facade { kind = "entrance", width = 12 }` centred on its back (`minX`) wall.
4. **Deck.** `{ "server", "breakout" }` followed by weighted draws from `KIT_WEIGHTS`, up to `rng:NextInteger(KIT_ROOMS.min, max)` − 1 (reception counts toward the total).
5. **Line the segments.** Visit the segments in shuffled order, both sides in random order. Walk a cursor along the segment's span:
   - Try the next deck type's kits, largest first and randomly mirrored, facing the segment.
   - Conference weight is multiplied by `PERIMETER_CONFERENCE_BOOST` when the slot's back edge is within `ROOM_MARGIN` of the lattice bounding box. Apply this when drawing the deck type for a slot.
   - Reject a placement that overlaps any room or the bay, or leaves the lattice bounding box grown by `ROOM_MARGIN`.
   - On success, add the room, a `Door { a = room, b = segment, kind = kit.door.kind }`, its markers and its pane. Advance the cursor by the kit's width.
   - If nothing fits, advance by `ROOM_STEP`.
   - Stop when the deck is empty.
6. **Prune.** Repeatedly remove leaf segment/junction pairs that have no room door, other than dock and lobby. Add a `closet` marker at the far wall of each remaining leaf junction (a dead end with a cupboard).
7. **Stairwell.** Add one `Facade { kind = "stairwell", width = 6 }` on a junction wall with no incident segment and void behind it: a 6 × 4 probe behind the wall overlaps no room. Pick one with the rng.
8. **Patrol and rest.**
   - Every junction gets a `patrol` marker at its centre.
   - The route is a DFS from the dock junction over doors (not into the bay). It appends each room's patrol marker on entry and the parent's again on backtrack, as today. The bay patrol is inserted after the dock junction's first visit.
   - `rest` is the first breakout's rest marker.
9. **No furniture normalisation.** `rebuild` in `OfficeServiceServer` calls `generate` directly and drops `normalize` and `fitted` for generated layouts. The boot `LAYOUT` keeps them. It also asserts `checkHideSpots` and `checkWalk`.

- [ ] **Step 1: Measure today's floor area.**
  - Before changing anything, the controller runs this in Studio via `execute_luau`: require `OfficeLayoutGenerationUtils` and sum the room areas (excluding the bay) over seeds 1–20.
  - Record the mean, rounded to 100, as `TARGET_FLOOR_AREA`.
  - Note the value in the ledger.
- [ ] **Step 2: Write the failing specs.**
  - In `OfficeLayoutRules.spec`, `checkHideSpots` and `checkWalk` on small fixtures:
    - 7 desks fails and 8 passes;
    - a corridor chain fails at a 100-stud limit and passes at 1000.
  - Rewrite `OfficeLayoutGenerationUtils.spec`, over seeds 1–200 (yield every 10):
    - deterministic;
    - every layout passes `validate`, `checkCapacity`, `checkRoute`, `checkHideSpots` and `checkWalk(640)`;
    - 14–20 kit rooms;
    - exactly one server room and one reception, and at least one breakout;
    - every non-hallway, non-bay room has `kit ~= nil` and `floor == 1`;
    - every kit room has exactly one door, onto a hallway room;
    - every facade's probe overlaps no room;
    - the reception's position is identical across seeds;
    - mean floor area over the seeds within ±30 % of `TARGET_FLOOR_AREA`;
    - at least 30 distinct room-signature strings;
    - at least 4 different kit ids appear in every seed;
    - every seed's `OfficeSpawnUtils.roll` passes `OfficeSpawnRules.check` against the biggest crew's contract (keep the existing spec's `CONTRACT` test).
- [ ] **Step 3:** Controller runs: FAIL.
- [ ] **Step 4: Implement, delete the two retired modules and their specs, then confirm nothing else references them.**
  - Run `grep -rn "OfficeLayoutGraphRules\|OfficeLayoutRoomUtils" src docs`. It should print nothing except the module map, which `module_map.py --write` regenerates.
- [ ] **Step 5:** Controller runs the full suite: PASS. If a kit's markers make capacity or hide counts fail, raise them in the kit, not the rules.
  - Commit: `Office: kit-room generator on the corridor network (replaces the grid generator)`.

### Task 5: Glass panes, and glass Harlow sees through

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau` (+ spec)
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau` (+ spec)
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantSenseSystem.luau`

**Interfaces:**
- Produces:
  - `OccupantConstants.SIGHT_THROUGH_TAG = "SightThrough"`.
  - `mergedWallSegments(layout)` now subtracts `layout.panes` spans from the merged lines, the same way door gaps cut a room's own wall.
  - `OfficeLayoutUtils.panes(layout): { Segment }` returns the panes.
- `OfficeBuildSystem` builds one glass part per pane:
  - `Material = Glass`, `Transparency = 0.55`, `CanCollide = true`, `CanQuery = true`;
  - tagged `SIGHT_THROUGH_TAG`;
  - parented under `Walls` and named `"GlassWall"`.
- `OccupantSenseSystem.glimpses` appends `CollectionService:GetTagged(SIGHT_THROUGH_TAG)` to its exclude list.

- [ ] **Step 1: Write the failing specs.**
  - `OfficeLayoutUtils.spec`: a two-room layout whose shared wall from x 0–20 carries a pane x 10–16 gives merged segments covering 0–10 and 16–20 on that line, and `panes` returns the one pane.
  - `OfficeBuildSystem.spec`: building that layout yields one `GlassWall` tagged `SightThrough`, with collision on.
- [ ] **Step 2:** Controller runs: FAIL.
- [ ] **Step 3:** Implement. The `glimpses` change has no spec (the system is an exempt raycast shell). Note it in the report.
- [ ] **Step 4:** Controller runs: PASS. Commit: `Office: glass wall panes; Harlow's sight passes SightThrough parts`.

### Task 6: Real doors

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeDoorUtils.luau` (+ spec)
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeDoorSystem.luau`, with an exemption entry: `"Instance/TweenService/Interaction shell (door maths is specced in OfficeDoorUtils)"`
- Modify:
  - `OfficeBuildSystem.luau`: `Built.doors: OfficeDoorSystem.DoorSet`, and it calls `OfficeDoorSystem.build`;
  - `OfficeServiceServer.luau`;
  - `OfficeConstants.luau`;
  - `SpecRoots.luau` (your hunk only).

**Interfaces:**
- Constants:

  ```lua
  DOOR_KIND = "officeDoor", DOOR_PATH_LABEL = "OfficeDoor", DOOR_HEIGHT = 9, DOOR_LEAF_THICKNESS = 0.3,
  DOOR_SWING_SECONDS = 0.3, DOOR_OPEN_ANGLE = math.rad(95), DOOR_AUTO_OPEN_RADIUS = 10, DOOR_SLAM_RADIUS = 18,
  ```

- `OfficeDoorUtils`:
  - `leafFrame(door: Door, edge: Edge, swingSign: number, fraction: number, origin: CFrame): CFrame`. The hinge is at the door's −side jamb. At fraction 0 the leaf fills the opening, centred at `DOOR_HEIGHT / 2`. At fraction 1 it is turned `swingSign · DOOR_OPEN_ANGLE` about the hinge.
  - `swingSign(door: Door, edge: Edge, roomA: Room): number`: the leaf swings into the non-hallway room (into `a` when neither or both are hallways).
  - `near(doors: { DoorState }, point: Vector3, radius: number): { string }` returns the ids of closed doors whose centre is within `radius` (XZ distance).
  - `canClose(doorwayMin: Vector3, doorwayMax: Vector3, bodies: { Vector3 }): boolean` is false when any body position is inside the doorway box grown by 1 stud.
  - `export type DoorState = { id: string, position: Vector3, open: boolean }`.
- `OfficeDoorSystem`:
  - `build(layout: Layout, origin: CFrame, parent: Instance): DoorSet` builds:
    - one leaf per `Door` with kind `"solid"` or `"glass"`;
    - one closed, non-interactable leaf flush against the wall per `Facade`, with attribute `OfficeFacade = kind`.
  - Door ids are `"<a>|<b>"`.
  - Leaf: anchored, `CanQuery = true`, `CanCollide = true` while closed, and a child `PathfindingModifier { Label = DOOR_PATH_LABEL, PassThrough = true }`.
    - Glass leaves: `Material = Glass`, `Transparency = 0.5`, tagged `SightThrough`.
    - Interactable: kind `DOOR_KIND`, enabled.
    - Attributes `OfficeDoorId` and `OfficeDoorOpen`.
  - `DoorSet` methods:
    - `toggle(id: string, by: Player?): boolean`. Closing checks `canClose` against every character root. While open, `CanCollide` is false. Closing sets `CanCollide = true` at the end of the swing. It returns whether the state changed.
    - `openNear(point: Vector3): boolean` opens every door in `near(..., DOOR_AUTO_OPEN_RADIUS)` and is true if any opened.
    - `states(): { DoorState }`.
    - `closeAll()` is for the harness.
    - `destroy()`.
  - The swing tweens the leaf CFrame over `DOOR_SWING_SECONDS` with TweenService (Quad Out).
- `OfficeServiceServer`:
  - registers `DOOR_KIND` in `InteractionRegistry`: actionText `"Open / close"`, objectText `"Door"`, maxDistance 8;
  - `onInteract(DOOR_KIND)` calls `toggle(id, player)`. On a close by a player it emits `NoiseServiceServer:emit(leafPosition, DOOR_SLAM_RADIUS, "door", { player.UserId })`;
  - new method `openDoorsNear(self, position: Vector3): boolean` returns false when no office is built;
  - dependencies add `"InteractionServiceServer"` and `"NoiseServiceServer"`. Check that neither depends on Office first.

- [ ] **Step 1: Write the failing `OfficeDoorUtils.spec`.**
  - A door at (10, 0), width 6, on a `minZ` edge: fraction 0 puts the leaf centre at `origin * (10, 4.5, 0)`; fraction 1 rotates it 95° about the hinge at x = 7.
  - `swingSign` picks the kit room over the hallway in both orders of a/b.
  - `near` returns only closed doors within the radius.
  - `canClose` is false with a body at the door centre and true with a body 3 studs outside the box.
- [ ] **Step 2:** Controller runs: FAIL.
- [ ] **Step 3:** Implement the utils, system, build integration and service wiring.
- [ ] **Step 4:** Controller runs the suite: PASS. Then the controller checks in Studio Play (an existing shift, or Cmdr start):
  - a door opens and closes with the prompt in about 0.3 s;
  - closing on yourself is refused;
  - a glass door shows the room behind.

  Take screenshots for the ledger.
- [ ] **Step 5:** Commit: `Office: real doors (solid/glass leaves, facades, prompt, slam noise, PassThrough)`.

### Task 7: Harlow opens doors and takes his beat

**Files:**
- Create: `src/ServerScriptService/Features/Occupant/Rules/OccupantDoorRules.luau` (+ spec)
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau` (`think`)
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`: `DOOR_BEAT_SECONDS = 0.5`
- Modify: `OccupantBrainRules.spec.luau`, a chase-memory test only if none covers it.

**Interfaces:**
- `OccupantDoorRules.hold(intent: NpcTypes.Intent, now: number, holdUntil: number): NpcTypes.Intent` returns `{ kind = "stand" }` when `now < holdUntil` and `intent.kind == "goTo"`; otherwise it returns `intent` unchanged (attack, stand and idle pass through).
- In `think`, before `Sense.gather`: `if OfficeServiceServer:openDoorsNear(position) then holdUntil = now + OccupantConstants.DOOR_BEAT_SECONDS end`. Return `OccupantDoorRules.hold(result.intent, now, holdUntil)`. `holdUntil` is a module local, reset to 0 with the mind.

- [ ] **Step 1: Write the failing spec.**
  - `goTo` at `now = 1`, `holdUntil = 1.4` gives `stand`; at `now = 1.5` it gives the `goTo`; an `attack` intent passes through unchanged.
  - In `OccupantBrainRules.spec`, if no test covers it, add `it("losing sight sends him to the last place he saw them")`: a chase mind whose senses go from a clear glimpse at P to no clear glimpse gives intent `goTo` at P with `run = true`, in mode `search`.
- [ ] **Step 2:** Controller runs: FAIL.
- [ ] **Step 3:** Implement and wire.
- [ ] **Step 4:** Controller runs: PASS. Commit: `Occupant: Harlow opens doors in reach and takes a 0.5 s door beat`.

### Task 8: Traversal harness, with every door closed

**Files:**
- Create: `src/ServerScriptService/Features/Office/Testing/OfficeTraversalHarness.luau` and `OfficeTraversalHarness.spec.luau`

**Interfaces:**
- `OfficeTraversalHarness.run(seeds: { number }, origin: CFrame): { failures: { string }, paths: number }`. For each seed:
  - generate and `OfficeBuildSystem.build` the layout at `origin` (use `CFrame.new(5000, 1, 5000)`, clear of the live office);
  - `doors.closeAll()`;
  - `PathfindingService:CreatePath({ AgentCanJump = true, Costs = { [SAFE_ZONE_LABEL] = math.huge } })`, matching his `pathCosts`;
  - `ComputeAsync` from the bay patrol point to every patrol marker and every room centre;
  - record `"<seed> <target>: <status>"` for any status other than `Success`;
  - destroy the model.
- Spec: `it("Harlow can path to every room and patrol point with every door closed")`: `run({ 1, 2, 3, 4, 5 }, ...)` gives empty `failures` and `paths > 100`.

- [ ] **Step 1:** Write the harness and spec.
- [ ] **Step 2:** Controller runs it in Studio Play.
  - If it passes, PassThrough is verified. Record that in the ledger.
  - If closed doors fail, rule the fallback (a `PathfindingLink` per door, attachments 3 studs either side, the same label), implement it in `OfficeDoorSystem`, and re-run.
- [ ] **Step 3:** Commit: `Office: closed-door traversal harness for Harlow`.

### Task 9: Play-check handoff

- [ ] Controller runs one full shift in Studio and checks the following:
  - spawn at the truck;
  - walk dock → reception;
  - open and close doors;
  - let Harlow patrol through at least 5 doors;
  - get chased through a door, then close it behind you.

  Note anything stuck in the ledger. Capture screenshots of a corridor, the atrium, a glass conference room and a dead-end cupboard.
- [ ] Send the owner the screenshots and the play-check list. Per the standing rule, checklist items count as done only after the owner's play-check.
