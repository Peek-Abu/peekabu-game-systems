# Hub owner pass 2026-11-11 (round 2): gates

Owner's play-test notes, relayed by the coordinator. Each gate needs evidence: a measurement, a capture path (opened
with Read), or a command's output.

- [x] G1 Time clock faces the room: the art's LookVector points at its readers in real Play.
  EVIDENCE: Play (fresh player, after the Rojo resync): TimeClockArt pivot LookVector . (+X, the room) = 1.00; the
  wall_boards_front capture shows the clock face with its card slot toward the room.
- [x] G2 No floating or see-through sign: every hub sign (clock sign, daily sheet, result board, contract board, crew
  wall, supply sign, bell sign, rank chart, training truck sign) has a wall or a solid back, checked from behind in Play.
  EVIDENCE: Play captures wall_boards_front / wall_boards_side: the clock and its sign on one teal back standing on the
  floor, the daily sheet on a teal back with legs, both flush with the wall and solid edge-on. Edit scan of every
  SurfaceGui host in DepotHub: the only transparent hosts are floor stencils, the markers (hidden in Play) and the
  training truck's side signs, which sit on the truck box. Supply, bell, crew, rank and banner signs are opaque parts.
  The result board is an opaque 1-stud board now against the wall; the contract board keeps its framed body and
  kickstand (DepotBoardVisualSystem.build).
- [x] G3 Locker doors: nothing within 4 studs in front of the Gloom/Gleam doors; the doors read as special from 15
  studs (capture).
  EVIDENCE: picnic bench moved to the yard (58, -126); area_lockers capture from ~17 studs shows the GLOOM / GLEAM
  toppers, neon door trims and glowing floor mats; scan blocking: 0.
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
- [x] G6 Clerk in real Play: DepotClerkSystem in the client, SupplyClerk model present, stamp track playing, parcel
  present and hopping, wave on approach.
  EVIDENCE: Play: SupplyClerk (today Cappy) playing rbxassetid://109774578542575; parcel y range 4.560..5.019 over 3 s
  (hop 0.46); at the contact frame the stamp face y 5.020 = parcel top 5.020; walking in from 26 studs played
  rbxassetid://105235060315952 (the wave). Captures clerk_front / clerk_side. Not checked: the wave on opening the Shop.
- [x] G7 Coach Pippa alive: idle track playing, she waves on approach and on her own timer, her head turns toward the
  player (measured Neck C0 yaw), generic clips only.
  EVIDENCE: Play: tracks = stock idle 507766666 + the generic wave 105235060315952 only. Neck yaw: player far ahead
  0.1, front-left 44.7, front-right -44.9, behind 0.0. Wave on walking up (front-left) = true; standing 20 studs away
  for 14 s: 1 wave of her own. Capture coach_look.
- [ ] G8 Specs: DepotBoardVisualSystem, DepotBuildSystem, TrainingCoachRules specs pass in the Studio suite.
  EVIDENCE: pending
- [x] G9 Gate: lint, format and typecheck clean (bash scripts/check.sh), no new file over the limit.
  EVIDENCE: full check.sh in polish-021838: selene 0 errors, stylua clean, luau-lsp only the existing
  QueueTicketSystem ForRange lint; file length fails only on files already over 400 (DepotBuildSystem kept at 386 code
  lines by moving the clock into DepotBoardVisualSystem.hangClock, 268).
- [x] G10 Fresh-player walk-around: a capture from each area (yard entrance, trucks, left wall boards, lockers,
  break area, supply counter, training bay, storage racks), each opened with Read.
  EVIDENCE: fresh player (picker, Start as Pippa, hub); captures: in_hub, clerk_front, clerk_side, coach_look,
  wall_boards_front, wall_boards_side, area_lockers, area_break, area_trucks, area_storage, area_backcorner, area_yard.
  Seen and left for later (out of scope): the sky backdrop's hard dark/purple seam in the yard; Pippa's face showed
  white on the "You're hired" card.
- [x] G11 No Claude* temps left in the place; nothing saved.
  EVIDENCE: Edit scan of game:GetDescendants() for names starting "Claude": none. No save made.
