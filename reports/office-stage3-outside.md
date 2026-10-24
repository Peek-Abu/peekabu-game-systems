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
| P3 | **Spawn PASS; walk to dock MARGINAL** (217-221 studs vs 190-215; just over the band, accepted inside the owner's 160-250 range, controller Ruling 5); dock → lobby PASS (431-435) |
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
- **Per trip:** about 2 × 13.6 + 2 × 0.5 ≈ **28 s**. This is the upper bound, using the full 217-stud walk; reach-adjusted (8-stud prompt reach) it is about 27 s. The plan estimated 2 × 12.5 = 25 s.
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
- The one-off client warning on the first arrival, "transit screen timed out waiting for placed" (revealed anyway; the crew landed): see whether it recurs.
- The roller door's loud CorrodedMetal and the hedge speckle (Task 8's art notes).

## Play-check 2 verification

Code at HEAD `35e20c0e`: the exterior is back around the office, so each door is a short hop, and the truck is at world (1168, -276). It also has the shadowless fills, the outdoor test that follows the character root, and the entrance cover held until the frames settle. A knocked-out player's Back to depot now goes to the depot, the dock shelves face the room, and every room fits inside the shell. Studio window "Odd Hours: Shift", 2026-10-23.

**Session housekeeping:**
- `studio-playtest-shift.lock` was created before Play and deleted after.
- RunTests is cleared to nil.
- The probe Scripts went with Play.
- Edit still has `Workspace.OfficeExterior`.

**Starting the solo shift:**
- A plain Play lands the player at the depot (-960, 2.6, 26).
- I moved the character onto `CleanupCrewDepot.truck1` (bed at (-980, 2.75, 48)).
- An injected server Script called `QueueServiceServer:departNow(player)` and it returned true.
- The player arrived on the yard truck at (1170.75, 7, -276). Shift 1, variant B, quota 640.

**How the hops were driven and timed:**
- Each hop was a real prompt press from the client: `InputHoldBegin/End` on the entrance's InteractionPrompt, once it had armed to 8 studs.
- A client Heartbeat logger timed them. It recorded the frame time, the root position, Lighting, and the transit cover's `GroupTransparency` (CanvasGroup `cover`).

| Check | Result |
|---|---|
| V1 | **PASS**: `Tests: 4452 passed, 0 failed, 4452 total`; traversal seeds 1-20: **957 paths, 0 failures** |
| V2 | **PASS in effect, with one literal mismatch** (below): Harlow has no way out of the dock room. z -50 is not inZone; the yard is |
| V3 | **PASS**: all four hops land on their frames; the cover starts lifting 0.35-0.41 s after the press and is gone by 0.63-0.69 s; FPS 43-60, worst frame 0.023-0.068 s; the carried item travels |
| V4 | **PASS**: yard 2.2 / 70 (officeExterior) → after Enter 0.35 / 0 (officeTier1) → after Leave 2.2 / 70 |
| V5 | **PASS**: the built office has 264 lights, **0** with Shadows (104 are PointLight fills). OfficeExterior has 63 lights, 16 with Shadows (15 SpotLights + 1 PointLight, all on `LightAnchor`s) |
| V6 | **PASS**: knocked out by the third catch (hp 0), voted Back to depot, character re-added at **(-960, 2.77, 26)**: the depot |
| V7 | **PASS**: both bay shelves' LookVector points at the room centre (dot 1.00) |
| V8 | **Done**: 4 captures, `pc2v_01..04` |

### V1: suite and traversal (PASS)
- Suite (RunTests Play): `Tests: 4452 passed, 0 failed, 4452 total`.
- Traversal harness: run in a later Play after the shift, on the Server, as `run({1..20}, CFrame.new(5000,1,5000))`. Result: **paths 957, failures 0**.

### V2: Harlow can't get out (PASS in effect)
- **Harlow's agent:** `PathfindingService:CreatePath({AgentCanJump = true, Costs = {[SAFE_ZONE_LABEL] = math.huge}})`. These are the NpcMoverSystem parameters plus OccupantServiceServer's `pathCosts`.
- **Bay patrol point:** route #2, (1178, 1, -31).
- **Loading bay box:** (1146, 1, -52)..(1190, 14, -10).

| Path | Harlow's costs | No costs |
|---|---|---|
| bay point → truck pad centre (1168, 4, -276) | **NoPath** (3/3 runs) | NoPath |
| bay point → yard (1168, 4, -74), 10 studs south of the dock door | **Success, 7 waypoints, ending at (1168, 1, -51)** (3/3 runs; same at y 1) | NoPath |
| yard (1168, 1, -74) → pad | NoPath | Success, 52 waypoints, every one labelled `SafeZone` |

**The literal mismatch:** bay → yard with his costs reports `Success`, not NoPath.
- It is the engine's partial path. Its last waypoint is (1168, 1, -51), at the dock room's door wall (room face z -51.5).
- That is **23 studs short of the goal and still inside the room**. Following it leaves him in the dock room; it never reaches the yard.
- The yard itself is all SafeZone: the no-cost yard → pad path is labelled SafeZone throughout.
- No walkable link crosses the wall: the no-cost bay → yard path is NoPath.
- Not a code bug. But any caller that trusts `Status == Success` without checking the last waypoint against the goal would be fooled, so it is flagged here.

**inZone** (`OccupantSenseSystem.layout(route)` + `OccupantBrainRules.inZone`):

| Point | inZone | In the bay box |
|---|---|---|
| (1168, 4, -50), just inside the dock room | **false** | true |
| (1168, 2, -50), just inside the dock room | **false** | true |
| yard (1168, 4, -74) | **true** | |
| pad (1168, 4, -276) | **true** | |
| yard (1100, 4, -150) | **true** | |
| car park (918, 4, 152) | **true** | |

The boxes behind those answers:
- `outdoors()`: yard (836, 1, -321)..(1322, 121, -57); car park (836, 1, -57)..(956, 121, 230).
- `safeZone()`: (1162, 4, -284)..(1174, 12.7, -268).

### V3: real hops (PASS)
The entrance frames (`OfficeServiceServer:entrance`):

| Entrance | Outside frame | Inside frame |
|---|---|---|
| Dock | (1168, 1, -69), look -Z | (1168, 1, -48), look +Z |
| Lobby | (933, 1, 152), look -X | (966, 1, 152), look +X |

Times are measured from the press.

| Hop | From → landed (root) | Cover on | Teleport | Cover starts lifting | Cover gone | 2 s after the hop: FPS / worst frame |
|---|---|---|---|---|---|---|
| Enter dock | (1168, -70) → **(1168, 2.37, -48)**, look +Z | +0.09 s | +0.28 s | **+0.37 s** | +0.66 s | **50.7 / 0.042 s** |
| Leave dock (carrying the Bottle bag) | (1168, -46) → **(1168, 2.41, -69)**, look -Z | +0.08 | +0.29 | **+0.35** | +0.63 | **47.8 / 0.045** |
| Enter lobby (carrying) | (932, 152) → **(966, 2.37, 152)**, look +X | +0.10 | +0.27 | **+0.36** | +0.63 | **60.1 / 0.023** |
| Leave lobby (`Exit_lobby_2`, carrying) | (967, 152) → **(933, 2.73, 152)**, look -X | +0.07 | +0.33 | **+0.41** | +0.69 | **42.7 / 0.068** |

- **Against the earlier long-jump hitch** (worst frame ~0.56 s, FPS 3-7): the worst frame is now 0.023-0.068 s and FPS stays at 43-60. The cover lifted on the settle check's quick-frames rule every time, never on its 1 s cap.
- **Carried item:** the Bottle bag, picked up through `CarryServiceServer:pickUp`, arrived with the player on every hop, and `CarriedBy` stayed the player throughout:
  - after Leave dock: (1167.95, 4.24, -70.73);
  - after Enter lobby: (971.98, 4.19, 154.36);
  - after Leave lobby: (931.28, 4.56, 151.94).
- **The P4 carry drift recurred:**
  - Standing still in reception with the bag, the root moved from x 966 to 970.8 (+X) in about 20 s.
  - Without the bag, after the dock Enter, the root also moved from z -48 to -40.5. A catch knockdown happened in that window, so that one can't be attributed.

### V4: atmosphere (PASS)
Client `Lighting`, read right after each hop settled:

| Moment | Brightness | GeographicLatitude | Preset |
|---|---|---|---|
| Yard, before Enter | 2.20 | 70 | officeExterior |
| After Enter dock (Ambient (22, 25, 40), Atmosphere 0.28 / 0.60, ClockTime 0) | 0.35 | 0 | officeTier1 |
| After Leave dock | 2.20 | 70 | officeExterior |
| Car park, before Enter lobby | 2.20 | 70 | officeExterior |
| After Enter lobby | 0.35 | 0 | officeTier1 |
| After Leave lobby | 2.20 | 70 | officeExterior |

### V5: shadows (PASS)
- **`CleanupCrewOffice`** (the built office plus the truck): 264 Light instances, **0 with Shadows = true**. 104 of them are PointLight fills.
- **`OfficeExterior`:** 63 lights, **16 with Shadows = true**: 15 SpotLights and 1 PointLight, all parented to `LightAnchor` parts (the yard and car-park lamps).

### V6: Back to depot after a knockout (PASS)
1. I set up a server watcher that logged root anchoring, big jumps and CharacterAdded.
2. I was caught 3 times in the shift. For the third catch, I was placed 6 studs in front of the Manager in the office, at (1098, 151).
3. The catch anchored the root (+0.3 s), released it (+1.3 s), and the character died: hp 0, body at (1066.3, 1.6, 152.0).
4. The shift state was `phase=results`, `crew=1`.
5. An injected Script called `ShiftServiceServer:vote(player, "depot")`, which returned true.
6. On that same frame, the root moved to (-960, 3.94, 26) with hp 100.
7. CharacterAdded fired at **(-960, 2.77, 26)**: the depot spawn (x ≈ -960), not the truck or the dock room.

**Note on the first two catches:**
- The first came just after the dock Enter, in the dock room: the HUD showed "Ice got caught!".
- The second came somewhere in the ~100 s around the lobby hops. The watcher wasn't running yet, so it isn't attributed: reception or outdoors can't be told.
- Worth watching in the owner's play-check.

### V7: dock-room shelves (PASS)
The bay's two `CleanupCrewOffice.Furniture.Shelf` parts (5×6×2):

| Shelf | Position | LookVector | Dot with the direction to the room centre (1168, -31) |
|---|---|---|---|
| minX wall | (1148, 4, -31) | (+1, 0, 0) | 1.00 |
| maxX wall | (1188, 4, -31) | (-1, 0, 0) | 1.00 |

- Each shelf's `ArtVisual` pivot has the same LookVector.
- I have no capture of the shelves' open side: a camera-positioned capture taken later, while I was outdoors, rendered the bay dark under the exterior lighting.

### V8: captures
In `design/production-art/map-kits/odd-hours-b1/exterior/captures/`. All are Play captures with the HUD showing.

| Capture | What it shows |
|---|---|
| `pc2v_01_dock_door_from_yard.jpg` | the closed roller door from the yard pad, with the "ENTER office" prompt armed and the ooze puddles |
| `pc2v_02_dock_room_after_enter.jpg` | the dock room right after Enter, looking +Z into the bay (a shelf on the left wall). It rendered this time, not black. The toast reads "Ice got caught!" |
| `pc2v_03_reception_after_enter.jpg` | reception right after the lobby Enter: the desk and sofa, with the Bottle bag carried (camera close behind the character) |
| `pc2v_04_lobby_from_carpark.jpg` | the lobby's glass doors between the rotunda columns, seen from the car park, with "ENTER office" armed |

### Other observations
- **ByteNet errors (not attributed):**
  - The server logged 10 of these between 168 s and 229 s of the session: `bytenet-max ... process.read:108: No readable entity found for ID: 17 for type: packet` (in `onServerEvent`).
  - That window covers the dock Enter, the first catch and the lobby captures.
  - My probes sent no client packets, so they don't explain it.
- **Transit warning gone:** the client did not log P1's "transit screen timed out" warning this time.
