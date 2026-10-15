# office-placement gates

- [x] G1 chairs face desks, monitors face sitters
  EVIDENCE: live screenshots showed the officeChair backrest desk-side and the monitor's rear vents
  sitter-side; `chairAt` turns flipped and the monitor proxy unrotated, each with a facing spec
  (LookVector toward desk/sitter). Full TestEZ green. Chair audit 8/8 dot=+1.000; sitter-side monitor
  screenshot shows a clean display.
- [x] G2 appliances and tabletop loot sit on furniture, one piece per top
  EVIDENCE: counter policy (coffeeMachine/waterJug/printer/fishTank), table policy (plaque/monitor),
  cabinet policy (plaque); first-free assignment with floor overflow; spawn rules refuse off-policy
  spots. Live Play measured base-flush placement with production art. Full TestEZ green.
- [x] G3 searched furniture reads as searched
  EVIDENCE: `OfficeSearchedDressingSystem` (desk: pulled drawer + dark cavity on the sitter face;
  locker: 65° hinged door + dark interior; additive only, cleared on reset), wired to a new `searched`
  signal on `CargoServiceServer`. Screenshots confirm both reads. Full TestEZ green.
- [x] G4 sparse furniture stands clear and validated
  EVIDENCE: 4 authored cabinets + 2 tables, 1 generated cabinet; `validate()` refuses crowded or
  overlapping surface furniture (caught a real counter/pile overlap pre-ship). Full TestEZ green.

## Search overlay evidence superseded / 2026-10-12

Old G3 additive overlay was rejected by user. Current desk/locker keys use hollow component rigs with real drawer/hinged door tweens; originals preserved in ServerStorage.FurnitureBeforeSplitRig. Native tested6drawer pieces/2door pieces moved with no overlay; bulky cabinet and printer searched loot had floor bases0 and clear chair space. Matching door vents/nameplate added afterward. Source recipes and captures in design/search-layout-review/. Suite2,247/0, static gates pass. Production meshed-component refinement remains asset work.
