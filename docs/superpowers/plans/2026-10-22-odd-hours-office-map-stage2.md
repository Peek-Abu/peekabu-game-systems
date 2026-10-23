# Office Map Stage 2: The B1 Art Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The generated office stops looking drab. Every greybox piece the stage-1 generator builds gets the mock room's approved finish (S2 clean + S1 moody), and each room type gets its own identity.

**Architecture:**
- **Reuse the existing art system.** `ArtVisualSystem.attach(root, family, key)` already swaps a greybox proxy for a template from `ReplicatedStorage.Assets.CleanupCrew.ArtKits/<kitId>/<family>/<key>`, and falls back to greybox when a key is missing. Stage 2 adds a new kit, `odd-hours-b1`, which generated layouts select.
- **Art lives in the Studio place**, assembled by a command script from the mock room's uploaded Icey Labs assets plus a few new hand-built props.
- **Three small code changes:**
  - kit markers can name their own art key (server racks, conference table, sofa…);
  - a new art-only `prop` marker kind for room dressing;
  - per-room-type keys and lighting.

**Tech Stack:** Luau `--!strict` (TestEZ specs in Studio), headless Blender 5.1 + the `texture-pipeline` skill (`hardlib.py`/`build_set.py`), Open Cloud uploads via `publish.py`, the Studio MCP for assembly.

**Spec:** `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md`, goal 11 and the "Order of work" line ("then art for the remaining kits"). The mock-room look approved on 2026-10-22 (`Workspace.ClaudeMockRoom` in the Shift place) is the visual reference.

## Global Constraints

- Everything in stage 1's Global Constraints still binds: `--!strict`, no `any`/casts, spec-first, plain commits staged by name, no push, no wally/rokit/rojo build/check.sh, no checkout/reset/stash, never stage someone else's SpecRoots hunk, specs run in Studio Play by the controller.
- **Art never goes into Rojo.** Kit templates live in the Shift place at `ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]`.
  - The assembly script is source and lives in `design/production-art/map-kits/odd-hours-b1/`.
- **Every template passes `ArtKitRules.validateTemplate`:**
  - `RuntimeApproved = true`, Archivable, positive `BaseSize` matching the geometry bounds;
  - bottom-centred pivot;
  - only Part/MeshPart/Model/Folder/Attachment/SurfaceAppearance/Decal/Texture descendants;
  - no tags;
  - `FrontAxis` set;
  - building templates are Stretch-fit.
  - Surfaces use the MaterialVariants already in MaterialService (`OH_Plaster`, `OH_Oak`, `OH_Carpet`, `OH_Ceiling`) via the `MaterialVariant` property, never a MaterialVariant child.
- **Uploads only to Icey Labs** (`publish.py … --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277`). Never use group 9738205. **Every upload batch needs the owner's OK**, which is the stop point in Task 4.
- **Style (owner):**
  - simple shapes with drawn detail, not ultra-detailed models;
  - every surface carries colour, normal and roughness;
  - windows never show the outside;
  - no faces on Gloom art.
- **Hide sizing:** the desk template must keep `HideConstants.HUG_FREE_MIN` (3.6 W × 4.2 H × 4.3 D) under it at the proxy size `OfficeConstants.DESK_SIZE` (8.25 × 4.95 × 4.95). The furniture grows; characters never shrink.
- **The stage-1 bar still holds:** the full suite is green, and `OfficeTraversalHarness` seeds 1–20 pass with every door closed after kits gain props.
- **Shift length is 8:30** (`SHIFT_SECONDS = 510`); this stage doesn't change the economy.

## Rulings made while planning

- **One kit, keyed by name.** The generator sets `layout.artKit = OfficeConstants.GENERATED_ART_KIT = "odd-hours-b1"`. The authored boot layout keeps `client-office-slate`. Cargo and desk props keep resolving from the slate kit: `attach` walks up to the office model's `ArtKitId`, so the new kit must also hold the cargo/props keys. The assembly script copies the slate kit's `cargo` and `props` folders into the new kit unchanged.
- **Room identity through art keys, not new gameplay.** `Marker.art: string?` names the template key for that marker's furniture; it falls back to the kind's default key. Server racks stay `shelf` markers with `art = "serverRack"`; the conference table is `table` + `art = "conferenceTable"`.
- **Dressing props are a new marker kind `prop`.** It is art-only and gameplay ignores it. Footprints come from `OfficeConstants.PROP_SIZES[art]`. Props over 1 stud tall collide, as `shelf` does.
- **Per-room-type surfaces:** `attach` is tried with `<key>_<roomType>` first, then `<key>` (e.g. `floorTile_server` = vinyl tiles, `floorTile_breakout` = lino). Corridors use `_hallway`.
- **Doors get art:** `building/doorLeaf` (solid) and `building/doorLeafGlass` are attached to the door leaf proxies. The visual is welded to the leaf, so it swings with it.
- **New hand-built props this stage:** `serverRack`, `doorLeaf`, `doorLeafGlass`, `supplyCabinet` (tall), `stairwellSign`. Everything else comes from the mock room's 31 uploaded models.

## Review Focus

- **A prop marker that makes a room or patrol point unreachable.** Pinned by re-running `OfficeTraversalHarness` seeds 1–20 in Task 6, plus `OfficeKitRules` aisle checks on every new prop footprint.
- **The desk template shrinking the hide space.** Pinned by a Task 3 check: the attached desk's underside clearance at proxy size ≥ HUG_FREE_MIN.
- **Missing keys silently showing greybox.** Pinned by Task 3's coverage check: every key the Office requests for `odd-hours-b1` resolves to a valid template.
- **Door art not following the swing, or blocking the doorway.** Pinned by Task 5's live check: the leaf visual moves with the leaf, stays non-colliding, and the closed-door harness is unchanged.
- **Glass or a window showing the void outside.** Pinned in stage 1 (pane clipping). Task 6 adds a visual sweep of every pane in 3 seeds.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Utils | OfficeArtKeyUtils | The template keys to try for a piece: marker override, room-type variant, default |

No other new modules: the build and decor systems gain calls, and the registry, types and constants gain fields.

---

### Task 1: Art keys in the layout (code)

**Files:**
- Modify: `Office/Data/OfficeTypes.luau`: `KitMarker.art: string?`, `Marker.art: string?`, and `"prop"` added to `MarkerKind`.
- Modify: `Office/Utils/OfficeKitUtils.luau`, which copies `art`.
- Modify: `Office/Data/OfficeConstants.luau`: `GENERATED_ART_KIT = "odd-hours-b1"` and `PROP_SIZES: { [string]: Vector3 }` for every prop key in Task 3's list.
- Create: `Office/Utils/OfficeArtKeyUtils.luau` and its spec.
- Modify: `Office/Rules/OfficeKitRules.luau` and `OfficeLayoutRules.luau`: `prop` footprints count as furniture (overlap, walls, door approach, pile clearance).
- Modify: `Office/Utils/OfficeLayoutGenerationUtils.luau`, which sets `layout.artKit`.
- Modify: `Office/Systems/OfficeBuildSystem.luau` and `OfficeDecorSystem.luau`.
  - Every `attach` call goes through `OfficeArtKeyUtils.candidates` and tries each key in turn.
  - `prop` markers build an art-only root (destroyed if no template, like decor's `artOnly`).
  - Door leaves attach `doorLeaf` / `doorLeafGlass`.
- Modify: `Art/Data/ArtKitRegistry.luau`: register the kit `odd-hours-b1` and the new keys.

**Interfaces:**
- `OfficeArtKeyUtils.candidates(defaultKey: string, override: string?, roomType: string?): { string }`: returns `{ override, defaultKey .. "_" .. roomType, defaultKey }`, skipping nils and duplicates, in that order.
- `OfficeArtKeyUtils.attachFirst(art: ArtVisualSystem.Controller, root: BasePart, family: ArtTypes.Family, keys: { string }): Model?`: the first non-nil `attach`.

- [ ] **Step 1: Write the failing specs.**
  - `candidates("desk", nil, nil)` → `{"desk"}`.
  - `candidates("floorTile", nil, "server")` → `{"floorTile_server", "floorTile"}`.
  - `candidates("shelf", "serverRack", "server")` → `{"serverRack", "shelf_server", "shelf"}`.
  - The `OfficeKitUtils` spec: a kit marker with `art = "sofa"` places with `art == "sofa"`.
  - The `OfficeKitRules` spec: a `prop` with `art = "sofa"` overlapping a desk fails with `overlaps`.
  - The `OfficeBuildSystem` spec (stub art assets as the existing spec does):
    - a `prop` marker with a template builds an `ArtVisual`;
    - a `prop` marker without one leaves no root;
    - a solid door's leaf gets the `doorLeaf` template;
    - a room with `roomType = "server"` uses `floorTile_server` when present and `floorTile` otherwise.
- [ ] **Step 2:** The controller runs the specs: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** The controller runs the full suite: PASS, unchanged look (the new kit doesn't exist yet, so everything falls back to greybox). Commit: `Office: art keys per marker, prop dressing markers, room-type art variants, door leaf art`.

### Task 2: New hand-built props (Blender)

**Files:** `F:/Dev/temp/…/scratchpad/hard/build_set.py` (scratch; a copy of the final script also goes to `design/production-art/map-kits/odd-hours-b1/build_set.py`).

Build with `hardlib` (`@prop` functions), checking each with `turntable.py` (front, back, side, below, three-quarter):
- `serverRack` (2 × 7 × 3.5, matte charcoal, drawn LED strips + vents on the front, under 6,000 tris);
- `doorLeaf` (5.9 × 9 × 0.3 office door: oak veneer, kick plate, handle drawn plus a simple lever);
- `doorLeafGlass` (same frame, centre glass panel transparent via the colour map's alpha);
- `supplyCabinet` (4.32 × 8 × 3.45 tall steel cabinet with two doors, the existing `CLOSET_SIZE`; a hide spot, so the inside is open enough);
- `stairwellSign` ("FLOORS 2–14" plate, 2 × 1 × 0.1).

- [ ] Build all five, run `measure_one.py` on their colour maps (calm PASS), and save turntables to `design/production-art/map-kits/odd-hours-b1/turntables/`.
- [ ] Export FBX via `real/to_fbx.py` (the 180° yaw and bbox-centring traps are documented in the texture-pipeline skill's ship section).

### Task 3: Assemble the kit in Studio (art + check script)

**Files:**
- Create: `design/production-art/map-kits/odd-hours-b1/AssembleKit.CommandBar.luau`. It is run in Edit via the Studio MCP and is idempotent: it rebuilds the kit folder from scratch.
- Create: `design/production-art/map-kits/odd-hours-b1/KIT_MAP.md`: key → source asset id, BaseSize, FrontAxis, FitMode.

The kit's key list:

| Family | Key | Source |
|---|---|---|
| building | floorTile | `OH_Carpet` slab (Part, MaterialVariant) |
| building | floorTile_server | vinyl tile slab (new proc `tile` texture → MaterialVariant `OH_Vinyl`; upload in Task 4) |
| building | floorTile_breakout | lino slab (`OH_Lino`, Task 4) |
| building | floorTile_hallway | darker carpet (`OH_Carpet` with Color tint) |
| building | ceilingTile | `OH_Ceiling` slab |
| building | wallSolid | `OH_Plaster` body + oak dado rail + skirting strip (3 Parts) |
| building | fluorescent | `surf troffer` panel |
| building | doorLeaf / doorLeafGlass | Task 2 meshes |
| building | exitSign | copy from slate |
| furniture | desk | `c_desk`, Stretch to DESK_SIZE proportions |
| furniture | officeChair | `c_chair` |
| furniture | locker | `c_lockers` |
| furniture | shelf | `c_bookshelf` |
| furniture | serverRack | Task 2 |
| furniture | kitchenCounter | `c_coffeebar` (SupportSurfaceY at its worktop) |
| furniture | corkboard | `c_whiteboard` |
| furniture | breakTable | `c_coffeetable` |
| furniture | conferenceTable | `c_conftable` |
| furniture | receptionDesk | `c_reception` |
| furniture | supplyCabinet | Task 2 |
| furniture | elevatorFront | copy from slate |
| furniture | partition | `c_partition` |
| cargo, props | (all) | copied from the slate kit |
| furniture (prop) | sofa, vending, waterCooler, copier, floorLamp, planter, wasteBin, artFrame, wallScreen, sconce, wallClock, deskPlant | `r_sofa`, `r_vending`, `r_cooler`/`c_cooler`, `c_copier`, `c_floorlamp`, `r_planter`, `r_bin`, `d_artframe`, `d_wallscreen`, `d_sconce`, `d_wallclock`, `r_deskplant` |
| building | stairwellSign | Task 2 |

Each template:
- a Model holding the uploaded MeshPart (InsertService:LoadAsset of the model id, with SurfaceAppearance from the decal→image ids, exactly as `real/make_real.lua` does);
- re-centred so its bounds sit bottom-centred on the pivot (apply the stage-0 bbox and yaw fixes);
- `BaseSize` = bounds, `RuntimeApproved = true`, `FrontAxis` checked by eye against −Z;
- `FitMode = "Stretch"` only for the desk and building pieces.

- [ ] **Step 1:** Write the script. It also prints a coverage report:
  - every key in the table resolves;
  - every template passes `ArtKitRules.validateTemplate` (require it in the command bar on a fresh module clone, since Edit caches requires);
  - the desk at DESK_SIZE leaves ≥ HUG_FREE_MIN under its top (measure the template's underside gap × scale).
- [ ] **Step 2:** Run it in the Shift place (Edit). Iterate until the report is all-green, then paste the report into `KIT_MAP.md`.
- [ ] **Step 3:** The owner saves the place (Ctrl+S). Commit the script and `KIT_MAP.md`: `Art: odd-hours-b1 kit assembly script and map`.

### Task 4: Uploads (STOP for the owner's OK)

- [ ] List the batch: the 5 Task-2 FBX meshes plus their colour, normal and roughness maps, and the `OH_Vinyl` and `OH_Lino` texture sets (proc `tile`, styled through `texstyle.py`, `measure_one` PASS). Give the count and file sizes. **Ask the owner and wait for a clear yes.**
- [ ] Upload with `publish.py` to group 189923277, verify the creator, and record the ids in `KIT_MAP.md`. Re-run Task 3's script so these keys stop showing greybox.

### Task 5: Dress the kits (code)

**Files:** `Office/Data/OfficeKitRegistry.luau` (+ spec), `Office/Data/OfficeConstants.luau` (`PROP_SIZES` values).

Per kit, add `art` overrides and `prop` markers, keeping every existing gameplay marker:

| Kit | Overrides | Props (at least) |
|---|---|---|
| pods_a | | copier, planter, wasteBin ×2, artFrame, partition ×2 |
| pods_b | | waterCooler, wasteBin, deskPlant on 2 desks (desk-top props stay decor) |
| conference_a / _b | table → `conferenceTable` | wallScreen, artFrame, planter (a only) |
| breakout_a | table → `breakTable`, counter → `kitchenCounter` | sofa, vending, waterCooler, floorLamp, wallClock |
| storage_a | | wasteBin, sconce |
| server_a | shelf → `serverRack` (all 3) | sconce, wasteBin |
| reception_a | counter → `receptionDesk` | sofa, planter ×2, artFrame, wallClock |

- [ ] **Step 1:** Write the failing specs: each kit has at least the listed props and overrides, and every kit still passes `OfficeKitRules` in all facings and mirrors.
- [ ] **Step 2:** Author the coordinates against wall-hugging (`ArtWallMounted` for frames, screens, sconces and clocks at wall height; the rest on the floor, clear of aisles ≥ 4 studs). Re-run `chk.py` with prop footprints.
- [ ] **Step 3:** The controller runs the suite plus the traversal harness for seeds 1–20 (all doors closed): PASS. Commit: `Office kits: room dressing and per-type furniture art`.

### Task 6: Atmosphere per room type (code)

**Files:** `Office/Data/OfficeConstants.luau` (`ROOM_LIGHT: { [string]: { color: Color3, brightness: number, spacing: number } }`), and `OfficeBuildSystem.luau`, which uses it for each room's lights (fallback: the current values).

Values (S1 moody):

| Room | Colour | Brightness | Spacing |
|---|---|---|---|
| hallway | (200, 214, 240) | 0.35 | 18 |
| pods | (215, 228, 255) | 0.5 | 15 |
| conference | (255, 236, 210) | 0.45 | 15 |
| breakout | (255, 222, 180) | 0.55 | 15 |
| storage | (230, 230, 220) | 0.3 | 15 |
| server | (150, 190, 255) | 0.4 | 15, plus a blue PointLight on each rack (decor) |
| reception | (255, 240, 220) | 0.6 | 15 |

- [ ] **Step 1:** Write the failing spec: a server room's lights use the server colour, and an unknown room type uses the defaults.
- [ ] **Step 2:** Implement. The controller runs the suite: PASS. Commit: `Office: per-room-type lighting`.

### Task 7: Look check and owner review

- [ ] The controller builds seeds 3, 7 and 11 in Play (streamed around the camera) and captures, per seed:
  - a corridor;
  - the atrium;
  - one room of each type;
  - a glass conference front;
  - a dead-end cupboard.

  Check: no greybox left where a key should resolve, no clipping, panes never show the void, doors swing with their art. Fix through the owning task.
- [ ] Send the owner the captures and ask for a play-check. Stage 2 is done only after the owner's look.
