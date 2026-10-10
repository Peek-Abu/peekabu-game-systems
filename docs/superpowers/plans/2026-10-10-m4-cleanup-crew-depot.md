# M4: Cleanup Crew, Depot, Queues and the Return Trip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a depot lobby in front of the shift: a code-built garage with three truck queue pads, tonight's contract board and a result board; a party that departs a truck travels (Queue base: reserved server live, local move in Studio) to the office, gets a drive card and an arrival card, plays the shift as "the crew", and on **Back to depot** rides the return trip home carrying its performance review, which is pinned on the result board for each returning player. Real PlaceIds stay placeholders, so the whole loop plays through the Studio local fallback in one server; a walkthrough tells the developer how to create the shift place, fill in the PlaceIds, publish both places and test with two accounts.

**Architecture:** One new game feature, **Depot** (spec §6.2's proposed name), and a Shift extension. Every decision is a pure, specced module: the depot layout check (`DepotLayoutRules`), contract selection and the words on the board and cards (`DepotContractUtils`), the result card's teleport wire format, the depot's trust boundary (`ShiftCardUtils`), crew membership and the "on its way home" window (`ShiftCrewTracker`), and the client's card queue (`DepotStore`). Instance, Players and Queue wiring lives in spec-exempt shells: `DepotBuildSystem` (graybox, pads tagged `QueuePad`, billboards), `DepotServiceServer` (registers the place-role table at load, builds the garage only where the depot role runs, sends the travel cards, pins result cards), `ShiftTripSystem` (Queue `arrived` / `joinedLate` / `returned`, the return trip, Round eligibility and the spawn resolver) and `DepotServiceClient` (the travel-card HUD widget). `ShiftServiceServer` changes by a few lines: a shift starts only for a crew, only the crew votes, and Back to depot calls the trip.

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax packets, Charm, React (react-lua) + ReactCharm + UI Labs, TestEZ (Studio, `RunTests = true`), SignalTyped, CollectionService, the base **Queue** feature (`QueueServiceServer`, `QueueRegistry`, `QueuePlaceRules`, `QueueConstants`, `QueueTypes`), base Round (`configure { eligible }`), Death (`setSpawnPoint`), Toast, HudRegistry.

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (M4 row of §9; §3 steps 1–3 and 7; §5 places and roles; §6.2 Depot row; §6.4 teleport data rule; §6.5 stranger joins, teleport fails, last player out, "the depot result card comes through the return teleport"). Queue API: `docs/superpowers/plans/2026-10-10-queue-base.md` (the Interfaces blocks are the real API). Builds on the M1 plan (`docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md`) and the M2 plan (`overnight-handoff/2026-10-10-m2-cleanup-crew-harlow.md` → `docs/superpowers/plans/`).

**Branch / PR:** `game/cleanup-crew`, after M2's commits and after the controller has merged `base/queue` into it locally. Same PR #3 (the controller updates its description in Task 6; never merge).

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts without a commented justification and developer sign-off (none are planned).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`). `*.story` files need neither.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder; UI tree modules PascalCase (`ViewModel` suffix for view models, `use<Thing>` hooks). Requires use full addresses; a feature folder required from 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count).
- After adding/moving modules: `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- **Rojo safety:** the developer may be connected to `rojo serve`. Implementers never run `rokit install`, `wally install`, `install.sh`, `wally-package-types` or `scripts/check.sh` (with or without `--skip-install`), and never start `rojo serve`; the per-task gate is `bash .superpowers/sdd/gate.sh` (lint, format, typecheck, rules, file length, module map; must end `==> All checks passed.`, the ruff line is advisory). Tests run only in Studio, by the controller: steps saying "controller: Studio TestEZ" set the Workspace attribute `RunTests = true`, Play, read Output; gameplay checks run in a fresh Play with `RunTests = false` and use a temporary server `Script` in **Workspace** and/or a client `LocalScript` in `StarterPlayer.StarterPlayerScripts` that the controller injects and deletes afterwards (the plugin VM cannot reach live services). Only a solo player is available (no second client).
- **Module-map and commit order (every task):** `git add <new and edited src files>` → `python3 scripts/python/module_map.py --write` → `git add docs/project-structure.md` → `stylua <each new or edited .luau file>` (re-`git add` them) → `bash .superpowers/sdd/gate.sh` → `git commit -m "<message as given>"` → `python3 scripts/python/module_map.py --check` (must print no FAIL). Never run `stylua src` wholesale.
- Server-authoritative: clients only send requests (Queue's Depart now, a vote); the server re-validates everything. React components never send packets (`check_pr_rules`); they read client stores. `Instance.new("ScreenGui")` is banned outside `UILayerHost` (`check_pr_rules`): on-screen UI is a HUD widget; world UI is server-built `BillboardGui`s.
- Asset-id literals only in a feature's `Data/<Feature>Assets`. **M4 uses none and uploads nothing.**
- **M4 UI is plain functional placeholder UI**: Tokens + primitives on screen, plain `BillboardGui` text in the world. The final contract board, pad, result card, drive and arrival cards wait for the developer's Figma approval (spec §7).
- **No publishing, no uploads, no real PlaceIds.** `DepotConstants.PLACE_IDS` stays `0` (Queue's placeholder) for both roles; the walkthrough (Task 6) is for the developer.
- **Spec numbers (tuning hypotheses, all in Data constants):** quota 350 clearance (trash only), salvage a separate bonus; shift 7:00; clock-out countdown 10 s; arrival countdown 5 s (`ShiftConstants.ARRIVAL_SECONDS`); a truck is a queue pad holding **1–4** players; **~15 s** countdown, reset on join; anyone aboard can Depart now (base widget); the shift server waits up to ~20 s for the expected party (Queue `ARRIVAL_TIMEOUT`); teleport fails → 3 retries with backoff, then back on the pad with a toast (Queue); depot has **3–4 trucks** (this plan: 3); depot and office geometry at different world positions (office origin x = 1000; depot origin x = −1000).

## Review Focus

1. **Forged or broken teleport data** (the result card or the contract id rides the client: wrong version, wrong types, NaN, huge or negative numbers, a crew count with missing lines, 5 000-character names, an unknown contract id) → the depot pins nothing or a clamped card, the arrival card falls back to the first contract, and no server errors. (Task 2 `ShiftCardUtils` spec "rejects a field of the wrong type", "rejects a crew count that doesn't match its lines", "clamps negative, fractional and huge numbers", "cuts a very long name"; Task 1 `DepotContractUtils` spec "falls back to the first contract…"; Task 3 Step 7 check "a forged card pins nothing".)
2. **Back to depot, but the return trip fails** (live, after Queue's retries) → no new shift starts under the crew during the 40 s window; afterwards each player still here gets one toast and the next shift starts; a member who did reach the depot (or was moved there in Studio) has left the crew. (Task 2 `ShiftCrewTracker` spec "holds the next shift while the crew is on its way home", "lets the crew work again once the window has passed, and says so once"; Task 5 checklist item 9.)
3. **A second party arrives while a crew is already here** (Studio: two trucks in one server), or the previous crew has already gone → a crew still present is added to, never replaced; a crew that has left is replaced and its "leaving" window ends. (Task 2 `ShiftCrewTracker` spec "adds a second party to a crew still here", "replaces a crew that has left the server", "ends the window when a new party replaces the crew".)
4. **A misconfigured depot layout**, above all a spawn point on or beside a truck bed (players would spawn straight into a queue), a truck whose cab leaves the floor, two trucks touching, a capacity of 0 / 5 / 2.5 → a boot error listing every problem, never a half-built depot. (Task 1 `DepotLayoutRules` spec, all cases; Task 3 Step 4 `assert`.)
5. **Who is crew decides spawns, participation and votes:** a depot bystander (or a player before departing) spawns and respawns at the depot and is never a Round participant or voter; a crew member respawns in the loading bay; on a shift-only server everybody spawns in the loading bay. (Task 2 `ShiftCrewTracker` spec "counts only crew members who are here"; Task 5 Step 7 checks 2, 3, 6b and 8e.)

---

## New modules

New feature name: **Depot** (singular, PascalCase; proposed in spec §6.2 / §11). **No new subfolder kind, no new role word and no second service.** Shift gains a `State` tracker, a `Utils` module and a `Systems` module (all existing kinds).

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Depot | shared | Data | DepotTypes | Contract, card and depot-layout shapes |
| Depot | shared | Data | DepotConstants | Role names, the place-role table (placeholder PlaceIds), contracts, card timings and texts |
| Depot | shared | Net | DepotEvents | `Card` packet (server → client): a drive or arrival card |
| Depot | server | Data | DepotLayoutConstants | The depot's world origin, authored layout, graybox sizes and colours |
| Depot | server | Rules | DepotLayoutRules | Is the depot layout buildable (trucks, boards, spawns clear of the pads)? |
| Depot | server | Utils | DepotContractUtils | Tonight's contract, resolving an untrusted contract id, board lines, drive/arrival cards |
| Depot | server | Systems | DepotBuildSystem | Builds the garage, tagged truck pads, boards and labels; pins a player's result card |
| Depot | server | (root) | DepotServiceServer | Registers roles; builds the depot where it runs; depart data; travel cards; result cards; pad labels |
| Depot | client | State | DepotStore | The travel card on screen and the cards queued behind it |
| Depot | client | (root) | DepotServiceClient | Takes `Card` packets into DepotStore; registers the card HUD widget |
| Shift | server | Utils | ShiftCardUtils | The result card: review → flat teleport payload, untrusted payload → card, card → lines |
| Shift | server | State | ShiftCrewTracker | Who the crew is, and the "on its way home" window |
| Shift | server | Systems | ShiftTripSystem | Queue wiring: crew from arrivals, late members, the return trip, eligibility and spawns |
| UI tree | client | Screens/Depot | DepotCardPanel (+ `.story`) | Presentational placeholder travel card |
| UI tree | client | Screens/Depot | DepotCard | HUD widget: shows DepotCardPanel while DepotStore has a card |

Modified: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (crew-only start and vote, Back to depot, eligibility, spawn resolver), `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (one key), `src/ServerScriptService/Core/Testing/SpecRoots.luau` (exemptions), `docs/project-structure.md`, `docs/ROADMAP.md`. Created doc: `docs/cleanup-crew-publish.md` (the publish walkthrough). Created plan copy: `docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md`.

**Not touched (M2 owns them):** Office, Occupant, Noise, Cargo, Vacuum, the Shift HUD/results components and view model, `ShiftPhaseRules`, `ShiftTypes`, `ShiftSnapshotUtils`, `ShiftResultsUtils`.

**Design decisions (verified against source):**
- **Where the roles are registered.** `QueueRegistry.register(role, placeId)` must run before any service starts (Queue reads the table in `start`, `mode()`, `runsRole()`). `DepotServiceServer` registers `DepotConstants.PLACE_IDS` at module load (the `InteractionRegistry.register`-at-load precedent in `ShiftServiceServer`); `ServerHandler` requires every service before `init`/`start`. Two placeholder `0`s are allowed (`QueueRegistry.register` only refuses a duplicate *real* PlaceId).
- **Studio = one server, both roles.** `QueueServiceServer:mode()` is `"local"` in Studio (and on an unknown PlaceId, which is every place until the PlaceIds are filled in). Depot builds when `runsRole("depot")`; a depart is a local move to `setArrivalPoint("shift")` (the loading bay) and fires `arrived` deferred; `returnParty` is a local move to `setArrivalPoint("depot")` and fires `returned` from Queue's tick.
- **A shift starts only for a crew.** M1's `ShiftPhaseRules.tick(state, now, present)` returns `"start"` when `present >= MIN_PLAYERS` in the lobby. M4 passes the crew count (`ShiftTripSystem:startable`) instead of `#Players:GetPlayers()`, so no rules change: a live depot server never starts a shift, a live shift server starts once the party has arrived, Studio starts when a truck departs.
- **Round participants = the crew** through `RoundServiceServer:configure({ eligible = ... })` (`RoundTypes.RoundConfig.eligible`). Round has no public "add participant", so an expected member who arrives after the run started is crew (votes, spawns in the bay, banks) but not a Round participant; `buildResults` lists crew from `ShiftTripSystem:crew()` so their work still shows (the roster keeps scores by UserId).
- **Spawns.** `DeathServiceServer:setSpawnPoint(resolver)` applies on every character, first spawn included (`DeathServiceServer.start`, `observeCharacter`). The resolver becomes `ShiftTripSystem.spawnFor`: crew → loading bay; otherwise the depot where this server runs the depot role; otherwise (a shift-only live server) the loading bay.
- **Office is not gated by role.** The live depot place also builds the (empty, static) office graybox at x = 1000; nothing spawns there because no shift starts. Gating it would edit `OfficeServiceServer.start`, which M2 rewrites; see Open question 1.
- **Pad status.** Queue's `PadSnapshot`s are keyed `pad<n>` with no link to an Instance, so the per-truck billboard counts players server-side with `QueueServiceServer:padOf(player)`; the countdown and Depart now are the base's placeholder `queuePad` HUD widget, shown to players aboard (kept on).
- **Drive card.** Sent by the server on Queue `departing`; on a live server the client is torn down by the teleport while it shows. `TeleportService:SetTeleportGui` is typed `(gui: GuiObject)` in `globalTypes.d.luau:17299` and a ScreenGui cannot be created outside `UILayerHost`, so the loading-screen version is left out (Open question 2).

---

### Task 0: Preflight

**Files:** Create: `docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md` (a copy of this plan).

- [ ] **Step 1: Confirm the branch, M2 and the merged Queue base**

```bash
git branch --show-current
git log --oneline -40
```
Expected: `game/cleanup-crew`; the log contains M2's "docs: record Cleanup Crew M2 on the roadmap" and the Queue base commits ("feat(queue): …", "docs: record the base Queue feature"). If either is missing, stop and tell the controller (the Queue merge is the controller's job).

- [ ] **Step 2: Confirm every API this plan calls** (each grep prints at least one line; if one prints nothing, stop and report which):

```bash
# Queue base (merged)
grep -n "register = \|function QueueRegistry.register\|function QueueRegistry.has" src/ServerScriptService/Features/Queue/Data/QueueRegistry.luau
grep -n "function QueuePlaceRules.isReservedServer" src/ServerScriptService/Features/Queue/Rules/QueuePlaceRules.luau
grep -n "arrived = arrived\|joinedLate = joinedLate\|returned = returned\|departing = departing" src/ServerScriptService/Features/Queue/QueueServiceServer.luau
grep -n "setDepartData = function\|setArrivalPoint = function\|configure = function\|returnParty = function\|padOf = function\|runsRole = function\|mode = function\|role = function" src/ServerScriptService/Features/Queue/QueueServiceServer.luau
grep -n "CAPACITY_ATTRIBUTE\|COUNTDOWN_ATTRIBUTE\|DESTINATION_ATTRIBUTE\|TAG = \"QueuePad\"" src/ReplicatedStorage/Shared/Features/Queue/Data/QueueConstants.luau
grep -n "export type QueuePayload\|export type ArrivalPoint\|export type DepartDataResolver" src/ReplicatedStorage/Shared/Features/Queue/Data/QueueTypes.luau
grep -n "function QueueTeleportRules.payload" src/ServerScriptService/Features/Queue/Rules/QueueTeleportRules.luau
grep -n "HUD_KEY = \"queuePad\"" src/ReplicatedStorage/Client/Features/Queue/QueueServiceClient.luau
# M2 results carry catches
grep -n "catches: number" src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau
# Shift anchors M4 edits (Task 5)
grep -n "local function presentIds" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "ShiftPhaseRules.tick(state, now(), #Players:GetPlayers())" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "if decision == \"depot\" then" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "DeathServiceServer:setSpawnPoint(function(player)" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "lateJoin = true," src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
grep -n "local function buildResults" src/ServerScriptService/Features/Shift/ShiftServiceServer.luau
# base APIs
grep -n "eligible: ((player: Player) -> boolean)?" src/ReplicatedStorage/Shared/Features/Round/Data/RoundTypes.luau
grep -n "setSpawnPoint = function\|kill = function" src/ServerScriptService/Features/Death/DeathServiceServer.luau
grep -n "spawnCFrame = function" src/ServerScriptService/Features/Office/OfficeServiceServer.luau
grep -n "function HudRegistry.register\|function HudRegistry.has" src/ReplicatedStorage/Client/UI/React/Screens/Hud/HudRegistry.luau
grep -n "function SetTeleportGui" globalTypes.d.luau
```
Record the code-line count of `ShiftServiceServer` (Task 5 must not raise it past 400):
```bash
python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; print(c.count_code_lines(open('src/ServerScriptService/Features/Shift/ShiftServiceServer.luau',encoding='utf8').read()))"
```

- [ ] **Step 3: Copy this plan into the repo** (from the path the controller handed you) to `docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md`.

- [ ] **Step 4: Baseline gate**

```bash
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.` If anything fails here, stop and report: it is not ours.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md
git commit -m "docs: plan Cleanup Crew M4 (depot, queues, return trip)"
```

---

### Task 1: Depot data, layout rules and contracts (pure)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau`
- Create: `src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau`
- Create: `src/ServerScriptService/Features/Depot/Rules/DepotLayoutRules.luau` + `DepotLayoutRules.spec.luau`
- Create: `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau` + `DepotContractUtils.spec.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (three exemptions)

**Interfaces:**
- Consumes: nothing new (pure).
- Produces (DepotTypes): `Contract = { id: string, client: string, job: string, note: string }`, `CardKind = "drive" | "arrival"`, `CardMessage = { kind: string, title: string, body: string }`, `ShownCard = { kind: CardKind, title: string, body: string, expiresAt: number }`, `Rect = { minX, minZ, maxX, maxZ: number }`, `Point = { x: number, z: number }`, `Truck = { id: string, x: number, z: number, capacity: number, countdown: number }`, `Layout = { floor: Rect, trucks: { Truck }, contractBoard: Point, resultBoard: Point, spawns: { Point } }`.
- Produces (DepotConstants): `ROLE_DEPOT = "depot"`, `ROLE_SHIFT = "shift"`, `PLACE_IDS: { [string]: number }` (both 0), `CONTRACTS: { Contract }`, `DRIVE_CARD_SECONDS = 3`, `ARRIVAL_CARD_SECONDS = 5`, `MAX_QUEUED_CARDS = 3`, `HUD_ORDER = 950`, `RESULT_BOARD_TITLE`, `RETURN_TEXT`.
- Produces (DepotLayoutConstants): `ORIGIN = CFrame.new(-1000, 0, 0)`, `MODEL_NAME = "CleanupCrewDepot"`, `LAYOUT: Layout`, sizes (`BED_SIZE`, `CAB_SIZE`, `BOARD_SIZE`, wall/floor), limits (`MARGIN`, `TRUCK_GAP`, `SPAWN_CLEARANCE`, `MIN_TRUCKS`, `MAX_TRUCKS`, `MAX_CAPACITY`, `MIN_COUNTDOWN`, `MAX_COUNTDOWN`), label sizes/offsets, colours, `SPAWN_HEIGHT`, `LABEL_INTERVAL`, `CARD_NAME = "DepotResultCard"`, `PLAYER_GUI_WAIT`.
- Produces (DepotLayoutRules): `validate(layout: Layout) -> (boolean, { string })`.
- Produces (DepotContractUtils): `tonight(contracts: { Contract }, epochSeconds: number) -> Contract`, `resolve(contracts: { Contract }, id: unknown) -> Contract`, `boardLines(contract: Contract, quota: number) -> { string }`, `driveCard(contract: Contract) -> CardMessage`, `arrivalCard(contract: Contract, quota: number) -> CardMessage`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Depot/Rules/DepotLayoutRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotLayoutRules = require(script.Parent.DepotLayoutRules)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

-- A small valid depot: three trucks along the back, boards at the front, spawns between them.
local function fixture()
	return {
		floor = { minX = 0, minZ = 0, maxX = 96, maxZ = 72 },
		trucks = {
			{ id = "t1", x = 20, z = 48, capacity = 4, countdown = 15 },
			{ id = "t2", x = 48, z = 48, capacity = 2, countdown = 10 },
			{ id = "t3", x = 76, z = 48, capacity = 1, countdown = 30 },
		},
		contractBoard = { x = 34, z = 12 },
		resultBoard = { x = 62, z = 12 },
		spawns = { { x = 40, z = 26 }, { x = 56, z = 26 } },
	}
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function()
	describe("the authored depot", function()
		it("is valid", function()
			local ok, errors = DepotLayoutRules.validate(DepotLayoutConstants.LAYOUT)
			if not ok then
				error(table.concat(errors, "\n"))
			end
			expect(ok).to.equal(true)
		end)

		it("has a placeholder-or-real whole PlaceId for both roles", function()
			for _, role in { DepotConstants.ROLE_DEPOT, DepotConstants.ROLE_SHIFT } do
				local placeId = DepotConstants.PLACE_IDS[role]
				expect(type(placeId)).to.equal("number")
				expect(placeId >= 0 and placeId == math.floor(placeId)).to.equal(true)
			end
		end)
	end)

	describe("validate", function()
		it("accepts a small valid depot", function()
			local ok, errors = DepotLayoutRules.validate(fixture())
			expect(#errors).to.equal(0)
			expect(ok).to.equal(true)
		end)

		it("refuses a floor with no area", function()
			local layout = fixture()
			layout.floor.maxX = 0
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "no area")).to.equal(true)
		end)

		it("needs three or four trucks", function()
			local layout = fixture()
			table.remove(layout.trucks)
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "2 trucks")).to.equal(true)
		end)

		it("refuses a duplicate or empty truck id", function()
			local layout = fixture()
			layout.trucks[2].id = "t1"
			layout.trucks[3].id = ""
			local _, errors = DepotLayoutRules.validate(layout)
			expect(hasError(errors, 'truck "t1" is defined twice')).to.equal(true)
			expect(hasError(errors, "a truck has no id")).to.equal(true)
		end)

		it("refuses a capacity outside 1-4 or not whole", function()
			for _, bad in { 0, 5, 2.5 } do
				local layout = fixture()
				layout.trucks[1].capacity = bad
				local ok, errors = DepotLayoutRules.validate(layout)
				expect(ok).to.equal(false)
				expect(hasError(errors, 'truck "t1": capacity')).to.equal(true)
			end
		end)

		it("refuses a countdown outside 5-60 seconds", function()
			for _, bad in { 0, 4, 61 } do
				local layout = fixture()
				layout.trucks[2].countdown = bad
				local ok, errors = DepotLayoutRules.validate(layout)
				expect(ok).to.equal(false)
				expect(hasError(errors, 'truck "t2": countdown')).to.equal(true)
			end
		end)

		it("refuses a truck whose bed or cab leaves the floor", function()
			local layout = fixture()
			layout.trucks[1].z = 66
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'truck "t1" is not inside the floor')).to.equal(true)
		end)

		it("refuses trucks parked too close together", function()
			local layout = fixture()
			layout.trucks[2].x = 30
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'trucks "t1" and "t2"')).to.equal(true)
		end)

		it("refuses a board outside the floor or standing on a truck", function()
			local layout = fixture()
			layout.contractBoard = { x = 20, z = 48 }
			layout.resultBoard = { x = 200, z = 12 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'the contract board stands on truck "t1"')).to.equal(true)
			expect(hasError(errors, "the result board is not inside the floor")).to.equal(true)
		end)

		it("refuses two boards on top of each other", function()
			local layout = fixture()
			layout.resultBoard = { x = 36, z = 12 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, "boards overlap")).to.equal(true)
		end)

		it("refuses a spawn on or beside a truck bed, so nobody spawns into a queue", function()
			local layout = fixture()
			layout.spawns[1] = { x = 20, z = 38 }
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'spawn 1 is within')).to.equal(true)
			expect(hasError(errors, 'of truck "t1"')).to.equal(true)
		end)

		it("needs a spawn, inside the floor", function()
			local none = fixture()
			none.spawns = {}
			local _, noneErrors = DepotLayoutRules.validate(none)
			expect(hasError(noneErrors, "no spawn points")).to.equal(true)
			local outside = fixture()
			outside.spawns = { { x = -5, z = 10 } }
			local _, outsideErrors = DepotLayoutRules.validate(outside)
			expect(hasError(outsideErrors, "spawn 1 is not inside the floor")).to.equal(true)
		end)

		it("lists every problem at once", function()
			local layout = fixture()
			layout.trucks[1].capacity = 9
			layout.spawns = {}
			local ok, errors = DepotLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(#errors >= 2).to.equal(true)
		end)
	end)
end
```

`src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotContractUtils = require(script.Parent.DepotContractUtils)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local CONTRACTS = {
	{ id = "a", client = "Alpha Ltd.", job = "Clear it.", note = "Quiet." },
	{ id = "b", client = "Beta Ltd.", job = "Clear more.", note = "Loud." },
	{ id = "c", client = "Gamma Ltd.", job = "Clear all.", note = "Odd." },
}
local DAY = 86400

return function()
	describe("tonight", function()
		it("keeps one contract for a whole UTC day", function()
			expect(DepotContractUtils.tonight(CONTRACTS, 0).id).to.equal("a")
			expect(DepotContractUtils.tonight(CONTRACTS, DAY - 1).id).to.equal("a")
		end)

		it("moves to the next contract each day and wraps around", function()
			expect(DepotContractUtils.tonight(CONTRACTS, DAY).id).to.equal("b")
			expect(DepotContractUtils.tonight(CONTRACTS, 2 * DAY + 5).id).to.equal("c")
			expect(DepotContractUtils.tonight(CONTRACTS, 3 * DAY).id).to.equal("a")
		end)

		it("always finds a contract in the authored list", function()
			local contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
			expect(type(contract.id)).to.equal("string")
			expect(#DepotConstants.CONTRACTS >= 1).to.equal(true)
		end)

		it("refuses an empty list", function()
			expect(function()
				DepotContractUtils.tonight({}, 0)
			end).to.throw()
		end)
	end)

	describe("resolve", function()
		it("finds a contract by id", function()
			expect(DepotContractUtils.resolve(CONTRACTS, "b").id).to.equal("b")
		end)

		it("falls back to the first contract for a missing, unknown or malformed id", function()
			expect(DepotContractUtils.resolve(CONTRACTS, nil).id).to.equal("a")
			for _, bad in { "zzz", 42, true, string.rep("b", 5000) } do
				expect(DepotContractUtils.resolve(CONTRACTS, bad).id).to.equal("a")
			end
		end)
	end)

	describe("words", function()
		it("puts the client, the job, the quota and the note on the board", function()
			local lines = DepotContractUtils.boardLines(CONTRACTS[2], 350)
			expect(lines[1]).to.equal("TONIGHT'S CONTRACT")
			expect(lines[2]).to.equal("Beta Ltd.")
			expect(lines[3]).to.equal("Clear more.")
			expect(lines[4]).to.equal("Load 350 of trash on the truck. Salvage earns a finder's fee.")
			expect(lines[5]).to.equal("Loud.")
			expect(lines[6]).to.equal("Stand in a truck bed to join a crew (1-4 players).")
		end)

		it("builds the drive card", function()
			local card = DepotContractUtils.driveCard(CONTRACTS[1])
			expect(card.kind).to.equal("drive")
			expect(card.title).to.equal("On the road")
			expect(card.body).to.equal("Heading to Alpha Ltd.")
		end)

		it("builds the arrival card", function()
			local card = DepotContractUtils.arrivalCard(CONTRACTS[3], 350)
			expect(card.kind).to.equal("arrival")
			expect(card.title).to.equal("Gamma Ltd.")
			expect(card.body).to.equal("Clear all. Clear 350 of trash. Odd.")
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error with "module not found" (`DepotLayoutRules` / `DepotContractUtils` missing).

- [ ] **Step 3: Shared data.**

`src/ReplicatedStorage/Shared/Features/Depot/Data/DepotTypes.luau`:

```lua
--!strict
--[=[
	DepotTypes: the Depot feature's shapes (Cleanup Crew spec §3 steps 1-3, §6.2 "Depot"). Layout
	coordinates are depot-local studs on the floor plane, x across, z deep, with DepotLayoutConstants.ORIGIN
	placing 0, 0 in the world. Types only (spec-exempt).

	@class DepotTypes
]=]

-- One night's job, shown on the contract board and on the arrival card. Its id rides the teleport.
export type Contract = {
	id: string,
	client: string,
	job: string,
	note: string,
}

export type CardKind = "drive" | "arrival"

-- A travel card on the wire (DepotEvents.Card). `kind` is checked on the client (DepotStore.show).
export type CardMessage = {
	kind: string,
	title: string,
	body: string,
}

-- The card on screen; `expiresAt` is os.clock() on the client.
export type ShownCard = {
	kind: CardKind,
	title: string,
	body: string,
	expiresAt: number,
}

export type Rect = {
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
}

export type Point = {
	x: number,
	z: number,
}

-- A truck: its bed (the queue pad) centred at (x, z), its cab behind it (+z). Capacity and countdown go
-- onto the pad's Queue attributes.
export type Truck = {
	id: string,
	x: number,
	z: number,
	capacity: number,
	countdown: number,
}

export type Layout = {
	floor: Rect,
	trucks: { Truck },
	contractBoard: Point,
	resultBoard: Point,
	spawns: { Point },
}

return {}
```

`src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau`:

```lua
--!strict
--[=[
	DepotConstants: the depot's names, the place-role table, tonight's contracts, and the travel cards'
	timings and texts (Cleanup Crew spec §2, §3, §5). Static data (spec-exempt).

	@class DepotConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

-- The place-role table, registered in Queue's QueueRegistry by DepotServiceServer at load. Keys are the
-- role names below. 0 is Queue's placeholder PlaceId: that role is reached by a local move (both roles in
-- one server) until its real PlaceId is filled in. See docs/cleanup-crew-publish.md.
local PLACE_IDS: { [string]: number } = {
	-- PLACEHOLDER: the depot place (the experience's start place).
	depot = 0,
	-- PLACEHOLDER: the shift place, once the developer creates it in the experience.
	shift = 0,
}

-- Tonight's job rotates by UTC day (DepotContractUtils.tonight). All are Harlow & Finch: there is one office.
local CONTRACTS: { DepotTypes.Contract } = {
	{
		id = "harlow-finch-1",
		client = "Harlow & Finch Ltd.",
		job = "Clear the office before the sale.",
		note = "The bank says the building is empty.",
	},
	{
		id = "harlow-finch-2",
		client = "Harlow & Finch Ltd.",
		job = "The bank wants every floor spotless.",
		note = "Someone reported lights on after midnight.",
	},
	{
		id = "harlow-finch-3",
		client = "Harlow & Finch Ltd.",
		job = "Final clearance before the auction.",
		note = "The manager never handed in his keys.",
	},
}

return table.freeze({
	ROLE_DEPOT = "depot",
	ROLE_SHIFT = "shift",
	PLACE_IDS = table.freeze(PLACE_IDS),
	CONTRACTS = table.freeze(CONTRACTS),
	-- How long each travel card stays up; a card that arrives while another shows waits behind it.
	DRIVE_CARD_SECONDS = 3,
	ARRIVAL_CARD_SECONDS = 5,
	MAX_QUEUED_CARDS = 3,
	-- HUD widget order: above Queue's pad widget (900), under the toasts (1000).
	HUD_ORDER = 950,
	RESULT_BOARD_TITLE = "PERFORMANCE REVIEWS",
	RETURN_TEXT = "Back at the depot. Your performance review is pinned on the board.",
})
```

- [ ] **Step 4: Server layout data.** `src/ServerScriptService/Features/Depot/Data/DepotLayoutConstants.luau`:

```lua
--!strict
--[=[
	DepotLayoutConstants: where the depot sits, its authored graybox layout and its sizes (Cleanup Crew spec
	§1 "polished feel on graybox", §3 step 1, §5). Every number is a tuning hypothesis. Static data
	(spec-exempt; LAYOUT is checked by DepotLayoutRules.spec).

	@class DepotLayoutConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

-- A closed garage: three trucks along the back wall, the boards at the front, spawns between.
local LAYOUT: DepotTypes.Layout = {
	floor = { minX = 0, minZ = 0, maxX = 96, maxZ = 72 },
	trucks = {
		{ id = "truck1", x = 20, z = 48, capacity = 4, countdown = 15 },
		{ id = "truck2", x = 48, z = 48, capacity = 4, countdown = 15 },
		{ id = "truck3", x = 76, z = 48, capacity = 4, countdown = 15 },
	},
	contractBoard = { x = 34, z = 12 },
	resultBoard = { x = 62, z = 12 },
	spawns = {
		{ x = 40, z = 26 },
		{ x = 46, z = 26 },
		{ x = 52, z = 26 },
		{ x = 58, z = 26 },
	},
}

return table.freeze({
	-- Where the depot's local 0, 0 sits in the world. The office is at x = 1000 (OfficeConstants.ORIGIN), so in
	-- Studio, where one server plays both roles, the two never meet.
	ORIGIN = CFrame.new(-1000, 0, 0),
	MODEL_NAME = "CleanupCrewDepot",
	LAYOUT = LAYOUT,
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 1,
	FLOOR_THICKNESS = 1,
	-- A truck's bed (the queue pad: low enough to step onto) and the cab behind it.
	BED_SIZE = Vector3.new(12, 1, 16),
	CAB_SIZE = Vector3.new(12, 8, 6),
	BOARD_SIZE = Vector3.new(12, 8, 1),
	-- Trucks, boards and spawns keep this far inside the walls.
	MARGIN = 3,
	-- Space between two trucks.
	TRUCK_GAP = 4,
	-- A spawn keeps this far from any truck, so nobody spawns aboard a pad.
	SPAWN_CLEARANCE = 6,
	-- Spec §3: 3-4 trucks of 1-4 players, a ~15 s countdown.
	MIN_TRUCKS = 3,
	MAX_TRUCKS = 4,
	MAX_CAPACITY = 4,
	MIN_COUNTDOWN = 5,
	MAX_COUNTDOWN = 60,
	-- Players appear this high above a spawn point.
	SPAWN_HEIGHT = 3,
	-- How often the pad labels recount who is aboard (seconds).
	LABEL_INTERVAL = 0.5,
	-- Billboard sizes are in studs (BillboardGui scale); offsets from the part's centre.
	PAD_LABEL_SIZE = Vector2.new(8, 3),
	PAD_LABEL_OFFSET = Vector3.new(0, 7, 0),
	BOARD_LABEL_SIZE = Vector2.new(12, 8),
	BOARD_LABEL_OFFSET = Vector3.new(0, 1, 0),
	TITLE_LABEL_SIZE = Vector2.new(10, 1.5),
	TITLE_LABEL_OFFSET = Vector3.new(0, 6, 0),
	CARD_LABEL_SIZE = Vector2.new(12, 9),
	CARD_LABEL_OFFSET = Vector3.new(0, 0.5, 0),
	LABEL_MAX_DISTANCE = 120,
	-- The returning player's card, in their PlayerGui.
	CARD_NAME = "DepotResultCard",
	PLAYER_GUI_WAIT = 10,
	FLOOR_COLOR = Color3.fromRGB(84, 86, 90),
	WALL_COLOR = Color3.fromRGB(150, 140, 120),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BOARD_COLOR = Color3.fromRGB(120, 95, 60),
	LABEL_BACKGROUND = Color3.fromRGB(245, 235, 200),
	LABEL_TEXT = Color3.fromRGB(30, 30, 30),
})
```

- [ ] **Step 5: The layout rules.** `src/ServerScriptService/Features/Depot/Rules/DepotLayoutRules.luau`:

```lua
--!strict
--[=[
	DepotLayoutRules: is a depot layout buildable and safe to play? `validate` lists every problem: a floor
	with no area; fewer than MIN_TRUCKS or more than MAX_TRUCKS trucks; duplicate or empty truck ids; a
	capacity that is not a whole number from 1 to MAX_CAPACITY; a countdown outside MIN..MAX_COUNTDOWN; a
	truck (bed and cab) not inside the floor; two trucks closer than TRUCK_GAP; a board outside the floor, on a
	truck or on the other board; no spawn points; a spawn outside the floor or within SPAWN_CLEARANCE of a
	truck (a player would spawn straight into a queue). DepotServiceServer refuses to build a layout that
	fails. Pure.

	@class DepotLayoutRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

type Rect = DepotTypes.Rect
type Point = DepotTypes.Point
type Truck = DepotTypes.Truck

local function inside(outer: Rect, inner: Rect, margin: number): boolean
	return inner.minX >= outer.minX + margin
		and inner.maxX <= outer.maxX - margin
		and inner.minZ >= outer.minZ + margin
		and inner.maxZ <= outer.maxZ - margin
end

-- The distance between two rectangles; 0 when they touch or overlap.
local function gap(a: Rect, b: Rect): number
	local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
	local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- The bed and the cab behind it (+z).
local function footprint(truck: Truck): Rect
	local bed = DepotLayoutConstants.BED_SIZE
	return {
		minX = truck.x - bed.X / 2,
		maxX = truck.x + bed.X / 2,
		minZ = truck.z - bed.Z / 2,
		maxZ = truck.z + bed.Z / 2 + DepotLayoutConstants.CAB_SIZE.Z,
	}
end

local function boardRect(point: Point): Rect
	local size = DepotLayoutConstants.BOARD_SIZE
	return {
		minX = point.x - size.X / 2,
		maxX = point.x + size.X / 2,
		minZ = point.z - size.Z / 2,
		maxZ = point.z + size.Z / 2,
	}
end

local function pointRect(point: Point): Rect
	return { minX = point.x, maxX = point.x, minZ = point.z, maxZ = point.z }
end

local DepotLayoutRules = {}

--[=[
	Every problem with `layout`; ok when there are none.
]=]
function DepotLayoutRules.validate(layout: DepotTypes.Layout): (boolean, { string })
	local errors: { string } = {}
	local floor = layout.floor
	local margin = DepotLayoutConstants.MARGIN
	if floor.minX >= floor.maxX or floor.minZ >= floor.maxZ then
		table.insert(errors, "the depot floor has no area")
	end

	local count = #layout.trucks
	local minTrucks = DepotLayoutConstants.MIN_TRUCKS
	local maxTrucks = DepotLayoutConstants.MAX_TRUCKS
	if count < minTrucks or count > maxTrucks then
		table.insert(errors, `{count} trucks; the depot needs {minTrucks}-{maxTrucks}`)
	end
	local seen: { [string]: boolean } = {}
	local maxCapacity = DepotLayoutConstants.MAX_CAPACITY
	local minCountdown = DepotLayoutConstants.MIN_COUNTDOWN
	local maxCountdown = DepotLayoutConstants.MAX_COUNTDOWN
	for _, truck in layout.trucks do
		if truck.id == "" then
			table.insert(errors, "a truck has no id")
		elseif seen[truck.id] then
			table.insert(errors, `truck "{truck.id}" is defined twice`)
		end
		seen[truck.id] = true
		local capacity = truck.capacity
		if capacity < 1 or capacity > maxCapacity or capacity ~= math.floor(capacity) then
			table.insert(errors, `truck "{truck.id}": capacity must be a whole number from 1 to {maxCapacity}`)
		end
		if truck.countdown < minCountdown or truck.countdown > maxCountdown then
			table.insert(errors, `truck "{truck.id}": countdown must be {minCountdown}-{maxCountdown} seconds`)
		end
		if not inside(floor, footprint(truck), margin) then
			table.insert(errors, `truck "{truck.id}" is not inside the floor`)
		end
	end
	for index, a in layout.trucks do
		for other = index + 1, #layout.trucks do
			local b = layout.trucks[other]
			if gap(footprint(a), footprint(b)) < DepotLayoutConstants.TRUCK_GAP then
				table.insert(
					errors,
					`trucks "{a.id}" and "{b.id}" are closer than {DepotLayoutConstants.TRUCK_GAP} studs`
				)
			end
		end
	end

	local function checkBoard(name: string, point: Point)
		local rect = boardRect(point)
		if not inside(floor, rect, margin) then
			table.insert(errors, `the {name} is not inside the floor`)
		end
		for _, truck in layout.trucks do
			if overlaps(rect, footprint(truck)) then
				table.insert(errors, `the {name} stands on truck "{truck.id}"`)
			end
		end
	end
	checkBoard("contract board", layout.contractBoard)
	checkBoard("result board", layout.resultBoard)
	if overlaps(boardRect(layout.contractBoard), boardRect(layout.resultBoard)) then
		table.insert(errors, "the contract and result boards overlap")
	end

	if #layout.spawns == 0 then
		table.insert(errors, "no spawn points")
	end
	local clearance = DepotLayoutConstants.SPAWN_CLEARANCE
	for index, point in layout.spawns do
		local rect = pointRect(point)
		if not inside(floor, rect, margin) then
			table.insert(errors, `spawn {index} is not inside the floor`)
		end
		for _, truck in layout.trucks do
			if gap(rect, footprint(truck)) < clearance then
				table.insert(errors, `spawn {index} is within {clearance} studs of truck "{truck.id}"`)
			end
		end
	end
	return #errors == 0, errors
end

return DepotLayoutRules
```

- [ ] **Step 6: The contract utils.** `src/ServerScriptService/Features/Depot/Utils/DepotContractUtils.luau`:

```lua
--!strict
--[=[
	DepotContractUtils: tonight's contract and the words around it (Cleanup Crew spec §2, §3 steps 1-3).
	`tonight` picks the contract for the current UTC day, so every depot server shows the same job all day;
	`resolve` turns a contract id that rode a teleport (untrusted: teleport data travels through the client)
	back into a contract, falling back to the first; the rest build the contract board's lines and the drive
	and arrival cards. Pure.

	@class DepotContractUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

type Contract = DepotTypes.Contract

local DAY_SECONDS = 86400

local DepotContractUtils = {}

function DepotContractUtils.tonight(contracts: { Contract }, epochSeconds: number): Contract
	assert(#contracts > 0, "DepotContractUtils.tonight: no contracts")
	local day = math.floor(epochSeconds / DAY_SECONDS)
	return contracts[day % #contracts + 1]
end

function DepotContractUtils.resolve(contracts: { Contract }, id: unknown): Contract
	assert(#contracts > 0, "DepotContractUtils.resolve: no contracts")
	if type(id) == "string" then
		for _, contract in contracts do
			if contract.id == id then
				return contract
			end
		end
	end
	return contracts[1]
end

function DepotContractUtils.boardLines(contract: Contract, quota: number): { string }
	return {
		"TONIGHT'S CONTRACT",
		contract.client,
		contract.job,
		`Load {quota} of trash on the truck. Salvage earns a finder's fee.`,
		contract.note,
		"Stand in a truck bed to join a crew (1-4 players).",
	}
end

function DepotContractUtils.driveCard(contract: Contract): DepotTypes.CardMessage
	return { kind = "drive", title = "On the road", body = `Heading to {contract.client}` }
end

function DepotContractUtils.arrivalCard(contract: Contract, quota: number): DepotTypes.CardMessage
	return {
		kind = "arrival",
		title = contract.client,
		body = `{contract.job} Clear {quota} of trash. {contract.note}`,
	}
end

return DepotContractUtils
```

- [ ] **Step 7: Exemptions.** In `src/ServerScriptService/Core/Testing/SpecRoots.luau`, at the end of `EXEMPT_MODULES` (after the last Cleanup Crew block, before the closing `}`), add:

```lua

	-- Cleanup Crew: Depot
	["ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants"] = "static names, place table, contracts and card texts (no logic)",
	["ServerScriptService.Features.Depot.Data.DepotLayoutConstants"] = "authored layout data; validated by DepotLayoutRules.spec",
```

- [ ] **Step 8: Module map, format, gate, commit** (Global Constraints order):

```bash
git add src/ReplicatedStorage/Shared/Features/Depot src/ServerScriptService/Features/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot src/ServerScriptService/Features/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src/ReplicatedStorage/Shared/Features/Depot src/ServerScriptService/Features/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
bash .superpowers/sdd/gate.sh
git commit -m "feat(depot): layout, contracts and their rules"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 9: Controller: Studio TestEZ** (`RunTests = true`). Studio verification checklist:
1. `DepotLayoutRules.spec` and `DepotContractUtils.spec` pass (15 + 9 cases); the total rises by 24 with 0 failures.
2. `assertAllModulesSpecced` and `assertAllSpecsCovered` pass (the three exemptions are picked up).
3. Output shows no require errors from the new Depot folders (the server boots normally: nothing requires them yet).

---

### Task 2: The result card and the crew (pure)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau` + `ShiftCardUtils.spec.luau`
- Create: `src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.luau` + `ShiftCrewTracker.spec.luau`

**Interfaces:**
- Consumes: `QueueTypes.QueuePayload = { [string]: string | number | boolean }`; `QueueTeleportRules.payload(value) -> (QueuePayload?, string?)` (spec only); `ShiftTypes.ShiftResults` (with M2's `catches: number`), `ShiftTypes.Award`.
- Produces (ShiftCardUtils): `export type ResultCard = { client: string, shift: number, outcome: string, quota: number, cleared: number, bonus: number, salvage: number, piles: number, catches: number, quotaMet: boolean, crew: { CardLine }, awards: { ShiftTypes.Award } }`, `export type CardLine = { name: string, banked: number }`, `export type CardInfo = { client: string, shift: number }`; `encode(results: ShiftTypes.ShiftResults, info: CardInfo) -> QueuePayload`, `decode(payload: QueuePayload?) -> ResultCard?`, `lines(card: ResultCard) -> { string }`.
- Produces (ShiftCrewTracker): `ShiftCrewTracker.new() -> ShiftCrewTracker` with `join(userIds: { number }, presentIds: { number })`, `add(userId) -> boolean`, `remove(userId) -> boolean`, `has(userId) -> boolean`, `present(presentIds: { number }) -> { number }` (sorted, unique), `leave(now: number, wait: number)`, `isLeaving(now) -> boolean`, `expired(now) -> boolean` (true once), `startable(presentIds, now) -> number`, `clear()`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau`:

```lua
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftCardUtils = require(script.Parent.ShiftCardUtils)
local QueueTeleportRules = require(ServerScriptService.Features.Queue.Rules.QueueTeleportRules)

local INFO = { client = "Harlow & Finch Ltd.", shift = 2 }

local function review(crewSize)
	local crew = {}
	for index = 1, crewSize or 2 do
		table.insert(crew, { name = `Crew{index}`, banked = 100 - index, piles = index, salvage = 0 })
	end
	return {
		outcome = "clockout",
		quota = 350,
		cleared = 380,
		bonus = 95,
		salvage = 3,
		piles = 12,
		catches = 1,
		quotaMet = true,
		crew = crew,
		awards = { { title = "Top Hauler", name = "Crew1" }, { title = "Dust Devil", name = "Crew2" } },
	}
end

-- What the depot sees: the payload after the teleport's JSON round trip.
local function wire(payload)
	return HttpService:JSONDecode(HttpService:JSONEncode(payload))
end

local function payload()
	return wire(ShiftCardUtils.encode(review(2), INFO))
end

return function()
	describe("encode", function()
		it("fits the Queue's payload limits", function()
			local clean, reason = QueueTeleportRules.payload(ShiftCardUtils.encode(review(4), INFO))
			expect(reason).to.equal(nil)
			expect(clean ~= nil).to.equal(true)
		end)

		it("keeps at most four crew lines and three awards", function()
			local big = review(6)
			table.insert(big.awards, { title = "Treasure Hunter", name = "Crew3" })
			table.insert(big.awards, { title = "Extra", name = "Crew4" })
			local card = ShiftCardUtils.decode(wire(ShiftCardUtils.encode(big, INFO)))
			expect(#card.crew).to.equal(4)
			expect(#card.awards).to.equal(3)
		end)
	end)

	describe("decode", function()
		it("round-trips a review through teleport data", function()
			local card = ShiftCardUtils.decode(payload())
			expect(card.client).to.equal("Harlow & Finch Ltd.")
			expect(card.shift).to.equal(2)
			expect(card.outcome).to.equal("clockout")
			expect(card.quota).to.equal(350)
			expect(card.cleared).to.equal(380)
			expect(card.bonus).to.equal(95)
			expect(card.salvage).to.equal(3)
			expect(card.piles).to.equal(12)
			expect(card.catches).to.equal(1)
			expect(card.quotaMet).to.equal(true)
			expect(#card.crew).to.equal(2)
			expect(card.crew[1].name).to.equal("Crew1")
			expect(card.crew[1].banked).to.equal(99)
			expect(card.awards[2].title).to.equal("Dust Devil")
			expect(card.awards[2].name).to.equal("Crew2")
		end)

		it("cuts a very long name", function()
			local long = review(1)
			long.crew[1].name = string.rep("x", 5000)
			local card = ShiftCardUtils.decode(wire(ShiftCardUtils.encode(long, INFO)))
			expect(#card.crew[1].name).to.equal(40)
		end)

		it("reads nothing from no payload, another version or a payload that is not a card", function()
			expect(ShiftCardUtils.decode(nil)).to.equal(nil)
			expect(ShiftCardUtils.decode({})).to.equal(nil)
			expect(ShiftCardUtils.decode({ contract = "harlow-finch-1" })).to.equal(nil)
			local other = payload()
			other.v = 2
			expect(ShiftCardUtils.decode(other)).to.equal(nil)
		end)

		it("rejects a field of the wrong type", function()
			local wrong = {
				client = 5,
				outcome = 5,
				shift = "two",
				quota = "lots",
				cleared = "lots",
				bonus = "lots",
				salvage = "lots",
				piles = "lots",
				catches = "lots",
				met = "yes",
				crew = "two",
				awards = "two",
				c1n = 7,
				c1b = "seven",
				a1t = false,
				a1n = 3,
			}
			for key, value in wrong do
				local broken = payload()
				broken[key] = value
				expect(ShiftCardUtils.decode(broken)).to.equal(nil)
			end
		end)

		it("rejects a crew count that doesn't match its lines", function()
			local short = payload()
			short.crew = 3
			expect(ShiftCardUtils.decode(short)).to.equal(nil)
			local huge = payload()
			huge.crew = 9
			expect(ShiftCardUtils.decode(huge)).to.equal(nil)
			local awards = payload()
			awards.awards = 4
			expect(ShiftCardUtils.decode(awards)).to.equal(nil)
		end)

		it("clamps negative, fractional and huge numbers", function()
			local odd = payload()
			odd.cleared = -5
			odd.bonus = 12.7
			odd.quota = 1e12
			local card = ShiftCardUtils.decode(odd)
			expect(card.cleared).to.equal(0)
			expect(card.bonus).to.equal(12)
			expect(card.quota).to.equal(1000000)
		end)

		it("rejects a number that is not a number", function()
			local nan = payload()
			nan.bonus = 0 / 0
			expect(ShiftCardUtils.decode(nan)).to.equal(nil)
		end)
	end)

	describe("lines", function()
		it("reads like the review", function()
			local lines = ShiftCardUtils.lines(ShiftCardUtils.decode(payload()))
			expect(lines[1]).to.equal("Harlow & Finch Ltd. - shift 2")
			expect(lines[2]).to.equal("Clocked out")
			expect(lines[3]).to.equal("Cleared 380 / 350 - QUOTA MET")
			expect(lines[4]).to.equal("Finder's fee 95")
			expect(lines[5]).to.equal("Salvage 3 | Piles 12 | Caught 1")
			expect(lines[6]).to.equal("Crew1: banked 99")
			expect(lines[7]).to.equal("Crew2: banked 98")
			expect(lines[8]).to.equal("Top Hauler: Crew1")
			expect(lines[9]).to.equal("Dust Devil: Crew2")
			expect(#lines).to.equal(9)
		end)

		it("says when the quota was missed, and keeps an unknown outcome as written", function()
			local missed = review(1)
			missed.quotaMet = false
			missed.outcome = "abandoned"
			local lines = ShiftCardUtils.lines(ShiftCardUtils.decode(wire(ShiftCardUtils.encode(missed, INFO))))
			expect(lines[2]).to.equal("Everyone left")
			expect(lines[3]).to.equal("Cleared 380 / 350 - quota missed")
			local odd = review(1)
			odd.outcome = "weird"
			local oddLines = ShiftCardUtils.lines(ShiftCardUtils.decode(wire(ShiftCardUtils.encode(odd, INFO))))
			expect(oddLines[2]).to.equal("weird")
		end)
	end)
end
```

`src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.spec.luau`:

```lua
local ShiftCrewTracker = require(script.Parent.ShiftCrewTracker)

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

return function()
	it("starts with nobody", function()
		local crew = ShiftCrewTracker.new()
		expect(#crew:present({ 1, 2 })).to.equal(0)
		expect(crew:startable({ 1, 2 }, 0)).to.equal(0)
		expect(crew:has(1)).to.equal(false)
	end)

	describe("join", function()
		it("makes the arriving party the crew", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 7, 8 }, { 7, 8, 9 })
			expect(crew:has(7)).to.equal(true)
			expect(crew:has(9)).to.equal(false)
			expect(same(crew:present({ 7, 8, 9 }), { 7, 8 })).to.equal(true)
		end)

		it("replaces a crew that has left the server", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:join({ 2 }, { 2 })
			expect(crew:has(1)).to.equal(false)
			expect(crew:has(2)).to.equal(true)
		end)

		it("adds a second party to a crew still here", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:join({ 2 }, { 1, 2 })
			expect(same(crew:present({ 1, 2 }), { 1, 2 })).to.equal(true)
		end)
	end)

	describe("add, remove and present", function()
		it("adds and removes one member, once", function()
			local crew = ShiftCrewTracker.new()
			expect(crew:add(4)).to.equal(true)
			expect(crew:add(4)).to.equal(false)
			expect(crew:remove(4)).to.equal(true)
			expect(crew:remove(4)).to.equal(false)
			expect(crew:has(4)).to.equal(false)
		end)

		it("counts only crew members who are here, once each, in UserId order", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 9, 3, 5 }, { 9, 3, 5 })
			expect(same(crew:present({ 5, 9, 4, 5 }), { 5, 9 })).to.equal(true)
			expect(crew:startable({ 5, 9, 4 }, 0)).to.equal(2)
		end)
	end)

	describe("leaving", function()
		it("holds the next shift while the crew is on its way home", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			expect(crew:isLeaving(139)).to.equal(true)
			expect(crew:startable({ 1 }, 139)).to.equal(0)
			expect(crew:expired(139)).to.equal(false)
		end)

		it("lets the crew work again once the window has passed, and says so once", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			expect(crew:isLeaving(140)).to.equal(false)
			expect(crew:startable({ 1 }, 140)).to.equal(1)
			expect(crew:expired(140)).to.equal(true)
			expect(crew:expired(141)).to.equal(false)
		end)

		it("never reports a window that was not opened", function()
			expect(ShiftCrewTracker.new():expired(1000)).to.equal(false)
		end)

		it("ends the window when a new party replaces the crew", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			crew:join({ 2 }, { 2 })
			expect(crew:isLeaving(110)).to.equal(false)
			expect(crew:startable({ 2 }, 110)).to.equal(1)
		end)
	end)

	it("clears everything", function()
		local crew = ShiftCrewTracker.new()
		crew:join({ 1, 2 }, { 1, 2 })
		crew:leave(0, 40)
		crew:clear()
		expect(crew:has(1)).to.equal(false)
		expect(crew:isLeaving(1)).to.equal(false)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error with "module not found".

- [ ] **Step 3: The card.** `src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau`:

```lua
--!strict
--[=[
	ShiftCardUtils: the result card that rides the return teleport to the depot (Cleanup Crew spec §3 steps 1
	and 7, §6.5 "the depot result card comes through the return teleport"). `encode` flattens a performance
	review into a Queue payload (flat keys, 27 at most, under Queue's 32); `decode` is the depot's trust
	boundary: teleport data travels through the client, so a wrong version, a wrong type anywhere or a crew
	count without its lines reads as no card, numbers are clamped to whole 0..MAX_NUMBER and text is cut to
	MAX_TEXT characters; `lines` is what the depot's board shows. Pure.

	Wire keys: v, client, shift, outcome, quota, cleared, bonus, salvage, piles, catches, met, crew, awards,
	c<i>n / c<i>b (crew line i: name, banked; i <= 4), a<i>t / a<i>n (award i: title, name; i <= 3).

	@class ShiftCardUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type QueuePayload = QueueTypes.QueuePayload

export type CardLine = {
	name: string,
	banked: number,
}

export type ResultCard = {
	client: string,
	shift: number,
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	salvage: number,
	piles: number,
	catches: number,
	quotaMet: boolean,
	crew: { CardLine },
	awards: { ShiftTypes.Award },
}

-- What the review does not know: whose contract it was and which shift on that server.
export type CardInfo = {
	client: string,
	shift: number,
}

local VERSION = 1
local MAX_CREW = 4
local MAX_AWARDS = 3
local MAX_TEXT = 40
local MAX_NUMBER = 1000000

local OUTCOME_TEXT: { [string]: string } = {
	clockout = "Clocked out",
	timeout = "Time's up",
	abandoned = "Everyone left",
}

-- At most MAX_TEXT characters, cut on a character boundary; invalid UTF-8 reads "?".
local function cut(value: string): string
	if utf8.len(value) == nil then
		return "?"
	end
	local stop = utf8.offset(value, MAX_TEXT + 1)
	if stop == nil then
		return value
	end
	return string.sub(value, 1, stop - 1)
end

local function text(value: unknown): string?
	if type(value) ~= "string" then
		return nil
	end
	return cut(value)
end

-- A whole number clamped to 0..MAX_NUMBER; nil for anything that is not a number (NaN included).
local function count(value: unknown): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), 0, MAX_NUMBER)
end

local ShiftCardUtils = {}

function ShiftCardUtils.encode(results: ShiftTypes.ShiftResults, info: CardInfo): QueuePayload
	local payload: QueuePayload = {
		v = VERSION,
		client = cut(info.client),
		shift = info.shift,
		outcome = cut(results.outcome),
		quota = results.quota,
		cleared = results.cleared,
		bonus = results.bonus,
		salvage = results.salvage,
		piles = results.piles,
		catches = results.catches,
		met = results.quotaMet,
	}
	local crew = math.min(#results.crew, MAX_CREW)
	payload.crew = crew
	for index = 1, crew do
		local line = results.crew[index]
		payload[`c{index}n`] = cut(line.name)
		payload[`c{index}b`] = line.banked
	end
	local awards = math.min(#results.awards, MAX_AWARDS)
	payload.awards = awards
	for index = 1, awards do
		local award = results.awards[index]
		payload[`a{index}t`] = cut(award.title)
		payload[`a{index}n`] = cut(award.name)
	end
	return payload
end

function ShiftCardUtils.decode(payload: QueuePayload?): ResultCard?
	if payload == nil or payload.v ~= VERSION then
		return nil
	end
	local met = payload.met
	if type(met) ~= "boolean" then
		return nil
	end
	local client = text(payload.client)
	local outcome = text(payload.outcome)
	local shift = count(payload.shift)
	local quota = count(payload.quota)
	local cleared = count(payload.cleared)
	local bonus = count(payload.bonus)
	local salvage = count(payload.salvage)
	local piles = count(payload.piles)
	local catches = count(payload.catches)
	local crewCount = count(payload.crew)
	local awardCount = count(payload.awards)
	if
		client == nil
		or outcome == nil
		or shift == nil
		or quota == nil
		or cleared == nil
		or bonus == nil
		or salvage == nil
		or piles == nil
		or catches == nil
		or crewCount == nil
		or awardCount == nil
		or crewCount > MAX_CREW
		or awardCount > MAX_AWARDS
	then
		return nil
	end
	local crew: { CardLine } = {}
	for index = 1, crewCount do
		local name = text(payload[`c{index}n`])
		local banked = count(payload[`c{index}b`])
		if name == nil or banked == nil then
			return nil
		end
		table.insert(crew, { name = name, banked = banked })
	end
	local awards: { ShiftTypes.Award } = {}
	for index = 1, awardCount do
		local title = text(payload[`a{index}t`])
		local name = text(payload[`a{index}n`])
		if title == nil or name == nil then
			return nil
		end
		table.insert(awards, { title = title, name = name })
	end
	return {
		client = client,
		shift = shift,
		outcome = outcome,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		salvage = salvage,
		piles = piles,
		catches = catches,
		quotaMet = met,
		crew = crew,
		awards = awards,
	}
end

function ShiftCardUtils.lines(card: ResultCard): { string }
	local lines: { string } = {
		`{card.client} - shift {card.shift}`,
		OUTCOME_TEXT[card.outcome] or card.outcome,
		`Cleared {card.cleared} / {card.quota} - {if card.quotaMet then "QUOTA MET" else "quota missed"}`,
		`Finder's fee {card.bonus}`,
		`Salvage {card.salvage} | Piles {card.piles} | Caught {card.catches}`,
	}
	for _, line in card.crew do
		table.insert(lines, `{line.name}: banked {line.banked}`)
	end
	for _, award in card.awards do
		table.insert(lines, `{award.title}: {award.name}`)
	end
	return lines
end

return ShiftCardUtils
```

Implementer notes (verify, do not guess): if luau-lsp does not narrow `met` to `boolean` after the `type(met) ~= "boolean"` early return, keep the same structure with `local quotaMet: boolean = met == true` after the check (never cast). `payload.v` indexes the `QueuePayload` string indexer. If luau-lsp does not narrow the eleven locals through the long `or` chain, split the chain into two `if … then return nil end` statements (strings, then numbers).

- [ ] **Step 4: The crew.** `src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.luau`:

```lua
--!strict
--[=[
	ShiftCrewTracker: who the crew is on this server, and whether it is on its way home (Cleanup Crew spec §3
	steps 3 and 7, §6.5). The crew is the party that arrived (Queue `arrived`; a second party joins a crew
	still here, and replaces one that has gone) plus expected members who came late. A player leaves it by
	leaving the server or by being moved back to the depot. After Back to depot the crew is "leaving" for a
	while: `startable` is 0, so no shift starts under a crew whose return trip is still in flight; once the
	window has passed, `expired` reports it once and the crew still here can work again. Plain bookkeeping
	(pure).

	@class ShiftCrewTracker
]=]

export type ShiftCrewTracker = {
	join: (self: ShiftCrewTracker, userIds: { number }, presentIds: { number }) -> (),
	add: (self: ShiftCrewTracker, userId: number) -> boolean,
	remove: (self: ShiftCrewTracker, userId: number) -> boolean,
	has: (self: ShiftCrewTracker, userId: number) -> boolean,
	present: (self: ShiftCrewTracker, presentIds: { number }) -> { number },
	leave: (self: ShiftCrewTracker, now: number, wait: number) -> (),
	isLeaving: (self: ShiftCrewTracker, now: number) -> boolean,
	expired: (self: ShiftCrewTracker, now: number) -> boolean,
	startable: (self: ShiftCrewTracker, presentIds: { number }, now: number) -> number,
	clear: (self: ShiftCrewTracker) -> (),
}

local ShiftCrewTracker = {}

function ShiftCrewTracker.new(): ShiftCrewTracker
	local members: { [number]: boolean } = {}
	local leavingUntil: number? = nil

	local tracker: ShiftCrewTracker
	tracker = {
		join = function(self, userIds, presentIds)
			if #self:present(presentIds) == 0 then
				table.clear(members)
				leavingUntil = nil
			end
			for _, userId in userIds do
				members[userId] = true
			end
		end,

		add = function(_self, userId)
			if members[userId] then
				return false
			end
			members[userId] = true
			return true
		end,

		remove = function(_self, userId)
			if not members[userId] then
				return false
			end
			members[userId] = nil
			return true
		end,

		has = function(_self, userId)
			return members[userId] == true
		end,

		present = function(_self, presentIds)
			local ids: { number } = {}
			for _, userId in presentIds do
				if members[userId] and not table.find(ids, userId) then
					table.insert(ids, userId)
				end
			end
			table.sort(ids)
			return ids
		end,

		leave = function(_self, now, wait)
			leavingUntil = now + wait
		end,

		isLeaving = function(_self, now)
			local untilTime = leavingUntil
			return untilTime ~= nil and now < untilTime
		end,

		expired = function(_self, now)
			local untilTime = leavingUntil
			if untilTime == nil or now < untilTime then
				return false
			end
			leavingUntil = nil
			return true
		end,

		startable = function(self, presentIds, now)
			if self:isLeaving(now) then
				return 0
			end
			return #self:present(presentIds)
		end,

		clear = function(_self)
			table.clear(members)
			leavingUntil = nil
		end,
	}
	return tracker
end

return ShiftCrewTracker
```

- [ ] **Step 5: Module map, format, gate, commit:**

```bash
git add src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.luau src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.spec.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.luau src/ServerScriptService/Features/Shift/Utils/ShiftCardUtils.spec.luau src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.luau src/ServerScriptService/Features/Shift/State/ShiftCrewTracker.spec.luau
git add src/ServerScriptService/Features/Shift
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): the result card wire format and the crew tracker"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Controller: Studio TestEZ** (`RunTests = true`). Studio verification checklist:
1. `ShiftCardUtils.spec` (11 cases) and `ShiftCrewTracker.spec` (11 cases) pass; total +22, 0 failures.
2. `assertAllModulesSpecced` passes with no new exemption (both modules have specs).
3. The `ShiftCardUtils` case "fits the Queue's payload limits" passed: it is the only check that a 4-crew, 3-award card stays inside Queue's 32 keys / 1000-character limits.

---

### Task 3: The depot on the server (graybox, pads, boards, travel cards, result cards)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau`
- Create: `src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau`
- Create: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (three exemptions)

**Interfaces:**
- Consumes: Task 1 (`DepotTypes`, `DepotConstants`, `DepotLayoutConstants`, `DepotLayoutRules.validate`, `DepotContractUtils.*`), Task 2 (`ShiftCardUtils.decode / lines`); Queue: `QueueRegistry.register(role, placeId)` / `has(role)`, `QueueServiceServer:setDepartData(resolver)`, `:setArrivalPoint(role, resolver)`, `:padOf(player) -> BasePart?`, `:runsRole(role) -> boolean`, `:role() -> string?`, `:mode() -> "live" | "local"`, signals `departing: Signal<BasePart, { Player }>`, `arrived: Signal<{ Player }, QueuePayload>`, `returned: Signal<Player, QueuePayload>`; `QueueConstants.TAG / CAPACITY_ATTRIBUTE / COUNTDOWN_ATTRIBUTE / DESTINATION_ATTRIBUTE`; `ToastServiceServer:send(target, { text, duration? })`; `ShiftConstants.QUOTA`.
- Produces (DepotEvents): `DepotEvents.packets.Card` (value `ByteNet.struct({ kind = ByteNet.string, title = ByteNet.string, body = ByteNet.string })`, server → client).
- Produces (DepotBuildSystem): `export type BuiltTruck = { id: string, index: number, capacity: number, pad: BasePart, label: TextLabel }`, `export type Built = { model: Model, trucks: { BuiltTruck }, resultBoard: BasePart }`; `build(layout, origin, boardLines) -> Built`, `pinCard(player, board, lines) -> boolean` (yields up to `PLAYER_GUI_WAIT`).
- Produces (DepotServiceServer): `spawnCFrame(index: number) -> CFrame` (wrapping over the spawn points), `contract() -> DepotTypes.Contract`, `getState()`. Registers `DepotConstants.PLACE_IDS` in `QueueRegistry` **at load**. Sets Queue's depart data (`{ contract = <tonight's id> }`) and the depot arrival point.

- [ ] **Step 1: The packet** `src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau`:

```lua
--!strict
--[=[
	DepotEvents: the Depot's ByteNet packet (server → client only): a travel card (the drive card when a
	party's truck leaves, the arrival card when it reaches the office). The client checks the kind
	(DepotStore.show).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at DepotServiceServer load).

	@class DepotEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "DepotEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DepotEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- kind "drive" | "arrival"; anything else is dropped by the client.
			Card = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					title = ByteNet.string,
					body = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return DepotEvents
```

- [ ] **Step 2: The builder** `src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau`:

```lua
--!strict
--[=[
	DepotBuildSystem: builds the depot's static graybox once (Cleanup Crew spec §1 "polished feel on
	graybox", §3 step 1, §5): a floor and four walls; per truck a bed that is a Queue pad (QueueCapacity,
	QueueCountdown and QueueDestination set BEFORE the QueuePad tag, because Queue reads them once when the
	pad is tagged), a cab behind it and a label above it; the contract board with tonight's contract; the
	result board, where `pinCard` hangs a returning player's card that only they see (a BillboardGui in their
	PlayerGui, kept across respawns). Plain placeholder look on purpose: the final boards and labels wait for
	the developer's Figma approval (spec §7). Everything is anchored under one Model in Workspace.

	Spec-exempt shell (Instances); the layout is the one the specced DepotLayoutRules validated.

	@class DepotBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

export type BuiltTruck = {
	id: string,
	-- 1-based, in layout order: "TRUCK 1".
	index: number,
	capacity: number,
	pad: BasePart,
	label: TextLabel,
}

export type Built = {
	model: Model,
	trucks: { BuiltTruck },
	resultBoard: BasePart,
}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- A plain text billboard over `adornee` (size in studs). Returned unparented with its label.
local function billboard(name: string, adornee: BasePart, size: Vector2, offset: Vector3, text: string): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffset = offset
	gui.MaxDistance = DepotLayoutConstants.LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = DepotLayoutConstants.LABEL_BACKGROUND
	label.BackgroundTransparency = 0.1
	label.TextColor3 = DepotLayoutConstants.LABEL_TEXT
	label.Font = Enum.Font.SourceSansSemibold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	return gui, label
end

local DepotBuildSystem = {}

function DepotBuildSystem.build(layout: DepotTypes.Layout, origin: CFrame, boardLines: { string }): Built
	local model = Instance.new("Model")
	model.Name = DepotLayoutConstants.MODEL_NAME
	local floor = layout.floor
	local width = floor.maxX - floor.minX
	local depth = floor.maxZ - floor.minZ
	local centreX = floor.minX + width / 2
	local centreZ = floor.minZ + depth / 2
	local floorThickness = DepotLayoutConstants.FLOOR_THICKNESS
	block(
		"Floor",
		Vector3.new(width, floorThickness, depth),
		origin * CFrame.new(centreX, -floorThickness / 2, centreZ),
		DepotLayoutConstants.FLOOR_COLOR,
		model
	)

	local height = DepotLayoutConstants.WALL_HEIGHT
	local thickness = DepotLayoutConstants.WALL_THICKNESS
	local walls = folder("Walls", model)
	local across = Vector3.new(width + thickness, height, thickness)
	local along = Vector3.new(thickness, height, depth + thickness)
	for _, wall in
		{
			{ size = across, x = centreX, z = floor.minZ },
			{ size = across, x = centreX, z = floor.maxZ },
			{ size = along, x = floor.minX, z = centreZ },
			{ size = along, x = floor.maxX, z = centreZ },
		}
	do
		block("Wall", wall.size, origin * CFrame.new(wall.x, height / 2, wall.z), DepotLayoutConstants.WALL_COLOR, walls)
	end

	local bed = DepotLayoutConstants.BED_SIZE
	local cab = DepotLayoutConstants.CAB_SIZE
	local trucks: { BuiltTruck } = {}
	for index, truck in layout.trucks do
		local truckFolder = folder(truck.id, model)
		local pad = block(
			"TruckBed",
			bed,
			origin * CFrame.new(truck.x, bed.Y / 2, truck.z),
			DepotLayoutConstants.BED_COLOR,
			truckFolder
		)
		pad:SetAttribute(QueueConstants.CAPACITY_ATTRIBUTE, truck.capacity)
		pad:SetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE, truck.countdown)
		pad:SetAttribute(QueueConstants.DESTINATION_ATTRIBUTE, DepotConstants.ROLE_SHIFT)
		CollectionService:AddTag(pad, QueueConstants.TAG)
		block(
			"TruckCab",
			cab,
			origin * CFrame.new(truck.x, cab.Y / 2, truck.z + bed.Z / 2 + cab.Z / 2),
			DepotLayoutConstants.TRUCK_COLOR,
			truckFolder
		)
		local gui, label = billboard(
			"PadLabel",
			pad,
			DepotLayoutConstants.PAD_LABEL_SIZE,
			DepotLayoutConstants.PAD_LABEL_OFFSET,
			""
		)
		gui.Parent = truckFolder
		table.insert(trucks, { id = truck.id, index = index, capacity = truck.capacity, pad = pad, label = label })
	end

	local boards = folder("Boards", model)
	local boardSize = DepotLayoutConstants.BOARD_SIZE
	local contractPoint = layout.contractBoard
	local contractBoard = block(
		"ContractBoard",
		boardSize,
		origin * CFrame.new(contractPoint.x, boardSize.Y / 2, contractPoint.z),
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	local contractGui = billboard(
		"ContractText",
		contractBoard,
		DepotLayoutConstants.BOARD_LABEL_SIZE,
		DepotLayoutConstants.BOARD_LABEL_OFFSET,
		table.concat(boardLines, "\n")
	)
	contractGui.Parent = boards
	local resultPoint = layout.resultBoard
	local resultBoard = block(
		"ResultBoard",
		boardSize,
		origin * CFrame.new(resultPoint.x, boardSize.Y / 2, resultPoint.z),
		DepotLayoutConstants.BOARD_COLOR,
		boards
	)
	local titleGui = billboard(
		"ResultTitle",
		resultBoard,
		DepotLayoutConstants.TITLE_LABEL_SIZE,
		DepotLayoutConstants.TITLE_LABEL_OFFSET,
		DepotConstants.RESULT_BOARD_TITLE
	)
	titleGui.Parent = boards

	model.Parent = Workspace
	return { model = model, trucks = trucks, resultBoard = resultBoard }
end

--[=[
	Hangs `lines` on the result board for `player` only: a BillboardGui in their PlayerGui (replacing their
	last card, kept across respawns). Yields up to PLAYER_GUI_WAIT seconds for the PlayerGui; false when it
	never appears or the player left.
]=]
function DepotBuildSystem.pinCard(player: Player, board: BasePart, lines: { string }): boolean
	local found = player:WaitForChild("PlayerGui", DepotLayoutConstants.PLAYER_GUI_WAIT)
	if found == nil or not found:IsA("PlayerGui") or player.Parent == nil then
		return false
	end
	local old = found:FindFirstChild(DepotLayoutConstants.CARD_NAME)
	if old ~= nil then
		old:Destroy()
	end
	local gui = billboard(
		DepotLayoutConstants.CARD_NAME,
		board,
		DepotLayoutConstants.CARD_LABEL_SIZE,
		DepotLayoutConstants.CARD_LABEL_OFFSET,
		table.concat(lines, "\n")
	)
	gui.ResetOnSpawn = false
	gui.Parent = found
	return true
end

return DepotBuildSystem
```

Implementer note: `local contractGui = billboard(...)` keeps only the first return (the gui); that is intended. If selene flags the unused second value elsewhere, name it `_label`.

- [ ] **Step 3: The service** `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`:

```lua
--!strict
--[=[
	DepotServiceServer: the company garage, Cleanup Crew's lobby (spec §3 steps 1-3 and 7, §5, §6.2 "Depot").

	- At load it registers the place-role table (DepotConstants.PLACE_IDS: placeholders until the developer
	  creates the shift place) in Queue's QueueRegistry, so Queue knows every role before services start.
	- Where this server runs the depot role (the depot place; in Studio every role runs in one server) it
	  builds the graybox garage at DepotLayoutConstants.ORIGIN, validated by DepotLayoutRules (a broken
	  layout is a boot error): truck beds tagged QueuePad (Queue holds the parties, runs the countdown and
	  Depart now), tonight's contract board (DepotContractUtils.tonight), the result board, and a label over
	  each truck counting who is aboard (QueueServiceServer:padOf; Queue's own HUD widget shows the countdown
	  to those aboard).
	- A departing party carries tonight's contract id (setDepartData) and gets the drive card; a local move
	  to the depot lands on the spawn points (setArrivalPoint).
	- An arriving party, wherever it lands, gets the arrival card for its contract (resolved from the
	  untrusted payload).
	- A returning player (Queue `returned`) gets their result card (ShiftCardUtils.decode: teleport data is
	  untrusted) pinned on the result board, visible to them only, and a toast.

	Spec-exempt shell (Players, RunService, ByteNet, Queue signals); the decisions are the specced
	DepotLayoutRules, DepotContractUtils and ShiftCardUtils.

	@class DepotServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotServer = ServerScriptService.Features.Depot
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotLayoutConstants = require(DepotServer.Data.DepotLayoutConstants)
local DepotLayoutRules = require(DepotServer.Rules.DepotLayoutRules)
local DepotContractUtils = require(DepotServer.Utils.DepotContractUtils)
local DepotBuildSystem = require(DepotServer.Systems.DepotBuildSystem)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

-- The place-role table, at load: Queue resolves this server's role and routes when services start.
for role, placeId in DepotConstants.PLACE_IDS do
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

local LAYOUT = DepotLayoutConstants.LAYOUT

local log = Logger.new("DepotServiceServer")

local built: DepotBuildSystem.Built? = nil
local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
local stoppers: { () -> () } = {}
local cardsSent = 0
local cardsPinned = 0

local function sendCard(players: { Player }, card: DepotTypes.CardMessage)
	for _, player in players do
		if player.Parent == Players then
			DepotEvents.packets.Card.sendTo(card, player)
			cardsSent += 1
		end
	end
end

local function padText(index: number, aboard: number, capacity: number): string
	if aboard == 0 then
		return `TRUCK {index}\n0/{capacity} aboard\nStand in the bed to join`
	end
	return `TRUCK {index}\n{aboard}/{capacity} aboard`
end

-- Recounts who stands in each truck bed (Queue's membership) and rewrites the labels.
local function refreshLabels()
	local current = built
	if current == nil then
		return
	end
	local aboard: { [BasePart]: number } = {}
	for _, player in Players:GetPlayers() do
		local pad = QueueServiceServer:padOf(player)
		if pad ~= nil then
			aboard[pad] = (aboard[pad] or 0) + 1
		end
	end
	for _, truck in current.trucks do
		truck.label.Text = padText(truck.index, aboard[truck.pad] or 0, truck.capacity)
	end
end

local function pinResultCard(player: Player, payload: QueueTypes.QueuePayload)
	local current = built
	local card = ShiftCardUtils.decode(payload)
	if current == nil or card == nil then
		return
	end
	local lines = ShiftCardUtils.lines(card)
	task.spawn(function()
		if DepotBuildSystem.pinCard(player, current.resultBoard, lines) then
			cardsPinned += 1
			ToastServiceServer:send(player, { text = DepotConstants.RETURN_TEXT, duration = 6 })
		end
	end)
end

export type DepotServiceServer = {
	dependencies: { string },
	start: (self: DepotServiceServer) -> (),
	stop: (self: DepotServiceServer) -> (),
	getState: (self: DepotServiceServer) -> { [string]: string | number | boolean },
	spawnCFrame: (self: DepotServiceServer, index: number) -> CFrame,
	contract: (self: DepotServiceServer) -> DepotTypes.Contract,
}

local DepotServiceServer: DepotServiceServer = {
	dependencies = { "QueueServiceServer", "ToastServiceServer" },

	--[=[
		Hands Queue the depart data and the depot arrival point, sends travel cards and result cards, and builds
		the garage where this server runs the depot role.
	]=]
	start = function(self)
		QueueServiceServer:setDepartData(function(_pad, _party)
			return { contract = contract.id }
		end)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, function(_player, index)
			return self:spawnCFrame(index)
		end)
		local departing = QueueServiceServer.departing:Connect(function(_pad, party)
			sendCard(party, DepotContractUtils.driveCard(contract))
		end)
		local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
			local arriving = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
			sendCard(party, DepotContractUtils.arrivalCard(arriving, ShiftConstants.QUOTA))
		end)
		local returned = QueueServiceServer.returned:Connect(pinResultCard)
		table.insert(stoppers, function()
			departing:Disconnect()
			arrived:Disconnect()
			returned:Disconnect()
		end)

		if not QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
			log:info("not a depot server: the garage is not built")
			return
		end
		local ok, errors = DepotLayoutRules.validate(LAYOUT)
		assert(ok, `depot layout is invalid:\n{table.concat(errors, "\n")}`)
		built = DepotBuildSystem.build(
			LAYOUT,
			DepotLayoutConstants.ORIGIN,
			DepotContractUtils.boardLines(contract, ShiftConstants.QUOTA)
		)
		refreshLabels()
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= DepotLayoutConstants.LABEL_INTERVAL then
				elapsed = 0
				refreshLabels()
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
		log:info(`depot built: {#LAYOUT.trucks} trucks, tonight's contract {contract.id}`)
	end,

	stop = function(_self)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		QueueServiceServer:setDepartData(nil)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, nil)
		local current = built
		if current ~= nil then
			current.model:Destroy()
			built = nil
		end
	end,

	--[=[
		Where the `index`-th player appears in the depot (wrapping over the spawn points).
	]=]
	spawnCFrame = function(_self, index)
		local spawns = LAYOUT.spawns
		local point = spawns[(math.max(index, 1) - 1) % #spawns + 1]
		return DepotLayoutConstants.ORIGIN * CFrame.new(point.x, DepotLayoutConstants.SPAWN_HEIGHT, point.z)
	end,

	contract = function(_self)
		return contract
	end,

	getState = function(_self)
		local current = built
		return {
			built = current ~= nil,
			trucks = if current ~= nil then #current.trucks else 0,
			contract = contract.id,
			mode = QueueServiceServer:mode(),
			role = QueueServiceServer:role() or "none",
			cardsSent = cardsSent,
			cardsPinned = cardsPinned,
		}
	end,
}

return DepotServiceServer
```

Implementer notes (verify, do not guess):
- `payload.contract` indexes `QueuePayload`'s string indexer (`string | number | boolean`); `DepotContractUtils.resolve` takes `unknown`.
- The signal `Connect` return values are only ever `:Disconnect()`ed (the ShiftServiceServer `phases:Disconnect()` pattern); do not annotate their type.
- `getState`'s narrow return type is deliberate (no `any`); if `ServiceController`'s service type demands `{ [string]: any }`, check its declaration and report rather than adding `any`.
- `self:spawnCFrame(index)` inside the arrival-point closure: `start` takes `self` (not `_self`) for this.

- [ ] **Step 4: Exemptions.** In `SpecRoots.luau`, after the Task 1 Depot entries, add:

```lua
	["ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Depot.Systems.DepotBuildSystem"] = "Instance builder (the layout is validated by the specced DepotLayoutRules)",
	["ServerScriptService.Features.Depot.DepotServiceServer"] = "Players/RunService/ByteNet/Queue-signal shell (layout rules, contract utils and the result card are specced)",
```

- [ ] **Step 5: Module map, format, gate, commit:**

```bash
git add src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Shared/Features/Depot/Net/DepotEvents.luau src/ServerScriptService/Features/Depot/Systems/DepotBuildSystem.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src/ReplicatedStorage/Shared/Features/Depot src/ServerScriptService/Features/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
bash .superpowers/sdd/gate.sh
git commit -m "feat(depot): graybox garage, truck queue pads, boards, travel and result cards"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Controller: Studio TestEZ** (`RunTests = true`). Expected: everything passes; `assertAllModulesSpecced` passes with the three new exemptions.

- [ ] **Step 7: Controller: Studio verification** (Play Solo, `RunTests = false`). Until Task 5 the M1/M2 shift still starts on its own and moves the player into the office at its start, so the script waits for that first. Insert this server **Script** in Workspace named `DepotVerify`, Play, read Output, Stop, delete it:

```lua
-- DepotVerify: temporary Studio check for the depot server side (delete after the run).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Depot = require(ServerScriptService.Features.Depot.DepotServiceServer)
local Queue = require(ServerScriptService.Features.Queue.QueueServiceServer)
local Shift = require(ServerScriptService.Features.Shift.ShiftServiceServer)

local function check(label, ok, detail)
	print(`[{if ok then "PASS" else "FAIL"}] {label}{if detail ~= nil then " (" .. tostring(detail) .. ")" else ""}`)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
-- Pre-M4 shift logic: wait for its start (it moves the player once), then test undisturbed.
local deadline = os.clock() + 20
while Shift:getShift().phase ~= "running" and os.clock() < deadline do
	task.wait(0.25)
end
task.wait(1)

local model = workspace:FindFirstChild("CleanupCrewDepot")
check("the depot is built", model ~= nil)
check("Queue runs locally in Studio", Queue:mode() == "local", Queue:mode())
check("the depot sits far from the office", model ~= nil and model:GetPivot().Position.X < -900, model and model:GetPivot().Position)
local pads = {}
for _, tagged in CollectionService:GetTagged("QueuePad") do
	if model ~= nil and tagged:IsDescendantOf(model) then
		table.insert(pads, tagged)
	end
end
table.sort(pads, function(a, b)
	return a.Position.X < b.Position.X
end)
check("three truck beds are queue pads", #pads == 3, #pads)
check("pads hold 4 and go to the shift", pads[1] ~= nil and pads[1]:GetAttribute("QueueCapacity") == 4 and pads[1]:GetAttribute("QueueDestination") == "shift")
local state = Depot:getState()
check("tonight's contract is chosen", type(state.contract) == "string", state.contract)
local board = model and model:FindFirstChild("Boards") and model.Boards:FindFirstChild("ContractText")
check("the contract board names the job", board ~= nil and string.find(board.Text.Text, "TONIGHT'S CONTRACT", 1, true) ~= nil)

character:PivotTo(pads[1].CFrame + Vector3.new(0, 4, 0))
task.wait(1.5)
check("Queue sees the player aboard truck 1", Queue:padOf(player) == pads[1])
local label = pads[1].Parent:FindFirstChild("PadLabel")
check("the truck label counts the player", label ~= nil and string.find(label.Text.Text, "1/4 aboard", 1, true) ~= nil, label and label.Text.Text)

local departed, arrivedPayload = false, nil
Queue.departing:Connect(function()
	departed = true
end)
Queue.arrived:Connect(function(_party, payload)
	arrivedPayload = payload
end)
check("Depart now", Queue:departNow(player))
task.wait(1.5)
check("the party departed", departed)
check("the party arrived with tonight's contract id", arrivedPayload ~= nil and arrivedPayload.contract == state.contract, arrivedPayload and arrivedPayload.contract)
check("two travel cards were sent (drive, arrival)", Depot:getState().cardsSent >= 2, Depot:getState().cardsSent)

Queue:returnParty({ player }, "depot", { v = 99, client = "x" })
task.wait(1.5)
check("a forged card pins nothing", player.PlayerGui:FindFirstChild("DepotResultCard") == nil)
check("the return trip moved the player to the depot", (player.Character:GetPivot().Position - Depot:spawnCFrame(1).Position).Magnitude < 8)
Queue:returnParty({ player }, "depot", {
	v = 1, client = "Harlow & Finch Ltd.", shift = 1, outcome = "clockout", quota = 350, cleared = 380,
	bonus = 95, salvage = 3, piles = 12, catches = 1, met = true, crew = 1, c1n = player.DisplayName,
	c1b = 200, awards = 0,
})
task.wait(1.5)
local card = player.PlayerGui:FindFirstChild("DepotResultCard")
check("the result card is pinned for this player", card ~= nil)
check("it shows the review", card ~= nil and string.find(card.Text.Text, "Cleared 380 / 350 - QUOTA MET", 1, true) ~= nil)
player.Character.Humanoid.Health = 0
player.CharacterAdded:Wait()
task.wait(1)
check("the card survives a respawn", player.PlayerGui:FindFirstChild("DepotResultCard") ~= nil)
```

Studio verification checklist:
1. Every line prints `[PASS]`.
2. Server Output also shows Queue's expected warning `no arrival point for role "shift"; players stay where they are` (the shift's arrival point arrives in Task 5) and `depot built: 3 trucks, tonight's contract harlow-finch-<n>`.
3. Screenshot from above the depot (x ≈ −950, z ≈ 36): a walled grey garage, three dark truck beds with white cabs behind, a label over each bed ("TRUCK 1 / 0/4 aboard / Stand in the bed to join"), the contract board's text, the result board's "PERFORMANCE REVIEWS" title and the player's card on it.
4. While standing on truck 1, Queue's placeholder pad widget (bottom centre) shows "1/4 aboard", "Leaving in 15s" counting down.
5. No errors in server or client Output from Depot or Queue.

---

### Task 4: Travel cards on the client

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau` + `DepotStore.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.luau` + `DepotCardPanel.story.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCard.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (three exemptions)

**Interfaces:**
- Consumes: `DepotTypes.CardKind / CardMessage / ShownCard`, `DepotConstants.DRIVE_CARD_SECONDS / ARRIVAL_CARD_SECONDS / MAX_QUEUED_CARDS / HUD_ORDER` (Task 1); `DepotEvents.packets.Card` (Task 3); `HudRegistry.register(key, widget, order)` / `has(key)`; `Panel` primitive (`title?, children?`); `Tokens`; `Charm.atom`; `ReactCharm.useAtom`.
- Produces (DepotStore): `card` (Charm atom of `ShownCard?`), `show(kind: string, title: string, body: string, now: number) -> boolean`, `expire(now: number)`, `clear()`.
- Produces (DepotServiceClient): registers HUD widget `depotCard` (order 950).
- Produces (UI): `DepotCardPanel(props: { kind: string, title: string, body: string })`, `DepotCard()` (HUD widget).

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotStore = require(script.Parent.DepotStore)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local DRIVE = DepotConstants.DRIVE_CARD_SECONDS
local ARRIVAL = DepotConstants.ARRIVAL_CARD_SECONDS

return function()
	afterEach(function()
		DepotStore.clear()
	end)

	it("shows a card for its kind's time", function()
		expect(DepotStore.show("drive", "On the road", "Heading out", 10)).to.equal(true)
		local card = DepotStore.card()
		expect(card.kind).to.equal("drive")
		expect(card.title).to.equal("On the road")
		expect(card.body).to.equal("Heading out")
		expect(card.expiresAt).to.equal(10 + DRIVE)
	end)

	it("ignores an unknown kind", function()
		expect(DepotStore.show("party", "x", "y", 0)).to.equal(false)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("keeps the card until its time is up, then clears it", function()
		DepotStore.show("arrival", "Harlow & Finch Ltd.", "Clear it.", 10)
		DepotStore.expire(10 + ARRIVAL - 0.1)
		expect(DepotStore.card() ~= nil).to.equal(true)
		DepotStore.expire(10 + ARRIVAL)
		expect(DepotStore.card()).to.equal(nil)
	end)

	it("queues a card that arrives while another shows, then shows it in full", function()
		DepotStore.show("drive", "On the road", "Heading out", 10)
		DepotStore.show("arrival", "Harlow & Finch Ltd.", "Clear it.", 11)
		expect(DepotStore.card().kind).to.equal("drive")
		DepotStore.expire(10 + DRIVE)
		local card = DepotStore.card()
		expect(card.kind).to.equal("arrival")
		expect(card.expiresAt).to.equal(10 + DRIVE + ARRIVAL)
	end)

	it("drops the oldest queued card past the limit", function()
		DepotStore.show("drive", "first", "", 0)
		for index = 1, DepotConstants.MAX_QUEUED_CARDS + 1 do
			DepotStore.show("arrival", tostring(index), "", 1)
		end
		DepotStore.expire(DRIVE)
		expect(DepotStore.card().title).to.equal("2")
	end)

	it("replaces a card whose time has passed without waiting", function()
		DepotStore.show("drive", "old", "", 0)
		DepotStore.show("arrival", "new", "", DRIVE + 1)
		expect(DepotStore.card().title).to.equal("new")
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: `DepotStore.spec` errors (module missing).

- [ ] **Step 3: The store** `src/ReplicatedStorage/Client/Features/Depot/State/DepotStore.luau`:

```lua
--!strict
--[=[
	DepotStore: the travel card this client shows (the drive card when its truck leaves, the arrival card at
	the office; Cleanup Crew spec §3 steps 2-3). `card` is a Charm atom the HUD widget reads; `show` takes a
	card from the server (DepotEvents.Card), checks its kind and queues it behind a card still on screen (at
	most MAX_QUEUED_CARDS wait; the oldest is dropped); `expire` moves on once a card's time is up. Times are
	os.clock(). A mirror of what the server sent; nothing here is sent back.

	@class DepotStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

type Pending = {
	kind: DepotTypes.CardKind,
	title: string,
	body: string,
}

local initialCard: DepotTypes.ShownCard? = nil
local card = Charm.atom(initialCard)
local pending: { Pending } = {}

local function kindOf(value: string): DepotTypes.CardKind?
	if value == "drive" then
		return "drive"
	elseif value == "arrival" then
		return "arrival"
	end
	return nil
end

local function secondsFor(kind: DepotTypes.CardKind): number
	if kind == "drive" then
		return DepotConstants.DRIVE_CARD_SECONDS
	end
	return DepotConstants.ARRIVAL_CARD_SECONDS
end

local function present(entry: Pending, now: number)
	card({ kind = entry.kind, title = entry.title, body = entry.body, expiresAt = now + secondsFor(entry.kind) })
end

local DepotStore = {
	card = card,
}

-- Shows (or queues) a card from the server. False, and nothing shown, for an unknown kind.
function DepotStore.show(kind: string, title: string, body: string, now: number): boolean
	local parsed = kindOf(kind)
	if parsed == nil then
		return false
	end
	local entry: Pending = { kind = parsed, title = title, body = body }
	local current = card()
	if current == nil or now >= current.expiresAt then
		present(entry, now)
		return true
	end
	if #pending >= DepotConstants.MAX_QUEUED_CARDS then
		table.remove(pending, 1)
	end
	table.insert(pending, entry)
	return true
end

-- Once the card's time is up: the next queued card, or none.
function DepotStore.expire(now: number)
	local current = card()
	if current == nil or now < current.expiresAt then
		return
	end
	local nextCard = table.remove(pending, 1)
	if nextCard ~= nil then
		present(nextCard, now)
	else
		card(nil)
	end
end

function DepotStore.clear()
	table.clear(pending)
	card(nil)
end

return DepotStore
```

- [ ] **Step 4: The presentational card** `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.luau`:

```lua
--!strict
--[=[
	DepotCardPanel: the placeholder travel card: a kicker ("ON THE ROAD" / "ARRIVAL"), a title and a line of
	text, centred on screen. Presentational only (props in). Plain on purpose: the final drive and arrival
	cards are designed and approved in Figma first (Cleanup Crew spec §7 "UI approval") and replace this.

	@class DepotCardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)

local e = React.createElement

export type DepotCardPanelProps = {
	kind: string,
	title: string,
	body: string,
}

local WIDTH = 420
local KICKER: { [string]: string } = {
	drive = "ON THE ROAD",
	arrival = "ARRIVAL",
}

local function line(order: number, text: string, size: number, color: Color3, font: Enum.Font): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})
end

local function DepotCardPanel(props: DepotCardPanelProps): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, {
			children = {
				layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, Tokens.space.sm),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				kicker = line(
					1,
					KICKER[props.kind] or string.upper(props.kind),
					Tokens.textSize.sm,
					Tokens.color.accent,
					Tokens.font.bold
				),
				title = line(2, props.title, Tokens.textSize.xxl, Tokens.color.text, Tokens.font.bold),
				body = line(3, props.body, Tokens.textSize.lg, Tokens.color.textMuted, Tokens.font.body),
			},
		}),
	})
end

return DepotCardPanel
```

`src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCardPanel.story.luau`:

```lua
--!strict
--[=[
	DepotCardPanel.story: the placeholder travel card in Studio's edit mode (UI Labs).

	@class DepotCardPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Arrival = true,
	},
}, function(props)
	local arrival = props.controls.Arrival
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		card = e(DepotCardPanel, {
			kind = if arrival then "arrival" else "drive",
			title = if arrival then "Harlow & Finch Ltd." else "On the road",
			body = if arrival
				then "Clear the office before the sale. Clear 350 of trash. The bank says the building is empty."
				else "Heading to Harlow & Finch Ltd.",
		}),
	})
end)
```

- [ ] **Step 5: The HUD widget** `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotCard.luau`:

```lua
--!strict
--[=[
	DepotCard: the travel-card HUD widget (registered by DepotServiceClient). Draws DepotCardPanel while
	DepotStore holds a card; DepotServiceClient moves the store on as cards expire.

	@class DepotCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)

local function DepotCard(): React.ReactNode
	local card = ReactCharm.useAtom(DepotStore.card)
	if card == nil then
		return nil
	end
	return React.createElement(DepotCardPanel, { kind = card.kind, title = card.title, body = card.body })
end

return DepotCard
```

- [ ] **Step 6: The client service** `src/ReplicatedStorage/Client/Features/Depot/DepotServiceClient.luau`:

```lua
--!strict
--[=[
	DepotServiceClient: the depot on this client. Registers the travel-card HUD widget (DepotCard) during init,
	takes the server's cards (DepotEvents.Card) into DepotStore and moves the card on as its time runs out.
	The pad countdown and Depart now are Queue's own placeholder widget; the boards and truck labels are
	world billboards the server builds.

	Spec-exempt shell (ByteNet, HUD registration, RunService); the card queue is the specced DepotStore.

	@class DepotServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local DepotCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard)

local HUD_KEY = "depotCard"

local stoppers: { () -> () } = {}

export type DepotServiceClient = {
	dependencies: { string },
	init: (self: DepotServiceClient) -> (),
	start: (self: DepotServiceClient) -> (),
	stop: (self: DepotServiceClient) -> (),
	getState: (self: DepotServiceClient) -> { [string]: string | number | boolean },
}

local DepotServiceClient: DepotServiceClient = {
	dependencies = {},

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, DepotCard, DepotConstants.HUD_ORDER)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			DepotEvents.packets.Card.listen(function(data: DepotTypes.CardMessage)
				DepotStore.show(data.kind, data.title, data.body, os.clock())
			end)
		)
		local ticking = RunService.Heartbeat:Connect(function()
			if DepotStore.card() ~= nil then
				DepotStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		DepotStore.clear()
	end,

	getState = function(_self)
		local card = DepotStore.card()
		return { card = if card ~= nil then card.kind else "none" }
	end,
}

return DepotServiceClient
```

Implementer notes: `table.insert(stoppers, <packet>.listen(...))` mirrors `ShiftServiceServer.start` exactly (ByteNetMax's `listen` returns its disconnect function at runtime, `packet.luau:101`); if luau-lsp rejects it on the client, report it instead of casting. The listen callback's parameter annotation `DepotTypes.CardMessage` has the struct's exact shape.

- [ ] **Step 7: Exemptions.** In `SpecRoots.luau`, after the Task 3 Depot entries, add:

```lua
	["ReplicatedStorage.Client.Features.Depot.DepotServiceClient"] = "ByteNet/HUD registration/RunService shell (DepotStore is specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel"] = "React UI component (placeholder; story in DepotCardPanel.story)",
	["ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard"] = "React HUD widget wiring DepotStore to DepotCardPanel (no logic)",
```

- [ ] **Step 8: Module map, format, gate, commit:**

```bash
git add src/ReplicatedStorage/Client/Features/Depot src/ReplicatedStorage/Client/UI/React/Screens/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ReplicatedStorage/Client/Features/Depot src/ReplicatedStorage/Client/UI/React/Screens/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src/ReplicatedStorage/Client/Features/Depot src/ReplicatedStorage/Client/UI/React/Screens/Depot src/ServerScriptService/Core/Testing/SpecRoots.luau
bash .superpowers/sdd/gate.sh
git commit -m "feat(depot): drive and arrival cards on the client"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 9: Controller: Studio TestEZ and UI Labs.** `RunTests = true`: `DepotStore.spec` (6 cases) passes, `assertAllModulesSpecced` passes. Open `DepotCardPanel.story` in UI Labs (edit mode): "ARRIVAL" / "Harlow & Finch Ltd." / the body, centred; toggling Arrival off shows "ON THE ROAD" / "On the road" / "Heading to Harlow & Finch Ltd.".

- [ ] **Step 10: Controller: Studio verification** (Play Solo, `RunTests = false`). Insert a client **LocalScript** `CardVerify` in `StarterPlayer.StarterPlayerScripts`:

```lua
-- CardVerify: temporary Studio check for the travel cards (delete after the run).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
Charm.subscribe(DepotStore.card, function(card)
	print("[CARD]", if card then card.kind else "none", if card then card.title else "")
end)
```
and a server **Script** `CardDepart` in Workspace:

```lua
-- CardDepart: temporary; puts the player on truck 1 and departs (delete after the run).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Queue = require(game:GetService("ServerScriptService").Features.Queue.QueueServiceServer)
local Shift = require(game:GetService("ServerScriptService").Features.Shift.ShiftServiceServer)
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local deadline = os.clock() + 20
while Shift:getShift().phase ~= "running" and os.clock() < deadline do
	task.wait(0.25)
end
task.wait(1)
local model = workspace:WaitForChild("CleanupCrewDepot")
for _, pad in CollectionService:GetTagged("QueuePad") do
	if pad:IsDescendantOf(model) and pad.Parent.Name == "truck1" then
		player.Character:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
	end
end
task.wait(1)
print("[DEPART]", Queue:departNow(player))
```
Studio verification checklist:
1. Client Output: `[CARD] drive On the road`, about 3 s later `[CARD] arrival Harlow & Finch Ltd.`, about 5 s after that `[CARD] none`.
2. Screenshots: during the first 3 s a centred panel "ON THE ROAD / On the road / Heading to Harlow & Finch Ltd."; then "ARRIVAL / Harlow & Finch Ltd. / <job> Clear 350 of trash. <note>"; then nothing. Toasts still draw above the card.
3. No client or server errors from Depot or Queue.

---

### Task 5: The crew and the return trip (Shift)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (by anchor, see Step 3)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau` (one key)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (one exemption)

**Interfaces:**
- Consumes: Task 1 (`DepotConstants.ROLE_DEPOT / ROLE_SHIFT / CONTRACTS`, `DepotContractUtils.tonight / resolve`, `DepotTypes.Contract`), Task 2 (`ShiftCrewTracker`, `ShiftCardUtils.encode`), Task 3 (`DepotServiceServer:spawnCFrame`); Queue: `QueueServiceServer.arrived / joinedLate / returned`, `:configure({ homeRole })`, `:setArrivalPoint(role, resolver)`, `:returnParty(players, role, payload) -> boolean`, `:runsRole(role)`, `:mode()`, `:role()`, `QueuePlaceRules.isReservedServer(privateServerId, privateServerOwnerId)`; `OfficeServiceServer:spawnCFrame(index)`; `ToastServiceServer:send`; `RoundTypes.RoundConfig.eligible`.
- Produces (ShiftTripSystem): `ShiftTripSystem.new() -> ShiftTripSystem` with plain function fields `eligible: (player: Player) -> boolean` and `spawnFor: (player: Player) -> CFrame?`, and methods `start(onChanged: () -> ())`, `stop()`, `crew() -> { Player }`, `crewIds(except: number?) -> { number }`, `startable(now: number) -> number`, `sendHome(results: ShiftTypes.ShiftResults?, shift: number, now: number) -> boolean`, `isLeaving(now: number) -> boolean`.
- Produces (ShiftConstants): `RETURN_WAIT_SECONDS = 40`.
- Produces (ShiftServiceServer): unchanged public API; `getState` gains `crew: number`, `leaving: boolean`. Behaviour: a shift starts only for a crew present; only crew members vote; Round participants are the crew; Back to depot sends the crew home with the result card; spawns follow `ShiftTripSystem.spawnFor`.

- [ ] **Step 1: The constant.** In `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`, inside the frozen table, immediately before the `-- HUD widget order` comment, add:

```lua
	-- After Back to depot: how long the crew may still be here (Queue's return trip retries 1 + 2 + 4 s and
	-- waits up to 15 s per try) before the trip counts as failed and the next shift may start.
	RETURN_WAIT_SECONDS = 40,
```

- [ ] **Step 2: The trip system** `src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau`:

```lua
--!strict
--[=[
	ShiftTripSystem: the shift's half of the trip between the depot and the office (Cleanup Crew spec §3
	steps 2-3 and 7, §5, §6.5). It decides who the crew is and sends them home:

	- Queue `arrived(party, payload)`: the party joins the crew (ShiftCrewTracker.join: added to a crew still
	  here, replacing one that has gone), and the payload's contract id (untrusted: it rode the teleport) is
	  resolved by DepotContractUtils for the result card;
	- Queue `joinedLate(player)`: an expected member who came after the start joins the crew and is moved to
	  the loading bay;
	- Queue `returned(player)` on this server (a local move home in Studio) and leaving the server take a
	  player out of the crew;
	- `sendHome` is Back to depot: the result card (ShiftCardUtils.encode) rides
	  QueueServiceServer:returnParty, and the crew is "leaving" for ShiftConstants.RETURN_WAIT_SECONDS, so no
	  shift restarts under it; if crew members are still here when that ends (the trip failed after Queue's
	  retries), each is told once and `startable` lets the next shift begin.

	It also gives Queue the loading bay as the shift's local-move arrival point and the depot as the home of
	redirected strangers, and on a live PUBLIC server of the shift place (someone reached it without a
	party; reserved servers are Queue's) it sends every player to the depot. ShiftServiceServer hands Round
	`eligible` (only the crew takes part) and Death `spawnFor` (crew in the loading bay; anyone else at the
	depot where this server runs it, otherwise in the loading bay).

	Spec-exempt shell (Players, Queue signals, teleports); membership and the leaving window are the specced
	ShiftCrewTracker, the card is the specced ShiftCardUtils, the contract the specced DepotContractUtils.

	@class ShiftTripSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotContractUtils = require(ServerScriptService.Features.Depot.Utils.DepotContractUtils)
local DepotServiceServer = require(ServerScriptService.Features.Depot.DepotServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local QueuePlaceRules = require(ServerScriptService.Features.Queue.Rules.QueuePlaceRules)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftCrewTracker = require(ServerScriptService.Features.Shift.State.ShiftCrewTracker)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type QueuePayload = QueueTypes.QueuePayload

local STUCK_TEXT = "The truck couldn't get back to the depot. Another shift it is."
local REFUSED_TEXT = "The truck can't leave right now. Starting another shift."

export type ShiftTripSystem = {
	-- Round's `eligible`: only the crew takes part in a run. A plain function, handed over as it is.
	eligible: (player: Player) -> boolean,
	-- Death's spawn resolver. A plain function, handed over as it is.
	spawnFor: (player: Player) -> CFrame?,
	start: (self: ShiftTripSystem, onChanged: () -> ()) -> (),
	stop: (self: ShiftTripSystem) -> (),
	crew: (self: ShiftTripSystem) -> { Player },
	crewIds: (self: ShiftTripSystem, except: number?) -> { number },
	startable: (self: ShiftTripSystem, now: number) -> number,
	sendHome: (self: ShiftTripSystem, results: ShiftTypes.ShiftResults?, shift: number, now: number) -> boolean,
	isLeaving: (self: ShiftTripSystem, now: number) -> boolean,
}

local log = Logger.new("ShiftTripSystem")

-- UserIds in the server, without `except` (a player who is leaving: Players still lists them in PlayerRemoving).
local function presentIds(except: number?): { number }
	local ids: { number } = {}
	for _, player in Players:GetPlayers() do
		if player.UserId ~= except then
			table.insert(ids, player.UserId)
		end
	end
	return ids
end

local function idsOf(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function playersOf(userIds: { number }): { Player }
	local list: { Player } = {}
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

-- A live public server of the shift place: nobody should be here without a party.
local function isPublicShiftServer(): boolean
	return QueueServiceServer:mode() == "live"
		and QueueServiceServer:role() == DepotConstants.ROLE_SHIFT
		and not QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId)
end

local ShiftTripSystem = {}

function ShiftTripSystem.new(): ShiftTripSystem
	local members = ShiftCrewTracker.new()
	local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
	local changed: () -> () = function() end
	local stoppers: { () -> () } = {}

	local function crewPlayers(): { Player }
		return playersOf(members:present(presentIds()))
	end

	local function toLoadingBay(player: Player)
		local character = player.Character
		local index = table.find(members:present(presentIds()), player.UserId) or 1
		if character ~= nil then
			character:PivotTo(OfficeServiceServer:spawnCFrame(index))
		end
	end

	local system: ShiftTripSystem = {
		eligible = function(player)
			return members:has(player.UserId)
		end,

		spawnFor = function(player)
			local index = table.find(members:present(presentIds()), player.UserId)
			if index ~= nil or not QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
				return OfficeServiceServer:spawnCFrame(index or 1)
			end
			return DepotServiceServer:spawnCFrame(table.find(Players:GetPlayers(), player) or 1)
		end,

		start = function(_self, onChanged)
			changed = onChanged
			QueueServiceServer:configure({ homeRole = DepotConstants.ROLE_DEPOT })
			QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_SHIFT, function(_player, index)
				return OfficeServiceServer:spawnCFrame(index)
			end)
			local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
				if #party == 0 then
					return
				end
				members:join(idsOf(party), presentIds())
				contract = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
				log:info(`a crew of {#party} arrived for {contract.id}`)
				changed()
			end)
			local late = QueueServiceServer.joinedLate:Connect(function(player)
				if members:add(player.UserId) then
					toLoadingBay(player)
					changed()
				end
			end)
			local returned = QueueServiceServer.returned:Connect(function(player, _payload)
				if members:remove(player.UserId) then
					changed()
				end
			end)
			local leaving = Players.PlayerRemoving:Connect(function(player)
				if members:remove(player.UserId) then
					changed()
				end
			end)
			table.insert(stoppers, function()
				arrived:Disconnect()
				late:Disconnect()
				returned:Disconnect()
				leaving:Disconnect()
			end)
			if isPublicShiftServer() then
				log:warn("a public server of the shift place: every player is sent to the depot")
				local function sendToDepot(player: Player)
					QueueServiceServer:returnParty({ player }, DepotConstants.ROLE_DEPOT, {})
				end
				for _, player in Players:GetPlayers() do
					sendToDepot(player)
				end
				local joining = Players.PlayerAdded:Connect(sendToDepot)
				table.insert(stoppers, function()
					joining:Disconnect()
				end)
			end
		end,

		stop = function(_self)
			for _, stopFn in stoppers do
				stopFn()
			end
			table.clear(stoppers)
			QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_SHIFT, nil)
			members:clear()
		end,

		crew = function(_self)
			return crewPlayers()
		end,

		crewIds = function(_self, except)
			return members:present(presentIds(except))
		end,

		startable = function(_self, now)
			if members:expired(now) then
				local stuck = crewPlayers()
				for _, player in stuck do
					ToastServiceServer:send(player, { text = STUCK_TEXT, duration = 5 })
				end
				if #stuck > 0 then
					log:warn(`{#stuck} crew member(s) never left for the depot; the next shift may start`)
				end
			end
			return members:startable(presentIds(), now)
		end,

		sendHome = function(_self, results, shift, now)
			local players = crewPlayers()
			if #players == 0 then
				return false
			end
			local payload: QueuePayload = {}
			if results ~= nil then
				payload = ShiftCardUtils.encode(results, { client = contract.client, shift = shift })
			end
			if not QueueServiceServer:returnParty(players, DepotConstants.ROLE_DEPOT, payload) then
				for _, player in players do
					ToastServiceServer:send(player, { text = REFUSED_TEXT, duration = 5 })
				end
				return false
			end
			members:leave(now, ShiftConstants.RETURN_WAIT_SECONDS)
			changed()
			return true
		end,

		isLeaving = function(_self, now)
			return members:isLeaving(now)
		end,
	}
	return system
end

return ShiftTripSystem
```

- [ ] **Step 3: Wire it into ShiftServiceServer** (`src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`). Make exactly these edits, located by their anchors (Task 0 Step 2 confirmed each one exists; M2 may have changed the lines around them, never these):

  1. **Require** (beside the other `ShiftServer` requires):
     ```lua
     local ShiftTripSystem = require(ShiftServer.Systems.ShiftTripSystem)
     ```
  2. **Module state:** immediately after the `local roster = ShiftRosterTracker.new()` line (if it does not exist, after `local stoppers: { () -> () } = {}`), add:
     ```lua
     -- The crew and the trips between the depot and the office (Queue); only the crew starts, takes part and votes.
     local trip = ShiftTripSystem.new()
     ```
  3. **`presentIds`:** replace the whole function (its comment and body, which loop over `Players:GetPlayers()`) with:
     ```lua
     -- The crew members in the server (`except`: one who is leaving; Players still lists them during PlayerRemoving).
     local function presentIds(except: number?): { number }
     	return trip:crewIds(except)
     end
     ```
     (Its callers, the vote tally in `publish`, `resolveVote` and `getState`, stay as they are.)
  4. **`buildResults`:** in its loop that lists everyone taking part, replace `RoundServiceServer:participants()` with `trip:crew()` (so an expected member who came late is listed). Leave every other `participants()` call (`beginRun`'s pivot, M2's `catchTotal`) unchanged.
  5. **`resolveVote`:** replace the whole `if decision == "depot" then … end` block (M1's "The depot opens in a later build" toast) with:
     ```lua
     	-- Back to depot: the crew rides home with the review; if the trip is refused, the reset is another shift.
     	if decision == "depot" then
     		trip:sendHome(results, state.shift, now())
     	end
     ```
     It must stay **before** the `finishReset()` call that follows (finishReset clears `results`).
  6. **`step`:** replace `ShiftPhaseRules.tick(state, now(), #Players:GetPlayers())` with `ShiftPhaseRules.tick(state, now(), trip:startable(now()))`.
  7. **`dependencies`:** add `"QueueServiceServer",` and `"DepotServiceServer",` to the list.
  8. **`start`:** in the `RoundServiceServer:configure({ ... })` table, after `lateJoin = true,`, add `eligible = trip.eligible,`. Replace the whole `DeathServiceServer:setSpawnPoint(function(player) … end)` call with:
     ```lua
     		DeathServiceServer:setSpawnPoint(trip.spawnFor)
     ```
     and immediately after it add:
     ```lua
     		trip:start(publish)
     ```
  9. **`stop`:** before `DeathServiceServer:setSpawnPoint(nil)`, add `trip:stop()`.
  10. **`getState`:** add `crew = #trip:crewIds(),` and `leaving = trip:isLeaving(now()),` to the returned table.
  11. **Header comment:** replace the results bullet's "(the depot is M4: until then both reset in this server)" with "(Back to depot sends the crew home through ShiftTripSystem with the review as its result card)", and add a bullet: `- the crew (M4): a shift starts only for the party that arrived through the Queue (ShiftTripSystem); only the crew takes part in Round's run, votes and respawns in the loading bay.`

  After the edits: if selene reports `Players` unused, it is not (PlayerRemoving still uses it); if it reports `OfficeServiceServer` unused, it is not (`beginRun`). Check the file length:
  ```bash
  python3 -c "import sys; sys.path.insert(0,'scripts/python'); import check_file_length as c; print(c.count_code_lines(open('src/ServerScriptService/Features/Shift/ShiftServiceServer.luau',encoding='utf8').read()))"
  ```
  Expected: no more than Task 0's count + 2 (the edits remove about as many code lines as they add) and ≤ 400. If it is over 400, stop and report: do not move unrelated code without the controller.

- [ ] **Step 4: Exemption.** In `SpecRoots.luau`, in the `-- Cleanup Crew: Shift` block, after the `ShiftServiceServer` entry, add:

```lua
	["ServerScriptService.Features.Shift.Systems.ShiftTripSystem"] = "Players/Queue-signal/teleport shell (ShiftCrewTracker, ShiftCardUtils and DepotContractUtils are specced)",
```

- [ ] **Step 5: Module map, format, gate, commit:**

```bash
git add src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
stylua src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
git add src/ServerScriptService/Features/Shift src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
bash .superpowers/sdd/gate.sh
git commit -m "feat(shift): the crew arrives by truck and rides home with its review"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Controller: Studio TestEZ** (`RunTests = true`). Expected: everything passes (no spec changed; `ShiftPhaseRules.tick`'s cases still hold because only its caller's count changed).

- [ ] **Step 7: Controller: Studio verification, the whole loop** (Play Solo, `RunTests = false`). Insert this server **Script** in Workspace named `TripVerify` (keep Task 4's `CardVerify` LocalScript out; screenshots cover the cards):

```lua
-- TripVerify: temporary Studio check for the depot -> shift -> depot loop (delete after the run).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Depot = require(ServerScriptService.Features.Depot.DepotServiceServer)
local Office = require(ServerScriptService.Features.Office.OfficeServiceServer)
local Queue = require(ServerScriptService.Features.Queue.QueueServiceServer)
local Round = require(ServerScriptService.Features.Round.RoundServiceServer)
local Shift = require(ServerScriptService.Features.Shift.ShiftServiceServer)

local function check(label, ok, detail)
	print(`[{if ok then "PASS" else "FAIL"}] {label}{if detail ~= nil then " (" .. tostring(detail) .. ")" else ""}`)
end
local function near(model, cframe)
	return model ~= nil and (model:GetPivot().Position - cframe.Position).Magnitude < 8
end
local function waitFor(predicate, seconds)
	local deadline = os.clock() + seconds
	while not predicate() and os.clock() < deadline do
		task.wait(0.25)
	end
	return predicate()
end
local function respawn(player)
	local old = player.Character
	old.Humanoid.Health = 0
	waitFor(function()
		return player.Character ~= nil and player.Character ~= old
	end, 15)
	task.wait(1)
	return player.Character
end
local function truck1()
	for _, pad in CollectionService:GetTagged("QueuePad") do
		if pad.Parent ~= nil and pad.Parent.Name == "truck1" then
			return pad
		end
	end
	return nil
end
local function board(player)
	player.Character:PivotTo(truck1().CFrame + Vector3.new(0, 4, 0))
	task.wait(1)
	return Queue:departNow(player)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local _ = player.Character or player.CharacterAdded:Wait()
task.wait(8)

-- 1-3: nobody is crew yet
check("1 no shift starts without a crew", Shift:getShift().phase == "lobby", Shift:getShift().phase)
check("2 the player spawned at the depot", near(player.Character, Depot:spawnCFrame(1)))
check("3 a depot player respawns at the depot", near(respawn(player), Depot:spawnCFrame(1)))

-- 4-6: the trip out
check("4 departing truck 1", board(player))
check("5 moved to the loading bay", waitFor(function()
	return near(player.Character, Office:spawnCFrame(1))
end, 5))
check("5b one crew member", waitFor(function()
	return Shift:getState().crew == 1
end, 3), Shift:getState().crew)
check("6 the shift runs with the crew as Round's participant", waitFor(function()
	return Shift:getShift().phase == "running"
end, 12) and Round:isParticipant(player))
check("6b a crew member respawns in the loading bay", near(respawn(player), Office:spawnCFrame(1)))

-- 7-8: Back to depot
Shift:clockOut(player)
check("7 results after clocking out", waitFor(function()
	return Shift:getShift().phase == "results"
end, 15))
Shift:vote(player, "depot")
check("8 back at the depot", waitFor(function()
	return near(player.Character, Depot:spawnCFrame(1))
end, 5))
check("8b the result card is pinned", waitFor(function()
	return player.PlayerGui:FindFirstChild("DepotResultCard") ~= nil
end, 5))
check("8c no longer crew", waitFor(function()
	return Shift:getState().crew == 0
end, 3), Shift:getState().crew)
task.wait(6)
check("8d no shift restarts at the depot", Shift:getShift().phase == "lobby", Shift:getShift().phase)
check("8e Round has no participant", not Round:isParticipant(player))

-- 9-10: Another shift keeps the crew in the office
check("9 departing again", board(player))
check("9b running again", waitFor(function()
	return Shift:getShift().phase == "running"
end, 15))
Shift:clockOut(player)
waitFor(function()
	return Shift:getShift().phase == "results"
end, 15)
Shift:vote(player, "another")
check("10 another shift starts for the same crew", waitFor(function()
	return Shift:getShift().phase == "starting" or Shift:getShift().phase == "running"
end, 10))
check("10b still in the office", not near(player.Character, Depot:spawnCFrame(1)))
print("TripVerify done", Shift:getState().crew, Depot:getState().cardsPinned)
```

Studio verification checklist:
1. Every line prints `[PASS]`; the last line is `TripVerify done 1 1`.
2. Server Output: `a crew of 1 arrived for harlow-finch-<n>` twice; no Queue warning about a missing arrival point any more.
3. Screenshots at check 4 → 6: the drive card, then the arrival card in the loading bay during the 5 s arrival countdown, then the Shift HUD.
4. Screenshot at check 8b: the player in the depot, the result board showing their card ("Harlow & Finch Ltd. - shift 1", "Clocked out", "Cleared …", …) and the toast "Back at the depot. Your performance review is pinned on the board.".
5. The results panel disappears when the player is moved home; the Shift HUD is not drawn in the depot after the vote.
6. With M2's Harlow: he spawns only when the shift runs and is gone after the vote (no Harlow in the office while the player waits at the depot).
7. No errors in server or client Output from Shift, Depot, Queue, Office, Occupant or Cargo across the run.
8. Optional (if time): `Queue:configure({ forceLive = true })` from the command bar during Play is **not** a valid failure test here (both roles are placeholders, which route locally even when forced); the failed-return fallback is covered by `ShiftCrewTracker.spec` and the live walkthrough.
9. Review the code path for Review Focus 2 by reading `ShiftTripSystem.startable` / `sendHome` against `ShiftCrewTracker.spec` "leaving" cases (the fallback cannot be triggered in Studio).

---

### Task 6: Docs, the publish walkthrough, full run, PR

**Files:**
- Create: `docs/cleanup-crew-publish.md`
- Modify: `docs/project-structure.md` (the game-features note)
- Modify: `docs/ROADMAP.md` (the "Games on this base" row)

**Interfaces:** none new.

- [ ] **Step 1: Feature names note.** In `docs/project-structure.md`, replace the line that starts `Cleanup Crew (branch \`game/cleanup-crew\`) adds` (after M2: `… adds Cargo, Noise, Occupant, Office, Shift and Vacuum.`) with:

```markdown
Cleanup Crew (branch `game/cleanup-crew`) adds Cargo, Depot, Noise, Occupant, Office, Shift and Vacuum.
```

- [ ] **Step 2: ROADMAP row.** In `docs/ROADMAP.md`, in the "Games on this base" table, append to the Cleanup Crew row's "Built so far" cell (after the M2 sentence, before "Spec: ..."):

```markdown
M4 depot and trips: a code-built depot garage (Depot) with three truck queue pads (base Queue: 1-4 players, 15 s countdown, Depart now), tonight's contract board and a result board; drive and arrival cards; the crew is the party that arrived, the only players who start a shift, take part and vote; Back to depot rides Queue's return trip with the review as a result card pinned for each returning player; placeholder PlaceIds, so the whole loop plays in one Studio server (publish walkthrough: `docs/cleanup-crew-publish.md`).
```

- [ ] **Step 3: The walkthrough** `docs/cleanup-crew-publish.md`:

````markdown
# Cleanup Crew: publishing the depot and shift places

How to turn the Studio build (one server playing both roles) into a published experience with a depot
place and a shift place. Do this yourself; agents never publish or upload. Spec:
`docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §5.

## What you end up with

- One experience, owned by your personal account, with **two places**: the **depot** (the start place,
  public servers, the lobby) and the **shift** (reserved servers only, made by the Queue for each party).
- The same code synced to both (`rojo serve`), because one codebase plays both roles. A server learns its
  role from its PlaceId through the place-role table in
  `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau` (`PLACE_IDS`).
- While a PlaceId is `0` (the placeholder), that role is reached by a local move: a published depot place
  with `shift = 0` still plays the whole loop in one server. You can publish the depot first and add the
  shift place later.

## 1. Create the shift place

1. Open the experience's start place (the depot) in Roblox Studio.
2. **View → Asset Manager → Places**. Right-click the empty area → **Add New Place**. Name it `Shift`.
3. Double-click the new place to open it. It starts from the Baseplate template; keep the baseplate and
   its SpawnLocation (players stand in the office's loading bay anyway, but the baseplate catches anyone
   who spawns before the code moves them).
4. Turn **Team Create off** in both places while you sync and publish (Rojo and publishing are simpler
   with it off).

## 2. Fill in the PlaceIds

1. In Asset Manager → Places, right-click each place → **Copy ID to Clipboard** (or run `print(game.PlaceId)`
   in each place's command bar).
2. In `DepotConstants.luau`, set `PLACE_IDS.depot` and `PLACE_IDS.shift` to the two numbers and remove the
   two `PLACEHOLDER` comments.
3. Commit on `game/cleanup-crew` (`fix(depot): real PlaceIds for the depot and shift places`).

The two ids must differ (Queue refuses one real PlaceId playing two roles at boot).

## 3. Sync and publish both places

For **each** place (depot first, then shift):

1. Open the place in Studio.
2. In the repo: `rojo serve` (if it is not already running). In Studio: Rojo plugin → **Connect**. Wait until
   the sync finishes (ReplicatedStorage, ServerScriptService, StarterPlayer filled in; no Rojo errors).
3. Press **Play** once in Studio: Output should say `queue in local mode` (Studio is always local) and, in
   the depot place, `depot built: 3 trucks`. Stop.
4. **File → Publish to Roblox**. Disconnect Rojo.

Both places get the same code; the server decides at run time which role it plays (`queue in live mode,
role depot` / `role shift, reserved server` in the live server's Output, F9 → Server).

## 4. Let the second account in

In **Game Settings → Permissions** (or Creator Hub → the experience → Access), make the experience playable by
your second account (for example Public; Creator Hub may ask you to complete the experience questionnaire
first). Teleports between places of the same experience need no extra setting.

## 5. Test with two accounts

Use two devices or two Roblox clients signed in to different accounts. Tick each item.

- [ ] Both accounts join the experience from its page: both land in the same depot server (join the
      second through the first's profile → **Join** if Roblox splits them).
- [ ] Both stand in **truck 1**: its label says `2/4 aboard`; each sees the pad panel (`2/4 aboard`,
      `Leaving in 15s`), and the countdown restarts when the second player steps in.
- [ ] One presses **Depart now**: both see the drive card, then load into **one** reserved shift server
      together; the arrival card shows; a 5 s countdown; the shift starts in the loading bay.
- [ ] One account steps off the truck during the countdown: it leaves the party; the other departs alone.
- [ ] Close one client mid-teleport: the other arrives; the shift starts after ~20 s.
- [ ] A third account (or the second, rejoining) joins a crew member through their profile while the crew
      is still arriving: seated if there is room; once the shift has started it is sent to a depot server.
- [ ] Play to results, vote **Back to depot**: both land in a depot server (not necessarily the one you
      left), each sees **their** result card on the result board and the toast.
- [ ] Vote **Another shift**: a new shift starts in the same reserved server.
- [ ] Everyone leaves a shift server: rejoining never puts you back in it (empty servers close).
- [ ] Optional failure check: temporarily set `PLACE_IDS.shift` to a PlaceId of a place in **another**
      experience you own, publish the depot, depart: after 3 retries the party is back on the pad with
      "Couldn't leave. You're back on the pad." Put the real id back and republish.

## Troubleshooting

- **"Couldn't leave. You're back on the pad."** every time: the shift PlaceId is wrong or the shift place
  is not published.
- **Everyone plays in one server after publishing:** a PlaceId is still `0` or does not match the place
  (the Output line `queue in local mode` on a live server says so).
- **409 "Server is busy"** only concerns Open Cloud uploads (CI), not Studio publishing.
- Live logs: F9 → **Server** tab (Developer Console), as the experience owner.
- Teleports never work inside Studio; that is why Studio plays both roles locally.
````

- [ ] **Step 4: Gate**

```bash
python3 scripts/python/module_map.py --check
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.`

- [ ] **Step 5: Commit**

```bash
git add docs/cleanup-crew-publish.md docs/ROADMAP.md docs/project-structure.md
git commit -m "docs: record Cleanup Crew M4 and the publish walkthrough"
python3 scripts/python/module_map.py --check
```

- [ ] **Step 6: Controller: full TestEZ run** (`RunTests = true`). Expected: every spec passes (the five M4 specs included); `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 7: Controller: full-loop playtest** (Play Solo, `RunTests = false`, no helper scripts). Checklist:
1. Spawn in the depot; the contract board, three labelled trucks and the result board are readable from the spawn (screenshot + Qwen3-VL readability pass if available).
2. Walk onto a truck bed: the label and the pad panel count you; Depart now; drive card, arrival card, loading bay.
3. Play a short shift as in M1/M2 (vacuum, bank, Harlow), clock out, vote Back to depot: back in the depot with your card pinned and the toast.
4. Walk onto a truck again: a fresh shift (new spawns, fresh Harlow) starts; vote Another shift: a new shift without leaving the office.
5. Die in the depot (reset character): respawn in the depot; die in the office: respawn in the loading bay.
6. Server and client Output: no errors or warnings from Depot, Queue, Shift, Office, Occupant, Cargo or Vacuum across the run (Queue's `queue in local mode, role none` info line is expected).

- [ ] **Step 8: Controller: update PR #3's description (never merge).** Push, then append an M4 section (use the scratchpad for the temporary file):

```bash
git push origin game/cleanup-crew
gh pr view 3 --json body -q .body > "$SCRATCH/cc-pr-body.md"
cat >> "$SCRATCH/cc-pr-body.md" <<'EOF'

## M4: Depot, queues and the return trip

Milestone M4 of docs/superpowers/specs/2026-10-10-cleanup-crew-design.md (plan: docs/superpowers/plans/2026-10-10-m4-cleanup-crew-depot.md). Needs the base Queue feature (merged into this branch locally from `base/queue`).

- Depot: a code-built garage at x = -1000 (the office is at x = 1000) with three truck queue pads (Queue: 1-4 players, 15 s countdown reset on join, Depart now), tonight's contract board (rotating by UTC day) and a result board; layout validated by the specced DepotLayoutRules (no spawn on a pad).
- Trips: departing parties carry the contract id; drive and arrival cards (placeholder HUD widget); the crew is the party that arrived (ShiftCrewTracker): only the crew starts a shift, takes part in Round's run, votes and respawns in the loading bay; others spawn at the depot.
- Back to depot: Queue's return trip carries the review as a flat result card (ShiftCardUtils, decoded as untrusted at the depot) pinned on the result board for each returning player; a failed trip falls back to another shift after 40 s.
- Places: placeholder PlaceIds (both 0), so the whole loop plays in one Studio server; `docs/cleanup-crew-publish.md` walks through creating the shift place, filling in the ids, publishing both places and the two-account test (which also covers the Queue PR's live-only checklist).

Open questions for the developer: see the M4 plan's list (office built on the depot place too, loading-screen drive card, failed-return fallback, contracts, result-card form, Studio bystander HUD).

Verified: .superpowers/sdd/gate.sh green; TestEZ green in Studio; Studio checklists in Tasks 1-6 (solo, local mode). Not verifiable in Studio: everything in the walkthrough's two-account list.
EOF
gh pr edit 3 --body-file "$SCRATCH/cc-pr-body.md"
```
(`$SCRATCH` = the controller's scratchpad directory.) Do not merge: the developer reviews. When `base/game-hooks` and `base/queue` merge to main, rebase `game/cleanup-crew` onto main and retarget the PR (AGENTS.md: stacked branches).

---

## Open questions for the developer

Designed around in this plan; none blocks M4. Every one is a reversible game-side choice. **No approval-gated layout change** (no new subfolder kind, role word or second service).

1. **The office graybox is also built on the live depot place** (static, empty, 2000 studs from the garage, behind walls). Gating it by role edits `OfficeServiceServer.start`, which M2 rewrites; it can be a one-line guard (`QueueServiceServer:runsRole("shift")`) after M2 lands, if you want it.
2. **Drive card on the loading screen.** `TeleportService:SetTeleportGui` is typed `(gui: GuiObject)` in `globalTypes.d.luau` while Roblox's docs describe a ScreenGui, and `check_pr_rules` bans creating ScreenGuis outside `UILayerHost`. M4 shows the drive card on screen when the truck leaves (live, until the teleport takes over) and leaves the loading screen default. Worth a small base addition in M5 once verified live.
3. **A failed return trip** (after Queue's 3 retries) keeps the crew in the shift server; 40 s after the vote each player still there is told and the next shift starts. Alternative: re-try the return trip, or kick to the depot.
4. **Contracts** are three flavour texts for Harlow & Finch rotating by UTC day; the quota stays `ShiftConstants.QUOTA` (350). A contract could later carry its own quota or variant.
5. **The result card** is a world billboard on the result board that only the returning player sees (plus a toast), replaced at their next return; not a screen popup. It is placeholder until its Figma screen is approved.
6. **Studio-only quirk:** with two Studio clients where one stays at the depot, that bystander also sees the Shift HUD and results panel (the `shift` world entry is server-wide); they cannot vote or take part. Live servers never mix the roles.
7. **Three trucks** (the spec says 3–4); `DepotLayoutRules` accepts a fourth.

## Spec gaps (decided here, worth confirming)

- **"Last player out → the server closes"** needs no code: Roblox shuts an empty server down (Queue base reached the same conclusion). It is checked live in the walkthrough.
- **An expected member who arrives after the run started** is crew (votes, banks, respawns in the bay, listed in the review) but not a Round participant: Round has no public way to add one mid-run, so Round's own "everyone left" check ignores them.
- **A pad's countdown is shown only to players aboard** (Queue's placeholder widget); the truck billboard shows how many are aboard. Queue's pad snapshots cannot be matched to pad instances on the client.
- **A public server of the shift place** (only reachable if direct access to the place is allowed) sends every player to the depot.
- **The arrival card** is a client card for 5 s at arrival (matching the 5 s arrival countdown); during a live arrival wait of up to 20 s the crew stands in the loading bay.
