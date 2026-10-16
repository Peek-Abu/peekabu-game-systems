# Cleanup Crew: the chase kit (an unsafe bay, sprint, hiding spots)

Date: 2026-10-15. The developer approved four changes together. The first one, "clean it where you find it", is in the
[loot loop design](2026-10-15-cleanup-crew-loot-loop-design.md) §3.2a. This note covers the other three. They change the
[MVP design](2026-10-10-cleanup-crew-design.md) §4 "Mr. Harlow". Every number is a tuning hypothesis kept in a Data
constants module.

## 1. Why

The loading bay was a hard safe zone. The Manager could not path into it, see anyone in it or hear anything in it. So
the bay was where you cleaned, waited and caught your breath. Once cleaning moved to "where you find it", the bay had to
stop being a free room. The crew also had no way to answer a chase except by walking at 16 against his 20. Sprint gives
them a few seconds to break line of sight, and the hiding spots give them somewhere to break it to.

## 2. The loading bay is no longer safe

- **Only the inside of the truck's box is safe.** That is the bed's footprint, from the bed's top to the truck's top
  (`OfficeLoadingBayUtils.truckBox`, `OfficeServiceServer:safeZone`). Nobody inside it is seen, heard or caught. The
  `SafeZone` pathfinding volume now covers only the box, so he never paths into it. The ramp and the bay floor are
  open ground.
- **He patrols through the bay.** Each generated route visits a bay patrol point once
  (`OfficeLoadingBayUtils.patrolPoint`, on the open side away from the truck). It goes from the room the bay door opens
  into, then back to it. `OfficeLayoutRules.checkRoute` now allows route points in the bay, but none on the truck or its
  ramp. The rest point must still be outside the bay.
- **He never lingers.** He may chase, investigate and catch in the bay. But after **8 s** in it
  (`BAY_LINGER_SECONDS`) with nobody in sight, he sighs and walks to the nearest route point outside it. Then he keeps
  out of the bay for **20 s** (`BAY_COOLDOWN_SECONDS`): no bay noises, no bay route points. So he cannot body-block the
  ramp. A chase in the bay is not cut short: the timer only acts once he has lost sight of everyone.
- **Flows checked:**
  - Clock out and the overtime sheet are inside the box, so they stay safe.
  - Banking needs you on the bed, so it is safe too. The walk up the ramp is not.
  - A respawn lands in the bed (`arrivalFrame`), inside the box (specced), and the 10 s catch grace is unchanged.
  - The Manager's break after the quota still ignores everyone, wherever they are.
- Shift's analytics "in the bay" flag now reads the whole bay (`OfficeServiceServer:loadingBay`).

## 3. Sprint

Revised 2026-10-15 after the developer's review: carrying no longer forbids a sprint, it slows it, and the stamina bar
became a paper slip by the equipment cards.

- **Controls:** hold Shift or L3 (the base `sprint` action, already bound), or hold the phone's SPRINT button. That
  button has its own spot in the action arc, up and left of DROP, so both can show at once. The desktop hint row gains
  "Hold Shift sprint".
- **Rule (`SprintRules`):** you must ask, be alive, not be frozen in a catch and not be hiding. The bar must also allow
  it. Your hands may be full.
- **Speed (`SprintSpeedFormulas`):** sprint = 23 × (carried walk speed / 16). It is computed through Carry's own
  formula (`CarryFormulas.carrierSpeed`), so the load slows the sprint by exactly the factor it slows the walk:

  | In hand | Walk | Sprint | Against his chase of 20 |
  |---|---|---|---|
  | nothing | 16 | 23 | gains 3 a second |
  | tiny or light (weight 1.5) | 14.8 | 21.3 | gains 1.3 a second |
  | medium (4) | 12.8 | 18.4 | loses ground |
  | heavy (7) | 10.4 | 15 | loses ground |
  | bulky (10) | 8 | 11.5 | loses ground |

  So only a light load can still outrun him. His chase is 21 at the top tier with a crew and 19.5 solo.
- **Stamina (`SprintStaminaFormulas`):**
  - It drains only while you are actually moving at a sprint. A full bar lasts **4.5 s**, a lead of about 9-13 studs
    empty-handed.
  - It refills **1 s** after the last drain, from empty to full in **4 s**.
  - Run it dry and you cannot sprint again until it is back to **30%**, so you can't stutter-sprint on a sliver.
  - The design: outrun him for a few seconds, then break line of sight or hide.
- **Server-authoritative:**
  - The client only says the key is held (`SprintEvents.Sprint`, rate limited).
  - Every 0.05 s the server applies the rule and sets WalkSpeed itself, for whatever is in the hands at that moment.
    It publishes the bar as the Player's `SprintStamina` / `Sprinting` attributes.
  - Carry is given the unboosted walk speed (`CarryServiceServer:setSpeedBase`), so a pick-up or a drop mid-sprint
    leaves Carry's walk speed right. When the sprint ends, you walk at your own speed slowed by your load.
- **HUD (`SprintStaminaSlip`):** a small cream paper slip headed "WIND" with a row of ten punch-card boxes, inked in
  teal as far as the bar reaches and stamp red under 30%. It is tucked just above the bottom-right equipment cards on
  desktop, and under the top-right tool card on phone. It shows only while the bar is not full.
- **Noise (the decision):**
  - **Sprinting feet are heard; walking stays silent.** A noise of radius 14 (before his hearing scale) every 0.7 s
    while moving at a sprint.
  - Why: a sprint is the escape tool, so it should cost something. The cost is that he can follow a fleeing player
    round a corner if he is close. A radius of 14 is about a third of the vacuum's 40, so once you break line of sight
    at range, a short sprint is not heard. Walking and plain running stay silent, so ordinary play is never punished.
  - The ripple shows the crew that sprinting is loud.

## 4. Hiding spots

Revised 2026-10-15 after the developer's review: desks and tables only (a locker's or cabinet's open and closed states
made them risky); hidden players stay visible to their crew, in a clear tucked pose; going in and out is a single tap.

- **Where:** every desk and every table, under it. These are the office's own furniture, so there are no new props:
  - Office tags the desks it builds (`OfficeBuildSystem`) and the art-only tables once their art attaches
    (`OfficeDecorSystem`). Lockers and filing cabinets are not tagged.
  - `HideSpotSystem` gives each tagged piece one spot: an Attachment on its front holding a ProximityPrompt.
  - A desk's front is always its knee-hole. A table's front is whichever long side has more open floor
    (`HideSpotUtils.spotFrame`), so the peek and the way in and out face the room.
  - The office rebuilds each shift, and the spots follow it.
- **In:** **one press of C** (L1 on a gamepad), or a tap on the phone's chip, within **6 studs**. It has its own key,
  so it never takes E from a desk's Search. The paper chip ("[C] HIDE UNDER desk") sits one slot above the interaction
  chip. The server re-checks everything (`HideRules`):
  - you are alive and not frozen in a catch;
  - you are not already hidden;
  - the spot is free and not cooling off for you;
  - at least **1 s** has passed since your last stay ended;
  - you are in range;
  - your hands are empty, or hold a small (tiny or light) item (2026-10-16: the hotbar inventory's small sizes).

  Anything bigger stops you, and picking one up while hidden pushes you out.
- **The body, and what the crew sees:**
  - The root is anchored and slides into the spot in **0.25 s** (a tween, not a teleport). It stands at standing
    height (`HideSpotUtils`).
  - Every client folds the body into a tucked huddle over the same 0.25 s (`HidePoseSystem`, `HidePoseFormulas`,
    `HideConstants.TUCK_POSE`): kneeling on the heels, the torso folded over the knees, the head bowed (the ears follow
    it down) and the arms along the body.
  - The pose is laid over the animation on each joint in `PreSimulation`. Out, it unfolds in 0.2 s.
  - Under a desk the body lies corner to corner across the knee-hole, clear of the drawer pedestal. Under a table it
    lies along the length.
  - The spot's prompt closes for everyone. The Player's `HideSpotId` / `HideSince` attributes tell every client.
- **The peek view:**
  - The camera goes to the spot's peek frame: low, looking out from under the front edge.
  - The mouse looks about ±35° / ±12°.
  - Your own body is hidden from you, the controls are off, and other prompts are off.
  - An overlay frames the view: the dark underside of the furniture above.
- **Out:** one tap of C, E or Jump, or a tap on the chip. Not before **0.5 s** in the spot, so a tap in and out can't
  be spammed. The body comes out where you went in, else at the first clear exit: in front, then behind, then either
  side.
- **Anti-camping:**
  - After **20 s** in one spot the chip turns into a warning: "CRAMPED · out in 10s".
  - At **30 s** you climb out (a sticky note says why).
  - That spot then refuses you for **10 s**, so you have to move to another spot rather than re-enter.
- **The Manager and hiding players:**
  - A player who goes in while he sees them, or while he is chasing them, is **"seen entering"**. Hide asks his witness
    at that moment (`setWitness`).
  - Unseen, he cannot see them at all: the brain skips them and a catch is refused ("hidden").
  - Seen, he knows exactly where they are, through the furniture. He comes to the spot, drags them out (`evict`) and
    catches them. This is today's baseline for what the coming behaviours will refine.
- **API for the coming behaviours** (stare-down, opening the spot, sitting at the desk you are under, the director),
  on `HideServiceServer`:
  - `isHidden(player)`
  - `spotOf(player)` returns the spot's id, kind, noun, furniture part, position, since, and seenEntering.
  - `seenEntering(player)`
  - `setSeen(player, seen)`
  - `evict(player, reason?)`
  - `spots()` lists every spot with its furniture and its frame.
  - `occupantOf(spotId)`
  - `enter(player, spotId)`, the same checks, for tests and admin.
  - the `entered(player, info)` and `exited(player, spotId, reason)` signals.

## 5. Modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Hide | shared | Data | HideConstants | The furniture kinds, tags, attribute names, keys and tuning |
| Hide | shared | Data | HideTypes | Spot, frames, occupancy, entry input, exit reasons, spot info |
| Hide | shared | Net | HideEvents | The Exit request |
| Hide | shared | Rules | HideRules | Who may go in; how a stay is going (ok, cramped, out) |
| Hide | shared | Utils | HideSpotUtils | A spot's frame (facing the room), its hiding, peek, prompt and exit frames |
| Hide | server | root | HideServiceServer | Enter, exit, camping, the witness, the public API |
| Hide | server | State | HideOccupancyTracker | Who hides where, since when, seen or not; spot cool-offs |
| Hide | server | Systems | HideSpotSystem | One spot and prompt per tagged piece of furniture |
| Hide | client | root | HideServiceClient | The paper prompt, the peek camera, coming out |
| Hide | client | State | HideStore | The prompt shown and the spot the player hides in |
| Hide | client | Systems | HidePoseSystem | Every hiding player's tucked pose, on every client |
| Hide | client | Utils | HidePoseFormulas | The tucked pose's joint transforms, its easing and blend |
| UI | client | Screens/Hide | HideViewModel, HideChip, HidePeekOverlay | The chip's words and the overlay |
| Sprint | shared | Data | SprintConstants | Speed, stamina and noise tuning, names |
| Sprint | shared | Net | SprintEvents | The held-key request |
| Sprint | shared | Rules | SprintRules | Whether a player sprints now; whether the button shows |
| Sprint | shared | Utils | SprintStaminaFormulas | The stamina bar |
| Sprint | shared | Utils | SprintSpeedFormulas | The sprint speed for a load (Carry's own formula) |
| Sprint | server | root | SprintServiceServer | Applies the rule, owns the speed, the bar and the footstep noise |
| Sprint | client | root | SprintServiceClient | Sends the held key, mirrors the bar |
| Sprint | client | State | SprintStore | The bar as the HUD sees it |
| UI | client | Screens/Sprint | SprintViewModel, SprintStaminaSlip | The stamina slip |

Changed:
- `OfficeLoadingBayUtils`: `truckBox`, `patrolPoint`.
- `OfficeLayoutGenerationUtils`: the bay patrol point in the route.
- `OfficeLayoutRules.checkRoute`.
- `OfficeBuildSystem`: the safe volume over the box, desks tagged.
- `OfficeDecorSystem`: tables tagged.
- `OfficeServiceServer`: `safeZone` is the box, plus `loadingBay`.
- `OccupantBrainRules`: the bay rule, hidden glimpses, `witnessed`.
- `OccupantCatchRules`: "hidden".
- `OccupantSenseSystem`: `markHidden`, `inView`, `senses`.
- `OccupantServiceServer`: the bay, the witness, evict on catch.
- `OccupantTypes` and `OccupantConstants`.
- `CarryServiceServer`: `setSpeedBase`.
- `CarryFormulas.carrierSpeed`.
- `ShiftHudViewModel`: the SPRINT button (its own arc spot) and the sprint hint.
- `ShiftMobileButtons`.
- `ShiftHud` and `ShiftCompactHudPanel`: the stamina slip by the equipment cards.
- `CargoConstants`: the unused `NO_SPRINT` list removed (no size forbids a sprint now).
- `ShiftAnalyticsWatchSystem`.

## 6. Open questions for the developer

- Seen entering currently means he comes and drags you out. The coming behaviours (stare-down, opening the spot) will
  replace or soften that.
- The tucked pose is tuned for the employee rig (its big head and ears). A rig with other proportions needs
  `HideConstants.TUCK_POSE` and the furniture tucks re-checked.
