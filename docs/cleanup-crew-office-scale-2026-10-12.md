# Cleanup Crew office scale-up — hallway spine + zones (2026-10-12)

Response to the original request: rooms feel small, no hallways, buildings read tiny, furniture sits where no office would put it. Reference moods: `design/production-art/concepts/office-lived-a-*` (bullpen furnishing language) and `office-corridor-b-*` (hallway language: wood doors, frosted glass, plates, cart, EXIT).

## Scale anchors (1 stud ≈ one Blender unit ≈ 0.34 m; R15 is ~5 studs)

- Corridors: 6 wide (real 2 m halls), never the current 12–16 slab. Loop them so Harlow can circle and players are never cornered.
- Room doors off hallways: 4 wide single doors with frosted-glass panel + plate; 8-wide double doors only for the loading bay and the archive.
- Rooms keep real footprints: bullpen 30×26, meeting 22×18, kitchenette 16×14, storage 18×14, accounts 20×16. Current wing boxes (~24–32 × ~22) are not far off in meters — the smallness is emptiness + door soup, not footprint.
- Ceilings stay at the current build height; add soffit bands + hanging EXIT/teal trim so halls read lower and rooms read taller.

## Layout v2 (OfficeLayoutGenerationUtils, spec-first)

1. Keep the 7-room authored core + spawns + rest point byte-stable (spawn guarantees, Harlow patrol base, quota pacing all assume them).
2. Replace the single service corridor with a hallway LOOP: spine hall along the wing + two cross-halls forming a rectangle. Hall width 6, door width 4 (8 at bay/archive).
3. Rooms open off the loop only (no room-to-room doors except storage↔supply). Each room gets one zone kind: `bullpen | meeting | kitchenette | storage | accounts | training`.
4. Determinism: same seed contract (seed → identical layout), connectivity validation extended to halls (every room reachable from the archive through hall doors), 30-seed spec stays green, live pathfind spot-checks per seed class.

## Zoning (OfficeBuildSystem + OfficeDeskVisualSystem, new markers)

- `bullpen`: 2×3 desk clusters (monitor + keyboard + mug + paper per desk), task chairs, locker bank on one wall, cork board with work orders.
- `meeting`: long table + 6 chairs, whiteboard, credenza, ceiling projector box.
- `kitchenette`: counter run, fridge, round table + 3 stools, wall clock, notice board.
- `storage`: shelf rows with labeled boxes, salvage staging (cargo spawns stay on existing item markers).
- `accounts`/`training`: desk pairs + filing cabinets + plants.
- New marker kinds: `deskCluster`, `meetingTable`, `shelfRow`, `counterRun`, `plantSpot`, `boardSpot`. Existing pile/item/desk/patrol markers keep positions relative to the new room rects; patrol route extends through hall midpoints so Harlow uses the loop.

## Rollout (code order)

1. Types + `OfficeLayoutGenerationUtils` v2 (rooms, hall loop, doors) with specs; keep v1 generator until the build system migrates.
2. `OfficeBuildSystem` hall construction (floor runner, trim, ceiling panels, EXIT signs, door frames + frosted panels + plates).
3. `OfficeDeskVisualSystem` zone kits behind the new markers.
4. Seed-matrix validation (30 logical seeds), two live seeds pathfound, quota/Harlow pacing review (bigger map = longer rotations; may need +1 patrol marker per hall).
5. Live full-loop screenshot pass (bullpen, hall, kitchenette) before any upload.

## Non-goals

- No restroom interiors, no elevator shafts, no second floor (sightlines + pathfinding cost).
- No furniture physics: all dressing noncolliding/nonquery except explicit low counters; cargo collisions unchanged.
- Authored hero meshes (truck B, vacuum pick) import separately; this spec only needs their footprints (bed 12×16, vacuum tool bounds) which are unchanged.
