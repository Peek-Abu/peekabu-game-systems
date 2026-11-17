---
name: skin-making
description: Use when making, remaking, fitting, painting, recolouring, gating or shipping a skin or outfit for the team's Roblox employee characters (Odd Hours / Cleanup Crew - Pippa, Cappy, Prickles, any later employee or game) - coats, robes, skirts, sleeves, bloomers, boots, hats, lapels, collars, cuffs, props worn on the body - and when turning a 2D concept into a worn 3D skin. Also when a skin is called 2D, flat, painted-on, snug, "looks like two pieces", stitched, seamed, holes all over, torn at the armpits or shoulders, clipping, twitching, smudged, miscoloured, maroon or pink in the depot light, too slim, or "where are his knees / legs", when a skirt flips on a jump or pokes in crouch, when an outfit stays rigid in game, or when a new idle or clip makes arms go through a skin. SmartBone cloth is part of this skill (section still to add).
---

# Skin making

A **skin is the same employee plus additions**. Never remodel the character. The owner judges two things: **does it
look exactly like the concept, in real 3D**, and **does it hold up in the real game clips and light**. Every route that
missed either one failed (see [failed-routes.md](failed-routes.md)).

The route below is the one that worked: the **Showstopper Prickles remake** (round 5, then crouch weights "EB", violet
coat; owner 2026-11-16: "THIS IS THE BEST SHOWSTOPPER HAS LOOKED", then "make it the live one"). Start every new skin
from it. Do not start from an older route because it is already half built.

Paths below use `$SSR` = `E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival/showstopper_remake`
(main checkout, **untracked**: `characters/` is never in git). Snapshot copies of the key scripts are in
[scripts/](scripts/README.md) in case that folder is lost.

## 1. The owner's rules (check every one in your plan)

| Rule | What it means in practice |
|---|---|
| Keep the base character | His own head, face, hands, spines, flower, ears and tail stay. Base pieces keep their base spot and size. Check in the live place what the base pieces ARE before copying any into a skin mesh. |
| Never hide his limbs to make clothes fit | Hide only what the outfit truly covers (HideParts). "Why are his legs gone!?" / "where are his knees?!" both failed skins. |
| Match the concept 1:1 | Same outline, volume and scale as the 2D. Render concept and model side by side from the same angle. Shape first, clip numbers second. |
| Real 3D depth | Clothes are thick. Lapels, collars, cuffs, trim stand off the cloth. Painted-on or snug = "SUPER 2d" = fail. |
| One garment = one piece | Never cut a garment across two body parts. A coat is ONE robe, not a top plus a skirt. |
| One exact colour per plain cloth | No AI paint on plain cloth. Flat swatch colours; paint only small details. |
| Rigid props stay props | Hat, flower, boots the owner already liked are reused, not rebuilt. |
| Ask before effects | No goo or drips unless that skin's owner answer says so. No face on Gloom art. No 4-point sparkle star. |
| Generic poses stay generic | Shared poses (hide, sit, vacuum) never get per-character fixes. A character's own personality clips (idle, fidget) may be edited. |
| Owner approves each visual step | On an artifact page (he works over Remote Control). Yes/no questions by piece name. Never mark anything done. |

## 2. Pick the build for each piece

| Piece kind | Build it as | Weights |
|---|---|---|
| Hat, crown, glasses, buckles, held props | Either a mesh **inside the outfit** weighted 100% to its body part (shipped Showstopper V2: `SSR_Hat`, 100% Head, so the separate hat gear went), or a rigid **fitted gear** Model (MountPart attribute). Never an Accessory (Accessories don't follow `ScaleTo(1.25)`). Inside the outfit is simpler; gear is for pieces worn on several skins. | 100% one part |
| Boots | Built closed shapes, inside the outfit mesh | shin + foot |
| Coat / robe / dress / apron / long skirt | **ONE skinned robe** from neckline to hem (section 3) | torso top, hips + thighs for the skirt |
| Sleeves, trousers, bloomers | **Closed lofts**, bands and cuffs are rings OF THE SAME MESH with face colours | arm / leg parts, blend at elbow and knee |
| Lapels, collar, cuffs, trim | A **real fold of the same mesh**, standing off 0.15 studs | same as the cloth under it |
| Swinging cloth (tails, skirt sway) | SmartBone chains on top of the leg weights: **TO ADD**, section 9 | |
| A layer over another layer (apron over a dress, waistcoat under a coat) | Its own closed piece, standing off the cloth under it (>= 0.05), with **the same weights as the cloth under it** at each point (copy from the nearest robe point). Not yet built on a shipped skin: gate it hard. | copied from the layer below |

Close-fit Layered Clothing (cages) works only for snug, short garments and never for a long coat; see failed routes.

**Another employee?** The recipe is the same; the files differ. Body: `characters/launch/animation-workbench/workflow/output/<name>/<Name>_controls.blend` (Pippa, Cappy, Prickles). Deform skeleton: `<Part>Bone` bones at that character's template joints; earlier per-character exports to copy from are `characters/skins/release/gloom_carnival/r2_pippa/p7_export.py` and `r2_cappy/c6_export.py`. Pose set: rebuild `pose_set_a3.py` from **that** employee's live clips (its registry entries: idle, crouch idle, walk, run, crouch walk, fidget, select, hire reveal, emote, ability clips). Numbers like the EB crouch weights are Prickles' starting point, not a rule: sweep them per skin with the pose gate.

## 3. The route that works, step by step

Tools: Blender 5.1 headless (`blender -b --disable-autoexec -P <script> -- <args>`). Body: the character's controls
blend (Prickles: `characters/launch/animation-workbench/workflow/output/prickles/Prickles_controls.blend`), T pose,
front is -Y, his left is +X, 1 unit = 1 stud.

1. **Plan page first.** Concept crop next to the plain character. List every piece with its build from section 2.
   Ask the owner yes/no by piece name (hat, lapels, coat, bloomers, boots). Ask about goo/effects.
2. **Blockout** (`ss_blockout.py`). Size every piece from the concept (measure px per stud from the head width and
   height). Flat concept colours. Show front, side and three-quarter; get shape answers before detail.
3. **Reuse approved props** (the old hat file, `route2_whole/r2_built.boots()`). Remake cloth, not liked props.
4. **Build the robe** (`ss_robe.py`):
   - one parametric grid from neckline to hem; both halves share the back centre column above the vent;
   - warp grid columns so one column lies exactly on the lapel edge (or colour zones stair-step);
   - lapels and collar: the cloth rolls outward at the front edges and neckline and folds back over the coat,
     edge 0.15 off, gold piping on the flap edge, a notch where lapel meets collar so they never overlap;
   - the skirt hangs by **cloth simulation** (top rows pinned) over the bloomers and boots, collision thickness 0.05;
   - solidify with rim, so it is a closed shell.
5. **Close everything.** Sleeves = one closed loft each. Bloomer legs = one closed piece from hip down INTO the boot
   shaft. Recalculate every lofted normal OUTWARD (lofts come out inward, and Roblox culls back faces).
6. **Head clearance.** Push every vertex 0.05 below the head's underside (ray up from below). Drop the neckline so the
   collar roll clears without squashing. Big toon heads hide the upper chest: put chest detail lower than on a human.
7. **Weights** (`ss_export_remake.py`), limit 4, normalised:
   - robe top + lapels: UpperTorso, blending to LowerTorso at the waist;
   - skirt: hips + thighs. Hem: front panels follow their own thigh 0.95, sides 0.68, back 0.40, centre back split
     between both thighs; the waist row stays on the hips;
   - **bloomer top and skirt side must follow the thigh by the same amount at the same height**, or crouch pushes the
     puff through the skirt. Shipped crouch values "EB": `UP0=0.80 UP1=1.00 SIDEB=0.30 T1=0.40`;
   - sleeves: UpperArm blending to LowerArm at the elbow, weighted by **distance from the arm axis, never by height
     cuts**; bloomers: hips at top, shin below the knee; boots: shin + foot.
8. **Export** with the game's deform skeleton (`route2_whole/export_r25/Showstopper_R2_final.blend`, bones named
   `<Part>Bone`). Flat colours go into one small swatch texture per MeshPart. Each mesh under 20k triangles **without
   decimating** (decimate mixes swatch colours into shards): split into more meshes instead (SSR_Robe, SSR_Upper,
   SSR_Lower, SSR_Hat).
9. **Offline gates** (section 4). All pass before any Studio work.
10. **Colour check** unlit, then neutral light, then warm depot light (section 5).
11. **Ship** (section 6).

**When the owner looks**, in this order: (a) the plan page, (b) blockout renders, (c) each build round's offline
renders + gate sheets next to the concept, on the skin's artifact page, (d) only after a test player in Studio looked
right: `employeeoutfittest` in game, (e) his OK to make it the real skin. He never is the first to see it in game.

## 4. Gates (every one, every round, before Studio)

Details, commands and how to read them: [gates.md](gates.md).

| Gate | Pass |
|---|---|
| Holes (`gate_holes.py` + `gate_check.py`): body hidden as the game hides it, 16 views, magenta background, garment insides red | 0 red, 0 open edges per piece |
| Clipping on **every keyframe of every clip the skin will play** (`pose_gate.py`, pose set from the LIVE clips: idle, crouch idle, walk, run, crouch walk, fidget, nod, hire reveal, emote, ability in/out) | worst frame per clip reported; idle ~0; never worse than the last approved build. There is no fixed bar for crouch: report the numbers with renders and let the owner decide (Showstopper shipped at ~3% of points in crouch) |
| Head (`head_gate.py`) | 0 vertices inside the head |
| Hands, forearms and **spike / ear tips vs the head**, hand vs the other arm (`clip_gate.py`, `idle_arms.py` checks) | head gap > 0.06, no hand sinking > ~0.03 |
| Holes again on the **posed** scenes from the pose gate | 0 red |
| A "points inside" count | is not visible clipping. Check a render before gating on it (sleeves pressed into the coat behind their own front read clean) |
| Concept side by side, same angle | shape matches; owner says yes |

Validate any new gate by reproducing a known approved number first.

## 5. Colour and paint

- Flat colour per garment zone in one swatch texture. Colours sampled from the approved 2D.
- Check the texture **unlit from all sides first**, then lit.
- The depot light is orange. Red-leaning plum (#683256) reads maroon there; bluer purples (#6A3A8E, #4F2D7F) stay
  purple. Judge in neutral AND warm light (`render_idle.py ... PLUM=<hex> WARM=1`), then in the depot itself.
- No LIFT on colours (it turned a jacket red in the depot).
- A colour change = re-export (`ss_export_remake.py <dir> PLUM=6A3A8E`, hex without `#`) + re-PATCH + re-place,
  about 10 minutes. A separately textured hat keeps its old colour (it has its own texture file): say so when offering
  colours, and recolour its texture too if the owner wants it to match.
- Mesh limit: each MeshPart under 20,000 triangles (Roblox's per-mesh limit).
- For texture detail beyond flat colour (fabric weave, normal, roughness), use the **texture-pipeline** skill's
  style filter, and check it does not bring back smudges.

## 6. Ship checklist

Full steps and Studio rules: [ship-and-studio.md](ship-and-studio.md).

1. Offline gates on every clip pass.
2. Export.
3. Upload or PATCH the **test** asset: Icey Labs (group 189923277) **only**, never VentureMMO, only after the owner's OK.
   New asset: `../showstopper_tails/create_model.py`; same id: `lc_pilot/tools/patch_model.py <id> <fbx>`.
4. Place it (`place_remake.luau`: meshes in a Folder, Rig holders with `<Part>Bone` Bones at the template joints,
   HideParts / HideAccessories / SoloMeshes; asserts bones line up within 0.02). Skinned meshes must be welded to
   **LowerTorso**, not HumanoidRootPart, or they stay rigid.
5. Engine check: temp Workspace script builds builder-made employees, `EmployeeOutfitSystem.fit`, loops the live clips;
   one muted Play; captures; delete the temp.
6. The owner tries `employeeoutfittest <OutfitModel>`.
7. Only after his explicit OK: point `EmployeeRegistry`'s skin at the new outfit, art in **BOTH** places (lobby + Shift),
   push on `game/cleanup-crew`, owner real-play check. The owner saves and publishes the places.

## 7. When the skin exposes a bad clip

A skin with anything on the chest shows arm poses that were always wrong (Prickles' shipped idle had a hand 0.23 inside
his chest with no skin at all). Measure the plain character first (`idle_clip_probe.py`). Fixing his own idle means
re-posing every clip that starts, ends or holds it, then overwriting them in place (Open Cloud PATCH, same ids, backups
first). Full method: [clip-repose.md](clip-repose.md).

## 8. Plain answers to owner questions

- "Wouldn't robe collisions fix clipping?" No. Roblox does not collide skinned meshes with the body. A worn outfit
  bends only by its weights.
- "Wouldn't SmartBone fix it?" Only for parts that have bone chains. A skirt skinned straight to the thighs has none,
  so it needs a chain rebuild, the code merge, the package, tuning and re-gating: a day-plus, not a ship-day fix.
- "Can AI make the whole skin?" AI statues melt body and cloth together and smear paint. Use AI for rigid one-off
  props only, then hand-built shapes for cloth.

## 9. SmartBone cloth - TO ADD

> **This section is not written yet.** The owner's plan: SmartBone is the next step after this skill, then this
> section gets filled in from that work. Until then, do not ship SmartBone on a skin.

Known so far (from the tails test, 2026-11-15): [smartbone.md](smartbone.md).

## Red flags - stop and re-read

| Thought | Reality |
|---|---|
| "The old build is already approved, I'll keep it" | Old approvals were placeholders until this route. Remake cloth; reuse only liked rigid props. |
| "Hide his legs, the boots fit better" | Never hide his own limbs. Fix the boots. |
| "Stretch this sleeve to cover the gap" | Rejected. Build true-size cloth. |
| "Top plus separate skirt is easier" | Shows as a seam. One robe. |
| "Raise the lapel colour zone a bit" | Reads 2D. Real fold, 0.15 off. |
| "Decimate to get under 20k" | Shards the colours. Split meshes. |
| "Gate passes at rest and in walk" | Gate every frame of every live clip, crouch and emote included. |
| "It looks right in my render light" | Check unlit, then warm depot light, then the depot. |
| "Owner can look first, then I'll test in game" | Test player in the game's own idle and light first. |
| "AI painted it, close enough" | Plain cloth = one exact colour. |
| "Use the Studio id from earlier" | Ids change each restart. Match window name AND placeId. |
