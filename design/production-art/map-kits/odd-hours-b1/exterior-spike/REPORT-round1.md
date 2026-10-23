# Odd Hours B1 exterior: look spike report (2026-10-23)

Built by `BuildExteriorSpike.CommandBar.luau` into `Workspace.ClaudeExteriorSpike` (Shift place, Edit, one undo step).
6,685 parts, 97 lights; Lighting untouched. 0 parts in the interior keep-out (world x 961..1294, z -52..203, y < 17);
the script checks this each run. No uploads (new MaterialVariants `OH_ExtStone` = Concrete + OH_Plaster maps at 22/tile,
`OH_ExtPanel` = Slate + OH_Ceiling maps at 14/tile).

## Built (world coordinates, front = -Z)
- Podium shell: 3-thick walls 2 studs outside the keep-out (W x 956..959, E 1296..1299, S z -57..-54, N 205..208), y 0..31,
  cornice to 32.5, roof slab y 27..28, opaque night-glass ribbon y 19.5..25.5. Openings: dock x 1161..1175 y 1..13;
  lobby z 145..159 y 1..14, each with a floor through to the keep-out face at y 1.
- Dock block x 1110..1230, z -64..-57, top y 24: 14x12 roller door (rolled up) at x 1168, guards, bumpers, canopy y 17,
  man-door facade with steps, utility cabinet and pipes, 3 dumpsters, cartons, bollards. Apron x 1104..1244, z -112..-64.
- Towers (12-stud storeys from y 28): TowerW x 1044..1138 z -26..96 top 166; Pylon x 1138..1198 z -36..10 top 180;
  TowerE x 1198..1284 z -18..110 top 150; TowerNW x 966..1040 z 112..196 top 130. Dark glass cores, stone fins about every
  7 studs, spandrels, corner piers, crowns, penthouses, red beacons; about 5-6% of bays warm-lit (Neon) with blind slats.
  Pylon: art-deco nested frames around a recessed panel.
- Lobby rotunda (west face, z 152): warm glass half-cylinder R 18, about 8 wide of open doors, stone canopy disc R 27 with
  lenses, 4 columns, oak feature wall, marble floor, two Neon ring lights, empty counter, blank welcome screen. Plaza with
  4 planters, topiaries, path lights, ramp, zebra crossing.
- Site: fence box x 836..1322, z -172..230 (see-through mesh, invisible 90-tall wall on the line). Front apron with
  13 stalls; 18-wide road z -160..-142 out through an east gate (boom barrier, security booth with dark TV); west car park
  with 18 stalls; sidewalk round the building; 2 blockout cars; 15 glossy puddles; about 330 stylised pines.
- Lights: sodium (255,170,90) vs moon (150,170,235). Poles 7 x spot 6/60/120 shadowed; 14 wall packs 4/32/95; dock floods
  4/55 shadowed, canopy spot 4/28; door spill (255,196,136) point 5/26 shadowed + spot 5/40 + apron pool 2/16; pylon
  uplights 8/60/26; facade washes (SurfaceLights on invisible panels: moon 0.8/36, sodium 0.5/34); crown rim spots 1.5/60;
  lobby (255,188,118) ring 3.5/30 shadowed, fill 2/22, plaza 1.6/18, canopy 1.8/24; path lights 1.1/9.

## Truck
Clone of `ReplicatedStorage.Assets.CleanupCrew.Truck` at `CFrame.new(1168, 4, -84) * CFrame.Angles(0, math.pi, 0)`,
back and ramp toward the door; ramp foot about z -72.

## Walks (PathfindingService, agent radius 1.5, 16 studs/s)
| From | To | Studs | Seconds |
|---|---|---|---|
| Truck ramp foot | Dock door outer face | 7 | 0.4 |
| Truck ramp foot | Interior threshold (z -52) | about 20 | 1.3 |
| Dock door | Lobby doors (round the SW corner) | 444.8 | 27.8 |

## Caveats
- Only the authored office built in Play, so the dock door shows a void (no bay behind it yet).
- Local lights render only near the camera, so the night aerial is from about 300 studs.
- The depot atmosphere overrides Lighting in Play; captures set the client back to the place's night values (not saved).
- Anomalies and Gloom ooze not built; only their slots (blank welcome screen, dark booth TV).
- Spec goal 1 says 15-30 s from truck to door; the truck is parked at the dock as the concept shows.

## Proposed Lighting / Sky (not applied)
1. Sky renders black in Play: Atmosphere Haze about 1.5-2, Color about (60,64,110), Decay about (40,36,80), Density about 0.3
   for a violet horizon, or an existing cloudy night skybox.
2. Moon overhead at ClockTime 0, latitude 0: ClockTime 21.5-22 with GeographicLatitude about 40 puts it low behind the
   towers (needs an interior re-check).
3. Preferred: an "office exterior" preset in the per-location atmosphere blend (VfxAtmosphereRegistry): OutdoorAmbient
   about (40,46,80), Brightness about 1, Exposure about -0.3; then halve the moon washes.

## Captures
01_concept_angle_dock_truck_towers.jpg, 01b_concept_angle_alt.jpg, 02_lobby_rotunda_from_west_carpark.jpg,
03_aerial_whole_set_night.jpg, 03b_aerial_layout_read_PLAYONLY_daylight.jpg, 04_from_open_dock_door_looking_out.jpg,
05_interior_check_no_exterior_parts.jpg
