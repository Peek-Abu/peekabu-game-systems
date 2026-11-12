# Hub owner pass 2026-11-11 (round 2): gates

Owner's play-test notes, relayed by the coordinator. Each gate needs evidence: a measurement, a capture path (opened
with Read), or a command's output.

- [ ] G1 Time clock faces the room: the art's LookVector points at its readers in real Play.
  EVIDENCE: pending
- [ ] G2 No floating or see-through sign: every hub sign (clock sign, daily sheet, result board, contract board, crew
  wall, supply sign, bell sign, rank chart, training truck sign) has a wall or a solid back, checked from behind in Play.
  EVIDENCE: pending
- [ ] G3 Locker doors: nothing within 4 studs in front of the Gloom/Gleam doors; the doors read as special from 15
  studs (capture).
  EVIDENCE: pending
- [x] G4 Prop scan script: zero props buried (more than 25% of the box below the surface under it) and zero
  prop-vs-prop overlaps over 15% of the smaller box, across every prop in DepotHub.Dressing / Spots / Training /
  Yard. The script and its output are written down.
  EVIDENCE: PropScan.CommandBar.luau, Edit mode 2026-11-11 after the fixes: "props scanned: 139 / buried: 0 /
  clipping: 0 / blocking: 0". First pass found the owner's pumpkin sunk 61% into the coffee bar, goo under a pallet,
  two pumpkins in a pumpkin (43-46%), two training crates in each other (42%), leaf drifts into lockers (22%) and a hay
  bale (36%), and the picnic bench in front of the locker doors. Fixed: pumpkin lifted 0.86 onto the counter, goo moved
  5.6 off the pallet, pumpkins and crates spread, drifts moved, bench moved to the yard. Coffee corner capture shows the
  pumpkin on the counter.
- [x] G5 Walkway scan: no prop blocks an interactable's prompt spot (3 studs deep in front of each tagged
  interactable, as wide as it).
  EVIDENCE: same run, "blocking: 0". Caveat: the first version faced its zones along LookVector and missed the
  bench (the locker spots look into the wall); the bench was found by eye in the capture. The zone now uses the part's
  thin horizontal axis turned to the room.
- [ ] G6 Clerk in real Play: DepotClerkSystem in the client, SupplyClerk model present, stamp track playing, parcel
  present and hopping, wave on approach.
  EVIDENCE: pending
- [ ] G7 Coach Pippa alive: idle track playing, she waves on approach and on her own timer, her head turns toward the
  player (measured Neck C0 yaw), generic clips only.
  EVIDENCE: pending
- [ ] G8 Specs: DepotBoardVisualSystem, DepotBuildSystem, TrainingCoachRules specs pass in the Studio suite.
  EVIDENCE: pending
- [ ] G9 Gate: lint, format and typecheck clean (bash scripts/check.sh --skip-install), no new file over the limit.
  EVIDENCE: pending
- [ ] G10 Fresh-player walk-around: a capture from each area (yard entrance, trucks, left wall boards, lockers,
  break area, supply counter, training bay, storage racks), each opened with Read.
  EVIDENCE: pending
- [ ] G11 No Claude* temps left in the place; nothing saved.
  EVIDENCE: pending
