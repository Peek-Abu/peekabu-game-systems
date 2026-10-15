# Cleanup Crew: from functional UI to finished art

Current clarification (2026-10-12): office/client props and player cleaning-company equipment have separate palettes. Read [two-company art contract](cleanup-crew-two-company-art-contract.md); the office is not crew-branded. Preserve the shared stylization and existing UI kit.

2026-10-11. The user rejected the word-led and monoline icon hub studies as too generic/basic. This pass studies shipped game interfaces, establishes a shared visual direction, and starts real production-art work. It does not claim the new studies are final launch art. Existing functional layout, state, server authority and interaction fixes stay intact.

## Reference tools actually checked

- Plugin directory searches found no Mobbin or game-reference connector. No official Figma tool was used.
- [Mobbin official MCP](https://mobbin.com/mcp) exists, but requires Pro/Team; [official server repository](https://github.com/mobbin/mobbin-mcp-server) documents hosted HTTP/OAuth. Mobbin is primarily app/site reference. No subscription or installation was made. It can help settings/navigation but is not the first tool for this game's art direction.
- [Interface In Game](https://interfaceingame.com/) has game HUD/menu/lobby/results captures and videos. Inspected actual Overcooked 2 gameplay and results pixels, not just its name.
- Game UI Database has a relevant PowerWash entry, but automated retrieval was blocked/failed. Do not claim it was inspected.
- Inspected a PowerWash tablet image attributed to its UI artist, [Paul Simpson](https://johnpablo.com/powerwash-simulator-1), from the public portfolio image surfaced by image search; the portfolio HTML returned 403. Also inspected publisher Steam captures of Lethal Company and Trash Goblin. Research captures stay in ignored tmp/codex-mcp/reference-study, not in the game's art registry or external design file.

## What the references teach us (design interpretation)

| Reference | Actual observed feature | Adapt for Cleanup Crew | Do not transplant |
|---|---|---|---|
| [Overcooked! 2 captures](https://interfaceingame.com/games/overcooked-2/) | Illustrated ingredients/order cards, distinct score/time corners; torn-paper results and expressive characters. | Prop silhouettes, strong number hierarchy, visible state treatment, more personality at results than during play. | Its character art, kitchen iconography or saturated full-screen palette. |
| [PowerWash Simulator](https://store.steampowered.com/app/1290000/PowerWash_Simulator/) / artist tablet image | Tablet chassis, substantial active-nav treatment, image-led job cards, clear separation of navigation and content. | Dispatch/gear menus need recognizable objects and a real selected state; detailed information belongs in an opened menu. | A modern tablet skin that replaces our paperwork identity, or copying the entire blue theme. |
| [Lethal Company](https://store.steampowered.com/app/1966720/Lethal_Company/) | Sparse device-like HUD, carried tool visible, context-specific controls and inventory outlines. | Keep the play view open; tool/action feedback belongs to current context, display language belongs to the world. | Its thin low-contrast text, first-person assumptions or exact orange HUD. |
| [Trash Goblin](https://store.steampowered.com/app/2407830/Trash_Goblin/) | Authored material detail on tools/trinkets and physical HUD hardware echoes the world. | UI illustrations, company equipment, world props and surfaces must share a material/silhouette language. | Fantasy clutter, maximal wear, or artwork used without a license. |

These are source-backed visual observations plus our interpretation, not proof of retention/accessibility outcomes. No reference-game asset is copied into the game.

## Diagnosis of the current gap

The functional base is useful: paper identity, readable hierarchy, contextual HUD, stable target selection, lifecycle cleanup. The visual studies still looked generic because they used uniform rectangles, equally weighted outline icons, sparse flat materials, placeholder world geometry, limited brand-specific objects and no authored motion/state composition. Replacing outlines with filled icons alone will not finish the game.

The remaining work spans UI art, world art, character/tool animation, lighting and interaction polish. The empty graybox in the gameplay screenshot contributes heavily to the unfinished impression. The UI should not grow larger to compensate.

## Proposed direction: company equipment and handled paperwork

- Company teal enamel; warm ivory paper/plastic; graphite rubber/hardware; restrained amber safety markers; muted stamp red for warnings.
- Chunky recognizable object silhouettes with purposeful bevels, layered pieces and readable contact surfaces. Draw icons from those objects; a gear shortcut should resemble the company's gear case, and a vacuum symbol should resemble its real tool.
- Distinct visual families: illustrated props for navigation, compact simple symbols for data/status, bold silhouettes for urgent actions. Do not force one thin outline style onto every concept.
- Paperwork has headers/tabs/clips, ink hierarchy, deliberate edges and restrained surface texture. Selected, focused, pressed and disabled states must be visibly designed. Random noise, arbitrary rotations and excessive faux wear do not make something authored.
- Keep supported minimum type/targets and clear labels for children/touch. Reading instructions should not require guessing a decorated symbol.
- Put major personality in dispatch/gear/results; keep the active shift HUD quiet and contextual.

New Figma studies, created through the existing alternative bridge:

- [Hub direction v2](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=85-2926)
- [Shift HUD with the same kit](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=85-2996)
- [Performance review with the same kit](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=85-3046)
- [Reference decisions](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=85-3077)

Hub/shift reuse existing actual Roblox captures. Results use sample values and portrait placeholders and are a composition study; they still need approved crew portrait/award assets, edge/material finishing, state variants and motion. The studies are not a finished game skin or runtime implementation.

## Rollout across existing screens

| Screen family | Keep | Art/state work |
|---|---|---|
| Depot board/pad/travel card | Scene/queue/server flow | Dispatch ticket, illustrated truck/job, active/departure states. |
| Shift compact HUD / prompt / mobile controls | Quiet contextual layout, measured key gaps, one target | Status symbols versus tool illustrations, high-contrast focus/hold feedback. |
| Shift review / performance board | Actual results and crew data | Awards, real crew thumbnails, stamp/tally sequencing, failed/met/overtime variants. |
| Catch/CCTV/rehired | Suppression and cleanup, camera behavior | Company warning/review vocabulary; tension without unreadable clutter. |
| Toast/review tab/world cues | Layering and timing | Same ink/material palette; purpose-specific severity and motion. |
| Gear/settings/handbook/new hub shortcuts | Proposed scope only | Approved menu kit before introducing these new screens; persistence/progression separate. |

Approve three proof screens plus one phone composition and their normal/pressed/disabled/urgent states, then apply the shared kit to all families. Do not rebuild every screen independently. This pass does not ask for an unreviewable blanket redesign approval.

## Production art started

Editable original Blender study: design/production-art/vacuum-study/vacuum-study.blend, with build_study.py, product PNG and transparent PNG. It uses actual geometry and authored material assignments via an agent-written script; no image-to-3D or external mesh was used. It establishes a compact industrial tool with detachable ivory canister, teal motor/nozzle, rubber grip/gasket, steel tube and amber release/control markers. It is still a study, not a final hero mesh.

Audited: 38 source meshes, 1,544 base triangles, **12,552 evaluated triangles including bevels/text**. The small raw number is not the import cost. Consolidation, baked vents/text, UV/material atlas, collision, LOD, importer scale and hand contact remain. Do not ship the unconsolidated DCC scene or render-only floor/lights.

The 56-entry asset-inventory.csv includes 13 actual cargo IDs extracted from CargoRegistry, not invented props. Suggested proof slice:

1. One finished company vacuum and grip/use pose.
2. One truck with readable queue/loading bed and visual chassis.
3. One loading-bay/reception room: wall/door/floor/ceiling/light kit plus desk/chair/locker/board.
4. Rubbish bag, dust bag, recycling box and monitor as representative carry/fragile items.
5. Same objects illustrated in dispatch/tool/gear UI, with coherent materials and light.

Only after that slice reads as a finished game should we spread it through twelve rooms and finish the other cargo families.

## Sourcing shortlist and commercial constraints

| Route | Verified source | Decision |
|---|---|---|
| Original/commissioned hero assets | Project-specific source and contract/provenance | Recommended for vacuum, truck, Harlow/clipboard, uniform and company signs. No commission sent or paid. |
| Kenney Furniture Kit | [Pack page](https://kenney.nl/assets/furniture-kit) lists 140 files, CC0. | Free cohesion/prototype candidate, not automatically our premium final art. Test one room and finish consistently. |
| Quaternius Furniture Pack | [Specific pack page](https://quaternius.com/packs/furniture.html) lists 23 models, FBX/OBJ/Blend, CC0 and personal/commercial use. | Alternative starter; do not mix multiple packs indiscriminately. Do not generalize this license to newer packs. |
| Synty POLYGON Office | [Pack page](https://syntystore.com/products/polygon-office-pack) lists modular office pieces and 626 props. [Current one-time EULA](https://syntystore.com/pages/one-time-purchase-licence) excludes content for metaverse/game-creation software. | **Hold**: Roblox use is not cleared by the standard page; written vendor permission/suitable license is needed before adoption. No purchase/import. |

Do not confuse reference images with licensed production assets. Preserve exact pack/license/source version, creator, ownership/upload destination and modified files in an asset manifest. Paid packs/commissions require a separate budget decision. No key, paid service or upload was used in this pass.

## Technical handoff and quality gates

- DCC source: meaningful parts, pivot/grip reference, units stated, transforms applied, material palette and baked outputs. Provide clean/dirty/damaged variants only where gameplay uses them.
- Asset integration: artist-owned ReplicatedStorage.Assets must retain Rojo ignoreUnknown protection. Replace visual children around authoritative carry/queue/proximity roots; do not let art resize gameplay ranges or duplicate ownership/state. Keep collision proxies and tagged root contracts. Any runtime adapter needs planned module placement and sibling specs.
- Profile evaluated triangles, draw calls, texture memory and active pile/cargo counts on actual supported devices. Budgets are not final until that scene is measured.
- Carry/equipment: empty/full hands, pickup/load/drop/throw, fragility/pocket sizes, Tool grips, avatar proportions and animations reviewed together.
- Scene: room adjacency/doors, Harlow paths, camera collision, occlusion, readability under ordinary/night lighting; the expanded wing still needs co-op balance.
- UI: illustrated navigation remains legible at small size, numbers outrank decoration, key gaps/prompt holds work, no placeholder portraits/ranks in production. Phone composition and pressed/focus states are mandatory proof views.
- Production sign-off: source/provenance, no unapproved upload, consistent kit across room + truck + tool + UI, cleanup on respawn/catch/scene change. A nice product render alone is insufficient.

## Validation

Actual reference pixels and all three Figma studies were inspected; a dark study annotation was corrected for contrast. Blender 5.1 ran the original authoring script, saved the editable source, rendered product/cutout images and audited evaluated geometry. Inventory cargo IDs are matched to source. Runtime code is unchanged in this pass; the previous 2,144-test result is historical validation, not a new art-runtime test.


## User direction and local generator audit

The user likes the illustrated Jobs/Guide/Gear/Settings controls in hub 85:2926 and provisionally accepts quiet HUD 85:2996. Performance review 85:3046 is still too bland. Preserve the approved navigation direction; do not treat the review as approved.

Interaction intent: idle top strip teal; hover and keyboard/controller focus turn it amber/yellow; press adds a small relief/ink response; release activates once and returns smoothly. Touch needs press feedback without hover. Selected should remain distinct from transient hover. Motion must respect reduced motion and not shift the clickable target. Performance review needs actual crew portraits, existing award badges, a clearer team-result moment and a short tally/stamp sequence that can be skipped; avoid invented persistent rank data.

Correct local model root supplied by user: **E:/AI**. Read-only audit found:

- E:/AI/ComfyUI_trellis_test/ComfyUI/custom_nodes/ComfyUI-Trellis2, with Mesh Texturing and Pixal3D MultiView support in its README (multi-view updates dated September 2026).
- TRELLIS.2-4B pipeline.json and texturing_pipeline.json plus three safetensors (~3.95 GiB) in its model directory. Configs advertise both image-to-shape and mesh-texturing; this does not establish that every image-to-3D checkpoint is present or that the current pipeline runs.
- Pixal3D configs and two texturing safetensors (~3.47 GiB).
- Existing single/multi-view mesh-texturing API workflows and historical view captures. Reuse settings only; do not reuse the user's other project reference art as Cleanup Crew assets.
- Hunyuan3D portable directories for 2/2.1 under E:/AI/HY3D2/Hunyuan3D2_WinPortable. Their runtime/weights were not tested.
- GPU: RTX 3060, 12,288 MiB VRAM. [Upstream TRELLIS.2](https://github.com/microsoft/TRELLIS.2) documents 24GB minimum and Linux testing; the local Windows wrapper/offload workflow must be benchmarked instead of assuming compatibility. [Hunyuan3D 2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1) documents 21GB for texture generation in its standard path, so the same caution applies.
- A Claude AI-animation skill exists at C:/Users/Bruk Abu/.claude/skills/generating-animations-with-ai/SKILL.md; no dedicated model/texturing skill was found in that catalog. It is motion guidance, not evidence that a mesh pipeline is configured.

The unnamed recent texture release cannot be positively identified. Relevant verified candidates include [TRELLIS.2 mesh-conditioned texturing](https://github.com/microsoft/TRELLIS.2/blob/main/example_texturing.py), [Pixal3D](https://github.com/TencentARC/Pixal3D) (September 2026 multi-view inference update), and [ComfyUI's native integration](https://blog.comfy.org/p/trellis2-and-pixal3d-are-now-native). Existing local texturing support makes testing first more useful than a new download. No installation, environment edit, weight download or generation was run in this audit.

Recommended consistent production pipeline:

1. Confirm one room/truck/vacuum style target, palette, bevel language and cleanliness; use the same reference sheet across the entire set.
2. Author modular architecture and mechanical hero geometry in Blender, preserving grid/door dimensions, meaningful parts and hand contacts.
3. Compare authored material treatment versus mesh-conditioned AI texturing on one original asset. Generated base color must not bake lighting, fake lettering or incompatible realism. Use a shared material/trim library and authored company graphics.
4. Use image-to-3D selectively for secondary organic objects, then clean topology, UVs, materials, pivots, collision and LOD in Blender. Generator output is an input to finishing, not automatic production acceptance.
5. Judge the complete proof slice inside Roblox in ordinary/night lighting and supported camera distance; then roll it out through the twelve-room layout.

User input currently needed: choose whether the existing teal/ivory vacuum material study is the target, or whether it should be chunkier/playful or more grounded/industrial. Blender GUI/MCP is useful for live review but not required for the existing background authoring workflow; connection still needs verifying before claiming active MCP access. Purchases/downloads/uploads remain separate concrete actions, not implied by a style choice.


## Accepted starting proof direction / 2026-10-12

"Let's do it" authorizes the proposed teal/ivory room + company truck + vacuum proof set. Original editable Blender scene and renders now exist under design/production-art/proof-set. Keep this shared palette and industrial prop construction while refining personality and wear; approval of a starting direction is not final production approval of every mesh.

The initial conventional atlas candidate demonstrates a reliable approach: authored silhouettes, shared material rules, deterministic original geometry, atlas consolidation, then engine/animation/device checks. Vacuum candidate exports at 6,696 triangles, one mesh/material, 1024 colour atlas; no runtime import yet. The 56-entry asset inventory remains the scope, not a completed catalogue.

UI user feedback is recorded in button states 90:3092 and revised performance review 90:3166. Smooth interactions reinforce the illustrated prop buttons; final crew portraits, rating and awards must come from existing game data.


Local texture benchmark completed: 304.37 s on RTX 3060 12 GB using existing TRELLIS2 1024 weights, own mesh/render and offline model settings. Rendered and reviewed. Keep authored materials as master: generated output loses amber controls and adds unwanted edge markings; normals/unseen surfaces need checks. This proves the existing local path works, not production quality or all model support. Exact outputs and decision: design/production-art/texture-benchmark/README.md. Benchmark server stopped; no other GPU job unloaded. No new tools or Blender GUI needed for this proof phase.
