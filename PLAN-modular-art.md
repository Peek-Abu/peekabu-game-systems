# Modular map art / building, furniture, cargo

User explicitly requests creating remaining building kit, room furniture and all gameplay cargo, then integrating; different maps need selectable kits across asset families. Client slate/wood identity is separate from cleaning company teal/ivory/amber. Do not narrow this to a sample room. All work in this game worktree; preserve other agent layout/art work and existing untracked assets. No official Figma. Parent exclusively controls Studio/Figma. Do not publish assets/place or download paid assets. Final publication owner/batch approval is still unresolved, but source creation, local native staging and runtime adapters are authorized.

## Contracts before work

Art namespace: artist-owned ReplicatedStorage.Assets.CleanupCrew.ArtKits/<kitId>/<family>/<assetKey> (each asset Model). KitId = client-office-slate. Family = building/furniture/cargo/props/equipment. Each runtime-approved Model must have RuntimeApproved=true, BaseSize Vector3 (authored dimensions, used for visual-only fit), and a bottom/base-centred pivot. Empty/missing/unapproved templates cannot hide existing visuals. Do not mount artist Assets in Rojo.

Runtime ArtVisualSystem.attach(root:BasePart,family:ArtTypes.Family,assetKey:string,kitId:string?,hidden:boolean?):Model? clones artist template if present/approved, validates safe visual children, aligns to root floor, fits source visual to existing proxy without changing proxy bounds/tags/physics/gameplay authority. Visual parts: noncolliding/nonquery/nontouch/massless, welded to root; anchored only when root is anchored. Preserve original visual transparency per part, hide/reveal cleanly. Original root transparency only hidden if attach succeeds; methods setHidden(root,hidden) and resolveKit(instance) support lifecycle and map-local selection by ancestor ArtKitId. Use invisible authoritative cargo proxy, not mesh collisions, for carry/load/pocket.

Map selection: Office Layout optional artKit:string? plus OfficeConstants default; store ArtKitId on built model BEFORE children are built. Cargo inherits kit from spawn parent ancestors or explicit SpawnOptions.artKit override. NO single global current-kit variable: multiple maps can coexist. New kits replace matching semantic keys; optional fallback to default kit is explicit and tested, not missing defaults disguised as approval. Existing company truck/vacuum remain outside client kit.

Required source coverage: 12 building keys wallSolid,wallDoorway,wallCorner,doorLeaf,ceilingTile,floorTile,skirting,window,fluorescent,exitSign,pillar,garageDoor; 13 furniture keys desk,officeChair,locker,shelf,corkboard,filingDrawer,wasteBin,wallClock,breakTable,kitchenCounter,elevatorFront,pipeSet,cableSet; ALL CargoRegistry ids (13): rubbishBag,dustBag,recyclingBox,bottleBag,officePlant,plaque,monitor,waterJug,printer,coffeeMachine,fishTank,goldenStapler,filingCabinet. Reuse/refine existing v2 desk/chair/bin/monitor instead of duplicating competing art. Existing extra props retained as props family: keyboard,mug,paperTray,folder,paperStack,mouse,bookStack,deskCalendar,stationeryCup. Total logical keys 47, reuse mapping documented. All source geometry/materials original, atlas-embedded GLBs, editable source and honest source/export/native-preview labels. A complete source catalog does not imply runtime integration if template approval/persistence is pending.

## Ownership / leaves

art-catalog owns design/production-art/map-kits/client-office-slate, scripts there, manifests/renders/audits. No runtime/Studio edits. Full 47-key catalog source and original completion, visuals inspected, geometry/GLB/material/pivots audited. Avoid modifying original v2 batch.

kit-runtime owns new shared/server Art feature modules/specs only. No Office/Cargo edits, no SpecRoots/module map edits, no Studio. Spec-first, strict/no any/no casts. May propose narrower template contract fixes to parent before changing signature.

map-integration owns OfficeBuildSystem + existing Office data/types/tests, CargoSpawnSystem + spec if needed and existing Cargo types/tests. Use kit-runtime interface above. No new Art modules, no shared SpecRoots/module map, no Studio. Preserve office expansions/markers and gameplay root dimensions. Runtime approved templates exercised by instance specs; missing templates preserve functional fallback.

Parent owns Studio/Figma, cross-leaf integration/gates, SpecRoots/modulemap and final owner/publication handoff. Creation/upload authority must not be conflated. Run checks without Wally/package regeneration while Rojo live. TestEZ in isolated RunTests session only.

## New module placement (before source)
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Art | shared | Data | ArtTypes | Typed kit/family contracts |
| Art | shared | Data | ArtKitRegistry | Semantic family coverage, map kit catalog and default |
| Art | shared | Rules | ArtKitRules | Validate kit identifiers/template safety/fit policy as needed |
| Art | server | Systems | ArtVisualSystem | Clone/fit/weld/hide approved visuals around existing root |

Every implementation gets sibling spec (types only may existing exemption pattern with reason). No new subfolder kind, role word, second service. Any further module planned here by leaf before writing.

Status: work started; no completion or production upload claimed.

Map integration existing-file scope: OfficeBuildSystem/OfficeConstants/OfficeTypes and CargoSpawnSystem/CargoTypes; parent also approves OfficeDecorSystem existing module and sibling spec. No new implementation modules. Zone markers are already authored by layout generation; build each once. Building proxies retain bounds; art attaches to their roots. Desk art replaces desk body while desk dressing remains separate and unique. Decor preserves exit illumination, elevator ambiance and monitor illumination.

Parent approved minimal OfficeLayoutGenerationUtils + sibling spec update: preserve base.artKit through seeded expansion; all existing room/marker generation stays unchanged.
Parent furniture followup: extend existing OfficeDecorSystem with deterministic bounded per-desk art-only chair and all nine desktop prop semantic keys. New art-only roots stay invisible/noncolliding/nonqueryable/untouchable and are destroyed if template attachment fails. No new implementation modules. Source monitor authored front +Z is rotated to Office -Z convention; fallback screen placement remains on world desk-front side.
Parent approves root correction of generated visual shelf/desk overlap. Existing GenerationUtils only: move training shelf and the equivalent storage shelf away from desks, keeping all gameplay marker coordinates, generated geometry, door positions and RNG consumption unchanged. Sibling specs cover both regression pairs plus representative seeded deterministic shelf envelopes, room bounds, door approaches and patrol/rest clearance.

Parent verification 2026-10-12: owner selected Icey Labs189923277; named47-model upload approval pending. Full2215/0 Studio tests and static gates pass. Local native review inspected in Figma113:3470. EditableMesh server staging does NOT replicate: removed all local-only templates from production namespace and isolated them in ServerStorage. Persistent uploads/client verification are still required; do not claim shipped integration. Camera protected property root fix uses StarterPlayer Rojo properties.
