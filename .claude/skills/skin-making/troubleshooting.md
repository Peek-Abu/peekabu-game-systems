# Troubleshooting: symptom -> first check -> fix

### Too much exposed neck/upper torso (Backstage r10)

Compare the actual collar and shoulder coverage with the reference, not only head penetration counts. A front-only
shirt ending at2.17 and a low wide coat opening left a large skin band. R10 uses a continuous full-circumference
shirt/yoke/collar, a higher fitted coat neckline and a small bow-seat adjustment. Native neck/head/body geometry
is preserved. Upper collar weights blend toward Head, lower rows retain torso/hip support; all867current keys
were checked for head contact. A low neckline passing the head gate is not proof of a reference-matching fit.

### Same-colour checks, elbow folds and actual lapel tips (Backstage r08)

Inspect the ACTUAL visible face assignments before dismissing a colour mismatch as lighting. Backstage r08's
unlit named-plum swatches matched, but that test compared the wrong coat surface:680 outward back faces used the
darker LINING material. The owner correctly saw lighter sleeves at the shoulder. R09 corrected the outer-face
assignments and checked the actual front/back garment unlit. Matching shader inputs alone does not prove that
the outside uses those inputs. A Non-Color pattern mask can share the same cloth RGB, but does not repair wrong
material indices. Check texture/normal paths and real face assignment before changing the palette.

Covering a rounded elbow cap by shifting the ENTIRE bend past the joint made the inner crease look oversized.
Check the actual hinge direction: here both elbows bend toward native -Y. A crease-aware weight field can keep
the inside near the real pivot and retain cap coverage at the rear. Treat this as a fitted garment choice, not
universal constants. Also inspect nearby lapels: a fold wrapped under the arm can look like extra sleeve webbing.

Lapel chains must reach the prominent FREE POINTS, not an arbitrary vertical strip of chest. Verify weights at
those points and on the gold edging, then use sleeve-volume colliders if the cloth rests against clothing.
Broad positional masks can miss the actual end. Re-sweep piping around a changed centreline; independently
warping tube vertices across a fold-selection boundary created fins. Cap/bevel sharp mitres rather than stretching
them into blades. Seat buttons against a forward outer cloth face, not the thin closure rim that turns them sideways.
The reference may place buttons on the OUTER PANELS, away from the opening/trim. Correct orientation at the rim
is still wrong placement. Check their lateral location and edge clearance against the concept; Backstage r09
moved both coat buttons outward about.09stud and left roughly.026stud beyond the button radius to the trim.

### Sleeve patterns that slide or stop matching the concept (Backstage Cappy)

A procedural shader reading Geometry.Position reads the DEFORMED position. In the manual pose preview this made
the left sleeve's diamonds slide, change shape and appear as unrelated cream patches. Use explicit cloth UVs or
another stable rest-coordinate attribute; check rest and bent-arm views from the same angles as the reference.
Wrap a repeated sleeve pattern around its intended circumference rather than leaving the visible back blank.
Do not enlarge the elbow into a balloon solely to improve a contact count: judge the outline against the concept.

For multiple animated anchors in an upload-free physics prototype, parent each chain root to its own animated
native anchor and follow the actual outfit's LowerTorso root space. Putting the same body motion directly on a
flat simulated root can disagree with SmartBone's cached parent/rest transforms. Record actual solver transforms
and compare physics-only deviation against the moving native anchor; raw mesh-root-space movement includes
the character animation and is not a cloth swing/flip measurement. Keep a test export with actual deform bones;
vertex groups and a JSON manifest alone are not an FBX physics rig.

SmartBone aligns a bone's UpVector with its child link. Orient prototype bind frames along the chain rather than
giving every bone identity rotation; otherwise a downward tail can rotate at rest. Place every chain joint on
the actual garment and stop at that angle's real hem. Backstage's constant fallback points for missing low
vertices created zigzagging chains in empty space; fixing the surface placement reduced idle physics deviation
from about .41 to .073 studs. Do not tune stiffness or colliders to conceal an invalid rest chain.

### Approved materials and production completeness (Bell Jester r17)

Keep the reviewed material route during installation. TextureID + Fabric/Metal and SurfaceAppearance-only are not
visually interchangeable. Bell Jester's approved flat-colour material route was retained; do not describe it as a
new normal/roughness-map delivery. PreloadAsync does not support SurfaceAppearance instances: preload actual
MeshParts for meshes and explicit image proxies/manifest IDs for maps when required, then inspect the actual
client colours as well as fetch statuses. See ContentProvider's documented limitations.

Preview-only native neck/tail patches are not production packaging. Include those exact visible regions in the
final import when HideParts removes their source part. Preserve visible UVs and geometry, cap only hidden cut
boundaries, and check the final imported asset without the prototype patch script. Bell Jester r17 packages
eight meshes; the six original garment meshes retain the approved r16 geometry and the two native regions use
the existing palette. Keep the integrated native bow from also spawning as separate fitted gear.

### Curled toes and original chest props (Bell Jester r15, 2026-11-19)

For a palette-textured native prop, NEVER delete/repack its original UV before reading its source colours. The old flat-colour bow bake helper did that safely only because its old texture was constant; native Pippa's multicolour palette sampled wrong colours after the same operation. Either preserve source UV with an explicitly named UV node while baking a separate target UV, or keep the native UV and reuse the original palette directly. R15 uses the latter, plus SmoothPlastic like the base. Live colour inspection caught the pink bow/bell despite all asset fetches returning Success. Do not add an unnecessary new image upload to repair something the existing palette already supplies.

ScaleTo preserves a Model's pivot location. An FBX imported at100x can keep its old bbox-centre offset after ScaleTo(.01); subtract ExportRoot.WorldPosition from the model pivot after scaling, then verify source bone rests before fit. Bell Jester's corrected import agrees within4.54e-7stud. Do not accept small MeshPart sizes alone as placement proof.

A raised shoe curl must not pick up shin weights merely because it is high. Restrict ankle blending to the actual shaft region; toe, outsole, bell and hanger follow the foot. Compare the curl to the rigid foot transform across every key: r14 drifted up to .9915 studs, corrected r15 measured zero. Attach a bell through its existing top loop, let its body hang clear of the upper, and verify both its rest intersection and its bone assignment. Closed geometry alone does not prove either.

“Same as normal Pippa” means her actual native bow and bell, not an older skin’s similarly coloured props. Those native pieces are disconnected components inside UpperTorso. Preserve their exact geometry/UVs/materials and relative spacing as one assembly; translate the assembly onto the new cloth. Reusing Bell Jester BowProp plus a cape bell did not meet that request. Render the native reference beside the outfit before attributing a different silhouette to lighting.

Look up the owner's words here before reading code. Every row happened on a real skin.

| Owner says | First check (before any code) | Cause and fix |
|---|---|---|
| "The legs / a piece vanished", in previews AND worn, other pieces fine, right after a PATCH or re-place | **On the CLIENT** (a Play, not Edit, not the server): `ContentProvider:GetAssetFetchStatus(meshPart.MeshId)` for every worn MeshPart, and each SurfaceAppearance map. `Failure` on one = that Studio failed one fetch (typically right after the upload) and keeps the failure for its whole process. Then confirm the asset is healthy (Open Cloud: Mesh, Approved, Active, group-owned; it loads in another Studio). | **Give the mesh a NEW id**: move one hidden vertex 0.0001 stud (`scripts/fbx_nudge_lower.py`), re-export, PATCH the model, re-place in BOTH places. Roblox dedupes identical geometry to the same mesh id (the hat kept its id over every PATCH), so a tiny change is needed to force a fresh fetch everywhere. Prove it in a FRESH Play on the client: every worn mesh `Success`. A server-built model drawing fine in an earlier Play proves nothing about a later client. |
| Same, but only in shop / locker previews | `GetAssetFetchStatus` as above, then: did the preview draw before its meshes loaded? | Previews wait for meshes and maps (`EmployeePreviewSystem.whenLoaded`, still cards redraw once loaded; warm previews skip the wait via `loaded`). A new preview path must use them. The unlock reveal shows the coat grey for its first second while maps load: known, minor. |
| "Where are his legs / knees?!" (not a load failure) | The outfit's `HideParts` / `HideAccessories` attributes | Hide only what the outfit truly covers. Never hide limbs to make the fit easy. |
| "The skirt clips when running", "the pants poke through" | Offline `pose_gate.py` on the run clip with the chains held rigid, then a render of the worst frame. High there = weights; clean there but bad in game = SmartBone. | Weights: the bloomer top and the skirt side must follow the thigh by the SAME amount at the same height (`UP0 UP1 SIDEB T1`). SmartBone: joints on the cloth surface (`SURFACE=1`), colliders the size of what you see, sized against bone heads ([smartbone.md](smartbone.md)). Still clipping with all that (Showstopper V4): the cloth BETWEEN two chains cuts the puff (the joints clear it); bigger colliders only push the cloth out at rest. Real fix = a rebuild with 8 chains and ~0.06 clearance over the puff (or a slimmer puff). Report before/after numbers on the same moves vs the last approved build. |
| "Can't you just turn on collisions?" | - | No: Roblox never collides a skinned mesh with the body; the cloth bends only by its weights. SmartBone collides its BONES with colliders, not the cloth between bones. |
| "It flips up / over on a jump" | In-engine: highest hem point vs the hips (vs the shoulders for a cape) per move, real jumps (`ChangeState(Jumping)`) | `TailBoneLift` 0.15 + shared cap `TailBoneYAxisLimits` top 0.05. Never one low shared ceiling (bends the rest shape). |
| "It twitches standing still" | Frame-to-frame jitter standing (~0.005 is fine) | Colliders touching bone points at rest (shrink until bone radius + 0.02 clear), or bone radius too big (0.04, not 0.3). |
| "Too rigid" (cloth) | Share of weight on the chains | Move more of the thigh weight onto the chains (front ~45 %, sides/back ~35 %); stiffness 0.35, not 0.55. Vent edges ride only their own side. |
| "The outfit stays rigid / in bind pose" | The weld | Skinned meshes weld to LowerTorso (never HumanoidRootPart), meshes in a Folder (not a sub-Model), bones named `<Part>Bone`. |
| "Seams" / "loads of seams or clipping" on one garment | Is that garment several overlapping closed pieces? | Union into one shell ([textures.md](textures.md)). Also no cross-piece AO in the bake. |
| "A section of black" / a band of another colour | The build script's colour zones (a designed cuff or band) | Remove it unless the owner asked for it; ask before any contrasting band. |
| "Bland", "plastic", "no texture" | Is it still the flat swatch export? | The texture round ([textures.md](textures.md)). |
| "Miscoloured", "smudged" | AI paint on plain cloth? Cross-piece AO? | One exact colour per plain cloth; AO only_local. |
| "Maroon / pink in game" | Render in warm light (`WARM=1`) | Bluer hue; no LIFT. |
| "Hat isn't the same colour as the coat" | Does the prop have its own texture? | HSV recolour of the prop's texture ([textures.md](textures.md)). |
| "Looks 2D", "painted on", "attached to body" | Stand-off of lapels, collar, trim | Real folds 0.15 off; real cloth thickness. |
| "Looks like two pieces", "stitches" | Is one garment cut across two meshes or body parts? | One garment = one piece. |
| "Holes all over" | Hole gate; loose rings or bands? | Bands are rings OF the closed piece; recalc normals outward (Roblox culls back faces). |
| Closed capelet still shows red back faces | Check signed volume AND every rendered angle; zero open edges is not enough | Bell Jester blockout 11-17: reversing a negative-volume shell reduced 22,717 red pixels to 34, but radial inner/outer surfaces still crossed at raised shoulders. Normal-offset Solidify thickness with rims reached zero in all 16 static views. Re-run the posed gate later; static zero does not certify motion. |
| Native face becomes black only in an unlit comparison | Did the comparison replace an alpha-bearing face shader with bare emission? | Limit the unlit override to the outfit, or preserve the native material's alpha mix. Do not treat a diagnostic shader error as a broken source texture. |
| "Arms go through the coat in the idle" | `idle_clip_probe.py` on the plain character first | Often the clip was always wrong; fix the character's own clips ([clip-repose.md](clip-repose.md)), never shared poses. |
| Arms or hands clip in the vacuum hold / hide / sit with the skin | Is it the shared pose? | Shared poses get generic fixes only. The vacuum hold clipping (Cappy's hoodie, Prickles' belly) is a known post-launch item: report, don't patch per skin. |
| "Worked in the lobby but not in Shift" (or the reverse) | Window name AND `game.PlaceId` of the Studio you touched; is the art in that place? | Art goes in BOTH places; a place without it shows Classic. |


### Bloomer end caps, cached clips and false edge pixels (Bell Jester, 2026-11-17)

A zero-open-edge solid loft can still cap across the legs. Make a real continuous garment wall with lining and neck/arm/leg openings. r06 used an inner-void boolean without remeshing the accepted exterior (17,770 triangles, zero non-manifold edges). Never hide the legs to disguise caps. Distinguish lining-inside-body contacts from exterior cloth contacts and intentional skin visible below a hem.

For served signatures include every native body joint and Pose.Weight at the sampled keys: Head/LowerTorso/LeftUpperLeg alone falsely matched a full-body file to the upper-body ability. Compose disabled channels over the actual base layer. Do not modify/destroy fetched provider sequences: in the isolated Studio this produced empty later KeyframeSequenceProvider reads; AnimationClipProvider:GetAnimationClipAsync returned the correct121 idle keys. Clone before edits. Roblox now recommends AnimationClipProvider: https://create.roblox.com/docs/reference/engine/classes/AnimationClipProvider .

Keep the diagnostic renderer calibrated. Bell Jester REST gave small red cuff/bell-edge pixels with EEVEE1 sample; identical views at EEVEE64 and Cycles32 gave zero. CPU rays at failed pixel centres hit front-facing surfaces. Do not lower gate samples for speed, and do not loosen red thresholds or edit sound geometry to silence a renderer artefact. Evidence: characters/skins/remakes-skill-2026-11-17/bell-jester/renderer_validation/result.json .

### Continuous shorts and honest cloth checks (Bell Jester repair, 2026-11-18)

An overlapping solid-tube union can pass hole checks while retaining an obvious hip saddle seam. For this romper the repair uses continuous pair-of-pants topology with a shared crotch bridge, real lining and smooth loop-defined cuff borders. Do not assign a cuff colour by triangle-centre height: that creates a jagged paint boundary. Solidify's even-offset option produced spikes at this saddle; inspect the resulting bounds and surface rather than assuming a closed mesh is sound.

Do not let knee/shin weights pull a short hem across the bent knee. Preserve topology-based weights through later export helpers. A pelvis-fixed inner crotch can fold against separately moving thighs; compare controlled shared-thigh weight candidates in the same crouch keys. These are garment-specific findings, not universal weight numbers. Keep original body geometry and clips intact.

A raised neckline needs its own head-motion check. Here the ruffle follows the head and the cape neckline blends from head to torso before its swinging region. Held-chain checks passed 1,592 keys and 272 views; they do not certify the moving cape. Sparse chain points may clear a collider while cloth spans cross a forearm. Evaluate actual full-surface recorded physics, from multiple views, before calling that a visible defect or a pass.

“Cuffs clip on the insides” needs a medial-opening check, including the lining, against both thighs AND shins. Broad cuff-region counts mix the back of the bent knee with the inner edge the owner means; identify the actual offending points and render the exposed edge. Widening the inner quadrant and adding opening depth reduced contacts here without changing hem height, native legs or weights. Preserve a gap between left/right cuffs; a larger opening can start touching the opposite leg in crossing-leg poses. Recheck those poses and do not convert a reduced contact count into a zero-clipping claim.

### Typed loading and isolated fit previews (r13 Studio, 2026-11-18)

Before treating a fetch Failure as an unhealthy upload, check HOW it was requested. Passing raw mesh-ID strings into PreloadAsync caused AssetTypeMismatch for every visibly healthy worn mesh. Preloading the actual MeshPart instances instead returned Success for all32mesh/image IDs immediately; no mesh nudge or reupload was needed. See the instance-based examples in https://create.roblox.com/docs/reference/engine/classes/ContentProvider . Check the returned statuses, not a stale earlier failure snapshot.

A LocalScript cannot read SurfaceAppearance.ColorMap (Plugin capability). Keep the known map IDs in the prepared manifest and use a hidden ImageLabel for an explicit image preload when needed. Do not move that check onto a privileged server and call it a client fetch check.

Streaming can initially leave an ObjectValue.Value nil even when its reference Instance exists. Wait for the value and required descendants; the isolated review model used ModelStreamingMode.Persistent. Set its Humanoid to the actual R15 rig type. FBX may omit unweighted terminal cloth markers: compare imported bones to the manifest and restore exact endpoints before the game's SmartBone preparation, never rename the last weighted bone as an end by accident. Exact exposed neck/tail faces hidden by a whole-torso HideParts need explicit production packaging; a local EditableMesh copy is a test, not a shipped asset. EditableMesh UVs in this test needed V flipped from Blender UVs.

If boots seem buried, inspect the stage before changing their rig. Baseplate's default SpawnLocation top was1stud, covering correctly placed boots whose floor was.2. Moving the owned review stage away resolved it; the meshes and weights were sound. Leave an intentionally active owner review documented with restoration refs and an exact cleanup script; restore temporary boot flags once the owner finishes.

For isolated SmartBone prototypes, run parallel signal code inside an Actor, initialize/increment the package's shared.FrameCounter, and advance source animation and physics with the same simulation clock. A clamped physics delta paired with raw wall-clock animation delta invalidates the comparison. Record solver duration separately from wall delta; background throttling alone is not proof of solver cost. Restore temporary boot-script states and remove only the owned fixture after every test. Upload-free EditableMesh testing is a prototype, never a substitute for final imported/worn-game, shared-pose and real-jump checks.
