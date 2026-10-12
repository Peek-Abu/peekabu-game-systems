# Cleanup Crew tasks 1–3 implementation contract

User authorized rebuilding truck/keyboard, integrating vacuum and equip/idle/use/stow animations using Claude animation skill, and implementing hub navigation plus elevating all existing UI. Active game checkout is this worktree. Do not modify base main, existing untracked assets/overnight-handoff, package links, place publish or other Studio instances. No official Figma MCP. Studio/Figma ownership is parent-only to avoid cross-session mutations. No paid generation/download/new installs. Prepare exact named asset batches for required final approval; never upload to default Venture group. Public target owner is not yet verified.

Leaf ownership: modeling owns design/production-art/proof-set and server Depot/Office visual-build modules only (announce new module placement/spec-first). Animation owns design/animations, animation runtime integration and Vacuum feature except tool visual construction coordinated via parent. UI owns client UI screens, client Depot registration and UI asset data, existing Settings integration as appropriate. Parent owns gates integration, SpecRoots/module map, shared contract documentation, Studio/Figma execution, VacuumToolSystem and asset import/transfer. No simultaneous edits to shared files; send needed exemptions/interfaces to parent.

Deliverable interfaces: named CompanyTruck art model matching validated boarding footprint; keyboard source export and bounded native/import visual; vacuum asset pivot at grip and axes documented; animation keys cleanupVacuumEquip/Hold/Use/Stow with measured durations/upper-body layering/lifecycle; UI hub registers in DepotServiceClient with working Jobs/Guide/Gear/Settings scenes, no fabricated shop/rank progress. Preserve authoritative data/votes/privacy, contextual quiet HUD and phone controls. All screen families audited: depot/card/pad, shift HUD/prompts, results, catch/spectate and physical boards. Artwork/interaction language shared, award symbols remain distinct.

New modules must be named/planned in leaf plan before writing; no new role word/subfolder/service duplication. --!strict, no any/casts. Spec-first. Do not run wally/package generation while live Rojo. Evidence: local renders/native visual fixtures, meaningful TestEZ specs, lint/format/types/PR/file-length gates; production IDs and live published asset verification are pending explicit batch authorization.

Root status: work dispatched; not complete.

## Animation leaf module placement (before implementation)
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Animation | shared | Data | AnimationVacuumRegistry | Canonical approved vacuum asset IDs only; empty until upload approval and native length audit |
| Animation | server | Systems | AnimationVacuumSystem | Server-authorized tool state transitions through existing grant owner; injectable sink for specs |

Equip 0.65 s, stow 0.45 s source timings. Upper body only, no root/leg transforms. Manual stow alone may play stow; cargo/death/revoke/character replacement immediately cancel. Registry readiness gates every play rather than using foreign or invented IDs.

## UI new modules (declared before writing)
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| UI tree | client | Screens/Depot | DepotHubViewModel | Pure visibility, layout, page copy and bounded settings helpers; sibling specs |
| UI tree | client | Screens/Depot | DepotHub | Reactive hub shortcut HUD |
| UI tree | client | Screens/Depot | DepotHubScreen | Guide, equipment and persisted settings panels |
| UI tree | client | Screens/Depot | DepotHubScene | Registers page scenes |
| UI tree | client | Screens/Paper | PaperPropViewModel | Original filled prop geometry; sibling specs |
| UI tree | client | Screens/Paper | PaperPropIcon | Native renderer of original prop shapes |
| UI tree | client | Screens/Paper | PaperPortrait | Cancellable player headshot loading |
Rendering modules are exempt shells; pure view models receive specs first. No new feature/subfolder/service.


Parent vacuum visual module placement before code: Vacuum/server/Data/VacuumVisualConstants (original source geometry and grip coordinates, paired geometry specs); Vacuum/server/Systems/VacuumVisualSystem (constructs noncolliding Tool visual or clones explicitly runtime-approved artist template, paired instance specs). Existing VacuumToolSystem composes it. An unapproved artist template must never silently replace the runtime tool. Original atlas GLB/FBX remains the exact mesh upload candidate; native source facsimile supports local/live function until approved import.

UI rendering extraction: UI tree / client / Screens/Paper / PaperAwardIcon renders existing specced award shapes for results and personalized physical review boards (exempt rendering shell).

## Carry contact extension module placement (before code)
| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Animation | shared | Data | AnimationCarryRegistry | Per-cargo semantic grasp style: top-handle bags, one-hand tiny salvage, two-hand furniture |
| Animation | shared | Utils | AnimationCarryContactUtils | Pure box-surface grasp and reachable placement computation, rejects unreachable pairs |
| Animation | server | Systems | AnimationCarrySystem | Server-created native IKControl arm-only contact and lifecycle cleanup, no native joint writes |

G4 native AnimationConstraint chain support must be verified by parent Studio before runtime integration is called validated. GetChainLength0 means invalid native chain per current official docs. Explicit authored CarryGripLeft/Right attachments can supersede geometry targets once art provides them; all targets stay at actual model surfaces or supplied handles. Existing root-weld owns authoritative cargo physics; nearest-face placement correction is only for default-offset objects, explicit caller holdOffset remains honored.

Parent-requested carry boundary root fix (planned before source): Carry/shared/Rules/CarryCarrierRules — alive-Humanoid permission predicate; shell pickUp uses it before hold grant, part mutation, IK creation or state publication. Missing/root-only/dead/NaN health must not grant carrying.
