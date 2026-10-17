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

## 10. Awareness: peripheral vision and the head turn (2026-10-17)

**The report.** Pushed out of a desk by "cramped" (HideConstants CAMP_SECONDS, 30 s), the player stood right beside
him in the same room and he carried on. He only saw a 100° cone (60 studs) and a 40° long cone (125 studs), and
coming out of a hiding spot made no noise at all. The developer approved options 1 + 2: peripheral vision, and a
noise-driven head turn as his signature "I noticed something" tell. Every number below is in `OccupantConstants`
(or `HideConstants` for the noises), tuning hypotheses as ever.

### 10.1 Peripheral vision

- The front cone is unchanged: **100°, 60 studs, seen at once**; the long cone too (40°, 125 studs, 0.35–1.4 s).
- **The peripheral zone** (`OccupantSightUtils.peripheral`): outside the front cone but within **200° total (±100°)**
  of his heading (`PERIPHERAL_ANGLE`), within **25 studs** (`PERIPHERAL_RANGE`), with a clear line of sight. Never a
  hidden player, one in their grace, or anyone in the truck's box.
- Someone there is **noticed slowly** (`OccupantSightUtils.glanceDelay`): **1.5 s** at his side rising to **2.5 s** at
  25 studs (`GLANCE_SECONDS`, linear in the distance), **×1.4 crouched** (`GLANCE_CROUCH`; the character's `Crouching`
  attribute, which nothing sets yet, so dormant). At 12 studs, about 2.0 s.
- Only the nearest player in the zone is counted (`Mind.glanceId`, `glanceSeconds`); another becoming nearest starts
  from 0. Out of the zone, the count falls back **2 s a second** (`NOTICE_DECAY`, as the long cone) and is dropped at 0.
- He keeps walking while it counts (no tell). In patrol, investigate and search only (as the long cone).
- When it completes he does **the head turn** at them, never an instant chase.

### 10.2 The head turn (a new mode, `alert`)

- **Triggers.**
  - A peripheral notice completing (at that player).
  - A noise he hears (through `NoiseRules`, the hearing scale and the breather's `BREATHER_HEARING`, as before) from
    **outside his front cone** (more than 50° off his heading), while he patrols or investigates. A noise in front of
    him is investigated as before. A search still re-aims at a noise directly (he is already hunting and running), after a quick head snap
    to it: **0.2 s** (`SEARCH_SNAP`) with his head swivelled there and no move, then the run (the developer, 2026-10-17).
- **The turn.** He stops dead (no move) and turns **only his head** to the point: the desk ambush's 180° `swivel`
  on the long neck (0.35 s), the Noticing face. He holds **1.0–1.4 s** (`TURN_HOLD`, rolled per turn; 0.6–1.0 until the developer added 0.4 s, 2026-10-17) after the swivel
  lands (`TURN_SWIVEL` 0.35 s), so the check comes **1.35–1.75 s** after the trigger. While he holds, his head follows
  the peripheral player as long as he can still see them that way.
- **The check** (`OccupantSightUtils.toward`): anyone not hidden with a clear line, within **60 studs**
  (`SIGHT_RANGE`), inside a **100° cone** (`SIGHT_ANGLE`) around the direction his head turned. The player who
  triggered it is preferred, then the nearest. Found: **the chase** (the usual "spotted" cue and menace jump).
- **Not found** (they hid again, or stepped behind a wall): he **investigates the point** (the usual walk, "curious",
  look around, the suspicion stare at a spot by it).
- Anyone who walks into his front cone during the hold is chased at once ("sight beats everything"). Other noises
  during the hold are ignored. The shift's break cancels it as it cancels everything.
- **Fairness.** The hold is the player's window: from the trigger they have ~1.35–1.75 s to get out of that cone or into a
  hiding spot. Going into a spot during the hold is not "seen entering" (his body never turned), so he investigates
  and may stare at the spot on a suspicion, as for any noise by the spots.
- Replicated as the mode `alert`: the client's dread reads it as **aware** (`OccupantDreadFormulas` HUNTING), the
  crew's faces as alarmed (`EmployeeFaceRules`), his face Noticing; `harlowAmbush` plays from his head as he turns.

### 10.3 New noises (Hide, relayed by `NoiseServiceServer`)

- **Leaving a spot yourself** (`left`): radius **9** (`EXIT_NOISE`), from where you come out.
- **Pushed out by "cramped"** (`cramped`): a "tumble out", radius **19** (`CRAMPED_NOISE`), plus a short sound for
  everyone near (`hideTumble`: the in-house body-fall C at 0.45 volume, rolled off by 45 studs). PLACEHOLDER: a
  dedicated "tumble out of the furniture" sound is to be made.
- Evicted, caught, gone: no noise (another rule already handles those moments).
- `HideRules.exitNoise(reason)` gives the radius; `HideServiceServer.noiseMade` fires it, `NoiseServiceServer`
  relays it like Vacuum's and Cargo's (sources `hideExit`, `hideTumble`).
- So the reported case now plays: pushed out beside him → a 19-stud noise from his side → the head turn → he sees
  you → the chase. A voluntary exit is heard only within 9 studs × his hearing scale (1 at tier 0 with a crew; it grows with the
  tier and for a solo player), so one across the room is not heard.

### 10.4 The desk ambush, folded in

- **Trigger:** a noise he hears, a player he sees (his body's cone), or a player within **14 studs with a clear line
  of sight** in any direction (`AMBUSH_RADIUS`). It no longer works through walls.
- **After it** (the head swivel and AMBUSH_HOLD 1.1 s, unchanged, are the head turn): he chases anyone he sees in
  his body's cone **or in the cone his head is turned to** (`OccupantSightUtils.toward`), else investigates the point.
  A player right behind him is now chased, not investigated.
- During a sit-in a noise at the spot still marks the hider (the certain catch) only while they are still under it:
  the hider bolting makes their exit noise, and that is an ambush.

### 10.5 How it composes

- **Director:** `alert` is not patrol, so no steer or work break starts during it; the menace gauge moves as usual
  (a chase from it bumps MENACE_SPOTTED). On a breather a turn needs a noise within BREATHER_HEARING (20); sight
  (and so the peripheral notice) still works.
- **Stare-down / sit-in / ambush:** unchanged triggers inside their modes; the stare's own noise handling is first.
- **Chase / search:** the turn's chase is the ordinary chase; losing them goes to the ordinary search.
- **Several players:** one turn at a time, at one point; the check takes the triggering player, else the nearest in
  that cone.
- **Hide's witness** stays the body's sight (near or far cone), not the peripheral zone or the turned head.

### 10.6 Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Occupant | server | Rules | OccupantAlertRules | The head turn: the peripheral notice, whether a noise turns his head, the alert mode's think |
| Hide | shared | Data | HideAssets | The hide feature's sounds (the tumble), registered at load |

Changed: `OccupantSightUtils` (`peripheral`, `glanceDelay`, `toward`, `beside`), `OccupantMindUtils`,
`OccupantBrainRules`, `OccupantWorkRules` (the rise), `OccupantStareRules` (`ambushes`), `OccupantTypes` (`alert`,
`glanceId` / `glanceSeconds`, `Glimpse.crouched`), `OccupantConstants`, `OccupantSenseSystem` (crouch),
`OccupantFaceUtils`, `OccupantDreadFormulas`, `OccupantWarningSystem` (the turn's sound), `EmployeeFaceRules`,
`HideRules`, `HideConstants`, `HideServiceServer`, `NoiseServiceServer`, `HidePoseSystem` (registers the sound).

## 11. The slow turns: "I know you're there" and the staring contest (2026-10-17)

**The approval.** The developer approved two rare slow-turn variants of the head turn (§10.2) on the same head-swivel
rig. The quick snap (0.35 s, then the 1.0-1.4 s hold) stays the common case. Every number is in `OccupantConstants`
(`SLOW_*`, `STILL_*`, `WHIP_SECONDS`, `JERK_*`, `CERTAIN_*`, `KNOWING_*`, `STARE_*` and `DREAD.LOOKS.slowTurn`), tuning
hypotheses as ever.

### 11.1 Which turn: snap, knowing or stare

Every head turn picks its variant once, as it starts (`OccupantTurnRules.pick`). That covers the §10.2 head turn (a
completed glance, or a noise from beside or behind him) and the §1 desk ambush.

1. **A target he is certain of.** The candidate is the turn's player: the glance's player, the ambush's nearest
   player, or else the nearest player down the cone toward the point. They count only when both hold:
   - they are not hidden, not in their grace and not in the truck's box, and he has a clear line to them;
   - they are within **14 flat studs** (`CERTAIN_RANGE`, the ambush radius), or he had them in sight a moment ago
     (`watched` at least **0.5 s**, `CERTAIN_WATCHED`; it decays 0.5 s per second).

   That covers the three approved cases: a player right behind him at his desk; a player pushed out "cramped" next to
   him (its 19-stud tumble turns his head and they are within 14 studs); and a player coming out of a spot he just
   saw them go into. With no such target, the turn is the **snap**.
2. **Gates.** Each of these must hold, or the turn is the snap:
   - he is not on a breather;
   - the previous head turn was a snap (`lastTurn`), so two slow turns never come in a row, in either order;
   - at least **60 s** have passed since the last slow turn (`SLOW_GAP`).
3. **The staring contest (the rarest).** It is picked when all three hold:
   - nobody in the crew has had one this shift (`stared`);
   - the menace gauge is within **20-70** (`STARE_MENACE`: tension has built but is not peaking);
   - its roll is under **0.35** (`STARE_CHANCE`).
4. **The knowing turn.** Otherwise it is picked when all three hold:
   - this player has not had one this shift (`knowingFor`);
   - menace is at most **70** (`KNOWING_MENACE_MAX`);
   - its roll is under **0.5** (`KNOWING_CHANCE`).
5. **Else the snap.** The rolls are `Senses.rolls[5]` (stare) and `[6]` (knowing). With no rolls (0.5 each) neither
   is picked.
6. **A developer's force.** `occupantturn <snap|knowing|stare|auto>` (Admins) makes the next head turn that variant,
   skipping the gates, rolls and certainty. It still needs a player he can see. If the caller is in his view, the
   turn starts at once at the caller.

### 11.2 The slow turn (both variants)

- **His body.** He stops dead. Standing, he goes into mode `alert`; seated at a desk, he stays in `work`, with the
  typing stopped dead. The phase is `slowTurn`, the turn's player is his `target`, and his head follows them.
- **The turn.** His head turns slowly and deliberately to them over **2.0 s** (`SLOW_TURN_SECONDS`), as the gesture
  `slowSwivel` (smootherstepped).
  - His waist leads with **20 %** of the yaw (`SLOW_WAIST_SHARE`), all of it by 60 % of the turn, and the neck carries
    the rest. So the shoulders come round first, then the long neck, and **the smile comes round last**.
  - The face stays **Calm** (the customer-service smile) through the turn and the stare.
- **Its sound.** A slow porcelain creak from his head (`harlowCreak`) replaces the snap's intake. It is stopped with a
  0.08 s fade if the turn is cut short.
- **The dread.** Within dread range the stage is **aware** at full strength, with no proximity scaling
  (`OccupantDreadFormulas.slow`), using the `slowTurn` look:
  - the heart at 1, beating faster (**0.5 s**, `BEAT_SLOW`), and the dread loop at 0.5;
  - the office and chase music ducked **-30 dB** to near-silence and muffled -12;
  - a stronger vignette.
- **The lights.** Lights within **34 studs** (`SLOW_FLICKER_RADIUS`, against the usual 26) flicker with the existing
  flicker, but darker: dark much more often (`SLOW_FLICKER_THRESHOLD`).
- **What counts as moving.** Any meaningful movement, never a camera turn:
  - a flat speed of at least **2.5 studs/s** (`STILL_SPEED`), or
  - drifting at least **1.25 studs** from where they stood (`STILL_DISTANCE`; measured in 3D, so a jump counts).
- **The settle.** For the first **0.35 s** (`SLOW_SETTLE`), the point they "stood" at follows them, so a player who
  hears the creak can still freeze. A player still walking when the settle ends is chased then.
- **Moving mid-turn.** It ends the turn early. On that think his head whips the rest of the way (`whip`, **0.15 s**,
  `WHIP_SECONDS`), and the jerk (11.4) starts the chase at once.
- **Hiding or breaking the line before the turn ends.** He **searches** from where they were, running: the ordinary
  search (the last-seen point, then the nearby route points).

### 11.3 How each variant ends

- **The knowing turn.** If they stay still to the end of the 2.0 s: the jerk and the chase.
- **The staring contest.** The turn completes, then comes phase `staring`: his head on them and no movement at all,
  for a rolled **4-7 s** (`STARE_CONTEST_SECONDS`). Then:
  - **The target moves:** the jerk and the bolt.
  - **Another crew member moves** where he can see them (a clear line, within `SIGHT_RANGE`, inside `SIGHT_ANGLE`
    toward the point his head looks at): the jerk and the bolt at **them**. Each watched player's standing point is
    taken when he first sees them there. Players he cannot see never set him off.
  - **Nobody moves for the whole stare:** the jerk and the bolt at the target anyway.
  - **The target hides or breaks the line:** he searches.
- **Sight beats everything, as ever.** Anyone walking into his body's front cone meanwhile is chased at once.

### 11.4 The jerk (wherever a slow turn ends in a chase)

He never bolts with his head still twisted backwards. On the trigger think he goes straight into the chase (mode
`chase`, phase `jerk`). On that frame:

- **His body.** The server turns his root to face the player over **0.13 s** (`JERK_SECONDS`, ease-out, per frame:
  `OccupantSeatSystem.jerk`). His head stays locked on them in world space, so the body snaps round under an
  already-turned head.
- **Seated.** He pops up: the stand clip at **8x** (`JERK_STAND_SPEED`, 0.225 s), head still on them.
- **His face** goes to **Hunting** (the smile widens) on the same attribute write.
- **The sound.** A sharp porcelain crack (`harlowCrack`) from his head and the chase sting land together. Both fire
  from the same replicated change, on the client's Heartbeat.
- **The run.** A full-speed chase with no wind-up and no startle. The intent is the run, or the grab within reach.
- **Watching every frame.** While he watches, the server checks for movement every frame: `OccupantServiceServer`'s
  Heartbeat runs his brain then, not only on the 0.15 s NPC think. So the trigger is at most a frame late. The jerk
  (and any chase start) wakes the NPC (`NpcServiceServer:wake`), so the run starts on its next frame: while the path
  computes he heads straight at a player in clear line, and the route takes over when it arrives.
- **Afterwards.** The phase clears after `JERK_SECONDS`, leaving an ordinary chase.

### 11.5 Replication and the client

- **Phases.** `slowTurn` and `staring` (in `alert`, or in `work` at a desk) and `jerk` (in `chase`) ride the existing
  phase attribute. No new attribute or packet is needed.
- **Gestures.** `slowSwivel` (the turn and the stare) and `whip` (the hurried rest of a turn, and the jerk) ride the
  gesture attribute. `OccupantGestureSystem` carries one turn fraction across them, so a whip continues from wherever
  the slow turn got to.
- **Several players.** One turn at a time, at one target. Others moving matter only during the stare, and only when
  he sees them move. Each client's dread follows his mode and phase, so everyone near him gets the silence.

### 11.6 Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Occupant | server | Rules | OccupantTurnRules | The slow turns: which variant, the slow turn's and the stare's think, the watch for movement, the jerk |

Changed modules:

- **Occupant rules:**
  - `OccupantAlertRules`: `begin` picks the variant; `think` hands slow turns over.
  - `OccupantWorkRules`: the ambush picks the variant too; seated slow turns.
  - `OccupantBrainRules`: the jerk's phase settles; a seated jerk stands fast.
- **Shared data and formulas:**
  - `OccupantTypes`: phases, `TurnKind`, the mind's turn fields, `Glimpse.speed`.
  - `OccupantConstants`.
  - `OccupantGestureFormulas`: `slowSwivel` and `whip`, the waist lead.
  - `OccupantDreadFormulas`: `slow`.
  - `OccupantTellRules`: the harder flicker.
  - `OccupantFaceUtils`: Calm through a slow turn.
  - `OccupantAssets`: `harlowCreak` and `harlowCrack`.
- **Server systems and service:**
  - `OccupantSenseSystem`: speed.
  - `OccupantSeatSystem`: `jerk`.
  - `OccupantServiceServer`: the per-frame watch, `forceTurn`.
- **Client systems:** `OccupantGestureSystem`, `OccupantWarningSystem` (the creak and the crack), `OccupantTellSystem`
  and `OccupantDreadSystem`.
- **A new command:** `occupantturn` (Cmdr, Admins).
