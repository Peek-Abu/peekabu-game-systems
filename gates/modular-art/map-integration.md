# map-integration gates

- [x] G1 optional per-layout/per-spawn kit selection with ancestry, no global kit
  EVIDENCE: OfficeTypes.Layout.artKit, OfficeConstants.ART_KIT_ID and OfficeBuildSystem ArtKitId set before children. OfficeLayoutGenerationUtils preserves base.artKit. CargoTypes.SpawnOptions.artKit override or ancestor selection via adapter. Isolated controller injected specs cover two simultaneous kits.
- [x] G2 building/furniture/cargo paths actually call adapter and preserve existing authority
  EVIDENCE: OfficeBuildSystem floors/ceilings/walls/lights/open doorway frames, desk/locker, existing shelf/counter/plant/board markers; OfficeDecorSystem exit/elevator/monitor/keyboard/mouse. CargoSpawnSystem all 13 catalog kinds. Carryable tag lands after art; cargo proxy dimensions/values unchanged; invisible root remains collidable/queryable after reveal; adapter visual welds and Anchored synchronization tested. Vertical wall proxy orientation changes preserve original world collision envelope. Door frames request ArtOpeningWidth to preserve authored open passage.
- [ ] G3 meaningful instance specs for hidden/reveal/visuals/tags and missing-kit fallback
  EVIDENCE: OfficeBuildSystem, OfficeDecorSystem, CargoSpawnSystem instance specs written first, then expanded using isolated unparented ArtKits root (no artist Assets mutation). Cargo exercises all 13 kinds and explicit override plus ancestry, hidden/reveal/weld/unanchor; Office exercises building/furniture/dressing and fallback/enclosure/light/search tags; Decor tests unique monitor and ambiance/light preservation. Focused Selene, StyLua and luau-lsp analyze passed without Wally/package generation. Actual TestEZ execution awaits parent Studio isolated RunTests session; do not count static checks as runtime completion.

## Actual builder keys vs source availability

Building used: floorTile, ceilingTile, wallSolid, wallDoorway, fluorescent, exitSign.
Furniture used: desk, officeChair (one per desk when a clear room placement exists), locker, shelf, kitchenCounter, corkboard, elevatorFront.
Cargo: every CargoRegistry id (13), with officePlant also reused by decorative plant markers, and monitor by desktop decor.
Props used: keyboard, mouse, mug, paperTray, folder, paperStack, bookStack, deskCalendar, stationeryCup. Per-desk deterministic odd/even paper variants keep source-sized props within the 5x3 top; chairs are art-only outside the desk and checked against room walls/other desks/lockers. Missing approved templates destroy added art-only roots; existing fallback keyboard/mouse and functional monitor remain. Source monitor display face is art-local -Z (the +Z face shows rear vents — verified by screenshots 2026-10-13), so the decor proxy stays unrotated with the screen toward the -Z sitter, matching the fallback Screen.
Remaining catalog keys are available to future/map-authored semantic roots; the current layout has no matching marker or gameplay need. No large obstacles were scattered merely to claim source catalog integration. Truck/vacuum company art remains independent.

Furniture followup: two added isolated instance specs cover complete nine-prop availability + every authored desk chair, bounded tabletop placement, no gameplay tags/collision/query/touch, and missing-kit absence of all extra art-only roots. Actual Studio execution remains parent-owned.

Generated dressing root correction: training shelf.1 moved from the desk's exact point to (164, split3 - 3); equivalent storage shelf.1 moved to (164, 87). Both retain at least 0.5 stud between shelf/desk footprints, remain within room bounds and away from door/patrol approaches. Only visual shelf coordinates changed; no RNG draw, gameplay spawn marker, room, door or patrol coordinate changed. Added known-pair regression plus seven-seed deterministic bounds/clearance specs. Focused lint/format/strict typecheck passed; Studio execution pending parent.
