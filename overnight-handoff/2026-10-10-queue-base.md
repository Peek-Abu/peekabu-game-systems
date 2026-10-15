# Queue (base feature) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a generic base feature, Queue, that gathers a party on a tagged pad and moves it together to another place of the same experience (a fresh reserved server), handles the arriving side (expected party, timeout, strangers), sends players back with a result payload, and runs the whole loop in one Studio server when the place is unknown.

**Architecture:** Every decision is a pure, specced module: pad config / aboard / countdown / depart rules (`QueuePadRules`), place-role resolution and routing (`QueuePlaceRules`), retry schedule / payload limits / ticket wire format (`QueueTeleportRules`), and three bookkeeping trackers (pads, teleports in flight, arrivals). Instance, TeleportService and Players work lives in spec-exempt Systems shells and the `QueueServiceServer` root, which also owns the Studio "local mode" (a teleport becomes a move to the destination role's arrival point, then `arrived` fires exactly as it would live). Pads replicate to clients as one StateSync world entry (`queue`); the client gets a plain placeholder HUD widget a game can switch off.

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax packets, Charm atoms + charm-sync world slice, React (react-lua) + ReactCharm + UI Labs, TestEZ (Studio, `RunTests = true`), Observers, SignalTyped, TeleportService (`ReserveServer`, `TeleportAsync` + `TeleportOptions`, `TeleportInitFailed`), `Player:GetJoinData()`, HttpService JSON.

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (§3 steps 1–3 and 7, §5 places and roles, §6.1 Queue row, §6.4 teleport data rule, §6.5 stranger joins / teleport fails / last player out). Format and base APIs follow `docs/superpowers/plans/2026-10-10-m0-base-game-hooks.md`.

**Branch:** `base/queue`, created from `base/game-hooks`. PR → `base/game-hooks` (the controller opens it; never merge).

## Global Constraints

- `--!strict` everywhere except `*.spec.luau`. No `any`, no `::` casts without a commented justification.
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields).
- Every new first-party module has a `<Name>.spec.luau` sibling or an `EXEMPT_MODULES` entry with a reason (`src/ServerScriptService/Core/Testing/SpecRoots.luau`).
- Module names `<Feature><What><RoleWord>` in the allowed subfolder; requires use full addresses; a folder used 3+ times gets a `<Feature><Realm>` variable.
- ≤ 400 code lines per module (`scripts/python/check_file_length.py`).
- After adding/moving modules: `python3 scripts/python/module_map.py --write`.
- Commits: plain messages, **no `Co-Authored-By:` / `Claude-Session:` trailers** (AGENTS.md).
- **Rojo safety:** while the developer is connected to `rojo serve`, run `bash scripts/check.sh --skip-install` only. Never run `rokit install`, `wally install`, `install.sh` or a full `check.sh` while they are connected; say so before running one.
- Server-authoritative: clients only send requests; the server re-validates everything.

Plan-specific, binding for every task:

- **Gate:** implementers run `bash .superpowers/sdd/gate.sh` (it must end with `==> All checks passed.`; the ruff line is advisory). Never `wally install`, `rokit install`, `install.sh`, `wally-package-types`, plain `check.sh` or `check.sh --skip-install`; never start `rojo serve` (Studio is live-synced from this worktree).
- **Tests run only in Roblox Studio, by the controller** (TestEZ, Workspace attribute `RunTests = true`, Play, read Output). Implementers write specs first, then code, and report "Studio TestEZ pending with the controller". Steps marked **(controller)** are skipped by implementers.
- **Studio verification code runs in the game VM:** the controller inserts a temporary server `Script` into **Workspace** (not Rojo-mounted, so the sync leaves it alone), presses Play (Solo: Studio has one player), reads Output for `[PASS]` / `[FAIL]` lines, stops, and deletes the Script. Never paste it into the plugin command VM: it would require different module instances than the running game.
- **Module map reads git-tracked files:** `git add` new modules first, then `python3 scripts/python/module_map.py --write`, then `git add docs/project-structure.md`, then the gate, then commit. After committing, `python3 scripts/python/module_map.py --check` must print no FAIL.
- **Generic base:** no game names in code. Roles are strings a game registers; "depot" / "shift" appear only as examples in prose.

## Review Focus

1. **A party member leaves the server, or walks off, mid-countdown or mid-teleport** → the countdown keeps running for the rest; a teleport in flight settles without them and nobody gets a false "couldn't leave" toast. (Task 2 Step 1 `QueuePadTracker` "forgets a player who left the server"; Task 3 Step 1 `QueueDepartureTracker` "finishes when every member has left the server")
2. **A teleport partly fails (TeleportInitFailed for one player)** → only that player is retried, into the same reserved server (the access code is kept), and only they are toasted after the last retry. (Task 3 Step 1 `QueueDepartureTracker` "counts failures per player" / "reports the players it gave up on"; Task 4 Step 4 `QueueTeleportSystem` keeps `accessCode`)
3. **Forged or broken teleport data** (it travels through the client) → decodes as nothing; the player is handled as a stranger; the server never errors. (Task 3 Step 1 `QueueTeleportRules` "rejects a forged or broken ticket")
4. **A stranger follows a friend into a reserved server while the party is still arriving** → never takes a seat an expected member needs; redirected home when there is no room, kicked only if no home role can be reached. (Task 3 Step 1 `QueueArrivalTracker` "keeps seats for expected players still on their way")
5. **A misconfigured pad** (no destination, capacity 0 / 7.5 / "4", an unregistered role) → warned and ignored at tag time, or for an unregistered role: departing fails into a toast + `departFailed` and the pad reopens. (Task 2 Step 1 `QueuePadRules` "config"; Task 4 Step 8 checklist items 4–5)

---

## New modules

New feature name: **Queue** (singular, PascalCase; proposed in the spec §11). No new subfolder kind, no new role word and no second service: three `Systems` modules in one feature is allowed.

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Queue | shared | Data | QueueTypes | Pad, ticket, payload, snapshot, route and config types |
| Queue | shared | Data | QueueConstants | Tag + attribute names, defaults, limits, retry delays, timeouts, world entry, toast texts |
| Queue | shared | Net | QueueEvents | Depart-now packet (client → server) |
| Queue | shared | Utils | QueueSnapshotUtils | Decodes the `queue` world entry; finds the pad a player is aboard |
| Queue | server | Data | QueueRegistry | The place-role table: role name → PlaceId (placeholder 0 until the place exists) |
| Queue | server | Rules | QueuePadRules | Pad config check, aboard test, party admission, countdown deadline, depart permission |
| Queue | server | Rules | QueuePlaceRules | Live vs local mode, this server's role, routing to a role, reserved-server test |
| Queue | server | Rules | QueueTeleportRules | Retry/backoff schedule, payload limits, ticket encode/decode |
| Queue | server | State | QueuePadTracker | Members, countdown and departing state per pad (pure bookkeeping) |
| Queue | server | State | QueueDepartureTracker | Teleports in flight per player: failures, give-ups, completion, watchdog |
| Queue | server | State | QueueArrivalTracker | Arrival server's expected party, crew, admissions and when the wait is over |
| Queue | server | Systems | QueuePadSystem | Observes tagged pads, samples characters each tick, hands due parties on |
| Queue | server | Systems | QueueTeleportSystem | ReserveServer + TeleportAsync with retries; TeleportInitFailed; watchdog |
| Queue | server | Systems | QueueArrivalSystem | Reads arrivals on a reserved server, admits/redirects, fires the party when ready |
| Queue | server | (root) | QueueServiceServer | Public API, signals, local-mode moves, return trip, world entry |
| Queue | client | State | QueueStore | Decoded snapshot atom + the default-widget switch |
| Queue | client | (root) | QueueServiceClient | Sends Depart now; registers the placeholder HUD widget |
| UI tree | client | Screens/Hud | QueuePadPanel (+ `.story`) | Presentational placeholder panel: aboard count, countdown, Depart-now button |
| UI tree | client | Screens/Hud | QueuePadStatus | HUD widget: shows QueuePadPanel while the local player is aboard |

Modified: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (exemptions), `docs/project-structure.md` (feature list + module map), `docs/ROADMAP.md`.

**Client UI decision:** the base ships a *plain placeholder* widget through HudRegistry (key `queuePad`), not "state only". Reason: the spec requires the whole loop to play through `rojo serve`, and Depart now needs a button to be playable; the final pad UI is gated on Figma approval (M3), so a game hides this widget with `QueueServiceClient:setDefaultWidget(false)` and draws its own from `QueueStore`. React components never touch packets (check_pr_rules "components render"): the service passes `onDepart` in.

**Teleport API notes (verified against `globalTypes.d.luau` lines 17271–17302 and 15140):** `TeleportService:ReserveServer(placeId): (string, string)` (access code, private server id), `TeleportService:TeleportAsync(placeId, players, options?): TeleportAsyncResult`, `TeleportOptions.ReservedServerAccessCode`, `TeleportOptions:SetTeleportData(data)`, `TeleportService.TeleportInitFailed: (Player, EnumTeleportResult, string, number, TeleportOptions)`, `Player:GetJoinData(): { TeleportData: TeleportData?, Members: {number}?, SourcePlaceId: number?, ... }`, `game.PrivateServerId: string`, `game.PrivateServerOwnerId: number`. **ReserveServer and TeleportAsync error in Studio**, which is why Studio routes as a local move. If selene flags `ReserveServer` as deprecated, do not switch to `ReserveServerAsync` (typed `...any`); instead set `options.ShouldReserveServer = true` on the first `TeleportAsync` and keep `result.ReservedServerAccessCode` for retries. Teleport data travels as a JSON **string** (`HttpService:JSONEncode`), which keeps every Luau type narrow (`TeleportData` is a recursive union that cannot be indexed without casts); the arrival server `JSONDecode`s it under `pcall` and the specced decoder validates every field.

---

### Task 0: Branch, plan copy, baseline

**Files:** Create: `docs/superpowers/plans/2026-10-10-queue-base.md` (a copy of this plan).

- [ ] **Step 1: Branch from the base hooks branch**

```bash
git switch base/game-hooks
git switch -c base/queue
```

- [ ] **Step 2: Copy this plan into the repo** (from the controller's scratchpad path it was handed) to `docs/superpowers/plans/2026-10-10-queue-base.md`.

- [ ] **Step 3: Baseline gate**

```bash
bash .superpowers/sdd/gate.sh
```
Expected: ends with `==> All checks passed.` If anything fails here, stop and report: it is not ours.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-10-10-queue-base.md
git commit -m "docs: plan the base Queue feature"
```

---

### Task 1: Queue data, place-role table and place rules

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Queue/Data/QueueTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Queue/Data/QueueConstants.luau`
- Create: `src/ServerScriptService/Features/Queue/Data/QueueRegistry.luau` + `QueueRegistry.spec.luau`
- Create: `src/ServerScriptService/Features/Queue/Rules/QueuePlaceRules.luau` + `QueuePlaceRules.spec.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (two exemptions)

**Interfaces:**
- Produces (QueueTypes): `PadConfig = { capacity: number, countdown: number, destination: string }`, `PadStatus = "open" | "departing"`, `QueuePayload = { [string]: string | number | boolean }`, `TicketKind = "depart" | "return"`, `QueueTicket = { kind, from: string?, role: string, party: { number }, capacity: number, payload: QueuePayload }`, `PadSnapshot = { members: { number }, capacity: number, destination: string, endsAt: number?, departing: boolean }`, `QueueSnapshot = { pads: { [string]: PadSnapshot } }`, `Mode = "live" | "local"`, `Route = { kind: "local" } | { kind: "teleport", placeId: number }`, `Admission = "crew" | "late" | "redirect"`, `QueueConfig = { homeRole: string?, forceLive: boolean }`, `QueueConfigUpdate`, `DepartDataResolver = (pad: BasePart, party: { Player }) -> QueuePayload`, `ArrivalPoint = (player: Player, index: number) -> CFrame?`
- Produces (QueueConstants): the frozen table below (names used by every later task).
- Produces (QueueRegistry): `register(role: string, placeId: number)`, `has(role) -> boolean`, `placeOf(role) -> number?`, `roles() -> { [string]: number }` (frozen copy).
- Produces (QueuePlaceRules): `roleOf(placeId, roles) -> string?`, `mode(placeId, isStudio, forceLive, roles) -> Mode`, `route(mode, destination, roles) -> (Route?, string?)`, `runsRole(mode, currentRole: string?, role) -> boolean`, `isReservedServer(privateServerId: string, privateServerOwnerId: number) -> boolean`.

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Queue/Data/QueueRegistry.spec.luau`:

```lua
local QueueRegistry = require(script.Parent.QueueRegistry)

-- The registry is module state shared by the whole test session: register each role once.
local function ensure(role, placeId)
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

return function()
	it("registers a role and returns its place", function()
		ensure("spec-home", 910000001)
		expect(QueueRegistry.placeOf("spec-home")).to.equal(910000001)
		expect(QueueRegistry.roles()["spec-home"]).to.equal(910000001)
	end)

	it("rejects a duplicate role", function()
		ensure("spec-dup", 910000002)
		expect(function()
			QueueRegistry.register("spec-dup", 910000003)
		end).to.throw()
	end)

	it("rejects an empty role, a negative or a fractional PlaceId", function()
		expect(function()
			QueueRegistry.register("", 910000004)
		end).to.throw()
		expect(function()
			QueueRegistry.register("spec-negative", -1)
		end).to.throw()
		expect(function()
			QueueRegistry.register("spec-fraction", 1.5)
		end).to.throw()
		expect(QueueRegistry.has("spec-negative")).to.equal(false)
		expect(QueueRegistry.has("spec-fraction")).to.equal(false)
	end)

	it("refuses two roles on one real place but allows several placeholders", function()
		ensure("spec-place-a", 910000005)
		expect(function()
			QueueRegistry.register("spec-place-b", 910000005)
		end).to.throw()
		ensure("spec-later-a", 0)
		ensure("spec-later-b", 0)
		expect(QueueRegistry.placeOf("spec-later-b")).to.equal(0)
	end)

	it("knows nothing about an unregistered role", function()
		expect(QueueRegistry.has("spec-never")).to.equal(false)
		expect(QueueRegistry.placeOf("spec-never")).to.equal(nil)
	end)

	it("hands out a frozen copy", function()
		expect(table.isfrozen(QueueRegistry.roles())).to.equal(true)
	end)
end
```

`src/ServerScriptService/Features/Queue/Rules/QueuePlaceRules.spec.luau`:

```lua
local QueuePlaceRules = require(script.Parent.QueuePlaceRules)

local ROLES = { home = 111, away = 222, later = 0 }

return function()
	describe("roleOf", function()
		it("finds the role a place plays", function()
			expect(QueuePlaceRules.roleOf(222, ROLES)).to.equal("away")
		end)

		it("knows no role for an unknown or unpublished place", function()
			expect(QueuePlaceRules.roleOf(999, ROLES)).to.equal(nil)
			expect(QueuePlaceRules.roleOf(0, ROLES)).to.equal(nil)
		end)
	end)

	describe("mode", function()
		it("is live on a registered place outside Studio", function()
			expect(QueuePlaceRules.mode(111, false, false, ROLES)).to.equal("live")
		end)

		it("is local in Studio, even on a registered place", function()
			expect(QueuePlaceRules.mode(111, true, false, ROLES)).to.equal("local")
		end)

		it("is local on an unknown or unpublished place", function()
			expect(QueuePlaceRules.mode(999, false, false, ROLES)).to.equal("local")
			expect(QueuePlaceRules.mode(0, false, false, ROLES)).to.equal("local")
		end)

		it("is live when forced, even in Studio", function()
			expect(QueuePlaceRules.mode(0, true, true, ROLES)).to.equal("live")
		end)
	end)

	describe("route", function()
		it("teleports a live server to the destination's place", function()
			local route = QueuePlaceRules.route("live", "away", ROLES)
			expect(route.kind).to.equal("teleport")
			expect(route.placeId).to.equal(222)
		end)

		it("moves locally in local mode", function()
			expect(QueuePlaceRules.route("local", "away", ROLES).kind).to.equal("local")
		end)

		it("moves locally to a placeholder destination, even from a live server", function()
			expect(QueuePlaceRules.route("live", "later", ROLES).kind).to.equal("local")
		end)

		it("refuses an unregistered role and says why", function()
			local route, reason = QueuePlaceRules.route("live", "nowhere", ROLES)
			expect(route).to.equal(nil)
			expect(string.find(reason, "not registered") ~= nil).to.equal(true)
		end)
	end)

	describe("runsRole", function()
		it("runs every role in local mode", function()
			expect(QueuePlaceRules.runsRole("local", nil, "away")).to.equal(true)
		end)

		it("runs only its own role when live", function()
			expect(QueuePlaceRules.runsRole("live", "home", "home")).to.equal(true)
			expect(QueuePlaceRules.runsRole("live", "home", "away")).to.equal(false)
		end)
	end)

	describe("isReservedServer", function()
		it("is a reserved server with a private id and no owner", function()
			expect(QueuePlaceRules.isReservedServer("abc", 0)).to.equal(true)
		end)

		it("is not a public server or an owned private server", function()
			expect(QueuePlaceRules.isReservedServer("", 0)).to.equal(false)
			expect(QueuePlaceRules.isReservedServer("abc", 42)).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Run to verify failure (controller).** Studio, `RunTests = true`, Play. Expected: both specs error with "module not found" (`QueueRegistry` / `QueuePlaceRules` missing).

- [ ] **Step 3: Shared data.**

`src/ReplicatedStorage/Shared/Features/Queue/Data/QueueTypes.luau`:

```lua
--!strict
--[=[
	QueueTypes: the Queue feature's shapes. Types only (spec-exempt).

	@class QueueTypes
]=]

-- A pad's settings, read once from its attributes when it is tagged (QueuePadRules.config).
export type PadConfig = {
	capacity: number,
	countdown: number,
	destination: string,
}

export type PadStatus = "open" | "departing"

-- Game data riding a teleport: a contract id on the way out, a result card on the way back. Flat and
-- capped (QueueConstants.MAX_PAYLOAD_*). Never security data: teleport data travels through the client.
export type QueuePayload = { [string]: string | number | boolean }

export type TicketKind = "depart" | "return"

-- What a teleport carries (JSON teleport data). `party` lists the user ids the arrival server expects;
-- the reserved server's access code, not this list, is what keeps strangers out.
export type QueueTicket = {
	kind: TicketKind,
	from: string?,
	role: string,
	party: { number },
	capacity: number,
	payload: QueuePayload,
}

-- One pad as every client sees it (the `queue` world entry). `endsAt` is server time
-- (workspace:GetServerTimeNow()); absent while nobody is aboard and while departing.
export type PadSnapshot = {
	members: { number },
	capacity: number,
	destination: string,
	endsAt: number?,
	departing: boolean,
}

export type QueueSnapshot = {
	pads: { [string]: PadSnapshot },
}

-- "live": this server is a registered place and teleports for real. "local": Studio or an unknown place;
-- every role runs in this one server and a teleport becomes a move.
export type Mode = "live" | "local"

export type Route = { kind: "local" } | { kind: "teleport", placeId: number }

-- What happens to a player joining an arrival server.
export type Admission = "crew" | "late" | "redirect"

export type QueueConfig = {
	-- Where a stranger is sent from a full arrival server (default: the party's source role).
	homeRole: string?,
	-- Studio verification only: route as a live server so the teleport path and its failure handling
	-- run (every teleport fails in Studio).
	forceLive: boolean,
}

export type QueueConfigUpdate = {
	homeRole: string?,
	forceLive: boolean?,
}

-- Builds the payload for a departing party (a contract id). An error or a payload over the limits
-- sends `{}` instead.
export type DepartDataResolver = (pad: BasePart, party: { Player }) -> QueuePayload

-- Where a player lands when a local move takes them to a role. `index` is their place in the party
-- (1-based), so a game can spread them out.
export type ArrivalPoint = (player: Player, index: number) -> CFrame?

return {}
```

`src/ReplicatedStorage/Shared/Features/Queue/Data/QueueConstants.luau`:

```lua
--!strict
--[=[
	QueueConstants: names, defaults and limits for queue pads, teleports and arrivals. Static data
	(spec-exempt). Every number is a tuning value.

	@class QueueConstants
]=]

return table.freeze({
	-- CollectionService tag on a pad: a BasePart whose top players stand on.
	TAG = "QueuePad",
	-- Pad attributes, read once when the pad is tagged (set them before tagging).
	CAPACITY_ATTRIBUTE = "QueueCapacity",
	COUNTDOWN_ATTRIBUTE = "QueueCountdown",
	DESTINATION_ATTRIBUTE = "QueueDestination",
	DEFAULT_CAPACITY = 4,
	-- TeleportAsync moves at most 50 players at once.
	MAX_CAPACITY = 50,
	DEFAULT_COUNTDOWN = 15,
	MAX_COUNTDOWN = 300,
	-- Studs above the pad's top surface a HumanoidRootPart still counts as aboard.
	ABOARD_HEIGHT = 8,
	-- How often pads are sampled and timers checked (seconds).
	TICK_INTERVAL = 0.25,
	-- Seconds before retry 1, 2 and 3. After the third retry fails the party is back on its pad.
	RETRY_DELAYS = table.freeze({ 1, 2, 4 }),
	-- Seconds a player may still be here after their teleport started before it counts as failed.
	TELEPORT_WATCHDOG = 15,
	-- Seconds an arrival server waits for the expected party before starting with whoever arrived.
	ARRIVAL_TIMEOUT = 20,
	-- A role's PlaceId before its place exists; reached by a local move.
	PLACEHOLDER_PLACE_ID = 0,
	TICKET_VERSION = 1,
	MAX_PAYLOAD_KEYS = 32,
	MAX_PAYLOAD_KEY_LENGTH = 64,
	MAX_PAYLOAD_STRING = 1000,
	-- The StateSyncWorldStore entry the pads are published under.
	WORLD_ENTRY = "queue",
	DEPART_FAILED_TEXT = "Couldn't leave. You're back on the pad.",
	RETURN_FAILED_TEXT = "Couldn't travel. Try again in a moment.",
	REDIRECT_KICK_TEXT = "This server is full. Please rejoin.",
})
```

- [ ] **Step 4: The place-role table** `src/ServerScriptService/Features/Queue/Data/QueueRegistry.luau`:

```lua
--!strict
--[=[
	QueueRegistry: the place-role table. Which PlaceId plays which role (a game's "depot" and "shift",
	any strings). A game registers its roles at load, from server code; the base registers none.

	A role whose place does not exist yet registers QueueConstants.PLACEHOLDER_PLACE_ID (0): it is
	reached by a local move until the real PlaceId is filled in. Example, in a game's server Data:

		QueueRegistry.register("depot", 1234567890)
		QueueRegistry.register("shift", QueueConstants.PLACEHOLDER_PLACE_ID) -- PLACEHOLDER: create the place, then fill in its PlaceId

	@class QueueRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)

local places: { [string]: number } = {}

local QueueRegistry = {}

--[=[
	Registers `role` as played by `placeId`. Errors on an empty or duplicate role, a PlaceId that is not a
	whole number >= 0, or a real PlaceId already playing another role.
]=]
function QueueRegistry.register(role: string, placeId: number)
	assert(role ~= "", "queue role must not be empty")
	assert(places[role] == nil, `queue role "{role}" is already registered`)
	assert(
		placeId >= 0 and placeId == math.floor(placeId),
		`queue role "{role}": PlaceId must be a whole number >= 0, got {placeId}`
	)
	if placeId ~= QueueConstants.PLACEHOLDER_PLACE_ID then
		for other, id in places do
			assert(id ~= placeId, `PlaceId {placeId} already plays role "{other}"`)
		end
	end
	places[role] = placeId
end

function QueueRegistry.has(role: string): boolean
	return places[role] ~= nil
end

function QueueRegistry.placeOf(role: string): number?
	return places[role]
end

-- A frozen copy of the whole table, for the pure QueuePlaceRules.
function QueueRegistry.roles(): { [string]: number }
	return table.freeze(table.clone(places))
end

return QueueRegistry
```

- [ ] **Step 5: The place rules** `src/ServerScriptService/Features/Queue/Rules/QueuePlaceRules.luau`:

```lua
--!strict
--[=[
	QueuePlaceRules: which mode this server runs in, which role it plays, and how a party reaches a role.
	Pure: the role table comes in as an argument (QueueRegistry.roles()).

	Studio, or a PlaceId the table does not know, is "local": every role runs in this one server and a
	teleport becomes a move, so the whole loop plays through rojo serve. A destination whose PlaceId is
	still the placeholder is reached by a local move even from a live server.

	@class QueuePlaceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type Roles = { [string]: number }

local QueuePlaceRules = {}

-- The role `placeId` plays, or nil (unknown, or an unpublished place's 0).
function QueuePlaceRules.roleOf(placeId: number, roles: Roles): string?
	if placeId == QueueConstants.PLACEHOLDER_PLACE_ID then
		return nil
	end
	for role, id in roles do
		if id == placeId then
			return role
		end
	end
	return nil
end

function QueuePlaceRules.mode(placeId: number, isStudio: boolean, forceLive: boolean, roles: Roles): QueueTypes.Mode
	if forceLive then
		return "live"
	end
	if isStudio or QueuePlaceRules.roleOf(placeId, roles) == nil then
		return "local"
	end
	return "live"
end

-- How a party reaches `destination`, or nil and why.
function QueuePlaceRules.route(
	mode: QueueTypes.Mode,
	destination: string,
	roles: Roles
): (QueueTypes.Route?, string?)
	local placeId = roles[destination]
	if placeId == nil then
		return nil, `role "{destination}" is not registered`
	end
	if mode == "local" or placeId == QueueConstants.PLACEHOLDER_PLACE_ID then
		return { kind = "local" }, nil
	end
	return { kind = "teleport", placeId = placeId }, nil
end

-- Whether this server runs `role` (a game builds that role's world only where this is true).
function QueuePlaceRules.runsRole(mode: QueueTypes.Mode, currentRole: string?, role: string): boolean
	return mode == "local" or currentRole == role
end

-- A server reached through ReserveServer: a private server id and no owner (a VIP server has one).
function QueuePlaceRules.isReservedServer(privateServerId: string, privateServerOwnerId: number): boolean
	return privateServerId ~= "" and privateServerOwnerId == 0
end

return QueuePlaceRules
```

- [ ] **Step 6: Exemptions.** In `src/ServerScriptService/Core/Testing/SpecRoots.luau`, add after the Toast entries (after the `ToastStack` line):

```lua
	["ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants"] = "static names, defaults and limits (no logic)",
```

- [ ] **Step 7: Run the specs (controller).** Studio `RunTests = true`, Play. Expected: `QueueRegistry` and `QueuePlaceRules` specs pass; `assertAllModulesSpecced` passes.

- [ ] **Step 8: Module map, gate, commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Queue src/ServerScriptService/Features/Queue src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
bash .superpowers/sdd/gate.sh
git commit -m "feat(queue): place-role table and place rules"
python3 scripts/python/module_map.py --check
```
Note: `Queue` is added to the **Feature names** list in Task 4 Step 7; the layout check does not need it.

---

### Task 2: Pad rules, pad tracker and the client snapshot decoder

**Files:**
- Create: `src/ServerScriptService/Features/Queue/Rules/QueuePadRules.luau` + `QueuePadRules.spec.luau`
- Create: `src/ServerScriptService/Features/Queue/State/QueuePadTracker.luau` + `QueuePadTracker.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Queue/Utils/QueueSnapshotUtils.luau` + `QueueSnapshotUtils.spec.luau`

**Interfaces:**
- Consumes: `QueueTypes.PadConfig`, `PadStatus`, `PadSnapshot`, `QueueSnapshot`; `QueueConstants` (Task 1); `WorldTypes.WorldValue` / `WorldTable` (`src/ReplicatedStorage/Shared/Data/WorldTypes.luau`).
- Produces (QueuePadRules): `config(capacity: unknown, countdown: unknown, destination: unknown) -> (PadConfig?, string?)`, `isAboard(padCFrame: CFrame, padSize: Vector3, point: Vector3, height: number) -> boolean`, `admit(existing: { number }, aboard: { number }, capacity: number) -> { number }`, `deadline(previous: { number }, current: { number }, deadline: number?, now: number, countdown: number) -> number?`, `canDepart(members: { number }, status: PadStatus, userId: number) -> boolean`
- Produces (QueuePadTracker): `QueuePadTracker.new() -> QueuePadTracker` with `add(padId, config)`, `remove(padId) -> { number }`, `has(padId) -> boolean`, `config(padId) -> PadConfig?`, `sync(padId, aboard: { number }, now) -> boolean` (changed), `members(padId) -> { number }`, `padOf(userId) -> string?`, `departNow(userId, now) -> string?`, `due(now) -> { string }`, `lock(padId) -> { number }`, `unlock(padId)`, `forget(userId) -> boolean`, `snapshot() -> WorldTypes.WorldTable`
- Produces (QueueSnapshotUtils): `decode(value: WorldValue?) -> QueueSnapshot?`, `padOf(snapshot: QueueSnapshot?, userId: number) -> (string?, PadSnapshot?)`

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Queue/Rules/QueuePadRules.spec.luau`:

```lua
local QueuePadRules = require(script.Parent.QueuePadRules)

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
	describe("config", function()
		it("reads a complete pad", function()
			local config = QueuePadRules.config(2, 10, "away")
			expect(config.capacity).to.equal(2)
			expect(config.countdown).to.equal(10)
			expect(config.destination).to.equal("away")
		end)

		it("defaults the capacity and countdown", function()
			local config = QueuePadRules.config(nil, nil, "away")
			expect(config.capacity).to.equal(4)
			expect(config.countdown).to.equal(15)
		end)

		it("clamps the countdown", function()
			expect(QueuePadRules.config(nil, -5, "away").countdown).to.equal(0)
			expect(QueuePadRules.config(nil, 9999, "away").countdown).to.equal(300)
		end)

		it("refuses a bad capacity and says why", function()
			for _, bad in { 0, 51, 2.5, "4", 0 / 0 } do
				local config, reason = QueuePadRules.config(bad, nil, "away")
				expect(config).to.equal(nil)
				expect(reason).never.to.equal(nil)
			end
		end)

		it("refuses a countdown that is not a number", function()
			expect(QueuePadRules.config(4, "soon", "away")).to.equal(nil)
			expect(QueuePadRules.config(4, 0 / 0, "away")).to.equal(nil)
		end)

		it("refuses a pad with no destination", function()
			expect(QueuePadRules.config(4, 15, nil)).to.equal(nil)
			expect(QueuePadRules.config(4, 15, "")).to.equal(nil)
			expect(QueuePadRules.config(4, 15, 7)).to.equal(nil)
		end)
	end)

	describe("isAboard", function()
		local PAD = CFrame.new(0, 0.5, 0)
		local SIZE = Vector3.new(10, 1, 10)

		it("counts a player standing on the pad", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(4, 3, -4), 8)).to.equal(true)
		end)

		it("does not count a player beside it", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(5.5, 3, 0), 8)).to.equal(false)
		end)

		it("does not count a player far above or below it", function()
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(0, 20, 0), 8)).to.equal(false)
			expect(QueuePadRules.isAboard(PAD, SIZE, Vector3.new(0, -3, 0), 8)).to.equal(false)
		end)

		it("follows the pad's rotation", function()
			local turned = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0)
			local narrow = Vector3.new(2, 1, 20)
			-- 6 studs along the pad's long axis is on it; 6 studs along world X is off it.
			local alongPad = turned:PointToWorldSpace(Vector3.new(0, 3, 6))
			expect(QueuePadRules.isAboard(turned, narrow, alongPad, 8)).to.equal(true)
			expect(QueuePadRules.isAboard(turned, narrow, Vector3.new(6, 3, 0), 8)).to.equal(false)
		end)
	end)

	describe("admit", function()
		it("keeps members in join order and adds newcomers after them", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1, 2, 3 }, 4), { 3, 1, 2 })).to.equal(true)
		end)

		it("drops members who stepped off", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1 }, 4), { 1 })).to.equal(true)
		end)

		it("never goes over capacity; the earliest keep their seats", function()
			expect(same(QueuePadRules.admit({ 3, 1 }, { 1, 2, 3, 4 }, 3), { 3, 1, 2 })).to.equal(true)
		end)
	end)

	describe("deadline", function()
		it("starts the countdown when the first player boards", function()
			expect(QueuePadRules.deadline({}, { 1 }, nil, 100, 15)).to.equal(115)
		end)

		it("resets the countdown when someone joins", function()
			expect(QueuePadRules.deadline({ 1 }, { 1, 2 }, 110, 105, 15)).to.equal(120)
		end)

		it("keeps the countdown when someone leaves", function()
			expect(QueuePadRules.deadline({ 1, 2 }, { 1 }, 110, 105, 15)).to.equal(110)
		end)

		it("stops the countdown when the pad empties", function()
			expect(QueuePadRules.deadline({ 1 }, {}, 110, 105, 15)).to.equal(nil)
		end)
	end)

	describe("canDepart", function()
		it("lets anyone aboard depart an open pad", function()
			expect(QueuePadRules.canDepart({ 1, 2 }, "open", 2)).to.equal(true)
		end)

		it("refuses a player who is not aboard", function()
			expect(QueuePadRules.canDepart({ 1 }, "open", 3)).to.equal(false)
		end)

		it("refuses while the pad is already departing", function()
			expect(QueuePadRules.canDepart({ 1 }, "departing", 1)).to.equal(false)
		end)
	end)
end
```

`src/ServerScriptService/Features/Queue/State/QueuePadTracker.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueuePadTracker = require(script.Parent.QueuePadTracker)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)

local CONFIG = { capacity = 2, countdown = 15, destination = "away" }

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
	local tracker

	beforeEach(function()
		tracker = QueuePadTracker.new()
		tracker:add("pad1", CONFIG)
		tracker:add("pad2", CONFIG)
	end)

	it("refuses to track one pad twice", function()
		expect(function()
			tracker:add("pad1", CONFIG)
		end).to.throw()
	end)

	it("boards players and starts the countdown", function()
		expect(tracker:sync("pad1", { 7 }, 100)).to.equal(true)
		expect(same(tracker:members("pad1"), { 7 })).to.equal(true)
		expect(tracker:padOf(7)).to.equal("pad1")
		expect(#tracker:due(114)).to.equal(0)
		expect(tracker:due(115)[1]).to.equal("pad1")
	end)

	it("reports no change when nothing moved", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(tracker:sync("pad1", { 7 }, 101)).to.equal(false)
	end)

	it("resets the countdown when someone joins and keeps it when someone leaves", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad1", { 7, 8 }, 105) -- ends at 120
		tracker:sync("pad1", { 8 }, 110) -- still 120
		expect(#tracker:due(119)).to.equal(0)
		expect(tracker:due(120)[1]).to.equal("pad1")
	end)

	it("stops the countdown when the pad empties", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad1", {}, 101)
		expect(#tracker:due(1000)).to.equal(0)
		expect(tracker:padOf(7)).to.equal(nil)
	end)

	it("fills to capacity in join order", function()
		tracker:sync("pad1", { 7, 8, 9 }, 100)
		expect(same(tracker:members("pad1"), { 7, 8 })).to.equal(true)
		expect(tracker:padOf(9)).to.equal(nil)
	end)

	it("keeps a player on the first pad that claimed them", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad2", { 7, 8 }, 100)
		expect(same(tracker:members("pad2"), { 8 })).to.equal(true)
		expect(tracker:padOf(7)).to.equal("pad1")
	end)

	it("lets a member depart now, but nobody else", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(tracker:departNow(9, 101)).to.equal(nil)
		expect(tracker:departNow(7, 101)).to.equal("pad1")
		expect(tracker:due(101)[1]).to.equal("pad1")
	end)

	it("freezes a departing party and reopens the pad empty", function()
		tracker:sync("pad1", { 7, 8 }, 100)
		expect(same(tracker:lock("pad1"), { 7, 8 })).to.equal(true)
		expect(tracker:sync("pad1", { 9 }, 101)).to.equal(false)
		expect(tracker:departNow(7, 101)).to.equal(nil)
		expect(#tracker:due(1000)).to.equal(0)
		tracker:unlock("pad1")
		expect(#tracker:members("pad1")).to.equal(0)
		tracker:sync("pad1", { 7 }, 200)
		expect(tracker:due(215)[1]).to.equal("pad1")
	end)

	it("forgets a player who left the server", function()
		tracker:sync("pad1", { 7, 8 }, 100)
		expect(tracker:forget(7)).to.equal(true)
		expect(same(tracker:members("pad1"), { 8 })).to.equal(true)
		expect(tracker:forget(7)).to.equal(false)
		expect(tracker:due(115)[1]).to.equal("pad1") -- the rest keep their countdown
		tracker:forget(8)
		expect(#tracker:due(1000)).to.equal(0)
	end)

	it("publishes a snapshot clients can decode", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:lock("pad2")
		local snapshot = QueueSnapshotUtils.decode(tracker:snapshot())
		expect(snapshot.pads.pad1.members[1]).to.equal(7)
		expect(snapshot.pads.pad1.endsAt).to.equal(115)
		expect(snapshot.pads.pad1.capacity).to.equal(2)
		expect(snapshot.pads.pad1.destination).to.equal("away")
		expect(snapshot.pads.pad1.departing).to.equal(false)
		expect(snapshot.pads.pad2.departing).to.equal(true)
		expect(snapshot.pads.pad2.endsAt).to.equal(nil)
	end)

	it("drops a removed pad", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(same(tracker:remove("pad1"), { 7 })).to.equal(true)
		expect(tracker:has("pad1")).to.equal(false)
		expect(tracker:padOf(7)).to.equal(nil)
		expect(tracker:config("pad1")).to.equal(nil)
	end)
end
```

`src/ReplicatedStorage/Shared/Features/Queue/Utils/QueueSnapshotUtils.spec.luau`:

```lua
local QueueSnapshotUtils = require(script.Parent.QueueSnapshotUtils)

local function pad(overrides)
	local value = { members = { 7, 8 }, capacity = 4, destination = "away", endsAt = 120, departing = false }
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

return function()
	it("decodes pads", function()
		local snapshot = QueueSnapshotUtils.decode({ pads = { pad1 = pad() } })
		local decoded = snapshot.pads.pad1
		expect(decoded.members[2]).to.equal(8)
		expect(decoded.capacity).to.equal(4)
		expect(decoded.destination).to.equal("away")
		expect(decoded.endsAt).to.equal(120)
		expect(decoded.departing).to.equal(false)
	end)

	it("decodes absent pads, absent members and an absent countdown", function()
		expect(next(QueueSnapshotUtils.decode({}).pads)).to.equal(nil)
		local snapshot = QueueSnapshotUtils.decode({
			pads = { pad1 = { capacity = 4, destination = "away", departing = true } },
		})
		expect(#snapshot.pads.pad1.members).to.equal(0)
		expect(snapshot.pads.pad1.endsAt).to.equal(nil)
	end)

	it("rejects a malformed entry", function()
		expect(QueueSnapshotUtils.decode(nil)).to.equal(nil)
		expect(QueueSnapshotUtils.decode("x")).to.equal(nil)
		expect(QueueSnapshotUtils.decode({ pads = 5 })).to.equal(nil)
		for _, bad in {
			{ capacity = "4" },
			{ members = { "7" } },
			{ departing = "no" },
			{ endsAt = "soon" },
			{ destination = 3 },
		} do
			expect(QueueSnapshotUtils.decode({ pads = { pad1 = pad(bad) } })).to.equal(nil)
		end
	end)

	it("finds the pad a player is aboard", function()
		local snapshot = QueueSnapshotUtils.decode({ pads = { pad1 = pad() } })
		local padId, found = QueueSnapshotUtils.padOf(snapshot, 8)
		expect(padId).to.equal("pad1")
		expect(found.capacity).to.equal(4)
		expect(QueueSnapshotUtils.padOf(snapshot, 9)).to.equal(nil)
		expect(QueueSnapshotUtils.padOf(nil, 8)).to.equal(nil)
	end)
end
```

- [ ] **Step 2: Run to verify failure (controller).** Studio test run → the three specs error (modules missing).

- [ ] **Step 3: Pad rules** `src/ServerScriptService/Features/Queue/Rules/QueuePadRules.luau`:

```lua
--!strict
--[=[
	QueuePadRules: the decisions about one queue pad. Pure.

	- `config`: a pad's attributes, defaulted and checked.
	- `isAboard`: whether a point (a HumanoidRootPart) stands on the pad, measured in the pad's own space so
	  a rotated pad works.
	- `admit`: the party after a sample: members still aboard keep their place, newcomers follow, never
	  past capacity.
	- `deadline`: the countdown starts when the first player boards, resets on every join, stays when
	  someone leaves and stops when the pad empties.
	- `canDepart`: anyone aboard an open pad may Depart now.

	@class QueuePadRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

local QueuePadRules = {}

-- A pad's config from its attribute values, or nil and why.
function QueuePadRules.config(
	capacity: unknown,
	countdown: unknown,
	destination: unknown
): (QueueTypes.PadConfig?, string?)
	local seats = if capacity == nil then QueueConstants.DEFAULT_CAPACITY else capacity
	if
		type(seats) ~= "number"
		or seats ~= math.floor(seats)
		or seats < 1
		or seats > QueueConstants.MAX_CAPACITY
	then
		return nil, `{QueueConstants.CAPACITY_ATTRIBUTE} must be a whole number from 1 to {QueueConstants.MAX_CAPACITY}`
	end
	local seconds = if countdown == nil then QueueConstants.DEFAULT_COUNTDOWN else countdown
	if type(seconds) ~= "number" or seconds ~= seconds then
		return nil, `{QueueConstants.COUNTDOWN_ATTRIBUTE} must be a number of seconds`
	end
	if type(destination) ~= "string" or destination == "" then
		return nil, `{QueueConstants.DESTINATION_ATTRIBUTE} must name a role`
	end
	return {
		capacity = seats,
		countdown = math.clamp(seconds, 0, QueueConstants.MAX_COUNTDOWN),
		destination = destination,
	},
		nil
end

-- Whether `point` is over the pad's top face and no more than `height` studs above it.
function QueuePadRules.isAboard(padCFrame: CFrame, padSize: Vector3, point: Vector3, height: number): boolean
	local offset = padCFrame:PointToObjectSpace(point)
	local half = padSize / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Z) <= half.Z
		and offset.Y >= -half.Y
		and offset.Y <= half.Y + height
end

-- The party after a sample: `existing` members still in `aboard` (in their order), then newcomers from
-- `aboard` (in its order), up to `capacity`.
function QueuePadRules.admit(existing: { number }, aboard: { number }, capacity: number): { number }
	local present: { [number]: boolean } = {}
	for _, userId in aboard do
		present[userId] = true
	end
	local result: { number } = {}
	for _, userId in existing do
		if present[userId] and #result < capacity then
			table.insert(result, userId)
		end
	end
	for _, userId in aboard do
		if #result >= capacity then
			break
		end
		if table.find(result, userId) == nil then
			table.insert(result, userId)
		end
	end
	return result
end

-- When the pad departs after going from `previous` to `current` members at `now`.
function QueuePadRules.deadline(
	previous: { number },
	current: { number },
	deadline: number?,
	now: number,
	countdown: number
): number?
	if #current == 0 then
		return nil
	end
	for _, userId in current do
		if table.find(previous, userId) == nil then
			return now + countdown
		end
	end
	return deadline or now + countdown
end

function QueuePadRules.canDepart(members: { number }, status: QueueTypes.PadStatus, userId: number): boolean
	return status == "open" and table.find(members, userId) ~= nil
end

return QueuePadRules
```

- [ ] **Step 4: Pad tracker** `src/ServerScriptService/Features/Queue/State/QueuePadTracker.luau`:

```lua
--!strict
--[=[
	QueuePadTracker: who is aboard which pad, each pad's countdown and whether it is departing. Plain
	bookkeeping keyed by pad ids (strings) and UserIds; QueuePadSystem owns the Instances and samples who
	stands where. The decisions are QueuePadRules.

	A player is aboard at most one pad (the first that claims them). While a pad departs its party is
	frozen; `unlock` reopens it empty and the next sample re-boards whoever still stands there, which is
	how a failed teleport puts the party back on its pad.

	@class QueuePadTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueuePadRules = require(ServerScriptService.Features.Queue.Rules.QueuePadRules)

type PadConfig = QueueTypes.PadConfig

type Pad = {
	config: PadConfig,
	members: { number },
	endsAt: number?,
	status: QueueTypes.PadStatus,
}

export type QueuePadTracker = {
	add: (self: QueuePadTracker, padId: string, config: PadConfig) -> (),
	remove: (self: QueuePadTracker, padId: string) -> { number },
	has: (self: QueuePadTracker, padId: string) -> boolean,
	config: (self: QueuePadTracker, padId: string) -> PadConfig?,
	sync: (self: QueuePadTracker, padId: string, aboard: { number }, now: number) -> boolean,
	members: (self: QueuePadTracker, padId: string) -> { number },
	padOf: (self: QueuePadTracker, userId: number) -> string?,
	departNow: (self: QueuePadTracker, userId: number, now: number) -> string?,
	due: (self: QueuePadTracker, now: number) -> { string },
	lock: (self: QueuePadTracker, padId: string) -> { number },
	unlock: (self: QueuePadTracker, padId: string) -> (),
	forget: (self: QueuePadTracker, userId: number) -> boolean,
	snapshot: (self: QueuePadTracker) -> WorldTypes.WorldTable,
}

local function sameList(a: { number }, b: { number }): boolean
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

local QueuePadTracker = {}

function QueuePadTracker.new(): QueuePadTracker
	local pads: { [string]: Pad } = {}

	local tracker: QueuePadTracker
	tracker = {
		add = function(_self, padId, config)
			assert(pads[padId] == nil, `pad "{padId}" is already tracked`)
			pads[padId] = { config = config, members = {}, endsAt = nil, status = "open" }
		end,

		remove = function(_self, padId)
			local pad = pads[padId]
			pads[padId] = nil
			return if pad ~= nil then pad.members else {}
		end,

		has = function(_self, padId)
			return pads[padId] ~= nil
		end,

		config = function(_self, padId)
			local pad = pads[padId]
			return if pad ~= nil then pad.config else nil
		end,

		--[=[
			Applies one sample: the user ids standing on the pad now (sorted). Returns whether the members or
			the countdown changed. A departing pad ignores samples.
		]=]
		sync = function(self, padId, aboard, now)
			local pad = pads[padId]
			if pad == nil or pad.status ~= "open" then
				return false
			end
			local free: { number } = {}
			for _, userId in aboard do
				local current = self:padOf(userId)
				if current == nil or current == padId then
					table.insert(free, userId)
				end
			end
			local members = QueuePadRules.admit(pad.members, free, pad.config.capacity)
			local endsAt = QueuePadRules.deadline(pad.members, members, pad.endsAt, now, pad.config.countdown)
			local changed = not sameList(members, pad.members) or endsAt ~= pad.endsAt
			pad.members = members
			pad.endsAt = endsAt
			return changed
		end,

		members = function(_self, padId)
			local pad = pads[padId]
			return if pad ~= nil then table.clone(pad.members) else {}
		end,

		padOf = function(_self, userId)
			for padId, pad in pads do
				if table.find(pad.members, userId) ~= nil then
					return padId
				end
			end
			return nil
		end,

		-- Depart now: a member of an open pad makes it due immediately. The pad id, or nil when refused.
		departNow = function(self, userId, now)
			local padId = self:padOf(userId)
			local pad = if padId ~= nil then pads[padId] else nil
			if padId == nil or pad == nil or not QueuePadRules.canDepart(pad.members, pad.status, userId) then
				return nil
			end
			pad.endsAt = now
			return padId
		end,

		due = function(_self, now)
			local list: { string } = {}
			for padId, pad in pads do
				local endsAt = pad.endsAt
				if pad.status == "open" and #pad.members > 0 and endsAt ~= nil and endsAt <= now then
					table.insert(list, padId)
				end
			end
			table.sort(list)
			return list
		end,

		-- Freezes the party for departure and returns it.
		lock = function(_self, padId)
			local pad = pads[padId]
			if pad == nil then
				return {}
			end
			pad.status = "departing"
			pad.endsAt = nil
			return table.clone(pad.members)
		end,

		unlock = function(_self, padId)
			local pad = pads[padId]
			if pad == nil then
				return
			end
			pad.status = "open"
			pad.members = {}
			pad.endsAt = nil
		end,

		forget = function(_self, userId)
			for _, pad in pads do
				local index = table.find(pad.members, userId)
				if index ~= nil then
					table.remove(pad.members, index)
					if #pad.members == 0 and pad.status == "open" then
						pad.endsAt = nil
					end
					return true
				end
			end
			return false
		end,

		-- Plain data for the `queue` world entry (decoded on clients by QueueSnapshotUtils).
		snapshot = function(_self)
			local list: WorldTypes.WorldTable = {}
			for padId, pad in pads do
				local members: WorldTypes.WorldTable = {}
				for index, userId in pad.members do
					members[index] = userId
				end
				local entry: WorldTypes.WorldTable = {
					members = members,
					capacity = pad.config.capacity,
					destination = pad.config.destination,
					departing = pad.status == "departing",
				}
				local endsAt = pad.endsAt
				if endsAt ~= nil then
					entry.endsAt = endsAt
				end
				list[padId] = entry
			end
			return { pads = list }
		end,
	}
	return tracker
end

return QueuePadTracker
```

- [ ] **Step 5: Snapshot decoder** `src/ReplicatedStorage/Shared/Features/Queue/Utils/QueueSnapshotUtils.luau`:

```lua
--!strict
--[=[
	QueueSnapshotUtils: turns the replicated `queue` world entry (plain data off the wire, typed as a
	WorldValue) back into a typed QueueSnapshot, or nil when it is malformed, and finds the pad a player is
	aboard. The server builds the entry (QueuePadTracker:snapshot); this is the client's trust boundary.

	@class QueueSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type WorldValue = WorldTypes.WorldValue
type PadSnapshot = QueueTypes.PadSnapshot
type QueueSnapshot = QueueTypes.QueueSnapshot

-- A list of numbers; nil decodes as empty (an empty list does not survive the wire).
local function numberList(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "number" then
			return nil
		end
		table.insert(result, item)
	end
	return result
end

local function padFrom(value: WorldValue?): PadSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local members = numberList(value.members)
	local capacity = value.capacity
	local destination = value.destination
	local endsAt = value.endsAt
	local departing = value.departing
	if members == nil or type(capacity) ~= "number" or type(destination) ~= "string" then
		return nil
	end
	if endsAt ~= nil and type(endsAt) ~= "number" then
		return nil
	end
	if type(departing) ~= "boolean" then
		return nil
	end
	return {
		members = members,
		capacity = capacity,
		destination = destination,
		endsAt = if type(endsAt) == "number" then endsAt else nil,
		departing = departing,
	}
end

local QueueSnapshotUtils = {}

--[=[
	Decodes the `queue` world entry. Absent pads decode as none; a wrong type anywhere rejects the whole value.
]=]
function QueueSnapshotUtils.decode(value: WorldValue?): QueueSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local pads: { [string]: PadSnapshot } = {}
	local raw = value.pads
	if raw ~= nil then
		if type(raw) ~= "table" then
			return nil
		end
		for key, item in raw do
			local pad = padFrom(item)
			if type(key) ~= "string" or pad == nil then
				return nil
			end
			pads[key] = pad
		end
	end
	return { pads = pads }
end

-- The pad `userId` is aboard (its id and snapshot), or nil.
function QueueSnapshotUtils.padOf(snapshot: QueueSnapshot?, userId: number): (string?, PadSnapshot?)
	if snapshot == nil then
		return nil, nil
	end
	for padId, pad in snapshot.pads do
		if table.find(pad.members, userId) ~= nil then
			return padId, pad
		end
	end
	return nil, nil
end

return QueueSnapshotUtils
```

- [ ] **Step 6: Run the specs (controller).** Studio `RunTests = true` → `QueuePadRules`, `QueuePadTracker`, `QueueSnapshotUtils` pass.

- [ ] **Step 7: Module map, gate, commit**

```bash
git add src/ServerScriptService/Features/Queue src/ReplicatedStorage/Shared/Features/Queue
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
bash .superpowers/sdd/gate.sh
git commit -m "feat(queue): pad rules, pad tracker and snapshot decoding"
python3 scripts/python/module_map.py --check
```

---
### Task 3: Teleport rules, departure tracker and arrival tracker

**Files:**
- Create: `src/ServerScriptService/Features/Queue/Rules/QueueTeleportRules.luau` + `QueueTeleportRules.spec.luau`
- Create: `src/ServerScriptService/Features/Queue/State/QueueDepartureTracker.luau` + `QueueDepartureTracker.spec.luau`
- Create: `src/ServerScriptService/Features/Queue/State/QueueArrivalTracker.luau` + `QueueArrivalTracker.spec.luau`

**Interfaces:**
- Consumes: `QueueTypes.QueuePayload`, `QueueTicket`, `TicketKind`, `Admission`; `QueueConstants.RETRY_DELAYS`, `MAX_PAYLOAD_*`, `MAX_CAPACITY`, `TICKET_VERSION` (Task 1); `WorldTypes`.
- Produces (QueueTeleportRules): `retryDelay(failures: number) -> number?` (1 → 1, 2 → 2, 3 → 4, otherwise nil), `payload(value: QueuePayload?) -> (QueuePayload?, string?)` (a checked copy), `encode(ticket: QueueTicket) -> WorldTypes.WorldTable`, `decode(value: WorldTypes.WorldValue?) -> QueueTicket?`
- Produces (QueueDepartureTracker): `new()` with `begin(userIds) -> number` (departure id), `departureOf(userId) -> number?`, `attempt(userId, now)`, `fail(userId) -> number?` (failures so far; nil when no attempt is in flight), `giveUp(userId, reason) -> number?`, `arrive(userId) -> number?`, `finished(departure) -> Outcome?` where `Outcome = { gaveUp: { number }, reason: string? }`, `stale(now, watchdog) -> { number }`
- Produces (QueueArrivalTracker): `new(timeout: number, defaultCapacity: number)` with `expect(ticket, now)`, `join(userId, now) -> Admission`, `leave(userId)`, `ready(now) -> boolean`, `close() -> { number }`, `isClosed() -> boolean`, `ticket() -> QueueTicket?`, `crew() -> { number }`

- [ ] **Step 1: Write the failing specs.**

`src/ServerScriptService/Features/Queue/Rules/QueueTeleportRules.spec.luau`:

```lua
local HttpService = game:GetService("HttpService")

local QueueTeleportRules = require(script.Parent.QueueTeleportRules)

local function ticket()
	return {
		kind = "depart",
		from = "home",
		role = "away",
		party = { 7, 8 },
		capacity = 4,
		payload = { contract = "c-1", night = 2, hard = true },
	}
end

-- What the arrival server sees: the encoded ticket after a JSON round trip (teleport data is a JSON string).
local function wire(value)
	return HttpService:JSONDecode(HttpService:JSONEncode(QueueTeleportRules.encode(value)))
end

return function()
	describe("retryDelay", function()
		it("backs off over three retries, then gives up", function()
			expect(QueueTeleportRules.retryDelay(1)).to.equal(1)
			expect(QueueTeleportRules.retryDelay(2)).to.equal(2)
			expect(QueueTeleportRules.retryDelay(3)).to.equal(4)
			expect(QueueTeleportRules.retryDelay(4)).to.equal(nil)
			expect(QueueTeleportRules.retryDelay(0)).to.equal(nil)
		end)
	end)

	describe("payload", function()
		it("accepts flat strings, numbers and booleans as a copy", function()
			local original = { a = "x", b = 1, c = true }
			local checked = QueueTeleportRules.payload(original)
			expect(checked.a).to.equal("x")
			expect(checked.b).to.equal(1)
			expect(checked.c).to.equal(true)
			expect(checked).never.to.equal(original)
		end)

		it("treats a missing payload as empty", function()
			expect(next(QueueTeleportRules.payload(nil))).to.equal(nil)
		end)

		it("refuses too many keys and says why", function()
			local big = {}
			for index = 1, 33 do
				big[`k{index}`] = index
			end
			local checked, reason = QueueTeleportRules.payload(big)
			expect(checked).to.equal(nil)
			expect(reason).never.to.equal(nil)
		end)

		it("refuses an overlong string or key", function()
			expect(QueueTeleportRules.payload({ a = string.rep("x", 1001) })).to.equal(nil)
			expect(QueueTeleportRules.payload({ [string.rep("k", 65)] = 1 })).to.equal(nil)
		end)

		it("refuses a nested table, NaN or infinity", function()
			expect(QueueTeleportRules.payload({ a = {} })).to.equal(nil)
			expect(QueueTeleportRules.payload({ a = 0 / 0 })).to.equal(nil)
			expect(QueueTeleportRules.payload({ a = math.huge })).to.equal(nil)
		end)
	end)

	describe("encode / decode", function()
		it("survives the trip as JSON teleport data", function()
			local decoded = QueueTeleportRules.decode(wire(ticket()))
			expect(decoded.kind).to.equal("depart")
			expect(decoded.from).to.equal("home")
			expect(decoded.role).to.equal("away")
			expect(decoded.party[2]).to.equal(8)
			expect(decoded.capacity).to.equal(4)
			expect(decoded.payload.contract).to.equal("c-1")
			expect(decoded.payload.night).to.equal(2)
			expect(decoded.payload.hard).to.equal(true)
		end)

		it("keeps an empty payload and a missing source", function()
			local value = ticket()
			value.payload = {}
			value.from = nil
			value.kind = "return"
			local decoded = QueueTeleportRules.decode(wire(value))
			expect(decoded.kind).to.equal("return")
			expect(decoded.from).to.equal(nil)
			expect(next(decoded.payload)).to.equal(nil)
		end)

		it("rejects data that is not a queue ticket", function()
			expect(QueueTeleportRules.decode(nil)).to.equal(nil)
			expect(QueueTeleportRules.decode("hello")).to.equal(nil)
			expect(QueueTeleportRules.decode({})).to.equal(nil)
			local other = wire(ticket())
			other.v = 99
			expect(QueueTeleportRules.decode(other)).to.equal(nil)
		end)

		it("rejects a forged or broken ticket", function()
			for _, bad in {
				{ kind = "steal" },
				{ role = "" },
				{ from = 5 },
				{ capacity = 0 },
				{ capacity = 4.5 },
				{ capacity = 51 },
				{ party = { "7" } },
				{ party = { 7, -8 } },
				{ party = { 7, 8, 9 }, capacity = 2 },
				{ payload = { a = { b = 1 } } },
				{ payload = { a = string.rep("x", 1001) } },
			} do
				local forged = wire(ticket())
				for key, item in bad do
					forged[key] = item
				end
				expect(QueueTeleportRules.decode(forged)).to.equal(nil)
			end
		end)
	end)
end
```

`src/ServerScriptService/Features/Queue/State/QueueDepartureTracker.spec.luau`:

```lua
local QueueDepartureTracker = require(script.Parent.QueueDepartureTracker)

return function()
	local tracker

	beforeEach(function()
		tracker = QueueDepartureTracker.new()
	end)

	it("finishes when every member has left the server", function()
		local id = tracker:begin({ 7, 8 })
		expect(tracker:departureOf(7)).to.equal(id)
		expect(tracker:arrive(7)).to.equal(id)
		expect(tracker:finished(id)).to.equal(nil)
		tracker:arrive(8)
		local outcome = tracker:finished(id)
		expect(#outcome.gaveUp).to.equal(0)
		expect(tracker:finished(id)).to.equal(nil) -- reported once
	end)

	it("counts failures per player, only while their teleport is in flight", function()
		tracker:begin({ 7, 8 })
		expect(tracker:fail(7)).to.equal(nil) -- no attempt started yet
		tracker:attempt(7, 100)
		tracker:attempt(8, 100)
		expect(tracker:fail(7)).to.equal(1)
		expect(tracker:fail(7)).to.equal(nil) -- a second report for the same attempt
		tracker:attempt(7, 101)
		expect(tracker:fail(7)).to.equal(2)
		expect(tracker:fail(8)).to.equal(1)
		expect(tracker:fail(99)).to.equal(nil)
	end)

	it("reports the players it gave up on, and why", function()
		local id = tracker:begin({ 7, 8 })
		tracker:arrive(7)
		expect(tracker:giveUp(8, "flooded")).to.equal(id)
		local outcome = tracker:finished(id)
		expect(#outcome.gaveUp).to.equal(1)
		expect(outcome.gaveUp[1]).to.equal(8)
		expect(outcome.reason).to.equal("flooded")
	end)

	it("ignores a player who leaves after being given up on", function()
		tracker:begin({ 7 })
		tracker:giveUp(7, "failed")
		expect(tracker:arrive(7)).to.equal(nil)
		expect(tracker:departureOf(7)).to.equal(nil)
	end)

	it("keeps a player with the departure they are already on", function()
		local first = tracker:begin({ 7 })
		local second = tracker:begin({ 7, 8 })
		expect(tracker:departureOf(7)).to.equal(first)
		tracker:arrive(8)
		expect(#tracker:finished(second).gaveUp).to.equal(0)
	end)

	it("finds teleports that never resolved", function()
		tracker:begin({ 7, 8 })
		tracker:attempt(7, 100)
		tracker:attempt(8, 110)
		expect(#tracker:stale(114, 15)).to.equal(0)
		local stale = tracker:stale(115, 15)
		expect(#stale).to.equal(1)
		expect(stale[1]).to.equal(7)
		tracker:fail(7) -- the failure stops 7's clock until the retry starts
		local later = tracker:stale(200, 15)
		expect(#later).to.equal(1)
		expect(later[1]).to.equal(8)
	end)
end
```

`src/ServerScriptService/Features/Queue/State/QueueArrivalTracker.spec.luau`:

```lua
local QueueArrivalTracker = require(script.Parent.QueueArrivalTracker)

local function ticket(party, capacity)
	return { kind = "depart", role = "away", party = party, capacity = capacity or 4, payload = {} }
end

return function()
	it("is ready as soon as the whole party has arrived", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7, 8 }), 100)
		expect(tracker:join(7, 100)).to.equal("crew")
		expect(tracker:ready(101)).to.equal(false)
		expect(tracker:join(8, 103)).to.equal("crew")
		expect(tracker:ready(103)).to.equal(true)
		expect(#tracker:close()).to.equal(2)
		expect(tracker:isClosed()).to.equal(true)
		expect(tracker:ready(104)).to.equal(false) -- fires once
	end)

	it("starts with whoever arrived when the wait runs out", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7, 8, 9 }), 100)
		tracker:join(7, 100)
		expect(tracker:ready(119)).to.equal(false)
		expect(tracker:ready(120)).to.equal(true)
		local crew = tracker:close()
		expect(#crew).to.equal(1)
		expect(crew[1]).to.equal(7)
	end)

	it("lets a stranger join the crew when there is room", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7 }, 4), 100)
		tracker:join(7, 100)
		expect(tracker:join(50, 101)).to.equal("crew")
		expect(#tracker:crew()).to.equal(2)
	end)

	it("keeps seats for expected players still on their way", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7, 8, 9 }, 4), 100)
		tracker:join(7, 100)
		expect(tracker:join(50, 101)).to.equal("crew") -- 4 seats - 1 crew - 2 coming = 1
		expect(tracker:join(51, 101)).to.equal("redirect")
		expect(tracker:join(8, 102)).to.equal("crew")
		expect(tracker:join(9, 102)).to.equal("crew")
	end)

	it("frees a stranger's seat when they leave", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7 }, 2), 100)
		tracker:join(7, 100)
		expect(tracker:join(50, 101)).to.equal("crew")
		expect(tracker:join(51, 101)).to.equal("redirect")
		tracker:leave(50)
		expect(tracker:join(51, 102)).to.equal("crew")
	end)

	it("does not wait for an expected player who already left", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7, 8 }), 100)
		tracker:join(7, 100)
		tracker:leave(7)
		tracker:join(8, 101)
		expect(tracker:ready(101)).to.equal(true)
		local crew = tracker:close()
		expect(#crew).to.equal(1)
		expect(crew[1]).to.equal(8)
	end)

	it("treats an expected straggler as late and redirects strangers once started", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7, 8 }), 100)
		tracker:join(7, 100)
		tracker:close()
		expect(tracker:join(8, 130)).to.equal("late")
		expect(tracker:join(50, 130)).to.equal("redirect")
	end)

	it("waits out the timeout with the default capacity when nobody carried a ticket", function()
		local tracker = QueueArrivalTracker.new(20, 2)
		expect(tracker:join(50, 100)).to.equal("crew")
		expect(tracker:join(51, 100)).to.equal("crew")
		expect(tracker:join(52, 100)).to.equal("redirect")
		expect(tracker:ready(119)).to.equal(false)
		expect(tracker:ready(120)).to.equal(true)
	end)

	it("keeps the first ticket it saw", function()
		local tracker = QueueArrivalTracker.new(20, 4)
		tracker:expect(ticket({ 7 }), 100)
		tracker:expect(ticket({ 9 }), 101)
		expect(tracker:ticket().party[1]).to.equal(7)
	end)
end
```

- [ ] **Step 2: Run to verify failure (controller).** Studio test run → the three specs error (modules missing).

- [ ] **Step 3: Teleport rules** `src/ServerScriptService/Features/Queue/Rules/QueueTeleportRules.luau`:

```lua
--!strict
--[=[
	QueueTeleportRules: the retry schedule, the payload limits and the teleport ticket's wire format. Pure.

	A ticket travels as JSON teleport data. It goes through the client on the way, so it carries only what
	is harmless to forge (expected user ids, a contract id, a result card) and the arrival server decodes
	it as untrusted input. The reserved server's access code is what keeps strangers out.

	@class QueueTeleportRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type WorldValue = WorldTypes.WorldValue
type WorldTable = WorldTypes.WorldTable
type QueuePayload = QueueTypes.QueuePayload
type QueueTicket = QueueTypes.QueueTicket

local QueueTeleportRules = {}

-- Seconds to wait before retrying after a player's `failures`-th failure, or nil: give up.
function QueueTeleportRules.retryDelay(failures: number): number?
	local delays = QueueConstants.RETRY_DELAYS
	if failures < 1 or failures > #delays then
		return nil
	end
	return delays[failures]
end

-- A checked copy of a payload, or nil and why. Absent = empty.
function QueueTeleportRules.payload(value: QueuePayload?): (QueuePayload?, string?)
	local result: QueuePayload = {}
	if value == nil then
		return result, nil
	end
	local count = 0
	for key, item in value do
		count += 1
		if count > QueueConstants.MAX_PAYLOAD_KEYS then
			return nil, `more than {QueueConstants.MAX_PAYLOAD_KEYS} keys`
		end
		if type(key) ~= "string" or key == "" or #key > QueueConstants.MAX_PAYLOAD_KEY_LENGTH then
			return nil, `bad key {tostring(key)}`
		end
		if type(item) ~= "string" and type(item) ~= "number" and type(item) ~= "boolean" then
			return nil, `"{key}" must be a string, number or boolean`
		end
		if type(item) == "string" and #item > QueueConstants.MAX_PAYLOAD_STRING then
			return nil, `"{key}" is longer than {QueueConstants.MAX_PAYLOAD_STRING} characters`
		end
		if type(item) == "number" and (item ~= item or math.abs(item) == math.huge) then
			return nil, `"{key}" is not a finite number`
		end
		result[key] = item
	end
	return result, nil
end

-- The ticket as plain data, ready for HttpService:JSONEncode.
function QueueTeleportRules.encode(ticket: QueueTicket): WorldTable
	local party: WorldTable = {}
	for index, userId in ticket.party do
		party[index] = userId
	end
	local payload: WorldTable = {}
	for key, item in ticket.payload do
		payload[key] = item
	end
	local wire: WorldTable = {
		v = QueueConstants.TICKET_VERSION,
		kind = ticket.kind,
		role = ticket.role,
		capacity = ticket.capacity,
		party = party,
		payload = payload,
	}
	local from = ticket.from
	if from ~= nil then
		wire.from = from
	end
	return wire
end

local function kindOf(value: WorldValue?): QueueTypes.TicketKind?
	if value == "depart" then
		return "depart"
	elseif value == "return" then
		return "return"
	end
	return nil
end

-- Positive whole user ids; absent decodes as empty.
local function userIds(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "number" or item < 1 or item ~= math.floor(item) then
			return nil
		end
		table.insert(result, item)
	end
	return result
end

local function payloadOf(value: WorldValue?): QueuePayload?
	local result: QueuePayload = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for key, item in value do
		if type(key) ~= "string" or type(item) == "table" then
			return nil
		end
		result[key] = item
	end
	local checked = QueueTeleportRules.payload(result)
	return checked
end

--[=[
	Decodes teleport data (already JSON-decoded) into a ticket, or nil when it is not a valid one.
]=]
function QueueTeleportRules.decode(value: WorldValue?): QueueTicket?
	if type(value) ~= "table" or value.v ~= QueueConstants.TICKET_VERSION then
		return nil
	end
	-- Annotated and tested with `not` (the RoundSnapshotUtils note): comparing an optional singleton union
	-- against nil widens it back to string.
	local kind: QueueTypes.TicketKind? = kindOf(value.kind)
	local role = value.role
	local from = value.from
	local capacity = value.capacity
	if not kind then
		return nil
	end
	if type(role) ~= "string" or role == "" then
		return nil
	end
	if from ~= nil and type(from) ~= "string" then
		return nil
	end
	if
		type(capacity) ~= "number"
		or capacity < 1
		or capacity > QueueConstants.MAX_CAPACITY
		or capacity ~= math.floor(capacity)
	then
		return nil
	end
	local party = userIds(value.party)
	local payload = payloadOf(value.payload)
	if party == nil or payload == nil or #party > capacity then
		return nil
	end
	return {
		kind = kind,
		from = if type(from) == "string" then from else nil,
		role = role,
		party = party,
		capacity = capacity,
		payload = payload,
	}
end

return QueueTeleportRules
```

If luau-lsp reports the `type(key) ~= "string"` / `type(item) ~= ...` guards in `payload` as always-false (the parameter is already typed), keep them anyway: specs and `payloadOf` feed this function untyped data, and the guards are the check. Do not cast to silence anything.

- [ ] **Step 4: Departure tracker** `src/ServerScriptService/Features/Queue/State/QueueDepartureTracker.luau`:

```lua
--!strict
--[=[
	QueueDepartureTracker: teleports in flight, per player. A departure is a group sent together; each
	member is outstanding until they leave the server (teleported) or are given up on. Failures count per
	player and only while that player's attempt is in flight (so a watchdog timeout and a late
	TeleportInitFailed for one attempt count once); a partial failure therefore retries only the players
	it hit. Plain bookkeeping keyed by UserIds; QueueTeleportSystem talks to TeleportService.

	@class QueueDepartureTracker
]=]

type Member = { departure: number, failures: number, since: number? }

type Departure = { outstanding: number, gaveUp: { number }, reason: string? }

export type Outcome = { gaveUp: { number }, reason: string? }

export type QueueDepartureTracker = {
	begin: (self: QueueDepartureTracker, userIds: { number }) -> number,
	departureOf: (self: QueueDepartureTracker, userId: number) -> number?,
	attempt: (self: QueueDepartureTracker, userId: number, now: number) -> (),
	fail: (self: QueueDepartureTracker, userId: number) -> number?,
	giveUp: (self: QueueDepartureTracker, userId: number, reason: string) -> number?,
	arrive: (self: QueueDepartureTracker, userId: number) -> number?,
	finished: (self: QueueDepartureTracker, departure: number) -> Outcome?,
	stale: (self: QueueDepartureTracker, now: number, watchdog: number) -> { number },
}

local QueueDepartureTracker = {}

function QueueDepartureTracker.new(): QueueDepartureTracker
	local members: { [number]: Member } = {}
	local departures: { [number]: Departure } = {}
	local nextId = 0

	-- Ends a member's part in their departure; returns the departure id, or nil when they had none.
	local function settle(userId: number): number?
		local member = members[userId]
		if member == nil then
			return nil
		end
		members[userId] = nil
		local departure = departures[member.departure]
		if departure ~= nil then
			departure.outstanding -= 1
		end
		return member.departure
	end

	local tracker: QueueDepartureTracker
	tracker = {
		-- A new departure for `userIds`; a player already in flight stays with their first departure.
		begin = function(_self, userIds)
			nextId += 1
			local departure: Departure = { outstanding = 0, gaveUp = {}, reason = nil }
			departures[nextId] = departure
			for _, userId in userIds do
				if members[userId] == nil then
					members[userId] = { departure = nextId, failures = 0, since = nil }
					departure.outstanding += 1
				end
			end
			return nextId
		end,

		departureOf = function(_self, userId)
			local member = members[userId]
			return if member ~= nil then member.departure else nil
		end,

		-- An attempt for this player started at `now` (os.clock()).
		attempt = function(_self, userId, now)
			local member = members[userId]
			if member ~= nil then
				member.since = now
			end
		end,

		-- Counts a failure of the attempt in flight: the player's failures so far, or nil.
		fail = function(_self, userId)
			local member = members[userId]
			if member == nil or member.since == nil then
				return nil
			end
			member.failures += 1
			member.since = nil
			return member.failures
		end,

		giveUp = function(_self, userId, reason)
			local member = members[userId]
			if member == nil then
				return nil
			end
			local departure = departures[member.departure]
			if departure ~= nil then
				table.insert(departure.gaveUp, userId)
				departure.reason = reason
			end
			return settle(userId)
		end,

		-- The player left the server: their teleport went through.
		arrive = function(_self, userId)
			return settle(userId)
		end,

		-- The outcome once nobody is outstanding (reported once), else nil.
		finished = function(_self, id)
			local departure = departures[id]
			if departure == nil or departure.outstanding > 0 then
				return nil
			end
			departures[id] = nil
			return { gaveUp = departure.gaveUp, reason = departure.reason }
		end,

		stale = function(_self, now, watchdog)
			local list: { number } = {}
			for userId, member in members do
				local since = member.since
				if since ~= nil and now - since >= watchdog then
					table.insert(list, userId)
				end
			end
			table.sort(list)
			return list
		end,
	}
	return tracker
end

return QueueDepartureTracker
```

- [ ] **Step 5: Arrival tracker** `src/ServerScriptService/Features/Queue/State/QueueArrivalTracker.luau`:

```lua
--!strict
--[=[
	QueueArrivalTracker: an arrival server's party. Who is expected (from the first ticket seen), who has
	arrived, and when the wait is over: once everyone expected has shown up, or `timeout` seconds after the
	first arrival. Decides each joining player's admission. Plain bookkeeping keyed by UserIds;
	QueueArrivalSystem reads join data and does the teleports.

	Seats are kept for expected players still on their way, so a stranger following a friend in never
	takes a party member's place. After the party has started, an expected straggler is "late" (the game
	decides what to do) and a stranger is redirected.

	@class QueueArrivalTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type QueueTicket = QueueTypes.QueueTicket

export type QueueArrivalTracker = {
	expect: (self: QueueArrivalTracker, ticket: QueueTicket, now: number) -> (),
	join: (self: QueueArrivalTracker, userId: number, now: number) -> QueueTypes.Admission,
	leave: (self: QueueArrivalTracker, userId: number) -> (),
	ready: (self: QueueArrivalTracker, now: number) -> boolean,
	close: (self: QueueArrivalTracker) -> { number },
	isClosed: (self: QueueArrivalTracker) -> boolean,
	ticket: (self: QueueArrivalTracker) -> QueueTicket?,
	crew: (self: QueueArrivalTracker) -> { number },
}

local QueueArrivalTracker = {}

function QueueArrivalTracker.new(timeout: number, defaultCapacity: number): QueueArrivalTracker
	local current: QueueTicket? = nil
	local crew: { number } = {}
	local seen: { [number]: boolean } = {}
	local startedAt: number? = nil
	local closed = false

	local function isExpected(userId: number): boolean
		local ticket = current
		return ticket ~= nil and table.find(ticket.party, userId) ~= nil
	end

	-- Seats left for strangers: capacity minus the crew minus expected players still on their way.
	local function room(): number
		local ticket = current
		local capacity = if ticket ~= nil then ticket.capacity else defaultCapacity
		local coming = 0
		if ticket ~= nil then
			for _, userId in ticket.party do
				if not seen[userId] then
					coming += 1
				end
			end
		end
		return capacity - #crew - coming
	end

	local function board(userId: number)
		if table.find(crew, userId) == nil then
			table.insert(crew, userId)
		end
	end

	local tracker: QueueArrivalTracker
	tracker = {
		-- The first ticket wins (one reserved server per departure); the wait starts at the first arrival.
		expect = function(_self, ticket, now)
			if current == nil then
				current = ticket
			end
			if startedAt == nil then
				startedAt = now
			end
		end,

		join = function(_self, userId, now)
			if startedAt == nil then
				startedAt = now
			end
			local expected = isExpected(userId)
			if closed then
				if expected then
					board(userId)
					return "late"
				end
				return "redirect"
			end
			if expected then
				seen[userId] = true
				board(userId)
				return "crew"
			end
			if room() > 0 then
				board(userId)
				return "crew"
			end
			return "redirect"
		end,

		leave = function(_self, userId)
			local index = table.find(crew, userId)
			if index ~= nil then
				table.remove(crew, index)
			end
			if isExpected(userId) then
				seen[userId] = true
			end
		end,

		ready = function(_self, now)
			local began = startedAt
			if closed or began == nil then
				return false
			end
			if now - began >= timeout then
				return true
			end
			local ticket = current
			if ticket == nil or #ticket.party == 0 then
				return false
			end
			for _, userId in ticket.party do
				if not seen[userId] then
					return false
				end
			end
			return true
		end,

		close = function(_self)
			closed = true
			return table.clone(crew)
		end,

		isClosed = function(_self)
			return closed
		end,

		ticket = function(_self)
			return current
		end,

		crew = function(_self)
			return table.clone(crew)
		end,
	}
	return tracker
end

return QueueArrivalTracker
```

- [ ] **Step 6: Run the specs (controller).** Studio `RunTests = true` → `QueueTeleportRules`, `QueueDepartureTracker`, `QueueArrivalTracker` pass.

- [ ] **Step 7: Module map, gate, commit**

```bash
git add src/ServerScriptService/Features/Queue
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
bash .superpowers/sdd/gate.sh
git commit -m "feat(queue): teleport rules, departure and arrival tracking"
python3 scripts/python/module_map.py --check
```

---

### Task 4: Server shells: packet, pad / teleport / arrival systems, the service

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Queue/Net/QueueEvents.luau`
- Create: `src/ServerScriptService/Features/Queue/Systems/QueuePadSystem.luau`
- Create: `src/ServerScriptService/Features/Queue/Systems/QueueTeleportSystem.luau`
- Create: `src/ServerScriptService/Features/Queue/Systems/QueueArrivalSystem.luau`
- Create: `src/ServerScriptService/Features/Queue/QueueServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (five exemptions), `docs/project-structure.md` (feature list: add Queue)

**Interfaces:**
- Consumes: everything from Tasks 1–3 by the exact names in their Interfaces blocks; `Observers.observeTag(tag, fn) -> () -> ()` (as in `InteractionServiceServer`); `RequestHandler.wrap({ name, rateLimit, handler })`; `StateSyncWorldStore.set(name, value)` / `.clear(name)`; `ToastServiceServer:send(target: Player | "all", { text, style?, duration? }) -> boolean`; `SignalTyped.new()`; `ServiceController:getPhase() -> "registering" | "initializing" | "starting" | "running" | "stopping"`.
- Produces (QueueEvents): `QueueEvents.packets.Depart` (value `ByteNet.bool`, client → server; payload unused).
- Produces (QueuePadSystem): `QueuePadSystem.new(onDue: (pad: BasePart, config: PadConfig, party: { Player }) -> (), onChanged: () -> ())` with `start()`, `stop()`, `step(now)`, `departNow(player, now) -> boolean`, `unlock(pad: BasePart)`, `forget(player)`, `padOf(player) -> BasePart?`, `snapshot() -> WorldTable`, `count() -> number`.
- Produces (QueueTeleportSystem): `QueueTeleportSystem.new()` with `send(request: { players: { Player }, placeId: number, reserve: boolean, data: string?, onFinished: (gaveUp: { Player }, reason: string?) -> () })`, `initFailed(player, reason)`, `left(player)`, `step(now)`, `inFlight() -> number`.
- Produces (QueueArrivalSystem): `QueueArrivalSystem.new(hooks: { ticketOf, onArrived, onLate, onRedirect })` with `start()`, `stop()`, `step(now)`, `getState() -> { crew: { number }, closed: boolean }`.
- Produces (QueueServiceServer), what games call:
  - signals `arrived: Signal<{ Player }, QueuePayload>`, `joinedLate: Signal<Player>`, `returned: Signal<Player, QueuePayload>`, `departing: Signal<BasePart, { Player }>`, `departFailed: Signal<BasePart, { Player }, string>`
  - `configure(update: QueueConfigUpdate)`, `setDepartData(resolver: DepartDataResolver?)`, `setArrivalPoint(role: string, resolver: ArrivalPoint?)`
  - `departNow(player) -> boolean`, `padOf(player) -> BasePart?`
  - `returnParty(players: { Player }, role: string, payload: QueuePayload?) -> boolean`, `returnPayloadOf(player) -> QueuePayload?`
  - `mode() -> Mode`, `role() -> string?`, `runsRole(role) -> boolean`

- [ ] **Step 1: The packet** `src/ReplicatedStorage/Shared/Features/Queue/Net/QueueEvents.luau`:

```lua
--!strict
--[=[
	QueueEvents: the ByteNet packet for Depart now (client → server). The payload is unused; the server
	finds the sender's pad and checks they are aboard an open pad (QueuePadTracker).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value
	the server creates when IT requires this module (at QueueServiceServer load).

	@class QueueEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "QueueEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local QueueEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Payload unused; the packet is the request.
			Depart = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return QueueEvents
```

- [ ] **Step 2: The pad system** `src/ServerScriptService/Features/Queue/Systems/QueuePadSystem.luau`:

```lua
--!strict
--[=[
	QueuePadSystem: the pads in the world. Every BasePart tagged QueuePad has its attributes read once when
	tagged (QueueCapacity, QueueCountdown, QueueDestination; set them first) and is sampled every tick: a
	living player whose HumanoidRootPart is over the pad is aboard (QueuePadRules.isAboard). Membership,
	countdowns and Depart now are the specced QueuePadTracker; this module turns Instances into its ids and
	hands a due pad's party to `onDue`. A misconfigured pad is warned about and ignored.

	Spec-exempt shell (CollectionService via Observers, characters, Players).

	@class QueuePadSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueuePadRules = require(ServerScriptService.Features.Queue.Rules.QueuePadRules)
local QueuePadTracker = require(ServerScriptService.Features.Queue.State.QueuePadTracker)

export type OnDue = (pad: BasePart, config: QueueTypes.PadConfig, party: { Player }) -> ()

export type QueuePadSystem = {
	start: (self: QueuePadSystem) -> (),
	stop: (self: QueuePadSystem) -> (),
	step: (self: QueuePadSystem, now: number) -> (),
	departNow: (self: QueuePadSystem, player: Player, now: number) -> boolean,
	unlock: (self: QueuePadSystem, pad: BasePart) -> (),
	forget: (self: QueuePadSystem, player: Player) -> (),
	padOf: (self: QueuePadSystem, player: Player) -> BasePart?,
	snapshot: (self: QueuePadSystem) -> WorldTypes.WorldTable,
	count: (self: QueuePadSystem) -> number,
}

local log = Logger.new("QueuePadSystem")

-- Root positions of every living character, by UserId.
local function rootPositions(): { [number]: Vector3 }
	local positions: { [number]: Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart") then
				positions[player.UserId] = root.Position
			end
		end
	end
	return positions
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

local QueuePadSystem = {}

function QueuePadSystem.new(onDue: OnDue, onChanged: () -> ()): QueuePadSystem
	local tracker = QueuePadTracker.new()
	local padById: { [string]: BasePart } = {}
	local idByPad: { [BasePart]: string } = {}
	local order: { string } = {}
	local nextId = 0
	local stopObserving: (() -> ())? = nil

	-- Starts tracking one tagged instance; returns its cleanup.
	local function observe(instance: Instance): (() -> ())?
		if not instance:IsA("BasePart") then
			log:warn(`{instance:GetFullName()} is tagged {QueueConstants.TAG} but is not a BasePart`)
			return nil
		end
		local pad: BasePart = instance
		local config, reason = QueuePadRules.config(
			pad:GetAttribute(QueueConstants.CAPACITY_ATTRIBUTE),
			pad:GetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE),
			pad:GetAttribute(QueueConstants.DESTINATION_ATTRIBUTE)
		)
		if config == nil then
			log:warn(`{pad:GetFullName()} is not a usable queue pad: {reason or "?"}`)
			return nil
		end
		nextId += 1
		local padId = `pad{nextId}`
		tracker:add(padId, config)
		padById[padId] = pad
		idByPad[pad] = padId
		table.insert(order, padId)
		onChanged()
		return function()
			tracker:remove(padId)
			padById[padId] = nil
			idByPad[pad] = nil
			local index = table.find(order, padId)
			if index ~= nil then
				table.remove(order, index)
			end
			onChanged()
		end
	end

	local system: QueuePadSystem
	system = {
		start = function(_self)
			stopObserving = Observers.observeTag(QueueConstants.TAG, observe)
		end,

		stop = function(_self)
			local stopFn = stopObserving
			if stopFn ~= nil then
				stopFn()
				stopObserving = nil
			end
		end,

		-- One sample: who stands on each pad, then every pad whose countdown ended departs.
		step = function(_self, now)
			local positions = rootPositions()
			local changed = false
			for _, padId in order do
				local pad = padById[padId]
				if pad ~= nil then
					local aboard: { number } = {}
					for userId, position in positions do
						if QueuePadRules.isAboard(pad.CFrame, pad.Size, position, QueueConstants.ABOARD_HEIGHT) then
							table.insert(aboard, userId)
						end
					end
					table.sort(aboard)
					if tracker:sync(padId, aboard, now) then
						changed = true
					end
				end
			end
			for _, padId in tracker:due(now) do
				local pad = padById[padId]
				local config = tracker:config(padId)
				local party = playersOf(tracker:lock(padId))
				changed = true
				if pad ~= nil and config ~= nil then
					onDue(pad, config, party)
				end
			end
			if changed then
				onChanged()
			end
		end,

		departNow = function(_self, player, now)
			if tracker:departNow(player.UserId, now) == nil then
				return false
			end
			onChanged()
			return true
		end,

		unlock = function(_self, pad)
			local padId = idByPad[pad]
			if padId ~= nil then
				tracker:unlock(padId)
				onChanged()
			end
		end,

		forget = function(_self, player)
			if tracker:forget(player.UserId) then
				onChanged()
			end
		end,

		padOf = function(_self, player)
			local padId = tracker:padOf(player.UserId)
			return if padId ~= nil then padById[padId] else nil
		end,

		snapshot = function(_self)
			return tracker:snapshot()
		end,

		count = function(_self)
			return #order
		end,
	}
	return system
end

return QueuePadSystem
```

- [ ] **Step 3: Check `IsA` narrowing.** If luau-lsp reports `local pad: BasePart = instance` as a type mismatch (no `IsA` refinement in this setup), replace the `IsA` guard with `if not instance:IsA("BasePart") then ... end` followed by `local pad = instance :: BasePart -- IsA("BasePart") was checked on the line above; luau-lsp does not refine through IsA here` and flag the cast for sign-off in the report. Try the uncast version first: `InteractionServiceServer.rootPartOf` and `rootPositions` above already rely on `IsA` refinement.

- [ ] **Step 4: The teleport system** `src/ServerScriptService/Features/Queue/Systems/QueueTeleportSystem.luau`:

```lua
--!strict
--[=[
	QueueTeleportSystem: sends players to another place and sees each teleport through. A departure that
	reserves reserves ONE server (ReserveServer) and keeps its access code, so every retry, including a
	retry for only the players a partial failure hit, lands in that same server. A failure (ReserveServer or
	TeleportAsync erroring, TeleportInitFailed, or a player still here TELEPORT_WATCHDOG seconds after the
	attempt) is retried on QueueTeleportRules' schedule; after the last retry the player is given up on.
	`onFinished` runs once per departure with the players given up on (empty when everyone left).

	ReserveServer and TeleportAsync error in Studio; that is why QueueServiceServer routes Studio as a local
	move. Spec-exempt shell (TeleportService, Players); the bookkeeping is the specced QueueDepartureTracker
	and the schedule the specced QueueTeleportRules.

	@class QueueTeleportSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueDepartureTracker = require(ServerScriptService.Features.Queue.State.QueueDepartureTracker)
local QueueTeleportRules = require(ServerScriptService.Features.Queue.Rules.QueueTeleportRules)

export type OnFinished = (gaveUp: { Player }, reason: string?) -> ()

export type Request = {
	players: { Player },
	placeId: number,
	-- Reserve a fresh server (a party going out), or join any public server (a trip home, a redirect).
	reserve: boolean,
	-- JSON teleport data, or nil for none.
	data: string?,
	onFinished: OnFinished,
}

export type QueueTeleportSystem = {
	send: (self: QueueTeleportSystem, request: Request) -> (),
	initFailed: (self: QueueTeleportSystem, player: Player, reason: string) -> (),
	left: (self: QueueTeleportSystem, player: Player) -> (),
	step: (self: QueueTeleportSystem, now: number) -> (),
	inFlight: (self: QueueTeleportSystem) -> number,
}

type Record = {
	request: Request,
	accessCode: string?,
	players: { [number]: Player },
}

local log = Logger.new("QueueTeleportSystem")

local QueueTeleportSystem = {}

function QueueTeleportSystem.new(): QueueTeleportSystem
	local tracker = QueueDepartureTracker.new()
	local records: { [number]: Record } = {}

	-- Reports a departure once nobody in it is outstanding.
	local function settle(id: number)
		local record = records[id]
		if record == nil then
			return
		end
		local outcome = tracker:finished(id)
		if outcome == nil then
			return
		end
		records[id] = nil
		local gaveUp: { Player } = {}
		for _, userId in outcome.gaveUp do
			local player = record.players[userId]
			if player ~= nil and player.Parent == Players then
				table.insert(gaveUp, player)
			end
		end
		local ok, err = pcall(record.request.onFinished, gaveUp, outcome.reason)
		if not ok then
			log:error(`onFinished failed: {tostring(err)}`)
		end
	end

	local attempt: (id: number, players: { Player }) -> ()

	-- Counts a failure for each player; retries them on the schedule or gives up on them.
	local function fail(id: number, players: { Player }, reason: string)
		local retry: { [number]: { Player } } = {}
		for _, player in players do
			local failures = tracker:fail(player.UserId)
			if failures ~= nil then
				local delay = QueueTeleportRules.retryDelay(failures)
				if delay == nil then
					log:warn(`giving up teleporting {player.Name}: {reason}`)
					tracker:giveUp(player.UserId, reason)
				else
					local group = retry[delay] or {}
					table.insert(group, player)
					retry[delay] = group
				end
			end
		end
		for delay, group in retry do
			log:info(`retrying {#group} player(s) in {delay}s: {reason}`)
			task.delay(delay, attempt, id, group)
		end
		settle(id)
	end

	attempt = function(id, players)
		local record = records[id]
		if record == nil then
			return
		end
		local present: { Player } = {}
		local now = os.clock()
		for _, player in players do
			if player.Parent == Players and tracker:departureOf(player.UserId) == id then
				table.insert(present, player)
				tracker:attempt(player.UserId, now)
			end
		end
		if #present == 0 then
			settle(id)
			return
		end
		local request = record.request
		if request.reserve and record.accessCode == nil then
			local ok, result = pcall(function(): string
				local code = TeleportService:ReserveServer(request.placeId)
				return code
			end)
			if not ok then
				fail(id, present, `ReserveServer failed: {tostring(result)}`)
				return
			end
			record.accessCode = result
		end
		local options = Instance.new("TeleportOptions")
		local code = record.accessCode
		if code ~= nil then
			options.ReservedServerAccessCode = code
		end
		local data = request.data
		if data ~= nil then
			options:SetTeleportData(data)
		end
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(request.placeId, present, options)
		end)
		if not ok then
			fail(id, present, `TeleportAsync failed: {tostring(err)}`)
		end
	end

	local system: QueueTeleportSystem
	system = {
		send = function(_self, request)
			local ids: { number } = {}
			local byId: { [number]: Player } = {}
			for _, player in request.players do
				table.insert(ids, player.UserId)
				byId[player.UserId] = player
			end
			local id = tracker:begin(ids)
			records[id] = { request = request, accessCode = nil, players = byId }
			task.spawn(attempt, id, request.players)
		end,

		-- TeleportInitFailed, or the watchdog: the player's attempt failed.
		initFailed = function(_self, player, reason)
			local id = tracker:departureOf(player.UserId)
			if id ~= nil then
				fail(id, { player }, reason)
			end
		end,

		-- The player left the server (teleported, or quit): no longer outstanding.
		left = function(_self, player)
			local id = tracker:arrive(player.UserId)
			if id ~= nil then
				settle(id)
			end
		end,

		step = function(self, now)
			for _, userId in tracker:stale(now, QueueConstants.TELEPORT_WATCHDOG) do
				local player = Players:GetPlayerByUserId(userId)
				if player ~= nil then
					self:initFailed(player, "teleport timed out")
				end
			end
		end,

		inFlight = function(_self)
			local count = 0
			for _ in records do
				count += 1
			end
			return count
		end,
	}
	return system
end

return QueueTeleportSystem
```

- [ ] **Step 5: The arrival system** `src/ServerScriptService/Features/Queue/Systems/QueueArrivalSystem.luau`:

```lua
--!strict
--[=[
	QueueArrivalSystem: the arriving side of a reserved server. Each joining player's ticket (read by the
	service from their join data) tells the specced QueueArrivalTracker who is expected; the tracker decides
	each admission. When the party is complete or the wait runs out, `onArrived` gets the crew (possibly
	empty if everyone left). A redirected stranger goes to `onRedirect`; an expected straggler who comes
	after the start goes to `onLate`.

	Joins are handled once every service has started (ServiceController phase "running"), so a game's
	`arrived` listener is always connected before the party can be reported.

	Spec-exempt shell (Players, join data only exist after a live teleport).

	@class QueueArrivalSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceController = require(ReplicatedStorage.Shared.Core.ServiceController)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueueArrivalTracker = require(ServerScriptService.Features.Queue.State.QueueArrivalTracker)

type QueueTicket = QueueTypes.QueueTicket

export type Hooks = {
	ticketOf: (player: Player) -> QueueTicket?,
	onArrived: (crew: { Player }, ticket: QueueTicket?) -> (),
	onLate: (player: Player) -> (),
	onRedirect: (player: Player, ticket: QueueTicket?) -> (),
}

export type QueueArrivalSystem = {
	start: (self: QueueArrivalSystem) -> (),
	stop: (self: QueueArrivalSystem) -> (),
	step: (self: QueueArrivalSystem, now: number) -> (),
	getState: (self: QueueArrivalSystem) -> { crew: { number }, closed: boolean },
}

local QueueArrivalSystem = {}

function QueueArrivalSystem.new(hooks: Hooks): QueueArrivalSystem
	local tracker = QueueArrivalTracker.new(QueueConstants.ARRIVAL_TIMEOUT, QueueConstants.DEFAULT_CAPACITY)
	local waiting: { Player } = {}
	local connections: { RBXScriptConnection } = {}

	local function admit(player: Player, now: number)
		local ticket = hooks.ticketOf(player)
		if ticket ~= nil and ticket.kind == "depart" then
			tracker:expect(ticket, now)
		end
		local admission = tracker:join(player.UserId, now)
		if admission == "redirect" then
			hooks.onRedirect(player, tracker:ticket())
		elseif admission == "late" then
			hooks.onLate(player)
		end
	end

	local system: QueueArrivalSystem
	system = {
		start = function(_self)
			for _, player in Players:GetPlayers() do
				table.insert(waiting, player)
			end
			table.insert(
				connections,
				Players.PlayerAdded:Connect(function(player)
					table.insert(waiting, player)
				end)
			)
			table.insert(
				connections,
				Players.PlayerRemoving:Connect(function(player)
					local index = table.find(waiting, player)
					if index ~= nil then
						table.remove(waiting, index)
					end
					tracker:leave(player.UserId)
				end)
			)
		end,

		stop = function(_self)
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end,

		step = function(_self, now)
			if ServiceController:getPhase() ~= "running" then
				return
			end
			local joining = waiting
			waiting = {}
			for _, player in joining do
				if player.Parent == Players then
					admit(player, now)
				end
			end
			if tracker:ready(now) then
				local crew: { Player } = {}
				for _, userId in tracker:close() do
					local player = Players:GetPlayerByUserId(userId)
					if player ~= nil then
						table.insert(crew, player)
					end
				end
				hooks.onArrived(crew, tracker:ticket())
			end
		end,

		getState = function(_self)
			return { crew = tracker:crew(), closed = tracker:isClosed() }
		end,
	}
	return system
end

return QueueArrivalSystem
```

- [ ] **Step 6: The service** `src/ServerScriptService/Features/Queue/QueueServiceServer.luau`:

```lua
--!strict
--[=[
	QueueServiceServer: parties that travel together between the places of one experience (spec:
	docs/superpowers/specs/2026-10-10-cleanup-crew-design.md §6.1, the Queue row).

	- Pads: a BasePart tagged `QueuePad` (attributes QueueCapacity, QueueCountdown, QueueDestination) holds
	  a party. Standing on it joins, leaving leaves; with anyone aboard a countdown runs (reset on each
	  join) and anyone aboard can Depart now (`departNow`, or the client's button). Published to every
	  client as the `queue` world entry.
	- Roles: a game registers its place-role table in QueueRegistry ("depot", "shift", any strings). In
	  Studio or on an unknown PlaceId every role runs in this one server ("local" mode) and a teleport
	  becomes a move to the role's arrival point (`setArrivalPoint`), so the loop plays through rojo serve.
	- Departing (live): a fresh reserved server, the party teleported with a ticket (expected user ids and
	  the game's payload from `setDepartData`), retried on failure (3 retries, backing off); after the last
	  the party is back on its pad with a toast and `departFailed` fires.
	- Arriving (a reserved server): waits up to ARRIVAL_TIMEOUT for the expected party, then fires
	  `arrived(party, payload)` with whoever came. Strangers become crew while there is room, else they are
	  sent to the home role (`configure({ homeRole })`, default: where the party came from). A local move
	  fires `arrived` the same way.
	- Returning: `returnParty(players, role, payload)` sends players to any public server of that role;
	  `returned(player, payload)` fires where they land (live or local), and `returnPayloadOf` keeps the
	  payload for a game that reads it later (a result card).

	The last player leaving a reserved server needs no code: Roblox shuts an empty server down.

	Spec-exempt shell (TeleportService, Players, HttpService, signals); the decisions are the specced
	QueuePadRules, QueuePlaceRules, QueueTeleportRules, QueuePadTracker, QueueDepartureTracker and
	QueueArrivalTracker.

	@class QueueServiceServer
]=]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local QueueShared = ReplicatedStorage.Shared.Features.Queue
local QueueServer = ServerScriptService.Features.Queue
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ServiceController = require(ReplicatedStorage.Shared.Core.ServiceController)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(QueueShared.Data.QueueConstants)
local QueueEvents = require(QueueShared.Net.QueueEvents)
local QueueTypes = require(QueueShared.Data.QueueTypes)
local QueueRegistry = require(QueueServer.Data.QueueRegistry)
local QueuePlaceRules = require(QueueServer.Rules.QueuePlaceRules)
local QueueTeleportRules = require(QueueServer.Rules.QueueTeleportRules)
local QueueArrivalSystem = require(QueueServer.Systems.QueueArrivalSystem)
local QueuePadSystem = require(QueueServer.Systems.QueuePadSystem)
local QueueTeleportSystem = require(QueueServer.Systems.QueueTeleportSystem)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type QueuePayload = QueueTypes.QueuePayload
type QueueTicket = QueueTypes.QueueTicket

local log = Logger.new("QueueServiceServer")

local arrived: SignalTyped.Signal<{ Player }, QueuePayload> = SignalTyped.new()
local joinedLate: SignalTyped.Signal<Player> = SignalTyped.new()
local returned: SignalTyped.Signal<Player, QueuePayload> = SignalTyped.new()
local departing: SignalTyped.Signal<BasePart, { Player }> = SignalTyped.new()
local departFailed: SignalTyped.Signal<BasePart, { Player }, string> = SignalTyped.new()

local config: QueueTypes.QueueConfig = { homeRole = nil, forceLive = false }
local departData: QueueTypes.DepartDataResolver? = nil
local arrivalPoints: { [string]: QueueTypes.ArrivalPoint } = {}
local returnPayloads: { [Player]: QueuePayload } = {}
local pendingReturns: { Player } = {}
local counters = { departures = 0, localMoves = 0, failures = 0, arrivals = 0, redirects = 0, returns = 0 }
local connections: { RBXScriptConnection } = {}
local stoppers: { () -> () } = {}
local arrivalsActive = false
local publishScheduled = false
local accumulated = 0

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function currentMode(): QueueTypes.Mode
	return QueuePlaceRules.mode(game.PlaceId, RunService:IsStudio(), config.forceLive, QueueRegistry.roles())
end

local function currentRole(): string?
	return QueuePlaceRules.roleOf(game.PlaceId, QueueRegistry.roles())
end

local function idsOf(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function toast(players: { Player }, text: string)
	for _, player in players do
		ToastServiceServer:send(player, { text = text })
	end
end

-- A local move (Studio, an unknown place or a placeholder role): each player to the role's arrival point.
local function moveLocally(players: { Player }, role: string)
	counters.localMoves += 1
	local resolver = arrivalPoints[role]
	if resolver == nil then
		log:warn(`no arrival point for role "{role}"; players stay where they are`)
		return
	end
	for index, player in players do
		local ok, result = pcall(resolver, player, index)
		local character = player.Character
		if not ok then
			log:error(`arrival point for "{role}" errored: {tostring(result)}`)
		elseif typeof(result) == "CFrame" then
			if character ~= nil then
				character:PivotTo(result)
			end
		elseif result ~= nil then
			log:warn(`arrival point for "{role}" returned a {typeof(result)}, not a CFrame`)
		end
	end
end

local function payloadFor(pad: BasePart, party: { Player }): QueuePayload
	local resolver = departData
	if resolver == nil then
		return {}
	end
	local ok, result = pcall(resolver, pad, party)
	if not ok then
		log:error(`depart data errored: {tostring(result)}`)
		return {}
	end
	local clean, reason = QueueTeleportRules.payload(result)
	if clean == nil then
		log:error(`depart data refused: {reason or "?"}`)
		return {}
	end
	return clean
end

local teleports = QueueTeleportSystem.new()
-- Assigned below, once `depart` (which unlocks pads) exists.
local pads: QueuePadSystem.QueuePadSystem

-- Republishes the pads as the `queue` world entry, at most once per frame.
local function publish()
	if publishScheduled then
		return
	end
	publishScheduled = true
	task.defer(function()
		publishScheduled = false
		StateSyncWorldStore.set(QueueConstants.WORLD_ENTRY, pads:snapshot())
	end)
end

local function failDeparture(pad: BasePart, party: { Player }, reason: string)
	counters.failures += 1
	log:warn(`departure from {pad:GetFullName()} failed: {reason}`)
	toast(party, QueueConstants.DEPART_FAILED_TEXT)
	pads:unlock(pad)
	departFailed:Fire(pad, party, reason)
end

local function sendParty(
	pad: BasePart,
	padConfig: QueueTypes.PadConfig,
	party: { Player },
	payload: QueuePayload,
	placeId: number
)
	local ticket: QueueTicket = {
		kind = "depart",
		from = currentRole(),
		role = padConfig.destination,
		party = idsOf(party),
		capacity = padConfig.capacity,
		payload = payload,
	}
	teleports:send({
		players = party,
		placeId = placeId,
		reserve = true,
		data = HttpService:JSONEncode(QueueTeleportRules.encode(ticket)),
		onFinished = function(gaveUp, reason)
			pads:unlock(pad)
			if #gaveUp > 0 then
				failDeparture(pad, gaveUp, reason or "teleport failed")
			end
		end,
	})
end

-- A pad's countdown ended (or someone pressed Depart now): its frozen party leaves.
local function depart(pad: BasePart, padConfig: QueueTypes.PadConfig, party: { Player })
	if #party == 0 then
		pads:unlock(pad)
		return
	end
	counters.departures += 1
	departing:Fire(pad, party)
	local payload = payloadFor(pad, party)
	local route, reason = QueuePlaceRules.route(currentMode(), padConfig.destination, QueueRegistry.roles())
	if route == nil then
		failDeparture(pad, party, reason or "no route")
	elseif route.kind == "teleport" then
		sendParty(pad, padConfig, party, payload, route.placeId)
	else
		moveLocally(party, padConfig.destination)
		pads:unlock(pad)
		task.defer(function()
			counters.arrivals += 1
			arrived:Fire(party, payload)
		end)
	end
end

pads = QueuePadSystem.new(depart, publish)

-- The Queue ticket in a player's join data, or nil (none, not ours, or forged).
local function ticketOf(player: Player): QueueTicket?
	local raw = player:GetJoinData().TeleportData
	if type(raw) ~= "string" then
		return nil
	end
	local ok, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return nil
	end
	-- JSONDecode is typed `any`; QueueTeleportRules.decode checks every field, so it is the trust boundary.
	local value: WorldTypes.WorldValue? = parsed
	return QueueTeleportRules.decode(value)
end

-- `returned` fires from the tick once every service has started, so a game's listener never misses one.
local function queueReturn(player: Player, payload: QueuePayload)
	returnPayloads[player] = payload
	table.insert(pendingReturns, player)
end

local function noteReturn(player: Player)
	local ticket = ticketOf(player)
	if ticket ~= nil and ticket.kind == "return" then
		queueReturn(player, ticket.payload)
	end
end

local function flushReturns()
	if #pendingReturns == 0 or ServiceController:getPhase() ~= "running" then
		return
	end
	local list = pendingReturns
	pendingReturns = {}
	for _, player in list do
		local payload = returnPayloads[player]
		if payload ~= nil and player.Parent == Players then
			counters.returns += 1
			returned:Fire(player, payload)
		end
	end
end

-- A stranger in a full arrival server: off to a public server of the home role, kicked if there is none.
local function redirect(player: Player, ticket: QueueTicket?)
	counters.redirects += 1
	local home = config.homeRole or (if ticket ~= nil then ticket.from else nil)
	local route = if home ~= nil then QueuePlaceRules.route("live", home, QueueRegistry.roles()) else nil
	if route ~= nil and route.kind == "teleport" then
		teleports:send({
			players = { player },
			placeId = route.placeId,
			reserve = false,
			data = nil,
			onFinished = function(gaveUp)
				for _, stuck in gaveUp do
					stuck:Kick(QueueConstants.REDIRECT_KICK_TEXT)
				end
			end,
		})
		return
	end
	log:warn(`no home role to send {player.Name} to; removing them from the full server`)
	player:Kick(QueueConstants.REDIRECT_KICK_TEXT)
end

local arrivals = QueueArrivalSystem.new({
	ticketOf = ticketOf,
	onArrived = function(crew, ticket)
		counters.arrivals += 1
		arrived:Fire(crew, if ticket ~= nil then ticket.payload else {})
	end,
	onLate = function(player)
		joinedLate:Fire(player)
	end,
	onRedirect = redirect,
})

local onDepart = RequestHandler.wrap({
	name = "QueueDepart",
	rateLimit = { maxRequests = 5, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		pads:departNow(player, serverNow())
	end,
})

local function tick()
	pads:step(serverNow())
	teleports:step(os.clock())
	if arrivalsActive then
		arrivals:step(os.clock())
	end
	flushReturns()
end

export type QueueServiceServer = {
	dependencies: { string },
	arrived: SignalTyped.Signal<{ Player }, QueuePayload>,
	joinedLate: SignalTyped.Signal<Player>,
	returned: SignalTyped.Signal<Player, QueuePayload>,
	departing: SignalTyped.Signal<BasePart, { Player }>,
	departFailed: SignalTyped.Signal<BasePart, { Player }, string>,

	start: (self: QueueServiceServer) -> (),
	stop: (self: QueueServiceServer) -> (),
	getState: (self: QueueServiceServer) -> { [string]: any },

	configure: (self: QueueServiceServer, update: QueueTypes.QueueConfigUpdate) -> (),
	setDepartData: (self: QueueServiceServer, resolver: QueueTypes.DepartDataResolver?) -> (),
	setArrivalPoint: (self: QueueServiceServer, role: string, resolver: QueueTypes.ArrivalPoint?) -> (),
	departNow: (self: QueueServiceServer, player: Player) -> boolean,
	padOf: (self: QueueServiceServer, player: Player) -> BasePart?,
	returnParty: (self: QueueServiceServer, players: { Player }, role: string, payload: QueuePayload?) -> boolean,
	returnPayloadOf: (self: QueueServiceServer, player: Player) -> QueuePayload?,
	mode: (self: QueueServiceServer) -> QueueTypes.Mode,
	role: (self: QueueServiceServer) -> string?,
	runsRole: (self: QueueServiceServer, role: string) -> boolean,
}

local QueueServiceServer: QueueServiceServer = {
	dependencies = { "StateSyncServiceServer", "ToastServiceServer" },
	arrived = arrived,
	joinedLate = joinedLate,
	returned = returned,
	departing = departing,
	departFailed = departFailed,

	--[=[
		Starts the pads, the arrival side on a reserved server (or return handling on a public live
		server), the Depart-now packet and the tick.
	]=]
	start = function(_self)
		local mode = currentMode()
		local reserved = QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId)
		pads:start()
		publish()
		if mode == "live" and reserved then
			arrivalsActive = true
			arrivals:start()
		elseif mode == "live" then
			for _, player in Players:GetPlayers() do
				noteReturn(player)
			end
			table.insert(connections, Players.PlayerAdded:Connect(noteReturn))
		end
		table.insert(
			connections,
			Players.PlayerRemoving:Connect(function(player)
				teleports:left(player)
				pads:forget(player)
				returnPayloads[player] = nil
			end)
		)
		table.insert(
			connections,
			TeleportService.TeleportInitFailed:Connect(function(player, result, message)
				teleports:initFailed(player, `{result.Name}: {message}`)
			end)
		)
		table.insert(
			stoppers,
			QueueEvents.packets.Depart.listen(function(data: boolean, player: Player?)
				if player then
					onDepart(data, player)
				end
			end)
		)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(deltaTime)
				accumulated += deltaTime
				if accumulated >= QueueConstants.TICK_INTERVAL then
					accumulated = 0
					tick()
				end
			end)
		)
		log:info(`queue in {mode} mode, role {currentRole() or "none"}{if reserved then ", reserved server" else ""}`)
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		pads:stop()
		arrivals:stop()
		arrivalsActive = false
		StateSyncWorldStore.clear(QueueConstants.WORLD_ENTRY)
	end,

	configure = function(_self, update)
		local homeRole = update.homeRole
		if homeRole ~= nil then
			config.homeRole = homeRole
		end
		local forceLive = update.forceLive
		if forceLive ~= nil then
			config.forceLive = forceLive
		end
	end,

	--[=[
		Sets how a departing party's payload is built (a contract id). Nil sends `{}`.
	]=]
	setDepartData = function(_self, resolver)
		departData = resolver
	end,

	--[=[
		Sets where a local move puts players for `role` (Studio, unknown place, placeholder role). Nil clears.
	]=]
	setArrivalPoint = function(_self, role, resolver)
		arrivalPoints[role] = resolver
	end,

	--[=[
		Depart now for the player's pad (a game's own button or prompt). False when they are not aboard an
		open pad.
	]=]
	departNow = function(_self, player)
		return pads:departNow(player, serverNow())
	end,

	padOf = function(_self, player)
		return pads:padOf(player)
	end,

	--[=[
		Sends `players` to any public server of `role` with `payload` (a result card). False, with a
		warning, for an empty or oversized party, a payload over the limits or an unregistered role.
	]=]
	returnParty = function(_self, players, role, payload)
		local clean, reason = QueueTeleportRules.payload(payload)
		if clean == nil then
			log:warn(`returnParty refused: {reason or "?"}`)
			return false
		end
		if #players == 0 or #players > QueueConstants.MAX_CAPACITY then
			log:warn(`returnParty refused: {#players} players`)
			return false
		end
		local route, routeReason = QueuePlaceRules.route(currentMode(), role, QueueRegistry.roles())
		if route == nil then
			log:warn(`returnParty refused: {routeReason or "?"}`)
			return false
		end
		if route.kind == "teleport" then
			local ticket: QueueTicket = {
				kind = "return",
				from = currentRole(),
				role = role,
				party = idsOf(players),
				capacity = #players,
				payload = clean,
			}
			teleports:send({
				players = players,
				placeId = route.placeId,
				reserve = false,
				data = HttpService:JSONEncode(QueueTeleportRules.encode(ticket)),
				onFinished = function(gaveUp, failReason)
					if #gaveUp > 0 then
						log:warn(`return trip failed for {#gaveUp} player(s): {failReason or "?"}`)
						toast(gaveUp, QueueConstants.RETURN_FAILED_TEXT)
					end
				end,
			})
		else
			moveLocally(players, role)
			for _, player in players do
				queueReturn(player, clean)
			end
		end
		return true
	end,

	returnPayloadOf = function(_self, player)
		return returnPayloads[player]
	end,

	mode = function(_self)
		return currentMode()
	end,

	role = function(_self)
		return currentRole()
	end,

	runsRole = function(_self, role)
		return QueuePlaceRules.runsRole(currentMode(), currentRole(), role)
	end,

	getState = function(_self)
		return {
			mode = currentMode(),
			role = currentRole() or "none",
			pads = pads:count(),
			inFlight = teleports:inFlight(),
			arrival = if arrivalsActive then arrivals:getState() else nil,
			counters = table.clone(counters),
		}
	end,
}

return QueueServiceServer
```

Notes for the implementer (verify, do not guess):
- `route.kind == "teleport"` narrows the `Route` union so `route.placeId` types. If luau-lsp does not narrow here, restructure to `if route.kind == "local" then ... else ... end` the same way; never cast.
- `player:GetJoinData().TeleportData` is typed `TeleportData?` (globalTypes.d.luau line 15140); `type(raw) ~= "string"` narrows it to `string`.
- `pcall(resolver, player, index)` returns `(boolean, CFrame?)`; `typeof(result) == "CFrame"` is the runtime check because a game's resolver is outside the type system at runtime.
- `getState`'s `{ [string]: any }` is the existing service convention (RoundServiceServer, ToastServiceServer); do not add `any` anywhere else.

- [ ] **Step 7: Exemptions and the feature list.** Add to `EXEMPT_MODULES` after the two Queue entries from Task 1:

```lua
	["ReplicatedStorage.Shared.Features.Queue.Net.QueueEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Queue.Systems.QueuePadSystem"] = "CollectionService/character shell (QueuePadRules and QueuePadTracker are specced)",
	["ServerScriptService.Features.Queue.Systems.QueueTeleportSystem"] = "TeleportService shell; teleports cannot run in Studio (QueueDepartureTracker and QueueTeleportRules are specced)",
	["ServerScriptService.Features.Queue.Systems.QueueArrivalSystem"] = "Players/join-data shell; join data exists only after a live teleport (QueueArrivalTracker is specced)",
	["ServerScriptService.Features.Queue.QueueServiceServer"] = "TeleportService/Players/HttpService/signal shell (rules and trackers are specced)",
```
In `docs/project-structure.md`, **Feature names** list: insert `Queue` after `PlayerData` (alphabetical): `... Npc, PlayerData, Queue, Round, Setting, ...`.

- [ ] **Step 8: Studio verification (controller).** First a TestEZ run (`RunTests = true`): every Queue spec passes and `assertAllModulesSpecced` passes. Then turn `RunTests` off, insert this as a **Script in Workspace** named `QueueVerify`, Play Solo, read Output, stop, delete the Script:

```lua
-- QueueVerify: temporary Studio check for the base Queue feature (delete after the run).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Queue = require(ServerScriptService.Features.Queue.QueueServiceServer)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
task.wait(3) -- every service has started

local function check(label, ok)
	print((if ok then "[PASS] " else "[FAIL] ") .. label)
end

for role, placeId in { ["verify-home"] = 0, ["verify-away"] = 0, ["verify-live"] = 920000001 } do
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end
local HOME = CFrame.new(0, 5, -60)
local AWAY = CFrame.new(300, 5, 0)
Queue:setArrivalPoint("verify-home", function()
	return HOME
end)
Queue:setArrivalPoint("verify-away", function(_, index)
	return AWAY + Vector3.new(index * 4, 0, 0)
end)
Queue:setDepartData(function(_pad, party)
	return { contract = "verify-1", size = #party }
end)

local arrivedWith, failedReason, returnedWith = nil, nil, nil
Queue.arrived:Connect(function(party, payload)
	arrivedWith = { count = #party, contract = payload.contract, size = payload.size }
end)
Queue.returned:Connect(function(who, payload)
	returnedWith = { name = who.Name, result = payload.result }
end)

local function stepOff()
	character:PivotTo(CFrame.new(0, 5, 60))
end
Queue.departFailed:Connect(function(_pad, _party, reason)
	failedReason = reason
	stepOff()
end)

local function makePad(name, x, countdown, destination)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Anchored = true
	pad.Size = Vector3.new(10, 1, 10)
	pad.Position = Vector3.new(x, 0.5, 40)
	pad:SetAttribute("QueueCapacity", 4)
	pad:SetAttribute("QueueCountdown", countdown)
	pad:SetAttribute("QueueDestination", destination)
	pad.Parent = workspace
	CollectionService:AddTag(pad, "QueuePad")
	task.wait(0.5)
	return pad
end
local function stand(pad)
	character:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
end
local function entryFor(userId)
	local entry = StateSyncWorldStore.get("queue")
	if type(entry) ~= "table" then
		return nil
	end
	for _, pad in entry.pads do
		for _, id in pad.members or {} do
			if id == userId then
				return pad
			end
		end
	end
	return nil
end

check("Studio runs in local mode and runs every role", Queue:mode() == "local" and Queue:runsRole("verify-away"))

-- 1. Countdown → local move → arrived(party, payload)
local padA = makePad("VerifyPadA", 0, 3, "verify-away")
stand(padA)
task.wait(1)
check("1a player is aboard pad A", Queue:padOf(player) == padA)
local seen = entryFor(player.UserId)
check("1b world entry shows them with a countdown", seen ~= nil and seen.endsAt ~= nil and seen.capacity == 4)
task.wait(3)
check(
	"1c arrived fired with the party and payload",
	arrivedWith ~= nil and arrivedWith.count == 1 and arrivedWith.contract == "verify-1" and arrivedWith.size == 1
)
check("1d moved to the arrival point", (character:GetPivot().Position - (AWAY.Position + Vector3.new(4, 0, 0))).Magnitude < 6)
check("1e pad A reopened", Queue:padOf(player) == nil)

-- 2. Stepping off leaves the party
local padB = makePad("VerifyPadB", 30, 30, "verify-away")
arrivedWith = nil
stand(padB)
task.wait(1)
check("2a aboard pad B", Queue:padOf(player) == padB)
stepOff()
task.wait(1)
check("2b stepping off leaves the party", Queue:padOf(player) == nil and entryFor(player.UserId) == nil)

-- 3. Depart now
stand(padB)
task.wait(1)
check("3a Depart now accepted for a member", Queue:departNow(player) == true)
task.wait(1)
check("3b departed at once", arrivedWith ~= nil)
check("3c Depart now refused when not aboard", Queue:departNow(player) == false)

-- 4. A pad without a destination is ignored (expect a "not a usable queue pad" warning above)
local bad = makePad("VerifyPadBad", 60, 3, "")
stand(bad)
task.wait(1)
check("4 a pad without a destination is ignored", Queue:padOf(player) == nil)

-- 5. An unregistered destination fails into a toast + departFailed, and the pad reopens
local nowhere = makePad("VerifyPadNowhere", 90, 1, "verify-nowhere")
failedReason = nil
stand(nowhere)
task.wait(2.5)
check("5 unregistered destination fails with a reason", failedReason ~= nil and string.find(failedReason, "not registered") ~= nil)

-- 6. Forced live: Studio cannot teleport, so 3 retries back off (1 + 2 + 4 s), then the party is back on its pad
Queue:configure({ forceLive = true })
local live = makePad("VerifyPadLive", 120, 1, "verify-live")
failedReason = nil
local started = os.clock()
stand(live)
while failedReason == nil and os.clock() - started < 40 do
	task.wait(0.25)
end
local took = os.clock() - started
check("6a a failing teleport gives up after the retries", failedReason ~= nil)
check(`6b the retries backed off (took {math.floor(took)}s, expect >= 8)`, took >= 8)
Queue:configure({ forceLive = false })

-- 7. Return trip (local): returned(player, payload) and a move to the role's arrival point
returnedWith = nil
check("7a returnParty accepted", Queue:returnParty({ player }, "verify-home", { result = "cleared" }) == true)
task.wait(1)
check("7b returned fired with the payload", returnedWith ~= nil and returnedWith.result == "cleared")
check("7c moved home", (character:GetPivot().Position - HOME.Position).Magnitude < 6)
check("7d payload kept for later reads", Queue:returnPayloadOf(player) ~= nil)
check("7e refuses an unregistered role", Queue:returnParty({ player }, "verify-nowhere", nil) == false)
check("7f refuses an oversized payload", Queue:returnParty({ player }, "verify-home", { big = string.rep("x", 2000) }) == false)

for _, pad in { padA, padB, bad, nowhere, live } do
	pad:Destroy()
end
print("QueueVerify done")
```
Expected: every line `[PASS]`; above them a `VerifyPadBad ... is not a usable queue pad: QueueDestination must name a role` warning; for item 6 three `retrying 1 player(s) in 1s / 2s / 4s: ReserveServer failed: ...` info lines and a `giving up teleporting ...` warning; the toast `Couldn't leave. You're back on the pad.` on screen after items 5 and 6 (screenshot it); `queue in local mode, role none` in the boot log. If 6a fails with the 40 s timeout, ReserveServer is hanging rather than erroring in Studio: report it (the watchdog covers TeleportAsync, not ReserveServer). The live path itself (real reserved servers, arrival wait, strangers, return) is verified in the M4 publish walkthrough (Task 6 PR body checklist); Studio cannot run it.

- [ ] **Step 9: Module map, gate, commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Queue src/ServerScriptService/Features/Queue src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
bash .superpowers/sdd/gate.sh
git commit -m "feat(queue): pads, reserved-server teleports with retries, arrivals and return trips"
python3 scripts/python/module_map.py --check
```

---

### Task 5: Client: store, service and the placeholder pad widget

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Queue/State/QueueStore.luau` + `QueueStore.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Queue/QueueServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadPanel.luau` + `QueuePadPanel.story.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadStatus.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (three exemptions)

**Interfaces:**
- Consumes: `QueueSnapshotUtils.decode` / `padOf`, `QueueConstants.WORLD_ENTRY`, `QueueTypes.QueueSnapshot` / `PadSnapshot` (Tasks 1–2); `QueueEvents.packets.Depart` (Task 4); `StateSyncClientStore.world` (Charm atom of `WorldTypes.WorldMap`); `HudRegistry.register(key, widget, order)` / `has(key)`; `Button` (`text, onActivated, variant?, disabled?, layoutOrder?`) and `Panel` (`title?, children?`) primitives; `Tokens`.
- Produces (QueueStore): `snapshot: () -> QueueSnapshot?` (Charm computed), `widgetEnabled: Charm atom<boolean>` (default true), `padFor(userId) -> (string?, PadSnapshot?)`
- Produces (QueueServiceClient): `departNow()`, `setDefaultWidget(enabled: boolean)`, `myPad() -> PadSnapshot?`; registers HUD widget `queuePad` (order 900, under toasts at 1000).
- Produces (UI): `QueuePadPanel(props: { aboard: number, capacity: number, secondsLeft: number?, departing: boolean, onDepart: () -> () })`, `QueuePadStatus(props: { onDepart: () -> () })`.

- [ ] **Step 1: Write the failing spec** `src/ReplicatedStorage/Client/Features/Queue/State/QueueStore.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueStore = require(script.Parent.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	local previous

	beforeEach(function()
		previous = StateSyncClientStore.world()
	end)

	afterEach(function()
		StateSyncClientStore.world(previous)
		QueueStore.widgetEnabled(true)
	end)

	it("decodes the queue world entry and finds a player's pad", function()
		StateSyncClientStore.world({
			queue = {
				pads = {
					pad1 = { members = { 7 }, capacity = 4, destination = "away", endsAt = 120, departing = false },
				},
			},
		})
		local padId, pad = QueueStore.padFor(7)
		expect(padId).to.equal("pad1")
		expect(pad.endsAt).to.equal(120)
		expect(QueueStore.padFor(8)).to.equal(nil)
	end)

	it("has no snapshot before the first sync or for a malformed entry", function()
		StateSyncClientStore.world({})
		expect(QueueStore.snapshot()).to.equal(nil)
		StateSyncClientStore.world({ queue = "broken" })
		expect(QueueStore.snapshot()).to.equal(nil)
		expect(QueueStore.padFor(7)).to.equal(nil)
	end)

	it("shows the default widget unless a game turns it off", function()
		expect(QueueStore.widgetEnabled()).to.equal(true)
		QueueStore.widgetEnabled(false)
		expect(QueueStore.widgetEnabled()).to.equal(false)
	end)
end
```

- [ ] **Step 2: Run to verify failure (controller).** Studio test run → `QueueStore` spec errors (module missing).

- [ ] **Step 3: The store** `src/ReplicatedStorage/Client/Features/Queue/State/QueueStore.luau`:

```lua
--!strict
--[=[
	QueueStore: the queue as this client sees it, for the HUD. `snapshot` decodes the `queue` world entry
	(QueueSnapshotUtils); `widgetEnabled` lets a game hide the base's placeholder pad widget and draw its
	own (QueueServiceClient:setDefaultWidget). A read-only mirror of server state.

	@class QueueStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueShared = ReplicatedStorage.Shared.Features.Queue
local Charm = require(ReplicatedStorage.Packages.Charm)
local QueueConstants = require(QueueShared.Data.QueueConstants)
local QueueTypes = require(QueueShared.Data.QueueTypes)
local QueueSnapshotUtils = require(QueueShared.Utils.QueueSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local snapshot = Charm.computed(function(): QueueTypes.QueueSnapshot?
	return QueueSnapshotUtils.decode(StateSyncClientStore.world()[QueueConstants.WORLD_ENTRY])
end)

local widgetEnabled = Charm.atom(true)

local QueueStore = {
	snapshot = snapshot,
	widgetEnabled = widgetEnabled,
}

-- The pad `userId` is aboard, as this client sees it (its id and snapshot), or nil.
function QueueStore.padFor(userId: number): (string?, QueueTypes.PadSnapshot?)
	return QueueSnapshotUtils.padOf(snapshot(), userId)
end

return QueueStore
```

- [ ] **Step 4: The presentational panel** `src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadPanel.luau`:

```lua
--!strict
--[=[
	QueuePadPanel: the placeholder pad panel: players aboard, the countdown and a Depart-now button.
	Presentational only (props in, a callback out). Plain on purpose: each game's final pad UI is designed
	and approved in Figma first, and replaces this.

	@class QueuePadPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)
local Panel = require(ReplicatedStorage.Client.UI.React.Primitives.Panel)

local e = React.createElement

export type QueuePadPanelProps = {
	aboard: number,
	capacity: number,
	-- Whole seconds until departure, or nil while departing.
	secondsLeft: number?,
	departing: boolean,
	onDepart: () -> (),
}

local WIDTH = 240

local function statusText(props: QueuePadPanelProps): string
	if props.departing then
		return "Departing…"
	end
	local seconds = props.secondsLeft
	if seconds == nil then
		return "Waiting"
	end
	return `Leaving in {seconds}s`
end

local function QueuePadPanel(props: QueuePadPanelProps): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Tokens.space.xxl * 3),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		panel = e(Panel, {
			title = `{props.aboard}/{props.capacity} aboard`,
			children = {
				layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, Tokens.space.sm),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				status = e("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, Tokens.textSize.lg + Tokens.space.xs),
					BackgroundTransparency = 1,
					Font = Tokens.font.medium,
					TextSize = Tokens.textSize.lg,
					TextColor3 = Tokens.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = statusText(props),
				}),
				depart = e(Button, {
					text = "Depart now",
					variant = "primary",
					disabled = props.departing,
					onActivated = props.onDepart,
					layoutOrder = 2,
				}),
			},
		}),
	})
end

return QueuePadPanel
```

`src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadPanel.story.luau`:

```lua
--!strict
--[=[
	QueuePadPanel.story: the placeholder pad panel in Studio's edit mode (UI Labs).

	@class QueuePadPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local QueuePadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Aboard = 2,
		Capacity = 4,
		SecondsLeft = 12,
		Departing = false,
	},
}, function(props)
	local controls = props.controls
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		panel = e(QueuePadPanel, {
			aboard = controls.Aboard,
			capacity = controls.Capacity,
			secondsLeft = if controls.Departing then nil else controls.SecondsLeft,
			departing = controls.Departing,
			onDepart = function()
				print("QueuePadPanel.story: Depart now")
			end,
		}),
	})
end)
```

- [ ] **Step 5: The HUD widget** `src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadStatus.luau`:

```lua
--!strict
--[=[
	QueuePadStatus: the base's placeholder HUD widget for queue pads. Shows QueuePadPanel while the local
	player is aboard a pad, with a countdown that ticks locally against server time. Reads QueueStore; Depart
	now is the `onDepart` the service passes in (components never talk to the server). Hidden when a game
	turns the default widget off.

	@class QueuePadStatus
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local QueuePadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel)

local TICK_SECONDS = 0.2

export type QueuePadStatusProps = {
	onDepart: () -> (),
}

local function QueuePadStatus(props: QueuePadStatusProps): React.ReactNode
	local enabled = ReactCharm.useAtom(QueueStore.widgetEnabled)
	local snapshot = ReactCharm.useAtom(QueueStore.snapshot)
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local _, pad = QueueSnapshotUtils.padOf(snapshot, Players.LocalPlayer.UserId)
	local ticking = pad ~= nil and pad.endsAt ~= nil

	React.useEffect(function(): () -> ()
		local running = ticking
		if running then
			task.spawn(function()
				while running do
					setNow(workspace:GetServerTimeNow())
					task.wait(TICK_SECONDS)
				end
			end)
		end
		return function()
			running = false
		end
	end, { ticking })

	if not enabled or pad == nil then
		return nil
	end
	local endsAt = pad.endsAt
	return React.createElement(QueuePadPanel, {
		aboard = #pad.members,
		capacity = pad.capacity,
		secondsLeft = if endsAt ~= nil then math.max(0, math.ceil(endsAt - now)) else nil,
		departing = pad.departing,
		onDepart = props.onDepart,
	})
end

return QueuePadStatus
```

- [ ] **Step 6: The client service** `src/ReplicatedStorage/Client/Features/Queue/QueueServiceClient.luau`:

```lua
--!strict
--[=[
	QueueServiceClient: the queue on this client. Sends Depart now for the local player and registers the
	base's placeholder pad widget (QueuePadStatus: players aboard, countdown, a Depart-now button) during
	init. The widget is deliberately plain: a game's final pad UI is designed and approved in Figma first;
	the game then hides this one with `setDefaultWidget(false)` and reads QueueStore.

	Spec-exempt shell (ByteNet, HUD registration); the state is the specced QueueStore and
	QueueSnapshotUtils.

	@class QueueServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local QueueEvents = require(ReplicatedStorage.Shared.Features.Queue.Net.QueueEvents)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueueStore = require(ReplicatedStorage.Client.Features.Queue.State.QueueStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local QueuePadStatus = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadStatus)

local HUD_KEY = "queuePad"
-- Under the toasts (1000), so a toast is never hidden behind the pad panel.
local HUD_ORDER = 900

local function departNow()
	QueueEvents.packets.Depart.send(true)
end

local function Widget(): React.ReactNode
	return React.createElement(QueuePadStatus, { onDepart = departNow })
end

export type QueueServiceClient = {
	dependencies: { string },
	init: (self: QueueServiceClient) -> (),
	departNow: (self: QueueServiceClient) -> (),
	setDefaultWidget: (self: QueueServiceClient, enabled: boolean) -> (),
	myPad: (self: QueueServiceClient) -> QueueTypes.PadSnapshot?,
	getState: (self: QueueServiceClient) -> { [string]: any },
}

local QueueServiceClient: QueueServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, Widget, HUD_ORDER)
		end
	end,

	--[=[
		Asks the server to depart the local player's pad now (it checks they are aboard an open pad).
	]=]
	departNow = function(_self)
		departNow()
	end,

	--[=[
		Shows or hides the base's placeholder pad widget (a game with its own pad UI turns it off).
	]=]
	setDefaultWidget = function(_self, enabled)
		QueueStore.widgetEnabled(enabled)
	end,

	myPad = function(_self)
		local _, pad = QueueStore.padFor(Players.LocalPlayer.UserId)
		return pad
	end,

	getState = function(_self)
		local padId = QueueStore.padFor(Players.LocalPlayer.UserId)
		return { pad = padId or "none", widget = QueueStore.widgetEnabled() }
	end,
}

return QueueServiceClient
```

- [ ] **Step 7: Exemptions.** Add to `EXEMPT_MODULES` after the Task 4 Queue entries:

```lua
	["ReplicatedStorage.Client.Features.Queue.QueueServiceClient"] = "ByteNet/HUD registration shell (QueueStore and QueueSnapshotUtils are specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadStatus"] = "React UI component (rendered in-game; its panel has a story)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel"] = "React UI component (presentational; story in QueuePadPanel.story)",
```

- [ ] **Step 8: Studio verification (controller).** TestEZ run (`RunTests = true`): `QueueStore` passes, `assertAllModulesSpecced` passes. Open `QueuePadPanel` in UI Labs (edit mode): renders "2/4 aboard", "Leaving in 12s", an enabled "Depart now"; toggling Departing shows "Departing…" and a disabled button. Then `RunTests` off, insert this **Script in Workspace** named `QueueWidgetVerify`, Play Solo:

```lua
-- QueueWidgetVerify: temporary Studio check for the pad widget (delete after the run).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Queue = require(ServerScriptService.Features.Queue.QueueServiceServer)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
task.wait(3)

if not QueueRegistry.has("verify-away") then
	QueueRegistry.register("verify-away", 0)
end
Queue:setArrivalPoint("verify-away", function()
	return CFrame.new(300, 5, 0)
end)
Queue.arrived:Connect(function(party)
	print(`[PASS] the Depart now button departed a party of {#party}`)
end)

local pad = Instance.new("Part")
pad.Name = "VerifyWidgetPad"
pad.Anchored = true
pad.Size = Vector3.new(10, 1, 10)
pad.Position = Vector3.new(0, 0.5, 40)
pad:SetAttribute("QueueCapacity", 4)
pad:SetAttribute("QueueCountdown", 60)
pad:SetAttribute("QueueDestination", "verify-away")
pad.Parent = workspace
CollectionService:AddTag(pad, "QueuePad")
task.wait(0.5)
character:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
print("Stand by: the pad panel should show 1/4 aboard, a countdown from 60 and a Depart now button")
```
Expected: within a second the panel appears bottom-centre: "1/4 aboard", "Leaving in 60s" counting down each second (screenshot twice, a few seconds apart). Click **Depart now** (`user_mouse_input` on the button): Output prints `[PASS] the Depart now button departed a party of 1`, the character is moved to (300, 5, 0) and the panel disappears. Stop, delete the Script and the pad is gone with the play session.

- [ ] **Step 9: Module map, gate, commit**

```bash
git add src/ReplicatedStorage/Client/Features/Queue src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadPanel.luau src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadPanel.story.luau src/ReplicatedStorage/Client/UI/React/Screens/Hud/QueuePadStatus.luau src/ServerScriptService/Core/Testing/SpecRoots.luau
python3 scripts/python/module_map.py --write
git add docs/project-structure.md
bash .superpowers/sdd/gate.sh
git commit -m "feat(queue): client store, Depart now and a placeholder pad widget"
python3 scripts/python/module_map.py --check
```

---

### Task 6: Docs, full test run, PR

**Files:**
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: ROADMAP.** In the "In the base today" table, add a row after `Toast`:

```markdown
| Queue | Party pads (`QueuePad` tag; capacity, countdown reset on join, Depart now) that move a party together to another place of the experience: a fresh reserved server, 3 backed-off retries then back on the pad with a toast; the arrival side waits for the expected party (20 s), seats strangers only where there is room and redirects the rest; a return trip carries a result payload; a place-role table (`QueueRegistry`) with placeholder PlaceIds, and a local mode in Studio / unknown places where a teleport becomes a move and `arrived` fires the same way |
```
Replace the whole `## Queue — planned before Cleanup Crew M4` section (heading and paragraph) with nothing (Queue is now listed as built).

- [ ] **Step 2: Gate.** `bash .superpowers/sdd/gate.sh` → `==> All checks passed.`

- [ ] **Step 3: Full TestEZ run (controller).** Studio `RunTests = true`. Expected: every spec passes (the nine Queue specs included), `assertAllModulesSpecced` and `assertAllSpecsCovered` pass.

- [ ] **Step 4: Commit**

```bash
git add docs/ROADMAP.md
git commit -m "docs: record the base Queue feature"
```

- [ ] **Step 5: Push and open the PR (controller only; never merge)**

```bash
git push -u origin base/queue
gh pr create --base base/game-hooks --head base/queue --title "Queue: party pads, reserved-server teleports, arrivals and return trips" --body "$(cat <<'EOF'
Adds the base Queue feature (spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md §6.1, plan: docs/superpowers/plans/2026-10-10-queue-base.md). Generic: roles are strings a game registers.

- Pads: `QueuePad` tag + QueueCapacity / QueueCountdown / QueueDestination; countdown resets on join; Depart now (server `departNow`, client button)
- Live: fresh reserved server per departure, teleport ticket (expected ids + game payload, JSON, decoded as untrusted), 3 retries backing off 1/2/4 s, then back on the pad with a toast (`departFailed`)
- Arrival: waits up to 20 s for the expected party, then `arrived(party, payload)`; strangers seated only where no expected member needs the seat, else redirected home
- Return: `returnParty(players, role, payload)` → `returned(player, payload)` where they land
- Place-role table `QueueRegistry` (placeholder PlaceId 0 until a place exists); Studio / unknown place = local mode, a teleport becomes a move and `arrived` fires the same way
- Client: `queue` world entry, `QueueStore`, placeholder pad widget (games hide it with `setDefaultWidget(false)`)

Verified: gate green; TestEZ green in Studio; Studio checklists in the plan (Task 4 Step 8, Task 5 Step 8), including the forced-live failure path (retries then back on the pad).

Not verifiable in Studio, to run in the M4 publish walkthrough (two places in one experience, PlaceIds registered):
- [ ] a party of 2+ departs a pad and lands together in one reserved server; `arrived` fires once with both
- [ ] a party member who closes the game mid-teleport: the rest arrive, the arrival server starts after 20 s
- [ ] a friend joining a member's reserved server: seated if there is room, else sent to a public home server
- [ ] `returnParty` lands the party in a home server with `returned(player, payload)`
- [ ] the empty reserved server shuts down after the last player leaves

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Open questions for the developer

None of these block the plan; each has a default the plan implements.

1. **Placeholder destination on a live server routes as a local move** (both roles run in that server), rather than refusing to depart. Lets you publish the depot place before the shift place exists. Say if you prefer a refusal with a toast.
2. **A stranger who cannot be redirected is kicked** ("This server is full. Please rejoin."): when no home role is known, or the redirect teleport fails after its retries.
3. **Placeholder pad widget ships in the base** via HudRegistry (key `queuePad`); a game switches it off with `QueueServiceClient:setDefaultWidget(false)` once its Figma-approved pad UI exists.
4. **Expected party members who arrive after the party started** are admitted and reported through `joinedLate(player)`; the game decides (Round `lateJoin` or not). Strangers after the start are redirected.
5. **`configure({ forceLive = true })`** is public API used only to verify the teleport-failure path in Studio. Acceptable, or should it be gated to Studio (`RunService:IsStudio()`)?

No approval-gated layout changes: no new subfolder kind, no new role word, no second service.

## Spec gaps (decided here, worth confirming)

- **A full pad does not depart early**; only the countdown or Depart now departs it. The spec is silent.
- **Players beyond capacity standing on a pad** are not members (the earliest keep their seats); the placeholder widget does not tell them the pad is full.
- **The drive card on the loading screen** is client-side (`TeleportService:SetTeleportGui`) and game art: left to the game at M4, not in the base.
- **TeleportData size limit is not documented by Roblox**; the plan caps the payload (32 keys, strings ≤ 1000 characters). A large result card should be summarised to fit.
- **`ReserveServer` vs `ReserveServerAsync`**: both exist in the current API dump; the typed `ReserveServer` is used, with a fallback (`ShouldReserveServer` + `ReservedServerAccessCode` from the result) if selene marks it deprecated.
