# P0.75: menus from posed scene shots (2026-11-13)

Launch List row: `p075-scene-menus`. **Status: ideation done; 2 mocks waiting on a Studio slot, then the owner's
yes/no. Nothing is built.**

The owner loves the PLACES menu because each card is a staged, graded shot from our own game. This row picks the
menus that would gain most from the same treatment. Every shot follows `game-ui-design` section 6:
- staged in Studio with the real rigs, sets and lights;
- graded with `photos.py grade` (crop, split-tone to the V1 palette, vignette, grain), with the same `--shadow #34145F`
  violet as the place cards so every photo in the game looks like one set;
- a live scrim Frame under any words (no words baked into images);
- uploaded to Icey Labs only, after the owner's OK.

## Hard rules every pick keeps
- **Nothing over a shop/inventory item viewport.** No pick touches the Shop, the Inventory item cards, the Locker
  reveal or the skin pages. Skins are left out on purpose.
- **No face on Gloom.** Gloom shows only as goo piles and stains.
- **Words at a 3rd-grade level**, short, in the order you do things.

## Picks (best first)

### 1. Field Guide: "How to play" in 4 photos (MOCK 1)
- **Today:** GUIDE opens "FIELD GUIDE / MORROW & MORROW CLEARANCE / NEW ASSOCIATE BRIEFING" with four walls of text
  (`DepotHubViewModel.copy`). Too many words for kids, and no pictures.
- **Replace with:** four big step cards in a row (2x2 on phone). Each card is a graded photo, a number tab breaking
  its top-left corner, and one short line on a scrim under it.

| Step | Scene to stage | Light | Line |
|---|---|---|---|
| 1 GET ON A TRUCK | Pippa and Cappy hopping into the crew truck bed at the depot, one waving | warm depot night, truck lights on | "Hop on a truck with friends." |
| 2 VACUUM THE GLOOM | Pippa vacuuming a violet Gloom pile in an Office hall, the suction stream on | dim office, the vacuum's lilac light as key | "Vacuum up the purple Gloom." |
| 3 BE QUIET, HIDE | Prickles knee-hugging under a desk, Harlow's legs in the doorway, out of focus | dark, coral rim from the hall | "Monsters hear you. Hide!" |
| 4 LOAD AND GO HOME | Cappy carrying a shiny valuable up the truck ramp, gold sparkle on it | truck interior warm, gold rim | "Put treasure on the truck. Then clock out." |

- **Grade:** the place-card grade, plus a cream inner rim; step 3 alone keeps more shadow (danger reads as dark).
- **Signature:** step 2's card wears the Gloom goo `cap` on its top edge (it's about Gloom); step 4 gets the Gleam
  sparkles (you earn there).
- **Keeps:** the control hint (`cleanControl`) moves into a small key chip on card 2.

### 2. "Who's out tonight?": monster cards (MOCK 2)
- **Today:** no screen. Kids learn Harlow's and Bramble's rules only by getting caught, or from one tip line.
- **Where:** a second tab on the Guide page (HOW TO PLAY | MONSTERS), and the same card in the places menu detail
  (it already has a small monster card; this becomes its picture).
- **Replace with:** one tall card per monster: a posed portrait in his own place, his name on a coral tab, the place's
  DANGER drops (same meter as the places menu), and **one rule** in big words.

| Monster | Scene | Light | Rule line |
|---|---|---|---|
| Harlow | Standing in an Office doorway, leaning in, coffee cup in hand, desk in the foreground | violet office, coral rim on his edge | "He hears noise. Be quiet!" |
| Bramble | At the end of a locker hall, wings half up, frozen mid-step | dim yellow hall light, coral rim | "Look at him and he stops." |
| (SOON) next monsters | silhouette only, goo pooled inside the frame | | "Coming soon" |

- **Grade:** Manager-portrait recipe (`photos.py portrait`: grape rays + halftone, coral rim) cut out and breaking the
  card's top edge over a graded shot of his place.
- **No new rules.** The lines only say what the game already does.

### 3. Rank chart: a photo for each rank
- **Today:** a list of seven tags (lanyard colour + name), the next ones faded.
- **Replace with:** each row gets a small square photo of an employee wearing that rank's lanyard, posed bigger as the
  rank goes up (New Kid: holding a mop shyly; Big Boss: arms crossed on the truck roof). Your row's photo pops out of the
  row, under the "YOU ARE HERE!" pill.
- **Scene:** all seven shot at the depot by the rank board, same angle, so the row reads as a line-up.
- **Grade:** bright depot grade (the warm one), so it reads as "goal", not horror.

### 4. Company Clipboard: the timecard and today's job
- **Today:** a track of punch slots and the job's render on cream.
- **Replace with:**
  - the TIMECARD tab's header strip becomes Pippa punching the real hub time clock;
  - TODAY'S JOB gets a small photo of the job being done (for example, "Vacuum 200 Gloom" = a vacuum shot).
  The job photos come from pick 1's set, so no new shots are needed beyond the time clock.
- **Grade:** warm depot grade; the punch slots stay drawn, not photos.

### 5. Ride screens: ON THE ROAD
- **Today:** the drive card is a lilac road with the truck render on it. The arrival card already shows the place
  photo.
- **Replace with:** the drive card's header becomes the crew truck on a night road (headlights, the depot sign behind),
  and the truck render still drives along the road line under it.
- **Lowest of the five:** the ride is short, so this is a polish item.

## Looked at, not picked
- **Character pick / hire:** the live 3D employee on its platform already beats a photo; a photo would freeze them.
- **Locker opening:** already a 3D stage with your own employee.
- **Shop, Inventory, skins:** item viewports must stay clear (hard rule).
- **Shift Review:** already uses the darkened place live + the winner's own character. A staged shot can't hold the
  real crew.
- **Caught / Rehired card:** a horror photo there would scare young kids for little gain.

## Mocks (2026-11-13)
**Owner review page:** https://claude.ai/artifact/CTavrAssNqC2X3CQFdvZpu
- 17 yes/no questions (look / layout / words / what to build).
- Answers save to its db collection `picks` (doc ids `r1-<Q>`, fields `answer`, `note`, `at`).

**Mock 2: monster cards ("Who's out tonight?"): real captures.**
- Studio Shift place in Edit mode (coordinator slot), clones of `Assets.CleanupCrew.Characters.Manager` and `.Bramble`
  posed through Motor6D C0 turns (the `EmployeePoseRegistry` convention: degrees about X, Y, Z in `CFrame.Angles`
  order).
  - Harlow listening, hand to ear, `Noticing` face.
  - Bramble frozen, wings up.
- Cut out with rembg `isnet-general-use` + alpha matting. `cutout.py`'s backdrop key left violet halos, because my
  grey wall and floor were two tones.
- `iconize.py --style ink --rim #FF4F6E`, on a `photos.py portrait` grape rays/halftone backdrop, the head breaking the
  card's top.
- **For the build:** reshoot bigger, on one flat chroma colour (magenta suits both), so the edges come out clean.

**Mock 1: How to play: layout final, photos are stand-ins.**
- The Training map in Edit mode doesn't look like play: the carpet floor renders black, and the Gloom creep is flat
  blue.
- I tried fill lights and a higher ambient; neither fixed the floor. A test shot of Pippa vacuuming proved the pose
  and the hand-fitted vacuum work.
- **The four step photos need a short Play slot** on the Shift place:
  - a client RenderStep camera override (see the studio-play-captures memory);
  - no saves.
- The review page says so, and asks layout/words now.

**Studio clean-up:**
- Everything I added sat in `workspace.P075_TEMP`, which is deleted.
- Lighting is restored from the values saved at the start: ClockTime 0, Brightness 0.5, Exposure -0.7, both
  ambients.
- Nothing saved; the coordinator was told.

**Files** (outside git, in the shared notes folder `p075-scene-menus/`):
- `mock.html` (the HTML mock, V1 tokens + `base2.css`), `renders/`, `raw/`, `cut/`.
- `photos/` holds the cut-outs and backdrops.

## Owner's answers
**Round 1** (db `picks`, `r1-*`, partial):
- Y1 (two tabs) YES.
- Y2 (four cards in a row) YES.
- R3 (SOON card) YES, with the note "Just spice up that card too!".

**Owner notes via the coordinator (2026-11-13):**
- How to play showed the same picture 4 times.
- The 4-point star/shine is banned (the kit replaced it with soap bubbles, `470f20f9`).
- Card 4 overflowed the panel.
- Monster cards gave too much info: the owner wants lore and at most a tiny hint, never mechanics or escape.
- Both mocks looked drab.
- "What about other mocks?"

## Round 2 (2026-11-13), same review page, questions `r2-*`
- **Stars:** no 4-point star anywhere. Rewards use `fx_bubbles.png`; light panels use violet bubble rings.
- **How to play:** four different stand-in captures (posed Play shots still to come), and card 4 is inside the panel.
- **Guide header:** gold, per the kit's colour-per-screen rule.
- **Monsters tab:**
  - Player-facing name **THE MANAGER** (the lore doc's rule), not Harlow.
  - Lore only: "He never went home. He still checks every desk at night." / "Maple Hill's old owl mascot. He is very,
    very shy."
  - No rules or escape tips.
  - Each monster has his own colour backdrop (coral / moss) and the cut-out breaks the card. SOON is a narrow
    silhouette card.
- **New mocks:**
  - Rank chart: a staircase of lanyard-coloured pillars, photos on reached ranks, "?" ahead, YOU lifted.
  - Clipboard TIMECARD: Pippa at the hub time clock. TODAY'S JOB: a job photo.
  - Ride card: the truck breaking out of a photo strip.
  - All three use stand-in pictures (existing renders and older captures), tagged on the page.
- **Red-flag pass:**
  - Removed ✓ and ● glyphs (now drawn).
  - Un-mirrored the truck (its lettering read backwards).
  - Swapped the Pippa salute render (the owner flagged its hands clipping) for the cheer render.
  - Moved the place chips out from under the cut-outs.
- **Files:** `mock2.html`, `r2/` renders and `photos/` in the notes folder.
- **Skill profile updated:** the stars ban and soap bubbles in the profile, plus a taste-log entry for this round.

### How-to-play Play shots (2026-11-13, Shift place, coordinator slot)
All four were staged during Play (runtime only: server execute_luau into `workspace.P075_TEMP`, nothing saved):
1. Pippa (`point`) and Cappy (`wave`) in depot `truck1`'s bed.
2. Pippa vacuuming in the real Office open-plan: hand-fitted vacuum, Gloom pile = clones of the Training map's
   GloomCreep parts.
3. Prickles crouched by an Office desk (`RevealSuspicious` face), the Manager behind with a coral light.
4. Cappy carrying the office kit's snow globe into `truck1`.

**How the shots were taken:**
- Client RenderStep camera override from Workspace attributes.
- The game's ScreenGuis and BillboardGuis disabled for the shots.
- `truck1`'s LocalTransparencyModifier held at 0, because the depot fades trucks near the camera.
- ReplicationFocus moved to the shot.
- The idle Office is unlit, so temp PointLights were used there.

**Clean-up, verified in Edit after stopping:**
- The client binds are removed and the GUIs re-enabled.
- `P075_TEMP` is destroyed; Play is stopped.
- In Edit: RunTests false, Lighting unchanged, the workspace back to its 6 children, no injected scripts.

**Lobby:** the Lobby Studio was in Play (another session), so the time-clock shot is still a stand-in. The rank
line-up and the truck at night were skipped to free Shift for p075-monsters.

**Files:**
- Raw captures: `raw/play_s1..4.jpg`.
- Graded: `photos/s1..4.jpg` (37:45) and `photos/job.jpg` (TODAY'S JOB).
- Review page v3 shows them.

### Time-clock shot (2026-11-13, Lobby Edit, coordinator slot)
- `Assets.CleanupCrew.TimeClock` (x1.6) on the hub wall at the `Board_clock` marker, with Pippa (`point`, Happy)
  pointing at it.
- One temp key light; Lighting untouched.
- Temp folder deleted, RunTests false, nothing saved.
- The editor-only marker labels ("clock", "daily") were patched out of the mock photo. A final shot should hide the
  markers in Studio instead.
- File: `raw/lobby_clock*.jpg`, graded `photos/clock2.jpg`. Page v4 shows it on TIMECARD.

**Still needed:**
- Studio time for the remaining pictures: Shift Edit for the rank line-up in lanyards and the truck at night.
- The SOON card still needs the "spice" the owner asked for in round 1.

## Round 3 (2026-11-14), same review page (v5), questions `r3-*`

**Owner's round-2 notes, in short:**
- How to play: step 1 shows yellow training arrows; the vacuum (step 2) and Prickles (step 3) are posed wrong.
- Monsters: the Manager is not facing the camera. The coming-soon card is stretched. No danger icon. Bramble: turn only his head to the camera.
- Ranks: what are these characters? Use the rank lanyard icon. Show a Big Boss view. What is given on rank-ups and level-ups? A rank-based pose could feed the ladder. Shifts don't move you up, levels do, so "3 more shifts" is misleading.

Only `r2-L1` (monster colours: yes) was saved in the db; the rest came as these notes.

**What a rank-up gives (read from the code):**
- A level and a rank are the same thing: 7 levels, one rank each (`RankRegistry`). There are no level-ups in between.
- XP thresholds: 0 / 75 / 300 / 800 / 1,800 / 3,400 / 5,200.
- XP per shift (`RankConstants.XP`):
  - 10 for working the shift and 15 for meeting the contract;
  - 1 for each item you load (up to 10);
  - 5 for overtime loot, 5 for clocking out uncaught, and 5 more if the whole crew clocks out;
  - all of it doubled when a friend is in the crew.
  - A normal shift is about 30-50 XP.
- What a rank gives:
  - the lanyard colour, plus the v6 badge (its shape and back icon change by rank: NEW!, broom, sponge, vacuum, clipboard, keys, #1 mug);
  - the rank name on the ID card;
  - a Roblox badge for ranks 2-7 (`BadgeConstants` `rank-2`..`rank-7`);
  - the RANK UP! sticker on the results card (`RankSlip`).
- Nothing else: no currency, no items, no power. After Big Boss nothing yet; the Clearance Level track is not built.
- A rank pose is already half built: `EmployeePoseRegistry` profile context `byLevel = {1 shy, 2 wave, 3 proud}`, chosen by `EmployeePoseRules`.
  - Proposal (`r3-R2`): one pose per rank, all existing kit poses. In order: shy, wave, proud, point, coachCheer, cheer, victory.
  - Used on the profile card, crew and seat portraits, and the ladder.

**Changes in the mocks (`mock3.html`, renders in `r3/`):**
- Monster cards:
  - DANGER drops removed.
  - Three equal cards. The coming-soon card has goo drips from the top edge, a big "?" and COMING SOON caution tape.
  - Manager line shortened to "He never went home. He still checks every desk."
- Rank chart:
  - The NEXT RANK card has the next badge breaking its corner, an XP bar (560 / 800 XP) and a "You get" list.
  - The staircase shows each rank's real v6 badge-back render, LEVEL n and XP.
  - Only YOU stands on your step.
  - New Big Boss view: all steps lit, you on gold, TOP RANK.
  - The badge renders are cut from `characters/identity/lanyards/v6/review_v6.png` (rembg isnet with holes filled).
- Red-flag check: no 4-point star or sparkle anywhere (the rewards use soap bubbles; the Big Boss glow is plain rays), and nothing covers an item viewport (these screens have none).

**Still waiting for a Studio slot (asked the coordinator):**
- Shift Play:
  - step 1 from an angle without the training arrows;
  - steps 2 and 3 with a test character really vacuuming and hiding (the vacuum is IK with no clips; the hide pose is `HidePoseSystem`).
- Edit:
  - the Manager facing the camera;
  - Bramble with only his head turned;
  - the employee in each rank pose.

**Studio slot 2026-11-14 (Shift, about 30 minutes, Edit then Play), page v6:**
- Edit:
  - Bramble: the round-2 body, with only `Neck` turned (Y -18 instead of 18) so the head faces the camera.
  - Pippa in the seven kit poses from `EmployeePoseRegistry.get("Pippa")`: shy, wave, proud, point, coachCheer, cheer, victory. These are now on the ladder (Cleaner = proud, Big Boss = victory) and in a strip on the page.
- Play, step 1:
  - The yellow arrows were the hub chevron trail (`TrainingTrailSystem` Beams in `workspace.TrainingGuide`, re-enabled every frame). They were removed for the shot by unparenting the folder on my client.
  - The faded truck on the left was the depot's occlusion fade; the shot holds `LocalTransparencyModifier` at 0 on every depot part.
- Play, step 2:
  - The hub has no vacuum `Tool`: `VacuumServiceClient.selected()` needs the Tool, which a run gives.
  - So I walked onto the Training pad. It started a real training run, and a Studio MCP mouse hold gave the game's own vacuum pose.
  - A cloned GloomCreep sits under the nozzle, with two temp lights (the training map is flashlight-dark).
  - The vacuum aims along the camera's yaw (`VacuumLookSystem`), so the shot is framed from the front-side.
- Not done:
  - Step 3, the real hide. Pressing C and `ProximityPrompt:InputHoldBegin` on HideDesk1's reach prompt in the training run gave no `HideSpotId`. The run probably locks hiding until its hide stop, so it needs a run played up to that stop.
  - The Manager facing the camera. A clone's mask face (FacePlate SurfaceAppearance) is blank in both Edit and Play; only the live Manager NPC shows it. The front-facing shot needs the real Manager in a shift run.
- Cleanup:
  - Edit temps were deleted before Play. Play was stopped (its changes thrown away).
  - Shift ended in Edit with Lighting at 0 / 0.5 / -0.7, workspace children unchanged and no P075 scripts. RunTests and DevAutoPick were never set.
  - Audio was muted on the client during Play. Nothing was saved.

**Second Studio slot 2026-11-14 (Shift Play), page v7:**
- Step 3:
  - In a training run (started from the Training pad), my test employee stood at HideDesk1's reach point and a Studio MCP key press of C put her in (`HideSpotId` desk.3). This is the game's own knee-hug pose.
  - The first hide ended on the cramp timer. The second capture is the one used.
  - The earlier refusal was not a training lock; `HideRules.canEnter` has none.
- The Manager:
  - The live NPC (`TrainingMap.Shift["The Manager"]`) waits in the staff room behind StaffDoor until the escape stop. The camera went inside the room, and his Calm mask face renders on the live model.
  - Cut out with rembg, with the baseboard and floor masked off.
- Cleanup: Play stopped; Edit clean (Lighting 0 / 0.5 / -0.7, no P075 objects, RunTests and DevAutoPick unset). Audio was muted. Nothing was saved.

## Next
2. Read the owner's picks. Build only the YES items. Each build:
   - states its module placement first;
   - is spec-first;
   - uploads to Icey Labs only after the owner's OK.
