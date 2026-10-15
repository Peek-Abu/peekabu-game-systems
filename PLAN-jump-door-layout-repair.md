# Jump, loading identity and office connection repair

Contract: user reports generic banked-item boxes, repeated-jump manager pauses/escape and possible airborne catch immunity; doorway trim/pillar overlap both sides; fewer mandatory corridors, smaller rooms with size variety. Keep16–24functional rooms, four bay sides, loops, physical navigation clearance, kit selection and existing cargo/quota/A-B guarantees. No publishing/uploading. Door interactions are an ideation request; propose selective doors, do not introduce an unreviewed door gameplay system.

Use existing module-placement and orchestrated unlazy skills. Specs first; strict/no any/casts; <=400code lines. Studio exclusive parent. No Wally/link generation while Rojo serves. Parent reruns full static/TestEZ and actual held-jump pursuit, airborne catches, loading visual identity and doorway renders/native paths.

Ownership leaves:
- cargo: CargoFeedbackSystem/client and specced shared CargoFeedbackUtils/types/events as needed. Actual item visual/template geometry during bank arc, no generic box with valid art. Props preserve source immutability, kit identity, cancellation and no client authority. Propose newmodule placement before creation.
- layout: OfficeLayoutGenerationUtils/GraphRules/RoomUtils and sibling specs/types as needed. Mix real direct shared-wall links and corridor links; shrinkroom sizes, vary dimensions; adapt marker packing rather than clipping/overlaps. Suggested lattice variable column widths/row heights and zero-or-positive boundary gaps yields realadjacent roomwalls without graph-only shortcuts. Preserve16–24rooms/cycles/4ports/bay and physical doorwidth10. Propose anynew helper module beforecreation.
- doorway: OfficeBuildSystem/spec and existing ArtVisualSystem/spec only if needed. Diagnose monolithic wallDoorwayasset outerwall panels scaled to opening10 causing oversized decorative columns. Fix narrow two-sided jamb/header geometry without duplicating wallpanel skins or blocking aperture. Existing assets remain untouched. Propose newmodule beforecreation ifBuild cap requires splitting.
- parent: NpcMoverSystem/NpcPathRules and Occupant server/shared catch/brain/service/specs, integration, Studio and docs. Diagnose airborne path destination and 3D versus horizontal catch reach while preserving genuine elevation separation, LOS/safezone/grace.

Acceptance files: gates/jump-door-layout/{cargo,layout,doorway,integration}.md. Native proof belongs parent; leaves certify only source checks.

Approved module placements before creation:
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Art | shared | Systems | ArtVisualSystem + spec | Move the existing safe art renderer for server/client reuse; server compatibility wrapper retains callers. Cargo agent owns migration; doorway agent will not edit ArtVisual. |
| Office | server | Systems | OfficeDoorwayVisualSystem + spec | Narrow two-sided noncolliding trim and consistent doorway lintel, replacing oversized monolithic wall-panel doorway art. Doorway agent owns. |

Cargo owner expanded to source packet metadata in CargoLoadSystem/server CargoService announce boundary, shared CargoTypes/Events/FeedbackUtils and pocket provenance as necessary. Preserve server authority, default/backward compatibility and code cap. Parent owns noCargo edits. Header must remain visible BELOW ceiling: recommend9.5stud clear height +solid cream lintel to12stud walltop, so frame isn't hidden above ceiling. Explicitly testNPCheight8 clearance; noactualdoor leaves/gameplay in thispass.
| Cargo | client | Systems | CargoSwoopSystem + spec | Assemble an independent ghost using shared art renderer; animate scale/pivot and destroy safely without retained renderer callbacks. |
| Occupant | server | Rules | OccupantReachRules + spec | Shared pure horizontal/body-height grab reach used by brain and authoritative catch recheck; normal jumping remains catchable while distinct elevation is rejected. |
| Occupant | server | Systems | OccupantSenseSystem + spec | Native LOS and character foot-height gathering, extracted from capped service; keeps brain/catch measurements consistent for R6/R15. |
