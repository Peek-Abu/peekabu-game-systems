# SmartBone cloth (skirts, coat tails, lapel fringe, capes)

Only for cloth that should SWING. Stiff coat tails are part of the coat surface with chest + hips weights
([SKILL.md](SKILL.md) section 2).

## Required planning and Studio showcase

Cloth motion belongs to the skin deliverable, not a separate task the owner must discover and request. During
ideation, list each cape, skirt, tail, lapel/flap or loose trim region, whether it should move, and how. Asking
"Should the cape and front flaps swing while the bow stays rigid?" is appropriate at that stage. Once settled,
build the chains, weights and colliders during the skin work. Deliberately rigid construction remains valid;
explain that choice rather than quietly skipping physics.

Before the final skin handoff, show the actual imported/worn model in Studio with simulation active, at normal
speed: rest -> walk/run -> stop/settle, crouch, real jump/landing, and relevant fidget/emote/shared holds. Include
front and side/back views that reveal the affected cloth. Record settings, active trees/chains, movement and
clipping/jitter/flip observations in the ledger. The owner should be reviewing working cloth, not being asked
to approve a static skin with physics left for later. A held-chain pose gate or an offline drape is useful
preparation but does not prove the runtime physics. Preserve the agreed rest silhouette; physics is not a
replacement for fitting the garment.

Tested on Showstopper Prickles, rounds 1-4 (2026-11-17). Round 3 shipped as `PricklesShowstopperV3` (owner: "good
enough especially for kids"); round 4 + per-bone ceilings ships as `PricklesShowstopperV4` (owner: "Yes its good
enough!"). **Round 4 (bones on the cloth surface) + `TailBoneLift` is the recipe for every new skin**: build steps
below, then the last two sections. Check `EmployeeRegistry` for which outfit is live.
`$SSR` = `characters/skins/release/gloom_carnival/showstopper_remake` (main checkout, untracked).

## What it is

- **The same mesh.** SmartBone 2 (`jakeywastaken/smartbone-2@0.5.2`, MIT, Wally) moves a few bone chains inside the
  cloth each frame, on each client. At rest the outfit looks exactly like the plain skinned build.
- **Chains ride ON TOP of the shipped weights.** Never replace the thigh-follow weights that keep crouch clean. Only a
  share of each point's weight moves onto the chains (see "Weights").
- It does not fix clipping by itself. SmartBone pushes **bones** away from colliders, not the cloth between them.

## Close-fitting cape or lapel (owner correction, Bell Jester 2026-11-18)

The owner wanted the bow/front flap and back cape to rest closer to Pippa. A universal .30-stud stand-off made it float. First fit the actual rest shape over the supporting garment: for the tested .035 lining, start near .095 outer-surface distance to leave .06 real layer clearance. Preserve thickness by applying the SAME displacement field to outer and inner walls; projecting both independently to the same radius collapses the lining. Keep neckline/head clearance and shoulders appropriate to the concept. Reseat the bow and bell against that fitted surface.

Then size chest/back/arm colliders to the visible supporting volume and place chain points on the new cloth. One low torso capsule may miss the upper chest; split coverage according to the actual contour rather than growing a low capsule until it shoves the cape outward. A collider prevents inward penetration at bones; it does not attract floating cloth onto the body, and it does not guarantee clearance across the full span between chains. Compare the rest silhouette before/after physics, then check full-mesh run/fidget/crouch/jump contacts. Do not use enlarged colliders as the garment fitting method.

## Game wiring (code on game/cleanup-crew)

- An outfit opts in with attributes on its Model: `TailPhysics = "SmartBone"` and `Tail<setting>` (root settings) /
  `TailBone<setting>` (per-bone settings: lengths scaled by the character's scale). `EmployeeOutfitSystem.fit` copies
  them onto the fitted `Outfit` folder; `EmployeeTailSystem` hands the character to `EmployeeTailSmartBoneUtils.prepare`.
- Chains are `Tail<name><n>Bone` bones, flat under a Rig holder; prepare nests them, marks the last `_end`, and tags
  each body part in `SMARTBONE_ROOT_PARTS` that carries chains (`LowerTorso` for a skirt, `UpperTorso` for a lapel
  fringe) as its own SmartBone root. All roots share one collider key per character.
- **Colliders:** an outfit `SmartColliders` folder of invisible Parts (`Body` = body part, `ColliderShape` =
  `Capsule`), placed in template space. The fit welds them on, scaled; the client tags them instead of the bare legs.
  SmartBone capsule = the part's X axis is the segment (length = Size.X), radius = min(Size.Y, Size.Z) / 2.
- SmartBone can only load on a client (its debug gizmo hooks RenderStepped as it loads): require it inside `start`,
  never at the top of a module the test runner loads on the server (TestEZ failed to load the spec once).
- The package is installed (`wally.toml`, pinned 0.5.2; 0.6 is a release candidate). If it ever changes: `wally install` in the SERVED worktree only in a window with both Rojo serves stopped; pull and
  install together (a client module hard-requires `Packages.SmartBone`).

## Build recipe (`$SSR/ride_chains.py`, `place_v4.luau`)

Written as Showstopper did it (round 3, 6 chains). For a NEW skin apply the later sections on top: joints on the
cloth surface and full-size colliders ("Bones on the cloth surface"), `TailBoneLift` ("The hem ceiling rule"), 8
chains and ~0.06 clearance over puffs ("What still clips").

1. **Chains:** 8 chains of 3 links around a full skirt for a new skin (Showstopper shipped 6: RF RS RB LF LS LB) on the robe's own skirt bones, under LowerTorsoBone, plus
   a zero-weight end marker (Roblox drops it; the place script adds it back one link past the last).
2. **Weights** (on the exported robe, `export_final_r7.blend` so UVs and maps stay valid):
   - the hips' share of every skirt point (1 - thigh-follow) moves onto the chains, fading in below the waist
     (z 1.30 → 1.12) so the waistband stays on the hips;
   - PLUS part of the thigh weight (round 2, "too rigid"): front flaps 45 %, sides and back 35 %, ramping in toward the
     hem (z 1.20 → 0.55). Average share on chains: 41 % (round 1 had 26 % and barely moved the front);
   - around the body a point blends the two nearest chains by angle; down a chain it blends the two nearest links;
   - **the back vent:** below the vent top a back point rides only ITS OWN side's chains (blended over 0.12 above the
     top). An even blend of both back chains held the split rigid while the panels swung ("rigid and weird").
3. **Lapel fringe:** a 2-link chain per lapel under UpperTorsoBone, from the lapel top to its tip; the flap's points
   (the robe's own Lapel groups, same vertex order as the export) move onto it, more toward the tips (LAPK 0.6).
4. **Colliders:** measure the VISIBLE surface (the bloomer puff, the boots, the coat's chest) from the exported meshes.
   With joints on the cloth surface (round 4, the recipe now) they stay at that full visible size: thighs 0.39, seat
   0.37, shins/boots 0.20, chest 0.54; check only that no simulated bone HEAD touches one at rest (bone radius +
   0.02). Round 3 (joints inside the cloth) had to shrink them to 0.32 / 0.27 / 0.20 / 0.41.
5. Place with the place script: Tail bones under their holder (`TailU*` → UpperTorso), end markers back, colliders
   from Blender coords through axes **solved from the imported bones** (three known Blender heads), settings as
   attributes. Separate test outfit first (`employeeoutfittest`), the live outfit only after the owner's OK.

## Settings that shipped (round 3; V4 keeps them all and adds `TailBoneLift` 0.15, the per-bone ceiling)

| Root (outfit `Tail*`) | Value | Per bone (`TailBone*`) | Value |
|---|---|---|---|
| Constraint | Spring (Distance crumples the hem) | RotationLimit | 35 |
| Stiffness | 0.35 (0.55 was "too rigid") | Radius | 0.04 (0.3 ballooned the cloth off the colliders) |
| Elasticity | 4 | YAxisLimits | -4 .. 0.05 (hem ceiling at the hips) |
| Damping | 0.18 | | |
| Gravity | (0, -30, 0) | | |
| Inertia | 0.1, WindType "" (indoors) | | |

The Y ceiling: with 0.35 the hem rose 0.19 above the hips on a jump (a flip); at 0.05 it stays level with them.
Middle links rest just below the hips, so the ceiling cannot go lower without bending the rest shape.

## Gates

- Offline: the pose gate with the chains held rigid to their root part must match the plain build within a few points (limit-4 can trim thigh weight: crouch 115 → 128 of 4,299).
  `pose_gate.py` maps EVERY `Tail*` bone to LowerTorso (line 45): that is wrong for `TailU*` chains (lapels, capes),
  which ride UpperTorso. Map `TailU*` to UpperTorso in your copy before gating them.
- In-engine (muted Play, test character from the builder, no profile writes; the owner's account may play another
  employee, so swap the Play character to a builder-made one on the server): per move, the largest hem-tip move from
  rest (swing), lapel-tip swing, the highest hem point vs the hips (flip check), frame-to-frame jitter standing
  (twitch), and chain points inside the VISIBLE volumes (clip depth). Real jumps need `ChangeState(Jumping)`.
- Showstopper round 3: skirt swing walk 0.87 / run 0.98 / stop 0.14 / jumps 1.14; lapel tips 0.54 / 0.70 / 0.10 /
  0.72; hem level with the hips on jumps; deepest clip walk 0.28 → 0.10 with the outfit colliders (run 0.20 both).

## Bones on the cloth surface (round 4, tested 11-17)

- The skirt bones from the robe rig sit **inside** the draped cloth, so colliders (which act on bones) must stay below
  the visible size. Round 4 moved every non-root joint out onto the cloth (`ride_chains.py ... SURFACE=1`: each joint
  keeps its height and angle, its radius becomes the robe's outer surface there minus half the cloth).
- **Size colliders against the real collision points only:** SmartBone collides each simulated bone's position (its
  head) with its radius; chain roots are pinned. Checking points along whole links (as round 3 did) trims the colliders
  far more than needed. With joints on the surface and only real points checked, every collider reached full visible
  size (thighs 0.39, seat 0.37, chest 0.54).
- Result (same moves, same visible volumes), round 3 → round 4: points inside the visible body run 21 → 12, walk 16 →
  13, jump 19 → 12; deepest run 0.20 → 0.10. Swing a little livelier (lapel tips walk 0.54 → 0.85).
- **But the hem lifts above the hips** (walk 0.14, run 0.16, jumps 0.25 vs round 3 level): the joints are further out,
  so the panels swing on longer levers. A lower shared Y ceiling (-0.06) cut it (jump 0.16) but bent the rest shape
  (some middle joints rest at the ceiling; standing sway rose to 0.26). Not clearly better, so round 3 stayed live.
- Fixed by **per-bone ceilings** (next section): round 4 + `TailBoneLift` 0.15 keeps the hem at or below the hips.

## The hem ceiling rule (every skin): `TailBoneLift`

- One shared ceiling (`TailBoneYAxisLimits`) cannot work for a whole skirt: the hem tips rest ~0.8 below the hips and
  the upper joints right at them, so a ceiling low enough to stop the hem flipping up squeezes the upper joints (rest
  shape bends, standing sway 0.12 → 0.26), and one that leaves the joints alone lets the hem fold up (jump +0.32).
- **Set `TailBoneLift` on the outfit** (studs, scaled with the character like the other `TailBone*` lengths).
  `EmployeeTailSmartBoneUtils.prepare` gives each simulated bone its own `YAxisLimits`: up to where it RESTS in its
  root part's space plus the lift, capped by `TailBoneYAxisLimits`' top; the bottom stays the shared one. Nothing to
  measure per skin: it reads the rest heights from the fitted bones.
- **Default: lift 0.15, shared cap 0.05.** Tested on Showstopper round 4, 2026-11-17 (skirt swing / lapel swing / highest
  hem vs hips / chain points inside the body / deepest):

| Ceiling | walk | run | jump | idle sway |
|---|---|---|---|---|
| shared 0.05 only | 0.96/0.85/**+0.13**/12/0.08 | 0.77/0.71/-0.02/12/0.10 | 1.15/0.63/**+0.32**/13/0.08 | 0.12 |
| shared -0.06 only | | | 0.16 hem | 0.26 (rest bent) |
| lift 0.10 | 0.86/0.79/-0.07/14/0.08 | 0.87/0.65/-0.16/9/0.10 | 1.14/0.59/-0.10/12/0.08 | 0.12 |
| **lift 0.15** (2 runs) | 1.00/0.83/0.00/14/0.09, 0.97/0.80/-0.01 | 0.81/0.74/-0.06/12/0.10, 0.69/0.71/-0.17 | 0.94/0.44/-0.15/13/0.08, 1.27/0.60/-0.04 | 0.12 |
| lift 0.25 | 0.95/0.84/+0.05/12/0.08 | 0.74/0.73/-0.11/13/0.10 | 1.19/0.51/+0.06/12/0.08 | 0.09 |

- Lower the lift (0.10) for a skin whose hem must stay further down; raise it only if the swing reads stiff and the
  hem-vs-hips gate still passes. The lapel chains get the same rule (their tips still swing 0.4-0.8).
- Standing twitch stayed 0.004-0.005 at every lift. Test outfit: `PricklesShowstopperSB` (asset 139625595849758, the same asset the live `PricklesShowstopperV4` now uses).

## What still clips (V4, owner 11-17: "It still clips through the puffed up pants though?")

- Measured per collider (points inside the VISIBLE bloomers): the seat puff 0.07-0.09 walking/running (0.02 standing);
  the thigh puffs 0.12-0.20 on jumps, from the cloth BETWEEN two neighbouring chains (chord midpoints), not the joints.
- Cause, measured in Blender at rest: over the hips' sides the robe's inner face already touches the bloomer puff (gap
  -0.04 to +0.05). SmartBone pushes only the joints; the straight span between two chains 60 degrees apart cuts the
  round puff.
- Bigger colliders do NOT fix it: seat + thighs x1.12 / x1.25 push the front flaps out at rest (0.16 / 0.49) and make
  the walk jumpier (clip spikes 0.47); seat only x1.12 measured the same as the baseline on a repeat, x1.2 starts
  pushing the front flaps (0.11). Check rest drift (hem tips vs the fitted rest) before keeping any collider growth.
- **Build rule for new skins:** leave about 0.06 of clearance between a swinging skirt and anything puffy under it
  (or slim the puff where the skirt covers it), and use 8 chains around a full skirt instead of 6. Showstopper's own
  fix is a later rebuild.

## Other cloth: capes, long tails, hoods (NOT yet built: start here, gate hard)

Only skirt chains (LowerTorso root) and 2-link lapel chains (UpperTorso root) have shipped. For anything else, carry
the same rules over and prove each in engine:
- **Root at the part the cloth hangs from.** A cape hangs from the shoulders: UpperTorso (already in
  `SMARTBONE_ROOT_PARTS`). The place scripts put chains whose names start with `TailU` under the UpperTorso holder and
  the rest under LowerTorso, so name cape chains `TailU<letter><n>Bone` (or extend the script's rule). A new root part
  (e.g. Head for long ears or a hood) needs a code change in `EmployeeConstants.SMARTBONE_ROOT_PARTS`, spec first.
- **Chains across the width, links down the length**: start from the new-skin skirt density (8 chains around a full
  circle, i.e. one every ~45 degrees of what the cloth spans, so a back-only cape over ~180 degrees gets 4-5; 3 links over ~1 stud of length, end marker after the
  last); add a link per extra ~0.4 stud. Fewer, wider-spaced chains let the straight span between two chains cut
  through whatever is under the cloth ("What still clips" above).
- **Weights**: the top row (neckline, shoulder seam) stays 100 % on the root part; below it the cloth fades onto the
  chains (blend the two nearest chains by angle, the two nearest links by length), most at the hem. A cape behind the
  body has no thigh-follow to keep: nearly all of its hem weight can ride the chains. Points that pass near the arms
  get no arm weight.
- **Colliders**: whatever the cloth can swing into, at the size you SEE: back and seat for a cape, plus the upper arms
  if the run's arm swing reaches behind (measure it on the live clip first). Same sizing: against bone heads, joints on
  the cloth surface.
- **What is already on the back**: Prickles' spines, Pippa's tail. A cape must not flatten, hide or swallow them:
  hang it clear of them or ask the owner how the concept treats them (a tail slot, a cape that ends above the tail).
- **The flip gate is relative to where it hangs**: for a cape, the highest cape point at or below the top of the
  shoulders on every move, nothing ever above the head's underside; for a skirt, vs the hips. `TailBoneLift` works the same way for any root (each
  bone may rise only `lift` above its own rest in the root part's space), so start at 0.15 and lower it if the jump
  gate fails.
- **Pose gate offline** still holds the chains rigid to their root: it shows the weights alone. Clipping into the body
  for a cape (no layer under it) = cape points inside the body parts, not the robe-poke count.

## Failed / rejected

- Six skirt chains on the game's simple two-tail spring (round 4 of the remake, before SmartBone): twitched, clipped,
  flipped over on a jump.
- Heavy wool (stiffness 0.55, elasticity 6, damping 0.25, bend 25): "too rigid".
- Chains carrying only the hips' share: the front flaps barely moved (5 % at the front hem).
- Bone radius 0.3 with body-size colliders: pushes the cloth out at rest.
- Colliders grown past the visible size to stop the bloomer clipping (round 4): pushes the front flaps out at rest.
