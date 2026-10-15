# Jump, loading visuals and room connections — verification

## Implemented

- Truck loading effects assemble the actual cargo art from its kit, proxy dimensions and rotation. The server snapshots visual identity before deleting a banked item, including pocket deposits. Client ghosts scale and move independently; source assets stay unchanged and delayed effects are invalidated on stop/restart.
- Harlow paths to the supporting surface beneath the observed target rather than an airborne root position. His acquisition cone is horizontal while sight range remains three-dimensional and line of sight is still checked against actual geometry. Catching uses horizontal range and reachable body height, with a fresh server-side wall check, safe-zone and grace checks. Default NPC attack behaviour is unchanged unless its intent opts into vertical reach.
- Doorway art uses narrow trim on both faces instead of enlarging the old wall-panel model. Wall endcaps stop at the opening edges, preserving the full ten-stud physical aperture. Source art is preserved.
- Work rooms are 30–40 by 28–38 studs, with different size pairs across each map. The seeded graph mixes actual shared-wall connections and corridors, retaining 16–24 work rooms, loops, four possible loading-bay sides and reserved furniture/door approaches.

## Native Studio evidence

Fresh TestEZ session: **2,328 passed, 0 failed**. Tests ran separately from normal gameplay.

Real truck drop: recycling box pickup and drop both succeeded; the source item was banked and destroyed. Client observed a CargoSwoop containing the real MeshPart (Cube.298), hidden proxy (Transparency 1), and automatic cleanup within the one-second observation window. HUD clearance became 15/350.

Held-jump pursuit in a real generated office: two successive physics jumps; Harlow entered chase, maintained approximately 17–20 studs/second while pursuing, and entered catch at 0.95 seconds with the player airborne, root Y 10.98 and horizontal gap 3.17. No chase stop was observed before the catch. This is a controlled short pursuit, not a certification of every possible obstacle or network condition.

Native sensing control: an opaque wall blocked sight; removing that wall restored sight. The same reach rule used by catch rejected the separate-height control.

Native PathfindingService, radius 2 / height 8 / jumping disabled, on every non-bay connected-room edge:

| Seed | Bay side | Work rooms | Corridors | Direct work-room links | Paths passed |
|---|---|---:|---:|---:|---:|
| 1 | East | 24 | 12 | 15 | 39 |
| 4 | North | 18 | 2 | 18 | 22 |
| 5 | South | 21 | 3 | 22 | 28 |
| 11 | West | 21 | 10 | 15 | 35 |

All **124/124** paths passed in isolated generated geometry. The live dressed map, seed 867032862, additionally passed **36/36** paths. Both faces of its work23/work24 opening were inspected in native rendered captures: narrow trim, no oversized side-panel pillars, and a clear opening. Temporary navigation maps were destroyed by their probes; all remaining play-only probes disappeared when play stopped.

## Static checks

Whole-source Selene: 0 errors/warnings/parse errors. StyLua check clean. Luau-LSP strict analysis clean. All first-party files satisfy the code-line cap. Module map current; PR rules against origin/main pass with zero warnings. Package links were not regenerated during Rojo sync.

## Selective door proposal

Use doors to communicate room purpose and create readable chase choices:

- Keep most bullpen connections and corridor junctions open.
- Add single doors to meeting rooms, records rooms and private offices; reserve wider double doors for occasional storage or service rooms.
- Place a door only where its entire swing has a reserved clear footprint. Swing toward the room interior and away from wall-side furniture; use appropriate handed variants.
- Let players open doors quickly and let Harlow operate them too. A closed door can interrupt sight briefly but must not permanently defeat navigation. Audible opening/closing should warn both parties.
- Start without keys, random locked routes or mandatory door spam. Confirm routes remain reachable with every selected door closed before enabling this in a shift.

These interactive doors are proposed, not implemented in this pass. Door state, collision, path planning, animations and multiplayer authority should be implemented together.

## Remaining scope

Continue the separate asset backlog (printer, recycling contents, fish-tank replacement, dust-bag badge and general prop polish), broader multiplayer/mobile playtests, procedural room-purpose dressing and pacing, sound/vacuum-noise response, and progression/retention validation with public testers. No asset upload or game publishing occurred.
