# Week 1: Office Map Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Builders can hand-build the Office in Studio and tag its gameplay points, and the code runs a full shift off those tags. A first playable hallway Office is built that way, falling back to today's generated office whenever no valid tagged map is present.

**Architecture:** A **tag contract** (CollectionService tags plus attributes, `OfficeMapConstants`) describes every gameplay point the generator supplies today. A pure pipeline turns a tagged map into the existing `OfficeTypes.Layout`. `OfficeMapScanUtils` reads the instances into plain data (`MapScan`), `OfficeMapRules` validates it (errors block use, research-rule misses are warnings), and `OfficeMapLayoutUtils` converts it. So the spawn roll, layout rules, depths, `whereIs`, the route and the truck all keep working unchanged. `OfficeMapSystem` adopts the map: it writes the code-owned tags and attributes (search, hide, marker ids, chair to desk) onto the builder's furniture and builds the Depot-matching truck at the dock. `OfficeServiceServer` serves its unchanged public API from whichever source loaded. The map is then laid out (validated as data before anyone builds), blocked out in Studio from that data, dressed with a Blender kit, lit per the research report's LT rules, and playtested.

**Tech Stack:** Luau `--!strict`, Rojo (code only), TestEZ in Studio, CollectionService, the Office / Hide / Occupant / Cargo / Vacuum / Shift features, Roblox Studio MCP, Blender MCP, `publishing-roblox-assets`.

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` §7 "Office map rework" (and §1 for the places split). The research reference is `E:/Projects/peekabu-game-systems/reports/Odd Hours map design research.md`. Rule IDs L*, W*, R*, K*, P* and LT* below are that report's.

**Branch:** `game/cleanup-crew` (worktree `.claude/worktrees/mvp-demo-pack-052599`). Never merges into base.

**Depends on:** `docs/superpowers/plans/2026-10-18-week1-places-split.md` (written in parallel). That plan gates `OfficeServiceServer.start` to the shift role (`QueueServiceServer:runsRole("shift")`). Task 7 here also edits `start`. Whichever lands second rebases onto the other: the role gate wraps everything `start` does, the map/generator choice included. Nothing else here waits on the split. The Studio build (Tasks 9–11) happens in the current place until the Shift place exists (see the Studio rule below).

## Approval needed

- **Module placement: none.** Every new module uses an existing subfolder kind (Data, Rules, Utils, Systems, Testing) and role word (Constants, Rules, Utils, System, Harness). There is no second service and no new feature.
- **Owner gates (stop and wait for an explicit yes in chat):**
  1. **Layout plan** (Task 5, Step 6). The top-down plan, before any Studio building.
  2. **Shift place window** (Tasks 9–11). Only the "Odd Hours (placeId: 113354563835664)" Studio window is used until the owner has created the Shift place. Moving the build into the Shift place's window needs the owner's approval first.
  3. **Kit look** (Task 9, Step 5). One fully finished kit piece (K8) before any variants. Layout and look are approved separately.
  4. **Asset uploads** (Task 9, Step 6). Each upload batch is listed (file, kind, size) and confirmed before `publish.py` runs. Assets go to group 189923277 only.
  5. **Full-shift playtest sign-off** (Task 11). Then the board item moves to **review**, never Done.

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`. No `::` casts (none are planned).
- Spec-first: each `.spec.luau` is written and seen failing before its module. New Data modules get a `SpecRoots.EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`).
- Placement follows the New modules table below and `docs/project-structure.md`. A folder required 3+ times in a file gets an `OfficeServer` variable (the existing convention). Each module stays ≤ 400 code lines (`scripts/python/check_file_length.py`).
- **Public API of `OfficeServiceServer` is frozen:** the `OfficeServiceServer` export type keeps every field name and signature. Consumers (Occupant, Shift, Cargo, Vacuum, Hide) get no edits.
- **Workspace is not mounted by Rojo.** The hand-built map lives in the place. Code never creates or deletes the builder's parts. It only adds tags and attributes to them (and removes exactly what it added), plus a child folder of its own.
- **Studio rule:** Studio MCP only in the "Odd Hours (placeId: 113354563835664)" window, until the Shift place exists. After that, the Shift place window is used only once the owner approves it. No computer-use. Respect the playtest lock. Never run installs, `rojo build`, `wally` or `scripts/check.sh` while the owner is connected.
- **Tests (Studio only):** set Workspace attribute `RunTests = true`, press Play, read Output. Expect `0 failed` and a passed count ≥ the last count plus the task's new `it`s (last count **3828**). Then Stop and set `RunTests = false` (a test session is never a play session).
- **Lint/format changed files only:** `selene <files>` then `stylua <files>` then `stylua --check <files>`. After adding modules, run `python3 scripts/python/module_map.py --write` (stage `docs/project-structure.md`) and `python3 scripts/python/check_file_length.py`, adding no new failures for touched files.
- **Commits:** plain messages exactly as given. **No `Co-Authored-By:` or `Claude-Session:` trailers.**
- Research numbers are starting values (`[I]` in the report). They live in `OfficeMapConstants` and fail as **warnings** with the rule ID, never as errors. Errors are reserved for maps the code cannot run.
- Asset naming: `OH_<Kit>_<Piece>_<Size>_<Var>` (K7). Uploads only via `python "C:/Users/Bruk Abu/.claude/skills/publishing-roblox-assets/publish.py" --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277 …` (the `publishing-roblox-assets` skill gives the per-file arguments).

## Review Focus

1. **The client transit waits for a Workspace child carrying `LayoutSeed == seed`** (`Client/Features/Shift/Systems/ShiftTransitSystem.luau:91-100`). A map that is not a direct Workspace child, or a seed not written on the map every shift, leaves players behind the transit cover forever. The fix is a validator error and a per-shift `SetAttribute`. Tests: Task 3 "errors when the map is not a direct Workspace child"; Task 7 Step 5 check (b).
2. **A tagged map that is broken, or two maps**, must fall back to the generated office with every problem logged. No half-adopted map may remain (no code tags left on builder parts, no stray truck). Tests: Task 6 "load returns nil and touches nothing when the map has errors" and "load refuses two maps"; Task 7 Step 5 check (e).
3. **A map that is not world-aligned** (truck dock yawed 90°/180°/270°): `spawnCFrame` must still face out of the truck's open back, `safeZone` min must be ≤ max on every axis, and `whereIs` must find rooms. Tests: Task 1 "reads a dock turned 90° as the map's frame"; Task 2 "rooms turned 90° swap their extents"; Task 6 "builds the truck in the dock's frame".
4. **Builder geometry that is a little off:** room boxes 0.01 studs apart, a locker flush against a wall, a door box a hair off the wall line. These must snap and validate, not fail with a cryptic layout error. A real gap or overlap names the piece. Tests: Task 2 "snaps room edges and door lines to 0.5 studs"; Task 3 "accepts furniture flush to a wall" and "names both rooms when two room boxes overlap".
5. **Hand-built furniture without the generator's art structure:** a closet or desk with no drawer or door children. Searching, hiding and peeking must not error, and searched-state dressing is skipped in map mode. Tests: Task 6 "adopted furniture carries search and hide tags and no generator art"; Task 7 Step 5 check (d).

---

## The tag contract (decided here; Task 4 writes it up for builders)

Map space is the **truck dock's floor frame**: origin at the dock part's centre, dropped to its bottom face. Its yaw is the dock's, and its −Z is the dock's front face (the direction players face on arrival, out of the truck's open back). x runs across, z runs deep, and y = 0 is the floor. `OfficeConstants.ORIGIN` remains the generator's origin only.

| Tag (new, `OfficeMapConstants`) | On | Attributes (builder sets) | What the code does with it |
|---|---|---|---|
| `OfficeMap` | the map's root **Model**, a direct child of Workspace | `OfficeMapVersion` = 1 | Root of the scan. Gets `LayoutSeed` each shift (code) |
| `OfficeRoom` | an invisible, non-colliding box Part filling a room from wall centre to wall centre, floor to ceiling | `RoomId` (unique string), `RoomName` (CCTV and crew-status text), `RoomZone` (optional: `hallway` for corridors), `LoadingBay` = true on exactly one, `DeadEnd` = true for an intended one-exit room | Layout rooms; `whereIs`, depths, dirty-room roll (hallways never dirty) |
| `OfficeDoor` | an invisible box Part across a doorway opening | none | Layout doors. The two rooms are found from the wall it sits on, and its width is the long side |
| `OfficeTruckDock` | one box Part on the bay floor where the truck bed goes (12 × 16 footprint), front face toward the office | none | Map frame. Code builds the truck, bed (Load), time clock (Clock out), overtime sheet, safe-zone volume and arrival spots |
| `OfficeSpot` | a small invisible Part on the floor | `SpotKind` = `pile` / `item` / `patrol` / `rest`; `PatrolOrder` (integer from 1, unique) on patrol spots | Vacuum piles and buried loot, floor valuables, the Manager's patrol loop (in order) and his break point |
| `OfficeFurniture` | the furniture's root BasePart (its collision box) | `FurnitureKind` = `desk` / `locker` / `table` / `cabinet` / `closet` / `shelf` / `counter` / `plant` / `board` | Markers. Desk and locker get Search (Cargo). Desk, table and closet get Hide (`HideFurniture`, and closet hides as Hide's `cabinet`). Table, cabinet and counter tops hold loot |

Existing tags builders also place (contract unchanged, now documented): `OfficeChair` on a chair root (code writes `OfficeDeskMarker` to the nearest desk within 6 studs: the Manager's stare and seat), `OfficeLight` on a light fixture with a `Light` child (the Manager's flicker tells, atmosphere blinks), `OfficeLightEmitter` = true on its glowing panel, and `OfficeAmbient` + `AmbientKind` (`phone`/`typing`/`elevator`) for ambience emitters.

Code-written, never set by builders: `OfficeMarkerId`, `OfficeDeskMarker`, `HideFurnitureKind`, the Interaction attributes and `Interactable` tag, `ArtSupportSurfaceY` (only when absent: the part's height), and `LayoutSeed`.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Data | OfficeMapConstants | Tag and attribute names of the map contract, snap/tolerance values, research-rule thresholds |
| Office | server | Utils | OfficeMapScanUtils | Reads one tagged map Model into plain map-space data (`MapScan`) plus its parts; changes nothing |
| Office | server | Utils | OfficeMapLayoutUtils | Converts a valid `MapScan` into an `OfficeTypes.Layout` and each piece's marker id |
| Office | server | Rules | OfficeMapRules | Validates a `MapScan`: contract errors (map unusable) and research-rule warnings |
| Office | server | Testing | OfficeMapPlanHarness | The approved layout plan as data; builds its tagged graybox blockout in a place |
| Office | server | Systems | OfficeMapSystem | Finds, validates and adopts a tagged map (code tags, truck at the dock); releases it |

Modified: `Office/Data/OfficeTypes`, `Office/Utils/OfficeLoadingBayUtils` (+`truckAt`), `Office/Systems/OfficeBuildSystem` (+`buildTruck`, `buildSafeZone`, `markFurniture` extracted), `Office/OfficeServiceServer`, `Client/Features/Office/Data/OfficeAtmosphereConstants`, `Core/Testing/SpecRoots`. New docs: `docs/office-map-builder-guide.md`, `docs/office-map/layout-v1.svg`.

---

### Task 1: Contract constants, map types and the scan

**Files:**
- Create: `src/ServerScriptService/Features/Office/Data/OfficeMapConstants.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau` (append types)
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeMapScanUtils.luau`
- Test: `src/ServerScriptService/Features/Office/Utils/OfficeMapScanUtils.spec.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (exempt `OfficeMapConstants`: "static tag names and thresholds (no logic)")

**Interfaces:**
- Produces, in `OfficeMapConstants` (frozen table):
  - Tags: `MAP_TAG = "OfficeMap"`, `ROOM_TAG = "OfficeRoom"`, `DOOR_TAG = "OfficeDoor"`, `DOCK_TAG = "OfficeTruckDock"`, `SPOT_TAG = "OfficeSpot"`, `FURNITURE_TAG = "OfficeFurniture"`. `SCANNED_TAGS` is these five plus `OfficeDecorConstants.CHAIR_TAG` and `OccupantConstants.LIGHT_TAG`, in that order.
  - Attributes: `VERSION_ATTRIBUTE = "OfficeMapVersion"`, `VERSION = 1`, `ROOM_ID = "RoomId"`, `ROOM_NAME = "RoomName"`, `ROOM_ZONE = "RoomZone"`, `LOADING_BAY = "LoadingBay"`, `DEAD_END = "DeadEnd"`, `SPOT_KIND = "SpotKind"`, `PATROL_ORDER = "PatrolOrder"`, `FURNITURE_KIND = "FurnitureKind"`.
  - Kinds: `SPOT_KINDS = { pile, item, patrol, rest }` and `FURNITURE_KINDS = { desk, locker, table, cabinet, closet, shelf, counter, plant, board }` (sets of `true`). `HIDE_KINDS = { desk = "desk", table = "table", closet = "cabinet" }` (furniture kind to Hide's `HideFurnitureKind`).
  - Geometry: `SNAP = 0.5`, `GRID = 2`, `SQUARE_TOLERANCE = math.rad(1)`, `FLOOR_TOLERANCE = 0.5`, `DOOR_REACH = 0.75`, `CHAIR_REACH = 6`, `CODE_FOLDER = "OfficeCode"`.
  - Thresholds (report IDs in comments): `ROOMS = {min=12,max=18}` (L8), `FOOTPRINT_MAX = Vector2.new(480, 360)` (L8, 400×300 + 20%), `HIDE_REACH = 45` (L7), `CORRIDOR_WIDTH = {min=8,max=12}` and `ROOM_LIKE_WIDTH = 16` (L4), `CHOKE_MIN = 5` (L4), `STRAIGHT_MAX = 80` (L3), `LOOPS_MIN = 2` (L1), `DEAD_END_SHARE = 0.2` (L6), `HALLWAY_SHARE = {min=0.25,max=0.35}` (L10), `RUN_SPEED = 16` and `TRUCK_REACH_SECONDS = 40` (L8).
- Produces, in `OfficeTypes`:
  ```lua
  export type MapPiece = {
      tag: string, name: string, isPart: boolean,
      x: number, y: number, z: number,            -- centre, map space
      sizeX: number, sizeY: number, sizeZ: number, -- extents along map axes (swapped for 90°/270° yaw)
      yaw: number, square: boolean,                -- yaw in radians; square = yaw a multiple of 90° and upright
      attributes: { [string]: string | number | boolean },
      hasLight: boolean,                           -- a Light descendant (OfficeLight pieces)
  }
  export type MapScan = { name: string, version: unknown, inWorkspace: boolean, docks: number,
      origin: CFrame, pieces: { MapPiece } }
  export type MapReport = { errors: { string }, warnings: { string } }
  ```
- Produces `OfficeMapScanUtils.scan(map: Model): (OfficeTypes.MapScan, { Instance })`. `pieces[i]` describes `instances[i]`. It walks `map:GetDescendants()` with `HasTag` (not `GetTagged`, so specs work on unparented models). An instance with two scanned tags yields one piece per tag. With one dock, `origin` is the dock's floor frame. With none or several, `origin = map:GetPivot()` and `docks` records the count.
- Produces `OfficeMapScanUtils.floorFrame(dock: BasePart): CFrame`: the dock's centre dropped to its bottom face, yaw only, with −Z along the dock's flattened LookVector.

- [ ] **Step 1: Write the failing spec** `OfficeMapScanUtils.spec.luau`. Each `it` builds a `Model` with tagged Parts (unparented):
  - `it("reads a dock turned 90° as the map's frame")`: dock at world (100, 2, 50) with size (12, 2, 16), turned 90° about Y. `scan.origin.Position` ≈ (100, 1, 50), and `scan.origin.LookVector` ≈ the dock's LookVector (fuzzy 1e-3).
  - `it("puts a room in map space with its extents swapped for a 90° turn")`: room size (20, 12, 8) turned 90° relative to the dock gives `sizeX ≈ 8`, `sizeZ ≈ 20`, `square == true`.
  - `it("marks a piece turned 30° as not square")`.
  - `it("copies every attribute")`: `RoomId`, `RoomName` and `LoadingBay` read back with their types.
  - `it("records a tagged Model as not a part")`: `isPart == false`.
  - `it("counts docks and falls back to the pivot without exactly one")`: 0 docks gives `docks == 0` and origin == `map:GetPivot()`; 2 docks gives `docks == 2`.
  - `it("knows whether the map is a direct Workspace child")`: false unparented, true parented to Workspace (clean up in `afterEach`).
  - `it("flags lights with and without a Light child")`: `hasLight` true for a part with a `PointLight`, false without.
  - `it("pairs each piece with its instance")`: `instances[i]` has `pieces[i].name == instances[i]:GetFullName()`.
- [ ] **Step 2: Run tests; expect the new spec to fail** (module missing). Studio test run per Global Constraints.
- [ ] **Step 3: Write `OfficeMapConstants`, the `OfficeTypes` additions, the SpecRoots exemption, and `OfficeMapScanUtils.scan` / `floorFrame`.** Local frame = `origin:ToObjectSpace(part.CFrame)`. Square = local UpVector · Y ≥ cos(tolerance) and |yaw mod 90°| ≤ tolerance. Extents are swapped when yaw is near 90° or 270°.
- [ ] **Step 4: Run tests; expect all to pass** (count +9).
- [ ] **Step 5: Lint/format the four changed files; run `module_map.py --write`; commit**
  ```bash
  git add src/ServerScriptService/Features/Office/Data/OfficeMapConstants.luau src/ServerScriptService/Features/Office/Data/OfficeTypes.luau src/ServerScriptService/Features/Office/Utils/OfficeMapScanUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeMapScanUtils.spec.luau src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
  git commit -m "Office: map tag contract and scan"
  ```

### Task 2: Scan to Layout

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.luau` (+ `truckAt`; `truck` calls it)
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.spec.luau`
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeMapLayoutUtils.luau`
- Test: `src/ServerScriptService/Features/Office/Utils/OfficeMapLayoutUtils.spec.luau`

**Interfaces:**
- Consumes: `MapScan` and `MapPiece` (Task 1), and `OfficeMapConstants`.
- Produces `OfficeLoadingBayUtils.truckAt(cx: number, cz: number, towardMax: boolean): OfficeTypes.Truck`. This is `truck`'s footprint and clock maths for a given bed centre. `truck(bay, side)` becomes `truckAt(<its cx>, <its cz>, side == 2)` with identical results.
- Produces `OfficeMapLayoutUtils.toLayout(scan: OfficeTypes.MapScan): (OfficeTypes.Layout, { [number]: string })`. The second value maps piece index to marker id. It assumes `OfficeMapRules` found no contract errors (it `assert`s what it relies on). The rules:
  - **Rooms:** sorted by `RoomId`; bounds = centre ± extent/2, rounded to `SNAP`; `id = RoomId`, `name = RoomName`, `zone = RoomZone`. `startRoom` = the `LoadingBay` room.
  - **Doors:** for each door piece, the shared edge of the two rooms whose edge line lies within `DOOR_REACH` of its centre. `x`/`z` across that edge are set **exactly** to the edge value; `width` is the long horizontal extent, rounded to `SNAP`; `a`/`b` are the two ids in sorted order.
  - **Markers:** spots and furniture, each in the room `OfficeLayoutUtils.roomAt` finds for its centre. `kind` is the spot or furniture kind. `rotation = yaw` for furniture, nil for spots. `id = "<roomId>.<kind>.<n>"`, with n counting from 1 in order of (x, then z) within room and kind.
  - **Spawns:** one `spawn` marker per `OfficeLoadingBayUtils.arrivals(truck)` point in the start room.
  - `route` = patrol marker ids sorted by `PatrolOrder`; `rest` = the rest marker's id.
  - `truck = truckAt(0, 0, towardMax)`, where `towardMax` is true when the bay has more floor on −X (bay.maxX < −bay.minX). This keeps the clock (at `CLOCK_SIDE` from the bed) on the roomier side.
  - `artKit = nil`.

- [ ] **Step 1: Write the failing specs.** In `OfficeLoadingBayUtils.spec`: `it("places a truck by its centre")` checks `truckAt(0, 0, false)` gives min/max X ±6, min/max Z ±8, `clockX = 14`, `clockZ = -10`; and `it("keeps truck(bay, side) as before")` checks that for all four sides `truck(bay, side)` equals `truckAt(cx, cz, side == 2)`. In `OfficeMapLayoutUtils.spec` (fixtures are hand-made `MapScan` tables built by a local `piece(tag, x, z, sizeX, sizeZ, attrs)` helper):
  - `it("builds rooms sorted by RoomId with names and zones")`
  - `it("snaps room edges and door lines to 0.5 studs")`: rooms with maxX 20.01 and minX 19.98 both become 20, and a door centred at x 20.3 gets `x == 20` exactly, so `OfficeLayoutUtils.doorEdge` is non-nil for both rooms.
  - `it("rooms turned 90° swap their extents")`
  - `it("names markers <room>.<kind>.<n> in x-then-z order")`
  - `it("orders the route by PatrolOrder and finds the rest point")`
  - `it("adds a spawn marker per arrival point in the loading bay")`: 4 markers of kind `spawn`, room = start room.
  - `it("puts the truck at the map origin with the clock on the roomier side")`
  - `it("maps each spot and furniture piece to its marker id")`
  - `it("converts a tiny valid map that OfficeLayoutRules.validate accepts")`: bay + 2 rooms + 2 doors gives `validate` → `true`.
- [ ] **Step 2: Run tests; expect the new `it`s to fail.**
- [ ] **Step 3: Implement `truckAt`, re-point `truck` at it, and implement `toLayout`.**
- [ ] **Step 4: Run tests; expect all to pass** (count +11; the existing `OfficeLoadingBayUtils` specs stay green).
- [ ] **Step 5: Lint/format changed files; `module_map.py --write`; commit**
  ```bash
  git add src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeLoadingBayUtils.spec.luau src/ServerScriptService/Features/Office/Utils/OfficeMapLayoutUtils.luau src/ServerScriptService/Features/Office/Utils/OfficeMapLayoutUtils.spec.luau docs/project-structure.md
  git commit -m "Office: convert a tagged map scan into a layout"
  ```

### Task 3: The validator

**Files:**
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeMapRules.luau`
- Test: `src/ServerScriptService/Features/Office/Rules/OfficeMapRules.spec.luau`

**Interfaces:**
- Consumes: `MapScan`, `MapReport`, `OfficeMapConstants` (Task 1); `OfficeMapLayoutUtils.toLayout` (Task 2); `OfficeLayoutRules.validate` / `checkCapacity` / `checkRoute`; `OfficeLayoutUtils.depths`; `OfficeConstants.DOOR_MIN_WIDTH`, `WALL_THICKNESS`.
- Produces `OfficeMapRules.validate(scan: OfficeTypes.MapScan): OfficeTypes.MapReport`. Every message starts with the piece's `name` (or the map's) so a builder can find it.
  - **Errors** (map unusable). Contract checks run first. When they pass, `toLayout` runs and the three `OfficeLayoutRules` checks run on its result (their messages prefixed `layout: `). Warnings run only when there are no errors.
    - E1 `OfficeMapVersion` missing or not `VERSION`.
    - E2 not a direct Workspace child.
    - E3 `docks ~= 1`.
    - E4 a tagged non-BasePart.
    - E5 a piece that is not `square` (lights, chairs and spots exempt).
    - E6 a room without `RoomId`/`RoomName`, or a duplicate `RoomId`.
    - E7 a `LoadingBay` count other than 1.
    - E8 a room whose bottom (`y − sizeY/2`) is off the floor by more than `FLOOR_TOLERANCE`.
    - E9 two room boxes that overlap after snapping (names both).
    - E10 a door touching 0, 1 or 3+ rooms.
    - E11 a spot with a missing or unknown `SpotKind`, outside every room, a patrol spot without an integer `PatrolOrder` ≥ 1, a duplicate order, or a rest count other than 1.
    - E12 furniture with a missing or unknown `FurnitureKind`, outside every room, or whose real footprint crosses its room's wall line minus `WALL_THICKNESS/2`.
    - E13 the converted layout failing `OfficeLayoutRules`.
  - **Warnings**, prefixed with the rule ID, e.g. `"[L7] Cubicles: door at (40, 12) is 61 studs from the nearest hide (aim ≤ 45)"`:
    - L1: loops = doors − rooms + 1 < `LOOPS_MIN`.
    - L3: a hallway's long side > `STRAIGHT_MAX`.
    - L4: a hallway's short side outside `CORRIDOR_WIDTH` or > `ROOM_LIKE_WIDTH`; a door narrower than `CHOKE_MIN`.
    - L6: a one-door room without `DeadEnd`; dead ends > `DEAD_END_SHARE` of non-hallway rooms; a dead end with no hide.
    - L7: a room door farther than `HIDE_REACH` (straight line) from every hide piece (furniture of a `HIDE_KINDS` kind).
    - L8: non-hallway room count outside `ROOMS`; map footprint larger than `FOOTPRINT_MAX` (either orientation); the walking distance from the dock to the farthest room centre > `RUN_SPEED × TRUCK_REACH_SECONDS`. The walking distance is a shortest path whose nodes are the dock, door centres and room centres, with straight-line edges between nodes that share a room.
    - L9: the deepest room (by `OfficeLayoutUtils.depths`) has no route to the bay that survives removing any single door on its shortest door path.
    - L10: hallway floor area share outside `HALLWAY_SHARE`.
    - K1: a room or door bound off the `GRID`.
    - LT11: a non-hallway room containing no `OfficeLight` piece, or an `OfficeLight` piece with `hasLight == false`.

- [ ] **Step 1: Write the failing spec.** A local `validMap()` builds a small scan that passes with **no errors**: bay, 6 work rooms each with 5 pile spots, a deep item and a deep desk, 3 patrol spots, a rest spot in a non-bay room, doors forming two loops. One `it` per check, each mutating `validMap()` and asserting that the report contains a message matching a `string.find` pattern:
  - `it("passes a valid map with no errors")`
  - `it("errors when the map is not a direct Workspace child")`
  - `it("errors without exactly one truck dock")`
  - `it("errors on a missing map version")`
  - `it("errors on a room turned off the grid")`
  - `it("errors on a duplicate RoomId")`
  - `it("errors without exactly one loading bay")`
  - `it("errors on a raised room floor")`
  - `it("names both rooms when two room boxes overlap")`
  - `it("errors on a door between three rooms and one between none")`
  - `it("errors on an unknown spot kind and a duplicate PatrolOrder")`
  - `it("errors on furniture crossing a wall")`
  - `it("accepts furniture flush to a wall")`: a locker (2.5 deep) whose back face is on the wall's inner face raises no error.
  - `it("passes layout rule failures through as errors")`: remove the rest spot, and the report contains a `layout:` message.
  - `it("warns [L1] on a tree-shaped map")`
  - `it("warns [L7] when a door is far from every hide")`
  - `it("warns [L8] when the farthest room is over 40 s from the truck")`
  - `it("warns [L6] on an unmarked one-door room")`
  - `it("warns [L4] on a hallway wider than 16 studs")`
  - `it("warns [LT11] on a room without lights")`
  - `it("skips warnings while there are errors")`
- [ ] **Step 2: Run tests; expect failures.**
- [ ] **Step 3: Implement `OfficeMapRules.validate`.** Keep it ≤ 400 code lines. If it nears that, split the warnings into local functions in the same file, not a second module.
- [ ] **Step 4: Run tests; expect all to pass** (count +21).
- [ ] **Step 5: Lint/format; `module_map.py --write`; commit**
  ```bash
  git add src/ServerScriptService/Features/Office/Rules/OfficeMapRules.luau src/ServerScriptService/Features/Office/Rules/OfficeMapRules.spec.luau docs/project-structure.md
  git commit -m "Office: validate hand-built maps against the tag contract and the map research rules"
  ```

### Task 4: Builder guide

**Files:**
- Create: `docs/office-map-builder-guide.md`

**Interfaces:**
- Consumes: the tag contract table above and Task 3's message list.

- [ ] **Step 1: Write the guide for non-coders** (no Luau). Sections:
  1. What the code needs from the map, in one picture-in-words. One Model `OfficeMap` in Workspace, `OfficeMapVersion = 1`.
  2. How to add a tag and an attribute in Studio (Properties → Tags / Attributes).
  3. One subsection per tag from the contract table. Say where the box goes (room boxes reach the *middle* of the walls, so neighbouring room boxes touch; door boxes sit across the opening), its size rules (room floors at the same height; rotate only in 90° steps; furniture centre inside its room), and every attribute with allowed values.
  4. The truck dock. Make it 12 × 16, with the front face toward the office (Studio's "Front" face). Leave ≥ 4 studs of floor behind it for the ramp and ~15 studs on one side for the clock. Never build the truck yourself.
  5. Existing tags (`OfficeChair`, `OfficeLight` + `OfficeLightEmitter`, `OfficeAmbient` + `AmbientKind`).
  6. Physical rules the code assumes. Walls, floors and tall furniture are `CanCollide`/`CanQuery` on (the Manager's sight and paths use them, and glass blocks his sight today). Small clutter has `CanCollide`, `CanTouch` and `CanQuery` off (L13, P6). No collidable furniture in door frames.
  7. Layout targets: an L1–L10 cheat sheet in plain words with the numbers from `OfficeMapConstants`, and the K2–K5 kit sizes.
  8. Checking your map. Press Play (with `RunTests` off). Output prints `office map: <n> errors, <m> warnings` and each message. Errors mean the game silently uses the old generated office, so fix them first. Warnings are design advice, each tagged with a rule ID.
  9. Every message from Task 3 with a one-line fix.
- [ ] **Step 2: Verify** every tag and attribute name in the guide matches `OfficeMapConstants`. Run `grep -o '"[A-Za-z]*"' src/ServerScriptService/Features/Office/Data/OfficeMapConstants.luau` and check each name appears in the guide and vice versa.
- [ ] **Step 3: Commit**
  ```bash
  git add docs/office-map-builder-guide.md
  git commit -m "Docs: Office map builder guide"
  ```

### Task 5: Layout plan (owner gate 1)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Testing/OfficeMapPlanHarness.luau`
- Test: `src/ServerScriptService/Features/Office/Testing/OfficeMapPlanHarness.spec.luau`
- Create: `docs/office-map/layout-v1.svg`

**Interfaces:**
- Consumes: `OfficeMapScanUtils.scan`, `OfficeMapLayoutUtils.toLayout`, `OfficeMapRules.validate`, `OfficeLayoutUtils.mergedWallSegments` / `lightPoints`, `OfficeMapConstants`, `OfficeConstants` (furniture sizes, `WALL_HEIGHT`, `WALL_THICKNESS`).
- Produces `OfficeMapPlanHarness.plan(): OfficeTypes.MapScan`. This is the approved layout in map space, from a compact table in the module: `rooms {id, name, zone, minX, minZ, maxX, maxZ, deadEnd?, bay?}`, `doors {x, z, width, alongX}`, `spots {kind, x, z, order?}`, `furniture {kind, x, z, yaw}`, `lights` (auto: `lightPoints` per non-hallway room).
- Produces `OfficeMapPlanHarness.instantiate(parent: Instance): Model`. It builds the tagged graybox blockout: invisible tagged room, door, spot and dock boxes, standard-size tagged furniture boxes, opaque floors, ceilings and walls from `mergedWallSegments(toLayout(plan()))` with door gaps, and a tagged `OfficeLight` part with a `PointLight` at each light point. It sets `OfficeMapVersion`, names the Model `OfficeMap` and parents it. It is used by the spec, by Task 7's smoke run and by Task 9's Studio blockout.

**Layout requirements the plan must meet** (copy the room identities from the report's room table; R1):
- About 400 × 300 studs, **12–18 non-hallway rooms** in 3–5 zones (L8), on the 4-stud kit grid (K1). Hallways are `RoomZone = "hallway"` rooms 8–12 studs clear (main corridor 12; L4, K4), no straight run over 80 (L3), and 25–35 % of floor area (L10).
- The truck bay is the hub with 2–3 spokes and ≥ 2 connector loops (L1). Room-scale loops have an inner block ≥ 12 studs and laps of ~80–150 studs (L5).
- Every room has ≥ 2 exits except `DeadEnd` rooms (≤ 1 in 5, each with a hide and loot; L6). There is a hide within 45 studs of every room door, and ≥ 2 hides in noisy cleaning rooms (L7). Two routes run back to the bay from the deepest zone, which holds the richest cleaning (L9). One soft break room has several hides and two exits; the rest point goes there (L14). The farthest room is ≤ 40 s from the truck (L8).
- Capacity for the existing roll: ≥ 6 non-hallway rooms with 5 pile spots each (`DIRTY_ROOMS.max` and `PILES_PER_ROOM.max`), item spots in every work room including deep ones (depth ≥ 2), and deep desks or lockers. The patrol loop (≥ 3 points, ordered) circles the cleaning clusters rather than crossing them (L11), off the truck.
- The bay is at least 44 × 42 (today's `BAY_WIDTH` × `BAY_DEPTH`), with the dock placed per Task 4 §4.
- A unique tall landmark at every hallway junction (W2), and a distinct key colour per zone (W4). These are noted in the SVG only; art comes later.

- [ ] **Step 1: Write the failing spec**
  - `it("the plan passes with no errors and no warnings")`: `OfficeMapRules.validate` on a scan of `instantiate()` (parented to Workspace in the test, destroyed in `afterEach`) gives `#errors == 0` and `#warnings == 0`.
  - `it("instantiate round-trips to the same layout as plan()")`: `toLayout(scan(instantiate(...)))` deep-equals `toLayout(plan())`.
  - `it("holds 12-18 rooms and two loops")`
  - `it("the spawn roll meets its guarantees on the plan")`: `OfficeSpawnUtils.roll` + `OfficeSpawnRules.check` on `toLayout(plan())` for seeds 1–20 all pass.
- [ ] **Step 2: Run tests; expect failures.**
- [ ] **Step 3: Design the layout and write it into the harness.** Iterate until the spec passes with zero warnings. If a research number cannot be met without hurting play, keep the warning and record why in a comment on that room, then change the first `it` to expect exactly those warnings.
- [ ] **Step 4: Run tests; expect all to pass** (count +4).
- [ ] **Step 5: Draw `docs/office-map/layout-v1.svg` from the harness numbers.** Show rooms with names, zone colours, doors, hides, the 45-stud reach circles around each room door, the patrol loop with order numbers, the rest point, the truck dock and arrival spots, landmarks, a 40-stud scale bar and north = map −Z. Publish it as a private Artifact for the owner and send the link.
- [ ] **Step 6: Owner gate 1.** Ask the owner to approve the layout (layout only; look comes later). On change requests, edit the harness, re-run Steps 4–5, and ask again. Do not start Task 9 before a clear yes.
- [ ] **Step 7: Lint/format; `module_map.py --write`; commit**
  ```bash
  git add src/ServerScriptService/Features/Office/Testing/OfficeMapPlanHarness.luau src/ServerScriptService/Features/Office/Testing/OfficeMapPlanHarness.spec.luau docs/office-map/layout-v1.svg docs/project-structure.md
  git commit -m "Office: layout plan v1 as a validated harness and top-down plan"
  ```

### Task 6: Adopting a tagged map

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau` (extract `buildTruck`, `buildSafeZone`, `markFurniture`; `build` calls them)
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.spec.luau`
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeMapSystem.luau`
- Test: `src/ServerScriptService/Features/Office/Systems/OfficeMapSystem.spec.luau`

**Interfaces:**
- Consumes: Tasks 1–3; `OfficeMapPlanHarness.instantiate` (Task 5) for fixtures; `ArtVisualSystem.Controller` (fake in specs, as `OfficeBuildSystem.spec` does).
- Produces, in `OfficeBuildSystem` (unchanged behaviour for `build`):
  - `buildTruck(truck: OfficeTypes.Truck, origin: CFrame, parent: Instance, art: ArtVisualSystem.Controller): (BasePart, BasePart, BasePart)` returns the bed (Load), clock (Clock out) and overtime sheet (off), exactly as `build` makes them today.
  - `buildSafeZone(truck: OfficeTypes.Truck, origin: CFrame, parent: Instance): BasePart` makes today's `SafeZone` volume with its `PathfindingModifier`.
  - `markFurniture(part: BasePart, marker: OfficeTypes.Marker)` sets `OfficeMarkerId`. Desk and locker get Search (Interaction, disabled until stocked). Desk, table and closet get `HideFurnitureKind` (via `OfficeMapConstants.HIDE_KINDS`) and the `HideFurniture` tag. `build` uses it for its desks and lockers.
- Produces, in `OfficeMapSystem`:
  ```lua
  export type Loaded = {
      map: Model, origin: CFrame, layout: OfficeTypes.Layout,
      built: OfficeBuildSystem.Built,           -- model = the map; searchables by marker id
      report: OfficeTypes.MapReport,
      release: () -> (),                        -- removes exactly what adopt added
  }
  OfficeMapSystem.load(maps: { Instance }, visuals: ArtVisualSystem.Controller?): (Loaded?, OfficeTypes.MapReport?)
  OfficeMapSystem.adopt(map: Model, scan: OfficeTypes.MapScan, instances: { Instance },
      visuals: ArtVisualSystem.Controller?): Loaded
  ```
  - `load`: 0 maps gives `nil, nil`. 2+ maps gives `nil` and a report whose only error is `"<n> OfficeMap models; keep exactly one"`. 1 map runs scan → validate. With errors it returns `nil, report` and touches nothing. With none it returns `adopt(...)` with `loaded.report = report`.
  - `adopt`: makes `CODE_FOLDER` under the map and builds the truck and safe zone there in `scan.origin`. It calls `markFurniture` on each furniture part with its marker. For each `OfficeChair` piece it writes `OfficeDeskMarker` = the nearest desk marker id within `CHAIR_REACH`. On table, cabinet and counter parts without `ArtSupportSurfaceY` it sets that attribute to the part's `Size.Y`. It records every attribute and tag it added; `release` removes them and destroys the code folder. Calling `adopt` again on the same map first releases the previous adoption (the map is held in a module-level weak table).

- [ ] **Step 1: Write the failing specs.** In `OfficeBuildSystem.spec`, `it("buildTruck and buildSafeZone make the parts build makes")` checks names, Interaction kinds, the safe zone's `PathfindingModifier` label, and that a layout's `build` output is unchanged. In `OfficeMapSystem.spec` (fixtures from `OfficeMapPlanHarness.instantiate(Workspace)`, destroyed in `afterEach`):
  - `it("load returns nothing when there is no map")`
  - `it("load refuses two maps")`
  - `it("load returns nil and touches nothing when the map has errors")`: remove the dock, then no descendant has `OfficeMarkerId` and no `OfficeCode` folder exists.
  - `it("adopted furniture carries search and hide tags and no generator art")`: every desk has the Interaction tag, the Search kind and `HideFurniture`; every closet has `HideFurnitureKind == "cabinet"`; a locker has no `HideFurniture`. The furniture parts gained no new children besides the hide spot attachment.
  - `it("builds the truck in the dock's frame")`: turn the whole map 90°, then the bed's centre ≈ the dock's centre raised by `BED_HEIGHT/2`, and its LookVector ≈ the dock's.
  - `it("links each chair to its nearest desk")`
  - `it("gives surface furniture a support height")`
  - `it("release removes exactly what adopt added")`: after `release`, the map's descendants, tags and attributes equal a snapshot taken before `adopt`.
  - `it("adopting twice leaves one truck")`
- [ ] **Step 2: Run tests; expect failures.**
- [ ] **Step 3: Extract the three `OfficeBuildSystem` functions, then implement `OfficeMapSystem`.**
- [ ] **Step 4: Run tests; expect all to pass** (count +10; every existing `OfficeBuildSystem`, Hide and Occupant spec stays green).
- [ ] **Step 5: Lint/format; `module_map.py --write`; `check_file_length.py`; commit**
  ```bash
  git add src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.spec.luau src/ServerScriptService/Features/Office/Systems/OfficeMapSystem.luau src/ServerScriptService/Features/Office/Systems/OfficeMapSystem.spec.luau docs/project-structure.md
  git commit -m "Office: adopt a hand-built tagged map and build the truck at its dock"
  ```

### Task 7: The Office reads tags

**Files:**
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (refresh the OfficeServiceServer exemption reason: "…; map choice is the specced OfficeMapSystem/OfficeMapRules")

**Interfaces:**
- Consumes: `OfficeMapSystem.load` / `Loaded` (Task 6). Every existing consumer call.
- Produces: no new public API. Internally:
  - `local origin: CFrame` (starts at `OfficeConstants.ORIGIN`) replaces every `OfficeConstants.ORIGIN` use in `floorAt`, `spotFrame`, `spawnCFrame`, `safeZone`, `loadingBay` and `whereIs`.
  - `local source: "generator" | "map"` and `local loaded: OfficeMapSystem.Loaded?`.
  - A local `useLayout(layout: OfficeTypes.Layout)` holds what `rebuild` repeats today (LAYOUT, depths, markerById, routePoints, restMarker).
  - `getState()` adds `source`, `mapErrors` and `mapWarnings` (counts).

- [ ] **Step 1: Write the map/generator choice into `start`.** Call `OfficeMapSystem.load(CollectionService:GetTagged(OfficeMapConstants.MAP_TAG))`. Log one line `office map: <n> errors, <m> warnings` whenever a report exists, then each message (`log:warn` for errors, `log:info` for warnings). If loaded: `source = "map"`, `origin = loaded.origin`, `useLayout(loaded.layout)`, `built = loaded.built`, and skip `OfficeBuildSystem.build` and `OfficeDecorSystem.build`. Otherwise run today's path unchanged, with `log:warn("office map unusable; using the generated office")` when a map was present.
- [ ] **Step 2: Map mode in `beginShift`, `stop` and the searched handler.**
  - `beginShift`: in map mode, skip `rebuild`, then `loaded.map:SetAttribute("LayoutSeed", options.seed)` and `layoutSeed = options.seed`. The spawn roll still uses `options.seed` (its randomness is the variety per shift).
  - `stop`: in map mode call `loaded.release()` instead of destroying the model.
  - Searched handler: in map mode do not call `dressing.apply` (follow-up F3).
- [ ] **Step 3: Run tests; expect all green** (count unchanged from Task 6). Lint/format the two files. Run `check_file_length.py`. If `OfficeServiceServer` goes over 400 code lines, move `rollPlan` into `OfficeSpawnUtils.rollChecked(layout: OfficeTypes.Layout, options: OfficeTypes.RollOptions, seed: number): (OfficeTypes.SpawnPlan, { string })`. It returns the plan and the missed-guarantee reasons for the service to log. Write its spec first: `it("re-rolls with the next seed until the guarantees hold")` (+1 test).
- [ ] **Step 4: Generator regression run (no map in the place).** With `RunTests = false`, press Play in the Odd Hours window and run a shift to clock-out. Output shows no `office map:` line; `getState().source == "generator"` (Debugger F4). Stop.
- [ ] **Step 5: Map smoke run.** In edit mode, Studio MCP runs `require(game.ServerScriptService.Features.Office.Testing.OfficeMapPlanHarness).instantiate(workspace)`, positioned clear of the depot and the generated office (dock near world (1000, 1, 600)). Press Play and check:
  - (a) Output shows `office map: 0 errors, 0 warnings` and `getState().source == "map"`.
  - (b) After boarding and the transit, the cover lifts. `workspace.OfficeMap:GetAttribute("LayoutSeed")` equals the shift's seed.
  - (c) Piles, floor valuables and buried loot appear on spots. Desks and lockers search. The Manager walks the ordered patrol, rests in the break room, never enters the truck box, and CCTV/crew status shows `RoomName`s.
  - (d) Hide under a desk, under a table and inside a closet; peek; get searched. No errors in Output.
  - (e) Delete the dock and Play again. Output lists the dock error and `using the generated office`, the generated office runs, and the map has no `OfficeMarkerId` attributes.
  - Stop, then delete `workspace.OfficeMap`. It is not kept from this step.
- [ ] **Step 6: Commit**
  ```bash
  git add src/ServerScriptService/Features/Office/OfficeServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
  git commit -m "Office: serve the office from a tagged hand-built map, falling back to the generator"
  ```

### Task 8: Lighting floor (LT3, LT5)

**Files:**
- Modify: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.spec.luau`

**Interfaces:**
- Consumes: `OfficeAtmosphereConstants.PRESETS` (the field name in the returned table; check it before writing the test).

- [ ] **Step 1: Write the failing spec** in `OfficeAtmosphereUtils.spec`:
  - `it("keeps every office preset's exposure between -0.5 and 0.3")` (LT5)
  - `it("never drops an office preset's ambient below the night floor")` (LT3): every office preset's ambient has luminance (0.2126 R + 0.7152 G + 0.0722 B, 0–255) ≥ that of RGB(35, 40, 70), and none is (0, 0, 0).
- [ ] **Step 2: Run tests; expect failures** (today `officeNight` ambient is 26, 30, 46 and `officeTier2` exposure is −0.7).
- [ ] **Step 3: Retune the presets.** `officeNight` ambient ≈ (42, 48, 80) at exposure −0.3. Tiers step down toward the floor, not below it: tier 1 ≈ (38, 43, 74) at −0.4, tier 2 ≈ (35, 40, 70) at −0.5. Break ≈ (48, 54, 88) at −0.2. Overtime keeps its red hue at a luminance at or above the floor, at −0.5. `outdoorAmbient` is ≥ ambient per channel (LT4). Fog is unchanged.
- [ ] **Step 4: Run tests; expect all to pass** (count +2).
- [ ] **Step 5: Lint/format; commit**
  ```bash
  git add src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau src/ReplicatedStorage/Client/Features/Office/Utils/OfficeAtmosphereUtils.spec.luau
  git commit -m "Office: raise the night lighting floor to the map research's phone-safe values"
  ```

### Task 9: Studio blockout and the modular kit (owner gates 2, 3, 4)

Studio MCP and Blender MCP; no product code. The `module-placement` skill does not apply. Use the `publishing-roblox-assets` skill for uploads.

**Files:**
- Create: `art/office-kit/OH_Kit.blend` (Blender source) and `art/office-kit/export/*.fbx`
- Place content (not in git): `Workspace.OfficeMap`, `ServerStorage.OfficeKit`

- [ ] **Step 1: Window check.** If the owner has created the Shift place by now, ask (gate 2) whether to build in its window. Otherwise use the Odd Hours (113354563835664) window only. Build everything as one `OfficeMap` Model so it can move to the Shift place unchanged later.
- [ ] **Step 2: Measure (K14, K15).** In the place, measure a default R15 character's height and width with Studio MCP and write them into the guide's §7. Export a 4 × 4 × 4 test cube from Blender with K15's settings, import it, and confirm it is 4 studs. If it is not, fix the export scale before any kit piece. If K2–K5 change, update `OfficeMapConstants` comments, the guide and Task 5's plan via a new layout gate.
- [ ] **Step 3: Blockout.** Instantiate `OfficeMapPlanHarness.instantiate(workspace)` at the agreed spot. Play a shift solo. Check Output reports 0 errors and 0 warnings. Note any spot where the Manager snags (doors, corners: L13) and fix it in the harness (re-running Task 5 Step 4).
- [ ] **Step 4: Kit, standard pieces first (K8, LDB "no variants yet").** Model in Blender MCP in the toon style. Use bevels 0.1–0.25 (K10), one exaggeration factor of ~20 % (K11), a ≤ 512² palette atlas plus one trim sheet (K13, P4), pivots on the floor grid inside the footprint (K6), and triangle budgets per P2. Pieces:
  - `OH_Wall_Solid_8_01`, `OH_Wall_Door_8_01` (6 × 9 opening), `OH_Wall_DoubleDoor_12_01` (10-wide opening), `OH_Wall_Window_8_01`, `OH_Wall_Corner_1_01`
  - `OH_Floor_Carpet_8_01`, `OH_Floor_Tile_8_01`, `OH_Ceiling_Panel_8_01`, `OH_Ceiling_Light_8_01` (emissive panel; LT11, LT14), `OH_Trim_Base_8_01`
  - Landmarks for W2: `OH_Prop_Vending_4_01`, `OH_Prop_Plant_4_01`, `OH_Door_Fire_6_01`
  - Exit sign: `OH_Sign_Exit_2_01`
  - Desks, lockers, tables, chairs and the supply cabinet reuse the existing approved art kit models (no new furniture this week).
- [ ] **Step 5: Owner gate 3 (look).** Finish `OH_Wall_Solid_8_01` fully (bevels, atlas, trim). Show it in Blender and next to a character in Studio. Get the owner's yes before making the rest to that finish.
- [ ] **Step 6: Owner gate 4 (uploads).** List the batch (file, kind, size). On a yes, upload each mesh **once** (P3) with `python "C:/Users/Bruk Abu/.claude/skills/publishing-roblox-assets/publish.py" --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277` plus the skill's per-file arguments. Record the asset ids in `art/office-kit/ASSET_IDS.md`. Put one master of each piece in `ServerStorage.OfficeKit` (Box collision or none per P6; RenderFidelity per P8; each a Package per P10).
- [ ] **Step 7: Commit the Blender sources**
  ```bash
  git add art/office-kit
  git commit -m "Art: Odd Hours office modular kit v1 sources and asset ids"
  ```

### Task 10: Dress, light and tag the hallway Office

Studio MCP; place content only.

- [ ] **Step 1: Replace the blockout's graybox walls, floors and ceilings with kit clones** (cloned from `ServerStorage.OfficeKit`, never re-imported; P3). Keep every tagged room, door, spot, dock and furniture box exactly where the harness put it. Do not move a tagged piece; if one must move, change the harness and re-run Task 5 Step 4 instead.
- [ ] **Step 2: Room identities (R1–R4, R8, W2–W4).** Per the report's room table, give each room one key colour, one hero silhouette, one light signature and one gag. Place a landmark at every hallway junction and a `← LOADING BAY` sign with a pictogram at decision nodes (W3). Use the existing furniture art for desks, lockers, tables, chairs and closets, each tagged `OfficeFurniture` / `OfficeChair` on its collision root. Clutter goes per R9 with collision off (L13, P6), keeping door frames clear.
- [ ] **Step 3: Lights (LT11–LT16, LT19).** Each fixture is a Neon bulb part plus a `SurfaceLight` or `PointLight` with Range 10–20 and `Shadows = false`, tagged `OfficeLight` with `OfficeLightEmitter` on the panel. At most 1–3 shadow casters (the corner office lamp). Corridors alternate lit pools and dark gaps, with objectives in pools. Exit signs are Neon plus a PointLight at Range 6–8. The truck bay is the brightest, warmest light, visible down a long sightline (W1). Place `OfficeAmbient` emitters (`phone` and `typing` at desks, `elevator` in the lobby).
- [ ] **Step 4: Place lighting settings (Shift place only).** In the Shift place's Lighting (Studio, not code; these are not scriptable): `LightingStyle = Soft`, `PrioritizeLightingQuality = on` (LT1), `EnvironmentDiffuseScale` / `SpecularScale` ≈ 0.2 (LT6), a `BloomEffect` (Threshold 0.92, Intensity 0.7, Size 24; LT8) and a `ColorCorrectionEffect` (Contrast 0.1, Saturation 0.1, Tint (225, 230, 255); LT7). No DepthOfField or SunRays (LT10). While only the Odd Hours place exists, skip this step: it would change the hub too. The code-owned Ambient and Exposure are Task 8's.
- [ ] **Step 5: Streaming check (P9).** Read `Workspace.StreamingEnabled` and the model streaming settings. If streaming is on, set each furnished room's furniture group to `ModelStreamingMode = Atomic`. Confirm in a Play that the transit cover lifts (Review Focus 1) with the map root not streamed out. If it is streamed out, stop and raise it with the owner (open question Q1) before going further.
- [ ] **Step 6: Validator pass.** Play. Output must show `office map: 0 errors` and every warning resolved or recorded as accepted in the harness comments. Delete the blockout leftovers.

### Task 11: Full-shift playtest (owner gate 5)

- [ ] **Step 1: Run the specs once more** (Studio test run). Expect `0 failed` at the expected count (3828 + 57).
- [ ] **Step 2: Solo full shift** (`RunTests = false`). Arrive in the truck → clean piles in at least 3 rooms → find a buried valuable → search a desk → bank at the truck → hide from the Manager in each hide kind → get caught once → meet quota → overtime sheet → clock out → results. Record the time from the farthest room to the truck at running speed (≤ 40 s, L8).
- [ ] **Step 3: 2-player Local Server** (Studio Test → Local Server, 2 players): the same loop. Teammates can find each other using the landmarks (W2), the Manager loses a player around a loop (L5) and at a hide, and nobody snags in a doorway.
- [ ] **Step 4: Readability check (LT23, LT24-lite).** At graphics quality 1 and 10 in Studio, every door, objective and hide is readable and wall/floor edges show in the darkest area.
- [ ] **Step 5: Owner gate 5.** Show the owner a short summary (what played, timings, issues) and screenshots of the lobby, the cubicle corridor, the server room and the corner office (R11 hero shots). On a yes, move the Launch Board's Office map rework item to **review**.

### Task 12: Log follow-ups

- [ ] **Step 1:** Add the follow-ups below to the Launch Board (todo) and to `docs/superpowers/handoffs/2026-10-18-first-launch-build-week-1.md` under a "Office map follow-ups" heading. Commit:
  ```bash
  git add docs/superpowers/handoffs/2026-10-18-first-launch-build-week-1.md
  git commit -m "Docs: log Office map follow-ups"
  ```

## Follow-ups (not this week)

- **F1 Polish rounds** with owner review, look and layout approved separately: kit variants (texture variants first), clutter vignettes (R9, R10), lore tiers (R6), the gloom pipeline (R7), glass for the conference room and corner office (R5; needs a sight rule for glass), thumbnails (R11).
- **F2 Lighting systems:** per-room light culling (LT17), a client brightness slider (LT22), gleam restoration when a room is cleaned (LT25), a player lantern (LT20), and a real low-end Android pass at quality 1, 3 and 10 (LT24, P11).
- **F3 Searched-state dressing for hand-built desks and lockers** (map mode skips `OfficeSearchedDressingSystem` today).
- **F4 Co-op way-back aid** at the ~90 % tier (W5) and teammate outlines (W7).
- **F5 Retire the generator** once the hand-built Office has passed a public test: remove `OfficeBuildSystem` / `OfficeDecorSystem` / generation utils and their specs, after owner approval.
- **F6 Map-design skill:** turn the report's [S] rules into hard checks and the [I] values into tunable defaults (the validator is its seed), run like the UI and VFX phases.

## Open questions

- **Q1 Streaming:** is `StreamingEnabled` on in the place? The client's `LayoutSeed` check reads Workspace children, so a streamed-out map root would hold the transit cover. A fix (e.g. a tiny persistent seed marker) would be a code change not planned here.
- **Q2 Glass (R5):** should the Manager see through glass walls? Today every queryable part blocks his sight.
- **Q3 Second storey:** the contract is single-floor (rooms on one floor height, E8). Is that right for launch?

## Coordinator decisions (2026-10-18)

- Single floor for week 1.
- Glass blocks the Manager's sight by default; a `SeeThrough` attribute marks clear windows he can see through.
- StreamingEnabled: check the place's Workspace setting in Studio (MCP) at the start of Task 6; if on, the map root must be persistent (ModelStreamingMode Persistent) before the transit wait.
