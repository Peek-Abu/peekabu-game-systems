# Textures: from flat swatch to real cloth (colour, normal, roughness maps)

Proven on Showstopper (texture round, 11-16, build `$SSR/cr/TX`, ledger `cr/TX/GATES.md`; owner: "Yes legs are back!"
after the ship, look approved). Load the **texture-pipeline** skill too: its style filter (`texstyle.py`,
`style.json`) and calm check (`measure_one.py`) are used here.

## When

- **Blockout and shape rounds: flat swatch colours.** One small swatch image, each face's UV at the centre of its
  colour block. Fast to recolour; right for judging shape and colour.
- **A shipped skin: real UVs + baked maps.** A flat swatch has no UV layout, no detail, no normal or roughness map, so
  Roblox lights it like plastic. Owner on the flat build: "the texture just looks bland", "the coat and boots seem to
  have no textures", "make it as similar to concept texture". Do the texture round before asking to register.

## Recipe (scripts: `tex_prep.py`, `tex_bake.py`, `ss_export_tex.py`, `fbx_notex.py`)

1. **Pick one CC0 scan per garment kind**, against the concept's look (owner OK before downloading). Showstopper:
   coat/sleeves `Fabric084` (soft microfiber, reads velvet), cream lapels/cuffs/waistcoat `Fabric036` (woven),
   bloomers/shirt `Fabric082A` (fine cotton), boots `Leather038`, hat `Fabric034` (felt).
   - ambientCG refuses the texture-pipeline `fetch_cc0.py` download (HTTP 403 for Python's client). This works:
     `curl -L -A "Mozilla/5.0" -o <Id>.zip "https://ambientcg.com/get?file=<Id>_2K-JPG.zip"`. Each zip in its own new
     folder; unzip images only.
2. **Style every scan** through `texstyle.py` with the costume classes in `style.json` (`ss_velvet`, `ss_weave`,
   `ss_cotton`, `ss_leather`, `ss_felt`: neutral grey swatch, saturation 0). Then `measure_one.py` must PASS the calm
   check. At the fabric class's lum_std 0.05 three failed (reads as TV static); lum_std ~0.03 with denoise 0.4-0.5
   passes. A new cloth kind = a new `ss_*` class in style.json, checked the same way.
3. **Ratio maps** (`tex_prep.py`): each styled colour map becomes `lum / mean x 0.5` (grey 128 = no change). The bake
   multiplies the garment's flat concept colour by 2 x ratio, so **the colour stays exactly the concept colour on
   average** (the one-exact-colour rule holds) and only the weave varies (~4 % std). AO darkens creases a little, so the baked mean sits a few percent
   under the concept colour: measure each zone's baked mean against its hex and say so if it drifts.
4. **UVs**: on each final joined mesh, AFTER the join: smart project (66 degrees, island margin 0.002) + pack (margin
   0.004).
5. **Detail is box-projected in stud space** (object coordinates = studs, blend 0.3), not through the UVs, so the
   weave is the same size on every piece and UV seams never show in the pattern. Tile sizes: velvet 1.2 studs, weave
   0.8, cotton 1.0, leather 0.6, felt 0.7.
6. **Bake per MeshPart** in Cycles (`tex_bake.py`):
   - **Colour = an EMIT bake** of flat colour x ratio x AO. Never a DIFFUSE bake: it drops metallic gold to black.
   - **AO with only_local = True** (distance 0.06, strength 0.25-0.45): pieces never darken each other. Cross-piece AO
     brings back dark "seam" lines where pieces meet.
   - **Normal = tangent bake of a Bump node** fed by the scan's Displacement (box-projected heights stay correct in any
     projection; a box-projected normal MAP does not). Bump distance 0.002-0.004 studs gives a mean tilt of 7-10
     degrees; the felt hat at 0.004 on a 0.7 tile came out 16 (strong, fine on felt).
   - **Roughness** = the styled scan's roughness. Class targets: velvet .82, weave .78, cotton .86, leather .50; gold .35.
   - Bake at 2x (2048), scale down to 1024 (Roblox's image size limit), margin 16 px EXTEND. ~5 min CPU for 4 meshes.
7. **Export the FBX without embedded textures** (`fbx_notex.py`, path_mode STRIP): 1.5 MB instead of 15 MB. The maps
   go up as separate images.
8. **Re-run every gate** (holes, head, pose on every clip) even though the shape did not change, and check the
   numbers match the last approved build. Plus the maps' own checks: tilt and roughness means printed by the bake, the
   calm check, an unlit sheet from all sides, then neutral and warm light.
9. **Ship**: new UVs give the meshes NEW mesh ids (a mesh whose geometry and UVs did not change keeps its id: the
   hat did). A changed id is the quick proof the new revision loaded. Images to the group, then one SurfaceAppearance per MeshPart ([ship-and-studio.md](ship-and-studio.md)
   "Textured outfits"). `EmployeeOutfitSystem.fit` clones each mesh with its own SurfaceAppearance (a style folder
   only replaces it when the skin names a style), so no code change.

`ss_export_tex.py` still has a decimate branch for a robe over `MAX_TRIS` (16,000; Roblox's own limit is 20,000). It must never run on a mesh with
several colours (it shards colour borders): if it would trigger, split the mesh instead.

## One colour per garment, really

- **Overlapping closed pieces of one garment draw dark lines where they cross**, and the owner reads every one as a
  seam ("I can see loads of seams or areas of clipping"). Showstopper's bloomers were three pieces (seat + two legs)
  plus pleat valleys. Fix (`ss_bloomer_shell.py`): **union into ONE shell**: voxel remesh 0.008 of the joined pieces,
  corrective smooth 6 x 0.5 (blends the joins, softens the pleats), decimate to ~9,000 triangles, one material. The
  decimate is allowed here because the shell has ONE colour and is decimated before its UVs exist. Weights for the
  shell: each side's leg weights, split across the crotch (smoothstep -0.10..0.10 in x). Side effect: crouch pokes went
  down (145 -> 115).
- **Ask before any contrasting band on a plain garment**, even if the concept seems to show one. Showstopper's "section
  of black" was a designed dark knee cuff (`bloom_dk`); the owner wanted one colour all the way down.

## Recolouring a prop that has its own painted texture

A prop with its own texture (the hat) keeps its old colour when the cloth is recoloured. Say so when offering colours,
and recolour its texture if he wants it to match (`tex_prep.py`, the violet hat): select the old colour's pixels by HSV
(Showstopper plum: hue 290-15 degrees, sat > 0.18, value < 0.55), set them to the new colour times (pixel luminance /
median luminance of the selection) **in linear space**, so the painted shading stays. Leave details (cream diamonds,
gold band) alone; a gold mask (hue 25-60) keeps felt and high roughness off metal trim.

## Colour judging

- When adapting/copying shader graphs, copy output defaults as well as inputs: `ShaderNodeRGB` stores its colour
  on its output socket. Copying inputs alone made Backstage's plain zones white while the linked sleeve pattern
  stayed coloured. Inspect the actual colour map and measure plain-zone means against the source before lighting
  review. Normal/roughness success does not establish colour correctness.
- Keep original pattern/prop UV layers when adding bake UVs, and explicitly select each source layer in its shader.
  Reacquire UV layer references after Edit-mode unwrap operations. If legacy mesh attribute storage crashes
  Blender5.1, rebuild only that storage in a separate copy; preserve vertex/face order, groups, corner normals and
  source UVs, and compare geometry/weight/UV hashes before accepting it.

- Judge **unlit first** (client Lighting: Ambient and OutdoorAmbient white, Brightness 0, shadows, lights and post
  effects off): that is where you see whether pieces match (hat vs coat).
- Then neutral light, then the game's warm depot light. Red-leaning colours drift there: plum #683256 read maroon;
  bluer purples (#6A3A8E, #4F2D7F) stay purple. No LIFT on colours (turned a jacket red).
- Small shiny props (bells, bows) get `CastShadow = false`: their shadows read as dark smudges on light cloth.
