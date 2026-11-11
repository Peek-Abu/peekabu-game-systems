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
