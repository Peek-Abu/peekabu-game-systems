# Odd Hours B1: office exterior set

`BuildExterior.CommandBar.luau` builds `Workspace.OfficeExterior` in the Shift place. It is the fixed outside the crew walks through: the yard, the truck pad, the dock door, the lobby rotunda and the car park, with the oversized HQ towers behind them.

It is Studio art: the parts live in the place, and only the script is in git. The set came from the approved look spike (`../exterior-spike/`, round 2).

## Where it sits
The set wraps the generated office again, with `EXTERIOR_OFFSET` = 0. The entrances are short teleport hops, handled by code in `OfficeEntranceSystem`.

## What it builds
- **Closed podium.**
  - Its inner faces stand 2 studs outside the interior keep-out (world x 961..1294, z -52..203, y < 17).
  - The roof slab sits at y 27, above the generated rooms.
  - The gap between the podium and the rooms is sealed from outside: solid walls, a roof, no openings, and opaque night-glass windows.
- **Dock.** The roller door is rolled down, with a warm strip of light under it; the code's ooze seeps out there.
- **Lobby.** The rotunda has closed glass doors with lit lobby dressing behind them. This is exterior art, not the generated reception.
- **Towers.** Three glass towers and a stone deco pylon, rising to y 180.
- **Yard and access.**
  - An open yard of about 200 studs, with sodium poles along the walk.
  - A lit truck pad and an access road through a gated fence.
  - The car park and lobby plaza on the west side.
  - A fence, a treeline and an invisible wall around the edge.
- **No truck.** The code builds the truck at `TRUCK_CENTRE`; only its pad is art.
- **Budget.** About 3,350 parts and 63 lights (limits: ≤ 4,500 parts, ≤ 70 lights).

## Numbers shared with code
These come from `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau` (`OUTSIDE`, layout space, world = layout + `ORIGIN` (1000, 1, 0)). The script copies them at its top and asserts that the art lines up.

| Constant | Layout value | World position of the art |
|---|---|---|
| `EXTERIOR_OFFSET` | (0, 0, 0) | |
| `DOCK_OUTSIDE` | (168, -64) | roller door centre and front face (1168, -64), 14 wide (`DOCK_DOOR_WIDTH`) |
| `LOBBY_OUTSIDE` | (-62, 152) | rotunda door pair centre (938, 152) |
| `TRUCK_CENTRE` | (168, -276) | truck pad centre (1168, -276) |
| `yard` / `carpark` | | the fence line: x 836..1322, z -321..230 |

Arrival points (5 studs out from each door) stand on flush ground: dock (1168, -69) at y 1.04, lobby (933, 152) at y 1.36.

## Rebuild
1. Open the Shift place in Edit.
2. Paste the whole script into the command bar and run it.
3. It builds the new set as `OfficeExterior_Building` and checks every part against the keep-out.
   - **If any part is inside the keep-out:** the half-built set is removed, the recording is cancelled, and the build errors. The old set is left untouched.
   - **Otherwise:** it destroys the old `OfficeExterior` (and any leftover `ClaudeExteriorSpike`) and renames the new set.
   - All of this is one ChangeHistory step: Ctrl+Z undoes it.
4. It never touches Lighting. The outside look comes from the `officeExterior` atmosphere preset in code (`OfficeAtmosphereConstants`).
5. Never name the model `CleanupCrewOffice`. The code owns that name and rebuilds it every shift.

`captures/pc2_*.jpg` are Play checks with a generated office built. They use the `officeExterior` preset values applied on the client.
