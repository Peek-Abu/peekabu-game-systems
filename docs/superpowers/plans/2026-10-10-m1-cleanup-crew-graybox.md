# M1: Cleanup Crew graybox loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Studio-playable graybox shift with no Harlow: a code-built office at a far-off world position, randomised spawns with guarantees, vacuum piles into a canister that pops dust bags, carry with hands and two pockets, bank at the truck, a 350 clearance quota, clock out, a plain results panel and an Another-shift vote that resets in the same server.

**Architecture:** Four game features stacked on the M0 base hooks. **Office** builds static geometry from authored room data once and rolls each shift's spawns (pure, seeded, guarantee-checked) into one per-shift container held by one Janitor. **Vacuum** owns piles, the `pile` Interaction channel and the canister. **Cargo** owns the 13-kind catalog, pockets, handling traits, search and banking (claim → add → destroy in one synchronous step). **Shift** configures Round, follows its phases with its own pure phase machine (it holds `results` itself until the crew votes), runs clock out and the vote, and publishes the `shift` world entry the placeholder React HUD reads. Every decision is a pure, specced Rules/Utils/State module; Instance work lives in spec-exempt shells. Noise is M2: Vacuum and Cargo expose a `noiseMade(position, radius, source)` signal fired where noise happens, with the radii already in their Data constants.

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax packets, Charm atoms + charm-sync world/public-player slices, React (react-lua) + ReactCharm, TestEZ (Studio, `RunTests = true`), Observers, SignalTyped, Janitor. Base APIs from M0 (`base/game-hooks`): Interaction channels, Carry `pickedUp`/`dropped`/`forceDrop(reason)`, Toast, Death `setSpawnPoint`.

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (M1 row of §9; mechanics §4; flow §3; architecture §6). Builds on `docs/superpowers/plans/2026-10-10-m0-base-game-hooks.md`.

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts without a commented justification and developer sign-off (none are planned).
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`). `*.story` files need neither.
- Module names `<Feature><What><RoleWord>` in an allowed subfolder; UI tree modules PascalCase (`ViewModel` suffix for view models, `use<Thing>` hooks). Requires use full addresses; a feature folder required from 3+ times in one file gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`; comments and blanks do not count).
- After adding/moving modules: `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md; `check_pr_rules` rejects them).
- **Rojo safety:** the developer may be connected to `rojo serve`. Implementers never run `rokit install`, `wally install`, `install.sh` or `scripts/check.sh`; the per-task gate is `bash .superpowers/sdd/gate.sh` (lint, format, typecheck, rules, file length, module map). Tests run only in Studio: steps saying "controller: Studio TestEZ" are run by the controller (Workspace attribute `RunTests = true`, Play, read Output).
- Server-authoritative: clients only send requests (a channel start/stop, `pocket`, a vote); the server re-validates everything. React components never send packets (`check_pr_rules`); they call client services or write client stores.
- Asset-id literals only in a feature's `Data/<Feature>Assets` (M1 uses none: graybox parts, plain UI).
- **M1 UI is plain functional placeholder UI** (Tokens + primitives). Final screens wait for the developer's Figma approval in M3.
- **Spec numbers (tuning hypotheses, all in Data constants):** vacuum range 8 studs, 2.5 s per pile, progress kept on release, rates add; canister capacity 3 → dust bag (trash, 15); pockets 2, tiny only; walk 16, any carried item under 15 (Carry weight); heavy and bulky block sprint (data only: the base has no sprint); bulky ~half speed; fragile loses one value tier per drop/throw; rattly pulse every ~2 s (M2); quota 350 clearance (trash only), salvage is a separate bonus; spawn guarantees: trash ≥ 1.5 × quota counting canister output, ≥ 1 greed target (fish tank, filing cabinet, golden stapler) placed deep; shift 7:00; clock-out countdown 10 s; noise: vacuum pulse every 1 s at radius 40 (M2 consumes); variant B (default) hides some salvage under piles, A exposes all.

## Review Focus

1. **Two Loads of the same item, or Load spam while the server is busy** → the item counts once, then is destroyed; a refused Load leaves item and pockets untouched. (Task 8 Step 1 `CargoClaimTracker` spec "claims an item once" + Task 8 Step 10 checklist item 6)
2. **A player dies or leaves mid-shift holding an item and two pocketed items** → the hands item drops where they were (Carry), the pocketed items scatter around the body inside the shift container, nothing is duplicated or lost, their public fields clear. (Task 8 Step 1 `CargoPocketTracker` "take empties the pockets and returns what was in them" + Task 8 Step 10 checklist item 8; Task 12 Step 6 item 4 for leaving)
3. **Clock out pressed twice, during the countdown, or outside a running shift** → exactly one 10 s countdown; later presses are ignored. (Task 5 Step 1 `ShiftPhaseRules` "starts one countdown while running", "ignores a second press during the countdown", "ignores a press outside a running shift")
4. **Another shift while someone holds an item or is mid-vacuum** → the held item is destroyed with the container (Carry releases it and restores walk speed), canisters and pockets read 0/empty, desks are re-stocked, and the new shift's spawns are fresh. (Task 10 Step 6 checklist item 7)
5. **Nobody votes, or everyone leaves during results** → the vote times out to Another shift; an empty server never starts a countdown. (Task 5 Step 1 `ShiftVoteRules` "times out to another with no votes, even in an empty server" + `ShiftPhaseRules` "never starts an empty server")

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Cargo | shared | Data | CargoTypes | Item, entry, deposit, bank-handler and spawn-option types |
| Cargo | shared | Data | CargoConstants | Weights, pockets, fragile tiers, noise radii, attribute and interaction names |
| Cargo | shared | Data | CargoRegistry | The 13 cargo kinds (12 office items + dust bag) with values and traits |
| Cargo | shared | Rules | CargoHandlingRules | Pocket limits, fragile value tiers, spill and drop-noise decisions |
| Cargo | shared | Rules | CargoBankRules | In-the-bed check and what a Load is worth |
| Cargo | shared | Net | CargoEvents | `Pocket` packet (client → server) |
| Cargo | server | State | CargoClaimTracker | Claims an item id once (banking/pocketing never double count) |
| Cargo | server | State | CargoPocketTracker | Each player's pocketed entries, 2 slots |
| Cargo | server | Systems | CargoSpawnSystem | Builds graybox item parts, reveals hidden ones, updates value labels, finds the floor |
| Cargo | server | (root) | CargoServiceServer | Carry kinds, pockets, handling, search, banking |
| Cargo | client | (root) | CargoServiceClient | `pocket` action; button-friendly pocket/drop/throw |
| Vacuum | shared | Data | VacuumConstants | Range, duration, canister, noise, pile kinds, names |
| Vacuum | server | Utils | VacuumCanisterUtils | Canister fill/overflow and which channeler is credited |
| Vacuum | server | (root) | VacuumServiceServer | Pile spawning and shrink, the `pile` channel, canisters, dust-bag and noise signals |
| Vacuum | client | Utils | VacuumAimUtils | Picks the pile the player is facing within range |
| Vacuum | client | (root) | VacuumServiceClient | `vacuum` hold action → channel start/stop on the aimed pile |
| Office | server | Data | OfficeTypes | Room, door, marker, layout, segment and spawn-plan types |
| Office | server | Data | OfficeConstants | Origin, wall sizes, roll ranges and chances, colours |
| Office | server | Data | OfficeLayoutConstants | The authored office: rooms, doors, truck, markers |
| Office | server | Utils | OfficeLayoutUtils | Lookups, room depths (BFS), door edges, wall segments |
| Office | server | Rules | OfficeLayoutRules | Layout validation (connected, markers inside rooms, doors on shared walls) and roll capacity |
| Office | server | Utils | OfficeSpawnUtils | The seeded per-shift spawn roll |
| Office | server | Rules | OfficeSpawnRules | A plan meets the guarantees (trash, deep greed, no reused marker) |
| Office | server | Systems | OfficeBuildSystem | Builds floors, walls, truck, time clock, desks and lockers |
| Office | server | (root) | OfficeServiceServer | Builds once; per shift rolls, places, reveals, resets |
| Shift | shared | Data | ShiftTypes | Phase, sub-state, state, snapshot, results, vote types |
| Shift | shared | Data | ShiftConstants | Quota, durations, variant, Round counter names, world entry |
| Shift | shared | Net | ShiftEvents | `Vote` packet (client → server) |
| Shift | shared | Utils | ShiftSnapshotUtils | Builds and decodes the `shift` world entry |
| Shift | server | Rules | ShiftPhaseRules | Shift phase machine: follow Round, clock out, quota, tick actions |
| Shift | server | Rules | ShiftVoteRules | Parse, tally and decide the Another shift / depot vote |
| Shift | server | Utils | ShiftResultsUtils | Builds the results payload (totals, crew lines, awards) |
| Shift | server | (root) | ShiftServiceServer | Configures Round, runs the shift, banking handler, clock out, vote, reset |
| Shift | client | State | ShiftStore | Decoded snapshot (computed atom) and the local vote atom |
| Shift | client | (root) | ShiftServiceClient | Registers the HUD widgets, sends the vote |
| UI tree | client | Hooks | useServerClock | Re-renders with the server clock (timers) |
| UI tree | client | Screens/Shift | ShiftHudViewModel | Pure strings for the HUD and the results panel |
| UI tree | client | Screens/Shift | ShiftHudPanel (+ `.story`) | Presentational HUD panel |
| UI tree | client | Screens/Shift | ShiftHud | HUD widget: reads stores, renders ShiftHudPanel |
| UI tree | client | Screens/Shift | ShiftResultsPanel (+ `.story`) | Presentational results panel with two vote buttons |
| UI tree | client | Screens/Shift | ShiftResults | Results widget: reads stores, writes the vote |
| UI tree | client | Screens/Shift | ShiftMobileButtons | Touch buttons: hold Vacuum, Pocket, Drop, Throw |

No new subfolder kind, role word or second service. Modified: `SpecRoots` (exemptions), `docs/project-structure.md` (module map; a game-features note), `docs/ROADMAP.md` (a games note).

## Open questions for the developer

Designed around in this plan; none blocks M1.

1. **Touch buttons.** The base Input feature has keyboard/mouse and gamepad bindings only, no touch. M1 draws game-side React buttons in the Shift HUD (Task 11). A base touch-button layer (ROADMAP Input row mentions touch) would replace them; that is a base change, out of scope here.
2. **`CarryServiceClient` has no callable drop/throw.** It binds G/F to Carry's packets but exposes only `isCarrying`. `CargoServiceClient:drop()/throw()` send `CarryEvents` packets directly for the mobile buttons. A base `CarryServiceClient:drop()/throw()` would be cleaner.
3. **Round's results phase cannot be cut short** (`RoundPhaseRules.startNow` refuses in `results`; `configure` does not move a running timer). Shift sets `resultsDuration = 0` and holds its own `results` phase until the vote. A base `RoundServiceServer:skipResults()` would let Round's phase match Shift's.
4. **No sprint in the base.** "Heaviest stop sprint" is stored as data (`CargoConstants.NO_SPRINT`), enforced when a sprint system exists. Should M2 add a sprint (base Input already declares a `sprint` action)?
5. **Pocket key.** The spec names G (drop) and F (throw) only; this plan binds pocket to **Q** (gamepad D-pad up).
6. **Two vacuums finishing one pile** credit the canister of the channeler with the lowest fill (ties: lowest UserId); everyone on it gets the "piles" stat. The spec is silent on whose canister fills.
7. **Back to depot before M4** has no depot to go to: if it wins, a toast says so and another shift starts in the same server.

---

### Task 0: Branch

**Files:** none (environment).

- [ ] **Step 1: Create the game branch from the base branch**

```bash
git switch base/game-hooks
git switch -c game/cleanup-crew
```

- [ ] **Step 2: Confirm the M0 APIs this plan uses are present** (they are being implemented on `base/game-hooks`; if any is missing, stop and tell the controller which):

```bash
grep -n "registerChannel\|hasChannel" src/ReplicatedStorage/Shared/Features/Interaction/Data/InteractionRegistry.luau
grep -n "channel = function\|resetChannel" src/ServerScriptService/Features/Interaction/InteractionServiceServer.luau
grep -n "startChannel\|stopChannel" src/ReplicatedStorage/Client/Features/Interaction/InteractionServiceClient.luau
grep -n "CHANNEL_KIND_ATTRIBUTE\|CHANNEL_PROGRESS_ATTRIBUTE\|CHANNEL_COUNT_ATTRIBUTE" src/ReplicatedStorage/Shared/Features/Interaction/Data/InteractionConstants.luau
grep -n "dropped\|forceDrop" src/ServerScriptService/Features/Carry/CarryServiceServer.luau
grep -n "send = function" src/ServerScriptService/Features/Toast/ToastServiceServer.luau
grep -n "setSpawnPoint" src/ServerScriptService/Features/Death/DeathServiceServer.luau
```
Expected: every grep prints at least one line.

- [ ] **Step 3: Baseline gate**

```bash
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.` If anything fails here, stop and report: it is not ours.

---

### Task 1: Cargo catalog and handling rules (shared, pure)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoRegistry.luau` (+ `CargoRegistry.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoBankRules.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: `CarryTypes.DropReason = "drop" | "throw" | "forced" | "death" | "removed" | "destroyed"` (`src/ReplicatedStorage/Shared/Features/Carry/Data/CarryTypes.luau`).
- Produces (CargoTypes): `Category = "trash" | "salvage"`, `Size = "tiny" | "light" | "medium" | "heavy" | "bulky"`, `ItemDef = { id, name, category, value, size, throwable, fragile, rattly, spills, splashes, blocksView, hidden, greed, spawnWeight, deskWeight, partSize: Vector3, color: Color3 }`, `CargoEntry = { kind: string, value: number }`, `DepositItem = { kind, category, value }`, `Deposit = { clearance: number, bonus: number, items: { DepositItem } }`, `BankHandler = (player: Player, deposit: Deposit) -> boolean`, `SpawnOptions = { hidden: boolean?, value: number? }`.
- Produces (CargoConstants): `WEIGHT`, `DROP_NOISE`, `NO_SPRINT` (maps by size), `FRAGILE_TIERS = {1, 0.5, 0.25}`, `POCKET_SLOTS = 2`, `POCKET_SIZE = "tiny"`, `PUBLIC_POCKET_FIELDS = {"pocket1", "pocket2"}`, `POCKET_ACTION = "pocket"`, `BULKY_HOLD_OFFSET`, `ID_ATTRIBUTE = "CargoId"`, `VALUE_ATTRIBUTE = "CargoValue"`, `IMPACTS_ATTRIBUTE = "CargoImpacts"`, `HIDDEN_ATTRIBUTE = "CargoHidden"`, `LABEL_NAME = "CargoLabel"`, `LOAD_KIND = "cargo-load"`, `SEARCH_KIND = "cargo-search"`, `LOAD_DISTANCE`, `SEARCH_DISTANCE`, `SEARCH_HOLD`, `BED_TOLERANCE`, `BED_HEIGHT`, `SPLASH_NOISE`, `SEARCH_NOISE`, `RATTLE_NOISE`, `RATTLE_INTERVAL`, `SCATTER_RADIUS`, `SPILL_PILE_KIND = "paper"`, `LABEL_DISTANCE`, `FLOOR_PROBE`.
- Produces (CargoRegistry): `get(id) -> ItemDef?`, `has(id) -> boolean`, `ids() -> { string }` (sorted, frozen), `greedIds() -> { string }` (sorted).
- Produces (CargoHandlingRules): `canPocket(def: ItemDef?, pocketed: number) -> (boolean, string?)`, `valueAfter(def, impacts: number) -> number`, `isImpact(reason: DropReason) -> boolean`, `shouldSpill(def, reason) -> boolean`, `dropNoise(def) -> number`.
- Produces (CargoBankRules): `onBed(localPoint: Vector3, bedSize: Vector3) -> boolean`, `deposit(hands: CargoEntry?, pockets: { CargoEntry }, lookup: (kind: string) -> ItemDef?) -> (Deposit?, string?)`.

- [ ] **Step 1: Write the failing specs.**

`src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoRegistry.spec.luau`:

```lua
local CargoRegistry = require(script.Parent.CargoRegistry)

local EXPECTED = {
	{ "rubbishBag", "trash", 10 },
	{ "dustBag", "trash", 15 },
	{ "recyclingBox", "trash", 15 },
	{ "bottleBag", "trash", 15 },
	{ "officePlant", "salvage", 20 },
	{ "plaque", "salvage", 25 },
	{ "monitor", "salvage", 30 },
	{ "waterJug", "salvage", 30 },
	{ "printer", "salvage", 40 },
	{ "coffeeMachine", "salvage", 50 },
	{ "fishTank", "salvage", 70 },
	{ "goldenStapler", "salvage", 80 },
	{ "filingCabinet", "salvage", 120 },
}

return function()
	it("holds the twelve office items and the dust bag", function()
		expect(#CargoRegistry.ids()).to.equal(13)
	end)

	it("matches the spec's kinds and values", function()
		for _, row in EXPECTED do
			local def = CargoRegistry.get(row[1])
			expect(def).to.be.ok()
			expect(def.category).to.equal(row[2])
			expect(def.value).to.equal(row[3])
		end
	end)

	it("lists ids sorted", function()
		local ids = CargoRegistry.ids()
		for index = 2, #ids do
			expect(ids[index - 1] < ids[index]).to.equal(true)
		end
	end)

	it("marks exactly the three greed targets", function()
		local greed = CargoRegistry.greedIds()
		expect(#greed).to.equal(3)
		expect(greed[1]).to.equal("filingCabinet")
		expect(greed[2]).to.equal("fishTank")
		expect(greed[3]).to.equal("goldenStapler")
	end)

	it("carries the spec's traits", function()
		expect(CargoRegistry.get("rubbishBag").throwable).to.equal(true)
		expect(CargoRegistry.get("dustBag").throwable).to.equal(true)
		expect(CargoRegistry.get("recyclingBox").spills).to.equal(true)
		expect(CargoRegistry.get("bottleBag").rattly).to.equal(true)
		expect(CargoRegistry.get("officePlant").blocksView).to.equal(true)
		expect(CargoRegistry.get("plaque").size).to.equal("tiny")
		expect(CargoRegistry.get("monitor").fragile).to.equal(true)
		expect(CargoRegistry.get("waterJug").splashes).to.equal(true)
		expect(CargoRegistry.get("printer").size).to.equal("heavy")
		expect(CargoRegistry.get("coffeeMachine").rattly).to.equal(true)
		local tank = CargoRegistry.get("fishTank")
		expect(tank.fragile and tank.rattly and tank.size == "heavy").to.equal(true)
		local stapler = CargoRegistry.get("goldenStapler")
		expect(stapler.hidden and stapler.size == "tiny").to.equal(true)
		expect(CargoRegistry.get("filingCabinet").size).to.equal("bulky")
	end)

	it("never rolls the dust bag or a greed target onto the open floor", function()
		expect(CargoRegistry.get("dustBag").spawnWeight).to.equal(0)
		for _, id in CargoRegistry.greedIds() do
			expect(CargoRegistry.get(id).spawnWeight).to.equal(0)
		end
	end)

	it("returns nil for an unknown id", function()
		expect(CargoRegistry.get("spaceship")).to.equal(nil)
		expect(CargoRegistry.has("spaceship")).to.equal(false)
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoHandlingRules = require(script.Parent.CargoHandlingRules)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

return function()
	describe("canPocket", function()
		it("takes a tiny item into a free pocket", function()
			expect(CargoHandlingRules.canPocket(CargoRegistry.get("plaque"), 0)).to.equal(true)
			expect(CargoHandlingRules.canPocket(CargoRegistry.get("goldenStapler"), 1)).to.equal(true)
		end)

		it("refuses anything bigger than tiny", function()
			local ok, reason = CargoHandlingRules.canPocket(CargoRegistry.get("rubbishBag"), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("too big for pockets")
		end)

		it("refuses a third item", function()
			local ok, reason = CargoHandlingRules.canPocket(CargoRegistry.get("plaque"), 2)
			expect(ok).to.equal(false)
			expect(reason).to.equal("pockets full")
		end)

		it("refuses something that is not cargo", function()
			local ok, reason = CargoHandlingRules.canPocket(nil, 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("not cargo")
		end)
	end)

	describe("valueAfter", function()
		it("drops a fragile item one tier per impact, then holds", function()
			local monitor = CargoRegistry.get("monitor")
			expect(CargoHandlingRules.valueAfter(monitor, 0)).to.equal(30)
			expect(CargoHandlingRules.valueAfter(monitor, 1)).to.equal(15)
			expect(CargoHandlingRules.valueAfter(monitor, 2)).to.equal(8)
			expect(CargoHandlingRules.valueAfter(monitor, 7)).to.equal(8)
		end)

		it("leaves a sturdy item's value alone", function()
			expect(CargoHandlingRules.valueAfter(CargoRegistry.get("printer"), 5)).to.equal(40)
		end)
	end)

	describe("impacts and spills", function()
		it("counts every drop reason except destruction as an impact", function()
			for _, reason in { "drop", "throw", "forced", "death", "removed" } do
				expect(CargoHandlingRules.isImpact(reason)).to.equal(true)
			end
			expect(CargoHandlingRules.isImpact("destroyed")).to.equal(false)
		end)

		it("spills only a spilling item, and only on an impact", function()
			local box = CargoRegistry.get("recyclingBox")
			expect(CargoHandlingRules.shouldSpill(box, "drop")).to.equal(true)
			expect(CargoHandlingRules.shouldSpill(box, "destroyed")).to.equal(false)
			expect(CargoHandlingRules.shouldSpill(CargoRegistry.get("rubbishBag"), "drop")).to.equal(false)
		end)
	end)

	describe("dropNoise", function()
		it("scales with size and splashes loudest", function()
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("plaque"))).to.equal(CargoConstants.DROP_NOISE.tiny)
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("printer"))).to.equal(CargoConstants.DROP_NOISE.heavy)
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))).to.equal(CargoConstants.SPLASH_NOISE)
			expect(CargoConstants.SPLASH_NOISE > CargoConstants.DROP_NOISE.bulky).to.equal(true)
		end)
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoBankRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoBankRules = require(script.Parent.CargoBankRules)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local BED = Vector3.new(12, 3, 16)

return function()
	describe("onBed", function()
		it("accepts a player standing on the bed", function()
			expect(CargoBankRules.onBed(Vector3.new(0, 4, 0), BED)).to.equal(true)
			expect(CargoBankRules.onBed(Vector3.new(6.5, 4, -8.5), BED)).to.equal(true)
		end)

		it("refuses a player beside the truck or far above it", function()
			expect(CargoBankRules.onBed(Vector3.new(9, 4, 0), BED)).to.equal(false)
			expect(CargoBankRules.onBed(Vector3.new(0, 4, 11), BED)).to.equal(false)
			expect(CargoBankRules.onBed(Vector3.new(0, 20, 0), BED)).to.equal(false)
		end)
	end)

	describe("deposit", function()
		it("adds hands trash to clearance", function()
			local deposit = CargoBankRules.deposit({ kind = "rubbishBag", value = 10 }, {}, CargoRegistry.get)
			expect(deposit.clearance).to.equal(10)
			expect(deposit.bonus).to.equal(0)
			expect(#deposit.items).to.equal(1)
		end)

		it("adds salvage to bonus and unloads pockets with the hands item", function()
			local deposit = CargoBankRules.deposit(
				{ kind = "dustBag", value = 15 },
				{ { kind = "plaque", value = 25 }, { kind = "goldenStapler", value = 80 } },
				CargoRegistry.get
			)
			expect(deposit.clearance).to.equal(15)
			expect(deposit.bonus).to.equal(105)
			expect(#deposit.items).to.equal(3)
			expect(deposit.items[2].category).to.equal("salvage")
		end)

		it("loads pockets alone when the hands are empty", function()
			local deposit = CargoBankRules.deposit(nil, { { kind = "plaque", value = 25 } }, CargoRegistry.get)
			expect(deposit.bonus).to.equal(25)
		end)

		it("uses the item's current (damaged) value", function()
			local deposit = CargoBankRules.deposit({ kind = "monitor", value = 15 }, {}, CargoRegistry.get)
			expect(deposit.bonus).to.equal(15)
		end)

		it("refuses an empty load", function()
			local deposit, reason = CargoBankRules.deposit(nil, {}, CargoRegistry.get)
			expect(deposit).to.equal(nil)
			expect(reason).to.equal("nothing to load")
		end)

		it("refuses an unknown kind", function()
			local deposit, reason = CargoBankRules.deposit({ kind = "spaceship", value = 999 }, {}, CargoRegistry.get)
			expect(deposit).to.equal(nil)
			expect(reason).to.equal('unknown cargo "spaceship"')
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the three specs error (modules missing).

- [ ] **Step 3: Types** `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoTypes.luau`:

```lua
--!strict
--[=[
	CargoTypes: the Cargo feature's shapes (Cleanup Crew spec §4, "Cargo and carrying"). Types only
	(spec-exempt).

	@class CargoTypes
]=]

export type Category = "trash" | "salvage"

-- How big an item is: its carry weight, its drop noise, and whether it fits a pocket.
export type Size = "tiny" | "light" | "medium" | "heavy" | "bulky"

export type ItemDef = {
	id: string,
	name: string,
	category: Category,
	-- Clearance (trash) or bonus (salvage) when loaded undamaged.
	value: number,
	size: Size,
	throwable: boolean,
	-- Loses one value tier per impact (CargoConstants.FRAGILE_TIERS).
	fragile: boolean,
	-- Pulses a small noise every CargoConstants.RATTLE_INTERVAL while carried (M2: Noise).
	rattly: boolean,
	-- Becomes a pile when dropped (the recycling box).
	spills: boolean,
	-- A very loud drop (the water jug; its slippery puddle is M2).
	splashes: boolean,
	-- Leaves partly block the carrier's view (the office plant; M3 feel).
	blocksView: boolean,
	-- Never spawns in the open: only under a pile or in a desk / locker.
	hidden: boolean,
	-- One greed target is guaranteed per shift, placed deep.
	greed: boolean,
	-- Relative chance in the open-floor roll (0 = never rolled there).
	spawnWeight: number,
	-- Relative chance as desk / locker contents (0 = never).
	deskWeight: number,
	-- Graybox look.
	partSize: Vector3,
	color: Color3,
}

-- A carried or pocketed item as banking sees it: its kind and its value now (after any damage).
export type CargoEntry = {
	kind: string,
	value: number,
}

export type DepositItem = {
	kind: string,
	category: Category,
	value: number,
}

-- What one Load is worth: trash adds to clearance, salvage to bonus (before any overtime multiplier).
export type Deposit = {
	clearance: number,
	bonus: number,
	items: { DepositItem },
}

-- The game's banking callback (Shift): adds the deposit; false refuses it (no shift running). It must not
-- yield: claim, add and destroy run as one step.
export type BankHandler = (player: Player, deposit: Deposit) -> boolean

export type SpawnOptions = {
	-- Spawned invisible and un-interactable (under a pile) until revealed.
	hidden: boolean?,
	-- The value it carries (a scattered pocket item keeps its own); absent = the catalog value.
	value: number?,
}

return {}
```

- [ ] **Step 4: Constants** `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoConstants.luau`:

```lua
--!strict
--[=[
	CargoConstants: Cargo tuning and names (Cleanup Crew spec §4). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class CargoConstants
]=]

-- Carry weight per size. Carry walks at CarryFormulas.walkSpeedFor(16, weight, 0.05, 0.4): tiny and light
-- 14.8 (any carried item puts you under Harlow's chase speed of 15), medium 12.8, heavy 10.4, bulky 8 (half).
local WEIGHT: { [string]: number } = { tiny = 1.5, light = 1.5, medium = 4, heavy = 7, bulky = 10 }

-- Noise radius (studs) of a drop, by size. M2's Noise feature reads these through CargoHandlingRules.
local DROP_NOISE: { [string]: number } = { tiny = 6, light = 14, medium = 24, heavy = 36, bulky = 40 }

-- Sizes too heavy to sprint with. The base has no sprint yet: data for when it does.
local NO_SPRINT: { [string]: boolean } = { heavy = true, bulky = true }

-- A fragile item's value fraction after 0, 1, then 2 or more impacts.
local FRAGILE_TIERS: { number } = { 1, 0.5, 0.25 }

-- The public-player fields that name what is in each pocket (absent = empty).
local PUBLIC_POCKET_FIELDS: { string } = { "pocket1", "pocket2" }

return table.freeze({
	WEIGHT = table.freeze(WEIGHT),
	DROP_NOISE = table.freeze(DROP_NOISE),
	NO_SPRINT = table.freeze(NO_SPRINT),
	FRAGILE_TIERS = table.freeze(FRAGILE_TIERS),
	-- Pockets: two slots, tiny items only.
	POCKET_SLOTS = 2,
	POCKET_SIZE = "tiny",
	PUBLIC_POCKET_FIELDS = table.freeze(PUBLIC_POCKET_FIELDS),
	-- The Input action that pockets the hands item.
	POCKET_ACTION = "pocket",
	-- A bulky item is held far out in front (the cabinet cart).
	BULKY_HOLD_OFFSET = CFrame.new(0, -1, -4.5),
	-- Attributes on a spawned item, and its label's name.
	ID_ATTRIBUTE = "CargoId",
	VALUE_ATTRIBUTE = "CargoValue",
	IMPACTS_ATTRIBUTE = "CargoImpacts",
	HIDDEN_ATTRIBUTE = "CargoHidden",
	LABEL_NAME = "CargoLabel",
	-- Interaction kinds Cargo registers (the truck bed and the desks / lockers carry them).
	LOAD_KIND = "cargo-load",
	SEARCH_KIND = "cargo-search",
	LOAD_DISTANCE = 16,
	SEARCH_DISTANCE = 8,
	SEARCH_HOLD = 0.8,
	-- The truck bed counts this far past its footprint, and this high above its top.
	BED_TOLERANCE = 1.5,
	BED_HEIGHT = 8,
	-- Noise seams (M2): a jug's splash, a search, a rattle pulse.
	SPLASH_NOISE = 70,
	SEARCH_NOISE = 12,
	RATTLE_NOISE = 12,
	RATTLE_INTERVAL = 2,
	-- Pocketed items scatter this far around where their owner died or left.
	SCATTER_RADIUS = 4,
	-- The pile a spilled recycling box becomes.
	SPILL_PILE_KIND = "paper",
	-- Graybox item labels are seen within this many studs.
	LABEL_DISTANCE = 24,
	-- How far down the floor is looked for under a spill or a scattered item.
	FLOOR_PROBE = 20,
})
```

- [ ] **Step 5: Registry** `src/ReplicatedStorage/Shared/Features/Cargo/Data/CargoRegistry.luau`:

```lua
--!strict
--[=[
	CargoRegistry: the cargo catalog (Cleanup Crew spec §4 table): twelve items found in the office plus the
	dust bag the vacuum makes. Built here at load and frozen; `ids()` is sorted so a roll that walks the
	catalog picks the same items for the same seed.

	Every number is a tuning hypothesis. spawnWeight / deskWeight are this plan's hypotheses for how often
	an item is rolled on the open floor / into a desk; greed targets are placed by the roll itself.

	@class CargoRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

-- The optional traits; anything absent is false (or 0 for weights).
type Traits = {
	throwable: boolean?,
	fragile: boolean?,
	rattly: boolean?,
	spills: boolean?,
	splashes: boolean?,
	blocksView: boolean?,
	hidden: boolean?,
	greed: boolean?,
	spawnWeight: number?,
	deskWeight: number?,
}

local PART_SIZE: { [string]: Vector3 } = {
	tiny = Vector3.new(1, 0.4, 0.8),
	light = Vector3.new(2, 2, 2),
	medium = Vector3.new(2.5, 2.5, 2.5),
	heavy = Vector3.new(3, 3, 3),
	bulky = Vector3.new(3, 5, 3.5),
}

local items: { [string]: ItemDef } = {}

local function define(
	id: string,
	name: string,
	category: CargoTypes.Category,
	value: number,
	size: CargoTypes.Size,
	color: Color3,
	traits: Traits
)
	assert(items[id] == nil, `cargo item "{id}" is defined twice`)
	assert(value > 0, `cargo item "{id}": value must be positive`)
	local spawnWeight = traits.spawnWeight or 0
	local deskWeight = traits.deskWeight or 0
	assert(spawnWeight >= 0 and deskWeight >= 0, `cargo item "{id}": weights must not be negative`)
	local def: ItemDef = {
		id = id,
		name = name,
		category = category,
		value = value,
		size = size,
		throwable = traits.throwable == true,
		fragile = traits.fragile == true,
		rattly = traits.rattly == true,
		spills = traits.spills == true,
		splashes = traits.splashes == true,
		blocksView = traits.blocksView == true,
		hidden = traits.hidden == true,
		greed = traits.greed == true,
		spawnWeight = spawnWeight,
		deskWeight = deskWeight,
		partSize = PART_SIZE[size],
		color = color,
	}
	items[id] = table.freeze(def)
end

-- Trash: clearance.
define("rubbishBag", "Rubbish bag", "trash", 10, "light", Color3.fromRGB(40, 40, 45), {
	throwable = true,
	spawnWeight = 3,
	deskWeight = 2,
})
define("dustBag", "Dust bag", "trash", 15, "light", Color3.fromRGB(150, 135, 110), { throwable = true })
define("recyclingBox", "Recycling box", "trash", 15, "light", Color3.fromRGB(60, 120, 200), {
	spills = true,
	spawnWeight = 2,
})
define("bottleBag", "Bottle bag", "trash", 15, "light", Color3.fromRGB(70, 160, 90), {
	rattly = true,
	spawnWeight = 2,
	deskWeight = 1,
})

-- Salvage: bonus.
define("officePlant", "Office plant", "salvage", 20, "medium", Color3.fromRGB(50, 140, 60), {
	blocksView = true,
	spawnWeight = 3,
})
define("plaque", "Employee of the Month plaque", "salvage", 25, "tiny", Color3.fromRGB(190, 150, 70), {
	spawnWeight = 2,
	deskWeight = 3,
})
define("monitor", "Monitor", "salvage", 30, "medium", Color3.fromRGB(30, 30, 35), { fragile = true, spawnWeight = 3 })
define("waterJug", "Water cooler jug", "salvage", 30, "heavy", Color3.fromRGB(120, 180, 230), {
	splashes = true,
	spawnWeight = 2,
})
define("printer", "Printer", "salvage", 40, "heavy", Color3.fromRGB(210, 210, 200), { spawnWeight = 2 })
define("coffeeMachine", "Coffee machine", "salvage", 50, "heavy", Color3.fromRGB(110, 70, 50), {
	rattly = true,
	spawnWeight = 1,
})
define("fishTank", "Fish tank", "salvage", 70, "heavy", Color3.fromRGB(80, 200, 220), {
	fragile = true,
	rattly = true,
	greed = true,
})
define("goldenStapler", "Golden stapler", "salvage", 80, "tiny", Color3.fromRGB(255, 200, 40), {
	hidden = true,
	greed = true,
})
define("filingCabinet", "Filing cabinet on cart", "salvage", 120, "bulky", Color3.fromRGB(120, 125, 135), {
	greed = true,
})

local sortedIds: { string } = {}
local sortedGreed: { string } = {}
for id, def in items do
	table.insert(sortedIds, id)
	if def.greed then
		table.insert(sortedGreed, id)
	end
end
table.sort(sortedIds)
table.sort(sortedGreed)
table.freeze(sortedIds)
table.freeze(sortedGreed)

local CargoRegistry = {}

function CargoRegistry.get(id: string): ItemDef?
	return items[id]
end

function CargoRegistry.has(id: string): boolean
	return items[id] ~= nil
end

-- Every id, sorted (frozen).
function CargoRegistry.ids(): { string }
	return sortedIds
end

-- The greed targets' ids, sorted (frozen).
function CargoRegistry.greedIds(): { string }
	return sortedGreed
end

return CargoRegistry
```

- [ ] **Step 6: Handling rules** `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoHandlingRules.luau`:

```lua
--!strict
--[=[
	CargoHandlingRules: what handling does to cargo (Cleanup Crew spec §4). Pockets take tiny items only,
	two at a time; a fragile item loses a value tier per impact; a recycling box spills into a pile; a drop
	is as loud as the item is heavy, and the water jug splashes louder than anything. Pure.

	@class CargoHandlingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

local CargoHandlingRules = {}

--[=[
	Whether the hands item fits a pocket, given how many are already pocketed.
]=]
function CargoHandlingRules.canPocket(def: ItemDef?, pocketed: number): (boolean, string?)
	if def == nil then
		return false, "not cargo"
	end
	if def.size ~= CargoConstants.POCKET_SIZE then
		return false, "too big for pockets"
	end
	if pocketed >= CargoConstants.POCKET_SLOTS then
		return false, "pockets full"
	end
	return true, nil
end

--[=[
	An item's value after `impacts` drops or throws: unchanged unless fragile, else the catalog value times
	the tier's fraction, rounded; past the last tier it stays there.
]=]
function CargoHandlingRules.valueAfter(def: ItemDef, impacts: number): number
	if not def.fragile then
		return def.value
	end
	local tiers = CargoConstants.FRAGILE_TIERS
	local fraction = tiers[math.clamp(impacts + 1, 1, #tiers)]
	return math.floor(def.value * fraction + 0.5)
end

--[=[
	Whether a hold ending for `reason` hit the floor. Everything does except the object being destroyed while
	held. (Cargo's own pocketing and banking claim the item first, so their forced drops never get here.)
]=]
function CargoHandlingRules.isImpact(reason: CarryTypes.DropReason): boolean
	return reason ~= "destroyed"
end

function CargoHandlingRules.shouldSpill(def: ItemDef, reason: CarryTypes.DropReason): boolean
	return def.spills and CargoHandlingRules.isImpact(reason)
end

--[=[
	The radius (studs) a drop of this item is heard at (the M2 Noise seam).
]=]
function CargoHandlingRules.dropNoise(def: ItemDef): number
	if def.splashes then
		return CargoConstants.SPLASH_NOISE
	end
	return CargoConstants.DROP_NOISE[def.size] or 0
end

return CargoHandlingRules
```

- [ ] **Step 7: Bank rules** `src/ReplicatedStorage/Shared/Features/Cargo/Rules/CargoBankRules.luau`:

```lua
--!strict
--[=[
	CargoBankRules: loading at the truck (Cleanup Crew spec §4 "Banking", §6.4). `onBed` says whether a
	point in the bed part's object space is in the truck bed; `deposit` says what the hands item and the
	pockets are worth: trash adds to clearance, salvage to bonus. Pure; the claim that stops a double count
	is CargoClaimTracker.

	@class CargoBankRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry
type Deposit = CargoTypes.Deposit

local CargoBankRules = {}

--[=[
	True when `localPoint` (a HumanoidRootPart position in the bed's object space) is over the bed's
	footprint (plus BED_TOLERANCE) and no higher than BED_HEIGHT above its top.
]=]
function CargoBankRules.onBed(localPoint: Vector3, bedSize: Vector3): boolean
	local half = bedSize / 2
	local tolerance = CargoConstants.BED_TOLERANCE
	return math.abs(localPoint.X) <= half.X + tolerance
		and math.abs(localPoint.Z) <= half.Z + tolerance
		and localPoint.Y >= -half.Y - tolerance
		and localPoint.Y <= half.Y + CargoConstants.BED_HEIGHT
end

--[=[
	What loading `hands` (may be nil) and `pockets` is worth. Nil with a reason for an empty load or a kind
	the catalog does not know.
]=]
function CargoBankRules.deposit(
	hands: CargoEntry?,
	pockets: { CargoEntry },
	lookup: (kind: string) -> CargoTypes.ItemDef?
): (Deposit?, string?)
	local entries: { CargoEntry } = {}
	if hands ~= nil then
		table.insert(entries, hands)
	end
	for _, entry in pockets do
		table.insert(entries, entry)
	end
	local deposit: Deposit = { clearance = 0, bonus = 0, items = {} }
	for _, entry in entries do
		local def = lookup(entry.kind)
		if def == nil then
			return nil, `unknown cargo "{entry.kind}"`
		end
		local value = math.max(0, entry.value)
		if def.category == "trash" then
			deposit.clearance += value
		else
			deposit.bonus += value
		end
		table.insert(deposit.items, { kind = entry.kind, category = def.category, value = value })
	end
	if #deposit.items == 0 then
		return nil, "nothing to load"
	end
	return deposit, nil
end

return CargoBankRules
```

- [ ] **Step 8: Exemptions.** In `SpecRoots.luau` `EXEMPT_MODULES`, add (group them under a `-- Cleanup Crew: Cargo` comment):

```lua
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants"] = "static tuning and names (no logic)",
```

- [ ] **Step 9: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.`

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: CargoRegistry, CargoHandlingRules and CargoBankRules specs pass; `assertAllModulesSpecced` passes.

- [ ] **Step 11: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(cargo): catalog, handling and banking rules"
```

---

### Task 2: Vacuum constants, canister and aim rules (pure)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`
- Create: `src/ServerScriptService/Features/Vacuum/Utils/VacuumCanisterUtils.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumAimUtils.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Produces (VacuumConstants): `CHANNEL_KIND = "pile"`, `PILE_TAG = "VacuumPile"`, `PILE_KIND_ATTRIBUTE = "PileKind"`, `BASE_SIZE_ATTRIBUTE = "PileBaseSize"`, `RANGE = 8`, `DURATION = 2.5`, `CANISTER_CAPACITY = 3`, `DUST_BAG_KIND = "dustBag"`, `PUBLIC_FIELD = "canister"`, `NOISE_INTERVAL = 1`, `NOISE_RADIUS = 40`, `MIN_SCALE`, `ACTION = "vacuum"`, `AIM_INTERVAL`, `AIM_MIN_DOT`, `BAG_OFFSET: CFrame`, `PILE_KINDS: { [string]: { size: Vector3, color: Color3, material: Enum.Material } }`, `PILE_KIND_LIST = { "paper", "debris", "cables" }`.
- Produces (VacuumCanisterUtils): `add(fill: number, capacity: number) -> (number, boolean)` (new fill, a bag popped), `creditFor(userIds: { number }, fillOf: (userId: number) -> number) -> number?`.
- Produces (VacuumAimUtils): `pick(origin: Vector3, look: Vector3, candidates: { Vector3 }, range: number, minDot: number) -> number?` (index into candidates).

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Vacuum/Utils/VacuumCanisterUtils.spec.luau`:

```lua
local VacuumCanisterUtils = require(script.Parent.VacuumCanisterUtils)

return function()
	describe("add", function()
		it("fills one pile at a time", function()
			local fill, popped = VacuumCanisterUtils.add(0, 3)
			expect(fill).to.equal(1)
			expect(popped).to.equal(false)
			fill, popped = VacuumCanisterUtils.add(1, 3)
			expect(fill).to.equal(2)
			expect(popped).to.equal(false)
		end)

		it("pops a dust bag and empties when the third pile lands", function()
			local fill, popped = VacuumCanisterUtils.add(2, 3)
			expect(fill).to.equal(0)
			expect(popped).to.equal(true)
		end)
	end)

	describe("creditFor", function()
		local fills = { [1] = 2, [2] = 0, [3] = 0 }
		local function fillOf(id)
			return fills[id] or 0
		end

		it("credits the only channeler", function()
			expect(VacuumCanisterUtils.creditFor({ 1 }, fillOf)).to.equal(1)
		end)

		it("credits the emptiest canister, then the lowest UserId", function()
			expect(VacuumCanisterUtils.creditFor({ 1, 3, 2 }, fillOf)).to.equal(2)
		end)

		it("credits nobody when nobody was on it", function()
			expect(VacuumCanisterUtils.creditFor({}, fillOf)).to.equal(nil)
		end)
	end)
end
```

`src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumAimUtils.spec.luau`:

```lua
local VacuumAimUtils = require(script.Parent.VacuumAimUtils)

local ORIGIN = Vector3.new(0, 3, 0)
local LOOK = Vector3.new(0, -0.3, -1)

return function()
	it("picks the nearest pile in front within range", function()
		local index = VacuumAimUtils.pick(ORIGIN, LOOK, {
			Vector3.new(0, 0.5, -7),
			Vector3.new(1, 0.5, -4),
		}, 8, 0.35)
		expect(index).to.equal(2)
	end)

	it("ignores piles behind the player", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 0.5, 5) }, 8, 0.35)).to.equal(nil)
	end)

	it("ignores piles out of range, counting height", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 0.5, -9) }, 8, 0.35)).to.equal(nil)
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0, 12, -2) }, 8, 0.35)).to.equal(nil)
	end)

	it("counts a pile underfoot whatever the camera faces", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, { Vector3.new(0.5, 0.5, 0.5) }, 8, 0.35)).to.equal(1)
	end)

	it("returns nil with no piles", function()
		expect(VacuumAimUtils.pick(ORIGIN, LOOK, {}, 8, 0.35)).to.equal(nil)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Constants** `src/ReplicatedStorage/Shared/Features/Vacuum/Data/VacuumConstants.luau`:

```lua
--!strict
--[=[
	VacuumConstants: vacuum tuning and names (Cleanup Crew spec §4 "Vacuum"). Every number is a tuning
	hypothesis. Static data (spec-exempt).

	@class VacuumConstants
]=]

export type PileStyle = {
	size: Vector3,
	color: Color3,
	material: Enum.Material,
}

-- The three pile visuals (graybox).
local PILE_KINDS: { [string]: PileStyle } = {
	paper = { size = Vector3.new(4, 1.2, 4), color = Color3.fromRGB(235, 230, 215), material = Enum.Material.Fabric },
	debris = { size = Vector3.new(3.5, 1, 3.5), color = Color3.fromRGB(120, 105, 90), material = Enum.Material.Slate },
	cables = { size = Vector3.new(3, 0.8, 3), color = Color3.fromRGB(25, 25, 25), material = Enum.Material.Plastic },
}

-- Ordered, so a seeded roll picks the same kinds.
local PILE_KIND_LIST: { string } = { "paper", "debris", "cables" }

return table.freeze({
	-- The Interaction channel kind a pile carries (its ChannelKind attribute).
	CHANNEL_KIND = "pile",
	-- CollectionService tag on every pile (the client's aim and the shrink follow it).
	PILE_TAG = "VacuumPile",
	PILE_KIND_ATTRIBUTE = "PileKind",
	BASE_SIZE_ATTRIBUTE = "PileBaseSize",
	-- Aim at a pile within this many studs; one player clears it in DURATION seconds.
	RANGE = 8,
	DURATION = 2.5,
	-- Piles per canister; the next one pops a dust bag (this Cargo kind) and empties it.
	CANISTER_CAPACITY = 3,
	DUST_BAG_KIND = "dustBag",
	-- The public-player field holding a player's canister fill.
	PUBLIC_FIELD = "canister",
	-- Noise seam (M2): a pulse every NOISE_INTERVAL seconds while a pile is being vacuumed.
	NOISE_INTERVAL = 1,
	NOISE_RADIUS = 40,
	-- A pile shrinks to this fraction of its size as progress reaches full.
	MIN_SCALE = 0.35,
	-- The hold-to-vacuum Input action, how often the client re-aims, and how squarely it must face a pile.
	ACTION = "vacuum",
	AIM_INTERVAL = 0.1,
	AIM_MIN_DOT = 0.35,
	-- Where a dust bag lands, relative to the HumanoidRootPart (at the feet, a little ahead).
	BAG_OFFSET = CFrame.new(0, -3, -2.5),
	PILE_KINDS = table.freeze(PILE_KINDS),
	PILE_KIND_LIST = table.freeze(PILE_KIND_LIST),
})
```

- [ ] **Step 4: Canister utils** `src/ServerScriptService/Features/Vacuum/Utils/VacuumCanisterUtils.luau`:

```lua
--!strict
--[=[
	VacuumCanisterUtils: the canister's maths (Cleanup Crew spec §4): each cleared pile adds one; the pile
	that fills it pops a dust bag and empties it. When several players finish a pile together, the channeler
	with the emptiest canister is credited (ties: the lowest UserId). Pure.

	@class VacuumCanisterUtils
]=]

local VacuumCanisterUtils = {}

--[=[
	The fill after one more pile, and whether that pile popped a dust bag (the fill is then 0).
]=]
function VacuumCanisterUtils.add(fill: number, capacity: number): (number, boolean)
	local nextFill = fill + 1
	if nextFill >= capacity then
		return 0, true
	end
	return nextFill, false
end

--[=[
	Which of the players who finished a pile gets it in their canister; nil when none.
]=]
function VacuumCanisterUtils.creditFor(userIds: { number }, fillOf: (userId: number) -> number): number?
	local best: number? = nil
	local bestFill = math.huge
	for _, userId in userIds do
		local fill = fillOf(userId)
		if fill < bestFill or (fill == bestFill and best ~= nil and userId < best) then
			best = userId
			bestFill = fill
		end
	end
	return best
end

return VacuumCanisterUtils
```

- [ ] **Step 5: Aim utils** `src/ReplicatedStorage/Client/Features/Vacuum/Utils/VacuumAimUtils.luau`:

```lua
--!strict
--[=[
	VacuumAimUtils: which pile the player is vacuuming: the nearest within `range` (straight-line, so height
	counts) whose flat direction is within the camera's flat look by at least `minDot`. A pile underfoot
	(within 1.5 studs flat) counts whatever the camera faces. Pure; the server re-checks range.

	@class VacuumAimUtils
]=]

local UNDERFOOT = 1.5

local VacuumAimUtils = {}

function VacuumAimUtils.pick(
	origin: Vector3,
	look: Vector3,
	candidates: { Vector3 },
	range: number,
	minDot: number
): number?
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local hasLook = flatLook.Magnitude > 1e-6
	local forward = if hasLook then flatLook.Unit else Vector3.zero
	local best: number? = nil
	local bestDistance = math.huge
	for index, position in candidates do
		local offset = position - origin
		local distance = offset.Magnitude
		if distance <= range and distance < bestDistance then
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local facing = flat.Magnitude <= UNDERFOOT or not hasLook or flat.Unit:Dot(forward) >= minDot
			if facing then
				best = index
				bestDistance = distance
			end
		end
	end
	return best
end

return VacuumAimUtils
```

- [ ] **Step 6: Exemption.** Add to `EXEMPT_MODULES` (under `-- Cleanup Crew: Vacuum`):

```lua
	["ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants"] = "static tuning and names (no logic)",
```

- [ ] **Step 7: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```
Expected: `==> All checks passed.`

- [ ] **Step 8: Controller: Studio TestEZ.** Expected: VacuumCanisterUtils and VacuumAimUtils specs pass.

- [ ] **Step 9: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(vacuum): constants, canister and aim rules"
```

---
### Task 3: Office layout data and validation (pure)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`
- Create: `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`
- Create: `src/ServerScriptService/Features/Office/Data/OfficeLayoutConstants.luau`
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Produces (OfficeTypes): `Room = { id, name, minX, minZ, maxX, maxZ }`, `Door = { a: string, b: string, x: number, z: number, width: number }`, `MarkerKind = "pile" | "item" | "desk" | "locker" | "spawn"`, `Marker = { id, room, kind: MarkerKind, x, z }`, `Truck = { minX, minZ, maxX, maxZ, clockX, clockZ }`, `Layout = { startRoom: string, rooms: { Room }, doors: { Door }, markers: { Marker }, truck: Truck }`, `Edge = "minX" | "maxX" | "minZ" | "maxZ"`, `Segment = { x1, z1, x2, z2 }`, `Range = { min: number, max: number }`, `RollOptions = { quota: number, variant: string, piles: Range, salvage: Range }`, `PilePlan = { marker: string, kind: string, hides: string? }`, `ItemPlan = { marker: string, kind: string }`, `SearchPlan = { marker: string, kind: string? }`, `SpawnPlan = { piles: { PilePlan }, items: { ItemPlan }, searchables: { SearchPlan }, greed: ItemPlan?, trashValue: number }`.
- Produces (OfficeConstants): `ORIGIN = CFrame.new(1000, 0, 0)`, `MODEL_NAME`, `SHIFT_FOLDER_NAME`, `WALL_HEIGHT`, `WALL_THICKNESS`, `FLOOR_THICKNESS`, `MARKER_MARGIN = 2`, `DOOR_MIN_WIDTH = 4`, `DEEP_DEPTH = 2`, `TRASH_FACTOR = 1.5`, `PILES: Range = {18, 24}`, `SALVAGE: Range = {6, 9}`, `SEARCH_FILL_CHANCE`, `HIDE_CHANCE`, `HIDEABLE: { [string]: boolean }`, `ROLL_ATTEMPTS`, `DESK_SIZE`, `LOCKER_SIZE`, `BED_HEIGHT`, `CAB_SIZE`, `CLOCK_SIZE`, `SPAWN_HEIGHT`, `FLOOR_COLORS: { Color3 }`, `WALL_COLOR`, `DESK_COLOR`, `LOCKER_COLOR`, `TRUCK_COLOR`, `BED_COLOR`, `CLOCK_COLOR`.
- Produces (OfficeLayoutConstants): `LAYOUT: Layout` (7 rooms, 7 doors, truck, 4 spawn / 24 pile / 60 item / 8 desk / 4 locker markers).
- Produces (OfficeLayoutUtils): `room(layout, id) -> Room?`, `marker(layout, id) -> Marker?`, `markersOf(layout, kind) -> { Marker }`, `depths(layout) -> { [string]: number }`, `doorEdge(room, door) -> Edge?`, `wallSegments(room, doors) -> { Segment }`.
- Produces (OfficeLayoutRules): `validate(layout) -> (boolean, { string })`, `checkCapacity(layout) -> (boolean, string?)`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT
local ROOM = { id = "r", name = "R", minX = 0, minZ = 0, maxX = 20, maxZ = 10 }
local TRUCK = { minX = 0, minZ = 0, maxX = 1, maxZ = 1, clockX = 0, clockZ = 0 }

return function()
	describe("depths", function()
		it("counts doors from the loading bay", function()
			local depths = OfficeLayoutUtils.depths(LAYOUT)
			expect(depths.bay).to.equal(0)
			expect(depths.lobby).to.equal(1)
			expect(depths.open).to.equal(1)
			expect(depths.breakRoom).to.equal(2)
			expect(depths.manager).to.equal(2)
			expect(depths.server).to.equal(2)
			expect(depths.archive).to.equal(2)
		end)

		it("leaves an unreachable room out", function()
			local depths = OfficeLayoutUtils.depths({
				startRoom = "a",
				rooms = {},
				doors = { { a = "a", b = "b", x = 0, z = 0, width = 6 } },
				markers = {},
				truck = TRUCK,
			})
			expect(depths.b).to.equal(1)
			expect(depths.c).to.equal(nil)
		end)
	end)

	describe("doorEdge", function()
		it("finds the wall a door sits on", function()
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 0, width = 4 })).to.equal("minZ")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 10, width = 4 })).to.equal("maxZ")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 0, z = 5, width = 4 })).to.equal("minX")
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 20, z = 5, width = 4 })).to.equal("maxX")
		end)

		it("returns nil for a door off the walls or wider than its wall", function()
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 10, z = 5, width = 4 })).to.equal(nil)
			expect(OfficeLayoutUtils.doorEdge(ROOM, { a = "r", b = "s", x = 20, z = 5, width = 12 })).to.equal(nil)
		end)
	end)

	describe("wallSegments", function()
		it("builds four walls for a room without doors", function()
			expect(#OfficeLayoutUtils.wallSegments(ROOM, {})).to.equal(4)
		end)

		it("splits a wall around a door", function()
			local segments = OfficeLayoutUtils.wallSegments(ROOM, { { a = "r", b = "s", x = 10, z = 0, width = 4 } })
			expect(#segments).to.equal(5)
			expect(segments[1].x1).to.equal(0)
			expect(segments[1].x2).to.equal(8)
			expect(segments[1].z1).to.equal(0)
			expect(segments[2].x1).to.equal(12)
			expect(segments[2].x2).to.equal(20)
		end)

		it("ignores other rooms' doors", function()
			expect(#OfficeLayoutUtils.wallSegments(ROOM, { { a = "x", b = "y", x = 10, z = 0, width = 4 } })).to.equal(4)
		end)
	end)

	describe("lookups", function()
		it("finds rooms, markers and markers of a kind", function()
			expect(OfficeLayoutUtils.room(LAYOUT, "archive").name).to.equal("Archive")
			expect(OfficeLayoutUtils.marker(LAYOUT, "bay.spawn.1").room).to.equal("bay")
			expect(#OfficeLayoutUtils.markersOf(LAYOUT, "spawn")).to.equal(4)
			expect(OfficeLayoutUtils.room(LAYOUT, "attic")).to.equal(nil)
		end)
	end)
end
```

`src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutRules = require(script.Parent.OfficeLayoutRules)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local function fixture()
	return {
		startRoom = "a",
		rooms = {
			{ id = "a", name = "A", minX = 0, minZ = 0, maxX = 20, maxZ = 20 },
			{ id = "b", name = "B", minX = 20, minZ = 0, maxX = 40, maxZ = 20 },
		},
		doors = { { a = "a", b = "b", x = 20, z = 10, width = 6 } },
		markers = {
			{ id = "a.spawn.1", room = "a", kind = "spawn", x = 5, z = 5 },
			{ id = "b.pile.1", room = "b", kind = "pile", x = 30, z = 10 },
		},
		truck = { minX = 2, minZ = 10, maxX = 8, maxZ = 18, clockX = 12, clockZ = 4 },
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
	describe("the authored office", function()
		it("is valid", function()
			local ok, errors = OfficeLayoutRules.validate(OfficeLayoutConstants.LAYOUT)
			if not ok then
				error(table.concat(errors, "\n"))
			end
			expect(ok).to.equal(true)
		end)

		it("has the markers the spawn roll needs", function()
			local ok, reason = OfficeLayoutRules.checkCapacity(OfficeLayoutConstants.LAYOUT)
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
		end)
	end)

	describe("validate", function()
		it("accepts a small valid layout", function()
			local ok, errors = OfficeLayoutRules.validate(fixture())
			expect(ok).to.equal(true)
			expect(#errors).to.equal(0)
		end)

		it("reports a room nobody can reach", function()
			local layout = fixture()
			layout.doors = {}
			local ok, errors = OfficeLayoutRules.validate(layout)
			expect(ok).to.equal(false)
			expect(hasError(errors, 'room "b" cannot be reached')).to.equal(true)
		end)

		it("reports a marker outside its room, including too close to a wall", function()
			local layout = fixture()
			layout.markers[2].x = 21
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.pile.1" is not inside room "b"')).to.equal(true)
		end)

		it("reports a marker naming a missing room", function()
			local layout = fixture()
			layout.markers[2].room = "z"
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "b.pile.1" names a missing room')).to.equal(true)
		end)

		it("reports a door that is not on a wall both rooms share", function()
			local layout = fixture()
			layout.doors[1].x = 10
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "not on a wall both rooms share")).to.equal(true)
		end)

		it("reports a door narrower than the minimum", function()
			local layout = fixture()
			layout.doors[1].width = 2
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "narrower than")).to.equal(true)
		end)

		it("reports overlapping rooms", function()
			local layout = fixture()
			layout.rooms[2].minX = 15
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'rooms "a" and "b" overlap')).to.equal(true)
		end)

		it("reports duplicate marker ids", function()
			local layout = fixture()
			layout.markers[2].id = "a.spawn.1"
			layout.markers[2].room = "a"
			layout.markers[2].x = 10
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, 'marker "a.spawn.1" is defined twice')).to.equal(true)
		end)

		it("reports a truck outside the start room", function()
			local layout = fixture()
			layout.truck.maxX = 30
			local _, errors = OfficeLayoutRules.validate(layout)
			expect(hasError(errors, "truck")).to.equal(true)
		end)
	end)

	describe("checkCapacity", function()
		it("refuses a layout with too few pile markers", function()
			local ok, reason = OfficeLayoutRules.checkCapacity(fixture())
			expect(ok).to.equal(false)
			expect(string.find(reason, "pile markers", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Types** `src/ServerScriptService/Features/Office/Data/OfficeTypes.luau`:

```lua
--!strict
--[=[
	OfficeTypes: the Office feature's shapes. Layout coordinates are office-local studs on the floor plane:
	x across, z deep, the loading bay's corner at 0, 0 (OfficeConstants.ORIGIN places it in the world).
	Types only (spec-exempt).

	@class OfficeTypes
]=]

-- An axis-aligned rectangular room.
export type Room = {
	id: string,
	name: string,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
}

-- A doorway centred at (x, z) on the wall rooms `a` and `b` share.
export type Door = {
	a: string,
	b: string,
	x: number,
	z: number,
	width: number,
}

export type MarkerKind = "pile" | "item" | "desk" | "locker" | "spawn"

-- A place something can spawn (or a player appears): its id is "<room>.<kind>.<n>".
export type Marker = {
	id: string,
	room: string,
	kind: MarkerKind,
	x: number,
	z: number,
}

-- The truck bed's footprint (the banking zone) and the time clock beside it, inside the start room.
export type Truck = {
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	clockX: number,
	clockZ: number,
}

export type Layout = {
	startRoom: string,
	rooms: { Room },
	doors: { Door },
	markers: { Marker },
	truck: Truck,
}

export type Edge = "minX" | "maxX" | "minZ" | "maxZ"

-- One straight piece of wall, from (x1, z1) to (x2, z2), along a room edge.
export type Segment = {
	x1: number,
	z1: number,
	x2: number,
	z2: number,
}

export type Range = {
	min: number,
	max: number,
}

export type RollOptions = {
	quota: number,
	-- "B" hides some salvage under piles; "A" exposes it all.
	variant: string,
	piles: Range,
	salvage: Range,
}

-- A pile on a marker, possibly with a cargo item hidden under it.
export type PilePlan = {
	marker: string,
	kind: string,
	hides: string?,
}

export type ItemPlan = {
	marker: string,
	kind: string,
}

-- A desk or locker and what it holds (nil = empty).
export type SearchPlan = {
	marker: string,
	kind: string?,
}

-- One shift's spawns. `greed` records where the guaranteed greed target went (an item, pile or desk
-- marker); `trashValue` is the open-floor trash plus the dust bags the piles make.
export type SpawnPlan = {
	piles: { PilePlan },
	items: { ItemPlan },
	searchables: { SearchPlan },
	greed: ItemPlan?,
	trashValue: number,
}

return {}
```

- [ ] **Step 4: Constants** `src/ServerScriptService/Features/Office/Data/OfficeConstants.luau`:

```lua
--!strict
--[=[
	OfficeConstants: the office's placement, graybox sizes and the spawn roll's knobs (Cleanup Crew spec §4
	"Spawn guarantees", §5). Every number is a tuning hypothesis. Static data (spec-exempt).

	@class OfficeConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local PILES: OfficeTypes.Range = { min = 18, max = 24 }
local SALVAGE: OfficeTypes.Range = { min = 6, max = 9 }
-- Sizes small enough to hide under a pile (variant B).
local HIDEABLE: { [string]: boolean } = { tiny = true, medium = true }
local FLOOR_COLORS: { Color3 } = {
	Color3.fromRGB(96, 92, 86),
	Color3.fromRGB(70, 82, 96),
	Color3.fromRGB(88, 96, 78),
	Color3.fromRGB(100, 86, 80),
}

return table.freeze({
	-- Where the office's local 0, 0 sits in the world: far from the origin, where M4 builds the depot.
	ORIGIN = CFrame.new(1000, 0, 0),
	MODEL_NAME = "CleanupCrewOffice",
	SHIFT_FOLDER_NAME = "Shift",
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 1,
	FLOOR_THICKNESS = 1,
	-- A marker sits at least this far inside its room's walls.
	MARKER_MARGIN = 2,
	DOOR_MIN_WIDTH = 4,
	-- Rooms this many doors from the loading bay, or more, are "deep" (where the greed target goes).
	DEEP_DEPTH = 2,
	-- Trash on the floor, counting the piles' dust bags, is at least this times the quota.
	TRASH_FACTOR = 1.5,
	PILES = table.freeze(PILES),
	SALVAGE = table.freeze(SALVAGE),
	-- Chance a desk or locker holds something.
	SEARCH_FILL_CHANCE = 0.5,
	-- Variant B: chance a hideable salvage item goes under a pile instead of in the open.
	HIDE_CHANCE = 0.35,
	HIDEABLE = table.freeze(HIDEABLE),
	-- Seeds tried (seed, seed + 1, ...) before a roll that misses a guarantee is an error.
	ROLL_ATTEMPTS = 5,
	DESK_SIZE = Vector3.new(5, 3, 3),
	LOCKER_SIZE = Vector3.new(2.5, 7, 2.5),
	-- The truck bed is a platform this tall; the cab sits behind it.
	BED_HEIGHT = 3,
	CAB_SIZE = Vector3.new(12, 8, 6),
	CLOCK_SIZE = Vector3.new(1.5, 4, 1.5),
	-- Players appear this high above a spawn marker.
	SPAWN_HEIGHT = 3,
	FLOOR_COLORS = table.freeze(FLOOR_COLORS),
	WALL_COLOR = Color3.fromRGB(200, 198, 190),
	DESK_COLOR = Color3.fromRGB(140, 110, 80),
	LOCKER_COLOR = Color3.fromRGB(110, 120, 130),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	CLOCK_COLOR = Color3.fromRGB(200, 60, 50),
})
```

- [ ] **Step 5: The authored office** `src/ServerScriptService/Features/Office/Data/OfficeLayoutConstants.luau`:

```lua
--!strict
--[=[
	OfficeLayoutConstants: the authored Harlow & Finch office (Cleanup Crew spec §1 "authored geometry,
	randomised spawns", §5): seven rooms, their doors, the truck in the loading bay, and every spawn marker,
	in office-local studs (OfficeTypes). Geometry is built from this once (OfficeBuildSystem); each shift's
	spawns are rolled onto its markers (OfficeSpawnUtils).

	Depths from the loading bay: Reception and the open-plan office 1; the break room, Mr. Harlow's office,
	the server room and the archive 2 (deep).

	Static data (spec-exempt): OfficeLayoutRules.spec validates THIS layout, so an edit that disconnects a
	room or strays a marker fails the tests.

	@class OfficeLayoutConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local rooms: { OfficeTypes.Room } = {
	{ id = "bay", name = "Loading bay", minX = 0, minZ = 0, maxX = 40, maxZ = 30 },
	{ id = "lobby", name = "Reception", minX = 0, minZ = 30, maxX = 40, maxZ = 60 },
	{ id = "open", name = "Open-plan office", minX = 40, minZ = 0, maxX = 100, maxZ = 60 },
	{ id = "breakRoom", name = "Break room", minX = 0, minZ = 60, maxX = 30, maxZ = 90 },
	{ id = "manager", name = "Mr. Harlow's office", minX = 30, minZ = 60, maxX = 60, maxZ = 90 },
	{ id = "server", name = "Server room", minX = 60, minZ = 60, maxX = 100, maxZ = 90 },
	{ id = "archive", name = "Archive", minX = 100, minZ = 0, maxX = 130, maxZ = 40 },
}

local doors: { OfficeTypes.Door } = {
	{ a = "bay", b = "lobby", x = 20, z = 30, width = 8 },
	{ a = "bay", b = "open", x = 40, z = 15, width = 8 },
	{ a = "lobby", b = "open", x = 40, z = 45, width = 8 },
	{ a = "lobby", b = "breakRoom", x = 15, z = 60, width = 6 },
	{ a = "open", b = "manager", x = 50, z = 60, width = 6 },
	{ a = "open", b = "server", x = 80, z = 60, width = 6 },
	{ a = "open", b = "archive", x = 100, z = 20, width = 6 },
}

local markers: { OfficeTypes.Marker } = {}

-- Appends one marker per point, numbered from 1 within its room and kind.
local function add(room: string, kind: OfficeTypes.MarkerKind, points: { { number } })
	for index, point in points do
		table.insert(markers, { id = `{room}.{kind}.{index}`, room = room, kind = kind, x = point[1], z = point[2] })
	end
end

add("bay", "spawn", { { 28, 10 }, { 32, 10 }, { 28, 16 }, { 32, 16 } })
add("bay", "item", { { 34, 4 }, { 36, 26 }, { 26, 26 } })

add("lobby", "pile", { { 6, 36 }, { 18, 40 }, { 30, 52 }, { 10, 54 } })
add("lobby", "item", {
	{ 4, 34 },
	{ 14, 34 },
	{ 26, 36 },
	{ 36, 40 },
	{ 8, 46 },
	{ 20, 50 },
	{ 34, 56 },
	{ 4, 56 },
	{ 28, 46 },
})
add("lobby", "desk", { { 22, 44 } })

add("open", "pile", {
	{ 48, 8 },
	{ 62, 14 },
	{ 78, 6 },
	{ 92, 18 },
	{ 55, 30 },
	{ 70, 38 },
	{ 88, 34 },
	{ 50, 50 },
	{ 66, 54 },
	{ 84, 50 },
})
add("open", "item", {
	{ 44, 4 },
	{ 56, 6 },
	{ 70, 4 },
	{ 86, 10 },
	{ 96, 6 },
	{ 46, 22 },
	{ 60, 24 },
	{ 74, 22 },
	{ 94, 28 },
	{ 52, 40 },
	{ 66, 42 },
	{ 78, 40 },
	{ 96, 46 },
	{ 58, 56 },
	{ 74, 56 },
	{ 92, 56 },
	{ 44, 34 },
	{ 72, 32 },
	{ 84, 20 },
	{ 96, 38 },
	{ 44, 56 },
	{ 66, 10 },
})
add("open", "desk", { { 50, 18 }, { 68, 28 }, { 86, 26 }, { 60, 46 }, { 80, 46 } })

add("breakRoom", "pile", { { 6, 66 }, { 20, 80 } })
add("breakRoom", "item", { { 4, 64 }, { 14, 70 }, { 26, 66 }, { 8, 84 }, { 24, 86 }, { 16, 87 } })
add("breakRoom", "locker", { { 4, 78 } })

add("manager", "pile", { { 40, 70 }, { 52, 84 } })
add("manager", "item", { { 34, 64 }, { 46, 66 }, { 56, 72 }, { 36, 84 }, { 48, 86 }, { 56, 64 } })
add("manager", "desk", { { 45, 78 } })

add("server", "pile", { { 66, 70 }, { 80, 78 }, { 94, 66 } })
add("server", "item", { { 64, 64 }, { 74, 66 }, { 88, 70 }, { 70, 86 }, { 84, 86 }, { 96, 84 }, { 90, 62 } })
add("server", "locker", { { 97, 76 } })

add("archive", "pile", { { 106, 8 }, { 118, 20 }, { 124, 34 } })
add("archive", "item", { { 104, 4 }, { 114, 6 }, { 126, 8 }, { 108, 22 }, { 122, 28 }, { 110, 36 }, { 126, 38 } })
add("archive", "desk", { { 112, 30 } })
add("archive", "locker", { { 127, 14 }, { 127, 26 } })

local LAYOUT: OfficeTypes.Layout = {
	startRoom = "bay",
	rooms = rooms,
	doors = doors,
	markers = markers,
	-- The bed (the banking zone) and the time clock, inside the loading bay.
	truck = { minX = 4, minZ = 4, maxX = 16, maxZ = 20, clockX = 24, clockZ = 6 },
}

return table.freeze({
	LAYOUT = LAYOUT,
})
```

- [ ] **Step 6: Layout utils** `src/ServerScriptService/Features/Office/Utils/OfficeLayoutUtils.luau`:

```lua
--!strict
--[=[
	OfficeLayoutUtils: answers about a layout: lookups, each room's depth (doors from the start room, by
	breadth-first search), which wall a door sits on, and the wall pieces a room's edges break into around
	its doors. Pure.

	@class OfficeLayoutUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Door = OfficeTypes.Door
type Edge = OfficeTypes.Edge

local OfficeLayoutUtils = {}

function OfficeLayoutUtils.room(layout: Layout, id: string): Room?
	for _, room in layout.rooms do
		if room.id == id then
			return room
		end
	end
	return nil
end

function OfficeLayoutUtils.marker(layout: Layout, id: string): OfficeTypes.Marker?
	for _, marker in layout.markers do
		if marker.id == id then
			return marker
		end
	end
	return nil
end

-- The markers of one kind, in layout order.
function OfficeLayoutUtils.markersOf(layout: Layout, kind: OfficeTypes.MarkerKind): { OfficeTypes.Marker }
	local list: { OfficeTypes.Marker } = {}
	for _, marker in layout.markers do
		if marker.kind == kind then
			table.insert(list, marker)
		end
	end
	return list
end

--[=[
	Doors from the start room to each reachable room (the start room is 0). Unreachable rooms are absent.
]=]
function OfficeLayoutUtils.depths(layout: Layout): { [string]: number }
	local result: { [string]: number } = { [layout.startRoom] = 0 }
	local queue: { string } = { layout.startRoom }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, door in layout.doors do
			local other: string? = nil
			if door.a == current then
				other = door.b
			elseif door.b == current then
				other = door.a
			end
			if other ~= nil and result[other] == nil then
				result[other] = result[current] + 1
				table.insert(queue, other)
			end
		end
	end
	return result
end

--[=[
	The wall of `room` the door's whole opening sits on, or nil when it is on none of them.
]=]
function OfficeLayoutUtils.doorEdge(room: Room, door: Door): Edge?
	local half = door.width / 2
	if door.z - half >= room.minZ and door.z + half <= room.maxZ then
		if door.x == room.minX then
			return "minX"
		elseif door.x == room.maxX then
			return "maxX"
		end
	end
	if door.x - half >= room.minX and door.x + half <= room.maxX then
		if door.z == room.minZ then
			return "minZ"
		elseif door.z == room.maxZ then
			return "maxZ"
		end
	end
	return nil
end

local EDGES: { Edge } = { "minZ", "maxZ", "minX", "maxX" }

--[=[
	The pieces of wall around `room`, edge by edge (minZ, maxZ, minX, maxX), each edge broken around the
	openings of the room's own doors (doors naming other rooms are ignored).
]=]
function OfficeLayoutUtils.wallSegments(room: Room, doors: { Door }): { OfficeTypes.Segment }
	local segments: { OfficeTypes.Segment } = {}
	for _, edge in EDGES do
		local horizontal = edge == "minZ" or edge == "maxZ"
		local fixed = if edge == "minZ"
			then room.minZ
			elseif edge == "maxZ" then room.maxZ
			elseif edge == "minX" then room.minX
			else room.maxX
		local from = if horizontal then room.minX else room.minZ
		local to = if horizontal then room.maxX else room.maxZ
		local gaps: { { number } } = {}
		for _, door in doors do
			if (door.a == room.id or door.b == room.id) and OfficeLayoutUtils.doorEdge(room, door) == edge then
				local centre = if horizontal then door.x else door.z
				table.insert(gaps, { centre - door.width / 2, centre + door.width / 2 })
			end
		end
		table.sort(gaps, function(a, b)
			return a[1] < b[1]
		end)
		local function emit(a: number, b: number)
			if b - a <= 1e-6 then
				return
			end
			if horizontal then
				table.insert(segments, { x1 = a, z1 = fixed, x2 = b, z2 = fixed })
			else
				table.insert(segments, { x1 = fixed, z1 = a, x2 = fixed, z2 = b })
			end
		end
		local cursor = from
		for _, gap in gaps do
			emit(cursor, gap[1])
			cursor = gap[2]
		end
		emit(cursor, to)
	end
	return segments
end

return OfficeLayoutUtils
```

- [ ] **Step 7: Layout rules** `src/ServerScriptService/Features/Office/Rules/OfficeLayoutRules.luau`:

```lua
--!strict
--[=[
	OfficeLayoutRules: is a layout buildable and playable? `validate` lists every problem: duplicate or empty
	rooms, overlapping rooms, doors that name missing rooms, are too narrow or are not on a wall both rooms
	share, rooms the start room cannot reach, markers outside their room (or within MARKER_MARGIN of a
	wall), and a truck outside the start room. `checkCapacity` says whether the spawn roll has the markers
	it needs. OfficeServiceServer refuses to build a layout that fails either. Pure.

	@class OfficeLayoutRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room

local OfficeLayoutRules = {}

local function inside(room: Room, x: number, z: number, margin: number): boolean
	return x >= room.minX + margin and x <= room.maxX - margin and z >= room.minZ + margin and z <= room.maxZ - margin
end

--[=[
	Every problem with `layout`; ok when there are none.
]=]
function OfficeLayoutRules.validate(layout: Layout): (boolean, { string })
	local errors: { string } = {}
	local roomsById: { [string]: Room } = {}
	for _, room in layout.rooms do
		if roomsById[room.id] ~= nil then
			table.insert(errors, `room "{room.id}" is defined twice`)
		end
		if room.minX >= room.maxX or room.minZ >= room.maxZ then
			table.insert(errors, `room "{room.id}" has no floor area`)
		end
		roomsById[room.id] = room
	end
	for index, a in layout.rooms do
		for other = index + 1, #layout.rooms do
			local b = layout.rooms[other]
			if a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ then
				table.insert(errors, `rooms "{a.id}" and "{b.id}" overlap`)
			end
		end
	end
	local start = roomsById[layout.startRoom]
	if start == nil then
		table.insert(errors, `start room "{layout.startRoom}" does not exist`)
	end

	for _, door in layout.doors do
		local a = roomsById[door.a]
		local b = roomsById[door.b]
		if a == nil or b == nil then
			table.insert(errors, `door {door.a}-{door.b} names a missing room`)
		elseif door.width < OfficeConstants.DOOR_MIN_WIDTH then
			table.insert(errors, `door {door.a}-{door.b} is narrower than {OfficeConstants.DOOR_MIN_WIDTH} studs`)
		elseif OfficeLayoutUtils.doorEdge(a, door) == nil or OfficeLayoutUtils.doorEdge(b, door) == nil then
			table.insert(errors, `door {door.a}-{door.b} is not on a wall both rooms share`)
		end
	end

	local depths = OfficeLayoutUtils.depths(layout)
	for _, room in layout.rooms do
		if depths[room.id] == nil then
			table.insert(errors, `room "{room.id}" cannot be reached from "{layout.startRoom}"`)
		end
	end

	local seen: { [string]: boolean } = {}
	for _, marker in layout.markers do
		if seen[marker.id] then
			table.insert(errors, `marker "{marker.id}" is defined twice`)
		end
		seen[marker.id] = true
		local room = roomsById[marker.room]
		if room == nil then
			table.insert(errors, `marker "{marker.id}" names a missing room`)
		elseif not inside(room, marker.x, marker.z, OfficeConstants.MARKER_MARGIN) then
			table.insert(errors, `marker "{marker.id}" is not inside room "{room.id}"`)
		end
	end

	local truck = layout.truck
	if
		start ~= nil
		and not (
			inside(start, truck.minX, truck.minZ, 0)
			and inside(start, truck.maxX, truck.maxZ, 0)
			and inside(start, truck.clockX, truck.clockZ, 0)
		)
	then
		table.insert(errors, `the truck is not inside the start room "{start.id}"`)
	end
	return #errors == 0, errors
end

--[=[
	Whether the spawn roll can always run on this layout: enough pile markers for the largest pile roll, a
	spawn marker, and a deep item marker and a deep desk or locker for the greed target.
]=]
function OfficeLayoutRules.checkCapacity(layout: Layout): (boolean, string?)
	local piles = #OfficeLayoutUtils.markersOf(layout, "pile")
	if piles < OfficeConstants.PILES.max then
		return false, `{piles} pile markers; the roll needs {OfficeConstants.PILES.max}`
	end
	if #OfficeLayoutUtils.markersOf(layout, "spawn") == 0 then
		return false, "no spawn markers"
	end
	local depths = OfficeLayoutUtils.depths(layout)
	local deepItem = false
	local deepSearch = false
	for _, marker in layout.markers do
		local deep = (depths[marker.room] or 0) >= OfficeConstants.DEEP_DEPTH
		if deep and marker.kind == "item" then
			deepItem = true
		elseif deep and (marker.kind == "desk" or marker.kind == "locker") then
			deepSearch = true
		end
	end
	if not deepItem then
		return false, "no deep item marker for the greed target"
	end
	if not deepSearch then
		return false, "no deep desk or locker for a hidden greed target"
	end
	return true, nil
end

return OfficeLayoutRules
```

- [ ] **Step 8: Exemptions.** Add to `EXEMPT_MODULES` (under `-- Cleanup Crew: Office`):

```lua
	["ServerScriptService.Features.Office.Data.OfficeTypes"] = "type definitions only (no runtime logic)",
	["ServerScriptService.Features.Office.Data.OfficeConstants"] = "static placement, sizes and roll knobs (no logic)",
	["ServerScriptService.Features.Office.Data.OfficeLayoutConstants"] = "authored layout data; validated by OfficeLayoutRules.spec",
```

- [ ] **Step 9: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 10: Controller: Studio TestEZ.** Expected: OfficeLayoutUtils and OfficeLayoutRules specs pass (including "the authored office is valid").

- [ ] **Step 11: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(office): authored layout, layout utils and validation"
```

---

### Task 4: Office spawn roll and guarantees (pure, seeded)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Office/Rules/OfficeSpawnRules.luau` (+ `.spec.luau`)

**Interfaces:**
- Consumes: `OfficeTypes.*`, `OfficeConstants.*`, `OfficeLayoutUtils.depths/markersOf/marker` (Task 3); `CargoRegistry.get/ids/greedIds` (Task 1); `VacuumConstants.PILE_KIND_LIST/CANISTER_CAPACITY/DUST_BAG_KIND` (Task 2).
- Produces (OfficeSpawnUtils): `roll(layout: Layout, options: RollOptions, rng: Random) -> SpawnPlan`.
- Produces (OfficeSpawnRules): `check(plan: SpawnPlan, layout: Layout, quota: number) -> (boolean, string?)`, `trashValue(plan: SpawnPlan) -> number`.

Roll order (consumes `rng` in this order, so a seed always gives the same plan): pile count and markers → pile kinds → desk/locker contents → greed kind and place → salvage (variant B may hide under piles) → trash until the guarantee.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnUtils = require(script.Parent.OfficeSpawnUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeSpawnRules = require(ServerScriptService.Features.Office.Rules.OfficeSpawnRules)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local LAYOUT = OfficeLayoutConstants.LAYOUT
local QUOTA = 350

local function options(variant)
	return { quota = QUOTA, variant = variant, piles = OfficeConstants.PILES, salvage = OfficeConstants.SALVAGE }
end

local function roll(seed, variant)
	return OfficeSpawnUtils.roll(LAYOUT, options(variant or "B"), Random.new(seed))
end

return function()
	it("meets every guarantee for fifty seeds in both variants", function()
		for seed = 1, 50 do
			for _, variant in { "A", "B" } do
				local ok, reason = OfficeSpawnRules.check(roll(seed, variant), LAYOUT, QUOTA)
				if not ok then
					error(`seed {seed} variant {variant}: {reason}`)
				end
			end
		end
	end)

	it("rolls the same plan for the same seed", function()
		local first = roll(7)
		local second = roll(7)
		expect(#first.piles).to.equal(#second.piles)
		expect(#first.items).to.equal(#second.items)
		for index, pile in first.piles do
			expect(pile.marker).to.equal(second.piles[index].marker)
			expect(pile.kind).to.equal(second.piles[index].kind)
			expect(pile.hides).to.equal(second.piles[index].hides)
		end
		for index, item in first.items do
			expect(item.marker).to.equal(second.items[index].marker)
			expect(item.kind).to.equal(second.items[index].kind)
		end
		expect(first.greed.kind).to.equal(second.greed.kind)
	end)

	it("rolls a pile count inside the configured range", function()
		for seed = 1, 20 do
			local count = #roll(seed).piles
			expect(count >= OfficeConstants.PILES.min and count <= OfficeConstants.PILES.max).to.equal(true)
		end
	end)

	it("hides nothing under piles in variant A", function()
		for seed = 1, 20 do
			for _, pile in roll(seed, "A").piles do
				expect(pile.hides).to.equal(nil)
			end
		end
	end)

	it("hides some salvage under piles in variant B", function()
		local hidden = 0
		for seed = 1, 20 do
			for _, pile in roll(seed, "B").piles do
				if pile.hides ~= nil then
					hidden += 1
				end
			end
		end
		expect(hidden > 0).to.equal(true)
	end)

	it("keeps a hidden greed target out of the open", function()
		for seed = 1, 50 do
			local plan = roll(seed)
			for _, item in plan.items do
				expect(CargoRegistry.get(item.kind).hidden).to.equal(false)
			end
			if plan.greed.kind == "goldenStapler" then
				local marker = plan.greed.marker
				local inDesk = string.find(marker, ".desk.", 1, true) ~= nil
				local inLocker = string.find(marker, ".locker.", 1, true) ~= nil
				local underPile = string.find(marker, ".pile.", 1, true) ~= nil
				expect(inDesk or inLocker or underPile).to.equal(true)
			end
		end
	end)

	it("reports the trash total it rolled, counting canister output", function()
		for seed = 1, 10 do
			local plan = roll(seed)
			expect(plan.trashValue).to.equal(OfficeSpawnRules.trashValue(plan))
			expect(plan.trashValue >= QUOTA * OfficeConstants.TRASH_FACTOR).to.equal(true)
		end
	end)

	it("lists every desk and locker, empty or not", function()
		expect(#roll(3).searchables).to.equal(12)
	end)
end
```

`src/ServerScriptService/Features/Office/Rules/OfficeSpawnRules.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnRules = require(script.Parent.OfficeSpawnRules)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT

-- Three piles make one dust bag (15); quota 20 needs 30 trash.
local function plan()
	return {
		piles = {
			{ marker = "lobby.pile.1", kind = "paper" },
			{ marker = "lobby.pile.2", kind = "debris" },
			{ marker = "lobby.pile.3", kind = "cables" },
		},
		items = {
			{ marker = "lobby.item.1", kind = "rubbishBag" },
			{ marker = "lobby.item.2", kind = "rubbishBag" },
			{ marker = "archive.item.1", kind = "fishTank" },
		},
		searchables = {},
		greed = { marker = "archive.item.1", kind = "fishTank" },
		trashValue = 35,
	}
end

return function()
	it("accepts a plan that meets the guarantees", function()
		local ok, reason = OfficeSpawnRules.check(plan(), LAYOUT, 20)
		expect(reason).to.equal(nil)
		expect(ok).to.equal(true)
	end)

	it("counts the dust bags the piles make", function()
		expect(OfficeSpawnRules.trashValue(plan())).to.equal(35)
	end)

	it("refuses too little trash", function()
		local short = plan()
		table.remove(short.items, 2)
		local ok, reason = OfficeSpawnRules.check(short, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("only 25 trash for a quota of 20")
	end)

	it("refuses a missing greed target", function()
		local noGreed = plan()
		noGreed.greed = nil
		local ok, reason = OfficeSpawnRules.check(noGreed, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("no greed target")
	end)

	it("refuses a greed target placed shallow", function()
		local shallow = plan()
		shallow.items[3].marker = "lobby.item.3"
		shallow.greed.marker = "lobby.item.3"
		local ok, reason = OfficeSpawnRules.check(shallow, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("the greed target is not placed deep")
	end)

	it("refuses a greed record naming a non-greed item", function()
		local wrong = plan()
		wrong.greed.kind = "printer"
		local ok, reason = OfficeSpawnRules.check(wrong, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('"printer" is not a greed target')
	end)

	it("refuses a marker used twice", function()
		local twice = plan()
		twice.items[2].marker = "lobby.item.1"
		local ok, reason = OfficeSpawnRules.check(twice, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('marker "lobby.item.1" is used twice')
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Spawn rules** `src/ServerScriptService/Features/Office/Rules/OfficeSpawnRules.luau`:

```lua
--!strict
--[=[
	OfficeSpawnRules: does one shift's spawn plan keep the spec's promises (§4 "Spawn guarantees")? Trash on
	the floor, counting the dust bags the piles make, is at least TRASH_FACTOR × the quota; one greed target
	sits in a deep room; no marker holds two things. Pure.

	@class OfficeSpawnRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type SpawnPlan = OfficeTypes.SpawnPlan

local OfficeSpawnRules = {}

--[=[
	The clearance a plan puts on the floor: open-floor trash items plus one dust bag per full canister of
	piles. Unknown kinds count nothing (`check` refuses them).
]=]
function OfficeSpawnRules.trashValue(plan: SpawnPlan): number
	local dustBag = CargoRegistry.get(VacuumConstants.DUST_BAG_KIND)
	local total = math.floor(#plan.piles / VacuumConstants.CANISTER_CAPACITY) * (if dustBag ~= nil then dustBag.value else 0)
	for _, item in plan.items do
		local def = CargoRegistry.get(item.kind)
		if def ~= nil and def.category == "trash" then
			total += def.value
		end
	end
	return total
end

--[=[
	Ok when `plan` meets every guarantee for `quota`; otherwise the first broken one.
]=]
function OfficeSpawnRules.check(plan: SpawnPlan, layout: OfficeTypes.Layout, quota: number): (boolean, string?)
	local used: { [string]: boolean } = {}
	local markers: { string } = {}
	for _, pile in plan.piles do
		table.insert(markers, pile.marker)
	end
	for _, item in plan.items do
		if CargoRegistry.get(item.kind) == nil then
			return false, `unknown cargo "{item.kind}"`
		end
		table.insert(markers, item.marker)
	end
	for _, marker in markers do
		if used[marker] then
			return false, `marker "{marker}" is used twice`
		end
		used[marker] = true
	end

	local trash = OfficeSpawnRules.trashValue(plan)
	if trash < quota * OfficeConstants.TRASH_FACTOR then
		return false, `only {trash} trash for a quota of {quota}`
	end

	local greed = plan.greed
	if greed == nil then
		return false, "no greed target"
	end
	local def = CargoRegistry.get(greed.kind)
	if def == nil or not def.greed then
		return false, `"{greed.kind}" is not a greed target`
	end
	local marker = OfficeLayoutUtils.marker(layout, greed.marker)
	local depths = OfficeLayoutUtils.depths(layout)
	if marker == nil or (depths[marker.room] or 0) < OfficeConstants.DEEP_DEPTH then
		return false, "the greed target is not placed deep"
	end
	return true, nil
end

return OfficeSpawnRules
```

- [ ] **Step 4: The roll** `src/ServerScriptService/Features/Office/Utils/OfficeSpawnUtils.luau`:

```lua
--!strict
--[=[
	OfficeSpawnUtils: rolls one shift's spawns onto the layout's markers (Cleanup Crew spec §4 "Spawn
	guarantees", §1 "randomised spawns"). Deterministic for a given Random: the catalog is walked in sorted
	order and `rng` is consumed in a fixed sequence:

	1. piles: a count in `options.piles`, on shuffled pile markers, each a random pile kind;
	2. desks and lockers: each holds a desk-weighted item with SEARCH_FILL_CHANCE, else nothing;
	3. the greed target (fish tank, filing cabinet or golden stapler), always in a deep room: a hidden one
	   (the stapler) in a deep desk or locker (else under a deep pile), the others on a deep item marker;
	4. salvage: a count in `options.salvage`; in variant "B" a hideable one may go under a free pile;
	5. trash on the remaining item markers until the floor's trash (plus the piles' dust bags) reaches
	   TRASH_FACTOR × quota.

	OfficeSpawnRules.check verifies the result. Pure.

	@class OfficeSpawnUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type Marker = OfficeTypes.Marker
type ItemDef = CargoTypes.ItemDef

local function shuffled(list: { Marker }, rng: Random): { Marker }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local swap = rng:NextInteger(1, index)
		copy[index], copy[swap] = copy[swap], copy[index]
	end
	return copy
end

-- A catalog id chosen by weight; nil when every weight is 0.
local function pickWeighted(weightOf: (def: ItemDef) -> number, rng: Random): string?
	local total = 0
	local last: string? = nil
	for _, id in CargoRegistry.ids() do
		local def = CargoRegistry.get(id)
		local weight = if def ~= nil then weightOf(def) else 0
		if weight > 0 then
			total += weight
			last = id
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, id in CargoRegistry.ids() do
		local def = CargoRegistry.get(id)
		local weight = if def ~= nil then weightOf(def) else 0
		if weight > 0 then
			if roll < weight then
				return id
			end
			roll -= weight
		end
	end
	return last
end

local function trashWeight(def: ItemDef): number
	return if def.category == "trash" then def.spawnWeight else 0
end

local function salvageWeight(def: ItemDef): number
	return if def.category == "salvage" and not def.greed and not def.hidden then def.spawnWeight else 0
end

local function deskWeight(def: ItemDef): number
	return if def.greed then 0 else def.deskWeight
end

local OfficeSpawnUtils = {}

function OfficeSpawnUtils.roll(
	layout: OfficeTypes.Layout,
	options: OfficeTypes.RollOptions,
	rng: Random
): OfficeTypes.SpawnPlan
	local depths = OfficeLayoutUtils.depths(layout)
	local function isDeep(marker: Marker): boolean
		return (depths[marker.room] or 0) >= OfficeConstants.DEEP_DEPTH
	end

	-- 1. Piles.
	local pileMarkers = shuffled(OfficeLayoutUtils.markersOf(layout, "pile"), rng)
	local pileCount = math.min(rng:NextInteger(options.piles.min, options.piles.max), #pileMarkers)
	local kinds = VacuumConstants.PILE_KIND_LIST
	local piles: { OfficeTypes.PilePlan } = {}
	for index = 1, pileCount do
		table.insert(piles, { marker = pileMarkers[index].id, kind = kinds[rng:NextInteger(1, #kinds)] })
	end
	local function freePile(deepOnly: boolean): OfficeTypes.PilePlan?
		for index, pile in piles do
			if pile.hides == nil and (not deepOnly or isDeep(pileMarkers[index])) then
				return pile
			end
		end
		return nil
	end

	-- 2. Desks and lockers, in layout order.
	local searchMarkers = OfficeLayoutUtils.markersOf(layout, "desk")
	for _, marker in OfficeLayoutUtils.markersOf(layout, "locker") do
		table.insert(searchMarkers, marker)
	end
	local searchables: { OfficeTypes.SearchPlan } = {}
	for _, marker in searchMarkers do
		local kind = if rng:NextNumber() < OfficeConstants.SEARCH_FILL_CHANCE then pickWeighted(deskWeight, rng) else nil
		table.insert(searchables, { marker = marker.id, kind = kind })
	end

	local itemPool = shuffled(OfficeLayoutUtils.markersOf(layout, "item"), rng)
	local items: { OfficeTypes.ItemPlan } = {}
	local function takeMarker(deepOnly: boolean): Marker?
		for index, marker in itemPool do
			if not deepOnly or isDeep(marker) then
				table.remove(itemPool, index)
				return marker
			end
		end
		return nil
	end

	-- 3. The greed target, deep.
	local greedIds = CargoRegistry.greedIds()
	local greedKind = greedIds[rng:NextInteger(1, #greedIds)]
	local greedDef = CargoRegistry.get(greedKind)
	local greed: OfficeTypes.ItemPlan? = nil
	if greedDef ~= nil and greedDef.hidden then
		local deepSearch: { number } = {}
		for index, marker in searchMarkers do
			if isDeep(marker) then
				table.insert(deepSearch, index)
			end
		end
		if #deepSearch > 0 then
			local index = deepSearch[rng:NextInteger(1, #deepSearch)]
			searchables[index].kind = greedKind
			greed = { marker = searchMarkers[index].id, kind = greedKind }
		else
			local pile = freePile(true)
			if pile ~= nil then
				pile.hides = greedKind
				greed = { marker = pile.marker, kind = greedKind }
			end
		end
	else
		local marker = takeMarker(true)
		if marker ~= nil then
			greed = { marker = marker.id, kind = greedKind }
			table.insert(items, greed)
		end
	end

	-- 4. Salvage.
	local salvageCount = rng:NextInteger(options.salvage.min, options.salvage.max)
	for _ = 1, salvageCount do
		local kind = pickWeighted(salvageWeight, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil then
			break
		end
		local hideable = options.variant == "B" and OfficeConstants.HIDEABLE[def.size] == true
		local pile = if hideable and rng:NextNumber() < OfficeConstants.HIDE_CHANCE then freePile(false) else nil
		if pile ~= nil then
			pile.hides = kind
		else
			local marker = takeMarker(false)
			if marker == nil then
				break
			end
			table.insert(items, { marker = marker.id, kind = kind })
		end
	end

	-- 5. Trash until the guarantee.
	local dustBag = CargoRegistry.get(VacuumConstants.DUST_BAG_KIND)
	local trashValue = math.floor(pileCount / VacuumConstants.CANISTER_CAPACITY)
		* (if dustBag ~= nil then dustBag.value else 0)
	local target = options.quota * OfficeConstants.TRASH_FACTOR
	while trashValue < target do
		local kind = pickWeighted(trashWeight, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		local marker = takeMarker(false)
		if kind == nil or def == nil or marker == nil then
			break
		end
		table.insert(items, { marker = marker.id, kind = kind })
		trashValue += def.value
	end

	return {
		piles = piles,
		items = items,
		searchables = searchables,
		greed = greed,
		trashValue = trashValue,
	}
end

return OfficeSpawnUtils
```

- [ ] **Step 5: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 6: Controller: Studio TestEZ.** Expected: OfficeSpawnUtils (including "fifty seeds in both variants") and OfficeSpawnRules specs pass. Worst case by construction: 18 piles → 90; 60 item markers − at most 9 salvage − 1 greed = 50 trash markers × 10 = 500; 590 ≥ 525.

- [ ] **Step 7: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(office): seeded spawn roll with trash and greed guarantees"
```

---

### Task 5: Shift phase and vote rules (pure)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`
- Create: `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Shift/Rules/ShiftVoteRules.luau` (+ `.spec.luau`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `RoundTypes.RoundState = { phase: Phase, round: number, endsAt: number?, outcome: string? }` (`src/ReplicatedStorage/Shared/Features/Round/Data/RoundTypes.luau`).
- Produces (ShiftTypes): `ShiftPhase = "lobby" | "starting" | "running" | "results"`, `ShiftSub = "normal" | "clockout"`, `Variant = "A" | "B"`, `Vote = "another" | "depot"`, `TickAction = "none" | "start" | "endShift" | "resolveVote"`, `ShiftState = { phase, sub, shift: number, endsAt: number?, clockOutAt: number?, voteEndsAt: number?, quota: number, quotaMet: boolean, variant: Variant }`, `CrewStats = { userId, name, banked, piles, salvage }`, `CrewLine = { name, banked, piles, salvage }`, `Award = { title: string, name: string }`, `ShiftResults = { outcome, quota, cleared, bonus, salvage, piles, quotaMet, crew: { CrewLine }, awards: { Award } }`, `ShiftSnapshot = { phase, sub, shift, endsAt?, clockOutAt?, voteEndsAt?, quota, cleared, bonus, quotaMet, variant, votesAnother, votesDepot, results: ShiftResults? }`.
- Produces (ShiftConstants): `WORLD_ENTRY = "shift"`, `QUOTA = 350`, `SHIFT_SECONDS = 420`, `ARRIVAL_SECONDS = 5`, `CLOCK_OUT_SECONDS = 10`, `VOTE_SECONDS = 30`, `MIN_PLAYERS = 1`, `VARIANT: Variant = "B"`, `SALVAGE_MULTIPLIER = 1`, `OVERTIME_SALVAGE_MULTIPLIER = 1.5`, `CLEARANCE = "clearance"`, `BONUS = "bonus"`, `SCORE_BANKED`, `SCORE_PILES`, `SCORE_SALVAGE`, `OUTCOME_CLOCKOUT = "clockout"`, `OUTCOME_RESET = "reset"`, `CLOCK_OUT_KIND = "shift-clockout"`, `TICK_INTERVAL = 0.25`, `HUD_ORDER = 10`.
- Produces (ShiftPhaseRules): `initial(quota, variant) -> ShiftState`, `follow(state, round: RoundState, now) -> ShiftState?`, `clockOut(state, now) -> ShiftState?`, `markQuota(state, cleared) -> ShiftState?`, `tick(state, now, present: number) -> TickAction`, `toLobby(state) -> ShiftState`.
- Produces (ShiftVoteRules): `parse(value: unknown) -> Vote?`, `tally(votes: { [number]: Vote }, present: { number }) -> (number, number)`, `decide(votes, present, timedOut: boolean) -> Vote?`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.spec.luau`:

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

local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("running", { endsAt = 520 }), 100)
end

local function results()
	return ShiftPhaseRules.follow(running(), round("results", { outcome = "timeout" }), 600)
end

return function()
	it("starts in the lobby with the quota and variant", function()
		local state = ShiftPhaseRules.initial(350, "A")
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
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

		it("enters running with the shift number and end time, quota unmet", function()
			local state = running()
			expect(state.phase).to.equal("running")
			expect(state.sub).to.equal("normal")
			expect(state.shift).to.equal(1)
			expect(state.endsAt).to.equal(520)
			expect(state.quotaMet).to.equal(false)
		end)

		it("holds results with a vote deadline when Round shows results", function()
			local state = results()
			expect(state.phase).to.equal("results")
			expect(state.voteEndsAt).to.equal(600 + ShiftConstants.VOTE_SECONDS)
			expect(state.endsAt).to.equal(nil)
			expect(state.clockOutAt).to.equal(nil)
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
	end)

	describe("markQuota", function()
		it("marks the quota met once it is reached", function()
			expect(ShiftPhaseRules.markQuota(running(), 349)).to.equal(nil)
			local state = ShiftPhaseRules.markQuota(running(), 350)
			expect(state.quotaMet).to.equal(true)
			expect(ShiftPhaseRules.markQuota(state, 400)).to.equal(nil)
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
		local state = ShiftPhaseRules.toLobby(ShiftPhaseRules.markQuota(ShiftPhaseRules.clockOut(running(), 200), 400))
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.shift).to.equal(1)
		expect(state.quotaMet).to.equal(false)
		expect(state.clockOutAt).to.equal(nil)
		expect(state.endsAt).to.equal(nil)
		expect(state.quota).to.equal(350)
	end)
end
```

`src/ServerScriptService/Features/Shift/Rules/ShiftVoteRules.spec.luau`:

```lua
local ShiftVoteRules = require(script.Parent.ShiftVoteRules)

return function()
	it("parses only the two choices", function()
		expect(ShiftVoteRules.parse("another")).to.equal("another")
		expect(ShiftVoteRules.parse("depot")).to.equal("depot")
		expect(ShiftVoteRules.parse("quit")).to.equal(nil)
		expect(ShiftVoteRules.parse(5)).to.equal(nil)
	end)

	it("tallies only players still present", function()
		local another, depot = ShiftVoteRules.tally({ [1] = "another", [2] = "depot", [9] = "depot" }, { 1, 2 })
		expect(another).to.equal(1)
		expect(depot).to.equal(1)
	end)

	describe("decide", function()
		it("waits while the vote is open and undecided", function()
			expect(ShiftVoteRules.decide({ [1] = "another" }, { 1, 2, 3 }, false)).to.equal(nil)
		end)

		it("lets a strict majority decide early", function()
			expect(ShiftVoteRules.decide({ [1] = "depot", [2] = "depot" }, { 1, 2, 3 }, false)).to.equal("depot")
		end)

		it("decides at once for a solo player", function()
			expect(ShiftVoteRules.decide({ [1] = "another" }, { 1 }, false)).to.equal("another")
		end)

		it("keeps working on a tie once everyone has voted", function()
			expect(ShiftVoteRules.decide({ [1] = "another", [2] = "depot" }, { 1, 2 }, false)).to.equal("another")
		end)

		it("times out to the larger side", function()
			expect(ShiftVoteRules.decide({ [1] = "depot" }, { 1, 2, 3 }, true)).to.equal("depot")
		end)

		it("times out to another with no votes, even in an empty server", function()
			expect(ShiftVoteRules.decide({}, { 1, 2 }, true)).to.equal("another")
			expect(ShiftVoteRules.decide({}, {}, true)).to.equal("another")
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Types** `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau`:

```lua
--!strict
--[=[
	ShiftTypes: one Cleanup Crew shift's shapes (spec §3, §6.3, §6.5). Types only (spec-exempt).

	@class ShiftTypes
]=]

-- Mirrors Round's phases, except that Shift holds `results` itself until the crew votes.
export type ShiftPhase = "lobby" | "starting" | "running" | "results"

-- What a running shift is doing. M2 adds "break" | "warning" | "overtime".
export type ShiftSub = "normal" | "clockout"

-- The A/B validation switch (spec §4): B hides some salvage under piles, A exposes it all.
export type Variant = "A" | "B"

export type Vote = "another" | "depot"

-- What the service should do on this clock step.
export type TickAction = "none" | "start" | "endShift" | "resolveVote"

-- The server's shift machine. Times are server time (workspace:GetServerTimeNow()).
export type ShiftState = {
	phase: ShiftPhase,
	sub: ShiftSub,
	-- Shifts started on this server (Round's run number).
	shift: number,
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

-- The performance review (plain in M1).
export type ShiftResults = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	-- Salvage items loaded, and piles vacuumed, by the whole crew.
	salvage: number,
	piles: number,
	quotaMet: boolean,
	crew: { CrewLine },
	awards: { Award },
}

-- What every client sees (the `shift` world entry).
export type ShiftSnapshot = {
	phase: ShiftPhase,
	sub: ShiftSub,
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

- [ ] **Step 4: Constants** `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau`:

```lua
--!strict
--[=[
	ShiftConstants: the shift's pacing and names (Cleanup Crew spec §3, §4 "Pacing"). Every number is a
	tuning hypothesis. Static data (spec-exempt).

	@class ShiftConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local VARIANT: ShiftTypes.Variant = "B"

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
	-- Salvage multiplier now, and in overtime (M2).
	SALVAGE_MULTIPLIER = 1,
	OVERTIME_SALVAGE_MULTIPLIER = 1.5,
	-- Round team counters and per-player scores.
	CLEARANCE = "clearance",
	BONUS = "bonus",
	SCORE_BANKED = "banked",
	SCORE_PILES = "piles",
	SCORE_SALVAGE = "salvage",
	-- The outcome a clock out ends the run with (Round sets "timeout" and "abandoned" itself).
	OUTCOME_CLOCKOUT = "clockout",
	-- The outcome a mid-shift reset (Studio test runs) ends the run with; no results are shown for it.
	OUTCOME_RESET = "reset",
	-- The interaction kind on the truck's time clock.
	CLOCK_OUT_KIND = "shift-clockout",
	TICK_INTERVAL = 0.25,
	-- HUD widget order (the Toast stack draws above, at 1000).
	HUD_ORDER = 10,
})
```

- [ ] **Step 5: Phase rules** `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau`:

```lua
--!strict
--[=[
	ShiftPhaseRules: a Cleanup Crew shift as pure functions over ShiftState (spec §3, §6.5). The shift
	follows Round's phases (lobby → starting → running → results) but keeps `results` itself until the crew
	votes: Round is configured to leave results at once (it cannot be held or cut short). While running, the
	sub-state is `normal` or `clockout`; M2 adds break, warning and overtime here.

	Every function returns the NEXT state, or nil when nothing changes; `tick` returns what the service
	should do on this clock step.

	@class ShiftPhaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type ShiftState = ShiftTypes.ShiftState

local ShiftPhaseRules = {}

function ShiftPhaseRules.initial(quota: number, variant: ShiftTypes.Variant): ShiftState
	return { phase = "lobby", sub = "normal", shift = 0, quota = quota, quotaMet = false, variant = variant }
end

--[=[
	Back to waiting, keeping the shift count, quota and variant (a cancelled countdown, or a reset after the
	vote).
]=]
function ShiftPhaseRules.toLobby(state: ShiftState): ShiftState
	return {
		phase = "lobby",
		sub = "normal",
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
			shift = round.round,
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
	Starts the clock-out countdown. Only while running and not already counting down.
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
	Marks the quota met the first time clearance reaches it during a running shift.
]=]
function ShiftPhaseRules.markQuota(state: ShiftState, cleared: number): ShiftState?
	if state.phase ~= "running" or state.quotaMet or cleared < state.quota then
		return nil
	end
	local nextState = table.clone(state)
	nextState.quotaMet = true
	return nextState
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

- [ ] **Step 6: Vote rules** `src/ServerScriptService/Features/Shift/Rules/ShiftVoteRules.luau`:

```lua
--!strict
--[=[
	ShiftVoteRules: the results vote (spec §3 step 7): Another shift or Back to depot. Only players still in
	the server count. A strict majority decides at once; otherwise the vote waits until everyone has voted or
	the time is up, then the larger side wins and a tie (or no votes at all) keeps working: another shift.
	Pure.

	@class ShiftVoteRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Vote = ShiftTypes.Vote

local ShiftVoteRules = {}

-- A vote from the wire, or nil when it is not one of the two choices.
function ShiftVoteRules.parse(value: unknown): Vote?
	if value == "another" then
		return "another"
	elseif value == "depot" then
		return "depot"
	end
	return nil
end

-- Votes for each side among `present` (UserIds still in the server).
function ShiftVoteRules.tally(votes: { [number]: Vote }, present: { number }): (number, number)
	local another = 0
	local depot = 0
	for _, userId in present do
		local vote = votes[userId]
		if vote == "another" then
			another += 1
		elseif vote == "depot" then
			depot += 1
		end
	end
	return another, depot
end

-- The decision, or nil while the vote is still open.
function ShiftVoteRules.decide(votes: { [number]: Vote }, present: { number }, timedOut: boolean): Vote?
	local another, depot = ShiftVoteRules.tally(votes, present)
	if another * 2 > #present then
		return "another"
	end
	if depot * 2 > #present then
		return "depot"
	end
	local everyone = #present > 0 and another + depot >= #present
	if not everyone and not timedOut then
		return nil
	end
	return if depot > another then "depot" else "another"
end

return ShiftVoteRules
```

Note: `decide({}, {}, true)` returns "another" because `0 * 2 > 0` is false and the timeout branch picks "another". And `decide({}, {}, false)` returns nil (`everyone` needs at least one player present).

- [ ] **Step 7: Exemptions.** Add to `EXEMPT_MODULES` (under `-- Cleanup Crew: Shift`):

```lua
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants"] = "static pacing and names (no logic)",
```

- [ ] **Step 8: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 9: Controller: Studio TestEZ.** Expected: ShiftPhaseRules and ShiftVoteRules specs pass.

- [ ] **Step 10: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(shift): phase machine and vote rules"
```

---

### Task 6: Shift results and snapshot codec (pure)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau` (+ `.spec.luau`)

**Interfaces:**
- Consumes: `ShiftTypes.*` (Task 5); `WorldTypes.WorldValue` (`src/ReplicatedStorage/Shared/Data/WorldTypes.luau`).
- Produces (ShiftResultsUtils): `ResultsInput = { outcome: string, quota: number, cleared: number, bonus: number, quotaMet: boolean, crew: { CrewStats } }`; `build(input: ResultsInput) -> ShiftResults` (crew sorted by banked, then name; awards "Top Hauler" / "Dust Devil" / "Treasure Hunter" for the most banked / piles / salvage, none when nobody scored).
- Produces (ShiftSnapshotUtils): `build(state: ShiftState, cleared: number, bonus: number, votesAnother: number, votesDepot: number, results: ShiftResults?) -> ShiftSnapshot`; `decode(value: WorldValue?) -> ShiftSnapshot?`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.spec.luau`:

```lua
local ShiftResultsUtils = require(script.Parent.ShiftResultsUtils)

local function input(crew)
	return { outcome = "clockout", quota = 350, cleared = 380, bonus = 95, quotaMet = true, crew = crew }
end

local CREW = {
	{ userId = 1, name = "Ava", banked = 120, piles = 3, salvage = 1 },
	{ userId = 2, name = "Ben", banked = 200, piles = 6, salvage = 0 },
	{ userId = 3, name = "Cat", banked = 0, piles = 0, salvage = 0 },
}

return function()
	it("copies the shift's totals and sums the crew's", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(results.outcome).to.equal("clockout")
		expect(results.cleared).to.equal(380)
		expect(results.quota).to.equal(350)
		expect(results.bonus).to.equal(95)
		expect(results.quotaMet).to.equal(true)
		expect(results.piles).to.equal(9)
		expect(results.salvage).to.equal(1)
	end)

	it("lists the crew by amount banked", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(results.crew[1].name).to.equal("Ben")
		expect(results.crew[2].name).to.equal("Ava")
		expect(results.crew[3].name).to.equal("Cat")
	end)

	it("hands out an award per category to the leader", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(#results.awards).to.equal(3)
		expect(results.awards[1].title).to.equal("Top Hauler")
		expect(results.awards[1].name).to.equal("Ben")
		expect(results.awards[2].title).to.equal("Dust Devil")
		expect(results.awards[2].name).to.equal("Ben")
		expect(results.awards[3].title).to.equal("Treasure Hunter")
		expect(results.awards[3].name).to.equal("Ava")
	end)

	it("gives no award when nobody scored in it", function()
		local results = ShiftResultsUtils.build(input({ { userId = 1, name = "Ava", banked = 0, piles = 0, salvage = 0 } }))
		expect(#results.awards).to.equal(0)
	end)

	it("breaks ties by name", function()
		local results = ShiftResultsUtils.build(input({
			{ userId = 1, name = "Zed", banked = 50, piles = 2, salvage = 0 },
			{ userId = 2, name = "Amy", banked = 50, piles = 2, salvage = 0 },
		}))
		expect(results.crew[1].name).to.equal("Amy")
		expect(results.awards[1].name).to.equal("Amy")
		expect(results.awards[2].name).to.equal("Amy")
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.spec.luau`:

```lua
local ShiftSnapshotUtils = require(script.Parent.ShiftSnapshotUtils)

local function state(extra)
	local value = {
		phase = "running",
		sub = "normal",
		shift = 2,
		endsAt = 900,
		quota = 350,
		quotaMet = false,
		variant = "B",
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local RESULTS = {
	outcome = "clockout",
	quota = 350,
	cleared = 380,
	bonus = 95,
	salvage = 3,
	piles = 12,
	quotaMet = true,
	crew = { { name = "Ava", banked = 200, piles = 6, salvage = 2 } },
	awards = { { title = "Top Hauler", name = "Ava" } },
}

return function()
	it("round-trips a running shift", function()
		local snapshot = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 120, 40, 0, 0, nil))
		expect(snapshot).to.be.ok()
		expect(snapshot.phase).to.equal("running")
		expect(snapshot.sub).to.equal("normal")
		expect(snapshot.shift).to.equal(2)
		expect(snapshot.endsAt).to.equal(900)
		expect(snapshot.cleared).to.equal(120)
		expect(snapshot.bonus).to.equal(40)
		expect(snapshot.quota).to.equal(350)
		expect(snapshot.variant).to.equal("B")
		expect(snapshot.results).to.equal(nil)
	end)

	it("round-trips a clock-out countdown", function()
		local snapshot =
			ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ sub = "clockout", clockOutAt = 500 }), 0, 0, 0, 0, nil))
		expect(snapshot.sub).to.equal("clockout")
		expect(snapshot.clockOutAt).to.equal(500)
	end)

	it("round-trips results and votes", function()
		local value = ShiftSnapshotUtils.build(
			state({ phase = "results", endsAt = nil, voteEndsAt = 1000, quotaMet = true }),
			380,
			95,
			2,
			1,
			RESULTS
		)
		local snapshot = ShiftSnapshotUtils.decode(value)
		expect(snapshot.phase).to.equal("results")
		expect(snapshot.voteEndsAt).to.equal(1000)
		expect(snapshot.votesAnother).to.equal(2)
		expect(snapshot.votesDepot).to.equal(1)
		expect(snapshot.results.cleared).to.equal(380)
		expect(snapshot.results.crew[1].name).to.equal("Ava")
		expect(snapshot.results.awards[1].title).to.equal("Top Hauler")
	end)

	it("defaults absent vote counts to zero", function()
		local snapshot = ShiftSnapshotUtils.decode({
			phase = "lobby",
			sub = "normal",
			shift = 0,
			quota = 350,
			cleared = 0,
			bonus = 0,
			quotaMet = false,
			variant = "B",
		})
		expect(snapshot.votesAnother).to.equal(0)
		expect(snapshot.votesDepot).to.equal(0)
	end)

	it("rejects malformed values", function()
		local good = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
		local function with(key, value)
			local copy = table.clone(good)
			copy[key] = value
			return copy
		end
		expect(ShiftSnapshotUtils.decode(nil)).to.equal(nil)
		expect(ShiftSnapshotUtils.decode("running")).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("phase", "overtime"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("sub", "nap"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("variant", "C"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("quota", nil))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("endsAt", "soon"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("results", { outcome = "clockout" }))).to.equal(nil)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Results** `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau`:

```lua
--!strict
--[=[
	ShiftResultsUtils: builds the end-of-shift performance review (spec §3 step 7; plain in M1, the joke
	awards grow in M3): the shift's totals, the crew ordered by what they banked, and an award per category
	(most banked, most piles, most salvage) for whoever leads it with more than zero. Ties go to the earlier
	name. Pure.

	@class ShiftResultsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type CrewStats = ShiftTypes.CrewStats

export type ResultsInput = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	quotaMet: boolean,
	crew: { CrewStats },
}

local ShiftResultsUtils = {}

function ShiftResultsUtils.build(input: ResultsInput): ShiftTypes.ShiftResults
	local crew = table.clone(input.crew)
	table.sort(crew, function(a, b)
		if a.banked ~= b.banked then
			return a.banked > b.banked
		end
		return a.name < b.name
	end)

	local lines: { ShiftTypes.CrewLine } = {}
	local salvage = 0
	local piles = 0
	for _, member in crew do
		table.insert(lines, { name = member.name, banked = member.banked, piles = member.piles, salvage = member.salvage })
		salvage += member.salvage
		piles += member.piles
	end

	local awards: { ShiftTypes.Award } = {}
	local function award(title: string, score: (member: CrewStats) -> number)
		local best: CrewStats? = nil
		local bestScore = 0
		for _, member in crew do
			local value = score(member)
			if value > bestScore then
				best = member
				bestScore = value
			end
		end
		if best ~= nil then
			table.insert(awards, { title = title, name = best.name })
		end
	end
	award("Top Hauler", function(member)
		return member.banked
	end)
	award("Dust Devil", function(member)
		return member.piles
	end)
	award("Treasure Hunter", function(member)
		return member.salvage
	end)

	return {
		outcome = input.outcome,
		quota = input.quota,
		cleared = input.cleared,
		bonus = input.bonus,
		salvage = salvage,
		piles = piles,
		quotaMet = input.quotaMet,
		crew = lines,
		awards = awards,
	}
end

return ShiftResultsUtils
```

- [ ] **Step 4: Snapshot codec** `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftSnapshotUtils.luau`:

```lua
--!strict
--[=[
	ShiftSnapshotUtils: the `shift` world entry (spec §6.3). `build` turns the server's state plus the
	counters, vote counts and results into the plain snapshot published through StateSyncWorldStore;
	`decode` is the client's trust boundary for it (the RoundSnapshotUtils pattern): a wrong type anywhere
	rejects the whole value; absent vote counts read 0.

	@class ShiftSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type WorldValue = WorldTypes.WorldValue
type ShiftSnapshot = ShiftTypes.ShiftSnapshot
type ShiftResults = ShiftTypes.ShiftResults

local function phaseOf(value: WorldValue?): ShiftTypes.ShiftPhase?
	if value == "lobby" then
		return "lobby"
	elseif value == "starting" then
		return "starting"
	elseif value == "running" then
		return "running"
	elseif value == "results" then
		return "results"
	end
	return nil
end

local function subOf(value: WorldValue?): ShiftTypes.ShiftSub?
	if value == "normal" then
		return "normal"
	elseif value == "clockout" then
		return "clockout"
	end
	return nil
end

local function variantOf(value: WorldValue?): ShiftTypes.Variant?
	if value == "A" then
		return "A"
	elseif value == "B" then
		return "B"
	end
	return nil
end

-- An optional number: (value, ok). Absent is fine; any other type is not.
local function optionalNumber(value: WorldValue?): (number?, boolean)
	if value == nil then
		return nil, true
	end
	if type(value) == "number" then
		return value, true
	end
	return nil, false
end

-- A vote count: absent reads 0.
local function countOf(value: WorldValue?): (number, boolean)
	if value == nil then
		return 0, true
	end
	if type(value) == "number" then
		return value, true
	end
	return 0, false
end

local function crewOf(value: WorldValue?): { ShiftTypes.CrewLine }?
	local result: { ShiftTypes.CrewLine } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "table" then
			return nil
		end
		local name = item.name
		local banked = item.banked
		local piles = item.piles
		local salvage = item.salvage
		if type(name) ~= "string" then
			return nil
		end
		if type(banked) ~= "number" then
			return nil
		end
		if type(piles) ~= "number" then
			return nil
		end
		if type(salvage) ~= "number" then
			return nil
		end
		table.insert(result, { name = name, banked = banked, piles = piles, salvage = salvage })
	end
	return result
end

local function awardsOf(value: WorldValue?): { ShiftTypes.Award }?
	local result: { ShiftTypes.Award } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "table" then
			return nil
		end
		local title = item.title
		local name = item.name
		if type(title) ~= "string" then
			return nil
		end
		if type(name) ~= "string" then
			return nil
		end
		table.insert(result, { title = title, name = name })
	end
	return result
end

local function numberField(value: WorldValue?): number?
	return if type(value) == "number" then value else nil
end

-- The results: (results, ok). Absent is fine.
local function resultsOf(value: WorldValue?): (ShiftResults?, boolean)
	if value == nil then
		return nil, true
	end
	if type(value) ~= "table" then
		return nil, false
	end
	local outcome = value.outcome
	local quotaMet = value.quotaMet
	local quota = numberField(value.quota)
	local cleared = numberField(value.cleared)
	local bonus = numberField(value.bonus)
	local salvage = numberField(value.salvage)
	local piles = numberField(value.piles)
	local crew = crewOf(value.crew)
	local awards = awardsOf(value.awards)
	if type(outcome) ~= "string" or type(quotaMet) ~= "boolean" then
		return nil, false
	end
	if quota == nil or cleared == nil or bonus == nil or salvage == nil or piles == nil then
		return nil, false
	end
	if crew == nil or awards == nil then
		return nil, false
	end
	return {
		outcome = outcome,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		salvage = salvage,
		piles = piles,
		quotaMet = quotaMet,
		crew = crew,
		awards = awards,
	},
		true
end

local ShiftSnapshotUtils = {}

--[=[
	The snapshot for `state` (a fresh table: publish a new one every time).
]=]
function ShiftSnapshotUtils.build(
	state: ShiftTypes.ShiftState,
	cleared: number,
	bonus: number,
	votesAnother: number,
	votesDepot: number,
	results: ShiftResults?
): ShiftSnapshot
	return {
		phase = state.phase,
		sub = state.sub,
		shift = state.shift,
		endsAt = state.endsAt,
		clockOutAt = state.clockOutAt,
		voteEndsAt = state.voteEndsAt,
		quota = state.quota,
		cleared = cleared,
		bonus = bonus,
		quotaMet = state.quotaMet,
		variant = state.variant,
		votesAnother = votesAnother,
		votesDepot = votesDepot,
		results = results,
	}
end

--[=[
	Decodes a replicated snapshot, or nil when it is malformed.
]=]
function ShiftSnapshotUtils.decode(value: WorldValue?): ShiftSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	-- Annotated and tested with `not` (the RoundSnapshotUtils note: comparing an optional singleton union
	-- against nil widens it back to string).
	local phase: ShiftTypes.ShiftPhase? = phaseOf(value.phase)
	local sub: ShiftTypes.ShiftSub? = subOf(value.sub)
	local variant: ShiftTypes.Variant? = variantOf(value.variant)
	if not phase or not sub or not variant then
		return nil
	end
	local quotaMet = value.quotaMet
	if type(quotaMet) ~= "boolean" then
		return nil
	end
	local shift = numberField(value.shift)
	local quota = numberField(value.quota)
	local cleared = numberField(value.cleared)
	local bonus = numberField(value.bonus)
	if shift == nil or quota == nil or cleared == nil or bonus == nil then
		return nil
	end
	local endsAt, endsOk = optionalNumber(value.endsAt)
	local clockOutAt, clockOk = optionalNumber(value.clockOutAt)
	local voteEndsAt, voteOk = optionalNumber(value.voteEndsAt)
	local votesAnother, anotherOk = countOf(value.votesAnother)
	local votesDepot, depotOk = countOf(value.votesDepot)
	local results, resultsOk = resultsOf(value.results)
	if not (endsOk and clockOk and voteOk and anotherOk and depotOk and resultsOk) then
		return nil
	end
	local snapshot: ShiftSnapshot = {
		phase = phase,
		sub = sub,
		shift = shift,
		endsAt = endsAt,
		clockOutAt = clockOutAt,
		voteEndsAt = voteEndsAt,
		quota = quota,
		cleared = cleared,
		bonus = bonus,
		quotaMet = quotaMet,
		variant = variant,
		votesAnother = votesAnother,
		votesDepot = votesDepot,
		results = results,
	}
	return snapshot
end

return ShiftSnapshotUtils
```

- [ ] **Step 5: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```
If luau-lsp does not narrow a value after one of the combined guards (`if not phase or not sub or not variant`, `if type(outcome) ~= "string" or type(quotaMet) ~= "boolean"`, the `== nil or` chains), split that guard into one `if ... then return ... end` per value (same behaviour, no cast).

- [ ] **Step 6: Controller: Studio TestEZ.** Expected: ShiftResultsUtils and ShiftSnapshotUtils specs pass.

- [ ] **Step 7: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(shift): results builder and snapshot codec"
```

---
### Task 7: Vacuum runtime (piles, channel, canister, hold-to-vacuum)

**Files:**
- Create: `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau`
- Create: `src/ReplicatedStorage/Client/Features/Vacuum/VacuumServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (M0, verify in Task 0): `InteractionRegistry.registerChannel(id, { duration, maxDistance })`, `InteractionRegistry.hasChannel(id)`, `InteractionServiceServer:channel(kind, { canChannel: ((player, target) -> boolean)?, onComplete: (players: { Player }, target: Instance) -> () })`, `InteractionConstants.CHANNEL_KIND_ATTRIBUTE / CHANNEL_PROGRESS_ATTRIBUTE / CHANNEL_COUNT_ATTRIBUTE`, client `InteractionServiceClient:startChannel(target)` / `:stopChannel()`. Base: `CarryServiceServer:getCarried(player) -> Instance?`, `CarryServiceClient:isCarrying() -> boolean`, `StateSyncPublicPlayerStore.set(userId, fields)`, `InputActionRegistry.register(id, def)`, `InputServiceClient:bind(id, callback) -> () -> ()`.
- Consumes (Task 2): `VacuumConstants.*`, `VacuumCanisterUtils.add/creditFor`, `VacuumAimUtils.pick`.
- Produces (VacuumServiceServer):
  - `pileCleared: SignalTyped.Signal<BasePart, { Player }>` (the destroyed pile, everyone on it)
  - `dustBagReady: SignalTyped.Signal<Player, CFrame, Instance>` (who, the floor point at their feet, the parent to spawn into)
  - `noiseMade: SignalTyped.Signal<Vector3, number, string>` (position, radius, `"vacuum"`): the M2 Noise seam
  - `spawnPile(kind: string, floor: CFrame, parent: Instance) -> BasePart`, `fillOf(player) -> number`, `reset() -> ()`
- Produces (VacuumServiceClient): `beginVacuum() -> ()`, `endVacuum() -> ()`, `isVacuuming() -> boolean`; registers the `vacuum` Input action (left mouse, gamepad R2).
- A pile is an anchored, non-colliding Part tagged `VacuumPile` with attributes `ChannelKind = "pile"`, `PileKind`, `PileBaseSize`.
- SignalPlus (behind SignalTyped) runs handlers **deferred** (`task.defer`), so listeners run a moment after the event, never inside it.

- [ ] **Step 1: Server** `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau`:

```lua
--!strict
--[=[
	VacuumServiceServer: piles and the vacuum (Cleanup Crew spec §4 "Vacuum", §6.4). A pile is a tagged
	part carrying the `pile` Interaction channel kind, so holding the vacuum on it is Interaction's channel:
	progress accumulates on the server, is kept on release, and several players' rates add. This service:

	- registers the channel (8 studs, 2.5 s) and refuses it to a player whose hands hold an item;
	- shrinks a pile as its ChannelProgress rises;
	- on completion destroys the pile, adds it to the credited channeler's canister (VacuumCanisterUtils),
	  publishes the public `canister` field, and on overflow fires `dustBagReady` (Cargo spawns the bag);
	- fires `pileCleared` (Office reveals what was hidden under it; Shift counts piles) and, every second a
	  pile is being vacuumed, `noiseMade` (the M2 Noise seam; nothing listens in M1).

	Spec-exempt shell (Instances, Players, RunService, signals); the maths is the specced
	VacuumCanisterUtils.

	@class VacuumServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumCanisterUtils = require(ServerScriptService.Features.Vacuum.Utils.VacuumCanisterUtils)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

-- Registered at load: the channel is a server rule (the client only names the pile it aims at).
if not InteractionRegistry.hasChannel(VacuumConstants.CHANNEL_KIND) then
	InteractionRegistry.registerChannel(VacuumConstants.CHANNEL_KIND, {
		duration = VacuumConstants.DURATION,
		maxDistance = VacuumConstants.RANGE,
	})
end

local pileCleared: SignalTyped.Signal<BasePart, { Player }> = SignalTyped.new()
local dustBagReady: SignalTyped.Signal<Player, CFrame, Instance> = SignalTyped.new()
local noiseMade: SignalTyped.Signal<Vector3, number, string> = SignalTyped.new()

local fills: { [number]: number } = {}
local counters = { spawned = 0, cleared = 0, bags = 0 }
local stoppers: { () -> () } = {}

local function publish(userId: number)
	StateSyncPublicPlayerStore.set(userId, { [VacuumConstants.PUBLIC_FIELD] = fills[userId] or 0 })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Scales a pile down with its progress, keeping it on the floor.
local function shrink(pile: BasePart)
	local base = pile:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)
	if typeof(base) ~= "Vector3" then
		return
	end
	local progress = pile:GetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
	local fraction = if type(progress) == "number" then progress else 0
	local scale = 1 - (1 - VacuumConstants.MIN_SCALE) * fraction
	local bottom = pile.Position.Y - pile.Size.Y / 2
	pile.Size = base * scale
	pile.Position = Vector3.new(pile.Position.X, bottom + pile.Size.Y / 2, pile.Position.Z)
end

-- The channel's completion: the pile is cleared once, for everyone on it.
local function clear(players: { Player }, target: Instance)
	if not target:IsA("BasePart") then
		return
	end
	local parent = target.Parent
	target:Destroy()
	counters.cleared += 1
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local creditId = VacuumCanisterUtils.creditFor(ids, function(userId)
		return fills[userId] or 0
	end)
	local credited = if creditId ~= nil then Players:GetPlayerByUserId(creditId) else nil
	if creditId ~= nil and credited ~= nil then
		local fill, popped = VacuumCanisterUtils.add(fills[creditId] or 0, VacuumConstants.CANISTER_CAPACITY)
		fills[creditId] = fill
		publish(creditId)
		local root = rootOf(credited)
		if popped and root ~= nil and parent ~= nil then
			counters.bags += 1
			dustBagReady:Fire(credited, root.CFrame * VacuumConstants.BAG_OFFSET, parent)
		end
	end
	pileCleared:Fire(target, players)
end

-- One noise pulse per pile someone is vacuuming right now.
local function pulse()
	for _, pile in CollectionService:GetTagged(VacuumConstants.PILE_TAG) do
		local count = pile:GetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE)
		if pile:IsA("BasePart") and type(count) == "number" and count > 0 then
			noiseMade:Fire(pile.Position, VacuumConstants.NOISE_RADIUS, "vacuum")
		end
	end
end

export type VacuumServiceServer = {
	dependencies: { string },
	pileCleared: SignalTyped.Signal<BasePart, { Player }>,
	dustBagReady: SignalTyped.Signal<Player, CFrame, Instance>,
	noiseMade: SignalTyped.Signal<Vector3, number, string>,
	start: (self: VacuumServiceServer) -> (),
	stop: (self: VacuumServiceServer) -> (),
	getState: (self: VacuumServiceServer) -> { [string]: any },
	spawnPile: (self: VacuumServiceServer, kind: string, floor: CFrame, parent: Instance) -> BasePart,
	fillOf: (self: VacuumServiceServer, player: Player) -> number,
	reset: (self: VacuumServiceServer) -> (),
}

local VacuumServiceServer: VacuumServiceServer = {
	dependencies = { "InteractionServiceServer", "CarryServiceServer", "StateSyncServiceServer" },
	pileCleared = pileCleared,
	dustBagReady = dustBagReady,
	noiseMade = noiseMade,

	--[=[
		Handles the pile channel, shrinks piles as they progress, pulses vacuum noise, forgets leavers.
	]=]
	start = function(_self)
		InteractionServiceServer:channel(VacuumConstants.CHANNEL_KIND, {
			-- Spec §4: you can't vacuum while your hands hold an item.
			canChannel = function(player, _target)
				return CarryServiceServer:getCarried(player) == nil
			end,
			onComplete = clear,
		})

		table.insert(
			stoppers,
			Observers.observeTag(VacuumConstants.PILE_TAG, function(pile: Instance)
				if not pile:IsA("BasePart") then
					return nil
				end
				local changed = pile
					:GetAttributeChangedSignal(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
					:Connect(function()
						shrink(pile)
					end)
				return function()
					changed:Disconnect()
				end
			end)
		)

		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= VacuumConstants.NOISE_INTERVAL then
				elapsed = 0
				pulse()
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			fills[player.UserId] = nil
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Places a pile of `kind` (VacuumConstants.PILE_KINDS) standing on `floor`, under `parent`.
	]=]
	spawnPile = function(_self, kind, floor, parent)
		local style = VacuumConstants.PILE_KINDS[kind]
		assert(style ~= nil, `spawnPile: unknown pile kind "{kind}"`)
		local pile = Instance.new("Part")
		pile.Name = `Pile ({kind})`
		pile.Size = style.size
		pile.Color = style.color
		pile.Material = style.material
		pile.Anchored = true
		pile.CanCollide = false
		pile.CanTouch = false
		pile.CFrame = floor * CFrame.new(0, style.size.Y / 2, 0)
		pile:SetAttribute(VacuumConstants.PILE_KIND_ATTRIBUTE, kind)
		pile:SetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE, style.size)
		pile:SetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE, VacuumConstants.CHANNEL_KIND)
		pile.Parent = parent
		CollectionService:AddTag(pile, VacuumConstants.PILE_TAG)
		counters.spawned += 1
		return pile
	end,

	fillOf = function(_self, player)
		return fills[player.UserId] or 0
	end,

	--[=[
		Empties every canister (a new shift). Piles go with the shift's container (Office).
	]=]
	reset = function(_self)
		table.clear(fills)
		for _, player in Players:GetPlayers() do
			publish(player.UserId)
		end
	end,

	getState = function(_self)
		local canisters: { [string]: number } = {}
		for userId, fill in fills do
			canisters[tostring(userId)] = fill
		end
		return {
			piles = #CollectionService:GetTagged(VacuumConstants.PILE_TAG),
			canisters = canisters,
			counters = table.clone(counters),
		}
	end,
}

return VacuumServiceServer
```

- [ ] **Step 2: Client** `src/ReplicatedStorage/Client/Features/Vacuum/VacuumServiceClient.luau`:

```lua
--!strict
--[=[
	VacuumServiceClient: hold to vacuum (Cleanup Crew spec §4). While the `vacuum` action is held (left
	mouse, gamepad R2, or the Shift HUD's touch button through beginVacuum / endVacuum), it re-aims every
	AIM_INTERVAL at the pile the player faces within range (VacuumAimUtils) and keeps Interaction's channel
	on it; letting go stops the channel, and the pile keeps its progress. Nothing is sent while carrying.
	The server decides everything.

	Spec-exempt shell (Input, Camera, CollectionService); the aim is the specced VacuumAimUtils.

	@class VacuumServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumAimUtils = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumAimUtils)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InteractionServiceClient = require(ReplicatedStorage.Client.Features.Interaction.InteractionServiceClient)

local holding = false
local unbinders: { () -> () } = {}

-- The pile the local player is facing within range, or nil.
local function aimedPile(): Instance?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = Workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or camera == nil then
		return nil
	end
	local piles: { BasePart } = {}
	local positions: { Vector3 } = {}
	for _, pile in CollectionService:GetTagged(VacuumConstants.PILE_TAG) do
		if pile:IsA("BasePart") then
			table.insert(piles, pile)
			table.insert(positions, pile.Position)
		end
	end
	local index = VacuumAimUtils.pick(
		root.Position,
		camera.CFrame.LookVector,
		positions,
		VacuumConstants.RANGE,
		VacuumConstants.AIM_MIN_DOT
	)
	return if index ~= nil then piles[index] else nil
end

export type VacuumServiceClient = {
	dependencies: { string },
	init: (self: VacuumServiceClient) -> (),
	start: (self: VacuumServiceClient) -> (),
	stop: (self: VacuumServiceClient) -> (),
	beginVacuum: (self: VacuumServiceClient) -> (),
	endVacuum: (self: VacuumServiceClient) -> (),
	isVacuuming: (self: VacuumServiceClient) -> boolean,
}

local VacuumServiceClient: VacuumServiceClient = {
	dependencies = { "InputServiceClient", "InteractionServiceClient", "CarryServiceClient" },

	init = function(_self)
		if not InputActionRegistry.has(VacuumConstants.ACTION) then
			InputActionRegistry.register(VacuumConstants.ACTION, {
				context = "gameplay",
				bindings = { keyboard = { Enum.UserInputType.MouseButton1 }, gamepad = { Enum.KeyCode.ButtonR2 } },
				description = "Hold to vacuum the pile in front of you",
			})
		end
	end,

	start = function(self)
		table.insert(
			unbinders,
			InputServiceClient:bind(VacuumConstants.ACTION, function(phase)
				if phase == "begin" then
					self:beginVacuum()
				else
					self:endVacuum()
				end
			end)
		)
	end,

	stop = function(self)
		self:endVacuum()
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	--[=[
		Starts vacuuming whatever pile the player faces, re-aiming until endVacuum.
	]=]
	beginVacuum = function(_self)
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			while holding do
				local target = if CarryServiceClient:isCarrying() then nil else aimedPile()
				if target ~= nil then
					InteractionServiceClient:startChannel(target)
				else
					InteractionServiceClient:stopChannel()
				end
				task.wait(VacuumConstants.AIM_INTERVAL)
			end
		end)
	end,

	endVacuum = function(_self)
		holding = false
		InteractionServiceClient:stopChannel()
	end,

	isVacuuming = function(_self)
		return holding
	end,
}

return VacuumServiceClient
```

- [ ] **Step 3: Exemptions.** Add to `EXEMPT_MODULES` under `-- Cleanup Crew: Vacuum`:

```lua
	["ServerScriptService.Features.Vacuum.VacuumServiceServer"] = "Instance/Players/RunService/signal shell (VacuumCanisterUtils is specced)",
	["ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient"] = "Input/Camera shell (VacuumAimUtils is specced; the server decides)",
```

- [ ] **Step 4: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 5: Controller: Studio TestEZ** (regression: every spec still passes; `assertAllModulesSpecced` passes).

- [ ] **Step 6: Studio verification (controller, Play Solo; server command bar via execute_luau).**

```lua
local V = require(game.ServerScriptService.Features.Vacuum.VacuumServiceServer)
local P = require(game.ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local player = game.Players:GetPlayers()[1]
local root = player.Character.HumanoidRootPart
V.noiseMade:Connect(function(_, radius, source) print("NOISE", source, radius) end)
V.pileCleared:Connect(function(pile, players) print("CLEARED", pile.Name, #players) end)
V.dustBagReady:Connect(function(who, at) print("BAG", who.Name, at.Position) end)
local folder = Instance.new("Folder") folder.Name = "VacuumTest" folder.Parent = workspace
for i = 1, 3 do
	V:spawnPile("paper", CFrame.new(root.Position + root.CFrame.LookVector * (3 + i * 5) - Vector3.new(0, 3, 0)), folder)
end
```
Checklist:
1. Face the nearest pile and hold left mouse: it shrinks; Output shows `NOISE vacuum 40` about once a second; after ~2.5 s `CLEARED Pile (paper) 1`; `P.get(player.UserId).canister` is `1`.
2. Hold on the second pile ~1 s, release, hold again: it finishes ~1.5 s later (progress kept). `canister` is `2`.
3. Clear the third pile: `BAG <name> <position at your feet>` and `canister` is `0`.
4. Spawn another pile, pick up any carryable (or skip if none exists yet: Cargo comes in Task 8) and hold left mouse on it: no shrink, no `CLEARED` (canChannel refuses).
5. `V:reset()` → `canister` is `0`. `folder:Destroy()` → no errors in Output.

- [ ] **Step 7: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(vacuum): piles, the vacuum channel and canisters"
```

---

### Task 8: Cargo runtime (spawning, pockets, handling, search, banking)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`
- Create: `src/ServerScriptService/Features/Cargo/State/CargoClaimTracker.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau`
- Create: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`
- Create: `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (base / M0): `CarryRegistry.register(id, { weight, throwable?, throwSpeed?, holdOffset? })`, `CarryConstants.TAG / KIND_ATTRIBUTE / PUBLIC_FIELD`, `CarryServiceServer.dropped: Signal<Player, Instance, DropReason>`, `CarryServiceServer:getCarried(player)`, `CarryServiceServer:forceDrop(player, reason?) -> boolean`, `CarryEvents.packets.Drop.send(true)` / `.Throw.send(aim)`, `InteractionRegistry.register(id, { actionText, objectText?, holdDuration?, maxDistance? })`, `InteractionServiceServer:onInteract(kind, handler)`, `InteractionServiceServer:setEnabled(target, enabled)`, `InteractionConstants.ENABLED_ATTRIBUTE`, `ToastServiceServer:send(target, { text, style?, duration? }) -> boolean`, `RequestHandler.wrap(config)`, `StateSyncPublicPlayerStore.set / clearField`.
- Consumes (Tasks 1, 2, 7): `CargoTypes.*`, `CargoConstants.*`, `CargoRegistry.*`, `CargoHandlingRules.*`, `CargoBankRules.*`, `VacuumConstants.DUST_BAG_KIND`, `VacuumServiceServer:spawnPile(kind, floor, parent)`, `VacuumServiceServer.dustBagReady`.
- Produces (CargoClaimTracker): `new() -> { claim(id: number) -> boolean, release(id), isClaimed(id) -> boolean, clear() }`.
- Produces (CargoPocketTracker): `new() -> { add(userId, entry: CargoEntry) -> boolean, list(userId) -> { CargoEntry }, count(userId) -> number, take(userId) -> { CargoEntry }, clear() }`.
- Produces (CargoSpawnSystem): `new() -> { spawn(kind, floor: CFrame, parent: Instance, options: SpawnOptions?) -> BasePart, reveal(item: Instance), setValue(item: Instance, value: number), floorUnder(position: Vector3, ignore: { Instance }) -> CFrame }`.
- Produces (CargoServiceServer): `noiseMade: Signal<Vector3, number, string>` (sources `"drop"`, `"search"`), `spawnItem(kind, floor, parent, options?) -> BasePart`, `reveal(item)`, `useContainer(parent: Instance?)`, `stockSearchable(part: BasePart, kind: string?)`, `onBanked(handler: BankHandler)`, `pocket(player) -> (boolean, string?)`, `load(player, bed: BasePart) -> (boolean, string?)`, `search(player, part: BasePart) -> (boolean, string?)`, `pocketsOf(player) -> { CargoEntry }`, `reset()`.
- Produces (CargoServiceClient): `pocket()`, `drop()`, `throw()`; registers the `pocket` Input action (Q, gamepad D-pad up).

- [ ] **Step 1: Write the failing tracker specs.**

`src/ServerScriptService/Features/Cargo/State/CargoClaimTracker.spec.luau`:

```lua
local CargoClaimTracker = require(script.Parent.CargoClaimTracker)

return function()
	it("claims an item once", function()
		local claims = CargoClaimTracker.new()
		expect(claims:claim(1)).to.equal(true)
		expect(claims:claim(1)).to.equal(false)
		expect(claims:isClaimed(1)).to.equal(true)
	end)

	it("keeps items independent", function()
		local claims = CargoClaimTracker.new()
		claims:claim(1)
		expect(claims:isClaimed(2)).to.equal(false)
		expect(claims:claim(2)).to.equal(true)
	end)

	it("lets a released item be claimed again", function()
		local claims = CargoClaimTracker.new()
		claims:claim(1)
		claims:release(1)
		expect(claims:isClaimed(1)).to.equal(false)
		expect(claims:claim(1)).to.equal(true)
	end)

	it("forgets every claim on clear", function()
		local claims = CargoClaimTracker.new()
		claims:claim(1)
		claims:claim(2)
		claims:clear()
		expect(claims:isClaimed(1)).to.equal(false)
		expect(claims:isClaimed(2)).to.equal(false)
	end)
end
```

`src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.spec.luau`:

```lua
local CargoPocketTracker = require(script.Parent.CargoPocketTracker)

local PLAQUE = { kind = "plaque", value = 25 }
local STAPLER = { kind = "goldenStapler", value = 80 }

return function()
	it("holds two entries and refuses a third", function()
		local pockets = CargoPocketTracker.new()
		expect(pockets:add(1, PLAQUE)).to.equal(true)
		expect(pockets:add(1, STAPLER)).to.equal(true)
		expect(pockets:add(1, PLAQUE)).to.equal(false)
		expect(pockets:count(1)).to.equal(2)
	end)

	it("lists copies, in pocketing order", function()
		local pockets = CargoPocketTracker.new()
		pockets:add(1, PLAQUE)
		pockets:add(1, STAPLER)
		local list = pockets:list(1)
		expect(list[1].kind).to.equal("plaque")
		expect(list[2].kind).to.equal("goldenStapler")
		list[1].value = 0
		table.clear(list)
		expect(pockets:list(1)[1].value).to.equal(25)
		expect(pockets:count(1)).to.equal(2)
	end)

	it("take empties the pockets and returns what was in them", function()
		local pockets = CargoPocketTracker.new()
		pockets:add(1, PLAQUE)
		local taken = pockets:take(1)
		expect(#taken).to.equal(1)
		expect(taken[1].kind).to.equal("plaque")
		expect(pockets:count(1)).to.equal(0)
		expect(#pockets:take(1)).to.equal(0)
	end)

	it("keeps players apart", function()
		local pockets = CargoPocketTracker.new()
		pockets:add(1, PLAQUE)
		expect(pockets:count(2)).to.equal(0)
		expect(#pockets:list(2)).to.equal(0)
	end)

	it("clear empties everyone", function()
		local pockets = CargoPocketTracker.new()
		pockets:add(1, PLAQUE)
		pockets:add(2, STAPLER)
		pockets:clear()
		expect(pockets:count(1)).to.equal(0)
		expect(pockets:count(2)).to.equal(0)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: both specs error (modules missing).

- [ ] **Step 3: Trackers.**

`src/ServerScriptService/Features/Cargo/State/CargoClaimTracker.luau`:

```lua
--!strict
--[=[
	CargoClaimTracker: which cargo items have been claimed (being banked, pocketed or spilled). Claiming is
	the first move of every step that consumes an item, so an item can be consumed once: a second Load of the
	same item finds it claimed (Cleanup Crew spec §6.4, "two simultaneous Loads can't double-count"). Items
	are identified by their CargoId.

	@class CargoClaimTracker
]=]

export type CargoClaimTracker = {
	claim: (self: CargoClaimTracker, itemId: number) -> boolean,
	release: (self: CargoClaimTracker, itemId: number) -> (),
	isClaimed: (self: CargoClaimTracker, itemId: number) -> boolean,
	clear: (self: CargoClaimTracker) -> (),
}

local CargoClaimTracker = {}

function CargoClaimTracker.new(): CargoClaimTracker
	local claimed: { [number]: boolean } = {}

	local tracker: CargoClaimTracker = {
		-- True when this call claimed it; false when it was already claimed.
		claim = function(_self, itemId)
			if claimed[itemId] then
				return false
			end
			claimed[itemId] = true
			return true
		end,

		-- Gives a claim back (the banking handler refused the deposit).
		release = function(_self, itemId)
			claimed[itemId] = nil
		end,

		isClaimed = function(_self, itemId)
			return claimed[itemId] == true
		end,

		clear = function(_self)
			table.clear(claimed)
		end,
	}
	return tracker
end

return CargoClaimTracker
```

`src/ServerScriptService/Features/Cargo/State/CargoPocketTracker.luau`:

```lua
--!strict
--[=[
	CargoPocketTracker: what each player has in their pockets (Cleanup Crew spec §4: two slots). A pocketed
	item is no longer an Instance, only its kind and value; it becomes one again when it is scattered. Lists
	are handed out as copies.

	@class CargoPocketTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry

export type CargoPocketTracker = {
	add: (self: CargoPocketTracker, userId: number, entry: CargoEntry) -> boolean,
	list: (self: CargoPocketTracker, userId: number) -> { CargoEntry },
	count: (self: CargoPocketTracker, userId: number) -> number,
	take: (self: CargoPocketTracker, userId: number) -> { CargoEntry },
	clear: (self: CargoPocketTracker) -> (),
}

local CargoPocketTracker = {}

local function copy(list: { CargoEntry }): { CargoEntry }
	local result: { CargoEntry } = {}
	for _, entry in list do
		table.insert(result, { kind = entry.kind, value = entry.value })
	end
	return result
end

function CargoPocketTracker.new(): CargoPocketTracker
	local pockets: { [number]: { CargoEntry } } = {}

	local tracker: CargoPocketTracker = {
		-- False when the pockets are full.
		add = function(_self, userId, entry)
			local list = pockets[userId]
			if list == nil then
				list = {}
				pockets[userId] = list
			end
			if #list >= CargoConstants.POCKET_SLOTS then
				return false
			end
			table.insert(list, { kind = entry.kind, value = entry.value })
			return true
		end,

		list = function(_self, userId)
			return copy(pockets[userId] or {})
		end,

		count = function(_self, userId)
			local list = pockets[userId]
			return if list ~= nil then #list else 0
		end,

		-- Empties the player's pockets and returns what was in them.
		take = function(_self, userId)
			local list = pockets[userId] or {}
			pockets[userId] = nil
			return copy(list)
		end,

		clear = function(_self)
			table.clear(pockets)
		end,
	}
	return tracker
end

return CargoPocketTracker
```

- [ ] **Step 4: Packets** `src/ReplicatedStorage/Shared/Features/Cargo/Net/CargoEvents.luau`:

```lua
--!strict
--[=[
	CargoEvents: Cargo's ByteNet packets (client → server only). The server decides everything (what the
	sender holds, whether it fits a pocket, rate limits).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CargoServiceServer load).

	@class CargoEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CargoEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CargoEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Pocket the hands item. Payload unused; the packet is the request.
			Pocket = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CargoEvents
```

- [ ] **Step 5: Spawn system** `src/ServerScriptService/Features/Cargo/Systems/CargoSpawnSystem.luau`:

```lua
--!strict
--[=[
	CargoSpawnSystem: puts graybox cargo in the world. One anchored Part per item, sized and coloured from
	CargoRegistry, carrying its CarryKind / CargoId / CargoValue / CargoImpacts attributes and a name-and-value
	label, then tagged Carryable so Carry (and through it Interaction's "Pick up" prompt) takes over. A hidden
	item (under a pile) is invisible, lets players through and has its prompt off until `reveal`.

	Spec-exempt shell (Instances, raycasts); the catalog is the specced CargoRegistry.

	@class CargoSpawnSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)

export type CargoSpawnSystem = {
	spawn: (
		self: CargoSpawnSystem,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoSpawnSystem, item: Instance) -> (),
	setValue: (self: CargoSpawnSystem, item: Instance, value: number) -> (),
	floorUnder: (self: CargoSpawnSystem, position: Vector3, ignore: { Instance }) -> CFrame,
}

local function labelText(kind: string, value: number): string
	local def = CargoRegistry.get(kind)
	return `{if def ~= nil then def.name else kind} ({value})`
end

local function labelOf(item: Instance): (BillboardGui?, TextLabel?)
	local billboard = item:FindFirstChild(CargoConstants.LABEL_NAME)
	if billboard == nil or not billboard:IsA("BillboardGui") then
		return nil, nil
	end
	local text = billboard:FindFirstChildOfClass("TextLabel")
	return billboard, text
end

local function makeLabel(part: BasePart, text: string, visible: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = CargoConstants.LABEL_NAME
	billboard.Size = UDim2.fromOffset(200, 30)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	billboard.MaxDistance = CargoConstants.LABEL_DISTANCE
	billboard.Enabled = visible
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.SourceSansSemibold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
	billboard.Parent = part
end

local CargoSpawnSystem = {}

function CargoSpawnSystem.new(): CargoSpawnSystem
	local nextId = 0

	local system: CargoSpawnSystem = {
		--[=[
			Spawns one `kind` standing on `floor` under `parent` and returns its part.
		]=]
		spawn = function(_self, kind, floor, parent, options)
			local def = CargoRegistry.get(kind)
			assert(def ~= nil, `CargoSpawnSystem: unknown cargo "{kind}"`)
			local hidden = options ~= nil and options.hidden == true
			local value = if options ~= nil and options.value ~= nil then options.value else def.value
			nextId += 1
			local part = Instance.new("Part")
			part.Name = def.name
			part.Size = def.partSize
			part.Color = def.color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Anchored = true
			part.CanCollide = not hidden
			part.Transparency = if hidden then 1 else 0
			part.CFrame = floor * CFrame.new(0, def.partSize.Y / 2, 0)
			part:SetAttribute(CarryConstants.KIND_ATTRIBUTE, kind)
			part:SetAttribute(CargoConstants.ID_ATTRIBUTE, nextId)
			part:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			part:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, 0)
			if hidden then
				part:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, true)
				part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
			end
			makeLabel(part, labelText(kind, value), not hidden)
			part.Parent = parent
			-- Last: Carry reads the kind, and Interaction the enabled flag, when the tag lands.
			CollectionService:AddTag(part, CarryConstants.TAG)
			return part
		end,

		--[=[
			Uncovers a hidden item: visible, solid, labelled and pickable. A no-op for one already visible.
		]=]
		reveal = function(_self, item)
			if not item:IsA("BasePart") or item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) ~= true then
				return
			end
			item:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, nil)
			item.Transparency = 0
			item.CanCollide = true
			item:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, nil)
			local billboard = labelOf(item)
			if billboard ~= nil then
				billboard.Enabled = true
			end
		end,

		--[=[
			Sets an item's value (a fragile item dropped a tier) and its label.
		]=]
		setValue = function(_self, item, value)
			item:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			local kind = item:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
			local _, text = labelOf(item)
			if text ~= nil and type(kind) == "string" then
				text.Text = labelText(kind, value)
			end
		end,

		--[=[
			The floor point below `position` (ignoring `ignore`), or 3 studs below it when nothing is hit.
		]=]
		floorUnder = function(_self, position, ignore)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			local hit = Workspace:Raycast(position, Vector3.new(0, -CargoConstants.FLOOR_PROBE, 0), params)
			return CFrame.new(if hit ~= nil then hit.Position else position - Vector3.new(0, 3, 0))
		end,
	}
	return system
end

return CargoSpawnSystem
```

- [ ] **Step 6: Server** `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau`:

```lua
--!strict
--[=[
	CargoServiceServer: Cleanup Crew's cargo (spec §4 "Cargo and carrying", §6.4). Every catalog item is a
	Carry kind (weight by size, the bulky cart held far out) spawned by CargoSpawnSystem. On top of Carry:

	- Pockets: the `pocket` packet moves a tiny hands item into one of two pockets (CargoPocketTracker),
	  published as the public `pocket1` / `pocket2` fields. Pockets scatter where their owner dies or leaves.
	- Handling (Carry's `dropped`, which SignalPlus delivers deferred): a fragile item loses a value tier per
	  impact; a recycling box spills into a pile (VacuumServiceServer:spawnPile); every drop fires `noiseMade`
	  (the M2 Noise seam).
	- Search: desks and lockers stocked per shift (`stockSearchable`); a short hold gives what was rolled.
	- Banking: the `cargo-load` interaction on the truck bed. Claim (CargoClaimTracker) → add (the game's
	  `onBanked` handler) → destroy, in one synchronous step, so two Loads never count one item twice.

	Spec-exempt shell (Instances, Players, ByteNet, signals); the rules are the specced CargoHandlingRules,
	CargoBankRules, CargoClaimTracker and CargoPocketTracker.

	@class CargoServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CarryShared = ReplicatedStorage.Shared.Features.Carry
local Observers = require(ReplicatedStorage.Packages.Observers)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryRegistry = require(CarryShared.Data.CarryRegistry)
local CarryTypes = require(CarryShared.Data.CarryTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoBankRules = require(CargoShared.Rules.CargoBankRules)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoPocketTracker = require(CargoServer.State.CargoPocketTracker)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

-- Registered at load, before any item spawns or any desk is tagged.
for _, id in CargoRegistry.ids() do
	local def = CargoRegistry.get(id)
	if def ~= nil and not CarryRegistry.has(id) then
		CarryRegistry.register(id, {
			weight = CargoConstants.WEIGHT[def.size] or 0,
			throwable = def.throwable,
			holdOffset = if def.size == "bulky" then CargoConstants.BULKY_HOLD_OFFSET else nil,
		})
	end
end
if not InteractionRegistry.has(CargoConstants.LOAD_KIND) then
	InteractionRegistry.register(CargoConstants.LOAD_KIND, {
		actionText = "Load",
		objectText = "Truck",
		maxDistance = CargoConstants.LOAD_DISTANCE,
	})
end
if not InteractionRegistry.has(CargoConstants.SEARCH_KIND) then
	InteractionRegistry.register(CargoConstants.SEARCH_KIND, {
		actionText = "Search",
		holdDuration = CargoConstants.SEARCH_HOLD,
		maxDistance = CargoConstants.SEARCH_DISTANCE,
	})
end

type Stock = { kind: string?, searched: boolean }

local noiseMade: SignalTyped.Signal<Vector3, number, string> = SignalTyped.new()
local spawner = CargoSpawnSystem.new()
local claims = CargoClaimTracker.new()
local pockets = CargoPocketTracker.new()
local stock: { [BasePart]: Stock } = {}
local bankHandler: CargoTypes.BankHandler? = nil
local container: Instance? = nil
local counters = { banked = 0, pocketed = 0, spilled = 0, searched = 0, scattered = 0 }
local stoppers: { () -> () } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- An object's cargo kind and id, or nil when it is not cargo.
local function cargoOf(object: Instance): (string?, number?)
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) or type(id) ~= "number" then
		return nil, nil
	end
	return kind, id
end

local function entryOf(object: Instance): CargoTypes.CargoEntry?
	local kind = cargoOf(object)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	if kind == nil or type(value) ~= "number" then
		return nil
	end
	return { kind = kind, value = value }
end

local function idOf(object: Instance): number?
	local _, id = cargoOf(object)
	return id
end

local function publishPockets(userId: number)
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

-- Everything a floor probe must look through: every character, plus `extra`.
local function ignoreList(extra: Instance?): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(list, character)
		end
	end
	if extra ~= nil then
		table.insert(list, extra)
	end
	return list
end

-- Drops a player's pocketed items around `origin` (where they died or left), inside the shift.
local function scatter(player: Player, origin: Vector3?)
	local list = pockets:take(player.UserId)
	publishPockets(player.UserId)
	local parent = container
	if origin == nil or parent == nil or parent.Parent == nil then
		return
	end
	for index, entry in list do
		local angle = index / #list * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CargoConstants.SCATTER_RADIUS
		spawner:spawn(entry.kind, spawner:floorUnder(origin + offset, ignoreList()), parent, { value = entry.value })
		counters.scattered += 1
	end
end

-- Carry's `dropped` (deferred): fragile tiers, spills and drop noise. Pocketing and banking claim the item
-- before they force-drop it, so those never land here.
local function onDropped(_player: Player, object: Instance, reason: CarryTypes.DropReason)
	local kind, id = cargoOf(object)
	if kind == nil or id == nil or claims:isClaimed(id) or not CargoHandlingRules.isImpact(reason) then
		return
	end
	local def = CargoRegistry.get(kind)
	if def == nil or not object:IsA("BasePart") or object.Parent == nil then
		return
	end
	local position = object.Position
	noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), "drop")
	if CargoHandlingRules.shouldSpill(def, reason) then
		claims:claim(id)
		local parent = object.Parent
		local floor = spawner:floorUnder(position, ignoreList(object))
		object:Destroy()
		if parent ~= nil then
			VacuumServiceServer:spawnPile(CargoConstants.SPILL_PILE_KIND, floor, parent)
		end
		counters.spilled += 1
		return
	end
	if def.fragile then
		local impacts = object:GetAttribute(CargoConstants.IMPACTS_ATTRIBUTE)
		local count = (if type(impacts) == "number" then impacts else 0) + 1
		object:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, count)
		spawner:setValue(object, CargoHandlingRules.valueAfter(def, count))
	end
end

export type CargoServiceServer = {
	dependencies: { string },
	noiseMade: SignalTyped.Signal<Vector3, number, string>,
	start: (self: CargoServiceServer) -> (),
	stop: (self: CargoServiceServer) -> (),
	getState: (self: CargoServiceServer) -> { [string]: any },
	spawnItem: (
		self: CargoServiceServer,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoServiceServer, item: Instance) -> (),
	useContainer: (self: CargoServiceServer, parent: Instance?) -> (),
	stockSearchable: (self: CargoServiceServer, part: BasePart, kind: string?) -> (),
	onBanked: (self: CargoServiceServer, handler: CargoTypes.BankHandler) -> (),
	pocket: (self: CargoServiceServer, player: Player) -> (boolean, string?),
	load: (self: CargoServiceServer, player: Player, bed: BasePart) -> (boolean, string?),
	search: (self: CargoServiceServer, player: Player, part: BasePart) -> (boolean, string?),
	pocketsOf: (self: CargoServiceServer, player: Player) -> { CargoTypes.CargoEntry },
	reset: (self: CargoServiceServer) -> (),
}

local CargoServiceServer: CargoServiceServer

local function tell(player: Player, text: string)
	ToastServiceServer:send(player, { text = text, duration = 2 })
end

local onPocket = RequestHandler.wrap({
	name = "CargoPocket",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		local ok, reason = CargoServiceServer:pocket(player)
		if not ok and reason ~= nil then
			tell(player, reason)
		end
	end,
})

CargoServiceServer = {
	dependencies = {
		"CarryServiceServer",
		"InteractionServiceServer",
		"VacuumServiceServer",
		"ToastServiceServer",
		"StateSyncServiceServer",
	},
	noiseMade = noiseMade,

	--[=[
		Handles Load and Search, Carry's drops, Vacuum's dust bags and the pocket packet; scatters pockets on
		death and leave.
	]=]
	start = function(self)
		InteractionServiceServer:onInteract(CargoConstants.LOAD_KIND, function(player, target)
			if target:IsA("BasePart") then
				local ok, reason = self:load(player, target)
				if not ok and reason ~= nil then
					tell(player, reason)
				end
			end
		end)
		InteractionServiceServer:onInteract(CargoConstants.SEARCH_KIND, function(player, target)
			if target:IsA("BasePart") then
				self:search(player, target)
			end
		end)

		local dropped = CarryServiceServer.dropped:Connect(onDropped)
		local bags = VacuumServiceServer.dustBagReady:Connect(function(_player, floor, parent)
			if parent.Parent ~= nil then
				spawner:spawn(VacuumConstants.DUST_BAG_KIND, floor, parent)
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			local root = rootOf(player)
			scatter(player, if root ~= nil then root.Position else nil)
		end)
		table.insert(stoppers, function()
			dropped:Disconnect()
			bags:Disconnect()
			leaving:Disconnect()
		end)
		table.insert(
			stoppers,
			CargoEvents.packets.Pocket.listen(function(data: boolean, player: Player?)
				if player then
					onPocket(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local died = if humanoid ~= nil
					then humanoid.Died:Connect(function()
						local root = rootOf(player)
						scatter(player, if root ~= nil then root.Position else nil)
					end)
					else nil
				return function()
					if died ~= nil then
						died:Disconnect()
					end
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	spawnItem = function(_self, kind, floor, parent, options)
		return spawner:spawn(kind, floor, parent, options)
	end,

	reveal = function(_self, item)
		spawner:reveal(item)
	end,

	--[=[
		The shift's container (Office): where searched and scattered items are spawned. Nil = no shift.
	]=]
	useContainer = function(_self, parent)
		container = parent
	end,

	--[=[
		Gives a desk or locker its contents for this shift (nil = empty) and turns its Search prompt on.
	]=]
	stockSearchable = function(_self, part, kind)
		stock[part] = { kind = kind, searched = false }
		InteractionServiceServer:setEnabled(part, true)
	end,

	--[=[
		Sets THE banking handler (Shift). Errors on a second one.
	]=]
	onBanked = function(_self, handler)
		assert(bankHandler == nil, "CargoServiceServer:onBanked: a banking handler is already set")
		bankHandler = handler
	end,

	--[=[
		Moves the hands item into a pocket: claim, record, release from Carry, destroy.
	]=]
	pocket = function(_self, player)
		local item = CarryServiceServer:getCarried(player)
		local entry = if item ~= nil then entryOf(item) else nil
		local id = if item ~= nil then idOf(item) else nil
		local def = if entry ~= nil then CargoRegistry.get(entry.kind) else nil
		local ok, reason = CargoHandlingRules.canPocket(def, pockets:count(player.UserId))
		if not ok then
			return false, reason
		end
		if item == nil or entry == nil or id == nil or not claims:claim(id) then
			return false, "nothing to pocket"
		end
		pockets:add(player.UserId, entry)
		CarryServiceServer:forceDrop(player, "forced")
		item:Destroy()
		publishPockets(player.UserId)
		counters.pocketed += 1
		return true, nil
	end,

	--[=[
		Loads the hands item and the pockets onto the truck: the player must stand in the bed; claim → the
		banking handler adds the deposit → destroy. A refused deposit leaves everything as it was.
	]=]
	load = function(_self, player, bed)
		local handler = bankHandler
		local root = rootOf(player)
		if handler == nil then
			return false, "the truck is not taking cargo"
		end
		if root == nil or not CargoBankRules.onBed(bed.CFrame:PointToObjectSpace(root.Position), bed.Size) then
			return false, "stand in the truck bed to load"
		end
		local item = CarryServiceServer:getCarried(player)
		local hands = if item ~= nil then entryOf(item) else nil
		local id = if item ~= nil then idOf(item) else nil
		local deposit, reason = CargoBankRules.deposit(hands, pockets:list(player.UserId), CargoRegistry.get)
		if deposit == nil then
			return false, reason
		end
		if hands ~= nil and (id == nil or not claims:claim(id)) then
			return false, "already loaded"
		end
		local ok, accepted = pcall(handler, player, deposit)
		if not ok or accepted ~= true then
			if hands ~= nil and id ~= nil then
				claims:release(id)
			end
			return false, "the truck is not taking cargo"
		end
		pockets:take(player.UserId)
		publishPockets(player.UserId)
		if item ~= nil and hands ~= nil then
			CarryServiceServer:forceDrop(player, "forced")
			item:Destroy()
		end
		counters.banked += 1
		return true, nil
	end,

	--[=[
		Searches a stocked desk or locker once per shift: what was rolled appears on the floor in front of it.
	]=]
	search = function(_self, player, part)
		local stocked = stock[part]
		if stocked == nil or stocked.searched then
			return false, "already searched"
		end
		stocked.searched = true
		InteractionServiceServer:setEnabled(part, false)
		counters.searched += 1
		noiseMade:Fire(part.Position, CargoConstants.SEARCH_NOISE, "search")
		local kind = stocked.kind
		local parent = container
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil or parent == nil then
			tell(player, "Nothing useful in here.")
			return true, nil
		end
		local front = part.CFrame * CFrame.new(0, -part.Size.Y / 2, -(part.Size.Z / 2 + 1.5))
		spawner:spawn(kind, front, parent)
		tell(player, `Found: {def.name}`)
		return true, nil
	end,

	pocketsOf = function(_self, player)
		return pockets:list(player.UserId)
	end,

	--[=[
		A new shift: pockets emptied (and published), claims forgotten, desks closed until re-stocked. The
		items themselves go with the shift's container (Office).
	]=]
	reset = function(_self)
		claims:clear()
		pockets:clear()
		for part in stock do
			InteractionServiceServer:setEnabled(part, false)
		end
		table.clear(stock)
		container = nil
		for _, player in Players:GetPlayers() do
			publishPockets(player.UserId)
		end
	end,

	getState = function(_self)
		local stocked = 0
		for _ in stock do
			stocked += 1
		end
		return {
			stocked = stocked,
			hasContainer = container ~= nil,
			hasBankHandler = bankHandler ~= nil,
			counters = table.clone(counters),
		}
	end,
}

return CargoServiceServer
```

- [ ] **Step 7: Client** `src/ReplicatedStorage/Client/Features/Cargo/CargoServiceClient.luau`:

```lua
--!strict
--[=[
	CargoServiceClient: the `pocket` Input action (Q / D-pad up), and button-friendly `pocket`, `drop` and
	`throw` for the Shift HUD's touch buttons. Requests only; the server decides.

	Drop and throw send Carry's own packets: CarryServiceClient binds them to G / F but has no callable API
	(an open question for the base).

	Spec-exempt shell (Input, Camera, ByteNet).

	@class CargoServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoEvents = require(ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents)
local CarryEvents = require(ReplicatedStorage.Shared.Features.Carry.Net.CarryEvents)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)

local unbinders: { () -> () } = {}

export type CargoServiceClient = {
	dependencies: { string },
	init: (self: CargoServiceClient) -> (),
	start: (self: CargoServiceClient) -> (),
	stop: (self: CargoServiceClient) -> (),
	pocket: (self: CargoServiceClient) -> (),
	drop: (self: CargoServiceClient) -> (),
	throw: (self: CargoServiceClient) -> (),
}

local CargoServiceClient: CargoServiceClient = {
	dependencies = { "InputServiceClient", "CarryServiceClient" },

	init = function(_self)
		if not InputActionRegistry.has(CargoConstants.POCKET_ACTION) then
			InputActionRegistry.register(CargoConstants.POCKET_ACTION, {
				context = "gameplay",
				bindings = { keyboard = { Enum.KeyCode.Q }, gamepad = { Enum.KeyCode.DPadUp } },
				description = "Pocket a tiny item",
			})
		end
	end,

	start = function(self)
		table.insert(
			unbinders,
			InputServiceClient:bind(CargoConstants.POCKET_ACTION, function(phase)
				if phase == "begin" then
					self:pocket()
				end
			end)
		)
	end,

	stop = function(_self)
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	pocket = function(_self)
		if CarryServiceClient:isCarrying() then
			CargoEvents.packets.Pocket.send(true)
		end
	end,

	drop = function(_self)
		if CarryServiceClient:isCarrying() then
			CarryEvents.packets.Drop.send(true)
		end
	end,

	throw = function(_self)
		local camera = Workspace.CurrentCamera
		if camera ~= nil and CarryServiceClient:isCarrying() then
			CarryEvents.packets.Throw.send(camera.CFrame.LookVector)
		end
	end,
}

return CargoServiceClient
```

- [ ] **Step 8: Exemptions.** Add to `EXEMPT_MODULES` under `-- Cleanup Crew: Cargo`:

```lua
	["ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem"] = "Instance/raycast shell (CargoRegistry is specced)",
	["ServerScriptService.Features.Cargo.CargoServiceServer"] = "Instance/Players/ByteNet/signal shell (handling, bank rules, claim and pocket trackers are specced)",
	["ReplicatedStorage.Client.Features.Cargo.CargoServiceClient"] = "Input/Camera/ByteNet shell (the server decides)",
```

- [ ] **Step 9: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```
Expected: pass; `CargoServiceServer` under 400 code lines (`check_file_length.py`).

- [ ] **Step 10: Controller: Studio TestEZ, then Studio verification (Play Solo).** TestEZ: CargoClaimTracker and CargoPocketTracker pass. Then, server command bar:

```lua
local C = require(game.ServerScriptService.Features.Cargo.CargoServiceServer)
local P = require(game.ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local player = game.Players:GetPlayers()[1]
local root = player.Character.HumanoidRootPart
local f = Instance.new("Folder") f.Name = "CargoTest" f.Parent = workspace
C:useContainer(f)
local function at(dx, dz) return CFrame.new(root.Position + Vector3.new(dx, -3, dz)) end
for i, kind in { "plaque", "goldenStapler", "monitor", "recyclingBox", "rubbishBag", "filingCabinet" } do
	C:spawnItem(kind, at(4 + i * 4, 0), f)
end
C.noiseMade:Connect(function(_, radius, source) print("NOISE", source, radius) end)
C:onBanked(function(_, d) print("BANK", d.clearance, d.bonus, #d.items) return true end)
local bed = Instance.new("Part") bed.Name = "TestBed" bed.Anchored = true bed.Size = Vector3.new(12, 1, 16)
bed.CFrame = CFrame.new(root.Position + Vector3.new(-14, -3.5, 0)) bed:SetAttribute("InteractionKind", "cargo-load") bed.Parent = f
game.CollectionService:AddTag(bed, "Interactable")
local desk = Instance.new("Part") desk.Name = "TestDesk" desk.Anchored = true desk.Size = Vector3.new(5, 3, 3)
desk.CFrame = CFrame.new(root.Position + Vector3.new(0, -1.5, -10)) desk:SetAttribute("InteractionKind", "cargo-search")
desk:SetAttribute("InteractionEnabled", false) desk.Parent = f game.CollectionService:AddTag(desk, "Interactable")
C:stockSearchable(desk, "plaque")
```
Checklist (each with the expected result):
1. Every item shows a name label with its value; the cabinet slows you to about 8 studs/s (`player.Character.Humanoid.WalkSpeed`), a rubbish bag to 14.8.
2. Pick up the plaque (E), press Q: `P.get(player.UserId).pocket1 == "plaque"`, the plaque is gone, walk speed back to 16. Pocket the stapler: `pocket2 == "goldenStapler"`.
3. Pick up the monitor, press Q: toast "too big for pockets". Press G: `NOISE drop 24`, its label reads `Monitor (15)`. Pick up and drop again: `Monitor (8)`.
4. Pick up the recycling box, press G: it becomes a paper pile on the floor (`NOISE drop 14`); vacuuming that pile works (Task 7).
5. Stand on `TestBed` holding the rubbish bag and use Load: `BANK 10 105 3`; the bag is gone; `pocket1` / `pocket2` are nil.
6. Double count: pick up the monitor, stand on the bed, run `print(C:load(player, workspace.CargoTest.TestBed), C:load(player, workspace.CargoTest.TestBed))` → `true nil false nothing to load`, and exactly one `BANK` line.
7. Load while standing beside the bed: toast "stand in the truck bed to load".
8. Pocket a freshly spawned plaque (`C:spawnItem("plaque", at(2, 0), f)`), then reset the character (Esc → Reset): the plaque reappears on the floor where you died, `pocket1` is nil.
9. Hold E on `TestDesk` for ~0.8 s: a plaque appears in front of it, toast "Found: Employee of the Month plaque", `NOISE search 12`; the desk prompt disappears.
10. Vacuum three piles (`require(game.ServerScriptService.Features.Vacuum.VacuumServiceServer):spawnPile("debris", at(0, 6), f)` ×3, spaced): a Dust bag appears at your feet.
11. `C:reset()` → `C:getState().stocked == 0`; `f:Destroy()` → no errors.

- [ ] **Step 11: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(cargo): spawning, pockets, handling, search and banking"
```

---

### Task 9: Office runtime (build once, roll and place each shift, reset)

**Files:**
- Create: `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau`
- Create: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `OfficeLayoutConstants.LAYOUT`, `OfficeLayoutRules.validate/checkCapacity`, `OfficeLayoutUtils.*`, `OfficeSpawnUtils.roll`, `OfficeSpawnRules.check` (Tasks 3–4); `VacuumServiceServer:spawnPile`, `VacuumServiceServer.pileCleared` (Task 7); `CargoServiceServer:spawnItem/reveal/useContainer/stockSearchable` (Task 8); `CargoConstants.LOAD_KIND/SEARCH_KIND`, `ShiftConstants.CLOCK_OUT_KIND`; `Janitor.new()`, `:Add(object, "Destroy")`, `:Cleanup()`.
- Produces (OfficeBuildSystem): `Built = { model: Model, bed: BasePart, clock: BasePart, searchables: { [string]: BasePart } }`; `build(layout, origin: CFrame) -> Built`.
- Produces (OfficeServiceServer): `beginShift(options: { seed: number, variant: string, quota: number }) -> SpawnPlan`, `reset() -> ()`, `spawnCFrame(index: number) -> CFrame`, `container() -> Folder?`.

- [ ] **Step 1: Build system** `src/ServerScriptService/Features/Office/Systems/OfficeBuildSystem.luau`:

```lua
--!strict
--[=[
	OfficeBuildSystem: builds the office's static graybox from a layout, once (Cleanup Crew spec §1
	"polished feel on graybox", §5): a floor per room, walls broken around doors (OfficeLayoutUtils.
	wallSegments), the truck (its bed is the banking zone and carries Cargo's Load prompt; a cab behind it),
	the time clock (Shift's Clock out prompt), and a desk or locker on every desk / locker marker (Cargo's
	Search prompt, off until Cargo stocks it). Everything is anchored under one Model in Workspace at the
	layout's origin. No ceiling: the graybox keeps the camera free.

	Spec-exempt shell (Instances); the layout is the one the specced OfficeLayoutRules validated.

	@class OfficeBuildSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OfficeServer = ServerScriptService.Features.Office
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

export type Built = {
	model: Model,
	bed: BasePart,
	clock: BasePart,
	searchables: { [string]: BasePart },
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

local function interactable(part: BasePart, kind: string, enabled: boolean)
	part:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, kind)
	if not enabled then
		part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
	end
	CollectionService:AddTag(part, InteractionConstants.TAG)
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local OfficeBuildSystem = {}

function OfficeBuildSystem.build(layout: OfficeTypes.Layout, origin: CFrame): Built
	local model = Instance.new("Model")
	model.Name = OfficeConstants.MODEL_NAME
	local height = OfficeConstants.WALL_HEIGHT
	local thickness = OfficeConstants.WALL_THICKNESS
	local floorThickness = OfficeConstants.FLOOR_THICKNESS
	local colors = OfficeConstants.FLOOR_COLORS

	for index, room in layout.rooms do
		local roomFolder = folder(room.name, model)
		local width = room.maxX - room.minX
		local depth = room.maxZ - room.minZ
		block(
			"Floor",
			Vector3.new(width, floorThickness, depth),
			origin * CFrame.new(room.minX + width / 2, -floorThickness / 2, room.minZ + depth / 2),
			colors[(index - 1) % #colors + 1],
			roomFolder
		)
		for _, segment in OfficeLayoutUtils.wallSegments(room, layout.doors) do
			local horizontal = segment.z1 == segment.z2
			local length = if horizontal then segment.x2 - segment.x1 else segment.z2 - segment.z1
			local size = if horizontal
				then Vector3.new(length + thickness, height, thickness)
				else Vector3.new(thickness, height, length + thickness)
			local centre = CFrame.new((segment.x1 + segment.x2) / 2, height / 2, (segment.z1 + segment.z2) / 2)
			block("Wall", size, origin * centre, OfficeConstants.WALL_COLOR, roomFolder)
		end
	end

	local truckFolder = folder("Truck", model)
	local truck = layout.truck
	local bedWidth = truck.maxX - truck.minX
	local bedDepth = truck.maxZ - truck.minZ
	local bedHeight = OfficeConstants.BED_HEIGHT
	local bed = block(
		"TruckBed",
		Vector3.new(bedWidth, bedHeight, bedDepth),
		origin * CFrame.new(truck.minX + bedWidth / 2, bedHeight / 2, truck.minZ + bedDepth / 2),
		OfficeConstants.BED_COLOR,
		truckFolder
	)
	interactable(bed, CargoConstants.LOAD_KIND, true)
	local cab = OfficeConstants.CAB_SIZE
	block(
		"TruckCab",
		cab,
		origin * CFrame.new(truck.minX + bedWidth / 2, cab.Y / 2, truck.maxZ + cab.Z / 2),
		OfficeConstants.TRUCK_COLOR,
		truckFolder
	)
	local clockSize = OfficeConstants.CLOCK_SIZE
	local clock = block(
		"TimeClock",
		clockSize,
		origin * CFrame.new(truck.clockX, clockSize.Y / 2, truck.clockZ),
		OfficeConstants.CLOCK_COLOR,
		truckFolder
	)
	interactable(clock, ShiftConstants.CLOCK_OUT_KIND, true)

	local furniture = folder("Furniture", model)
	local searchables: { [string]: BasePart } = {}
	for _, marker in layout.markers do
		if marker.kind == "desk" or marker.kind == "locker" then
			local isDesk = marker.kind == "desk"
			local size = if isDesk then OfficeConstants.DESK_SIZE else OfficeConstants.LOCKER_SIZE
			local part = block(
				if isDesk then "Desk" else "Locker",
				size,
				origin * CFrame.new(marker.x, size.Y / 2, marker.z),
				if isDesk then OfficeConstants.DESK_COLOR else OfficeConstants.LOCKER_COLOR,
				furniture
			)
			interactable(part, CargoConstants.SEARCH_KIND, false)
			searchables[marker.id] = part
		end
	end

	model.Parent = Workspace
	return { model = model, bed = bed, clock = clock, searchables = searchables }
end

return OfficeBuildSystem
```

- [ ] **Step 2: Service** `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`:

```lua
--!strict
--[=[
	OfficeServiceServer: the Harlow & Finch office (Cleanup Crew spec §6.2 "Office", §6.5 "Reset"). At start
	it validates the authored layout (OfficeLayoutRules; a broken layout is a boot error) and builds the
	static graybox once (OfficeBuildSystem) at OfficeConstants.ORIGIN, far from the origin where M4's depot
	goes. Each shift `beginShift` rolls the spawns (OfficeSpawnUtils, re-rolling with the next seed if
	OfficeSpawnRules finds a broken guarantee) and places them in ONE per-shift folder owned by ONE Janitor:
	piles (Vacuum), items (Cargo), hidden items under piles (revealed when the pile is cleared), and desk /
	locker contents (Cargo). `reset` destroys that folder and forgets the shift.

	Spec-exempt shell (Instances, signals); the decisions are the specced OfficeLayoutRules, OfficeLayoutUtils,
	OfficeSpawnUtils and OfficeSpawnRules.

	@class OfficeServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

type Marker = OfficeTypes.Marker

local LAYOUT = OfficeLayoutConstants.LAYOUT

local log = Logger.new("OfficeServiceServer")

local markerById: { [string]: Marker } = {}
for _, marker in LAYOUT.markers do
	markerById[marker.id] = marker
end
local spawnMarkers = OfficeLayoutUtils.markersOf(LAYOUT, "spawn")

local built: OfficeBuildSystem.Built? = nil
local shiftJanitor = Janitor.new()
local shiftFolder: Folder? = nil
-- pile → the item hidden under it, for this shift.
local hidden: { [BasePart]: BasePart } = {}
local lastPlan: OfficeTypes.SpawnPlan? = nil
local stoppers: { () -> () } = {}

-- The floor point under a marker, in the world.
local function floorAt(marker: Marker): CFrame
	return OfficeConstants.ORIGIN * CFrame.new(marker.x, 0, marker.z)
end

local function rollPlan(options: { seed: number, variant: string, quota: number }): OfficeTypes.SpawnPlan
	local rollOptions: OfficeTypes.RollOptions = {
		quota = options.quota,
		variant = options.variant,
		piles = OfficeConstants.PILES,
		salvage = OfficeConstants.SALVAGE,
	}
	for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
		local seed = options.seed + attempt
		local plan = OfficeSpawnUtils.roll(LAYOUT, rollOptions, Random.new(seed))
		local ok, reason = OfficeSpawnRules.check(plan, LAYOUT, options.quota)
		if ok then
			return plan
		end
		log:warn(`spawn roll {seed} missed a guarantee: {reason or "?"}`)
	end
	error(`office: no spawn roll from seed {options.seed} met the guarantees`)
end

export type OfficeServiceServer = {
	dependencies: { string },
	start: (self: OfficeServiceServer) -> (),
	stop: (self: OfficeServiceServer) -> (),
	getState: (self: OfficeServiceServer) -> { [string]: any },
	beginShift: (
		self: OfficeServiceServer,
		options: { seed: number, variant: string, quota: number }
	) -> OfficeTypes.SpawnPlan,
	reset: (self: OfficeServiceServer) -> (),
	spawnCFrame: (self: OfficeServiceServer, index: number) -> CFrame,
	container: (self: OfficeServiceServer) -> Folder?,
}

local OfficeServiceServer: OfficeServiceServer = {
	dependencies = { "VacuumServiceServer", "CargoServiceServer" },

	--[=[
		Validates and builds the office, and reveals hidden items as their piles are cleared.
	]=]
	start = function(_self)
		local ok, errors = OfficeLayoutRules.validate(LAYOUT)
		assert(ok, `office layout is invalid:\n{table.concat(errors, "\n")}`)
		local capacityOk, reason = OfficeLayoutRules.checkCapacity(LAYOUT)
		assert(capacityOk, `office layout cannot hold a shift: {reason or "?"}`)
		built = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		local cleared = VacuumServiceServer.pileCleared:Connect(function(pile)
			local item = hidden[pile]
			hidden[pile] = nil
			if item ~= nil and item.Parent ~= nil then
				CargoServiceServer:reveal(item)
			end
		end)
		table.insert(stoppers, function()
			cleared:Disconnect()
		end)
	end,

	stop = function(self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		self:reset()
		local current = built
		if current ~= nil then
			current.model:Destroy()
			built = nil
		end
	end,

	--[=[
		Resets, then rolls and places one shift's spawns. Returns the plan placed.
	]=]
	beginShift = function(self, options)
		self:reset()
		local current = built
		assert(current ~= nil, "OfficeServiceServer:beginShift before start")
		local plan = rollPlan(options)
		local folder = Instance.new("Folder")
		folder.Name = OfficeConstants.SHIFT_FOLDER_NAME
		folder.Parent = current.model
		shiftJanitor:Add(folder, "Destroy")
		shiftFolder = folder
		CargoServiceServer:useContainer(folder)

		for _, pilePlan in plan.piles do
			local marker = markerById[pilePlan.marker]
			if marker ~= nil then
				local floor = floorAt(marker)
				local pile = VacuumServiceServer:spawnPile(pilePlan.kind, floor, folder)
				local hides = pilePlan.hides
				if hides ~= nil then
					hidden[pile] = CargoServiceServer:spawnItem(hides, floor, folder, { hidden = true })
				end
			end
		end
		for _, itemPlan in plan.items do
			local marker = markerById[itemPlan.marker]
			if marker ~= nil then
				CargoServiceServer:spawnItem(itemPlan.kind, floorAt(marker), folder)
			end
		end
		for _, search in plan.searchables do
			local part = current.searchables[search.marker]
			if part ~= nil then
				CargoServiceServer:stockSearchable(part, search.kind)
			end
		end
		lastPlan = plan
		log:info(`shift spawns: {#plan.piles} piles, {#plan.items} items, {plan.trashValue} trash`)
		return plan
	end,

	--[=[
		Destroys everything the current shift spawned (the one folder) and forgets it.
	]=]
	reset = function(_self)
		shiftJanitor:Cleanup()
		shiftFolder = nil
		table.clear(hidden)
		lastPlan = nil
	end,

	--[=[
		Where the `index`-th crew member appears in the loading bay (wrapping over the spawn markers).
	]=]
	spawnCFrame = function(_self, index)
		local marker = spawnMarkers[(math.max(index, 1) - 1) % #spawnMarkers + 1]
		return OfficeConstants.ORIGIN * CFrame.new(marker.x, OfficeConstants.SPAWN_HEIGHT, marker.z)
	end,

	container = function(_self)
		return shiftFolder
	end,

	getState = function(_self)
		local plan = lastPlan
		local hiddenCount = 0
		for _ in hidden do
			hiddenCount += 1
		end
		return {
			built = built ~= nil,
			shift = shiftFolder ~= nil,
			piles = if plan ~= nil then #plan.piles else 0,
			items = if plan ~= nil then #plan.items else 0,
			trashValue = if plan ~= nil then plan.trashValue else 0,
			greed = if plan ~= nil and plan.greed ~= nil then `{plan.greed.kind} @ {plan.greed.marker}` else nil,
			hiddenUnderPiles = hiddenCount,
		}
	end,
}

return OfficeServiceServer
```


- [ ] **Step 3: Exemptions.** Add under `-- Cleanup Crew: Office`:

```lua
	["ServerScriptService.Features.Office.Systems.OfficeBuildSystem"] = "Instance builder (the layout is validated by the specced OfficeLayoutRules)",
	["ServerScriptService.Features.Office.OfficeServiceServer"] = "Instance/signal shell (layout rules, spawn roll and spawn rules are specced)",
```

- [ ] **Step 4: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 5: Controller: Studio TestEZ, then Studio verification (Play Solo).** TestEZ: everything passes. Then server command bar:

```lua
local O = require(game.ServerScriptService.Features.Office.OfficeServiceServer)
local player = game.Players:GetPlayers()[1]
print(workspace.CleanupCrewOffice:GetPivot().Position)
player.Character:PivotTo(O:spawnCFrame(1))
local plan = O:beginShift({ seed = 1, variant = "B", quota = 350 })
print(#plan.piles, #plan.items, plan.trashValue, plan.greed.kind, plan.greed.marker)
print(game:GetService("HttpService"):JSONEncode(O:getState()))
```
Checklist:
1. `workspace.CleanupCrewOffice` exists near x = 1000 with seven floored, walled rooms, door gaps, a grey truck bed with a white cab, a red time clock, desks and lockers. Walking every doorway works (no blocked door).
2. You stand in the loading bay. The printed plan has 18–24 piles, `trashValue >= 525`, a greed target on a marker in breakRoom / manager / server / archive.
3. Piles and labelled items are scattered through the rooms; the bed shows a "Load" prompt, the clock a "Clock out" prompt (it does nothing until Task 10), stocked desks a "Search" hold prompt.
4. `O:getState().hiddenUnderPiles` > 0 (variant B); vacuum piles until one reveals a labelled item underneath (try `seed = 2..5` if none is close).
5. `O:beginShift({ seed = 1, variant = "B", quota = 350 })` again: same pile and item placement as step 2 (seeded).
6. `O:beginShift({ seed = 9, variant = "A", quota = 350 })`: `hiddenUnderPiles == 0`.
7. Hold an item, then `O:reset()`: `workspace.CleanupCrewOffice.Shift` is gone, the held item is gone and walk speed is back to 16; desks lose their prompt only after `require(game.ServerScriptService.Features.Cargo.CargoServiceServer):reset()`.

- [ ] **Step 6: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(office): graybox build and per-shift spawns"
```

---
### Task 10: Shift runtime (Round, banking, quota, clock out, results, vote, reset)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Shift/Net/ShiftEvents.luau`
- Create: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes (base, verified in source): `RoundServiceServer:configure({ minPlayers?, countdown?, duration?, resultsDuration?, autoStart?, lateJoin? })`, `:getPhase() -> RoundState`, `:startCountdown() -> boolean`, `:endRound(outcome) -> boolean`, `:participants() -> { Player }`, `:setTarget(counter, target?)`, `:addTeam(counter, amount) -> number`, `:teamValue(counter) -> number`, `:addScore(player, counter, amount) -> number`, `:scoreOf(player, counter) -> number`, `.phaseChanged: Signal<RoundState>` (`src/ServerScriptService/Features/Round/RoundServiceServer.luau`); `DeathServiceServer:setSpawnPoint(resolver?)`; `InteractionServiceServer:onInteract(kind, handler)`; `InteractionRegistry.register`; `ToastServiceServer:send(target, request)`; `RequestHandler.wrap` with a decoding `validate` (third return passed to `handler`); `StateSyncWorldStore.set / clear`.
- Consumes (Tasks 5–9): `ShiftPhaseRules.*`, `ShiftVoteRules.*`, `ShiftResultsUtils.build`, `ShiftSnapshotUtils.build`, `ShiftConstants.*`, `CargoServiceServer:onBanked/reset`, `CargoTypes.Deposit`, `VacuumServiceServer.pileCleared/reset`, `OfficeServiceServer:beginShift/reset/spawnCFrame`.
- Produces (ShiftEvents): `packets.Vote` (client → server, `ByteNet.string`).
- Produces (ShiftServiceServer): `getShift() -> ShiftState`, `clockOut(player: Player?) -> boolean`, `vote(player, choice: Vote) -> boolean`, `resetShift() -> ()`; the `shift` world entry.
- Round is configured: `minPlayers = 1`, `countdown = 5` (arrival), `duration = 420`, `resultsDuration = 0` (Shift holds results itself), `autoStart = false` (Shift's tick starts countdowns), `lateJoin = true`.
- Round's `phaseChanged` and Vacuum's `pileCleared` arrive deferred (SignalPlus): handlers run later in the same frame, before Round's next 0.25 s step, so Round's counters are still intact when results are built.

- [ ] **Step 1: Packets** `src/ReplicatedStorage/Shared/Features/Shift/Net/ShiftEvents.luau`:

```lua
--!strict
--[=[
	ShiftEvents: the Shift's ByteNet packets (client → server only). The server parses the vote
	(ShiftVoteRules) and ignores it outside results.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at ShiftServiceServer load).

	@class ShiftEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ShiftEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ShiftEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- "another" or "depot"; anything else is dropped by the server.
			Vote = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ShiftEvents
```

- [ ] **Step 2: Server** `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`:

```lua
--!strict
--[=[
	ShiftServiceServer: one Cleanup Crew shift, start to vote (spec §3, §6.5). It configures Round (a 5 s
	arrival countdown, the 7:00 run, late join; results handed straight back, because Round cannot hold
	them) and follows its phases through ShiftPhaseRules. Around them:

	- run start: the clearance target, the office's spawns (OfficeServiceServer:beginShift), the crew moved
	  to the loading bay, which is also where everyone respawns (DeathServiceServer:setSpawnPoint);
	- banking: Cargo's `onBanked` adds trash to Round's `clearance` counter and salvage to `bonus`, keeps
	  per-player scores, and stamps QUOTA MET once;
	- clock out: the time clock at the truck starts a 10 s countdown for everyone, then ends the run;
	- results: ShiftResultsUtils builds the review; the crew votes Another shift / Back to depot (the depot is
	  M4: until then both reset in this server);
	- reset: Office, Vacuum and Cargo clear everything the shift made. `resetShift` mid-run (Studio test
	  runs) ends Round's run first and skips the review.

	State rides the `shift` world entry (ShiftSnapshotUtils). Spec-exempt shell (Players, RunService, the
	services it drives); the decisions are the specced ShiftPhaseRules, ShiftVoteRules, ShiftResultsUtils and
	ShiftSnapshotUtils.

	@class ShiftServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local ShiftServer = ServerScriptService.Features.Shift
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ShiftPhaseRules = require(ShiftServer.Rules.ShiftPhaseRules)
local ShiftVoteRules = require(ShiftServer.Rules.ShiftVoteRules)
local ShiftResultsUtils = require(ShiftServer.Utils.ShiftResultsUtils)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

-- Registered at load: the office's time clock carries this kind from the moment it is built.
if not InteractionRegistry.has(ShiftConstants.CLOCK_OUT_KIND) then
	InteractionRegistry.register(ShiftConstants.CLOCK_OUT_KIND, { actionText = "Clock out", objectText = "Time clock" })
end

local log = Logger.new("ShiftServiceServer")

local state: ShiftTypes.ShiftState = ShiftPhaseRules.initial(ShiftConstants.QUOTA, ShiftConstants.VARIANT)
local votes: { [number]: ShiftTypes.Vote } = {}
local results: ShiftTypes.ShiftResults? = nil
local resetPending = false
local rng = Random.new()
local publishScheduled = false
local stoppers: { () -> () } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function presentIds(): { number }
	local ids: { number } = {}
	for _, player in Players:GetPlayers() do
		table.insert(ids, player.UserId)
	end
	return ids
end

-- Republishes the `shift` world entry, coalesced to once per frame.
local function publish()
	if publishScheduled then
		return
	end
	publishScheduled = true
	task.defer(function()
		publishScheduled = false
		local another, depot = ShiftVoteRules.tally(votes, presentIds())
		local review = results
		-- During results Round has already cleared its counters, so the review carries the totals.
		local cleared = if review ~= nil then review.cleared else RoundServiceServer:teamValue(ShiftConstants.CLEARANCE)
		local bonus = if review ~= nil then review.bonus else RoundServiceServer:teamValue(ShiftConstants.BONUS)
		StateSyncWorldStore.set(
			ShiftConstants.WORLD_ENTRY,
			ShiftSnapshotUtils.build(state, cleared, bonus, another, depot, review)
		)
	end)
end

local function setState(nextState: ShiftTypes.ShiftState)
	state = nextState
	publish()
end

local function crewStats(): { ShiftTypes.CrewStats }
	local crew: { ShiftTypes.CrewStats } = {}
	for _, player in RoundServiceServer:participants() do
		table.insert(crew, {
			userId = player.UserId,
			name = player.DisplayName,
			banked = RoundServiceServer:scoreOf(player, ShiftConstants.SCORE_BANKED),
			piles = RoundServiceServer:scoreOf(player, ShiftConstants.SCORE_PILES),
			salvage = RoundServiceServer:scoreOf(player, ShiftConstants.SCORE_SALVAGE),
		})
	end
	return crew
end

-- Clears everything the shift made and waits in the lobby (the tick starts the next countdown).
local function finishReset()
	OfficeServiceServer:reset()
	VacuumServiceServer:reset()
	CargoServiceServer:reset()
	table.clear(votes)
	results = nil
	setState(ShiftPhaseRules.toLobby(state))
end

local function beginRun()
	table.clear(votes)
	results = nil
	RoundServiceServer:setTarget(ShiftConstants.CLEARANCE, state.quota)
	local plan =
		OfficeServiceServer:beginShift({ seed = rng:NextInteger(1, 1000000000), variant = state.variant, quota = state.quota })
	log:info(`shift {state.shift} started: variant {state.variant}, greed {if plan.greed ~= nil then plan.greed.kind else "?"}`)
	for index, player in RoundServiceServer:participants() do
		local character = player.Character
		if character ~= nil then
			character:PivotTo(OfficeServiceServer:spawnCFrame(index))
		end
	end
	ToastServiceServer:send("all", {
		text = `Shift {state.shift}: clear {state.quota} of trash before the clock runs out. Load it on the truck.`,
		duration = 6,
	})
end

local function onRoundPhase(roundState: RoundTypes.RoundState)
	local before = state.phase
	local nextState = ShiftPhaseRules.follow(state, roundState, now())
	if nextState == nil then
		return
	end
	if nextState.phase == "results" and resetPending then
		resetPending = false
		finishReset()
		return
	end
	if nextState.phase == "results" then
		results = ShiftResultsUtils.build({
			outcome = roundState.outcome or "timeout",
			quota = state.quota,
			cleared = RoundServiceServer:teamValue(ShiftConstants.CLEARANCE),
			bonus = RoundServiceServer:teamValue(ShiftConstants.BONUS),
			quotaMet = state.quotaMet,
			crew = crewStats(),
		})
	end
	setState(nextState)
	if nextState.phase == "running" and before ~= "running" then
		beginRun()
	end
end

-- Cargo's banking handler: synchronous (claim → add → destroy happens around it).
local function onBanked(player: Player, deposit: CargoTypes.Deposit): boolean
	if state.phase ~= "running" then
		return false
	end
	local bonus = math.floor(deposit.bonus * ShiftConstants.SALVAGE_MULTIPLIER + 0.5)
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
	ToastServiceServer:send(player, { text = `Loaded: +{deposit.clearance} clearance, +{bonus} bonus`, duration = 2 })
	local met = ShiftPhaseRules.markQuota(state, RoundServiceServer:teamValue(ShiftConstants.CLEARANCE))
	if met ~= nil then
		setState(met)
		ToastServiceServer:send("all", {
			text = "QUOTA MET. Salvage is a bonus now: clock out at the truck when you're done.",
			duration = 6,
		})
	else
		publish()
	end
	return true
end

local function resolveVote(timedOut: boolean)
	local decision = ShiftVoteRules.decide(votes, presentIds(), timedOut)
	if decision == nil then
		return
	end
	if decision == "depot" then
		ToastServiceServer:send("all", { text = "The depot opens in a later build. Starting another shift.", duration = 5 })
	end
	finishReset()
end

local function step()
	local action = ShiftPhaseRules.tick(state, now(), #Players:GetPlayers())
	if action == "start" then
		RoundServiceServer:startCountdown()
	elseif action == "endShift" then
		RoundServiceServer:endRound(ShiftConstants.OUTCOME_CLOCKOUT)
	elseif action == "resolveVote" then
		resolveVote(true)
	end
end

export type ShiftServiceServer = {
	dependencies: { string },
	start: (self: ShiftServiceServer) -> (),
	stop: (self: ShiftServiceServer) -> (),
	getState: (self: ShiftServiceServer) -> { [string]: any },
	getShift: (self: ShiftServiceServer) -> ShiftTypes.ShiftState,
	clockOut: (self: ShiftServiceServer, player: Player?) -> boolean,
	vote: (self: ShiftServiceServer, player: Player, choice: ShiftTypes.Vote) -> boolean,
	resetShift: (self: ShiftServiceServer) -> (),
}

local ShiftServiceServer: ShiftServiceServer

local onVote = RequestHandler.wrap({
	name = "ShiftVote",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	validate = function(data: string, _player: Player): (boolean, string?, ShiftTypes.Vote?)
		local choice = ShiftVoteRules.parse(data)
		if choice == nil then
			return false, "unknown vote", nil
		end
		return true, nil, choice
	end,
	handler = function(_data: string, player: Player, choice: ShiftTypes.Vote?)
		if choice ~= nil then
			ShiftServiceServer:vote(player, choice)
		end
	end,
})

ShiftServiceServer = {
	dependencies = {
		"RoundServiceServer",
		"OfficeServiceServer",
		"VacuumServiceServer",
		"CargoServiceServer",
		"ToastServiceServer",
		"DeathServiceServer",
		"InteractionServiceServer",
		"StateSyncServiceServer",
	},

	--[=[
		Configures Round and Death, takes over banking and the time clock, follows Round, counts piles,
		listens for votes and starts the clock.
	]=]
	start = function(self)
		RoundServiceServer:configure({
			minPlayers = ShiftConstants.MIN_PLAYERS,
			countdown = ShiftConstants.ARRIVAL_SECONDS,
			duration = ShiftConstants.SHIFT_SECONDS,
			resultsDuration = 0,
			autoStart = false,
			lateJoin = true,
		})
		DeathServiceServer:setSpawnPoint(function(player)
			return OfficeServiceServer:spawnCFrame(table.find(Players:GetPlayers(), player) or 1)
		end)
		CargoServiceServer:onBanked(onBanked)
		InteractionServiceServer:onInteract(ShiftConstants.CLOCK_OUT_KIND, function(player, _target)
			self:clockOut(player)
		end)

		local phases = RoundServiceServer.phaseChanged:Connect(onRoundPhase)
		local piles = VacuumServiceServer.pileCleared:Connect(function(_pile, players)
			if state.phase ~= "running" then
				return
			end
			for _, player in players do
				if player.Parent ~= nil then
					RoundServiceServer:addScore(player, ShiftConstants.SCORE_PILES, 1)
				end
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			votes[player.UserId] = nil
			publish()
		end)
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= ShiftConstants.TICK_INTERVAL then
				elapsed = 0
				step()
			end
		end)
		table.insert(stoppers, function()
			phases:Disconnect()
			piles:Disconnect()
			leaving:Disconnect()
			ticking:Disconnect()
		end)
		table.insert(
			stoppers,
			ShiftEvents.packets.Vote.listen(function(data: string, player: Player?)
				if player then
					onVote(data, player)
				end
			end)
		)
		publish()
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		DeathServiceServer:setSpawnPoint(nil)
		StateSyncWorldStore.clear(ShiftConstants.WORLD_ENTRY)
	end,

	getShift = function(_self)
		return table.clone(state)
	end,

	--[=[
		Starts the 10 s clock-out countdown (the time clock's prompt). False when it cannot (not running, or
		already counting down).
	]=]
	clockOut = function(_self, player)
		local nextState = ShiftPhaseRules.clockOut(state, now())
		if nextState == nil then
			return false
		end
		setState(nextState)
		local who = if player ~= nil then player.DisplayName else "Someone"
		ToastServiceServer:send("all", {
			text = `{who} clocked out. The shift ends in {ShiftConstants.CLOCK_OUT_SECONDS} s: cargo not on the truck is lost.`,
			duration = ShiftConstants.CLOCK_OUT_SECONDS,
		})
		return true
	end,

	--[=[
		Records a results vote (replacing the player's earlier one) and resolves the vote if it is decided.
	]=]
	vote = function(_self, player, choice)
		if state.phase ~= "results" then
			return false
		end
		votes[player.UserId] = choice
		publish()
		resolveVote(false)
		return true
	end,

	--[=[
		Clears the shift and returns to the lobby (Another shift; Studio test runs). Mid-run it ends Round's
		run first; the reset then happens when Round reports results.
	]=]
	resetShift = function(_self)
		if RoundServiceServer:getPhase().phase == "running" then
			resetPending = true
			RoundServiceServer:endRound(ShiftConstants.OUTCOME_RESET)
			return
		end
		finishReset()
	end,

	getState = function(_self)
		local another, depot = ShiftVoteRules.tally(votes, presentIds())
		return {
			phase = state.phase,
			sub = state.sub,
			shift = state.shift,
			quota = state.quota,
			quotaMet = state.quotaMet,
			variant = state.variant,
			cleared = RoundServiceServer:teamValue(ShiftConstants.CLEARANCE),
			bonus = RoundServiceServer:teamValue(ShiftConstants.BONUS),
			votesAnother = another,
			votesDepot = depot,
			hasResults = results ~= nil,
			resetPending = resetPending,
		}
	end,
}

return ShiftServiceServer
```

- [ ] **Step 3: Exemptions.** Add under `-- Cleanup Crew: Shift`:

```lua
	["ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Shift.ShiftServiceServer"] = "Players/RunService/service-orchestration shell (phase, vote, results and snapshot rules are specced)",
```

- [ ] **Step 4: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```

- [ ] **Step 5: Controller: Studio TestEZ** (regression; everything passes). Note: the TestEZ session is not a play session (AGENTS.md); run the checklist below in a fresh Play with `RunTests` off.

- [ ] **Step 6: Studio verification (controller, Play Solo, `RunTests = false`).** Server command bar helpers:

```lua
local S = require(game.ServerScriptService.Features.Shift.ShiftServiceServer)
local R = require(game.ServerScriptService.Features.Round.RoundServiceServer)
local W = require(game.ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local H = game:GetService("HttpService")
local player = game.Players:GetPlayers()[1]
local function show() print(H:JSONEncode(W.get("shift"))) end
show()
```
Checklist:
1. Within a second of joining, `S:getShift().phase` is `"starting"`; 5 s later `"running"`, `shift = 1`; you stand in the loading bay at x ≈ 1028; a toast announces the quota; `show()` has `quota = 350`, `endsAt` ≈ now + 420.
2. Carry a rubbish bag onto the truck bed and Load: toast `Loaded: +10 clearance, +0 bonus`; `show()` has `cleared = 10`. Pocket a plaque and Load with empty hands: `bonus = 25`.
3. `R:addTeam("clearance", 340)` then Load one more trash item: `quotaMet = true` and the "QUOTA MET" toast to everyone, once (Load another: no second toast).
4. Vacuum a pile: `R:scoreOf(player, "piles")` is 1.
5. Use the time clock: a clock-out toast for everyone; `sub = "clockout"`, `clockOutAt` ≈ now + 10; using it again does nothing. 10 s later `phase = "results"`, `results.outcome = "clockout"`, `results.cleared` matches, `results.crew[1].name` is your display name; `R:getPhase().phase` is `"lobby"`; Shift stays in results.
6. `S:vote(player, "another")`: true; within a frame the shift is back in `"lobby"`, `workspace.CleanupCrewOffice.Shift` is replaced, and the next countdown starts; shift 2 runs with a fresh spawn roll (different piles).
7. Mid-run reset while holding an item and mid-vacuum: `S:resetShift()` → `getState().resetPending` true for a frame, then lobby → starting → running shift 3; the held item is gone, walk speed is 16, `canister` and pockets read 0/empty (`require(game.ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore).get(player.UserId)`), no review was shown (`hasResults` false until the next results).
8. Vote timeout: clock out, wait 30 s in results without voting → another shift starts.
9. Respawn: reset your character mid-shift → you respawn in the loading bay.
10. Timer expiry: `R:configure({ duration = 20 })`, then `S:resetShift()`; the next shift ends by itself 20 s after it starts with `results.outcome = "timeout"`. Restore with `R:configure({ duration = 420 })`.

- [ ] **Step 7: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(shift): shift lifecycle, banking, clock out, results and vote"
```

---

### Task 11: Shift client and placeholder UI (HUD, results, touch buttons)

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Shift/State/ShiftStore.luau`
- Create: `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Hooks/useServerClock.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau` (+ `.spec.luau`)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudPanel.luau` (+ `ShiftHudPanel.story.luau`)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHud.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftResultsPanel.luau` (+ `ShiftResultsPanel.story.luau`)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftResults.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftMobileButtons.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `ShiftSnapshotUtils.decode`, `ShiftTypes.*`, `ShiftConstants.WORLD_ENTRY/HUD_ORDER`, `ShiftEvents.packets.Vote`; `StateSyncClientStore.world` / `.publicPlayers` (Charm atoms), `StateSyncConstants.publicEntryKey(userId)`; `HudRegistry.register(key, component, order)` / `.has(key)`; `Panel`, `Button`, `Tokens`; `ReactCharm.useAtom`; `VacuumServiceClient:beginVacuum/endVacuum`, `CargoServiceClient:pocket/drop/throw`; `CargoRegistry.get`, `CargoConstants.PUBLIC_POCKET_FIELDS`, `CarryConstants.PUBLIC_FIELD`, `VacuumConstants.PUBLIC_FIELD/CANISTER_CAPACITY`.
- Produces (ShiftStore): `snapshot: Charm computed () -> ShiftSnapshot?`, `myVote: Charm.Atom<Vote?>`.
- Produces (ShiftServiceClient): `get() -> ShiftSnapshot?`, `vote(choice: Vote) -> ()`; registers HUD widgets `shiftHud` (order 10), `shiftResults` (11), `shiftMobile` (12).
- Produces (ShiftHudViewModel): `HudView = { timer, clearance, quotaMet: boolean, bonus, canister, hands, pockets, clockOut: string? }`, `ResultsView = { title, lines: { string }, another, depot, countdown }`; `clock(seconds) -> string`, `hud(snapshot?, me: PublicPlayer?, now) -> HudView?`, `results(snapshot?, now) -> ResultsView?`.
- Produces (useServerClock): `useServerClock(interval: number?) -> number` (server time, refreshed every `interval`, default 0.25 s).
- React components never send packets: ShiftResults writes `ShiftStore.myVote`; ShiftServiceClient sends it. This also avoids a require cycle (ShiftServiceClient requires the widgets; the widgets require only the store).

- [ ] **Step 1: Write the failing view-model spec** `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.spec.luau`:

```lua
local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		shift = 1,
		endsAt = 1000,
		quota = 350,
		cleared = 120,
		bonus = 40,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local REVIEW = {
	outcome = "clockout",
	quota = 350,
	cleared = 380,
	bonus = 95,
	salvage = 3,
	piles = 12,
	quotaMet = true,
	crew = { { name = "Ava", banked = 200, piles = 6, salvage = 2 } },
	awards = { { title = "Top Hauler", name = "Ava" } },
}

return function()
	describe("clock", function()
		it("formats minutes and seconds, rounding up and never negative", function()
			expect(ShiftHudViewModel.clock(420)).to.equal("7:00")
			expect(ShiftHudViewModel.clock(61)).to.equal("1:01")
			expect(ShiftHudViewModel.clock(59.2)).to.equal("1:00")
			expect(ShiftHudViewModel.clock(0)).to.equal("0:00")
			expect(ShiftHudViewModel.clock(-5)).to.equal("0:00")
		end)
	end)

	describe("hud", function()
		it("shows nothing outside a running shift", function()
			expect(ShiftHudViewModel.hud(nil, nil, 0)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot({ phase = "results" }), nil, 0)).to.equal(nil)
		end)

		it("shows the timer, clearance, bonus and canister", function()
			local view = ShiftHudViewModel.hud(snapshot(), { canister = 2 }, 580)
			expect(view.timer).to.equal("Shift 1 | 7:00")
			expect(view.clearance).to.equal("Clearance 120 / 350")
			expect(view.bonus).to.equal("Bonus 40")
			expect(view.canister).to.equal("Canister 2 / 3")
			expect(view.quotaMet).to.equal(false)
			expect(view.clockOut).to.equal(nil)
		end)

		it("names the hands item and the pockets, an empty one as a dash", function()
			local view = ShiftHudViewModel.hud(snapshot(), { carrying = "monitor", pocket1 = "plaque" }, 0)
			expect(view.hands).to.equal("Hands: Monitor")
			expect(view.pockets).to.equal("Pockets: Employee of the Month plaque | -")
		end)

		it("reads an absent canister and empty hands", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 0)
			expect(view.canister).to.equal("Canister 0 / 3")
			expect(view.hands).to.equal("Hands: -")
			expect(view.pockets).to.equal("Pockets: - | -")
		end)

		it("shows the clock-out countdown and the quota flag", function()
			local view = ShiftHudViewModel.hud(snapshot({ sub = "clockout", clockOutAt = 107, quotaMet = true }), nil, 100)
			expect(view.clockOut).to.equal("CLOCKING OUT 0:07")
			expect(view.quotaMet).to.equal(true)
		end)
	end)

	describe("results", function()
		it("shows nothing outside results", function()
			expect(ShiftHudViewModel.results(snapshot(), 0)).to.equal(nil)
			expect(ShiftHudViewModel.results(nil, 0)).to.equal(nil)
		end)

		it("lists the review and the vote", function()
			local view = ShiftHudViewModel.results(
				snapshot({ phase = "results", voteEndsAt = 130, votesAnother = 2, votesDepot = 1, results = REVIEW }),
				100
			)
			expect(view.title).to.equal("Shift 1 performance review")
			expect(view.lines[1]).to.equal("Clocked out")
			expect(view.lines[2]).to.equal("Cleared 380 / 350 - QUOTA MET")
			expect(view.lines[3]).to.equal("Bonus 95")
			expect(view.lines[4]).to.equal("Salvage found 3 | Piles vacuumed 12")
			expect(view.lines[5]).to.equal("Ava: banked 200, piles 6")
			expect(view.lines[6]).to.equal("Top Hauler: Ava")
			expect(view.another).to.equal("Another shift (2)")
			expect(view.depot).to.equal("Back to depot (1)")
			expect(view.countdown).to.equal("Deciding in 0:30")
		end)

		it("says when the quota was missed and the time ran out", function()
			local review = table.clone(REVIEW)
			review.outcome = "timeout"
			review.cleared = 200
			review.quotaMet = false
			local view = ShiftHudViewModel.results(snapshot({ phase = "results", voteEndsAt = 100, results = review }), 100)
			expect(view.lines[1]).to.equal("Time's up")
			expect(view.lines[2]).to.equal("Cleared 200 / 350 - quota missed")
		end)
	end)
end
```

- [ ] **Step 2: Controller: Studio TestEZ.** Expected: the spec errors (module missing).

- [ ] **Step 3: View model** `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudViewModel.luau`:

```lua
--!strict
--[=[
	ShiftHudViewModel: the strings the M1 placeholder Shift HUD and results panel show, from the shift
	snapshot and the local player's public entry. Pure (specced); the components only lay them out. Final
	screens replace these components after the developer's Figma approval (M3); the view model can stay.

	@class ShiftHudViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type HudView = {
	timer: string,
	clearance: string,
	quotaMet: boolean,
	bonus: string,
	canister: string,
	hands: string,
	pockets: string,
	clockOut: string?,
}

export type ResultsView = {
	title: string,
	lines: { string },
	another: string,
	depot: string,
	countdown: string,
}

local EMPTY = "-"
local OUTCOME_TEXT: { [string]: string } = {
	clockout = "Clocked out",
	timeout = "Time's up",
	abandoned = "Everyone left",
}

local function nameOf(kind: PublicPlayerTypes.PublicValue?): string
	if type(kind) ~= "string" then
		return EMPTY
	end
	local def = CargoRegistry.get(kind)
	return if def ~= nil then def.name else kind
end

local ShiftHudViewModel = {}

-- "m:ss", seconds rounded up, never below 0:00.
function ShiftHudViewModel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

--[=[
	The HUD's lines while a shift runs; nil otherwise. `me` is the local player's public entry.
]=]
function ShiftHudViewModel.hud(snapshot: ShiftSnapshot?, me: PublicPlayerTypes.PublicPlayer?, now: number): HudView?
	if snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local pockets: { string } = {}
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		table.insert(pockets, nameOf(entry[field]))
	end
	local endsAt = snapshot.endsAt
	local clockOutAt = snapshot.clockOutAt
	return {
		timer = `Shift {snapshot.shift} | {ShiftHudViewModel.clock(if endsAt ~= nil then endsAt - now else 0)}`,
		clearance = `Clearance {snapshot.cleared} / {snapshot.quota}`,
		quotaMet = snapshot.quotaMet,
		bonus = `Bonus {snapshot.bonus}`,
		canister = `Canister {if type(fill) == "number" then fill else 0} / {VacuumConstants.CANISTER_CAPACITY}`,
		hands = `Hands: {nameOf(entry[CarryConstants.PUBLIC_FIELD])}`,
		pockets = `Pockets: {table.concat(pockets, " | ")}`,
		clockOut = if snapshot.sub == "clockout" and clockOutAt ~= nil
			then `CLOCKING OUT {ShiftHudViewModel.clock(clockOutAt - now)}`
			else nil,
	}
end

--[=[
	The results panel's lines while the crew votes; nil otherwise.
]=]
function ShiftHudViewModel.results(snapshot: ShiftSnapshot?, now: number): ResultsView?
	if snapshot == nil or snapshot.phase ~= "results" then
		return nil
	end
	local lines: { string } = {}
	local review = snapshot.results
	if review ~= nil then
		table.insert(lines, OUTCOME_TEXT[review.outcome] or review.outcome)
		table.insert(
			lines,
			`Cleared {review.cleared} / {review.quota} - {if review.quotaMet then "QUOTA MET" else "quota missed"}`
		)
		table.insert(lines, `Bonus {review.bonus}`)
		table.insert(lines, `Salvage found {review.salvage} | Piles vacuumed {review.piles}`)
		for _, member in review.crew do
			table.insert(lines, `{member.name}: banked {member.banked}, piles {member.piles}`)
		end
		for _, award in review.awards do
			table.insert(lines, `{award.title}: {award.name}`)
		end
	end
	local voteEndsAt = snapshot.voteEndsAt
	return {
		title = `Shift {snapshot.shift} performance review`,
		lines = lines,
		another = `Another shift ({snapshot.votesAnother})`,
		depot = `Back to depot ({snapshot.votesDepot})`,
		countdown = `Deciding in {ShiftHudViewModel.clock(if voteEndsAt ~= nil then voteEndsAt - now else 0)}`,
	}
end

return ShiftHudViewModel
```

- [ ] **Step 4: Store** `src/ReplicatedStorage/Client/Features/Shift/State/ShiftStore.luau`:

```lua
--!strict
--[=[
	ShiftStore: the shift as the local client sees it. `snapshot` is a Charm computed atom over the `shift`
	world entry, decoded by ShiftSnapshotUtils (nil before the first sync); `myVote` is the results choice the
	results panel writes and ShiftServiceClient sends. React reads both with useAtom; the client never writes
	the shift.

	@class ShiftStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftSnapshotUtils = require(ShiftShared.Utils.ShiftSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): ShiftTypes.ShiftSnapshot?
	return ShiftSnapshotUtils.decode(StateSyncClientStore.world()[ShiftConstants.WORLD_ENTRY])
end)

local initialVote: ShiftTypes.Vote? = nil
local myVote = Charm.atom(initialVote)

return {
	snapshot = snapshot,
	myVote = myVote,
}
```

- [ ] **Step 5: Server-clock hook** `src/ReplicatedStorage/Client/UI/React/Hooks/useServerClock.luau`:

```lua
--!strict
--[=[
	useServerClock: the server's clock (workspace:GetServerTimeNow()), refreshed every `interval` seconds
	(default 0.25), so a component counting down to a server deadline re-renders on its own.

	@class useServerClock
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local DEFAULT_INTERVAL = 0.25

local function useServerClock(interval: number?): number
	local initial: number = Workspace:GetServerTimeNow()
	local now, setNow = React.useState(initial)
	local period = interval or DEFAULT_INTERVAL
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(period)
				if alive then
					setNow(Workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { period })
	return now
end

return useServerClock
```

- [ ] **Step 6: HUD panel and widget.**

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudPanel.luau`:

```lua
--!strict
--[=[
	ShiftHudPanel: the M1 placeholder Shift HUD (spec §6.2: punch clock, clearance, bonus, canister, hands
	and pockets): a plain Panel of text lines, top left, with a large clock-out countdown when one runs.
	Presentational: it draws the HudView it is given.

	@class ShiftHudPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

local WIDTH = 280

export type ShiftHudPanelProps = {
	view: ShiftHudViewModel.HudView,
}

local function line(order: number, text: string, color: Color3, size: number): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Tokens.font.medium,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = text,
	})
end

local function ShiftHudPanel(props: ShiftHudPanelProps): React.ReactNode
	local view = props.view
	local body = Tokens.textSize.lg
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.xs),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		timer = line(1, view.timer, Tokens.color.text, Tokens.textSize.xl),
		clearance = line(2, view.clearance, if view.quotaMet then Tokens.color.success else Tokens.color.text, body),
		bonus = line(3, view.bonus, Tokens.color.warning, body),
		canister = line(4, view.canister, Tokens.color.text, body),
		hands = line(5, view.hands, Tokens.color.textMuted, body),
		pockets = line(6, view.pockets, Tokens.color.textMuted, body),
	}
	local clockOut = view.clockOut
	if clockOut ~= nil then
		children.clockOut = line(7, clockOut, Tokens.color.danger, Tokens.textSize.xxl)
	end
	return e("Frame", {
		Position = UDim2.fromOffset(Tokens.space.lg, Tokens.space.xxl * 2),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { width = WIDTH, children = children }),
	})
end

return ShiftHudPanel
```

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHud.luau`:

```lua
--!strict
--[=[
	ShiftHud: the Shift HUD widget (registered by ShiftServiceClient). Reads the shift snapshot, the local
	player's public entry and the server clock, and draws ShiftHudPanel while a shift runs.

	@class ShiftHud
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function ShiftHud(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local now = useServerClock()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local view = ShiftHudViewModel.hud(snapshot, me, now)
	if view == nil then
		return nil
	end
	return e(ShiftHudPanel, { view = view })
end

return ShiftHud
```

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftHudPanel.story.luau`:

```lua
--!strict
--[=[
	ShiftHudPanel.story: the placeholder Shift HUD with sample values, in Studio's edit mode (UI Labs).

	@class ShiftHudPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		SecondsLeft = 312,
		Cleared = 120,
		ClockingOut = false,
	},
}, function(props)
	local controls = props.controls
	local sub: ShiftTypes.ShiftSub = "normal"
	if controls.ClockingOut then
		sub = "clockout"
	end
	local snapshot: ShiftTypes.ShiftSnapshot = {
		phase = "running",
		sub = sub,
		shift = 1,
		endsAt = controls.SecondsLeft,
		clockOutAt = 7,
		quota = 350,
		cleared = controls.Cleared,
		bonus = 40,
		quotaMet = controls.Cleared >= 350,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	local view = ShiftHudViewModel.hud(snapshot, { canister = 2, carrying = "monitor", pocket1 = "plaque" }, 0)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		hud = if view ~= nil then e(ShiftHudPanel, { view = view }) else nil,
	})
end)
```

- [ ] **Step 7: Results panel and widget.**

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftResultsPanel.luau`:

```lua
--!strict
--[=[
	ShiftResultsPanel: the M1 placeholder performance review (spec §3 step 7): a centred Panel of plain lines
	and two vote buttons, the player's own choice highlighted. Presentational: it draws the ResultsView it is
	given and reports a click through `onVote`.

	@class ShiftResultsPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

local WIDTH = 440

export type ShiftResultsPanelProps = {
	view: ShiftHudViewModel.ResultsView,
	-- The local player's vote; a plain string because a singleton union widens across useAtom.
	myVote: string?,
	onVote: (choice: ShiftTypes.Vote) -> (),
}

local function text(order: number, value: string, color: Color3): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Tokens.font.body,
		TextSize = Tokens.textSize.lg,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = value,
	})
end

local function ShiftResultsPanel(props: ShiftResultsPanelProps): React.ReactNode
	local view = props.view
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.xs),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, value in view.lines do
		children[`line{index}`] = text(index, value, Tokens.color.text)
	end
	local after = #view.lines
	children.countdown = text(after + 1, view.countdown, Tokens.color.textMuted)
	children.buttons = e("Frame", {
		LayoutOrder = after + 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		another = e(Button, {
			text = view.another,
			selected = props.myVote == "another",
			layoutOrder = 1,
			onActivated = function()
				props.onVote("another")
			end,
		}),
		depot = e(Button, {
			text = view.depot,
			selected = props.myVote == "depot",
			layoutOrder = 2,
			onActivated = function()
				props.onVote("depot")
			end,
		}),
	})
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, { title = view.title, width = WIDTH, children = children }),
	})
end

return ShiftResultsPanel
```

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftResults.luau`:

```lua
--!strict
--[=[
	ShiftResults: the results widget (registered by ShiftServiceClient). While the crew votes it draws
	ShiftResultsPanel; a click writes ShiftStore.myVote, which ShiftServiceClient sends (components never
	talk to the server).

	@class ShiftResults
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftResultsPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResultsPanel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function ShiftResults(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local myVote = useAtom(ShiftStore.myVote)
	local now = useServerClock()
	local view = ShiftHudViewModel.results(snapshot, now)
	if view == nil then
		return nil
	end
	return e(ShiftResultsPanel, {
		view = view,
		myVote = myVote,
		onVote = function(choice)
			ShiftStore.myVote(choice)
		end,
	})
end

return ShiftResults
```

`src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftResultsPanel.story.luau`:

```lua
--!strict
--[=[
	ShiftResultsPanel.story: the placeholder performance review with a sample crew, in Studio's edit mode
	(UI Labs).

	@class ShiftResultsPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftResultsPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResultsPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		QuotaMet = true,
		VotedAnother = false,
	},
}, function(props)
	local controls = props.controls
	local review: ShiftTypes.ShiftResults = {
		outcome = "clockout",
		quota = 350,
		cleared = if controls.QuotaMet then 380 else 210,
		bonus = 95,
		salvage = 3,
		piles = 12,
		quotaMet = controls.QuotaMet,
		crew = {
			{ name = "Ava", banked = 200, piles = 6, salvage = 2 },
			{ name = "Ben", banked = 180, piles = 6, salvage = 1 },
		},
		awards = { { title = "Top Hauler", name = "Ava" }, { title = "Dust Devil", name = "Ava" } },
	}
	local snapshot: ShiftTypes.ShiftSnapshot = {
		phase = "results",
		sub = "normal",
		shift = 1,
		voteEndsAt = 24,
		quota = 350,
		cleared = review.cleared,
		bonus = review.bonus,
		quotaMet = review.quotaMet,
		variant = "B",
		votesAnother = if controls.VotedAnother then 1 else 0,
		votesDepot = 0,
		results = review,
	}
	local view = ShiftHudViewModel.results(snapshot, 0)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		results = if view ~= nil
			then e(ShiftResultsPanel, {
				view = view,
				myVote = if controls.VotedAnother then "another" else nil,
				onVote = function(choice)
					print("vote", choice)
				end,
			})
			else nil,
	})
end)
```

- [ ] **Step 8: Touch buttons** `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftMobileButtons.luau`:

```lua
--!strict
--[=[
	ShiftMobileButtons: touch controls while a shift runs (spec §4 "mobile: hold the Vacuum button"):
	a hold-to-vacuum button, then Pocket, Drop and Throw. Shown only on touch devices. The base Input feature
	has no touch bindings yet, so these call the Vacuum and Cargo client services directly (an open question
	for the base). Placeholder look (M3 replaces it).

	@class ShiftMobileButtons
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CargoServiceClient = require(ReplicatedStorage.Client.Features.Cargo.CargoServiceClient)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local VacuumServiceClient = require(ReplicatedStorage.Client.Features.Vacuum.VacuumServiceClient)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local BUTTON_WIDTH = 130
local VACUUM_HEIGHT = 60

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function ShiftMobileButtons(): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	if not UserInputService.TouchEnabled or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		-- Above the engine's jump button in the bottom-right corner.
		Position = UDim2.new(1, -Tokens.space.lg, 1, -Tokens.space.xxl * 5),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		vacuum = e("TextButton", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(BUTTON_WIDTH, VACUUM_HEIGHT),
			BackgroundColor3 = Tokens.color.accent,
			BorderSizePixel = 0,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.lg,
			TextColor3 = Tokens.color.onAccent,
			Text = "Hold: Vacuum",
			[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
				if isPress(input) then
					VacuumServiceClient:beginVacuum()
				end
			end,
			[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
				if isPress(input) then
					VacuumServiceClient:endVacuum()
				end
			end,
			[React.Event.MouseLeave] = function()
				VacuumServiceClient:endVacuum()
			end,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.md) }),
		}),
		pocket = e(Button, {
			text = "Pocket",
			width = BUTTON_WIDTH,
			layoutOrder = 2,
			onActivated = function()
				CargoServiceClient:pocket()
			end,
		}),
		drop = e(Button, {
			text = "Drop",
			width = BUTTON_WIDTH,
			layoutOrder = 3,
			onActivated = function()
				CargoServiceClient:drop()
			end,
		}),
		throw = e(Button, {
			text = "Throw",
			width = BUTTON_WIDTH,
			layoutOrder = 4,
			onActivated = function()
				CargoServiceClient:throw()
			end,
		}),
	})
end

return ShiftMobileButtons
```

- [ ] **Step 9: Client service** `src/ReplicatedStorage/Client/Features/Shift/ShiftServiceClient.luau`:

```lua
--!strict
--[=[
	ShiftServiceClient: the shift on the client. Registers the placeholder Shift widgets in the HUD during init
	(before the UI starts), and sends the local player's results vote whenever ShiftStore.myVote changes
	(clearing it when results end). Reads go through ShiftStore.

	Spec-exempt shell (Charm subscriptions, ByteNet); decoding is the specced ShiftSnapshotUtils.

	@class ShiftServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftShared = ReplicatedStorage.Shared.Features.Shift
local Charm = require(ReplicatedStorage.Packages.Charm)
local ShiftConstants = require(ShiftShared.Data.ShiftConstants)
local ShiftTypes = require(ShiftShared.Data.ShiftTypes)
local ShiftEvents = require(ShiftShared.Net.ShiftEvents)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ShiftHud = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud)
local ShiftMobileButtons = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons)
local ShiftResults = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResults)

local unsubscribers: { () -> () } = {}

export type ShiftServiceClient = {
	dependencies: { string },
	init: (self: ShiftServiceClient) -> (),
	start: (self: ShiftServiceClient) -> (),
	stop: (self: ShiftServiceClient) -> (),
	get: (self: ShiftServiceClient) -> ShiftTypes.ShiftSnapshot?,
	vote: (self: ShiftServiceClient, choice: ShiftTypes.Vote) -> (),
}

local ShiftServiceClient: ShiftServiceClient = {
	dependencies = { "StateSyncServiceClient", "VacuumServiceClient", "CargoServiceClient" },

	init = function(_self)
		if not HudRegistry.has("shiftHud") then
			HudRegistry.register("shiftHud", ShiftHud, ShiftConstants.HUD_ORDER)
		end
		if not HudRegistry.has("shiftResults") then
			HudRegistry.register("shiftResults", ShiftResults, ShiftConstants.HUD_ORDER + 1)
		end
		if not HudRegistry.has("shiftMobile") then
			HudRegistry.register("shiftMobile", ShiftMobileButtons, ShiftConstants.HUD_ORDER + 2)
		end
	end,

	start = function(_self)
		table.insert(
			unsubscribers,
			Charm.subscribe(ShiftStore.myVote, function(choice: ShiftTypes.Vote?)
				if choice ~= nil then
					ShiftEvents.packets.Vote.send(choice)
				end
			end)
		)
		table.insert(
			unsubscribers,
			Charm.subscribe(ShiftStore.snapshot, function(current: ShiftTypes.ShiftSnapshot?)
				local inResults = current ~= nil and current.phase == "results"
				if not inResults and ShiftStore.myVote() ~= nil then
					ShiftStore.myVote(nil)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, unsubscribe in unsubscribers do
			unsubscribe()
		end
		table.clear(unsubscribers)
	end,

	get = function(_self)
		return ShiftStore.snapshot()
	end,

	vote = function(_self, choice)
		ShiftStore.myVote(choice)
	end,
}

return ShiftServiceClient
```

- [ ] **Step 10: Exemptions.** Add (UI entries next to the existing `Screens.Hud` ones; the rest under `-- Cleanup Crew: Shift`):

```lua
	["ReplicatedStorage.Client.Features.Shift.State.ShiftStore"] = "Charm computed facade over the shift world entry (decoding is specced in ShiftSnapshotUtils)",
	["ReplicatedStorage.Client.Features.Shift.ShiftServiceClient"] = "HUD registration + Charm/ByteNet shell (the server decides)",
	["ReplicatedStorage.Client.UI.React.Hooks.useServerClock"] = "React hook — re-renders on the server clock (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel"] = "React UI component (placeholder; story in ShiftHudPanel.story; strings specced in ShiftHudViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHud"] = "React HUD widget wiring stores to ShiftHudPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResultsPanel"] = "React UI component (placeholder; story in ShiftResultsPanel.story; strings specced in ShiftHudViewModel)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResults"] = "React HUD widget wiring stores to ShiftResultsPanel (no logic)",
	["ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftMobileButtons"] = "React touch buttons calling client services (no logic)",
```

- [ ] **Step 11: Module map and gate**

```bash
python3 scripts/python/module_map.py --write
bash .superpowers/sdd/gate.sh
```
Expected: pass, including `check_pr_rules` (no `.packets.` in `Client/UI/React`, no `.Visible =` / `.Enabled =` in the UI tree).

- [ ] **Step 12: Controller: Studio TestEZ.** Expected: ShiftHudViewModel passes; full suite and `assertAllModulesSpecced` pass.

- [ ] **Step 13: Studio verification (controller).**
1. UI Labs (edit mode): `ShiftHudPanel` and `ShiftResultsPanel` stories render; toggling ClockingOut shows the red countdown line; toggling VotedAnother highlights "Another shift (1)".
2. Play Solo (`RunTests = false`): during the arrival countdown no Shift panel; when the shift runs, the top-left panel shows `Shift 1 | 7:00` counting down, `Clearance 0 / 350`, `Bonus 0`, `Canister 0 / 3`, `Hands: -`, `Pockets: - | -`. The toast stack (M0) shows the quota toast above it.
3. Pick up an item: `Hands: <name>`; pocket a plaque: `Pockets: Employee of the Month plaque | -`; vacuum a pile: `Canister 1 / 3`; Load: clearance / bonus update within a frame; reaching the quota turns the clearance line green.
4. Clock out: `CLOCKING OUT 0:10` counts down; then the HUD disappears and the centred "Shift 1 performance review" appears with the outcome, totals, your crew line, awards and `Deciding in 0:30`. Click "Another shift (0)": it highlights, the solo vote decides at once, the panel disappears and the next shift's HUD returns after the arrival countdown.
5. Client command bar check: `print(require(game.ReplicatedStorage.Client.Features.Shift.ShiftServiceClient):get().phase)` prints the current phase.
6. Touch: Studio → Test → Device emulator (a phone), Play: the Vacuum / Pocket / Drop / Throw column shows bottom-right during the shift only; holding Vacuum on a pile clears it, releasing keeps its progress; Pocket / Drop / Throw act on the hands item. Back on desktop emulation the column is gone.

- [ ] **Step 14: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(shift): placeholder HUD, results panel, vote and touch buttons"
```

---

### Task 12: Full-loop playtest, docs, PR

**Files:**
- Modify: `docs/ROADMAP.md` (a "Games on this base" note)
- Modify: `docs/project-structure.md` (Feature names: the game's features)

**Interfaces:** none new.

- [ ] **Step 1: ROADMAP note.** Append to `docs/ROADMAP.md`:

```markdown
## Games on this base

| Game | Branch | Built so far |
|---|---|---|
| Cleanup Crew (cleaning sim × co-op horror) | `game/cleanup-crew` | M1 graybox loop: code-built office with seeded spawns and guarantees (Office), vacuum and canister (Vacuum), 13 cargo kinds with handling traits, pockets, search and banking (Cargo), Round-driven shift with quota, clock out, results and vote (Shift). Spec: `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md`. |

Game features live only on their game branch; nothing in this table belongs in the base unless a second
game needs it unchanged (see the rule at the top).
```

- [ ] **Step 2: Feature names note.** In `docs/project-structure.md`, right after the sentence `A game adds its own (Pet, Shop, ...).`, add:

```markdown
Cleanup Crew (branch `game/cleanup-crew`) adds Cargo, Office, Shift and Vacuum.
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
git commit -m "docs: record Cleanup Crew M1 on the roadmap"
```

- [ ] **Step 5: Controller: full TestEZ run in Studio** (`RunTests = true`). Expected: every spec passes; `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 6: Controller: 2-player playtest** (Studio → Test → Clients: 2, `RunTests = false`). Checklist:
1. Both clients appear in the loading bay when the shift starts; both HUDs show the same timer and clearance.
2. Both vacuum the same pile: it clears in about half the time; only one canister fills; both get the pile stat (results crew lines).
3. Client 1 pockets two tiny items and holds a monitor; client 2 loads trash: client 1's HUD clearance updates too.
4. Client 1 leaves (close its window) while holding the monitor with two pocketed items: the monitor drops where they stood and the two items scatter around that spot; client 2 can pick all three up and load them. No errors in the server Output.
5. Client 2 clocks out: both see the countdown; at results both see the review; client 2 votes Back to depot (as the only player left, a majority): the "depot opens in a later build" toast, then another shift starts.
6. Rejoin a second client mid-shift: it joins the run (late join), spawns in the loading bay and sees the HUD.

- [ ] **Step 7: Controller: push and open the PR (never merge).**

```bash
git push -u origin game/cleanup-crew
gh pr create --base base/game-hooks --head game/cleanup-crew --title "Cleanup Crew M1: graybox loop (Office, Shift, Vacuum, Cargo)" --body "$(cat <<'EOF'
Milestone M1 of docs/superpowers/specs/2026-10-10-cleanup-crew-design.md: a Studio-playable graybox shift with no Harlow.

- Office: code-built office from authored room data at x = 1000 (layout validated by spec), seeded per-shift spawns with guarantees (trash >= 1.5x quota counting canister output, one deep greed target), one per-shift folder + one Janitor, reset.
- Vacuum: piles on the M0 Interaction channel (8 studs, 2.5 s, progress kept, rates add), canister of 3 popping 15-value dust bags, hold-to-vacuum on mouse / R2 / touch.
- Cargo: 13 cargo kinds with handling traits (weight, fragile tiers, spill, splash, bulky), 2 tiny-only pockets, desk/locker search, banking at the truck (claim -> add -> destroy, never double counted).
- Shift: configures Round (5 s arrival, 7:00 shift, late join), 350 clearance quota with a QUOTA MET toast, 10 s clock out, plain results and an Another-shift vote that resets in the same server.
- Placeholder UI only (final screens wait for Figma approval in M3). Noise is M2: Vacuum and Cargo fire `noiseMade` where noise happens.

Plan: docs/superpowers/plans/2026-10-10-m1-cleanup-crew-graybox.md (open questions for the developer listed there).

Verified: .superpowers/sdd/gate.sh green; TestEZ green in Studio; Studio checklists in Tasks 7-12.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Do not merge: the developer reviews. When `base/game-hooks` merges to main, rebase `game/cleanup-crew` onto main and retarget the PR (AGENTS.md: stacked branches).

---

## Next plans

- M2 (same branch): Noise (consumes `VacuumServiceServer.noiseMade` / `CargoServiceServer.noiseMade`, the rattle pulse, the jug puddle), Occupant (Harlow), pressure tiers, quota → break → overtime warning → overtime (`ShiftSub` grows; `OVERTIME_SALVAGE_MULTIPLIER`).
- Queue base PR before M4; M3 feel (Figma approval gate); M4 Depot; M5 phone pass, analytics, publish.
