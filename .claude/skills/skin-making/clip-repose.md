# Fixing an idle and re-posing the clips that touch it

Use this when a skin shows arms going through the chest, head or lapels in the character's own clips. Worked for
Prickles A3 (2026-11-16: owner "Prickels a3 looks good!"). Work folder:
`E:/Projects/peekabu-game-systems/characters/prickles/idle-arms-2026-11-16/` (untracked).

## 1. Fix the idle

- `idle_arms.py` re-solves only the **arm rotations** of every keyframe (Nelder-Mead over 18 rotation offsets). Body,
  legs, head, timing stay. A3 ended as ONE constant arm pose against the torso.
- It scores: arm/hand points inside torso/head (outward-ray test in each part's rest frame), points inside the outfit's
  chest pieces, hand targets, which forearm is in front, and staying near the old pose.
- Wrist bends alone could not fix the hands overlapping (they needed ~80 degrees). Layering the cross did (left forearm
  higher and in front). Then the owner tuned by eye ("left arm a little more down, wrist up way more").
- Short arms cannot cross fully outside raised lapels; aim to cut lapel contact, not to zero it.
- The A3 solve (deterministic given its inputs; a6 came from draft A with the same terms):
  ```bash
  blender -b --disable-autoexec -P idle_arms.py -- solve INIT=out/report_a6.json FREE=all W_TGT=0 W_OUT=8 W_REG=0.0 W_WRIST=1.0 HAND_MARGIN=0.0 W_HAND=600 HEAD_GAP=0.09 W_HEADGAP=1500 CROSS_X=0.10 W_CROSS=200 CONTACT=0.02 W_CONTACT=300 ELB_MIN=80 W_ELB=20 ELB_OUT=0.55 W_ELBOUT=100 ITERS=900
  ```
  It writes `out/Prickles_Idle_armsdown_draft.rbxmx` and `out/report.json`. Probe any clip with
  `idle_arms.py -- probe INIT=<report.json>`; render with `render_idle.py -- <clip.rbxmx> <frame> <abs_out_prefix> [outfit]`
  (absolute output path: Blender resolves relative render paths against the blend file).
- **Preview without uploading**: a temp Workspace Script fetches the live idle
  (`KeyframeSequenceProvider:GetKeyframeSequenceAsync`), swaps the arm Pose CFrames, registers it in memory and plays it
  on builder-made employees (`preview_server.luau`). Delete the temp folder before anyone saves.

## 2. Find every clip that touches the idle

Everything that starts, ends or holds the idle pose: crouch idle, fidget, select nod, hire reveal, default emote,
ability enter/exit, and the still pose in code (`EmployeePoseRegistry`).

- **Find what is actually live** before touching anything. Registry comments and upload logs point at the last file
  PATCHed to each id; that is often not the folder a handoff names. Confirm in Studio with one read-only
  `GetKeyframeSequenceAsync` per id returning a signature (key count, length, three joints on first/middle/last keys)
  and compare with the local files (`served_sig.py` / `served_cmp.py`).
- **Survey** (`clips/survey.py`): per clip, per frame, the worst arm-joint angle to the OLD idle and the NEW one. A clip
  can carry more than one old "crossed" pose (the plant clips and the hire's middle hold sat on an even older idle).

## 3. Re-pose

- Carry the change as a left turn per joint: `R_new = D @ R_clip`, `D = new @ old^-1`, weighted per side by how close
  that arm is to a crossed reference (smoothstep 8..30 degrees), and **blur the weight over time (+-7 frames)**.
  Unblurred, the hand-over landed in the 3 fastest frames (arms jumped 16 -> 28 deg/frame).
- **Held frames become the new idle's ONE constant pose**, not delta + the old wobble (the carried wobble pushed the
  paws 0.035 into each other). Snap to the exact new matrices once the weight is above 0.995.
- **What a constant arm pose cannot survive: the head moving relative to the torso** (nod, huff, wind-up). Those frames
  need per-frame corrections.
- **Per-frame correction is sequential**, not sparse + interpolated (interpolated fades failed between solves and even
  broke a passing seam). Visit frames in order; keep a decayed copy (0.6x) of the previous offset if it passes, else
  solve warm-started from it. Strong pull to zero (W_REG 30), then a repair pass toward the neighbours' mean. A weak
  pull (1.5) drifted to a different crossing and pushed the paws through each other.
- Start from the locked side (Potted Plant enter runs backward from the plant pose). Locked frames (a pose that must
  equal another clip's) are never touched.
- A straight per-joint slerp between two end poses does NOT help when the body moves meanwhile (he sinks into the pot).
- Clips that only start or end on the idle still need their middle checked.

## 4. Gate and ship

- Gate every frame with the idle's own checks (`clips/clip_gate.py`): body, head gap with spike tips, hand in the other
  arm, chest-piece contact, plus the outfit pose gate. First reproduce the approved idle's numbers exactly.
- Back up every live clip to disk with a manifest (id, file, sha256, date) **before** any upload. The Icey Labs key can't
  download assets, so the local files are the backup.
- After the owner's OK: overwrite in place, same ids: Open Cloud `PATCH https://apis.roblox.com/assets/v1/assets/{id}`
  (multipart `request` {"assetId": id} + `fileContent`; tool
  `characters/launch/animation-workbench/workflow/menu-reactions-idle-seam-2026-10-30/patch_try.py`). Works for
  animations despite the docs; not for audio. Icey Labs only. Key from `ICEY_LABS_OPEN_CLOUD_KEY`, never printed.
- Confirm in Studio that the new files serve (signature again). Rollback = PATCH the backup.
- Push the still pose in code in the same go, so the still and the moving idle never disagree.
- Shared poses (hide, sit, vacuum) are never fixed per character; this method is for a character's own clips only.
