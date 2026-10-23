# odd-hours-b1 kit map

Kit: `ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]` (Shift place, not in Rojo). Built by
`AssembleKit.CommandBar.luau` (idempotent; rebuilds the folder each run). The kit holds only what it restyles:
`OfficeArtKeyUtils.attachFirst` falls back to `client-office-slate` for everything else (cargo, props, exitSign,
elevatorFront, ...). Stage 2 uploads (Task 4) are in: rows `t2_*` and `c_desk_nodivider` in `IDS`, plus the `OH_Vinyl` / `OH_Lino` MaterialVariants (see "Task 4 uploads" below).

Mesh templates: uploaded MeshPart (bbox-centred, no yaw baked in), seated on the pivot floor, SurfaceAppearance from the
decal-resolved colour/normal/rough images. Every mesh as imported faces -Z (checked by eye on a contact sheet), so
`FrontAxis = NegativeZ` everywhere and no part is rotated (a rotated part would make Stretch fit refuse non-uniform scale).

| Key | Family | Source | BaseSize | FrontAxis | FitMode | Status |
|---|---|---|---|---|---|---|
| floorTile | building | Part, Fabric + `OH_Carpet` | 4 x 0.092 x 4 | NegativeZ | Stretch | built |
| floorTile_hallway | building | same, Color 0.75,0.75,0.78 | 4 x 0.092 x 4 | NegativeZ | Stretch | built |
| ceilingTile | building | Part, Concrete + `OH_Ceiling` | 4 x 0.1 x 4 | NegativeZ | Stretch | built |
| wallSolid | building | Plaster body (`OH_Plaster`) + oak dado rail at 3.2 (`OH_Oak`) + dark skirting | 8 x 8 x 0.44 | NegativeZ | Stretch | built |
| fluorescent | building | metal housing + Neon diffuser + `surf troffer` colour as a Decal on the bottom face | 3.5 x 0.24 x 1 | NegativeZ | Stretch | built |
| floorTile_server | building | Plastic + `OH_Vinyl` slab | 4 x 0.092 x 4 | NegativeZ | Stretch | built |
| floorTile_breakout | building | Plastic + `OH_Lino` slab | 4 x 0.092 x 4 | NegativeZ | Stretch | built |
| doorLeaf | building | t2_doorLeaf 128086321055290 | 5.9 x 9 x 0.3 | NegativeZ | Stretch | built (hinge at local +X, see door note) |
| doorLeafGlass | building | t2_doorLeafGlass 121018102259344 (+ `Glass` piece: Material Glass, Transparency 0.5) | 5.9 x 9 x 0.3 | NegativeZ | Stretch | built (hinge at local +X, see door note) |
| desk | furniture | c_desk_nodivider 74890171416031 | 8.8 x 4.95 x 4.6 | NegativeZ | Stretch | built (no divider; hide space passes, see below) |
| officeChair | furniture | c_chair 76140780685205 | 2.71 x 4.60 x 2.79 | NegativeZ | Uniform | built |
| locker | furniture | c_lockers 80348717249179 | 6 x 8 x 2.52 | - | Uniform | HELD: bank of lockers != single searchable locker (marker is ~2.5 x 7 x 2.5, art would shrink to 0.42x; slate locker via fallback) |
| shelf | furniture | c_bookshelf 82298001439367 | 5.54 x 8 x 2.08 | NegativeZ | Uniform | built |
| kitchenCounter | furniture | c_coffeebar 132077928644424 | 8 x 6.35 x 3.08 | NegativeZ | Uniform | built, SupportSurfaceY = 4.60 (measured worktop) |
| corkboard | furniture | c_whiteboard 118580116232249 | 6.4 x 6.1 x 1.9 | NegativeZ | Uniform | built |
| breakTable | furniture | c_coffeetable 139831089082474 | 5 x 1.8 x 3 | NegativeZ | Uniform | built |
| conferenceTable | furniture | c_conftable 96816971294905 | 14 x 4.95 x 6 | NegativeZ | Uniform | built |
| receptionDesk | furniture | c_reception 87200857409958 | 12.86 x 4.6 x 5.16 | NegativeZ | Uniform | built |
| partition | furniture | c_partition 75231876449467 | 6 x 5 x 1.8 | NegativeZ | Uniform | built |
| sofa | furniture | r_sofa 124968857530240 | 7.64 x 3.50 x 3.62 | NegativeZ | Uniform | built |
| vending | furniture | r_vending 127404994422146 (colour map only) | 3.43 x 7.50 x 4.57 | NegativeZ | Uniform | built |
| waterCooler | furniture | c_cooler 108596742667007 (full maps; r_cooler has colour only) | 1.34 x 5 x 1.415 | NegativeZ | Uniform | built |
| copier | furniture | c_copier 138748993668815 | 4.6 x 4.6 x 3.28 | NegativeZ | Uniform | built |
| floorLamp | furniture | c_floorlamp 95651966049736 | 1.54 x 6.52 x 1.54 | NegativeZ | Uniform | built |
| planter | furniture | r_planter 115416560681395 (colour map only) | 4.06 x 5.97 x 3.92 | NegativeZ | Uniform | built |
| wasteBin | furniture | r_bin 88852446542319 (colour map only) | 1.85 x 2.0 x 1.86 | NegativeZ | Uniform | built |
| artFrame | furniture | d_artframe 136440655171491 | 4 x 3 x 0.27 | NegativeZ | Uniform | built |
| wallScreen | furniture | d_wallscreen 111518569613272 | 7 x 4 x 0.34 | NegativeZ | Uniform | built |
| sconce | furniture | d_sconce 95782564886770 | 0.88 x 1.05 x 0.98 | NegativeZ | Uniform | built |
| wallClock | furniture | d_wallclock 129091527121534 | 1.8 x 1.8 x 0.25 | NegativeZ | Uniform | built |
| deskPlant | furniture | r_deskplant 101911962938936 (colour map only) | 1.26 x 1.39 x 1.26 | NegativeZ | Uniform | built |
| serverRack | furniture | t2_serverRack 76858453551547 (+ `LED_Green/Amber/Blue` pieces: Neon, own colour) | 2 x 7 x 3.5 | NegativeZ | Uniform | built |
| supplyCabinet | furniture | t2_supplyCabinet 88586894738036 | 4.32 x 8 x 3.45 | NegativeZ | Uniform | built |
| stairwellSign | furniture | t2_stairwellSign 103288430156868 | 2 x 1 x 0.1 | NegativeZ | Uniform | built |
| exitSign, elevatorFront, cargo, props | - | not in this kit | - | - | - | slate fallback |

## Task 4 uploads (owner-approved batch 2026-10-22; Icey Labs group 189923277, all Approved)

6 models + 24 images. Images were created as Decals (type 13); the script resolves them to Image ids through
`InsertService:LoadAsset`, as in stage 1. Creator verified on economy.roblox.com (`CreatorTargetId 189923277`, "Icey Labs")
for serverRack (model, type 10), serverRack color, c_desk_nodivider and surf lino rough (type 13). Raw log:
`upload_log_stage2.jsonl` (also in the scratchpad `real/`).

| Asset | model | color | normal | rough |
|---|---|---|---|---|
| serverRack | 76858453551547 | 79134697329536 | 108106230649311 | 105815688686484 |
| doorLeaf | 128086321055290 | 126343314525764 | 76384627646625 | 70500544549300 |
| doorLeafGlass | 121018102259344 | 135379141376361 | 135630238974539 | 77112399835962 |
| supplyCabinet | 88586894738036 | 126150657377347 | 139489244266070 | 95122457736870 |
| stairwellSign | 103288430156868 | 133644663294809 | 73965497346519 | 113065990472125 |
| c_desk_nodivider | 74890171416031 | 81026453399291 | 78612349455668 | 93828460741235 |
| surf vinyl (floor) | - | 101900287489221 | 116209190833069 | 75027194809569 |
| surf lino (floor) | - | 121652013918684 | 113839306478006 | 128575032242313 |

MaterialVariants (MaterialService, resolved image ids, StudsPerTile 8, BaseMaterial Plastic):
`OH_Vinyl` = 72254599732798 / 104486307492802 / 105527373510920; `OH_Lino` = 82266988550517 / 116901973023085 / 119203464324229
(colour / normal / roughness). Floors: `proc.py vinyl` / `proc.py lino` (new kinds), `texstyle.py` classes `vinyl` / `lino`
(added to `style.json`; copies in `textures/`), `measure_one` PASS: vinyl lum_std 0.0298 fine 0.0149, lino 0.0158 / 0.0121.

Multi-object meshes: the script keeps every MeshPart of the import with its offset from the main piece. serverRack's `LED_*`
become Neon with their own colours (no SurfaceAppearance); the middle LED (`LED_Amber`) carries an Attachment `LedLight`.
`validateTemplate` rejects lights, so the blue PointLight (range 6, brightness 0.4) cannot live in a template: a runtime hook
must add it at that attachment. doorLeafGlass's `Glass` is Material Glass, Transparency 0.5.

FBX traps: the 180 deg yaw is already inside the imported part offsets (LEDs sit at -Z, X mirrored), so no part is rotated;
bbox-centring is handled by seating the main piece at (0, size.Y/2, 0) and keeping the other pieces' offsets from it.

Door hinge side (resolved): authored hinge on the leaf's -X edge, lever on +X. After the FBX yaw the imported leaf has the
LEVER at -X and the HINGE at +X (checked on the uploaded mesh through an EditableMesh: the lever/rose vertices that stand
proud of the slab have mean X = -1.75). Fixed in code: `OfficeDoorUtils.leafFrame` now hinges the proxy at local +X for
every door, horizontal or vertical (commit dfbc5803), so the lever never shows on the hinge side and no template change was
needed. The generated entrance facade is a double door: two 6-wide `doorLeafGlass` leaves side by side (the template is
5.9 wide, so Stretch stays near 1), each hinged at its outer edge (the left leaf is yawed half a turn so its local +X
points left).

## Coverage and validation report (script run in Edit)

```
built 33 (invalid 0), pending 0, held 1 (locker), failed 0
```

Every built template passes `ArtKitRules.validateTemplate` (required through a fresh `:Clone()` of the module).
Pending: none. Held: locker.

Live attach check (Edit, cloned `ArtVisualSystem`, proxies under a Model with `ArtKitId = "odd-hours-b1"`): `attach`
returned a visual for all 27 keys built in the first run (before desk and locker were held; the kit now has 33 built, the locker still held) (kitchenCounter set `ArtSupportSurfaceY`). exitSign / serverRack / doorLeaf
return nil from the kit (so the slate fallback / greybox applies). The test model and scratch parts were deleted;
nothing is left in Workspace.

## Desk hide-space measurement (`c_desk_nodivider`, desk is built)

`c_desk_nodivider` (rebuilt from the mock-room `c_desk` without the divider, `build_set_stage2.py`): 8.8 x 4.95 x 4.6, top
at 4.95 and underside at 4.67. Stretch to `DESK_SIZE` 8.25 x 4.95 x 4.95 gives scale (0.9375, 1.0, 1.076). Measured on the
uploaded mesh through an EditableMesh (face boxes scaled to DESK_SIZE; the old `GetPartBoundsInBox` search only sees a
MeshPart's bounds, so it was replaced in the script):

- Knee-hole (front is -Z): x -3.61..+1.64 = 5.25 wide (needs 3.6), underside 4.67 high (needs 4.2), z -2.48..+2.26 = 4.73 deep from the front (needs 4.3); the drawer pedestal is at +X, the leg panel at -X.
- Script: 54 placements of a 3.6 x 4.2 x 4.3 box (centres x -1.58..-0.33, z -0.32..0.08); max free height at that footprint 4.6; HideConstants' own free box (5.10 x 4.57 x 4.42) is free = true.
- Turntables: `turntables/c_desk_nodivider_{front,back,side,below,tq}.png`.

## Notes and captures

- Thin proxies shrink Uniform-fit art to the thinnest axis (e.g. corkboard base depth 1.9 vs proxy 0.5 scales it to
  0.26); the PROP_SIZES-style proxies for artFrame / wallScreen / sconce / wallClock / partition are fine only
  because those meshes are thin too. Check corkboard's marker size.
- vending, planter, wasteBin and deskPlant only have colour maps uploaded (no normal/rough); everything else has all three.
- wallSolid's dado rail is at 3.2 of an 8-high base; it scales with the wall height under Stretch.
- Captures (Studio MCP temp output, `C:\Users\Bruk Abu\.claude\projects\E--Projects\d1f6cb33-c53e-4180-8ef7-e885b69020d8\tool-results\`):
  `mcp-Roblox_Studio-blob-1792720627015-rpq86y.jpg` (template contact sheet 1), `...-1792720644156-pi5rie.jpg` (sheet 2),
  `...-1792720648740-cheba5.jpg` (sheet 3), `...-1792720638290-wna80d.jpg` (desk / locker / chair close-up),
  `...-1792720670671-9aqgzc.jpg` (attached wall, floors, ceiling), `...-1792720676003-0gqm1f.jpg` (attached troffer),
  `...-1792720679337-5elevv.jpg` (attached furniture, desk stretched).
- The owner saves the place (Ctrl+S); nothing was saved or published.

## Fix round 1

- desk and locker are held in the script (`HELD` table; remove an entry to rebuild it, e.g. once a no-divider desk id replaces c_desk). Re-run result: built 25, pending 7, held 2, failed 0; `furniture/desk` and `furniture/locker` are absent from the kit.
- Proportion mismatches (corkboard, counter, tables vs their proxies) are solved in code by Task 5, which adds `ART_SIZES` so the proxy follows the art's BaseSize; templates are left unchanged.
