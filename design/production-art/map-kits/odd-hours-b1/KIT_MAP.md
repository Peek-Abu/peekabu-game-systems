# odd-hours-b1 kit map

Kit: `ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]` (Shift place, not in Rojo). Built by
`AssembleKit.CommandBar.luau` (idempotent; rebuilds the folder each run). The kit holds only what it restyles:
`OfficeArtKeyUtils.attachFirst` falls back to `client-office-slate` for everything else (cargo, props, exitSign,
elevatorFront, ...). Re-run the script after adding the Task 2 ids (rows `t2_serverRack`, `t2_supplyCabinet`,
`t2_stairwellSign`, `t2_doorLeaf`, `t2_doorLeafGlass` in `IDS`) and the `OH_Vinyl` / `OH_Lino` MaterialVariants.

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
| floorTile_server | building | `OH_Vinyl` slab | - | - | - | pending (MaterialVariant not made; Task 4) |
| floorTile_breakout | building | `OH_Lino` slab | - | - | - | pending (MaterialVariant not made; Task 4) |
| doorLeaf | building | Task 2 mesh | - | - | - | pending upload (Task 4) |
| doorLeafGlass | building | Task 2 mesh | - | - | - | pending upload (Task 4) |
| desk | furniture | c_desk 127882537035090 | 8.8 x 6.69 x 4.6 | NegativeZ | Stretch | built, FAILS hide space (see below) |
| officeChair | furniture | c_chair 76140780685205 | 2.71 x 4.60 x 2.79 | NegativeZ | Uniform | built |
| locker | furniture | c_lockers 80348717249179 | 6 x 8 x 2.52 | NegativeZ | Uniform | built |
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
| serverRack | furniture | Task 2 mesh | - | - | - | pending upload (Task 4) |
| supplyCabinet | furniture | Task 2 mesh | - | - | - | pending upload (Task 4) |
| stairwellSign | furniture | Task 2 mesh | - | - | - | pending upload (Task 4) |
| exitSign, elevatorFront, cargo, props | - | not in this kit | - | - | - | slate fallback |

## Coverage and validation report (script run in Edit)

```
built 27 (invalid 0), pending 7, failed 0
```

Every built template passes `ArtKitRules.validateTemplate` (required through a fresh `:Clone()` of the module).
Pending: floorTile_server, floorTile_breakout, doorLeaf, doorLeafGlass, serverRack, supplyCabinet, stairwellSign.

Live attach check (Edit, cloned `ArtVisualSystem`, proxies under a Model with `ArtKitId = "odd-hours-b1"`): `attach`
returned a visual for all 27 built keys (kitchenCounter set `ArtSupportSurfaceY`). exitSign / serverRack / doorLeaf
return nil from the kit (so the slate fallback / greybox applies). The test model and scratch parts were deleted;
nothing is left in Workspace.

## Desk hide-space measurement (the one failure)

`c_desk` as uploaded: 8.8 x 6.69 x 4.6. Its worktop is at Y 4.95, the underside of the top at Y 4.67, and a green
privacy divider rises to Y 6.69 at the back. Stretch fit maps the whole bounds (divider included) onto
`DESK_SIZE` 8.25 x 4.95 x 4.95, so the scale is (0.9375, 0.740, 1.076): the underside drops to about 3.46 studs.

- Height free under the top at DESK_SIZE: about 3.46 (needs 4.2) -> FAIL (short by ~0.74).
- Depth: the modesty panel sits at z about +2.26 of a 4.95 desk, so about 4.7 free from the front (needs 4.3) -> ok.
- Width: knee-hole spans x about -3.7..+1.9 (the drawer pedestal is at +X, like the slate desk) = about 5.6 (needs 3.6) -> ok.
- Script search: 0 placements of a 3.6 x 4.2 x 4.3 box anywhere; HideConstants' own free box (5.10 x 4.57 x 4.42) blocked.

Cause is only the divider in the Y stretch: without it the mesh is 4.95 tall (underside 4.67), scale Y becomes 1.0
and the free height is 4.67 (>= 4.2). Fixes, none done here: re-export `c_desk` without the divider (separate mesh),
or let the desk proxy be taller than 4.95. Until then keep the slate desk for hide-critical maps, or delete
`furniture/desk` from the kit (the fallback then uses the slate desk).

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
