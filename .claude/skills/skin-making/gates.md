# Skin gates: commands, how to read them, real numbers

All offline, in Blender 5.1 headless, before any Studio work. `$SSR` =
`E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake` (untracked main-checkout
folder; snapshots in [scripts/](scripts/README.md)). `B` = `blender -b --disable-autoexec -P`.

Run order for one build folder `<dir>` (the round 5 build was `r19`, the shipped crouch build `cr/EB`):

```bash
bash $SSR/run3.sh <dir> SUBD=0          # blockout -> robe -> renders -> pose demo -> hole gate
B $SSR/head_gate.py -- <dir>
B $SSR/ss_export_remake.py -- <dir> UP0=0.80 UP1=1.00 SIDEB=0.30 T1=0.40 PLUM=6A3A8E
POSESET=$SSR/pose_a3.json B $SSR/pose_gate.py -- <dir>
POSESET=$SSR/pose_a3.json B $SSR/sleeve_gate.py -- <dir>
```

## 1. Hole gate (`gate_holes.py` + `gate_check.py`)

- `B gate_holes.py -- <dir> [pose]` then `python gate_check.py <dir> [pose]`.
- The body is hidden exactly as the game skin hides it (Showstopper's HideParts: all but head and hands; YOUR outfit's
  HideParts, which hide only what it covers). 16 views: 8 around at eye level, 8 from
  25 degrees above. Flat colours, **magenta** background, every garment's **inside (back faces) red**.
- Red pixels = you can see into a garment (gap, open edge, flipped normal). Magenta shut inside the figure = a
  see-through hole. Magenta between separate parts that is only air is fine.
- It also counts open (non-manifold) edges per piece. **Pass: 0 red, 0 open edges.**
- Writes `<dir>/gate/gate.json` and a marked sheet `gate_sheet.jpg` (problems in yellow). Put the sheet on the page.
- Roblox culls back faces. Offline renders must cull too, and normals must be computed before any orientation vote, or
  pieces show only their walls in game.

## 2. Pose gate (`pose_gate.py`) - clipping on every frame

- Poses the **exported** outfit (`<dir>/export/export_final.blend`) with every keyframe of the real clips, as one deform
  matrix per body part, linear blend skinning with the `<Part>Bone` weights (what Roblox does).
- **Poke** = a bloomer / boot / waistcoat point the robe covers at rest that ends on the other side of that same robe
  face in the pose (beyond 0.015).
- The poke metric needs a garment UNDER another (bloomers under a skirt). For a single-layer garment (a cape, a
  hoodie) count garment points inside the visible body instead, and set your own baseline from the first build the
  owner approves. Piece names in the script (`SSR_*`, bloomer / boot roles) are Showstopper's: rename them.
- The pose set MUST come from the **live** clips. `pose_set_a3.py` builds `pose_a3.json` from the files that serve now
  (idle, crouch idle, walk, run, crouch walk, fidget, nod, hire reveal, emote, plant in/out). An older set
  (`../showstopper_tails/pose_all.json`, built by `gait_all.py`) only has locomotion.
- Quick subset: `POSESET=... ONLY=a,b NOSCENES=1 pose_gate.py -- <dir>`.
- It writes posed scenes for picked frames; run the hole gate on them too (`gate_holes.py -- <dir> pose`).

Real numbers (worst frame, out of 4,299 covered points):

| Build | Idle | Walk | Run | Crouch idle | Crouch walk |
|---|---|---|---|---|---|
| Round 5 | 5 | 63 | 28 | 394 | 437 |
| EB (shipped) | 13 | 47 | - | 145 | 147 |
| Sides pushed harder (SIDEB 0.45-0.5) | - | 85-88 | - | ~120 | ~120 |
| TX (textured, one-shell bloomers; live V2+) | 14 | 44 | 41 | 115 | 117 |

Crouch is still open: the deep knee bend pushes the hip puff through the skirt sides. Its cause was a weight mismatch
(bloomer top followed the thigh 100%, the skirt side ~40%, at the same height), not the puff size.

## 3. Head gate (`head_gate.py`)

- Counts every outfit vertex above the head's underside and below its top. The hat sits ON the head and is skipped.
- **Pass: 0.** If a collar fails, lower the neckline; don't squash the roll.

## 4. Arm, hand and spike gates (`idle_arms.py`, `clip_gate.py`)

In `characters/prickles/idle-arms-2026-11-16/` (`clips/` for clip_gate). Measured on every frame:

| Check | A3 idle (approved) |
|---|---|
| Hands crossed past the centre line | left 0.10, right 0.07 |
| Hand resting on the other arm | sinks at most 0.024 |
| Head gap: hands, forearms **and spike tips** | 0.064 |
| Shoulders under the head | 0.010-0.017 by rig design; reported, not pushed |
| Body | 2 points at 0.006 |
| Chest-piece (lapel) contact | 196 of ~880 (shipped idle had 482) |

Check more than the body: draft A's left hand sank 0.15 into the right arm; "fixed A" had a spike 0.016 into the head.
Validate a new gate by reproducing these numbers exactly first.

## 5. Sleeve gate (`sleeve_gate.py`) and the "inside is not visible" trap

It counts sleeve points inside the chest pieces in each pose. In the A3 idle it found 311 of 900 inside, yet renders
look clean: the sleeves' back halves press into the coat behind their own front halves. **A count of inside points is
not visible clipping.** Look at a render before gating on such a count. A real visible-clipping gate needs the inside
points that are also seen from outside.

## 6. Plain-character probe (`idle_clip_probe.py`)

`B idle_clip_probe.py -- <out.json> [Clip]`: how far the plain character's arms go into his own torso and head per
frame, no skin. Run it before blaming the outfit.

## 7. Worn props (hat, glasses, bow)

`head_gate.py` skips a hat that sits ON the head, and the pose gate only checks robe pokes, so a prop needs its own:
- **Seated**: rest render from four sides; no gap under the brim, no prop point inside the head (ray test in the
  head's rest frame, like `head_gate.py` with the hat included).
- **Clearance on every keyframe of every clip**: the prop rides its mount part rigidly, but ears, spikes, the flower
  and the hands move relative to it (Pippa's ears are also swung by code springs, which no clip shows: leave extra
  room, ~0.1). Pose the character with the pose set, transform the prop with its mount part, and report the smallest
  gap per clip (ears / spikes / flower / hands vs the prop).
- In engine: watch the ears in walk, run and a jump on a builder-made character; captures from the side and back.
- The hole gate (closed shell, 0 open edges, normals outward) and the texture round apply to a prop too: a shipped hat
  is textured like Showstopper's felt hat.

## 8. In engine (after an upload, in one muted Play)

- **Client** `ContentProvider:GetAssetFetchStatus` = Success for every worn MeshPart's MeshId and every
  SurfaceAppearance map ([troubleshooting.md](troubleshooting.md) for a Failure).
- The skin on builder-made characters in the game's idle and light, unlit too; the live clips looped.
- The shared poses with the skin on (vacuum hold, hide, sit, carry): report clipping; fixes stay generic.
- **Cloth showcase before handoff:** every region marked simulated in the ideation plan has physics active in
  Studio. Show normal-speed rest -> walk/run -> stop/settle, crouch and real jump/landing, plus relevant clips,
  from views exposing the front/back. Record active chains/trees, rest-shape drift, swing, jitter, flips and
  full-surface clipping ([smartbone.md](smartbone.md) "Gates"). A held-chain pose pass is not a physics pass.
  If a planned cloth region is still rigid, keep this gate open; do not wait for the owner to ask for physics.

## 9. Gate ledger

Keep a `GATES.md` in the build folder: each gate, its command, the result and the evidence image. Builds without one
(Backstage Cappy, Bell Jester Pippa) failed in front of the owner.
