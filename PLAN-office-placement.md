# Office placement & loot surfaces

User steering: the office must read like an actual office, not scattered graybox-plus-art. Loot belongs ON
things (desks, counters, tables) — most kinds, not just some. Chairs are backwards at desks, computers show
odd lines, appliances sit on floors. Searched containers must read as searched (drawers out, locker ajar).
Sparse procedural cabinets/tables are authorized to create surfaces where the layout has none. Floor
complaint dropped by user as not important.

## Verified facts (live Studio evidence, 2026-10-13)

- Chair backwards CONFIRMED: isolated desk+chair build, side screenshot — backrest on the desk side, sitter
  would face away. Root cause: `chairAt` turns assume the officeChair template seats toward +Z at turn 0;
  observed it seats toward -Z (its CFrame LookVector). All four candidate turns are exactly inverted.
- Cargo spawns on the floor BY CONSTRUCTION: `CargoSpawnSystem.spawn(kind, floor, ...)` stands the part on
  whatever CFrame it is given, and every caller passes a floor-plane frame (`floorAt(marker)`, search-front,
  `floorUnder`). So monitors, coffee machines, printers all sit on floors. The spawn function itself already
  accepts any surface frame — callers and plans are the fix site, not the spawner.
- Search completion spawns the found item "on the floor in front" (`CargoServiceServer.search`) and records
  `stocked.searched = true` with no visual change to the container. Hook point for searched-state dressing.
- Monitor "weird lines": open — streaks visible on the art screen in screenshots; graybox Screen plane sits
  ~0.005 under the art screen surface (z-fight candidate) OR authored texture. Isolate before fixing.
  DONE 2026-10-13: isolated — graybox Screen hidden yet streaks persist; opposite-side screenshot shows a
  clean display on art-local -Z, so the +Z slits are rear vents and every monitor faced AWAY from its
   sitter. Fix: proxy unrotated (removed the pi turn) + facing spec. Sitter-side screenshot confirms a
  clean screen. Fallback dressing already faced -Z correctly. Full TestEZ 2,223 passed / 0 failed.

## Slices (spec-first, in order)

1. Chair facing (this plan's first code): flip the four `chairAt` turns + facing spec in the existing
   `OfficeDecorSystem.spec` (chair LookVector must point at its desk). Existing modules only.
   DONE 2026-10-13: spec added, turns flipped, live audit 8/8 chairs dot=+1.000, screenshot confirms
   backrest away from desk. Full TestEZ 2,222 passed / 0 failed. Gotcha: Edit-session `require` cache
   serves stale modules to `execute_luau` — clone-then-require (or a fresh Play session) for verification.
2. Monitor lines: hide-graybox-screen isolation screenshot; fix in `monitor()` (offset/destroy screen when
   art lands) or hand texture to artist with evidence. Existing modules only.
3. Loot on surfaces: kind→surface policy in `OfficeSpawnRules` (existing server Rules); surface spots from
   desk/counter markers in `OfficeSpawnUtils` (existing Utils); pass surface frames at `OfficeServiceServer`
   spawn sites (existing service). No new module.
   DONE 2026-10-13 (v1: counters only — desk tops are fully dressed, tiny loot waits for slice-4 tables):
   `surfaceTopY` in OfficeLayoutUtils, `surfaceKinds` policy + check in OfficeSpawnRules (counter:
   coffeeMachine/waterJug/printer/fishTank), first-free-counter assignment in OfficeSpawnUtils.roll with
   floor overflow, `spotFrame` in OfficeServiceServer. Full TestEZ 2,227 passed / 0 failed (incl. 50-seed
   generated-layout counter specs). Live Play: fishTank greed + coffeeMachine spawned base-flush on
   counter tops (3.00) with production art.
4. Sparse procedural furniture: corner cabinets + a couple of side tables via `OfficeLayoutGenerationUtils`
   markers (existing Utils, parent-approved edit pattern) + build paths in `OfficeBuildSystem` (existing
   System, `artOnly`-style decor roots, filingCabinet/counter art). Layout data tweak in
   `OfficeLayoutConstants` + `OfficeLayoutRules` validation. No new module.
   DONE 2026-10-13: new "cabinet"/"table" marker kinds; CABINET_SIZE/TABLE_SIZE + SURFACE_ITEM_CLEAR;
   surfaceTopY/table/cabinet; policy table→{plaque,monitor}, cabinet→{plaque}; generalized takeSurface;
   validate() refuses crowded/overlapping surface furniture (also for counters — caught a REAL
   kitchen-counter/pile overlap, pile moved 146→139); authored markers (4 cabinets, 2 tables) +
   generated stores cabinet; decor builds art-only roots; plaque/monitor/table specs. Full TestEZ
   2,234 passed / 0 failed. Live Play: fishTank+coffeeMachine on counters, plaque on lobby cabinet,
   all base-flush with art. Screenshots: plaque on cabinet, monitor on meeting table.
5. Searched-state dressing: desks show a pulled drawer + dark cavity, lockers a hinged-open door + dark
   interior; applied on search completion, cleared on shift reset. Needs the new module below (event-driven
   visual lifecycle = Systems by the three-question test).
   DONE 2026-10-13: `Office > server > Systems > OfficeSearchedDressingSystem` (plan row above) +
   `searched: Signal<BasePart>` on CargoServiceServer (same seam as pileCleared/dustBagReady) +
   OfficeServiceServer wiring (connect in start, clear in reset). Locker front verified -Z by screenshot
   (vents/plate/handle). Screenshots: pulled drawer + cavity read clearly; door swung 65° with dark gap.
   Full TestEZ 2,238 passed / 0 failed. Gates: gates/office-placement.md (G1-G4 all evidenced).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Office | server | Systems | OfficeSearchedDressingSystem | Overlays open-state dressing on searched desks/lockers, clears on reset |

No new subfolder kind, no new role word, no second service — no approval needed. The system subscribes to
a `searched` signal on `CargoServiceServer` (Office→Cargo dependency already exists via `stockSearchable`;
no new dependency direction). If no signal slot fits, fall back to `OfficeServiceServer` polling
`getState` per shift end — decided during slice 5.

## Gates to update

- `gates/modular-art/map-integration.md` G3: chair/prop instance specs already cover bounds; add facing.
- New gate file `gates/office-placement.md` (G1 chairs face desks, G2 appliances/loot on surfaces,
  G3 searched reads as searched, G4 layout reads as office) — evidence only from Studio screenshots.
