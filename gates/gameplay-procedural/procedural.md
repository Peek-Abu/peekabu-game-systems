# procedural gates

- [x] G1 Room graph and placed geometry vary,16–24 functional work rooms, winding routes/cycles and cardinal ports
  CHECK: & 'C:/Users/Bruk Abu/.rokit/tool-storage/lune-org/lune/0.10.5/lune.exe' run gates/gameplay-procedural/source-probe.luau
  EXPECT: Supplemental source specs: 8/8 passed
  EVIDENCE: Parent rerun: final Studio TestEZ2305/0 and full source gates pass; native bank/drop, searched component/floor support, continuous/corner pursuit, frozen last-seen and wall occlusion, actual emitter fade/restore and174/174doorway paths recorded in docs/cleanup-crew-gameplay-repair-verification-2026-10-13.md. See named native measurements and screenshots there; deferred art and multiplayer balance are explicitly excluded.
- [x] G2 Loading-bay attachment orientation and furniture layouts vary without violating guarantees
  EVIDENCE: Parent rerun: final Studio TestEZ2305/0 and full source gates pass; native bank/drop, searched component/floor support, continuous/corner pursuit, frozen last-seen and wall occlusion, actual emitter fade/restore and174/174doorway paths recorded in docs/cleanup-crew-gameplay-repair-verification-2026-10-13.md. See named native measurements and screenshots there; deferred art and multiplayer balance are explicitly excluded.
- [x] G3 Native TestEZ seed matrix and representative native path validation
  EVIDENCE: Parent rerun: final Studio TestEZ2305/0 and full source gates pass; native bank/drop, searched component/floor support, continuous/corner pursuit, frozen last-seen and wall occlusion, actual emitter fade/restore and174/174doorway paths recorded in docs/cleanup-crew-gameplay-repair-verification-2026-10-13.md. See named native measurements and screenshots there; deferred art and multiplayer balance are explicitly excluded.

Four-pass audit: complete fresh graph/room/corridor generator; domain review replaced mirrored-only furniture with cardinal/archetype variation; defect hunt fixed truck entrance interception/cab outsidebay and guaranteed graphcycle using initial2x2occupancy; polish uses actual wall thickness.

Native scheduler follow-up: parent full TestEZ run timed out atTestEZ.TestRunner116 without reported failed assertions. All seven procedural seed loops nowyield everyfive seeds; counts/assertions unchanged. Doorcarve spec computes mergedwall segments once/layout instead of once/door. Supplemental source remains8/8passed.

Native aperture follow-up: source-first regression requires nominal aperture>=10 and conservative collision clearance>=9; sourceprobe observed7/8fail before implementation,8/8pass afterward. Eight generator doorcall sites changed8to10, including fourbay sideoptions. No other geometry/NPCsettings changed. Strict0diagnostics,Selene0warnings/errors,StyLua clean. Native radius2 rerun remains parentowned.


Parent verification2026-10-13: docs/cleanup-crew-gameplay-repair-verification-2026-10-13.md records final TestEZ2305/0,174/174native doorway paths and measured bank/drop, component opening, support/floor, continuous/corner pursuit, frozen last-seen, occlusion and lamp fade/restoration. Earlier leaf pending paragraphs are historical and superseded by this parent evidence. Future art/co-op balancing remains explicitly open.
