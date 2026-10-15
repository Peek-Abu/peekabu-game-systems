# Cleanup Crew remaining work / reconciled 2026-10-12

Scope: Cleanup Crew game launch and the user's original requests, not the entire shared-systems ROADMAP. Historical plan checkboxes are not a current completion certificate. No public-player test yet. No asset/place uploads performed by this pass; calendar remains excluded.

## Completed in this repair pass

Manager: 2,247 final isolated Studio tests pass, including pursuit regressions. Actual corner trial: chase at0.25s, search retaining target at0.75s, re-acquisition after entering hall at1.25s, catch at2.25s, patrol afterward. This proves corner pursuit, not public-player difficulty balance.

Searchables: same hollow component rig, six drawer pieces tween forward; locker door and details rotate around a hinge. No searched overlay on the component rig. Native Parts replicate and require no uploads. Original monolithic mesh templates preserved in ServerStorage.FurnitureBeforeSplitRig; replacement prototypes installed at the same desk/locker semantic keys. Source geometry recipe: design/search-layout-review/component-rigs.json; buildTemplate in OfficeSearchedDressingSystem reproduces it. Asset agent can replace individual pieces with polished meshes while retaining SearchComponent=drawer/door and SearchDoor leaf name. No separate searched asset required.

Loot: actual filing cabinet3x5x3.5 and printer3x3x3 searched from desk/locker; both bases at floor0, six/two components moved, no overlay. Clear side/floor candidates use full cargo footprint, room support rays and collision/visual-chair envelopes. No suitable floor means search stays available and contents are not consumed. Large items never have to fit in small containers because they appear beside them.

Generation: thirteen connected rooms; substantial seeded core/wing proportions, 10stud spine, at least8stud cross arm, 6stud wing doorways, shuffled safe bay arrival order, optional staff-room loop links. Shared edges remap together; no second overlapping building. Thirty-seed logical/clear-door/spawn guarantees. Native eight-stud-tall agent paths passed15/15doorways on seeds1/19 and17/17on loop seed2 after the navigation mesh settled (three initial immediate-query misses). Loading bay stays stable deliberately. Rooms remain an orthogonal office template, not an arbitrary dungeon generator.

## Still needed

| Area | Current basis | Remaining work |
|---|---|---|
| Production art | Client kit imported in Studio by asset work; split furniture now editable native prototypes | Asset-agent final mesh/component refinement; validate truck/vacuum proportions and grip; signs/branding, Harlow/clipboard, final materials/lighting, polished room-specific dressing; mobile LOD/part/render budgets and cross-map kit QA. Calendar excluded. |
| Room variety and procedural gameplay | Core proportions, hall access and some connections vary | More distinguishable archetypes, furniture density/layouts, multiple map/entrance templates if desired, seed stress tests, readable wayfinding, meaningful contract/objective modifiers. Room count alone is not replayability. |
| Difficulty and immersion | Corner pursuit works; speed/search pressure updated | Real running-player evasion, noise/search persistence, four-player target switching, safe-bay/grace/rest behavior in co-op; catch frequency, quota/time/travel balance on larger maps; final audio/light/footstep/voice scare mix. |
| Animation | Native idle repair and carry IK work; vacuum source candidates exist | Verify which clips are actually published/integrated; contact validation across avatars; equip/hold/use/stow, light/heavy/bulky carry, pickup/load/drop/throw, rummage/pocket actions, Harlow patrol/chase/look/grab/throw/break/clipboard. Verify base/main idle fix merge status. |
| UI finish | Icon-led hub/screens, shared button motion, dedicated award silhouettes, progress tweens | Live portrait/landscape/desktop compositions; long/rebound/localized keys; performance review density/portraits; every hover/focus/press/hold/accept/refuse transition; controller focus, actual touch, reduced motion and purposeful sound. Recheck against final Roblox screenshots, not isolated Figma alone. |
| Controls and complete MVP loop | Queue-to-shift, searchable placement and chase tested | Finish end-to-end manual hotbar1, vacuum/pile clear/empty bag, pickup/carry/pocket/swap/drop/throw, load/bank/quota, clock-out/results/vote/return/Another shift; repeat runs without stale models/prompts/animation contacts. |
| Multiplayer and robustness | Server authority and regression suite | Real2–4players, late join/full trucks/depart failures, simultaneous search/pickup/bank, death/respawn/leaving/cargo destruction, owner/observer animations, private review isolation, reconnection and persistence failures. |
| Onboarding | Guide/work-order/gear explanations | First-time contextual tutorial, accessible controls, understandable quota/loading/canister/noise/optional salvage, forgiving first shift; measure where unfamiliar players get stuck. |
| Persistent player goals | Researched proposal only | Minimal crew passport/milestones, saved wages/earned styles, gear locker/loadout preview and visible next goal; then salvage casebook and mastery challenges. Real rank/XP/title persistence before rank tags. |
| Company identity | Avatar-preserving vest/apron/badge concept | Opt-in uniform assets, avatar fitting/restoration, nametag/ranktag behavior; earned rank variants after progression. Do not force everyone into a replacement avatar. |
| Retention/public validation | Shift analytics and hypothesis matrix | First external public/co-op tests; baseline D1/D7 and session/replay data, onboarding/goal/equip/return instrumentation; compare contracts/goals causally. No claim that retention is already proven. |
| Monetization | Cosmetic tool/sound/style proposals | Desirable previews and guaranteed cosmetic choices; evaluate passes versus repeatable dev products; real paid conversion/demand testing. No actual shop/catalogue/products/economy tuning from this research pass. |
| Analytics accuracy | M5 events exist | Pocket source preservation; same-kind multiple salvage attribution; distinguish Harlow catch from other deaths; leaving-player delivery; session grouping decision; verify live dashboard and build labels. |
| Release QA | Static gates and dedicated TestEZ | Real phone/tablet/controller and broad avatar matrix, streaming/performance/network checks, asset ownership/moderation/permissions, two-place travel, private data/save tests, remove diagnostic overrides, manual publish checklist and rollback rehearsal. No automatic CD or place publishing. |

## Suggested sequence

1. Finish the unfamiliar-player MVP loop, device/co-op and manager balance checks using the current art.
2. Asset agent finalizes consistent room/tool/furniture components; integrate matching animations and UI QA.
3. Add the smallest saved progression/next-goal loop and onboard it.
4. Public test with analytics, then prioritize features using measured replay/retention. Test monetization demand after cosmetic desirability exists.

References: docs/cleanup-crew-original-request-status.md; docs/cleanup-crew-launch-polish-2026-10-11.md; docs/cleanup-crew-ui-implementation-audit-2026-10-12.md; docs/cleanup-crew-ui-pass-coordination.md; docs/cleanup-crew-office-scale-2026-10-12.md; docs/cleanup-crew-retention-and-monetization-2026-10-12.md; docs/cleanup-crew-validation-hypotheses.csv; docs/cleanup-crew-m5-checklist.md; docs/cleanup-crew-publish.md; design/animations/vacuum/README.md; design/animations/carry/README.md.


## Update2026-10-13

Currentrepair verified: drop/throw truckbanking, recyclingidentity/stablegroundcargo, hollow movingdrawers/180degree lockers, floor-safe searchedrewards, flush fitted wallvisuals, actual worktop support, raised opaquefloor, wider doors, variable16–24workroom graphs/fourbay sides, continuous cornerpursuit/frozen lastSeen, occluded headUI and visiblelampfades/coverage. TestEZ2305/0;174/174native doorwaypaths. Evidence: docs/cleanup-crew-gameplay-repair-verification-2026-10-13.md.

Still open: printer/recycling-interior/static fish-tank replacement/dust-bag badge/final furniturematerial artpass; vacuum hearing explicitlydeferred; richer zonefurniture/wayfinding/density and separateL/T hallwaymodules; actualco-op quota/travel/scarebalance. Broad progression/onboarding/device/publicretention/monetization/release work above remains open. No upload/publish.

## Latest reconciliation: camera, art and manager direction

See `cleanup-crew-manager-direction-and-mvp-2026-10-13.md` for the current prioritized MVP list and manager proposal. The historic generation/manager/test counts above are superseded by the newer verification documents. Dust-bag badge and printer floating controls are repaired in canonical exports and local Studio previews; uploaded production replacements remain pending. Selected vacuum/truck art integration is still open: runtime uses native source geometry. No manager changes were made during this ideation request.
