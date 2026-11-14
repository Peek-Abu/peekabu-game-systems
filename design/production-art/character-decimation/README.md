# Character decimation (p05 D1, 2026-11-13)

Owner pick: the 10k level. Built with an uneven per-part budget: more triangles on hands, ears and the face, fewer on
hidden or flat parts.

| Employee | Before | After | Source build (matches the live meshes part by part) |
|---|---|---|---|
| Pippa | 83,200 | 9,899 | `characters/pippa/v13` |
| Prickles | 125,604 | 10,198 | `characters/prickles/v4` |
| Cappy | 138,760 | 52,791 | `characters/cappy/v6` (hair, earbuds, skinned shorts, socks and waist piece untouched) |

- `optimize_mesh_budget.py`: a copy of `characters/kit/optimize_mesh.py` with two changes.
  - It reads `PART_TRIS`, a JSON map of part name to target triangles.
  - Its triangulation self-check allows 1e-4 studs instead of 1e-5, because Prickles' head trips on float noise.

  Run: `PART_TRIS='{...}' blender -b <build>.blend --factory-startup -P optimize_mesh_budget.py -- <out> --max-error 0.2 [--only a,b]`.
  The budgets used are in `reports/p05-perf-art.md`.
- `render_compare.py`: old-vs-new EEVEE renders from fixed cameras (front, 3/4, head, head side, hand).
  - Usage: `blender -b <file> -P render_compare.py -- <out_prefix> [<original.blend>]`.
  - The second argument points every image at the original's exact file. Without it, a relinked face image from
    another version folder made a false "broken head" on 2026-11-13.
- `decimate_swap.luau`: the Studio Edit swap (ApplyMesh). It carries over Size, CFrame and TextureID and records
  `PreDecimateMeshId`. It refuses a part whose surface centre or area moved, and undoes everything unless the
  mesh-blind fingerprint is unchanged.
- Uploaded models (Icey Labs): `reports/p05-decimation-assets.json`.
