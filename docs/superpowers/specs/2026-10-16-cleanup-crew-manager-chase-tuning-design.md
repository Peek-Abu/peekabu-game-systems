# Cleanup Crew: the Manager's chase tuning, secure cabinets, no overhead UI

Date: 2026-10-16. From the developer's playtest of The Manager (the `Occupant` feature). It changes the
[chase kit](2026-10-15-cleanup-crew-chase-kit-design.md) and the
[behaviour set](2026-10-15-cleanup-crew-manager-behaviours-design.md). Every number is a tuning hypothesis kept in a
Data constants module.

## 1. What the playtest said

- The chase felt too short; even sprinting you could not really get away. More stamina would help.
- Hiding under a table mid-chase was always found ("he stuck his head under after pacing around me").
- Wanted more secure spots: cabinets.
- He could not see down a straight hall, so chases started too close to escape.
- The "!" / "?" over his head and the notices naming him felt choreographed and tied the game to one monster.
- On a play-again he sometimes stood frozen and never moved or turned, even in a chase.

## 2. Sight: near, and far down a clear line

| | Before | After |
|---|---|---|
| Near sight | 60 studs, 100° cone, seen at once | unchanged |
| Long sight | none | 125 studs, 40° cone straight ahead (`LONG_SIGHT_RANGE`, `LONG_SIGHT_ANGLE`) |
| Notice beat | none | 0.35 s at 60 studs rising to 1.4 s at 125 (`NOTICE_SECONDS`) |

- Far sightings need a steady clear line for the beat. Meanwhile he **stops and turns his head to you** (the swivel
  gesture; no icon). Lose the line and the beat falls back at `NOTICE_DECAY` a second.
- Once chasing, his target stays in sight down the long cone, so a straight hall does not save you: break the line of
  sight round a corner or a door.
- Rays are cast to the long range (`OccupantSenseSystem.rayRange`).

## 3. Losing him is a skill

- **Stamina** (`SprintConstants`): 4.5 s → **6 s**; refill after 1 s → **0.8 s**, empty to full 4 s → **3.5 s**.
  Empty-handed sprint stays 23 against his chase of 20 / 20.5 / 21 (tiers 0-2 with a crew; 19.5-20.5 solo), so a full
  bar is a 12-18 stud lead.
- **Sprint noise** radius 14 → **10** (×1.44 at the top tier = 14.4): sprinting round a corner with a lead is no longer
  heard, so a juke works; on his heels it still is.
- Losing sight still sends him to where he last saw you, then at most two nearby route points.

## 4. Hiding during a chase depends on what he saw

- **Witness** (`OccupantBrainRules.witnessed`): only when he actually sees you go in, near or far. A chase alone no
  longer counts: break the line of sight first and he did not see where you went.
- **Check odds** (`OccupantStareRules.checkChance`) follow how far away he was as you went in (`Mind.entered`):

  | Seen going in from | Stare | Check chance |
  |---|---|---|
  | 12 studs or closer | 4-10 s | 0.8 (+0.03 per second watched, cap 0.9) |
  | 26 studs | 4-10 s | 0.45 |
  | 40 studs or further | 2-4 s (a suspicion) | 0.1 |
  | not seen (hunch where he lost you) | 2-4 s | 0.12 (`HUNCH_CHECK`) |

  Before: 0.25 + 0.08 per second watched, +0.3 within 12 studs, cap 0.9, and every chase hide counted as seen.
- **The hunch**: searching, he reaches where he last saw you; a hiding spot within 10 studs there gets a short stare.
- **The pacing**: on the way to a spot's stand point, within `STAND_NEAR` (6) for `STAND_SETTLE` (0.8 s) he plants
  there. Before, a stand point squeezed beside a chair that the path could not quite reach kept him circling the hider
  until the 20 s give-up.

## 5. The secure supply cabinet

- A tall, always-closed supply cabinet (`supplyCabinet` art, 4.32 × 8 × 3.45, room for Pippa standing). Office places
  at most one per room, against a clear stretch of wall with its door to the room (`OfficeLayoutRoomUtils`, marker kind
  `closet`, placed last so it displaces nothing), and keeps only every third of those (`CLOSET_EVERY`): about 5-7 in a
  16-24-room office. It is solid. Hide makes it an "inside" spot: "[C] HIDE IN cabinet".
- **Inside**: you stand upright (no tucked pose); the closed cabinet hides you from everyone, so crewmates just see a
  closed door. The peek camera looks out through the door's louvres; the overlay draws the slats.
- **His rules**: he never looks in casually. He **opens** it (`OPEN_SECONDS` 2.2: the door rattles for 0.9 s, then
  swings open; your camera turns to his face) only after a noise at it, or when he saw you get in within
  `OPEN_RADIUS` (14) and the check roll says so. Never on a hunch, never a sit-in. Tapping out during the rattle is
  the escape. The anti-camping push-out still applies; spots are limited.
- Art: `design/production-art/map-kits/client-office-slate/build_supply_cabinet.py` (Blender, the kit's chunky
  style and atlas; two meshes, `Body` and `Door`), uploaded to Icey Labs as asset 137371684847747, the template at
  `ReplicatedStorage.Assets.CleanupCrew.ArtKits["client-office-slate"].furniture.supplyCabinet`. The door swing is
  client-side only (`HideDoorSystem`, from the furniture's `HideDoorOpen` attribute set by `HideServiceServer:setDoor`).

## 6. No overhead UI; abstract notices

- Removed: the "!" / "?" cue disc and the typed memo over his head (`OccupantBillboardSystem`, `OccupantCueDisc`,
  `OccupantMemo`, `OccupantWorldViewModel`, `useTypedGraphemes`). His lines are still **voiced** (gibberish clips)
  from a model attribute, never shown.
- The tells are diegetic: footsteps, the pen click, typing, light flicker, the heartbeat, the dread swell, the chase
  sting and music, and now the head turn when he notices you far off.
- Pacing notices speak of **site activity**, never the Manager ("Site activity is picking up…"), so another anomaly can
  share them.
- The PA was kept here, rarer and abstract, but was removed entirely the same evening (§9).

## 7. The play-again freeze

**Symptom:** on some shifts he stood still at one spot and never moved or turned, even when a chase began (his
brain kept thinking, so the tells and music still played).

**Root cause** (reproduced live): the NPC mover is costed (the truck box is `SafeZone`, cost ∞), and a costed mover
never steers without a path. Two of his own moves could leave his root where no path can start:

1. **Standing up from a desk.** `OccupantAssets.SEAT.standOffset` (0, 0, -1.1) is the stand-up clip's step
   *forward*, toward the desk, so every stand-up put his root inside the desk proxy. Physics shoved him out, sometimes
   behind the desk into the gap against the wall. From there every `ComputeAsync` returned `NoPath`
   (measured: 1-2 desks in every 16-23-desk layout), so he froze for the rest of the shift. It shows "on a play-again"
   because each shift's office is a fresh random layout, and he takes his first desk break 20-40 s in.
2. **Staring at a spot whose stand point is inside furniture.** The plant slide tweens him there, anchored, through
   anything. With the new cabinets, 6 of 44 stand points in a measured layout were inside a break table or a counter.

**Fix:**

- `OccupantDeskUtils.standUp`: the clip's offset, pulled straight back from the desk until his body is
  `STAND_CLEAR` (1.6) clear of its footprint. The `sit` effect now carries the desk's frame and size to
  `OccupantSeatSystem`.
- `OccupantDeskUtils.standPoints` plus `OccupantSenseSystem`: a stare's stand point is the first candidate a body fits
  at (that side, the other side, straight out further).
- Verified: 5 consecutive play-agains with a real desk break each; after every stand-up he walked 60-86 studs within
  10 s. Every stand-up point in 5 layouts has a path (before the fix: 1-2 per layout had none).
- Not fixed here (base code): the costed mover still has no recovery when no path exists from where it stands. A
  `base/*` change should let a costed kind steer straight at its goal for a short burst after repeated `NoPath`.

## 8. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Hide | client | Systems | HideDoorSystem | A supply cabinet's door rattling and swinging open on every client |
| Occupant | server | Utils | OccupantSightUtils | What he sees: near, far down the long cone, the notice delay |

Changed: `OccupantDeskUtils` (`standUp`, `standPoints`), `OccupantSeatSystem`, `OccupantWorkRules` (the `sit`
effect's desk), `OfficeLayoutGenerationUtils` (`CLOSET_EVERY`: one cabinet in three rooms that can take one),
`OccupantConstants`, `OccupantTypes`, `OccupantMindUtils` (`sightOf`, `visible`, `distant`, `sees`,
`noticeDelay`), `OccupantBrainRules` (the notice beat, witness, hunch), `OccupantStareRules` (distance-scaled checks,
`suspicious`, the cabinet's `open`, the approach settle), `OccupantDirectorRules` (`entered`), `OccupantSenseSystem`
(long rays, secure spots), `OccupantEffectSystem` (`door`), `OccupantRigSystem` (no shells), `OccupantTellRules`
(no cue; the open reveal), `OccupantFaceUtils`, `OccupantFeedbackUtils`, `OccupantPresenceSystem`,
`OccupantServiceClient`, `OccupantPaSubtitle`, `SprintConstants`, `HideConstants`, `HideTypes`, `HideSpotUtils`,
`HideServiceServer` (`setDoor`), `HidePoseSystem`, `HideServiceClient`, `HideViewModel`, `HidePeekOverlay`,
`OfficeTypes`, `OfficeConstants`, `OfficeLayoutRoomUtils`, `OfficeFurniturePlacementUtils`, `OfficeLayoutRules`,
`OfficeDecorSystem`, `ArtKitRegistry`, `ShiftNoticeUtils`.

## 9. Playtest follow-ups (2026-10-16, evening)

### Silent chases

**Symptom:** "Sometimes I don't hear the 'detected' sound even when he's behind me. I get caught without ever knowing
he was chasing me." With the overhead "!" gone, sound and screen are the only chase signals.

**Root causes** (code read, then measured live):

1. **The chase itself was the quietest state.** `harlowChase` had no asset (silent), and for the chased player the
   heartbeat sound and its red pulse switch off by rule (`OccupantTellRules.heartbeat`: "not chasing you"). So once
   the 0.88 s sting was over, a chase on you made *less* noise than him walking near you.
2. **A chase switched onto you never stung.** `OccupantFeedbackUtils.cues` stung only on a *mode* change into chase;
   when he dropped a crewmate (hidden, out of sight) and picked you up, the mode stayed `chase` and only the silent
   music cue fired. The server's `M.chase` likewise gives no `spotted` cue when he is already chasing.
3. **The sting could start late.** Every play builds a fresh Sound; with nothing holding the asset, the first play after
   a while took **0.23 s** to load (measured), a quarter of the 0.88 s sting.

Not causes: the sting is 2D for the chased player (no distance gate), Volume 1 in SFX (group 1), no cooldown; the
server publishes mode and target in the same frame.

**Fix:**

- Every chase start on you stings, however it starts, including a switch from a crewmate (`cues`: `spotted` with
  every `chaseStart`). A chase carrying on does not re-sting; a re-spot (search to chase) does.
- **The chase bed** for as long as the chase on you lasts: `harlowChase` is a PLACEHOLDER loop, the overtime ticking
  at 1.6x (not one of the rejected round-1 chase candidates), under your heartbeat racing at `CHASE_BEAT` 0.36 s
  (`OccupantTellRules.beatPeriod`).
- **The chase pulse**: the chased player's screen throbs soft red and slightly drained with that beat (never below 35%
  between beats), and fades out over 1.5 s when the chase ends (`OccupantTellRules.chasePulse`, `OccupantTellSystem`).
  No icons, no text.
- **Warm sounds**: the sting, bed, heartbeat and footstep assets stay held by silent Sounds while the client runs, so
  every play is loaded at once (live: `IsLoaded` true at the play frame, audible within 0.02 s).
- **Running footsteps**: his steps land louder with speed, x1 at his walk to x1.6 at his 20 studs/s run
  (`OccupantFeedbackUtils.footstepVolume`), so the crew near a chase hears him running (live: 0.70 at patrol, 1.10 at
  his 19.5 studs/s chase).

**Verified live** (one player, a real shift, a probe on the client): direct sight (sting, bed at 1.6x, pulse); long
sight at 72 studs after the notice beat (sting, bed, pulse); the desk ambush (work, ambush, investigate, chase: the
sting at the chase); a re-spot (chase, search, chase: a second sting); every sting 2D, loaded and playing. A chase
switched from a crewmate, a crewmate's view and the stare tap-out need a second player or a witnessed hide that did not
reproduce in the time box; they are covered by the specs (the client keys only off the mode and target attributes).

### The PA removed

The PA call-out ("{name}, please report to the office."), the ambient PA lines, the PA chime from him and the PA
subtitle strip are gone with their code and tuning: `OccupantPaStore`, `OccupantPaSubtitle`, `OccupantPaViewModel`,
`OccupantEvents.Pa`, the `callout` effect, `focus` / `nextCalloutAt`, `OccupantDirectorUtils.farthest`,
`OccupantTellRules.paLine`, `PA_LINES`, `PA_CALLOUTS`, `PA_GAP`, `PA_CHANCE`, `PA_SECONDS`, `CALLOUT_*`,
`STEER_FOCUS_SPREAD`. The other warning stages stay: footsteps, pen click, typing, flicker, heartbeat, music. Shift's
own overtime warning chime is a shift notice, not his PA, and stays.

### Supply cabinet: wider slits

The peek camera sits just outside the door's face and the overlay draws the louvres, so the model is unchanged (no
re-upload). The louvres (`HideViewModel.LOUVRE`) go from 9 slats at 62% with 8% sides (32% of the screen open) to 7
slats at 42% with 5% sides (52% open). Screenshots: `characters/qa/manager-v3/cabinet-peek-before.jpg` and
`cabinet-peek-after.jpg`.
