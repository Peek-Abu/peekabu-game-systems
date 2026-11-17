# Skin-making skill: notes from the Showstopper remake (started 2026-11-16)

The owner will turn these notes into a "skin making" skill. It must cover props, clothing, fitting, painting and
colours, every issue hit so far, SmartBone for cloth, turning concepts into skins, and anything else. This file keeps
the lessons, the recipes that worked, and the routes that failed and why, so nothing is lost.

Sources: this folder (`showstopper_remake/`, scripts named below), `../showstopper_tails/`, `../route2_whole/`,
`../lc_pilot/`, `handoffs/skins-reevaluation-2026-11-09.md`, and the skin page artifact
(https://claude.ai/artifact/HP5UKfMcSWKy9By7nNq17u, sections #remake-*).

## 0. Current best state (owner, 2026-11-16: "THIS IS THE BEST SHOWSTOPPER HAS LOOKED")

Showstopper remake **round 5** plus Prickles' **fixed A2 idle**. This is the reference for every later skin.

**Outfit:** round 5.
- Build: `r19/` (pieces, robe, export).
- Test asset: Icey Labs 108833355972983, revision 3.
- Placed unsaved in the lobby as `PricklesShowstopperRemake`.
- Meshes: SSR_Robe, SSR_Upper, SSR_Lower, SSR_Hat.
- What it is:
  - one robe, with the skirt skinned to the hips and thighs;
  - folded lapels and collar standing 0.15 off the coat;
  - bloomers closed into the boots;
  - the earlier hat and boots;
  - cream cuffs in the source (`ss_robe.py`), not yet uploaded.

**Idle:** fixed A2.
- File: `characters/prickles/idle-arms-2026-11-16/out/draft_a5.rbxmx`, from `idle_arms.py`.
- The shipped idle's keyframes with the six arm rotations re-solved:
  - the left arm 0.14 lower and the left wrist tilted 39° up;
  - checked on every frame: 0 body, 0 hand-in-hand, hands/forearms/spikes at least 0.074 from the head, 54 of about
    880 points on the lapels.
- Draft only: not uploaded. The 7 dependent clips get re-posed after the owner OKs A2.

## 1. What a skin is (owner rules)

- A skin is **the same base employee plus additions**. Never remodel the character. His own head, face, spines,
  flower and hands stay.
- **Match the concept 1:1 in shape and volume, with real 3D depth.** Painted-on, snug or "2D" pieces fail on sight.
- **Rigid props stay props.** The hat, flower and boots were "decent" from the earlier build and were kept. Remake the
  cloth and body pieces, not the props the owner already liked.
- **No goo or drips** on this skin ("forget the goo / drip"). Ask per skin before adding effect-like decoration.
- **No face on Gloom/goo art.** **No 4-point AI sparkle star** anywhere.
- **Kid reading level** for anything player-facing.

## 2. The pipeline that works (Showstopper round 5)

Blender 5.1 headless (`-b --disable-autoexec`), the body from `Prickles_controls.blend` (T pose, front -Y, his left
+X, units = studs).

1. **Blockout from the concept** (`ss_blockout.py`): every piece sized from the concept (~124 px per stud), flat concept
   colours. Plan on the page and get yes/no shape answers before building further.
2. **Reuse approved props** from earlier builds (the hat file, the `r2_built.boots()` builder) instead of rebuilding them.
3. **One robe, not a top plus a skirt** (`ss_robe.py`):
   - One parametric grid from the neckline to the hem.
   - The two halves share the back centre column above the vent.
   - Lapels and collar are a **real fold of the same mesh**: at the front edges and neckline the cloth rolls outward
     over a small radius and comes back over the coat. The edge stands off 0.15 studs, the gold piping sits on the flap
     edge, and the lapel/collar corner is a notch so the two never overlap.
   - Grid columns are **warped so a column lies exactly on the lapel edge**, otherwise zone colours stair-step.
   - The skirt part hangs by **cloth simulation** (top rows pinned) against the bloomers and boots, with collision
     thickness 0.05.
   - Then solidify (with rim) gives a closed shell.
4. **Closed pieces only.**
   - Sleeves are one closed loft each; the gold band and cuff are rings *of the same mesh*, with face materials.
   - Bloomer legs are one closed piece from the hip down INTO the boot shaft; the dark cuff is a face-material band.
   - Recalculate every lofted piece's normals OUTWARD (lofts come out inward; Roblox culls back faces).
5. **Head clearance**: every vertex of every piece is pushed 0.05 below the head's underside (ray up from below). The
   neckline sits low enough that the collar's roll clears it without squashing (`head_gate.py` = 0 inside).
6. **Weights** (`ss_export_remake.py`):
   - The robe top and lapels go to UpperTorso, blending to LowerTorso at the waist.
   - **The skirt goes to the hips and thighs**: front panels follow their own thigh 0.95 at the hem, the sides 0.68, the
     back 0.40, the centre back split between both thighs, and the waist row stays with the hips.
   - Sleeves go to UpperArm, blending to LowerArm at the elbow. The bloomer legs go to the hips at the top and the shin
     below the knee. Boots go to the shin and foot.
   - Limit 4 influences, normalised.
7. **Export**:
   - Use the game's deform skeleton (`route2_whole/export_r25/Showstopper_R2_final.blend`, `<Part>Bone` names).
   - Flat colours go into one small swatch texture (one texture per MeshPart).
   - Each mesh stays under 20k triangles **without decimation**; split into more meshes instead (decimation mixes
     swatch colours into shards).
   - Final set: SSR_Robe, SSR_Upper, SSR_Lower, SSR_Hat.
8. **Gates, all offline, before any Studio**:
   - `gate_holes.py` + `gate_check.py`: body hidden as the game hides it, 16 directions, magenta background, garment
     insides drawn red. 0 red, 0 open edges. Magenta spots inside the figure are only air between separate parts.
   - `pose_gate.py`: poses the EXPORTED outfit with every keyframe of his real clips (Idle, Walk, Run, CrouchIdle,
     CrouchWalk from `../showstopper_tails/pose_all.json`), linear blend as Roblox does it. It counts covered
     bloomer/boot points that end on the other side of the same robe face (tolerance 0.015), writes posed scenes, and the
     hole gate runs on them.
   - `head_gate.py`: 0 vertices inside the head.
9. **Upload and place**:
   - Icey Labs only (group 189923277) and only after the owner's OK. `../showstopper_tails/create_model.py` for a new
     asset; `lc_pilot/tools/patch_model.py` updates the same id.
   - `place_remake.luau` builds the outfit Model (Outfit meshes + Rig holders with `<Part>Bone` Bones at the template
     joints; HideParts copied from the live outfit; HideAccessories; SoloMeshes).
   - Test with `employeeoutfittest <Name>`.

Round 5 numbers (worst frame, out of 4,299 covered points):

| Clip | Pokes |
|---|---|
| Idle | 5 |
| Walk | 63 |
| Run | 28 |
| Crouch | 394 |
| Crouch walk | 437 |

Crouch stays open: the deep knee bend pushes the hip puff through the skirt sides.

## 3. Failed routes and why (do not repeat)

| Route | What happened | Why |
|---|---|---|
| Caged / layered clothing jackets (rev 1-17, Nov 6-9) | owner failed them: "armpits and shoulders look wrong" | Roblox's cage deformation tears at shoulders/armpits; can't hold a long coat |
| AI whole-body figure cut into rigid pieces (route 2, rev 19-29) | "finalized until a modeller" only provisionally; remade | AI surface: ragged lapels, smeared paint between pieces, overlapping rigid shells at joints, too slim |
| AI-painted plain cloth | "miscolouring / smudging" | painter colour differs per piece and bleeds; snap plain cloth to one exact colour (`CLEAN=1`) |
| Stretching a piece to cover a gap (3.8x sleeve) | rejected | use true-size cloth instead |
| Scripted-primitive skins (fwjelaa kit) | rejected | looked like a kit, not the concept; remodelled the base |
| Coat as top + separate cloth-sim skirt (rounds 1-3) | "obvious stitches / seam" | two meshes overlap at the waist; a drip band hid the join |
| Lapels as a colour zone on the robe (round 3) | "looks almost 2D / attached to body" | only 0.03 raised; must be a real fold with stand-off |
| Lapels as fan-filled sheets projected on an ellipse (rounds 1-2) | holes, floating gold wires | not on the real surface; piping tubes floated in air |
| Rolled tube collar | clipped into the head | sat above the head's underside; clamp to head + lower neckline |
| Loose gold rings on sleeves, loose cuff rings on bloomers | "holes all over" | separate rings leave gaps and open at bent joints; make bands part of the closed piece |
| Six skirt tail chains on the game's simple tail spring (round 4) | "twitch, clip, rumple over the top on jump" | the spring was made for two back tails; chains move independently, stretch the cloth between them, and get flung on a jump |
| Decimating joined clothing parts | dark cuff band turned into shards | decimation merges faces across swatch-colour borders |
| Hard-coding Studio ids | worked in the lobby while thinking it was Shift | ids change on every Studio restart; match window name + placeId ("Odd Hours" = lobby 113354563835664, "Odd Hours: Shift" = 118845637680835) |

## 4. SmartBone for cloth (owner: separate later step, but part of the skill)

- It is the **same mesh**. SmartBone adds a few skirt bone chains that ride ON TOP of the leg weights (chains parented
  to the hips/thighs, their weight shared with the leg weights), and moves them a little each frame.
- At rest it looks identical; in motion the skirt lags and swings (heavier toward the hem). Illustration on the page:
  `rm_r6_smartbone.jpg` (`sway_demo.py`).
- Settings tried in the tails test ("heavy wool"): Constraint Spring, Damping 0.25, Elasticity 6, Stiffness 0.55,
  Gravity (0, -30, 0), Inertia 0.1, per-bone RotationLimit 25, Radius 0.3, ZAxisLimits 0.2..3, YAxisLimits -4..0.35, and
  the legs as capsule SmartColliders (`../showstopper_tails/smartbone_owner_try.luau`).
- Needs:
  - the parked `claude/smartbone-tails` code merged (EmployeeTailSmartBoneUtils, owner pick 11-15);
  - the SmartBone 2 package (v0.5.2, MIT) in both places;
  - a pose gate that simulates it.

## 5. Animation side effects (skins expose clip problems)

- A skin with anything on the chest exposes arm poses. Prickles' shipped idle had his left hand 0.23 studs inside his
  chest and 0.09 inside his head, and the right forearm 0.16 inside the chest, in every frame, with no skin at all
  (`idle_clip_probe.py`).
- Fixing a personality idle is allowed (it is the character's own clip). Generic pose fixes (hide, sit) must stay
  generic for every employee.
- Changing an idle means re-posing everything that starts, ends or holds it: crouch idle, fidget, select nod, hire
  reveal, default emote, ability enter/exit, and the static EmployeePoseRegistry pose. Overwrite in place (Open Cloud
  PATCH, same ids), after the owner sees the new idle and OKs it.
- `characters/prickles/idle-arms-2026-11-16/idle_arms.py` re-solves only the arm rotations of every keyframe:
  - Nelder-Mead over 18 rotation offsets.
  - Scores: arm/hand points inside the torso/head (outward-ray test in each part's rest frame), points inside the
    outfit's chest pieces, hand targets, which forearm is in front, and staying near the old pose.
  - Short arms cannot cross outside raised lapels completely; drafts A and B cut the lapel contact by about half.
  - Check more than the body:
    - **hand vs the other arm**: draft A's left hand sank 0.15 into the right;
    - **head gap with every spike tip**: fixed A had a left-hand spike 0.016 into the head.
  - Wrist bends alone could not fix the hand overlap (they needed ~80°). Layering the cross (left forearm higher and in
    front) did, and the owner then tuned it by eye ("left arm a little more down, wrist up way more").
  - His shoulders sit 0.016 under the head by the rig's design in every idle; the head-gap rule covers the forearms, hands
    and spikes, not the shoulder joint.
  - Preview without uploading: a temp Workspace Script fetches the shipped idle with
    KeyframeSequenceProvider:GetKeyframeSequenceAsync, swaps the arm Pose CFrames, registers it in memory, and plays it on
    builder-made Prickles (`preview_server.luau`). The place's SpawnLocation is unused (origin), so the lineup is placed at
    the depot start (1, 2.4, -224).

## 6. Working rules learned

- Plan on the page first and ask the owner yes/no shape questions by name (hat, lapels, coat, bloomers, boots).
- Show **side and three-quarter views** for depth questions.
- Check in the game's own idle and light early: the idle bends the knees and crosses the arms, and the depot light is
  orange (plum reads maroon).
- Studio:
  - One Play at a time, slot from the coordinator.
  - Mute every Play: zero all Sounds client-side plus a DescendantAdded hook; never MasterVolume.
  - No profile writes: rebuild the Play character with the game's builder.
  - Never save places.
  - Remove temps and report.
  - A scripted camera must also set Camera.Focus, or focus-radius systems (the tail spring) stop.
- Offline gates first, Studio last. The owner judges in Studio: every round ends with the exact command he types.
