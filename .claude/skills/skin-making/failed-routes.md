# Failed skin routes and why (do not repeat)

Every row was built, shown to the owner and failed. The "why" is what to avoid, not just the route.

## Whole-route failures

| Route (when) | What the owner saw | Why it failed |
|---|---|---|
| Scripted-primitive skins, fwjelaa picture-to-model kit (Oct 28) | "complete trash" | Rebuilt the character from scratch and looked like a kit, not the concept. |
| Early scripted Blender skins: Bubble Buddy, PJ Cappy, Sheriff Prickles (Oct) | hood "liquidy / strappy paste", "why are his legs gone!?" | Shrink-wrapped drapes drift from the concept; leg masks hid his real legs. |
| AI statue pilot: Qwen 2D -> TRELLIS 2 -> automatic fit (Nov 4) | "the deformation... has the skin ruined" | Every automatic cut, shrinkwrap, smooth, decimate and re-bake damaged the AI surface. |
| Hunyuan statue cut into ball-jointed rigid shells (Nov 5) | never approved | No tearing, but blotchy colour, ragged lapel edges, a guessed back. |
| Layered Clothing (cages) jackets, rev 1-17 (Nov 5-9) | "armpits and shoulders look wrong", "looks SUPER 2d" | Cage deformation tears at shoulders and armpits; anything ~0.1 off the body tears in a crossed-arm idle; layered points far from the cage get squeezed (a flared skirt came out half width). Fits only snug clothes, and snug reads painted-on. |
| Long coat as one skinned shell + layered bloomers (rev 17, Nov 9) | "reevaluate COMPLETELY" | Shape came from guessed number tables (hunch, puffy chest); colour read raspberry in game. |
| AI whole dressed body cut into rigid pieces (route 2, rev 19-29, Nov 10) | "finalized until a modeller", later revealed as a placeholder | AI surface: ragged lapels, smeared paint between pieces, overlapping rigid shells at joints, too slim. |
| Carnival skins copied from route 2's first-day cut (Backstage Cappy, Nov 11) | "where are his knees?!", "we didn't use the lessons" | Hid every limb; the waist cut plane sliced the tailcoat across two body parts; AI paint blotches; no unlit sheet; owner was the first in-game tester. |

## Piece-level failures

| Attempt | What happened | Why / do instead |
|---|---|---|
| AI-painted plain cloth | "miscolouring / smudging" | Painter colour differs per piece and bleeds. Snap plain cloth to one exact colour (`CLEAN=1`). |
| Stretching a sleeve 3.8x to cover a gap | rejected | Build true-size cloth. |
| Coat top + separate cloth-sim skirt (rounds 1-3) | "obvious stitches / seam" | Two meshes overlap at the waist, and a drip band hid the join. One robe. |
| Lapels as a raised colour zone (0.03) | "looks almost 2D / attached to body" | Real fold of the same mesh, 0.15 stand-off. |
| Lapels as fan-filled sheets projected on an ellipse | holes, floating gold wires | Not on the real surface. Build from the robe itself. |
| Rolled tube collar | clipped into the head | Sat above the head's underside. Clamp to the head, lower the neckline. |
| Loose gold rings on sleeves, loose cuff rings on bloomers | "holes all over" | Separate rings gap and open at bent joints. Bands are part of the closed piece. |
| Six skirt tail chains on the game's simple tail spring (round 4) | "twitch, clip, rumple over the top on jump" | The spring was made for two back tails; chains move apart, stretch the cloth between them, and get flung on a jump. |
| Decimating joined clothing | dark cuff band turned into shards | Decimate merges faces across swatch-colour borders. Split into more meshes. |
| Moving the base flower onto the hat | "too high / too connected" (twice) | Base pieces keep their base spot. The flower is its own base part; keep it and cut it from the hat. |
| Sleeve weights cut by height | gap in the side panel when arms drop to idle | Weight by distance from the arm axis. |
| Donor weight transfer (Robust Weight Transfer from the Avatar Setup body) and play-pose bake for long coats | arms-up and walk broke | Write the weights by rule (section 3 step 7 of SKILL.md). |
| Skinned outfit welded to HumanoidRootPart | stayed rigid in bind pose | Weld to LowerTorso; meshes in a Folder, not a sub-Model. |
| Hat as an Accessory | wrong size after `ScaleTo(1.25)` | Fitted gear Model with MountPart. |
| LIFT on colours | jacket turned red in the depot light | Plain swatch colours, judged in warm light. |
| Red-leaning plum #683256 | maroon in the depot | Bluer purple #6A3A8E shipped. |
| Bloomers as three overlapping closed pieces (seat + two legs) with pleat valleys | "loads of seams or areas of clipping" | Every crossing draws a dark line. One voxel-remeshed shell per garment ([textures.md](textures.md)). |
| A designed dark cuff band on the bloomers | "a section of black" | Ask before any contrasting band on a plain garment. |
| Flat swatch export shipped as the finish | "bland", "no textures" | No UVs, detail, normal or roughness: Roblox lights it like plastic. Texture round before shipping. |
| DIFFUSE colour bake; AO across pieces | gold turned black; dark seam lines | EMIT bake; AO only_local. |
| Coat recoloured, hat left alone | "make the hat violet too" | A prop with its own texture keeps its colour: recolour its texture by HSV. |
| Trusting a PATCH because the server-built model drew fine | the owner's lobby Studio drew no bloomers or boots ("legs missing") | That client's mesh fetch had failed and stayed failed. Check client fetch status; nudge the geometry for a new mesh id. |
| Granting the skin to a real account to test it (older handoffs) | data written to the owner's profile | No profile writes: builder or `employeeoutfittest`. |
| Hard-coded Studio ids | worked in the lobby while thinking it was Shift | Ids change each restart. Match window name + placeId ([odd-hours.md](odd-hours.md)). |

## Tools tried and their verdict

| Tool | Verdict |
|---|---|
| Avatar Setup | Bakes the body grey, fuses the face plate, swaps Motor6Ds, ~30 assets per run. Not adopted. Its cages were good. |
| EditableMesh test bodies | Always show false holes. Never judge fit on them. |
| Engine wrap settings (Stiffness, Puffiness, AutoSkin) | Did nothing for armpit tears. |
| Tripo / Meshy / Rodin (paid) | Make whole statues with their own skeleton, same limit as Hunyuan. Rigid props only, owner's OK before spending. |
| Human 3D artist | The owner's fallback for sculpting a look to the 2D; our pipeline does fit, weights and gates. |
