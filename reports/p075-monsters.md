# p075 monsters: Bramble scarier + a second monster for any map (2026-11-13)

Launch List rows `p075-bramble-scarier` and `p075-monster-anywhere`. **Ideas only. Nothing is built until the owner picks.**

Owner review page (YES/NO plus a note, answers save to its db collection `answers`):
https://claude.ai/artifact/KnEyvGZo2g1edvVzDCTp8m (source: `reports/p075-monsters.html`)

## Where Bramble stands (code, 2026-11-13)
- `OccupantKindRegistry` BRAMBLE: patrol 16, chase 27 (a sprint is 23), strike catch (a sound and one coat), head turn,
  feather trail, no voice, **no footsteps** (`sounds.footsteps = nil`).
- Watching is decided by the camera: `OccupantConstants.FREEZE_CONE = 35` (half-angle), camera within
  `FREEZE_CAMERA_RANGE = 16` of the head, sight cap `FREEZE_RANGE = 80`. Nothing checks what the character is doing,
  so a player can point the camera at Bramble and keep vacuuming. That is the owner's "you can kind of just clean
  while he's staring".

## Research takeaways (from how these games build dread; general design knowledge, not fresh web research)
- **A tell before the danger.** Doors' Rush (light flicker and rumble), Piggy and Dandy's World (a proximity sound or
  music) teach a tell, and then players dread it.
- **Watching must cost something.** Lethal Company's Coil-head (a freeze-while-seen monster) works because the crew
  must look away to do the job. Ours has no such cost.
- **He's never where you left him.** Weeping-angel monsters move in blinks and blackouts; the scare is the gap.
- **Silence, then loud.** Granny and Apeirophobia keep the monster quiet until it's close; the sudden change scares.
- **Third person needs a "close" moment.** First person gets "in my face" for free; third person needs a short camera
  pull-in.
- **One set piece per shift.** Doors' Seek and Halt hallways are short, scripted and memorable.

## Part 1: Bramble features (all work in third person)
| Id | Feature | How it plays | Look-to-freeze | Kid safety | Cost |
|---|---|---|---|---|---|
| B1 | Busy hands, busy eyes | Vacuum on = you don't count as watching. One kid watches, one cleans. | Makes watching cost something | Tip text only | Small (server skips watchers with the vacuum on) |
| B2 | The lights blink | Every 20-40 s his lights buzz 1 s, then go dark 0.5 s; he jumps up to 10 studs closer | The weeping-angel "blink" | One blink, never a strobe, ≥15 s apart, never fully black | Medium (School room lights grouped by room) |
| B3 | Quiet as a bat, then loud and quick (owner's ask) | Silent far away; inside ~18 studs loud quick foam thumps + feather rustle; stop when frozen; Harlow's heartbeat/vignette dread on for him | Steps stop = someone is watching | Soft thumps, under the chase music | Small (footstep set + distance switch + dread on) |
| B4 | The perch | Unseen 15 s and far: he moves to a high spot no camera sees (lockers, trophy case, hoop, stage); look away and he drops with a thump | Only moves where unseen | Reveal, no sting | Medium (perch tags in the School generator, pose, move rule) |
| B5 | "He's right here" camera | First time per life he's within 6 studs: camera pulls in over the shoulder ~0.5 s, FOV narrows, owl head turns round | The pull-in points at him, so it also freezes him | Short, no scream; off with reduced motion | Small-medium (Camera feature, phone check) |
| B6 | The long locker hall | Once a shift, hall light banks go dark toward you; he appears in the next lit bank, closer | Moves only through dark banks | ~10 s, rattles not bangs, a lit way out | Bigger; after launch |
| E1 | Copycat sound | He plays a crew sound (vacuum start, ping) from an empty room | n/a | Mild | Small |
| E2 | Head spin | Look away and back: his head has followed you, his body hasn't moved | Uses the existing head turn | Mild | Small |

Also on the page: **S7** (chase 27→30 at School) and **S8** (freeze cone 35°→25°, shared) as yes/no.

**Suggested order (O1):** B1 + B3 first (small, aimed at both owner notes), then B5 and B2, then B4, B6 after launch.
Each step is play-checked before the next.

## Part 2: a second monster for any map
Ground rule: **no employee turns evil.** That is Dandy's World's core (its own toons twisted into monsters). Ours come
from the building's leftovers and the company's old things, which fits the lore doc (buildings grow trouble from mess
and forgotten stuff). Each joins a shift through the 11-10 roster plan: the map's main monster starts the shift, the
second one arrives later (P2).

| Id | Monster | Hook | Hunts / counterplay | With Harlow / Bramble | Silhouette, colour | Cost |
|---|---|---|---|---|---|---|
| M1 | Big Dust Bunny (my pick) | Leave the mess, and it gets bigger | Hops to the dirtiest rooms; grows with Gloom left. Cleaning shrinks it; vacuum it when small and it pops into tiny bunnies (comes back later). Hop thumps + lint puffs tell | Both; gives cleaning a way to fight back, and punishes "only watching" Bramble | Lumpy lint ball, long floppy ears, stub tail; grey + Gloom purple; **no face**, no clothes (never reads as Pippa) | Medium |
| M2 | The Lookalike | One of your crew is made of Gloom | Copies a real crewmate's shape in solid Gloom, acts friendly, grabs a lone kid. Blank name tag, waves back late, 3 s of vacuum pops it | Bramble: it "watches" him but doesn't freeze him | Crew-shaped, drippy, deep purple, smooth blank head, **no face**, blank lanyard | Medium |
| M3 | Unit-7, the old cleaning robot | It thinks you are the mess | Rolls to noise; hose pull you run against; bags you (to the truck, minus a coat and your carry). Wet Floor signs block it; unplug at its dock for 30 s | Loud: hides Bramble's steps, draws Harlow | Squat barrel on treads, ribbed hose arm, one amber light, old orange stripe | Bigger |
| M4 | Morry the Mop | The old mascot only dances while its song plays | Dances toward you while the jingle plays; when it stops, anyone moving is spotted. Vacuum its boombox batteries | Harlow only; never with Bramble (two freeze games). Close to 11-10 Roll Call | Mop head with a cap (no face), faded orange/teal suit | Medium |
| M5 | Safety Sam, the cardboard cutout | Turn him sideways and he's gone | Paper-thin standee, invisible edge-on, slides along walls turning his edge to watchers; paper-flap tell; sticker slap takes a coat. Vacuum folds him 10 s | Harlow only (two sight monsters with Bramble) | Thumbs-up worker print with the face peeled off; faded, bent corners | Small-medium |

Picks on the page: keep/drop each of M1-M5, **P1** build Big Dust Bunny first, **P2** the second monster arrives
partway through a shift.

## Not done / next
- Nothing built. The next step after picks is a plan (module placement stated per AGENTS.md) for the first batch.
- No Studio use in this task.
