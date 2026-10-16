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
  (runs, from a chase) to the spot's front, **1.6 studs** off its edge, faces it and **stands still for 4–10 s**
  (Noticing face, no cue disc, no line).
- **Then he checks or leaves** (`OccupantStareRules.checks`). The chance to check is
  `0.25 + 0.08 × seconds he had eyes on you`, plus **0.3 if you went in within 12 studs of him**, capped at 0.9.
  A noise within **10 studs** of the spot during the stare makes it certain.
  - **Check:** he bends down to look under (waist and neck gesture, 1.1 s, Hunting face), then the catch.
  - **Leave:** he straightens and walks on. He forgets you (`setSeen(false)`) and leaves that spot alone for 25 s.
- **Learnable:** break line of sight early and far, and he likely walks away; duck under a desk right in front of him
  after a long chase and he looks. Keep the crew quiet around you.
- **Tapping out is a valid escape.** He is startled for **0.7 s** before he chases. Sprinting at 23 against his 20,
  you get away if you go at once. That includes tapping out during the bend.
- **Suspicion.** When he arrives at a noise and a hiding spot lies within **10 studs** of it, he walks to the nearest
  spot and stares for **2–4 s**, then moves on. A noise during that stare makes him look.
- While he stands at your spot, the camping push-out (30 s) is held, so it never throws you into his lap.

## 3. Sitting at the desk you are under

- **When:** a stare (known or suspected) on a desk with someone under it, whose chair is on the knee-hole side, ends
  with a **35%** roll. At most **2 per shift**, at least **90 s** apart.
- **The event:**
  - He sits **0.7 studs further back** than at work, so his knees stop at the desk's edge instead of 0.45 into the
    knee-hole (the overlap with the hider's huddle). His shins and shoes fill the hider's peek view.
  - He types for **7–11 s** (the typing is right above you).
  - His head slowly tips down into view under the desk, upside down, still smiling (2.6 s: Calm, then Hunting for
    the last 0.9 s). It holds **1.4 s**.
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
  far desks. He still sees. Then the gauge resets. So busy and calm phases alternate.

## 5. Warning signs in stages

The stages run on each client (`OccupantTellRules.stage`) by the distance to him:

| Stage | Distance | Tells |
|---|---|---|
| far | 45–85 | his footsteps (heard to 85), a pen click every 9–16 s |
| mid | 25–45 | lights within 26 studs of him flicker; now and then a PA chime and a short corporate line on a paper subtitle (each client, 50–100 s apart, 40% chance) |
| near | under 25 | the heartbeat (now 25 studs, was 40), his footsteps, a dread swell that grows as he nears |
| chase | his chase on you | the sting, then the chase music |

- **The PA call-out** (server, everyone hears it): first after 75 s, then every 120–210 s, never in a breather. It
  names the crew member farthest from him ("Pippa. My office."). His next steer, 4 s later, aims at that player's area
  (6–10 studs off).

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
| Occupant | server | Rules | OccupantDirectorRules | Steering toward the crew, the PA call-out, the breather; tracking sight and the menace gauge |
| Occupant | server | Utils | OccupantMindUtils | The shared pieces of his thinking (mode copies, lookups, sight, patrol, chase, stare and work starts) |
| Occupant | server | Utils | OccupantDeskUtils | Which desk he works at, its seat frame, a spot's stand point |
| Occupant | server | Utils | OccupantDirectorUtils | Where to steer him (the crew's area), the far point for a breather, the call-out pick |
| Occupant | server | Utils | OccupantMenaceFormulas | The menace gauge, breather lengths, steer intervals |
| Occupant | server | Systems | OccupantSeatSystem | Seats him on a chair and stands him up (anchor, clipboard, clips) |
| Occupant | server | Systems | OccupantEffectSystem | Carries out a think's effects (body, Hide's seen and hold, catch, PA call-out) |
| Occupant | shared | Utils | OccupantGestureFormulas | The procedural head and waist gestures (swivel, peek, under, tilt) |
| Occupant | client | Systems | OccupantGestureSystem | Lays his gestures over his joints on every client |
| Occupant | client | Systems | OccupantWarningSystem | The staged far and mid tells, his seated typing, the PA lines and call-outs |
| Occupant | client | State | OccupantPaStore | The PA subtitle on screen |
| UI | client | Screens/World | OccupantPaSubtitle, OccupantPaViewModel | The paper PA subtitle |

Changed: `OccupantBrainRules` (now the orchestrator over the Work, Stare and Director rules; the body's settling), `OccupantTypes`,
`OccupantConstants`, `OccupantAssets` (typing, priorities), `OccupantEvents` (`Pa`), `OccupantFaceUtils` (per phase),
`OccupantTellRules` (stages), `OccupantFeedbackUtils`, `OccupantServiceServer`, `OccupantSenseSystem`,
`OccupantRigSystem`, `OccupantCatchSystem`, `OccupantServiceClient`, `OccupantScareSystem`, `OccupantPresenceSystem`,
`OccupantTellSystem`, `HideServiceServer` (`hold`), `EmployeeFaceRules` (stare alerts).

## 8. Placeholder sounds still needed

- `harlowChase`: the chase music (pending since M3).
- `harlowDread`: the near-stage dread swell (a low, slow loop).
- `harlowAmbush`: a short sharp intake for the ambush swivel. Silent until uploaded; the sting covers it.
- PA voice lines are text only (chime and subtitle). Recorded lines could replace them later.
