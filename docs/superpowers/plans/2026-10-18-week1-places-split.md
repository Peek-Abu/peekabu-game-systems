# Week 1 Part 1: Hub place + one Shift place Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One codebase runs as two published places, the hub (depot role, place 113354563835664) and the Shift place (shift role), with every shift-only service inert in the hub, the hub's own spawns, strangers on a public Shift server sent to the hub, and the whole loop still playing in one Studio place.

**Architecture:** Queue already resolves each server's role and keeps Studio in "local" mode, where `QueueServiceServer:runsRole(role)` is true for every role. This plan adds no ServiceController change and touches no base feature (Queue, Round, Npc, Death stay as they are). The game's own services check `runsRole` at the top of `start`: Office, Shift and Occupant run only where the shift role runs, and Depot already builds the garage only where the depot role runs. The place-role table comes from two constants through a specced pure helper. That helper keeps both roles in one server until the Shift place id is filled in, so a hub republished early cannot break the loop. The two new decisions (who installs the spawn resolver, which server is stranded) live in specced pure modules. The service files that call them stay spec-exempt shells.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, TestEZ (`.spec.luau`), Queue (`QueueServiceServer`, `QueuePlaceRules`, `QueueRegistry`), Selene, StyLua.

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` §1 "Hub place + one Shift place".

## Approval needed

None. This plan adds no new subfolder kind, no new role word and no second service. The two new modules use existing subfolders and role words (`Utils`, `Rules`). No base feature is edited: Queue, Round, Npc and Death are only called.

## Global Constraints

- `--!strict` everywhere. No `any`, no casts.
- Spec-first: every new module has a `.spec.luau` sibling, or an exemption with a reason in `SpecRoots.EXEMPT_MODULES`.
- Module placement follows `docs/project-structure.md` and the `module-placement` skill. After adding a module, run `python3 scripts/python/module_map.py --write`.
- Server-authoritative. No client writes authoritative state.
- Rojo never touches artist content. The Shift place's map belongs to that place. Do not add a `$path` on Workspace, Lighting or ServerStorage.
- Every `*ServiceServer` stays registered in every place. Gate inside `start` with `QueueServiceServer:runsRole(role)`, and make no ServiceController change in base.
- Place ids: `113354563835664` is the hub (depot role). The Shift place id stays `0` until the owner publishes it.
- Office: gate it to the shift role ONLY. Another plan (part 7) reworks the Office to hand-built/tagged, so make no other Office change.
- Commits use plain messages. Do not add a `Co-Authored-By:` or `Claude-Session:` trailer. This game branch never merges into base.
- No publishing, uploads or `rojo`/`wally`/`check.sh` runs by agents. Publishing and live tests are owner actions.
- Test command (Studio only): set the Workspace attribute `RunTests = true`, press Play, read Output, then set `RunTests` back to `false`. The last full count was 3828 passing.
- Lint and format changed files from Git Bash: `selene <files>` and `stylua --check <files>`.

## Review Focus

1. **The hub is republished before the Shift place id is known** (`SHIFT_PLACE_ID = 0`). The whole loop must still play in that one server, as it does today: both roles stay placeholders. Pinned in Task 1 (`roles(113354563835664, 0)` gives both `0`).
2. **A typo makes the hub and Shift ids the same.** The server must fail at boot with a message that names the two constants, not with Queue's generic duplicate error. Pinned in Task 1.
3. **A live hub server where Shift is inert.** Players must still spawn on the depot's spawn points, not on the place's baseplate, and returning players must land beside the result board. Pinned in Task 2 (`depotOwnsSpawns(true, false)` is `true`), plus a live check in Task 7.
4. **Studio local mode, where both roles run.** Exactly one service installs Death's spawn resolver (Shift's `spawnFor`, as today), so Depot must not overwrite it. Pinned in Task 2 (`depotOwnsSpawns(true, true)` is `false`).
5. **A stranger joins the Shift place directly** (a public server, a friend join or a place link). They are sent to the hub. A reserved party server is never treated as stranded, and Studio never is. Pinned in Task 5 (`isStrandedServer` cases).

---

## Services by place (decision record)

| Service | Hub (depot role) | Shift role | How |
|---|---|---|---|
| Depot | garage, board, pads, depart data, result card, **hub spawns** | travel-card listeners only (the arrival card shows in the Shift server) | the garage is already gated by `runsRole(depot)` (`DepotServiceServer.luau:261`); spawns are new in Task 2 |
| Office | inert | builds the office | Task 3: gate `start` |
| Shift (Trip, Transit, Vote, ClockOut, Site, Analytics watch, Review, Crew status) | inert | runs | Task 4: gate `start` |
| Occupant (Harlow) | inert | runs | Task 4: gate `start` (stops the 8 s respawn delay and the witness hook from reaching the hub) |
| Round, Npc (base) | idle by construction: Round has `autoStart = false` and only Shift configures or starts it; Npc only adopts tagged rigs that Occupant spawns | runs | not edited (base features) |
| Cargo, Carry, Hide, Noise, Vacuum | idle by construction: they react to tagged parts, piles and crew that only the Office and Shift create; the vacuum tool is handed out only by `ShiftServiceServer` → `VacuumServiceServer:setCrew`; the backpack look stays in both, as the spec asks | runs | not edited; checked live in Task 7 |
| All the "both" services from spec §1 | run | run | unchanged |

On the client, no gating is needed. `OfficeAtmosphereUtils.preset(nil, …)` and `DepotAtmosphereUtils.inHub(nil, …)` already choose the hub's evening light and music when the `shift` world entry is missing, which is what an inert Shift leaves behind.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Depot | server | Utils | `DepotPlaceUtils` | The place-role table from the hub and Shift ids (both placeholders until both are real), and whether Depot installs the spawn resolver. |
| Shift | server | Rules | `ShiftPlaceRules` | Whether this server is a stranded public Shift server whose players must go to the hub. |

---

### Task 1: Place-role table from one fill-in constant

**Files:**
- Create: `src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.luau`
- Test: `src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau:46-51` (the `PLACE_IDS` table) and its export (`PLACE_IDS = table.freeze(PLACE_IDS)`, ~line 78)
- Modify: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau:59-64` (the at-load registration loop) and its header comment
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau:456` (the DepotConstants exemption reason: "place table" becomes "place ids")
- Modify: `docs/project-structure.md` (regenerated module map)

**Interfaces:**
- Consumes: `DepotConstants.ROLE_DEPOT` (`"depot"`), `DepotConstants.ROLE_SHIFT` (`"shift"`), `QueueConstants.PLACEHOLDER_PLACE_ID` (`0`), `QueueRegistry.register(role: string, placeId: number)`
- Produces:
  - `DepotConstants.HUB_PLACE_ID: number = 113354563835664`
  - `DepotConstants.SHIFT_PLACE_ID: number = 0`. This is the single constant the owner fills in (Task 7). `PLACE_IDS` is removed.
  - `DepotPlaceUtils.roles(hubPlaceId: number, shiftPlaceId: number): { [string]: number }` returns a frozen `{ depot = …, shift = … }`. If either id is `0`, both are `0`. It errors when both are real and equal, and the message names `HUB_PLACE_ID` and `SHIFT_PLACE_ID`.

- [ ] **Step 1: Write the failing test** `DepotPlaceUtils.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotPlaceUtils = require(script.Parent.DepotPlaceUtils)

return function()
	describe("roles", function()
		it("maps both real ids to their roles", function()
			local roles = DepotPlaceUtils.roles(113354563835664, 222)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(113354563835664)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(222)
		end)

		it("keeps both roles placeholders while the shift id is unknown", function()
			local roles = DepotPlaceUtils.roles(113354563835664, 0)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(0)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(0)
		end)

		it("keeps both roles placeholders while the hub id is unknown", function()
			local roles = DepotPlaceUtils.roles(0, 222)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(0)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(0)
		end)

		it("refuses one real id for both places", function()
			expect(function()
				DepotPlaceUtils.roles(555, 555)
			end).to.throw()
		end)

		it("returns a frozen table", function()
			expect(table.isfrozen(DepotPlaceUtils.roles(1, 2))).to.equal(true)
		end)

		it("is what the constants register today", function()
			local roles = DepotPlaceUtils.roles(DepotConstants.HUB_PLACE_ID, DepotConstants.SHIFT_PLACE_ID)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.be.a("number")
			expect(roles[DepotConstants.ROLE_SHIFT]).to.be.a("number")
		end)
	end)
end
```

- [ ] **Step 2: Run the test to verify it fails.**
Run: Studio, with `RunTests = true` → Play → Output → set it back.
Expected: FAIL. `DepotPlaceUtils` is not a valid member of `Utils`.

- [ ] **Step 3: Implement.** In `DepotConstants.luau`, replace `PLACE_IDS` with `HUB_PLACE_ID = 113354563835664` and `SHIFT_PLACE_ID = 0`. Comment the second one: `-- OWNER: the Shift place's PlaceId (docs/cleanup-crew-publish.md §2). 0 keeps both roles in one server.` Update the header comment to say "the place ids". Create `DepotPlaceUtils.roles` with the signature above (a pure function, header `@class DepotPlaceUtils`). In `DepotServiceServer`, register `DepotPlaceUtils.roles(DepotConstants.HUB_PLACE_ID, DepotConstants.SHIFT_PLACE_ID)` in the existing `for role, placeId in … do if not QueueRegistry.has(role)` loop. Update the SpecRoots reason. Then run `python3 scripts/python/module_map.py --write`.

- [ ] **Step 4: Run the tests to verify they pass.**
Run: the Studio test command.
Expected: all pass; the count is 3828 + 6.

- [ ] **Step 5: Lint and format.**
Run (Git Bash): `selene src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.spec.luau src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau`, then `stylua --check` on the same files.
Expected: no errors, no diffs.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.spec.luau src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "feat(depot): hub place id and one fill-in constant for the shift place"
```

---

### Task 2: The hub spawns its own players when Shift is inert

**Files:**
- Modify: `src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.luau` (add `depotOwnsSpawns`)
- Test: `src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Depot/DepotServiceServer.luau`: `dependencies` (~line 201), `start` (~line 218), `stop` (~line 291) and the header comment

**Interfaces:**
- Consumes: `QueueServiceServer:runsRole(role: string): boolean`, `DeathServiceServer:setSpawnPoint(resolver: DeathTypes.SpawnResolver?)`, `DepotServiceServer:spawnCFrame(index: number): CFrame`
- Produces: `DepotPlaceUtils.depotOwnsSpawns(runsDepot: boolean, runsShift: boolean): boolean`. It is true only when this server runs the depot and not the shift; otherwise Shift's `trip.spawnFor` keeps owning the resolver.

- [ ] **Step 1: Write the failing test.** Add to the spec:

```lua
describe("depotOwnsSpawns", function()
	it("is the depot's job in a hub-only server", function()
		expect(DepotPlaceUtils.depotOwnsSpawns(true, false)).to.equal(true)
	end)

	it("stays Shift's job when both roles run here (Studio, local mode)", function()
		expect(DepotPlaceUtils.depotOwnsSpawns(true, true)).to.equal(false)
	end)

	it("is never the depot's job in a shift-only server", function()
		expect(DepotPlaceUtils.depotOwnsSpawns(false, true)).to.equal(false)
		expect(DepotPlaceUtils.depotOwnsSpawns(false, false)).to.equal(false)
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail.**
Run: the Studio test command.
Expected: FAIL. `attempt to call a nil value (field 'depotOwnsSpawns')`.

- [ ] **Step 3: Implement.** Add `depotOwnsSpawns`. In `DepotServiceServer`:
  - add `"DeathServiceServer"` to `dependencies`;
  - in `start`, after the `runsRole(DepotConstants.ROLE_DEPOT)` early return and before the build, check `DepotPlaceUtils.depotOwnsSpawns(true, QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT))`. When it is true, call `DeathServiceServer:setSpawnPoint` with a resolver that returns `self:spawnCFrame(table.find(Players:GetPlayers(), player) or 1)` (the depot branch of `ShiftTripSystem.spawnFor`), set a module-local `ownsSpawns = true`, and log `hub spawns: the depot places players`;
  - in `stop`, when `ownsSpawns` is true, call `setSpawnPoint(nil)` and reset the flag.

  The header gains one bullet: in a hub-only server, the depot places spawning players.

- [ ] **Step 4: Run the tests to verify they pass.**
Run: the Studio test command.
Expected: all pass (count +3). Output during Play still shows `depot built: 3 trucks, …` and does **not** show `hub spawns:`, because Studio is local mode and Shift owns spawns.

- [ ] **Step 5: Lint and format** the three changed files (same commands as Task 1).

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.luau src/ServerScriptService/Features/Depot/Utils/DepotPlaceUtils.spec.luau src/ServerScriptService/Features/Depot/DepotServiceServer.luau
git commit -m "feat(depot): place players on the depot spawns in a hub-only server"
```

---

### Task 3: The Office builds only where the shift role runs

**Files:**
- Modify: `src/ServerScriptService/Features/Office/OfficeServiceServer.luau`: `dependencies` (line 206), the top of `start` (lines 212-221) and one header sentence

**Interfaces:**
- Consumes: `QueueServiceServer:runsRole(role: string): boolean`, `DepotConstants.ROLE_SHIFT`
- Produces: none new. In a hub-only server, `OfficeServiceServer:getState().built` is `false`. The pure accessors (`spawnCFrame`, `safeZone`, `loadingBay`, `whereIs`, `route`) keep working because they read the layout, not the built model, and their only callers (Shift, Occupant) are inert there too (Task 4).

Spec-exempt shell (its existing `EXEMPT_MODULES` line stays). The gate is one `runsRole` call; the role decision is the specced `QueuePlaceRules.runsRole`.

- [ ] **Step 1: Implement.** Add `"QueueServiceServer"` to `dependencies`. Make the first statement of `start`: `if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then log:info("not a shift server: the office is not built") return end`. Add the two requires (`QueueServiceServer` from `ServerScriptService.Features.Queue`, `DepotConstants` from `ReplicatedStorage.Shared.Features.Depot.Data`). `stop` already handles `built == nil`. Change nothing else in the Office.

- [ ] **Step 2: Run the tests to verify nothing regressed.**
Run: the Studio test command.
Expected: all pass, same count as after Task 2. Output does not contain `not a shift server`, because Studio is local mode and the office is still built.

- [ ] **Step 3: Lint and format** `OfficeServiceServer.luau`.

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Features/Office/OfficeServiceServer.luau
git commit -m "feat(office): build the office only where the shift role runs"
```

---

### Task 4: Shift and Occupant stay inert outside the shift role

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`: requires (after line 81), `start` (line 415), `stop` (line 455) and the header comment
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau`: `dependencies` (line 418), the top of `start`, requires and the header comment

**Interfaces:**
- Consumes: `QueueServiceServer:runsRole(role: string): boolean`, `DepotConstants.ROLE_SHIFT`
- Produces: none new. In a hub-only server, Shift publishes no `shift` world entry, never configures Round, never sets Death's spawn point, and starts none of its systems (Trip, Transit, Vote, ClockOut, TimeClock, Overtime, Gloom, Analytics watch, Review, Crew status). Occupant spawns no Harlow, and it neither sets the NPC brain or Hide witness nor changes Death's `respawnDelay`.

Both are spec-exempt shells (their existing `EXEMPT_MODULES` lines stay).

- [ ] **Step 1: Implement Shift.** Require `QueueServiceServer` and `DepotConstants`; both are already among Shift's declared `dependencies`, so that list needs no change. Make the first statement of `start`: `if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then log:info("not a shift server: the shift does not run here") return end`. Then set a module-local `started = true`. In `stop`, return at once unless `started` is true, and reset it at the end. Without this, `stop` in a hub would call `DeathServiceServer:setSpawnPoint(nil)` over Depot's resolver from Task 2. Header: one bullet saying the shift runs only where the shift role runs.

- [ ] **Step 2: Implement Occupant.** Add `"QueueServiceServer"` to `dependencies` and the two requires. Make the first statement of `start` the same gate, with the log `not a shift server: the Manager does not run here`. `stop` is already safe when `start` returned early (it clears hooks it may not have set and despawns nothing).

- [ ] **Step 3: Run the tests to verify nothing regressed.**
Run: the Studio test command.
Expected: all pass, same count as after Task 2.

- [ ] **Step 4: Studio loop check (local mode, one place).** Do this only if the playtest lock allows; otherwise hand it to the owner as the first item of Task 7's checklist. Leave `RunTests` unset and press Play solo. Output shows `queue in local mode`, `depot built: 3 trucks`, and none of the three `not a shift server` lines. Walk up truck 1 and press Depart now: the shift starts in the office's loading bay, and Harlow patrols. Clock out, vote Back to depot: you land at the depot and your result card is on the board. Stop.

- [ ] **Step 5: Lint and format** the two changed files.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Shift/ShiftServiceServer.luau src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau
git commit -m "feat(shift): run the shift and the Manager only where the shift role runs"
```

---

### Task 5: A stranger on a public Shift server is sent to the hub (specced)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Rules/ShiftPlaceRules.luau`
- Test: `src/ServerScriptService/Features/Shift/Rules/ShiftPlaceRules.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau:112-117` (replace the local `isPublicShiftServer` body) and the header
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau:426` (the ShiftTripSystem reason gains "ShiftPlaceRules")
- Modify: `docs/project-structure.md` (regenerated module map)

**Interfaces:**
- Consumes: `QueueTypes.Mode` (`"live" | "local"`), `QueuePlaceRules.isReservedServer(privateServerId: string, privateServerOwnerId: number): boolean`, `DepotConstants.ROLE_SHIFT`
- Produces: `ShiftPlaceRules.isStrandedServer(mode: QueueTypes.Mode, role: string?, reserved: boolean): boolean`. It is true only for `mode == "live"`, `role == DepotConstants.ROLE_SHIFT` and `not reserved`.

- [ ] **Step 1: Write the failing test** `ShiftPlaceRules.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftPlaceRules = require(script.Parent.ShiftPlaceRules)

return function()
	describe("isStrandedServer", function()
		it("is a live public server of the shift place", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_SHIFT, false)).to.equal(true)
		end)

		it("is never a reserved party server", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_SHIFT, true)).to.equal(false)
		end)

		it("is never the hub", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_DEPOT, false)).to.equal(false)
		end)

		it("is never Studio or an unknown place (local mode)", function()
			expect(ShiftPlaceRules.isStrandedServer("local", DepotConstants.ROLE_SHIFT, false)).to.equal(false)
			expect(ShiftPlaceRules.isStrandedServer("local", nil, false)).to.equal(false)
		end)

		it("is never a live server with no role", function()
			expect(ShiftPlaceRules.isStrandedServer("live", nil, false)).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 2: Run the test to verify it fails.**
Run: the Studio test command.
Expected: FAIL. `ShiftPlaceRules` is not a valid member of `Rules`.

- [ ] **Step 3: Implement.** Create `ShiftPlaceRules.isStrandedServer` (pure, `@class ShiftPlaceRules`). In `ShiftTripSystem`, replace the body of `isPublicShiftServer` with `ShiftPlaceRules.isStrandedServer(QueueServiceServer:mode(), QueueServiceServer:role(), QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId))`. Keep the existing `sendToDepot` behaviour: `returnParty` to the depot, then a kick with `STRANDED_TEXT` after `RETURN_WAIT_SECONDS` if they are still there. Change the warn text to `a public server of the shift place: every player is sent to the hub`. Update the SpecRoots reason, then run `python3 scripts/python/module_map.py --write`.

- [ ] **Step 4: Run the tests to verify they pass.**
Run: the Studio test command.
Expected: all pass; the count is 3828 + 6 + 3 + 5.

- [ ] **Step 5: Lint and format** the four changed source files.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Shift/Rules/ShiftPlaceRules.luau src/ServerScriptService/Features/Shift/Rules/ShiftPlaceRules.spec.luau src/ServerScriptService/Features/Shift/Systems/ShiftTripSystem.luau src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "feat(shift): spec the stranded public shift server check"
```

---

### Task 6: Runbook for the hub + Shift split

**Files:**
- Modify: `docs/cleanup-crew-publish.md`

**Interfaces:**
- Consumes: `DepotConstants.HUB_PLACE_ID`, `DepotConstants.SHIFT_PLACE_ID` (Task 1); the log lines `hub spawns: the depot places players` (Task 2), `not a shift server: …` (Tasks 3-4) and `a public server of the shift place: every player is sent to the hub` (Task 5)
- Produces: the owner's runbook and live checklist, used by Task 7.

- [ ] **Step 1: Edit the runbook.**
  - Rename "depot place" to "hub (the depot role)", and give its id, `113354563835664`, as the existing start place.
  - §2 now says: fill in **only** `SHIFT_PLACE_ID` in `DepotConstants.luau`. While it is `0`, both roles play in one server even when published.
  - Add the "Services by place" table from this plan, in short form.
  - §3: publish **both** places from the same commit. A Shift place published with an older build (shift id `0`) plays every role locally and builds a depot inside the office place.
  - Expected live log lines: the hub shows `queue in live mode, role depot`, `hub spawns: the depot places players` and the three `not a shift server` lines. A party's Shift server shows `queue in live mode, role shift, reserved server` and no `depot built` line.
  - Replace §5's checklist with Task 7's checklist (keep the existing failure checks and the "Things to measure" section).

- [ ] **Step 2: Commit**

```bash
git add docs/cleanup-crew-publish.md
git commit -m "docs(depot): runbook for the hub and shift places"
```

---

### Task 7: Owner action — create and publish the Shift place, fill in its id, live test

**Files:**
- Modify (agent, after the owner gives the id): `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau` (`SHIFT_PLACE_ID`)

**Interfaces:**
- Consumes: Tasks 1-6.
- Produces: both places published from one commit, and the live checklist ticked.

- [ ] **Step 1 (owner):** Create the Shift place, following `docs/cleanup-crew-publish.md` §1 (Asset Manager → Places → Add New Place, named `Shift`). Its map content (part 7's office build) is owned in that place. Until it exists, the code-built office keeps working.
- [ ] **Step 2 (owner):** Copy the Shift place's PlaceId and tell the agent.
- [ ] **Step 3 (agent):** Set `SHIFT_PLACE_ID` to that id and delete the `OWNER:` comment. Run the Studio test command (all pass; the `is what the constants register today` case now sees two different real ids). Lint and format the file, then commit:

```bash
git add src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau
git commit -m "fix(depot): real PlaceId for the shift place"
```

- [ ] **Step 4 (owner):** From that commit, sync and publish the hub (113354563835664) first, then the Shift place (runbook §3). Turn Team Create off while syncing.
- [ ] **Step 5 (owner): live checklist.** Use two accounts on published places, with F9 → Server open on the owner account.
  - [ ] Studio, before publishing (local mode, one place): the full loop from Task 4 Step 4 still works, solo and in a 2-player Local Server.
  - [ ] Hub log: `queue in live mode, role depot`, `hub spawns: the depot places players` and `depot built: 3 trucks`. There is no office in the hub, no Harlow, no shift timer on the HUD, and the hub's evening light and music play. Players spawn on the depot's spawn points, wearing the vacuum backpack but holding no vacuum tool.
  - [ ] A party of 2 departs from truck 1: the drive card shows, then both land in **one** reserved Shift server. Its log reads `queue in live mode, role shift, reserved server` with no `depot built` line. The arrival card shows and the shift starts in the loading bay.
  - [ ] A full shift plays: Harlow patrols, the vacuum works and valuables bank.
  - [ ] Vote **Back to depot**: both land in a hub server and each sees **their** result card on the result board, plus the toast.
  - [ ] **Stranger redirect, public server:** join the Shift place directly (open `https://www.roblox.com/games/<shift id>` and press Play; if Roblox refuses a direct join to a non-start place, note that and tick this as covered by the refusal). The Shift log shows `a public server of the shift place: every player is sent to the hub`, and the player lands in a hub server. If that teleport fails, they are kicked after 130 s with "This shift server is empty. Rejoin from the depot."
  - [ ] **Stranger, reserved server:** a third account tries to follow a crew member into their Shift server through the profile. Note what Roblox shows; they must end up in a hub server, never inside the crew's shift.
  - [ ] **Return failure:** if a return trip fails, the two toasts from the runbook show and the next shift can start.
  - [ ] Everyone leaves a Shift server: rejoining never puts you back in it.
- [ ] **Step 6 (owner):** Move board item §1 to "review".

---

## Self-review notes

- Spec §1 coverage: place ids (Tasks 1 and 7); per-place services (Tasks 2-4, plus the decision table for the services left idle); the Office gated to the shift role only (Task 3); Shift → Depot coupling is safe (Depot's `spawnCFrame` and `contract` are pure and its card listeners are needed in the Shift server; Shift's `stop` no longer clears Depot's resolver); `ShiftTripSystem` → Depot/Office is safe (it starts only with Shift, where the Office is built; it calls only Depot's pure `spawnCFrame`); stranger redirect (Task 5 + live check); done-when (Task 4 Step 4 + Task 7 checklist); owner action (Task 7).
- Out of scope here: the hand-built/tagged Office (part 7), and every other week-1 part.
