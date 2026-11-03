# Employee Abilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Let's Go!, Spot It! and Potted Plant real, server-authoritative abilities on Q / Y / a phone button, with
Potted Plant as general stealth in the shared Npc layer.

**Architecture:**
- **Ability (new game feature)** owns the button, the checks, the cooldowns and starting and ending each effect.
- Each effect lives where its job already is:
  - **Speed:** a single speed scale owned by Sprint. Every `WalkSpeed` writer applies it, and every base read divides
    it out.
  - **Stealth:** concealment with per-monster witnesses in Npc. Occupant and Hide read it and feed it.
  - **Treasure:** picked on the server from Cargo's tagged parts.
- Animations, VFX and HUD read only the replicated attributes the server sets.

**Tech Stack:** Luau `--!strict`, Rojo, ByteNet, Charm, React (UI Labs stories), TestEZ in Studio.

**Spec:** `docs/superpowers/specs/2026-10-29-employee-abilities-design.md` (approved 2026-10-30).

## Global Constraints

- **Code style:** `--!strict`. No `any`, no casts. Services use the lean annotated-literal shape. Spec files are
  untyped.
- **Tests first:** every new first-party module gets its `.spec.luau` before its code, unless it is in
  `SpecRoots.EXEMPT_MODULES` with a reason. Shells (Instances, ByteNet, physics) are exempt the way the Npc and Sprint
  shells are.
- **Ability numbers:**

  | Ability | Cooldown | Effect | Clip |
  |---|---|---|---|
  | Let's Go! | 45 s | 4 s, ×1.25 speed, 20 stud radius | — |
  | Spot It! | 40 s | 5 s | 3.667 s, full and upper |
  | Potted Plant | 45 s | up to 8 s; moving more than 1 stud ends it | — |

- **Binding:** keyboard `Q`, gamepad `ButtonY`, plus a button on the phone arc.
- **Player words (kid level):** "Let's Go!", "Spot It!", "Potted Plant", "Not ready yet!", "Nothing to find!",
  "Put that down first!", "You popped out!", "Ready!".
- **Attributes:**
  - Player: `AbilityReadyAt` (server time).
  - Character: `AbilityActive` (ability id), `SpeedScale` (number, absent means 1), `SpeedBoostUntil` (server time).
- **Uploads:** group 189923277 only, `--group 189923277 --key-env ICEY_LABS_OPEN_CLOUD_KEY`. Never VentureMMO.
- **Shared worktree:**
  - Before editing a file, check `git diff <file>` for someone else's changes. If there are any, message the
    coordinator.
  - Commit only my own hunks (`git add -p`), with plain messages and no trailers.
  - Commit only after the owner's play-check. No push.
- **Layering:** a base feature (Npc, Carry, Animation, Input, UI) never requires a game feature (Sprint, Hide,
  Occupant, Ability). Game features hook into base features through registration functions.
- **Commands:**
  - After adding modules: `python3 scripts/python/module_map.py --write`.
  - Gate: `bash scripts/check.sh --skip-install`. Never `wally install` while the owner is connected.

## Review Focus

1. **A plant started while a monster watches.** Only that monster sees Prickles. Other monsters are still fooled.
   Pinned in Task 1 (`NpcConcealTracker`, the per-NPC witness).
2. **A boost that starts or ends during a sprint, a crouch or a pick-up.** `WalkSpeed` returns exactly to its pre-boost
   value. Pinned in Task 4 (the speed round-trip spec).
3. **Prickles moving, jumping or using his vacuum mid-plant.** Concealment ends the same tick, and the Manager can
   catch him at once. Pinned in Task 5 (`AbilityRules.plantEnds`).
4. **Using an ability while dead, caught, hiding, in the lobby, or with a different employee.** Refused, with no
   cooldown spent. Pinned in Task 5 (`AbilityRules.canUse`).
5. **The Spot It target picked up or removed during the 5 s.** The highlight goes away and no error is raised. Pinned
   in Task 7 (`AbilitySpotSystem` clears on `AncestryChanged` or a claim). Checked in real play.

## New modules

| Feature | Realm | Subfolder | Name | Job |
|---|---|---|---|---|
| Npc | server | State | NpcConcealTracker | Who is concealed, by which sources, and which NPCs witnessed it. |
| Sprint | server | State | SprintBoostTracker | One speed scale and end time per userId; refreshing never stacks. |
| Ability | shared | Data | AbilityTypes | `AbilityId`, `AbilityDef`. |
| Ability | shared | Data | AbilityConstants | Attributes, bindings, rate limits, words, tick. |
| Ability | shared | Data | AbilityRegistry | Defs by id, and employee name → id. |
| Ability | shared | Net | AbilityEvents | `Use`, `Cancel`, `Spotted`. |
| Ability | shared | Rules | AbilityRules | `canUse`, `plantEnds`. |
| Ability | server | (root) | AbilityServiceServer | Requests, cooldowns, effects. |
| Ability | server | State | AbilityCooldownTracker | Ready-at per userId, and the plants that are running. |
| Ability | server | Utils | AbilityTreasureUtils | The closest qualifying treasure from candidates. |
| Ability | client | (root) | AbilityServiceClient | Input, `Use` and `Cancel`, `Spotted`. |
| Ability | client | State | AbilityStore | Charm atoms: ready-at, active. |
| Ability | client | Systems | AbilitySpotSystem | Cappy's local through-walls highlight. |
| Ability | client | Systems | AbilityVfxSystem | Boost trails and burst, leaf puffs, ability sounds. |
| Animation | shared | Data | AnimationAbilityRegistry | The ability clips (replicable, with wireIds). |
| UI | client | Screens/Hud | AbilityButton (+ `.story`) | The desktop button with its cooldown ring and key cap. |

---

### Task 1: Concealment in the Npc layer

**Files:**
- Create: `src/ServerScriptService/Features/Npc/State/NpcConcealTracker.luau` and `.spec.luau`
- Modify: `Npc/NpcServiceServer.luau`, `Npc/Systems/NpcBehaviourSystem.luau` (`candidates` gains an agent-aware filter)
- Docs: `docs/superpowers/specs/2026-10-09-npc-design.md` (append a "Concealment" section)

**Interfaces:**
- Produces `NpcConcealTracker.new()` with these methods:
  - `:conceal(userId: number, source: string, witnesses: { number })`, where `witnesses` are NPC roster ids;
  - `:reveal(userId: number, source: string)`;
  - `:isConcealed(userId: number): boolean`;
  - `:isConcealedFrom(userId: number, npcId: number): boolean`. It is true while any source holds the player and
    that NPC did not witness that source;
  - `:forgetNpc(npcId: number)`;
  - `:clear(userId: number)`.
- Produces on `NpcServiceServer`:
  - `conceal(player, source)`: asks every live agent's witness check now;
  - `reveal(player, source)`;
  - `isConcealed(player)`;
  - `isConcealedFrom(player, npc: Model): boolean`;
  - `setWitness(kind: string, check: ((npc: Model, player: Player) -> boolean)?)`. The default check is the generic
    `inSight` plus line of sight.
- `NpcBehaviourSystem.think`: candidates for an agent exclude players for whom `isConcealedFrom(userId, agent.id)` is
  true. This covers hostile and timid, sight and attack (attack targets come only from candidates).

- [ ] **Step 1:** Write `NpcConcealTracker.spec`. Each case is one `it`:
  - concealed with no witnesses → concealed from NPC 1 and NPC 2;
  - witnessed by 1 → not concealed from 1, concealed from 2;
  - two sources, reveal one → still concealed;
  - reveal both → not concealed;
  - the same source concealed again replaces its witnesses;
  - `forgetNpc` drops it from every witness set;
  - `clear` drops everything.
- [ ] **Step 2:** Run the suite in Studio and confirm the new spec fails (module missing).
- [ ] **Step 3:** Implement the tracker in the closure-table style of `NpcRosterTracker`.
- [ ] **Step 4:** Wire `NpcServiceServer`:
  - a tracker instance and a `witnesses: { [string]: check }` map;
  - the methods above;
  - `removeAgent` calls `forgetNpc`;
  - `Players.PlayerRemoving` calls `clear`;
  - `thinkDeps` gains `concealedFrom: (userId: number, npcId: number) -> boolean`.
- [ ] **Step 5:** `NpcBehaviourSystem.candidates(targetFilter, concealedFrom, agentId)` skips concealed players. The
  generic witness function lives in `NpcBehaviourSystem.sees(agent, player): boolean`, the same cone and ray as
  `think`.
- [ ] **Step 6:** Gate: `selene src`, `stylua --check src`, typecheck via `bash scripts/check.sh --skip-install`.

### Task 2: The Manager honours concealment

**Files:**
- Modify: `Occupant/Systems/OccupantSenseSystem.luau` (`markHidden`), `Occupant/Systems/OccupantCatchSystem.luau`
  (`attempt`), `Occupant/OccupantServiceServer.luau` (`start`: `NpcServiceServer:setWitness(NPC_KIND, …)`)
- Test: `Occupant/Systems/OccupantSenseSystem.spec.luau` (add cases, or create it if there is none)

**Interfaces:**
- `System.markHidden(list, concealed: ((userId: number) -> boolean)?)`. A player who is not in a Hide spot but is
  concealed from him is marked `hidden = true, seen = false`. Hide's own marking wins for players in a spot.
- The catch input's `hidden` becomes `hideHiddenUnseen or NpcServiceServer:isConcealedFrom(player, rig.model)`.
- The witness the Manager registers is
  `function(npc, player) return npc == rig.model and witness(player) end`. It reuses the existing `witness`, which
  `Sense.witness` backs.

- [ ] **Step 1:** Spec: given a glimpse list with userIds 1, 2 and 3 and `concealed = function(id) return id == 2 end`,
  `markHidden` returns 2 marked hidden and not seen, and 1 and 3 unchanged. Hide is stubbed so that nobody is in a
  spot.
- [ ] **Step 2:** Run it and confirm it fails.
- [ ] **Step 3:** Implement it. `glimpses()` in `OccupantServiceServer` passes
  `function(id) return NpcServiceServer:isConcealedFrom(player, current.model) end`.
- [ ] **Step 4:** Make the catch-input change and register the witness.
- [ ] **Step 5:** Run the suite and the gate. Confirm the Occupant specs are still green.

### Task 3: Hide feeds concealment

**Files:**
- Modify: `Hide/HideServiceServer.luau` (`enter`, `leave`, `setSeen`)

**Interfaces:**
- On a successful `enter`, if not `seenEntering`, call `NpcServiceServer:conceal(player, "hide")`.
- On `leave`, call `reveal(player, "hide")`.
- `setSeen(player, true)` calls `reveal(player, "hide")`.
- Add `"NpcServiceServer"` to `dependencies`.

- [ ] **Step 1:** This is a shell edit (Hide is spec-exempt). Make the three calls.
- [ ] **Step 2:** Run the Hide and Occupant specs and the gate.

### Task 4: One speed scale (Sprint, Crouch, Carry)

**Files:**
- Create: `Sprint/State/SprintBoostTracker.luau` and `.spec.luau` (server)
- Modify:
  - `ReplicatedStorage/Shared/Features/Sprint/Utils/SprintSpeedFormulas.luau` and its spec
  - `Sprint/Data/SprintConstants.luau` (`SPEED_SCALE_ATTRIBUTE = "SpeedScale"`,
    `BOOST_UNTIL_ATTRIBUTE = "SpeedBoostUntil"`)
  - `SprintServiceServer.luau`
  - `Crouch/CrouchServiceServer.luau`
  - `Carry/Systems/CarrySpeedSystem.luau` and `CarryServiceServer.luau` (`setSpeedScale` hook)

**Interfaces:**
- `SprintBoostTracker.new()`:
  - `:boost(userId, scale, untilTime)` returns the scale that now applies. It keeps the max scale and the max until.
  - `:scaleAt(userId, now): number` is 1 when there is no boost or it has expired.
  - `:expired(now): { number }` removes and returns the userIds whose boost ended.
  - `:clear(userId)`.
- `SprintSpeedFormulas.scaleFrom(value: unknown): number` returns a positive number, else 1.
- `SprintSpeedFormulas.rescale(walkSpeed: number, from: number, to: number): number` returns
  `walkSpeed / from * to`.
- `SprintServiceServer`:
  - `boost(player, scale, seconds)`: sets `SpeedScale` and `SpeedBoostUntil` on the character and rescales
    `WalkSpeed` from the old scale to the new;
  - `speedScale(player): number`;
  - the tick expires boosts (rescales back, clears the attributes);
  - `observeCharacter` clears the boost.
- `CarrySpeedSystem.setSpeedScale(source: ((player: Player) -> number)?)`. `applyTo`'s `rest` is `WalkSpeed / scale`.
  It writes `carrierSpeed(rest, w) * scale`, and on unload restores `rest * scale`. Sprint registers it in `start`.
- Every Sprint and Crouch write is `× speedScale(player)`, and every Sprint and Crouch base read is
  `÷ speedScale(player)`.
- The invariant: `WalkSpeed = plain × scale` always.

- [ ] **Step 1:** `SprintBoostTracker.spec`:
  - a boost of 1.25 until t=10 → `scaleAt(5) = 1.25`, `scaleAt(11) = 1`;
  - boosting again at 1.25 until 12 → scale still 1.25 (never 1.5625) and lasts until 12;
  - a smaller later boost keeps 1.25 and extends;
  - `expired(11)` returns the id once.
- [ ] **Step 2:** `SprintSpeedFormulas.spec` additions:
  - `scaleFrom(nil) = 1`, `scaleFrom(-2) = 1`, `scaleFrom(1.25) = 1.25`;
  - `rescale(20, 1.25, 1) = 16`;
  - round trip: `rescale(rescale(13.6, 1, 1.25), 1.25, 1) == 13.6` (within 1e-9).
- [ ] **Step 3:** Run them and confirm they fail.
- [ ] **Step 4:** Implement the tracker and the formulas.
- [ ] **Step 5:** Thread the scale through Sprint, Crouch and Carry as described above.
- [ ] **Step 6:** Run the suite and the gate.
- [ ] **Step 7:** Studio probe, with Play and one client. Read `WalkSpeed` through each of these sequences; it must end
  at 16 every time:
  - boost, walk;
  - boost, then sprint during it, then the boost ends;
  - crouch, then boost, then stand;
  - pick up a medium item, boost, drop.

### Task 5: Ability shared data, packets and rules

**Files (shared, under `ReplicatedStorage/Shared/Features/Ability/`):**
- `Data/AbilityTypes.luau`
- `Data/AbilityConstants.luau`
- `Data/AbilityRegistry.luau` and `.spec`
- `Net/AbilityEvents.luau`
- `Rules/AbilityRules.luau` and `.spec`
- Modify: `Employee/Data/EmployeeProfileRegistry.luau`. Its `ability.cooldown` reads
  `AbilityRegistry.forEmployee(name).cooldown`. Update the "DISPLAY ONLY" note.

**Interfaces:**
- **Types:**
  - `AbilityId = "letsGo" | "spotIt" | "pottedPlant"`.
  - `AbilityDef = { id, cooldown, duration, radius: number?, scale: number?, clips: { full: string?, upper: string?, enter: string?, hold: string?, exit: string? } }`.
- **Registry:** `AbilityRegistry.get(id): AbilityDef?` and `AbilityRegistry.forEmployee(name: string): AbilityDef?`.
  The mapping is Pippa → letsGo, Cappy → spotIt, Prickles → pottedPlant.
- **Packets:**
  - `Use`: `ByteNet.bool`, ignored;
  - `Cancel`: `ByteNet.bool`, ignored;
  - `Spotted`: `ByteNet.struct({ cargoId = ByteNet.uint32 })`.
- **`AbilityRules.canUse(input): (boolean, Reason?)`.**
  - `input = { running, participant, alive, caught, hidden, now, readyAt, def: AbilityDef?, grounded, holding, hasTarget }`.
  - `Reason = "noAbility" | "notRunning" | "notPlaying" | "dead" | "caught" | "hidden" | "cooldown" | "airborne" | "holding" | "nothing"`.
  - The checks run in that order.
  - `airborne` and `holding` apply only to `pottedPlant`; `nothing` applies only to `spotIt`.
- **`AbilityRules.plantEnds(input): EndReason?`.**
  - `input = { now, startedAt, maxSeconds, moved: number, grounded, acting, alive, caught, cancelled }`.
  - `EndReason = "moved" | "jumped" | "acted" | "timeout" | "dead" | "caught" | "cancelled"`.
  - `moved` is the horizontal distance from the start, and it ends the plant when it is greater than
    `AbilityConstants.PLANT_MOVE_TOLERANCE = 1`.
- **`AbilityConstants`** also holds:
  - `REASON_WORDS`: cooldown → "Not ready yet!", nothing → "Nothing to find!", holding → "Put that down first!",
    moved → "You popped out!";
  - `REQUEST_RATE = { maxRequests = 10, windowSeconds = 5 }`;
  - `TICK = 0.05`.

- [ ] **Step 1:** Write `AbilityRegistry.spec`:
  - three employees map to the three ids;
  - an unknown employee → nil;
  - the cooldowns are 45, 40 and 45, and the durations 4, 5 and 8;
  - letsGo has radius 20 and scale 1.25.
- [ ] **Step 2:** Write `AbilityRules.spec`:
  - one `it` per `canUse` reason, each with all other inputs valid;
  - a fully valid input passes;
  - cooldown passes at exactly `now == readyAt`;
  - holding refuses only pottedPlant;
  - a missing target refuses only spotIt;
  - one `it` per `plantEnds` reason;
  - a moved distance of 0.9 continues; 1.1 → "moved";
  - timeout at `now - startedAt >= 8`.
- [ ] **Step 3:** Run them and confirm they fail.
- [ ] **Step 4:** Implement the modules. `EmployeeProfileRegistry` keeps the text and takes the cooldown from the
  registry.
- [ ] **Step 5:** Run the suite, then `module_map.py --write`, then the gate.

### Task 6: Ability server

**Files (under `src/ServerScriptService/Features/Ability/`):**
- `AbilityServiceServer.luau` (spec-exempt shell: add it to `EXEMPT_MODULES` with a reason)
- `State/AbilityCooldownTracker.luau` and `.spec`
- `Utils/AbilityTreasureUtils.luau` and `.spec`

**Interfaces:**
- **`AbilityCooldownTracker.new()`:**
  - `:readyAt(userId): number` (0 if never used);
  - `:spend(userId, now, cooldown): number` (the new ready-at);
  - `:resetAll()`;
  - `:startPlant(userId, plant: { startedAt, origin: Vector3 })`, `:plantOf(userId)`, `:endPlant(userId)`;
  - `:clear(userId)`.
- **`AbilityTreasureUtils.closest(origin: Vector3, candidates: { { id: number, position: Vector3, grimy: boolean, claimed: boolean } }): number?`**
  returns the id of the closest grimy, unclaimed candidate.
- **Service dependencies:** RoundServiceServer, DeathServiceServer, HideServiceServer, OccupantServiceServer (for
  `isCatching`, or OccupantCatchSystem directly), SprintServiceServer, NpcServiceServer, CargoServiceServer,
  AnimationServiceServer, ToastServiceServer.
- **Effects:**
  - **letsGo:** `SprintServiceServer:boost(p, 1.25, 4)` for Pippa and for every participant within 20 studs who is
    alive and not caught. Then play the full or upper clip.
  - **spotIt:**
    - Candidates come from `CollectionService:GetTagged(CarryConstants.TAG)`: a part with a numeric `CargoId`, a kind
      that is `CargoRegistry.get(kind).grimy`, and `claimed = CargoServiceServer.isClaimed(part)`. Parts with
      `CargoHidden` are included.
    - Send `Spotted.sendTo({cargoId}, player)`.
    - Set `AbilityActive` for 5 s.
  - **pottedPlant:**
    - `NpcServiceServer:conceal(player, "pottedPlant")`, `startPlant`, set `AbilityActive = "pottedPlant"`, play the
      enter and hold clips.
    - Every `TICK` it evaluates `plantEnds` with:
      - `moved` from the root position;
      - `grounded` from the humanoid's FloorMaterial / state;
      - `acting` = sprinting, vacuuming (the Vacuum attribute), hidden, holding, or an emote grant;
      - `alive`, `caught`, and `cancelled` from the `Cancel` packet.
    - On an end: `reveal`, `endPlant`, clear `AbilityActive`. For "timeout" (and still grounded), play the exit clip;
      otherwise stop the clips. Toast "You popped out!" when the reason is moved.
- **Cooldown:**
  - Spent on an accepted `Use` and published to `AbilityReadyAt`.
  - `resetAll` when the round phase enters "running", which re-publishes ready-at as 0.
  - A refused `Use` sends the reason's words via `ToastServiceServer:send` (only reasons with words).

- [ ] **Step 1:** Write the specs.
  - Cooldown tracker: spend → readyAt; resetAll → 0; the plant lifecycle.
  - Treasure utils: picks the closest grimy; skips non-grimy and claimed; ties go to the lower id; empty → nil.
- [ ] **Step 2:** Run them and confirm they fail.
- [ ] **Step 3:** Implement the tracker and the utils.
- [ ] **Step 4:** Implement the service shell.
- [ ] **Step 5:** Run the suite, then the module map, then the gate.

### Task 7: Ability client

**Files (under `src/ReplicatedStorage/Client/Features/Ability/`):**
- `AbilityServiceClient.luau`
- `State/AbilityStore.luau` and `.spec`
- `Systems/AbilitySpotSystem.luau`
- `Systems/AbilityVfxSystem.luau`

The client shells are spec-exempt with a reason.

**Interfaces:**
- **`AbilityStore`:** `readyAt: Charm atom<number>`, `active: atom<string?>`, `abilityId: atom<string?>`. The last one
  comes from the character's `EmployeeName`. Plus a pure `AbilityStore.secondsLeft(readyAt, now): number`, which is
  `ceil`, floored at 0.
- **`AbilityServiceClient`:**
  - Registers the input action `"ability"` (gameplay context, keyboard `Q`, gamepad `ButtonY`) and binds "begin" to
    `use()`.
  - `use()` sends `Use`.
  - While `active == "pottedPlant"`, the first "begin" of any other gameplay action, or a non-zero
    `Humanoid.MoveDirection`, or a jump sends `Cancel` once.
  - Listens for `Spotted` → `AbilitySpotSystem.show(cargoId, 5)`.
- **`AbilitySpotSystem.show(cargoId, seconds)`:**
  - Finds the tagged part with that `CargoId` and adds a `Highlight`: `AlwaysOnTop`, gold fill 0.6, outline
    `Color3.fromRGB(255, 214, 92)`.
  - Adds a sparkle `BillboardGui`.
  - Removes both after `seconds`, or when the part's ancestry changes or the part is claimed (parent changes).
- **`AbilityVfxSystem`** watches every character's attributes:
  - `SpeedBoostUntil` → orange trail and streak particles until that time;
  - `AbilityActive` set to letsGo on Pippa → a burst ring and a whistle;
  - `AbilityActive` set to or from pottedPlant → a leaf puff and a rustle.

  Use the game-vfx-design skill for the functional look.

- [ ] **Step 1:** Write `AbilityStore.spec`: `secondsLeft(10, 4.2) = 6`, `secondsLeft(10, 10) = 0`,
  `secondsLeft(10, 12) = 0`.
- [ ] **Step 2:** Implement the store and the services.
- [ ] **Step 3:** Run the suite, then the module map, then the gate.

### Task 8: Clips, pot prop and markers

**Files:**
- Create: `ReplicatedStorage/Shared/Features/Animation/Data/AnimationAbilityRegistry.luau` (data). Add it to
  `AnimationRegistry.DOMAIN_MODULES`.
- Modify: `Emote/Data/EmotePropRegistry.luau` (an entry for the plant clips), `Client/Features/Emote/Systems/EmotePropSystem.luau`
  (a template attribute `Mount = "Root"` mounts at the feet on the HumanoidRootPart), `Emote/Data/EmoteEffectRegistry.luau`
  (Face on the plant clips).

**Steps:**
- [ ] **Step 1: Prepare the clips.**
  - Copy the workbench `.rbxmx` files to the scratchpad.
  - Rename the markers: `pot_show` → `PropsShow`, `pot_hide` → `PropsStow`.
  - Add `Face` markers from `face_timeline.json` changes.
- [ ] **Step 2: Upload** each clip with the publish script under group 189923277 and record the ids. That is Pippa
  full and upper, and Prickles enter, hold and exit.
- [ ] **Step 3: Register the clips.**
  - Each entry is `replicable`, `protected`, has a new unused `wireId` (grep the existing ones), and a `durationMs`
    for each one-shot.
  - The hold is looped.
  - Cappy's entries are placeholders until the coordinator sends his ids (full and upper, 3667 ms).
- [ ] **Step 4: Build the pot and soil.**
  - Upload the mesh from `PottedPlant_prop.fbx`.
  - Build the template model `PottedPlant` (Pot and Soil parts, `Mount = "Root"`, offset from the prop timeline).
  - Put it in the place's `ReplicatedStorage.Assets.CleanupCrew.EmoteProps`. This needs Studio, so ask the
    coordinator first. The owner saves the place.
- [ ] **Step 5:** Extend `EmotePropSystem` with the root mount, then run the gate.

### Task 9: HUD

**Files:**
- Create: `ReplicatedStorage/Client/UI/React/Screens/Hud/AbilityButton.luau` and `AbilityButton.story.luau`
- Modify: `Screens/Shift/ShiftHudViewModel.luau` (a new arc spot and an `ability` field in `mobileButtons`),
  `ShiftMobileButtons.luau`, `ShiftActionButton.luau` (optional `cooldown: number?` 0..1 ring and `icon: string?`)
- Register the HUD button from `AbilityServiceClient` with `HudRegistry.register("abilityButton", …)`.

The button shows:
- the icon from `UIAssets[def icon]`;
- a key cap (`Q`, or `Y` when the last input was a gamepad);
- a sweep that is `secondsLeft / cooldown`, with big seconds;
- a "Ready!" pop.

It follows the game-ui-design Gloom & Gleam style.

- [ ] **Step 1:** Write the story with three states (ready, 30 s left, active) and preview it in UI Labs.
- [ ] **Step 2:** Implement the button and the arc spot.
- [ ] **Step 3:** Run the gate.

### Task 10: Verify in real play

- [ ] **Step 1:** Compare the Edit Source lengths with disk. Ask the coordinator for Studio.
- [ ] **Step 2:** Run the full suite (`RunTests = true`) and read the "Tests:" line. The only known failure is
  `RankServiceServer.spec:178`.
- [ ] **Step 3:** Two-client play probe: Pippa plus a teammate, Cappy, and Prickles versus the Manager. Cover
  watched, unwatched and mid-chase.
- [ ] **Step 4:** Message the coordinator "Studio free".
- [ ] **Step 5:** Send the owner a play-check list.
- [ ] **Step 6:** After the owner approves, commit my hunks only.
