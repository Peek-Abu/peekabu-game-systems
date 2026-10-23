# Odd Hours office map, stage 3: the outside, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The crew arrives and banks at a truck parked out in a fixed, hand-built night yard. They enter the generated
office Lethal Company style: interact with the dock door or the lobby door, a quick fade, and they appear at a fixed
spot inside (the dock room or the reception). Exit doors inside take them back out to the door they came in by.

**Architecture:**
- **The outside and the inside are separate places in the world.** The exterior set (place-owned art,
  `Workspace.OfficeExterior`) sits `EXTERIOR_OFFSET` away from the generated office, and nothing visual connects them.
- **Layout:** the layout carries the outside in layout space:
  - **grounds:** the yard and the car park;
  - **the truck:** on the yard pad;
  - **two entrances:** an outside door frame paired with an inside exit door on the dock room's or the reception's
    wall.
- **Teleport:** a new server system teleports a player between the pair on an interact, behind a short client fade.
- **Mr. Harlow** never follows. The outside is also added to his safe zone, as a guard.
- **Atmosphere:** the client blends to a brighter exterior preset while its camera is in the outdoor volumes.

**Tech Stack:** Roblox Luau (`--!strict`), TestEZ specs (Studio Play with `RunTests`), Studio MCP for the art task and
the Studio verification.

**Spec:** `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md` (goals 1-3, non-goals, anti-goals,
"Entrances", "Exterior previews use what exists"). It is amended by these owner decisions of 2026-10-23, which win over
the spec where they differ:
- **Entering is a teleport (like Lethal).** Interact, fade, appear at a fixed spot inside; the same spot every time on
  a shift. The outside visual is unrelated to the inside.
- **Two entrances to two places.** The dock door (main, by the truck) leads to the dock room. The lobby door (west
  face, round the corner, about 28 s outside) leads to the reception. Leaving by an inside exit returns you to that
  entrance's outside door.
- **The truck parks out in the yard.** Chosen 200 studs from the dock door (`TRUCK_WALK_STUDS` in the exterior
  builder), about 12.5 s at 16 studs/s.
- **The outside gets a brighter night;** the interior keeps its approved look.
- **The look is the round-2 spike:** `design/production-art/map-kits/odd-hours-b1/exterior-spike/REPORT.md` and its
  captures. Its world numbers, shifted by `EXTERIOR_OFFSET`, are this plan's outside geometry.
- **Deferred:** the anomaly pool stays in stage 4, and the first-minutes ideas are parked in
  `docs/superpowers/launch-backlog.md`.

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
- Server-authoritative: a teleport happens only on the server, after it checks that the player is in the running shift
  and within `ENTRANCE_REACH` of the door they used.
- **Keep everything stages 1-2 built:** doors, Harlow's door beat, depth by walk distance from the bay, hide spots ≥ 8,
  and walk ≤ 640 studs from the bay.

## Review Focus

1. **Carrying loot through a door.** A player holding or dragging loot keeps it across the teleport. It arrives with
   them and is never left behind, dropped through the floor, or duplicated. → Task 4, spec on the carried object's
   position after `teleport`, plus probe P4.
2. **Spamming the interact, or two players using one door at once.** Each request teleports its own player exactly
   once. A second request during that player's fade is ignored. → Task 4, spec "a request while a teleport is pending
   is refused".
3. **Mr. Harlow at an exit when a player leaves mid-chase.** He loses them, does not teleport, and hunts from the door
   (spec chase rule). → Task 5 spec (outside is safe) and probe P2.
4. **The authored boot layout, which has no grounds or entrances.** Everything behaves exactly as today: the truck in
   the bay, no doors to the outside, no exterior preset. → Tasks 1, 2, 3 and 6 each carry a "grounds nil" spec.
5. **Clock-out and banking with the truck turned 180°.** The time clock, overtime sheet, bed prompt and arrival facing
   follow the truck's yaw, and "aboard" (the truck box) still holds. → Task 1 specs on `arrivalFrame` / `truckBox`
   with yaw π, and probe P5.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Utils | `OfficeGroundsUtils` | The outside in layout space: the yard and car-park boxes, the truck on its pad, the two entrances' outside frames and their inside exits. |
| Office | server | Systems | `OfficeGroundsSystem` | Builds the outside's code parts into the office model: the Outdoors safe volumes, the outside door hit boxes and the inside exit doors. |
| Office | server | Systems | `OfficeEntranceSystem` | Teleports a player between an entrance's outside door and inside exit on an interact, with the fade. |
| Office | server | Rules | `OfficeOozeRules` | How much Gloom ooze shows at the dock for a site's Gloom total. |
| Office | server | Systems | `OfficeOozeSystem` | Builds the ooze spill under the outside dock door. |

The client's outdoor test goes into the existing `OfficeAtmosphereUtils`. The client fade reuses an existing UI fade if
one exists (`Primitives/FadeGroup` or the transit's load screen). Otherwise it lives in the existing Shift client
feature; add a row here before writing it.

---

### Task 1: Grounds, the yard truck and the entrances (data + pure geometry)

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeGroundsUtils.luau` and its spec
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.luau` and its spec

**Interfaces:**
- **Types:**
  - `Layout` gains `grounds: { Room }?` (outdoor boxes, never built as rooms; ids `"yard"` and `"carpark"`) and
    `entrances: { Entrance }?`.
  - `export type EntranceId = "dock" | "lobby"`.
  - `export type Entrance` has these fields:
    - `id: EntranceId`
    - `ground: string`
    - `outside: { x: number, z: number, yaw: number }`: the outside door's centre on the floor. The yaw faces away
      from the building, which is where a player arriving outside looks.
    - `exit: Door`: an inside doorway on room `exit.a`'s outer wall, with `exit.b` = the entrance id and `kind` =
      `"solid"` (dock) or `"glass"` (lobby).
  - `Truck` gains `yaw: number?`: radians about +Y. nil or 0 is today's truck (cab toward +Z, ramp toward -Z); `math.pi`
    puts the cab toward -Z and the ramp toward +Z.
- **Constants:** `OfficeConstants.OUTSIDE`, frozen, exactly as below. Layout space, z already shifted by
  `EXTERIOR_OFFSET`, from the spike's world numbers minus `ORIGIN` (1000, 1, 0) plus (0, 0, -1600).

  | Key | Value | Notes |
  |---|---|---|
  | `EXTERIOR_OFFSET` | `Vector3.new(0, 0, -1600)` | The world shift applied to the whole spike set. |
  | `yard` | `{ minX = -164, maxX = 322, minZ = -1921, maxZ = -1657 }` | Name `"Yard"`. |
  | `carpark` | `{ minX = -164, maxX = -44, minZ = -1657, maxZ = -1370 }` | Name `"Car park"`. |
  | `TRUCK_CENTRE` | `Vector2.new(168, -1876)` | |
  | `TRUCK_YAW` | `math.pi` | |
  | `DOCK_OUTSIDE` | `{ x = 168, z = -1664, yaw = 0 }` | The roller door on the dock block's front face; you arrive facing -Z, toward the truck. |
  | `LOBBY_OUTSIDE` | `{ x = -62, z = -1448, yaw = math.pi / 2 }` | The rotunda's doors; you arrive facing -X, out to the car park. |
  | `OUTSIDE_STEP` | `5` | How far in front of the outside door a player arrives. |
  | `INSIDE_STEP` | `4` | How far into the room from the exit a player arrives. |
  | `ENTRANCE_REACH` | `10` | |
  | `DOCK_EXIT_WIDTH` | `8` | |
  | `VOLUME_HEIGHT` | `120` | |
- **Functions** (`OfficeGroundsUtils`):
  - `grounds(): { Room }`: the yard and the car park, in that order.
  - `truck(): Truck`: `BED_SIZE` footprint centred on `TRUCK_CENTRE`, with `yaw = TRUCK_YAW`. The clock is at
    `CLOCK_SIDE` / `CLOCK_BACK`, rotated by the yaw.
  - `dockEntrance(bay: Room): Entrance`: exit on the bay's minZ wall at the bay's centre x, width `DOCK_EXIT_WIDTH`,
    kind `"solid"`.
  - `lobbyEntrance(reception: Room, z: number, width: number): Entrance`: exit on the reception's minX wall, kind
    `"glass"`.
  - `outsideFrame(entrance: Entrance): CFrame`: layout space, `OUTSIDE_STEP` out from the outside door along its yaw,
    at floor height, facing that yaw.
  - `insideFrame(entrance: Entrance, room: Room): CFrame`: `INSIDE_STEP` into `room` from the exit's centre,
    perpendicular to its wall, facing into the room.
  - `groundAt(grounds: { Room }, x: number, z: number): Room?`.
- **`OfficeLoadingBayUtils`:**
  - `arrivals`, `arrivalFrame` and `truckBox` honour `truck.yaw`.
  - Arrival offsets rotate about the bed centre. The facing is "out of the open back": -Z at yaw 0, +Z at yaw π.
  - `truckBox` stays the bed footprint up to `TOP`; a 180° turn leaves the box unchanged.

- [ ] **Step 1: Write the failing specs.** `OfficeGroundsUtils.spec.luau`:
  - **`grounds()`:** ids `{"yard","carpark"}`, the exact boxes above, touching at z -1657 without overlapping.
  - **`truck()`:** centre (168, -1876), the `BED_SIZE` footprint, `yaw == math.pi`; the truck lies inside `yard`.
  - **Dock entrance:** `dockEntrance({id="bay",minX=146,maxX=190,minZ=-52,maxZ=-10})` has `exit` = `{a="bay",
    b="dock", x=168, z=-52, width=8, kind="solid"}`, ground `"yard"`, and the outside frame from `DOCK_OUTSIDE`.
  - **Lobby entrance:** `lobbyEntrance({id="reception1",minX=-38,maxX=-10,minZ=138,maxZ=166}, 152, 12)` has `exit` =
    `{a="reception1", b="lobby", x=-38, z=152, width=12, kind="glass"}`, ground `"carpark"`.
  - **`insideFrame`:**
    - for the dock: Position ≈ (168, 0, -48), LookVector ≈ (0, 0, 1);
    - for the lobby: Position ≈ (-34, 0, 152), LookVector ≈ (1, 0, 0).
  - **`outsideFrame`:** for the dock, Position ≈ (168, 0, -1669) and LookVector ≈ (0, 0, -1). The point lies inside
    `yard`.
  - **`groundAt`:** (168, -1800) → yard; (-100, -1450) → carpark; (168, -30) → nil.

  `OfficeLoadingBayUtils.spec.luau` adds:
  - `arrivalFrame({...truck, yaw=math.pi}, 1).LookVector` ≈ (0, 0, 1);
  - with yaw nil it is ≈ (0, 0, -1), as today;
  - the yaw-π arrival points are the yaw-0 points rotated 180° about the bed centre;
  - **Review Focus 5:** `truckBox` with yaw π equals `truckBox` with yaw nil.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement** the types, constants, `OfficeGroundsUtils` and the yaw handling (rotate with
  `CFrame.Angles(0, yaw, 0)` about the bed centre).
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office grounds: the yard and car park, the truck turned on its pad, two teleport entrances`

### Task 2: The generator uses the outside

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutGenerationUtils.luau` (bay/truck block about
  566-650; entrance facade at 618) and its spec
- Modify: `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau` (truck-in-start-room 223-240, spawn
  check 290) and its spec

**Interfaces:**
- Consumes: Task 1's `grounds()`, `truck()`, `dockEntrance`, `lobbyEntrance`, `groundAt`.
- Produces, for a generated layout:
  - `layout.grounds = grounds()`
  - `layout.truck = truck()`
  - `layout.entrances = { dockEntrance(bay), lobbyEntrance(reception, <today's entrance facade z>, ENTRANCE_WIDTH) }`
  - spawn markers `yard.spawn.N` (room `"yard"`) at `arrivals(layout.truck)`, replacing `bay.spawn.N`
  - no `"entrance"` facade
  - `startRoom` stays `"bay"`, so depths and the walk cap are still measured from the dock room.
  - The bay keeps its door to the dock junction, its patrol point and its vinyl. It gains 2 `shelf` markers, one
    centred against each x wall, `MARKER_MARGIN` in.
- `OfficeLayoutRules.validate` changes when `grounds` is set:
  - the truck lies inside a ground;
  - each entrance's exit sits on its room's outer wall within the wall's span;
  - each entrance's outside door lies on (or within 1 stud of) its ground;
  - no ground overlaps a room;
  - `spawn` markers may name a ground id.
- When `grounds` is nil, every rule is exactly today's.

- [ ] **Step 1: Write the failing specs.**
  - **Generation spec, over seeds 1-200** (pcall each; every generated layout):
    - `#layout.grounds == 2`, and the truck has `yaw == math.pi` and lies inside `yard`;
    - `layout.entrances` holds `dock` (exit `a="bay"`, x 168, z -52) and `lobby` (exit `a="reception1"` on x -38,
      138 < z < 166);
    - no facade has kind `"entrance"`, and every `spawn` marker has room `"yard"`;
    - no room overlaps a ground, and `startRoom == "bay"`;
    - the bay's depth is 0, and no room's depth changed versus a fixture of seed 7's depths captured before this
      task.
  - **Rules spec:**
    - with grounds set and the truck in the bay → an error ("truck must stand on a ground");
    - an exit off its room's wall → an error;
    - a ground overlapping a room → an error;
    - **Review Focus 4:** the authored `OfficeLayoutConstants.LAYOUT` (no grounds) validates with 0 errors.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
  - First grep every consumer of `kind == "spawn"` and of `OfficeLayoutUtils.room(layout, marker.room)`: a marker
    naming a ground must not crash or mislead any of them.
  - `OfficeLayoutGenerationUtils` is already over the line limit, so put new code in `OfficeGroundsUtils` and leave
    only call sites in the generator.
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass, including every existing generation spec. Clear
  `RunTests`.
- [ ] **Step 5: Commit.** `Office generator: the truck parks in the yard, the dock room and reception get exits`

### Task 3: Building the outside's code parts and the turned truck

**Files:**
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeGroundsSystem.luau` and its spec
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau` (truck folder 141-170; one call to
  `OfficeGroundsSystem.build`) and its spec
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau` (`whereIs` about 528, new `outdoors`,
  new `entrance`)

**Interfaces:**
- Consumes: Task 1 types and functions, and the yaw-aware `OfficeLoadingBayUtils`.
- **The truck bed** is built at `origin * CFrame.new(centre) * CFrame.Angles(0, truck.yaw or 0, 0)`.
  `TruckVisual.build`, `TruckVisual.paperwork`, the TimeClock and the OvertimeSheet follow the bed's CFrame unchanged;
  they are already bed-relative.
- **`OfficeGroundsSystem.build(layout, origin, parent): { exits: { [EntranceId]: BasePart }, doors: { [EntranceId]: BasePart } }`.**
  When `layout.grounds` is nil it builds nothing and returns empty maps. Otherwise it builds three things.
  - **Outdoors volumes:** folder `Outdoors`, one part per ground named by its id.
    - The ground's box from y 0 to `VOLUME_HEIGHT`.
    - `Transparency=1`, `CanCollide=false`, `CanTouch=false`, `CanQuery=true`, `CastShadow=false`.
    - A child `PathfindingModifier` with Label `OccupantConstants.SAFE_ZONE_LABEL` and `PassThrough=false`.
  - **Outside door hit boxes:** folder `Entrances`, one invisible part per entrance at its outside door.
    - 8 wide, 10 tall, 1 deep.
    - `CanCollide=false`, `CanQuery=true`.
    - Interactable with a new kind `OfficeConstants.ENTER_KIND = "OfficeEnter"`, using the same attribute pattern as
      `OfficeBuildSystem`'s `interactable`, with attribute `EntranceId`.
  - **Inside exit doors:** each entrance's `exit` is a closed, non-swinging door in its room's wall.
    - The wall is cut and cased like a facade (`OfficeDoorSystem`'s facade path), so trim breaks at it as at
      facades.
    - The leaf is solid (dock) or double glass (lobby).
    - It gets an EXIT sign above it, using the existing exit-sign decor.
    - It is interactable with `OfficeConstants.LEAVE_KIND = "OfficeLeave"` and the `EntranceId` attribute.
- **`OfficeServiceServer`:**
  - `outdoors(): { { min: Vector3, max: Vector3 } }`: the grounds' world boxes, y 0 to `VOLUME_HEIGHT`, or `{}`.
  - `entrance(id: EntranceId): (CFrame?, CFrame?)`: the world outside frame and the world inside frame (via
    `insideFrame` with the exit's room), or nil when the layout has no such entrance.
  - `whereIs(position)`: unchanged inside rooms; on a ground it returns `ground.name, 0, nil`.
  - `safeZone()` stays the truck box. Clock-out "aboard" keeps meaning "in the truck".

- [ ] **Step 1: Write the failing specs.**
  - `OfficeGroundsSystem.spec`, on a generated layout (seed 3) built at a test origin:
    - `Outdoors` holds `yard` and `carpark`, each with a SafeZone-labelled modifier, `CanQuery == true` and
      `CanCollide == false`;
    - `Entrances` holds 2 parts with `EntranceId` `dock` and `lobby`, at the outside door positions;
    - the bay's south wall has a closed door part interactable as `OfficeLeave` with `EntranceId == "dock"`, and no
      wall or trim part crosses its leaf (the same check as the facade specs);
    - likewise the reception's west wall (`lobby`, glass).
    - **Review Focus 4:** building the authored `LAYOUT` returns empty maps and creates no `Outdoors` or `Entrances`.
  - `OfficeBuildSystem.spec`:
    - seed 3's `TruckBed.CFrame.LookVector` ≈ (0, 0, 1) and its position is the truck centre;
    - the TimeClock's CFrame equals `TruckVisual.paperwork(bed, "clock")`;
    - the authored `LAYOUT`'s bed is at yaw 0, as today.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.** Reuse `OfficeDoorSystem`'s facade casing and the decor's exit sign rather than writing
  new ones. If they are local functions, expose the smallest helper needed, with a spec.
- [ ] **Step 4: Run the suite, then the traversal harness** (seeds 1-20, `CFrame.new(5000,1,5000)`, from the Server
  in Play). Expected: suite all pass; traversal 0 failures. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office build: the truck in the yard, outdoor safe volumes, entrance doors and exits`

### Task 4: Entering and leaving the building (teleport + fade)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeEntranceSystem.luau` and its spec
- Modify: the server interact dispatch for `ENTER_KIND` / `LEAVE_KIND`. Mirror how `CLOCK_OUT_KIND` reaches
  `ShiftTimeClockSystem` and how the client's `ShiftPromptSystem` shows prompts for interactable kinds.
- Modify (client): the prompt labels `"Enter"` / `"Leave"`, and the fade. Reuse an existing fade (see New modules).

**Interfaces:**
- Consumes: `OfficeServiceServer:entrance(id)`, the parts from `OfficeGroundsSystem.build`, and the shift's
  running-crew check (as the clock-out uses it).
- **`OfficeEntranceSystem.request(player, kind, entranceId, now): boolean`.** Refused (false, nothing happens) when:
  - the player is not in the running shift's crew;
  - they are dead or caught;
  - their root is farther than `ENTRANCE_REACH` from the part they used;
  - a teleport is already pending for them (Review Focus 2).

  Otherwise it marks them pending and tells their client to fade out, then after `FADE_OUT` (0.2 s) does the
  following:
  1. `RequestStreamAroundAsync` the target.
  2. Moves the character to the target frame, plus `SPAWN_HEIGHT` up: `ENTER_KIND` → the inside frame,
     `LEAVE_KIND` → the outside frame.
  3. Tells the client to fade in over `FADE_IN` (0.3 s).
  4. Clears the pending flag.
- **What travels with the player:** anything they carry. Verify how Carry holds an object (welded to the character,
  or moved by `CarryPlacementSystem`). If it is not welded, move it by the same delta in the same step.
- **Pure helpers on the system for the spec:**
  - `OfficeEntranceSystem.target(kind, outsideFrame, insideFrame): CFrame`;
  - `OfficeEntranceSystem.allowed(state): boolean`, with `state = { inCrew, alive, distance, pending }`.

- [ ] **Step 1: Write the failing specs.**
  - `target("OfficeEnter", o, i) == i` and `target("OfficeLeave", o, i) == o`.
  - `allowed`:
    - `{inCrew=true, alive=true, distance=4, pending=false}` → true;
    - each of `inCrew=false`, `alive=false`, `distance=10.5`, `pending=true` → false.
  - **Review Focus 1 (carried object):** with a stub character and a carried part held the way Carry holds it, after
    `teleport(character, target)` the part's offset from the character's root is unchanged (within 0.05).
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office entrances: interact to enter or leave, a quick fade, the same spot every time`

### Task 5: Mr. Harlow treats the outside as the safe zone

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau` (`Zone` at about 97)
- Modify: `src/ServerScriptService/Features/Occupant/Utils/OccupantMindUtils.luau` (`inZone` at 126) and
  `OccupantSightUtils.luau` (its local `inZone` at 37), plus specs
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantSenseSystem.luau` (`System.layout` at about 110)

**Interfaces:**
- Consumes: `OfficeServiceServer:outdoors()` (Task 3).
- **`OccupantTypes.Zone`** gains `more: { Zone }?`. `inZone(point, zone)` is true when the point is in the box **or**
  in any `more` box.
- **One definition:** `OccupantSightUtils` uses `OccupantMindUtils.inZone` instead of its own copy.
- **`System.layout`** sets `zone = { min, max, more = <outdoors boxes> }`.
- **Effect:** every existing consumer of `senses.zone` (sight, noise, catch, goal candidates, turn rules) ignores
  players outside. `senses.bay` is unchanged. The outside is also unreachable on the navmesh, being separate ground;
  this zone is the guard for sight and noise.

- [ ] **Step 1: Write the failing specs.**
  - `OccupantMindUtils.spec`: `inZone` is true for a point in a `more` box and outside the main box; with `more = nil`
    the behaviour is unchanged.
  - `OccupantBrainRules.spec` / `OccupantCatchRules.spec` (Review Focus 3), mirroring the existing truck-zone cases:
    - a glimpse of a player inside a `more` box is ignored;
    - a noise there is ignored;
    - a catch there is refused.
  - `OccupantSightUtils.spec`: the existing truck-zone case still passes through the shared `inZone`.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Harlow: the yard and car park are safe ground; one inZone for all his senses`

### Task 6: The outside's atmosphere

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Vfx/Data/VfxTypes.luau` (`Atmosphere` / `AtmosphereValues` at 84-105)
- Modify: `src/ReplicatedStorage/Client/Features/Vfx/VfxServiceClient.luau` (`readLighting` 63, `writeLighting` 76) and
  `VfxFormulas.blendAtmosphere`, plus specs
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

  The atmosphere fields read and write Lighting's first `Atmosphere` child (when none exists they are carried but not
  written). `moonAngularSize` reads and writes the first `Sky` child (likewise). A preset that omits a field takes
  the place's base value captured at start, as the existing fields already do, so every existing preset keeps today's
  look. Numbers blend linearly and colours lerp.
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

    Fog takes the base value.
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
  - `OfficeAtmosphereUtils.hum(snapshot, userId, outside: boolean?)`: false outside.
  - `OfficeAtmosphereUtils.outdoors(point: Vector3, boxes: { { min: Vector3, max: Vector3 } }): boolean`: true inside
    any box.
- **System:** `OfficeAtmosphereSystem` polls every `OUTDOOR_POLL` (= 0.25 s) in a shift.
  - It reads the boxes from `Workspace.CleanupCrewOffice.Outdoors` parts (`CFrame.Position ± Size/2`).
  - It tests the camera position, and on a change re-applies the preset. The teleport fade hides the switch, so use a
    short blend (`OUTDOOR_FADE` = 0.3 s).
  - It exposes `OfficeAtmosphereSystem.expected(): string`.
- **Transit:** `ShiftTransitSystem.lit()` compares against `OfficeAtmosphereSystem.expected()`, so arriving at the
  truck in the yard counts as lit.

- [ ] **Step 1: Write the failing specs.**
  - `OfficeAtmosphereUtils.spec`:
    - `preset(running, uid, true) == "officeExterior"`;
    - in overtime → `"officeExteriorOvertime"`;
    - tier 2 and outside → `"officeExterior"`;
    - outside nil or false → every existing case unchanged;
    - **Review Focus 4:** hub plus outside → depot `EVENING`;
    - `hum(running, uid, true) == false`;
    - `outdoors` is true inside a box and false outside all boxes.
  - `VfxFormulas.spec`:
    - blending different `geographicLatitude` / `atmosphereColor` at alpha 0.5 gives the midpoint;
    - a preset without the new fields resolves to the base values.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office atmosphere: a brighter moonlit night outside`

### Task 7: Gloom ooze under the dock door (the dirty-shift preview)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeOozeRules.luau` and its spec
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeOozeSystem.luau` and its spec
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau` (after `lastPlan = plan`, about 405;
  cleared with the plan, about 466)

**Interfaces:**
- `OfficeOozeRules.level(gloom: number): "none" | "little" | "lot"`:
  - `< 985` → none;
  - `< 1240` → little;
  - else lot.
  - These are the thirds of the spec's 730-1495 site range.
- `OfficeOozeSystem.build(level, doorFrame: CFrame, width: number, parent: Instance): Model?`:
  - nil for `"none"`.
  - Otherwise a flat goo spill seeping out under the outside dock door. `doorFrame` sits at the door's centre on the
    ground, LookVector pointing away from the building.
  - Non-colliding, `CanQuery=false`, `CastShadow=false`. It uses the Gloom pile's existing goo look: reuse the pile
    visual's material and colour constants, found where Gloom piles are drawn.
  - `"little"`: 2 puddles reaching at most 4 studs out.
  - `"lot"`: a spill as wide as the door, reaching 10 studs out, plus 3 thin streaks on the door's lower edge.
- **The site's Gloom:** the sum of the rolled piles' Gloom, the figure the economy tunes on (730-1495).
  `OfficeServiceServer` builds the ooze into the office model right after `lastPlan = plan`, at the `dock` entrance's
  outside door, with width = the roller door's (14).

- [ ] **Step 1: Write the failing specs.**
  - `level(0)`, `level(984)` → `"none"`; `level(985)`, `level(1239)` → `"little"`; `level(1240)` → `"lot"`.
  - `build("none", …)` returns nil.
  - `build("lot", CFrame.lookAt(Vector3.zero, -Vector3.zAxis), 14, folder)`:
    - every part's centre has z ≤ 0 (the yard side) and |x| ≤ 8;
    - every part has `CanCollide == false` and `CanQuery == false`.
  - `build("little", …)`: at most 2 floor parts, all within 4 studs of the door.
- [ ] **Step 2: Run the suite in Studio Play.** Expected: the new specs FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite in Studio Play.** Expected: all pass. Clear `RunTests`.
- [ ] **Step 5: Commit.** `Office: Gloom ooze under the dock door shows how dirty the shift is`

### Task 8: Promote the spike to the real exterior set (Studio art, no Rojo)

**Files:**
- Create: `design/production-art/map-kits/odd-hours-b1/exterior/BuildExterior.CommandBar.luau`, from the spike's
  `exterior-spike/BuildExteriorSpike.CommandBar.luau`
- Create: `design/production-art/map-kits/odd-hours-b1/exterior/README.md` (one screen: what it builds, the numbers it
  shares with `OfficeConstants.OUTSIDE`, how to rebuild)

**Interfaces:**
- Consumes: `OfficeConstants.OUTSIDE` (Task 1). The builder copies these numbers at its top, with a comment naming the
  constant.
- Produces: `Workspace.OfficeExterior`, replacing `Workspace.ClaudeExteriorSpike`.
  - **Placement:** the spike set shifted by `EXTERIOR_OFFSET` (0, 0, -1600). The keep-out check is dropped; the set
    now stands alone.
  - **Truck:** no truck clone; the code builds the truck. The truck pad stays, centred on `TRUCK_CENTRE` (world 1168,
    -1876).
  - **The podium is closed:** no openings into its empty inside.
    - **Dock:** the roller door is rolled **down** (closed), with a strip of warm light spilling under it; the ooze
      seeps out from there.
    - **Lobby:** the rotunda's doors are closed glass with the lit lobby dressing visible behind them. That dressing is
      exterior art, not the generated reception.
    - **Alignment:** the doors' centres sit at `DOCK_OUTSIDE` / `LOBBY_OUTSIDE` (world (1168, -1664) and
      (938, -1448)), so the code's hit boxes line up with the art.
  - **Name:** the model is never named `CleanupCrewOffice`.
  - **Parts:** ≤ 4,500 parts and ≤ 70 lights.

- [ ] **Step 1:** Check the playtest lock. In Edit, run the builder: it clears and rebuilds `Workspace.OfficeExterior`
  and deletes `Workspace.ClaudeExteriorSpike`, as one ChangeHistory step.
- [ ] **Step 2: Verify with an Edit probe.** It must print:
  - `OfficeExterior parts=<n≤4500> lights=<n≤70> truckClones=0 openings=0`;
  - the truck pad's centre and the two door centres, each within 0.5 of the constants.
- [ ] **Step 3: Commit** the builder and README (scripts only; the art lives in the place).
  `Office exterior: the approved spike becomes the place's exterior set, apart from the office`

### Task 9: Studio verification and measurements

**Files:**
- Create: `reports/office-stage3-outside.md`
- Modify: `HANDOFF-office-map-2026-10-23.md` (status line and Studio state)

**Probes** (Server/Client in Play, a generated layout at the office origin; lock protocol):
- **P1:** suite all pass; traversal seeds 1-20, doors closed: 0 failures.
- **P2 (Review Focus 3):** `PathfindingService:CreatePath` with Harlow's agent parameters and `Costs`, from the bay's
  patrol point to the truck pad centre → status is not `Success`. A player standing in the yard is `inZone` for him.
- **P3:** the crew's spawn CFrame is on the yard truck bed, facing +Z. From a spawn, a pathfinding walk to the dock
  door hit box measures 190-215 studs, and dock door → lobby door outside measures 420-470. Report both in studs and
  in seconds at 16 studs/s.
- **P4 (Review Focus 1 and 2):**
  - interact Enter at the dock → the player lands at the inside frame;
  - Leave → back at the dock's outside frame;
  - the same for the lobby;
  - a carried item arrives with the player;
  - 5 rapid Enter requests → exactly 1 teleport.
- **P5 (Review Focus 5):** `whereIs` on the yard → "Yard"; clock-out "aboard" is true on the bed and false 3 studs off
  it; the TimeClock prompt works.
- **P6:** force Gloom 900 / 1100 / 1400 and build the ooze → no, small and large spills under the dock door.
- **P7 (client):** in the yard the atmosphere preset is `officeExterior`; after Enter it is the interior preset; after
  Leave it is exterior again.
- **P8:** captures of
  - arrival on the truck looking at the building;
  - the walk;
  - the dock door with ooze at "lot";
  - the lobby;
  - the inside of the dock room and the reception with their exit doors;

  saved in `design/production-art/map-kits/odd-hours-b1/exterior/captures/`.

- [ ] **Step 1:** Run P1-P8 and record each result, with its numbers, in `reports/office-stage3-outside.md`.
- [ ] **Step 2: Banking walk note for the owner.**
  - The truck → dock walk (P3) adds about 2 × 12.5 s per banking trip.
  - Give the time cost for 6 trips per shift, or the trip count measured in stage 1 if one exists.
  - Do **not** retune the quota or the shift length. The owner decides after the play-check.
- [ ] **Step 3:** Update the handoff's status line and Studio state:
  - `OfficeExterior` replaces the spike, at the new offset;
  - the owner saves the place;
  - `RunTests` is cleared.
- [ ] **Step 4: Commit.** `Office stage 3: outside verified in Studio, walk and banking measures`
- [ ] **Step 5:** Owner play-check. Done only after the owner passes it.
