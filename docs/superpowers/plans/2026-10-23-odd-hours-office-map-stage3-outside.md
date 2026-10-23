# Odd Hours office map, stage 3: the outside, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The crew arrives and banks at a truck parked out in a fixed, hand-built night yard about 200 studs from the
building's loading dock. They enter the generated office through the dock or the lobby, and Mr. Harlow never follows
them outside.

**Architecture:**
- The layout gains **grounds**: outdoor boxes in layout space (the front yard and the west car park) that are never
  built as rooms.
- It also gains **exits**: openings from a room's outer wall onto a ground. The bay's south wall opens to the yard, and
  the reception's west wall opens to the car park.
- The truck moves onto the yard pad, turned so its ramp faces the building.
- The code builds invisible **Outdoors** volumes over the grounds. They carry Harlow's SafeZone path cost, and they are
  added to his safe zone, so he never sees, hears, catches or paths to anyone outside.
- The client reads the same volumes to blend to a new exterior atmosphere preset.
- The scenery is the approved spike, promoted to place-owned art (`Workspace.OfficeExterior`), never in Rojo.

**Tech Stack:** Roblox Luau (`--!strict`), TestEZ specs (Studio Play with `RunTests`), Studio MCP for the art task and
the Studio verification.

**Spec:** `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md` (goals 1-3, non-goals, anti-goals,
"Entrances", "Exterior previews use what exists"). It is amended by these owner decisions of 2026-10-23, which win over
the spec where they differ:
- **Lobby on the west face.** About 28 s of walking outside from the dock.
- **The truck parks out in the yard, like Lethal Company.** Owner range 160-250 studs; chosen 200, from
  `TRUCK_WALK_STUDS` in the exterior builder. That is about 12.5 s at 16 studs/s, measured 199.5 studs in the spike.
- **The outside gets a brighter night**, while the interior keeps its approved look.
- **The look is the round-2 spike:** `design/production-art/map-kits/odd-hours-b1/exterior-spike/REPORT.md` and its
  captures. That report's numbers are the geometry source for this plan.
- **The anomaly pool stays in stage 4.** The first-minutes ideas are parked in `docs/superpowers/launch-backlog.md`
  and are out of scope here.

## Global Constraints

- `--!strict` everywhere. No `any`, no casts. Spec-first TDD: every new module gets a `.spec.luau` sibling, written
  first.
- Module placement per `docs/project-structure.md`. The New modules table below is the placement decision. Run
  `python3 scripts/python/module_map.py --write` after adding a module.
- **Commits:**
  - plain messages with **no trailers** (AGENTS.md wins over any attribution reminder);
  - stage files by name;
  - never stage the foreign `src/ServerScriptService/Core/Testing/SpecRoots.luau` hunk;
  - don't push.
- No wally / rokit / `rojo build` / `scripts/check.sh` while the owner is connected. No git checkout/reset/stash.
- **Specs run only in Studio Play.**
  1. Set the Workspace attribute `RunTests = true`.
  2. Play.
  3. Read `Tests: N passed`.
  4. **Clear `RunTests` afterwards.** Leaving it on made every Play lag on 2026-10-23.
- **Studio:**
  - Use only "Odd Hours: Shift" (studio_id `197d004d-31af-4c67-abfe-2cc4a86884ee`).
  - Before Play, check that `E:/Projects/peekabu-game-systems/docs/superpowers/studio-playtest-shift.lock` is absent,
    create it naming you, and delete it after.
  - Never touch the Venture window or `studio-playtest.lock`.
- Art lives in the place, never in Rojo. No uploads in this plan. Windows never show an interior or an outside view.
- The outside is the safe zone (spec non-goals): Mr. Harlow has no patrol points, goals, sight, hearing or catches
  there.
- **Keep everything stages 1-2 built:** doors, Harlow's door beat, depth by walk distance from the bay, hide spots ≥ 8,
  and walk ≤ 640 studs from the bay.

## Review Focus

1. **A player standing in the dock or lobby opening, half in and half out.** Harlow may catch them only while they
   stand inside the building, never once they are on a ground box. → Task 4, spec "a point on the yard side of the
   dock exit is safe; a point inside the bay is not".
2. **Harlow chasing a player out of the dock.** His path to a yard point must fail (NoPath), not succeed through the
   opening. → Task 8, probe P2.
3. **A shift started from the authored boot layout, which has no grounds.** Everything must behave exactly as today:
   the truck in the bay, no Outdoors volumes, no exterior preset. → Tasks 1, 3 and 5 each carry a "grounds nil" spec.
4. **Clock-out and banking with the truck turned 180°.** The time clock, overtime sheet, bed prompt and arrival facing
   all follow the truck's yaw, and "aboard" (the truck box) still holds. → Task 3, specs on `arrivalFrame` and
   `truckBox` with yaw π.
5. **The camera crossing the dock threshold quickly.** The atmosphere must not flicker between presets every frame at
   the boundary. → Task 5, spec "outside is decided on the camera point with OUTDOOR_HYSTERESIS".

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Utils | `OfficeGroundsUtils` | The outside in layout space: the yard and car-park boxes, the dock and lobby exits, the truck on its pad. |
| Office | server | Rules | `OfficeOozeRules` | How much Gloom ooze shows at the dock for a site's Gloom total. |
| Office | server | Systems | `OfficeOozeSystem` | Builds the ooze spill on the yard side of the dock exit. |
| Office | server | Systems | `OfficeGroundsSystem` | Builds the invisible Outdoors safe volumes over the grounds into the office model. |

No other new modules. The client's outdoor test goes into the existing `OfficeAtmosphereUtils`.

---

### Task 1: Grounds, exits and the yard truck (data + pure geometry)

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeGroundsUtils.luau` and `OfficeGroundsUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.luau` and its spec

**Interfaces:**
- Produces, types (`OfficeTypes`):
  - `Room` gains nothing.
  - `Layout` gains `grounds: { Room }?` (outdoor boxes, never built, ids `"yard"` and `"carpark"`) and
    `exits: { Door }?`. An exit's `a` is a room id, `b` a ground id, `kind` is `"open"`, and `x`/`z` sit on room
    `a`'s wall.
  - `Truck` gains `yaw: number?`: radians about +Y. nil or 0 is today's truck (cab toward +Z, ramp toward -Z); `math.pi`
    puts the cab toward -Z and the ramp toward +Z.
- Produces, constants: `OfficeConstants.OUTSIDE`, frozen, exactly:
  - `yard = { minX = -164, maxX = 322, minZ = -321, maxZ = -57 }`, name `"Yard"`
  - `carpark = { minX = -164, maxX = -44, minZ = -57, maxZ = 230 }`, name `"Car park"`
  - `DOCK_EXIT_WIDTH = 14`
  - `TRUCK_CENTRE = Vector2.new(168, -276)`
  - `TRUCK_YAW = math.pi`
  - `VOLUME_HEIGHT = 120`
  - Rationale (spike, world = layout + (1000, 1, 0)):
    - the fence box is x 836..1322 and z -321..230;
    - the podium's outer faces are z -57 (south) and x -44 (west);
    - the dock opening is x 1161..1175;
    - the truck pivot is (1168, -276).
- Produces, functions (`OfficeGroundsUtils`):
  - `grounds(): { Room }`: the yard and the car park, in that order.
  - `dockExit(bay: Room): Door`: on the bay's minZ wall, at the bay's centre x, width `DOCK_EXIT_WIDTH`.
  - `lobbyExit(reception: Room, z: number, width: number): Door`: on the reception's minX wall.
  - `truck(): Truck`: `BED_SIZE` footprint centred on `TRUCK_CENTRE`, with `yaw = TRUCK_YAW`. The clock is at
    `CLOCK_SIDE` / `CLOCK_BACK`, rotated by the yaw.
  - `groundAt(grounds: { Room }, x: number, z: number): Room?`.
- Changes `OfficeLoadingBayUtils`:
  - `arrivals`, `arrivalFrame` and `truckBox` honour `truck.yaw`.
  - Arrival offsets rotate with the yaw. The facing is "out of the open back": -Z at yaw 0, +Z at yaw π.
  - `truckBox` stays the bed footprint up to `TOP`; a 180° turn leaves the box unchanged.

- [ ] **Step 1: Write the failing specs.** `OfficeGroundsUtils.spec.luau`:
  - **`grounds()`:** returns ids `{"yard","carpark"}` with the exact boxes above; the two boxes touch at z -57 and do
    not overlap.
  - **`dockExit`:** `dockExit({id="bay",minX=146,maxX=190,minZ=-52,maxZ=-10})` →
    `{a="bay", b="yard", x=168, z=-52, width=14, kind="open"}`.
  - **`lobbyExit`:** `lobbyExit({id="reception1",minX=-38,...}, 152, 12)` →
    `{a="reception1", b="carpark", x=-38, z=152, width=12, kind="open"}`.
  - **`truck()`:** centre (168, -276), `maxX-minX == BED_SIZE.X`, `maxZ-minZ == BED_SIZE.Z`, `yaw == math.pi`.
  - **`groundAt`:**
    - (168, -200) → yard;
    - (-100, 150) → carpark;
    - (168, -30) → nil (inside the building);
    - (-41, 150) → nil (the podium wall gap).
  - **Review Focus 1:** `groundAt(grounds(), 168, -57.1)` → yard and `groundAt(grounds(), 168, -55)` → nil (the
    opening's depth is not outside).

  `OfficeLoadingBayUtils.spec.luau` adds:
  - `arrivalFrame({...truck, yaw=math.pi}, 1).LookVector` ≈ (0, 0, 1);
  - with yaw nil it is ≈ (0, 0, -1), as today;
  - the arrival points with yaw π are the yaw-0 points rotated 180° about the bed centre;
  - `truckBox` with yaw π equals `truckBox` with yaw nil.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL (module missing / wrong facing).
- [ ] **Step 3: Implement** the types, constants, `OfficeGroundsUtils` and the yaw handling in
  `OfficeLoadingBayUtils`. Rotate offsets with `CFrame.Angles(0, yaw, 0)` about the bed centre.
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office grounds: yard and car park boxes, dock and lobby exits, the truck turned on the yard pad`

### Task 2: The generator uses the outside

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutGenerationUtils.luau` (bay/truck block about
  566-650, entrance facade at 618) and its spec
- Modify: `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau` (truck-in-start-room at 223-240,
  spawn check at 290) and its spec

**Interfaces:**
- Consumes: Task 1's `grounds()`, `dockExit`, `lobbyExit`, `truck()`, `groundAt`.
- Produces, for a generated layout:
  - `layout.grounds = grounds()`
  - `layout.exits = { dockExit(bay), lobbyExit(reception, <today's entrance facade z>, ENTRANCE_WIDTH) }`
  - `layout.truck = truck()`
  - spawn markers `yard.spawn.N` (room `"yard"`) at `arrivals(layout.truck)`, replacing `bay.spawn.N`
  - no `"entrance"` facade
  - `startRoom` stays `"bay"`, so depths and the walk cap are still measured from the dock room.
  - The bay keeps its door to the dock junction, its patrol point and its vinyl. It gains 2 `shelf` markers, one
    against each side wall (x walls), centred in z, `MARKER_MARGIN` in from the wall.
- `OfficeLayoutRules.validate` changes:
  - When `layout.grounds` is set, the truck must lie inside a ground, not the start room.
  - Every exit's `a` is a room and `b` a ground, and the exit sits on room `a`'s wall within the wall's span.
  - Grounds overlap no room.
  - `spawn` markers may name a ground id.
  - When `grounds` is nil, every rule is exactly today's.

- [ ] **Step 1: Write the failing specs.**
  - **Generation spec, over seeds 1-200** (pcall each; every generated layout):
    - `#layout.grounds == 2`;
    - `layout.truck.yaw == math.pi`, and the truck is inside `"yard"`;
    - exactly one exit `bay→yard` with x 168, z -52, and one exit `reception1→carpark` on x -38 with
      138 < z < 166;
    - no facade has kind `"entrance"`;
    - every `spawn` marker has room `"yard"`;
    - no room overlaps either ground;
    - `startRoom == "bay"`;
    - every room's depth is the same as on a layout without grounds. Compare seed 7's depths to a run with the
      grounds step skipped, via a fixture, or assert the bay's depth stays 0 and the dock junction's stays 0 or 1
      as today.
  - **Rules spec:**
    - a layout with grounds and the truck in the bay is an error ("truck must stand on a ground");
    - an exit whose `b` is not a ground is an error;
    - a ground overlapping a room is an error;
    - **Review Focus 3:** the authored `OfficeLayoutConstants.LAYOUT` (no grounds) still validates with 0 errors.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.** Before changing spawn markers, grep every consumer of `kind == "spawn"` and of
  `OfficeLayoutUtils.room(layout, marker.room)`: a marker naming a ground must not crash or mislead any of them.
  Keep `OfficeLayoutGenerationUtils` from growing. It is already over the 400-line limit, so
  put new code in `OfficeGroundsUtils` and leave the generator with call sites only.
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass, including every existing generation spec. Clear
  `RunTests`.
- [ ] **Step 5: Commit.** `Office generator: the truck parks in the yard, the dock and lobby open onto the grounds`

### Task 3: Building the outside: openings, turned truck, Outdoors volumes, whereIs

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau` (truck folder at 141-170, safe zone
  at 291-315) and its spec
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeShellUtils.luau` and/or `OfficeShellVisualSystem.luau`
  (wherever walls are cut for doorways), plus specs
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau` (`whereIs` at about 528, new `outdoors`)

**Interfaces:**
- Consumes: Task 1 types, `groundAt`, the yaw-aware `OfficeLoadingBayUtils`.
- Produces:
  - **Walls:** an exit cuts its opening in room `a`'s wall like an `open` doorway of its width: no leaf, the same
    trim, casing and pilaster rules as an open archway of that width. Nothing is built on the ground side.
  - **Truck bed:** built at `origin * CFrame.new(centre) * CFrame.Angles(0, truck.yaw or 0, 0)`.
    `TruckVisual.build`, `TruckVisual.paperwork`, the TimeClock and the OvertimeSheet all follow the bed's CFrame
    unchanged; they are already bed-relative.
  - **Outdoors volumes:** a folder `Outdoors` in the office model, one invisible part per ground, named after the ground
    id:
    - the ground's box from y 0 to `OUTSIDE.VOLUME_HEIGHT`;
    - `CanCollide=false`, `CanTouch=false`, `CanQuery=true`, `CastShadow=false`, `Transparency=1`;
    - a child `PathfindingModifier` with Label `OccupantConstants.SAFE_ZONE_LABEL` and `PassThrough=false`.
    - Built only when `layout.grounds` is set.
  - **`OfficeServiceServer:outdoors(): { { min: Vector3, max: Vector3 } }`:** the grounds' world boxes, y 0 to
    `VOLUME_HEIGHT`. `{}` when there are no grounds.
  - **`OfficeServiceServer:whereIs(position)`:** unchanged inside rooms. On a ground it returns
    `ground.name, 0, nil`; elsewhere it returns nil as today.
  - `safeZone()` stays the truck box. Clock-out "aboard" (`ShiftClockOutRules.aboard`) must keep meaning "in the
    truck".

- [ ] **Step 1: Write the failing specs.** `OfficeBuildSystem.spec.luau`, on a generated layout (seed 3) built at a test
  origin:
  - **Bay wall:** no wall or slab part of the bay's south wall intersects the box x 161.1..174.9, z -53..-51,
    y 1..9.
  - **Reception wall:** likewise for the reception's west wall over its exit span.
  - **Truck:** `TruckBed.CFrame.LookVector` ≈ (0, 0, 1) at yaw π, and its position is the truck centre.
  - **Paperwork:** the TimeClock's CFrame equals `TruckVisual.paperwork(bed, "clock")`.
  - **Outdoors volumes:** `model.Outdoors` holds 2 parts, `yard` and `carpark`, each with a SafeZone-labelled
    PathfindingModifier, `CanQuery == true` and `CanCollide == false`.
  - **Review Focus 3:** the authored `LAYOUT` builds with no `Outdoors` folder and the truck at yaw 0, exactly as
    today.

  `OfficeServiceServer` has no booted spec, so cover `whereIs` / `outdoors` through `groundAt` in Task 1. Its two
  call sites are checked in the Task 8 probe.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.** The Outdoors volumes go in the new `OfficeGroundsSystem.build(layout, origin, parent)`
  (with its spec), called from `OfficeBuildSystem.build`, so the already oversized `OfficeBuildSystem` gains only
  the call.
- [ ] **Step 4: Run the suite and the traversal harness** (`OfficeTraversalHarness.run(seeds 1-20, CFrame.new(5000,1,5000))`
  from the Server in Play). Expected: suite all pass; traversal 0 failures. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office build: dock and lobby openings, the truck turned in the yard, Outdoors safe volumes`

### Task 4: Mr. Harlow treats the outside as the safe zone

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau` (`Zone` at about 97)
- Modify: `src/ServerScriptService/Features/Occupant/Utils/OccupantMindUtils.luau` (`inZone` at 126) and
  `OccupantSightUtils.luau` (its local `inZone` at 37), plus specs
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantSenseSystem.luau` (`System.layout` at about 110)

**Interfaces:**
- Consumes: `OfficeServiceServer:outdoors()` (Task 3).
- Produces:
  - `OccupantTypes.Zone` gains `more: { Zone }?`.
  - `inZone(point, zone)` is true when the point is in the box **or** in any `more` box.
  - `OccupantSightUtils` uses `OccupantMindUtils.inZone` instead of its own copy, so there is one definition.
  - `System.layout` sets `zone = { min, max, more = <outdoors boxes> }`.
  - Every existing consumer of `senses.zone` (sight, noise, catch, goal candidates, turn rules) thereby ignores
    players outside. `senses.bay` is unchanged.

- [ ] **Step 1: Write the failing specs.**
  - `OccupantMindUtils.spec`:
    - `inZone(p, { min, max, more = { yardBox } })` is true for a point in `yardBox` and outside the main box;
    - with `more = nil` the behaviour is unchanged.
  - **Review Focus 1:** with `more` set to the yard volume, a point at yard maxZ + 0.1 (inside the bay side) is
    false and a point at yard maxZ - 0.1 is true.
  - `OccupantBrainRules.spec` / `OccupantCatchRules.spec`:
    - a glimpse of a player inside a `more` box is ignored;
    - a noise there is ignored;
    - a catch there is refused;
    - each is a mirror of the existing truck-zone cases.
  - `OccupantSightUtils.spec`: the existing truck-zone case still passes through the shared `inZone`.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Harlow: the yard and car park are safe ground; one inZone for all his senses`

### Task 5: The outside's atmosphere

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Vfx/Data/VfxTypes.luau` (`Atmosphere` / `AtmosphereValues` at 84-105)
- Modify: `src/ReplicatedStorage/Client/Features/Vfx/VfxServiceClient.luau` (`readLighting` 63, `writeLighting` 76) and
  `VfxFormulas` (`blendAtmosphere`), plus specs
- Modify: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.luau` and its spec
- Modify: `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAtmosphereSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Shift/Systems/ShiftTransitSystem.luau` (`lit()` at about 104)

**Interfaces:**
- **Vfx:** `Atmosphere` gains optional fields, and `AtmosphereValues` gains them as required fields:
  - `geographicLatitude`
  - `environmentDiffuseScale`
  - `environmentSpecularScale`
  - `atmosphereDensity`
  - `atmosphereOffset`
  - `atmosphereColor`
  - `atmosphereDecay`
  - `atmosphereHaze`
  - `atmosphereGlare`
  - `moonAngularSize`

  The Atmosphere fields read and write the first `Atmosphere` child of Lighting (when none exists they are carried
  but not written). `moonAngularSize` reads and writes the first `Sky` child (likewise). A preset that omits a field
  takes the place's base value captured at start, as the existing fields already do, so every existing preset keeps
  today's look untouched. Numbers blend linearly and colours lerp.
- **Presets:** `OfficeAtmosphereConstants.EXTERIOR = "officeExterior"` and
  `EXTERIOR_OVERTIME = "officeExteriorOvertime"`, added to `PRESETS`.
  - `officeExterior` (spike round 2, exactly):

    | Field | Value |
    |---|---|
    | clockTime | 1.2 |
    | geographicLatitude | 70 |
    | brightness | 2.2 |
    | exposure | -0.1 |
    | ambient | (40,40,60) |
    | outdoorAmbient | (105,108,160) |
    | environmentDiffuseScale | 1 |
    | environmentSpecularScale | 1 |
    | atmosphereDensity | 0.3 |
    | atmosphereOffset | 0.12 |
    | atmosphereColor | (112,100,168) |
    | atmosphereDecay | (72,52,124) |
    | atmosphereHaze | 2.2 |
    | atmosphereGlare | 0.35 |
    | moonAngularSize | 10 |

    Fog stays as the base value.
  - `officeExteriorOvertime`: the same, except:

    | Field | Value |
    |---|---|
    | brightness | 1.8 |
    | outdoorAmbient | (120,60,70) |
    | atmosphereColor | (150,70,90) |
    | atmosphereDecay | (100,40,60) |

    This is the planner's tuning hypothesis, matching the interior's red overtime.
- **Utils:**
  - `OfficeAtmosphereUtils.preset(snapshot, userId, outside: boolean?): string`. During a crew shift (not hub), when
    `outside` it returns `EXTERIOR`, or `EXTERIOR_OVERTIME` in overtime. Tier and break do not change the outside.
  - `OfficeAtmosphereUtils.hum(snapshot, userId, outside: boolean?)`: false when outside.
  - `OfficeAtmosphereUtils.outdoors(point: Vector3, boxes: { { min: Vector3, max: Vector3 } }, wasOutside: boolean): boolean`:
    - true when the point is inside a box shrunk by `OUTDOOR_HYSTERESIS` (= 1 stud) on every side;
    - false when it is outside every box grown by `OUTDOOR_HYSTERESIS`;
    - otherwise `wasOutside` (Review Focus 5).
- **System:** `OfficeAtmosphereSystem` polls every `OUTDOOR_POLL` (= 0.25 s) in a shift.
  - It reads the boxes from `Workspace.CleanupCrewOffice.Outdoors` parts (axis-aligned: `CFrame.Position ± Size/2`).
  - It feeds the camera position to `outdoors`, and re-applies the preset with the existing `FADE` when the result
    changes.
  - It exposes `OfficeAtmosphereSystem.expected(): string`, the preset it wants now.
- **Transit:** `ShiftTransitSystem.lit()` compares against `OfficeAtmosphereSystem.expected()`, not
  `OfficeAtmosphereUtils.preset(...)`, so arriving in the yard counts as lit.

- [ ] **Step 1: Write the failing specs.**
  - `OfficeAtmosphereUtils.spec`:
    - `preset(runningSnapshot, uid, true) == "officeExterior"`;
    - with overtime → `"officeExteriorOvertime"`;
    - with tier 2 and outside → `"officeExterior"`;
    - with outside nil or false → today's results (every existing case unchanged);
    - hub plus outside → depot `EVENING`;
    - `hum(..., true) == false`.
    - `outdoors`: a point 2 studs inside a box → true; a point 2 studs outside every box → false; a point 0.5 inside
      the edge → `wasOutside` for both values of `wasOutside`.
  - `VfxFormulas.spec`:
    - blending two values with different `geographicLatitude` / `atmosphereColor` at alpha 0.5 gives the midpoint;
    - a preset missing the new fields resolves to the base value.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office atmosphere: a brighter moonlit night outside, blended at the doors`

### Task 6: Gloom ooze at the dock (the dirty-shift preview)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeOozeRules.luau` and its spec
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeOozeSystem.luau` and its spec
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau` (after the spawn plan is set, about 405;
  cleared with the plan at about 466)

**Interfaces:**
- `OfficeOozeRules.level(gloom: number): "none" | "little" | "lot"`:
  - `< 985` → none;
  - `< 1240` → little;
  - else lot.
  - These are the thirds of the spec's 730-1495 site range.
- `OfficeOozeSystem.build(level, exitFrame: CFrame, width: number, parent: Instance): Model?`:
  - nil for `"none"`.
  - Otherwise it builds a flat goo spill on the ground side of the dock exit. `exitFrame` sits at the exit centre on
    the floor, LookVector pointing out to the yard. The spill is non-colliding, non-queryable, `CastShadow=false`,
    using the Gloom pile's existing goo look; reuse the pile visual's material and colour constants, and find them
    where Gloom piles are drawn.
  - `"little"`: 2 puddles reaching at most 4 studs out from the threshold.
  - `"lot"`: a spill as wide as the opening, reaching 10 studs out, plus 3 drips down the inside of the opening's
    jambs.
- **The site's Gloom:** the sum of the rolled piles' Gloom, the same figure the economy tunes on (730-1495).
  `OfficeServiceServer` builds the ooze into the office model right after `lastPlan = plan`, when the layout has a
  `bay→yard` exit.

- [ ] **Step 1: Write the failing specs.**
  - `level(984) == "none"`, `level(985) == "little"`, `level(1239) == "little"`, `level(1240) == "lot"`,
    `level(0) == "none"`.
  - `build("none", …)` returns nil.
  - `build("lot", CFrame.lookAt(Vector3.zero, -Vector3.zAxis), 14, folder)`: every part's centre lies at z < 0 (the
    ground side), within |x| ≤ 7 + 1, and every part has `CanCollide == false` and `CanQuery == false`.
  - `build("little", …)`: at most 2 floor parts, all within 4 studs of the threshold.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office: Gloom ooze at the dock shows how dirty the shift is`

### Task 7: Promote the spike to the real exterior set (Studio art, no Rojo)

**Files:**
- Create: `design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau`, from the spike's
  `exterior-spike/BuildExteriorSpike.CommandBar.luau`
- Create: `design/production-art/map-kits/odd-hours-b1/exterior/README.md` (one screen: what it builds, the numbers
  it shares with `OfficeConstants.OUTSIDE`, how to rebuild)

**Interfaces:**
- Consumes: `OfficeConstants.OUTSIDE` (Task 1). The builder copies these numbers at its top with a comment naming the
  constant, because art scripts can't require server modules in Edit reliably.
- Produces: `Workspace.OfficeExterior` in the Shift place, replacing `Workspace.ClaudeExteriorSpike`.
  - **Truck:** no truck clone; the code builds the truck. The truck pad stays, centred on `TRUCK_CENTRE` (world 1168,
    -276).
  - **Reveal liners:** close the gap between the podium wall and the generated walls at both openings:
    - dock: x 1161..1175 sides, from z -57 to -52.6;
    - lobby: from x 956 to 961.4, at the lobby exit's z span.

    Nothing may enter the keep-out (world x 961..1294, z -52..203, y < 17); the builder's own check stays.
  - **Name:** the model is never named `CleanupCrewOffice`, so `clearStrays` never deletes it.
  - **Parts:** ≤ 4,500 parts and ≤ 70 lights.

- [ ] **Step 1:** Check the playtest lock. In Edit, run the builder: it clears and rebuilds `Workspace.OfficeExterior`
  and deletes `Workspace.ClaudeExteriorSpike`, as one ChangeHistory step.
- [ ] **Step 2: Verify with an Edit probe.** It must print:
  - `OfficeExterior parts=<n≤4500> lights=<n≤70> keepoutHits=0 truckClones=0`;
  - the truck pad's centre, within 0.5 of (1168, -276).
- [ ] **Step 3: Commit** the builder and README (scripts only; the place holds the art).
  `Office exterior: the approved spike becomes the place's exterior set`

### Task 8: Studio verification and measurements

**Files:**
- Create: `reports/office-stage3-outside.md`
- Modify: `HANDOFF-office-map-2026-10-23.md` (status line and Studio state)

**Probes** (Server in Play, a generated layout at the office origin; lock protocol):
- **P1:** suite all pass; traversal seeds 1-20, doors closed: 0 failures.
- **P2 (Review Focus 2):** `PathfindingService:CreatePath` with Harlow's agent parameters and `Costs` from
  `OccupantServiceServer`, computed from the bay's patrol point:
  - to the truck pad centre → status not `Success`, or a path whose waypoints never enter an Outdoors volume;
  - to a point 3 studs into the yard in front of the dock → the same.
- **P3:**
  - the crew's spawn CFrame sits on the yard truck bed and faces +Z;
  - from a spawn, a pathfinding walk to the dock exit (doorways open) measures 190-215 studs;
  - dock exit → lobby exit outside measures 420-470 studs;
  - report both in studs and in seconds at 16 studs/s.
- **P4:**
  - `whereIs` on the yard returns "Yard", and on the car park "Car park";
  - clock-out "aboard" is true on the bed and false 3 studs off it.
- **P5:** force `OfficeOozeRules.level` inputs 900 / 1100 / 1400 by building the ooze directly at the dock exit:
  0 / small / large spills, all on the yard side.
- **P6 (client):** with the camera in the yard the atmosphere state's preset is `officeExterior`; in the bay it is
  today's interior preset; crossing the threshold 10 times in 3 s switches at most 4 times.
- **P7:** captures of
  - arrival on the truck looking at the building;
  - the walk;
  - the dock opening with the bay behind it (no void);
  - the lobby from outside and from the reception;
  - the ooze at "lot";

  saved in `design/production-art/map-kits/odd-hours-b1/exterior/captures/`.

- [ ] **Step 1:** Run P1-P7 and record each result, with its numbers, in `reports/office-stage3-outside.md`.
- [ ] **Step 2: Banking walk note for the owner.**
  - The truck → dock walk (P3) adds about 2 × 12.5 s per banking trip.
  - State the trips per shift observed in the stage-1 measure, or assume 6 trips, as the time cost.
  - Do **not** retune the quota or the shift length. The owner decides after the play-check (handoff next step 2).
- [ ] **Step 3:** Update the handoff's status line and Studio state:
  - `OfficeExterior` replaces the spike;
  - the owner saves the place;
  - `RunTests` is cleared.
- [ ] **Step 4: Commit.** `Office stage 3: outside verified in Studio, walk and banking measures`
- [ ] **Step 5:** Owner play-check. Done only after the owner passes it.
