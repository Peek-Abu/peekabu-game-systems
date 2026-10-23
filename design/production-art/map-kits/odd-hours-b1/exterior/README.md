# Odd Hours B1: office exterior set

`BuildExterior.CommandBar.luau` builds `Workspace.OfficeExterior` in the Shift place. It is the fixed outside the crew walks through: the yard, the truck pad, the dock door, the lobby rotunda and the car park, with the oversized HQ towers behind them.

It is Studio art: the parts live in the place, and only the script is in git. The set came from the approved look spike (`../exterior-spike/`, round 2).

## What it builds
- **Closed podium.** A dock block whose roller door is rolled down, with a warm strip of light under it. The lobby rotunda has closed glass doors with lit lobby dressing behind them.
  - There are no openings into the podium.
  - The entrances are teleports, handled by code (`OfficeEntranceSystem`).
- **Towers.** Three glass towers and a stone deco pylon, rising to y 180. About 5% of their windows are lit, with blind slats.
- **Yard, truck pad and access.** An open yard of about 200 studs, with sodium poles along the walk. The truck pad is lit; an access road runs east through a gated fence.
- **West side.** A car park and the lobby plaza.
- **Boundary.** A fence, a treeline and an invisible wall.
- **No truck.** The code builds the truck at `TRUCK_CENTRE`; only its pad is art.
- **Budget.** About 3,350 parts and 63 lights (limits: ≤ 4,500 parts, ≤ 70 lights).

## Numbers shared with code
These come from `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau` (`OUTSIDE`, layout space, world = layout + `ORIGIN` (1000, 1, 0)). The script copies them at its top and asserts that the art lines up.

| Constant | Layout value | World position of the art |
|---|---|---|
| `EXTERIOR_OFFSET` | (0, 0, -1600) | every part is built in spike space, then shifted by this |
| `DOCK_OUTSIDE` | (168, -1664) | roller door centre and front face (1168, -1664), 14 wide (`DOCK_DOOR_WIDTH`) |
| `LOBBY_OUTSIDE` | (-62, -1448) | rotunda door pair centre (938, -1448) |
| `TRUCK_CENTRE` | (168, -1876) | truck pad centre (1168, -1876) |
| `yard` / `carpark` | | the fence line: x 836..1322, z -1921..-1370 |

Arrival points (5 studs out from each door) stand on flush ground at y ≈ 1: dock (1168, -1669) at 1.04, lobby (933, -1448) at 1.36. If a constant changes, edit the copy at the top of the script and rebuild.

## Rebuild
1. Open the Shift place in Edit.
2. Paste the whole script into the command bar and run it.
3. It deletes and rebuilds `Workspace.OfficeExterior`, and removes the old `Workspace.ClaudeExteriorSpike`, in one ChangeHistory step: Ctrl+Z undoes all of it.
4. It never touches Lighting. The outside look comes from the `officeExterior` atmosphere preset in code (`OfficeAtmosphereConstants`).
5. Never name the model `CleanupCrewOffice`. The code owns that name and rebuilds it every shift.
