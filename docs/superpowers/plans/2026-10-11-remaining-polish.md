# Remaining Cleanup Crew polish

User requested continuation of the original review on 2026-10-11. Handoff text supplies historical context; it is not a new user instruction. Preserve untracked art and existing approved paperwork designs. No official Figma MCP, uploads or publishing.

## New modules (before implementation)

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Shift | client | Rules | ShiftPromptRules | Pure eligible-target ranking and stable selection. |
| Office | server | Utils | OfficeLayoutGenerationUtils | Seeded connected modular extension of authored core. |
| Paper UI | client | UI/React/Screens/Paper | PaperButtonViewModel | Pure hover/press/focus ink treatment for existing menu buttons. |

Both get sibling specs. Add meaningful specs to existing DepotBuildSystem and OfficeBuildSystem (currently exempt Instance shells) for physical enclosure and surface contracts. Extend UIBillboards specs for SurfaceGui lifecycle; no new role or service.

## Work

1. Select one reachable, visible prompt, with aim relevance and stable ties; use the same target for one cargo price label. Release holds on target change. Server validation remains authoritative.
2. Generalize typed world GUI roots to BillboardGui | SurfaceGui; convert only physical contract/results/personal-review boards. Retain camera-facing truck tags, name cues and reward floaters. Physical backboards match canvas aspect and face; no camera-relative offsets.
3. Add depot roof and per-room ceilings to generated geometry; cap native zoom at 16 studs with Zoom occlusion. Do not mount Workspace.
4. Extend the seven-room authored core with five seeded modular rooms, loop doors and patrol/spawn markers; regenerate safely before each shift. Keep core loading bay, spawns and rest point stable. Validate layout, route, capacity, spawn guarantees over multiple seeds and live navigation.
5. Save practical first-launch hub, animation, uniform/name/rank and cohesive asset/tooling briefs with current primary sources. New hub menu design should be a reviewable screenshot-backed Figma proposal before implementation, if approval is still required. Functional repairs reuse approved designs.
6. Run separate Studio TestEZ, static gates and fresh non-test play verification; remove diagnostic state. Report remaining production-art and device/multiplayer limitations clearly.

## Completion evidence

- Final isolated Studio TestEZ: **2,144 passed, 0 failed** (2141 before the three PaperButton feedback specs). Initial specs were written before implementation; the first run failed to load the not-yet-created ShiftPromptRules module.
- Full source Selene/stylua/luau-lsp, placement rules, file-length and whitespace gates passed. Module map updated. No package regeneration or installation while Rojo was live.
- Two fresh shifted sessions generated distinct LayoutSeed values (697053524 and 747234453). Each had 12 physical room ceilings. Native PathfindingService returned Success from the archive to all four new wing rooms for both seeds.
- Live native prompt selection: two cargo items near the player yielded one active 6-stud prompt; real E picked up only item 1 (CarriedBy set for that item only). At 12 studs there were zero active prompts; an inserted solid occluder also yielded zero. Temporary camera/occluder restored or removed. Diagnostic item moves disappeared when the agent session stopped.
- Camera startup verified with LocalPlayer.CameraMaxZoomDistance == 16. The initial StarterPlayer-only approach did not apply to the existing Rojo session, so final code applies/restores tuning through the owning CameraServiceClient; default.project.json remains unchanged.
- Depot ceilings/lighting and physical contract/result boards inspected in a live screenshot. Personal review is SurfaceGui, Face Back, under its owner's PlayerGui, ResetOnSpawn false. Client review root mounted while shared root was hidden; removing the diagnostic review restored the shared root. Multiplayer privacy remains a separate verification.
- Existing PaperButton live fixture: hover and pressed colors changed distinctly; mouse release activated once. Fixture destroyed. Touch/controller gestures remain unverified.
- Launch-hub proposal created in the existing Figma file through Southleft's alternative bridge, node 81:2792, over an actual 1192x588 game screenshot. User explicitly approved this addition after automatic approval review rejected the initial new-image write. No official Figma MCP used. This is a proposal, not a shipped hub/progression menu.
- UI skill updated for the WorldShell union and current prompt/selected-price behavior. Animation inventory, uniform/name/rank approach, commercial-kit candidates and optional modeling tools are in docs/cleanup-crew-launch-polish-2026-10-11.md.
- End state: agent-started Play stopped, RunTests cleared, temporary button/review/occluder GUI removed, diagnostic camera restored. No commit, push, upload, publish, paid service, asset import or new MCP installation. assets/ and overnight-handoff/ remain untouched and unstaged.

Launch work still open: finished hero meshes/contact animations; approved hub UI and persistent rank/economy implementation; real devices, avatar variants, multiplayer/co-op pacing and broader seed/path tests. The procedural pass is a seeded modular wing around a stable authored core.
