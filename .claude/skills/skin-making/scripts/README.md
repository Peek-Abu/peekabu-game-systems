# Script snapshots (Showstopper remake 11-16, texture round 11-16, SmartBone 11-17; Bell Jester gear 11-12)

Copies of the scripts that built, gated and shipped Showstopper Prickles (and the fitted-gear placer from Bell Jester
Pippa). The live originals sit in the untracked main-checkout folder `$SSR`
(`E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake/`, see
[../odd-hours.md](../odd-hours.md)). Use the originals when they exist (they may be newer). These copies are here so
the recipe survives if that folder is lost.

They are **Showstopper-shaped**: absolute paths to `route2_whole/`, `../showstopper_tails/` and the hat file, Prickles'
proportions, piece names (SSR_*), asset ids. For a new skin, copy them into the new skin's build folder and change the
paths, pieces, ids and numbers. Never edit `$SSR` while a skin session works in it. The `.luau` files run through
Studio MCP `execute_luau` in Edit, with a slot, and are never saved into a place.

| Script | Step | Run |
|---|---|---|
| `ss_blockout.py` | blockout from the concept, flat colours | `blender -b --disable-autoexec -P ss_blockout.py -- <dir>` |
| `ss_robe.py` | one robe: grid, lapel fold, cloth-sim skirt, closed sleeves/bloomers, head clamp | `... -P ss_robe.py -- <dir> [k=v]` |
| `run3.sh` | blockout -> robe -> renders -> pose demo -> hole gate | `bash run3.sh <dir> [k=v]` |
| `head_gate.py` | 0 vertices inside the head | `... -P head_gate.py -- <dir>` |
| `ss_export_remake.py` | weights (incl. crouch `UP0 UP1 SIDEB T1`), colour `PLUM=`, swatch texture, FBX (shape rounds) | `... -P ss_export_remake.py -- <dir> [k=v]` |
| `gate_holes.py` + `gate_check.py` | 16-view hole gate | `... -P gate_holes.py -- <dir> [pose]`, `python gate_check.py <dir> [pose]` |
| `pose_set_a3.py` | pose set from the LIVE clips -> `pose_a3.json` | see its header |
| `pose_gate.py` | every-keyframe clipping on the exported outfit (maps EVERY `Tail*` bone to LowerTorso, rigid: in your copy map `TailU*` to UpperTorso) | `POSESET=pose_a3.json ... -P pose_gate.py -- <dir>` |
| `sleeve_gate.py` | sleeve points inside chest pieces (read with a render) | `POSESET=... -P sleeve_gate.py -- <dir>` |
| `idle_clip_probe.py` | plain character's arms inside its own body | `... -P idle_clip_probe.py -- <out.json> [Clip]` |
| `ss_bloomer_shell.py` | (texture round) overlapping pieces of one garment -> one closed shell, one colour | `... -P ss_bloomer_shell.py -- <src_dir> <dst_dir>` |
| `tex_prep.py` | (texture round) scan ratio maps + HSV recolour of a prop's own texture (violet hat) | `py -3.9 -I tex_prep.py <tex> <hat.png> [VIOLET=hex]` |
| `tex_bake.py` + `ss_export_tex.py` | (texture round) real UVs, baked colour / normal / roughness per mesh | `... -P ss_export_tex.py -- <dir> [weights k=v] [PLUM=hex] [RES=1024]` |
| `fbx_notex.py` | the upload FBX without embedded textures (maps ship as images) | `blender -b <dir>/export/export_final.blend -P fbx_notex.py -- <out.fbx>` |
| `fbx_nudge_lower.py` | (fetch failure fix) moves one hidden vertex 0.0001 so the mesh gets a NEW id, writes the no-texture FBX | `blender -b <dir>/export/export_final.blend -P fbx_nudge_lower.py -- <out.fbx>` |
| `ride_chains.py` | (SmartBone) chains on top of the weights, thigh share, vent split, lapel fringe, `SURFACE=1`, collider sizes -> `sb3.json` | `blender -b <export_final.blend> -P ride_chains.py -- <out> KF=0.45 KS=0.35 KB=0.35 LAPK=0.6 [SURFACE=1]` |
| `create_model.py` | NEW group model asset from an FBX (key from env, never printed) | `python create_model.py <fbx> <name> <desc>` |
| `patch_model.py` | new revision of an existing model asset, same id | `python patch_model.py <assetId> <fbx>` |
| `place_remake.luau` | places an outfit Model (meshes in a Folder, Rig holders, bones asserted within 0.02, HideParts...) | Studio MCP `execute_luau`, Edit, with a slot |
| `place_tex.luau` | (texture round) as above + Decal -> Image + one SurfaceAppearance per mesh; swaps the old Model only when the new one is complete | same |
| `place_v3.luau`, `place_v4.luau` | (SmartBone) live V3 / V4: textures, chains, end markers, SmartColliders, `Tail*` settings (V4 adds `TailBoneLift`) | same, in BOTH places |
| `place_belljester.luau` | a fitted-gear Model (`MountPart`, WorldPivot = template part, `CastShadow` off) + an outfit | same |
| `tex_check_server.luau` | engine check: builder-made characters, no player or data, wearing the outfit and looping live clips | a temp Workspace Script `__TEMP_..._delete_me`, one muted Play, deleted after |

Not copied (they live elsewhere, untracked): `idle_arms.py`, `render_idle.py`, `preview_server.luau` and the clip
re-pose tools (`clips/survey.py`, `repose.py`, `clip_gate.py`, `served_sig.py`, `served_cmp.py`) in
`characters/prickles/idle-arms-2026-11-16/`; the older SmartBone placers (`place_sb.luau`, `place_sb4.luau`) in `$SSR`; `gait_all.py` in `../showstopper_tails/`; the style
filter (`texstyle.py`, `style.json`, `measure_one.py`) in the texture-pipeline skill.
