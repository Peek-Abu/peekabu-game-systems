# Odd Hours B1 exterior: look spike report (round 2, 2026-10-23)

`BuildExteriorSpike.CommandBar.luau` rebuilds `Workspace.ClaudeExteriorSpike` (Shift place, Edit, one undo step).
3,371 parts, 65 lights (round 1: 6,685 / 97). Saved Lighting unchanged. 0 parts in the keep-out (world x 961..1294,
z -52..203, y < 17); in Play the generated office overlaps nothing. Round 1 details: REPORT-round1.md.

## Truck and yard (tunable)
- `TRUCK_WALK_STUDS = 200` at the top of the script. Ramp foot z = dock block front (-64) - 200 = -264; truck pivot
  `CFrame.new(1168, 4, -276) * CFrame.Angles(0, math.pi, 0)`, back/ramp toward the building.
- Truck pad x 1144..1192, z -298..-254 (light concrete, yellow edges, 2 sodium poles). Access road 18 wide (z -285..-267)
  east through the gate (barrier, security booth). Fence x 836..1322, z -321..230, invisible 90-tall wall on the line.
- The walk: straight open asphalt, sodium poles 26 studs to the side at z -110/-160/-210, puddles, lit dock apron.

## Walks (PathfindingService, radius 1.5, 16 studs/s, doorways blocked)
| From | To | Studs | Seconds |
|---|---|---|---|
| Truck ramp foot | Dock door | 199.5 | 12.5 |
| Truck ramp foot | Lobby doors (round SW corner) | 531.9 | 33.2 |
| Dock door | Lobby doors | 444.8 | 27.8 |

## Cuts vs round 1
Pines 3 rows x 9 tiers -> 2 rows x 5 tiers; fence one mesh + rail per 20-stud span; puddle layers 3 -> 2; blind slats 1-3
-> 1-2; moon washes 45-stud top bands only; crown rims 3 -> 1 per crown; wall packs 14 -> 8; path lights 8 -> 4; pylon
relays and lobby fill removed. Extra sodium pole in the west car park near z 135 (12 poles total).

## Proposed "officeExterior" atmosphere preset (Play-only preview)
ClockTime 1.2, GeographicLatitude 70, Brightness 2.2, ExposureCompensation -0.1, Ambient 40,40,60, OutdoorAmbient
105,108,160, EnvironmentDiffuseScale 1, EnvironmentSpecularScale 1; Atmosphere Density 0.3, Offset 0.12, Color
112,100,168, Decay 72,52,124, Haze 2.2, Glare 0.35; Sky.MoonAngularSize 10. Result: violet night horizon, moon upper
right behind the towers from the yard, tower tops and grids read, yard readable between sodium pools.
- Presets: `src/ReplicatedStorage/Client/Features/Office/Data/OfficeAtmosphereConstants.luau` (PRESETS), registered by
  `OfficeAtmosphereSystem` via `VfxAtmosphereRegistry.register`; chosen by `OfficeAtmosphereUtils.preset(snapshot, userId)`
  (shift state only today, no location).
- Needs: an inside/outside input (camera or character outside the office footprint), a fade at the thresholds, maybe an
  overtime variant outside; `VfxTypes.Atmosphere` + VfxServiceClient read/write extended with latitude, environment
  scales, Atmosphere fields and MoonAngularSize; interior presets must set latitude back (or interior re-check).
- In-shift `officeNight` (Brightness 0.42, OutdoorAmbient 14,16,27) is darker than any capture: without the exterior
  preset the outside would look darker in play than shown.

## Caveats
Local lights render only near the camera (about 5 s to settle), so from the truck the towers read by preset light and lit
windows. Aerial shows bare baseplate past the trees (hidden from the ground). Dock door still opens on the void until the
generated bay exists. Anomalies/ooze not built (slots only). Cars are blockouts.

## Captures (round 2; PRESET = preset previewed client-side)
01_r2_concept_angle_truck_in_yard_PRESET.jpg, 01b_r2_concept_angle_close_truck_PRESET.jpg,
02_r2_walk_from_truck_ramp_PRESET.jpg, 02b_r2_walk_from_truck_ramp_CURRENT_LIGHTING.jpg,
03_r2_lobby_rotunda_from_west_carpark_PRESET.jpg, 04_r2_aerial_PRESET.jpg,
05_r2_from_dock_door_looking_out_at_truck_PRESET.jpg
