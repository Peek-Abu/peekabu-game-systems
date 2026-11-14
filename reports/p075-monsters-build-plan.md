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
