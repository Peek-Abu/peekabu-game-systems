# Status against the original Cleanup Crew request

Updated 2026-10-11 after the icon-led design correction. Distinguish functional repairs from production art and launch features.

| Original point | Current status | Remaining |
|---|---|---|
| Learn repo/MCPs/Claude skills | Done; Cleanup Crew worktree, Studio and alternative Figma bridge used. | Optional Blender modeling bridge if useful; no new installation required for coding. |
| Billboard versus surface UI | Physical depot contract/results/personal reviews converted; behavior recorded in UI skill. | Use SurfaceGui for future leaderboards/terminals, verify multiplayer review isolation and all viewing angles. |
| Broken idle / raised arms | Game idle corrected and live-verified; root cause was inherited clip. | Equivalent base fix is prepared in codex/fix-r15-idle, still uncommitted/unmerged into main. Broader avatar check. |
| List animations needed | Priority inventory written in launch brief. | Author and integrate held/use/equip/stow, carry/pickup/load/throw/rummage and Harlow clips; no new production clips uploaded. |
| Shift HUD obstructs gameplay | Approved compact contextual HUD implemented; crew collapsed. | Apply icon language, broader catch/overtime/4-player/device compositions and real touch/controller tests. |
| Prompts too distant / many items | Single visible/reachable target; carry cap 6 studs, others cap 8; one selected cargo price. Real E, distance and wall tests passed. | Tune through co-op/device playtests; hold-switch edge cases. |
| Key square/text collisions | Prompt key measured with padded gap; clock-out banner spaced. | Long/rebound keys and localized text on real devices. |
| Drab interactions | HUD press/hover/focus and menu ink feedback implemented and checked. | Broader selected/accepted/rejected transitions, purposeful sound and icon-driven hierarchy; reduced-motion/device coverage. |
| Boring hub / launch features | Hub shortcuts implemented and live-verified 2026-10-12: Jobs (work order + dispatch card), Guide (4-step loop), Gear (vacuum/carry facts, no fictional shop), Settings (5 persisted steppers, Music 100->90% clicked live). | Rank/XP/cosmetics persistence and handbook/settings content need scoped implementation (retention program). |
| Small / non-procedural building | 12-room office, seed-varying modular wing rebuilt each shift, loop doors and new patrol/spawn markers. Paths checked for two live seeds; 30 logical seeds covered. | Authored modular art kit, wider variation themes/layouts, pacing/quota/Harlow co-op balance and seed/path stress tests. Seven-room core is still stable. |
| Vacuum in inventory / low friction | Real server-owned Tool, auto-equip, cargo stow/restore, manual stow and respawn support. Native suction checked. | Finished model and hand-contact animations; manual 1 key and touch/gamepad flow are not fully verified. |
| Camera outside hub / no ceiling | Hub roof, room ceilings, lights; native camera max 16 with Zoom occlusion verified. | Decorated exterior, garage doors/openings, final lighting and avatar/camera corner cases. |
| Cohesive assets | Art-direction/sourcing brief completed; code-built meshes remain prototypes. | Large production pass: truck, vacuum, furniture/cargo, walls/doors, company signs, Harlow/clipboard, uniforms, materials and lighting. One consistent kit and palette, not mixed marketplace styles. |
| Company cleaning outfit | Avatar-preserving optional vest/apron/badge approach proposed. | Author/fit assets; appearance restoration and opt-in wardrobe; rank variants after progression exists. No forced outfit implemented. |
| Nametag / ranktag | Behavior/design recommendations written. | Actual company tag UI and authoritative persistent ranks; do not show invented progression. |
| Icons (new correction) | Hub revised in Figma; 14 original SVGs and reusable Figma vector components created. UI skill updated. | Approve screen usage and integrate through runtime PaperIcon/UIAssets; export/upload assets with required authorization. No Roblox image upload yet. |

The large coherent art pass is the largest outstanding production task, but it is not the only one. Highest-value sequence: lock one representative room plus truck/vacuum style; author matching contact animations; implement the approved icon-led hub and progression/wardrobe scope; then run real co-op/device/avatar validation and tune the expanded office.

Current design: [icon-led hub](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=81-2792), [ink icon set](https://www.figma.com/design/PYtXsNlpV1MW2nOVx0wXl4?node-id=82-2856). Editable local sources: design/cleanup-crew/icons/. Detailed animation/art/tooling recommendations: docs/cleanup-crew-launch-polish-2026-10-11.md.

This icon pass changes design sources and guidance, not runtime code. XML/grid/stroke validation and visual Figma captures were checked; the historical runtime suite remains 2,144 passed, not a new icon-runtime test. No upload, publish, push or commit performed.


## Latest art-direction correction

The user rejected the first monoline icon treatment as too generic/simple. It is retained as an exploration, not a final approved kit. Research now covers actual Overcooked HUD/results, PowerWash tablet, Lethal Company and Trash Goblin captures. Shared hub/shift/results studies are 85:2926 / 85:2996 / 85:3046. An original editable Blender vacuum material/mesh study and 56-entry production inventory were created; neither is a production-ready runtime replacement. Full findings: docs/cleanup-crew-art-direction-2026-10-11.md.


## Live verification — 2026-10-12 (tasks-1-3 Studio drive)

StudioMCP-driven session, TestEZ **2182 passed / 0 failed** (fixed 2 `AnimationCarrySystem.spec` failures: `Destroying` fires deferred, never synchronously — specs now wait 0.1 s; verified for detached, ServerStorage and Workspace instances). Live: pad join/countdown/DEPART NOW, shift HUD desktop + iPhone-17-Pro 874x402, suction 47% then pile clear with canister 1/3, E pickup with both carry-IK chains bound, G-drop cleanup, two Harlow catches (CCTV + carrying-variant incident report), time-clock E clock-out, PERFORMANCE REVIEW with award art + real headshot, vote auto-pick into another shift. Evidence: `tmp/muse-gates/*.jpg` (scratch, ignored). Gates `gates/cleanup-crew-1-3/` all checked except integration G3 (upload batches await approval). No uploads performed.

Still open: manual vote click, physical touch/controller hardware, real-audio checks, 2+ client co-op, seed/path stress, avatar-variant fit.


## Production proof phase — 2026-10-12

The user accepted teal/ivory as the starting proof direction with "Let's do it" and asked to continue. Completed: original matching room/truck/vacuum Blender proof set, truck and vacuum GLBs, inspected renders, 56-entry asset inventory, and a separately atlas-consolidated vacuum candidate (6,696 triangles / one mesh / one material). This begins the large art pass; it does not finish all 56 assets or integrate them into Roblox.

User-liked illustrated hub props are retained. Alternative Desktop Bridge added a five-state button study (90:3092) and stronger receipt/crew performance review (90:3166), with sample examples of the game's existing awards. Idle strips are teal; hover/focus/pressed are gold; selected is a separate teal outline. A standalone HTML preview covers focus, hover, press, touch click, close/Escape, cancellable tally and reduced motion. Its JS syntax passed; interactive browser verification remains outstanding because the browser tool failed.

Still outstanding: art style review and refinement, modular kit production and scene dressing across all rooms, all actual cargo assets, Harlow/uniforms/tags, PBR/UV/detail baking and LOD/collision, contact animations and grip/scale, shared runtime icon exports/uploads and hub screen wiring, progression/wardrobe scope, deeper procedural variation and pacing, four-player/touch/controller/device/avatar tests, and merging the prepared idle fix into base main. No upload or publish has occurred.


Local texture benchmark completed: 304.37 s on RTX 3060 12 GB using existing TRELLIS2 1024 weights, own mesh/render and offline model settings. Rendered and reviewed. Keep authored materials as master: generated output loses amber controls and adds unwanted edge markings; normals/unseen surfaces need checks. This proves the existing local path works, not production quality or all model support. Exact outputs and decision: design/production-art/texture-benchmark/README.md. Benchmark server stopped; no other GPU job unloaded. No new tools or Blender GUI needed for this proof phase.


## UI implementation begins — 2026-10-12

Latest user explicitly authorized implementation and requested stronger smooth scale/tilt/press feedback plus distinct award symbols. Shared PaperButton now animates an inner face (hover/focus 1.035x / -1.2°, press .965x / +.8°, 160/90 ms cubic-out) while preserving the hit/layout slot. Transitions/unmount cancel render connections; disabling/window focus loss releases press; Roblox reduced-motion preference removes geometric animation.

Implemented five original dedicated native GUI award silhouettes with matching SVGs; ShiftReviewViewModel maps real existing server award titles, unknown titles stay text-only. Existing rating, results values, complete awards, voting and phone fold behavior retained. Desktop and 844×390 phone fixtures inspected. Real mouse hover/press/release/leave and UI focus measured; one click activated once with a fixed 230×54 target. Pure specs plus separate Studio suite: 2,150 passed, zero failed. Static lint/format/type/file-length checks pass. Actual physical touch/controller hardware remains untested. Figma board 96:3272 and review 90:3166 updated via alternative bridge.

This implements shared buttons and awards in the current UI; new hub screens/navigation, the larger receipt composition/real portraits, and art imports remain separate work. No asset upload/publish. Art proof has been re-shown for review and copied into the app visualization folder; showing it is not approval of final art.


## Retention/business scope — 2026-10-12

User rejected proof keyboard/truck proportions and requested an unbiased retention/monetization/persistent-goal assessment. No public-player test exists (user confirmed). Researched brief and six-hypothesis validation matrix are saved in docs/cleanup-crew-retention-and-monetization-2026-10-12.md and docs/cleanup-crew-validation-hypotheses.csv. Recommend a minimal passport/locker/earned-style/next-goal test, then casebook and meaningful contracts; developer products focus on guaranteed cosmetic choice. Existing shift analytics help but persistence/onboarding/goal/shop exposure and durable reward instrumentation are missing. Proposed numerical gates are assumptions, not validated retention. No economy or products implemented, no publishing/acquisition performed. Keyboard/truck are explicitly unapproved and their root geometry issues are recorded.
