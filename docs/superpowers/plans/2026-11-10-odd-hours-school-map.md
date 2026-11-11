# Odd Hours: School map (procedural) — implementation plan

Owner decisions (2026-11-10, via the coordinator):
- The School is generated every shift, like the Office.
- It lives in the Shift place; there is no new place.
- The host picks OFFICE or SCHOOL on the truck's START panel.
- The threat is The Substitute (he freezes while watched). His behaviour spec and model wait on the owner's OK.

Pitch material is in the notes folder: `school-map-plan-v2-2026-11-10.md`, `substitute-behaviour-spec-2026-11-10.md`,
the seeds/kits sheets, and the Python prototype `school-gen-prototype-2026-11-10.py`.

## Approach
The School generator outputs the Office's own `OfficeTypes.Layout`, so everything that already consumes a layout keeps
working unchanged:
- `OfficeBuildSystem` (shell, doors, furniture proxies and art);
- `OfficeSpawnUtils` (Gloom, treasure, searchables);
- Hide (via `HideFurniture`);
- the Occupant route and rest;
- lighting, dressing and the walk/hide/route checks.

`OfficeServiceServer:beginShift` gains a `map` option, and its `rebuild` picks the generator by map.

Generator (mirrors the prototype):
1. **Lattice:** a 4×3 lattice of junctions (School steps, wider than the Office's so a landmark block fits a gym).
2. **Landmark blocks:** gym and cafeteria always, library 70%. Each fills a block whose 4 surrounding halls are forced
   in. Its kit sits in the block with doors on 2–4 sides.
3. **Spine and halls:** a spine from the front node straight back, then random extra edges to 10–13 total, joined
   until connected. Dead-end stubs that serve no room are pruned.
4. **Classroom blocks:** each other block splits into a 2×2 of rooms, each facing a drawn hall. A deck deals the
   principal, nurse, lounge, bathrooms ×2, art, music and janitor once each; the rest are classrooms.
5. **Wall band:** rooms 30 deep outside the edge halls.
6. **Hall dressing:** main halls get locker banks every 28 studs (`locker` markers, searchable plus hide-in) and the
   hall dressing (trophy case, art frames).
7. **Front hall:** the start room, standing in for the Office's loading bay. The truck and yard reuse the Office's
   grounds/teleport entrance for now (the dock door leads to the front hall). A school-front exterior set is a later
   art stage.
8. **Patrol and rest:** the patrol route is the Office's DFS route over the new doors. Rest is the teachers' lounge.

The layout checks are the Office's: validate, capacity, route, hide spots ≥ 8, and a walk ≤ 40 s.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| School | server | Data | SchoolConstants | lattice steps, deck, block odds, locker spacing, room sizes |
| School | server | Data | SchoolKitRegistry | the school room kits (OfficeTypes.Kit): classrooms, gym, cafeteria, library, small rooms |
| School | server | Utils | SchoolNetworkUtils | the hall network: lattice, forced landmark blocks, spine, extra edges, pruning (pure) |
| School | server | Utils | SchoolLayoutGenerationUtils | a full School `Layout` from a seed (pure; first of N attempts that passes Office's checks) |
| Shift | shared | Data | (edit) ShiftTypes | adds `MapId = "office" \| "school"` |
| Depot | server | State | DepotMapTracker | which map each truck pad's host picked (cleared when the party leaves) |
| Depot | shared | Rules | DepotMapRules | who may pick (the pad's host only) and which ids are valid |

Edits (no new modules):
- `OfficeTypes.RoomType` gains `classroom | gym | cafeteria | library | nurse | principal | lounge | bathroom |
  janitor | fronthall`.
- `OfficeLightingUtils`, `OfficeShellVisualSystem` (floors), `OfficeVariationRules` and `OfficeKitRules` (rest in the
  lounge) get entries for those types.
- `OfficeServiceServer` adds the `map` option on `beginShift` and a `map()` accessor.
- `ShiftSiteSystem` passes the map.
- `DepotServiceServer` handles the pick packet and puts the map in the depart data.
- The Depot client START panel shows the cards.
- `Shift` reads `payload.map` on arrival (as a display-only payload, ignored unless valid).

The Substitute's modules are listed in their own plan once the owner OKs the behaviour spec.

## Tasks (spec-first; each spec written and failing before its module)
1. `SchoolConstants`, plus the `SchoolKitRegistry` spec and registry. Every kit passes `OfficeKitRules`. Hide tables
   use the Office's 1.65× desk/table sizes (HUG_FREE_MIN holds).
2. `SchoolNetworkUtils` spec and module:
   - every landmark block has 4 halls;
   - connected;
   - no dead-end stub without a room;
   - seed-stable.
3. `SchoolLayoutGenerationUtils` spec and module, over 50 seeds:
   - the layout validates;
   - gym ×1, cafeteria ×1, library ≤ 1, lounge ×1 (rest), ≥ 6 classrooms;
   - hide spots ≥ 8;
   - walk ≤ 40 s;
   - a route exists.
4. `OfficeTypes` and the room-type tables, plus the `OfficeServiceServer` `map` option, with specs updated.
5. Shift and Depot: the map pick. `DepotMapRules`/`DepotMapTracker` specs; the packet; the depart data; arrival reads
   it; `ShiftSiteSystem` passes it on.
6. Client: OFFICE/SCHOOL cards on the START panel (host can tap, others see). Built with the game-ui-design skill.
7. Studio (slot from the coordinator):
   - the suite;
   - the traversal harness on School seeds;
   - a real Play of a School shift with 2 clients, hiding and a chase (Harlow until the Substitute exists).

   Owner play-check.
8. The Substitute (separate plan), then the school art kit and lighting.
