# Office Map: Match the Generator to the Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every generated office looks and feels like the approved spike (`Workspace.ClaudeSpike`): open 14/10 halls, 13-stud ceilings, plaster-and-oak walls with clean corners, framed glass, a ceiling grid with troffers, one warm light recipe, dressed halls and spike-sized rooms. The building stays about today's size.

**Architecture:**
- **Two pure modules plan the geometry:**
  - `OfficeShellUtils`: wall slabs, wainscot/rail/skirt runs, door casings, framed glass, ceiling grid, as boxes in layout space.
  - `OfficeLightingUtils`: troffer panels, fill lights and hall sconce spots per room, from one recipe table.
- **One new system, `OfficeShellVisualSystem`, turns those boxes into Parts** with MaterialVariants (plain-material fallback). `OfficeBuildSystem` hands it the walls, ceilings, lights, glass and door headers it builds itself today.
- **Generator changes are constants plus the kit catalogue:**
  - corridor widths, lattice, room count;
  - the kits resized to the spike;
  - one new pass that adds hall-dressing prop markers.
- **New art pieces** (troffer, rug, window bay, column, reception glow) become odd-hours-b1 kit templates in the Shift place, added by command-bar script. No uploads: they're clones of already-uploaded mock-room assets.

**Tech Stack:** Luau `--!strict`, TestEZ specs (Studio Play only), the Studio MCP for the place work, Rojo (already serving on port 34872).

**Spec:**
- `docs/superpowers/specs/2026-10-23-odd-hours-office-map-spike-delta-design.md` (this work; read it first);
- its parent `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md`;
- `HANDOFF-office-map-2026-10-23.md` (the spike's values and the Studio state).

The spike builder `design/production-art/map-kits/odd-hours-b1/spike/BuildSpike.CommandBar.luau` is the visual and numeric reference. Where this plan says "as the spike", read that file.

## Global Constraints

- `--!strict`, no `any`, no casts. Spec-first: every new module gets a `.spec.luau` sibling before its implementation. Specs are untyped.
- **Commits:** plain messages, **no trailers** (AGENTS.md overrides any attribution reminder). Stage files by name. Never push.
- **Never stage the `src/ServerScriptService/Core/Testing/SpecRoots.luau` hunk.** It's someone else's uncommitted change.
- No wally, rokit, `rojo build` or `scripts/check.sh` while the owner is connected. No git checkout, reset or stash in this worktree. `selene` / `stylua --check` on touched files are fine.
- **Specs run only in Studio Play**, by the controller:
  - set Workspace attribute `RunTests = true` in the "Odd Hours: Shift" window (studio_id `197d004d-31af-4c67-abfe-2cc4a86884ee`);
  - before Play, take the lock `docs/superpowers/studio-playtest-shift.lock` (only if absent; never touch `studio-playtest.lock`);
  - delete the lock after.
  - Edit-mode `require` caches modules, so don't trust it.
- **Art never goes into Rojo.**
  - Templates live at `ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]`.
  - Every template passes `ArtKitRules.validateTemplate`: no lights inside a template. Lights hang on named Attachments and the code adds them.
  - Studio changes go through a command-bar script kept in `design/production-art/map-kits/odd-hours-b1/`, recorded in `KIT_MAP.md`.
- **No uploads in this plan.** If one turns out to be needed, stop and ask the owner. Uploads go only to group 189923277, never 9738205.
- No computer-use on the owner's screen. Touch only the Odd Hours / Shift Studio windows.
- **Spike values, exact:**
  - **Heights and halls:** `WALL_HEIGHT` 13; `CORRIDOR_WIDE` 14; `CORRIDOR_NARROW` 10; junction/atrium ≥ 20.
  - **Wall build:**
    - each wall is two 0.5 plaster slabs from Y −1 to `WALL_HEIGHT` + 1;
    - wainscot 3 tall, 0.3 proud; rail 0.25 tall × 0.5 deep on top of the wainscot; skirt 0.6 tall, 0.4 proud.
  - **Doors:** rough opening `door.width` × `DOOR_HEIGHT` 9.4 with a 0.35 oak casing; wide open archways get 0.6 plaster pilasters.
  - **Glass:** Glass, Transparency 0.6, tinted like the mock's `ConfGlassZ`; 0.4 mullions about every 6 studs; base rail 0.35 tall; 0.6 end frames.
  - **Ceiling:** grid strips 0.15 × 0.08 every 4 studs, 0.04 under the ceiling.
  - **Colours:** panel colour (255,240,220); fill colour (255,232,205).
- **Size gates, every seed 1–20:**
  - mean floor area (rooms and hallways, bay excluded) within ±30 % of `TARGET_FLOOR_AREA` 24,300;
  - every room within 640 studs of walking from the bay;
  - ≥ 8 hide spots;
  - the contract guarantee holds.
  - If they conflict, walking, hide spots and the contract win, and area gives way (report it).
- **Keep:**
  - door hinge at local +X, the occluder rules, Mr. Harlow's door beat;
  - depth by walk distance;
  - `ART_SIZES` / `markerSize`, the default-kit fallback, `surfaceTopFor`;
  - `HUG_FREE_MIN` under desks.
- **Light density:** a generated office's light count per 1,000 square studs of floor must not exceed the spike's (measured in Task 8).

## Review Focus

1. **A place without the MaterialVariants or templates** (CI test place, unsaved place): the office still builds with plain Plaster/Wood/Glass and greybox proxies, without erroring. Test in Task 3.
2. **Inside corners and T-joints:** the trim from two walls meeting at a room corner or a corridor T leaves no gap and no visible overlap past the far face. Test in Task 2 ("trim closes inside corners").
3. **Harlow's tells and overtime on the new lights:**
   - every lit panel and every fill is tagged `OfficeLight`;
   - the overtime red paint and the flicker still reach a SurfaceLight, not only a PointLight.
   - Tests in Task 3 and Task 1.
4. **Hall dressing that pinches a path:**
   - a 10-wide hall keeps ≥ 7 studs clear;
   - nothing stands within 3 studs of a door casing or junction mouth;
   - collidable dressing stands ≥ 12 studs apart on a wall.
   - Tests in Task 7, plus the traversal harness in Task 8.
5. **The same seed must build the same office:** lit/unlit panels and hall dressing are deterministic from seed and position. Tests in Task 1 and Task 7.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Utils | `OfficeShellUtils` | Pure: the boxes (slabs, trim, casings, framed glass, ceiling grid) a wall, door, pane or room's ceiling is built from. |
| Office | server | Utils | `OfficeLightingUtils` | Pure: the troffer panels, fill lights, hall sconce spots and accent lights per room type, from `OfficeConstants.LIGHTING`. |
| Office | server | Utils | `OfficeHallDressingUtils` | Pure: the prop markers (sconces, art, plants, benches) a generated hallway gets, within the clearance rules. |
| Office | server | Systems | `OfficeShellVisualSystem` | Builds the shell boxes and lights as tagged Parts under the office model, with MaterialVariant fallback. |

Module removed: `OfficeDoorwayVisualSystem` (+ spec), if nothing but `OfficeBuildSystem` requires it after Task 3. Its trim is replaced by `OfficeShellUtils.doorCasing`. Run `python3 scripts/python/module_map.py --write` after Tasks 1–3 and 7.

Shared type used by Tasks 1–3 (declare it in `OfficeTypes`):

```luau
-- A box of the building shell in layout space, finished by an OfficeConstants.SHELL_MATERIALS key.
export type ShellMaterial = "plaster" | "oak" | "skirt" | "frame" | "glass" | "ceiling" | "grid"
export type ShellBox = { name: string, size: Vector3, cframe: CFrame, material: ShellMaterial, collide: boolean }
```

---

### Task 1: The lighting plan (`OfficeLightingUtils`)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeLightingUtils.luau`, `OfficeLightingUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`: add `LIGHTING`, `PANEL_COLOR`,
  `FILL_COLOR`, `ACCENT_LIGHTS`. (Task 3 removes `ROOM_LIGHT`, `LIGHT_SPACING`, `LIGHT_SIZE`, `LIGHT_COLOR`,
  `LIGHT_RANGE`, `LIGHT_BRIGHTNESS`, `SERVER_LED_*` and `BOARD_CENTER_HEIGHT` goes in Task 5.)
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau` (the `ShellBox` types above, plus `LightPanel`, `FillLight`).

**Interfaces:**
- Produces:
  - `type LightPanel = { x: number, z: number, lit: boolean, rotated: boolean, brightness: number }`
  - `type FillLight = { position: Vector3, brightness: number, range: number, color: Color3, shadows: boolean }`
  - `OfficeLightingUtils.roomLights(room: OfficeTypes.Room, roomType: string?): { panels: { LightPanel }, fills: { FillLight } }`
  - `OfficeLightingUtils.sconceSpots(room: OfficeTypes.Room): { { x: number, z: number, side: "minX" | "maxX" | "minZ" | "maxZ" } }`: the hall fill spots, on the wall each fill hangs beside.
  - `OfficeLightingUtils.accentFor(attachmentName: string): { brightness: number, range: number, color: Color3 }?`
  - `OfficeConstants.LIGHTING: { [string]: { panelBrightness: number, panelRange: number, allLit: boolean, fillBrightness: number, fillRange: number } }`, keyed by `OfficeArtKeyUtils.roomType` (`"hallway"` for corridors). An unknown type uses `pods`.

Recipe values (from the spike):

| key | panelBrightness | panelRange | allLit | fillBrightness | fillRange |
|---|---|---|---|---|---|
| hallway | 0.2 | 14 | true | 1.3 | 12 |
| pods, breakout, reception | 0.22 | 14 | false | 1.7 | 11.5 |
| conference | 0.22 | 14 | false | 1.5 | 11.5 |
| server | 0.12 | 14 | false | 0.6 | 10 |
| storage | 0.15 | 14 | true | 0.8 | 10 |

`ACCENT_LIGHTS`:

| Attachment name | Brightness | Range | Colour |
|---|---|---|---|
| `LedLight` | 0.4 | 6 | (120,170,255) (today's server LED) |
| `ScreenLight` | 0.7 | 6 | (190,215,255) |
| `GlowLight` | 1.6 | 11 | (255,200,140) |
| `LampLight` | 1.6 | 11 | (255,168,90) |

Accent lights cast no shadows.

Placement rules (the spike's `roomPanels` and hall loops):
- **Hallway** (`roomType == "hallway"`; its run axis is the longer side, x for a square):
  - panels on the centre line every 8 studs, starting 4 in from the run's start; `rotated` for z-runs; all lit.
  - fills every 16 studs starting 8 in, alternating sides, 3 studs off the wall, at Y 5.
  - `sconceSpots` returns the same spots, on the wall each fill hangs beside.
- **Rooms:**
  - panels on a centred grid of `nx = max(1, round(W/12))` × `nz = max(1, round(D/10))` at 12 × 10 spacing;
  - with `allLit` false, a panel is lit unless `(i + 2j) % 3 == 1` (≈ 2/3 lit, no randomness);
  - fills on a centred grid of `max(1, round(W/22))` × `max(1, round(D/18))` at Y 4.
- Only fills cast shadows.

- [ ] **Step 1: Write the failing spec** `OfficeLightingUtils.spec.luau`:
  - "hall panels every 8, all lit": a 14×80 x-run gives 10 panels, all `lit`, all `rotated == false`, z at the centre line, brightness 0.2.
  - "hall fills alternate sides every 16 at Y 5": the same run gives 5 fills, sides alternating, each 3 studs inside a wall, `position.Y == 5`, brightness 1.3, range 12; `sconceSpots` matches fills one to one.
  - "z-run panels are rotated": a 10×64 run gives panels with `rotated == true`.
  - "room panels ≈ 2/3 lit, the spike's pattern": a 60×44 pods room gives 5×4 = 20 panels, 13 lit by the `(i + 2j) % 3 ~= 1` rule, brightness 0.22; a 12×12 storage room gives 1 panel, lit, brightness 0.15.
  - "deterministic": the same room twice gives identical lists.
  - "only fills cast shadows; colours are the warm pair": every fill `shadows == true`, colour `FILL_COLOR`.
  - "accentFor": `ScreenLight` gives brightness 0.7 / range 6; an unknown name gives nil.
  - "unknown room type falls back to pods".
- [ ] **Step 2: Controller runs the suite in Play.** Expected: the new spec fails (module missing).
- [ ] **Step 3: Implement** `OfficeLightingUtils` and the new constants. Leave the old light constants in place; Task 3 deletes them once `OfficeBuildSystem` no longer reads them.
- [ ] **Step 4: Run.** Expected: `OfficeLightingUtils.spec` all pass.
- [ ] **Step 5: Commit** `Office lighting plan: spike recipe for troffers, fills, hall sconces and accents`.

### Task 2: The shell geometry (`OfficeShellUtils`)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeShellUtils.luau`, `OfficeShellUtils.spec.luau`
- Modify: `OfficeConstants`:
  - `WALL_HEIGHT = 13`;
  - `DOOR_HEIGHT = 9.4`;
  - `SHELL = { slab = 0.5, slabOverhang = 1, wainscotHeight = 3, wainscotProud = 0.3, railHeight = 0.25, railDepth = 0.5, skirtHeight = 0.6, skirtProud = 0.4, casing = 0.35, pilaster = 0.6, mullion = 0.4, mullionSpacing = 6, glassFrame = 0.6, baseRail = 0.35, gridSpacing = 4, gridWidth = 0.15, gridThickness = 0.08 }`;
  - `SHELL_MATERIALS: { [ShellMaterial]: { material: Enum.Material, variant: string?, color: Color3, transparency: number } }`, mapping:
    - plaster → `OH_Plaster`; oak → `OH_Oak`; ceiling → `OH_Ceiling`;
    - skirt, frame and grid → the spike's `MAT.skirt` / `MAT.frame` / `MAT.grid` values;
    - glass → the spike's glass at Transparency 0.6.

**Interfaces:**
- Consumes: `OfficeTypes.ShellBox`, `OfficeTypes.Segment`, `Door`, `Room`.
- Produces (all in layout space, Y 0 = floor top):
  - `OfficeShellUtils.wall(segment: Segment, first: number, last: number): { ShellBox }`. `first` / `last` are how far the run extends past each end: `WALL_THICKNESS / 2` at a corner, 0 at a door or pane, the same values `OfficeBuildSystem`'s `endcap` computes today.
  - `OfficeShellUtils.doorCasing(door: Door, edge: "minX" | "maxX" | "minZ" | "maxZ"): { ShellBox }`
  - `OfficeShellUtils.glassPane(pane: Segment): { ShellBox }`
  - `OfficeShellUtils.ceiling(room: Room): { ShellBox }`: the ceiling slab plus grid strips.

Rules:
- **A wall:**
  - two plaster slabs, each `slab` thick, side by side, from Y −1 to `WALL_HEIGHT + 1`, collide;
  - on **both** faces: wainscot, a rail on top of it, and a skirt, all non-colliding.
  - Each trim run extends past a corner end by its own proud depth, so two runs meeting at an inside corner close. At a door end (`first`/`last` 0) trim stops flush.
- **A door casing** (kind solid or glass): two jambs and a head of oak `casing` thick, inside the rough opening, proud `casing` on both faces. An `open` doorway wider than 8 gets plaster pilasters (0.6) at both jambs instead.
- **A glass pane:**
  - frame ends (`glassFrame`, frame material);
  - mullions evenly spaced, with gaps no wider than `mullionSpacing`;
  - a base rail (`baseRail` tall);
  - glass from the base rail to `WALL_HEIGHT − 0.5`, collide, material glass.

- [ ] **Step 1: Write the failing spec** `OfficeShellUtils.spec.luau`:
  - "a wall is two slabs from −1 to WALL_HEIGHT + 1": a 20-long x segment with ends 0.5/0.5 gives 2 plaster boxes 21 × 15 × 0.5, centred 0.25 either side of the line, Y centre 6.5, `collide == true`.
  - "trim on both faces": the same wall gives 2 wainscot (3 tall, 0.3 deep, outer face 0.3 proud), 2 rails (0.25 × 0.5, top at Y 3.25), 2 skirts (0.6 tall, 0.4 proud), none colliding.
  - "trim closes inside corners": two walls meeting at an L, each ended 0.5 at the corner. On the inside face, the wainscot boxes' footprints overlap (no gap) and neither reaches past the other wall's outer face.
  - "trim stops flush at a door": `first == 0` gives trim starting exactly at the segment's x1.
  - "casing": a 6.8-wide solid door gives 3 oak boxes; clear width 6.8 − 0.7 = 6.1; head bottom at 9.4 − 0.35 = 9.05.
  - "a wide open archway gets pilasters": a 14-wide open door gives 2 plaster pilasters, no oak.
  - "framed glass": a 22-long pane gives 2 end frames, mullions with every gap ≤ 6, 1 base rail 0.35 tall, glass top at 12.5, glass `collide == true`.
  - "ceiling grid every 4": a 12×12 room gives 1 ceiling slab and (2 + 2) strips, 0.15 × 0.08, at Y `WALL_HEIGHT − 0.04`.
- [ ] **Step 2: Run.** Expected: fails (module missing).
- [ ] **Step 3: Implement** `OfficeShellUtils` and the constants.
- [ ] **Step 4: Run.** Expected: `OfficeShellUtils.spec` all pass.
- [ ] **Step 5: Commit** `Office shell geometry: spike walls, trim, casings, framed glass, ceiling grid`.

### Task 3: Build the shell (`OfficeShellVisualSystem`) and hand it the old wall/light code

**Files:**
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeShellVisualSystem.luau`, `OfficeShellVisualSystem.spec.luau`
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau`:
  - lines 141–206 (ceiling and lights) → shell system;
  - 244–284 (walls, glass) → shell system;
  - 286–321 (door frames and headers) → casing and header via shell system.
  - The floor stays, minus `floorTile` stretching: floors take `SHELL_MATERIALS` carpet/lino/vinyl by room type, as the spike's `floor` field does.
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeDoorSystem.luau`: the leaf is the clear opening, `door.width − 2 × casing` by `DOOR_HEIGHT − casing`.
- Modify: `src/ReplicatedStorage/Client/Features/Office/Systems/OfficeAtmosphereSystem.luau:paint`: `FindFirstChildWhichIsA("Light")` instead of `FindFirstChildOfClass("PointLight")`, so overtime red reaches a SurfaceLight.
- Modify: `OfficeBuildSystem.spec.luau`. Its "ceiling lamp coverage" test goes; Task 1's spec owns light placement now.
- Delete (if unused): `OfficeDoorwayVisualSystem.luau` + spec.

**Interfaces:**
- Consumes: Task 1 `roomLights`, `accentFor`; Task 2 `wall`, `doorCasing`, `glassPane`, `ceiling`.
- Produces: `OfficeShellVisualSystem.build(layout: OfficeTypes.Layout, origin: CFrame, model: Model, art: ArtVisualSystem.Controller): ()`. It builds folders `Shell` (walls, glass, casings, ceilings) and `Lights` under `model`.

Rules:
- A box's Part takes `SHELL_MATERIALS[material]`. Set `MaterialVariant` only if `MaterialService` has a variant of that name, else plain material and colour.
- **A troffer panel:**
  - a Part, tagged `OccupantConstants.LIGHT_TAG` when lit;
  - visual from `OfficeArtKeyUtils.candidates("troffer", nil, roomType)` (lit and unlit share the template; an unlit one gets no light and Neon off);
  - a lit panel gets a `SurfaceLight` (Face Bottom, `panelBrightness`, `panelRange`, `PANEL_COLOR`, Shadows false) and an emitter part with attribute `OfficeLightEmitter = true`;
  - no template → a 4 × 0.2 × 2 greybox Neon panel.
- **A fill:** an invisible 0.2 anchor Part (no collide, query or touch), tagged `LIGHT_TAG`, holding the PointLight.
- **The bay and the authored boot layout get the same shell** (both run through `OfficeBuildSystem`).
- The old wall/ceiling/fluorescent art keys stop being used. The `opaqueBacking` cores go: the slabs are opaque.

- [ ] **Step 1: Write the failing spec** `OfficeShellVisualSystem.spec.luau`, building a small two-room layout plus a corridor with a fake art controller that attaches nothing:
  - "builds every wall as slabs and trim": counts match `OfficeShellUtils` output; slabs collide; trim doesn't.
  - "falls back to plain material without the MaterialVariants": with none registered, every Part's `MaterialVariant == ""` and its Material is the table's.
  - "tags every lit panel and every fill, never an unlit panel": tagged count == lit panels + fills.
  - "a lit panel carries a SurfaceLight with the recipe values; fills carry shadowed PointLights".
  - "the bay gets the shell": the bay room has slabs and panels.
  - In `OfficeDoorSystem`'s spec (or the build spec): "a leaf fills the clear opening": leaf size 6.1 × 9.05 for a 6.8 door.
- [ ] **Step 2: Run.** Expected: new specs fail.
- [ ] **Step 3: Implement**, then delete the moved code from `OfficeBuildSystem` and the old light constants. Run `module_map.py --write`.
- [ ] **Step 4: Run the whole suite in Play.** Expected: 0 failed. Then run the traversal harness (`OfficeTraversalHarness.run({1..20}, CFrame.new(5000,1,5000))` from the Server datamodel). Expected: 0 failures. (Wider door casings must not break a path.)
- [ ] **Step 5: Commit** `Office shell: spike walls, casings, framed glass, ceiling grid and warm troffer light replace stretched templates`.

### Task 4: New kit templates in the Shift place (Studio, controller)

**Files:**
- Create: `design/production-art/map-kits/odd-hours-b1/AddSpikeTemplates.CommandBar.luau`
- Modify: `design/production-art/map-kits/odd-hours-b1/KIT_MAP.md`, `AssembleKit.CommandBar.luau` (so a full rebuild includes them).

**Interfaces:**
- Produces these templates under `ArtKits["odd-hours-b1"]`, keys exactly:
  - `building/troffer`: the mock `CeilingPanel` without its SurfaceLight, with an emitter part attributed `OfficeLightEmitter`.
  - `props/rug`: the mock `Rug`.
  - `props/windowBay`: the mock `c_windowbay` with blinds. Opaque; shows no outside.
  - `props/column`: a 2 × 13 × 2 OH_Plaster column with oak skirt.
  - `props/receptionGlow`: the mock `ReceptionPanel`/Glow, with a `GlowLight` Attachment.
  - A `LampLight` attachment added to `props/floorLamp`, and a `ScreenLight` attachment to the monitor template.

Each passes `ArtKitRules.validateTemplate`: no lights, bottom-centre pivot, `BaseSize` = bounds, `FrontAxis`.

- [ ] **Step 1:** Check `Workspace.ClaudeMockRoom` still holds the source parts (`CeilingPanel`, `Rug`, `c_windowbay`, `ReceptionPanel`). If any is missing, stop and report.
- [ ] **Step 2:** Write the script. It clones, strips lights, sets attributes and parents into the kit. Run it in the Shift window via the Studio MCP `execute_luau`.
- [ ] **Step 3:** In Play, require `ArtKitRules` and validate each new template. Expected: all pass.
- [ ] **Step 4:** Record the keys and sizes (each `BaseSize`) in `KIT_MAP.md`, and add matching `PROP_SIZES` entries: `rug`, `windowBay`, `column`, `receptionGlow`. Ask the owner to **save the place (Ctrl+S)**.
- [ ] **Step 5: Commit** the script and `KIT_MAP.md`: `odd-hours-b1: troffer, rug, window bay, column and reception glow templates from the mock room`.

### Task 5: Kits at the spike's sizes, accent lights, floor-standing whiteboard

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeKitRegistry.luau` (+ its spec), `OfficeConstants.luau` (`PROP_SIZES`), `OfficeBuildSystem.luau` (board Y; accent lights).
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeFurniturePlacementUtils.luau:42` (the board overlap test assumed a wall height).

Kit sizes and contents. Translate the spike's rooms from world to kit-local, keeping desk fronts to open floor, aisles ≥ 4 and the door approach clear:

| Kit | Size | From the spike | Notes |
|---|---|---|---|
| `pods_a` | 60×44 | `OpenPlan` block: 3 pods = 12 desks, 2 `column` props, rug + `corkboard` standing, copier, shelf, planters, `windowBay` on the back wall | |
| `pods_b` | 44×32 | 2 pods = 8 desks, rug, standing `corkboard`, cooler, planter | |
| `pods_c` | retired | (my call: medium covers it) | |
| `conference_a` | 32×24 | keeps its size | framed glass front |
| `conference_b` | 22×18 | spike `Conference` | glass front with the door in it (`glass` span) |
| `breakout_a` | 32×26 | spike `Breakout` | |
| `server_a` | 20×18 | spike `ServerRoom` | |
| `storage_a` | 12×12 | spike `Storage` | keeps its closet |
| `reception_a` | 28×28 | spike `Reception` | `receptionGlow` prop |

- Kit door widths become 6.8 (rough opening).
- Each kit still gives ≥ the pile/item markers its type had per 100 square studs, so the contract roll holds with fewer rooms.

- **Whiteboard:** a `board` marker stands on the floor. Its centre is `size.Y / 2`, its art on its own legs. `BOARD_CENTER_HEIGHT` goes.
- **Accent lights:** wherever `OfficeBuildSystem` or `OfficeDecorSystem` attaches a template, any Attachment named in `ACCENT_LIGHTS` gets a PointLight from `OfficeLightingUtils.accentFor`. This replaces the `LedLight`-only code.

- [ ] **Step 1: Update the specs first.**
  - `OfficeKitRegistry.spec`: "kits match the spike's sizes" (the table above); "pods_a holds 12 desks, pods_b 8"; "no pods_c". The existing every-facing/mirror validation stays.
  - Build spec: "a board stands on the floor" (bottom at Y 0); "every ACCENT_LIGHTS attachment gets its light" (a fake template with `ScreenLight` gets brightness 0.7).
- [ ] **Step 2: Run.** Expected: those fail.
- [ ] **Step 3: Implement** the kits, the board rule and accent lights.
- [ ] **Step 4: Run** the suite (expected 0 failed) and the traversal harness for seeds 1–20 (expected 0 failures).
- [ ] **Step 5: Commit** `Office kits at the spike's sizes: 60x44 and 44x32 pods, standing whiteboard, accent lights`.

### Task 6: Generator scale: wide halls, fewer bigger rooms

**Files:**
- Modify: `OfficeConstants.luau`:
  - `CORRIDOR_WIDE = 14`, `CORRIDOR_NARROW = 10`, `ATRIUM_SIZE` ≥ 20 (keep 26 unless area needs it);
  - `LATTICE_STEP_X` / `LATTICE_STEP_Z`, `LATTICE_COLS` / `ROWS`, `LATTICE_JITTER` (lower, so runs stay straight), `ROOM_MARGIN`;
  - `KIT_ROOMS = { min = 6, max = 12 }`, `KIT_WEIGHTS` re-weighted for 2 pods kits.
- Modify: `OfficeLayoutGenerationUtils.spec.luau`. "holds 14-20 kit rooms" becomes "holds `KIT_ROOMS.min`–`max`", and the other gates stay as they are.
- Modify: `OfficeCorridorUtils.spec.luau` (widths).

**Interfaces:** none new. Everything downstream reads the constants.

- [ ] **Step 1:** Change the specs' fixed numbers to the constants above. Add a spec "every corridor run is 14 or 10 wide and every junction ≥ 20".
- [ ] **Step 2:** Tune the lattice and margin constants until, over seeds 1–20 in Play, all of these hold:
  - the area test (±30 % of 24,300, halls included);
  - walk ≤ 640;
  - hide ≥ 8;
  - "rolls spawns that meet the biggest crew's contract";
  - "passes every layout rule";
  - deep and shallow loot;
  - the new width spec.

  Start from step 84 × 76 and a 4 × 3 lattice. If area and walking can't both hold, keep walking and report the area.
- [ ] **Step 3: Run** the suite (0 failed) and the traversal harness for seeds 1–20 (0 failures).
- [ ] **Step 4: Write `reports/office-spike-match-measure.md`.** Per seed: room count, floor area, longest walk (studs and seconds), hide spots, total Gloom. Then the means against the targets.
- [ ] **Step 5: Commit** `Office generator at spike scale: 14/10 halls, fewer bigger rooms, same building size` (with the report).

### Task 7: Hall dressing (`OfficeHallDressingUtils`)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeHallDressingUtils.luau`, `OfficeHallDressingUtils.spec.luau`
- Modify: `OfficeLayoutGenerationUtils.luau`: after kits and doors are placed, append the dressing markers to `layout.markers` with the generator's seeded RNG.

**Interfaces:**
- Consumes:
  - `OfficeLightingUtils.sconceSpots(room)`;
  - the layout's doors, facades and junctions;
  - `PROP_SIZES` (`sconce`, `artFrame`, `wallClock`, `planter`, `sofa` as the bench).
- Produces: `OfficeHallDressingUtils.dress(room: Room, layout: Layout, rng: Random): { OfficeTypes.Marker }` (kind `prop`, `art` set, `room` = the hallway's id).

Rules:
- A `sconce` on every sconce spot that isn't within 1 stud of a door's casing (as the spike).
- Then, along each long wall, alternating:
  - an `artFrame` about every 20 studs;
  - a `planter` or `sofa` bench, standing within 1.5 studs of the wall, ≥ 3 studs from any door casing or junction mouth, ≥ 12 studs from the previous collidable prop on that wall.
- At most one `wallClock` per run.
- Junctions get a planter or `waterCooler` in a corner.
- Wall props never cover a door or facade (`OfficeLayoutRules` already checks this).

- [ ] **Step 1: Write the failing spec:**
  - "keeps 7 clear in a 10-wide hall": no collidable prop's footprint reaches more than 3 studs off its wall.
  - "nothing within 3 of a door or junction mouth".
  - "collidable props ≥ 12 apart per wall".
  - "a sconce on each free sconce spot".
  - "same seed, same dressing".
  - "every generated layout still passes `OfficeLayoutRules` with dressing" (seeds 1–20).
- [ ] **Step 2: Run.** Expected: fails.
- [ ] **Step 3: Implement** and wire into the generator. Run `module_map.py --write`.
- [ ] **Step 4: Run** the suite (0 failed) and the traversal harness for seeds 1–20 (0 failures).
- [ ] **Step 5: Commit** `Office halls dressed like the spike: sconces, art, plants and benches with clear lanes`.

### Task 8: Verify against the spike, then hand to the owner

**Files:**
- Modify: `reports/office-spike-match-measure.md` (light density, captures).
- Modify: `HANDOFF-office-map-2026-10-23.md` (status line only).

- [ ] **Step 1: Light density.**
  - Count PointLight + SurfaceLight under `Workspace.ClaudeSpike` per 1,000 square studs of its floor.
  - Do the same for generated seeds 1–20.
  - Expected: every seed ≤ the spike. If not, light hall panels every other one (`hallway.allLit` false with a 1-in-2 rule) and re-run Task 1's spec.
- [ ] **Step 2: Side-by-side captures.** For seed 1 in Play, capture the same views as the spike's (`01_main_hallway` … `07_reception`): main hall, junction, open plan, conference glass from the hall, breakout, server, reception. Save them to `design/production-art/map-kits/odd-hours-b1/spike-match/`. Lighting only shows in Play.
- [ ] **Step 3:** Send the owner the captures and the measure report (SendUserFile).
- [ ] **Step 4: Owner play-check.** It includes one session on a phone and a second client. Note their verdict in the report. **Only the owner's OK makes this done.**
- [ ] **Step 5: After the OK,** ask the owner to remove `Workspace.ClaudeSpike` and `ClaudeSpikeSpawn` (or remove them via the Studio MCP with their OK), then save the place.
- [ ] **Step 6: Commit** `Office spike match: measured, captured, owner play-checked`.
