# Odd Hours: map-agnostic monster roster + Bramble — implementation plan

Owner decisions (2026-11-10/11, via the coordinator):
- **Roster:** monsters are a general roster, Lethal-style, not tied to a map. Each map has a weighted list. One monster
  per map at launch.
- **Bramble, the owl mascot:** the School's monster.
  - It freezes while any non-hidden crew member watches it.
  - Even while frozen, its head turns toward the kid it's after.
  - After 10 s of non-stop watching, the head swaps to a new target. There is no step/stare timer.
- **No new player buttons or UI:** looking is done with the camera players already have.

Pitch and specs (notes folder): `freeze-monster-variants-2026-11-11.md`,
`substitute-behaviour-spec-2026-11-10.md` (the shared "watched" check and fairness numbers),
`monster-roster-pitch-2026-11-10.md`, `bramble-turnaround-2026-11-11.jpg`.

## Shape
The Occupant feature stays "the threat". It gains a **kind**:
- `harlow` is today's manager, unchanged.
- `bramble` is new.

A kind is data: rig template path, faces/sounds, tuning, which behaviour blocks it uses, and its twist.

- **Map-agnostic:** desks and hide spots are already discovered from tags (`Sense.known`), so a kind on a map without
  them just never uses those blocks. A kind may also switch off blocks it doesn't use (Bramble never sits at desks).
- **Roster:**
  - each map id (`office`, `school`) has a weighted list of kinds and a budget (`OccupantRosterRegistry`);
  - per shift, `OccupantRosterRules.pick` chooses the kind(s) from the seed;
  - at launch the budget allows one, and Occupant runs one rig as today. Two at once is a later change (the twin guard
    assumes one).
- **Freeze ("watched"), server side:**
  - Clients send a 10 Hz camera report (position plus look direction) only while a freeze kind is out.
  - Every 0.1 s the server decides who is watching, using `OccupantWatchRules` (pure) and raycasts:
    - alive, not knocked down, not hidden, not in the truck;
    - the report is fresh (< 0.3 s);
    - the camera is within 16 studs of the head, with a clear head-to-camera line;
    - the camera looks within 35° of the monster;
    - a clear server ray reaches head, chest or knees, within 80 studs.
- **Fairness:**
  - after the last watcher looks away, 0.4 s before he moves;
  - no catch for 0.6 s after unfreezing;
  - a catch only when unfrozen, 4 studs (+1 slack);
  - chase speed 21 (a sprint is 23);
  - the give-up clock counts moving time only.
- **Head target:**
  - the target is the nearest non-hidden crew member it last saw or heard (the brain's chase/search target if any);
  - after 10 s of continuous watching it swaps to another crew member (the next nearest, not the same one when
    possible);
  - the target's userId goes out as a rig attribute, and the client turns the head with a smooth yaw (up to 180°,
    owl-style). The server owns the choice.
- **Tells (client):**
  - a soft foam thump on each step it takes;
  - loose green feathers where it moved while unwatched (fade after 20 s);
  - the head turn itself;
  - Harlow's dread, music and catch flow, reused.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Occupant | shared | Data | OccupantKindRegistry | each monster kind: template path, faces, sounds, tuning, blocks used, freeze/head twist |
| Occupant | server | Data | OccupantRosterRegistry | per map id: weighted kinds + budget |
| Occupant | server | Rules | OccupantRosterRules | picks the shift's kind(s) from a map's roster and a seed (pure) |
| Occupant | server | Rules | OccupantWatchRules | who watches (report freshness, camera bounds, cone, ray hits), freeze/unfreeze beat, catch delay (pure) |
| Occupant | server | Rules | OccupantHeadRules | Bramble's head target: pick and the 10 s swap (pure) |
| Occupant | server | Systems | OccupantWatchSystem | camera reports in, raycasts at 10 Hz, publishes frozen + head target to the brain and the rig |
| Occupant | client | Systems | OccupantWatchReportSystem | sends the camera report at 10 Hz while a freeze kind is out |
| Occupant | client | Systems | OccupantHeadTurnSystem | turns a freeze kind's head toward its target (visual only) |
| Occupant | client | Systems | OccupantTrailSystem | feathers where a freeze kind moved unwatched, fading after 20 s |

Edits (no new modules):
- `OccupantEvents`: a `CameraReport` packet (CFrame-ish: position + look, unreliable).
- `OccupantBrainRules` and `OccupantMindUtils`: a `frozen` input. While frozen the intent is hold: no move, turn, doors
  or catch, and the give-up clock is paused. The catch is blocked until `unfrozenAt + 0.6`.
- `OccupantTuningFormulas`: per-kind speeds.
- `OccupantRigSystem`: build from the kind's template path (Harlow's stays the default).
- `OccupantServiceServer`: takes the kind for the shift from Shift/Office (the map) through `OccupantRosterRules`.
- `OccupantAssets`: Bramble's sounds and faces. Bramble has no painted face swap; its buttons and stitched smile are
  part of the model.

## Tasks (spec-first)
1. `OccupantKindRegistry`, `OccupantRosterRegistry`, `OccupantRosterRules` specs and modules. The Office roster is
   `{harlow = 1}`; the School's is `{bramble = 1}`.
2. `OccupantWatchRules` spec and module, covering every rule above, including:
   - a forged far camera;
   - a camera through a wall;
   - a stale report;
   - hidden or downed players;
   - the 0.4 s beat;
   - the 0.6 s catch block;
   - an 80-stud cap.
3. `OccupantHeadRules` spec and module (pick, keep, swap at 10 s, never the same kid when another exists, solo keeps
   the same kid).
4. Brain: the `frozen` input in `OccupantBrainRules` and its specs (hold intent, no catch, paused give-up).
5. `OccupantWatchSystem` and the `CameraReport` packet (server), plus `OccupantWatchReportSystem` (client).
6. `OccupantRigSystem` per kind, `OccupantServiceServer` taking the kind, and Shift passing the map.
7. Client: `OccupantHeadTurnSystem`, `OccupantTrailSystem`, sounds.
8. Bramble model (after the owner OKs the turnaround): built in Studio from simple shapes in the R15+ layout the
   Occupant rig expects, with a separate Head part on the neck joint for the turn. Uploads only to Icey Labs with the
   owner's OK.
9. Studio (with the coordinator's slot):
   - the suite;
   - a desk-free test map proves Harlow still patrols, chases and catches;
   - a real Play of a School shift with Bramble and 2 clients: watch-freeze, head target swap, hiding, a chase and a
     catch.

   Owner play-check.

## Follow-up: the School's run presentation (trip picture, portraits, roster-aware words)

A School run still showed Office/Harlow art and words in a few places. Rule per place:
- **About one run** (the trip card, the shift review, its awards): follows that run's map, and so its monster kind.
  The Office keeps its art and words exactly.
- **General hub text** (stat hints, the field guide, an ability's line, the dispatch board's HAZARD row, the chat
  wheel's ping): monster-neutral, kid reading level ("Monsters hear you less.").
- **The Office board's own cards** (the Jobs menu's THE MANAGER card, the hub's Tonight card) stay Harlow's: they are
  about tonight's Office job.

Art slots, never invented ids:
- `UIAssets.toonPhotos.schoolWide`: the School's trip-card picture, PENDING "" until uploaded. While empty the card
  shows the School map card's look (its colour panel and its `globe` icon), no Office photo.
- `UIAssets.toonIcons.brambleCalm` / `brambleHunt`: Bramble's portraits, PENDING "". While empty a Bramble portrait is
  the neutral `flashlight` icon, never Harlow's.
- `DepotTypes.MapSite.monster`: the kind a map's run words are about (Office harlow, School bramble); a server spec
  checks it against `OccupantRosterRegistry`.

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Occupant | client | Data | OccupantPortraitAssets | each monster kind's portrait icon (calm, hunt) by name, and the neutral stand-in while a kind's slot is empty |
