# Skin route history: every route, what worked, what failed, why

Every route since 25 Oct 2026, built and shown to the owner. Read this before trying anything that is not the current
route ([SKILL.md](SKILL.md) section 3): it has almost certainly been tried. Each route ends with what is still worth
reusing. The decision guide built from all of it is SKILL.md section 2.

Paths: `$GC` = `E:/Projects/peekabu-game-systems/characters/skins/release/gloom_carnival` (untracked main checkout),
`$PP` = `$GC/pilot_prickles`, `$RT` = `$PP/roblox_tools`, `$LC` = `$GC/lc_pilot`, `$H` =
`E:/Projects/peekabu-game-systems/handoffs/skins-reevaluation-2026-11-09.md` (sections "H12" etc.), `$NOTES` = the
coordinator's side-session notes folder (`C:/Users/Bruk Abu/AppData/Roaming/Claude/side-session-notes/local_563d59fb-00af-49e0-842b-041a39c00a94`).

## The two causes under every failure

1. **The look was written by script or by an AI, not built to the concept**: shapes typed as numbers, a garment
   guessed by a generator, paint smeared by an AI painter. The owner judges "looks exactly like the concept, in 3D".
2. **A separate garment was forced onto the body and the joining step damaged it**: cut, caged, shrink-wrapped,
   re-weighted, decimated, re-baked. Every automatic fitting step hurt the surface.

What finally worked: build every piece by hand-written geometry to the concept's measured shape, as closed shells on
the real character, weight by simple rules, colour flat and exact (then real texture maps), and gate it on every frame
of every live clip before the owner sees it.

## Timeline

| Date (2026) | Route | Owner verdict |
|---|---|---|
| Oct 25-29 | Scripted Blender primitives: Legendaries (Bubble Buddy, PJ Cappy, Sheriff Prickles) | Bubble Buddy v2 "approved as final"; PJ hood "liquidy / strappy paste"; Sheriff "why are his legs gone!?". All later called provisional |
| Oct 28 | fwjelaa picture-to-model kit: 5 props + a Bubble Buddy showcase | "complete trash" |
| Nov 4 | Gloom Carnival Epics, scripted, 3 rounds | "it all looks really bad still" |
| Nov 4 | AI pilot: Qwen 2D gate -> TRELLIS 2 figure -> 4 automatic fit passes; clothes-only coat; segmented rigid coat | "the deformation / whatever was done completely has the skin ruined still!"; "I dont like the coat!!! Theres still holes" |
| Nov 4-6 | Layered Clothing (cages): own cages -> Roblox-made cages placed before ScaleTo + armpit and elbow room | first "its trash", then approved for snug garments: "Prickles is good now!", Pippa v4b "good enough", Cappy v2b "Ye looks good!" |
| Nov 5 | Hunyuan3D shell route: ball-jointed closed rigid pieces + 2D colour projection | "still doesn't look great" |
| Nov 6 | Garments grown from the body cage (lc_pilot): bloomers, boots, coat; two-piece coat | bloomers/boots clean; coat "looks like two pieces" |
| Nov 6-9 | Skinned long coat v5, revs 1-17 | rev 17: "reevaluate COMPLETELY" (fit and motion) |
| Nov 9 | Route 1 jacket A: snug layered short jacket | "looks SUPER 2d"; "armpits and shoulders look wrong" |
| Nov 9-10 | Route 2: Hunyuan3D-2mv whole dressed figure knife-cut into rigid pieces, AI parts replaced by built ones (revs 18-29) | "finalized until we hire a modeler", registered; on Nov 16: "only because I knew a skin session to remake skins was going to be done!" |
| Nov 11-12 | Carnival skins: Backstage Cappy v1-v8, Bell Jester Pippa v1-v7 | v1-v4 failed ("where are his knees?!"); fully built rebuilds passed: "Pass, register it", "Good enough for now!" (provisional too) |
| Nov 15 | Showstopper tails: pattern pieces hung by cloth sim, Robust Weight Transfer, tail chains on a spring; SmartBone picked. Gloom skins dropped; Diner Epics (Grill Boss) started | six chains on the simple spring: "twitch, clip, rumple over the top on jump" |
| Nov 16-17 | **The current route**: Showstopper remake (one robe, built pieces, rule weights, every-clip gates), textures, SmartBone V3/V4 | "THIS IS THE BEST SHOWSTOPPER HAS LOOKED"; V4 "Yes its good enough!" |

---

## 1. Scripted Blender primitive skins (Oct 25-29, Nov 4)

- **What:** Blender Python assembles garments from lathes, swept tubes, SDF shells and shrink-wraps on the real rig;
  per-clip clipping audits; bake, decimate, export. Legendaries: `characters/skins/release/bubble_buddy/`,
  `pj_cappy/`, `sheriff_prickles/` (+ `characters/skins/runtime-candidates-2026-10-26/`). Carnival Epics round 1-3:
  `$GC/blockout/`, `$GC/detail/` (2 meshes Cloth + Trim at 18k each).
- **Worked:** Bubble Buddy v2, a targeted fix of four named flaws (goggles, pockets/snaps, boots, duck emblem) where
  every difference to the locked sheet became a build rule, Pippa proven unchanged, clipping measured every second
  frame of every clip. Owner: "approved as final" (later provisional). Built outfits held in game once bones had the
  `Bone` suffix and meshes welded to LowerTorso.
- **Failed:** PJ Cappy's hood as a shrink-wrapped drape: "looks more like a liquidy / strappy paste onto head / hair
  than a hood like the reference" (his rule: follow the reference, it "will not fail / lead you astray"). Sheriff's
  leg mask hid his real lower legs: "why are his legs gone!?". Carnival Epics: "it all looks really bad still",
  "Blender MCP is not the best approach for skins".
- **Why:** shape typed as numbers by an agent that cannot sculpt drifts from the concept; clip metrics were optimised
  over the silhouette; hiding limbs. "A method limit, not a tuning problem" ($H section 2). Decimating to 18k thinned
  the piping.
- **Reuse:** per-clip clip audits; "same angle, concept beside model" before building; three styles share one
  geometry. NOT reused: drapes, shrink-wraps, leg masks. The current route is also scripted geometry, but it measures
  the concept (px per stud) and builds real closed folds; the difference is shape from the concept, not from guesses.

## 2. fwjelaa "Picture to Roblox Model" kit (Oct 28)

- **What:** a free Blender + Claude kit (`C:/Users/Bruk Abu/Downloads/Picture-to-Roblox-Model-by-fwjelaa`, copy in
  `characters/tools/picture-to-model/`): scripted shapes compared to a picture, baked. Made 5 Legendary props x 3
  styles + a static Bubble Buddy showcase (`characters/skins/release/kit-props/`, `KIT-PROPS-REVIEW.md`).
- **Failed:** "complete trash"; the earlier drafts were "exponentially better".
- **Why:** the showcase rebuilt Pippa instead of using her (identity lost); generic vinyl-toy blobs below the props'
  bar.
- **Reuse:** nothing. Never use the kit for skins or props unless the owner asks again.

## 3. Qwen Image Edit 2D gate on the real character (Nov 4, kept)

- **What:** local Qwen Image 2.1 edit (ComfyUI) dresses the REAL character's own front/side/back renders from the
  concept; the owner approves the 2D before any 3D (`$PP/comfy_edit.py`, `$PP/2d/`, `$GC/route1_2d/`).
- **Worked:** "the owner approved it on the first try"; face, spines, proportions kept. Ghost-mannequin (clothes only)
  also worked first try.
- **Failed:** "side" came out three-quarter; ghost coat taller and thinner; arms 45 degrees down fused forearms to the
  coat; a redraw put a waistcoat on the back.
- **Reuse:** yes, for any route when the concept lacks views: approve front/side/back of the real character, arms
  about 30 degrees down. Measure sizes from the approved images, never from improvised sides.

## 4. TRELLIS 2 / Pixal3D image-to-3D (Nov 4; PJ slippers Oct 29)

- **What:** ComfyUI workflows (`3d_pixal3d_trellis2_image_to_model.json`, multi-view `pixal3d_multiview_bf16`):
  whole dressed figure (9 min, 698k faces), then four automatic fit passes (align to rig, colour-cut the body away,
  split, decimate, shrinkwrap, weights from the body, recolour; then remesh; then geometry cut + UV-keeping decimate;
  then front+back multi-view). Scripts `$PP/comfy_3d.py`, `fit_stage1-5.py`, `fit_v3.py`, `merge_v3c.py`.
  Clothes-only "ghost mannequin" coat (`$PP/coat_test/`, the owner's idea). Segmented rigid coat (`$PP/segmented/`).
  PJ Cappy slippers v3-v6 from a smoothed TRELLIS shape.
- **Worked:** the RAW figure "looked close to the concept" (every piece where the 2D had it); aligning the generated
  body to the real one by uniform scale + move placed everything; front+back made a real back; the raw clothes-only coat
  and its UV-keeping 3-part reduction stayed crisp; the segmented rigid coat moved cleanly at game distance.
- **Failed:** "the deformation / whatever was done completely has the skin ruined still!"; coat: "I dont like the
  coat!!! Theres still holes in the mesh, etc!"; segmented coat: shoulder gap in walk, ragged edges.
- **Why:** TRELLIS returns one fused picture-quality statue (body, cloth, spines, small parts), not garment topology.
  Removing the body tears cloth where they touch; colour cut-outs delete small parts; shrinkwrap and smoothing dent
  it; decimate jags it; re-bakes bring back baked lighting; nearest-body weights bend it like skin. The coat was a thick
  shell with an inner lining: a dropped arm pushes the lining through the panel (no correctives in Roblox). Single
  views invent the back (extra fins on PJ's slipper, a second flower).
- **Reuse:** a RAW shape reference; rigid one-off props (then repaired: Props table, kit-props row). Never an outfit body. Never
  any automatic fitting step on an AI surface.

## 5. Hunyuan3D-2 / 2mv shell route (Nov 5)

- **What:** Hunyuan3D-2 (`E:/AI/HY3D2`, ~92 s) makes ONE closed statue from the approved front (2mv `E:/AI/HY3D2mv`
  from front+back); `shell_build.py` cuts it into one rigid watertight piece per R15 part, each seam a SPHERE centred on
  the joint pivot (no gap opens when the part turns); real head and hands carved out and kept; colour projected from
  the approved images and snapped to the palette; no weights, cages or re-bake. `$PP/shell/` (ROUTES.md, shell_build.py,
  clip_anim.py, cfg_*.json).
- **Worked:** 13 pieces, all watertight, ~55k tris; no holes or tearing in the real clips; arms 30 degrees down (not
  T pose) removed shoulder holes; the whole coat as ONE piece on UpperTorso removed waist cracks.
- **Failed:** first "loads of holes around shoulder and arm in idle / walks looks super off with coat"; after fixes
  "still doesn't look great": seam rings, a dark fin on each shoulder in the crossed-arm idle, blotchy colour, ragged
  lapels, a guessed back.
- **Why:** motion was solved, the look was not: an older generator from one view, colour re-projected from two
  pictures onto a shape that did not match them.
- **Reuse:** joint-sphere seams for rigid pieces; dress at arms ~30 degrees; review motion on video of the real clips
  (`clip_anim.py`); one coat = one piece on one part.

## 6. Layered Clothing with cages (Nov 4-6; approved for SNUG garments)

- **What:** Roblox Layered Clothing: a garment Accessory with WrapLayer and inner/outer cages wraps the body's
  WrapTarget cages. Tools in `$RT/phase4/` and `$RT/perf/`; detector `holes_detect.py`.
- **Steps and verdicts:**
  1. Own template-fitted cages + TRELLIS coat (Nov 4): "its trash". Cause measured: coat inside its inner cage and
     outside its outer cage, the body poking out of its own cage, spines outside it.
  2. `fit_cages_v2.py` (Roblox's one connected `std_cage_deformable`, roll-free mapping, points pushed radially past
     the body incl. spines): a Roblox sample jacket held in real Walk.
  3. Avatar Setup (Studio MCP `auto_setup_avatar`): its body went GREY (empty 64x64 maps), fused the FacePlate,
     swapped Motor6Ds, made ~30 assets per run: NOT adopted. Its CAGES are what fit: the same cages on our original
     body fit just as well.
  4. **Cage ORDER was the decisive fix:** cages pre-placed on the template at scale 1 BEFORE the game's
     `ScaleTo(1.25)` (game scripts cannot set `WrapTarget.CageMeshId`, so cages live on the templates in Studio, both
     places). Spot frames 49/52 -> 28/52, none at the shoulders.
  5. **Armpit room** (`armpit_cages.py`: 0.10 at template scale, seams frozen, fold guard) and **elbow room**
     (`elbow_cages.py`, 0.08): owner "Prickles is good now!". `joint_room.py` generalises per employee (amounts scaled
     by UpperTorso cage width / 0.992). Pippa v4b (armpit 0.14, back 0.08, armpit-back 0.08, tail pulled out of the
     cage) "good enough", with a known speck on her own left side behind the arm on jumps. Cappy v2b (v2 torso + v1
     arms) "Ye looks good!". Ids: `$RT/employees/<Name>/joint_ids*.json`.
- **Failed / limits:** "too many holes - not pursuable!" (cages added after the scale); engine settings
  (WrapTarget.Stiffness, WrapLayer.Puffiness, AutoSkin) did nothing; EditableMesh test bodies ALWAYS show false holes
  (never judge fit on them); roomier cages in one go tore the collar.
- **Why it is close-fit only:** the engine deforms cloth by its nearest cage point. Cloth more than ~0.1 stud off the
  body is squeezed (a flared skirt came out half width) or torn where the arms reach (crossed-arm idle). An engine
  limit; cage edits cannot remove it. And snug reads painted-on (section 9).
- **Reuse:** the approved per-employee cages ARE on the templates (keep them); the route for a genuinely snug
  garment (a tight shirt or leggings) if the owner wants one; the rules: defining features (spines, tail, ears) poke
  out of the cage; the 4,000-tri layered cap; cages always before ScaleTo; test every garment on the stock R15 body
  first; judge in real Play with the detector plus eyes. Full redo order: `$RT/phase4/PIPELINE_PLAN.md`,
  `$LC/RECIPE.md` (its status header is stale).

## 7. Garments grown from the body cage (lc_pilot, Nov 6)

- **What:** garments built FROM the employee's body cage (`$LC/tools/base_cages.py`, `cage_garment.py`, `coat_v2.py`):
  cage faces pushed out along normals, solidified >= 0.035, <= 3,850 tris, outer cages by `garment_cages.py`; colour by
  `project_2d.py` (the approved 2D projected per texel with visibility rays and piece labels); wide stiff shapes (coat
  skirt, hat) as rigid fitted gear.
- **Worked:** bloomers first try; the cage-grown coat held in idle, walk, run, jump, crouch walk and a truck boarding.
  Hat as a fitted-gear Model (`MountPart`), never an Accessory.
- **Failed:** the TRELLIS coat re-caged still tore in the crossed-arm idle; the close-fit coat body + rigid skirt:
  "looks like two pieces"; project_2d filled unseen areas from the nearest colour (cream smears under the arms).
- **Why:** layered limits (section 6); two garments for one coat show a seam.
- **Reuse:** bloomer and boot shapes; "fill unseen texels with the fabric colour by rule, never nearest colour".

## 8. Skinned long coat v5, revs 1-17 (Nov 6-9)

- **What:** ONE skinned outfit (`EmployeeOutfitSystem`): coat shell + trim + inner, loft and sleeve tubes voxel-fused,
  weights from hand-written rules (`$LC/coat5/wfun.py`, recipe `$LC/coat5/LONGCOAT_BASE.md`), details as raised slabs
  (constrained Delaunay), body hidden by HideParts. Bloomers/boots layered, hat gear.
- **Worked (and still law):** one outfit for a whole garment; bones named `<Part>Bone`; skinned meshes in a Folder,
  welded to **LowerTorso** (welded to HumanoidRootPart they stay rigid in bind pose); bones within 0.02 of the joints;
  sleeve weights by DISTANCE from the arm axis (height cuts dragged the side panel in: the "gap"); Roblox culls back
  faces (offline renders must cull too; compute normals before any orientation vote). Owner: colour and fabric "look
  nice".
- **Failed:** rev 17: "reevaluate COMPLETELY". The fail was "fit and motion (stretching, colour patches at certain
  points)"; along the way: hunch, puffy chest, dark pockets, stretching on jumps, a back-shoulder tear in vacuum use.
- **Why:** shape from width tables and bending from typed formulas, 17 revisions each fixing one symptom; the coat
  had no bones of its own, so the hem could only follow the torso or the legs (both wrong for tails).
- **Rejected inside it:** Robust Weight Transfer from the Avatar Setup body (only ~35 % of a long coat is near the
  body: the hem gets leg weights and tears) and the play-pose bake (inverse skinning: one pose clean, arms-up
  shattered).
- **Side result:** Blender automatic weights on ONE closed, snug, body-like shell bend cleanly in every pose (rig test,
  $H 6b): the rig is fine; loose cloth far from any bone is the problem.
- **Reuse:** everything in "Worked"; the current route's weights descend from wfun.py's rules.

## 9. Route 1 jacket A: snug layered short jacket (Nov 9)

- **What:** the owner's own rule for route 1: no loose cloth across a joint; a short jacket from the cage-grown coat
  body, colour by project_2d.
- **Worked:** held in idle, walk, run, jump, crouch walk, vacuum, sit and hide.
- **Failed:** "looks SUPER 2d", clothes are 3D, it "can't be maintained / be final"; then "armpits and shoulders look
  wrong".
- **Why:** snug layered solves fit by flattening the garment onto the body: lapels, waistcoat and toggles become
  paint.
- **Reuse:** as a fit-and-motion test only. Every finished skin needs real volume and real 3D details.

## 10. Route 2: whole dressed figure knife-cut into rigid pieces (Nov 9-10)

- **What:** Hunyuan3D-2mv makes one closed dressed figure from the approved front+back (arms 30 degrees down), fitted by
  ONE uniform scale + move on the real hands and head (only the lower legs stretched to the floor), plane-cut into 12
  rigid pieces with balls on the joints, real head/hands/flower kept, painted by Hunyuan paint
  (`enable_model_cpu_offload()` or it stalls), exported as a skinned outfit. Then, rev by rev, AI parts were replaced
  by BUILT ones: sleeves (rev 23), hem, waistcoat point, trousers, boots (`r2_built.py`, rev 25-27). `$GC/route2_whole/`
  (r2_fit, r2_cut, r2_built, r2_export, GATES.md); asset 123759504597910 rev 29, hat 130595513137797 rev 7.
- **Worked:** real volume; no holes in real Play incl. sit and hide; each owner note was fixed by replacing AI
  surface with a built shape. "Skin looks good though!", "finalized until we hire a modeler", registered.
- **Failed:** "textures look stretched and NOT same color", "obvious miscolouring / smudging" (AI paint); a 3.8x
  stretched sleeve; LIFT on colours turned the jacket red in the depot light; SLIM 0.70 (arms looked missing) made it
  slimmer than the 2D; "weird cone on top of collar" (neck cut through the AI head's flare); rigid shells overlap at
  elbows, knees and waist. Nov 16: the approval was provisional.
- **Why:** AI surface cannot be controlled (lumpy, ragged lapels, per-piece colour, tiny atlas scraps); rigid
  per-part cutting cannot bend cloth; numbers tuned for one figure, not a pipeline.
- **Reuse:** `CLEAN=1` (plain cloth one exact colour); never stretch a piece; unlit sheet from all sides before lit
  renders; no LIFT; `r2_built.boots()` and the old hat (reused in the remake); export checks (open edges 0, weight
  error < 0.001, <= 4 influences, < 20k tris per mesh).

## 11. Carnival skins: Backstage Cappy v1-v8, Bell Jester Pippa v1-v7 (Nov 11-12)

- **What failed first (Cappy v1-v3, Pippa v1-v4):** reused Route 2's FIRST-day cut: hid every limb and showed AI legs,
  a waist cut plane sliced the coat across two parts, AI paint blotches, no unlit sheet, no ledger, the owner was the
  first in-game tester. Owner: "where are his knees?!", "we didn't use the lessons learned from showstopper"; Pippa
  "looks fatter, gold specks, bells not round, floating black lines on the bells". Review:
  `$NOTES/carnival-skins-lessons-review-2026-11-11.md`.
- **What passed: fully BUILT rebuilds, no AI mesh or texture** (`$GC/r2_cappy/c8_cut.py`, `c7_export.py`,
  `c6_bow.py`; `$GC/r2_pippa/p7_cut.py`, `p7_export.py`, `p7_bow.py`; ledgers GATES_v4-v7):
  - **Ray-cast shell**: one coat surface collar to tails grown by ray-casting the real torso (`far(bvh, angle, z)`
    grid, chest clearance 0.10, hips 0.055; Pippa 0.04 + 0.05 hip bulge), one weight function, dark lining, closed hem.
  - **Folded lapel flaps** with a notch; gold piping as ONE **mitred swept tube** per run (`jointed()`: ring stretched
    across each bend by 1/max(0.38, d1.t)). A plain swept tube pinched flat at corners in game; separate tubes + balls
    looked beaded; a line sunk into the cloth read as dashes (lift it 0.02 clear).
  - **Flat colour blocks** (one per material, every face at its block's middle) + one drawn tile for patterns; the
    exporter stops on any face without a colour rule; prove a tile is clean by counting its colours.
  - Pippa: romper legs as puffed tubes riding their own upper leg; a ball round each hip covers thigh tops in a crouch;
    capelet a lined shell standing 0.30 off, side flare cut to 28 % ("stuck out like wings"); bells their own mesh,
    Metal + Reflectance 0.25; bells and bow **CastShadow off** (their shadows read as smudges on the diamonds).
  - A prop that does not look like the reference becomes its own rigid prop (the owner's idea for Cappy's bow).
  - Owner: Cappy v5 "VERY CLOSE", v8 "Pass, register it"; Pippa v7 "Good enough for now!".
- **Still open at registration:** hide pose, emote, second client, real Locker; capelet smaller than the concept and
  pink-plum in the depot light. Both are provisional (remake pass).
- **Reuse:** the lessons checklist (keep limbs, one garment one piece, CLEAN colour, built shapes, unlit sheet, test
  player first, ledger) and every technique above.

## 12. Showstopper tails and the SmartBone precursor (Nov 15)

- **What:** `$GC/showstopper_tails/`: the skirt as two flat PATTERN pieces hung by Blender cloth simulation against
  the real bloomers and boots ("folds and flare come from the sim, not formulas"), Robust Weight Transfer from the
  bloomers plus overrides (front panels ride their own thigh; the waistband follows the jacket), two 3-bone tail
  chains on the game's simple spring (`EmployeeTailSystem`), every-keyframe gate on real clip data
  (`gait_all.py` -> `pose_all.json`).
- **Worked:** idle, walk, run clean (0/91, 0/49, 3/37 frames poking); the cloth-sim hang (kept in the current robe);
  the every-keyframe gate; the tip-bone convention; flat chain bones under the LowerTorso holder.
- **Failed:** crouch 91/91 frames poking; six skirt chains on the simple spring: "twitch, clip, rumple over the top on
  jump"; heavy-wool SmartBone settings "too rigid".
- **Why:** the spring was made for two back tails; independent chains stretch the cloth between them; crouch was a
  weight mismatch at the hip (solved later by matching thigh-follow).
- **Reuse:** led to SmartBone ([smartbone.md](smartbone.md)) and the remake's pattern of rule weights + chains on top.

## 13. The current route: Showstopper remake (Nov 16-17)

[SKILL.md](SKILL.md) section 3, [textures.md](textures.md), [smartbone.md](smartbone.md). One robe (grid neckline to
hem, real lapel folds 0.15 off, cloth-sim skirt), closed built pieces, rule weights with matched thigh-follow, every
clip gated offline, test player before the owner, CC0 texture maps, SmartBone chains on top. Its own failures are
the piece-level rows below.

---

## Props (hats, boots, bows, held props)

| Attempt | Verdict | Rule it left |
|---|---|---|
| Hat as an Accessory | wrong size after `ScaleTo(1.25)` | Fitted-gear Model with `MountPart`, WorldPivot = the template part's frame, modelled at template size; or a mesh inside the outfit at 100 % on its part. |
| Showstopper hat revs 3-7 (Nov 10): two gold rings; the base flower modelled into the hat hovering, then sunk into the crown, then moved to the base spot | "Two gold rings"; "too high / too connected with the other hat"; "isn't the flower a separate prop anyways?" | Base pieces (flower, spines, earbuds) keep their base spot and size, as their own parts; check in the live place what the base pieces are before copying any into a skin. Uploaded meshes centre on their bounding box, so a geometry change moves the mount offset. |
| Boots in the remake blockout | "read as socks" (with the hat height wrong) | Reuse the approved built boots; legs stay visible above them. |
| Bell Jester boots v6 | foot specks through the boot in a run (fixed in revs 7-8, then passed) | Thicker boot walls, sole a hair lower; check feet inside boots on every clip. |
| Cappy's bow as part of the coat (v4) | "doesn't look like reference at all ... why dont we seperate that as a prop?!" | Separate rigid prop; one flat colour, no gradient strip ("smudges and specks"). |
| Bells and bows casting shadows | dark smudges on the cream diamonds | `CastShadow` false on small shiny bits. |
| Cappy earbuds (base part, Nov 10) | "too far out, should be closer to his face" | Tune base-prop mounts on test copies of the template in Studio, option sheets by letter, owner picks. |
| Legendary held props, first version (Oct 29) | every prop turned 180 degrees, hose 4.5 studs off the hand; wand drifting 0.7; lasso through the head | Mount as A*R*A; glue props to the hand in clip space; per-frame clearance vs head, ears, goggles; prop timing by `PropsShow`/`PropsStow` markers in the clip; worn props get a Holster twin. |
| Goggle lenses invisible | wound inside out; Roblox culls back faces | Recalculate normals outward; render with back-face culling. |
| fwjelaa kit props; hub round-3 quick kit props (cash register, espresso machine, leaves) | "complete trash"; "a big no", "don't look right again" | Reuse first (Office kit, cargo, yard kit, the character's own liked props). A new prop = the Office two-pass procedure: texture pass from CC0 scans through the style filter, then a hand-built model baked with them (texture-pipeline skill; `TEXPIPE_WORK` must hold the scans or it silently paints flat). AI image-to-3D only for one-off soft/organic rigid props, then repaired (`rebake.py`, EMIT bake); thin shells always hand-built. Never quick kit props. |
| Pasting prop art from one place to the other | hand props vanished in Shift | Studio drops joints to things outside the copy: run the placing script in each place, or recreate the Motor6Ds. |
| Grill Boss Prickles (Diner Epic, Nov 15) | built offline only (jacket + trousers grown from the inner cage, a long apron), never exported or judged | A long apron over trousers is the untested "layer over another" case: gate it hard. Files untracked in worktree `fervent-greider-cee995`. |

## Animations skins needed

| Attempt | Verdict | Rule it left |
|---|---|---|
| Prickles' shipped idle under a chest-covering skin | hand 0.23 inside his chest with no skin at all | Probe the plain character first; fix the character's OWN idle and re-pose every clip that touches it ([clip-repose.md](clip-repose.md)); A3 approved: "Prickels a3 looks good!" |
| Wrist bends alone for crossed hands; weak per-frame pulls; interpolated fades; joint-space slerps | hands through each other, popping seams, arms through the body | Layer the cross; blur weights over time; sequential per-frame correction; never a straight slerp while the body moves. |
| New animation ids for fixed clips | the owner prefers same ids | Open Cloud PATCH overwrites animations in place (not audio: 400). Back up first; confirm serving in Studio. |
| Per-character hide / vacuum fixes | rejected (owner rule, 2026-10-18: SKILL.md section 1, generic poses) | Shared poses get generic rules over part extents only; the vacuum hold clipping is a post-launch item. |
| Furniture too small for the scaled employees | hide clipping seen by others | "The furniture grows to fit the characters; the characters never shrink." |

## Piece-level failures inside the routes

| Attempt | What happened | Do instead |
|---|---|---|
| AI-painted plain cloth | "miscolouring / smudging" | One exact colour per plain cloth (`CLEAN=1`), then real texture maps that keep it. |
| Stretching a sleeve 3.8x to cover a gap | rejected | True-size cloth. |
| Coat top + separate cloth-sim skirt (remake rounds 1-3) | "obvious stitches / seam" | One robe. |
| Lapels as a raised colour zone (0.03) | "looks almost 2D / attached to body" | Real fold of the same mesh, 0.15 off. |
| Lapels as fan-filled sheets projected on an ellipse | holes, floating gold wires | Build from the robe itself. |
| Rolled tube collar | clipped into the head | Clamp 0.05 under the head's underside, lower the neckline. |
| Loose gold rings on sleeves, cuff rings on bloomers | "holes all over" | Bands are rings OF the closed piece. |
| Decimating joined multi-colour clothing | dark cuff band turned to shards | Split meshes (a one-colour shell before its UVs may be decimated). |
| Sleeve weights cut by height | gap in the side panel at idle | Weight by distance from the arm axis. |
| Donor weight transfer / play-pose bake for long coats | arms-up and walk broke | Rule weights. |
| Skinned outfit welded to HumanoidRootPart; meshes in a sub-Model | rigid in bind pose | Weld to LowerTorso; meshes in a Folder; bones `<Part>Bone`. |
| LIFT on colours; red-leaning plum #683256 | red / maroon in the depot light | No LIFT; bluer purple #6A3A8E; judge unlit, neutral, warm. |
| Bloomers as three overlapping closed pieces | "loads of seams or areas of clipping" | One voxel-remeshed shell per garment. |
| A designed dark cuff band | "a section of black" | Ask before any contrasting band. |
| Flat swatch export as the finish | "bland", "no textures" | Texture round. |
| DIFFUSE colour bake; AO across pieces | gold black; dark seam lines | EMIT bake; AO only_local. |
| Coat recoloured, its hat left alone | "make the hat violet too" | Recolour the prop's own texture by HSV. |
| Trusting a PATCH because a server-built model drew | "legs missing" in the owner's Studio | Client `GetAssetFetchStatus`; nudge for a new mesh id. |
| Six skirt chains on the simple tail spring | "twitch, clip, rumple over the top on jump" | SmartBone with the outfit's colliders. |
| SmartBone chains spaced 60 degrees over a touching puff (V4) | "It still clips through the puffed up pants" | 8 chains, ~0.06 clearance over puffy layers; bigger colliders push the cloth out at rest. |
| Granting the skin to a real account to test it (older handoffs) | data written to the owner's profile | Builder or `employeeoutfittest`. |
| Hard-coded Studio ids | worked in the lobby while thinking it was Shift | Match window name + placeId ([odd-hours.md](odd-hours.md)). |

## Tools and their verdict

| Tool | Verdict |
|---|---|
| Qwen Image Edit 2.1 (local) | Keep: the 2D gate on the real character. |
| TRELLIS 2 / Pixal3D (local, MIT) | Shape reference and one-off rigid props only (then repaired). Shells are open/fused. |
| Hunyuan3D-2 / 2mv + paint (local) | Whole-figure tests only; paint smears. The texture-pipeline skill avoids Hunyuan3D for shipped props (its licence excludes the EU/UK/South Korea). |
| Avatar Setup (`auto_setup_avatar`) | Its 15 cages yes (already on the templates); its body no (grey, fused face, Motor6D swap, ~30 assets per run). |
| Accessory Fitting Tool / "SkinBench" | Proposed (11-15) as an Edit-mode bench folder in Shift; never confirmed run. AFT edits cages, cannot fix loose cloth. |
| EditableMesh test bodies | Always show false holes. Never judge fit on them. |
| Engine wrap settings (Stiffness, Puffiness, AutoSkin) | Did nothing for tears. |
| Robust Weight Transfer (Blender add-on, GPL) | Near-body pieces only (tails from bloomers + overrides); never a long coat. |
| Blender automatic weights | Fine on one closed snug body-like shell. |
| Tripo / Meshy / Rodin (paid) | Not used so far. Same statue limit; if ever, rigid props only, free tier first, owner's OK before any spend. |
| Human 3D modeller | The owner's fallback ("finalized until we hire a modeler"); brief and contract ready in `$PP/artist_handoff/`, never sent. |
| SmartBone 2 (Wally, MIT) | In the game; the cloth-motion route ([smartbone.md](smartbone.md)). |
