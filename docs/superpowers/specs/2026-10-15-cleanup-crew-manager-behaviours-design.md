# Cleanup Crew: the Manager's behaviour set

Date: 2026-10-15. The developer approved six behaviours for The Manager (the `Occupant` feature): desk work as part of
his routine, the stare-down at a hiding spot, sitting at the desk you hide under, a director that keeps him near the
crew, staged warning signs, and a new catch jumpscare. They replace the chase kit's baseline (chase-kit design §4,
"seen entering means he drags you out"). Every number is a tuning hypothesis in `OccupantConstants`.

## 1. Desk work (his routine)

- On patrol, a work break is due **20–40 s** after he clocks in, then **35–70 s** after the last one ended.
- **Which desk** (`OccupantDeskUtils.pick`):
  - 55% of the time a desk "near the crew": its seat is **18–45 studs** from the nearest crew member, the closest to
    30 studs winning.
  - Otherwise a desk "elsewhere": at least 45 studs from everyone, picked at random.
  - Never a desk someone hides under, a desk a player stands within 10 studs of, the last desk he used, or a desk in
    the loading bay. With no candidate, he skips the break.
- He walks to the chair, **sits** (root anchored at the chair, clipboard hidden, the sit-and-type clip) and **types for
  10–22 s**. The typing plays from his head, positional, out to 70 studs, so you hear it through rooms.
- **The ambush.** While he sits, a noise he hears, a player within **14 studs** or a player he sees sets it off:
  - the typing stops dead;
  - his head swivels to the point (0.35 s), still smiling (Calm) for 0.4 s, then the Noticing face;
  - he holds for **1.1 s**, then stands up (the stand-up clip at 1.5×, 1.2 s, head still turned);
  - then he chases whoever he sees, or investigates the point.
- Otherwise he stands up at 1× (1.8 s) and walks on from the nearest route point.

## 2. The stare-down

- **Known hider.** He saw you go in (Hide's witness: you were in sight, or you were his chase target). He walks
  (runs, from a chase) to the spot's front, **1.6 studs** off its edge and **1.9 studs** to the side (beside the
  desk's chair, not in it), faces it and **stands still for 4–10 s**
  (Noticing face, no cue disc, no line).
- **Then he checks or leaves** (`OccupantStareRules.checks`). The chance to check is
  `0.25 + 0.08 × seconds he had eyes on you`, plus **0.3 if you went in within 12 studs of him**, capped at 0.9.
  A noise within **10 studs** of the spot during the stare makes it certain.
  - **Check:** he folds double to look under (waist and neck gesture, 1.1 s, Hunting face), then the catch.
    The hider's camera draws back into the spot and turns to his face for it (he is too tall for his head to
    reach the peek camera's own view).
  - **Leave:** he straightens and walks on. He forgets you (`setSeen(false)`) and leaves that spot alone for 25 s.
- **Learnable:** break line of sight early and far, and he likely walks away; duck under a desk right in front of him
  after a long chase and he looks. Keep the crew quiet around you.
- **Tapping out is a valid escape.** He is startled for **0.7 s** before he chases. Sprinting at 23 against his 20,
  you get away if you go at once. That includes tapping out during the bend.
- **Suspicion.** When he arrives at a noise and a hiding spot lies within **10 studs** of it, he walks to the nearest
  spot and stares for **2–4 s**, then moves on. A noise during that stare makes him look.
- While he stands at your spot or sits over you, the camping push-out (30 s) is held until he has walked off, so it
  never throws you into his lap.

## 3. Sitting at the desk you are under

- **When:** a stare (known or suspected) on a desk with someone under it, whose chair is on the knee-hole side, ends
  with a **35%** roll. At most **2 per shift**, at least **90 s** apart.
- **The event:**
  - He sits **0.7 studs further back** than at work, so his knees stop at the desk's edge instead of 0.45 into the
    knee-hole (the overlap with the hider's huddle). His shins and shoes fill the hider's peek view.
  - He types for **7–11 s** (the typing is right above you).
  - He folds forward over his knees and his head slowly comes in under the desk's lip, upside down, still smiling
    (2.6 s: Calm, then Hunting for the last 0.9 s). It holds **1.4 s**. The hider's camera draws back and turns to
    his face, the same reveal as the stare's check.
  - Then: **50%** he catches you (certain if there was a noise), else his head rises (1 s), he types 2 s more, stands
    and leaves.
- **Tapping out** during it is the escape: he has to stand up first (1.2 s).

## 4. The director

- **Steering** (like Alien: Isolation's): every **28 s** with a crew (36 s solo), 4 s sooner per pressure tier, 16 s
  (22 s solo) in overtime. The first steer is 15–30 s into the shift. He walks to the route point or desk chair nearest
  a point **12–20 studs** from a random crew member, never within 8 studs of them. Players in the truck's box are left
  out.
- **The menace gauge** (0–100, `OccupantMenaceFormulas`):
  - It rises 10/s while he chases, 6/s while he stares or sits at a hider's desk, and 3/s while someone is within 18
    studs. It gains 15 for a sighting and 45 for a catch.
  - Otherwise it falls 2/s.
- **At 100 he takes a breather:** he walks to the route point farthest from the crew. For **30–60 s** (40–60 solo,
  5 s less per tier, 15–25 in overtime) he does not steer, ignores noises more than 20 studs from him and works at the
  far desks. He still sees. The gauge stays at 0 through it, even after a catch on it. So busy and calm phases alternate.

## 5. Warning signs in stages

The stages run on each client (`OccupantTellRules.stage`) by the distance to him:

| Stage | Distance | Tells |
|---|---|---|
| far | 45–85 | his footsteps (heard to 85), a pen click every 9–16 s |
| mid | 25–45 | lights within 26 studs of him flicker (the PA lines were removed 2026-10-16) |
| near | under 25 | the heartbeat (now 25 studs, was 40), his footsteps, a dread swell that grows as he nears |
| chase | his chase on you | the sting (every chase start), the chase bed with a racing heartbeat, a soft red screen pulse (2026-10-16) |

- **The PA is removed (2026-10-16 playtest).** There is no PA call-out, no ambient PA line, no PA chime from him and no
  PA subtitle strip; the director's steers aim at a random crew member's area only. See the chase-tuning design §9.

## 6. The catch jumpscare

- The victim's camera follows his face each frame for **1.0 s** (was 0.6). It sits 1.9 studs in front of his face
  plate, world-up, at FOV 38. You see the Hunting face, his head tilting 25°, the catch sting and a quick shake.
- From a hiding spot, the same camera shows his face under the desk, upside down (sit-in) or bent sideways (stare
  check).
- No gore. The frame-built grin overlay is now drawn only on the fallback body (the mask has its own Hunting face).
- Then the existing launch, ragdoll and spectate flow runs.

## 7. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Occupant | server | Rules | OccupantStareRules | The stare mode: how long a stare lasts, whether it ends in a check, the sit-in roll |
| Occupant | server | Rules | OccupantWorkRules | The work mode: desk breaks, typing, the ambush, the sit-in's phases |
| Occupant | server | Rules | OccupantDirectorRules | Steering toward the crew, the breather; tracking sight and the menace gauge |
| Occupant | server | Utils | OccupantMindUtils | The shared pieces of his thinking (mode copies, lookups, sight, patrol, chase, stare and work starts) |
| Occupant | server | Utils | OccupantDeskUtils | Which desk he works at, its seat frame, a spot's stand point |
| Occupant | server | Utils | OccupantDirectorUtils | Where to steer him (the crew's area), the far point for a breather |
| Occupant | server | Utils | OccupantMenaceFormulas | The menace gauge, breather lengths, steer intervals |
| Occupant | server | Systems | OccupantSeatSystem | Seats him on a chair and stands him up (anchor, clipboard, clips) |
| Occupant | server | Systems | OccupantEffectSystem | Carries out a think's effects (body, Hide's seen and hold, catch, cabinet door) |
| Occupant | shared | Utils | OccupantGestureFormulas | The procedural head and waist gestures (swivel, peek, under, tilt) |
| Occupant | client | Systems | OccupantGestureSystem | Lays his gestures over his joints on every client |
| Occupant | client | Systems | OccupantWarningSystem | The staged far and near tells, his seated typing |

Removed 2026-10-16 with the PA: `OccupantPaStore`, `OccupantPaSubtitle`, `OccupantPaViewModel`, `OccupantEvents.Pa`.

Changed: `OccupantBrainRules` (now the orchestrator over the Work, Stare and Director rules; the body's settling), `OccupantTypes`,
`OccupantConstants`, `OccupantAssets` (typing, priorities), `OccupantEvents` (`Pa`), `OccupantFaceUtils` (per phase),
`OccupantTellRules` (stages), `OccupantFeedbackUtils`, `OccupantServiceServer`, `OccupantSenseSystem`,
`OccupantRigSystem`, `OccupantCatchSystem`, `OccupantServiceClient`, `OccupantScareSystem`, `OccupantPresenceSystem`,
`OccupantTellSystem`, `HideServiceServer` (`hold`), `EmployeeFaceRules` (stare alerts).

## 8. Placeholder sounds still needed

- `harlowChase`: the chase music. Since 2026-10-16 a PLACEHOLDER bed (the overtime ticking at 1.6x) until the real
  music is chosen.
- `harlowDread`: the near-stage dread swell (a low, slow loop).
- `harlowAmbush`: a short sharp intake for the ambush swivel. Silent until uploaded; the sting covers it.
- The PA was removed (2026-10-16), so it needs no voice lines.

## 9. Audit and fixes (2026-10-17)

### His head through the desk (the hider's view)

**Report:** "the desk covers manager's head a bit", mostly while his head moves in and out.

**Cause** (sampled frame by frame against the desk art's parts, from the hider's camera): both gestures were one straight
blend from his pose to the end pose, so the arc of his very long torso and neck went where the geometry is.

- **Sit-in** (`under`): from the chair his head arced forward over the desk and came straight down through its top
  and the keyboard (head, face plate and neck inside the top for ~0.5 s; his hands pressed into the top at the start).
  The hider saw the head come out of the underside. Tipping back up went the same way in 0.4 s.
- **Stare's check** (`peek`): he stood 1.6 studs out on the desk's +X side, where the drawer pedestal is. The fold
  swept his head through the top and it ended inside the pedestal: from under the desk his face was hidden entirely.
- The camera and the desk's geometry were not at fault; neither was a missing collision (the art is non-colliding).

**Fix: shape the path, not the camera.** Moving the camera or putting the head on "the visible side" cannot help
while the head passes through solid furniture (everyone else sees it too), and fading the desk loses the "under the
desk" framing. A gesture can now be **keyed** (`OccupantConstants.GESTURES[...].keys`, `OccupantGestureFormulas.along`):
waypoints of joint rotations plus `back`, a draw-back of his whole body on the Root joint.

- **Sit-in:** he rolls back 2.8 studs **with his chair** (every client moves the chair art with him), folds so his
  head drops in front of the desk's edge, then rolls in to 0.5 studs back: his head ends just inside the lip, upside
  down, the whole face in view. Out (`exit`, TIP_BACK) the same way in reverse, whatever comes next (a catch, an
  ambush).
- **Check:** he stares from the knee-hole's open side (`STARE_SIDE` -1.9) and further out (`STARE_GAP` 3.6), folds
  there clear of the top, then leans in 1.5 studs so his face hangs at the mouth of the spot. Desks and tables. When the
  knee-hole side is blocked (a filing cabinet beside the desk) he stands on the other side and his head tips the
  other way (`peekMirror`, `Spot.side`): tipped the usual way from there it ended behind the drawer pedestal.
- **Supply cabinet:** no gesture; the louvre overlay was still drawn over his face once he opened the door. It now
  goes when the door opens (`HideStore.setDoorOpen`, `HideViewModel.overlay`).
- **Safety net, hider only** (`OccupantClearanceSystem`): the draw-back is scaled to the room behind him (a ray), and
  any part of the hider's own spot that his bent body still meets is faded for that hider until it no longer does.
  In the sampled layouts it never fires (all 20 desks of a layout had room for the full roll back).
- A found hider can be caught from `FOUND_REACH` (3) further than a chase grab, since his stand point is now 6-7
  studs from the huddle.

Before and after frames: `characters/qa/manager-v3/frames/` and the contact sheets beside them.

### Behaviour bugs fixed

| Bug | Root cause | Fix |
|---|---|---|
| Frozen for good (e.g. wedged in a filing cabinet, or a patrol/steer leg that no path reaches) | His NPC kind is costed (the truck box), and a costed mover never steers without a path; patrol legs and the director's steer had no give-up | `OccupantStuckRules`: standing still on a walk for STUCK_SECONDS drops that goal; still stuck, he is lifted to the nearest route point (`unstick`) |
| Re-stared the same spot forever when its stand point was unreachable | The approach's give-up only walked on; the hider stayed "seen", so `known` sent him straight back | The give-up leaves the spot alone and forgets the hider, like an ordinary walk-away |
| Looped stare → check → refused catch → stare | A catch refused at a far stand point left the hider "seen" | The check's end clears the spot and forgets the hider after the catch; `FOUND_REACH` |
| A supply cabinet left standing open | The door was shut only at the check's end; a hider bolting, a sighting or the shift's break skipped it | `OccupantBrainRules.shutDoor`: leaving the open phase any way shuts it |
| Sat with his knees in a hider's huddle, and could push them out "cramped" into his lap | A hider who crawled under a desk while he walked to it was not noticed at the chair | He sits back (SIT_IN_BACK) and holds their push-out, still unaware (no tip) |

### The desk ambush, how to see it

The trigger (`OccupantWorkRules` seated phases, `OccupantStareRules.ambushes`): while he sits typing at a desk, any
crew member within **14 flat studs** (`AMBUSH_RADIUS`; no line of sight needed, any direction, so right behind him
works), anyone in his sight cone (60 studs, 100°, facing the desk), or any noise he hears. No minimum typing time, no
cooldown, no chance roll, no menace gating; only a hider is never counted. He then holds 1.1 s (head swivelled to you),
stands in 1.2 s, and chases whoever is in his body's sight cone, else investigates where you were and chases as soon as
he turns and sees you. Work breaks come 20-40 s into the shift, then every 35-70 s, last 10-22 s, and are taken at a
desk nobody stands within 10 studs of (often 18-45 studs from the crew), so they are easy to miss: listen for the
typing. `occupantwork` (Admins) sends him to a desk on demand.

### Design questions (not bugs)

- After the ambush he chases only if you are inside his body's sight cone; a player behind him gets a short
  investigation first, though his head turned to them.
- The 14-stud ambush ignores walls: typing in one room, he springs on someone in the next.
- He does not notice a hider under the desk he sits at for an ordinary break (now he only keeps his knees clear).
- STARE_GAP 3.6 puts him further from the spot during the stare and the cabinet check (the face at an opened cabinet
  reads smaller).
