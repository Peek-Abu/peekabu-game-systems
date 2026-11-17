# Script snapshots (Showstopper remake, 2026-11-16; texture round and SmartBone, 2026-11-17)

Copies of the scripts that built and gated the shipped Showstopper Prickles remake. The live originals sit in the
untracked main-checkout folder
`E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake/` (`$SSR`). Use the
originals when they exist (they may be newer). These copies are here so the recipe survives if that folder is lost.

They are **Showstopper-shaped**: absolute paths to `route2_whole/`, `../showstopper_tails/` and the hat file, Prickles'
proportions, and piece names (SSR_*). For a new skin, copy them into the new skin's build folder and change the paths,
pieces and numbers. Do not edit `$SSR` while a skin session is working in it.

| Script | Step | Run |
|---|---|---|
| `ss_blockout.py` | blockout from the concept, flat colours | `blender -b --disable-autoexec -P ss_blockout.py -- <dir>` |
| `ss_robe.py` | one robe: grid, lapel fold, cloth-sim skirt, closed sleeves/bloomers, head clamp | `... -P ss_robe.py -- <dir> [k=v]` |
| `run3.sh` | blockout -> robe -> renders -> pose demo -> hole gate | `bash run3.sh <dir> [k=v]` |
| `head_gate.py` | 0 vertices inside the head | `... -P head_gate.py -- <dir>` |
| `ss_export_remake.py` | weights (incl. crouch `UP0 UP1 SIDEB T1`), colour `PLUM=`, swatch texture, FBX | `... -P ss_export_remake.py -- <dir> [k=v]` |
| `gate_holes.py` + `gate_check.py` | 16-view hole gate | `... -P gate_holes.py -- <dir> [pose]`, `python gate_check.py <dir> [pose]` |
| `pose_set_a3.py` | pose set from the LIVE clips -> `pose_a3.json` | see its header |
| `pose_gate.py` | every-keyframe clipping on the exported outfit | `POSESET=pose_a3.json ... -P pose_gate.py -- <dir>` |
| `sleeve_gate.py` | sleeve points inside chest pieces (read with a render) | `POSESET=... -P sleeve_gate.py -- <dir>` |
| `idle_clip_probe.py` | plain character's arms inside his own body | `... -P idle_clip_probe.py -- <out.json> [Clip]` |
| `place_remake.luau` | places the outfit Model in Studio Edit (never saved) | Studio MCP `execute_luau`, with a slot |
| `ss_bloomer_shell.py` | (texture round) three overlapping bloomer pieces -> one closed shell, one colour | `... -P ss_bloomer_shell.py -- <src_dir> <dst_dir>` |
| `tex_prep.py` + `tex_bake.py` + `ss_export_tex.py` | (texture round) scan ratio maps + violet hat; real UVs, baked colour/normal/roughness per mesh | `py -3.9 -I tex_prep.py <tex> <hat.png>`; `... -P ss_export_tex.py -- <dir> [k=v]` |
| `fbx_notex.py` | the upload FBX without embedded textures (maps ship as images) | `blender -b <dir>/export/export_final.blend -P fbx_notex.py -- <out.fbx>` |
| `ride_chains.py` | (SmartBone) skirt chains on top of the weights, thigh share, vent split, lapel fringe, collider sizes -> `sb3.json` | `blender -b <export_final.blend> -P ride_chains.py -- <out> KF=0.45 KS=0.35 KB=0.35 LAPK=0.6` |
| `place_v3.luau` | (SmartBone) places the live V3 outfit: textures, chains, end markers, SmartColliders, Tail* settings | Studio MCP `execute_luau`, with a slot |

Not copied (they live elsewhere, untracked): `idle_arms.py`, `render_idle.py`, `preview_server.luau` and the clip
re-pose tools in `characters/prickles/idle-arms-2026-11-16/`; `create_model.py` and `gait_all.py` in
`../showstopper_tails/`; `patch_model.py` in `../lc_pilot/tools/`.
