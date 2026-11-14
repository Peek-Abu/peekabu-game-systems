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
_pending (read `picks` on the review page)_

## Next
1. A Play slot for the four How-to-play step photos. Swap them into the mock and republish the review page.
2. Read the owner's picks. Build only the YES items. Each build:
   - states its module placement first;
   - is spec-first;
   - uploads to Icey Labs only after the owner's OK.
