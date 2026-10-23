# Office map stage 3 (the outside): Studio verification and measurements

Task 9 of `docs/superpowers/plans/2026-10-23-odd-hours-office-map-stage3-outside.md`. Code at HEAD `dee97022`.
Studio window "Odd Hours: Shift", 2026-10-23.

## How it was run

- **Suite:** `RunTests = true`, Play, then RunTests cleared to nil.
- **Real shifts:** a plain Play in the Shift place runs a real shift.
  - The solo player became crew and arrived on the yard truck. The shift reached `running` (shift 1, variant B, quota 640).
  - I ran three shifts in a row:
    - shift 1 ended by timeout (Harlow caught me 3 times inside);
    - shift 2 ended by my TimeClock clock-out;
    - shift 3 ran P7, the dock captures and the traversal harness.
- **Drivers:**
  - The real Interact path: the client presses the shift prompt with `ProximityPrompt:InputHoldBegin/End`. The prompt only arms when the camera is aimed at it within 8 studs (ShiftPromptSystem).
  - Server-side Scripts injected into ServerScriptService, so they share the game's module instances. Command-bar requires get fresh, unstarted copies, so they were not used for that.
  - A Heartbeat watcher counted root jumps over 50 studs (teleports).
- **Lock:** `studio-playtest-shift.lock` was created before Play and deleted after.
  - RunTests is nil in Edit.
  - The temporary probe folders went with Play.
  - Edit still has `Workspace.OfficeExterior`, and no `ClaudeExteriorSpike`.

## Probes

| Probe | Result |
|---|---|
| P1 | **PASS**: suite 4436/0; traversal seeds 1-20, doors closed: 957 paths, 0 failures |
| P2 | **PASS**: no Harlow path to the pad; the yard and car park are in his zone |
| P3 | **Spawn PASS; walk to dock MARGINAL** (217-221 studs vs 190-215); dock → lobby PASS (431-435) |
| P4 | **PASS**: enter/leave at the dock and lobby, carried item travels, 5 rapid Enters give 1 teleport |
| P5 | **PASS**: `whereIs` gives Yard / Car park; aboard true on the bed and false 3 studs off; the TimeClock clock-out works |
| P6 | **PASS**: none / little / lot at 900 / 1100 / 1400; the ooze sits on the pad in front of the closed door |
| P7 | **PASS**: the Lighting really changes outdoors (open item from Task 6 closed); the overtime tint was not seen live |
| P8 | **Done, with one gap**: 6 new captures. The dock-room inside renders black in the capture tool. Its exit was checked numerically instead |

### P1: suite and traversal (PASS)
- Suite: `Tests: 4436 passed, 0 failed, 4436 total`.
- Traversal harness, Server in Play, `run({1..20}, CFrame.new(5000,1,5000))`, doors closed: **paths 957, failures 0**.
- No server errors or warnings came from game code during the session. The only error was my own probe's typo.
- The client logged one warning: `[ShiftTransitSystem] the transit screen timed out waiting for "placed"; revealing anyway`, once, on the first arrival. The crew still landed and the shift ran.

### P2: Harlow and the yard (PASS)
- **Bay patrol point:** route point #2 at (1178, 1, -31), in the loading bay.
- **Path from the bay point to the pad centre (1168, 4, -1876):** I called `PathfindingService:CreatePath({AgentCanJump = true, Costs = {[SAFE_ZONE_LABEL] = math.huge}})`. These are the same parameters as NpcMoverSystem and Harlow's `pathCosts`.
  - Result: **NoPath**.
  - Without costs it is also NoPath, because the exterior is 1,600 studs apart and has no walkable link.
- **The costs on their own:** from the dock's outside frame to the pad:
  - with Harlow's costs: **NoPath**;
  - with no costs: Success, 53 waypoints.

  So the Outdoors SafeZone modifiers do block him on their own.
- **inZone:** I built Harlow's zone with `OccupantSenseSystem.layout(route)` (2 extra boxes).
  - The player standing on the truck bed is `inZone = true`.
  - So are (1168, 4, -1700) in the yard, (1100, 4, -1800) in the yard and (900, 4, -1500) in the car park.
  - The bay patrol point is false.

### P3: spawn and walk distances (spawn PASS; walk to dock MARGINAL)
- **Spawn:** `spawnCFrame(1..4)` = (1170.75 / 1165.25, 7, -1876 / -1880).
  - LookVector is (0, 0, 1), facing +Z toward the building.
  - The player landed at (1170.75, 5.43, -1876), on the yard truck bed.
- **Pathfinding lengths** (default agent, radius 2, height 5, can jump):

| Walk | Length | Time at 16 studs/s | Straight line | Target |
|---|---|---|---|---|
| Spawn 1 → dock hit box (1168, 6, -1664) | **216.9 studs** | **13.6 s** | 212 | 190-215 |
| Spawn 2 → dock hit box | 220.5 studs | 13.8 s | | 190-215 |
| Dock hit box → lobby hit box (938, 6, -1448) | **435.4 studs** | **27.2 s** | 315.5 | 420-470 |
| Dock outside frame → lobby outside frame | 431.4 studs | 27.0 s | | 420-470 |

- The walk to the dock is 2-6 studs over the brief's band. Measured to the hit box *centre*, it is just past 215.
- The prompt arms within 8 studs (ENTRANCE_REACH 10, client cap 8), so the walk you actually make to press Enter is about 209-213 studs (13.1-13.3 s).
- Not a code bug: the truck pad and the door are fixed by the approved exterior (TRUCK_CENTRE z -1876, door z -1664: 212 straight).

### P4: entrances (PASS)
Each row is a real prompt press. The positions are root positions.

| Action | Landed at | Expected |
|---|---|---|
| Enter at dock (from 1168, -1671) | (1168, 2.37, -48), look +Z | inside frame (1168, 1, -48), look +Z |
| Leave at dock exit (carrying a Monitor) | (1168, 2.41, -1669), look -Z; Monitor at (1168.0, 2.3, -1671.1), 2 studs ahead | outside frame (1168, 1, -1669), look -Z |
| Enter at lobby (still carrying) | (966, 2.37, 152), look +X; Monitor at (968.1, 2.3, 152.0) | inside frame (966, 1, 152), look +X |
| Leave at lobby exit | (933, 2.73, -1448), look -X | outside frame (933, 1, -1448), look -X |
| 5 rapid Enter presses at the lobby (frame waits, 0.03 s apart) | watcher teleport count 5 → **6: exactly 1 teleport** | 1 |

- The carried item travels welded to the character on both legs (dock Leave, lobby Enter).
- The prompt-press probe can't tell how many of the 5 presses reached the server; the engine may swallow some once the prompt hides. Either way, the result is 1 teleport.
- The lobby has two glass leaves. The client arms the one it picks (`Exit_lobby_2` here). Both are tagged, as Task 3 intended.
- Seen while carrying: twice, the character drifted several studs (+Z in the dock room, +X in reception) while holding the Monitor and standing still. It was probably the carried object's physics against the character, or my camera override. This is not stage 3 code, and I could not attribute it, so it is left for the play-check.

### P5: whereIs, aboard and the TimeClock (PASS)
- `whereIs`:
  - the player on the bed → `"Yard", 0, nil`;
  - (1168, -1700) and (1100, -1800) → `Yard`;
  - (900, -1500) and (900, -1400) → `Car park`.
  - `outdoors()`: yard (836, 1, -1921)..(1322, 121, -1657); car park (836, 1, -1657)..(956, 121, -1370).
- **Aboard** (`ShiftClockOutRules.aboard` with the real `safeZone()` = (1162, 4, -1884)..(1174, 12.7, -1868)):

| Point | Aboard |
|---|---|
| Player on the bed | **true** |
| Bed centre | true |
| 0.5 in from the open back | true |
| 3 studs behind the open back (z -1865) | **false** |
| 3 studs off the +X side | **false** |
| 3 studs past the cab end | **false** |

- **TimeClock:** the prompt reads "Clock out" (range 7, hold 1.5). Pressing it on the bed ended the solo shift: phase `results`, outcome `clockout`.

### P6: the ooze (PASS)
`OfficeOozeSystem.buildAtDock` at the real dock entrance (168, -1664, yaw 0), ORIGIN (1000, 1, 0):

| Gloom | Level | Parts | Extent |
|---|---|---|---|
| 900 | none | 0 (nil) | |
| 1100 | little | 2 | y 1.000..1.112; x 1163.9..1171.3; z -1667.4..-1664.0 |
| 1400 | lot | 6 puddles + 3 streaks | y 1.000..3.200; x 1161..1175 (the 14-wide door); z -1674..-1664 |

- **Ground check (open item from Task 7):**
  - The DockPad top is y 1.04 from z -1664.5 to -1674.
  - The puddles are 0.1-thick discs centred at y 1.05-1.09. Their tops (1.100 / 1.112 / 1.124 / 1.136) stand 0.06-0.10 above the pad, and their lower halves are buried 0.04 in it.
  - So they sit on the ground: neither floating nor hidden.
  - The y=0 layout-space assumption holds, give or take 0.04.
- **Door check:**
  - The roller curtain (`OfficeExterior.Dock.RollerCurtain`, 0.4 thick) has its front face exactly at z -1664.000. Its bottom is at y 1.35, with the warm gap strip under it.
  - The streaks sit at z -1664.25..-1664.15, in front of the face and not inside it.
  - The "leaf < 0.2 thick" worry doesn't apply: the door frame is the curtain's front face, not its centre.
- This shift's own roll was "none" (site Gloom under 985).
- **Look:** see capture t9_03. The three streaks read as thin magenta posts standing on the spill rather than drips on the door. That is an art call for the owner, not a bug.

### P7: atmosphere (PASS; closes the Task 6 open item)
Client Lighting was read directly. The values match `OfficeAtmosphereConstants.PRESETS` exactly.

| Moment | Brightness | GeographicLatitude | ClockTime | Ambient / OutdoorAmbient | Atmosphere density / haze / glare | Moon | Preset |
|---|---|---|---|---|---|---|---|
| Yard, shift 3 | 2.2 | 70 | 1.2 | (40, 40, 60) / (105, 108, 160) | 0.30 / 2.2 / 0.35 | 10 | **officeExterior** |
| After Enter at dock | 0.42 | 0 | 0 | (26, 30, 46) / (14, 16, 27) | 0.28 / 0.6 / 0 (place base) | 11 | **officeNight** |
| After Leave at dock | 2.2 | 70 | 1.2 | as the yard | 0.30 / 2.2 | 10 | **officeExterior** |
| Reception, shift 1 (tier 2) → Leave lobby | 0.28 → 2.2 | 0 → 70 | | | 0.28/0.6 → 0.30/2.2 | | **officeTier2 → officeExterior** |

- **The Task 6 open item is closed.** The Vfx write path does write Lighting, its Atmosphere child and its Sky (MoonAngularSize) in a real shift, and it switches within the 2.5 s after each teleport.
- **Overtime tint outdoors:** not observed. No shift reached overtime in this session; that needs the quota met and the overtime sheet.
  - By the code it **stays on outdoors**: `OfficeAtmosphereSystem.setOvertime` (around line 130) is driven by `OfficeAtmosphereUtils.overtime(snapshot, userId)` alone, with no outdoors check. Outdoors, the red tint and saturation screen request would sit on top of `officeExteriorOvertime`.
  - It is a design call, not a bug: the plan's exterior-overtime preset is itself red. It is left for the owner's play-check.
- ColorCorrection TintColor stayed (248, 248, 250) throughout, which is the non-overtime base.

### P8: captures (DONE, with one gap)
In `design/production-art/map-kits/odd-hours-b1/exterior/captures/`. All are Play captures with in-shift lighting and the HUD showing.

| Capture | What it shows |
|---|---|
| `t9_01_arrival_truck_bed_looking_at_building.jpg` | arrival, from the truck box out of the open back toward the dock block |
| `t9_01b_truck_on_pad_ramp_toward_building.jpg` | the code-built truck standing on the pad, ramp down toward +Z (the building) |
| `t9_02_walk_truck_to_dock.jpg` | the walk: mid-yard, looking at the dock door and the office tower |
| `t9_03_dock_door_ooze_lot.jpg` | the closed roller door with the "lot" ooze (forced Gloom 1400) |
| `t9_04_lobby_doors_from_carpark.jpg` | the rotunda's lobby doors from the car park |
| `t9_06_reception_exit_doors.jpg` | inside the reception: the double glass exit, oak casing, EXIT sign |
| `t8_01..03_*_PRESET.jpg` | Task 8's captures, moved here from `exterior-spike/` |

- **The gap: the dock room (loading bay) from inside.** Four attempts came out black, apart from the troffers and the EXIT sign text. This is the capture tool's known dim mode (see `reports/office-spike-match-measure.md`). The 13 lights within 25 studs of the exit were all enabled.
- Instead, the dock exit's parts were checked numerically:
  - Wall room face: z -51.5.
  - Leaf: -51.5..-51.2, 0.3 proud.
  - Casing jambs and head front: -51.15, 0.05 proud of the leaf.
  - EXIT sign front: -51.2, above the head (y 10.65+).
- **Z-fight check (open item from Task 3):** I scanned every pair of visible parts within 10 studs of each exit for coplanar overlapping faces.
  - The only hits are faces no one sees:
    - back faces glued to the wall: wainscot/skirt at -52.5, and jamb/head inside the slab at -52.0;
    - same-material wood mitres where a jamb meets the head.
  - The visible faces (wall, leaf, casing, sign) are 0.3 / 0.05 apart.
  - The reception capture shows clean casing and trim around the exit.
  - So there is **no z-fight** at either exit.

### Open items from earlier tasks
| From | Check | Outcome |
|---|---|---|
| Task 6 | Lighting really changes outdoors vs indoors | **Yes** (P7 numbers) |
| Task 6 | Overtime tint outdoors | Not observed live. The code keeps it on outdoors. Owner's call |
| Task 7 | Ooze on the ground in front of the closed door, not floating or buried | **Yes** (P6) |
| Task 8 | The code-built truck stands on the pad, ramp toward the building, in a real shift | **Yes** (see below) |
| Task 3 | `whereIs` gives Yard / Car park outdoors | **Yes** (P5) |
| Task 3 | No exit trim z-fight | **None** (P8) |

**The truck on the pad (Task 8):**
- `CleanupCrewOffice.Truck.TruckBed` is at (1168, 2.5, -1876), size 12×3×16, LookVector +Z.
- TruckArt spans y 0.79..12.70, z -1890.9..-1863.8. The TruckPad top is y 1.05 under the whole bed.
- The bed bottom is at 1.00, 0.05 into the pad, and the wheels are about 0.26 into the pad: unnoticeable.
- Capture t9_01b shows it.

## Banking walk (Step 2: a note for the owner; nothing retuned)
- Banking happens at the truck in the yard. Each banking trip now goes dock exit → teleport → yard → truck, and back.
- From P3, the walk is 217 studs = **13.6 s each way**: about 13.1 s once the 8-stud prompt reach is counted.
- Each teleport adds a 0.5 s fade (0.2 out, 0.3 in).
- **Per trip:** about 2 × 13.6 + 2 × 0.5 ≈ **28 s**. The plan estimated 2 × 12.5 = 25 s.
- **6 trips per shift:** about **2 min 48 s** (6 × 28 s), which is 33% of the 8:30 (510 s) shift. That is on top of the walk inside the office to the dock room.
  - Stage 1 measured no trip count, so 6 is the brief's default.
- A crew that banks each valuable as it is cleaned spends a third of the shift crossing the yard. The trip count and the time cost are the owner's to weigh after the play-check.
- **The quota (contract 640-690 seen) and the shift length (510 s) are unchanged, as the brief requires.**

## Left for the owner's play-check
- The overtime look outdoors: red tint plus officeExteriorOvertime.
- The dock room's look from inside: the capture tool rendered it black.
- The feel of the 13.6 s yard walk per leg.
- Whether the carry drift seen in P4 happens with normal input.
- The ooze streak look.
- The roller door's loud CorrodedMetal and the hedge speckle (Task 8's art notes).
