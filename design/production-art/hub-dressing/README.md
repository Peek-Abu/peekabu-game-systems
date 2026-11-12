# Odd Hours depot hub (Night Garage) dressing

- `build_hub.py`: hand-built props on the yard kit (`../yard-dressing/build_yard.py` materials and helpers), Blender 5.1 headless.
  Props: `pumpkin:round|tall|squat`, `leafpile:a|b` (drift, scatter), `tree` (autumn maple), `pendant` (caged garage lamp),
  `wallpack` (wall light). Env `HUB_OUT` = output folder; `TEXPIPE_WORK` as the texture pipeline.
- `to_fbx_hub.py`: `_parts.glb` -> FBX (Glow / Glass / Hazard pieces keep their names).
- `upload_batch.json` / `upload_log.jsonl`: the 2026-11-11 upload (owner OK via the coordinator), 8 meshes + 24 maps,
  Icey Labs (group 189923277) only, every asset checked group-owned and Approved.

Placed in the lobby place (Studio art, `Workspace.DepotHub`): pumpkins and leaves under `Dressing/Autumn`, garage lamps and wall
lights under `Lights` (they carry the old fixtures' lights), the maples and `Yard/YardLife` (yard-kit bushes, grass, cars,
dumpster, barriers, outside wall lights, fireflies) under `Yard`, and `Training/TrainingTruck` (a 0.5-scale clone of
`Assets.CleanupCrew.Truck` with the band livery and TRAINING signs). Placing a loaded mesh: its parts' CFrames are relative to
the authored floor origin, so `cf * (part.CFrame.Rotation + part.CFrame.Position * k)` with `Size * k`.

## Pumpkins v2 (2026-11-11, owner OK)
The vine leaf's veins/stalk (`vleaf_veins`) were never moved with the leaf, so they sat inside the pumpkin, and the leaf
cut into the ribs. `build_hub.py` now moves both and seats them rigidly on the skin (`_drape`). Re-uploaded to Icey Labs
and swapped into the lobby's 14 pumpkins in place (MeshPart:ApplyMesh, scale and CFrame kept; SurfaceAppearance maps):

| Variant | Model | Mesh | Color / Normal / Rough (image ids) |
|---|---|---|---|
| round | 118435555682999 | 77809726577446 | 99998307521436 / 74155896689065 / 131731772303976 |
| tall | 139682393289774 | 132186097936997 | 97822968756899 / 91975468946512 / 122189962640296 |
| pale (squat) | 103333606513045 | 124424530913187 | 109552291066008 / 130340302459288 / 128424890770824 |

## Radio and shift bell v2 (2026-11-11, look sheet only, nothing uploaded)
Office procedure. Texture pass: ambientCG Metal048C (brass) and PaintedMetal012 (chipped paint) through new
`brass` / `paint` style classes (owner OK for the two downloads); wood is the oak scan. Model pass: `build_hub.py`
props `radio` (1.9 x 0.95 x 1.35, oak cabinet, cream front, brass slats over a dark cloth, dial, knobs, handle,
antenna), `bellpost` (teal post, base plate, collar, arm and yoke) and `bell` (brass bell, pivot at its pin, hangs
from the yoke at (0, -0.85, 4.1)); `radio_bell_look.py` renders them. When swapped into the hub: the radio mesh must be
named `RadioBody` (the music notes emit from it) and the bell parts keep `DepotSwing` + the `BellPivot` attachment.
Sheet: notes `hub-r3-radio-bell-v2-look.jpg`.
