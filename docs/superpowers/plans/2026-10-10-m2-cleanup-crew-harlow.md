# M2: Cleanup Crew, Mr. Harlow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put Mr. Harlow in the M1 graybox shift: he patrols, hears noise, investigates, chases on sight, catches (camera snap, lights out, ragdoll launch, spectate, "Rehired." at the loading bay), never enters the loading bay, speeds up with the pressure tiers, and takes his break when the quota is met, after which the shift runs break → overtime warning → overtime (salvage ×1.5) at the top tier. All tells are functional placeholders.

**Architecture:** Two new game features and four extended ones, on the M1 interfaces. **Noise** relays every noise (Vacuum's and Cargo's existing `noiseMade` signals, plus `emit`) as one `made` signal and a client ripple ring sized by the hearing scale. **Occupant** registers the `harlow` NPC kind (base Npc: `setBrain`, `goTo`, `setTuning`, `pathCosts`, `onAttack`) with a brain whose every decision is the pure, specced `OccupantBrainRules.step(mind, senses)`; the service gathers the senses (one synchronous ray per crew member, the last heard noise, the shift's break, the Office's route and safe zone) and executes the catch through `OccupantCatchSystem` and base Death. **Shift** grows a pacing stage (`normal | break | warning | overtime`) and a pressure tier beside M1's clock-out sub-state, a `changed` signal, notices and the overtime salvage multiplier. **Office** adds Harlow's patrol route, his rest point, ceiling lights and the loading-bay PathfindingModifier volume. **Cargo** adds the rattle pulse, the jug's slippery puddle, and the spec §6.3 `swap` / unpocket request (pockets move into `CargoPocketSystem`, keeping the service under the line cap).

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax packets, Charm + charm-sync (`shift` world entry), React (react-lua) for the placeholder HUD line, TestEZ (Studio, `RunTests = true`), SignalTyped (SignalPlus, deferred listeners), Observers, PathfindingService (costs via PathfindingModifier labels). Base APIs from M0: `NpcServiceServer:setBrain / setTuning / onAttack / despawn`, `NpcRegistry.register`, Death `kill(humanoid, cause, { launch })` / `configure({ respawnDelay })` / `isDead`, Carry `getCarried / pickUp / forceDrop / dropped`, Toast `send`, Camera `pushMode / removeMode / addTrauma`, Vfx `requestScreen / updateScreen / releaseScreen`.

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (M2 row of §9; §4 "Mr. Harlow", "Pacing", the noise lines of "Vacuum" and "Cargo and carrying"; §6.2 Noise and Occupant rows; §6.3–6.5; §7 catch and tells). Builds on `docs/superpowers/plans/2026-10-10-m0-base-game-hooks.md` and `docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md` (with `.superpowers/sdd/2026-10-10-m1-cleanup-crew-graybox/amendments.md`).

**Branch / PR:** same branch `game/cleanup-crew`, continuing after M1's commits; same PR as M1 (no new PR: the controller updates its description in Task 12; never merge).

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts without a commented justification and developer sign-off (none are planned).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`). `*.story` files need neither.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder; UI tree modules PascalCase (`ViewModel` suffix for view models, `use<Thing>` hooks). Requires use full addresses; a feature folder required from 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count).
- After adding/moving modules: `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- **Rojo safety:** the developer may be connected to `rojo serve`. Implementers never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh` (with or without `--skip-install`), and never start `rojo serve`; the per-task gate is `bash .superpowers/sdd/gate.sh` (lint, format, typecheck, rules, file length, module map). Tests run only in Studio, by the controller: steps saying "controller: Studio TestEZ" inject nothing and set the Workspace attribute `RunTests = true`, Play, read Output; gameplay checks run in a fresh Play with `RunTests = false` and use a temporary server `Script` / client `LocalScript` the controller injects (the plugin VM cannot reach live services). Only a solo player is available (no second client).
- **Module-map and commit order (every task):** `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` (re-`git add` them) → `bash .superpowers/sdd/gate.sh` → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check` (must print no FAIL). Never run `stylua src` wholesale.
- Server-authoritative: clients only send requests (a channel start/stop, `pocket`, `swap`, a vote); the server re-validates everything. Catches are decided on the server tick; drops happen on the server (spec §6.4). React components never send packets.
- Asset-id literals only in a feature's `Data/<Feature>Assets`. **M2 uses none and uploads nothing:** graybox parts, plain BillboardGuis, screen tints, base locomotion animation ids (`idle` / `walk` / `run`).
- **M2 presentation is placeholder only:** a plain billboard "?" / "!", a plain speech bubble, a red screen pulse for the heartbeat, a neon disc for the noise ripple, no sound. The final scare (stretched-grin face, distorted sting), SFX, music, gibberish voice, Kimodo animations, sticky-note/stamp toast styles, overtime red lighting and art are **M3** and must not be built here.
- **Spec numbers carried from M1 (tuning hypotheses, all in Data constants):** vacuum range 8 studs, 2.5 s per pile; canister 3 → dust bag (trash, 15); pockets 2, tiny only; walk 16, any carried item under 15; quota 350 clearance (trash only), salvage a separate bonus; shift 7:00; clock-out countdown 10 s; noise: vacuum pulse every 1 s at radius ~40; drop noise scaled by weight; rattly pulse every ~2 s; water jug dropped = very loud splash + slippery puddle; search = small noise; variant B (default) hides some salvage under piles.
- **M2 spec numbers (verbatim from spec §4, all in Data constants):**
  - States: patrol (authored route, random start and order) → investigate (walk to the last heard noise, look around ~4 s) → chase (sight ~60 studs, 100° cone, line of sight) → search (last-seen point, ~6 s) → patrol.
  - Speeds: patrol 10, chase 15. Players walk 16; any carried item pushes you under 15.
  - Catch at ~4 studs: camera snaps to his face ~0.6 s, nearby lights die; ragdoll launch (base Death ragdoll + impulse), hands and pockets scatter; spectate teammates ~8 s; "Rehired." card, respawn at the loading bay.
  - Grace: after a catch he ignores that player ~10 s and walks away. The loading bay is a safe zone he never paths into or chases into.
  - Tells: lights within ~20 studs of him flicker; heartbeat when he is near but hasn't seen you; "?" over his head investigating; "!" when he spots you; a sigh when he gives up; speech bubble lines ("Those are COMPANY ASSETS.", "Per my last email…", "You're FIRED!").
  - Pacing: shift 7:00; pressure tiers at 2:00 and 4:00: hearing radius ×1.2 and patrol speed +1 per tier, announced by a flicker and a note ("You hear Harlow pacing faster…"); party size: solo gets hearing ×0.75 and chase speed −1; quota met → break 30 s (Harlow walks to the break room) → "Overtime in 0:30, salvage ×1.5" warning 30 s → overtime at the top tier until the timer ends; salvage ×1.5 during overtime.

## Review Focus

1. **A chased player runs into the loading bay** → Harlow never paths in or catches there; he stops outside, searches the last point he saw them outside the bay, sighs and resumes patrol; noise made inside the bay is never followed. (Task 6 `OccupantBrainRules` spec "loses a player who steps into the loading bay and searches outside it", "never spots a player standing in the loading bay" and "ignores a noise inside the loading bay"; Task 7 `OccupantCatchRules` "refuses a player in the safe zone, even at arm's length"; Task 8 Step 12 checklist item 4 path test; Task 9 Step 7 checklist item 6.)
2. **A player is caught holding the water jug with two pocketed items** → the jug drops once (one splash noise, one puddle), the pockets scatter once, nothing duplicates; Harlow cannot catch the same player again during the grace or while their catch is running. (Task 7 `OccupantCatchRules` "refuses a dead player, one mid-catch, one in grace, and anyone on his break"; Task 6 "ignores the caught player during the grace, and sees them after it"; Task 4 `CargoHandlingRules` "leaves a puddle only when the jug hits the floor"; Task 10 Step 7 checklist item 3.)
3. **The quota is met late, or the crew clocks out during the break or overtime** → clock out and the pacing stage are independent, salvage ×1.5 applies only in overtime, results are still built. (Task 1 `ShiftPhaseRules` spec "keeps the overtime stage through a clock out", "multiplies salvage only in overtime", "ignores a shift that is not running".)
4. **Two crew members in sight, or the chased player dies or leaves** → Harlow keeps chasing his target while he can still see them, else the nearest; a vanished target sends him to search, never a frozen chase. (Task 6 `OccupantBrainRules` spec "keeps chasing his target over a nearer player", "searches the last place he saw them, then gives up".)
5. **Another shift or a reset happens mid-chase or mid-catch** → Harlow leaves with the shift container, a fresh Harlow starts the next shift, and a catch already in its 0.6 s snap never kills anyone after the reset. (Task 10 Step 7 checklist item 6; Task 9 Step 7 checklist item 8.)

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Noise | shared | Data | NoiseTypes | The noise event shape |
| Noise | shared | Data | NoiseConstants | Ripple look and timing |
| Noise | shared | Rules | NoiseRules | Who hears a noise: distance within radius × hearing scale |
| Noise | shared | Net | NoiseEvents | `Ripple` packet (server → clients) |
| Noise | server | (root) | NoiseServiceServer | Collects noise from Vacuum, Cargo and `emit`; fires `made`; sends ripples |
| Noise | client | (root) | NoiseServiceClient | Draws the ripple ring on the floor |
| Occupant | shared | Data | OccupantConstants | Harlow's speeds, sight, timings, tells, placeholder lines and body |
| Occupant | shared | Data | OccupantTypes | Mode, cue, mind, senses, glimpse, zone and catch-input types |
| Occupant | shared | Net | OccupantEvents | `CatchCam`, `LightsOut`, `Flicker` packets (server → clients) |
| Occupant | shared | Rules | OccupantTellRules | Cue text, bubble lines, heartbeat, pulse and flicker decisions |
| Occupant | server | Rules | OccupantBrainRules | Patrol / investigate / chase / search / rest / catch decisions, grace, safe zone |
| Occupant | server | Rules | OccupantCatchRules | Whether a catch is allowed; the launch velocity |
| Occupant | server | Utils | OccupantTuningFormulas | Speeds and hearing scale from the tier and the crew size |
| Occupant | server | Systems | OccupantRigSystem | Builds Harlow's R15 body with his cue and speech billboards |
| Occupant | server | Systems | OccupantCatchSystem | Runs the catch sequence (snap, lights out, launch) |
| Occupant | server | (root) | OccupantServiceServer | The `harlow` kind, brain, senses, tuning, spawn/despawn, catch wiring |
| Occupant | client | Systems | OccupantTellSystem | Light flicker near Harlow, lights out, tier flicker, heartbeat pulse |
| Occupant | client | (root) | OccupantServiceClient | Catch camera; routes the packets to the tell system |
| Cargo | server | Systems | CargoPocketSystem | Pockets: pocket, swap / unpocket, scatter, publish (modified: existed from M1, extended in M2) |
| Cargo | server | Systems | CargoTraitSystem | Rattle pulses while carried, splash puddles |
| Cargo | client | Systems | CargoSlipSystem | Slipping on a puddle |
| Shift | server | Systems | ShiftBankingSystem | Banking and clock-out moved out of the service |
| Shift | server | Utils | ShiftNoticeUtils | Toasts for quota met (break), tier up, overtime warning, overtime |

23 new modules. **No new subfolder kind, role word or second service.** Noise and Occupant are the spec's proposed feature names (§6.2, §11); Task 12 records them in `docs/project-structure.md`. Modified: Shift (Types, Constants, PhaseRules, ResultsUtils, SnapshotUtils, ServiceServer, HUD view model and panel, HUD story), Cargo (Types, Constants, HandlingRules, Events, PocketTracker, ServiceServer, ServiceClient), Office (Types, Constants, LayoutConstants, LayoutUtils, LayoutRules, BuildSystem, ServiceServer), `SpecRoots` (exemptions), `docs/project-structure.md`, `docs/ROADMAP.md`.

## Open questions for the developer

Designed around in this plan; none blocks M2. Every one is a reversible game-side choice.

1. **The overtime warning.** The spec reads "break 30 s → overtime warning 30 s → overtime". This plan ends Harlow's break when the warning starts: he patrols again during the 30 s warning (at the current tier), and overtime moves him to the top tier. The alternative is to keep him in the break room until overtime.
2. **Hearing per tier compounds:** ×1.2 at tier 1, ×1.44 at tier 2 (`TIER_HEARING ^ tier`). "×1.2 per tier" could also mean ×1.4 at tier 2.
3. **Tier times count from the shift's start** (2:00 and 4:00 into the 7:00 shift), not from the clock reading 2:00 / 4:00 left.
4. **"Random start and order"** is a random starting point and a random direction along the authored loop (he always walks through real doors); not a shuffled visiting order. The start is rolled by Occupant from the Office's route, not by the Office's spawn roll.
5. **Where caught items land.** Base Death and M1 Cargo drop the hands item and scatter the pockets where the player stood when killed (the catch point), not where the ragdoll lands. Moving the scatter to the landing point needs a delayed scatter in Cargo.
6. **Swap.** Bound to **X** (gamepad D-pad down). With empty hands it takes the newest pocketed item into the hands; with a tiny item in hand it trades it for the oldest pocketed item; anything bigger in hand is refused ("hands full"). No touch button until the M5 phone pass.
7. **Slippery puddle** = a slip (a short PlatformStand stumble and a shove) when a player crosses it at walking speed; the puddle lasts 25 s. Harlow does not slip.
8. **Spectate ~8 s** is Death's `respawnDelay = 8` for every death on the shift server (Occupant configures it at start).
9. **Results count catches as one total** ("Caught by Mr. Harlow: N"); per-player catches and the joke awards grow in M3.
10. **Spec §6.3's per-player public `caught` field** is not added: base Death's public `dead` field (set from the kill to the respawn) and the `CatchCam` packet already tell clients everything M2 needs; Harlow's cues ride replicated attributes and billboards rather than ByteNet packets.
11. **Base hooks this plan wished for, not needed now:** an NPC "look around" pose (Occupant turns his root itself while he stands) and a base heartbeat/tell sound layer (M3 audio).

---

### Task 0: Preflight

**Files:** none.

- [ ] **Step 1: Confirm the branch and that M1 is complete**

```bash
git branch --show-current
git log --oneline -20
```
Expected: `game/cleanup-crew`; the log contains M1's "docs: record Cleanup Crew M1 on the roadmap" commit. If M1's Task 12 commit is missing, stop and tell the controller.

- [ ] **Step 2: Confirm the M1 and base APIs this plan edits or calls** (every grep prints at least one line; if one prints nothing, stop and report which):

```bash
grep -n "noiseMade" src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau src/ServerScriptService/Features/Cargo/CargoServiceServer.luau
grep -n "local function scatter\|local function publishPockets\|pockets:take\|pockets:list" src/ServerScriptService/Features/Cargo/CargoServiceServer.luau src/ServerScriptService/Features/Cargo/Systems/*.luau
grep -n "markQuota\|ShiftResultsUtils.build\|local function setState" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "spawnCFrame\|container = function" src/ServerScriptService/Features/Office/OfficeServiceServer.luau
grep -n "setBrain = function\|setTuning = function\|onAttack = function\|despawn = function" src/ServerScriptService/Features/Npc/NpcServiceServer.luau
grep -n "kill = function\|configure = function\|isDead = function" src/ServerScriptService/Features/Death/DeathServiceServer.luau
grep -n "pickUp = function\|forceDrop = function\|getCarried = function" src/ServerScriptService/Features/Carry/CarryServiceServer.luau
grep -n "  walk = entry\|  run = entry\|  idle = entry" src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationLocomotionRegistry.luau
```
Note where `scatter` / `publishPockets` live: in `CargoServiceServer` (the M1 plan's code) or in a `CargoHandlingSystem` (M1 amendment N7, if the implementer had to split). Task 5 moves them from wherever they are.

- [ ] **Step 3: Baseline gate**

```bash
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.` If anything fails here, stop and report: it is not ours.

---
### Task 1: Shift pacing rules (stage, tier, break, overtime; pure)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau` (full replacement)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (full replacement)
- Modify: `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau` (full replacement) + `ShiftPhaseRules.spec.luau` (full replacement)
- Create: `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau` (+ `ShiftNoticeUtils.spec.luau`)
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau` (+ spec case)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau` (+ spec cases)
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (one call site, so the gate stays green)
- Modify: typed snapshot / results literals in the Shift stories (gate)

**Interfaces:**
- Consumes: `RoundTypes.RoundState` (`src/ReplicatedStorage/Shared/Features/Round/Data/RoundTypes.luau`); `ToastTypes.ToastRequest = { text: string, style: string?, duration: number? }` (`src/ReplicatedStorage/Shared/Features/Toast/Data/ToastTypes.luau`); M1's `ShiftTypes`, `ShiftConstants`, `ShiftResultsUtils.build`, `ShiftSnapshotUtils.build/decode`.
- Produces (ShiftTypes): `ShiftStage = "normal" | "break" | "warning" | "overtime"`; `ShiftState` gains `stage: ShiftStage`, `stageEndsAt: number?`, `tier: number`, `startedAt: number?`; `ShiftSnapshot` gains `stage`, `stageEndsAt: number?`, `tier`; `ShiftResults` gains `catches: number`.
- Produces (ShiftConstants, new keys): `BREAK_SECONDS = 30`, `WARNING_SECONDS = 30`, `TIER_TIMES = { 120, 240 }`, `TOP_TIER = 2`, `TIER_HEARING = 1.2`, `TIER_PATROL_SPEED = 1`, `SOLO_HEARING = 0.75`, `SOLO_CHASE_SPEED = -1`, `SCORE_CAUGHT = "caught"`, `NOTICE_SECONDS = 6`.
- Produces (ShiftPhaseRules): `initial`, `toLobby`, `follow`, `clockOut`, `tick` as in M1 (they now also set `stage = "normal"`, `tier = 0`; `follow` into running sets `startedAt = now`); `markQuota(state, cleared, now) -> ShiftState?` (**now takes `now`**; meeting the quota starts the break: `stage = "break"`, `stageEndsAt = now + BREAK_SECONDS`); `advance(state, now) -> ShiftState?` (break → warning → overtime at their deadlines; the tier from `startedAt` and `TIER_TIMES`, the top tier in overtime); `tierAt(state, now) -> number`; `salvageMultiplier(state) -> number`.
- Produces (ShiftNoticeUtils): `notices(before: ShiftState, after: ShiftState) -> { ToastRequest }`.
- Produces (ShiftResultsUtils): `ResultsInput` gains `catches: number?`; `build` sets `results.catches = input.catches or 0`.
- Produces (ShiftSnapshotUtils): `build` copies `stage`, `stageEndsAt`, `tier`; `decode` reads them (absent stage = `"normal"`, absent tier = 0, an unknown stage rejects the value) and `results.catches` (absent = 0).

- [ ] **Step 1: Write the failing specs.**

Replace `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.spec.luau` with (M1's cases kept, `markQuota` now takes `now`, new pacing cases added):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftPhaseRules = require(script.Parent.ShiftPhaseRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local function round(phase, extra)
	local state = { phase = phase, round = 1 }
	for key, value in extra or {} do
		state[key] = value
	end
	return state
end

-- A shift that started running at 100 and ends at 520.
local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("running", { endsAt = 520 }), 100)
end

local function results()
	return ShiftPhaseRules.follow(running(), round("results", { outcome = "timeout" }), 600)
end

-- Quota met at 150: break until 180, warning until 210, then overtime.
local function onBreak()
	return ShiftPhaseRules.markQuota(running(), 350, 150)
end

return function()
	it("starts in the lobby with the quota and variant", function()
		local state = ShiftPhaseRules.initial(350, "A")
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.stage).to.equal("normal")
		expect(state.tier).to.equal(0)
		expect(state.shift).to.equal(0)
		expect(state.quota).to.equal(350)
		expect(state.variant).to.equal("A")
		expect(state.quotaMet).to.equal(false)
	end)

	describe("follow", function()
		it("enters starting with Round's countdown", function()
			local state = ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("starting", { endsAt = 105 }), 100)
			expect(state.phase).to.equal("starting")
			expect(state.endsAt).to.equal(105)
		end)

		it("enters running with the shift number, start and end time, quota unmet, normal stage", function()
			local state = running()
			expect(state.phase).to.equal("running")
			expect(state.sub).to.equal("normal")
			expect(state.stage).to.equal("normal")
			expect(state.tier).to.equal(0)
			expect(state.shift).to.equal(1)
			expect(state.startedAt).to.equal(100)
			expect(state.endsAt).to.equal(520)
			expect(state.quotaMet).to.equal(false)
		end)

		it("holds results with a vote deadline when Round shows results, pacing cleared", function()
			local state = ShiftPhaseRules.follow(ShiftPhaseRules.advance(onBreak(), 215), round("results"), 600)
			expect(state.phase).to.equal("results")
			expect(state.voteEndsAt).to.equal(600 + ShiftConstants.VOTE_SECONDS)
			expect(state.endsAt).to.equal(nil)
			expect(state.clockOutAt).to.equal(nil)
			expect(state.stage).to.equal("normal")
			expect(state.stageEndsAt).to.equal(nil)
			expect(state.tier).to.equal(0)
			expect(state.quotaMet).to.equal(true)
		end)

		it("stays in results when Round goes back to its lobby", function()
			expect(ShiftPhaseRules.follow(results(), round("lobby"), 601)).to.equal(nil)
		end)

		it("goes back to the lobby when a countdown is cancelled", function()
			local starting = ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("starting", { endsAt = 5 }), 0)
			expect(ShiftPhaseRules.follow(starting, round("lobby"), 1).phase).to.equal("lobby")
		end)

		it("ignores a phase it already follows", function()
			expect(ShiftPhaseRules.follow(running(), round("running", { endsAt = 520 }), 101)).to.equal(nil)
		end)
	end)

	describe("clockOut", function()
		it("starts one countdown while running", function()
			local state = ShiftPhaseRules.clockOut(running(), 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200 + ShiftConstants.CLOCK_OUT_SECONDS)
		end)

		it("ignores a second press during the countdown", function()
			local state = ShiftPhaseRules.clockOut(running(), 200)
			expect(ShiftPhaseRules.clockOut(state, 205)).to.equal(nil)
		end)

		it("ignores a press outside a running shift", function()
			expect(ShiftPhaseRules.clockOut(ShiftPhaseRules.initial(350, "B"), 0)).to.equal(nil)
			expect(ShiftPhaseRules.clockOut(results(), 610)).to.equal(nil)
		end)

		it("keeps the overtime stage through a clock out", function()
			local overtime = ShiftPhaseRules.advance(onBreak(), 215)
			local state = ShiftPhaseRules.clockOut(overtime, 220)
			expect(state.sub).to.equal("clockout")
			expect(state.stage).to.equal("overtime")
			expect(ShiftPhaseRules.salvageMultiplier(state)).to.equal(ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER)
		end)
	end)

	describe("markQuota", function()
		it("marks the quota met once it is reached and starts the break", function()
			expect(ShiftPhaseRules.markQuota(running(), 349, 150)).to.equal(nil)
			local state = ShiftPhaseRules.markQuota(running(), 350, 150)
			expect(state.quotaMet).to.equal(true)
			expect(state.stage).to.equal("break")
			expect(state.stageEndsAt).to.equal(150 + ShiftConstants.BREAK_SECONDS)
			expect(ShiftPhaseRules.markQuota(state, 400, 160)).to.equal(nil)
		end)

		it("ignores clearance outside a running shift", function()
			expect(ShiftPhaseRules.markQuota(ShiftPhaseRules.initial(350, "B"), 500, 0)).to.equal(nil)
		end)
	end)

	describe("advance", function()
		it("steps the break into the warning, then overtime", function()
			expect(ShiftPhaseRules.advance(onBreak(), 179)).to.equal(nil)
			local warning = ShiftPhaseRules.advance(onBreak(), 180)
			expect(warning.stage).to.equal("warning")
			expect(warning.stageEndsAt).to.equal(180 + ShiftConstants.WARNING_SECONDS)
			expect(ShiftPhaseRules.advance(warning, 209)).to.equal(nil)
			local overtime = ShiftPhaseRules.advance(warning, 210)
			expect(overtime.stage).to.equal("overtime")
			expect(overtime.stageEndsAt).to.equal(nil)
		end)

		it("puts overtime at the top tier", function()
			local overtime = ShiftPhaseRules.advance(onBreak(), 215)
			expect(overtime.stage).to.equal("overtime")
			expect(overtime.tier).to.equal(ShiftConstants.TOP_TIER)
			expect(ShiftPhaseRules.advance(overtime, 216)).to.equal(nil)
		end)

		it("raises the tier at 2:00 and 4:00 into the shift, and never past the top", function()
			local state = running()
			expect(ShiftPhaseRules.advance(state, 100 + 119)).to.equal(nil)
			local tier1 = ShiftPhaseRules.advance(state, 100 + 120)
			expect(tier1.tier).to.equal(1)
			expect(ShiftPhaseRules.advance(tier1, 100 + 200)).to.equal(nil)
			local tier2 = ShiftPhaseRules.advance(tier1, 100 + 240)
			expect(tier2.tier).to.equal(2)
			expect(ShiftPhaseRules.advance(tier2, 100 + 400)).to.equal(nil)
		end)

		it("ignores a shift that is not running", function()
			expect(ShiftPhaseRules.advance(ShiftPhaseRules.initial(350, "B"), 1000)).to.equal(nil)
			expect(ShiftPhaseRules.advance(results(), 1000)).to.equal(nil)
		end)
	end)

	describe("tierAt and salvageMultiplier", function()
		it("reads the tier from the shift's start", function()
			expect(ShiftPhaseRules.tierAt(running(), 150)).to.equal(0)
			expect(ShiftPhaseRules.tierAt(running(), 230)).to.equal(1)
			expect(ShiftPhaseRules.tierAt(running(), 350)).to.equal(2)
			expect(ShiftPhaseRules.tierAt(ShiftPhaseRules.initial(350, "B"), 9999)).to.equal(0)
		end)

		it("multiplies salvage only in overtime", function()
			expect(ShiftPhaseRules.salvageMultiplier(running())).to.equal(ShiftConstants.SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.salvageMultiplier(onBreak())).to.equal(ShiftConstants.SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.salvageMultiplier(ShiftPhaseRules.advance(onBreak(), 180))).to.equal(
				ShiftConstants.SALVAGE_MULTIPLIER
			)
			expect(ShiftPhaseRules.salvageMultiplier(ShiftPhaseRules.advance(onBreak(), 215))).to.equal(1.5)
		end)
	end)

	describe("tick", function()
		it("asks to start when someone waits in the lobby", function()
			expect(ShiftPhaseRules.tick(ShiftPhaseRules.initial(350, "B"), 0, 1)).to.equal("start")
		end)

		it("never starts an empty server", function()
			expect(ShiftPhaseRules.tick(ShiftPhaseRules.initial(350, "B"), 0, 0)).to.equal("none")
		end)

		it("ends the shift when the clock-out countdown runs out", function()
			local state = ShiftPhaseRules.clockOut(running(), 200)
			expect(ShiftPhaseRules.tick(state, 209.9, 1)).to.equal("none")
			expect(ShiftPhaseRules.tick(state, 210, 1)).to.equal("endShift")
		end)

		it("resolves the vote when its time is up", function()
			local deadline = 600 + ShiftConstants.VOTE_SECONDS
			expect(ShiftPhaseRules.tick(results(), deadline - 1, 1)).to.equal("none")
			expect(ShiftPhaseRules.tick(results(), deadline, 1)).to.equal("resolveVote")
		end)

		it("does nothing mid-shift", function()
			expect(ShiftPhaseRules.tick(running(), 300, 3)).to.equal("none")
		end)
	end)

	it("returns to the lobby keeping the shift count and clearing the run", function()
		local met = ShiftPhaseRules.markQuota(ShiftPhaseRules.clockOut(running(), 200), 400, 200)
		local state = ShiftPhaseRules.toLobby(met)
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.stage).to.equal("normal")
		expect(state.stageEndsAt).to.equal(nil)
		expect(state.tier).to.equal(0)
		expect(state.shift).to.equal(1)
		expect(state.quotaMet).to.equal(false)
		expect(state.clockOutAt).to.equal(nil)
		expect(state.endsAt).to.equal(nil)
		expect(state.startedAt).to.equal(nil)
		expect(state.quota).to.equal(350)
	end)
end
```

`src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftNoticeUtils = require(script.Parent.ShiftNoticeUtils)
local ShiftPhaseRules = require(ServerScriptService.Features.Shift.Rules.ShiftPhaseRules)

local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), { phase = "running", round = 1, endsAt = 520 }, 100)
end

local function texts(list)
	local result = {}
	for _, notice in list do
		table.insert(result, notice.text)
	end
	return result
end

return function()
	it("says nothing when nothing changed", function()
		expect(#ShiftNoticeUtils.notices(running(), running())).to.equal(0)
	end)

	it("announces the quota and Harlow's break", function()
		local list = texts(ShiftNoticeUtils.notices(running(), ShiftPhaseRules.markQuota(running(), 350, 150)))
		expect(#list).to.equal(1)
		expect(string.find(list[1], "QUOTA MET", 1, true) ~= nil).to.equal(true)
		expect(string.find(list[1], "break", 1, true) ~= nil).to.equal(true)
	end)

	it("warns before overtime in the spec's words", function()
		local onBreak = ShiftPhaseRules.markQuota(running(), 350, 150)
		local list = texts(ShiftNoticeUtils.notices(onBreak, ShiftPhaseRules.advance(onBreak, 180)))
		expect(#list).to.equal(1)
		expect(list[1]).to.equal("Overtime in 0:30, salvage ×1.5")
	end)

	it("announces overtime once, without a second tier note", function()
		local warning = ShiftPhaseRules.advance(ShiftPhaseRules.markQuota(running(), 350, 150), 180)
		local list = texts(ShiftNoticeUtils.notices(warning, ShiftPhaseRules.advance(warning, 210)))
		expect(#list).to.equal(1)
		expect(string.find(list[1], "OVERTIME", 1, true) ~= nil).to.equal(true)
	end)

	it("notes each pressure tier", function()
		local list = texts(ShiftNoticeUtils.notices(running(), ShiftPhaseRules.advance(running(), 220)))
		expect(#list).to.equal(1)
		expect(list[1]).to.equal("You hear Harlow pacing faster…")
	end)

	it("stays quiet outside a running shift", function()
		local lobby = ShiftPhaseRules.initial(350, "B")
		expect(#ShiftNoticeUtils.notices(lobby, running())).to.equal(0)
	end)
end
```

Add to `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.spec.luau`, inside the top-level `return function()`, after the last `it`:

```lua
	it("carries Harlow's catches, absent reading 0", function()
		local withCatches = input(CREW)
		withCatches.catches = 3
		expect(ShiftResultsUtils.build(withCatches).catches).to.equal(3)
		expect(ShiftResultsUtils.build(input(CREW)).catches).to.equal(0)
	end)
```

Add to `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.spec.luau`, inside the top-level `return function()`, after "rejects malformed values":

```lua
	it("round-trips the pacing stage, its deadline and the tier", function()
		local snapshot = ShiftSnapshotUtils.decode(
			ShiftSnapshotUtils.build(state({ stage = "warning", stageEndsAt = 640, tier = 2 }), 0, 0, 0, 0, nil)
		)
		expect(snapshot.stage).to.equal("warning")
		expect(snapshot.stageEndsAt).to.equal(640)
		expect(snapshot.tier).to.equal(2)
	end)

	it("reads an absent stage as normal and an absent tier as 0", function()
		local snapshot = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil))
		expect(snapshot.stage).to.equal("normal")
		expect(snapshot.stageEndsAt).to.equal(nil)
		expect(snapshot.tier).to.equal(0)
	end)

	it("rejects an unknown stage or a malformed stage deadline", function()
		local good = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
		local badStage = table.clone(good)
		badStage.stage = "nap"
		local badDeadline = table.clone(good)
		badDeadline.stageEndsAt = "soon"
		expect(ShiftSnapshotUtils.decode(badStage)).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(badDeadline)).to.equal(nil)
	end)

	it("round-trips Harlow's catch count in the results, absent reading 0", function()
		local review = table.clone(RESULTS)
		review.catches = 2
		local value = ShiftSnapshotUtils.build(state({ phase = "results", voteEndsAt = 1000 }), 380, 95, 0, 0, review)
		expect(ShiftSnapshotUtils.decode(value).results.catches).to.equal(2)
		local plain = ShiftSnapshotUtils.build(state({ phase = "results", voteEndsAt = 1000 }), 380, 95, 0, 0, RESULTS)
		expect(ShiftSnapshotUtils.decode(plain).results.catches).to.equal(0)
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: `ShiftNoticeUtils.spec` errors (module missing); the new `ShiftPhaseRules` cases fail (`stage`, `tier`, `advance` missing); the new snapshot/results cases fail.

- [ ] **Step 3: Types.** Replace `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau` with:

```lua
--!strict
--[=[
	ShiftTypes: one Cleanup Crew shift's shapes (spec §3, §4 "Pacing", §6.3, §6.5). Types only (spec-exempt).

	@class ShiftTypes
]=]

-- Mirrors Round's phases, except that Shift holds `results` itself until the crew votes.
export type ShiftPhase = "lobby" | "starting" | "running" | "results"

-- The clock-out countdown. Independent of the pacing stage: a crew may clock out during the break or overtime.
export type ShiftSub = "normal" | "clockout"

-- Pacing after the quota (spec §4 "Pacing"): break (Harlow rests) → overtime warning → overtime.
export type ShiftStage = "normal" | "break" | "warning" | "overtime"

-- The A/B validation switch (spec §4): B hides some salvage under piles, A exposes it all.
export type Variant = "A" | "B"

export type Vote = "another" | "depot"

-- What the service should do on this clock step.
export type TickAction = "none" | "start" | "endShift" | "resolveVote"

-- The server's shift machine. Times are server time (workspace:GetServerTimeNow()).
export type ShiftState = {
	phase: ShiftPhase,
	sub: ShiftSub,
	stage: ShiftStage,
	-- When the break or the warning ends; nil in the normal stage and in overtime.
	stageEndsAt: number?,
	-- Pressure tier: 0, +1 at each ShiftConstants.TIER_TIMES mark, the top tier in overtime.
	tier: number,
	-- Shifts started on this server (Round's run number).
	shift: number,
	-- running: when the shift began (the tiers count from here).
	startedAt: number?,
	-- starting: the arrival countdown's end; running: the shift's end.
	endsAt: number?,
	-- When the clock-out countdown ends the shift.
	clockOutAt: number?,
	-- When the results vote closes.
	voteEndsAt: number?,
	quota: number,
	quotaMet: boolean,
	variant: Variant,
}

-- One crew member's run, as the results builder reads it.
export type CrewStats = {
	userId: number,
	name: string,
	banked: number,
	piles: number,
	salvage: number,
}

export type CrewLine = {
	name: string,
	banked: number,
	piles: number,
	salvage: number,
}

export type Award = {
	title: string,
	name: string,
}

-- The performance review (plain in M1-M2).
export type ShiftResults = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	-- Salvage items loaded, and piles vacuumed, by the whole crew.
	salvage: number,
	piles: number,
	-- Times Mr. Harlow caught someone this shift.
	catches: number,
	quotaMet: boolean,
	crew: { CrewLine },
	awards: { Award },
}

-- What every client sees (the `shift` world entry).
export type ShiftSnapshot = {
	phase: ShiftPhase,
	sub: ShiftSub,
	stage: ShiftStage,
	stageEndsAt: number?,
	tier: number,
	shift: number,
	endsAt: number?,
	clockOutAt: number?,
	voteEndsAt: number?,
	quota: number,
	cleared: number,
	bonus: number,
	quotaMet: boolean,
	variant: Variant,
	votesAnother: number,
	votesDepot: number,
	results: ShiftResults?,
}

return {}
```

- [ ] **Step 4: Constants.** Replace `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` with:

```lua
--!strict
--[=[
	ShiftConstants: the shift's pacing and names (Cleanup Crew spec §3, §4 "Pacing": one constants module for
	the shift clock, the pressure tiers and the party-size scaling). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class ShiftConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local VARIANT: ShiftTypes.Variant = "B"

-- Seconds into the shift at which the pressure tier rises (2:00 and 4:00).
local TIER_TIMES: { number } = { 120, 240 }

return table.freeze({
	-- The StateSyncWorldStore entry the snapshot is published under.
	WORLD_ENTRY = "shift",
	-- Clearance (trash value) the crew must load.
	QUOTA = 350,
	-- 7:00 on the clock.
	SHIFT_SECONDS = 420,
	-- The arrival card (Round's countdown).
	ARRIVAL_SECONDS = 5,
	CLOCK_OUT_SECONDS = 10,
	-- How long the results vote stays open.
	VOTE_SECONDS = 30,
	MIN_PLAYERS = 1,
	VARIANT = VARIANT,
	-- Salvage multiplier normally, and in overtime.
	SALVAGE_MULTIPLIER = 1,
	OVERTIME_SALVAGE_MULTIPLIER = 1.5,
	-- After the quota: Harlow's break, then the overtime warning, then overtime (until the shift ends).
	BREAK_SECONDS = 30,
	WARNING_SECONDS = 30,
	-- Pressure tiers: each step multiplies Harlow's hearing and adds to his patrol speed; overtime is the top.
	TIER_TIMES = table.freeze(TIER_TIMES),
	TOP_TIER = 2,
	TIER_HEARING = 1.2,
	TIER_PATROL_SPEED = 1,
	-- A solo player gets a gentler Harlow.
	SOLO_HEARING = 0.75,
	SOLO_CHASE_SPEED = -1,
	-- Round team counters and per-player scores.
	CLEARANCE = "clearance",
	BONUS = "bonus",
	SCORE_BANKED = "banked",
	SCORE_PILES = "piles",
	SCORE_SALVAGE = "salvage",
	SCORE_CAUGHT = "caught",
	-- The outcome a clock out ends the run with (Round sets "timeout" and "abandoned" itself).
	OUTCOME_CLOCKOUT = "clockout",
	-- The outcome a mid-shift reset (Studio test runs) ends the run with; no results are shown for it.
	OUTCOME_RESET = "reset",
	-- The interaction kind on the truck's time clock.
	CLOCK_OUT_KIND = "shift-clockout",
	TICK_INTERVAL = 0.25,
	-- How long the pacing notices stay up.
	NOTICE_SECONDS = 6,
	-- HUD widget order (the Toast stack draws above, at 1000).
	HUD_ORDER = 10,
})
```

- [ ] **Step 5: Phase rules.** Replace `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau` with:

```lua
--!strict
--[=[
	ShiftPhaseRules: a Cleanup Crew shift as pure functions over ShiftState (spec §3, §4 "Pacing", §6.5). The
	shift follows Round's phases (lobby → starting → running → results) but keeps `results` itself until the
	crew votes: Round is configured to leave results at once (it cannot be held or cut short).

	While running, two things move independently: the clock-out countdown (`sub`) and the pacing `stage`.
	Meeting the quota starts Harlow's break; `advance` steps break → overtime warning → overtime at their
	deadlines, and keeps the pressure tier current (one more at each TIER_TIMES mark from the shift's start;
	overtime is the top tier).

	Every function returns the NEXT state, or nil when nothing changes; `tick` returns what the service should
	do on this clock step.

	@class ShiftPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftState = ShiftTypes.ShiftState
type ShiftStage = ShiftTypes.ShiftStage

-- The tier for a stage at `now`, counting from `startedAt`.
local function tierFor(stage: ShiftStage, startedAt: number?, now: number): number
	if stage == "overtime" then
		return ShiftConstants.TOP_TIER
	end
	if startedAt == nil then
		return 0
	end
	local elapsed = now - startedAt
	local tier = 0
	for _, mark in ShiftConstants.TIER_TIMES do
		if elapsed >= mark then
			tier += 1
		end
	end
	return math.min(tier, ShiftConstants.TOP_TIER)
end

local ShiftPhaseRules = {}

function ShiftPhaseRules.initial(quota: number, variant: ShiftTypes.Variant): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 0,
		quota = quota,
		quotaMet = false,
		variant = variant,
	}
end

--[=[
	Back to waiting, keeping the shift count, quota and variant (a cancelled countdown, or a reset after the
	vote).
]=]
function ShiftPhaseRules.toLobby(state: ShiftState): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = state.shift,
		quota = state.quota,
		quotaMet = false,
		variant = state.variant,
	}
end

--[=[
	Follows a Round phase change. Results are held until the vote even after Round returns to its lobby.
]=]
function ShiftPhaseRules.follow(state: ShiftState, round: RoundTypes.RoundState, now: number): ShiftState?
	if round.phase == "starting" and state.phase == "lobby" then
		local nextState = table.clone(state)
		nextState.phase = "starting"
		nextState.endsAt = round.endsAt
		return nextState
	end
	if round.phase == "running" and state.phase ~= "running" then
		return {
			phase = "running",
			sub = "normal",
			stage = "normal",
			tier = 0,
			shift = round.round,
			startedAt = now,
			endsAt = round.endsAt,
			quota = state.quota,
			quotaMet = false,
			variant = state.variant,
		}
	end
	if round.phase == "results" and state.phase == "running" then
		return {
			phase = "results",
			sub = "normal",
			stage = "normal",
			tier = 0,
			shift = state.shift,
			voteEndsAt = now + ShiftConstants.VOTE_SECONDS,
			quota = state.quota,
			quotaMet = state.quotaMet,
			variant = state.variant,
		}
	end
	if round.phase == "lobby" and state.phase == "starting" then
		return ShiftPhaseRules.toLobby(state)
	end
	return nil
end

--[=[
	Starts the clock-out countdown. Only while running and not already counting down. The pacing stage is
	untouched (overtime still pays ×1.5 during the countdown).
]=]
function ShiftPhaseRules.clockOut(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" or state.sub ~= "normal" then
		return nil
	end
	local nextState = table.clone(state)
	nextState.sub = "clockout"
	nextState.clockOutAt = now + ShiftConstants.CLOCK_OUT_SECONDS
	return nextState
end

--[=[
	Marks the quota met the first time clearance reaches it during a running shift, and starts Harlow's
	break (BREAK_SECONDS from `now`).
]=]
function ShiftPhaseRules.markQuota(state: ShiftState, cleared: number, now: number): ShiftState?
	if state.phase ~= "running" or state.quotaMet or cleared < state.quota then
		return nil
	end
	local nextState = table.clone(state)
	nextState.quotaMet = true
	if state.stage == "normal" then
		nextState.stage = "break"
		nextState.stageEndsAt = now + ShiftConstants.BREAK_SECONDS
	end
	return nextState
end

--[=[
	Moves the pacing on to `now`: break → warning (WARNING_SECONDS) → overtime at their deadlines, and the
	tier. Nil when nothing changed or the shift is not running.
]=]
function ShiftPhaseRules.advance(state: ShiftState, now: number): ShiftState?
	if state.phase ~= "running" then
		return nil
	end
	local stage: ShiftStage = state.stage
	local stageEndsAt = state.stageEndsAt
	if stage == "break" and stageEndsAt ~= nil and now >= stageEndsAt then
		stage = "warning"
		stageEndsAt = stageEndsAt + ShiftConstants.WARNING_SECONDS
	end
	if stage == "warning" and stageEndsAt ~= nil and now >= stageEndsAt then
		stage = "overtime"
		stageEndsAt = nil
	end
	local tier = tierFor(stage, state.startedAt, now)
	local sameStage = stage == state.stage
	if sameStage and stageEndsAt == state.stageEndsAt and tier == state.tier then
		return nil
	end
	local nextState = table.clone(state)
	nextState.stage = stage
	nextState.stageEndsAt = stageEndsAt
	nextState.tier = tier
	return nextState
end

--[=[
	The pressure tier at `now` (0 outside a running shift).
]=]
function ShiftPhaseRules.tierAt(state: ShiftState, now: number): number
	if state.phase ~= "running" then
		return 0
	end
	return tierFor(state.stage, state.startedAt, now)
end

--[=[
	What salvage is multiplied by when banked now: ×1.5 in overtime, else ×1.
]=]
function ShiftPhaseRules.salvageMultiplier(state: ShiftState): number
	if state.stage == "overtime" then
		return ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	end
	return ShiftConstants.SALVAGE_MULTIPLIER
end

--[=[
	What to do on this clock step: start a countdown (someone is waiting in the lobby), end the shift (the
	clock-out countdown ran out), resolve the vote (its time is up), or nothing.
]=]
function ShiftPhaseRules.tick(state: ShiftState, now: number, present: number): ShiftTypes.TickAction
	if state.phase == "lobby" and present >= ShiftConstants.MIN_PLAYERS then
		return "start"
	end
	local clockOutAt = state.clockOutAt
	if state.phase == "running" and state.sub == "clockout" and clockOutAt ~= nil and now >= clockOutAt then
		return "endShift"
	end
	local voteEndsAt = state.voteEndsAt
	if state.phase == "results" and voteEndsAt ~= nil and now >= voteEndsAt then
		return "resolveVote"
	end
	return "none"
end

return ShiftPhaseRules
```

If luau-lsp widens `stage` after a literal assignment, keep the `local stage: ShiftStage` annotation and compare through the `sameStage` local (the M1 RoundSnapshotUtils note); no cast.

- [ ] **Step 6: Notices** `src/ServerScriptService/Features/Shift/Utils/ShiftNoticeUtils.luau`:

```lua
--!strict
--[=[
	ShiftNoticeUtils: what the crew is told when the pacing moves (spec §3 step 5, §4 "Pacing", §7): the quota
	met and Harlow's break; "Overtime in 0:30, salvage ×1.5"; overtime itself; and each pressure tier ("You
	hear Harlow pacing faster…"). Plain toasts in M2; the stamp and sticky-note styles are M3. Pure: the
	service sends what this returns.

	@class ShiftNoticeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type ToastRequest = ToastTypes.ToastRequest

-- "m:ss", seconds rounded up.
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local ShiftNoticeUtils = {}

--[=[
	The toasts for the step from `before` to `after` (both running; otherwise none), in the order they happen.
]=]
function ShiftNoticeUtils.notices(before: ShiftTypes.ShiftState, after: ShiftTypes.ShiftState): { ToastRequest }
	local list: { ToastRequest } = {}
	if before.phase ~= "running" or after.phase ~= "running" then
		return list
	end
	local duration = ShiftConstants.NOTICE_SECONDS
	local multiplier = ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER
	if after.quotaMet and not before.quotaMet then
		table.insert(list, {
			text = `QUOTA MET. Mr. Harlow is on his break for {clock(ShiftConstants.BREAK_SECONDS)}: regroup and bank.`,
			duration = duration,
		})
	end
	if after.stage == "warning" and before.stage ~= "warning" then
		table.insert(list, {
			text = `Overtime in {clock(ShiftConstants.WARNING_SECONDS)}, salvage ×{multiplier}`,
			duration = duration,
		})
	end
	if after.stage == "overtime" and before.stage ~= "overtime" then
		table.insert(list, {
			text = `OVERTIME. Salvage ×{multiplier} until the clock runs out. Harlow is back, and faster.`,
			duration = duration,
		})
	elseif after.tier > before.tier then
		table.insert(list, { text = "You hear Harlow pacing faster…", duration = duration })
	end
	return list
end

return ShiftNoticeUtils
```

- [ ] **Step 7: Results.** In `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau`:
  - In `export type ResultsInput`, after `quotaMet: boolean,` add:
    ```lua
    	-- Times Mr. Harlow caught someone (M2); absent reads 0.
    	catches: number?,
    ```
  - In the table `build` returns, after `piles = piles,` add `catches = input.catches or 0,`.

- [ ] **Step 8: Snapshot codec.** In `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau`:
  - After the `subOf` function add:
    ```lua
    -- The pacing stage: absent reads "normal" (an older snapshot); anything unknown is malformed.
    local function stageOf(value: WorldValue?): ShiftTypes.ShiftStage?
    	if value == nil or value == "normal" then
    		return "normal"
    	elseif value == "break" then
    		return "break"
    	elseif value == "warning" then
    		return "warning"
    	elseif value == "overtime" then
    		return "overtime"
    	end
    	return nil
    end
    ```
  - In `resultsOf`, after `local awards = awardsOf(value.awards)` add `local catches, catchesOk = countOf(value.catches)`; after the `if crew == nil or awards == nil then return nil, false end` guard add:
    ```lua
    	if not catchesOk then
    		return nil, false
    	end
    ```
    and in the returned results table, after `piles = piles,`, add `catches = catches,`.
  - In `build`'s returned table, after `sub = state.sub,` add:
    ```lua
    		stage = state.stage,
    		stageEndsAt = state.stageEndsAt,
    		tier = state.tier,
    ```
  - In `decode`, after `local variant: ShiftTypes.Variant? = variantOf(value.variant)` add `local stage: ShiftTypes.ShiftStage? = stageOf(value.stage)`, and after the `if not phase or not sub or not variant then return nil end` guard add:
    ```lua
    	if not stage then
    		return nil
    	end
    ```
    After `local voteEndsAt, voteOk = optionalNumber(value.voteEndsAt)` add:
    ```lua
    	local stageEndsAt, stageEndsOk = optionalNumber(value.stageEndsAt)
    	local tier, tierOk = countOf(value.tier)
    ```
    extend the combined check to `if not (endsOk and clockOk and voteOk and anotherOk and depotOk and resultsOk and stageEndsOk and tierOk) then return nil end`, and in the `snapshot` table after `sub = sub,` add `stage = stage, stageEndsAt = stageEndsAt, tier = tier,` (one per line, stylua formats).

- [ ] **Step 9: Keep the gate green.**
  - `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`: the `markQuota` call becomes `ShiftPhaseRules.markQuota(state, RoundServiceServer:teamValue(ShiftConstants.CLEARANCE), now())` (Task 2 reworks banking; this is only so the call type-checks).
  - Typed literals: run `grep -rn "ShiftTypes.ShiftSnapshot = {\|ShiftTypes.ShiftResults = {\|ShiftTypes.ShiftState = {" src` and add the new required fields to each hit outside specs: a snapshot gets `stage = "normal",` and `tier = 0,`; a results table gets `catches = 0,`. Expected hits: `ShiftHudPanel.story.luau` (snapshot) and, if it builds one, `ShiftResultsPanel.story.luau` (results).

- [ ] **Step 10: Exemption.** None: ShiftNoticeUtils has a spec.

- [ ] **Step 11: Module map, format and gate** (order from the Global Constraints): `git add src` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua` on every file touched in this task → `bash .superpowers/sdd/gate.sh`. Expected: `==> All checks passed.`

- [ ] **Step 12: Controller: Studio TestEZ.** Expected: ShiftPhaseRules, ShiftNoticeUtils, ShiftResultsUtils, ShiftSnapshotUtils and ShiftHudViewModel specs pass; `assertAllModulesSpecced` passes.

- [ ] **Step 13: Commit**

```bash
git commit -m "feat(shift): pacing stages, pressure tiers and notices"
python3 scripts/python/module_map.py --check
```

---
### Task 2: Shift runtime pacing (break, overtime, tiers, catches) and the HUD stage line

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau` (+ spec cases)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudPanel.luau`

**Interfaces:**
- Consumes (Task 1): `ShiftPhaseRules.advance / markQuota(state, cleared, now) / salvageMultiplier`, `ShiftNoticeUtils.notices`, `ShiftConstants.SCORE_CAUGHT / OVERTIME_SALVAGE_MULTIPLIER`; base `SignalTyped.new()`, `RoundServiceServer:addScore / scoreOf / participants`, `ToastServiceServer:send`.
- Produces (ShiftServiceServer, new): `changed: SignalTyped.Signal<ShiftTypes.ShiftState>` (fired with a copy on every state change; SignalPlus delivers it deferred), `noteCatch(player: Player) -> boolean` (adds 1 to the player's `caught` score while running). The results now carry `catches`; banking multiplies salvage by `ShiftPhaseRules.salvageMultiplier(state)`; every state change sends `ShiftNoticeUtils.notices` to everyone (this replaces M1's QUOTA MET toast in `onBanked`).
- Produces (ShiftHudViewModel): `HudView` gains `stage: string?` ("BREAK m:ss: Mr. Harlow is on his break" / "OVERTIME IN m:ss" / "OVERTIME: salvage x1.5"); the results lines end with "Caught by Mr. Harlow: N".

- [ ] **Step 1: Write the failing view-model cases.** Add to `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.spec.luau`, inside the top-level `return function()`, after the `describe("results", ...)` block:

```lua
	describe("pacing line", function()
		it("counts down Harlow's break", function()
			local view = ShiftHudViewModel.hud(snapshot({ stage = "break", stageEndsAt = 124 }), nil, 100)
			expect(view.stage).to.equal("BREAK 0:24: Mr. Harlow is on his break")
		end)

		it("warns before overtime", function()
			local view = ShiftHudViewModel.hud(snapshot({ stage = "warning", stageEndsAt = 112 }), nil, 100)
			expect(view.stage).to.equal("OVERTIME IN 0:12")
		end)

		it("marks overtime with its multiplier", function()
			local view = ShiftHudViewModel.hud(snapshot({ stage = "overtime" }), nil, 100)
			expect(view.stage).to.equal("OVERTIME: salvage x1.5")
		end)

		it("shows no pacing line in a normal shift", function()
			expect(ShiftHudViewModel.hud(snapshot({ stage = "normal" }), nil, 100).stage).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot(), nil, 100).stage).to.equal(nil)
		end)
	end)

	it("ends the review with Harlow's catches", function()
		local review = table.clone(REVIEW)
		review.catches = 2
		local view = ShiftHudViewModel.results(snapshot({ phase = "results", voteEndsAt = 130, results = review }), 100)
		expect(view.lines[#view.lines]).to.equal("Caught by Mr. Harlow: 2")
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the five new cases fail (`stage` nil, no catches line).

- [ ] **Step 3: View model.** In `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau`:
  - Add the require `local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)` (keep the requires sorted as stylua/selene expect; two Shift modules stay full addresses).
  - In `export type HudView`, after `clockOut: string?,` add:
    ```lua
    	-- The pacing after the quota (break, overtime warning, overtime); nil in a normal shift.
    	stage: string?,
    ```
  - In `ShiftHudViewModel.hud`, before `return {`, add:
    ```lua
    	local stageEndsAt = snapshot.stageEndsAt
    	local stageLeft = if stageEndsAt ~= nil then stageEndsAt - now else 0
    	local stage: string? = nil
    	if snapshot.stage == "break" then
    		stage = `BREAK {ShiftHudViewModel.clock(stageLeft)}: Mr. Harlow is on his break`
    	elseif snapshot.stage == "warning" then
    		stage = `OVERTIME IN {ShiftHudViewModel.clock(stageLeft)}`
    	elseif snapshot.stage == "overtime" then
    		stage = `OVERTIME: salvage x{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}`
    	end
    ```
    and in the returned table, after the `clockOut = ...` entry, add `stage = stage,`.
  - In `ShiftHudViewModel.results`, after the `for _, award in review.awards do ... end` loop (still inside `if review ~= nil then`), add:
    ```lua
    		table.insert(lines, `Caught by Mr. Harlow: {review.catches}`)
    ```

- [ ] **Step 4: HUD panel.** In `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudPanel.luau`, replace the clock-out block

```lua
	local clockOut = view.clockOut
	if clockOut ~= nil then
		children.clockOut = line(7, clockOut, Tokens.color.danger, Tokens.textSize.xxl)
	end
```

with

```lua
	local stage = view.stage
	if stage ~= nil then
		children.stage = line(7, stage, Tokens.color.warning, body)
	end
	local clockOut = view.clockOut
	if clockOut ~= nil then
		children.clockOut = line(8, clockOut, Tokens.color.danger, Tokens.textSize.xxl)
	end
```

and add to its header comment: `M2: a pacing line (break / overtime warning / overtime) under the pockets.`

- [ ] **Step 5: Server.** In `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:

  1. Requires: add `local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)` and `local ShiftNoticeUtils = require(ShiftServer.Utils.ShiftNoticeUtils)` (beside the other `ShiftServer` requires).
  2. Module state: after `local stoppers: { () -> () } = {}` add
     ```lua
     -- Every state change (a copy), for Occupant (Harlow follows the run, its break and its tier).
     local changed: SignalTyped.Signal<ShiftTypes.ShiftState> = SignalTyped.new()
     ```
  3. Replace `setState` with:
     ```lua
     -- The one way the state changes: tells the crew what the pacing did, tells listeners, republishes.
     local function setState(nextState: ShiftTypes.ShiftState)
     	local before = state
     	state = nextState
     	for _, notice in ShiftNoticeUtils.notices(before, nextState) do
     		ToastServiceServer:send("all", notice)
     	end
     	changed:Fire(table.clone(nextState))
     	publish()
     end
     ```
  4. After `crewStats` add:
     ```lua
     -- Harlow's catches this run (the review's "Caught by Mr. Harlow").
     local function catchTotal(): number
     	local total = 0
     	for _, player in RoundServiceServer:participants() do
     		total += RoundServiceServer:scoreOf(player, ShiftConstants.SCORE_CAUGHT)
     	end
     	return total
     end
     ```
     and add `catches = catchTotal(),` to **every** `ShiftResultsUtils.build({ ... })` call in the file (M1's `onRoundPhase`, and the `endShift` branch if amendment N6 added one there).
  5. Replace the whole `onBanked` function with:
     ```lua
     -- Cargo's banking handler: synchronous (claim → add → destroy happens around it). Salvage is multiplied in
     -- overtime (ShiftPhaseRules.salvageMultiplier); meeting the quota starts the break (its notice comes from
     -- setState, ShiftNoticeUtils).
     local function onBanked(player: Player, deposit: CargoTypes.Deposit): boolean
     	if state.phase ~= "running" then
     		return false
     	end
     	local multiplier = ShiftPhaseRules.salvageMultiplier(state)
     	local bonus = math.floor(deposit.bonus * multiplier + 0.5)
     	local salvage = 0
     	for _, item in deposit.items do
     		if item.category == "salvage" then
     			salvage += 1
     		end
     	end
     	if deposit.clearance > 0 then
     		RoundServiceServer:addTeam(ShiftConstants.CLEARANCE, deposit.clearance)
     	end
     	if bonus > 0 then
     		RoundServiceServer:addTeam(ShiftConstants.BONUS, bonus)
     	end
     	RoundServiceServer:addScore(player, ShiftConstants.SCORE_BANKED, deposit.clearance + bonus)
     	if salvage > 0 then
     		RoundServiceServer:addScore(player, ShiftConstants.SCORE_SALVAGE, salvage)
     	end
     	local overtime = if multiplier > 1 then ` (overtime x{multiplier})` else ""
     	ToastServiceServer:send(player, {
     		text = `Loaded: +{deposit.clearance} clearance, +{bonus} bonus{overtime}`,
     		duration = 2,
     	})
     	local met = ShiftPhaseRules.markQuota(state, RoundServiceServer:teamValue(ShiftConstants.CLEARANCE), now())
     	if met ~= nil then
     		setState(met)
     	else
     		publish()
     	end
     	return true
     end
     ```
     (M1's "QUOTA MET. Salvage is a bonus now…" toast is gone: ShiftNoticeUtils announces the quota and the break.)
  6. In `step`, before `local action = ShiftPhaseRules.tick(...)`, add:
     ```lua
     	local advanced = ShiftPhaseRules.advance(state, now())
     	if advanced ~= nil then
     		setState(advanced)
     	end
     ```
  7. In `export type ShiftServiceServer`, add `changed: SignalTyped.Signal<ShiftTypes.ShiftState>,` and `noteCatch: (self: ShiftServiceServer, player: Player) -> boolean,`. In the literal, add `changed = changed,` after `dependencies`, and the method:
     ```lua
     	--[=[
     		Counts a catch by Mr. Harlow against the player (the review). False outside a running shift.
     	]=]
     	noteCatch = function(_self, player)
     		if state.phase ~= "running" then
     			return false
     		end
     		RoundServiceServer:addScore(player, ShiftConstants.SCORE_CAUGHT, 1)
     		publish()
     		return true
     	end,
     ```
  8. In `getState`, add `stage = state.stage,`, `stageEndsAt = state.stageEndsAt,`, `tier = state.tier,`, `catches = catchTotal(),`.
  9. Header comment: add a bullet `- pacing (M2): meeting the quota starts Harlow's break; the clock steps break → overtime warning → overtime (salvage ×1.5) and raises the pressure tier at 2:00 and 4:00 (ShiftPhaseRules.advance), each change announced (ShiftNoticeUtils) and fired on \`changed\`.`

  Check `python3 scripts/python/check_file_length.py` stays under 400 for this file (expected ~345 code lines).

- [ ] **Step 6: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 7: Controller: Studio TestEZ** (`RunTests = true`). Expected: everything passes.

- [ ] **Step 8: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local S = require(game.ServerScriptService.Features.Shift.ShiftServiceServer)
local R = require(game.ServerScriptService.Features.Round.RoundServiceServer)
S.changed:Connect(function(state) print("SHIFT", state.phase, state.stage, state.tier, state.stageEndsAt) end)
_G.S, _G.R = S, R
```
Checklist (command bar uses `_G.S` / `_G.R`; `player = game.Players:GetPlayers()[1]`):
1. A shift starts: `SHIFT running normal 0 nil`; the HUD has no pacing line.
2. Wait 2:00 into the shift: toast "You hear Harlow pacing faster…", `SHIFT running normal 1`, `_G.S:getState().tier == 1`.
3. `_G.R:addTeam("clearance", 345)`, then Load a rubbish bag: one toast "QUOTA MET. Mr. Harlow is on his break for 0:30: regroup and bank."; HUD line `BREAK 0:30: Mr. Harlow is on his break` counting down; `SHIFT running break`.
4. 30 s later: toast "Overtime in 0:30, salvage ×1.5"; HUD `OVERTIME IN 0:30`; 30 s later: the OVERTIME toast; HUD `OVERTIME: salvage x1.5`; `getState().tier == 2`.
5. In overtime, pocket a plaque and Load: toast `Loaded: +0 clearance, +38 bonus (overtime x1.5)` (25 × 1.5 rounded).
6. `_G.S:noteCatch(player)` → true. Clock out at the truck during overtime: the countdown runs, the HUD still shows the overtime line; results show "Caught by Mr. Harlow: 1" as the last line.
7. Another shift: `SHIFT lobby normal 0`, then `running normal 0`; no pacing line.

- [ ] **Step 9: Commit**

```bash
git commit -m "feat(shift): break, overtime and tiers at runtime; catches in the review"
python3 scripts/python/module_map.py --check
```

---
### Task 3: Noise (one stream of noise events, who hears them, the ripple ring)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Noise/Rules/NoiseRules.luau` (+ `NoiseRules.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Noise/Net/NoiseEvents.luau`
- Create: `src/ServerScriptService/Features/Noise/NoiseServiceServer.luau`
- Create: `src/ReplicatedStorage/Client/Features/Noise/NoiseServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (M1): `VacuumServiceServer.noiseMade: SignalTyped.Signal<Vector3, number, string>` (source `"vacuum"`, radius `VacuumConstants.NOISE_RADIUS`); `CargoServiceServer.noiseMade: SignalTyped.Signal<Vector3, number, string>` (sources `"drop"` with `CargoHandlingRules.dropNoise(def)` incl. the jug's `SPLASH_NOISE`, `"search"` with `SEARCH_NOISE`; Task 4 adds `"rattle"` with `RATTLE_NOISE`).
- Produces (NoiseTypes): `NoiseEvent = { position: Vector3, radius: number, source: string }`.
- Produces (NoiseRules): `heardRadius(radius: number, scale: number) -> number`, `hears(listener: Vector3, origin: Vector3, radius: number, scale: number) -> boolean`.
- Produces (NoiseEvents): `packets.Ripple` (server → clients) `{ position: vec3, radius: float32 }`.
- Produces (NoiseServiceServer): `made: SignalTyped.Signal<NoiseEvent>` (deferred), `emit(position: Vector3, radius: number, source: string) -> ()`, `setHearingScale(scale: number) -> ()`, `getHearingScale() -> number`.
- Produces (NoiseServiceClient): no API; draws a ripple for each `Ripple`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Shared/Features/Noise/Rules/NoiseRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseRules = require(script.Parent.NoiseRules)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoHandlingRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoHandlingRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

local ORIGIN = Vector3.new(0, 0, 0)

local function at(distance)
	return Vector3.new(distance, 0, 0)
end

return function()
	describe("hears", function()
		it("hears a noise within its radius, not beyond", function()
			expect(NoiseRules.hears(at(39.9), ORIGIN, 40, 1)).to.equal(true)
			expect(NoiseRules.hears(at(40), ORIGIN, 40, 1)).to.equal(true)
			expect(NoiseRules.hears(at(40.1), ORIGIN, 40, 1)).to.equal(false)
		end)

		it("scales the radius by the hearing scale", function()
			expect(NoiseRules.hears(at(47), ORIGIN, 40, 1.2)).to.equal(true)
			expect(NoiseRules.hears(at(31), ORIGIN, 40, 0.75)).to.equal(false)
		end)

		it("counts height", function()
			expect(NoiseRules.hears(Vector3.new(0, 30, 30), ORIGIN, 40, 1)).to.equal(false)
		end)

		it("never hears a silent noise or with no hearing", function()
			expect(NoiseRules.hears(ORIGIN, ORIGIN, 0, 1)).to.equal(false)
			expect(NoiseRules.hears(ORIGIN, ORIGIN, 40, 0)).to.equal(false)
		end)
	end)

	describe("heardRadius", function()
		it("is the radius times the scale, never negative", function()
			expect(NoiseRules.heardRadius(40, 1.2)).to.be.near(48, 1e-6)
			expect(NoiseRules.heardRadius(-5, 1)).to.equal(0)
			expect(NoiseRules.heardRadius(40, -1)).to.equal(0)
		end)
	end)

	describe("the spec's noise per action", function()
		it("a vacuum pulse carries about 40 studs", function()
			expect(VacuumConstants.NOISE_RADIUS).to.equal(40)
			expect(VacuumConstants.NOISE_INTERVAL).to.equal(1)
		end)

		it("a drop is as loud as the item is heavy, and the jug's splash is loudest", function()
			local plaque = CargoHandlingRules.dropNoise(CargoRegistry.get("plaque"))
			local bag = CargoHandlingRules.dropNoise(CargoRegistry.get("rubbishBag"))
			local monitor = CargoHandlingRules.dropNoise(CargoRegistry.get("monitor"))
			local printer = CargoHandlingRules.dropNoise(CargoRegistry.get("printer"))
			local cabinet = CargoHandlingRules.dropNoise(CargoRegistry.get("filingCabinet"))
			local jug = CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))
			expect(plaque < bag and bag < monitor and monitor < printer and printer <= cabinet).to.equal(true)
			expect(jug).to.equal(CargoConstants.SPLASH_NOISE)
			expect(jug > VacuumConstants.NOISE_RADIUS).to.equal(true)
		end)

		it("a rattle and a search are small", function()
			expect(CargoConstants.RATTLE_NOISE < VacuumConstants.NOISE_RADIUS).to.equal(true)
			expect(CargoConstants.SEARCH_NOISE < VacuumConstants.NOISE_RADIUS).to.equal(true)
			expect(CargoConstants.RATTLE_INTERVAL).to.equal(2)
		end)

		it("a dropped plaque goes unheard where a splash is heard", function()
			local plaque = CargoHandlingRules.dropNoise(CargoRegistry.get("plaque"))
			local jug = CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))
			expect(NoiseRules.hears(at(20), ORIGIN, plaque, 1)).to.equal(false)
			expect(NoiseRules.hears(at(60), ORIGIN, jug, 1)).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing).

- [ ] **Step 3: Types** `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseTypes.luau`:

```lua
--!strict
--[=[
	NoiseTypes: the Noise feature's shapes (Cleanup Crew spec §6.2 "Noise"). Types only (spec-exempt).

	@class NoiseTypes
]=]

-- One noise: where, how far it carries before any hearing scale (studs), and what made it ("vacuum",
-- "drop", "search", "rattle", ...).
export type NoiseEvent = {
	position: Vector3,
	radius: number,
	source: string,
}

return {}
```

- [ ] **Step 4: Constants** `src/ReplicatedStorage/Shared/Features/Noise/Data/NoiseConstants.luau`:

```lua
--!strict
--[=[
	NoiseConstants: the ripple ring's look (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at
	the radius Harlow hears it"). Placeholder graybox look; M3 restyles it. The radii themselves live with
	their sources (VacuumConstants, CargoConstants). Static data (spec-exempt).

	@class NoiseConstants
]=]

return table.freeze({
	RIPPLE_NAME = "NoiseRipple",
	-- Seconds the ring takes to spread to its radius and fade out.
	RIPPLE_SECONDS = 0.8,
	RIPPLE_COLOR = Color3.fromRGB(180, 210, 255),
	RIPPLE_TRANSPARENCY = 0.8,
	RIPPLE_THICKNESS = 0.1,
	-- How far down the floor is looked for under a noise.
	FLOOR_PROBE = 12,
})
```

- [ ] **Step 5: Rules** `src/ReplicatedStorage/Shared/Features/Noise/Rules/NoiseRules.luau`:

```lua
--!strict
--[=[
	NoiseRules: who hears a noise (Cleanup Crew spec §4, §6.2 "Noise"): a listener hears it when within the
	noise's radius times the listener's hearing scale (Harlow's comes from OccupantTuningFormulas: pressure
	tiers widen it, a solo crew narrows it). Straight-line distance; walls do not muffle (spec: "3D footsteps
	and muttering through walls" works both ways). Pure.

	@class NoiseRules
]=]

local NoiseRules = {}

--[=[
	How far a noise of `radius` is heard by a listener with hearing `scale` (never negative).
]=]
function NoiseRules.heardRadius(radius: number, scale: number): number
	return math.max(0, radius) * math.max(0, scale)
end

--[=[
	Whether a listener at `listener` hears a noise at `origin`.
]=]
function NoiseRules.hears(listener: Vector3, origin: Vector3, radius: number, scale: number): boolean
	local reach = NoiseRules.heardRadius(radius, scale)
	return reach > 0 and (listener - origin).Magnitude <= reach
end

return NoiseRules
```

- [ ] **Step 6: Packets** `src/ReplicatedStorage/Shared/Features/Noise/Net/NoiseEvents.luau`:

```lua
--!strict
--[=[
	NoiseEvents: the Noise feature's ByteNet packet (server → clients): a ripple to draw. The radius is
	already the heard radius (the noise's radius times Harlow's hearing scale).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at NoiseServiceServer load).

	@class NoiseEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "NoiseEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local NoiseEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Ripple = ByteNet.definePacket({
				value = ByteNet.struct({
					position = ByteNet.vec3,
					radius = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return NoiseEvents
```

- [ ] **Step 7: Server** `src/ServerScriptService/Features/Noise/NoiseServiceServer.luau`:

```lua
--!strict
--[=[
	NoiseServiceServer: noise from any source, as one stream (Cleanup Crew spec §4, §6.2 "Noise"). Vacuum's
	pulses and Cargo's drops, splashes, searches and rattles arrive on their `noiseMade` signals; anything else
	may call `emit`. Every noise fires `made` (Occupant decides whether Harlow hears it, through NoiseRules) and
	shows every client a ripple at the radius Harlow hears it at (the hearing scale Occupant keeps current).

	Spec-exempt shell (signals, ByteNet); the hearing rule is the specced NoiseRules.

	@class NoiseServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NoiseShared = ReplicatedStorage.Shared.Features.Noise
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local NoiseTypes = require(NoiseShared.Data.NoiseTypes)
local NoiseEvents = require(NoiseShared.Net.NoiseEvents)
local NoiseRules = require(NoiseShared.Rules.NoiseRules)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

local made: SignalTyped.Signal<NoiseTypes.NoiseEvent> = SignalTyped.new()
local hearingScale = 1
local total = 0
local bySource: { [string]: number } = {}
local stoppers: { () -> () } = {}

export type NoiseServiceServer = {
	dependencies: { string },
	made: SignalTyped.Signal<NoiseTypes.NoiseEvent>,
	start: (self: NoiseServiceServer) -> (),
	stop: (self: NoiseServiceServer) -> (),
	getState: (self: NoiseServiceServer) -> { [string]: any },
	emit: (self: NoiseServiceServer, position: Vector3, radius: number, source: string) -> (),
	setHearingScale: (self: NoiseServiceServer, scale: number) -> (),
	getHearingScale: (self: NoiseServiceServer) -> number,
}

local NoiseServiceServer: NoiseServiceServer = {
	dependencies = { "VacuumServiceServer", "CargoServiceServer" },
	made = made,

	--[=[
		Relays Vacuum's and Cargo's noise.
	]=]
	start = function(self)
		local vacuum = VacuumServiceServer.noiseMade:Connect(function(position: Vector3, radius: number, source: string)
			self:emit(position, radius, source)
		end)
		local cargo = CargoServiceServer.noiseMade:Connect(function(position: Vector3, radius: number, source: string)
			self:emit(position, radius, source)
		end)
		table.insert(stoppers, function()
			vacuum:Disconnect()
			cargo:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		One noise: fires `made` and draws a ripple for everyone. A noise with no radius is ignored.
	]=]
	emit = function(_self, position, radius, source)
		if radius <= 0 then
			return
		end
		total += 1
		bySource[source] = (bySource[source] or 0) + 1
		local event: NoiseTypes.NoiseEvent = { position = position, radius = radius, source = source }
		made:Fire(event)
		NoiseEvents.packets.Ripple.sendToAll({
			position = position,
			radius = NoiseRules.heardRadius(radius, hearingScale),
		})
	end,

	--[=[
		Harlow's hearing scale (OccupantServiceServer keeps it current); it sizes the ripples.
	]=]
	setHearingScale = function(_self, scale)
		assert(scale > 0, "NoiseServiceServer:setHearingScale: the scale must be positive")
		hearingScale = scale
	end,

	getHearingScale = function(_self)
		return hearingScale
	end,

	getState = function(_self)
		return { total = total, bySource = table.clone(bySource), hearingScale = hearingScale }
	end,
}

return NoiseServiceServer
```

- [ ] **Step 8: Client** `src/ReplicatedStorage/Client/Features/Noise/NoiseServiceClient.luau`:

```lua
--!strict
--[=[
	NoiseServiceClient: the ripple ring (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). Each `Ripple` becomes a flat neon disc on the floor under the noise that spreads
	to the heard radius and fades. Client-local parts (never replicated). Placeholder look; M3 restyles it.

	Spec-exempt shell (Instances, tweens, raycasts).

	@class NoiseServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)
local NoiseEvents = require(ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents)

local stoppers: { () -> () } = {}
local drawn = 0

-- The floor under a noise (characters and non-colliding parts ignored), or the noise itself.
local function floorBelow(position: Vector3): Vector3
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(ignore, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -NoiseConstants.FLOOR_PROBE, 0), params)
	return if hit ~= nil then hit.Position else position
end

local function ripple(position: Vector3, radius: number)
	if radius <= 0 then
		return
	end
	local thickness = NoiseConstants.RIPPLE_THICKNESS
	local floor = floorBelow(position)
	local ring = Instance.new("Part")
	ring.Name = NoiseConstants.RIPPLE_NAME
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = NoiseConstants.RIPPLE_COLOR
	ring.Transparency = NoiseConstants.RIPPLE_TRANSPARENCY
	ring.Size = Vector3.new(thickness, 1, 1)
	-- A cylinder's axis is its X: roll it upright so the disc lies flat on the floor.
	ring.CFrame = CFrame.new(floor + Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	local diameter = radius * 2
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(NoiseConstants.RIPPLE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(thickness, diameter, diameter), Transparency = 1 }
	)
	tween.Completed:Once(function()
		ring:Destroy()
	end)
	tween:Play()
	drawn += 1
end

export type NoiseServiceClient = {
	dependencies: { string },
	start: (self: NoiseServiceClient) -> (),
	stop: (self: NoiseServiceClient) -> (),
	getState: (self: NoiseServiceClient) -> { [string]: any },
}

local NoiseServiceClient: NoiseServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			NoiseEvents.packets.Ripple.listen(function(data)
				ripple(data.position, data.radius)
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	getState = function(_self)
		return { drawn = drawn }
	end,
}

return NoiseServiceClient
```

- [ ] **Step 9: Exemptions.** In `SpecRoots.luau` `EXEMPT_MODULES`, add under a `-- Cleanup Crew: Noise` comment:

```lua
	["ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants"] = "static ripple look (no logic)",
	["ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Noise.NoiseServiceServer"] = "signal/ByteNet relay shell (the hearing rule NoiseRules is specced)",
	["ReplicatedStorage.Client.Features.Noise.NoiseServiceClient"] = "Instance/tween/raycast shell (draws the ripple)",
```

- [ ] **Step 10: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 11: Controller: Studio TestEZ.** Expected: NoiseRules passes; `assertAllModulesSpecced` passes.

- [ ] **Step 12: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local N = require(game.ServerScriptService.Features.Noise.NoiseServiceServer)
N.made:Connect(function(e) print("NOISE", e.source, e.radius, e.position) end)
_G.N = N
```
Checklist:
1. Vacuum a pile: `NOISE vacuum 40` about once a second, and a faint blue disc spreads to about 80 studs across under the pile each pulse.
2. Drop a monitor (G): `NOISE drop 24`, a 48-stud disc. Drop the water jug: `NOISE drop 70`, a big disc. Search a desk: `NOISE search 12`.
3. `_G.N:setHearingScale(1.2)`, vacuum again: the disc is about 96 studs across. `_G.N:setHearingScale(1)`.
4. `_G.N:emit(workspace.CleanupCrewOffice:GetPivot().Position, 20, "test")`: `NOISE test 20` and a disc in the loading bay. `_G.N:getState().bySource.vacuum` counts the pulses.
5. No errors in the client or server Output.

- [ ] **Step 13: Commit**

```bash
git commit -m "feat(noise): one noise stream, hearing rule and ripple ring"
python3 scripts/python/module_map.py --check
```

---
### Task 4: Cargo traits (rattle pulse, the jug's slippery puddle)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau` (+ spec cases)
- Create: `src/ServerScriptService/Features/Cargo/Systems/CargoTraitSystem.luau`
- Create: `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoSlipSystem.luau`
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (M1): `CargoServiceServer`'s module locals `noiseMade`, `spawner` (`CargoSpawnSystem`: `floorUnder(position, ignore) -> CFrame`), `claims` (`CargoClaimTracker:isClaimed(id)`), `container`, `ignoreList(extra: Instance?) -> { Instance }`, `idOf(object) -> number?`; `CargoConstants.RATTLE_NOISE = 12`, `RATTLE_INTERVAL = 2`; base `CarryServiceServer:getCarried(player)`, `CarryServiceServer.dropped: Signal<Player, Instance, DropReason>` (deferred), `CarryConstants.KIND_ATTRIBUTE`.
- Produces (CargoConstants, new keys): `PUDDLE_TAG = "CargoPuddle"`, `PUDDLE_SIZE = Vector3.new(7, 0.15, 7)`, `PUDDLE_COLOR`, `PUDDLE_SECONDS = 25`, `SLIP_SPEED = 8`, `SLIP_HEIGHT = 5`, `SLIP_COOLDOWN = 2`, `SLIP_SECONDS = 0.9`, `SLIP_PUSH = 25`, `SLIP_CHECK = 0.1`.
- Produces (CargoHandlingRules, new): `rattles(def: ItemDef) -> boolean`, `leavesPuddle(def: ItemDef, reason: DropReason) -> boolean`, `slips(localPoint: Vector3, size: Vector3, speed: number, now: number, lastSlipAt: number) -> boolean`.
- Produces (CargoTraitSystem): `Deps = { noiseMade: SignalTyped.Signal<Vector3, number, string>, container: () -> Instance?, floorUnder: (position: Vector3, ignore: { Instance }) -> CFrame, ignore: (extra: Instance?) -> { Instance }, isClaimed: (object: Instance) -> boolean }`; `new(deps) -> { start(), stop(), puddles() -> number }`. Rattle noise fires on Cargo's `noiseMade` with source `"rattle"` (Noise relays it).
- Produces (CargoSlipSystem): `start() -> ()`, `stop() -> ()` (client, module-level).

- [ ] **Step 1: Write the failing spec cases.** Add to `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.spec.luau`, inside the top-level `return function()`, after `describe("dropNoise", ...)`:

```lua
	describe("traits (M2)", function()
		it("rattles only a rattly item", function()
			expect(CargoHandlingRules.rattles(CargoRegistry.get("bottleBag"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("coffeeMachine"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("fishTank"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("printer"))).to.equal(false)
		end)

		it("leaves a puddle only when the jug hits the floor", function()
			local jug = CargoRegistry.get("waterJug")
			expect(CargoHandlingRules.leavesPuddle(jug, "drop")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "throw")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "death")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "destroyed")).to.equal(false)
			expect(CargoHandlingRules.leavesPuddle(CargoRegistry.get("printer"), "drop")).to.equal(false)
		end)
	end)

	describe("slips", function()
		local SIZE = Vector3.new(7, 0.15, 7)

		it("slips a player crossing a puddle at walking speed", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 10, -math.huge)).to.equal(true)
			expect(CargoHandlingRules.slips(Vector3.new(3.4, 3, -3.4), SIZE, 10.4, 10, -math.huge)).to.equal(true)
		end)

		it("lets a player stand or creep in it", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 2, 10, -math.huge)).to.equal(false)
		end)

		it("ignores a player beside it or high above it", function()
			expect(CargoHandlingRules.slips(Vector3.new(5, 3, 0), SIZE, 14, 10, -math.huge)).to.equal(false)
			expect(CargoHandlingRules.slips(Vector3.new(0, 9, 0), SIZE, 14, 10, -math.huge)).to.equal(false)
		end)

		it("does not slip again straight after a slip", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 10, 9)).to.equal(false)
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 12, 9)).to.equal(true)
		end)
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (functions missing).

- [ ] **Step 3: Constants.** In `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`, inside the frozen table after `FLOOR_PROBE = 20,`, add:

```lua
	-- M2 traits: the water jug's slippery puddle (lasts PUDDLE_SECONDS), and slipping on it: crossing at
	-- SLIP_SPEED or faster, root within SLIP_HEIGHT of it, at most once per SLIP_COOLDOWN; a slip stands the
	-- player down for SLIP_SECONDS and shoves them on (impulse SLIP_PUSH × mass). Checked every SLIP_CHECK.
	PUDDLE_TAG = "CargoPuddle",
	PUDDLE_SIZE = Vector3.new(7, 0.15, 7),
	PUDDLE_COLOR = Color3.fromRGB(120, 180, 230),
	PUDDLE_SECONDS = 25,
	SLIP_SPEED = 8,
	SLIP_HEIGHT = 5,
	SLIP_COOLDOWN = 2,
	SLIP_SECONDS = 0.9,
	SLIP_PUSH = 25,
	SLIP_CHECK = 0.1,
```

Also change the comment above `SPLASH_NOISE` from "Noise seams (M2)" to "Noise: a jug's splash, a search, a rattle pulse (every RATTLE_INTERVAL while carried)".

- [ ] **Step 4: Rules.** In `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau`, before `return CargoHandlingRules`, add:

```lua
--[=[
	Whether a carried item pulses a rattle noise (M2: CargoTraitSystem, every RATTLE_INTERVAL).
]=]
function CargoHandlingRules.rattles(def: ItemDef): boolean
	return def.rattly
end

--[=[
	Whether a hold ending for `reason` leaves a slippery puddle: the jug, hitting the floor.
]=]
function CargoHandlingRules.leavesPuddle(def: ItemDef, reason: CarryTypes.DropReason): boolean
	return def.splashes and CargoHandlingRules.isImpact(reason)
end

--[=[
	Whether a player slips on a puddle: `localPoint` is their HumanoidRootPart in the puddle's object space,
	`speed` their horizontal speed. Over its footprint, within SLIP_HEIGHT above it, at SLIP_SPEED or more, and
	not within SLIP_COOLDOWN of the last slip.
]=]
function CargoHandlingRules.slips(localPoint: Vector3, size: Vector3, speed: number, now: number, lastSlipAt: number): boolean
	if speed < CargoConstants.SLIP_SPEED or now - lastSlipAt < CargoConstants.SLIP_COOLDOWN then
		return false
	end
	return math.abs(localPoint.X) <= size.X / 2
		and math.abs(localPoint.Z) <= size.Z / 2
		and localPoint.Y >= -size.Y
		and localPoint.Y <= CargoConstants.SLIP_HEIGHT
end
```

Update the module header: append "M2: rattles, puddles and slipping."

- [ ] **Step 5: Server trait system** `src/ServerScriptService/Features/Cargo/Systems/CargoTraitSystem.luau`:

```lua
--!strict
--[=[
	CargoTraitSystem: the handling traits that act over time (Cleanup Crew spec §4): a rattly item pulses a
	small noise every RATTLE_INTERVAL while carried, and the water jug leaves a slippery puddle where it hits
	the floor (players slip on it: CargoSlipSystem, client). Noise goes out through CargoServiceServer's
	`noiseMade` (passed in), like every Cargo noise; Noise relays it. Puddles live in the shift's container, so
	a reset clears them; each also expires after PUDDLE_SECONDS.

	Spec-exempt shell (Players, Carry, Instances); the trait decisions are the specced CargoHandlingRules.

	@class CargoTraitSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)

export type Deps = {
	noiseMade: SignalTyped.Signal<Vector3, number, string>,
	container: () -> Instance?,
	floorUnder: (position: Vector3, ignore: { Instance }) -> CFrame,
	ignore: (extra: Instance?) -> { Instance },
	isClaimed: (object: Instance) -> boolean,
}

export type CargoTraitSystem = {
	start: (self: CargoTraitSystem) -> (),
	stop: (self: CargoTraitSystem) -> (),
	puddles: (self: CargoTraitSystem) -> number,
}

local function defOf(object: Instance): CargoTypes.ItemDef?
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	return if type(kind) == "string" then CargoRegistry.get(kind) else nil
end

local CargoTraitSystem = {}

function CargoTraitSystem.new(deps: Deps): CargoTraitSystem
	local heartbeat: RBXScriptConnection? = nil
	local dropped: SignalTyped.Connection? = nil
	local made = 0

	-- One rattle pulse from everyone carrying a rattly item.
	local function rattle()
		for _, player in Players:GetPlayers() do
			local item = CarryServiceServer:getCarried(player)
			local def = if item ~= nil then defOf(item) else nil
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if def ~= nil and CargoHandlingRules.rattles(def) and root ~= nil and root:IsA("BasePart") then
				deps.noiseMade:Fire(root.Position, CargoConstants.RATTLE_NOISE, "rattle")
			end
		end
	end

	local function puddleAt(floor: CFrame, parent: Instance)
		local size = CargoConstants.PUDDLE_SIZE
		local part = Instance.new("Part")
		part.Name = "Puddle"
		part.Size = size
		part.CFrame = floor * CFrame.new(0, size.Y / 2, 0)
		part.Color = CargoConstants.PUDDLE_COLOR
		part.Material = Enum.Material.Glass
		part.Transparency = 0.35
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = parent
		CollectionService:AddTag(part, CargoConstants.PUDDLE_TAG)
		Debris:AddItem(part, CargoConstants.PUDDLE_SECONDS)
		made += 1
	end

	-- Carry's `dropped` (deferred). Items Cargo claimed first (banked, pocketed) never splash.
	local function onDropped(_player: Player, object: Instance, reason: CarryTypes.DropReason)
		local def = defOf(object)
		if def == nil or not CargoHandlingRules.leavesPuddle(def, reason) or deps.isClaimed(object) then
			return
		end
		local parent = deps.container()
		if parent == nil or parent.Parent == nil or not object:IsA("BasePart") or object.Parent == nil then
			return
		end
		puddleAt(deps.floorUnder(object.Position, deps.ignore(object)), parent)
	end

	local system: CargoTraitSystem = {
		start = function(_self)
			local elapsed = 0
			heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
				elapsed += deltaTime
				if elapsed >= CargoConstants.RATTLE_INTERVAL then
					elapsed = 0
					rattle()
				end
			end)
			dropped = CarryServiceServer.dropped:Connect(onDropped)
		end,

		stop = function(_self)
			local beat = heartbeat
			if beat ~= nil then
				beat:Disconnect()
				heartbeat = nil
			end
			local drops = dropped
			if drops ~= nil then
				drops:Disconnect()
				dropped = nil
			end
		end,

		puddles = function(_self)
			return made
		end,
	}
	return system
end

return CargoTraitSystem
```

- [ ] **Step 6: Client slip system** `src/ReplicatedStorage/Client/Features/Cargo/Systems/CargoSlipSystem.luau`:

```lua
--!strict
--[=[
	CargoSlipSystem: slipping on the water jug's puddle (Cleanup Crew spec §4: "dropped = very loud splash +
	slippery puddle"). Every SLIP_CHECK the local character is tested against each puddle
	(CargoHandlingRules.slips); a slip stands the character down (PlatformStand) for SLIP_SECONDS and shoves it
	on along its motion. Client-side because the character's physics belong to its client; a slip only hinders
	the player who slips, so nothing authoritative rides on it.

	Spec-exempt shell (Humanoid, physics); the decision is the specced CargoHandlingRules.slips.

	@class CargoSlipSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoHandlingRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoHandlingRules)

local connection: RBXScriptConnection? = nil
local lastSlipAt = -math.huge

local function slip(humanoid: Humanoid, root: BasePart, motion: Vector3)
	humanoid.PlatformStand = true
	if motion.Magnitude > 1e-3 then
		root:ApplyImpulse(motion.Unit * root.AssemblyMass * CargoConstants.SLIP_PUSH)
	end
	task.delay(CargoConstants.SLIP_SECONDS, function()
		if humanoid.Parent ~= nil and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function check(now: number)
	local character = Players.LocalPlayer.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or found == nil or not found:IsA("BasePart") then
		return
	end
	local root: BasePart = found
	if humanoid.PlatformStand or humanoid.Health <= 0 then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local motion = Vector3.new(velocity.X, 0, velocity.Z)
	for _, puddle in CollectionService:GetTagged(CargoConstants.PUDDLE_TAG) do
		if
			puddle:IsA("BasePart")
			and CargoHandlingRules.slips(
				puddle.CFrame:PointToObjectSpace(root.Position),
				puddle.Size,
				motion.Magnitude,
				now,
				lastSlipAt
			)
		then
			lastSlipAt = now
			slip(humanoid, root, motion)
			return
		end
	end
end

local CargoSlipSystem = {}

function CargoSlipSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= CargoConstants.SLIP_CHECK then
			elapsed = 0
			check(os.clock())
		end
	end)
end

function CargoSlipSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
end

return CargoSlipSystem
```

- [ ] **Step 7: Wire the trait system into the server.** In `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`:
  - Require: `local CargoTraitSystem = require(CargoServer.Systems.CargoTraitSystem)` beside `CargoSpawnSystem`.
  - After the `ignoreList` function (all of `noiseMade`, `spawner`, `claims`, `container`, `idOf` exist by then), add:
    ```lua
    -- Rattles and puddles (M2). Claimed items (banked, pocketed) never splash.
    local traits = CargoTraitSystem.new({
    	noiseMade = noiseMade,
    	container = function(): Instance?
    		return container
    	end,
    	floorUnder = function(position: Vector3, ignore: { Instance }): CFrame
    		return spawner:floorUnder(position, ignore)
    	end,
    	ignore = ignoreList,
    	isClaimed = function(object: Instance): boolean
    		local id = idOf(object)
    		return id ~= nil and claims:isClaimed(id)
    	end,
    })
    ```
  - In `start`, as its last line: `traits:start()`. In `stop`, before clearing the stoppers: `traits:stop()`.
  - In `getState`'s returned table add `puddles = traits:puddles(),`.
  - Header comment: add `- Traits (M2, CargoTraitSystem): rattly items pulse a noise while carried; the jug leaves a slippery puddle.`
  - If `scatter` / `onDropped` / `ignoreList` live in a `CargoHandlingSystem` (M1 amendment N7), make the same `CargoTraitSystem.new` call wherever those locals are in scope and expose `start` / `stop` through the service exactly as above.

- [ ] **Step 8: Wire the slip system into the client.** In `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`:
  - Require: `local CargoSlipSystem = require(ReplicatedStorage.Client.Features.Cargo.Systems.CargoSlipSystem)`.
  - In `start`, after the pocket binding: `CargoSlipSystem.start()`. In `stop`, after the unbind loop: `CargoSlipSystem.stop()`.
  - Header comment: add `M2: slipping on puddles (CargoSlipSystem).`

- [ ] **Step 9: Exemptions.** Add under `-- Cleanup Crew: Cargo`:

```lua
	["ServerScriptService.Features.Cargo.Systems.CargoTraitSystem"] = "Players/Carry/Instance shell (rattle and puddle decisions are specced in CargoHandlingRules)",
	["ReplicatedStorage.Client.Features.Cargo.Systems.CargoSlipSystem"] = "Humanoid/physics shell (the slip decision CargoHandlingRules.slips is specced)",
```

- [ ] **Step 10: Module map, format and gate** (Global Constraints order; confirm `CargoServiceServer` stays ≤ 400 code lines in the gate's file-length stage). Expected: `==> All checks passed.`

- [ ] **Step 11: Controller: Studio TestEZ.** Expected: CargoHandlingRules passes (incl. the new cases); full suite green.

- [ ] **Step 12: Controller: Studio verification** (Play Solo, `RunTests = false`, a shift running). Inject a temporary server Script:

```lua
local N = require(game.ServerScriptService.Features.Noise.NoiseServiceServer)
N.made:Connect(function(e) print("NOISE", e.source, e.radius) end)
```
Checklist:
1. Pick up a bottle bag (or a coffee machine): `NOISE rattle 12` every ~2 s while held, a small ripple at your feet; drop it: the pulses stop.
2. Pick up the water jug and drop it (G): `NOISE drop 70` and a flat blue "Puddle" appears under it (`workspace.CleanupCrewOffice.Shift.Puddle`).
3. Run across the puddle: you fall over for about a second and slide on, then stand up. Walk back across within 2 s: no second slip. Stand still in it: no slip.
4. ~25 s later the puddle is gone. Drop the jug again, then use Another shift / `resetShift()`: the puddle goes with the shift.
5. Carry the jug onto the truck bed and Load: no puddle at the truck.

- [ ] **Step 13: Commit**

```bash
git commit -m "feat(cargo): rattle pulses and the jug's slippery puddle"
python3 scripts/python/module_map.py --check
```

---
### Task 5: Cargo swap / unpocket (spec §6.3) and the pocket system

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau` (+ spec cases)
- Modify: `src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.luau` (+ spec cases)
- Modify: `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`
- Create: `src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau`
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau` (pockets move into CargoPocketSystem; `swap`)
- Modify: `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau` (`swap` action)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (M1): `CargoPocketTracker` (`add / list / count / take / clear`), `CargoClaimTracker`, `CargoSpawnSystem` (`spawn(kind, floor, parent, { value }) -> BasePart`, `floorUnder`), the service's `entryOf(object) -> CargoEntry?`, `idOf(object) -> number?`, `ignoreList(extra?)`, `container`, `RequestHandler.wrap`; base `CarryServiceServer:getCarried / pickUp(player, target) -> (boolean, string?) / forceDrop(player, reason)`, `StateSyncPublicPlayerStore.set / clearField`, `InputActionRegistry.register`, `InputServiceClient:bind`.
- Produces (CargoTypes): `SwapAction = "unpocket" | "swap"`.
- Produces (CargoConstants): `SWAP_ACTION = "swap"`.
- Produces (CargoHandlingRules): `swapPlan(holding: boolean, def: ItemDef?, pocketed: number) -> (SwapAction?, string?)`: no pockets → nil, `"pockets empty"`; empty hands → `"unpocket"` (the newest pocketed item comes out); a tiny item in hand → `"swap"` (it goes in, the oldest comes out); anything else → nil, `"hands full"`.
- Produces (CargoPocketTracker): `remove(userId: number, index: number) -> CargoEntry?` (the entry at `index`, removed; nil out of range).
- Produces (CargoEvents): `packets.Swap` (client → server, `ByteNet.bool`, payload unused).
- Produces (CargoPocketSystem): `Deps = { claims, spawner, container: () -> Instance?, ignore: () -> { Instance }, entryOf: (Instance) -> CargoEntry?, idOf: (Instance) -> number? }`; `new(deps) -> { pocket(player) -> (boolean, string?), swap(player) -> (boolean, string?), list(userId) -> { CargoEntry }, take(userId) -> { CargoEntry }, scatter(player, origin: Vector3?) -> (), clear() -> (), counts() -> { pocketed, swapped, scattered } }`.
- Produces (CargoServiceServer, new): `swap(player) -> (boolean, string?)`; `pocket`, `load`, `pocketsOf`, `reset` and the death/leave scatter keep their M1 behaviour through CargoPocketSystem.
- Produces (CargoServiceClient, new): `swap() -> ()`; registers the `swap` Input action (X, gamepad D-pad down).

- [ ] **Step 1: Write the failing spec cases.**

Add to `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.spec.luau` (top level, after `describe("slips", ...)`):

```lua
	describe("swapPlan", function()
		it("takes the newest pocketed item into empty hands", function()
			expect(CargoHandlingRules.swapPlan(false, nil, 1)).to.equal("unpocket")
			expect(CargoHandlingRules.swapPlan(false, nil, 2)).to.equal("unpocket")
		end)

		it("trades a tiny hands item for a pocketed one", function()
			expect(CargoHandlingRules.swapPlan(true, CargoRegistry.get("plaque"), 2)).to.equal("swap")
		end)

		it("refuses with empty pockets", function()
			local action, reason = CargoHandlingRules.swapPlan(false, nil, 0)
			expect(action).to.equal(nil)
			expect(reason).to.equal("pockets empty")
			local _, tinyReason = CargoHandlingRules.swapPlan(true, CargoRegistry.get("plaque"), 0)
			expect(tinyReason).to.equal("pockets empty")
		end)

		it("refuses while the hands hold something bigger, or not cargo", function()
			local action, reason = CargoHandlingRules.swapPlan(true, CargoRegistry.get("monitor"), 1)
			expect(action).to.equal(nil)
			expect(reason).to.equal("hands full")
			local _, otherReason = CargoHandlingRules.swapPlan(true, nil, 1)
			expect(otherReason).to.equal("hands full")
		end)
	end)
```

Add to `src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.spec.luau` (top level, after the last `it`):

```lua
	it("removes one entry by slot, keeping the others in order", function()
		local pockets = CargoPocketTracker.new()
		pockets:add(1, PLAQUE)
		pockets:add(1, STAPLER)
		local removed = pockets:remove(1, 1)
		expect(removed.kind).to.equal("plaque")
		expect(pockets:count(1)).to.equal(1)
		expect(pockets:list(1)[1].kind).to.equal("goldenStapler")
	end)

	it("removes nothing from an empty or out-of-range slot", function()
		local pockets = CargoPocketTracker.new()
		expect(pockets:remove(1, 1)).to.equal(nil)
		pockets:add(1, PLAQUE)
		expect(pockets:remove(1, 2)).to.equal(nil)
		expect(pockets:remove(1, 0)).to.equal(nil)
		expect(pockets:count(1)).to.equal(1)
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`swapPlan`, `remove` missing).

- [ ] **Step 3: Types and constants.**
  - `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`, after `SpawnOptions`:
    ```lua
    -- What a swap request does (M2, spec §6.3): take the newest pocketed item into empty hands, or trade a tiny
    -- hands item for the oldest pocketed one.
    export type SwapAction = "unpocket" | "swap"
    ```
  - `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`, after `POCKET_ACTION = "pocket",`:
    ```lua
    	-- The Input action that swaps the hands item with a pocket, or unpockets into empty hands (M2).
    	SWAP_ACTION = "swap",
    ```

- [ ] **Step 4: Rules.** In `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau`, before `return CargoHandlingRules`:

```lua
--[=[
	What a swap request does (spec §6.3): with empty hands the newest pocketed item comes out ("unpocket"); with
	a tiny item in hand it goes into the pockets and the oldest pocketed item comes out ("swap"). Nil with a
	reason when the pockets are empty or the hands hold anything bigger (or not cargo).
]=]
function CargoHandlingRules.swapPlan(holding: boolean, def: ItemDef?, pocketed: number): (CargoTypes.SwapAction?, string?)
	if pocketed <= 0 then
		return nil, "pockets empty"
	end
	if not holding then
		return "unpocket", nil
	end
	if def == nil or def.size ~= CargoConstants.POCKET_SIZE then
		return nil, "hands full"
	end
	return "swap", nil
end
```

- [ ] **Step 5: Tracker.** In `src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.luau`:
  - In `export type CargoPocketTracker` add `remove: (self: CargoPocketTracker, userId: number, index: number) -> CargoEntry?,` after `take`.
  - In the tracker literal, after `take`, add:
    ```lua
    		-- Takes the entry in slot `index` out (the slots after it move up); nil when that slot is empty.
    		remove = function(_self, userId, index)
    			local list = pockets[userId]
    			if list == nil or index < 1 or index > #list then
    				return nil
    			end
    			local entry = table.remove(list, index)
    			return if entry ~= nil then { kind = entry.kind, value = entry.value } else nil
    		end,
    ```

- [ ] **Step 6: Packet.** In `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`, after the `Pocket` packet:

```lua
			-- Swap the hands item with a pocket, or unpocket into empty hands (M2). Payload unused.
			Swap = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
```

- [ ] **Step 7: Pocket system** `src/ServerScriptService/Features/Cargo/Systems/CargoPocketSystem.luau`:

```lua
--!strict
--[=[
	CargoPocketSystem: the two pockets (Cleanup Crew spec §4 "Hands: one item of any kind. Pockets: 2 slots,
	tiny items only"; §6.3 the `pocket` and `swap` requests). `pocket` moves a tiny hands item into a pocket
	(claim, record, release from Carry, destroy); `swap` takes the newest pocketed item into empty hands, or
	trades a tiny hands item for the oldest pocketed one (CargoHandlingRules.swapPlan); `scatter` drops a
	player's pockets around where they died or left; `take` empties them for a Load. Pockets are published as
	the public `pocket1` / `pocket2` fields.

	Moved out of CargoServiceServer in M2 (the service was at the 400-line cap). Spec-exempt shell (Carry,
	Instances, public state); the decisions are the specced CargoHandlingRules and CargoPocketTracker.

	@class CargoPocketSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoPocketTracker = require(CargoServer.State.CargoPocketTracker)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type CargoEntry = CargoTypes.CargoEntry

export type Deps = {
	claims: CargoClaimTracker.CargoClaimTracker,
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	-- The shift's container (where items come back into the world); nil = no shift.
	container: () -> Instance?,
	-- What a floor probe looks through (every character).
	ignore: () -> { Instance },
	entryOf: (object: Instance) -> CargoEntry?,
	idOf: (object: Instance) -> number?,
}

export type Counts = { pocketed: number, swapped: number, scattered: number }

export type CargoPocketSystem = {
	pocket: (self: CargoPocketSystem, player: Player) -> (boolean, string?),
	swap: (self: CargoPocketSystem, player: Player) -> (boolean, string?),
	list: (self: CargoPocketSystem, userId: number) -> { CargoEntry },
	take: (self: CargoPocketSystem, userId: number) -> { CargoEntry },
	scatter: (self: CargoPocketSystem, player: Player, origin: Vector3?) -> (),
	clear: (self: CargoPocketSystem) -> (),
	counts: (self: CargoPocketSystem) -> Counts,
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local CargoPocketSystem = {}

function CargoPocketSystem.new(deps: Deps): CargoPocketSystem
	local pockets = CargoPocketTracker.new()
	local counts: Counts = { pocketed = 0, swapped = 0, scattered = 0 }

	local function publish(userId: number)
		local list = pockets:list(userId)
		for index, field in CargoConstants.PUBLIC_POCKET_FIELDS do
			local entry = list[index]
			if entry ~= nil then
				StateSyncPublicPlayerStore.set(userId, { [field] = entry.kind })
			else
				StateSyncPublicPlayerStore.clearField(userId, field)
			end
		end
	end

	-- Brings a pocketed entry back as an item at the player's feet and puts it in their hands a frame later
	-- (Carry adopts a new item when its tag lands). If the hands filled meanwhile, it stays on the floor.
	local function intoHands(player: Player, entry: CargoEntry, root: BasePart, parent: Instance)
		local floor = deps.spawner:floorUnder(root.Position, deps.ignore())
		local part = deps.spawner:spawn(entry.kind, floor, parent, { value = entry.value })
		task.defer(function()
			if part.Parent ~= nil and player.Parent ~= nil and CarryServiceServer:getCarried(player) == nil then
				CarryServiceServer:pickUp(player, part)
			end
		end)
	end

	local system: CargoPocketSystem
	system = {
		--[=[
			Moves the hands item into a pocket: claim, record, release from Carry, destroy.
		]=]
		pocket = function(_self, player)
			local item = CarryServiceServer:getCarried(player)
			local entry = if item ~= nil then deps.entryOf(item) else nil
			local id = if item ~= nil then deps.idOf(item) else nil
			local def = if entry ~= nil then CargoRegistry.get(entry.kind) else nil
			local ok, reason = CargoHandlingRules.canPocket(def, pockets:count(player.UserId))
			if not ok then
				return false, reason
			end
			if item == nil or entry == nil or id == nil or not deps.claims:claim(id) then
				return false, "nothing to pocket"
			end
			pockets:add(player.UserId, entry)
			CarryServiceServer:forceDrop(player, "forced")
			item:Destroy()
			publish(player.UserId)
			counts.pocketed += 1
			return true, nil
		end,

		--[=[
			Unpockets into empty hands, or trades a tiny hands item for the oldest pocketed one.
		]=]
		swap = function(self, player)
			local item = CarryServiceServer:getCarried(player)
			local entry = if item ~= nil then deps.entryOf(item) else nil
			local def = if entry ~= nil then CargoRegistry.get(entry.kind) else nil
			local action: CargoTypes.SwapAction?, reason = CargoHandlingRules.swapPlan(
				item ~= nil,
				def,
				pockets:count(player.UserId)
			)
			if not action then
				return false, reason
			end
			local root = rootOf(player)
			local parent = deps.container()
			if root == nil or parent == nil or parent.Parent == nil then
				return false, "not now"
			end
			local out: CargoEntry? = nil
			if action == "unpocket" then
				out = pockets:remove(player.UserId, pockets:count(player.UserId))
			else
				out = pockets:remove(player.UserId, 1)
				local pocketed, why = self:pocket(player)
				if not pocketed then
					if out ~= nil then
						pockets:add(player.UserId, out)
					end
					publish(player.UserId)
					return false, why
				end
			end
			publish(player.UserId)
			if out == nil then
				return false, "pockets empty"
			end
			intoHands(player, out, root, parent)
			counts.swapped += 1
			return true, nil
		end,

		list = function(_self, userId)
			return pockets:list(userId)
		end,

		--[=[
			Empties a player's pockets (a Load) and publishes them; returns what was in them.
		]=]
		take = function(_self, userId)
			local list = pockets:take(userId)
			publish(userId)
			return list
		end,

		--[=[
			Drops a player's pockets around `origin` (where they died or left), inside the shift.
		]=]
		scatter = function(_self, player, origin)
			local list = pockets:take(player.UserId)
			publish(player.UserId)
			local parent = deps.container()
			if origin == nil or parent == nil or parent.Parent == nil then
				return
			end
			for index, entry in list do
				local angle = index / #list * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CargoConstants.SCATTER_RADIUS
				local floor = deps.spawner:floorUnder(origin + offset, deps.ignore())
				deps.spawner:spawn(entry.kind, floor, parent, { value = entry.value })
				counts.scattered += 1
			end
		end,

		--[=[
			A new shift: everyone's pockets emptied and published.
		]=]
		clear = function(_self)
			pockets:clear()
			for _, player in Players:GetPlayers() do
				publish(player.UserId)
			end
		end,

		counts = function(_self)
			return table.clone(counts)
		end,
	}
	return system
end

return CargoPocketSystem
```

If luau-lsp rejects the two-name annotation `local action: CargoTypes.SwapAction?, reason = ...`, write `local action, reason = ...` and keep the `if not action then` guard (it narrows without widening the literal union); no cast.

- [ ] **Step 8: Move the pockets out of the service.** In `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau` (the M1 plan's Task 8 Step 6 code; if amendment N7 moved `scatter` into a `CargoHandlingSystem`, take it from there instead and leave that system's other duties alone):
  1. Requires: remove `CargoPocketTracker`; add `local CargoPocketSystem = require(CargoServer.Systems.CargoPocketSystem)`.
  2. Remove `local pockets = CargoPocketTracker.new()`, the `publishPockets` function and the `scatter` function. Remove `pocketed` and `scattered` from `counters`.
  3. After the `ignoreList` function (and the Task 4 `traits` block), add:
     ```lua
     local pocketSystem = CargoPocketSystem.new({
     	claims = claims,
     	spawner = spawner,
     	container = function(): Instance?
     		return container
     	end,
     	ignore = function(): { Instance }
     		return ignoreList(nil)
     	end,
     	entryOf = entryOf,
     	idOf = idOf,
     })
     ```
  4. Replace each `scatter(player, ...)` call (the `PlayerRemoving` and `Died` handlers) with `pocketSystem:scatter(player, ...)`, same arguments.
  5. Replace the body of `pocket` with `return pocketSystem:pocket(player)` (signature unchanged: `pocket = function(_self, player)`).
  6. In `load`: `pockets:list(player.UserId)` → `pocketSystem:list(player.UserId)`; the two lines `pockets:take(player.UserId)` + `publishPockets(player.UserId)` → `pocketSystem:take(player.UserId)`.
  7. `pocketsOf` → `return pocketSystem:list(player.UserId)`.
  8. In `reset`: `pockets:clear()` and the `publishPockets` loop → `pocketSystem:clear()`.
  9. In `getState`'s returned table add `pockets = pocketSystem:counts(),`.
  10. Add the swap request. After `onPocket`:
      ```lua
      local onSwap = RequestHandler.wrap({
      	name = "CargoSwap",
      	rateLimit = { maxRequests = 6, windowSeconds = 5 },
      	handler = function(_data: unknown, player: Player)
      		local ok, reason = CargoServiceServer:swap(player)
      		if not ok and reason ~= nil then
      			tell(player, reason)
      		end
      	end,
      })
      ```
      In `start`, after the `Pocket` listener:
      ```lua
      		table.insert(
      			stoppers,
      			CargoEvents.packets.Swap.listen(function(data: boolean, player: Player?)
      				if player then
      					onSwap(data, player)
      				end
      			end)
      		)
      ```
      In `export type CargoServiceServer` add `swap: (self: CargoServiceServer, player: Player) -> (boolean, string?),` and in the literal, after `pocket`:
      ```lua
      	--[=[
      		Unpockets into empty hands, or trades a tiny hands item for the oldest pocketed one (spec §6.3).
      	]=]
      	swap = function(_self, player)
      		return pocketSystem:swap(player)
      	end,
      ```
  11. Header comment: the Pockets bullet becomes `- Pockets (CargoPocketSystem): the \`pocket\` and \`swap\` packets; two tiny-only slots published as \`pocket1\` / \`pocket2\`; scattered where their owner dies or leaves.`

- [ ] **Step 9: Client action.** In `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`:
  - In `export type CargoServiceClient` add `swap: (self: CargoServiceClient) -> (),`.
  - In `init`, after the pocket registration:
    ```lua
    		if not InputActionRegistry.has(CargoConstants.SWAP_ACTION) then
    			InputActionRegistry.register(CargoConstants.SWAP_ACTION, {
    				context = "gameplay",
    				bindings = { keyboard = { Enum.KeyCode.X }, gamepad = { Enum.KeyCode.DPadDown } },
    				description = "Swap with a pocket (or unpocket)",
    			})
    		end
    ```
  - In `start`, after the pocket binding:
    ```lua
    		table.insert(
    			unbinders,
    			InputServiceClient:bind(CargoConstants.SWAP_ACTION, function(phase)
    				if phase == "begin" then
    					self:swap()
    				end
    			end)
    		)
    ```
  - Method (after `pocket`):
    ```lua
    	-- Works with empty hands too (unpocket); the server decides.
    	swap = function(_self)
    		CargoEvents.packets.Swap.send(true)
    	end,
    ```
  - Header comment: `the \`pocket\` (Q) and \`swap\` (X) Input actions`.

- [ ] **Step 10: Exemption.** Add under `-- Cleanup Crew: Cargo`:

```lua
	["ServerScriptService.Features.Cargo.Systems.CargoPocketSystem"] = "Carry/Instance/public-state shell (pocket, swap and slot decisions are specced in CargoHandlingRules and CargoPocketTracker)",
```

- [ ] **Step 11: Module map, format and gate** (Global Constraints order; `CargoServiceServer` must now be well under 400 code lines). Expected: `==> All checks passed.`

- [ ] **Step 12: Controller: Studio TestEZ.** Expected: CargoHandlingRules and CargoPocketTracker pass (incl. new cases); full suite green.

- [ ] **Step 13: Controller: Studio verification** (Play Solo, `RunTests = false`, a shift running). Inject a temporary server Script:

```lua
local P = require(game.ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local C = require(game.ServerScriptService.Features.Cargo.CargoServiceServer)
_G.pockets = function() local e = P.get(game.Players:GetPlayers()[1].UserId) or {} print("POCKETS", e.pocket1, e.pocket2, e.carrying) end
_G.C = C
```
Checklist (spawn tiny items near you with `_G.C:spawnItem("plaque", CFrame.new(game.Players:GetPlayers()[1].Character.HumanoidRootPart.Position + Vector3.new(3, -3, 0)), workspace.CleanupCrewOffice.Shift)`):
1. Pick up a plaque, Q: `_G.pockets()` → `plaque nil nil`. X with empty hands: a frame later the plaque is in your hands again, `nil nil plaque`.
2. Pocket a plaque and a golden stapler (`plaque goldenStapler nil`). Pick up a third tiny item (a plaque), X: hands hold the first plaque, pockets read `goldenStapler plaque`.
3. Hold a rubbish bag, X: toast "hands full", nothing changes. Empty pockets and empty hands, X: toast "pockets empty".
4. Pocket two items and reset your character: both scatter where you died; `pocket1`/`pocket2` are nil (M1 behaviour kept). Pocket one and Load at the truck with a rubbish bag in hand: one bank toast covers both; pockets empty.
5. `_G.C:getState().pockets` shows `pocketed`, `swapped`, `scattered` counts matching what you did.

- [ ] **Step 14: Commit**

```bash
git commit -m "feat(cargo): swap and unpocket; pockets move into CargoPocketSystem"
python3 scripts/python/module_map.py --check
```

---
### Task 6: Occupant data, brain and tuning (pure)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau`
- Create: `src/ServerScriptService/Features/Occupant/Rules/OccupantBrainRules.luau` (+ `OccupantBrainRules.spec.luau`)
- Create: `src/ServerScriptService/Features/Occupant/Utils/OccupantTuningFormulas.luau` (+ `OccupantTuningFormulas.spec.luau`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: base `NpcTypes.Intent` (`{ kind: "idle" } | { kind: "goTo", position: Vector3, run: boolean } | { kind: "attack", target: number } | ...`, `src/ServerScriptService/Features/Npc/Data/NpcTypes.luau`); `NpcSenseRules.inSight(origin, look, target, range, angle) -> boolean` (`src/ServerScriptService/Features/Npc/Rules/NpcSenseRules.luau`); Task 1 `ShiftConstants.TOP_TIER / TIER_HEARING / TIER_PATROL_SPEED / SOLO_HEARING / SOLO_CHASE_SPEED`; Task 3 `NoiseRules.hears` (spec only).
- Produces (OccupantConstants): `NPC_KIND = "harlow"`, `TAG = "Occupant"`, `MODE_ATTRIBUTE = "OccupantMode"`, `TARGET_ATTRIBUTE = "OccupantTarget"`, `PATROL_SPEED = 10`, `CHASE_SPEED = 15`, `SIGHT_RANGE = 60`, `SIGHT_ANGLE = 100`, `LOOK_SECONDS = 4`, `SEARCH_SECONDS = 6`, `GIVE_UP_SECONDS = 20`, `REACHED_DISTANCE = 3`, `LOOK_SWEEP = 70`, `LOOK_RATE = 1.2`, `CATCH_RANGE = 4`, `CATCH_SLACK = 1`, `CATCH_COOLDOWN = 1`, `CATCH_HOLD = 1.5`, `GRACE_SECONDS = 10`, `SNAP_SECONDS = 0.6`, `SPECTATE_SECONDS = 8`, `LAUNCH_SPEED = 45`, `LAUNCH_UP = 35`, `SPAWN_HEIGHT = 4`, `TUNING_INTERVAL = 1`, `FLICKER_RADIUS = 20`, `HEARTBEAT_RANGE = 40`, `BEAT_SLOW = 1`, `BEAT_FAST = 0.45`, `LIGHTS_OUT_RADIUS = 30`, `LIGHTS_OUT_SECONDS = 2.5`, `TIER_FLICKER_SECONDS = 1.5`, `TELL_INTERVAL = 0.05`, `SPEECH_SECONDS = 3`, `CAMERA_PRIORITY = 70`, `CATCH_FOV = 50`, `CATCH_TRAUMA = 0.6`, `CATCH_TINT`, `HEARTBEAT_TINT`, `SAFE_ZONE_LABEL = "SafeZone"`, `LIGHT_TAG = "OfficeLight"`, `CUE_NAME`, `SPEECH_NAME`, `DISPLAY_NAME = "Mr. Harlow"`, `REHIRED_TEXT = "Rehired."`, `BODY`, `LINES: { [string]: string }` (keys `spotted`, `curious`, `caught`, `giveUp`, `resting`).
- Produces (OccupantTypes): `Mode = "patrol" | "investigate" | "chase" | "search" | "rest" | "catch"`, `Cue = "spotted" | "curious" | "giveUp" | "resting" | "caught"`, `Zone = { min: Vector3, max: Vector3 }`, `Mind = { mode, since, routeIndex, routeStep, target: number?, lastSeen: Vector3?, noise: Vector3?, arrivedAt: number?, grace: { [number]: number } }`, `Glimpse = { userId: number, position: Vector3, clear: boolean }`, `Senses = { position, look, now, sightRange, sightAngle, players: { Glimpse }, heard: Vector3?, resting: boolean, route: { Vector3 }, restPoint: Vector3, zone: Zone }`, `CatchInput = { distance, position, alive, catching, inGrace, resting, zone }`.
- Produces (OccupantBrainRules): `Step = { mind: Mind, intent: NpcTypes.Intent, cue: Cue? }`; `newMind(routeIndex: number, routeStep: number, now: number) -> Mind`; `inZone(point: Vector3, zone: Zone) -> boolean`; `visible(mind, senses) -> { Glimpse }` (nearest first); `caught(mind, userId: number, now: number) -> Mind`; `lookYaw(elapsed: number) -> number` (radians); `step(mind: Mind, senses: Senses) -> Step`.
- Produces (OccupantTuningFormulas): `Tuning = { walkSpeed: number, runSpeed: number, hearing: number }`; `tuning(tier: number, crew: number) -> Tuning`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Occupant/Rules/OccupantBrainRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- The loading bay (safe), a three-point route and the break room's rest point.
local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
local REST = Vector3.new(200, 0, 200)

-- Harlow at (60, 3, 60) looking along +X, at os.clock 100.
local function senses(extra)
	local value = {
		position = Vector3.new(60, 3, 60),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = OccupantConstants.SIGHT_RANGE,
		sightAngle = OccupantConstants.SIGHT_ANGLE,
		players = {},
		resting = false,
		route = ROUTE,
		restPoint = REST,
		zone = ZONE,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function player(userId, position, clear)
	return { userId = userId, position = position, clear = clear ~= false }
end

local function fresh()
	return OccupantBrainRules.newMind(1, 1, 0)
end

local AHEAD = Vector3.new(80, 3, 60)

return function()
	describe("newMind", function()
		it("starts patrolling at the given point and direction", function()
			local mind = OccupantBrainRules.newMind(3, -1, 5)
			expect(mind.mode).to.equal("patrol")
			expect(mind.routeIndex).to.equal(3)
			expect(mind.routeStep).to.equal(-1)
			expect(mind.since).to.equal(5)
			expect(next(mind.grace)).to.equal(nil)
		end)
	end)

	describe("patrol", function()
		it("walks his route at patrol pace", function()
			local step = OccupantBrainRules.step(fresh(), senses())
			expect(step.mind.mode).to.equal("patrol")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(ROUTE[1])
			expect(step.intent.run).to.equal(false)
			expect(step.cue).to.equal(nil)
		end)

		it("heads for the next point on arrival, in his direction, wrapping round", function()
			local forward = OccupantBrainRules.step(fresh(), senses({ position = Vector3.new(101, 3, 100) }))
			expect(forward.mind.routeIndex).to.equal(2)
			expect(forward.intent.position).to.equal(ROUTE[2])
			local backward =
				OccupantBrainRules.step(OccupantBrainRules.newMind(1, -1, 0), senses({ position = Vector3.new(101, 3, 100) }))
			expect(backward.mind.routeIndex).to.equal(3)
			expect(backward.intent.position).to.equal(ROUTE[3])
		end)

		it("stands still with no route", function()
			expect(OccupantBrainRules.step(fresh(), senses({ route = {} })).intent.kind).to.equal("idle")
		end)
	end)

	describe("investigate", function()
		local NOISE = Vector3.new(90, 0, 60)

		it("walks to a noise he hears, curious", function()
			local step = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			expect(step.mind.mode).to.equal("investigate")
			expect(step.mind.noise).to.equal(NOISE)
			expect(step.cue).to.equal("curious")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(NOISE)
			expect(step.intent.run).to.equal(false)
		end)

		it("ignores a noise inside the loading bay", function()
			local step = OccupantBrainRules.step(fresh(), senses({ heard = Vector3.new(20, 0, 10) }))
			expect(step.mind.mode).to.equal("patrol")
		end)

		it("looks around on arrival, then gives up with a sigh", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local there = Vector3.new(90, 3, 61)
			local arrived = OccupantBrainRules.step(heard.mind, senses({ position = there, now = 101 }))
			expect(arrived.intent.kind).to.equal("idle")
			expect(arrived.mind.arrivedAt).to.equal(101)
			local looking = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = there, now = 101 + OccupantConstants.LOOK_SECONDS - 0.1 })
			)
			expect(looking.mind.mode).to.equal("investigate")
			expect(looking.intent.kind).to.equal("idle")
			local done =
				OccupantBrainRules.step(arrived.mind, senses({ position = there, now = 101 + OccupantConstants.LOOK_SECONDS }))
			expect(done.mind.mode).to.equal("patrol")
			expect(done.cue).to.equal("giveUp")
			expect(done.mind.noise).to.equal(nil)
		end)

		it("gives up a noise he cannot reach", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local stuck = OccupantBrainRules.step(heard.mind, senses({ now = 100 + OccupantConstants.GIVE_UP_SECONDS }))
			expect(stuck.mind.mode).to.equal("patrol")
			expect(stuck.cue).to.equal("giveUp")
		end)

		it("turns to a newer noise without a second cue", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local other = Vector3.new(70, 0, 90)
			local again = OccupantBrainRules.step(heard.mind, senses({ heard = other, now = 101 }))
			expect(again.mind.noise).to.equal(other)
			expect(again.cue).to.equal(nil)
		end)
	end)

	describe("chase", function()
		it("spots a player in his cone with a clear line of sight", function()
			local step = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			expect(step.mind.mode).to.equal("chase")
			expect(step.mind.target).to.equal(7)
			expect(step.mind.lastSeen).to.equal(AHEAD)
			expect(step.cue).to.equal("spotted")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(AHEAD)
			expect(step.intent.run).to.equal(true)
		end)

		it("does not see through walls, behind him, past his range or outside his cone", function()
			for _, glimpse in
				{
					player(7, AHEAD, false),
					player(7, Vector3.new(40, 3, 60)),
					player(7, Vector3.new(130, 3, 60)),
					player(7, Vector3.new(60, 3, 90)),
				}
			do
				local step = OccupantBrainRules.step(fresh(), senses({ players = { glimpse } }))
				expect(step.mind.mode).to.equal("patrol")
			end
		end)

		it("catches within reach", function()
			local step = OccupantBrainRules.step(fresh(), senses({ players = { player(7, Vector3.new(63, 3, 60)) } }))
			expect(step.intent.kind).to.equal("attack")
			expect(step.intent.target).to.equal(7)
		end)

		it("keeps chasing his target over a nearer player", function()
			local first = OccupantBrainRules.step(fresh(), senses({ players = { player(7, Vector3.new(90, 3, 60)) } }))
			local second = OccupantBrainRules.step(
				first.mind,
				senses({ now = 101, players = { player(7, Vector3.new(90, 3, 60)), player(8, Vector3.new(70, 3, 60)) } })
			)
			expect(second.mind.target).to.equal(7)
			expect(second.cue).to.equal(nil)
		end)

		it("searches the last place he saw them, then gives up", function()
			local seenAt = Vector3.new(90, 3, 60)
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, seenAt) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101 }))
			expect(lost.mind.mode).to.equal("search")
			expect(lost.mind.target).to.equal(nil)
			expect(lost.intent.kind).to.equal("goTo")
			expect(lost.intent.position).to.equal(seenAt)
			expect(lost.intent.run).to.equal(true)
			local arrived = OccupantBrainRules.step(lost.mind, senses({ position = seenAt, now = 102 }))
			expect(arrived.mind.arrivedAt).to.equal(102)
			local searching = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = seenAt, now = 102 + OccupantConstants.SEARCH_SECONDS - 0.1 })
			)
			expect(searching.mind.mode).to.equal("search")
			local done = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = seenAt, now = 102 + OccupantConstants.SEARCH_SECONDS })
			)
			expect(done.mind.mode).to.equal("patrol")
			expect(done.cue).to.equal("giveUp")
		end)

		it("loses a player who steps into the loading bay and searches outside it", function()
			local base = { position = Vector3.new(60, 3, 20), look = Vector3.new(-1, 0, 0) }
			local outside = Vector3.new(45, 3, 20)
			local chase = OccupantBrainRules.step(fresh(), senses({ position = base.position, look = base.look, players = { player(7, outside) } }))
			expect(chase.mind.mode).to.equal("chase")
			local inside = OccupantBrainRules.step(
				chase.mind,
				senses({ position = base.position, look = base.look, now = 101, players = { player(7, Vector3.new(35, 3, 20)) } })
			)
			expect(inside.mind.mode).to.equal("search")
			expect(inside.intent.position).to.equal(outside)
			expect(OccupantBrainRules.inZone(inside.intent.position, ZONE)).to.equal(false)
		end)

		it("never spots a player standing in the loading bay", function()
			local step = OccupantBrainRules.step(
				fresh(),
				senses({ position = Vector3.new(60, 3, 20), look = Vector3.new(-1, 0, 0), players = { player(7, Vector3.new(35, 3, 20)) } })
			)
			expect(step.mind.mode).to.equal("patrol")
		end)
	end)

	describe("catch and grace", function()
		it("stands after a catch, then walks on to his next point", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			expect(caught.mode).to.equal("catch")
			expect(caught.grace[7]).to.equal(100 + OccupantConstants.GRACE_SECONDS)
			local holding = OccupantBrainRules.step(caught, senses({ now = 100 + OccupantConstants.CATCH_HOLD - 0.1 }))
			expect(holding.mind.mode).to.equal("catch")
			expect(holding.intent.kind).to.equal("idle")
			local walking = OccupantBrainRules.step(caught, senses({ now = 100 + OccupantConstants.CATCH_HOLD }))
			expect(walking.mind.mode).to.equal("patrol")
			expect(walking.mind.routeIndex).to.equal(2)
			expect(walking.intent.position).to.equal(ROUTE[2])
		end)

		it("ignores the caught player during the grace, and sees them after it", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			local during = OccupantBrainRules.step(
				caught,
				senses({ now = 100 + OccupantConstants.CATCH_HOLD + 1, players = { player(7, AHEAD) } })
			)
			expect(during.mind.mode).to.equal("patrol")
			local after = OccupantBrainRules.step(
				during.mind,
				senses({ now = 100 + OccupantConstants.GRACE_SECONDS, players = { player(7, AHEAD) } })
			)
			expect(after.mind.mode).to.equal("chase")
		end)

		it("still sees everyone else during one player's grace", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			local step = OccupantBrainRules.step(
				caught,
				senses({ now = 100 + OccupantConstants.CATCH_HOLD + 1, players = { player(8, AHEAD) } })
			)
			expect(step.mind.target).to.equal(8)
		end)

		it("does not change the mind he was given", function()
			local mind = fresh()
			OccupantBrainRules.caught(mind, 7, 100)
			expect(mind.mode).to.equal("patrol")
			expect(mind.grace[7]).to.equal(nil)
		end)
	end)

	describe("rest", function()
		it("walks to the break room on the break, ignoring everyone", function()
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local rest = OccupantBrainRules.step(chase.mind, senses({ resting = true, players = { player(7, AHEAD) } }))
			expect(rest.mind.mode).to.equal("rest")
			expect(rest.mind.target).to.equal(nil)
			expect(rest.cue).to.equal("resting")
			expect(rest.intent.kind).to.equal("goTo")
			expect(rest.intent.position).to.equal(REST)
			expect(rest.intent.run).to.equal(false)
		end)

		it("waits at the rest point and ignores noises", function()
			local rest = OccupantBrainRules.step(fresh(), senses({ resting = true }))
			local waiting = OccupantBrainRules.step(
				rest.mind,
				senses({ resting = true, position = Vector3.new(200, 3, 201), heard = Vector3.new(190, 0, 190) })
			)
			expect(waiting.mind.mode).to.equal("rest")
			expect(waiting.intent.kind).to.equal("idle")
			expect(waiting.cue).to.equal(nil)
		end)

		it("goes back to his route when the break ends", function()
			local rest = OccupantBrainRules.step(fresh(), senses({ resting = true }))
			local back = OccupantBrainRules.step(rest.mind, senses({ now = 140 }))
			expect(back.mind.mode).to.equal("patrol")
			expect(back.intent.kind).to.equal("goTo")
		end)
	end)

	describe("lookYaw", function()
		it("sweeps from straight ahead within the look sweep", function()
			expect(OccupantBrainRules.lookYaw(0)).to.equal(0)
			local limit = math.rad(OccupantConstants.LOOK_SWEEP) + 1e-6
			for index = 0, 80 do
				expect(math.abs(OccupantBrainRules.lookYaw(index * 0.1)) <= limit).to.equal(true)
			end
		end)
	end)
end
```

`src/ServerScriptService/Features/Occupant/Utils/OccupantTuningFormulas.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTuningFormulas = require(script.Parent.OccupantTuningFormulas)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoHandlingRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoHandlingRules)
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- Whether Harlow hears a noise of `radius` from `distance` studs away at this tier and crew size.
local function hears(distance, radius, tier, crew)
	local scale = OccupantTuningFormulas.tuning(tier, crew).hearing
	return NoiseRules.hears(Vector3.zero, Vector3.new(distance, 0, 0), radius, scale)
end

return function()
	describe("tuning", function()
		it("starts at patrol 10, chase 15 and plain hearing for a crew", function()
			local tuning = OccupantTuningFormulas.tuning(0, 3)
			expect(tuning.walkSpeed).to.equal(10)
			expect(tuning.runSpeed).to.equal(15)
			expect(tuning.hearing).to.equal(1)
		end)

		it("adds 1 patrol speed and ×1.2 hearing per tier", function()
			local tier1 = OccupantTuningFormulas.tuning(1, 3)
			expect(tier1.walkSpeed).to.equal(11)
			expect(tier1.runSpeed).to.equal(15)
			expect(tier1.hearing).to.be.near(1.2, 1e-6)
			local tier2 = OccupantTuningFormulas.tuning(2, 4)
			expect(tier2.walkSpeed).to.equal(12)
			expect(tier2.hearing).to.be.near(1.44, 1e-6)
		end)

		it("goes easier on a solo player: hearing ×0.75, chase −1", function()
			local solo = OccupantTuningFormulas.tuning(0, 1)
			expect(solo.walkSpeed).to.equal(10)
			expect(solo.runSpeed).to.equal(14)
			expect(solo.hearing).to.be.near(0.75, 1e-6)
			expect(OccupantTuningFormulas.tuning(2, 1).hearing).to.be.near(1.08, 1e-6)
		end)

		it("treats an empty crew as solo and caps the tier", function()
			expect(OccupantTuningFormulas.tuning(0, 0).runSpeed).to.equal(14)
			expect(OccupantTuningFormulas.tuning(5, 3).walkSpeed).to.equal(12)
			expect(OccupantTuningFormulas.tuning(-1, 3).walkSpeed).to.equal(10)
		end)

		it("keeps an empty-handed player (16) faster than his chase, and any carry slower", function()
			local chase = OccupantTuningFormulas.tuning(2, 4).runSpeed
			expect(16 > chase).to.equal(true)
			expect(16 * (1 - 0.05 * CargoConstants.WEIGHT.tiny) < chase).to.equal(true)
		end)
	end)

	describe("who hears what", function()
		it("hears a crew's vacuum within 40 studs at the start", function()
			expect(hears(39, VacuumConstants.NOISE_RADIUS, 0, 3)).to.equal(true)
			expect(hears(41, VacuumConstants.NOISE_RADIUS, 0, 3)).to.equal(false)
		end)

		it("hears further at each pressure tier", function()
			expect(hears(47, VacuumConstants.NOISE_RADIUS, 1, 3)).to.equal(true)
			expect(hears(49, VacuumConstants.NOISE_RADIUS, 1, 3)).to.equal(false)
			expect(hears(57, VacuumConstants.NOISE_RADIUS, 2, 3)).to.equal(true)
			expect(hears(58, VacuumConstants.NOISE_RADIUS, 2, 3)).to.equal(false)
		end)

		it("hears a solo player at three quarters of the radius", function()
			expect(hears(29, VacuumConstants.NOISE_RADIUS, 0, 1)).to.equal(true)
			expect(hears(31, VacuumConstants.NOISE_RADIUS, 0, 1)).to.equal(false)
		end)

		it("hears a heavy drop further than a light one, and the jug's splash across a room", function()
			local bag = CargoHandlingRules.dropNoise(CargoRegistry.get("rubbishBag"))
			local printer = CargoHandlingRules.dropNoise(CargoRegistry.get("printer"))
			local jug = CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))
			expect(hears(20, bag, 0, 3)).to.equal(false)
			expect(hears(20, printer, 0, 3)).to.equal(true)
			expect(hears(65, jug, 0, 3)).to.equal(true)
			expect(hears(15, CargoConstants.RATTLE_NOISE, 0, 3)).to.equal(false)
			expect(hears(10, CargoConstants.RATTLE_NOISE, 0, 3)).to.equal(true)
		end)
	end)
end
```

The "any carry slower" line mirrors M1's Carry maths (`CarryFormulas.walkSpeedFor(16, weight, 0.05, 0.4)` = 16 × (1 − 0.05 × weight) above the floor): a tiny item gives 14.8 < 15, but solo chase is 14 (spec: solo chase −1), which is why the line uses the full crew's chase speed.

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Constants** `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau`:

```lua
--!strict
--[=[
	OccupantConstants: Mr. Harlow's tuning, names, placeholder lines and body (Cleanup Crew spec §4 "Mr.
	Harlow", §7). Every number is a tuning hypothesis. The pacing knobs (pressure tiers, party size) live in
	ShiftConstants (spec §4 "Pacing": one constants module). Static data (spec-exempt).

	@class OccupantConstants
]=]

export type Body = {
	height: number,
	width: number,
	depth: number,
	head: number,
	suit: Color3,
	shirt: Color3,
	skin: Color3,
}

-- "A tall, too-thin suited R15 rig built from a HumanoidDescription in code" (spec §7).
local BODY: Body = {
	height = 1.3,
	width = 0.7,
	depth = 0.65,
	head = 0.9,
	suit = Color3.fromRGB(38, 40, 48),
	shirt = Color3.fromRGB(205, 205, 195),
	skin = Color3.fromRGB(214, 200, 180),
}

-- Placeholder speech-bubble lines by OccupantTypes.Cue (spec §4 "Voice"; M3 adds the gibberish voice).
local LINES: { [string]: string } = {
	spotted = "Those are COMPANY ASSETS.",
	curious = "Per my last email…",
	caught = "You're FIRED!",
	giveUp = "*sigh*",
	resting = "Fifteen minutes. Union rules.",
}

return table.freeze({
	-- The NPC kind, and the tag the client's tells find him by.
	NPC_KIND = "harlow",
	TAG = "Occupant",
	-- Replicated attributes on his model: his mode, and the UserId he is chasing (0 = nobody).
	MODE_ATTRIBUTE = "OccupantMode",
	TARGET_ATTRIBUTE = "OccupantTarget",
	-- Speeds (spec: patrol 10, chase 15); tiers and party size adjust them (OccupantTuningFormulas).
	PATROL_SPEED = 10,
	CHASE_SPEED = 15,
	-- Sight: ~60 studs, a 100° cone, line of sight.
	SIGHT_RANGE = 60,
	SIGHT_ANGLE = 100,
	-- Investigate: look around ~4 s at the noise; search: ~6 s at the last-seen point; either gives up after
	-- GIVE_UP_SECONDS (an unreachable point).
	LOOK_SECONDS = 4,
	SEARCH_SECONDS = 6,
	GIVE_UP_SECONDS = 20,
	-- Close enough to a point to count as there (flat studs).
	REACHED_DISTANCE = 3,
	-- While looking around he sweeps ±LOOK_SWEEP degrees at LOOK_RATE radians of phase per second.
	LOOK_SWEEP = 70,
	LOOK_RATE = 1.2,
	-- Catch at ~4 studs (the server re-checks with CATCH_SLACK of tolerance); one try per CATCH_COOLDOWN.
	CATCH_RANGE = 4,
	CATCH_SLACK = 1,
	CATCH_COOLDOWN = 1,
	-- After a catch he stands CATCH_HOLD seconds, then walks on; he ignores that player GRACE_SECONDS.
	CATCH_HOLD = 1.5,
	GRACE_SECONDS = 10,
	-- The catch: camera on his face ~0.6 s, then the launch; ~8 s spectating (Death's respawn delay).
	SNAP_SECONDS = 0.6,
	SPECTATE_SECONDS = 8,
	LAUNCH_SPEED = 45,
	LAUNCH_UP = 35,
	-- He appears this far above his starting route point.
	SPAWN_HEIGHT = 4,
	-- How often his speeds and hearing are refreshed (tier, crew size).
	TUNING_INTERVAL = 1,
	-- Tells: lights within ~20 studs flicker; the heartbeat within HEARTBEAT_RANGE, one beat per BEAT_SLOW
	-- seconds at the edge down to BEAT_FAST up close.
	FLICKER_RADIUS = 20,
	HEARTBEAT_RANGE = 40,
	BEAT_SLOW = 1,
	BEAT_FAST = 0.45,
	-- A catch kills the lights within LIGHTS_OUT_RADIUS for LIGHTS_OUT_SECONDS; a tier rise flickers every
	-- light for TIER_FLICKER_SECONDS. The client re-checks the tells every TELL_INTERVAL.
	LIGHTS_OUT_RADIUS = 30,
	LIGHTS_OUT_SECONDS = 2.5,
	TIER_FLICKER_SECONDS = 1.5,
	TELL_INTERVAL = 0.05,
	SPEECH_SECONDS = 3,
	-- The catch camera (above Death's spectate mode at 50) and its screen effect.
	CAMERA_PRIORITY = 70,
	CATCH_FOV = 50,
	CATCH_TRAUMA = 0.6,
	CATCH_TINT = Color3.fromRGB(255, 120, 120),
	HEARTBEAT_TINT = Color3.fromRGB(255, 150, 150),
	-- The loading bay's PathfindingModifier label (Office builds it; his kind's pathCosts never enter it), and
	-- the tag on the office's ceiling lights (Office builds them; the tells flicker them).
	SAFE_ZONE_LABEL = "SafeZone",
	LIGHT_TAG = "OfficeLight",
	-- His billboards (placeholders).
	CUE_NAME = "OccupantCue",
	SPEECH_NAME = "OccupantSpeech",
	DISPLAY_NAME = "Mr. Harlow",
	REHIRED_TEXT = "Rehired.",
	BODY = table.freeze(BODY),
	LINES = table.freeze(LINES),
})
```

- [ ] **Step 4: Types** `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau`:

```lua
--!strict
--[=[
	OccupantTypes: Mr. Harlow's shapes (Cleanup Crew spec §4 "Mr. Harlow"). Shared: the client reads his mode
	from an attribute. Types only (spec-exempt).

	@class OccupantTypes
]=]

-- What he is doing: walking his route, checking a noise, chasing someone he sees, searching where he lost
-- them, on the shift's break, or standing over a catch.
export type Mode = "patrol" | "investigate" | "chase" | "search" | "rest" | "catch"

-- A moment worth a speech bubble (OccupantConstants.LINES).
export type Cue = "spotted" | "curious" | "giveUp" | "resting" | "caught"

-- An axis-aligned box in the world (the loading bay).
export type Zone = {
	min: Vector3,
	max: Vector3,
}

-- His memory between thinks. Times are os.clock() seconds.
export type Mind = {
	mode: Mode,
	-- When the current mode began.
	since: number,
	-- The route point he is walking to, and which way round he walks (1 or -1).
	routeIndex: number,
	routeStep: number,
	-- The UserId he is chasing.
	target: number?,
	-- Where he last saw his target (always outside the loading bay).
	lastSeen: Vector3?,
	-- The noise he is investigating.
	noise: Vector3?,
	-- When he reached the investigate / search point (looking around since).
	arrivedAt: number?,
	-- UserId → the os.clock() until which he ignores them (after a catch).
	grace: { [number]: number },
}

-- One crew member as the service saw them this think; `clear` is the line-of-sight ray's verdict.
export type Glimpse = {
	userId: number,
	position: Vector3,
	clear: boolean,
}

-- Everything the brain decides from, gathered by OccupantServiceServer each think.
export type Senses = {
	position: Vector3,
	look: Vector3,
	now: number,
	sightRange: number,
	sightAngle: number,
	players: { Glimpse },
	-- The last noise he heard since the previous think (already through NoiseRules).
	heard: Vector3?,
	-- The shift's break: he walks to `restPoint` and ignores everyone.
	resting: boolean,
	route: { Vector3 },
	restPoint: Vector3,
	zone: Zone,
}

-- What the catch rule needs about a would-be catch.
export type CatchInput = {
	distance: number,
	position: Vector3,
	alive: boolean,
	-- Their catch sequence is already running.
	catching: boolean,
	inGrace: boolean,
	resting: boolean,
	zone: Zone,
}

return {}
```

- [ ] **Step 5: Brain rules** `src/ServerScriptService/Features/Occupant/Rules/OccupantBrainRules.luau`:

```lua
--!strict
--[=[
	OccupantBrainRules: Mr. Harlow's decisions (Cleanup Crew spec §4 "Mr. Harlow"), as pure functions over his
	Mind and what he senses this think:

	- patrol: walk the authored loop from his random start, in his random direction;
	- investigate: walk to the last noise heard, look around LOOK_SECONDS, sigh, patrol;
	- chase: anyone within sightRange, inside the sightAngle cone, with a clear line of sight; a target he can
	  still see is kept over a nearer player; within CATCH_RANGE the intent is `attack` (the catch);
	- search: lost sight → run to where he last saw them, look around SEARCH_SECONDS, sigh, patrol;
	- rest: the shift's break → walk to the rest point and ignore everyone and everything;
	- catch: stand CATCH_HOLD seconds, then walk on to his next route point, ignoring the caught player for
	  GRACE_SECONDS.

	The loading bay (`zone`) is safe: nobody inside it is seen, no noise inside it is followed, so no goal is
	ever inside it (his kind's pathCosts also make it unwalkable). Investigate and search give up after
	GIVE_UP_SECONDS if he never gets there.

	The line-of-sight ray is the caller's (OccupantServiceServer): each Glimpse says whether it was clear.
	Pure: nothing here yields or touches an Instance; it never changes the mind it is given. Times are
	os.clock() seconds (the NPC brain's `now`).

	@class OccupantBrainRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local NpcSenseRules = require(ServerScriptService.Features.Npc.Rules.NpcSenseRules)

type Mind = OccupantTypes.Mind
type Mode = OccupantTypes.Mode
type Cue = OccupantTypes.Cue
type Senses = OccupantTypes.Senses
type Glimpse = OccupantTypes.Glimpse

export type Step = {
	mind: Mind,
	intent: NpcTypes.Intent,
	cue: Cue?,
}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 1..count, wrapping both ways (Luau's % is floored, so -1 % 3 == 2).
local function wrap(index: number, count: number): number
	return (index - 1) % count + 1
end

-- A copy of `mind` in `mode`, begun `now`, not yet arrived anywhere.
local function enter(mind: Mind, mode: Mode, now: number): Mind
	local nextMind = table.clone(mind)
	nextMind.mode = mode
	nextMind.since = now
	nextMind.arrivedAt = nil
	return nextMind
end

local function forget(mind: Mind)
	mind.target = nil
	mind.lastSeen = nil
	mind.noise = nil
end

-- Walks the route: on reaching the current point, heads for the next one in his direction.
local function patrol(mind: Mind, senses: Senses, cue: Cue?): Step
	local route = senses.route
	if #route == 0 then
		return { mind = mind, intent = { kind = "idle" }, cue = cue }
	end
	local index = wrap(mind.routeIndex, #route)
	if flatDistance(senses.position, route[index]) <= OccupantConstants.REACHED_DISTANCE then
		index = wrap(index + mind.routeStep, #route)
	end
	local nextMind = mind
	if index ~= mind.routeIndex then
		nextMind = table.clone(mind)
		nextMind.routeIndex = index
	end
	return { mind = nextMind, intent = { kind = "goTo", position = route[index], run = false }, cue = cue }
end

local function giveUp(mind: Mind, senses: Senses): Step
	local nextMind = enter(mind, "patrol", senses.now)
	forget(nextMind)
	return patrol(nextMind, senses, "giveUp")
end

local OccupantBrainRules = {}

--[=[
	A fresh Harlow: patrolling toward route point `routeIndex`, walking the loop in `routeStep`'s direction.
]=]
function OccupantBrainRules.newMind(routeIndex: number, routeStep: number, now: number): Mind
	return {
		mode = "patrol",
		since = now,
		routeIndex = routeIndex,
		routeStep = if routeStep < 0 then -1 else 1,
		grace = {},
	}
end

function OccupantBrainRules.inZone(point: Vector3, zone: OccupantTypes.Zone): boolean
	return point.X >= zone.min.X
		and point.X <= zone.max.X
		and point.Y >= zone.min.Y
		and point.Y <= zone.max.Y
		and point.Z >= zone.min.Z
		and point.Z <= zone.max.Z
end

--[=[
	The players he sees this think, nearest first: a clear ray, in range and cone, outside the safe zone, not in
	their grace.
]=]
function OccupantBrainRules.visible(mind: Mind, senses: Senses): { Glimpse }
	local list: { Glimpse } = {}
	for _, glimpse in senses.players do
		local graceUntil = mind.grace[glimpse.userId]
		local graced = graceUntil ~= nil and senses.now < graceUntil
		if
			glimpse.clear
			and not graced
			and not OccupantBrainRules.inZone(glimpse.position, senses.zone)
			and NpcSenseRules.inSight(senses.position, senses.look, glimpse.position, senses.sightRange, senses.sightAngle)
		then
			table.insert(list, glimpse)
		end
	end
	table.sort(list, function(a, b)
		local distanceA = (a.position - senses.position).Magnitude
		local distanceB = (b.position - senses.position).Magnitude
		if distanceA ~= distanceB then
			return distanceA < distanceB
		end
		return a.userId < b.userId
	end)
	return list
end

--[=[
	The mind after he catches `userId`: standing over the catch, that player in their grace.
]=]
function OccupantBrainRules.caught(mind: Mind, userId: number, now: number): Mind
	local nextMind = enter(mind, "catch", now)
	local grace = table.clone(mind.grace)
	grace[userId] = now + OccupantConstants.GRACE_SECONDS
	nextMind.grace = grace
	forget(nextMind)
	return nextMind
end

--[=[
	How far (radians) to turn from his arrival heading while looking around, `elapsed` seconds in.
]=]
function OccupantBrainRules.lookYaw(elapsed: number): number
	return math.rad(OccupantConstants.LOOK_SWEEP) * math.sin(elapsed * OccupantConstants.LOOK_RATE)
end

--[=[
	One think: the next mind, the NPC intent, and a cue worth a speech bubble (or nil).
]=]
function OccupantBrainRules.step(mind: Mind, senses: Senses): Step
	local now = senses.now

	-- The shift's break overrides everything.
	if senses.resting then
		local nextMind = mind
		local cue: Cue? = nil
		if mind.mode ~= "rest" then
			nextMind = enter(mind, "rest", now)
			forget(nextMind)
			cue = "resting"
		end
		if flatDistance(senses.position, senses.restPoint) <= OccupantConstants.REACHED_DISTANCE then
			return { mind = nextMind, intent = { kind = "idle" }, cue = cue }
		end
		return { mind = nextMind, intent = { kind = "goTo", position = senses.restPoint, run = false }, cue = cue }
	end

	-- Standing over a catch, then walking away (toward his next route point); back from the break.
	local current = mind
	if mind.mode == "catch" then
		if now - mind.since < OccupantConstants.CATCH_HOLD then
			return { mind = mind, intent = { kind = "idle" } }
		end
		current = enter(mind, "patrol", now)
		if #senses.route > 0 then
			current.routeIndex = wrap(mind.routeIndex + mind.routeStep, #senses.route)
		end
	elseif mind.mode == "rest" then
		current = enter(mind, "patrol", now)
	end

	-- Sight beats everything else.
	local seen = OccupantBrainRules.visible(current, senses)
	if #seen > 0 then
		local pick = seen[1]
		for _, glimpse in seen do
			if glimpse.userId == current.target then
				pick = glimpse
			end
		end
		local chasing = current.mode == "chase"
		local nextMind = if chasing then table.clone(current) else enter(current, "chase", now)
		nextMind.target = pick.userId
		nextMind.lastSeen = pick.position
		nextMind.noise = nil
		local cue: Cue? = if chasing then nil else "spotted"
		if (pick.position - senses.position).Magnitude <= OccupantConstants.CATCH_RANGE then
			return { mind = nextMind, intent = { kind = "attack", target = pick.userId }, cue = cue }
		end
		return { mind = nextMind, intent = { kind = "goTo", position = pick.position, run = true }, cue = cue }
	end

	-- Lost them: search where he last saw them.
	if current.mode == "chase" then
		local nextMind = enter(current, "search", now)
		nextMind.target = nil
		local lastSeen = nextMind.lastSeen
		if lastSeen == nil then
			return giveUp(nextMind, senses)
		end
		return { mind = nextMind, intent = { kind = "goTo", position = lastSeen, run = true } }
	end

	-- A noise (outside the safe zone).
	local heard = senses.heard
	if heard ~= nil and not OccupantBrainRules.inZone(heard, senses.zone) then
		local nextMind = enter(current, "investigate", now)
		nextMind.noise = heard
		local cue: Cue? = if current.mode == "investigate" then nil else "curious"
		return { mind = nextMind, intent = { kind = "goTo", position = heard, run = false }, cue = cue }
	end

	-- Walking to the noise / last-seen point, looking around, giving up.
	if current.mode == "investigate" or current.mode == "search" then
		local searching = current.mode == "search"
		local point = if searching then current.lastSeen else current.noise
		local hold = if searching then OccupantConstants.SEARCH_SECONDS else OccupantConstants.LOOK_SECONDS
		if point == nil or now - current.since >= OccupantConstants.GIVE_UP_SECONDS then
			return giveUp(current, senses)
		end
		local arrivedAt = current.arrivedAt
		if arrivedAt == nil then
			if flatDistance(senses.position, point) <= OccupantConstants.REACHED_DISTANCE then
				local nextMind = table.clone(current)
				nextMind.arrivedAt = now
				return { mind = nextMind, intent = { kind = "idle" } }
			end
			return { mind = current, intent = { kind = "goTo", position = point, run = searching } }
		end
		if now - arrivedAt >= hold then
			return giveUp(current, senses)
		end
		return { mind = current, intent = { kind = "idle" } }
	end

	return patrol(current, senses, nil)
end

return OccupantBrainRules
```

If luau-lsp cannot infer an `Intent` member from a nested table literal, give the literal a typed local first (`local intent: NpcTypes.Intent = { kind = "goTo", position = point, run = searching }`) and return `{ mind = current, intent = intent }`; no cast.

- [ ] **Step 6: Tuning formulas** `src/ServerScriptService/Features/Occupant/Utils/OccupantTuningFormulas.luau`:

```lua
--!strict
--[=[
	OccupantTuningFormulas: Harlow's speeds and hearing for the shift's pressure tier and the crew size
	(Cleanup Crew spec §4 "Pacing"): each tier adds TIER_PATROL_SPEED to his patrol speed and multiplies his
	hearing by TIER_HEARING (compounding: ×1.2, ×1.44); a solo crew gets SOLO_HEARING and SOLO_CHASE_SPEED.
	The tier is clamped to 0..TOP_TIER; a crew of 0 counts as solo. Pure.

	@class OccupantTuningFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

export type Tuning = {
	walkSpeed: number,
	runSpeed: number,
	-- Multiplies every noise's radius (NoiseRules).
	hearing: number,
}

local OccupantTuningFormulas = {}

function OccupantTuningFormulas.tuning(tier: number, crew: number): Tuning
	local level = math.clamp(math.floor(tier), 0, ShiftConstants.TOP_TIER)
	local solo = crew <= 1
	return {
		walkSpeed = OccupantConstants.PATROL_SPEED + level * ShiftConstants.TIER_PATROL_SPEED,
		runSpeed = OccupantConstants.CHASE_SPEED + (if solo then ShiftConstants.SOLO_CHASE_SPEED else 0),
		hearing = ShiftConstants.TIER_HEARING ^ level * (if solo then ShiftConstants.SOLO_HEARING else 1),
	}
end

return OccupantTuningFormulas
```

- [ ] **Step 7: Exemptions.** Add under a `-- Cleanup Crew: Occupant` comment:

```lua
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants"] = "static tuning, names and placeholder lines (no logic)",
	["ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes"] = "type definitions only (no runtime logic)",
```

- [ ] **Step 8: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 9: Controller: Studio TestEZ.** Expected: OccupantBrainRules and OccupantTuningFormulas pass.

- [ ] **Step 10: Commit**

```bash
git commit -m "feat(occupant): Harlow's brain rules and tier/party tuning"
python3 scripts/python/module_map.py --check
```

---
### Task 7: Occupant catch and tell rules (pure)

**Files:**
- Create: `src/ServerScriptService/Features/Occupant/Rules/OccupantCatchRules.luau` (+ `OccupantCatchRules.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Rules/OccupantTellRules.luau` (+ `OccupantTellRules.spec.luau`)

**Interfaces:**
- Consumes (Task 6): `OccupantConstants.*`, `OccupantTypes.CatchInput / Zone`, `OccupantBrainRules.inZone`.
- Produces (OccupantCatchRules): `canCatch(input: CatchInput) -> (boolean, string?)` (reasons, in this order: `"not alive"`, `"already caught"`, `"on break"`, `"grace"`, `"safe zone"`, `"too far"`; reach = `CATCH_RANGE + CATCH_SLACK`); `launch(from: Vector3, to: Vector3, speed: number, up: number) -> Vector3` (flat direction Harlow → victim × speed, plus `up`; +X when they stand on the same spot).
- Produces (OccupantTellRules): `cueFor(mode: string?) -> string` (`"?"` investigating or searching, `"!"` chasing, `""` otherwise); `lineFor(cue: string?) -> string?` (`OccupantConstants.LINES[cue]`); `heartbeat(distance: number, mode: string?, huntingMe: boolean) -> boolean`; `period(distance: number) -> number`; `pulse(elapsed: number, distance: number) -> number` (0..1); `flicker(distance: number, now: number, seed: number) -> boolean` (true = lit).

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Occupant/Rules/OccupantCatchRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantCatchRules = require(script.Parent.OccupantCatchRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }

local function input(extra)
	local value = {
		distance = 3,
		position = Vector3.new(60, 3, 60),
		alive = true,
		catching = false,
		inGrace = false,
		resting = false,
		zone = ZONE,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function refused(extra, expected)
	local ok, reason = OccupantCatchRules.canCatch(input(extra))
	expect(ok).to.equal(false)
	expect(reason).to.equal(expected)
end

return function()
	describe("canCatch", function()
		it("catches a living player within reach outside the loading bay", function()
			expect(OccupantCatchRules.canCatch(input())).to.equal(true)
			expect(OccupantCatchRules.canCatch(input({ distance = OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK }))).to.equal(true)
		end)

		it("refuses a player out of reach", function()
			refused({ distance = OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK + 0.1 }, "too far")
		end)

		it("refuses a player in the safe zone, even at arm's length", function()
			refused({ position = Vector3.new(38, 3, 28), distance = 2 }, "safe zone")
		end)

		it("refuses a dead player, one mid-catch, one in grace, and anyone on his break", function()
			refused({ alive = false }, "not alive")
			refused({ catching = true }, "already caught")
			refused({ inGrace = true }, "grace")
			refused({ resting = true }, "on break")
		end)
	end)

	describe("launch", function()
		it("throws the player away from him and up", function()
			local velocity = OccupantCatchRules.launch(Vector3.new(0, 5, 0), Vector3.new(10, 3, 0), 45, 35)
			expect(velocity.X).to.be.near(45, 1e-6)
			expect(velocity.Y).to.be.near(35, 1e-6)
			expect(velocity.Z).to.be.near(0, 1e-6)
		end)

		it("throws at full speed on a diagonal", function()
			local velocity = OccupantCatchRules.launch(Vector3.zero, Vector3.new(3, 0, 4), 45, 35)
			expect(Vector3.new(velocity.X, 0, velocity.Z).Magnitude).to.be.near(45, 1e-6)
		end)

		it("still throws when they stand on the same spot", function()
			local velocity = OccupantCatchRules.launch(Vector3.zero, Vector3.new(0, 2, 0), 45, 35)
			expect(velocity.X).to.be.near(45, 1e-6)
			expect(velocity.Y).to.be.near(35, 1e-6)
		end)
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Occupant/Rules/OccupantTellRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTellRules = require(script.Parent.OccupantTellRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

return function()
	describe("cues and lines", function()
		it("shows ? while he investigates or searches and ! while he chases", function()
			expect(OccupantTellRules.cueFor("investigate")).to.equal("?")
			expect(OccupantTellRules.cueFor("search")).to.equal("?")
			expect(OccupantTellRules.cueFor("chase")).to.equal("!")
			expect(OccupantTellRules.cueFor("patrol")).to.equal("")
			expect(OccupantTellRules.cueFor("rest")).to.equal("")
			expect(OccupantTellRules.cueFor(nil)).to.equal("")
		end)

		it("speaks the spec's lines", function()
			expect(OccupantTellRules.lineFor("spotted")).to.equal("Those are COMPANY ASSETS.")
			expect(OccupantTellRules.lineFor("curious")).to.equal("Per my last email…")
			expect(OccupantTellRules.lineFor("caught")).to.equal("You're FIRED!")
			expect(OccupantTellRules.lineFor("giveUp")).to.equal(OccupantConstants.LINES.giveUp)
			expect(OccupantTellRules.lineFor(nil)).to.equal(nil)
			expect(OccupantTellRules.lineFor("nonsense")).to.equal(nil)
		end)
	end)

	describe("heartbeat", function()
		it("beats when he is near and has not seen you", function()
			expect(OccupantTellRules.heartbeat(20, "patrol", false)).to.equal(true)
			expect(OccupantTellRules.heartbeat(20, "chase", false)).to.equal(true)
			expect(OccupantTellRules.heartbeat(20, "investigate", true)).to.equal(true)
		end)

		it("stops when he is far or chasing you", function()
			expect(OccupantTellRules.heartbeat(OccupantConstants.HEARTBEAT_RANGE + 1, "patrol", false)).to.equal(false)
			expect(OccupantTellRules.heartbeat(10, "chase", true)).to.equal(false)
		end)

		it("beats faster the closer he is", function()
			expect(OccupantTellRules.period(0)).to.be.near(OccupantConstants.BEAT_FAST, 1e-6)
			expect(OccupantTellRules.period(OccupantConstants.HEARTBEAT_RANGE)).to.be.near(OccupantConstants.BEAT_SLOW, 1e-6)
			expect(OccupantTellRules.period(999)).to.be.near(OccupantConstants.BEAT_SLOW, 1e-6)
			expect(OccupantTellRules.period(10) < OccupantTellRules.period(30)).to.equal(true)
		end)

		it("pulses from full at each beat and fades within it", function()
			expect(OccupantTellRules.pulse(0, 20)).to.equal(1)
			local period = OccupantTellRules.period(20)
			expect(OccupantTellRules.pulse(period * 0.9, 20)).to.equal(0)
			expect(OccupantTellRules.pulse(period, 20)).to.be.near(1, 1e-6)
			for index = 0, 50 do
				local value = OccupantTellRules.pulse(index * 0.07, 15)
				expect(value >= 0 and value <= 1).to.equal(true)
			end
		end)
	end)

	describe("flicker", function()
		it("leaves lights far from him alone", function()
			for index = 0, 50 do
				expect(OccupantTellRules.flicker(OccupantConstants.FLICKER_RADIUS + 1, index * 0.05, 0.37)).to.equal(true)
			end
		end)

		it("flickers lights near him: mostly on, sometimes off", function()
			local on, off = 0, 0
			for index = 0, 399 do
				if OccupantTellRules.flicker(5, index * 0.05, 0.37) then
					on += 1
				else
					off += 1
				end
			end
			expect(on > 0).to.equal(true)
			expect(off > 0).to.equal(true)
			expect(on > off).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Catch rules** `src/ServerScriptService/Features/Occupant/Rules/OccupantCatchRules.luau`:

```lua
--!strict
--[=[
	OccupantCatchRules: whether Harlow may catch a player right now (Cleanup Crew spec §4 "Catch", "Grace",
	§6.4 "Catches are decided on the server tick"): alive, not already being caught, not on his break, not in
	their grace, outside the loading bay, and within reach (CATCH_RANGE plus CATCH_SLACK, since the base checks
	the range a moment earlier). `launch` is the throw: away from him, flat, plus an upward kick. Pure.

	@class OccupantCatchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)

local OccupantCatchRules = {}

function OccupantCatchRules.canCatch(input: OccupantTypes.CatchInput): (boolean, string?)
	if not input.alive then
		return false, "not alive"
	end
	if input.catching then
		return false, "already caught"
	end
	if input.resting then
		return false, "on break"
	end
	if input.inGrace then
		return false, "grace"
	end
	if OccupantBrainRules.inZone(input.position, input.zone) then
		return false, "safe zone"
	end
	if input.distance > OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK then
		return false, "too far"
	end
	return true, nil
end

--[=[
	The ragdoll launch velocity: `speed` along the flat direction from `from` (Harlow) to `to` (the player),
	plus `up`. Straight along +X when they share a spot.
]=]
function OccupantCatchRules.launch(from: Vector3, to: Vector3, speed: number, up: number): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	return direction * speed + Vector3.new(0, up, 0)
end

return OccupantCatchRules
```

- [ ] **Step 4: Tell rules** `src/ReplicatedStorage/Shared/Features/Occupant/Rules/OccupantTellRules.luau`:

```lua
--!strict
--[=[
	OccupantTellRules: what Harlow's tells show (Cleanup Crew spec §4 "Tells", §7): "?" over his head while he
	investigates or searches, "!" while he chases; a speech-bubble line per cue; a heartbeat while he is within
	HEARTBEAT_RANGE and not chasing you, beating faster the closer he is; lights within FLICKER_RADIUS of him
	flicker (deterministic noise per light, mostly on). Shared: the server uses the cues and lines, the client
	the heartbeat and flicker. Pure.

	@class OccupantTellRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- Below this noise value a light near him is dark this instant.
local FLICKER_THRESHOLD = -0.1
-- How fast the flicker noise moves (per second).
local FLICKER_RATE = 7

local OccupantTellRules = {}

function OccupantTellRules.cueFor(mode: string?): string
	if mode == "investigate" or mode == "search" then
		return "?"
	end
	if mode == "chase" then
		return "!"
	end
	return ""
end

function OccupantTellRules.lineFor(cue: string?): string?
	if cue == nil then
		return nil
	end
	return OccupantConstants.LINES[cue]
end

--[=[
	Whether your heartbeat sounds: he is within HEARTBEAT_RANGE and not chasing you.
]=]
function OccupantTellRules.heartbeat(distance: number, mode: string?, huntingMe: boolean): boolean
	if distance > OccupantConstants.HEARTBEAT_RANGE then
		return false
	end
	return not (mode == "chase" and huntingMe)
end

--[=[
	Seconds per beat: BEAT_SLOW at the edge of the range, BEAT_FAST with him on top of you.
]=]
function OccupantTellRules.period(distance: number): number
	local closeness = 1 - math.clamp(distance / OccupantConstants.HEARTBEAT_RANGE, 0, 1)
	return OccupantConstants.BEAT_SLOW + (OccupantConstants.BEAT_FAST - OccupantConstants.BEAT_SLOW) * closeness
end

--[=[
	The beat's strength (0..1) `elapsed` seconds into the heartbeat: full at each beat, gone a third of the way
	to the next.
]=]
function OccupantTellRules.pulse(elapsed: number, distance: number): number
	local period = OccupantTellRules.period(distance)
	local phase = (elapsed % period) / period
	return math.clamp(1 - phase * 3, 0, 1)
end

--[=[
	Whether a light `distance` studs from him is lit at `now` (`seed` tells lights apart).
]=]
function OccupantTellRules.flicker(distance: number, now: number, seed: number): boolean
	if distance > OccupantConstants.FLICKER_RADIUS then
		return true
	end
	return math.noise(now * FLICKER_RATE, seed) > FLICKER_THRESHOLD
end

return OccupantTellRules
```

- [ ] **Step 5: Exemptions.** None (both have specs).

- [ ] **Step 6: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 7: Controller: Studio TestEZ.** Expected: OccupantCatchRules and OccupantTellRules pass. If "flickers lights near him" finds no dark sample (the noise field happens to stay high along that line), move `FLICKER_THRESHOLD` to `-0.05` and re-run; report the change.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(occupant): catch rules and tell rules"
python3 scripts/python/module_map.py --check
```

---
### Task 8: Office for Harlow (route, rest point, lights, safe-zone volume)

**Files:**
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`
- Modify: `src/ServerScriptService/Features/Office/Data/OfficeLayoutConstants.luau`
- Modify: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau` (+ spec cases)
- Modify: `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau` (+ spec cases)
- Modify: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau`
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`

**Interfaces:**
- Consumes (Task 6): `OccupantConstants.LIGHT_TAG = "OfficeLight"`, `OccupantConstants.SAFE_ZONE_LABEL = "SafeZone"`; M1's Office modules as in the M1 plan's Tasks 3 and 9.
- Produces (OfficeTypes): `MarkerKind` gains `"patrol" | "rest"`; `Layout` gains `route: { string }` (patrol marker ids in walking order, a loop) and `rest: string` (the rest marker's id).
- Produces (OfficeConstants, new keys): `LIGHT_SPACING = 15`, `LIGHT_SIZE`, `LIGHT_COLOR`, `LIGHT_RANGE = 16`, `LIGHT_BRIGHTNESS = 1.2`, `SAFE_ZONE_NAME = "SafeZone"`, `ROUTE_MIN = 3`.
- Produces (OfficeLayoutUtils, new): `lightPoints(room: Room, spacing: number) -> { { number } }` (`{ x, z }` office-local, an even grid, at least one); `bounds(room: Room, height: number) -> (Vector3, Vector3)` (office-local min/max, floor to `height`).
- Produces (OfficeLayoutRules, new): `checkRoute(layout) -> (boolean, string?)` (≥ ROUTE_MIN points, each a patrol marker outside the start room; the rest marker exists and is outside the start room).
- Produces (OfficeServiceServer, new): `route() -> { Vector3 }` (world floor points, walking order), `restPoint() -> Vector3`, `safeZone() -> (Vector3, Vector3)` (the loading bay's world min/max corners, floor to wall top).
- Built once (OfficeBuildSystem): a ceiling light (neon part + PointLight, tagged `OfficeLight`) on each `lightPoints` spot of every room; one invisible, non-colliding, non-queryable `SafeZone` part filling the start room with a `PathfindingModifier` labelled `SafeZone` (Harlow's kind costs it `math.huge`).

- [ ] **Step 1: Write the failing spec cases.**

Add to `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.spec.luau` (top level, after `describe("lookups", ...)`):

```lua
	describe("lightPoints", function()
		it("spreads lights evenly about one per spacing", function()
			local bay = OfficeLayoutUtils.room(LAYOUT, "bay")
			local points = OfficeLayoutUtils.lightPoints(bay, 15)
			expect(#points).to.equal(4)
			expect(points[1][1]).to.equal(10)
			expect(points[1][2]).to.equal(7.5)
			expect(points[4][1]).to.equal(30)
			expect(points[4][2]).to.equal(22.5)
		end)

		it("puts at least one light in the middle of a small room", function()
			local points = OfficeLayoutUtils.lightPoints(ROOM, 15)
			expect(#points).to.equal(1)
			expect(points[1][1]).to.equal(10)
			expect(points[1][2]).to.equal(5)
		end)
	end)

	describe("bounds", function()
		it("spans the room from the floor to the given height", function()
			local min, max = OfficeLayoutUtils.bounds(ROOM, 12)
			expect(min).to.equal(Vector3.new(0, 0, 0))
			expect(max).to.equal(Vector3.new(20, 12, 10))
		end)
	end)

	describe("route", function()
		it("lists Harlow's patrol points in walking order", function()
			expect(#LAYOUT.route).to.equal(7)
			expect(OfficeLayoutUtils.marker(LAYOUT, LAYOUT.route[1]).kind).to.equal("patrol")
			expect(OfficeLayoutUtils.marker(LAYOUT, LAYOUT.rest).room).to.equal("breakRoom")
		end)
	end)
```

Add to `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.spec.luau` (top level, after `describe("checkCapacity", ...)`):

```lua
	describe("checkRoute", function()
		local function routed()
			local layout = fixture()
			table.insert(layout.markers, { id = "b.patrol.1", room = "b", kind = "patrol", x = 25, z = 5 })
			table.insert(layout.markers, { id = "b.patrol.2", room = "b", kind = "patrol", x = 35, z = 5 })
			table.insert(layout.markers, { id = "b.patrol.3", room = "b", kind = "patrol", x = 35, z = 15 })
			table.insert(layout.markers, { id = "b.rest.1", room = "b", kind = "rest", x = 25, z = 15 })
			layout.route = { "b.patrol.1", "b.patrol.2", "b.patrol.3" }
			layout.rest = "b.rest.1"
			return layout
		end

		it("accepts the authored office's route", function()
			local ok, reason = OfficeLayoutRules.checkRoute(OfficeLayoutConstants.LAYOUT)
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
		end)

		it("accepts a small valid route", function()
			expect(OfficeLayoutRules.checkRoute(routed())).to.equal(true)
		end)

		it("refuses a route that is too short", function()
			local layout = routed()
			layout.route = { "b.patrol.1", "b.patrol.2" }
			local ok, reason = OfficeLayoutRules.checkRoute(layout)
			expect(ok).to.equal(false)
			expect(string.find(reason, "route", 1, true) ~= nil).to.equal(true)
		end)

		it("refuses a route point that is not a patrol marker", function()
			local layout = routed()
			layout.route[2] = "b.pile.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('route point "b.pile.1" is not a patrol marker')
		end)

		it("refuses a route point in the safe start room", function()
			local layout = routed()
			table.insert(layout.markers, { id = "a.patrol.1", room = "a", kind = "patrol", x = 10, z = 10 })
			layout.route[3] = "a.patrol.1"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('route point "a.patrol.1" is in the safe start room')
		end)

		it("refuses a missing rest point", function()
			local layout = routed()
			layout.rest = "b.rest.9"
			local _, reason = OfficeLayoutRules.checkRoute(layout)
			expect(reason).to.equal('rest point "b.rest.9" is not a rest marker')
		end)
	end)
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the new cases fail (`lightPoints`, `bounds`, `checkRoute`, `LAYOUT.route` missing).

- [ ] **Step 3: Types.** In `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`:
  - `export type MarkerKind = "pile" | "item" | "desk" | "locker" | "spawn" | "patrol" | "rest"` (add a comment: `-- patrol: a point on Mr. Harlow's route; rest: where he takes his break (M2).`).
  - In `export type Layout`, after `truck: Truck,` add:
    ```lua
    	-- Mr. Harlow's patrol route: patrol marker ids in walking order (a loop), and his rest marker (M2).
    	route: { string },
    	rest: string,
    ```

- [ ] **Step 4: Constants.** In `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`, inside the frozen table after `CLOCK_COLOR = ...,` add:

```lua
	-- M2: a ceiling light about every LIGHT_SPACING studs in each room (Harlow's tells flicker them).
	LIGHT_SPACING = 15,
	LIGHT_SIZE = Vector3.new(3, 0.3, 1.2),
	LIGHT_COLOR = Color3.fromRGB(235, 240, 255),
	LIGHT_RANGE = 16,
	LIGHT_BRIGHTNESS = 1.2,
	-- M2: the invisible volume over the loading bay that Harlow's paths never enter.
	SAFE_ZONE_NAME = "SafeZone",
	-- M2: Harlow's route needs at least this many points.
	ROUTE_MIN = 3,
```

- [ ] **Step 5: The authored route.** In `src/ServerScriptService/Features/Office/Data/OfficeLayoutConstants.luau`:
  - After the archive markers (before `local LAYOUT`), add:
    ```lua
    -- Mr. Harlow's patrol points (none in the loading bay: it is the safe zone) and where he takes his break.
    -- Kept clear of desks and lockers so each is on the navmesh.
    add("lobby", "patrol", { { 12, 42 } })
    add("breakRoom", "patrol", { { 16, 74 } })
    add("manager", "patrol", { { 38, 76 } })
    add("server", "patrol", { { 76, 72 } })
    add("open", "patrol", { { 90, 40 }, { 56, 32 } })
    add("archive", "patrol", { { 116, 14 } })
    add("breakRoom", "rest", { { 24, 82 } })
    ```
  - In `LAYOUT`, after `truck = ...,` add:
    ```lua
    	-- Walked as a loop from a random point in a random direction (Occupant rolls both each shift).
    	route = {
    		"lobby.patrol.1",
    		"breakRoom.patrol.1",
    		"manager.patrol.1",
    		"server.patrol.1",
    		"open.patrol.1",
    		"archive.patrol.1",
    		"open.patrol.2",
    	},
    	rest = "breakRoom.rest.1",
    ```
  - Header comment: add `M2: Harlow's seven-point patrol route and his rest point in the break room.`

- [ ] **Step 6: Utils.** In `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau`, before `return OfficeLayoutUtils`:

```lua
--[=[
	Ceiling-light spots for a room ({ x, z }, office-local): an even grid of about `spacing` studs, at least one,
	each in the middle of its cell.
]=]
function OfficeLayoutUtils.lightPoints(room: Room, spacing: number): { { number } }
	local width = room.maxX - room.minX
	local depth = room.maxZ - room.minZ
	local across = math.max(1, math.floor(width / spacing))
	local deep = math.max(1, math.floor(depth / spacing))
	local points: { { number } } = {}
	for column = 1, across do
		for row = 1, deep do
			table.insert(points, {
				room.minX + width * (column - 0.5) / across,
				room.minZ + depth * (row - 0.5) / deep,
			})
		end
	end
	return points
end

--[=[
	The room's box, office-local: (min, max) from the floor to `height`.
]=]
function OfficeLayoutUtils.bounds(room: Room, height: number): (Vector3, Vector3)
	return Vector3.new(room.minX, 0, room.minZ), Vector3.new(room.maxX, height, room.maxZ)
end
```

(The bay is 40 × 30: 2 × 2 spots at x 10 / 30, z 7.5 / 22.5, listed column by column, so `points[4]` is (30, 22.5).)

- [ ] **Step 7: Rules.** In `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau`, before `return OfficeLayoutRules`:

```lua
--[=[
	Whether Mr. Harlow can patrol this layout (M2): at least ROUTE_MIN route points, each a patrol marker
	outside the start room (the loading bay is his no-go safe zone), and a rest marker outside it too.
]=]
function OfficeLayoutRules.checkRoute(layout: Layout): (boolean, string?)
	local byId: { [string]: OfficeTypes.Marker } = {}
	for _, marker in layout.markers do
		byId[marker.id] = marker
	end
	if #layout.route < OfficeConstants.ROUTE_MIN then
		return false, `the patrol route has {#layout.route} points; it needs {OfficeConstants.ROUTE_MIN}`
	end
	for _, id in layout.route do
		local marker = byId[id]
		if marker == nil or marker.kind ~= "patrol" then
			return false, `route point "{id}" is not a patrol marker`
		end
		if marker.room == layout.startRoom then
			return false, `route point "{id}" is in the safe start room`
		end
	end
	local rest = byId[layout.rest]
	if rest == nil or rest.kind ~= "rest" then
		return false, `rest point "{layout.rest}" is not a rest marker`
	end
	if rest.room == layout.startRoom then
		return false, `rest point "{layout.rest}" is in the safe start room`
	end
	return true, nil
end
```

Header comment: add `\`checkRoute\` (M2) says whether Harlow's patrol route and rest point are usable.`

- [ ] **Step 8: Build.** In `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau`:
  - Require: `local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)`.
  - Inside the rooms loop, after the walls loop, add:
    ```lua
    		for _, point in OfficeLayoutUtils.lightPoints(room, OfficeConstants.LIGHT_SPACING) do
    			local size = OfficeConstants.LIGHT_SIZE
    			local fixture = block(
    				"Light",
    				size,
    				origin * CFrame.new(point[1], height - size.Y / 2, point[2]),
    				OfficeConstants.LIGHT_COLOR,
    				roomFolder
    			)
    			fixture.Material = Enum.Material.Neon
    			fixture.CanCollide = false
    			fixture.CanQuery = false
    			local light = Instance.new("PointLight")
    			light.Range = OfficeConstants.LIGHT_RANGE
    			light.Brightness = OfficeConstants.LIGHT_BRIGHTNESS
    			light.Color = OfficeConstants.LIGHT_COLOR
    			light.Parent = fixture
    			CollectionService:AddTag(fixture, OccupantConstants.LIGHT_TAG)
    		end
    ```
  - After the furniture loop, before `model.Parent = Workspace`, add:
    ```lua
    	-- The loading bay is Harlow's no-go zone: a volume his paths cost math.huge (his kind's pathCosts).
    	local start = OfficeLayoutUtils.room(layout, layout.startRoom)
    	if start ~= nil then
    		local min, max = OfficeLayoutUtils.bounds(start, height)
    		local zone = block(
    			OfficeConstants.SAFE_ZONE_NAME,
    			max - min,
    			origin * CFrame.new((min + max) / 2),
    			OfficeConstants.WALL_COLOR,
    			model
    		)
    		zone.Transparency = 1
    		zone.CanCollide = false
    		zone.CanQuery = false
    		zone.CanTouch = false
    		zone.CastShadow = false
    		local modifier = Instance.new("PathfindingModifier")
    		modifier.Label = OccupantConstants.SAFE_ZONE_LABEL
    		modifier.PassThrough = false
    		modifier.Parent = zone
    	end
    ```
  - Header comment: add `M2: ceiling lights (tagged for Harlow's tells) and the loading bay's PathfindingModifier volume (Harlow never paths into it).`

- [ ] **Step 9: Service.** In `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`:
  - After the `floorAt` function add:
    ```lua
    -- Harlow's route in the world, in walking order, and his rest point (M2).
    local routePoints: { Vector3 } = {}
    for _, id in LAYOUT.route do
    	local marker = markerById[id]
    	if marker ~= nil then
    		table.insert(routePoints, floorAt(marker).Position)
    	end
    end
    local restMarker = markerById[LAYOUT.rest]
    ```
  - In `start`, after the `checkCapacity` assert:
    ```lua
    		local routeOk, routeReason = OfficeLayoutRules.checkRoute(LAYOUT)
    		assert(routeOk, `office layout has no usable patrol route: {routeReason or "?"}`)
    ```
  - In `export type OfficeServiceServer` add:
    ```lua
    	route: (self: OfficeServiceServer) -> { Vector3 },
    	restPoint: (self: OfficeServiceServer) -> Vector3,
    	safeZone: (self: OfficeServiceServer) -> (Vector3, Vector3),
    ```
  - In the literal, after `container`:
    ```lua
    	--[=[
    		Harlow's patrol points in the world, in walking order (a loop).
    	]=]
    	route = function(_self)
    		return table.clone(routePoints)
    	end,

    	--[=[
    		Where Harlow takes his break (the break room).
    	]=]
    	restPoint = function(_self)
    		assert(restMarker ~= nil, "OfficeServiceServer:restPoint: the layout has no rest marker")
    		return floorAt(restMarker).Position
    	end,

    	--[=[
    		The loading bay in the world: its min and max corners, floor to wall top (Harlow's safe zone).
    	]=]
    	safeZone = function(_self)
    		local start = OfficeLayoutUtils.room(LAYOUT, LAYOUT.startRoom)
    		assert(start ~= nil, "OfficeServiceServer:safeZone: the layout has no start room")
    		local min, max = OfficeLayoutUtils.bounds(start, OfficeConstants.WALL_HEIGHT)
    		return OfficeConstants.ORIGIN:PointToWorldSpace(min), OfficeConstants.ORIGIN:PointToWorldSpace(max)
    	end,
    ```
  - In `getState` add `routePoints = #routePoints,`.
  - Header comment: add `M2: Harlow's route, rest point and the safe loading bay (\`route\`, \`restPoint\`, \`safeZone\`).`
  - If luau-lsp does not narrow `restMarker` after the `assert`, use `if restMarker == nil then error("...") end` instead (same behaviour, no cast).

- [ ] **Step 10: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 11: Controller: Studio TestEZ.** Expected: OfficeLayoutUtils and OfficeLayoutRules pass (incl. "the authored office is valid", "has the markers the spawn roll needs" and the route cases); the spawn-roll specs are unchanged and pass (patrol and rest markers are not rolled on).

- [ ] **Step 12: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local O = require(game.ServerScriptService.Features.Office.OfficeServiceServer)
local PathfindingService = game:GetService("PathfindingService")
task.wait(3)
local route = O:route()
print("ROUTE", #route, route[1], "REST", O:restPoint())
local min, max = O:safeZone()
print("ZONE", min, max)
local path = PathfindingService:CreatePath({ AgentCanJump = true, Costs = { SafeZone = math.huge } })
local lobby = route[1]
local bay = (min + max) / 2 * Vector3.new(1, 0, 1)
local ok1 = pcall(function() path:ComputeAsync(lobby, bay) end)
print("LOBBY->BAY", ok1, path.Status)
local ok2 = pcall(function() path:ComputeAsync(lobby, route[5]) end)
print("LOBBY->OPEN", ok2, path.Status)
local entered = false
for _, waypoint in path:GetWaypoints() do
	local p = waypoint.Position
	if p.X > min.X and p.X < max.X and p.Z > min.Z and p.Z < max.Z then entered = true end
end
print("THROUGH BAY", entered)
```
Checklist:
1. Each room has neon light fixtures near the wall tops (the bay 4, the open office 16); `#game.CollectionService:GetTagged("OfficeLight")` is about 40.
2. `workspace.CleanupCrewOffice.SafeZone` exists, invisible, walk-through, with a `PathfindingModifier` labelled `SafeZone`.
3. Output: `ROUTE 7 ...`, a rest point in the break room (x ≈ 1024, z ≈ 82), the zone from (1000, 0, 0) to (1040, 12, 30).
4. `LOBBY->BAY` is not `Success` (expected `NoPath`: the goal sits inside a `math.huge` region); `LOBBY->OPEN true Enum.PathStatus.Success`; `THROUGH BAY false`. If `LOBBY->BAY` does come back `Success`, report it with the waypoints: it is informational (the brain never targets a point in the bay, Task 6 spec), but the M0 mover's "stand when unreachable" assumption would then need a look.
5. Walking every doorway still works for the player (the volume does not collide).

- [ ] **Step 13: Commit**

```bash
git commit -m "feat(office): Harlow's route and rest point, ceiling lights, safe-zone volume"
python3 scripts/python/module_map.py --check
```

---
### Task 9: Harlow on the server (rig, brain wiring, senses, hearing, tuning, cues)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Occupant/Net/OccupantEvents.luau`
- Create: `src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau`
- Create: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (base, verified in source): `NpcRegistry.register(kind, NpcDefInput)` / `.has(kind)`; `NpcServiceServer:setBrain(kind, brain?)`, `:setTuning(npc, { walkSpeed?, runSpeed? }) -> boolean`, `:despawn(npc)`; a model tagged `NpcConstants.TAG` with `NpcConstants.KIND_ATTRIBUTE` is adopted by NpcServiceServer's tag observer (network owner = server, `DeathServiceServer:track`); the brain is `(def: NpcDef, context: BrainContext, npc: Model) -> Intent?`, run inside the think loop (must not yield), `context.now = os.clock()`, `def` carries `setTuning`'s overrides; `goTo` sets `WalkSpeed = run and def.runSpeed or def.walkSpeed`; `attack` runs `onAttack`'s handler within `def.attackRange` (default handler: `DeathServiceServer:damage(humanoid, def.attackDamage)`, a no-op at 0); a kind with `pathCosts` stands still when a goal is unreachable. `DeathServiceServer:isDead(player)`; `RoundServiceServer:participants() -> { Player }`; `Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)` (may yield); `RaycastParams.RespectCanCollide`.
- Consumes (Tasks 1–8): `ShiftServiceServer.changed` / `:getShift()` (`phase`, `stage`, `tier`); `NoiseServiceServer.made` / `:setHearingScale` / `:getHearingScale`; `NoiseRules.hears`; `OfficeServiceServer:container() / route() / restPoint() / safeZone()`; `OccupantBrainRules.newMind / step / lookYaw`; `OccupantTuningFormulas.tuning`; `OccupantTellRules.cueFor / lineFor`; `OccupantConstants.*`; `OccupantTypes.*`.
- Produces (OccupantEvents): `packets.CatchCam` (server → one client, `ByteNet.cframe`: the camera CFrame looking at his face), `packets.LightsOut` (server → all, `ByteNet.vec3`: where), `packets.Flicker` (server → all, `ByteNet.bool`: a tier rose).
- Produces (OccupantRigSystem): `Rig = { model: Model, humanoid: Humanoid, root: BasePart, head: BasePart, cue: TextLabel, speech: TextLabel, bubble: BillboardGui }`; `build(at: CFrame, parent: Instance) -> Rig` (yields); `setCue(rig, text: string)`; `say(rig, line: string)`; `setMode(rig, mode: OccupantTypes.Mode, target: number?)`.
- Produces (OccupantServiceServer): the `harlow` NPC kind and brain; `getHarlow() -> Model?`; `getMind() -> OccupantTypes.Mind?` (a copy). Task 10 adds the catch.

**Why the line-of-sight rays live in the brain closure (decided):** the base brain must not yield, and `Workspace:Raycast` is synchronous; the closure casts at most one ray per crew member (≤ 4) per 0.25 s think, which is what the base's own hostile perception already costs (`NpcBehaviourSystem.lineOfSight`), and hands the verdicts to the pure rules as `Glimpse.clear`. A separate perception loop would need its own schedule and could hand the brain a stale view. The kind is registered `attitude = "passive"` so the base's own perception never runs as well. Rays use `RespectCanCollide = true`, so carried items (Carry makes them non-colliding), piles, lights and the safe-zone volume never block his view; walls do.

- [ ] **Step 1: Packets** `src/ReplicatedStorage/Shared/Features/Occupant/Net/OccupantEvents.luau`:

```lua
--!strict
--[=[
	OccupantEvents: Mr. Harlow's ByteNet packets (server → clients only): the caught player's camera snap to his
	face, the lights dying around a catch, and every light flickering when a pressure tier rises. Everything
	else (his "?" / "!", his speech bubble, his mode for the heartbeat) rides replicated Instances and
	attributes.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at OccupantServiceServer load).

	@class OccupantEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "OccupantEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local OccupantEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- To the caught player: where their camera looks (at his face) for SNAP_SECONDS.
			CatchCam = ByteNet.definePacket({
				value = ByteNet.cframe,
				reliabilityType = "reliable",
			}),
			-- To everyone: the lights within LIGHTS_OUT_RADIUS of this point die for LIGHTS_OUT_SECONDS.
			LightsOut = ByteNet.definePacket({
				value = ByteNet.vec3,
				reliabilityType = "reliable",
			}),
			-- To everyone: a pressure tier rose; every light flickers for TIER_FLICKER_SECONDS.
			Flicker = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return OccupantEvents
```

- [ ] **Step 2: Rig** `src/ServerScriptService/Features/Occupant/Systems/OccupantRigSystem.luau`:

```lua
--!strict
--[=[
	OccupantRigSystem: Mr. Harlow's body and his placeholder tells (Cleanup Crew spec §7: "a tall, too-thin
	suited R15 rig built from a HumanoidDescription in code, so no place art is needed"). `build` makes the rig
	(Players:CreateHumanoidModelFromDescription, which may yield), removes any Animate script (the base Npc
	plays his idle / walk / run), adds a cue billboard ("?" / "!") and a plain speech bubble over his head, tags
	him Occupant (the client's tells find him by it) and, last, Npc with his NpcKind so NpcServiceServer adopts
	him. M3 replaces the cues and bubble with the final face, voice and art.

	Spec-exempt shell (Instances).

	@class OccupantRigSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	cue: TextLabel,
	speech: TextLabel,
	bubble: BillboardGui,
}

local CUE_COLOR = Color3.fromRGB(255, 220, 90)
local SPOTTED_COLOR = Color3.fromRGB(255, 70, 60)

-- The latest line per rig, so an older line's timer never hides a newer one. Weak keys.
local speechTokens: { [Model]: number } = {}
setmetatable(speechTokens, { __mode = "k" })

local function billboard(name: string, size: UDim2, offset: Vector3, parent: Instance): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = CUE_COLOR
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

local OccupantRigSystem = {}

--[=[
	Builds Harlow at `at` under `parent` and returns his rig. Yields (the rig is generated from a description).
]=]
function OccupantRigSystem.build(at: CFrame, parent: Instance): Rig
	local body = OccupantConstants.BODY
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = body.height
	description.WidthScale = body.width
	description.DepthScale = body.depth
	description.HeadScale = body.head
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeadColor = body.skin
	description.TorsoColor = body.shirt
	description.LeftArmColor = body.suit
	description.RightArmColor = body.suit
	description.LeftLegColor = body.suit
	description.RightLegColor = body.suit
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	description:Destroy()
	model.Name = OccupantConstants.DISPLAY_NAME
	local animate = model:FindFirstChild("Animate")
	if animate ~= nil then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if humanoid == nil or root == nil or not root:IsA("BasePart") or head == nil or not head:IsA("BasePart") then
		model:Destroy()
		error("OccupantRigSystem: the generated rig has no Humanoid, HumanoidRootPart or Head")
	end
	humanoid.DisplayName = OccupantConstants.DISPLAY_NAME
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local _, cue = billboard(OccupantConstants.CUE_NAME, UDim2.fromScale(2.5, 2.5), Vector3.new(0, 2.5, 0), head)
	local bubble, speech =
		billboard(OccupantConstants.SPEECH_NAME, UDim2.fromOffset(260, 56), Vector3.new(0, 4.5, 0), head)
	bubble.Enabled = false
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(20, 20, 24)
	speech.TextStrokeTransparency = 1
	speech.Font = Enum.Font.SourceSansSemibold
	model:SetAttribute(OccupantConstants.MODE_ATTRIBUTE, "patrol")
	model:SetAttribute(OccupantConstants.TARGET_ATTRIBUTE, 0)
	model:SetAttribute(NpcConstants.KIND_ATTRIBUTE, OccupantConstants.NPC_KIND)
	model:PivotTo(at)
	CollectionService:AddTag(model, OccupantConstants.TAG)
	model.Parent = parent
	-- Last: NpcServiceServer adopts a tagged model with a registered kind.
	CollectionService:AddTag(model, NpcConstants.TAG)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		cue = cue,
		speech = speech,
		bubble = bubble,
	}
end

--[=[
	The text over his head ("?", "!" or nothing).
]=]
function OccupantRigSystem.setCue(rig: Rig, text: string)
	rig.cue.Text = text
	rig.cue.TextColor3 = if text == "!" then SPOTTED_COLOR else CUE_COLOR
end

--[=[
	Shows a line in his speech bubble for SPEECH_SECONDS (a newer line replaces it).
]=]
function OccupantRigSystem.say(rig: Rig, line: string)
	local token = (speechTokens[rig.model] or 0) + 1
	speechTokens[rig.model] = token
	rig.speech.Text = line
	rig.bubble.Enabled = true
	task.delay(OccupantConstants.SPEECH_SECONDS, function()
		if speechTokens[rig.model] == token and rig.bubble.Parent ~= nil then
			rig.bubble.Enabled = false
		end
	end)
end

--[=[
	Publishes his mode and target as attributes (the client's heartbeat reads them).
]=]
function OccupantRigSystem.setMode(rig: Rig, mode: OccupantTypes.Mode, target: number?)
	rig.model:SetAttribute(OccupantConstants.MODE_ATTRIBUTE, mode)
	rig.model:SetAttribute(OccupantConstants.TARGET_ATTRIBUTE, target or 0)
end

return OccupantRigSystem
```

If luau-lsp does not narrow `humanoid` / `root` / `head` after the `error` branch, bind typed locals inside an `if ... then` success branch instead (same behaviour, no cast).

- [ ] **Step 3: Service** `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`:

```lua
--!strict
--[=[
	OccupantServiceServer: Mr. Harlow (Cleanup Crew spec §4 "Mr. Harlow", §6.2 "Occupant"). He is the `harlow`
	NPC kind (NpcServiceServer) driven by this service's brain:

	- Life: when a shift starts running he is built (OccupantRigSystem) on a random point of the Office's
	  patrol route and walks the loop in a random direction; when it stops he is despawned. He lives in the
	  shift's container, so a reset removes him too.
	- Senses, gathered in the brain each think and handed to the pure OccupantBrainRules: each crew member's
	  position with one synchronous line-of-sight ray (Workspace:Raycast never yields; at most one ray per
	  crew member per 0.25 s think, the base's own cost), the last noise he heard (NoiseServiceServer through
	  NoiseRules and the hearing scale), the shift's break, the route, the rest point and the safe loading bay.
	- Pacing: OccupantTuningFormulas turns the shift's tier and the crew size into his speeds (setTuning) and
	  his hearing scale (NoiseServiceServer:setHearingScale), refreshed every TUNING_INTERVAL; a tier rise
	  flickers every light (OccupantEvents.Flicker).
	- Tells: his mode and target as attributes (the client's heartbeat), a "?" / "!" cue and a speech bubble
	  (OccupantRigSystem); while he looks around he turns his root through a sweep. Placeholders; M3 replaces
	  them.

	Spec-exempt shell (Instances, raycasts, Players, signals); the decisions are the specced OccupantBrainRules,
	OccupantTuningFormulas and OccupantTellRules.

	@class OccupantServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantEvents = require(OccupantShared.Net.OccupantEvents)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local NpcRegistry = require(ServerScriptService.Features.Npc.Data.NpcRegistry)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local OccupantBrainRules = require(OccupantServer.Rules.OccupantBrainRules)
local OccupantTuningFormulas = require(OccupantServer.Utils.OccupantTuningFormulas)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)

-- Registered at load so setBrain / onAttack (start) find the kind.
if not NpcRegistry.has(OccupantConstants.NPC_KIND) then
	NpcRegistry.register(OccupantConstants.NPC_KIND, {
		-- The brain below does all of his seeing; "passive" keeps the base's own perception off.
		attitude = "passive",
		walkSpeed = OccupantConstants.PATROL_SPEED,
		runSpeed = OccupantConstants.CHASE_SPEED,
		sightRange = OccupantConstants.SIGHT_RANGE,
		sightAngle = OccupantConstants.SIGHT_ANGLE,
		wanderRadius = 0,
		attackRange = OccupantConstants.CATCH_RANGE,
		-- His attack is the catch (onAttack, Task 10); 0 keeps the base's default damage harmless.
		attackDamage = 0,
		attackCooldown = OccupantConstants.CATCH_COOLDOWN,
		animations = { idle = "idle", walk = "walk", run = "run" },
		pathCosts = { [OccupantConstants.SAFE_ZONE_LABEL] = math.huge },
	})
end

local log = Logger.new("OccupantServiceServer")

local rig: OccupantRigSystem.Rig? = nil
local mind: OccupantTypes.Mind? = nil
local spawning = false
local shift: ShiftTypes.ShiftState? = nil
local route: { Vector3 } = {}
local restPoint = Vector3.zero
local zone: OccupantTypes.Zone = { min = Vector3.zero, max = Vector3.zero }
local pendingNoise: Vector3? = nil
local lookBase: number? = nil
local tuningElapsed = 0
local rng = Random.new()
local counters = { spawned = 0, heard = 0, chases = 0, catches = 0 }
local stoppers: { () -> () } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

local function resting(): boolean
	local state = shift
	return state ~= nil and state.stage == "break"
end

-- Speeds and hearing for the current tier and crew size.
local function applyTuning()
	local current = rig
	local state = shift
	if current == nil or state == nil then
		return
	end
	local tuning = OccupantTuningFormulas.tuning(state.tier, #RoundServiceServer:participants())
	NpcServiceServer:setTuning(current.model, { walkSpeed = tuning.walkSpeed, runSpeed = tuning.runSpeed })
	NoiseServiceServer:setHearingScale(tuning.hearing)
end

-- His mode on the model, the cue over his head, and a line for a cue.
local function show(current: OccupantRigSystem.Rig, nextMind: OccupantTypes.Mind, cue: OccupantTypes.Cue?)
	OccupantRigSystem.setMode(current, nextMind.mode, nextMind.target)
	OccupantRigSystem.setCue(current, OccupantTellRules.cueFor(nextMind.mode))
	local line = OccupantTellRules.lineFor(cue)
	if line ~= nil then
		OccupantRigSystem.say(current, line)
	end
end

-- Every crew member he could see this think, each with one line-of-sight ray from his head.
local function glimpses(current: OccupantRigSystem.Rig, sightRange: number): { OccupantTypes.Glimpse }
	local list: { OccupantTypes.Glimpse } = {}
	local origin = current.head.Position
	local exclude: { Instance } = { current.model }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	-- Carried items, piles, lights and the safe-zone volume do not collide, so they never hide anyone.
	params.RespectCanCollide = true
	for _, player in RoundServiceServer:participants() do
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		if root ~= nil and humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player) then
			local offset = root.Position - origin
			local clear = offset.Magnitude <= sightRange and Workspace:Raycast(origin, offset, params) == nil
			table.insert(list, { userId = player.UserId, position = root.Position, clear = clear })
		end
	end
	return list
end

-- The `harlow` brain: senses → OccupantBrainRules.step → intent. Never yields.
local function brain(def: NpcTypes.NpcDef, context: NpcTypes.BrainContext, npc: Model): NpcTypes.Intent?
	local current = rig
	local before = mind
	if current == nil or before == nil or npc ~= current.model then
		return { kind = "idle" }
	end
	local senses: OccupantTypes.Senses = {
		position = context.position,
		look = current.root.CFrame.LookVector,
		now = context.now,
		sightRange = def.sightRange,
		sightAngle = def.sightAngle,
		players = glimpses(current, def.sightRange),
		heard = pendingNoise,
		resting = resting(),
		route = route,
		restPoint = restPoint,
		zone = zone,
	}
	pendingNoise = nil
	local result = OccupantBrainRules.step(before, senses)
	mind = result.mind
	if result.mind.mode ~= before.mode or result.mind.target ~= before.target or result.cue ~= nil then
		if result.mind.mode == "chase" and before.mode ~= "chase" then
			counters.chases += 1
		end
		show(current, result.mind, result.cue)
	end
	return result.intent
end
```

The same file continues:

```lua
-- A noise: remembered for the next think if he hears it (not while resting or standing over a catch).
local function onNoise(noise: NoiseTypes.NoiseEvent)
	local current = rig
	local currentMind = mind
	if current == nil or currentMind == nil or currentMind.mode == "rest" or currentMind.mode == "catch" then
		return
	end
	local scale = NoiseServiceServer:getHearingScale()
	if NoiseRules.hears(current.root.Position, noise.position, noise.radius, scale) then
		pendingNoise = noise.position
		counters.heard += 1
	end
end

local function despawn()
	local current = rig
	rig = nil
	mind = nil
	pendingNoise = nil
	lookBase = nil
	if current ~= nil and current.model.Parent ~= nil then
		NpcServiceServer:despawn(current.model)
	end
end

-- Builds Harlow for the running shift (yields while the rig is generated).
local function spawnHarlow()
	if rig ~= nil or spawning then
		return
	end
	local parent = OfficeServiceServer:container()
	local points = OfficeServiceServer:route()
	if parent == nil or #points == 0 then
		log:warn("no shift container or patrol route: Harlow stays home")
		return
	end
	spawning = true
	local start = rng:NextInteger(1, #points)
	local direction = if rng:NextNumber() < 0.5 then -1 else 1
	local at = CFrame.new(points[start] + Vector3.new(0, OccupantConstants.SPAWN_HEIGHT, 0))
	local ok, built = pcall(OccupantRigSystem.build, at, parent)
	spawning = false
	if not ok then
		log:error(`Harlow's rig failed to build: {tostring(built)}`)
		return
	end
	local state = shift
	if state == nil or state.phase ~= "running" or parent.Parent == nil then
		built.model:Destroy()
		return
	end
	route = points
	restPoint = OfficeServiceServer:restPoint()
	local min, max = OfficeServiceServer:safeZone()
	zone = { min = min, max = max }
	local fresh = OccupantBrainRules.newMind(start, direction, os.clock())
	rig = built
	mind = fresh
	pendingNoise = nil
	built.model.Destroying:Connect(function()
		if rig == built then
			rig = nil
			mind = nil
		end
	end)
	counters.spawned += 1
	show(built, fresh, nil)
	applyTuning()
	log:info(`Harlow clocks in at route point {start}, walking {if direction > 0 then "forward" else "backward"}`)
end

local function onShift(state: ShiftTypes.ShiftState)
	local previous = shift
	shift = state
	if state.phase ~= "running" then
		despawn()
		return
	end
	if previous ~= nil and previous.phase == "running" and state.tier > previous.tier then
		OccupantEvents.packets.Flicker.sendToAll(true)
	end
	if rig == nil then
		spawnHarlow()
	end
	applyTuning()
end

-- Per frame: turning while he looks around; tuning every TUNING_INTERVAL.
local function onHeartbeat(deltaTime: number)
	tuningElapsed += deltaTime
	if tuningElapsed >= OccupantConstants.TUNING_INTERVAL then
		tuningElapsed = 0
		applyTuning()
	end
	local current = rig
	local currentMind = mind
	local arrivedAt = if currentMind ~= nil then currentMind.arrivedAt else nil
	local looking = currentMind ~= nil and (currentMind.mode == "investigate" or currentMind.mode == "search")
	if current == nil or not looking or arrivedAt == nil then
		lookBase = nil
		return
	end
	local base = lookBase
	if base == nil then
		local look = current.root.CFrame.LookVector
		base = math.atan2(-look.X, -look.Z)
		lookBase = base
	end
	local yaw = base + OccupantBrainRules.lookYaw(os.clock() - arrivedAt)
	current.root.CFrame = CFrame.new(current.root.Position) * CFrame.Angles(0, yaw, 0)
end

export type OccupantServiceServer = {
	dependencies: { string },
	start: (self: OccupantServiceServer) -> (),
	stop: (self: OccupantServiceServer) -> (),
	getState: (self: OccupantServiceServer) -> { [string]: any },
	getHarlow: (self: OccupantServiceServer) -> Model?,
	getMind: (self: OccupantServiceServer) -> OccupantTypes.Mind?,
}

local OccupantServiceServer: OccupantServiceServer = {
	dependencies = {
		"NpcServiceServer",
		"ShiftServiceServer",
		"OfficeServiceServer",
		"NoiseServiceServer",
		"DeathServiceServer",
		"RoundServiceServer",
	},

	--[=[
		Gives the kind its brain, follows the shift, listens for noise and turns him while he looks around.
	]=]
	start = function(_self)
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, brain)
		local changed = ShiftServiceServer.changed:Connect(onShift)
		local noises = NoiseServiceServer.made:Connect(onNoise)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		table.insert(stoppers, function()
			changed:Disconnect()
			noises:Disconnect()
			heartbeat:Disconnect()
		end)
		-- Deferred: building the rig yields, and start must not.
		task.defer(onShift, ShiftServiceServer:getShift())
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, nil)
		despawn()
	end,

	getHarlow = function(_self)
		local current = rig
		return if current ~= nil then current.model else nil
	end,

	getMind = function(_self)
		local current = mind
		return if current ~= nil then table.clone(current) else nil
	end,

	getState = function(_self)
		local current = mind
		return {
			present = rig ~= nil,
			mode = if current ~= nil then current.mode else nil,
			target = if current ~= nil then current.target else nil,
			routeIndex = if current ~= nil then current.routeIndex else nil,
			routeStep = if current ~= nil then current.routeStep else nil,
			hearing = NoiseServiceServer:getHearingScale(),
			counters = table.clone(counters),
		}
	end,
}

return OccupantServiceServer
```

The file is the two code blocks above, in order (split only for reading).

- [ ] **Step 4: Exemptions.** Add under `-- Cleanup Crew: Occupant`:

```lua
	["ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Occupant.Systems.OccupantRigSystem"] = "Instance builder (HumanoidDescription rig, billboards)",
	["ServerScriptService.Features.Occupant.OccupantServiceServer"] = "NPC/raycast/signal shell (brain, tuning and tell decisions are specced in OccupantBrainRules, OccupantTuningFormulas, OccupantTellRules)",
```

- [ ] **Step 5: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 6: Controller: Studio TestEZ** (regression). Expected: everything passes.

- [ ] **Step 7: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local O = require(game.ServerScriptService.Features.Occupant.OccupantServiceServer)
local N = require(game.ServerScriptService.Features.Noise.NoiseServiceServer)
local S = require(game.ServerScriptService.Features.Shift.ShiftServiceServer)
local R = require(game.ServerScriptService.Features.Round.RoundServiceServer)
_G.O, _G.N, _G.S, _G.R = O, N, S, R
task.spawn(function()
	local last = nil
	while true do
		task.wait(0.25)
		local state = O:getState()
		local line = `{tostring(state.mode)} target={tostring(state.target)} route={tostring(state.routeIndex)}`
		if line ~= last then
			last = line
			local harlow = O:getHarlow()
			local speed = if harlow ~= nil then harlow:FindFirstChildOfClass("Humanoid").WalkSpeed else 0
			print("HARLOW", line, "speed", speed)
		end
	end
end)
```
Checklist (solo: chase speed 14, hearing ×0.75):
1. When the shift runs, a tall, thin, dark-suited "Mr. Harlow" appears on a route point outside the loading bay (Output: "Harlow clocks in at route point N, walking forward/backward") and walks from point to point at speed 10, animated (walk), through doorways, never through the bay.
2. Vacuum a pile within about 30 studs of him (40 × 0.75): he shows "?" and the bubble "Per my last email…", walks to the pile (`HARLOW investigate`), stands and turns left/right for ~4 s, says "*sigh*", the "?" clears, and he resumes his route.
3. Step into his view within 60 studs: "!" and "Those are COMPANY ASSETS.", `HARLOW chase target=<your UserId> speed 14`; he runs at you. Empty-handed you outrun him (16).
4. Break line of sight behind a wall: `HARLOW search`; he runs to where he last saw you, looks around ~6 s, sighs, patrols.
5. Let him reach you: he stops next to you and nothing happens (no damage; the catch is Task 10).
6. Get chased and run into the loading bay: he stops outside the doorway (`search` at the last point outside), never steps in; vacuum or drop something inside the bay: no "?".
7. Wait for 2:00 into the shift: `speed 11` on patrol; `_G.O:getState().hearing` ≈ 0.9 (1.2 × 0.75). Meet the quota (`_G.R:addTeam("clearance", 345)` + Load): bubble "Fifteen minutes. Union rules.", he walks to the break room and ignores you even face to face; 30 s later he patrols again. In overtime his patrol speed is 12.
8. Clock out: at results he is gone (`present = false`). Another shift: a new Harlow at a (usually different) route point. Mid-chase `_G.S:resetShift()`: he disappears with the shift and a fresh one appears next shift; no errors.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(occupant): Harlow patrols, hears, investigates, chases and searches"
python3 scripts/python/module_map.py --check
```

---
### Task 10: The catch (snap, lights out, ragdoll launch, spectate, "Rehired.")

**Files:**
- Create: `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`
- Create: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (base, verified in source): `NpcServiceServer:onAttack(kind, handler: (npc: Model, target: Player) -> ())` (called inside the think's `pcall`, so it must not yield; the base only calls it within `def.attackRange` and once per `attackCooldown`); `DeathServiceServer:kill(humanoid, cause, { launch = Vector3 })` (ragdoll, then the launch velocity on every part, server-owned), `:configure({ respawnDelay })`, `:isDead`; on death Carry force-drops the hands item (`"death"`) and Cargo scatters the pockets (M1); Death's spectate follows living teammates (`DeathServiceClient`, priority 50); Shift's spawn resolver puts the respawn in the loading bay (M1); `ToastServiceServer:send`; client `CameraServiceClient:pushMode({ kind = "fixed", cframe, fov? }, priority) -> number`, `:removeMode(token)`, `:addTrauma(amount)`; `VfxServiceClient:requestScreen({ saturation?, contrast?, tint? }) -> number`, `:releaseScreen(token)`; `Observers.observeCharacter(fn(player, character) -> cleanup?)`.
- Consumes (Tasks 2, 6, 7, 9): `ShiftServiceServer:noteCatch(player)`; `OccupantCatchRules.canCatch / launch`; `OccupantBrainRules.caught`; `OccupantEvents.packets.CatchCam / LightsOut`; `OccupantRigSystem.Rig / say`; the service's `rig`, `mind`, `shift`, `zone`, `show`, `rootOf`, `humanoidOf`, `counters`.
- Produces (OccupantCatchSystem): `Hooks = { stillOn: () -> boolean, onCaught: (player: Player) -> () }`; `begin(rig, player, hooks) -> boolean` (false when the player is already being caught or has no living character); `isCatching(userId) -> boolean`; `clear() -> ()`.
- Produces (OccupantServiceClient): no API; on `CatchCam` the local camera is held on his face for `SNAP_SECONDS` with a red-tinted screen and a shake.

- [ ] **Step 1: Catch system** `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`:

```lua
--!strict
--[=[
	OccupantCatchSystem: the catch sequence (Cleanup Crew spec §4 "Catch"). `begin` turns Harlow to face the
	player, freezes them (their root anchored), points their camera at his face (OccupantEvents.CatchCam),
	kills the lights around him for everyone (OccupantEvents.LightsOut) and has him say "You're FIRED!". After
	SNAP_SECONDS the player is released and killed with a launch (base Death: ragdoll + velocity), away from him
	and up; Carry drops their hands item and Cargo scatters their pockets as they die (M1), Death's spectate and
	respawn delay give the ~8 s of watching, and `hooks.onCaught` does the rest (Shift's catch count, toasts).
	If the shift ended meanwhile (`hooks.stillOn`), the player is just released.

	Called from the NPC think (onAttack), so `begin` itself never yields: the wait is a task.delay.

	Spec-exempt shell (Instances, ByteNet, Death); the decisions are the specced OccupantCatchRules.

	@class OccupantCatchSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local OccupantCatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantCatchRules)
local OccupantRigSystem = require(ServerScriptService.Features.Occupant.Systems.OccupantRigSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)

export type Hooks = {
	-- Whether the catch may still finish (a shift is still running and Harlow is still there).
	stillOn: () -> boolean,
	onCaught: (player: Player) -> (),
}

-- How far in front of his face the caught player's camera sits.
local FACE_DISTANCE = 2.5

-- UserIds whose catch is running.
local catching: { [number]: boolean } = {}

local OccupantCatchSystem = {}

function OccupantCatchSystem.isCatching(userId: number): boolean
	return catching[userId] == true
end

--[=[
	Starts catching `player`. False when they are already being caught or have no living character.
]=]
function OccupantCatchSystem.begin(rig: OccupantRigSystem.Rig, player: Player, hooks: Hooks): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if catching[player.UserId] or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if found == nil or not found:IsA("BasePart") then
		return false
	end
	local root: BasePart = found
	local userId = player.UserId
	catching[userId] = true

	local harlow = rig.root
	harlow.CFrame =
		CFrame.lookAt(harlow.Position, Vector3.new(root.Position.X, harlow.Position.Y, root.Position.Z))
	root.Anchored = true
	local face = rig.head.Position
	local eye = face + harlow.CFrame.LookVector * FACE_DISTANCE
	OccupantEvents.packets.CatchCam.sendTo(CFrame.lookAt(eye, face), player)
	OccupantEvents.packets.LightsOut.sendToAll(harlow.Position)
	OccupantRigSystem.say(rig, OccupantConstants.LINES.caught)

	task.delay(OccupantConstants.SNAP_SECONDS, function()
		catching[userId] = nil
		if root.Parent ~= nil then
			root.Anchored = false
		end
		if not hooks.stillOn() or humanoid.Parent == nil or humanoid.Health <= 0 then
			return
		end
		local velocity = OccupantCatchRules.launch(
			harlow.Position,
			root.Position,
			OccupantConstants.LAUNCH_SPEED,
			OccupantConstants.LAUNCH_UP
		)
		DeathServiceServer:kill(humanoid, "caught", { launch = velocity })
		hooks.onCaught(player)
	end)
	return true
end

--[=[
	Forgets every running catch (the service stopping). Their delayed steps still release the players.
]=]
function OccupantCatchSystem.clear()
	table.clear(catching)
end

return OccupantCatchSystem
```

If luau-lsp does not narrow `humanoid` after the first guard, add `if humanoid == nil then return false end` on its own line (no cast).

- [ ] **Step 2: Wire the catch into the service.** In `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`:
  1. Requires: add `local Observers = require(ReplicatedStorage.Packages.Observers)`, `local OccupantCatchRules = require(OccupantServer.Rules.OccupantCatchRules)`, `local OccupantCatchSystem = require(OccupantServer.Systems.OccupantCatchSystem)`, `local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)`.
  2. Module state: add `local rehire: { [number]: boolean } = {}` after `counters`.
  3. In `glimpses`, extend the condition to skip a player whose catch is running:
     `if root ~= nil and humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player) and not OccupantCatchSystem.isCatching(player.UserId) then`
  4. After `onNoise`, add:
     ```lua
     local catchHooks: OccupantCatchSystem.Hooks = {
     	stillOn = function(): boolean
     		local state = shift
     		return rig ~= nil and state ~= nil and state.phase == "running"
     	end,
     	onCaught = function(player: Player)
     		rehire[player.UserId] = true
     		ShiftServiceServer:noteCatch(player)
     		ToastServiceServer:send("all", {
     			text = `{player.DisplayName} was caught by {OccupantConstants.DISPLAY_NAME}.`,
     			duration = 4,
     		})
     	end,
     }

     -- The kind's attack is the catch: re-checked on the server (OccupantCatchRules), then the sequence.
     local function onCatch(npc: Model, player: Player)
     	local current = rig
     	local before = mind
     	local state = shift
     	if current == nil or before == nil or state == nil or npc ~= current.model then
     		return
     	end
     	local root = rootOf(player)
     	local humanoid = humanoidOf(player)
     	local now = os.clock()
     	local graceUntil = before.grace[player.UserId]
     	local ok, reason = OccupantCatchRules.canCatch({
     		distance = if root ~= nil then (root.Position - current.root.Position).Magnitude else math.huge,
     		position = if root ~= nil then root.Position else current.root.Position,
     		alive = humanoid ~= nil and humanoid.Health > 0 and not DeathServiceServer:isDead(player),
     		catching = OccupantCatchSystem.isCatching(player.UserId),
     		inGrace = graceUntil ~= nil and now < graceUntil,
     		resting = state.stage == "break",
     		zone = zone,
     	})
     	if not ok then
     		log:debug(`catch of {player.Name} refused: {reason or "?"}`)
     		return
     	end
     	if not OccupantCatchSystem.begin(current, player, catchHooks) then
     		return
     	end
     	local nextMind = OccupantBrainRules.caught(before, player.UserId, now)
     	mind = nextMind
     	counters.catches += 1
     	-- The catch line comes from OccupantCatchSystem; this clears the "!" and publishes the mode.
     	show(current, nextMind, nil)
     end
     ```
  5. In `start`, after `setBrain`, add:
     ```lua
     		NpcServiceServer:onAttack(OccupantConstants.NPC_KIND, onCatch)
     		-- ~8 s of spectating before the respawn (spec §4); Shift's resolver respawns in the loading bay.
     		DeathServiceServer:configure({ respawnDelay = OccupantConstants.SPECTATE_SECONDS })
     		table.insert(
     			stoppers,
     			Observers.observeCharacter(function(player: Player, _character: Model)
     				if rehire[player.UserId] then
     					rehire[player.UserId] = nil
     					ToastServiceServer:send(player, { text = OccupantConstants.REHIRED_TEXT, duration = 3 })
     				end
     				return nil
     			end)
     		)
     		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
     			rehire[player.UserId] = nil
     		end)
     		table.insert(stoppers, function()
     			leaving:Disconnect()
     		end)
     ```
  6. In `stop`, after the stoppers loop: `OccupantCatchSystem.clear()` and `table.clear(rehire)`.
  7. Add `"ToastServiceServer"` to `dependencies`.
  8. Header comment: add `- Catch: the kind's attack (onAttack) → OccupantCatchRules → OccupantCatchSystem: camera snap, lights out, ragdoll launch; ~8 s spectating (Death's respawn delay); "Rehired." on the respawn in the loading bay; the catch counts in Shift's review.` and add OccupantCatchRules to the specced list.
  9. SpecRoots: extend the service's exemption reason to `... OccupantBrainRules, OccupantCatchRules, OccupantTuningFormulas, OccupantTellRules)`.

  Check the file stays ≤ 400 code lines (expected ~330).

- [ ] **Step 3: Client service** `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`:

```lua
--!strict
--[=[
	OccupantServiceClient: Mr. Harlow on the client. The catch (Cleanup Crew spec §4 "Catch" step 1): on
	`CatchCam` the camera is held on his face for SNAP_SECONDS (a fixed camera mode above Death's spectate), with
	a shake and a red, drained screen; then Death's spectate takes over. The stretched-grin face and the
	distorted sting are M3. Task 11 adds the light and heartbeat tells (OccupantTellSystem).

	Spec-exempt shell (Camera, Vfx, ByteNet).

	@class OccupantServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantEvents = require(ReplicatedStorage.Shared.Features.Occupant.Net.OccupantEvents)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

local stoppers: { () -> () } = {}
local snaps = 0

local function snap(cframe: CFrame)
	snaps += 1
	local token = CameraServiceClient:pushMode(
		{ kind = "fixed", cframe = cframe, fov = OccupantConstants.CATCH_FOV },
		OccupantConstants.CAMERA_PRIORITY
	)
	CameraServiceClient:addTrauma(OccupantConstants.CATCH_TRAUMA)
	local screen = VfxServiceClient:requestScreen({ saturation = -0.7, contrast = 0.3, tint = OccupantConstants.CATCH_TINT })
	task.delay(OccupantConstants.SNAP_SECONDS, function()
		CameraServiceClient:removeMode(token)
		VfxServiceClient:releaseScreen(screen)
	end)
end

export type OccupantServiceClient = {
	dependencies: { string },
	start: (self: OccupantServiceClient) -> (),
	stop: (self: OccupantServiceClient) -> (),
	getState: (self: OccupantServiceClient) -> { [string]: any },
}

local OccupantServiceClient: OccupantServiceClient = {
	dependencies = { "CameraServiceClient", "VfxServiceClient" },

	start = function(_self)
		table.insert(
			stoppers,
			OccupantEvents.packets.CatchCam.listen(function(cframe: CFrame)
				snap(cframe)
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	getState = function(_self)
		return { snaps = snaps }
	end,
}

return OccupantServiceClient
```

- [ ] **Step 4: Exemptions.** Add under `-- Cleanup Crew: Occupant`:

```lua
	["ServerScriptService.Features.Occupant.Systems.OccupantCatchSystem"] = "Instance/ByteNet/Death shell (catch decisions and the launch are specced in OccupantCatchRules)",
	["ReplicatedStorage.Client.Features.Occupant.OccupantServiceClient"] = "Camera/Vfx/ByteNet shell (tell decisions are specced in OccupantTellRules)",
```

- [ ] **Step 5: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 6: Controller: Studio TestEZ** (regression). Expected: everything passes.

- [ ] **Step 7: Controller: Studio verification** (Play Solo, `RunTests = false`). Inject a temporary server Script:

```lua
local O = require(game.ServerScriptService.Features.Occupant.OccupantServiceServer)
local S = require(game.ServerScriptService.Features.Shift.ShiftServiceServer)
local N = require(game.ServerScriptService.Features.Noise.NoiseServiceServer)
_G.O, _G.S = O, S
N.made:Connect(function(e) print("NOISE", e.source, e.radius) end)
task.spawn(function()
	local last = nil
	while true do
		task.wait(0.25)
		local state = O:getState()
		local line = `{tostring(state.mode)} target={tostring(state.target)} catches={state.counters.catches}`
		if line ~= last then
			last = line
			print("HARLOW", line)
		end
	end
end)
```
Checklist:
1. Let Harlow catch you empty-handed outside the bay: you freeze, the camera snaps to his face (red, desaturated, shaking) for about 0.6 s, the bubble reads "You're FIRED!"; then you are thrown away from him as a ragdoll; toast "<your name> was caught by Mr. Harlow."
2. Solo, spectate has nobody to watch (the camera stays on your body); after ~8 s you respawn in the loading bay with the toast "Rehired.".
3. Get caught holding the water jug with a plaque and a stapler pocketed: the jug drops where you were caught with one `drop 70` noise and one puddle; the plaque and stapler appear on the floor around that spot; none of them twice; `pocket1` / `pocket2` are nil after respawn.
4. Harlow stands still ~1.5 s after the catch, then walks to his next route point. Walk out of the bay right after respawning and stand in his view within 10 s of the catch: no "!" (grace); after the 10 s he chases again.
5. Stand just inside the bay doorway with him chasing: he stops outside and never catches you; `_G.O:getState().counters.catches` does not grow.
6. Reset during a catch: start being caught, and in the same moment run `_G.S:resetShift()` from the command bar: you are released (not killed), no "caught" toast, the next shift starts normally.
7. Clock out after one catch: the review's last line is "Caught by Mr. Harlow: 1".
8. During Harlow's break (quota met), walk right up to him: no catch.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(occupant): the catch: snap, lights out, ragdoll launch, spectate and rehire"
python3 scripts/python/module_map.py --check
```

---
### Task 11: Harlow's tells on the client (flicker, lights out, tier flicker, heartbeat)

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantTellSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `OccupantTellRules.flicker / heartbeat / pulse` (Task 7); `OccupantConstants.TAG / LIGHT_TAG / MODE_ATTRIBUTE / TARGET_ATTRIBUTE / FLICKER_RADIUS / LIGHTS_OUT_RADIUS / LIGHTS_OUT_SECONDS / TIER_FLICKER_SECONDS / TELL_INTERVAL / HEARTBEAT_TINT`; `OccupantEvents.packets.LightsOut / Flicker` (Task 9); the office's `OfficeLight` parts (neon fixture + PointLight, Task 8); `VfxServiceClient:requestScreen / updateScreen / releaseScreen`.
- Produces (OccupantTellSystem, client module-level): `start() -> ()`, `stop() -> ()`, `lightsOut(position: Vector3, now: number) -> ()`, `flickerAll(now: number) -> ()`.

Lights are changed client-side only (a client-made change to a server part stays on that client): the tells are each player's own view, and nothing authoritative depends on them.

- [ ] **Step 1: Tell system** `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantTellSystem.luau`:

```lua
--!strict
--[=[
	OccupantTellSystem: Mr. Harlow's tells on this client (Cleanup Crew spec §4 "Tells", §7 "Tier up: lights
	flicker"). Every TELL_INTERVAL:
	- each office light (tag OfficeLight) within FLICKER_RADIUS of him flickers (OccupantTellRules.flicker);
	  for TIER_FLICKER_SECONDS after a tier rise every light flickers; for LIGHTS_OUT_SECONDS after a catch the
	  lights within LIGHTS_OUT_RADIUS of it are dark;
	- while he is within HEARTBEAT_RANGE and not chasing you (OccupantTellRules.heartbeat), the screen pulses
	  red with the beat (OccupantTellRules.pulse), faster the closer he is. Placeholder for the heartbeat sound
	  (M3).
	A light is "off" when its neon turns to plastic and its PointLight is disabled. Client-local changes only.

	Spec-exempt shell (Instances, Vfx); the decisions are the specced OccupantTellRules.

	@class OccupantTellSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTellRules = require(ReplicatedStorage.Shared.Features.Occupant.Rules.OccupantTellRules)
local VfxServiceClient = require(ReplicatedStorage.Client.Features.Vfx.VfxServiceClient)

local connection: RBXScriptConnection? = nil
-- Each light's state as this client last set it (weak keys: lights go with the office).
local lit: { [BasePart]: boolean } = {}
setmetatable(lit, { __mode = "k" })
local outAt: Vector3? = nil
local outUntil = 0
local flickerUntil = 0
local screenToken: number? = nil
local beatStarted = 0

local function setLit(light: BasePart, on: boolean)
	if lit[light] == on then
		return
	end
	lit[light] = on
	light.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local point = light:FindFirstChildOfClass("PointLight")
	if point ~= nil then
		point.Enabled = on
	end
end

-- A stable per-light seed so lights near him flicker out of step.
local function seedOf(light: BasePart): number
	local position = light.Position
	return position.X * 0.137 + position.Z * 0.071 + 0.5
end

local function harlowRoot(): BasePart?
	for _, model in CollectionService:GetTagged(OccupantConstants.TAG) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

local function updateLights(now: number, harlow: BasePart?)
	local out = outAt
	local darkAround = if out ~= nil and now < outUntil then out else nil
	local everywhere = now < flickerUntil
	for _, instance in CollectionService:GetTagged(OccupantConstants.LIGHT_TAG) do
		if instance:IsA("BasePart") then
			local seed = seedOf(instance)
			local on = true
			if everywhere then
				on = OccupantTellRules.flicker(0, now, seed)
			end
			if on and harlow ~= nil then
				on = OccupantTellRules.flicker((instance.Position - harlow.Position).Magnitude, now, seed)
			end
			if darkAround ~= nil and (instance.Position - darkAround).Magnitude <= OccupantConstants.LIGHTS_OUT_RADIUS then
				on = false
			end
			setLit(instance, on)
		end
	end
end

local function stopBeat()
	local token = screenToken
	if token ~= nil then
		VfxServiceClient:releaseScreen(token)
		screenToken = nil
	end
end

local function updateHeartbeat(now: number, harlow: BasePart?)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if harlow == nil or root == nil or not root:IsA("BasePart") then
		stopBeat()
		return
	end
	local model = harlow.Parent
	local mode = if model ~= nil then model:GetAttribute(OccupantConstants.MODE_ATTRIBUTE) else nil
	local target = if model ~= nil then model:GetAttribute(OccupantConstants.TARGET_ATTRIBUTE) else nil
	local distance = (root.Position - harlow.Position).Magnitude
	local beating = OccupantTellRules.heartbeat(
		distance,
		if type(mode) == "string" then mode else nil,
		target == Players.LocalPlayer.UserId
	)
	if not beating then
		stopBeat()
		return
	end
	local token = screenToken
	if token == nil then
		beatStarted = now
		token = VfxServiceClient:requestScreen({})
		screenToken = token
	end
	local strength = OccupantTellRules.pulse(now - beatStarted, distance)
	local white = Color3.new(1, 1, 1)
	VfxServiceClient:updateScreen(token, {
		tint = white:Lerp(OccupantConstants.HEARTBEAT_TINT, strength),
		saturation = -0.25 * strength,
	})
end

local OccupantTellSystem = {}

function OccupantTellSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < OccupantConstants.TELL_INTERVAL then
			return
		end
		elapsed = 0
		local now = os.clock()
		local harlow = harlowRoot()
		updateLights(now, harlow)
		updateHeartbeat(now, harlow)
	end)
end

function OccupantTellSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
	stopBeat()
	for light in lit do
		setLit(light, true)
	end
end

--[=[
	A catch at `position`: the lights around it die for LIGHTS_OUT_SECONDS.
]=]
function OccupantTellSystem.lightsOut(position: Vector3, now: number)
	outAt = position
	outUntil = now + OccupantConstants.LIGHTS_OUT_SECONDS
end

--[=[
	A pressure tier rose: every light flickers for TIER_FLICKER_SECONDS.
]=]
function OccupantTellSystem.flickerAll(now: number)
	flickerUntil = now + OccupantConstants.TIER_FLICKER_SECONDS
end

return OccupantTellSystem
```

- [ ] **Step 2: Route the packets.** In `src/ReplicatedStorage/Client/Features/Occupant/OccupantServiceClient.luau`:
  - Require: `local OccupantTellSystem = require(ReplicatedStorage.Client.Features.Occupant.Systems.OccupantTellSystem)`.
  - In `start`, after the `CatchCam` listener:
    ```lua
    		table.insert(
    			stoppers,
    			OccupantEvents.packets.LightsOut.listen(function(position: Vector3)
    				OccupantTellSystem.lightsOut(position, os.clock())
    			end)
    		)
    		table.insert(
    			stoppers,
    			OccupantEvents.packets.Flicker.listen(function(_rose: boolean)
    				OccupantTellSystem.flickerAll(os.clock())
    			end)
    		)
    		OccupantTellSystem.start()
    		table.insert(stoppers, OccupantTellSystem.stop)
    ```
  - Header comment: replace "Task 11 adds the light and heartbeat tells (OccupantTellSystem)." with "The light and heartbeat tells run in OccupantTellSystem (lights out on a catch, every light flickering on a tier rise)."

- [ ] **Step 3: Exemption.** Add under `-- Cleanup Crew: Occupant`:

```lua
	["ReplicatedStorage.Client.Features.Occupant.Systems.OccupantTellSystem"] = "Instance/Vfx shell (flicker, heartbeat and pulse decisions are specced in OccupantTellRules)",
```

- [ ] **Step 4: Module map, format and gate** (Global Constraints order). Expected: `==> All checks passed.`

- [ ] **Step 5: Controller: Studio TestEZ** (regression). Expected: everything passes.

- [ ] **Step 6: Controller: Studio verification** (Play Solo, `RunTests = false`). Checklist:
1. Follow Harlow at a distance: the ceiling lights within about 20 studs of him flicker (mostly on, blinking off), lights further away stay steady; the flicker moves with him.
2. Stand within ~40 studs of him out of his sight: the screen pulses red with a beat; get closer and it beats faster; step into his view so he chases you: the pulse stops; get away and lose him: it resumes while he is within 40 studs, stops beyond.
3. Get caught: the lights around him go dark for ~2.5 s (with the camera snap), then come back.
4. At 2:00 into a shift every light in the office flickers for ~1.5 s together with the "You hear Harlow pacing faster…" toast. The same happens when overtime starts.
5. After the shift ends (results), no light is left dark and the screen has no tint.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat(occupant): light flicker, lights out, tier flicker and heartbeat tells"
python3 scripts/python/module_map.py --check
```

---
### Task 12: Full-shift playtest, docs, PR update

**Files:**
- Modify: `docs/project-structure.md` (the game-features note)
- Modify: `docs/ROADMAP.md` (the "Games on this base" row)

**Interfaces:** none new.

- [ ] **Step 1: Feature names note.** In `docs/project-structure.md`, replace M1's line `Cleanup Crew (branch \`game/cleanup-crew\`) adds Cargo, Office, Shift and Vacuum.` with:

```markdown
Cleanup Crew (branch `game/cleanup-crew`) adds Cargo, Noise, Occupant, Office, Shift and Vacuum.
```

- [ ] **Step 2: ROADMAP row.** In `docs/ROADMAP.md`, in the "Games on this base" table, append to the Cleanup Crew row's "Built so far" cell (after the M1 sentence, before "Spec: ..."):

```markdown
M2 Mr. Harlow: the `harlow` NPC kind on the base brain/goTo/tuning/pathCosts hooks with a specced pure brain (patrol, investigate, chase, search, break, catch, grace, safe loading bay), one noise stream with a hearing rule and ripple rings (Noise), the catch (camera snap, lights out, ragdoll launch, spectate, "Rehired."), pressure tiers, quota → break → overtime warning → overtime (salvage ×1.5), rattle pulses, the jug's slippery puddle, swap/unpocket, placeholder tells (Occupant).
```

- [ ] **Step 3: Gate**

```bash
python3 scripts/python/module_map.py --check
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.`

- [ ] **Step 4: Commit**

```bash
git add docs/ROADMAP.md docs/project-structure.md
git commit -m "docs: record Cleanup Crew M2 on the roadmap"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 5: Controller: full TestEZ run in Studio** (`RunTests = true`). Expected: every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 6: Controller: full-shift playtest** (Play Solo, `RunTests = false`, no helper scripts; a second client is not available, so the multi-player cases stay for the M4/M5 playtests). Checklist:
1. Arrival → loading bay; Harlow clocks in somewhere in the office; lights steady except near him.
2. Vacuum, haul and bank as in M1; vacuum noise draws him ("?", "Per my last email…") to investigate and give up ("*sigh*").
3. A chase from sight ("!", "Those are COMPANY ASSETS."): escape empty-handed; escape into the loading bay (he never enters); get caught once (snap, lights out, "You're FIRED!", launch, spectate ~8 s, "Rehired." in the bay).
4. Tier at 2:00 and 4:00: all lights flicker + "You hear Harlow pacing faster…"; his patrol visibly quicker.
5. Meet the quota: "QUOTA MET…" + HUD break countdown; Harlow walks to the break room and ignores you; warning "Overtime in 0:30, salvage ×1.5"; overtime toast and HUD line; bank salvage at ×1.5.
6. Clock out (or let the timer end): results show the totals and "Caught by Mr. Harlow: 1"; Harlow is gone; Another shift starts cleanly with a fresh Harlow.
7. Drop the water jug and run through the puddle (slip); carry a bottle bag (rattle ripples); swap a pocket item with X.
8. Server and client Output: no errors or warnings from Occupant, Noise, Cargo, Shift or Office across the whole run.

- [ ] **Step 7: Controller: update the open PR's description (never merge).** The branch's PR (opened for M1 by its Task 12) stays the PR for M2. Push, then append an M2 section to its body:

```bash
git push origin game/cleanup-crew
gh pr view --json number,body -q .body > /tmp/cc-pr-body.md
cat >> /tmp/cc-pr-body.md <<'EOF'

## M2: Mr. Harlow

Milestone M2 of docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (plan: docs/superpowers/plans/2026-10-10-m2-cleanup-crew-harlow.md).

- Occupant: the `harlow` NPC kind on the M0 brain/goTo/setTuning/pathCosts/onAttack hooks, a tall thin suited R15 rig built from a HumanoidDescription; every decision in the specced pure OccupantBrainRules (patrol a random start/direction loop, investigate noise ~4 s, chase on sight 60 studs / 100° / line of sight, search ~6 s, break in the break room, grace 10 s, never into the loading bay via a SafeZone PathfindingModifier).
- Catch: server-decided (OccupantCatchRules), camera snap to his face 0.6 s, lights out, ragdoll launch through base Death, ~8 s spectate, "Rehired." in the loading bay; counted in the review.
- Noise: one stream from Vacuum and Cargo (vacuum 40, drops by weight, splash 70, rattle 12 every 2 s, search 12), the hearing rule (radius × tier ×1.2 per tier × solo 0.75) and the ripple ring.
- Shift: pressure tiers at 2:00 / 4:00 (patrol +1, hearing ×1.2), solo chase −1, quota → break 30 s → "Overtime in 0:30, salvage ×1.5" → overtime at the top tier, ×1.5 salvage in overtime.
- Cargo: the jug's slippery puddle, rattle pulses, swap/unpocket (X); pockets moved into CargoPocketSystem.
- Tells are functional placeholders (billboard ?/!, speech bubble, red heartbeat pulse, light flicker); final scare, SFX, music, voice and animations are M3.

Open questions for the developer: see the M2 plan's list (overtime-warning behaviour, compounding hearing, tier reference time, scatter point, swap semantics, slip feel).

Verified: .superpowers/sdd/gate.sh green; TestEZ green in Studio; Studio checklists in Tasks 2-12 (solo).
EOF
gh pr edit --body-file /tmp/cc-pr-body.md
```
Use the scratchpad instead of `/tmp` if the controller's environment says so. Do not merge: the developer reviews. When `base/game-hooks` merges to main, rebase `game/cleanup-crew` onto main and retarget the PR (AGENTS.md: stacked branches).

---

## Next plans

- M3 (same branch): feel. Reference board → Figma → **developer approval** → UI built; Harlow's final face, sting, gibberish voice, footsteps and muttering, chase music, heartbeat sound; sticky-note and stamp toast styles; overtime red lighting and atmosphere presets; Kimodo lurch / look-around / grab-and-throw animations replacing the base locomotion ids and the root-turn look-around.
- Queue base PR before M4; M4 Depot; M5 phone pass (incl. a touch Swap button), analytics, A/B switch, publish.
