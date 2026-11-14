# p075 monsters: owner picks and build plan (2026-11-14)

The owner answered the review page (https://claude.ai/artifact/KnEyvGZo2g1edvVzDCTp8m, db `answers`, 17 answers).
**This plan goes to the coordinator before any code.**

## What the owner picked
| Id | Idea | Pick |
|---|---|---|
| B1 | Vacuuming doesn't count as watching | **YES** |
| B2 | Lights blink, he jumps closer | no |
| B3 | Silent far away, loud quick steps inside ~18 studs | **YES** |
| B4 | Perches up high when unseen | **YES** |
| B5 | Close-camera moment | *not answered* |
| B6 | Locker-hall set piece | no |
| E1 / E2 | Copycat sound / head spin | no / no |
| S7 | Chase 27 to 30 at School | **YES** |
| S8 | Freeze cone 35° to 25° | no (stays 35°) |
| O1 | Build order | "up to you!" |
| M1 Big Dust Bunny, M3 Unit-7, M4 Morry | | no |
| M2 The Lookalike | | **YES**, note: "probably a post p1 or post launch thing" |
| M5 Safety Sam | | **YES** |
| P1 | Big Dust Bunny first | no |
| P2 | Second monster joins partway through a shift | **YES** |

**Owner direction (via the coordinator):** monster info in menus is lore and tiny tips only. It never explains how a
monster works or how to escape it; players learn that by playing.

## Build order (O1 was left to me)
1. **Batch 1, Bramble:** S7 + B1 + B3 (all small; they answer both owner notes) + the menu-word fixes below.
   One play-check.
2. **Batch 2, Bramble:** B4, the perch. One play-check.
3. **Batch 3, Safety Sam.** Needs decision D1 first.
4. **The Lookalike:** after launch, per the owner's note. Not planned here.

## Batch 1: S7, B1, B3, menu words
No new modules except one formula. Edits:
- **S7:** `OccupantKindRegistry` BRAMBLE `chaseSpeed` 27 to 30 (Bramble only runs on the School). Spec updated.
- **B1:** `OccupantWatchRules` eligibility gains "not vacuuming"; `OccupantWatchSystem` reads the character's
  `VacuumMotionConstants.ACTIVE_ATTRIBUTE` (the server already sets it) and passes it in. Spec first.
- **B3:**
  - `FootstepAssets`: a new `bramble` set (soft foam thump + feather rustle, ~6 variants), added to `FootstepTypes` with an
    optional proximity gate (`silentBeyond`, `loudWithin`).
  - `OccupantKindRegistry` BRAMBLE `sounds.footsteps = "bramble"`.
  - `FootstepEmitterSystem` applies the new formula below to the set's volume and pitch.
  - His steps stop on their own while frozen (his feet stop).
  - The heartbeat and vignette (`OccupantDreadSystem`) read his tagged rig, so I expect them to run for Bramble already.
    I'll check that in the play-check, not assume it.
- **Menu words (owner direction).** These lines now explain mechanics or escapes; proposed lore-only replacements:
  - `DepotBoardPanel` Bramble card: "Stops when you look at it" → "The school's old owl. It never blinks."
  - `DepotBoardPanel` Manager card: "Hears vacuums and things you drop" → "He still thinks he runs the place."
  - `DepotConstants` School tip: "Bramble the owl can't move while you look at it. Watch it and take turns!" →
    "Bramble the owl still guards the halls."
  - `DepotConstants` Office tip: "The Manager is here. He hears vacuums and things you drop. Empty hands run faster." →
    "The Manager is here. He never went home."
  - `TipRegistry.firstCatchBramble`: "Keep watching it, or hide!" is escape advice. Proposed: "Bramble got you!"
    The overtime tips ("Bramble gets faster") stay; they are about overtime, not the monster.
  - **Question Q1 below:** are the in-shift first-catch tips menus too, or may they keep a tiny hint?

### New modules (batch 1)
| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Footstep | client | Utils | FootstepProximityFormulas | A set's volume/pitch scale from listener distance: 0 beyond `silentBeyond`, jumps to loud and slightly quicker inside `loudWithin`. |

### Assets (batch 1)
- **Sound: Bramble footstep set.** About 6 soft foam thumps + 3 feather rustles, made in-house per the
  `game-sound-design` skill: spooky and cartoony, no stomps. Uploaded to **Icey Labs only after the owner OKs them**
  (on a review page).

### Studio (batch 1)
- **Shift place (34873), a School run, 2 clients:** one vacuums while looking at Bramble (he must move), one only
  watches (he must freeze), plus the chase speed and the steps: silent far away, loud inside ~18 studs, silent while
  frozen.
- **Lobby (34872):** the new board and tip words.

## Batch 2: B4, the perch
How it works: when nobody has seen him for 15 s and he is far from every crew member, he moves to a perch spot that
no crew camera sees and that sits near a crew member's area. He stays frozen there while watched. When unwatched, he
drops with one thump and goes back to his brain.

Edits:
- **School perch spots.** `SchoolKitRegistry` marks props that are perches: trophy case, basketball hoop, stage,
  locker-bank tops (via `SchoolHallUtils`), each with a perch offset. The build that places them (the Office feature's
  build system, which builds both maps) tags a perch point with `OccupantConstants.PERCH_TAG`. The Office keeps no
  perches; Harlow never uses them.
- **Bramble's twist and tuning.** `OccupantKindRegistry` FreezeTwist gains `perch: boolean` (Bramble true).
  `OccupantConstants` gains `PERCH_TAG`, `PERCH_UNSEEN_SECONDS = 15`, `PERCH_MIN_DISTANCE`, `PERCH_MAX_DISTANCE` and the drop timing.
- **The perch as a mode.** `OccupantTypes` gets a new mode, `perch`. `OccupantBrainRules` adds the perch step.
  `OccupantStageSystem` moves the rig with its existing `PivotTo`. `OccupantEffectSystem` plays the drop.

### New modules (batch 2)
| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Occupant | server | Rules | OccupantPerchRules | Whether a freeze kind may perch now, and which tagged perch: unseen ≥15 s, far from the crew, out of every fresh camera report's cone and sight, nearest a crew member's area. Pure. |

### Assets (batch 2)
- **Animation: Bramble perch hold + drop.** A crouched owl perch and a short drop-to-floor. Bramble-only; it's a
  monster rig, so the "character-agnostic poses" rule for employees doesn't apply. Upload to Icey Labs after the
  owner's OK.
- **Sound: drop thump.** One soft heavy foam thump; no sting when you spot him (owner-approved "reveal, not a
  jumpscare").

### Studio (batch 2)
- **Shift place (34873):** generate a few School seeds and check every perch spot. Bramble must sit on top of the prop,
  not inside it, and be visible from the floor.
- **Then a 2-client real play:** he perches only where unseen, freezes on the perch when watched, and drops when
  unwatched.

## Batch 3: Safety Sam (M5), any map, joins partway (P2)
**Decision D1 (needed before planning in detail).** `OccupantRosterRegistry` says the Occupant feature runs **one
rig**: every budget is 1, and the twin guard assumes one. A second monster at the same time means one of these:
- **A. Make Occupant multi-rig.** This touches much of its ~60 modules (brain, watch, catch, dread, tell, music) and
  risks Harlow and Bramble right before launch.
- **B (my pick). Sam is his own feature, `Cutout`.** His brain is nothing like theirs: he slides along walls, turns his
  thin edge toward watchers, and folds under the vacuum. He would reuse the existing coat-loss catch path and the walk
  graph, and leave Occupant untouched. A new feature with its own one service is within the layout rules (not
  approval-gated). If the developer would rather it live under Occupant, it needs A.

Sketch for B (to be firmed up after D1):

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Cutout | shared | Data | CutoutConstants | Sam's tuning: speed, join time, fold seconds, paper-flap range. |
| Cutout | shared | Data | CutoutTypes | His state types. |
| Cutout | server | root | CutoutServiceServer | Spawns him partway through a shift (P2), runs him, ends him with the shift. |
| Cutout | server | Rules | CutoutSlideRules | Next wall-hugging step along the walk graph toward his target, turning his edge to the nearest watcher. Pure. |
| Cutout | server | Rules | CutoutArrivalRules | When he joins: partway through the shift, never at the start, only on maps whose roster lists him. Pure. |
| Cutout | server | Rules | CutoutFoldRules | Whether a vacuum's suction folds him and for how long. Pure. |
| Cutout | server | Systems | CutoutRigSystem | Moves his rig, catches (one coat, through the existing catch path), folds. |
| Cutout | client | root | CutoutServiceClient | Starts his client systems. |
| Cutout | client | Systems | CutoutSoundSystem | The paper-flap tell, the sticker slap, the fold. |

**Assets (batch 3):**
- **Model:** a life-size cardboard cutout of a thumbs-up worker with the face peeled off (**no face**), faded print,
  bent corners. Via the `texture-pipeline` procedure.
- **Decal:** a "SAFETY FIRST" sticker.
- **Sounds:** paper flaps, sticker slap, fold/crumple, unfold.
- **Card:** a menu card with a lore line only (for example, "From the old safety video. Still smiling.").
- **Approval and upload:** each piece goes on a review page first, then to Icey Labs after the owner's OK.

**Studio (batch 3):** Shift place, both maps (he's any-map): Office with Harlow, and School with Bramble.
I proposed keeping him apart from Bramble on the review page, since both are sight monsters. The owner kept M5 without
saying, so this is **Q2**.

## Questions for the coordinator / owner
- **D1:** Safety Sam as his own `Cutout` feature (B), or make Occupant multi-rig (A)?
- **Q1:** Do in-shift first-catch tips count as "menus"? If yes, "Bramble got you!" with no hint.
- **Q2:** Safety Sam on the School with Bramble, or Office only?
- **Q3:** B5 (close camera) was left unanswered: drop it, or ask again?

## Status (2026-11-14)
- **Batch 1 pushed:** 95e03499 (S7 chase 30, B1 vacuum isn't watching, B3 footstep proximity gate) and 8f1f21cd
  (lore-only menu and board words; first-catch tips untouched until Q1).
  - B3 is not audible yet. p05-sound wires its owner-picked "Bramble steps A" set with
    `proximity = { silentBeyond = 18, loudVolume = 1.6, quickPitch = 1.12 }` and `sounds.footsteps = "bramble"`.
- **Batch 2 pushed:** de4b6c28 (B4 perch).
  - New module: `OccupantPerchRules`.
  - Perch spots: every locker, trophy cases and the gym hoop (`OfficeKitRules.isPerch`). There is no stage art in the
    School kit, so no stage perch.
  - Not built yet: the perch pose, the drop animation and the drop thump. He stands on top in his idle pose and drops
    without a sound. These are new assets that need the owner's OK before an Icey Labs upload.
- **Checked:** lint, format and types are clean locally.
- **Not checked yet:**
  - The specs: they run only in Studio (suite).
  - Real play: Shift place, a 2-client School run. Waiting on a Studio slot from the coordinator.
- **Scope (owner, 11-14):** "nevermind on new monster plan for p0.75!"
  - Batch 3 (Safety Sam) and the Lookalike are out of P0.75; the plan above stays for later.
  - B5 is dropped.
  - The first-catch tips stay as they are until Q1 is answered.
  - The perch pose, drop animation and thump are held for the owner.

## Shift check (2026-11-14, served at dc1ee2ac)
- **Suite:** 6658 passed, 3 failed. None of the three failures is mine:
  - `OccupantKindRegistry.spec` footstepSetOf: p05-sound's 61aed3cc turned on Bramble's steps; the spec still says
    none.
  - `AnimationCarryHarness.spec` and `DepotTruckVisualSystem.spec`: routed to p05-perf-art.
  - My first run had other failures: old words pinned in specs, the chase-27 spec, and my perch spec fixtures. All
    fixed in dc1ee2ac.
- **Real play: not done.**
  - The MCP starts solo Play only, and the Shift Play uses the owner's real account with saving on.
  - My School pick didn't take, likely because the place is locked on that profile. The truck left for the Office.
  - Unlocking the School would mean granting Credits and buying it on the owner's real save, so I didn't.
  - Nothing was written to Credits or places. The one Office trip that did start ran as a normal Office shift.
  - Flags set and cleared: `RunTests`, `DevAutoPick`. No temp instances. Nothing saved.

### Owner play-check (Shift, Test > Clients and Servers > 2 players, School)
1. **B1:** player A vacuums while looking at Bramble and he keeps moving. Player B only looks and he freezes.
2. **S7:** once he chases, he outruns a sprint (30).
3. **B4:** stop watching him for about 15 s with both players more than 40 studs away.
   - He should appear standing on top of a locker, trophy case or the gym hoop near you, not inside it.
   - Look at him and he stays still. Look away and he drops to the floor.
   - He also drops after 20 s, or if you walk within 10 studs.
4. **B3:** his steps are silent far away and suddenly loud and quick within about 18 studs (p05-sound's set).

## Perch pose, drop and thump (owner OK 2026-11-14: "bramble should get a perch and drop as well as thump soudn!")

**Built (no new modules, no animation upload):**

- **Perch pose.** A procedural owl crouch (gesture `perch`, `OccupantConstants.GESTURES`): hips forward, knees folded back,
  ankles keeping the feet flat (hip + knee + ankle = 0), a forward lean, the head up and cocked, the wings half open. It
  uses only standard R15 joint names, so any R15 rig takes it; a joint the rig lacks is skipped. `OccupantGestureSystem`
  now also bends the R15 limb joints (it rescans a rig missing one at most once a second). The server lowers the root by
  the crouch's leg drop (`OccupantGestureFormulas.crouchDrop`, from the rig's own hip, knee and ankle joints), so the
  feet stay on the top.
- **Drop.** The brain marks `Mind.droppedAt` (both drop paths: `OccupantPerchRules.think` and the break). The view shows
  the keyed `drop` gesture for `DROP_SECONDS` (0.9 s): from the crouch, a leap (legs tucked, wings high), the squash on
  landing, held, then the rise. `OccupantSeatSystem.drop` moves the anchored root on the same beats: a 1.5-stud hop and
  an accelerating fall to the floor point over 0.42 s (`OccupantPerchRules.fallAt`). It follows the gesture's legs
  (`OccupantGestureFormulas.jointAt`) so the feet stay on the floor, then lets go.
- **Thump.** A new kind sound slot `thump` (Bramble: `brambleThump`, Harlow: none). `OccupantWarningSystem` plays it from
  Bramble's head on the frame its mode leaves "perch" (`OccupantTellRules.dropped`). The file opens with the hop and the
  fall and lands 0.42 s in (`OccupantAssets.THUMP_HIT` = `DROP_FALL_SECONDS`). Its id stays **PENDING** (silent) until
  the owner picks a take and the coordinator OKs the Icey Labs upload.
- **Thump review page:** https://claude.ai/artifact/Nz9XJjYYuwvszTeW5s6Pry (3 in-house takes from the 11-12 Bramble
  stems; picks go to db collection `picks`, doc `thump-01`). All three pass the sfx gates, the named-source gate (the
  thump is the loudest part) and the cutoff gate.

**Not verified yet:**
- The joint bend directions on Bramble's actual rig: the signs assume R15 joint frames with no rotation. This needs a
  Studio look at a perched Bramble, and a flip of any limb that bends the wrong way.
- The TestEZ suite for the new specs: Studio only.

**Play-check (joins the 2-player Bramble checklist):**
1. Perch: Bramble crouches on top of a locker, trophy case or hoop with its feet on the top (not sunk in, not floating), leaning out, head cocked toward you.
2. Drop: when you walk close (within 10 studs) or look away after spotting it, it hops off, falls fast and squashes on landing, feet on the floor, then stands and walks on.
3. Thump (after the upload): the hop/flutter starts as it leaves the top and the THUMP lands as its feet hit the floor, heard from around 50 studs, quiet beyond.

**Thump uploaded (2026-11-14):** the owner picked take C ("soft and sneaky"). OGG mono, Icey Labs 189923277,
`rbxassetid://97041946735842` (owner and audio type checked on the economy API), wired into `brambleThump`. Rig check on
Shift: the perch head now looks down (it stared at the ceiling) and the wing lifts are smaller (2de045ac); suite
6676/6676.

**Q1 answered "yes!" (2026-11-14): first-catch tips are lore only.** `firstCatch`: "Mr. Harlow got you! He never went home,
and he still thinks he's the boss." `firstCatchBramble`: "Bramble got you! The old school owl wants everyone to stay
after school." A spec bars how-to words (hide, watch, look at, run, quiet, desk, freeze, keep) from both. Owner approved
the perch poses. Still flagged, unchanged: the overtime tips ("... gets faster"), Inventory "Monsters hear you less.",
transit "Hide from the monsters!".
