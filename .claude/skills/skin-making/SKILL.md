---
name: skin-making
description: Use when making, remaking, fitting, texturing, recolouring, gating, shipping or fixing a skin, outfit, worn prop or cosmetic for the team's Roblox employee characters (Odd Hours / Cleanup Crew - Pippa, Cappy, Prickles, any later employee or game) - coats, robes, dresses, aprons, skirts, capes, hoodies, bloomers, boots, hats, lapels, bows - when turning a 2D concept into a 3D skin, and before trying AI 3D generation (TRELLIS, Hunyuan), Layered Clothing cages or any older skin route. Also when a skin is called 2D, flat, bland, plastic, painted-on, "looks like two pieces", seamed, holes all over, torn at the armpits, clipping, twitching, smudged, maroon in the depot light, "a section of black", "where are his knees / legs", when a piece or the legs vanish in previews or when worn, when a skirt or cape flips on a jump, clips when running or pokes in crouch, when cloth should swing (SmartBone) or looks too rigid, or when a new idle makes arms go through a skin.
---

# Skin making

A **skin is the same character plus additions**. Never remodel the character. The owner judges two things: **does it
look exactly like the concept, in real 3D**, and **does it hold up in the real game clips and light**. Every route
that missed either one failed ([failed-routes.md](failed-routes.md)).

The route here is the one that worked: the **Showstopper Prickles remake** (owner 11-16: "THIS IS THE BEST SHOWSTOPPER
HAS LOOKED"; textured, then SmartBone V3/V4 11-17). Start every new skin from it, never from an older half-built route.

**Files:** this page is the recipe. [odd-hours.md](odd-hours.md) holds every game-specific id, path, character file,
code file and the rarity ladder. Details: [gates.md](gates.md), [textures.md](textures.md), [smartbone.md](smartbone.md),
[ship-and-studio.md](ship-and-studio.md), [troubleshooting.md](troubleshooting.md), [clip-repose.md](clip-repose.md),
[failed-routes.md](failed-routes.md) (the full history of every route since Oct 25), [scripts/](scripts/README.md).

## 0. Before anything

- **A fix or a "why does X look wrong"?** Go to [troubleshooting.md](troubleshooting.md) first: check before code.
- **What kind of job?** Pick the row; don't run the whole route for a hat.

| Job | Route |
|---|---|
| New outfit skin (coat, dress, hoodie, robe...) | Sections 1-6, 8 and 9 (7 only if a clip is bad) |
| One worn prop (hat, glasses, bow) | Rarity first (a lone accessory may not fit the ladder: ask). Plan page, build the prop (section 2 row), the prop gates (section 4), textures, place as fitted gear, register |
| Recolour only | Rarity Uncommon: palettes, no mesh work. Judge unlit + warm light |
| Re-texture an existing skin | [textures.md](textures.md) on its existing export; re-run every gate; new mesh ids -> fetch check |
| Make cloth swing | [smartbone.md](smartbone.md) |
| A skin exposes a bad clip | Section 7 |

- **Session hygiene.** A build round is one fresh session with a brief file in the build folder (what is live, the
  owner's notes verbatim, what to do, the rules). End each round with a handoff file and a lessons file; fold lessons
  into this skill. Long jobs (bakes, renders) run in the background while you do other work; never spend a turn only
  waiting. Subagents get an explicit model tier. Studio slots come from the coordinator ([odd-hours.md](odd-hours.md)).
- **The build folder** is untracked (`characters/skins/...`), with copies of the scripts (paths changed) and a
  `GATES.md` ledger: each gate, command, result and evidence image. Skins built without a ledger failed in front of
  the owner.

## 1. The owner's rules (state how each is met in your plan)

| Rule | What it means in practice |
|---|---|
| Keep the base character | Own head, face, hands, ears, tail, spines, flower stay, at their base spot and size. Check in the live place what the base pieces ARE before copying any into a skin. Code-driven parts (ears, tails) are never covered or stiffened. |
| Never hide limbs to make clothes fit | Hide only what the outfit truly covers (HideParts / HideAccessories). "Why are his legs gone!?" and "where are his knees?!" both failed skins. |
| Match the concept 1:1 | Same outline, volume and scale as the 2D, side by side from the same angle. "Make it look like the concept" is the bar; shape first, clip numbers second. |
| Real 3D depth | Clothes are thick. Lapels, collars, cuffs, pockets, trim stand off the cloth. Painted-on or snug = "SUPER 2d" = fail. |
| One garment = one piece | Never cut a garment across meshes or body parts; never several overlapping pieces for one garment. |
| One exact colour per plain cloth | Flat concept colour; texture detail varies around it, never shifts it. No AI paint on plain cloth. No contrasting band unless asked. |
| Rigid props stay props | Props the owner liked (hat, flower, boots) are reused, not rebuilt. |
| Deliberate prop construction | Shoes, bells, bows and ornaments need coherent silhouettes, real openings and convincing attachment points. A pile of intersecting blobs/tubes is a blockout, not a finished prop. See [footwear.md](footwear.md). |
| Cloth motion is part of the skin | Decide moving vs rigid pieces during ideation. Build physics for the moving pieces and showcase it in Studio before handoff; never wait for the owner to request a separate physics pass. See [smartbone.md](smartbone.md). |
| Ask before effects | No goo, drips or glow unless that skin's owner answer says so. No face on Gloom art. No 4-point sparkle star. |
| Generic poses stay generic | Shared poses (hide, sit, vacuum, carry) never get per-character or per-skin fixes. A character's own clips may be edited. |
| The owner approves each visual step | Section 8. Never mark anything done. |

## 2. Which route for which piece (from every route tried since Oct 25)

Each row is grounded in the history ([failed-routes.md](failed-routes.md), section numbers in brackets). Pick per
PIECE, not per skin: Showstopper is a built robe + built bloomers/boots + a reused rigid hat + SmartBone chains.

| Piece | Build it as | Weights | Never (and why) |
|---|---|---|---|
| Coat, robe, dress, long skirt, tailcoat | **ONE skinned robe**, neckline to hem, built from the concept's measured shape: parametric grid (section 3) or a **ray-cast shell** grown from the real torso (radius per angle and height by BVH ray cast, clearance by region: chest ~0.10, hips ~0.055) [11] | torso top, hips + thighs for the skirt; rule weights | Layered/cages (tears, squeezes past ~0.1 off the body) [6]; AI statue (fused, smeared) [4,10]; top + separate skirt (seam) [7]; rigid per-part shells (overlap at joints) [5,10]; donor weight transfer for a long coat [8] |
| Hoodie, sweater, short jacket | One closed skinned shell with real thickness, baggy where the concept is; hood down = a folded roll of the same mesh; pocket = a raised panel of the same mesh; ribbed cuffs/hem = rings of the same mesh | torso -> LowerTorso at the hem; sleeves by distance from the arm axis (automatic weights also work on one closed snug shell [8]) | Snug layered jacket: "SUPER 2d" [9] |
| A truly snug piece (bodysuit, tight shirt, leggings) the owner asks to be snug | One closed skinned shell grown from the real body (ray cast, ~0.03-0.05 clear; automatic weights work on it [8]), or Layered Clothing on the approved cages already on the templates [6]. It stays 3D only through what stands OFF it: raised emblems, belts, seams, cuffs and collars as real folds or rigid pieces, plus the texture round. Say on the plan page that snug alone read "SUPER 2d" [9] | automatic / rule weights, or cages | Painting emblems, lapels, toggles or trim onto it [9] |
| Sleeves, trousers, bloomers, romper legs | **Closed lofts / puffed tubes riding their own limb** [11]; bands and cuffs are rings OF THE SAME MESH; several pieces of one garment unioned into one shell (textures.md); a ball round each hip keeps thigh tops covered in a crouch [11] | arm / leg parts, blend at elbow and knee; the layer under a skirt follows the thigh exactly as much as the skirt side | Loose rings (holes); height-cut sleeve weights (side gap) [8]; three overlapping pieces (seams) |
| Lapels, collar, cuffs, trim, pockets | **A real fold of the same mesh**, standing off 0.15 (0.10 minimum at a tight spot), a notch where lapel meets collar; gold piping as ONE **mitred swept tube** per run, lifted 0.02 clear [11] | same as the cloth under it | Colour zones or painted lapels ("looks 2D"); fan-filled sheets; plain swept tubes (pinch at corners) or tubes + balls (beaded) [11] |
| Capelet, short cape | A lined shell fitted to the actual supporting chest/back garment. Choose the gap from the concept and owner: a close cape starts near 0.06 inter-layer clearance PLUS its own lining thickness. Do not treat ~0.30 stand-off as a universal rule; it made Bell Jester float. Limit side flare over arms, seat the bow on the fitted cloth, then test swinging chains/colliders ([smartbone.md](smartbone.md)). | UpperTorso (+ chains) | Oversized rest shape held away by oversized colliders; using collision as a fitting method |
| A layer over another (apron, waistcoat) | Its own closed piece standing off the cloth under it (>= 0.05; >= 0.06 if either one swings on SmartBone), copying that cloth's weights point by point, chains included. Not yet shipped (Grill Boss's apron was never judged): gate it hard | copied from below | |
| Swinging cloth (skirt, tails, lapel fringe, cape) | SmartBone chains ON TOP of the weights: 8 chains round a full skirt, ~0.06 clear of any puff under it; pattern pieces hung by cloth sim give the rest shape [12]. Structured tailcoats can use restrained motion; Backstage Cappy's earlier rigid preview is NOT an approval to omit physics. Keep deliberately rigid pieces only when the current plan calls for them. | a share moves onto the chains | The simple tail spring with many chains ("twitch, clip, rumple") [12]; colliders bigger than what you see |
| Boots, shoes | Built closed shapes with a coherent upper/vamp/toe, readable sole/heel appropriate to the design, a real opening and clean cuff. Reuse only after a CURRENT close-up quality comparison against the concept and the game's best existing footwear; old approval is not a quality exemption. Show front/side/underside and worn motion. Another character's good boots are a construction reference, never a reason to copy its styling. Thick walls; shaft on shin, foot on foot, own legs visible above. See [footwear.md](footwear.md). | shin + foot, controlled ankle blend | Disconnected primitive foot/curl/ankle blobs passed as finished footwear; hiding legs to make boots fit; unrepaired/generated boots passed without fit/quality review [10] |
| Gloves, mittens | A closed shell grown from the hand (ray cast, ~0.02-0.03 clear), 100 % on the hand, cuff a ring of the same mesh; the hand is hidden only because the glove truly covers it (ask first: hands are base parts). Check prop grips and the vacuum hold with them on | 100 % hand | Bulky gloves that push held props or the vacuum grip off the paw |
| Hat, crown, glasses, bow, ace card, earrings | Rigid **fitted gear** (`MountPart`) or a mesh inside the outfit at 100 % on its part; reuse a liked one; CastShadow off on small shiny bits; a piece that won't match the reference becomes its own prop [11] | 100 % one part | Accessory (no ScaleTo) [7]; moving or copying a base piece (flower, spines) into it [props]; quick kit props [2] |
| Held / signature prop (Legendary) | Reuse first; else the Office two-pass procedure (scan texture, then a hand-built model baked with it; texture-pipeline skill); AI image-to-3D (TRELLIS, never Hunyuan3D for a shipped prop: licence) only for a one-off organic rigid shape, then repaired; hard-surface and thin pieces always hand-built; glued to the hand in clip space, shown by clip markers | Motor6D on the hand; lives in the outfit's `Props` (with a `Hand` attribute; worn ones add `Holster`), or `Assets.CleanupCrew.EmoteProps` as the fallback any skin can use; listed in `EmotePropRegistry` | fwjelaa / quick kit props [2]; AI surface left raw |
| Plain cloth colour | One exact concept colour per garment (`CLEAN=1` thinking), then the texture round keeps it on average (textures.md) | | AI paint [10]; LIFT [10]; a contrasting band nobody asked for |
| Base character parts (head, face, hands, ears, tail, spines, flower, earbuds, legs) | Untouched, at their base spot and size; hide only what the outfit truly covers | | Remodelling the character [2]; hiding limbs [1,11] |

Shape sources, in order of trust: the concept and its approved views (measure px per stud from the head) > the
character's own body (ray cast, cage) > an AI shape as a REFERENCE only [4,5]. AI meshes never ship as an outfit body,
and no automatic fitting step (shrinkwrap, smoothing, remesh, re-bake, donor weights) ever runs on a surface the owner
must judge [4].

**Another employee:** same recipe, different files ([odd-hours.md](odd-hours.md) "Characters"): its controls blend,
its deform skeleton export, its own pose set rebuilt from ITS live clips. Showstopper's numbers (crouch weights, chain
shares, collider sizes) are starting points to sweep per skin, not rules.

## 3. The route, step by step

Blender 5.1 headless (`blender -b --disable-autoexec -P <script> -- <args>`). Body: the character's controls blend, T
pose, front is -Y, its left is +X, 1 unit = 1 stud. Scripts: [scripts/](scripts/README.md) (Showstopper-shaped: copy
into your build folder and change paths, pieces and numbers).

1. **Plan page first** (section 8): concept crop next to the plain character, every piece with its build from section
   2, the rarity, what stays visible, and its motion treatment (rigid, skinned, or simulated cloth). Propose the cape,
   flaps, tails or other loose regions that should move; a focused ideation question is fine. Once agreed, implement
   them as part of this skin, without another "now implement cloth physics" prompt. Explain intentionally rigid
   regions. Ask about effects and any contrasting bands.
2. **Blockout** (`ss_blockout.py`): size every piece from the concept (px per stud from the head width and height).
   Flat concept colours. Front, side and three-quarter. Shape answers before detail.
3. **Reuse approved props** (old hat, built boots). Remake cloth, not liked props.
4. **Build the robe** (`ss_robe.py`): one parametric grid neckline to hem (halves share the back centre column above any
   vent); warp grid columns so one lies exactly on each lapel edge (else colour zones stair-step); lapels and collar
   roll outward and fold back, edge 0.15 off, piping on the flap edge, a notch where lapel meets collar; the skirt hangs
   by **cloth simulation** (top rows pinned) over what is under it, collision thickness 0.05; if the skirt will swing, set the drape so it rests ~0.06 clear of any puff under it (this sets the rest SHAPE;
   motion comes later from SmartBone); solidify with rim -> a closed shell.
5. **Close everything.** Sleeves one closed loft each; bloomer legs from hip INTO the boot shaft; one garment one shell.
   Recalculate every lofted normal OUTWARD (lofts come out inward; Roblox culls back faces).
6. **Head clearance AND coverage.** Keep the garment clear of the head (start near 0.05 below its underside), while
   matching the reference's neck/shoulder coverage. Do not simply drop the neckline until a head gate passes and
   leave a broad exposed torso/neck band. Fit a complete shirt yoke/collar where needed and test an appropriate
   head-to-torso weight blend across the actual clips. Keep the character's neck/head geometry unchanged. Big toon
   heads hide the upper chest: place readable detail accordingly, without lowering the whole neckline.
7. **Weights** (`ss_export_remake.py`), limit 4, normalised:
   - robe top + lapels: UpperTorso, blending to LowerTorso at the waist;
   - skirt: hips + thighs. Hem: front panels follow their own thigh 0.95, sides 0.68, back 0.40, centre back split
     between both thighs; the waist row stays on the hips;
   - **the layer under the skirt and the skirt side must follow the thigh by the same amount at the same height**, or
     crouch pushes it through. Showstopper "EB": `UP0=0.80 UP1=1.00 SIDEB=0.30 T1=0.40` (sweep per skin);
   - sleeves: UpperArm blending to LowerArm at the elbow, by **distance from the arm axis, never height cuts**;
     bloomers: hips at top, shin below the knee; boots: shin + foot.
8. **Export** with the game's deform skeleton (bones `<Part>Bone`). Shape rounds: flat swatch colours. Each mesh under
   20,000 triangles (Roblox's limit; `ss_export_tex.py` already acts at 16,000): split into more meshes, don't decimate multi-colour meshes (decimate shards colour borders).
9. **Offline gates** (section 4). All pass before any Studio work.
10. **Textures** ([textures.md](textures.md)): real UVs + colour / normal / roughness maps before it ships. Judge unlit,
    neutral, then warm depot light.
11. **Cloth and Studio showcase**: implement the agreed moving regions using [smartbone.md](smartbone.md), then
    demonstrate actual simulation in Studio, including movement, stops, crouch and real jumps. Held-chain renders
    alone do not satisfy this step. Ship ([ship-and-studio.md](ship-and-studio.md)): test asset, place in both places,
    engine check with a test character, the owner's `employeeoutfittest`, then registration on his OK.

## 4. Gates (every one, every round, before Studio)

Commands and real numbers: [gates.md](gates.md). Log each in `GATES.md`.

| Gate | Pass |
|---|---|
| Holes (`gate_holes.py` + `gate_check.py`): body hidden as the game hides it, 16 views, garment insides red | 0 red, 0 open edges per piece |
| Clipping on **every keyframe of every clip the skin plays** (`pose_gate.py`, pose set rebuilt from the LIVE clips) | worst frame per clip reported; never worse than the last approved build (a few points from limit-4 weight trimming is expected: say so); no fixed crouch bar (report with renders, owner decides) |
| Head (`head_gate.py`) | 0 vertices inside the head. It skips a hat ON the head: check a hat separately (below). |
| Hands, forearms, spike / ear tips vs head, hand vs other arm (`clip_gate.py`, `idle_arms.py`) | head gap > 0.06, no hand sinking > ~0.03 |
| Holes on the **posed** scenes | 0 red |
| A worn prop (hat, glasses) | Seated: no gap under it, no point inside the head; ears (or spikes, flower) clear of it on every keyframe of every clip, in the prop's part space; renders from four sides |
| "Points inside" counts | not visible clipping: check a render before gating on one |
| Concept side by side, same angle | shape matches; owner says yes |
| After textures | the same numbers as the untextured build, plus the map checks in [textures.md](textures.md) |
| In engine (after upload) | client fetch status `Success` for every mesh and map; shared poses (vacuum, hide, sit) looked at with the skin on; SmartBone measures if any |
| Cloth showcase | Every planned moving region demonstrated with physics active in Studio at normal speed; rest silhouette preserved, stops settle, crouch/jumps checked for clipping, flipping and jitter. Intentionally rigid pieces named in the plan. No pending physics task hidden behind a static approval. |

Validate any new gate by reproducing a known approved number first.

## 5. Colour and textures

Shape rounds use flat swatch colours sampled from the approved 2D. **The shipped skin gets the texture round**
([textures.md](textures.md)): CC0 scans through the style filter, ratio maps that keep each garment's exact colour on
average, real UVs, EMIT colour bake, bump normal, roughness, SurfaceAppearance per mesh. Judge unlit from all sides
first, then neutral, then the warm depot light (red-leaning purples read maroon there). A colour change = re-export +
re-PATCH + re-place (~10 min). A prop with its own texture keeps its old colour: say so, recolour it if asked.

## 6. Ship

[ship-and-studio.md](ship-and-studio.md). In short: test asset (group only, owner's OK) -> place in BOTH places ->
engine check with builder-made characters in one muted Play, client fetch status -> `employeeoutfittest` by the owner
-> on his explicit OK: final outfit Model (a NEW name if a live skin changes; a re-texture or fetch nudge may re-place the same name, ship-and-studio.md) placed in both places FIRST, then the four
code files, spec first -> he saves and publishes -> his real-play check. Rollback = revert the commit; the old Model
stays in the places.

## 7. When the skin exposes a bad clip

A skin with anything on the chest shows arm poses that were always wrong (Prickles' idle had a hand 0.23 inside his
chest with no skin at all). Measure the plain character first (`idle_clip_probe.py`). Fixing its own idle means
re-posing every clip that starts, ends or holds it, then overwriting them in place (backups first). Method:
[clip-repose.md](clip-repose.md). Shared poses: never per character.

## 8. The owner's review

- **On an artifact page**: he works over Remote Control, so file cards and inline images don't reach him. One figure
  per image, plain caption ("front, side, back; violet coat in depot light"), concept beside the model. Republish the
  same page each round.
- **Yes/no questions by piece name** ("Hat: yes / no?", "Lapels stand off enough: yes / no?"), split into look, fit
  and rules. Never "approve 11 decisions".
- **Order**: plan page (including cloth-motion choices) -> blockout renders -> each round's renders + gate sheets next to the concept -> Studio cloth showcase with agreed physics active -> only after a
  test player looked right in Studio: `employeeoutfittest` in game -> his OK to make it the real skin -> his real-play
  check. **He is never the first to see it in game.**
- Kid-simple words, the plain answer first. Real numbers, before/after, from the same angle.
- His notes are short and loud ("where are his knees?!"): quote them verbatim in the brief and the ledger.
- Never write "done" or "fixed": "ready for you to check". Only he marks done.

## 9. SmartBone cloth (summary)

Full recipe: [smartbone.md](smartbone.md). SmartBone 2 is in the game (`wally.toml`, `EmployeeTailSmartBoneUtils`); an
outfit opts in by attributes. Chains ride ON TOP of the weights; joints on the cloth surface; the outfit's own
colliders the size of what you see, sized against bone heads; `TailBoneLift` 0.15 + shared cap 0.05 so the hem never
flips; soft settings stiffness 0.35, elasticity 4, damping 0.18, bend 35. Gate in engine per move.

**Implement it during the skin work, not as an owner-requested follow-up.** Put motion choices on the ideation page;
build and showcase the agreed simulated regions before asking for the final worn-skin approval. Not every material
needs simulation: retain deliberate rigid construction, but do not silently classify loose cloth as rigid to skip work.

**Plan for it at build time, not after:** SmartBone moves only the joints, so the cloth BETWEEN two chains is a
straight span that cuts into anything round under it. A new swinging skirt gets **8 chains around** (not 6) and **about
0.06 of clearance over anything puffy under it** (or a slimmer puff where the skirt covers it). Growing the colliders
past the visible size does not fix it: it pushes the cloth out at rest.

## Plain answers to owner questions

- "Wouldn't robe collisions fix clipping?" No. Roblox never collides skinned meshes with the body. A worn outfit bends
  only by its weights; SmartBone pushes its bones (not the cloth between them) off colliders.
- "Can SmartBone fix it?" For cloth that has chains, yes, and the game has it. A new chained piece still needs its
  chains, weights, colliders and in-engine gates: about a day per skin.
- "Can AI make the whole skin?" Tried four ways (TRELLIS, Hunyuan shells, Route 2, AI paint): AI statues melt body
  and cloth together, invent the back and smear paint, and every fitting step ruins the surface. AI only as a shape
  reference or for rigid one-off props; built shapes for cloth.
- "Can't we use Layered Clothing?" Only for snug pieces: the engine squeezes or tears cloth more than ~0.1 stud off the
  body, and snug reads painted-on ("SUPER 2d").

## Red flags - stop and re-read

| Thought | Reality |
|---|---|
| "The old build is approved, I'll keep it" | Old approvals were placeholders until this route. Remake cloth; reuse only liked rigid props. |
| "Hide his legs / her ears, it fits better" | Never hide the character's own parts. Fix the clothes. |
| "Stretch this piece to cover the gap" | Rejected. Build true-size cloth. |
| "Top plus separate skirt is easier" / "three bloomer pieces is fine" | Shows as seams. One piece per garment. |
| "Raise the lapel colour zone a bit" | Reads 2D. Real fold, 0.15 off. |
| "Decimate to get under 20k" | Shards the colours. Split meshes. (Only a one-colour shell, before its UVs, may be decimated.) |
| "Flat swatch is done" | Bland and plastic in game. Texture round before shipping. |
| "Gate passes at rest and in walk" | Every frame of every live clip, crouch and emote included. |
| "It looks right in my render light" | Unlit, then warm depot light, then the depot. |
| "The concept shows a dark band, so I'll add it" | Ask first. |
| "The piece vanished, let me read the code" | Client `GetAssetFetchStatus` first. |
| "The PATCH worked, it shows on the server" | Check every worn mesh's fetch status on a fresh CLIENT. |
| "Code first, art later" | Art in both places first; a place without it shows Classic. |
| "Owner can look first, then I'll test in game" | Test player in the game's idle and light first. |
| "Quick grant to test it on my character" | No profile writes. Builder or `employeeoutfittest`. |
| "Content lock is tomorrow, skip crouch / textures this once" | Gates don't bend for dates on your own say-so. Offer scope cuts (fewer pieces, one look, ship after launch) with what each costs, shown on the page; the owner chooses. |
| "He said 'just push it', that's the OK" | The OK counts only after he has seen the look on the page and the test in game. Show it first, then ask. |
| "I'll wait here until the bake finishes" | Background it and work on, or end the turn with a report. |
| "Let me try TRELLIS / Hunyuan / Tripo / cages for this garment" | Tried; read failed-routes.md first. AI = reference or rigid props only; cages = snug only. |
| "This old route's piece is close, I'll fit it" | Every automatic fit step ruined the surface. Rebuild the piece by hand to the concept. |
| "Use the Studio id from earlier" | Ids change each restart. Match window name AND placeId. |
