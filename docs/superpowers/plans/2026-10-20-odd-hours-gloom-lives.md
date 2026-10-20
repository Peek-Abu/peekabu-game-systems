# Gloom Lives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** every employee has 3 lives per shift. A catch costs one life. The third catch knocks the player out for the rest of the shift: they spectate, the crew is told, and they keep their pay. If the whole crew is out, the shift ends as a missed contract. Lives show only in the UI.

**Architecture:**
- **Shift owns lives.** A pure rules module and a tracker hold the lives; a modifier hook lets perks change the starting count.
- **Occupant's catch spends a life before the kill.** That way the third catch never shows a "back in" timer.
- **Knocking out reuses the base.** A per-player respawn hold in Death keeps the player down, Round's existing elimination ends a wiped run, and Death's existing spectate shows teammates.
- **Results and UI.** The results treat `"wiped"` as missed. The UI adds pips, an "OUT" state, and an "OUT FOR THE SHIFT" panel.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ specs (Studio, `RunTests`), ServiceController, StateSync public player fields.

**Spec:** `docs/superpowers/specs/2026-10-20-odd-hours-gloom-lives-design.md`

## Global Constraints

- `--!strict`, no `any`, no casts. Follow `AGENTS.md` and `docs/project-structure.md`.
- Every new module gets a `.spec.luau` sibling or a reasoned `SpecRoots.EXEMPT_MODULES` entry. After adding a module, run `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no trailers**. Stage files by name. Never stage `src/ServerScriptService/Core/Testing/SpecRoots.luau` except your own hunk (it carries someone else's uncommitted edit).
- Do not push. Do not run `wally`, `rokit`, `rojo build` or `scripts/check.sh`. Run `selene` and `stylua` on the files you touch.
- Rojo serves this worktree live to Studio: never `git checkout`, `reset` or `stash`.
- Specs run only in Studio, and the controller runs them.
- Lives never show on the character. No way to regain a life within a shift.
- `STARTING_LIVES = 3`. Public player fields: `lives` (number), `livesMax` (number), `knockedOut` (boolean).
- Copy:
  - CCTV line: `OUT FOR THE SHIFT`
  - roster status: `OUT`
  - toast: `<name> is out for the shift`

## Review Focus

- **A late joiner mid-shift gets full lives.** Pinned in Task 1 (`admit`).
- **Catches 1 and 2 still respawn as today; only the last catch holds the respawn.** Pinned in Task 3 (spend → knocked out only at 0).
- **Clock-out then the rest knocked out:** the shift ends through clock-out and never hangs. Pinned in Task 4 (`ShiftClockOutRules` spec).
- **Shift end with knocked-out players:** their holds are released, they get characters back, and the `knockedOut` and `lives` fields are cleared. Pinned in Task 3.
- **A modifier that returns 0 or a negative number:** lives are clamped to at least 1. Pinned in Task 1.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Shift | Server | Rules | `ShiftLivesRules` | Pure: a shift's starting lives after modifiers, and spending one life |
| Shift | Server | State | `ShiftLivesTracker` | Each player's remaining lives and knocked-out flag for the current shift |
| Death | Server | Rules | `DeathRespawnRules` | Pure: whether a dead player respawns now (mode and per-player hold) |

---

### Task 1: Lives rules, tracker and modifier hook (Shift)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`. Add `STARTING_LIVES = 3`, `PUBLIC_LIVES = "lives"`, `PUBLIC_LIVES_MAX = "livesMax"` and `PUBLIC_KNOCKED_OUT = "knockedOut"`.
- Create: `src/ServerScriptService/Features/Shift/Rules/ShiftLivesRules.luau` and its `.spec.luau`.
- Create: `src/ServerScriptService/Features/Shift/State/ShiftLivesTracker.luau` and its `.spec.luau`.

**Interfaces:**
- Produces: `ShiftLivesRules.starting(base: number, modifiers: { (number) -> number }): number`. It applies each modifier in order, floors the result, and clamps it to at least 1.
- Produces: `ShiftLivesRules.spend(remaining: number): (number, boolean)`. It returns `(max(remaining - 1, 0), knockedOut)`, where `knockedOut` is true exactly when the result is 0.
- Produces `ShiftLivesTracker.new()` with these methods:
  - `reset(entries: { [number]: number })`: userId → starting lives; it replaces everything.
  - `admit(userId: number, lives: number)`: a late joiner; it keeps an existing entry.
  - `spend(userId: number): (number, boolean)?`: nil for an unknown player or one already out.
  - `get(userId: number): number?`
  - `max(userId: number): number?`
  - `isOut(userId: number): boolean`
  - `out(): { number }`
  - `clear()`

- [ ] **Step 1: Write the failing specs:**
  - `starting(3, {})` is 3;
  - `starting(3, { function(n) return n + 1 end })` is 4;
  - a modifier returning -5 gives 1;
  - `starting(3, { function(n) return n + 0.7 end })` is 3;
  - `spend(3)` is `(2, false)`, `spend(1)` is `(0, true)` and `spend(0)` is `(0, true)`;
  - the tracker: `reset({[1]=3})`, then `spend(1)` three times gives `(2,false)`, `(1,false)`, `(0,true)`, and a fourth `spend` returns nil;
  - `isOut(1)` is true and `out()` is `{1}`;
  - `admit(2, 3)` then `get(2)` is 3;
  - `admit` on an existing entry does not reset it;
  - `max` returns the starting value;
  - `clear` empties everything.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement** the constants, the rules and the tracker. Run the module map.
- [ ] **Step 4: The controller runs the specs.** Expected: pass.
- [ ] **Step 5: Commit:** `Shift: lives rules and tracker for Gloom lives`.

### Task 2: Per-player respawn hold (Death)

**Files:**
- Create: `src/ServerScriptService/Features/Death/Rules/DeathRespawnRules.luau` and its `.spec.luau`.
- Modify: `src/ServerScriptService/Features/Death/DeathServiceServer.luau`.

**Interfaces:**
- Produces: `DeathRespawnRules.respawns(mode: "auto" | "manual", held: boolean): boolean`. It returns `mode == "auto" and not held`.
- Produces, on `DeathServiceServer`:
  - `holdRespawn(self, player: Player) -> ()`;
  - `releaseRespawn(self, player: Player) -> ()`: clears the hold and, if the player is dead, calls `respawn(player)` at once;
  - `isHeld(self, player: Player) -> boolean`.

Behaviour:
- **Auto mode:** set `Players.CharacterAutoLoads = false` always and drive auto respawn yourself. On a player's death, after `config.respawnDelay`, call `respawn(player)` if `DeathRespawnRules.respawns(config.respawn, held)` and the player is still present and dead.
- **Keep:** today's timing (`respawnDelay`, including Occupant's 8 s override through `configure`), the first spawn on join, and "manual" mode.
- **Leaving:** a player who leaves is dropped from the hold set.

- [ ] **Step 1: Write the failing spec:** `respawns("auto", false)` is true; `respawns("auto", true)`, `respawns("manual", false)` and `respawns("manual", true)` are false.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement** the rules and the service changes. Keep the service spec-exempt. Run the module map.
- [ ] **Step 4: The controller runs the full suite and a Play check:** a normal death still respawns after the delay. Expected: pass.
- [ ] **Step 5: Commit:** `Death: per-player respawn hold; auto respawn driven by Death`.

### Task 3: A catch spends a life; the last one knocks out (Shift and Occupant)

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:
  - **lives at run start:** in `beginRun`, reset lives for `RoundServiceServer:participants()` with `ShiftLivesRules.starting(STARTING_LIVES, modifiers)`, and publish `lives` and `livesMax` per player;
  - **late joiner:** admit them on transit admit;
  - **shift end:** in `clearRun`, for every knocked-out player call `releaseRespawn` and `clearField` `knockedOut`; for everyone, clear `lives` and `livesMax`, then clear the tracker.
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`:
  - `Hooks` gains `spendLife: (player: Player) -> boolean`;
  - in `begin`'s delayed block, call it **before** the kill;
  - when it returns true (knocked out), do not publish `caughtUntil`, clear the player's `rehire` flag, and send the toast `<name> is out for the shift` instead of the caught toast.
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`. Wire `spendLife = function(p) return ShiftServiceServer:spendLife(p) end`.

**Interfaces:**
- Consumes: Task 1 (`ShiftLivesRules`, `ShiftLivesTracker`, the constants) and Task 2 (`holdRespawn`, `releaseRespawn`).
- Produces:
  - `ShiftServiceServer:addLivesModifier(fn: (number) -> number): () -> ()` returns a function that removes it;
  - `ShiftServiceServer:spendLife(player: Player): boolean` returns true when this catch knocked the player out.

  `spendLife` returns false when the shift is not running or the player is unknown. On a knock-out it:
  - publishes `lives = 0` and `knockedOut = true`;
  - calls `DeathServiceServer:holdRespawn(player)`;
  - calls `RoundServiceServer:eliminate(player)`;
  - marks the roster (Task 4's `markOut`).

  Otherwise it publishes the new `lives`.

- [ ] **Step 1: Write the failing spec cases** in `OccupantCatchSystem`'s spec, if one exists, or in a new focused spec of the decision. Extract a pure helper, `OccupantCatchSystem`-adjacent in `Occupant/Utils` (`OccupantCatchUtils.afterCatch(knockedOut: boolean, backAt: number): { publishBack: number?, toast: "caught" | "out", rehire: boolean }`), and spec both branches:
  - knocked out → `publishBack = nil`, `toast = "out"`, `rehire = false`;
  - otherwise → `publishBack = backAt`, `toast = "caught"`, `rehire = true`.

  Add the new util to the New modules table when you create it.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement** the hook, the Shift methods, the run-start reset, the admit, and the shift-end release and clear.
- [ ] **Step 4: The controller runs the suite.** Expected: pass.
- [ ] **Step 5: Commit:** `Gloom lives: a catch spends a life; the last one keeps you down and out of the round`.

### Task 4: Results — a wipe is missed; record who was knocked out (Shift)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.lua`. Add `knockedOut: boolean?` to `CrewStats` and `CrewLine`.
- Modify: `src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.luau` and its spec. Add `markOut(self, userId: number, name: string) -> ()`, which sets `knockedOut = true`.
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau` and its spec:
  - `build` and `bare` set `quotaMet = input.quotaMet and input.outcome ~= RoundConstants.OUTCOME_WIPED`;
  - the rating follows that value;
  - crew lines carry `knockedOut`.
- Modify: `src/ServerScriptService/Features/Shift/Rules/ShiftClockOutRules.spec.luau`. Add a case: one crew member punched, and every other crew member is in the out list (knocked out). The shift settles to the clock-out end (`stillIn` empty), not waiting.

**Interfaces:**
- Produces: `ShiftRosterTracker:markOut` (used by Task 3's `spendLife`), and the `CrewLine.knockedOut` read by Task 5.

- [ ] **Step 1: Write the failing spec cases:**
  - `build` with `outcome = "wiped"` and `quotaMet = true` gives `quotaMet == false` and `rating == "needsImprovement"`;
  - `build` with `outcome = "clockout"` and `quotaMet = true` keeps `true`;
  - `bare("wiped", 350, true).quotaMet == false`;
  - `markOut` then `list()` has `knockedOut == true`, and the crew line carries it;
  - the clock-out case above.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement.** If the clock-out case fails, fix `ShiftClockOutRules` so an empty still-in list with at least one punch ends by clock-out.
- [ ] **Step 4: The controller runs the specs.** Expected: pass.
- [ ] **Step 5: Commit:** `Shift: a wiped shift is a missed contract; the review records who was knocked out`.

### Task 5: Lives in the UI (client)

**Files:**
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchViewModel.luau` and its spec. `cctv` also shows for a dead player whose `knockedOut == true` (no `caughtUntil`), with `back = "OUT FOR THE SHIFT"`.
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewViewModel.luau` and its spec:
  - `MemberView` gains `lives: number?`, `livesMax: number?` and `out: boolean`;
  - `statusOf` reads the `lives` and `livesMax` public fields;
  - a `knockedOut` branch comes before the caught branches: status `OUT`, short `OUT`, tone `"danger"`, struck true, `out = true`.
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewList.luau`:
  - each row draws `livesMax` pips, with `lives` of them filled, between the name and the tag;
  - the pips' column shrinks the name width the way `tagColumn` does;
  - a knocked-out row shows the tag `OUT` instead of `CAUGHT`.
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCompactHudPanel.luau` and `ShiftHudViewModel.luau`, plus their specs. The local player's own pips sit just under the Gloom meter (`METER[layout].top + METER[layout].size.Y` plus a gap). A `ShiftHudViewModel.livesFrame(layout, viewport): (Vector2, Vector2)` returns the position and size, specced to never overlap the meter, the crew list (`CrewVM.listSize`/`phoneFit`) or the clock-out board on phone (844×390) and desktop (1920×1080).
- **On a life loss,** the local pips pop briefly, scaling to 1.25 and back over 0.25 s.

**Interfaces:**
- Consumes: the public fields from Task 3, and `CrewLine.knockedOut` from Task 4 (review only; no new review screen).

- [ ] **Step 1: Write the failing spec cases:**
  - `cctv` with `dead = true`, `knockedOut = true` and no `caughtUntil` returns a view with `back == "OUT FOR THE SHIFT"`;
  - `statusOf` with `knockedOut = true` gives status `"OUT"`, `out == true`, `struck == true`;
  - `statusOf` with `lives = 2, livesMax = 3` carries both;
  - `livesFrame` doesn't overlap the meter or the crew list at 844×390 and 1920×1080.
- [ ] **Step 2: The controller runs the specs.** Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: The controller runs the specs, then renders the HUD story at phone size.** Expected: pass, with no overlap.
- [ ] **Step 5: Commit:** `UI: lives pips on the crew list and HUD; OUT state and OUT FOR THE SHIFT panel`.

### Task 6: Verification in real play (controller and owner)

- [ ] **Step 1: The full suite in Studio.** Expected: 0 failures.
- [ ] **Step 2: Controller 2-player check** (the owner starts a Local Server with 2 players):
  - get a player caught by the Manager twice: check that the pips drop and they respawn;
  - a third time: check that they stay down, spectate the other player, see `OUT FOR THE SHIFT`, the roster says `OUT` and the toast shows;
  - then the second player three times: check that the shift ends with `CONTRACT MISSED`.

  Take screenshots from both clients.
- [ ] **Step 3: The owner's play-check.** The plan is done only when the owner passes it.
- [ ] **Step 4: Update the checklist artifact** (https://claude.ai/artifact/M84j26steQDLTxxNFYJ8TM).
