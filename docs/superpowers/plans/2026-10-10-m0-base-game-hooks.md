# M0: Base game hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five small, game-agnostic hooks to the base (NPC brain/goTo/tuning/path costs, Death spawn point + launch, Carry signals, Interaction channels, Toast) so Cleanup Crew's M1–M2 can be built without patching base systems.

**Architecture:** Each hook extends an existing base feature through its public service API, keeping decisions in pure, specced Rules/State/Utils modules and Instance work in the existing spec-exempt shells. Toast is a new base feature (shared data + rules + utils, a server sender, a client store, one HUD widget). Queue (spec §6.1) is deliberately NOT in this plan: it gets its own plan before M4 so this PR stays small and M1 can start sooner.

**Tech Stack:** Luau `--!strict`, Rojo, ByteNetMax packets, Charm atoms + React (react-lua) + ReactCharm, TestEZ (Studio, `RunTests = true`), Observers, SignalTyped.

**Spec:** `docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` (§6.1 base changes).

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

## Review Focus

1. **A player dies, respawns or leaves while channeling** → their channel ends, the target's progress is kept, no error, other channelers continue. (Task 4 Step 1 + Task 4 Step 9 checklist)
2. **Two players finish the same channel on the same tick** → `onComplete` runs exactly once with both players. (Task 4 Step 1: "completes once for everyone on it")
3. **A game brain errors or returns nil** → the NPC keeps thinking with the default brain; the error is logged once per think, never crashes the loop. (Task 1 Step 1 `choose` tests + Step 7 pcall)
4. **The spawn resolver errors or returns a non-CFrame** → the character spawns where the engine put it and a warning is logged. (Task 2 Step 3 code + Step 6 checklist)
5. **Toast with empty/huge text, unknown style, absurd duration** → empty is refused, text clamped to 140 chars, unknown style falls back to `info`, duration clamped 1–15 s. (Task 5 Step 1 ToastRules tests)

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Interaction | shared | Net | InteractionEvents | Channel start/stop packets (client → server) |
| Interaction | server | State | InteractionChannelTracker | Who channels what, progress per target, complete-once (pure bookkeeping) |
| Interaction | server | Systems | InteractionChannelSystem | Per-tick channel validation, progress attributes, completion callbacks |
| Toast | shared | Data | ToastTypes | Toast/style/request types |
| Toast | shared | Data | ToastConstants | Defaults and limits |
| Toast | shared | Data | ToastRegistry | Toast styles by name (ships `info`) |
| Toast | shared | Net | ToastEvents | Show packet (server → client) |
| Toast | shared | Rules | ToastRules | Normalizes a request: text, style fallback, duration clamp |
| Toast | shared | Utils | ToastQueueUtils | Pure push (max visible) and expire |
| Toast | server | (root) | ToastServiceServer | `send(target, request)` |
| Toast | client | (root) | ToastServiceClient | Receives toasts, plays the style sound, expires them, registers the HUD widget |
| Toast | client | State | ToastStore | Charm atom of visible toasts |
| UI tree | client | Screens/Hud | ToastStack (+ `.story`) | Renders the toast stack |

Modified: `Npc` (Types, Registry, BrainRules, BehaviourSystem, MoverSystem, ServiceServer), `Death` (Types, ServiceServer), `Carry` (Types, ServiceServer), `Interaction` (Types, Constants, Registry, ServiceServer, ServiceClient), `SpecRoots`.

---

### Task 0: Branch and toolchain

**Files:** none (environment).

- [ ] **Step 1: Create the base branch from the current branch (main + spec + this plan)**

```bash
git switch -c base/game-hooks
```

- [ ] **Step 2: Install the toolchain in this worktree (packages are absent here).** The developer must NOT be connected to `rojo serve` yet; this runs `rokit install` + `wally install`.

```bash
rokit install --no-trust-check
bash install.sh
```
Expected: ends with `rojo build -o peekabu.rbxl` succeeding; `Packages/`, `ServerPackages/`, `DevPackages/` exist.

- [ ] **Step 3: Baseline gate**

```bash
bash scripts/check.sh
```
Expected: all stages pass on the untouched base. If anything fails here, stop and report: it is not ours.

---

### Task 1: NPC brain hook, `goTo` intent, per-NPC tuning, path costs

**Files:**
- Modify: `src/ServerScriptService/Features/Npc/Data/NpcTypes.luau`
- Modify: `src/ServerScriptService/Features/Npc/Data/NpcRegistry.luau` (+ `NpcRegistry.spec.luau`)
- Modify: `src/ServerScriptService/Features/Npc/Rules/NpcBrainRules.luau` (+ `NpcBrainRules.spec.luau`)
- Modify: `src/ServerScriptService/Features/Npc/Systems/NpcBehaviourSystem.luau`
- Modify: `src/ServerScriptService/Features/Npc/Systems/NpcMoverSystem.luau`
- Modify: `src/ServerScriptService/Features/Npc/NpcServiceServer.luau`

**Interfaces:**
- Produces (types in NpcTypes):
  - `Intent` gains `{ kind: "goTo", position: Vector3, run: boolean }`
  - `BrainContext = { target: { userId: number, distance: number, position: Vector3 }?, threat: {...}?, hasPatrol: boolean, position: Vector3, now: number }`
  - `Brain = (def: NpcDef, context: BrainContext, npc: Model) -> Intent?`
  - `NpcTuning = { walkSpeed: number?, runSpeed: number?, sightRange: number?, sightAngle: number? }`
  - `NpcDef.pathCosts: { [string]: number }?` and same on `NpcDefInput`
- Produces (NpcBrainRules): `choose(def, context, npc, brain?) -> Intent`, `tuned(def, tuning?) -> NpcDef`
- Produces (NpcServiceServer): `setBrain(kind: string, brain: Brain?) -> ()`, `setTuning(npc: Model, tuning: NpcTuning?) -> boolean`
- Produces (NpcMoverSystem): `NpcMoverSystem.new(humanoid, root, costs: { [string]: number }?)`

- [ ] **Step 1: Write the failing brain-rule tests.** Append inside the returned function of `NpcBrainRules.spec.luau`, after the `poseFor` describe:

```lua
	describe("choose", function()
		local CONTEXT = { hasPatrol = true, position = Vector3.zero, now = 0 }
		local NPC = Instance.new("Model")

		it("uses the default brain when the kind has none", function()
			expect(NpcBrainRules.choose(def({ attitude = "hostile" }), CONTEXT, NPC, nil).kind).to.equal("patrol")
		end)

		it("uses the game's intent when it answers", function()
			local seen
			local intent = NpcBrainRules.choose(def({}), CONTEXT, NPC, function(_def, _context, npc)
				seen = npc
				return { kind = "goTo", position = Vector3.new(1, 2, 3), run = true }
			end)
			expect(intent.kind).to.equal("goTo")
			expect(intent.position).to.equal(Vector3.new(1, 2, 3))
			expect(intent.run).to.equal(true)
			expect(seen).to.equal(NPC)
		end)

		it("falls back to the default brain when the game's brain returns nil", function()
			local intent = NpcBrainRules.choose(def({ attitude = "hostile" }), CONTEXT, NPC, function()
				return nil
			end)
			expect(intent.kind).to.equal("patrol")
		end)
	end)

	describe("tuned", function()
		it("returns the kind's def unchanged without tuning", function()
			local base = def({ walkSpeed = 8 })
			expect(NpcBrainRules.tuned(base, nil)).to.equal(base)
		end)

		it("overrides only the given fields", function()
			local result = NpcBrainRules.tuned(def({ walkSpeed = 8, runSpeed = 16, sightRange = 60 }), {
				walkSpeed = 10,
				sightRange = 72,
			})
			expect(result.walkSpeed).to.equal(10)
			expect(result.runSpeed).to.equal(16)
			expect(result.sightRange).to.equal(72)
			expect(result.attitude).to.equal("passive")
		end)

		it("never lets runSpeed fall below walkSpeed", function()
			local result = NpcBrainRules.tuned(def({ walkSpeed = 8, runSpeed = 16 }), { walkSpeed = 20 })
			expect(result.runSpeed).to.equal(20)
		end)
	end)
```

And in `NpcRegistry.spec.luau`, add (match the file's existing `ensure`/`refuses` helpers; if it has none, use plain `register` with unique kind ids as below):

```lua
	it("keeps pathCosts and refuses a negative cost", function()
		NpcRegistry.register("spec-costs", { attitude = "hostile", pathCosts = { SafeZone = math.huge } })
		expect(NpcRegistry.get("spec-costs").pathCosts.SafeZone).to.equal(math.huge)
		expect(function()
			NpcRegistry.register("spec-costs-bad", { attitude = "hostile", pathCosts = { SafeZone = -1 } })
		end).to.throw()
		expect(NpcRegistry.has("spec-costs-bad")).to.equal(false)
	end)
```

- [ ] **Step 2: Run tests to verify they fail.** Rojo serve + Studio (developer connected), Workspace attribute `RunTests = true`, Play. Expected: `choose`/`tuned` fail with "attempt to call a nil value", the pathCosts test fails (`pathCosts` is nil).

- [ ] **Step 3: Extend NpcTypes.** In `NpcTypes.luau`: add `pathCosts: { [string]: number }?,` as the last field of both `NpcDef` and `NpcDefInput` with the comment `-- PathfindingService costs by material/label name (math.huge = never enter). Absent = defaults.`; replace `BrainContext` and `Intent`, and add `NpcTuning` and `Brain`:

```lua
-- What the brain sees this tick. `target` is a player the NPC sees or remembers; `threat` the nearest
-- player at all (for fleeing); `position` is the NPC's own; `now` is os.clock().
export type BrainContext = {
	target: { userId: number, distance: number, position: Vector3 }?,
	threat: { position: Vector3, distance: number }?,
	hasPatrol: boolean,
	position: Vector3,
	now: number,
}

export type Intent =
	{ kind: "idle" }
	| { kind: "wander" }
	| { kind: "patrol" }
	| { kind: "chase", target: number }
	| { kind: "attack", target: number }
	| { kind: "flee", from: Vector3 }
	| { kind: "goTo", position: Vector3, run: boolean }

-- Runtime overrides for one live NPC (a game's pressure tiers). Nil fields keep the kind's value.
export type NpcTuning = {
	walkSpeed: number?,
	runSpeed: number?,
	sightRange: number?,
	sightAngle: number?,
}

-- A game's brain for one kind. Returning nil uses the default brain (NpcBrainRules.decide) this tick.
export type Brain = (def: NpcDef, context: BrainContext, npc: Model) -> Intent?
```

- [ ] **Step 4: Copy and validate pathCosts in NpcRegistry.** In `NpcRegistry.register`, add `pathCosts = input.pathCosts,` to the `def` literal after `animations`, and before `defs[kind] = table.freeze(def)`:

```lua
	local costs = def.pathCosts
	if costs ~= nil then
		for label, cost in costs do
			assert(cost >= 0, `npc kind "{kind}": path cost "{label}" must not be negative`)
		end
	end
```

- [ ] **Step 5: Add `choose` and `tuned` to NpcBrainRules.** Before `return NpcBrainRules`:

```lua
--[=[
	The intent for this tick: the game's brain when it has one and it answers, else `decide`.
]=]
function NpcBrainRules.choose(
	def: NpcTypes.NpcDef,
	context: NpcTypes.BrainContext,
	npc: Model,
	brain: NpcTypes.Brain?
): Intent
	if brain ~= nil then
		local intent = brain(def, context, npc)
		if intent ~= nil then
			return intent
		end
	end
	return NpcBrainRules.decide(def, context)
end

--[=[
	The kind's def with one NPC's runtime overrides. runSpeed is raised to walkSpeed if an override
	would put it below.
]=]
function NpcBrainRules.tuned(def: NpcTypes.NpcDef, tuning: NpcTypes.NpcTuning?): NpcTypes.NpcDef
	if tuning == nil then
		return def
	end
	local result = table.clone(def)
	result.walkSpeed = tuning.walkSpeed or def.walkSpeed
	result.runSpeed = math.max(tuning.runSpeed or def.runSpeed, result.walkSpeed)
	result.sightRange = tuning.sightRange or def.sightRange
	result.sightAngle = tuning.sightAngle or def.sightAngle
	return table.freeze(result)
end
```

- [ ] **Step 6: Path costs in the mover.** In `NpcMoverSystem.luau` change the constructor signature and path creation:

```lua
function NpcMoverSystem.new(humanoid: Humanoid, root: BasePart, costs: { [string]: number }?): NpcMoverSystem
	local path = PathfindingService:CreatePath({ AgentCanJump = true, Costs = costs or {} })
```
Add to the header comment: `` `costs` are the kind's pathCosts (PathfindingModifier labels or materials). ``

- [ ] **Step 7: Behaviour system: brains, goTo, chase by intent target.** In `NpcBehaviourSystem.luau`:

  a. In `Agent`, add after `def: NpcDef,`: `baseDef: NpcDef, -- the registered def; \`def\` is it with setTuning's overrides`.
  b. In `ThinkDeps`, add `brains: { [string]: NpcTypes.Brain },`.
  c. Replace the block from `local intent = NpcBrainRules.decide(def, {` through the end of the `if intent.kind == "attack" ...` chain's `elseif intent.kind == "chase"` branch with:

```lua
	local context: NpcTypes.BrainContext = {
		target = if target ~= nil
			then {
				userId = target.id,
				distance = (target.position - position).Magnitude,
				position = target.position,
			}
			else nil,
		threat = threat,
		hasPatrol = #agent.patrol > 0,
		position = position,
		now = now,
	}
	local chosen: Intent? = nil
	local ok, err = pcall(function()
		chosen = NpcBrainRules.choose(def, context, agent.model, deps.brains[agent.kind])
	end)
	if not ok then
		log:error(`brain for "{agent.kind}" errored: {err}`)
	end
	local intent: Intent = chosen or NpcBrainRules.decide(def, context)

	if intent.kind == "attack" then
		local victim = findCandidate(list, intent.target)
		if victim ~= nil then
			agent.humanoid.WalkSpeed = def.runSpeed
			attack(agent, victim, now, deps)
		end
	elseif intent.kind == "chase" then
		local quarry = findCandidate(list, intent.target)
		if quarry ~= nil then
			agent.humanoid.WalkSpeed = def.runSpeed
			agent.mover:moveTo(quarry.position, now)
		end
	elseif intent.kind == "goTo" then
		agent.humanoid.WalkSpeed = if intent.run then def.runSpeed else def.walkSpeed
		agent.mover:moveTo(intent.position, now)
```
  (the `flee`, `patrol`, `wander` and final `elseif` branches stay as they are.) Add `type Intent = NpcTypes.Intent` next to `type NpcDef = NpcTypes.NpcDef`. Note `local def = agent.def` at the top of `think` already reads the tuned def.

- [ ] **Step 8: Service: setBrain, setTuning, pass costs.** In `NpcServiceServer.luau`:

  a. Require `local NpcBrainRules = require(NpcServer.Rules.NpcBrainRules)` (keep requires alphabetical within the Npc block).
  b. Add `local brains: { [string]: NpcTypes.Brain } = {}` after `attackHandlers`, and `brains = brains,` to `thinkDeps`.
  c. In `adopt`, set `def = def, baseDef = def,` and `mover = NpcMoverSystem.new(humanoid, root, def.pathCosts),`.
  d. Add to the `NpcServiceServer` type:

```lua
	setBrain: (self: NpcServiceServer, kind: string, brain: NpcTypes.Brain?) -> (),
	setTuning: (self: NpcServiceServer, npc: Model, tuning: NpcTypes.NpcTuning?) -> boolean,
```
  e. Add the fields after `setTarget`:

```lua
	--[=[
		Gives a kind the game's own brain (investigate a noise, freeze when watched). The brain runs every
		think; returning nil uses the default brain for that tick. Nil removes it.
	]=]
	setBrain = function(_self, kind, brain)
		assert(NpcRegistry.has(kind), `setBrain: "{kind}" is not a registered npc kind`)
		brains[kind] = brain
	end,

	--[=[
		Overrides one live NPC's speeds or sight (pressure tiers, party-size scaling); nil restores the
		kind's values. False when `npc` is not a live NPC.
	]=]
	setTuning = function(_self, npc, tuning)
		local id = roster:idOf(npc)
		local agent = if id ~= nil then agents[id] else nil
		if agent == nil then
			return false
		end
		agent.def = NpcBrainRules.tuned(agent.baseDef, tuning)
		return true
	end,
```
  f. Update the header comment's bullet list with: `- A game can replace a kind's decisions (`setBrain`), send it to a point (the `goTo` intent), tune one NPC at runtime (`setTuning`), and mark zones it avoids (`pathCosts`).`

- [ ] **Step 9: Run the tests.** Studio, `RunTests = true`, Play. Expected: all Npc specs pass (old `decide` tests still pass: they pass contexts without position/now, which the untyped spec allows).

- [ ] **Step 10: Gate and commit**

```bash
bash scripts/check.sh --skip-install
git add src/ServerScriptService/Features/Npc
git commit -m "feat(npc): pluggable brain, goTo intent, per-NPC tuning and path costs"
```

---

### Task 2: Death: chosen respawn point and launch-on-kill

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Death/Data/DeathTypes.luau`
- Modify: `src/ServerScriptService/Features/Death/DeathServiceServer.luau`

**Interfaces:**
- Produces (DeathTypes): `SpawnResolver = (player: Player) -> CFrame?`, `KillOptions = { launch: Vector3? }`
- Produces (DeathServiceServer): `setSpawnPoint(resolver: SpawnResolver?) -> ()`; `kill(humanoid, cause: string?, options: KillOptions?) -> ()`

DeathServiceServer is a spec-exempt shell (existing entry); both changes are Instance/physics work verified in Studio (Step 6).

- [ ] **Step 1: Types.** Append to `DeathTypes.luau` before `return {}`:

```lua
-- Where a player's next character appears; nil = where the engine put it (a SpawnLocation).
export type SpawnResolver = (player: Player) -> CFrame?

export type KillOptions = {
	-- Velocity (studs/s) every body part gets at the moment of death: a throw, a blast.
	launch: Vector3?,
}
```

- [ ] **Step 2: State and the launch helper.** In `DeathServiceServer.luau`, after the `causes` table:

```lua
-- A launch from kill(), applied when the humanoid dies. Weak keys, like `causes`.
local launches: { [Humanoid]: Vector3 } = {}
setmetatable(launches, { __mode = "k" })
local spawnResolver: DeathTypes.SpawnResolver? = nil
```
and after `ragdollModel`:

```lua
-- Takes the body from its owner and throws it. A player's character is simulated by that player's
-- client, which would ignore a velocity the server sets, so ownership moves to the server first.
local function launchModel(model: Model, velocity: Vector3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
			descendant.AssemblyLinearVelocity = velocity
		end
	end
end
```

- [ ] **Step 3: Apply launch on death and the spawn point on spawn.** In `watch`'s `Died` handler, right after the `if config.ragdoll then ragdollModel(model) end` block:

```lua
		local launch = launches[humanoid]
		launches[humanoid] = nil
		if launch ~= nil then
			launchModel(model, launch)
		end
```
In `start`'s `observeCharacter` callback, as its first lines (before `StateSyncPublicPlayerStore.clearField`):

```lua
				local resolver = spawnResolver
				if resolver ~= nil then
					local ok, cframe = pcall(resolver, player)
					if not ok then
						log:warn(`spawn resolver failed for {player.Name}: {cframe}`)
					elseif typeof(cframe) == "CFrame" then
						-- Deferred: the engine places a new character after CharacterAdded fires.
						task.defer(function()
							if character.Parent ~= nil then
								character:PivotTo(cframe)
							end
						end)
					end
				end
```

- [ ] **Step 4: API.** In the `DeathServiceServer` type change `kill` and add `setSpawnPoint`:

```lua
	kill: (self: DeathServiceServer, humanoid: Humanoid, cause: string?, options: DeathTypes.KillOptions?) -> (),
	setSpawnPoint: (self: DeathServiceServer, resolver: DeathTypes.SpawnResolver?) -> (),
```
Replace the `kill` field and add `setSpawnPoint` after it:

```lua
	--[=[
		Kills a humanoid outright, with an optional cause ("fell", "caught", "round-ended") and an optional
		launch velocity applied to the body as it dies.
	]=]
	kill = function(_self, humanoid, cause, options)
		if humanoid.Health <= 0 then
			return
		end
		if cause ~= nil then
			causes[humanoid] = cause
		end
		if options ~= nil and options.launch ~= nil then
			launches[humanoid] = options.launch
		end
		humanoid.Health = 0
	end,

	--[=[
		Sets where every player's next character appears (a loading bay, a team base); nil restores the
		engine's choice. A resolver returning nil for a player leaves that spawn alone.
	]=]
	setSpawnPoint = function(_self, resolver)
		spawnResolver = resolver
	end,
```
Add `spawnResolver = spawnResolver ~= nil,` to `getState`'s table, and to the header bullets: `- \`setSpawnPoint(resolver)\` chooses where characters appear; \`kill(..., { launch })\` throws the body as it dies.`

- [ ] **Step 5: Gate.** `bash scripts/check.sh --skip-install`. Expected: pass (no other caller of `kill` breaks: the new parameter is optional; verify with `grep -rn ":kill(" src`).

- [ ] **Step 6: Studio verification (developer connected, Play Solo).** In the server command bar:

```lua
local D = require(game.ServerScriptService.Features.Death.DeathServiceServer)
D:configure({ respawn = "auto", respawnDelay = 2 })
D:setSpawnPoint(function() return CFrame.new(0, 20, 60) end)
local h = game.Players:GetPlayers()[1].Character.Humanoid
D:kill(h, "test", { launch = Vector3.new(0, 60, -80) })
```
Expected: the character ragdolls and visibly flies up and away; after ~2 s it respawns at (0, 20, 60). Then `D:setSpawnPoint(function() error("boom") end)` and reset the character: a warning `spawn resolver failed` and a normal spawn. Then `D:setSpawnPoint(nil)`.

- [ ] **Step 7: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Death/Data/DeathTypes.luau src/ServerScriptService/Features/Death/DeathServiceServer.luau
git commit -m "feat(death): chosen respawn point and launch on kill"
```

---

### Task 3: Carry signals and drop reasons

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Carry/Data/CarryTypes.luau`
- Modify: `src/ServerScriptService/Features/Carry/CarryServiceServer.luau`

**Interfaces:**
- Produces (CarryTypes): `DropReason = "drop" | "throw" | "forced" | "death" | "removed" | "destroyed"` ("removed" = the character was removed, by respawn or leaving; "destroyed" = the object itself was destroyed while held)
- Produces (CarryServiceServer): `pickedUp: SignalTyped.Signal<Player, Instance>`, `dropped: SignalTyped.Signal<Player, Instance, DropReason>`, `forceDrop(player, reason: DropReason?) -> boolean`

CarryServiceServer is a spec-exempt shell (existing entry).

- [ ] **Step 1: Find existing forceDrop callers**

```bash
grep -rn "forceDrop" src --include=*.luau
```
Expected: only `CarryServiceServer.luau`. If others exist, they keep working (the new parameter is optional).

- [ ] **Step 2: Type.** Append to `CarryTypes.luau` before its `return`:

```lua
-- Why a hold ended: the player dropped or threw it, a game rule forced it, the carrier died, the
-- carrier's character was removed (respawn or leaving), or the object was destroyed while held.
export type DropReason = "drop" | "throw" | "forced" | "death" | "removed" | "destroyed"
```

- [ ] **Step 3: Signals and firing.** In `CarryServiceServer.luau`:
  a. Require `local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)` and `local CarryTypes = require(CarryShared.Data.CarryTypes)`.
  b. After `local log = ...`:

```lua
local pickedUp: SignalTyped.Signal<Player, Instance> = SignalTyped.new()
local dropped: SignalTyped.Signal<Player, Instance, CarryTypes.DropReason> = SignalTyped.new()
```
  c. In the tag observer's cleanup, replace `if player ~= nil then release(player) end` with:

```lua
					if player ~= nil then
						release(player)
						dropped:Fire(player, target, "destroyed")
					end
```
  d. Character observer: `self:forceDrop(player, "death")` in the Died handler; `self:forceDrop(player, "removed")` in the cleanup.
  e. Type additions:

```lua
	pickedUp: SignalTyped.Signal<Player, Instance>,
	dropped: SignalTyped.Signal<Player, Instance, CarryTypes.DropReason>,
	forceDrop: (self: CarryServiceServer, player: Player, reason: CarryTypes.DropReason?) -> boolean,
```
(replacing the old `forceDrop` line), and `pickedUp = pickedUp, dropped = dropped,` as the first fields after `dependencies`.
  f. `pickUp`: after `counters.pickedUp += 1` add `pickedUp:Fire(player, target)`.
  g. `drop`: after `counters.dropped += 1` add `dropped:Fire(player, state.target, "drop")`.
  h. `throw`: after `counters.thrown += 1` add `dropped:Fire(player, state.target, "throw")`.
  i. `forceDrop`:

```lua
	forceDrop = function(_self, player, reason)
		local state = held[player.UserId]
		local root = release(player)
		if state == nil or root == nil then
			return false
		end
		root.Anchored = false
		counters.dropped += 1
		dropped:Fire(player, state.target, reason or "forced")
		return true
	end,
```
  j. Header: add `` `pickedUp` / `dropped(player, object, reason)` signals let a game react (banking, noise, analytics). ``

- [ ] **Step 4: Gate.** `bash scripts/check.sh --skip-install` → pass.

- [ ] **Step 5: Studio verification (Play Solo).** Server command bar:

```lua
local C = require(game.ServerScriptService.Features.Carry.CarryServiceServer)
C.pickedUp:Connect(function(p, o) print("PICKED", p.Name, o.Name) end)
C.dropped:Connect(function(p, o, r) print("DROPPED", p.Name, o.Name, r) end)
local CR = require(game.ReplicatedStorage.Shared.Features.Carry.Data.CarryRegistry)
if not CR.has("spec-box") then CR.register("spec-box", { weight = 1, throwable = true }) end
local b = Instance.new("Part") b.Size = Vector3.new(2,2,2) b.Position = game.Players:GetPlayers()[1].Character.HumanoidRootPart.Position + Vector3.new(0,0,-6) b:SetAttribute("CarryKind","spec-box") b.Parent = workspace
game.CollectionService:AddTag(b, "Carryable")
```
Expected: pick it up (prompt) → `PICKED`; press G → `DROPPED ... drop`; pick up, press F → `DROPPED ... throw`; pick up, reset character → `DROPPED ... death`; pick up, `b:Destroy()` in the command bar → `DROPPED ... destroyed` and walk speed restored.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Carry/Data/CarryTypes.luau src/ServerScriptService/Features/Carry/CarryServiceServer.luau
git commit -m "feat(carry): pickedUp and dropped signals with drop reasons"
```

---

### Task 4: Interaction channels (continuous hold with server-side progress)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Interaction/Data/InteractionTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Interaction/Data/InteractionConstants.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Interaction/Data/InteractionRegistry.luau` (+ spec)
- Create: `src/ReplicatedStorage/Shared/Features/Interaction/Net/InteractionEvents.luau`
- Create: `src/ServerScriptService/Features/Interaction/State/InteractionChannelTracker.luau` (+ `.spec.luau`)
- Create: `src/ServerScriptService/Features/Interaction/Systems/InteractionChannelSystem.luau`
- Modify: `src/ServerScriptService/Features/Interaction/InteractionServiceServer.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Interaction/InteractionServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Produces (InteractionTypes): `ChannelDef = { duration: number, maxDistance: number? }`
- Produces (InteractionConstants): `CHANNEL_KIND_ATTRIBUTE = "ChannelKind"`, `CHANNEL_PROGRESS_ATTRIBUTE = "ChannelProgress"` (0–1), `CHANNEL_COUNT_ATTRIBUTE = "ChannelCount"` (players on it), `CHANNEL_TICK = 0.1`
- Produces (InteractionRegistry): `registerChannel(id, def)`, `getChannel(id) -> ChannelDef?`, `hasChannel(id) -> boolean`
- Produces (InteractionChannelSystem): `ChannelHandler = { canChannel: ((player: Player, target: Instance) -> boolean)?, onComplete: (players: { Player }, target: Instance) -> () }`
- Produces (InteractionServiceServer): `channel(kind: string, handler: ChannelHandler) -> ()`, `resetChannel(target: Instance) -> ()`
- Produces (InteractionServiceClient): `startChannel(target: Instance) -> ()`, `stopChannel() -> ()`
- A game marks a channel target with the attribute `ChannelKind = "<kind>"`. Nothing is tagged; the client names the target in the start packet and the server checks it.

- [ ] **Step 1: Write the failing tracker spec** `src/ServerScriptService/Features/Interaction/State/InteractionChannelTracker.spec.luau`:

```lua
local InteractionChannelTracker = require(script.Parent.InteractionChannelTracker)

return function()
	it("starts a channel and reports it both ways", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		expect(tracker:targetOf(1)).to.equal(10)
		expect(#tracker:channelers(10)).to.equal(1)
	end)

	it("moves a player to the new target when they start another", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:start(1, 11)
		expect(tracker:targetOf(1)).to.equal(11)
		expect(#tracker:channelers(10)).to.equal(0)
	end)

	it("advances by elapsed time over duration, adding rates for each player", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:advance(10, 0.5, 2.5)
		expect(tracker:progress(10)).to.be.near(0.2)
		tracker:start(2, 10)
		tracker:advance(10, 0.5, 2.5)
		expect(tracker:progress(10)).to.be.near(0.6)
	end)

	it("keeps progress when everyone stops", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:advance(10, 1, 2.5)
		expect(tracker:stop(1)).to.equal(10)
		expect(tracker:targetOf(1)).to.equal(nil)
		expect(tracker:progress(10)).to.be.near(0.4)
		expect(tracker:advance(10, 5, 2.5)).to.equal(nil)
		expect(tracker:progress(10)).to.be.near(0.4)
	end)

	it("completes once for everyone on it, then forgets the target", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:start(2, 10)
		local done = tracker:advance(10, 2, 2.5)
		expect(done).to.be.ok()
		table.sort(done)
		expect(done[1]).to.equal(1)
		expect(done[2]).to.equal(2)
		expect(tracker:targetOf(1)).to.equal(nil)
		expect(tracker:progress(10)).to.equal(0)
		expect(tracker:advance(10, 5, 2.5)).to.equal(nil)
	end)

	it("reset clears progress and everyone on the target", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:advance(10, 1, 2.5)
		tracker:reset(10)
		expect(tracker:progress(10)).to.equal(0)
		expect(tracker:targetOf(1)).to.equal(nil)
	end)

	it("lists only targets someone is channeling", function()
		local tracker = InteractionChannelTracker.new()
		tracker:start(1, 10)
		tracker:start(2, 11)
		tracker:stop(2)
		local active = tracker:activeTargets()
		expect(#active).to.equal(1)
		expect(active[1]).to.equal(10)
	end)
end
```

And add to `InteractionRegistry.spec.luau` (inside the returned function):

```lua
	describe("channels", function()
		it("registers and returns a channel kind", function()
			if not InteractionRegistry.hasChannel("spec-vacuum") then
				InteractionRegistry.registerChannel("spec-vacuum", { duration = 2.5, maxDistance = 8 })
			end
			expect(InteractionRegistry.getChannel("spec-vacuum").duration).to.equal(2.5)
		end)

		it("refuses a non-positive duration or distance", function()
			expect(function()
				InteractionRegistry.registerChannel("spec-chan-zero", { duration = 0 })
			end).to.throw()
			expect(function()
				InteractionRegistry.registerChannel("spec-chan-far", { duration = 1, maxDistance = 0 })
			end).to.throw()
			expect(InteractionRegistry.hasChannel("spec-chan-zero")).to.equal(false)
		end)
	end)
```

- [ ] **Step 2: Run to verify failure.** Studio test run → tracker spec errors (module missing), registry `registerChannel` is nil.

- [ ] **Step 3: Types, constants, registry.**

`InteractionTypes.luau`, before `return {}`:

```lua
-- A channel: hold-to-work on an object with progress kept on the server (vacuum a pile, repair a fault).
export type ChannelDef = {
	-- Seconds one player needs from zero to done. Several players on one target add their rates.
	duration: number,
	-- Studs; absent = InteractionConstants.DEFAULT_MAX_DISTANCE.
	maxDistance: number?,
}
```

`InteractionConstants.luau`, inside the frozen table:

```lua
	-- String attribute naming an object's channel kind (InteractionRegistry.registerChannel).
	CHANNEL_KIND_ATTRIBUTE = "ChannelKind",
	-- Number attributes the server keeps on a channel target: progress 0-1, and players on it.
	CHANNEL_PROGRESS_ATTRIBUTE = "ChannelProgress",
	CHANNEL_COUNT_ATTRIBUTE = "ChannelCount",
	-- Seconds between channel progress updates.
	CHANNEL_TICK = 0.1,
```

`InteractionRegistry.luau`: add `local channels: { [string]: InteractionTypes.ChannelDef } = {}` under `kinds`, and before `return`:

```lua
--[=[
	Registers a channel kind. Asserts: the id is new; duration is positive; maxDistance is positive.
]=]
function InteractionRegistry.registerChannel(id: string, def: InteractionTypes.ChannelDef)
	assert(channels[id] == nil, `channel kind "{id}" is already registered`)
	assert(def.duration > 0, `channel "{id}": duration must be positive`)
	local distance = def.maxDistance
	if distance ~= nil then
		assert(distance > 0, `channel "{id}": maxDistance must be positive`)
	end
	channels[id] = def
end

function InteractionRegistry.getChannel(id: string): InteractionTypes.ChannelDef?
	return channels[id]
end

function InteractionRegistry.hasChannel(id: string): boolean
	return channels[id] ~= nil
end
```

- [ ] **Step 4: The tracker** `src/ServerScriptService/Features/Interaction/State/InteractionChannelTracker.luau`:

```lua
--!strict
--[=[
	InteractionChannelTracker: who is channeling which target, and each target's progress (0-1). Plain
	bookkeeping keyed by numbers (UserIds, target ids); InteractionChannelSystem owns the Instances.

	A player channels at most one target. Progress is kept when everyone stops. `advance` returns the
	players on a target exactly once, the tick it reaches 1, and forgets the target.

	@class InteractionChannelTracker
]=]

export type InteractionChannelTracker = {
	start: (self: InteractionChannelTracker, userId: number, targetId: number) -> (),
	stop: (self: InteractionChannelTracker, userId: number) -> number?,
	targetOf: (self: InteractionChannelTracker, userId: number) -> number?,
	channelers: (self: InteractionChannelTracker, targetId: number) -> { number },
	progress: (self: InteractionChannelTracker, targetId: number) -> number,
	advance: (self: InteractionChannelTracker, targetId: number, dt: number, duration: number) -> { number }?,
	reset: (self: InteractionChannelTracker, targetId: number) -> (),
	activeTargets: (self: InteractionChannelTracker) -> { number },
}

local InteractionChannelTracker = {}

function InteractionChannelTracker.new(): InteractionChannelTracker
	local targetByUser: { [number]: number } = {}
	local progressByTarget: { [number]: number } = {}

	local tracker: InteractionChannelTracker
	tracker = {
		start = function(_self, userId, targetId)
			targetByUser[userId] = targetId
		end,

		stop = function(_self, userId)
			local targetId = targetByUser[userId]
			targetByUser[userId] = nil
			return targetId
		end,

		targetOf = function(_self, userId)
			return targetByUser[userId]
		end,

		channelers = function(_self, targetId)
			local list: { number } = {}
			for userId, current in targetByUser do
				if current == targetId then
					table.insert(list, userId)
				end
			end
			table.sort(list)
			return list
		end,

		progress = function(_self, targetId)
			return progressByTarget[targetId] or 0
		end,

		advance = function(self, targetId, dt, duration)
			local players = self:channelers(targetId)
			if #players == 0 then
				return nil
			end
			local nextProgress = (progressByTarget[targetId] or 0) + dt * #players / duration
			if nextProgress < 1 then
				progressByTarget[targetId] = nextProgress
				return nil
			end
			self:reset(targetId)
			return players
		end,

		reset = function(_self, targetId)
			progressByTarget[targetId] = nil
			for userId, current in targetByUser do
				if current == targetId then
					targetByUser[userId] = nil
				end
			end
		end,

		activeTargets = function(_self)
			local seen: { [number]: true } = {}
			local list: { number } = {}
			for _, targetId in targetByUser do
				if not seen[targetId] then
					seen[targetId] = true
					table.insert(list, targetId)
				end
			end
			table.sort(list)
			return list
		end,
	}
	return tracker
end

return InteractionChannelTracker
```

- [ ] **Step 5: Run the tracker + registry specs.** Studio test run. Expected: PASS.

- [ ] **Step 6: Packets** `src/ReplicatedStorage/Shared/Features/Interaction/Net/InteractionEvents.luau`:

```lua
--!strict
--[=[
	InteractionEvents: the ByteNet packets for channels (client → server only). The server re-checks
	everything: the target's ChannelKind, distance, the game's canChannel, rate limits.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value
	the server creates when IT requires this module (at InteractionServiceServer load).

	@class InteractionEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "InteractionEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local InteractionEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- The object the player starts channeling (its ChannelKind decides the rules).
			ChannelStart = ByteNet.definePacket({
				value = ByteNet.inst,
				reliabilityType = "reliable",
			}),
			-- Payload unused; the packet is the request.
			ChannelStop = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return InteractionEvents
```

- [ ] **Step 7: The system** `src/ServerScriptService/Features/Interaction/Systems/InteractionChannelSystem.luau`:

```lua
--!strict
--[=[
	InteractionChannelSystem: runs every channel. Each tick it re-checks every channeler (a living
	character, in range, the target enabled and still in the world, the game's canChannel), advances
	progress through InteractionChannelTracker, mirrors it onto the target's ChannelProgress /
	ChannelCount attributes, and calls the kind's onComplete once when a target reaches full.

	Spec-exempt shell (Players, Instances, attributes); the bookkeeping is the specced
	InteractionChannelTracker and the per-player check is the specced InteractionRules.

	@class InteractionChannelSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local InteractionData = ReplicatedStorage.Shared.Features.Interaction.Data
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(InteractionData.InteractionConstants)
local InteractionRegistry = require(InteractionData.InteractionRegistry)
local InteractionRules = require(ServerScriptService.Features.Interaction.Rules.InteractionRules)
local InteractionChannelTracker = require(ServerScriptService.Features.Interaction.State.InteractionChannelTracker)

export type ChannelHandler = {
	-- Asked when a player starts and every tick after; false refuses or ends their channel.
	canChannel: ((player: Player, target: Instance) -> boolean)?,
	-- Once, when progress reaches full; `players` are everyone on the target at that moment.
	onComplete: (players: { Player }, target: Instance) -> (),
}

export type InteractionChannelSystem = {
	start: (self: InteractionChannelSystem, player: Player, target: Instance) -> (boolean, string?),
	stop: (self: InteractionChannelSystem, player: Player) -> (),
	reset: (self: InteractionChannelSystem, target: Instance) -> (),
	step: (self: InteractionChannelSystem, dt: number) -> (),
}

local log = Logger.new("InteractionChannelSystem")

local function rootPartOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function kindOf(target: Instance): string?
	local kind = target:GetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE)
	return if type(kind) == "string" and InteractionRegistry.hasChannel(kind) then kind else nil
end

local InteractionChannelSystem = {}

function InteractionChannelSystem.new(handlers: { [string]: ChannelHandler }): InteractionChannelSystem
	local tracker = InteractionChannelTracker.new()
	local idOf: { [Instance]: number } = {}
	setmetatable(idOf, { __mode = "k" })
	local targetById: { [number]: Instance } = {}
	local nextId = 0

	local function idFor(target: Instance): number
		local id = idOf[target]
		if id == nil then
			nextId += 1
			id = nextId
			idOf[target] = id
			targetById[id] = target
		end
		return id
	end

	-- Whether `player` may channel `target` right now; the reason when not.
	local function allowed(player: Player, target: Instance): (boolean, string?)
		local kind = kindOf(target)
		local def = if kind ~= nil then InteractionRegistry.getChannel(kind) else nil
		local handler = if kind ~= nil then handlers[kind] else nil
		local root = rootPartOf(target)
		if kind == nil or def == nil or handler == nil or root == nil or not target:IsDescendantOf(Workspace) then
			return false, "not a channel"
		end
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local alive = humanoid ~= nil and humanoid.Health > 0 and playerRoot ~= nil and playerRoot:IsA("BasePart")
		local distance = if playerRoot ~= nil and playerRoot:IsA("BasePart")
			then (playerRoot.Position - root.Position).Magnitude
			else math.huge
		local ok, reason = InteractionRules.check({
			hasCharacter = alive,
			distance = distance,
			maxDistance = def.maxDistance or InteractionConstants.DEFAULT_MAX_DISTANCE,
			tolerance = InteractionConstants.DISTANCE_TOLERANCE,
			enabled = target:GetAttribute(InteractionConstants.ENABLED_ATTRIBUTE) ~= false,
			cooldownRemaining = 0,
		})
		if not ok then
			return false, reason
		end
		local canChannel = handler.canChannel
		if canChannel ~= nil and not canChannel(player, target) then
			return false, "refused by game"
		end
		return true, nil
	end

	local function publish(targetId: number)
		local target = targetById[targetId]
		if target == nil then
			return
		end
		local count = #tracker:channelers(targetId)
		local progress = tracker:progress(targetId)
		target:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, if progress > 0 then progress else nil)
		target:SetAttribute(InteractionConstants.CHANNEL_COUNT_ATTRIBUTE, if count > 0 then count else nil)
	end

	local system: InteractionChannelSystem
	system = {
		start = function(_self, player, target)
			local ok, reason = allowed(player, target)
			if not ok then
				return false, reason
			end
			local previous = tracker:stop(player.UserId)
			local targetId = idFor(target)
			tracker:start(player.UserId, targetId)
			if previous ~= nil and previous ~= targetId then
				publish(previous)
			end
			publish(targetId)
			return true, nil
		end,

		stop = function(_self, player)
			local previous = tracker:stop(player.UserId)
			if previous ~= nil then
				publish(previous)
			end
		end,

		reset = function(_self, target)
			local targetId = idOf[target]
			if targetId == nil then
				return
			end
			tracker:reset(targetId)
			publish(targetId)
		end,

		step = function(_self, dt)
			for _, targetId in tracker:activeTargets() do
				local target = targetById[targetId]
				for _, userId in tracker:channelers(targetId) do
					local player = Players:GetPlayerByUserId(userId)
					if player == nil or target == nil or not (allowed(player, target)) then
						tracker:stop(userId)
					end
				end
				local kind = if target ~= nil then kindOf(target) else nil
				local def = if kind ~= nil then InteractionRegistry.getChannel(kind) else nil
				if target == nil or kind == nil or def == nil or not target:IsDescendantOf(Workspace) then
					-- Destroyed or no longer a channel: forget it so the id map does not hold it.
					tracker:reset(targetId)
					targetById[targetId] = nil
					continue
				end
				local done = tracker:advance(targetId, dt, def.duration)
				publish(targetId)
				if done ~= nil then
					local players: { Player } = {}
					for _, userId in done do
						local player = Players:GetPlayerByUserId(userId)
						if player ~= nil then
							table.insert(players, player)
						end
					end
					local ok, err = pcall(function()
						handlers[kind].onComplete(players, target)
					end)
					if not ok then
						log:error(`channel "{kind}" onComplete failed: {err}`)
					end
				end
			end
		end,
	}
	return system
end

return InteractionChannelSystem
```

- [ ] **Step 8: Wire the service and client.**

`InteractionServiceServer.luau`:
  a. Requires: `local RunService = game:GetService("RunService")`, `local InteractionEvents = require(ReplicatedStorage.Shared.Features.Interaction.Net.InteractionEvents)`, `local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)`, `local InteractionChannelSystem = require(ServerScriptService.Features.Interaction.Systems.InteractionChannelSystem)`.
  b. State after `handlers`:

```lua
local channelHandlers: { [string]: InteractionChannelSystem.ChannelHandler } = {}
local channels = InteractionChannelSystem.new(channelHandlers)

local onChannelStart = RequestHandler.wrap({
	name = "InteractionChannelStart",
	rateLimitKey = "InteractionChannel",
	rateLimit = { maxRequests = 20, windowSeconds = 5 },
	handler = function(data: unknown, player: Player)
		if typeof(data) == "Instance" then
			local ok, reason = channels:start(player, data)
			if not ok then
				log:debug(`channel refused for {player.Name}: {reason or "?"}`)
			end
		end
	end,
})

local onChannelStop = RequestHandler.wrap({
	name = "InteractionChannelStop",
	rateLimitKey = "InteractionChannel",
	rateLimit = { maxRequests = 20, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		channels:stop(player)
	end,
})
```
  c. In `start`, after the existing `leaving` connection, and change that connection's body to also call `channels:stop(player)`:

```lua
		table.insert(
			stoppers,
			InteractionEvents.packets.ChannelStart.listen(function(data: Instance, player: Player?)
				if player then
					onChannelStart(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			InteractionEvents.packets.ChannelStop.listen(function(data: boolean, player: Player?)
				if player then
					onChannelStop(data, player)
				end
			end)
		)
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= InteractionConstants.CHANNEL_TICK then
				channels:step(elapsed)
				elapsed = 0
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
```
  d. Type + fields:

```lua
	channel: (self: InteractionServiceServer, kind: string, handler: InteractionChannelSystem.ChannelHandler) -> (),
	resetChannel: (self: InteractionServiceServer, target: Instance) -> (),
```

```lua
	--[=[
		Sets THE handler for a registered channel kind. Errors on an unregistered kind or a second handler.
	]=]
	channel = function(_self, kind, handler)
		assert(InteractionRegistry.hasChannel(kind), `channel kind "{kind}" is not registered`)
		assert(channelHandlers[kind] == nil, `channel kind "{kind}" already has a handler`)
		channelHandlers[kind] = handler
	end,

	--[=[
		Zeroes a target's progress and ends everyone's channel on it (a pile respawned, a fault fixed).
	]=]
	resetChannel = function(_self, target)
		channels:reset(target)
	end,
```
  e. Header: add `Channels: an object with a ChannelKind attribute can be held-to-work; progress lives on the server (InteractionChannelSystem) and is mirrored on ChannelProgress / ChannelCount.`

`InteractionServiceClient.luau`: require `InteractionEvents`; add `local channelTarget: Instance? = nil`; type fields `startChannel: (self, target: Instance) -> ()`, `stopChannel: (self) -> ()`; fields:

```lua
	--[=[
		Starts channeling `target` (the game decides when: aim + hold). Repeats for the same target are
		not re-sent.
	]=]
	startChannel = function(_self, target)
		if channelTarget == target then
			return
		end
		channelTarget = target
		InteractionEvents.packets.ChannelStart.send(target)
	end,

	stopChannel = function(_self)
		if channelTarget == nil then
			return
		end
		channelTarget = nil
		InteractionEvents.packets.ChannelStop.send(true)
	end,
```

`SpecRoots.luau` `EXEMPT_MODULES`, next to the Interaction entries:

```lua
	["ReplicatedStorage.Shared.Features.Interaction.Net.InteractionEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Interaction.Systems.InteractionChannelSystem"] = "Players/Instance/attribute shell (InteractionChannelTracker and InteractionRules are specced)",
```

- [ ] **Step 9: Gate, then Studio verification.** `bash scripts/check.sh --skip-install` → pass. Play with 2 clients (Studio Test → Clients: 2). Server command bar:

```lua
local IR = require(game.ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local IS = require(game.ServerScriptService.Features.Interaction.InteractionServiceServer)
if not IR.hasChannel("spec-pile") then IR.registerChannel("spec-pile", { duration = 3, maxDistance = 8 }) end
pcall(function() IS:channel("spec-pile", { onComplete = function(ps, t) print("DONE", #ps, t.Name) t:Destroy() end }) end)
local p = Instance.new("Part") p.Name = "Pile" p.Anchored = true p.Size = Vector3.new(4,1,4) p.Position = Vector3.new(0, 0.5, 20) p:SetAttribute("ChannelKind","spec-pile") p.Parent = workspace
```
Each client's command bar (stand next to the pile): `require(game.ReplicatedStorage.Client.Features.Interaction.InteractionServiceClient):startChannel(workspace.Pile)`.
Expected: one client alone → `DONE 1 Pile` after ~3 s. Re-create the pile; start on client 1, after ~1 s `stopChannel()`, then start again → completes after ~2 s more (progress kept). Re-create; both clients start → `DONE 2 Pile` after ~1.5 s, printed once. Re-create; start, then walk 20 studs away → `ChannelCount` attribute clears, no DONE. Start, then reset the character → channel ends, no error in Output.

- [ ] **Step 10: Commit**

```bash
python3 scripts/python/module_map.py --write
git add src docs/project-structure.md
git commit -m "feat(interaction): channels with server-side progress"
```

---

### Task 5: Toast (new base feature)

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Data/ToastTypes.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Data/ToastConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Data/ToastRegistry.luau` (+ spec)
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Net/ToastEvents.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Rules/ToastRules.luau` (+ spec)
- Create: `src/ReplicatedStorage/Shared/Features/Toast/Utils/ToastQueueUtils.luau` (+ spec)
- Create: `src/ServerScriptService/Features/Toast/ToastServiceServer.luau`
- Create: `src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.luau` (+ spec)
- Create: `src/ReplicatedStorage/Client/Features/Toast/ToastServiceClient.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Hud/ToastStack.luau` and `ToastStack.story.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`, `docs/project-structure.md` (feature list: add Toast)

**Interfaces:**
- Produces (ToastTypes): `ToastStyle = { background: Color3, text: Color3, accent: Color3, font: Enum.Font, sound: string? }`, `ToastRequest = { text: string, style: string?, duration: number? }`, `Toast = { id: number, text: string, style: string, expiresAt: number }`
- Produces (ToastRegistry): `register(name, style)`, `get(name) -> ToastStyle?`, `has(name) -> boolean`; `info` is registered by the module itself.
- Produces (ToastRules): `normalize(request, hasStyle: (string) -> boolean) -> ({ text: string, style: string, duration: number }?, string?)`
- Produces (ToastQueueUtils): `push(list, toast, maxVisible) -> { Toast }`, `expire(list, now) -> ({ Toast }, boolean)`
- Produces (ToastServiceServer): `send(target: Player | "all", request: ToastRequest) -> boolean`
- Produces (ToastStore): `toasts: Charm.Atom<{ Toast }>`, `push(text, style, duration, now)`, `expire(now)`
- Cleanup Crew (M3) registers its own styles with `ToastRegistry.register` from shared code so both realms know them.

- [ ] **Step 1: Failing specs.**

`ToastRules.spec.luau`:

```lua
local ToastRules = require(script.Parent.ToastRules)

local function hasStyle(name)
	return name == "info" or name == "stamp"
end

return function()
	it("keeps a well-formed request", function()
		local toast = ToastRules.normalize({ text = "QUOTA MET", style = "stamp", duration = 3 }, hasStyle)
		expect(toast.text).to.equal("QUOTA MET")
		expect(toast.style).to.equal("stamp")
		expect(toast.duration).to.equal(3)
	end)

	it("refuses empty or blank text", function()
		local toast, reason = ToastRules.normalize({ text = "   " }, hasStyle)
		expect(toast).to.equal(nil)
		expect(reason).to.equal("empty")
	end)

	it("clamps long text to MAX_TEXT characters", function()
		local toast = ToastRules.normalize({ text = string.rep("a", 500) }, hasStyle)
		expect(#toast.text).to.equal(140)
	end)

	it("falls back to info for a missing or unknown style", function()
		expect(ToastRules.normalize({ text = "hi" }, hasStyle).style).to.equal("info")
		expect(ToastRules.normalize({ text = "hi", style = "nope" }, hasStyle).style).to.equal("info")
	end)

	it("defaults and clamps the duration", function()
		expect(ToastRules.normalize({ text = "hi" }, hasStyle).duration).to.equal(4)
		expect(ToastRules.normalize({ text = "hi", duration = 0 }, hasStyle).duration).to.equal(1)
		expect(ToastRules.normalize({ text = "hi", duration = 999 }, hasStyle).duration).to.equal(15)
	end)
end
```

`ToastQueueUtils.spec.luau`:

```lua
local ToastQueueUtils = require(script.Parent.ToastQueueUtils)

local function toast(id, expiresAt)
	return { id = id, text = tostring(id), style = "info", expiresAt = expiresAt }
end

return function()
	it("appends the newest last", function()
		local list = ToastQueueUtils.push({ toast(1, 10) }, toast(2, 10), 4)
		expect(#list).to.equal(2)
		expect(list[2].id).to.equal(2)
	end)

	it("drops the oldest beyond maxVisible", function()
		local list = {}
		for id = 1, 5 do
			list = ToastQueueUtils.push(list, toast(id, 10), 4)
		end
		expect(#list).to.equal(4)
		expect(list[1].id).to.equal(2)
	end)

	it("does not change the list it was given", function()
		local original = { toast(1, 10) }
		ToastQueueUtils.push(original, toast(2, 10), 4)
		expect(#original).to.equal(1)
	end)

	it("expires toasts whose time has passed and says whether anything changed", function()
		local list, changed = ToastQueueUtils.expire({ toast(1, 5), toast(2, 15) }, 10)
		expect(changed).to.equal(true)
		expect(#list).to.equal(1)
		expect(list[1].id).to.equal(2)
		local _, unchanged = ToastQueueUtils.expire(list, 10)
		expect(unchanged).to.equal(false)
	end)
end
```

`ToastRegistry.spec.luau`:

```lua
local ToastRegistry = require(script.Parent.ToastRegistry)

local STYLE = {
	background = Color3.new(1, 1, 0),
	text = Color3.new(0, 0, 0),
	accent = Color3.new(1, 0, 0),
	font = Enum.Font.SourceSans,
}

return function()
	it("ships the info style", function()
		expect(ToastRegistry.has("info")).to.equal(true)
	end)

	it("registers and returns a style", function()
		if not ToastRegistry.has("spec-sticky") then
			ToastRegistry.register("spec-sticky", STYLE)
		end
		expect(ToastRegistry.get("spec-sticky").background).to.equal(STYLE.background)
	end)

	it("rejects a duplicate style", function()
		if not ToastRegistry.has("spec-dup") then
			ToastRegistry.register("spec-dup", STYLE)
		end
		expect(function()
			ToastRegistry.register("spec-dup", STYLE)
		end).to.throw()
	end)
end
```

`ToastStore.spec.luau` (client State):

```lua
local ToastStore = require(script.Parent.ToastStore)

return function()
	beforeEach(function()
		ToastStore.toasts({})
	end)

	it("pushes toasts with increasing ids and an expiry", function()
		ToastStore.push("one", "info", 4, 100)
		ToastStore.push("two", "info", 4, 101)
		local list = ToastStore.toasts()
		expect(#list).to.equal(2)
		expect(list[2].id > list[1].id).to.equal(true)
		expect(list[1].expiresAt).to.equal(104)
	end)

	it("expires toasts on time", function()
		ToastStore.push("one", "info", 4, 100)
		ToastStore.expire(103)
		expect(#ToastStore.toasts()).to.equal(1)
		ToastStore.expire(105)
		expect(#ToastStore.toasts()).to.equal(0)
	end)
end
```

- [ ] **Step 2: Run to verify failure** (modules missing).

- [ ] **Step 3: Shared data.**

`ToastTypes.luau`:

```lua
--!strict
--[=[
	ToastTypes: the Toast feature's shapes. Types only (spec-exempt).

	@class ToastTypes
]=]

export type ToastStyle = {
	background: Color3,
	text: Color3,
	accent: Color3,
	font: Enum.Font,
	-- SoundRegistry id played when a toast in this style appears; absent = silent.
	sound: string?,
}

-- What a game sends. Absent style = ToastConstants.DEFAULT_STYLE; absent duration = DEFAULT_DURATION.
export type ToastRequest = {
	text: string,
	style: string?,
	duration: number?,
}

-- A toast on screen (client), expiring at `expiresAt` (os.clock()).
export type Toast = {
	id: number,
	text: string,
	style: string,
	expiresAt: number,
}

return {}
```

`ToastConstants.luau`:

```lua
--!strict
--[=[
	ToastConstants: defaults and limits. Static data (spec-exempt).

	@class ToastConstants
]=]

return table.freeze({
	DEFAULT_STYLE = "info",
	-- Seconds on screen: default, and the range a request is clamped to.
	DEFAULT_DURATION = 4,
	MIN_DURATION = 1,
	MAX_DURATION = 15,
	-- Characters; longer text is cut.
	MAX_TEXT = 140,
	-- Toasts shown at once; a new one pushes the oldest out.
	MAX_VISIBLE = 4,
})
```

`ToastRegistry.luau`:

```lua
--!strict
--[=[
	ToastRegistry: toast styles by name (the ItemRegistry contract: loud at boot, no re-registration).
	Ships `info`; a game registers its own from shared code so the server can validate and the client
	can draw them.

	@class ToastRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

local styles: { [string]: ToastTypes.ToastStyle } = {}

local ToastRegistry = {}

function ToastRegistry.register(name: string, style: ToastTypes.ToastStyle)
	assert(name ~= "", "toast style name must not be empty")
	assert(styles[name] == nil, `toast style "{name}" is already registered`)
	styles[name] = table.freeze(table.clone(style))
end

function ToastRegistry.get(name: string): ToastTypes.ToastStyle?
	return styles[name]
end

function ToastRegistry.has(name: string): boolean
	return styles[name] ~= nil
end

ToastRegistry.register("info", {
	background = Color3.fromRGB(20, 22, 29),
	text = Color3.fromRGB(228, 231, 238),
	accent = Color3.fromRGB(120, 170, 255),
	font = Enum.Font.SourceSansSemibold,
})

return ToastRegistry
```

`ToastEvents.luau`:

```lua
--!strict
--[=[
	ToastEvents: the ByteNet packet that shows a toast (server → client). Already normalized by the
	server (ToastRules).

	@class ToastEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ToastEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ToastEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Show = ByteNet.definePacket({
				value = ByteNet.struct({
					text = ByteNet.string,
					style = ByteNet.string,
					duration = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ToastEvents
```

- [ ] **Step 4: Rules and utils.**

`ToastRules.luau`:

```lua
--!strict
--[=[
	ToastRules: turns a game's toast request into what is sent: trimmed, non-empty text cut to MAX_TEXT,
	a known style (else the default), a clamped duration. Pure.

	@class ToastRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastConstants = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

export type Normalized = { text: string, style: string, duration: number }

local ToastRules = {}

function ToastRules.normalize(
	request: ToastTypes.ToastRequest,
	hasStyle: (name: string) -> boolean
): (Normalized?, string?)
	local text = string.match(request.text, "^%s*(.-)%s*$") or ""
	if text == "" then
		return nil, "empty"
	end
	local style = request.style
	local duration = request.duration or ToastConstants.DEFAULT_DURATION
	return {
		text = string.sub(text, 1, ToastConstants.MAX_TEXT),
		style = if style ~= nil and hasStyle(style) then style else ToastConstants.DEFAULT_STYLE,
		duration = math.clamp(duration, ToastConstants.MIN_DURATION, ToastConstants.MAX_DURATION),
	},
		nil
end

return ToastRules
```

`ToastQueueUtils.luau`:

```lua
--!strict
--[=[
	ToastQueueUtils: the visible-toast list's two moves, as pure functions returning new lists.

	@class ToastQueueUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

type Toast = ToastTypes.Toast

local ToastQueueUtils = {}

-- The list with `toast` appended; the oldest drop off past `maxVisible`.
function ToastQueueUtils.push(list: { Toast }, toast: Toast, maxVisible: number): { Toast }
	local result = table.clone(list)
	table.insert(result, toast)
	while #result > maxVisible do
		table.remove(result, 1)
	end
	return result
end

-- The list without toasts expired at `now`, and whether any were removed.
function ToastQueueUtils.expire(list: { Toast }, now: number): ({ Toast }, boolean)
	local result: { Toast } = {}
	for _, toast in list do
		if toast.expiresAt > now then
			table.insert(result, toast)
		end
	end
	return result, #result ~= #list
end

return ToastQueueUtils
```

- [ ] **Step 5: Server** `src/ServerScriptService/Features/Toast/ToastServiceServer.luau`:

```lua
--!strict
--[=[
	ToastServiceServer: shows a short message on one player's or everyone's screen ("QUOTA MET",
	"You hear Harlow pacing faster…"). Requests are normalized by ToastRules; the client draws them in
	the style named (ToastRegistry).

	Spec-exempt shell (ByteNet); the decision is the specced ToastRules.

	@class ToastServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastShared = ReplicatedStorage.Shared.Features.Toast
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ToastEvents = require(ToastShared.Net.ToastEvents)
local ToastRegistry = require(ToastShared.Data.ToastRegistry)
local ToastRules = require(ToastShared.Rules.ToastRules)
local ToastTypes = require(ToastShared.Data.ToastTypes)

local log = Logger.new("ToastServiceServer")
local counters = { sent = 0, refused = 0 }

export type ToastServiceServer = {
	dependencies: { string },
	getState: (self: ToastServiceServer) -> { [string]: any },
	send: (self: ToastServiceServer, target: Player | "all", request: ToastTypes.ToastRequest) -> boolean,
}

local ToastServiceServer: ToastServiceServer = {
	dependencies = {},

	--[=[
		Shows `request` to one player or to "all". False (and a warning) for empty text.
	]=]
	send = function(_self, target, request)
		local toast, reason = ToastRules.normalize(request, ToastRegistry.has)
		if toast == nil then
			counters.refused += 1
			log:warn(`toast refused: {reason or "?"}`)
			return false
		end
		if target == "all" then
			ToastEvents.packets.Show.sendToAll(toast)
		else
			ToastEvents.packets.Show.sendTo(toast, target)
		end
		counters.sent += 1
		return true
	end,

	getState = function(_self)
		return { counters = table.clone(counters) }
	end,
}

return ToastServiceServer
```

- [ ] **Step 6: Client store** `src/ReplicatedStorage/Client/Features/Toast/State/ToastStore.luau`:

```lua
--!strict
--[=[
	ToastStore: the toasts on screen, as one Charm atom the HUD reads (ToastStack). Written only by
	ToastServiceClient.

	@class ToastStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ToastConstants = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)
local ToastQueueUtils = require(ReplicatedStorage.Shared.Features.Toast.Utils.ToastQueueUtils)

local initial: { ToastTypes.Toast } = {}
local toasts = Charm.atom(initial)
local nextId = 0

local ToastStore = {
	toasts = toasts,
}

function ToastStore.push(text: string, style: string, duration: number, now: number)
	nextId += 1
	toasts(ToastQueueUtils.push(toasts(), {
		id = nextId,
		text = text,
		style = style,
		expiresAt = now + duration,
	}, ToastConstants.MAX_VISIBLE))
end

function ToastStore.expire(now: number)
	local list, changed = ToastQueueUtils.expire(toasts(), now)
	if changed then
		toasts(list)
	end
end

return ToastStore
```

- [ ] **Step 7: Widget + story.**

`src/ReplicatedStorage/Client/UI/React/Screens/Hud/ToastStack.luau`:

```lua
--!strict
--[=[
	ToastStack: the toasts on screen, stacked top-centre, newest at the bottom, each drawn in its
	ToastRegistry style. Reads ToastStore; never writes.

	@class ToastStack
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)

local e = React.createElement

local WIDTH = 360

local function ToastStack(): React.ReactNode
	local toasts = ReactCharm.useAtom(ToastStore.toasts)
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, toast in toasts do
		local style = ToastRegistry.get(toast.style) or ToastRegistry.get("info")
		if style ~= nil then
			children[`toast{toast.id}`] = e("TextLabel", {
				LayoutOrder = index,
				Size = UDim2.fromOffset(WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = style.background,
				TextColor3 = style.text,
				Font = style.font,
				TextSize = Tokens.textSize.xl,
				TextWrapped = true,
				Text = toast.text,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.md) }),
				stroke = e("UIStroke", {
					Color = style.accent,
					Thickness = Tokens.stroke.thick,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				padding = e("UIPadding", {
					PaddingTop = UDim.new(0, Tokens.space.md),
					PaddingBottom = UDim.new(0, Tokens.space.md),
					PaddingLeft = UDim.new(0, Tokens.space.lg),
					PaddingRight = UDim.new(0, Tokens.space.lg),
				}),
			})
		end
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Tokens.space.xxl * 3),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, children)
end

return ToastStack
```

`ToastStack.story.luau`:

```lua
--!strict
--[=[
	ToastStack.story: the toast stack with sample toasts, in Studio's edit mode (UI Labs).

	@class ToastStack.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local ToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Text = "You hear Harlow pacing faster…",
		Count = 2,
	},
}, function(props)
	local controls = props.controls
	ToastStore.toasts({})
	for _ = 1, controls.Count do
		ToastStore.push(controls.Text, "info", 60, os.clock())
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		stack = e(ToastStack),
	})
end)
```

- [ ] **Step 8: Client service** `src/ReplicatedStorage/Client/Features/Toast/ToastServiceClient.luau`:

```lua
--!strict
--[=[
	ToastServiceClient: receives toasts, plays their style's sound, keeps ToastStore current and expires
	toasts on time. Registers the ToastStack HUD widget during init (before the UI starts).

	Spec-exempt shell (ByteNet, RunService, Sound); the list moves are the specced ToastStore /
	ToastQueueUtils.

	@class ToastServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ToastEvents = require(ReplicatedStorage.Shared.Features.Toast.Net.ToastEvents)
local ToastRegistry = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastRegistry)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local ToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack)

-- Above the game's widgets, so a toast is never drawn under a HUD panel.
local HUD_ORDER = 1000
local EXPIRE_INTERVAL = 0.25

local stoppers: { () -> () } = {}

export type ToastServiceClient = {
	dependencies: { string },
	init: (self: ToastServiceClient) -> (),
	start: (self: ToastServiceClient) -> (),
	stop: (self: ToastServiceClient) -> (),
}

local ToastServiceClient: ToastServiceClient = {
	dependencies = { "SoundServiceClient" },

	init = function(_self)
		if not HudRegistry.has("toasts") then
			HudRegistry.register("toasts", ToastStack, HUD_ORDER)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			ToastEvents.packets.Show.listen(function(data)
				ToastStore.push(data.text, data.style, data.duration, os.clock())
				local style = ToastRegistry.get(data.style)
				local sound = if style ~= nil then style.sound else nil
				if sound ~= nil and SoundRegistry.has(sound) then
					SoundServiceClient:play(sound)
				end
			end)
		)
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= EXPIRE_INTERVAL then
				elapsed = 0
				ToastStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,
}

return ToastServiceClient
```
Check `SoundRegistry.has` exists (`grep -n "function SoundRegistry" src/ReplicatedStorage/Shared/Features/Sound/Data/SoundRegistry.luau`); if it is named differently, use that name. Check `SoundServiceClient:play(id)` accepts a nil options argument (it does: `play = function(_self, id, options)`).

- [ ] **Step 9: Exemptions, docs, module map.** Add to `EXEMPT_MODULES`:

```lua
	["ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes"] = "type definitions only (no runtime logic)",
	["ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants"] = "static defaults and limits (no logic)",
	["ReplicatedStorage.Shared.Features.Toast.Net.ToastEvents"] = "ByteNet packet definitions (no logic)",
	["ServerScriptService.Features.Toast.ToastServiceServer"] = "ByteNet shell (ToastRules is specced)",
	["ReplicatedStorage.Client.Features.Toast.ToastServiceClient"] = "ByteNet/RunService/Sound shell (ToastStore and ToastQueueUtils are specced)",
	["ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack"] = "React UI component (rendered in-game; story in ToastStack.story)",
```
In `docs/project-structure.md` add `Toast` to the **Feature names** list (alphabetical, after `Title`). Then:

```bash
python3 scripts/python/module_map.py --write
```

- [ ] **Step 10: Run specs + gate.** Studio `RunTests = true` → ToastRules, ToastQueueUtils, ToastRegistry, ToastStore pass. `bash scripts/check.sh --skip-install` → pass.

- [ ] **Step 11: Studio verification.** Play Solo; server command bar:

```lua
local T = require(game.ServerScriptService.Features.Toast.ToastServiceServer)
for i = 1, 6 do T:send("all", { text = "Toast " .. i, duration = 3 + i }) end
T:send("all", { text = "   " })
```
Expected: four toasts visible top-centre (Toast 3–6), each vanishing on its time; a `toast refused: empty` warning. Then open the `ToastStack` story in UI Labs (edit mode) → renders.

- [ ] **Step 12: Commit**

```bash
git add src docs/project-structure.md
git commit -m "feat(toast): server-sent toasts with styles and a HUD stack"
```

---

### Task 6: Docs, full gate, PR

**Files:**
- Modify: `docs/ROADMAP.md` (note the new hooks under the systems they extend; add Toast; add "Queue — planned before Cleanup Crew M4")
- Modify: `docs/superpowers/specs/2026-10-09-npc-design.md`, `...-death-design.md`, `...-carry-design.md`, `...-interaction-design.md` — one "2026-10-10 additions" paragraph each naming the new API.

- [ ] **Step 1: Write the doc paragraphs** (one short paragraph each, naming exactly the APIs from Tasks 1–5).

- [ ] **Step 2: Full gate, only when the developer is NOT connected to rojo serve** (tell them first):

```bash
bash scripts/check.sh
```
Expected: all stages pass.

- [ ] **Step 3: Full TestEZ run in Studio** (`RunTests = true`). Expected: every spec passes, `assertAllModulesSpecced` passes.

- [ ] **Step 4: Commit, push, PR**

```bash
git add docs
git commit -m "docs: record the base game hooks"
git push -u origin base/game-hooks
gh pr create --base main --title "Base game hooks: NPC brain, Death spawn/launch, Carry signals, Interaction channels, Toast" --body "$(cat <<'EOF'
Adds five generic hooks Cleanup Crew needs (spec: docs/superpowers/specs/2026-10-10-cleanup-crew-design.md §6.1), each useful to at least one more of the team's games:

- Npc: setBrain(kind, brain), goTo intent, setTuning(npc, tuning), pathCosts
- Death: setSpawnPoint(resolver), kill(..., { launch })
- Carry: pickedUp / dropped(reason) signals
- Interaction: channels (continuous hold with server-side progress)
- Toast: new feature, server-sent toasts with styles and a HUD stack

Queue (party pads + reserved servers) follows in its own PR before Cleanup Crew M4.

Verified: scripts/check.sh green; TestEZ green in Studio; Studio checklists in docs/superpowers/plans/2026-10-10-m0-base-game-hooks.md (Tasks 2-5).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: After review, merge with a merge commit** (never squash): `gh pr merge <N> --merge --subject "Merge PR #<N>: Base game hooks"`.

---

## Next plans (written after M0 merges)

- `2026-10-xx-m1-cleanup-crew-graybox.md` on `game/cleanup-crew` (Office, Shift, Vacuum, Cargo; Studio loop without Harlow)
- M2 Occupant + Noise; M3 feel (Figma approval gate); Queue base PR; M4 Depot; M5 phone, analytics, publish.
