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

## Anomaly slots
These names come from `src/ReplicatedStorage/Shared/Features/Office/Data/OfficeAnomalyConstants.luau`. The builder copies them at its top.

**How a client finds a slot:**
- Every slot is one Model named `AnomalySlot_<id>`.
- The Model carries the CollectionService tag `OfficeAnomalySlot` and the attribute `AnomalyId` = `<id>`.
- Find slots with `CollectionService:GetTagged("OfficeAnomalySlot")`, read `AnomalyId`, then work on the parts inside.
- The parts themselves are untagged.
- Each slot is built in its default, no-anomaly state. The client applies the anomaly and resets it to that state.

| `AnomalyId` | Where (under `OfficeExterior`) | Parts inside | Default state |
|---|---|---|---|
| `silhouette` | `AnomalySlot_silhouette` (folder `AnomalySlots`) | `FigureLegs`, `FigureBody`, `FigureHead` | Transparency 1. A flat, featureless dark figure about 2 × 6 studs standing in one lit tower window facing the yard: behind that window's clear glass pane (`SilhouetteWindowGlass`, outside the slot, always there) and in front of its room light (`WinLit`). Depth outward from the core face: light 0..0.12, figure 0.16..0.22, glass 0.28..0.32. That window has no blind slats. The window is the lowest lit one whose sill clears the podium's sight line from the yard (`SIGHTLINE_MIN_Y` = 40); its tower is in the Model attribute `Tower`. |
| `autoDoors` | `Lobby/AnomalySlot_autoDoors` | the two `LobbyDoorLeaf` | Closed. Each leaf has `Side` (-1/1) and `SlideStuds` (2.2). The open position is `leaf.CFrame + leaf.CFrame.RightVector * Side * SlideStuds`, which slides along the rotunda's tangent, away from the door centre. |
| `carTicking` | `AnomalySlot_carTicking` (folder `AnomalySlots`) | `Emitter` | An invisible, non-colliding part over the parked car's engine at world (914, 3.7, 35). Attach sound or particles here. |
| `welcomeScreen` | `Lobby/AnomalySlot_welcomeScreen` | `WelcomeScreen` | A dark display. Its `SurfaceGui` `Screen` (face Left, toward the rotunda) holds a TextLabel `Text` that is empty by default. |
| `boothTv` | `Fence/AnomalySlot_boothTv` | `BoothTV` | Dark (black SmoothPlastic). |
| `wetFloor` | `AnomalySlot_wetFloor` (folder `AnomalySlots`) | `SignFront`, `SignBack`, `SignHinge` | A yellow A-frame sign in the puddle at world (1174, -168), by the walk to the dock. The parts are Transparency 1 and the TextLabel `Text` ("CAUTION / WET FLOOR") is TextTransparency 1. Nothing collides. |
| `banner` | `AnomalySlot_banner` (folder `AnomalySlots`) | `BannerCloth`, `BannerRod`, `BannerBracket` ×2 | Visible and the right way up. It hangs on the podium front at x 1006..1056, y 8..13.5. The SurfaceGui text "TOGETHER WE THRIVE" sits on the cloth's Front face. |

## Rebuild
1. Open the Shift place in Edit.
2. Paste the whole script into the command bar and run it.
3. It builds the new set as `OfficeExterior_Building`, checks every part against the keep-out, and checks that each of the 7 anomaly slots exists exactly once.
   - **If either check fails:** the half-built set is removed, the recording is cancelled, and the build errors. The old set is left untouched.
   - **Otherwise:** it destroys the old `OfficeExterior` (and any leftover `ClaudeExteriorSpike`) and renames the new set.
   - All of this is one ChangeHistory step: Ctrl+Z undoes it.
4. It never touches Lighting. The outside look comes from the `officeExterior` atmosphere preset in code (`OfficeAtmosphereConstants`).
5. Never name the model `CleanupCrewOffice`. The code owns that name and rebuilds it every shift.

`captures/pc2_*.jpg` are Play checks with a generated office built. They use the `officeExterior` preset values applied on the client.
