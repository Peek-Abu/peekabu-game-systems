# Odd Hours yard dressing (Y3)

Design and owner picks: `docs/superpowers/specs/2026-11-04-yard-place-design.md`. Concepts: `yard_scene.jpg`, `yard_props.jpg`.

## Props (hand-built, texture-pipeline kit, no AI meshes)
- `build_yard.py`: one prop per name in Blender 5.1 headless (`wheeliebin:blue`, `car:red` pick a paint variant).
  Materials are procedural except the pallet and bench (the styled Wood049 oak scan, `TEXPIPE_WORK`). Bakes go to
  `out/` (colour x AO, tangent normal, roughness, `_parts.glb`, `_tt.glb`); not committed.
- `to_fbx_yard.py`: `_parts.glb` -> `export/*.fbx`, keeping the Glass, Glow and Hazard pieces apart (not committed).
- `present.py`: the real-scale look sheets (5.5-stud figure). Owner sheets: `turntables/yard_props_sheet.jpg`
  (props: approved 2026-11-05), `turntables/yard_cars_critters_v2.jpg` (cars v2: approved 2026-11-05). The critters
  were cut by the owner on 2026-11-05.

## Uploads
Icey Labs (group 189923277) only, via `publishing-roblox-assets/publish.py --key-env ICEY_LABS_OPEN_CLOUD_KEY
--group 189923277`. `upload_manifest.json` lists every asset, `upload_batch1.json` the approved first batch,
`upload_log.jsonl` the results (52 + the firefly sprite test, all Approved, owner verified).
`fill_ids.py` writes the log's ids into the placement script's `IDS` and `SPRITES` tables.

## Placement (Shift place, Edit)
`PlaceYardDressing.CommandBar.luau` builds `Workspace.YardDressing` (one ChangeHistory step; rebuilds the folder):
Dock, Walk, Verges (Grass parts for the footstep layer, tufts, bushes, fireflies), Moths, Cars, Booth (desk radio),
Plaza, SoundEmitters (`OfficeAmbient` + `AmbientKind`
at the design doc's Y3b spots). It marks every OfficeExterior puddle `FootstepSurface = "puddle"` and `CanQuery = true`
(the footsteps' downward ray skips CanQuery-off parts). It fails if a prop lands on the walk (x 1158..1178), the size-B
truck (x 1155.7..1180.3, z -299.2..-256.8) or within 3 studs of the time clock (1154, -266).
The cars are skipped until their mesh is in `IDS`.

Gotcha: the imported MeshParts carry a rotated PivotOffset. Move a placed prop by its parts' CFrames; a
`Model:PivotTo(fresh CFrame)` tips it over.
