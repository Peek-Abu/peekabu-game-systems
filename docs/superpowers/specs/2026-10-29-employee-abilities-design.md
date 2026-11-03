# Employee abilities — design (2026-10-29)

Status: **approved by the owner on 2026-10-30** with these answers: the plant uses Hide's rule (a witness is not fooled); treasure includes buried grimy items; the new Ability feature is approved.

## Why

Each employee card promises an ability. Today the abilities are text only: `EmployeeProfileRegistry` marks them
"DISPLAY ONLY". On 2026-10-29 the owner approved the three animation drafts and asked for the abilities to work in
real play. The owner wants **Potted Plant** to be a general **stealth** move that works against every monster built on
the shared Npc layer, not a Manager trick.

## Goals

- One press per employee: **Q** on a keyboard, **Y** on a gamepad, and a round button on a phone.
- The server owns everything. The client only asks. The server checks the request, runs the cooldown and makes every
  effect happen.
- Three launch abilities that do what the cards say:
  - **Pippa, "Let's Go!"** (45 s): Pippa and the crew near her run faster for 4 s.
  - **Cappy, "Spot It!"** (40 s): Cappy alone sees the closest treasure through walls for 5 s.
  - **Prickles, "Potted Plant"** (45 s): he stands still as a potted plant for up to 8 s. While he does, no monster can
    see him or catch him.
- Stealth lives in the shared Npc layer, so any future monster gets it for free.
- The HUD shows a cooldown and uses kid-level words.
- Animations play on top of gameplay. They never hold up an effect or cancel one.

## Non-goals

- No new abilities beyond these three, no upgrades, no ability shop.
- No VFX polish. Effects are functional and drawn in the current style. Real polish is a later phase.
- No fixes to the Manager bugs in the backlog (wide turns, chases through walls, chases from sound alone). Nothing here
  touches his turning, his sight ray or his noise handling.

## Anti-goals

These count as failure even if everything else works.

- **Speed that leaks or stacks.** A boost that stays after it ends, gets baked into sprint or crouch, or multiplies
  when it is re-cast.
- **Plant stealth that only fools the Manager,** or that a monster can still catch.
- **An animation that blocks the effect.** For example, the boost waiting for the clip, or a cancelled clip ending the
  plant.
- **The client deciding anything,** such as which treasure is closest, whether the plant is still on, or whether the
  ability is ready.

## Activation

- **Input.** A new `ability` action goes into `InputActionRegistry` (gameplay context): keyboard `Q`, gamepad
  `ButtonY`. Both are free today. The player can rebind it through the existing `keybinds` setting.
- **Phone.** A new spot on the Shift phone arc (`ShiftHudViewModel.arcFor`). It uses `ShiftActionButton` with the
  ability's icon and a new cooldown ring. Like the other phone buttons, it only shows while the shift is running.
- **Network.** A new `AbilityEvents` ByteNet namespace with three packets:
  - `Use` (client → server, no payload).
  - `Cancel` (client → server, no payload): ends the plant. The client sends it on any move or action input so the
    plant ends at once. The server still checks on its own; see Potted Plant.
  - `Spotted` (server → that one client): the Spot It target, `{ cargoId: uint32 }`.

  Both client packets go through `RequestHandler.wrap` with a rate limit.

## Server: the ability service

`AbilityServiceServer` does the following.

- **Which ability.** Reads the employee the player is playing (the character's `EmployeeName`) and looks it up in
  `AbilityRegistry`.
- **Checks a `Use` request** with `AbilityRules.canUse`. All of these must hold:
  - the shift is running;
  - the player is a participant, alive, not dead, not being caught, and not hiding;
  - the cooldown is over;
  - the ability's own check passes:
    - **Plant:** on the ground, and nothing in his hands. Pocketed items are fine.
    - **Spot It:** there is a treasure to show.

  A refused request costs no cooldown. The player sees a short toast in kid words, for example "Not ready yet!",
  "Nothing to find!" or "Put that down first!".
- **Cooldown.** `AbilityCooldownTracker` holds the cooldown per userId. It starts at the moment of use and survives a
  respawn. Every ability is ready when a shift starts.

  The service publishes the ready time on the Player as the attribute `AbilityReadyAt` (server time,
  `Workspace:GetServerTimeNow()`). This follows the Sprint and Hide pattern. The HUD draws the cooldown ring from it.
- **What is running.** The character's `AbilityActive` attribute holds the ability id while its effect runs. Other
  clients read it for visuals.
- **The numbers** live in `AbilityRegistry`: cooldown, duration, radius and speed scale. The profile card reads its
  cooldown number from there, so the card and the game can never disagree. The card text stays in
  `EmployeeProfileRegistry`.

## Pippa — Let's Go!

**Who gets the boost.** Pippa, plus every round participant whose root is within **20 studs** of her when she presses
(my call). Each of them must be alive and not being caught. Players who are hiding get it too; it does nothing until
they leave the spot.

**The boost.** A speed scale of **×1.25** (my call) for 4 s:

| | Normal | With the boost |
|---|---|---|
| Walk | 16 | 20 |
| Sprint | 23 | about 29 |

Carry slowdowns still apply on top.

**Where it lives: the Sprint feature.** Today three services each write `WalkSpeed`: Sprint, Crouch and Carry. Each one
works out a "base" walk speed by reading the current `WalkSpeed`. A boost that simply wrote `WalkSpeed` would get read
back as the new base and stay on for good. That is a stacking bug. The root fix:

- `SprintServiceServer` holds the one speed boost per player: `boost(player, scale, untilTime)` and
  `speedScale(player)`. The data sits in a new `SprintBoostTracker`.
- **No stacking.** A new boost while one is on keeps the bigger scale and the later end time. It never multiplies.
- **One formula.** Every place that writes `WalkSpeed` multiplies its result by `speedScale`:
  - Sprint's `SprintSpeedFormulas.speed`;
  - Crouch's stand and crouch speeds;
  - Carry's `CarrySpeedSystem.applyTo`, through the speed-base hook Sprint already registers with Carry.
- **Base reads.** Every place that reads a base back from `WalkSpeed` divides the scale out. Then the base can never
  include the boost.
- **Expiry.** Sprint's tick, which already runs every 0.05 s, re-applies the plain speed the moment the boost ends.
  Removing the character clears the boost.
- Specs pin the invariant: start a boost, then sprint, crouch, pick up, drop, and let it end. The walk speed always
  returns to exactly what it was before.

**What players see.** The boost sets the character attribute `SpeedBoostUntil` on each boosted player. Every client
draws a speed trail on those characters, so the crew sees who got it. Pippa gets an orange burst ring and a whistle
chime.

**Animation.** If Pippa is standing still, the server plays the full-body `Pippa_LetsGo` clip. If she is moving, it
plays the upper-body clip instead. Moving, jumping, falling, being hit, interacting or dying cancels the full-body clip
(a 0.12 s fade). None of that touches the boost: the boost is applied before the clip starts.

## Cappy — Spot It!

**What counts as treasure (owner-approved).** A **grimy** cargo item, meaning one of the valuables shown as "$???".
The item must:

- be tagged `Carryable` and have a `CargoId`;
- not be claimed or carried;
- **include** items buried under a dust pile (`CargoHidden`). Then the glow shows him which pile to vacuum.

Items still inside unsearched desks and lockers do not exist yet, so they never count.

**How the target is picked.** The server picks the closest one by straight-line distance from Cappy, anywhere in the
office. It sends `Spotted { cargoId }` to Cappy only.

**What Cappy sees.** His client draws a gold `Highlight` with `DepthMode = AlwaysOnTop` on the item, plus a small
sparkle billboard, for 5 s. Both end early if the item is picked up or removed. The item already replicates to every
client; only the highlight is local. If nothing qualifies, the request is refused with "Nothing to find!" and no
cooldown.

**Animation.** None until the char-anim-rework session delivers the v6 Spot It clip. The registry keeps a placeholder
entry that plays nothing, so the effect, sound and HUD all work without the clip. Adding the id later is a one-line
change.

## Prickles — Potted Plant (general stealth)

### Stealth in the shared Npc layer

- **API.** `NpcServiceServer` gains:
  - `conceal(player, source)`
  - `reveal(player, source)`
  - `isConcealed(player)`

  The data sits in a new `NpcConcealTracker`. A player can be concealed by more than one source at a time; they are
  concealed while any source holds them.
- **Generic monsters.** `NpcBehaviourSystem` drops concealed players from its sight list, both for chasing (`hostile`)
  and for fleeing (`timid`). A monster that is chasing a player who becomes concealed stops seeing them. It keeps its
  existing memory (`loseSightTime`) and then gives up. Every future monster that uses the default brain gets this for
  free.
- **The Manager**, which builds its own sense list:
  - `OccupantSenseSystem.markHidden` marks a player concealed from him (`isConcealedFrom`, his model) as `hidden` and **not** `seen`. That is the same "hiding
    where he didn't see you go in" state he already ignores.
  - Every other part of his sight already skips hidden players: the near and long sight, the side zone, the felt
    presence behind him, the turns and the stare.
  - `OccupantCatchSystem` counts concealed as "hidden unseen", so he can't catch Prickles.
  - Nothing changes in his turning, his sight ray or his noise handling.
- **Hide uses it too.** `HideServiceServer` conceals a player who hides unseen (source `"hide"`) and reveals them when
  they leave, or when the Manager is told he saw them go in (`setSeen`).
  - Generic monsters then respect hiding spots without extra work.
  - The Manager is unaffected: `markHidden` checks Hide first and only uses concealment for players who are not in a
    spot.
  - (My call. This is the "generalise Hide" step. It is small, but it is a change to Hide, so it is listed.)

### The plant itself

- **Starting.** Concealment begins **the moment the server accepts the press**. It does not wait for the clip.
- **Ending.** It ends at once on any of the following.
  - The root moves more than 1 stud across the floor from where it started (the server measures this every tick).
  - He jumps or falls.
  - He sprints, vacuums, hides, picks something up or plays an emote. The server watches those states directly.
  - A `Cancel` arrives. His client sends it on any move or action input, so the end feels instant.
  - 8 s pass.
  - He dies or gets caught, or the shift ends.
- **While he is a plant.** He is not frozen; walking simply ends it. He makes no noise.
- **When a monster saw him become a plant (owner, 2026-10-30): it does not work against that monster.** This is
  Hide's rule. Witnesses are decided per monster at the moment concealment starts:
  - `conceal` asks every live NPC whether it sees the player right now.
  - For a kind on the default brain, the answer is the generic sight check (`NpcSenseRules.inSight` plus the
    line-of-sight ray).
  - A kind with its own senses registers its own check with `NpcServiceServer:setWitness(kind, check)`. The Manager
    registers `OccupantSenseSystem.witness`, the same check Hide uses today.
  - A monster that witnessed it keeps seeing Prickles normally and can chase and catch him. Every other monster is
    fooled.
  - The plant still plays and the cooldown is still spent. The tracker answers `isConcealedFrom(player, npc)`.

**Animation.** Three clips: enter (1.63 s), then a 2 s hold on a loop, then exit (1.63 s).

- Moving cancels it: the server stops the skeleton tracks, the pot hides at once, and his face goes back to normal.
- A full 8 s ending plays the exit clip. It only plays if he is still standing still.
- Stopping the visual never ends the stealth, and ending the stealth always stops the visual.

**The pot and soil.**

- **Source.** They are built from `PottedPlant_prop.fbx` and uploaded to the Icey Labs group.
- **Where the template sits.** In the place's `ReplicatedStorage/Assets/CleanupCrew/EmoteProps`. That folder belongs
  to the place, so the owner saves it.
- **How it shows.** It reuses `EmotePropRegistry` and `EmotePropSystem`: `PropsShow` and `PropsStow` markers, renamed
  from the clips' own `pot_show` (enter, frame 9) and `pot_hide` (exit, frame 41).
- **One small extension.** A prop can be mounted at his feet, on the root, instead of in a hand.

**Faces.** The face timeline becomes `Face` markers in the clips before upload, and the existing Face-marker path swaps
the faces.

**Sound and VFX.** A leaf puff and a rustle on enter and exit, which everyone sees and hears. Nothing during the hold,
because it is stealth.

## Animations: where they register

- **Registry.** The ability clips go in a new animation domain module, `AnimationAbilityRegistry`. That keeps them out of
  `AnimationEmployeeRegistry`, which the char-wiring session is editing.
- **Fields.** Each entry is `replicable`, has a new permanent `wireId`, has `interruption = "protected"` and has
  `layer = "full"` (`"upper"` for Pippa's moving variant).
- **Playing them.** The server plays them with `AnimationServiceServer:play`, and only after the effect has started.
- **Uploads.** I upload Pippa's two clips, the three Prickles clips and the prop mesh to group 189923277 with
  `ICEY_LABS_OPEN_CLOUD_KEY`.

## HUD

- **Desktop.** A round ability button, bottom right beside the sprint bar, with:
  - the ability icon (from `UIAssets`, which already has all three);
  - a key cap: `Q`, or `Y` on a gamepad;
  - a dark sweep that empties as the cooldown runs, with the seconds left in big numbers;
  - a short "Ready!" pop when it fills.
- **Phone.** The same ring on the arc button.
- **What it reads from.** Everything comes from `AbilityReadyAt` and `AbilityActive`, mirrored into an `AbilityStore`.
- **Words.**
  - Ability names: "Let's Go!", "Spot It!", "Potted Plant".
  - Toasts: "Not ready yet!", "Nothing to find!", "Put that down first!", "You popped out!" (when the plant ends from
    moving).

## New modules

New modules (subject to the owner's approval of a new **Ability** feature):

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Ability | shared | Data | AbilityRegistry | The abilities by id (`letsGo`, `spotIt`, `pottedPlant`), with cooldown, duration, radius, scale, icon and clip keys, plus employee → ability. |
| Ability | shared | Data | AbilityConstants | Attribute names, key and button bindings, rate limits, toast words. |
| Ability | shared | Data | AbilityTypes | The ability id and definition types. |
| Ability | shared | Net | AbilityEvents | The `Use`, `Cancel` and `Spotted` packets. |
| Ability | shared | Rules | AbilityRules | `canUse`, and the plant's end checks (moved, jumped, acted, timed out). |
| Ability | server | (root) | AbilityServiceServer | Handles requests, runs cooldowns and starts and ends each effect. |
| Ability | server | State | AbilityCooldownTracker | Ready-at per userId, and the plants that are running. |
| Ability | server | Utils | AbilityTreasureUtils | Picks the closest qualifying treasure from a list of candidates. Pure. |
| Ability | client | (root) | AbilityServiceClient | Binds Q / Y, sends `Use` and `Cancel`, and listens for `Spotted`. |
| Ability | client | State | AbilityStore | Charm atoms for ready-at and active, for the HUD. |
| Ability | client | Systems | AbilitySpotSystem | Draws and clears Cappy's through-walls highlight. |
| Ability | client | Systems | AbilityVfxSystem | Pippa's burst and speed trails, and Prickles' leaf puffs and sounds. |
| Npc | server | State | NpcConcealTracker | Who is concealed from monsters, and by which sources. |
| Sprint | server | State | SprintBoostTracker | The one speed scale and end time per player (no stacking). |
| Animation | shared | Data | AnimationAbilityRegistry | The ability clips (replicable, with wireIds). |
| UI | client | Screens/Hud | AbilityButton (+ story) | The ability button with its cooldown ring and key cap. |

**Edits to existing modules:**

- `NpcServiceServer`, `NpcBehaviourSystem`
- `OccupantSenseSystem`, `OccupantCatchSystem`
- `HideServiceServer`
- `SprintServiceServer`, `SprintSpeedFormulas`
- `CrouchServiceServer`
- `CarrySpeedSystem`
- `EmotePropRegistry`, `EmotePropSystem` (the root mount)
- `ShiftHudViewModel`, `ShiftMobileButtons`, `ShiftActionButton` (the ring)
- `InputActionRegistry` caller (`AbilityServiceClient` registers the action)
- `EmployeeProfileRegistry` (reads the cooldown number from `AbilityRegistry`)
- `AnimationRegistry` (`DOMAIN_MODULES`)

**Approval-gated items:**

- A **new feature, Ability**. Nothing existing fits:
  - Employee owns who you are and how you look, not timed gameplay actions.
  - Each effect already sits in the feature whose job it is: speed in Sprint, stealth in Npc, treasure data in Cargo.
  - A dispatcher and cooldown owner is a job of its own.
- No new subfolder kind, no new role word and no second service.

## Testing

**Spec-first for every new module:**

- `AbilityRules`: every refusal reason, and every plant end reason.
- `AbilityCooldownTracker`.
- `AbilityTreasureUtils`: grimy only, unclaimed only, buried items included, closest first.
- `NpcConcealTracker`: concealment from several sources.
- `SprintBoostTracker`: refreshing a boost never stacks.
- `NpcBehaviourSystem`: a concealed player is never a candidate.
- `OccupantSenseSystem.markHidden`: a concealed player comes out as hidden and unseen.
- `OccupantCatchRules`: a concealed player can't be caught.
- The speed invariant: every sequence of boost, sprint, crouch and carry returns to the same walk speed.

Then the full suite in Studio. The only known failure is `RankServiceServer.spec:178`.

**Real play, with two clients:**

- Pippa casts while a teammate is nearby, and the teammate sees the trails and runs faster.
- The boost ends cleanly mid-sprint.
- Cappy sees the glow through walls, and the teammate sees nothing.
- Prickles plants in the Manager's view, mid-chase and out of view, and the Manager walks past.
- Moving ends the plant, and the Manager can catch him again right away.
- Q, Y and the phone button each work.

## Calls settled after the builder check (mine; the owner can overrule)

- **Generic monsters can't hurt a concealed player.** `NpcBehaviourSystem` picks its target from its candidate list,
  so its attack intent can only ever name a player on that list. Dropping concealed players from the list covers
  attacks as well as sight. A spec pins this down.
- **A monster right next to him can't catch him either.** It may bump into the pot, but being close is not enough for
  a catch.
- **What counts as treasure.** Any item whose cargo kind is `grimy` in `CargoRegistry`, whether or not it has been
  cleaned. It must be on the floor or under a pile, and must not be carried or pocketed. Distance is straight-line and
  ignores floors and doors, as on the card.
- **The boost stays on players who are caught.** It is harmless there. It clears when the character is removed, so it
  never carries over a respawn.
- **`AbilityActive` clears the moment stealth ends.** The exit clip is cosmetic only. A `Cancel` that arrives during
  the exit clip is ignored.
- **The client sends `Cancel` at most once per plant,** and only while its own `AbilityActive` is the plant. The rate
  limit (10 per 5 s) can't drop the real one.
- **The phone button.** Adding the ability button may shift the other phone arc buttons. That is checked at the
  play-check.
- **The `Carryable` tag** comes from `CarryConstants`.

## What is left to the builder

- Exact VFX and sound picks, within the game-vfx-design and sound skills.
- Toast timing.
- The ring's look, within the game-ui-design style.

## Owner answers

All three were answered on 2026-10-30:

1. **Plant while watched:** no. A monster that witnesses it is not fooled.
2. **Treasure:** yes, including buried grimy items.
3. **New Ability feature:** approved.
