# Character replication R5 — robustness, voice, chat settings: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove client-built bodies never go missing (a gated tripwire plus a join/rejoin/stall matrix), give
them spatial voice with the engine's own speaking icon, and land #32 and the chat/voice place settings.

**Architecture:** The client rig registry moves out of `CharacterReplicationServiceClient` into a pure
`RigRegistry`, which also becomes the one writer of remote players' `Player.Character` (that is what makes
the engine draw its speaking icon over a puppet). A pure `ReplicationTripwire` checks a snapshot built by
`ReplicationDiagnostics`, which runs it once a second only while Workspace `Diagnostics` is true. Voice is a
new `VoiceService` pair: the server creates one `AudioDeviceInput` per player; the client wires each remote
input to an `AudioEmitter` on that player's puppet head, driven by a pure `VoiceWiring` state machine.

**Tech Stack:** Luau `--!strict`, Rojo 7.7.0 (code-only project), TestEZ in Studio, ByteNet, Charm,
Janitor, Roblox Audio API (`AudioDeviceInput`, `AudioEmitter`, `AudioListener`, `AudioDeviceOutput`, `Wire`),
`TextChatService`.

**Spec:** `docs/superpowers/specs/2026-10-05-character-replication-r5-voice-design.md` (and CP3 / CP12 in
`docs/superpowers/specs/2026-09-22-character-replication-design.md`).

## Global Constraints

- Branch `feature/replication-chat-voice`, worktree `.claude/worktrees/replication-chat-voice`, stacked on
  `feature/replication-appearance` (R4, PR #34). Never merge; R2–R5 merge together after the developer verifies.
- `--!strict` everywhere in production code. **No `any`, no `::` casts.** Spec files are untyped and are not
  typechecked (`--ignore="**/*.spec.luau"`).
- Spec-first: every new module gets `<Name>.spec.luau` first, or an entry in
  `src/ServerScriptService/Modules/SpecRoots.luau` `EXEMPT_MODULES` with a reason.
- **400 code lines per module** (`scripts/python/check_file_length.py`; comments and blank lines don't count).
  `CharacterReplicationServiceClient.luau` is at exactly 400 today: anything added there must be paid for by
  what Task 3 moves out. Run `python scripts/python/check_file_length.py` after touching it.
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields).
- Commits: plain messages. **No `Co-Authored-By:` or `Claude-Session:` trailers.**
- **While the developer serves a folder with rojo: run NO `rojo` command anywhere, no `scripts/check.sh`, no
  `wally install`, no `git rebase` in a served tree.** Per-file `stylua <file>` and `selene <file>` are fine.
  The full gate (with typecheck) runs in Task 10, only after the developer says rojo is stopped.
- Never mention other games' names in code, docs or commit messages on this branch.
- Voice range: full volume to 10 studs, silent at 80 (`{[0]=1, [10]=1, [45]=0.35, [80]=0}`), constants in code.
- The tripwire never heals anything: no `Ready` resend, no rebuild. It reports.
- `TextChatService.ChatVersion` is set **by hand** in each place (scripts cannot write it). The developer must set
  it to `TextChatService` in the dev place before Task 11.

## Review Focus

1. **A pooled puppet reused for another player, then a late `unregister` for its old owner** — the new
   owner's `Character` and reverse lookup must survive (today `unregisterRig` clears `userIdsByRig[model]`
   unconditionally). Pinned in Task 3.
2. **A stale `bodyDespawned` for a rejoiner's old puppet arriving after the new puppet spawned** — voice must
   stay wired to the new head. Pinned in Task 7 (`clearHead` ignores a head that is not current).
3. **The server replaces a player's `VoiceInput`** while wired — voice must follow the new input, never
   keep a `Wire` to a destroyed one. Pinned in Task 7.
4. **A missing body whose reason changes mid-way** (no `Player` → not dressed) — the allowance restarts for
   the new reason instead of firing early or never. Pinned in Task 4.
5. **A player who leaves and rejoins** — the tripwire forgets their first-seen time, so the rejoin gets a fresh
   3 s allowance instead of an instant `unknownPlayer`. Pinned in Task 4.

---

### Task 1: `RequestHandler.wrap` guards a custom clock (#32, part 2)

**Files:**
- Modify: `src/ServerScriptService/Modules/RequestHandler.luau:214-228`
- Test: `src/ServerScriptService/Modules/RequestHandler.spec.luau` (append a `describe` before the file's final `end`)

**Interfaces:**
- Consumes: `RequestHandler.wrap(config)`, `RequestHandler.getRateLimitStatus(userId, actionName)`,
  `RequestHandler.resetRateLimit(userId, actionName?)`.
- Produces: no new API. A throwing `clock` now rejects the packet (counted like a validation reject).

- [ ] **Step 1: Write the failing test**

Append inside the spec's top-level `return function() ... end`, before its last `end`:

```lua
	-- -------------------------------------------------------------------------
	-- #32: a custom clock reads packet bytes; one that throws must reject the packet, not escape the listener.
	describe("wrap — a throwing custom clock", function()
		afterEach(function()
			RequestHandler.resetRateLimit(64)
		end)

		it("rejects the packet, counts it, and never calls the handler", function()
			local handled = 0
			local wrapped = RequestHandler.wrap({
				name = "ClockThrows",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function()
					return true
				end,
				clock = function()
					error("clock exploded")
				end,
				handler = function()
					handled += 1
				end,
			})
			local ok = pcall(wrapped, {}, mockPlayer(64))
			expect(ok).to.equal(true)
			expect(handled).to.equal(0)
			expect(RequestHandler.getRateLimitStatus(64, "ClockThrows").rejected).to.equal(1)
		end)

		it("still accepts the next packet when the clock recovers", function()
			local handled = 0
			local broken = true
			local wrapped = RequestHandler.wrap({
				name = "ClockRecovers",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function()
					return true
				end,
				clock = function()
					if broken then
						error("clock exploded")
					end
					return 1
				end,
				handler = function()
					handled += 1
				end,
			})
			wrapped({}, mockPlayer(64))
			broken = false
			wrapped({}, mockPlayer(64))
			expect(handled).to.equal(1)
			expect(RequestHandler.getRateLimitStatus(64, "ClockRecovers").rejected).to.equal(1)
		end)
	end)
```

- [ ] **Step 2: Confirm it fails**

Read the current code at `RequestHandler.luau:224`: `clock(data, player)` is called unprotected, so the first
test's `pcall(wrapped, ...)` returns `false`. (TestEZ only runs in Studio; the whole suite runs in Task 10.)

- [ ] **Step 3: Implement**

In `RequestHandler.luau`, replace:

```lua
			if not takeToken(entryFor(userId, bucketKey), rateLimit, clock(data, player), true) then
				reject(userId, true, nil)
				return nil
			end
```

with:

```lua
			-- #32: the clock reads packet bytes, so it can throw on a packet only validation vouched for. A throw
			-- rejects THIS packet (counted like a validation reject) instead of escaping the ByteNet listener.
			local clockOk, clockNow = pcall(clock, data, player)
			if not clockOk then
				reject(userId, false, `clock error: {clockNow}`)
				return nil
			end
			if not takeToken(entryFor(userId, bucketKey), rateLimit, clockNow, true) then
				reject(userId, true, nil)
				return nil
			end
```

Update the module header comment line that says the custom clock "requires `rateLimit`. Validation runs first."
to add: "A clock that throws rejects the packet."

- [ ] **Step 4: Lint and format**

Run: `stylua src/ServerScriptService/Modules/RequestHandler.luau src/ServerScriptService/Modules/RequestHandler.spec.luau && selene src/ServerScriptService/Modules/RequestHandler.luau`
Expected: `0 errors, 0 warnings`.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Modules/RequestHandler.luau src/ServerScriptService/Modules/RequestHandler.spec.luau
git commit -m "fix(request-handler): a throwing custom clock rejects the packet instead of escaping (#32)"
```

---

### Task 2: `StatsServiceServer.stop()` (#32, part 1)

**Files:**
- Modify: `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` (type block ~line 90–108;
  the literal after `start`)
- Test: `src/ServerScriptService/Services/StatsService/StatsServiceServer.spec.luau` (new `describe` inside
  `describe("StatsServiceServer", ...)`, after `describe("getState", ...)`)

**Interfaces:**
- Consumes: `CharacterReplicationServiceServer.observeBodies(self, callback)` (patched in the spec),
  `BodyObservers.observe(bodySpawned, bodyDespawned, liveBodies, callback)`, `SignalTyped.new()`.
- Produces: `StatsServiceServer:stop()`.

- [ ] **Step 1: Write the failing test**

Add at the top of the spec, beside the other requires:

```lua
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local BodyObservers = require(ServerScriptService.Services.CharacterReplicationService.BodyObservers)
```

Add inside `describe("StatsServiceServer", function() ... end)`, after `describe("getState", ...)`:

```lua
		-- -------------------------------------------------------------------------
		-- #32: start() must be undone by stop(). observeBodies is swapped for the REAL BodyObservers over fake
		-- signals, so start() can run here without a live body; the live service is restored afterwards.
		describe("start / stop", function()
			local origObserve
			local spawned, despawned

			beforeEach(function()
				ServerStore.remove(1)
				spawned, despawned = SignalTyped.new(), SignalTyped.new()
				local live = { { player = { UserId = 1, Name = "user1" }, epoch = 1 } }
				origObserve = CharacterReplicationService.observeBodies
				CharacterReplicationService.observeBodies = function(_self, callback)
					return BodyObservers.observe(spawned, despawned, function()
						return live
					end, callback)
				end
				StatsService:stop() -- drops the live service's own observer
				_profiles[1] = makeProfile(0, {})
			end)

			afterEach(function()
				StatsService:stop()
				CharacterReplicationService.observeBodies = origObserve
				ServerStore.remove(1)
				StatsService:start() -- the real observer again, for the rest of the suite
			end)

			it("stop tears down every body subscription; the counter returns to 0 by itself", function()
				StatsService:start()
				expect(StatsService:getState().activeSubscriptions).to.equal(1)
				StatsService:stop()
				expect(StatsService:getState().activeSubscriptions).to.equal(0)
			end)

			it("start, stop, start leaves one subscription per body and a change applies once", function()
				StatsService:start()
				StatsService:stop()
				StatsService:start()
				expect(StatsService:getState().activeSubscriptions).to.equal(1)
				table.clear(maxHealthCalls)
				ServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)
				expect(#maxHealthCalls).to.equal(1)
			end)
		end)
```

- [ ] **Step 2: Confirm it fails**

`StatsService:stop` does not exist today, so `StatsService:stop()` in `beforeEach` errors ("attempt to call a
nil value").

- [ ] **Step 3: Implement**

In the `export type StatsServiceServer` block add, after `start`'s field:

```lua
	stop: (self: StatsServiceServer) -> (),
```

In the literal, after the `start = function(self) ... end,` entry add:

```lua
	--[=[
		Undoes start(): the body observer and every per-body subscription (#32). No manual counter reset —
		BodyObservers' disposer runs each body's cleanup, which decrements `activeSubscriptions`, so it returns
		to 0 by itself and a leak would show.
		@param _self StatsServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("StatsServiceServer stopped")
	end,
```

- [ ] **Step 4: Lint and format**

Run: `stylua src/ServerScriptService/Services/StatsService/StatsServiceServer.luau src/ServerScriptService/Services/StatsService/StatsServiceServer.spec.luau && selene src/ServerScriptService/Services/StatsService/StatsServiceServer.luau`
Expected: `0 errors, 0 warnings`.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/StatsService/
git commit -m "fix(stats): stop() tears down the body subscriptions start() made (#32)"
```

---

### Task 3: `RigRegistry` — the registry moves out, and becomes the one writer of remote `Character`

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigRegistry.luau`
- Test: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RigRegistry.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau`
  (lines 75–76 `rigsByUserId`/`userIdsByRig`, 94–95 the two signals, 105–117 `registerRig`/`unregisterRig`,
  every call site, `getRig`/`getPlayerFromRig`, the literal's `bodySpawned`/`bodyDespawned` fields, the header)

**Interfaces:**
- Produces:
  - `export type Registry = { localUserId: number, rigsByUserId: { [number]: Model }, userIdsByRig: { [Model]: number }, spawned: SignalTyped.Signal<Player, Model>, despawned: SignalTyped.Signal<Player, Model> }`
  - `RigRegistry.new(localUserId: number): Registry`
  - `RigRegistry.register(registry: Registry, player: Player, model: Model)`
  - `RigRegistry.unregister(registry: Registry, player: Player, model: Model)`
  - `RigRegistry.rigFor(registry: Registry, userId: number): Model?`
  - `RigRegistry.userIdFor(registry: Registry, model: Model): number?`

- [ ] **Step 1: Write the failing spec**

`RigRegistry.spec.luau`:

```lua
--!strict
--[=[
	Unit tests for RigRegistry — lookups, the body signals, and the remote `Character` rules (R5 spec §2.1):
	set on register, cleared on unregister only if it still points at that rig, never touched for the local
	player, and a stale unregister is a no-op. Players cannot be constructed in a spec: stand-in tables.
]=]

local RigRegistry = require(script.Parent.RigRegistry)

return function()
	local LOCAL_ID = 1
	local registry, models

	local function player(userId)
		return { UserId = userId, Name = `user{userId}`, Character = nil }
	end

	local function model(name)
		local m = Instance.new("Model")
		m.Name = name
		table.insert(models, m)
		return m
	end

	beforeEach(function()
		registry = RigRegistry.new(LOCAL_ID)
		models = {}
	end)

	afterEach(function()
		for _, m in models do
			m:Destroy()
		end
	end)

	it("register maps both ways, sets a remote player's Character, and fires spawned", function()
		local p, a = player(2), model("A")
		local fired = {}
		registry.spawned:Connect(function(who, rig)
			table.insert(fired, { who, rig })
		end)
		RigRegistry.register(registry, p, a)
		expect(RigRegistry.rigFor(registry, 2)).to.equal(a)
		expect(RigRegistry.userIdFor(registry, a)).to.equal(2)
		expect(p.Character).to.equal(a)
		expect(#fired).to.equal(1)
		expect(fired[1][1]).to.equal(p)
		expect(fired[1][2]).to.equal(a)
	end)

	it("never touches the local player's Character (OwnerRig owns it)", function()
		local me, rig = player(LOCAL_ID), model("Mine")
		RigRegistry.register(registry, me, rig)
		expect(me.Character).to.equal(nil)
		RigRegistry.unregister(registry, me, rig)
		expect(RigRegistry.rigFor(registry, LOCAL_ID)).to.equal(nil)
	end)

	it("unregister clears both lookups and the Character, and fires despawned", function()
		local p, a = player(2), model("A")
		local fired = 0
		registry.despawned:Connect(function()
			fired += 1
		end)
		RigRegistry.register(registry, p, a)
		RigRegistry.unregister(registry, p, a)
		expect(RigRegistry.rigFor(registry, 2)).to.equal(nil)
		expect(RigRegistry.userIdFor(registry, a)).to.equal(nil)
		expect(p.Character).to.equal(nil)
		expect(fired).to.equal(1)
	end)

	it("a stale unregister (an older rig) is a no-op: the newer rig and Character stay", function()
		local p, a, b = player(2), model("A"), model("B")
		local fired = 0
		registry.despawned:Connect(function()
			fired += 1
		end)
		RigRegistry.register(registry, p, a)
		RigRegistry.register(registry, p, b)
		RigRegistry.unregister(registry, p, a)
		expect(RigRegistry.rigFor(registry, 2)).to.equal(b)
		expect(p.Character).to.equal(b)
		expect(fired).to.equal(0)
	end)

	-- Review focus 1: a pooled puppet released by player 2, reused by player 3, then a late unregister for 2.
	it("a reused puppet keeps its new owner's lookups and Character after a late unregister", function()
		local p2, p3, a = player(2), player(3), model("A")
		RigRegistry.register(registry, p2, a)
		RigRegistry.unregister(registry, p2, a)
		RigRegistry.register(registry, p3, a)
		RigRegistry.unregister(registry, p2, a) -- late and stale
		expect(RigRegistry.rigFor(registry, 3)).to.equal(a)
		expect(RigRegistry.userIdFor(registry, a)).to.equal(3)
		expect(p3.Character).to.equal(a)
		expect(p2.Character).to.equal(nil)
	end)

	it("unregister leaves a Character that points somewhere else alone", function()
		local p, a, other = player(2), model("A"), model("Other")
		RigRegistry.register(registry, p, a)
		p.Character = other
		RigRegistry.unregister(registry, p, a)
		expect(p.Character).to.equal(other)
	end)
end
```

- [ ] **Step 2: Confirm it fails**

`RigRegistry` does not exist: the `require` fails.

- [ ] **Step 3: Implement `RigRegistry.luau`**

```lua
--!strict
--[=[
	RigRegistry: this client's player ↔ rig registry (the R2 body API: `bodySpawned` / `bodyDespawned`,
	`getRig`, `getPlayerFromRig`), moved out of CharacterReplicationServiceClient.

	R5 (spec 2026-10-05 §2.1): it is also the ONE writer of a REMOTE player's `Player.Character`. Registering
	a remote player's puppet sets `Character` to it; unregistering clears it only if it still points at that
	puppet. The engine then draws its own speaking icon over the puppet (CP12 T5a). It is client-local — the
	server keeps `Character = nil` (measured). The local player's `Character` belongs to OwnerRig; this never
	touches it. Nothing reads a remote player's `Character`: this registry stays the source of truth.

	A stale unregister (a rig that is no longer the player's current one) is a no-op, so a pooled puppet reused
	by another player never loses its new owner's lookups or `Character`.

	@class RigRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)

local RigRegistry = {}

export type Registry = {
	localUserId: number,
	rigsByUserId: { [number]: Model },
	userIdsByRig: { [Model]: number },
	spawned: SignalTyped.Signal<Player, Model>,
	despawned: SignalTyped.Signal<Player, Model>,
}

--[=[
	@param localUserId number -- this client's player
	@return Registry
]=]
function RigRegistry.new(localUserId: number): Registry
	return {
		localUserId = localUserId,
		rigsByUserId = {},
		userIdsByRig = {},
		spawned = SignalTyped.new(),
		despawned = SignalTyped.new(),
	}
end

--[=[
	Maps `player` ↔ `model`, sets a remote player's `Character`, and fires `spawned`.
	@param registry Registry
	@param player Player
	@param model Model
]=]
function RigRegistry.register(registry: Registry, player: Player, model: Model)
	registry.rigsByUserId[player.UserId] = model
	registry.userIdsByRig[model] = player.UserId
	if player.UserId ~= registry.localUserId then
		player.Character = model
	end
	registry.spawned:Fire(player, model)
end

--[=[
	Undoes `register` when `model` is still `player`'s current rig; otherwise does nothing.
	@param registry Registry
	@param player Player
	@param model Model
]=]
function RigRegistry.unregister(registry: Registry, player: Player, model: Model)
	if registry.rigsByUserId[player.UserId] ~= model then
		return
	end
	registry.rigsByUserId[player.UserId] = nil
	registry.userIdsByRig[model] = nil
	if player.UserId ~= registry.localUserId and player.Character == model then
		player.Character = nil
	end
	registry.despawned:Fire(player, model)
end

--[=[
	@param registry Registry
	@param userId number
	@return Model?
]=]
function RigRegistry.rigFor(registry: Registry, userId: number): Model?
	return registry.rigsByUserId[userId]
end

--[=[
	@param registry Registry
	@param model Model
	@return number?
]=]
function RigRegistry.userIdFor(registry: Registry, model: Model): number?
	return registry.userIdsByRig[model]
end

return RigRegistry
```

- [ ] **Step 4: Wire it into `CharacterReplicationServiceClient.luau`**

1. Add the require beside the other `script.Parent` requires:

```lua
local RigRegistry = require(script.Parent.RigRegistry)
```

2. Delete the two lines `local rigsByUserId: { [number]: Model } = {}` and `local userIdsByRig: { [Model]: number } = {}`.
3. Replace the two signal lines

```lua
local bodySpawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()
local bodyDespawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()
```

with

```lua
-- The player ↔ rig registry and the body signals; also the one writer of remote players' `Character` (R5).
local registry = RigRegistry.new(Players.LocalPlayer.UserId)
```

4. Delete the local functions `registerRig` and `unregisterRig` (lines 105–117).
5. Replace every call: `registerRig(X, Y)` → `RigRegistry.register(registry, X, Y)` and
   `unregisterRig(X, Y)` → `RigRegistry.unregister(registry, X, Y)` (in `dropOwnerRig`, `buildOwnerRig`,
   `releasePuppet`, `renderPuppets`).
6. In the service literal: `bodySpawned = registry.spawned,` and `bodyDespawned = registry.despawned,`.
7. `getRig = function(_self, player) return RigRegistry.rigFor(registry, player.UserId) end,`
8. `getPlayerFromRig`:

```lua
	getPlayerFromRig = function(_self, rig)
		local userId = RigRegistry.userIdFor(registry, rig)
		return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	end,
```

9. If `SignalTyped` is no longer used in the file, remove its `require` (the type block still names
   `SignalTyped.Signal<Player, Model>` for `bodySpawned` — keep the require if so).
10. In the header's "Body API" paragraph add: "The registry lives in RigRegistry, which also sets each remote
    player's `Character` to their puppet (R5) so the engine draws its speaking icon; nothing reads it."

- [ ] **Step 5: Check size, lint, format**

Run: `python scripts/python/check_file_length.py && stylua src/ReplicatedStorage/Client/Services/CharacterReplicationService/ && selene src/ReplicatedStorage/Client/Services/CharacterReplicationService/`
Expected: "All first-party modules within 400 code lines", `0 errors`. `grep -n "rigsByUserId\|userIdsByRig\|registerRig\|unregisterRig" src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau` prints nothing.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService/
git commit -m "feat(replication): RigRegistry owns the rig registry and sets remote players' Character to their puppet"
```

---

### Task 4: `ReplicationTripwire` (pure)

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.luau`
- Test: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.spec.luau`

**Interfaces:**
- Produces:
  - `export type Check = "missing" | "unknownPlayer" | "orphan" | "duplicate" | "characterMismatch"`
  - `export type BodyView = { slot: number, userId: number, generation: number, epoch: number, held: boolean, placed: boolean, dressed: boolean, bufferEmpty: boolean, playerPresent: boolean }`
  - `export type HeldView = { slot: number, ownerUserId: number }`
  - `export type CharacterView = { userId: number, matches: boolean }`
  - `export type Snapshot = { otherUserIds: { number }, knownUserIds: { [number]: boolean }, bodies: { BodyView }, held: { HeldView }, characters: { CharacterView } }`
  - `export type Episode = { check: Check, key: string, reason: string, detail: string, startedAt: number, endedAt: number? }`
  - `export type Tripwire` (opaque to callers)
  - `ReplicationTripwire.ALLOWANCE: { [string]: number }` (seconds, by reason)
  - `ReplicationTripwire.new(): Tripwire`
  - `ReplicationTripwire.check(tripwire: Tripwire, snapshot: Snapshot, now: number): ({ Episode }, { Episode })` — (started, ended)
  - `ReplicationTripwire.describe(episode: Episode): string`
  - `ReplicationTripwire.getState(tripwire: Tripwire): { checks: number, counts: { [string]: number }, open: { string } }`

- [ ] **Step 1: Write the failing spec**

```lua
--!strict
--[=[
	Unit tests for ReplicationTripwire (R5 spec §1.2): each check, its allowance, episode start / end, and the
	two review-focus cases (a reason change restarts the allowance; a rejoin gets a fresh first-seen time).
]=]

local ReplicationTripwire = require(script.Parent.ReplicationTripwire)

return function()
	local tripwire

	-- A healthy view: player 2 in slot 4, visible, held, dressed, placed, Character correct.
	local function healthy()
		return {
			otherUserIds = { 2 },
			knownUserIds = { [2] = true },
			bodies = {
				{
					slot = 4,
					userId = 2,
					generation = 1,
					epoch = 3,
					held = true,
					placed = true,
					dressed = true,
					bufferEmpty = false,
					playerPresent = true,
				},
			},
			held = { { slot = 4, ownerUserId = 2 } },
			characters = { { userId = 2, matches = true } },
		}
	end

	beforeEach(function()
		tripwire = ReplicationTripwire.new()
	end)

	it("a healthy view opens nothing", function()
		local started, ended = ReplicationTripwire.check(tripwire, healthy(), 0)
		expect(#started).to.equal(0)
		expect(#ended).to.equal(0)
		started = ReplicationTripwire.check(tripwire, healthy(), 10)
		expect(#started).to.equal(0)
	end)

	it("missing (not placed) opens after 0.5 s, not before, and ends when placed", function()
		local view = healthy()
		view.bodies[1].placed = false
		expect(#ReplicationTripwire.check(tripwire, view, 0)).to.equal(0)
		expect(#ReplicationTripwire.check(tripwire, view, 0.4)).to.equal(0)
		local started = ReplicationTripwire.check(tripwire, view, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("missing")
		expect(started[1].reason).to.equal("notPlaced")
		local _, ended = ReplicationTripwire.check(tripwire, healthy(), 1.2)
		expect(#ended).to.equal(1)
		expect(ended[1].endedAt).to.equal(1.2)
		expect(ReplicationTripwire.getState(tripwire).counts.missing).to.equal(1)
	end)

	it("an undressed puppet is allowed 1.5 s, an empty buffer 2 s, a missing Player 3 s", function()
		local undressed = healthy()
		undressed.bodies[1].dressed = false
		undressed.bodies[1].placed = false
		ReplicationTripwire.check(tripwire, undressed, 0)
		expect(#ReplicationTripwire.check(tripwire, undressed, 1.4)).to.equal(0)
		expect(#ReplicationTripwire.check(tripwire, undressed, 1.5)).to.equal(1)

		tripwire = ReplicationTripwire.new()
		local empty = healthy()
		empty.bodies[1].bufferEmpty = true
		empty.bodies[1].placed = false
		ReplicationTripwire.check(tripwire, empty, 0)
		expect(#ReplicationTripwire.check(tripwire, empty, 1.9)).to.equal(0)
		expect(#ReplicationTripwire.check(tripwire, empty, 2)).to.equal(1)

		tripwire = ReplicationTripwire.new()
		local noPlayer = healthy()
		noPlayer.bodies[1].playerPresent = false
		noPlayer.bodies[1].held = false
		noPlayer.held = {}
		ReplicationTripwire.check(tripwire, noPlayer, 0)
		expect(#ReplicationTripwire.check(tripwire, noPlayer, 2.9)).to.equal(0)
		expect(#ReplicationTripwire.check(tripwire, noPlayer, 3)).to.equal(1)
	end)

	-- Review focus 4.
	it("a reason change restarts the allowance for the new reason", function()
		local noPlayer = healthy()
		noPlayer.bodies[1].playerPresent = false
		noPlayer.bodies[1].held = false
		noPlayer.held = {}
		ReplicationTripwire.check(tripwire, noPlayer, 0)
		ReplicationTripwire.check(tripwire, noPlayer, 2.5)
		local undressed = healthy()
		undressed.bodies[1].dressed = false
		undressed.bodies[1].placed = false
		expect(#ReplicationTripwire.check(tripwire, undressed, 2.6)).to.equal(0) -- not 2.6 s "undressed"
		expect(#ReplicationTripwire.check(tripwire, undressed, 4.0)).to.equal(0)
		-- 4.2, not 4.1: 4.1 - 2.6 is 1.4999… in floating point.
		local started = ReplicationTripwire.check(tripwire, undressed, 4.2)
		expect(#started).to.equal(1)
		expect(started[1].reason).to.equal("undressed")
	end)

	it("unknownPlayer counts from first seen and ends when the slot entry arrives", function()
		local view = healthy()
		view.otherUserIds = { 2, 7 }
		ReplicationTripwire.check(tripwire, view, 0)
		expect(#ReplicationTripwire.check(tripwire, view, 2.9)).to.equal(0)
		local started = ReplicationTripwire.check(tripwire, view, 3)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("unknownPlayer")
		view.knownUserIds[7] = true
		local _, ended = ReplicationTripwire.check(tripwire, view, 4)
		expect(#ended).to.equal(1)
	end)

	-- Review focus 5.
	it("a player who leaves and rejoins gets a fresh first-seen time", function()
		local view = healthy()
		view.otherUserIds = { 2, 7 }
		ReplicationTripwire.check(tripwire, view, 0)
		ReplicationTripwire.check(tripwire, healthy(), 2) -- 7 left
		ReplicationTripwire.check(tripwire, view, 10) -- 7 is back, still no entry
		expect(#ReplicationTripwire.check(tripwire, view, 12.9)).to.equal(0)
		expect(#ReplicationTripwire.check(tripwire, view, 13)).to.equal(1)
	end)

	it("orphan: a held puppet with no visible body, or the wrong owner", function()
		local noBody = healthy()
		noBody.held = { { slot = 4, ownerUserId = 2 }, { slot = 9, ownerUserId = 5 } }
		ReplicationTripwire.check(tripwire, noBody, 0)
		local started = ReplicationTripwire.check(tripwire, noBody, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("orphan")
		expect(started[1].reason).to.equal("noBody")

		tripwire = ReplicationTripwire.new()
		local wrongOwner = healthy()
		wrongOwner.held = { { slot = 4, ownerUserId = 5 } }
		ReplicationTripwire.check(tripwire, wrongOwner, 0)
		started = ReplicationTripwire.check(tripwire, wrongOwner, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].reason).to.equal("ownerMismatch")
	end)

	it("duplicate opens at once", function()
		local view = healthy()
		view.bodies[2] = {
			slot = 6,
			userId = 2,
			generation = 1,
			epoch = 3,
			held = true,
			placed = true,
			dressed = true,
			bufferEmpty = false,
			playerPresent = true,
		}
		view.held = { { slot = 4, ownerUserId = 2 }, { slot = 6, ownerUserId = 2 } }
		local started = ReplicationTripwire.check(tripwire, view, 0)
		local checks = {}
		for _, episode in started do
			checks[episode.check] = true
		end
		expect(checks.duplicate).to.equal(true)
	end)

	it("characterMismatch opens after 0.5 s", function()
		local view = healthy()
		view.characters = { { userId = 2, matches = false } }
		ReplicationTripwire.check(tripwire, view, 0)
		local started = ReplicationTripwire.check(tripwire, view, 0.5)
		expect(#started).to.equal(1)
		expect(started[1].check).to.equal("characterMismatch")
	end)

	it("getState lists open episodes and describe names the reason and the duration", function()
		local view = healthy()
		view.bodies[1].placed = false
		ReplicationTripwire.check(tripwire, view, 0)
		local started = ReplicationTripwire.check(tripwire, view, 1)
		local state = ReplicationTripwire.getState(tripwire)
		expect(state.checks).to.equal(2)
		expect(#state.open).to.equal(1)
		local _, ended = ReplicationTripwire.check(tripwire, healthy(), 3)
		expect(string.find(ReplicationTripwire.describe(started[1]), "notPlaced", 1, true) ~= nil).to.equal(true)
		expect(string.find(ReplicationTripwire.describe(ended[1]), "3.0 s", 1, true) ~= nil).to.equal(true)
	end)
end
```

- [ ] **Step 2: Confirm it fails** — the module does not exist; the `require` fails.

- [ ] **Step 3: Implement `ReplicationTripwire.luau`**

```lua
--!strict
--[=[
	ReplicationTripwire (R5 spec 2026-10-05 §1.2): checks that what this client SHOWS matches what the server
	says it should see. Pure — the caller builds a Snapshot (ReplicationDiagnostics) and passes the time.

	Every condition here is a bug, never a state to heal: a body in view with no placed puppet past its
	allowance, a player with no slot-table entry, an orphaned or duplicated puppet, a remote `Character`
	that disagrees with the registry. A condition becomes an EPISODE once it has held past the allowance for
	its reason; the episode ends when the condition clears. Callers log one line per start and per end.

	A reason change restarts the allowance (no Player → not dressed is a new wait, not a continuation).
	`unknownPlayer` counts from the first check that saw the player; a player who leaves is forgotten, so a
	rejoin starts fresh.

	@class ReplicationTripwire
]=]

local ReplicationTripwire = {}

export type Check = "missing" | "unknownPlayer" | "orphan" | "duplicate" | "characterMismatch"

export type BodyView = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	held: boolean,
	placed: boolean,
	dressed: boolean,
	bufferEmpty: boolean,
	playerPresent: boolean,
}

export type HeldView = { slot: number, ownerUserId: number }

export type CharacterView = { userId: number, matches: boolean }

export type Snapshot = {
	otherUserIds: { number },
	knownUserIds: { [number]: boolean },
	bodies: { BodyView }, -- visible bodies only
	held: { HeldView },
	characters: { CharacterView },
}

export type Episode = {
	check: Check,
	key: string,
	reason: string,
	detail: string,
	startedAt: number,
	endedAt: number?,
}

type Pending = { check: Check, reason: string, detail: string, since: number }

export type Tripwire = {
	pending: { [string]: Pending },
	open: { [string]: Episode },
	firstSeen: { [number]: number },
	counts: { [string]: number },
	checks: number,
}

-- Seconds a condition may hold before it is an episode, by reason.
local ALLOWANCE: { [string]: number } = {
	noPlayer = 3, -- the Player object has not replicated to this client yet
	notHeld = 0.5, -- the pool has not given it a puppet (it builds one per frame)
	undressed = 1.5, -- the dressed rule parks it; the default look lands after 1 s
	emptyBuffer = 2, -- just respawned: hidden until the first new-epoch sample
	notPlaced = 0.5,
	noSlotEntry = 3,
	noBody = 0.5,
	ownerMismatch = 0.5,
	twoPuppets = 0,
	characterMismatch = 0.5,
}
ReplicationTripwire.ALLOWANCE = ALLOWANCE

--[=[
	@return Tripwire
]=]
function ReplicationTripwire.new(): Tripwire
	return { pending = {}, open = {}, firstSeen = {}, counts = {}, checks = 0 }
end

local function missingReason(body: BodyView): string?
	if not body.playerPresent then
		return "noPlayer"
	elseif not body.held then
		return "notHeld"
	elseif not body.dressed then
		return "undressed"
	elseif body.bufferEmpty then
		return "emptyBuffer"
	elseif not body.placed then
		return "notPlaced"
	end
	return nil
end

--[=[
	Runs every check against `snapshot` at `now` (seconds, any monotonic clock).
	@return { Episode } -- episodes that started this check
	@return { Episode } -- episodes that ended this check (with `endedAt`)
]=]
function ReplicationTripwire.check(tripwire: Tripwire, snapshot: Snapshot, now: number): ({ Episode }, { Episode })
	tripwire.checks += 1
	local seen: { [string]: Pending } = {}
	local function hold(check: Check, key: string, reason: string, detail: string, since: number?)
		local fullKey = `{check}:{key}`
		local previous = tripwire.pending[fullKey]
		local start = if previous ~= nil and previous.reason == reason then previous.since else (since or now)
		seen[fullKey] = { check = check, reason = reason, detail = detail, since = start }
	end

	local bodyBySlot: { [number]: BodyView } = {}
	for _, body in snapshot.bodies do
		bodyBySlot[body.slot] = body
		local reason = missingReason(body)
		if reason ~= nil then
			hold(
				"missing",
				tostring(body.slot),
				reason,
				`slot {body.slot} user {body.userId} gen {body.generation} epoch {body.epoch}`
			)
		end
	end

	local present: { [number]: boolean } = {}
	for _, userId in snapshot.otherUserIds do
		present[userId] = true
		local first = tripwire.firstSeen[userId]
		if first == nil then
			first = now
			tripwire.firstSeen[userId] = now
		end
		if not snapshot.knownUserIds[userId] then
			hold("unknownPlayer", tostring(userId), "noSlotEntry", `user {userId}`, first)
		end
	end
	for userId in tripwire.firstSeen do
		if not present[userId] then
			tripwire.firstSeen[userId] = nil
		end
	end

	local slotsByOwner: { [number]: { number } } = {}
	for _, entry in snapshot.held do
		local body = bodyBySlot[entry.slot]
		if body == nil then
			hold("orphan", tostring(entry.slot), "noBody", `slot {entry.slot} owner {entry.ownerUserId}`)
		elseif body.userId ~= entry.ownerUserId then
			hold(
				"orphan",
				tostring(entry.slot),
				"ownerMismatch",
				`slot {entry.slot} owner {entry.ownerUserId} body user {body.userId}`
			)
		end
		local slots = slotsByOwner[entry.ownerUserId] or {}
		table.insert(slots, entry.slot)
		slotsByOwner[entry.ownerUserId] = slots
	end
	for owner, slots in slotsByOwner do
		if #slots > 1 then
			table.sort(slots)
			hold("duplicate", tostring(owner), "twoPuppets", `user {owner} slots {table.concat(slots, ",")}`)
		end
	end

	for _, character in snapshot.characters do
		if not character.matches then
			hold("characterMismatch", tostring(character.userId), "characterMismatch", `user {character.userId}`)
		end
	end

	local started: { Episode } = {}
	local ended: { Episode } = {}
	for key, pending in seen do
		if tripwire.open[key] == nil and now - pending.since >= (ALLOWANCE[pending.reason] or 0) then
			local episode: Episode = {
				check = pending.check,
				key = key,
				reason = pending.reason,
				detail = pending.detail,
				startedAt = pending.since,
				endedAt = nil,
			}
			tripwire.open[key] = episode
			tripwire.counts[pending.check] = (tripwire.counts[pending.check] or 0) + 1
			table.insert(started, episode)
		end
	end
	for key, episode in tripwire.open do
		if seen[key] == nil then
			tripwire.open[key] = nil
			episode.endedAt = now
			table.insert(ended, episode)
		end
	end
	tripwire.pending = seen
	return started, ended
end

--[=[
	One log line: check, reason, detail, and the duration once it has ended.
	@param episode Episode
	@return string
]=]
function ReplicationTripwire.describe(episode: Episode): string
	local endedAt = episode.endedAt
	local duration = if endedAt ~= nil
		then string.format(" · lasted %.1f s", endedAt - episode.startedAt)
		else ""
	return `{episode.check} ({episode.reason}) {episode.detail}{duration}`
end

--[=[
	For F4: how many checks ran, episodes per check so far, and the open episodes.
	@param tripwire Tripwire
]=]
function ReplicationTripwire.getState(tripwire: Tripwire): { checks: number, counts: { [string]: number }, open: { string } }
	local open: { string } = {}
	for _, episode in tripwire.open do
		table.insert(open, ReplicationTripwire.describe(episode))
	end
	table.sort(open)
	return { checks = tripwire.checks, counts = table.clone(tripwire.counts), open = open }
end

return ReplicationTripwire
```

Note on the describe test: the episode that started at `0` and ended at `3` has duration `3.0 s`, which the
spec searches for ("lasted 3.0 s" contains "3.0 s").

- [ ] **Step 4: Lint and format**

Run: `stylua src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.luau src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.spec.luau && selene src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.luau`
Expected: `0 errors`.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.luau src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationTripwire.spec.luau
git commit -m "feat(replication): ReplicationTripwire checks the shown puppets against the server's view"
```

---

### Task 5: `ReplicationDiagnostics` — the snapshot and the `Diagnostics` gate

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationDiagnostics.luau`
- Test: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/ReplicationDiagnostics.spec.luau`
- Modify: `CharacterReplicationServiceClient.luau` (the `HeldPuppet` type, `init`, `getState`)

**Interfaces:**
- Consumes: `RemoteBodies.State` (`bodies: { [number]: Body }` with `userId`, `generation`, `epoch`, `visible`,
  `samples.samples`), `PuppetPool.Puppet` (`outfit`), `RigOutfit.isDressed(outfit)`, Task 3's
  `RigRegistry.Registry` / `RigRegistry.rigFor`, Task 4's `ReplicationTripwire` API.
- Produces:
  - `export type HeldPuppet = { puppet: PuppetPool.Puppet, player: Player }`
  - `export type View = { remote: RemoteBodies.State, held: { [number]: HeldPuppet }, placed: { [number]: boolean }, registry: RigRegistry.Registry, players: { Player } }`
  - `ReplicationDiagnostics.ATTRIBUTE = "Diagnostics"`, `ReplicationDiagnostics.INTERVAL_SECONDS = 1`
  - `ReplicationDiagnostics.snapshot(view: View): ReplicationTripwire.Snapshot`
  - `export type Watcher`; `ReplicationDiagnostics.watch(readView: () -> View?, log: Logger.Logger): Watcher`;
    `ReplicationDiagnostics.stop(watcher: Watcher)`; `ReplicationDiagnostics.getState(watcher: Watcher): { enabled: boolean, checks: number, counts: { [string]: number }, open: { string } }`

- [ ] **Step 1: Write the failing spec** (covers `snapshot`; the gate is exercised in Studio, Task 11)

```lua
--!strict
--[=[
	Unit tests for ReplicationDiagnostics.snapshot — the view the tripwire checks. The gate (Workspace
	`Diagnostics`, a 1 Hz thread) is an Instance/scheduler shell, verified in Studio (plan Task 11).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationDiagnostics = require(script.Parent.ReplicationDiagnostics)
local RigRegistry = require(script.Parent.RigRegistry)
local RigOutfit = require(ReplicatedStorage.Shared.Modules.RigOutfit)
local OutfitDiff = require(ReplicatedStorage.Shared.Modules.OutfitDiff)

return function()
	local rigs

	local function player(userId)
		return { UserId = userId, Name = `user{userId}`, Character = nil }
	end

	local function puppet(dressed)
		local model = Instance.new("Model")
		table.insert(rigs, model)
		local outfit = RigOutfit.new(model)
		if dressed then
			RigOutfit.setWorn(outfit, OutfitDiff.empty(), 1)
		end
		return { model = model, outfit = outfit }
	end

	local function body(userId, visible, samples)
		return { userId = userId, generation = 1, epoch = 2, visible = visible, samples = { samples = samples } }
	end

	beforeEach(function()
		rigs = {}
	end)

	afterEach(function()
		for _, model in rigs do
			model:Destroy()
		end
	end)

	it("reports each visible body's state and skips hidden ones", function()
		local me, p2, p3 = player(1), player(2), player(3)
		local registry = RigRegistry.new(1)
		local dressed = puppet(true)
		RigRegistry.register(registry, p2, dressed.model)
		local view = {
			remote = { bodies = { [4] = body(2, true, { {} }), [5] = body(3, false, {}) } },
			held = { [4] = { puppet = dressed, player = p2 } },
			placed = { [4] = true },
			registry = registry,
			players = { me, p2, p3 },
		}
		local snapshot = ReplicationDiagnostics.snapshot(view)
		expect(#snapshot.bodies).to.equal(1)
		local b = snapshot.bodies[1]
		expect(b.slot).to.equal(4)
		expect(b.held).to.equal(true)
		expect(b.placed).to.equal(true)
		expect(b.dressed).to.equal(true)
		expect(b.bufferEmpty).to.equal(false)
		expect(b.playerPresent).to.equal(true)
		expect(snapshot.knownUserIds[2]).to.equal(true)
		expect(snapshot.knownUserIds[3]).to.equal(true) -- known even while hidden
		expect(#snapshot.otherUserIds).to.equal(2) -- never the local player
		expect(#snapshot.held).to.equal(1)
		expect(snapshot.held[1].ownerUserId).to.equal(2)
	end)

	it("flags an undressed puppet, an empty buffer and a missing Player", function()
		local registry = RigRegistry.new(1)
		local undressed = puppet(false)
		local view = {
			remote = { bodies = { [4] = body(2, true, {}) } },
			held = { [4] = { puppet = undressed, player = player(2) } },
			placed = {},
			registry = registry,
			players = { player(1) },
		}
		local b = ReplicationDiagnostics.snapshot(view).bodies[1]
		expect(b.dressed).to.equal(false)
		expect(b.bufferEmpty).to.equal(true)
		expect(b.playerPresent).to.equal(false)
		expect(b.placed).to.equal(false)
	end)

	it("a remote Character matches only the registry's rig (or nil when there is none)", function()
		local registry = RigRegistry.new(1)
		local p2, p3 = player(2), player(3)
		local a = puppet(true)
		RigRegistry.register(registry, p2, a.model)
		p3.Character = a.model -- wrong: the registry holds nothing for 3
		local view = { remote = { bodies = {} }, held = {}, placed = {}, registry = registry, players = { player(1), p2, p3 } }
		local matches = {}
		for _, c in ReplicationDiagnostics.snapshot(view).characters do
			matches[c.userId] = c.matches
		end
		expect(matches[2]).to.equal(true)
		expect(matches[3]).to.equal(false)
	end)
end
```

- [ ] **Step 2: Confirm it fails** — the module does not exist.

- [ ] **Step 3: Implement `ReplicationDiagnostics.luau`**

```lua
--!strict
--[=[
	ReplicationDiagnostics (R5 spec 2026-10-05 §1.2): builds ReplicationTripwire's snapshot from the client
	service's view, and runs the tripwire once a second ONLY while Workspace `Diagnostics` is true.

	Off = nothing runs: the 1 Hz thread does not exist (cancelled, not skipped) and the tripwire's state is
	dropped. The attribute listener is the only cost. One `log:warn` per episode start and end. No recovery:
	an episode is a bug to root-cause (spec decision 7).

	@class ReplicationDiagnostics
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local RigOutfit = require(ReplicatedStorage.Shared.Modules.RigOutfit)
local RemoteBodies = require(script.Parent.RemoteBodies)
local PuppetPool = require(script.Parent.PuppetPool)
local RigRegistry = require(script.Parent.RigRegistry)
local ReplicationTripwire = require(script.Parent.ReplicationTripwire)

local ReplicationDiagnostics = {}

ReplicationDiagnostics.ATTRIBUTE = "Diagnostics"
ReplicationDiagnostics.INTERVAL_SECONDS = 1

export type HeldPuppet = { puppet: PuppetPool.Puppet, player: Player }

export type View = {
	remote: RemoteBodies.State,
	held: { [number]: HeldPuppet },
	placed: { [number]: boolean }, -- slots placed in the last rendered frame
	registry: RigRegistry.Registry,
	players: { Player },
}

export type Watcher = {
	tripwire: ReplicationTripwire.Tripwire?,
	thread: thread?,
	connection: RBXScriptConnection,
}

--[=[
	The tripwire's view of this client: every other player, every known body (visible ones in detail), every
	held puppet, and whether each remote player's `Character` is the registry's rig for them.
	@param view View
	@return ReplicationTripwire.Snapshot
]=]
function ReplicationDiagnostics.snapshot(view: View): ReplicationTripwire.Snapshot
	local localUserId = view.registry.localUserId
	local present: { [number]: Player } = {}
	local others: { number } = {}
	for _, player in view.players do
		present[player.UserId] = player
		if player.UserId ~= localUserId then
			table.insert(others, player.UserId)
		end
	end
	local known: { [number]: boolean } = {}
	local bodies: { ReplicationTripwire.BodyView } = {}
	for slot, body in view.remote.bodies do
		known[body.userId] = true
		if body.visible then
			local entry = view.held[slot]
			table.insert(bodies, {
				slot = slot,
				userId = body.userId,
				generation = body.generation,
				epoch = body.epoch,
				held = entry ~= nil,
				placed = view.placed[slot] == true,
				dressed = entry ~= nil and RigOutfit.isDressed(entry.puppet.outfit),
				bufferEmpty = #body.samples.samples == 0,
				playerPresent = present[body.userId] ~= nil,
			})
		end
	end
	local held: { ReplicationTripwire.HeldView } = {}
	for slot, entry in view.held do
		table.insert(held, { slot = slot, ownerUserId = entry.player.UserId })
	end
	local characters: { ReplicationTripwire.CharacterView } = {}
	for _, userId in others do
		local player = present[userId]
		table.insert(characters, {
			userId = userId,
			matches = player.Character == RigRegistry.rigFor(view.registry, userId),
		})
	end
	return { otherUserIds = others, knownUserIds = known, bodies = bodies, held = held, characters = characters }
end

local function runOnce(watcher: Watcher, readView: () -> View?, log: Logger.Logger)
	local tripwire = watcher.tripwire
	local view = readView()
	if tripwire == nil or view == nil then
		return
	end
	local started, ended = ReplicationTripwire.check(tripwire, ReplicationDiagnostics.snapshot(view), os.clock())
	for _, episode in started do
		log:warn(`tripwire: {ReplicationTripwire.describe(episode)}`)
	end
	for _, episode in ended do
		log:warn(`tripwire cleared: {ReplicationTripwire.describe(episode)}`)
	end
end

local function sync(watcher: Watcher, readView: () -> View?, log: Logger.Logger)
	local on = Workspace:GetAttribute(ReplicationDiagnostics.ATTRIBUTE) == true
	local thread = watcher.thread
	if on and thread == nil then
		watcher.tripwire = ReplicationTripwire.new()
		watcher.thread = task.spawn(function()
			while true do
				task.wait(ReplicationDiagnostics.INTERVAL_SECONDS)
				runOnce(watcher, readView, log)
			end
		end)
	elseif not on and thread ~= nil then
		task.cancel(thread)
		watcher.thread = nil
		watcher.tripwire = nil
	end
end

--[=[
	Starts watching Workspace `Diagnostics`. `readView` returns nil until the service has a view.
	@param readView () -> View?
	@param log Logger.Logger
	@return Watcher
]=]
function ReplicationDiagnostics.watch(readView: () -> View?, log: Logger.Logger): Watcher
	local watcher: Watcher
	watcher = {
		tripwire = nil,
		thread = nil,
		connection = Workspace:GetAttributeChangedSignal(ReplicationDiagnostics.ATTRIBUTE):Connect(function()
			sync(watcher, readView, log)
		end),
	}
	sync(watcher, readView, log)
	return watcher
end

--[=[
	Stops the listener and the check thread.
	@param watcher Watcher
]=]
function ReplicationDiagnostics.stop(watcher: Watcher)
	watcher.connection:Disconnect()
	local thread = watcher.thread
	if thread ~= nil then
		task.cancel(thread)
		watcher.thread = nil
	end
	watcher.tripwire = nil
end

--[=[
	For F4. `enabled = false` (and zero counts) while `Diagnostics` is off.
	@param watcher Watcher
]=]
function ReplicationDiagnostics.getState(
	watcher: Watcher
): { enabled: boolean, checks: number, counts: { [string]: number }, open: { string } }
	local tripwire = watcher.tripwire
	if tripwire == nil then
		return { enabled = false, checks = 0, counts = {}, open = {} }
	end
	local state = ReplicationTripwire.getState(tripwire)
	return { enabled = true, checks = state.checks, counts = state.counts, open = state.open }
end

return ReplicationDiagnostics
```

If `local watcher: Watcher` followed by the assignment trips the typechecker ("used before init" inside the
closure), restructure as: create `watcher` with `connection` set after construction — make `connection`
`RBXScriptConnection?` in the type, assign it on the next line, and have `stop` check for nil. Do not cast.

- [ ] **Step 4: Wire it into `CharacterReplicationServiceClient.luau`**

1. Add `local ReplicationDiagnostics = require(script.Parent.ReplicationDiagnostics)`.
2. Replace `type HeldPuppet = { puppet: PuppetPool.Puppet, player: Player }` with
   `type HeldPuppet = ReplicationDiagnostics.HeldPuppet`.
3. Add a module local: `local diagnostics: ReplicationDiagnostics.Watcher? = nil`.
4. In `init`, right before `packets.Ready.send(true)`:

```lua
		-- R5 tripwire: runs only while Workspace `Diagnostics` is true.
		local watcher = ReplicationDiagnostics.watch(function(): ReplicationDiagnostics.View?
			return {
				remote = state,
				held = held,
				placed = placedSlots,
				registry = registry,
				players = Players:GetPlayers(),
			}
		end, log)
		diagnostics = watcher
		janitor:Add(function()
			ReplicationDiagnostics.stop(watcher)
			diagnostics = nil
		end, true)
```

5. In `getState`'s returned table add:

```lua
			tripwire = if diagnostics ~= nil then ReplicationDiagnostics.getState(diagnostics) else nil,
```

- [ ] **Step 5: Check size, lint, format**

Run: `python scripts/python/check_file_length.py && stylua src/ReplicatedStorage/Client/Services/CharacterReplicationService/ && selene src/ReplicatedStorage/Client/Services/CharacterReplicationService/`
Expected: within 400 code lines, `0 errors`. If `CharacterReplicationServiceClient.luau` is over 400, move the
`getState` body into a `ReplicationDiagnostics`-style helper rather than allowlisting it.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService/
git commit -m "feat(replication): ReplicationDiagnostics runs the tripwire only while Workspace Diagnostics is on"
```

---

### Task 6: `VoiceSettings` and `VoiceServiceServer`

**Files:**
- Create: `src/ServerScriptService/Services/VoiceService/VoiceSettings.luau`
- Test: `src/ServerScriptService/Services/VoiceService/VoiceSettings.spec.luau`
- Create: `src/ServerScriptService/Services/VoiceService/VoiceServiceServer.luau`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`, beside the
  CharacterReplicationServiceServer entry)

**Interfaces:**
- Produces:
  - `export type Readings = { enableDefaultVoice: boolean, useAudioApi: Enum.AudioApiRollout, chatVersion: Enum.ChatVersion, createDefaultTextChannels: boolean }`
  - `VoiceSettings.read(): Readings`
  - `VoiceSettings.problems(readings: Readings): { string }`
  - `VoiceServiceServer` with `dependencies = {}`, `init`, `start`, `stop`, `getState` → `{ inputs: number, settingsProblems: { string } }`
  - The replicated instance contract: each `Player` gets one `AudioDeviceInput` named **`VoiceInput`** with
    `.Player` set.

- [ ] **Step 1: Write the failing spec** (`VoiceSettings.spec.luau`)

```lua
--!strict
--[=[
	Unit tests for VoiceSettings.problems — the place settings R5 voice and chat depend on (spec §2.4).
]=]

local VoiceSettings = require(script.Parent.VoiceSettings)

return function()
	local function good()
		return {
			enableDefaultVoice = false,
			useAudioApi = Enum.AudioApiRollout.Enabled,
			chatVersion = Enum.ChatVersion.TextChatService,
			createDefaultTextChannels = true,
		}
	end

	it("reports nothing when every setting is right", function()
		expect(#VoiceSettings.problems(good())).to.equal(0)
	end)

	it("reports each wrong setting by name", function()
		local cases = {
			{ field = "enableDefaultVoice", value = true, name = "EnableDefaultVoice" },
			{ field = "useAudioApi", value = Enum.AudioApiRollout.Automatic, name = "UseAudioApi" },
			{ field = "chatVersion", value = Enum.ChatVersion.LegacyChatService, name = "ChatVersion" },
			{ field = "createDefaultTextChannels", value = false, name = "CreateDefaultTextChannels" },
		}
		for _, case in cases do
			local readings = good()
			readings[case.field] = case.value
			local problems = VoiceSettings.problems(readings)
			expect(#problems).to.equal(1)
			expect(string.find(problems[1], case.name, 1, true) ~= nil).to.equal(true)
		end
	end)

	it("says ChatVersion must be set by hand", function()
		local readings = good()
		readings.chatVersion = Enum.ChatVersion.LegacyChatService
		expect(string.find(VoiceSettings.problems(readings)[1], "by hand", 1, true) ~= nil).to.equal(true)
	end)
end
```

- [ ] **Step 2: Confirm it fails** — the module does not exist.

- [ ] **Step 3: Implement `VoiceSettings.luau`**

```lua
--!strict
--[=[
	VoiceSettings (R5 spec 2026-10-05 §2.4): the place settings voice and chat depend on, and what is wrong
	with them. `read` reads the services; `problems` is pure.

	`ChatVersion` cannot be set by Rojo or any script (Write: RobloxScriptSecurity): it is set by hand in the
	Studio Properties panel, per place. The other three are property-only nodes in default.project.json.

	@class VoiceSettings
]=]

local TextChatService = game:GetService("TextChatService")
local VoiceChatService = game:GetService("VoiceChatService")

local VoiceSettings = {}

export type Readings = {
	enableDefaultVoice: boolean,
	useAudioApi: Enum.AudioApiRollout,
	chatVersion: Enum.ChatVersion,
	createDefaultTextChannels: boolean,
}

--[=[
	@return Readings
]=]
function VoiceSettings.read(): Readings
	return {
		enableDefaultVoice = VoiceChatService.EnableDefaultVoice,
		useAudioApi = VoiceChatService.UseAudioApi,
		chatVersion = TextChatService.ChatVersion,
		createDefaultTextChannels = TextChatService.CreateDefaultTextChannels,
	}
end

--[=[
	One message per wrong setting.
	@param readings Readings
	@return { string }
]=]
function VoiceSettings.problems(readings: Readings): { string }
	local problems: { string } = {}
	if readings.enableDefaultVoice then
		table.insert(
			problems,
			"VoiceChatService.EnableDefaultVoice must be false: the engine's voice wires the server Character, "
				.. "which is nil under client-built bodies (CP12 T4)"
		)
	end
	if readings.useAudioApi ~= Enum.AudioApiRollout.Enabled then
		table.insert(problems, "VoiceChatService.UseAudioApi must be Enabled (voice is wired with the Audio API)")
	end
	if readings.chatVersion ~= Enum.ChatVersion.TextChatService then
		table.insert(
			problems,
			"TextChatService.ChatVersion must be TextChatService: set it by hand in the Properties panel "
				.. "(scripts and Rojo cannot write it)"
		)
	end
	if not readings.createDefaultTextChannels then
		table.insert(problems, "TextChatService.CreateDefaultTextChannels must be true (without it there is no chat)")
	end
	return problems
end

return VoiceSettings
```

- [ ] **Step 4: Implement `VoiceServiceServer.luau`**

```lua
--!strict
--[=[
	VoiceServiceServer (R5 spec 2026-10-05 §2.2): one `AudioDeviceInput` per player, named `VoiceInput`,
	`.Player` set, parented to the Player — the server must create it for it to replicate, and the engine
	streams that player's microphone into it. Each client wires the inputs of OTHER players to their puppet
	heads (VoiceServiceClient). No speaker parts, so no position ever leaves the server (CP3).

	At start it checks the place settings voice and chat depend on (VoiceSettings) and logs an error per
	wrong one.

	Spec-exempt shell (Players, Instances); its core VoiceSettings is specced.

	@class VoiceServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local VoiceSettings = require(script.Parent.VoiceSettings)

local INPUT_NAME = "VoiceInput"

local log = Logger.new("VoiceServiceServer")
local janitor = Janitor.new()
local inputs: { [Player]: AudioDeviceInput } = {}
local settingsProblems: { string } = {}

local function addInput(player: Player)
	if inputs[player] ~= nil then
		return
	end
	local input = Instance.new("AudioDeviceInput")
	input.Name = INPUT_NAME
	input.Player = player
	input.Parent = player
	inputs[player] = input
end

export type VoiceServiceServer = {
	dependencies: { string },
	init: (self: VoiceServiceServer) -> (),
	start: (self: VoiceServiceServer) -> (),
	stop: (self: VoiceServiceServer) -> (),
	getState: (self: VoiceServiceServer) -> { inputs: number, settingsProblems: { string } },
}

local VoiceServiceServer: VoiceServiceServer = {
	dependencies = {},

	init = function(_self)
		log:debug("VoiceServiceServer initialized")
	end,

	start = function(_self)
		settingsProblems = VoiceSettings.problems(VoiceSettings.read())
		for _, problem in settingsProblems do
			log:error(problem)
		end
		janitor:Add(Players.PlayerAdded:Connect(addInput), "Disconnect")
		janitor:Add(
			Players.PlayerRemoving:Connect(function(player: Player)
				inputs[player] = nil -- destroyed with the Player
			end),
			"Disconnect"
		)
		for _, player in Players:GetPlayers() do
			addInput(player)
		end
	end,

	stop = function(_self)
		janitor:Cleanup()
		for _, input in inputs do
			input:Destroy()
		end
		table.clear(inputs)
	end,

	getState = function(_self)
		local count = 0
		for _ in inputs do
			count += 1
		end
		return { inputs = count, settingsProblems = table.clone(settingsProblems) }
	end,
}

return VoiceServiceServer
```

- [ ] **Step 5: Exempt the shell in `SpecRoots.luau`**

In `EXEMPT_MODULES`, below the `CharacterReplicationServiceServer` line, add:

```lua
	["ServerScriptService.Services.VoiceService.VoiceServiceServer"] = "Players/Instance shell (core VoiceSettings is specced)",
```

- [ ] **Step 6: Lint, format, commit**

Run: `stylua src/ServerScriptService/Services/VoiceService/ src/ServerScriptService/Modules/SpecRoots.luau && selene src/ServerScriptService/Services/VoiceService/`
Expected: `0 errors`.

```bash
git add src/ServerScriptService/Services/VoiceService/ src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(voice): VoiceServiceServer creates each player's VoiceInput and checks the place settings"
```

---

### Task 7: `VoiceWiring` (pure)

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/VoiceService/VoiceWiring.luau`
- Test: `src/ReplicatedStorage/Client/Services/VoiceService/VoiceWiring.spec.luau`

**Interfaces:**
- Produces:
  - `export type Action = { kind: "wire", userId: number, input: Instance, head: BasePart } | { kind: "unwire", userId: number }`
  - `export type State` (opaque)
  - `VoiceWiring.FALLOFF: { [number]: number }` = `{[0]=1, [10]=1, [45]=0.35, [80]=0}`
  - `VoiceWiring.new(): State`
  - `VoiceWiring.setInput(state, userId: number, input: Instance?): { Action }`
  - `VoiceWiring.setHead(state, userId: number, head: BasePart?): { Action }`
  - `VoiceWiring.clearHead(state, userId: number, head: BasePart): { Action }` — only if `head` is current
  - `VoiceWiring.remove(state, userId: number): { Action }`
  - `VoiceWiring.wiredCount(state): number`

- [ ] **Step 1: Write the failing spec**

```lua
--!strict
--[=[
	Unit tests for VoiceWiring (R5 spec §2.3): wire once a player's input AND puppet head both exist, rewire
	when either is replaced, unwire on a current head's despawn or on leave, ignore a stale despawn.
]=]

local VoiceWiring = require(script.Parent.VoiceWiring)

return function()
	local state, instances

	local function part()
		local p = Instance.new("Part")
		table.insert(instances, p)
		return p
	end

	local function input()
		local i = Instance.new("Folder") -- any Instance stands in for an AudioDeviceInput here
		table.insert(instances, i)
		return i
	end

	local function kinds(actions)
		local out = {}
		for _, action in actions do
			table.insert(out, action.kind)
		end
		return table.concat(out, ",")
	end

	beforeEach(function()
		state = VoiceWiring.new()
		instances = {}
	end)

	afterEach(function()
		for _, i in instances do
			i:Destroy()
		end
	end)

	it("wires once both exist, in either order", function()
		local mic, head = input(), part()
		expect(kinds(VoiceWiring.setInput(state, 2, mic))).to.equal("")
		local actions = VoiceWiring.setHead(state, 2, head)
		expect(kinds(actions)).to.equal("wire")
		expect(actions[1].input).to.equal(mic)
		expect(actions[1].head).to.equal(head)

		expect(kinds(VoiceWiring.setHead(state, 3, part()))).to.equal("")
		expect(kinds(VoiceWiring.setInput(state, 3, input()))).to.equal("wire")
		expect(VoiceWiring.wiredCount(state)).to.equal(2)
	end)

	it("setting the same input or head again does nothing", function()
		local mic, head = input(), part()
		VoiceWiring.setInput(state, 2, mic)
		VoiceWiring.setHead(state, 2, head)
		expect(kinds(VoiceWiring.setInput(state, 2, mic))).to.equal("")
		expect(kinds(VoiceWiring.setHead(state, 2, head))).to.equal("")
	end)

	it("a new head (puppet rebuilt or reused) rewires to it", function()
		VoiceWiring.setInput(state, 2, input())
		VoiceWiring.setHead(state, 2, part())
		local newHead = part()
		local actions = VoiceWiring.setHead(state, 2, newHead)
		expect(kinds(actions)).to.equal("unwire,wire")
		expect(actions[2].head).to.equal(newHead)
	end)

	-- Review focus 3.
	it("a replaced input rewires to the new one; a removed input unwires", function()
		VoiceWiring.setInput(state, 2, input())
		VoiceWiring.setHead(state, 2, part())
		local newMic = input()
		local actions = VoiceWiring.setInput(state, 2, newMic)
		expect(kinds(actions)).to.equal("unwire,wire")
		expect(actions[2].input).to.equal(newMic)
		expect(kinds(VoiceWiring.setInput(state, 2, nil))).to.equal("unwire")
		expect(VoiceWiring.wiredCount(state)).to.equal(0)
	end)

	it("clearHead unwires the current head", function()
		local head = part()
		VoiceWiring.setInput(state, 2, input())
		VoiceWiring.setHead(state, 2, head)
		expect(kinds(VoiceWiring.clearHead(state, 2, head))).to.equal("unwire")
	end)

	-- Review focus 2: a rejoiner's old puppet despawns after the new one spawned.
	it("clearHead ignores a head that is not current", function()
		local oldHead, newHead = part(), part()
		VoiceWiring.setInput(state, 2, input())
		VoiceWiring.setHead(state, 2, oldHead)
		VoiceWiring.setHead(state, 2, newHead)
		expect(kinds(VoiceWiring.clearHead(state, 2, oldHead))).to.equal("")
		expect(VoiceWiring.wiredCount(state)).to.equal(1)
	end)

	it("remove unwires and forgets; the same id can rejoin cleanly", function()
		VoiceWiring.setInput(state, 2, input())
		VoiceWiring.setHead(state, 2, part())
		expect(kinds(VoiceWiring.remove(state, 2))).to.equal("unwire")
		expect(kinds(VoiceWiring.remove(state, 2))).to.equal("")
		expect(kinds(VoiceWiring.setInput(state, 2, input()))).to.equal("")
		expect(kinds(VoiceWiring.setHead(state, 2, part()))).to.equal("wire")
	end)

	it("a puppet with no head never wires", function()
		VoiceWiring.setInput(state, 2, input())
		expect(kinds(VoiceWiring.setHead(state, 2, nil))).to.equal("")
		expect(VoiceWiring.wiredCount(state)).to.equal(0)
	end)

	it("the falloff is full to 10 studs and silent at 80", function()
		expect(VoiceWiring.FALLOFF[0]).to.equal(1)
		expect(VoiceWiring.FALLOFF[10]).to.equal(1)
		expect(VoiceWiring.FALLOFF[80]).to.equal(0)
	end)
end
```

- [ ] **Step 2: Confirm it fails** — the module does not exist.

- [ ] **Step 3: Implement `VoiceWiring.luau`**

```lua
--!strict
--[=[
	VoiceWiring (R5 spec 2026-10-05 §2.3): which remote players' voice is wired, and the actions to take.
	Pure: the caller (VoiceServiceClient) performs each action on real instances.

	A player is wired when both exist: their replicated `VoiceInput` and their puppet's `Head`. Replacing
	either rewires (unwire, then wire). `clearHead` unwires only for the CURRENT head, so a stale despawn of an
	older puppet (a rejoin, a reuse) never cuts the live wiring. `remove` (the player left) unwires and
	forgets them.

	@class VoiceWiring
]=]

local VoiceWiring = {}

-- Approved at CP3: full volume to 10 studs, silent at 80.
local FALLOFF: { [number]: number } = { [0] = 1, [10] = 1, [45] = 0.35, [80] = 0 }
VoiceWiring.FALLOFF = FALLOFF

export type Action = { kind: "wire", userId: number, input: Instance, head: BasePart } | {
	kind: "unwire",
	userId: number,
}

type Entry = { input: Instance?, head: BasePart?, wired: boolean }

export type State = { entries: { [number]: Entry } }

--[=[
	@return State
]=]
function VoiceWiring.new(): State
	return { entries = {} }
end

local function entryFor(state: State, userId: number): Entry
	local entry = state.entries[userId]
	if entry == nil then
		entry = { input = nil, head = nil, wired = false }
		state.entries[userId] = entry
	end
	return entry
end

local function reconcile(entry: Entry, userId: number, changed: boolean): { Action }
	local actions: { Action } = {}
	if entry.wired and changed then
		local unwire: Action = { kind = "unwire", userId = userId }
		table.insert(actions, unwire)
		entry.wired = false
	end
	local input, head = entry.input, entry.head
	if not entry.wired and input ~= nil and head ~= nil then
		local wire: Action = { kind = "wire", userId = userId, input = input, head = head }
		table.insert(actions, wire)
		entry.wired = true
	end
	return actions
end

--[=[
	@param state State
	@param userId number
	@param input Instance? -- the player's `VoiceInput`, or nil when it is gone
	@return { Action }
]=]
function VoiceWiring.setInput(state: State, userId: number, input: Instance?): { Action }
	local entry = entryFor(state, userId)
	local changed = entry.input ~= input
	entry.input = input
	return reconcile(entry, userId, changed)
end

--[=[
	@param state State
	@param userId number
	@param head BasePart? -- the puppet's `Head`, or nil (no head)
	@return { Action }
]=]
function VoiceWiring.setHead(state: State, userId: number, head: BasePart?): { Action }
	local entry = entryFor(state, userId)
	local changed = entry.head ~= head
	entry.head = head
	return reconcile(entry, userId, changed)
end

--[=[
	The puppet that owned `head` despawned. Ignored unless `head` is the current one.
	@param state State
	@param userId number
	@param head BasePart
	@return { Action }
]=]
function VoiceWiring.clearHead(state: State, userId: number, head: BasePart): { Action }
	local entry = state.entries[userId]
	if entry == nil or entry.head ~= head then
		return {}
	end
	entry.head = nil
	return reconcile(entry, userId, true)
end

--[=[
	The player left: unwire and forget them.
	@param state State
	@param userId number
	@return { Action }
]=]
function VoiceWiring.remove(state: State, userId: number): { Action }
	local entry = state.entries[userId]
	state.entries[userId] = nil
	if entry == nil or not entry.wired then
		return {}
	end
	local unwire: Action = { kind = "unwire", userId = userId }
	return { unwire }
end

--[=[
	@param state State
	@return number
]=]
function VoiceWiring.wiredCount(state: State): number
	local count = 0
	for _, entry in state.entries do
		if entry.wired then
			count += 1
		end
	end
	return count
end

return VoiceWiring
```

- [ ] **Step 4: Lint, format, commit**

Run: `stylua src/ReplicatedStorage/Client/Services/VoiceService/ && selene src/ReplicatedStorage/Client/Services/VoiceService/`

```bash
git add src/ReplicatedStorage/Client/Services/VoiceService/VoiceWiring.luau src/ReplicatedStorage/Client/Services/VoiceService/VoiceWiring.spec.luau
git commit -m "feat(voice): VoiceWiring decides which remote voices are wired to which puppet head"
```

---

### Task 8: `VoiceServiceClient` (shell)

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/VoiceService/VoiceServiceClient.luau`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: Task 7's `VoiceWiring` API; `CharacterReplicationServiceClient.bodySpawned` /
  `bodyDespawned` (`Signal<Player, Model>`), `:getRig(player): Model?`; the `VoiceInput` contract (Task 6).
- Produces: `VoiceServiceClient` with `dependencies = { "CharacterReplicationServiceClient" }`, `init`,
  `start`, `stop`, `getState` → `{ wired: number, emitters: number, listener: boolean, textBubblesOff: boolean }`.

- [ ] **Step 1: Implement**

```lua
--!strict
--[=[
	VoiceServiceClient (R5 spec 2026-10-05 §2.3): spatial voice on client-built bodies, the CP3 route.

	- An `AudioListener` on the current camera, wired to an `AudioDeviceOutput` (the speakers).
	- Each OTHER player's replicated `VoiceInput` is wired to an `AudioEmitter` on their puppet's `Head`, with
	  the approved falloff (full to 10 studs, silent at 80). VoiceWiring decides when; this shell does it.
	  Never on the local rig — you never hear yourself.
	- Puppets come and go through CharacterReplicationServiceClient's `bodySpawned` / `bodyDespawned`; a
	  pooled puppet reused by another player is despawn → spawn, so an emitter never carries over.
	- The speaking icon is the ENGINE's: RigRegistry sets each remote player's `Character` to their puppet
	  (CP12 T5a). Text bubbles are off (spec decision 1): this service turns BubbleChatConfiguration off at
	  start, because the voice icon shares the bubble-chat billboard and "icon yes, text bubble no" is voice's
	  decision. T5c proved that keeps the icon.

	Spec-exempt shell (audio Instances, signals); its core VoiceWiring is specced.

	@class VoiceServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local CharacterReplicationService =
	require(ReplicatedStorage.Client.Services.CharacterReplicationService.CharacterReplicationServiceClient)
local VoiceWiring = require(script.Parent.VoiceWiring)

local INPUT_NAME = "VoiceInput"
local BUBBLE_CONFIG_WAIT_SECONDS = 10

type Live = { emitter: AudioEmitter, wire: Wire }

local log = Logger.new("VoiceServiceClient")
local janitor = Janitor.new()
local localPlayer = Players.LocalPlayer
local wiring = VoiceWiring.new()
local live: { [number]: Live } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local listener: AudioListener? = nil
local textBubblesOff = false

local function apply(actions: { VoiceWiring.Action })
	for _, action in actions do
		if action.kind == "unwire" then
			local current = live[action.userId]
			if current ~= nil then
				current.wire:Destroy()
				current.emitter:Destroy()
				live[action.userId] = nil
			end
		else
			local emitter = Instance.new("AudioEmitter")
			emitter.Name = "VoiceEmitter"
			emitter:SetDistanceAttenuation(VoiceWiring.FALLOFF)
			emitter.Parent = action.head
			local wire = Instance.new("Wire")
			wire.SourceInstance = action.input
			wire.TargetInstance = emitter
			wire.Parent = emitter
			live[action.userId] = { emitter = emitter, wire = wire }
		end
	end
end

local function inputOf(player: Player): Instance?
	local input = player:FindFirstChild(INPUT_NAME)
	return if input ~= nil and input:IsA("AudioDeviceInput") then input else nil
end

local function headOf(rig: Model): BasePart?
	local head = rig:FindFirstChild("Head")
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

local function onBodySpawned(player: Player, rig: Model)
	if player ~= localPlayer then
		apply(VoiceWiring.setHead(wiring, player.UserId, headOf(rig)))
	end
end

local function onBodyDespawned(player: Player, rig: Model)
	local head = headOf(rig)
	if player ~= localPlayer and head ~= nil then
		apply(VoiceWiring.clearHead(wiring, player.UserId, head))
	end
end

local function watchPlayer(player: Player)
	if player == localPlayer or playerConnections[player] ~= nil then
		return
	end
	local userId = player.UserId
	local function syncInput()
		apply(VoiceWiring.setInput(wiring, userId, inputOf(player)))
	end
	playerConnections[player] = { player.ChildAdded:Connect(syncInput), player.ChildRemoved:Connect(syncInput) }
	syncInput()
	local rig = CharacterReplicationService:getRig(player)
	if rig ~= nil then
		onBodySpawned(player, rig)
	end
end

-- CP10: a leaver's wiring must go on leave, or a rejoin (a NEW Player) is wired twice.
local function unwatchPlayer(player: Player)
	local connections = playerConnections[player]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end
	apply(VoiceWiring.remove(wiring, player.UserId))
end

local function placeListener()
	local camera = Workspace.CurrentCamera
	local current = listener
	if camera ~= nil and current ~= nil then
		current.Parent = camera
	end
end

local function disableTextBubbles()
	local config = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		or TextChatService:WaitForChild("BubbleChatConfiguration", BUBBLE_CONFIG_WAIT_SECONDS)
	if config ~= nil and config:IsA("BubbleChatConfiguration") then
		config.Enabled = false
		textBubblesOff = true
	else
		log:warn("no BubbleChatConfiguration: text bubbles were not turned off")
	end
end

export type VoiceServiceClient = {
	dependencies: { string },
	init: (self: VoiceServiceClient) -> (),
	start: (self: VoiceServiceClient) -> (),
	stop: (self: VoiceServiceClient) -> (),
	getState: (
		self: VoiceServiceClient
	) -> { wired: number, emitters: number, listener: boolean, textBubblesOff: boolean },
}

local VoiceServiceClient: VoiceServiceClient = {
	dependencies = { "CharacterReplicationServiceClient" },

	init = function(_self)
		log:debug("VoiceServiceClient initialized")
	end,

	start = function(_self)
		task.spawn(disableTextBubbles)

		local newListener = Instance.new("AudioListener")
		newListener.Name = "VoiceListener"
		local output = Instance.new("AudioDeviceOutput")
		output.Parent = newListener
		local wire = Instance.new("Wire")
		wire.SourceInstance = newListener
		wire.TargetInstance = output
		wire.Parent = newListener
		listener = newListener
		placeListener()
		janitor:Add(newListener, "Destroy")
		janitor:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeListener), "Disconnect")

		janitor:Add(CharacterReplicationService.bodySpawned:Connect(onBodySpawned), "Disconnect")
		janitor:Add(CharacterReplicationService.bodyDespawned:Connect(onBodyDespawned), "Disconnect")
		janitor:Add(Players.PlayerAdded:Connect(watchPlayer), "Disconnect")
		janitor:Add(Players.PlayerRemoving:Connect(unwatchPlayer), "Disconnect")
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
	end,

	stop = function(_self)
		janitor:Cleanup()
		for player in playerConnections do
			unwatchPlayer(player)
		end
		listener = nil
	end,

	getState = function(_self)
		local emitters = 0
		for _ in live do
			emitters += 1
		end
		local current = listener
		return {
			wired = VoiceWiring.wiredCount(wiring),
			emitters = emitters,
			listener = current ~= nil and current.Parent ~= nil,
			textBubblesOff = textBubblesOff,
		}
	end,
}

return VoiceServiceClient
```

- [ ] **Step 2: Exempt the shell in `SpecRoots.luau`**

Below the `CharacterReplicationServiceClient` exemption, add:

```lua
	["ReplicatedStorage.Client.Services.VoiceService.VoiceServiceClient"] = "audio/Instance shell (core VoiceWiring is specced)",
```

- [ ] **Step 3: Lint, format, commit**

Run: `stylua src/ReplicatedStorage/Client/Services/VoiceService/ src/ServerScriptService/Modules/SpecRoots.luau && selene src/ReplicatedStorage/Client/Services/VoiceService/`

```bash
git add src/ReplicatedStorage/Client/Services/VoiceService/VoiceServiceClient.luau src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(voice): VoiceServiceClient wires remote voices to puppet heads and turns text bubbles off"
```

---

### Task 9: Place settings and docs

**Files:**
- Modify: `default.project.json`
- Modify: `AGENTS.md` (Deployment model section, after the property-only nodes paragraph)
- Modify: `docs/architecture.md` (the "Bodies" section, or the replication section that documents the body API)
- Modify: `docs/superpowers/specs/2026-10-05-character-replication-r5-voice-design.md` (the Files table)

- [ ] **Step 1: `default.project.json`** — add beside the other property-only service nodes:

```json
    "VoiceChatService": {
      "$properties": {
        "EnableDefaultVoice": false,
        "UseAudioApi": "Enabled"
      }
    },
    "TextChatService": {
      "$properties": {
        "CreateDefaultTextChannels": true
      }
    },
```

Validate the JSON: `python -c "import json; json.load(open('default.project.json'))"` (prints nothing on success).

- [ ] **Step 2: `AGENTS.md`** — after the paragraph that introduces property-only service nodes, add:

```markdown
**Place-owned settings (set by hand, per place).** A few properties cannot be written by Rojo or any script,
so each place (dev, staging, live) must have them set in the Studio Properties panel:

| Setting | Value | Why it can't be automated |
|---|---|---|
| `TextChatService.ChatVersion` | `TextChatService` | Write is RobloxScriptSecurity. A place still on `LegacyChatService` runs the old chat in Studio. `VoiceServiceServer` logs an error at start if it is wrong. |
```

- [ ] **Step 3: `docs/architecture.md`** — in the section that documents the body API (`bodySpawned`,
  `getRig`), add:

```markdown
**Remote `Character` (R5).** Each client sets every remote player's `Player.Character` to that player's
puppet (`RigRegistry`, the one writer), and clears it when the puppet is released. It is client-local (the
server keeps `Character = nil`). Its only purpose is the engine's own voice speaking icon; nothing in our code
reads a remote `Character` — use `getRig` / `getPlayerFromRig`.

**Voice (R5).** `VoiceServiceServer` gives each player an `AudioDeviceInput` named `VoiceInput`;
`VoiceServiceClient` wires every other player's input to an `AudioEmitter` on their puppet head (full to 10
studs, silent at 80) and listens through the camera. Text bubbles are off; the speaking icon stays.

**`Diagnostics` (Workspace attribute, default off).** `true` turns on test-only checks. Today: the
replication tripwire (`ReplicationTripwire`, once a second), which logs a warning when a body the server says
you should see has no puppet, a player has no slot entry, or a puppet is orphaned or duplicated. Off = the
checks are not connected at all. Turn it on for a test, off after.
```

- [ ] **Step 4: R5 spec Files table** — replace the "New" table rows with:

```markdown
| `Client/Services/CharacterReplicationService/RigRegistry.luau` + spec | 2.1 — registry moved out of the client service (it was at the 400-line cap); one writer of remote `Character` |
| `Client/Services/CharacterReplicationService/ReplicationTripwire.luau` + spec | 1.2 — the checks (pure) |
| `Client/Services/CharacterReplicationService/ReplicationDiagnostics.luau` + spec | 1.2 — the snapshot and the `Diagnostics` gate |
| `ServerScriptService/Services/VoiceService/VoiceSettings.luau` + spec | 2.4 — the settings check (pure) |
| `ServerScriptService/Services/VoiceService/VoiceServiceServer.luau` (spec-exempt shell) | 2.2 |
| `Client/Services/VoiceService/VoiceWiring.luau` + spec | 2.3 — the wiring state machine (pure) |
| `Client/Services/VoiceService/VoiceServiceClient.luau` (spec-exempt shell) | 2.3 |
```

- [ ] **Step 5: Commit**

```bash
git add default.project.json AGENTS.md docs/architecture.md docs/superpowers/specs/2026-10-05-character-replication-r5-voice-design.md
git commit -m "docs(voice): place settings, voice and the Diagnostics switch; R5 voice/chat project nodes"
```

---

### Task 10: Full gate and TestEZ

**Precondition:** ask the developer: "Is rojo stopped (or serving a different folder) so I can run
`scripts/check.sh` in this worktree?" Do not run it until they say yes.

- [ ] **Step 1: Full gate**

Run (Git Bash, in the worktree): `bash scripts/check.sh`
Expected: lint, format, typecheck (luau-lsp), project rules, file length — all pass. Fix any typecheck error at
its root (no casts, no `any`). Commit fixes as `fix(...)` commits.

- [ ] **Step 2: TestEZ in Studio**

Ask the developer to serve **this worktree** into the dev place (`character-replication.rbxl`) and to set
`TextChatService.ChatVersion = TextChatService` there by hand. Then:
1. Confirm the sync: in Edit, `game:GetService("ReplicatedStorage").Client.Services.CharacterReplicationService:FindFirstChild("RigRegistry")` exists.
2. Set Workspace attribute `RunTests = true`, start Play, read Output.

Expected: every spec passes (R4 ended at 1857; R5 adds Tasks 1–7's cases). Set `RunTests` back to false.

---

### Task 11: Studio verification (3 clients), the stall test, and the cost measurement

**Precondition:** the developer serves this worktree into the dev place, `ChatVersion` is set, and they
start a **Clients and Servers** test with 3 players. Before testing, confirm the sync (Task 10 Step 2.1).
Set Workspace `Diagnostics = true` from the server.

- [ ] **Step 1: Settings and chat** — in each client: `VoiceChatService.EnableDefaultVoice == false`,
  `UseAudioApi == Enabled`, `TextChatService.ChatVersion == TextChatService`, `CreateDefaultTextChannels ==
  true`, `BubbleChatConfiguration.Enabled == false`; the server's `VoiceServiceServer:getState().settingsProblems`
  is empty; typing in chat shows the message in the window and no bubble.

- [ ] **Step 2: `Character` and voice wiring** — on each client, for each other player:
  `player.Character == CharacterReplicationServiceClient:getRig(player)`; their puppet's `Head` has exactly one
  `VoiceEmitter` whose `Wire.SourceInstance` is that player's `VoiceInput`; the local rig has no
  `VoiceEmitter`; `VoiceServiceClient:getState()` shows `wired == emitters == 2` and `listener == true`.
  Repeat after: a respawn (server respawn of one player), one client leaving and rejoining (the stayer's view),
  and walking one client more than 630 studs away and back. Use in-client probe LocalScripts inserted into the
  Play DataModel to read live module state (the execute_luau context has its own require cache).

- [ ] **Step 3: Matrix row 1** — with 2 clients already in, the third joins: everyone sees everyone;
  `getState().tripwire.counts` is empty on every client.

- [ ] **Step 4: Stall test (rows 7–8)** — in one client's window, via execute_luau:
  `settings().Network.IncomingReplicationLag = 2.5`, wait 3 s, set it back to `0`. First verify the setting is
  per-process (the other clients' render delay must not move). Expected on the stalled client: puppets hold in
  place (no vanish), the render delay catches up without slides, the tripwire opens no episode. Repeat in the
  **server** window (uplink stall): the server's movement rules show no new violation or correction storm for
  that player. Repeat both at 10 s. If the setting is not per-process, use the fallback: a local, uncommitted
  gate dropping the client's `Downlink` listener for N seconds, reverted (`git checkout --`) afterwards.

- [ ] **Step 5: `Character` assignment cost** — insert a probe LocalScript in one client that records
  PreRender-to-PreRender frame times; walk the other two clients out of range (> 630 studs) and back in,
  one at a time and together, 5 times each. Then repeat with the assignment disabled locally (temporarily
  comment out the two `player.Character` lines in `RigRegistry.luau`, uncommitted, revert after). Report the
  frame-time spike on entering view with and without the assignment.

- [ ] **Step 6: Record results** — append a "R5 Studio results (date)" section to
  `docs/superpowers/specs/2026-10-05-character-replication-r5-voice-design.md`: each step's result, the
  stall numbers, the measurement table, and any tripwire episodes with their root cause. Set `Diagnostics`
  back to off. Commit:

```bash
git add docs/superpowers/specs/2026-10-05-character-replication-r5-voice-design.md
git commit -m "docs(replication): R5 Studio results — wiring, Character, stall test, assignment cost"
```

---

### Task 12: Developer staging checklist and PR

- [ ] **Step 1: Write the checklist** into the R5 design doc, under "Developer staging checklist":
  before publishing, set `ChatVersion = TextChatService` and Workspace `Diagnostics = true` in staging;
  then with two accounts: matrix rows 1–6 (both views each), voice spatial with the 10/80 falloff, the native
  icon shows and animates, top-bar mute and per-player mute, volume sliders, no text bubbles, chat works,
  all again after a rejoin; read F4 → Services → `CharacterReplicationServiceClient.tripwire` on both clients
  (expect no episodes). Commit it.

- [ ] **Step 2: Push and open the PR — only when the developer asks.** Base `feature/replication-appearance`.
  Title "Character replication R5: robustness, voice, chat settings". Body in R4's style (Purpose,
  Decisions, Changes, Verification, Deferred), ending with the Claude Code footer. Never merge.
