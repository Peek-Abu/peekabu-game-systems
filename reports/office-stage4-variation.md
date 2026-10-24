# Office map stage 4 (per-run variation and exterior anomalies): Studio verification

Task 10 of `docs/superpowers/plans/2026-10-24-odd-hours-office-map-stage4-variation.md`. Code at `9431e278`.
Studio window "Odd Hours: Shift", 2026-10-23/24. The previous session ran out of usage during the Task 7 fix round; this
run finished that round, reviewed Task 9 and ran every probe below.

## Summary

| Probe | Result |
|---|---|
| V1 | **PASS**: suite 4530/0. Traversal seeds 1-20, doors closed: 957 paths, 0 failures. Hide spots, seeds 1-50: min 9 (≥ 8), 0 bad seeds; live builds 31 and 53 |
| V2 | **PASS**: two shifts, different seeds, every listed choice differs (table below) |
| V3 | **PASS**: server and client compute the same 48 broken tubes of 341, for seed 372465689 |
| V4 | **PASS after one fix**: all 7 anomalies behave as specified. The booth TV did not flicker (fixed in `9431e278`, re-checked). After the next shift every slot was back to default |
| V5 | **PASS**: one Interact closed an open door; Harlow paths through an open and a closed door |
| V6 | **PASS**: desk search keeps the art, all 3 drawers slide out, no fallback model |

## How it was run

- **Suite:** `RunTests = true`, Play, read `Tests:`, stop, RunTests cleared to nil (it was ran twice: 4529/0 after
  the Task 7 fixes, 4530/0 after the TV fix).
- **Real solo shifts:** plain Play. The character goes onto depot `truck1`, then an injected server Script calls
  `QueueServiceServer:departNow`. The player lands on the yard truck and the shift reaches `running`.
- **Forcing anomalies:** an injected server Script called `OfficeServiceServer:forceAnomalies({id})`. This is the same
  path the admin `anomaly` command uses. The character was moved near the slot, and the client instances were read
  from the Client data model.
- **Lock:** the shift lock was held by the agent that ran out of usage (Task 7 fix round). I took it over, since I was
  continuing that task, and deleted it at the end. `studio-playtest.lock` was not touched.

## V1: suite, traversal, hide spots

- Suite: `Tests: 4530 passed, 0 failed, 4530 total`.
- Traversal (`OfficeTraversalHarness.run({1..20})`, all doors shut): **957 paths, 0 failures**.
- Hide spots, from `OfficeLayoutMeasureHarness.run({1..50})` (desks plus closets per generated layout):
  - min 9, so at least 8 on every seed;
  - every seed generated;
  - variation cannot lower this, because `PROP_CHANCE` has no desk, closet or other hide furniture.
- Live builds: 31 `HideSpotId`s on seed 372465689 and 53 on seed 670064893.

## V2: two shifts, different seeds

Desk pods, the room type compared (seed 372465689 → 670064893):

| | Shift 1 (372465689) | Shift 2 (670064893) |
|---|---|---|
| Pod rooms | 3 | 5 |
| Props in pods | deskPlant 6, planter 4, waterCooler 2, artFrame 1, copier 1, partition 14, … (no rug) | deskPlant 17, planter 6, waterCooler 4, **rug 3**, artFrame 1, copier 1, partition 22, … |
| Desk clutter items in pods | 112 | 177 |
| Stains and paper in pods | 19 | 78 |
| Lit tube panels in pods (light mood) | 7 | 45 |
| Open doors at start | `breakout2|hallS4`, `conference1|hallS11` | `pods1|hallS8`, `storage2|hallS10` |
| Whole office: stains / paper | 24 / 15 | 11 / 86 |
| Broken tubes | 48 of 341 | 76 of 363 |

- The layout itself is generated per seed, so room counts differ too.
- A light mood changes how many panels in a room are lit (`OfficeLightingUtils`), not their brightness, so the lit
  count is what moves.

## V3: broken tubes agree

- The server's hash and the client's own `OfficeLightUtils.broken(position, BROKEN_FRACTION, LayoutSeed)` were each
  computed over every non-fill `OfficeLightEmitter` in the live office.
- The two lists are **identical**: 48 of 341 tubes, for seed 372465689.

## V4: the 7 anomalies

| Id | Seen in play |
|---|---|
| banner | The run's own pick. BannerCloth UpVector (0,-1,0), so the text reads upside down. Every other slot stayed default. Capture `s4_banner.jpg` |
| wetFloor | All sign parts went to Transparency 0 and the labels to TextTransparency 0. The banner was put back upright. Capture `s4_wetFloor.jpg`: the character blocks most of the sign; the numbers are the evidence |
| boothTv | Neon, colour 5f8cd2, the `tvStatic` loop playing (Looped, rollOff 25). **Bug:** the SurfaceLight stuck at 0.80 (see below). After the fix: brightness ranged 0.60-1.20 and changed in 112 of ~120 frames over 2 s |
| carTicking | The `carTick` loop playing (Looped, rollOff 40). Both tail lights in reach turned ff2d23 Neon with an `AnomalyTailGlow`. The TV went back to SmoothPlastic with no light |
| welcomeScreen | "WE VALUE YOUR TIME", with "WE VALUE YOUR SLEEP" at 4.33-5.48 s and 10.28-11.53 s, i.e. about 1.2 s in every 6 s. That is the server's `OfficeSeedUtils.pick` for seed 181912651. LightInfluence is 0. Capture `s4_welcomeScreen.jpg` |
| autoDoors | The run's own pick on seed 181912651. I arrived 25 studs away. The **first open came 30.8 s later**, not on approach: the leaves slid the full 2.2 studs and were shut again 3.2 s after (0.6 + 2 + 0.6) |
| silhouette | Visible (T0) before it was seen. Still T0 while on screen after 1.2 s in view, at 132 studs. **Gone (T1) the moment the camera turned away**, and still T1 after 2 s back in view. Capture `s4_silhouette.jpg`: a dark, featureless figure against the lit window |

- **Reset after the next shift:** I forced carTicking at the end of shift 1, then let "Another shift" start shift 2
  (seed 670064893, natural pick banner). The forced set was dropped and every slot was default again:
  - the tail lights were back to 961414 with no glow;
  - the TV was SmoothPlastic with no light, its voice idle;
  - the sign and the figure were T1, the welcome label empty;
  - the door leaves were at their closed place;
  - only the banner was flipped.
- **Fix found here, the TV flicker (`9431e278`):** the Task 7 fix round moved the anomaly clock to
  `Workspace:GetServerTimeNow()` (~1.8e9 s).
  - At that size `math.noise` has no precision left and returns one value (measured: 5 inputs, one output), so the
    TV light never moved.
  - The spec only tested small times.
  - Fix: wrap the noise input at 256. `math.noise` repeats every 256, checked in Studio: x and x + 256 agree to 2e-5.
  - A new spec covers server-clock times.
  - The other `math.noise` callers (broken-tube blink, Harlow's tell flicker) use `os.clock()`, so they are unaffected.
- **No captures** for autoDoors, boothTv or carTicking:
  - the doors' open moment cannot be timed to the capture;
  - the booth capture faced the back of the booth;
  - the car capture landed on the shift results screen (the shift ran out of time).

## V5: doors

- **An open door closes on Interact.** `breakout2|hallS4` started open. From 4 studs, with the camera aimed at it, the
  client's real prompt press (`InputHoldBegin/End`) closed it, and it stayed closed. One Interact, one toggle.
  - The first attempt pressed before the prompt was shown, and nothing reached the server
    (Interaction counters 0/0). That is a probe timing slip, not a game fault.
- **Harlow, open and closed doors.** I used Harlow's path parameters from the bay patrol point (1168, 4, 0):
  - Conference room, behind the still-open `conference1|hallS11`: Success, 47 waypoints, ends 0.0 short.
  - Breakout lounge, behind the door I had just closed: Success, 74 waypoints, ends 0.0 short.
  - The other breakout lounge: Success, 13 waypoints.
- Harlow had also opened `pods1` and `pods2` on his patrol during the shift.

## V6: the searched desk (Task 9)

- `ProbeDeskDrawers` in Edit gave: `tagged=3 moved=3/3 sameArt=true fallback=false`, `HUG_FREE_MIN` placements 54
  (x -1.58..-0.33), slide 2.227, new contacts while sliding 0, contacts when open 0, open drawer backs ≥ 1.97 inside
  the front.
- Spec `OfficeSearchedDressingSystem.spec` "slides every tagged drawer of a kit desk in place and keeps the art" is
  green in the suite.

## Also fixed in this run (Task 7 review round, `fa4eea90`)

- The silhouette hides only when off screen. Being occluded or out of range no longer counts, and see-through parts
  never occlude it.
- The lobby doors keep a 20-40 s clock and never open on approach.
- Reads are cached from attribute signals.
- Leaf and silhouette writes happen only on change.
- Re-streams keep their progress.
- Tail lights are re-looked-for.
- Per-slot decisions are a pure, specced `slotAction`.
- **Bug found by the suite:** a captured tail light was re-captured while lit (it pruned by `IsDescendantOf(game)`, so
  a reset "restored" the lit look). It now prunes only lights that left `OfficeExterior`.

## Observations for the owner (not stage 4 changes)

- **Departure race:** the first `departNow`, sent about 3 s after Play started, counted a local move but never fired
  `arrived`, so the shift stayed in the lobby. The second try worked, and so did a later session's first try after
  9 s. It is likely a too-early-after-boot case in the Queue/Depot path. It is worth a look before launch, but it is
  outside this stage.
- **Bright lobby:** the lobby rendered in bright daytime light when I teleported straight in (capture
  `s4_welcomeScreen.jpg`). The indoor/outdoor Lighting switch probably runs only through the entrances. A walk-in
  should be checked in the play-check.
