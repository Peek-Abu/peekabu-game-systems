# Character Replication R6 — Player Collision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make players solid to each other: a capsule blocker welded into every puppet, solid only near the local player, with a self-collider on the local rig and a slide-off push off heads.

**Architecture:**
- A new `Collision` feature. Shared: a size table and pure geometry. Server: one service that registers two collision groups. Client: one service that listens to the existing body API (`bodySpawned` / `bodyDespawned`) and runs one PreSimulation step through two systems (blockers, slide-off).
- No existing runtime module changes. `ReplicationServiceClient` is not touched.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ (Studio only), Janitor, Logger, the `ServiceController` `*ServiceServer` / `*ServiceClient` discovery under `Features/`.

**Spec:** `docs/superpowers/specs/2026-10-08-character-replication-r6-collision-design.md` (read it first; §3 is the size table, §4 the connection, §5 the per-frame step, §6 the performance targets).

## Global Constraints

- `--!strict` everywhere. No `any`, no `::` casts. Spec files are untyped and mirror `VoiceWiringTracker.spec.luau`.
- Service shape: lean annotated literal (`export type X = {...}` + `local X: X = {...}`), methods as fields.
- Module names and places exactly as the New modules table below. A name ends with a role word its subfolder allows.
- Requires use full addresses. A spec requires its own module via `script.Parent`. Use a `<Feature><Realm>` folder variable only for 3+ requires from one feature folder (rule 7). No file in this plan reaches 3.
- Spec-first: write `<Name>.spec.luau` before `<Name>.luau`. The two services are spec-exempt shells with a reason in `SpecRoots.EXEMPT_MODULES`.
- File length cap: 400 code lines.
- Commits: plain messages, no `Co-Authored-By:` / `Claude-Session:` trailers.
- Local gate: `bash scripts/check.sh` from the worktree root `B:/Projects/venture-game-systems/.claude/worktrees/replication-collision`. Run it with its `wally install` step the first time (fresh worktree), then `--skip-install`. Never run `rojo` commands. TestEZ runs only in Studio (Task 6).
- Never mention other games' names in code or docs on this branch.
- After adding modules: `python3 scripts/python/module_map.py --write` (Task 5).

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Collision | shared | Data | `CollisionConstants` | Size table, ranges, slide-off, group names, debug colours |
| Collision | shared | Utils | `CollisionShapeUtils` | Pure geometry: capsule parts, resting-on, push direction, slide-off velocity, range band |
| Collision | server | (root) | `CollisionServiceServer` | Registers the two collision groups at boot |
| Collision | client | Systems | `CollisionBlockerSystem` | Builds, welds, range-gates, velocity-drives and removes capsules |
| Collision | client | Systems | `CollisionSlideOffSystem` | Pushes the local root off a head |
| Collision | client | (root) | `CollisionServiceClient` | Body-API subscriber, PreSimulation step, F4 state |

Paths:
- `src/ReplicatedStorage/Shared/Features/Collision/Data/CollisionConstants.luau`
- `src/ReplicatedStorage/Shared/Features/Collision/Utils/CollisionShapeUtils.luau`
- `src/ServerScriptService/Features/Collision/CollisionServiceServer.luau`
- `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionBlockerSystem.luau`
- `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionSlideOffSystem.luau`
- `src/ReplicatedStorage/Client/Features/Collision/CollisionServiceClient.luau`

Plus a spec beside each, except the two services.

## Review Focus

1. **A solid puppet that teleports next to you** (respawn, unhide) must not fling you. Its contact velocity is zero on a teleport frame (Task 3 test "zero after a teleport").
2. **A pooled puppet reused for another player** must carry exactly one capsule (Task 3 tests "despawn → spawn" and "adding twice").
3. **A local respawn** must leave exactly one self-collider, on the new rig (Task 3 test "replaces it on respawn").
4. **Debug view toggled mid-session** must apply to capsules built afterwards too (Task 3 test "debug").
5. **Groups the place's art already registers** (for example an old `Players` group) must not collide with blockers. The server walks every registered group (Task 2 code; Task 6 Studio check "camera, clicks and tools unaffected" plus F4 server state).

---

### Task 1: Shared size table and geometry

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Collision/Data/CollisionConstants.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Collision/Data/CollisionConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Collision/Utils/CollisionShapeUtils.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Collision/Utils/CollisionShapeUtils.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `CollisionConstants` fields: `RADIUS`, `BOTTOM`, `TOP`, `SOLID_RANGE`, `RELEASE_RANGE`, `RANGE_CHECK_HZ`, `SLIDE_OFF_SPEED`, `REST_GAP`, `REST_MAX_RISE`, `CENTRE_EPSILON`, `MAX_CONTACT_SPEED`, `PUPPET_GROUP`, `SELF_GROUP`, `FRICTIONLESS`, `DEBUG_ATTRIBUTE`, `DEBUG_TRANSPARENCY`, `PUPPET_COLOR`, `SELF_COLOR`.
  - `CollisionShapeUtils`:
    - `export type PartSpec = { name: string, shape: Enum.PartType, size: Vector3, offset: CFrame }`
    - `capsule(radius: number, bottom: number, top: number): { PartSpec }` returns bottom ball, middle cylinder, top ball, in that order.
    - `restingOn(mine: Vector3, riseSpeed: number, theirs: Vector3): boolean`
    - `pushDirection(mine: Vector3, theirs: Vector3, look: Vector3): Vector3`
    - `slideOffVelocity(velocity: Vector3, direction: Vector3): Vector3?`
    - `nextSolid(solid: boolean, distanceSquared: number): boolean`

- [ ] **Step 1: Write the constants spec**

```lua
--!strict
--[=[
	Unit tests for CollisionConstants (R6 spec 2026-10-08 §3): the size table's invariants.
]=]

local CollisionConstants = require(script.Parent.CollisionConstants)

return function()
	local C = CollisionConstants

	it("releases farther out than it turns solid, and turns solid well before contact", function()
		expect(C.RELEASE_RANGE > C.SOLID_RANGE).to.equal(true)
		expect(C.SOLID_RANGE > 2 * C.RADIUS).to.equal(true)
	end)

	it("spans feet to head top with room for both end caps", function()
		expect(C.BOTTOM < C.TOP).to.equal(true)
		expect(C.TOP - C.BOTTOM > 2 * C.RADIUS).to.equal(true)
	end)

	it("keeps the slide-off push under walk speed and the teleport bar above it", function()
		expect(C.SLIDE_OFF_SPEED > 0).to.equal(true)
		expect(C.SLIDE_OFF_SPEED < 16).to.equal(true)
		expect(C.MAX_CONTACT_SPEED > 16).to.equal(true)
	end)

	it("names two distinct groups and a frictionless material", function()
		expect(C.PUPPET_GROUP).never.to.equal(C.SELF_GROUP)
		expect(C.FRICTIONLESS.Friction).to.equal(0)
		expect(C.FRICTIONLESS.FrictionWeight).to.equal(100)
	end)
end
```

- [ ] **Step 2: Write the constants module**

```lua
--!strict
--[=[
	CollisionConstants (R6 spec 2026-10-08 §3): the player-collision size table and tuning.

	Offsets are relative to the HumanoidRootPart, in studs, measured on the Venture rig (2026-09-24). The
	values are the CP7 spike's, unchanged; the 20/22 buffer, the 10 Hz range check and MAX_CONTACT_SPEED
	are R6's. This table is also the contract a later anti-cheat phase reads for "players are ground and
	walls" (spec decision 3).

	@class CollisionConstants
]=]

local CollisionConstants = {
	-- The capsule: radius, bottom of the feet, top of the head.
	RADIUS = 1.1,
	BOTTOM = -4.05,
	TOP = 1.53,
	-- A blocker turns solid at SOLID_RANGE or closer and off beyond RELEASE_RANGE (a buffer, so a player
	-- pacing the edge doesn't flip it), checked RANGE_CHECK_HZ times a second.
	SOLID_RANGE = 20,
	RELEASE_RANGE = 22,
	RANGE_CHECK_HZ = 10,
	-- Slide-off: while my feet rest on a head (within ±REST_GAP of its top, not rising faster than
	-- REST_MAX_RISE), my outward speed is raised to SLIDE_OFF_SPEED. Within CENTRE_EPSILON of their centre
	-- the push follows my facing.
	SLIDE_OFF_SPEED = 12,
	REST_GAP = 0.6,
	REST_MAX_RISE = 1,
	CENTRE_EPSILON = 0.2,
	-- A puppet that moved faster than this in one frame teleported; its contact velocity is written as zero.
	-- Provisional.
	MAX_CONTACT_SPEED = 80,
	PUPPET_GROUP = "CollisionPuppetBlocker",
	SELF_GROUP = "CollisionSelfCollider",
	-- density 0.7, friction 0, elasticity 0, FrictionWeight 100 (it wins the contact), ElasticityWeight 1.
	FRICTIONLESS = PhysicalProperties.new(0.7, 0, 0, 100, 1),
	-- Workspace attribute; true draws the capsules.
	DEBUG_ATTRIBUTE = "CollisionDebug",
	DEBUG_TRANSPARENCY = 0.6,
	PUPPET_COLOR = Color3.fromRGB(235, 70, 70),
	SELF_COLOR = Color3.fromRGB(70, 140, 235),
}

return CollisionConstants
```

- [ ] **Step 3: Write the geometry spec**

```lua
--!strict
--[=[
	Unit tests for CollisionShapeUtils (R6 spec 2026-10-08 §4, §5): capsule parts, resting-on, push
	direction, slide-off velocity and the range band.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionShapeUtils = require(script.Parent.CollisionShapeUtils)

return function()
	local C = CollisionConstants
	local HEAD = C.TOP - C.BOTTOM -- my root height when my feet are exactly on their head top (theirs at Y 0)

	local function near(a, b)
		return math.abs(a - b) < 1e-4 -- CFrame and Vector3 components are float32
	end

	local function nearVector(a, b)
		return (a - b).Magnitude < 1e-4
	end

	describe("capsule", function()
		it("joins two balls and an upright cylinder into exactly bottom..top at the radius", function()
			local parts = CollisionShapeUtils.capsule(C.RADIUS, C.BOTTOM, C.TOP)
			expect(#parts).to.equal(3)
			local bottom, middle, top = parts[1], parts[2], parts[3]
			expect(bottom.shape).to.equal(Enum.PartType.Ball)
			expect(middle.shape).to.equal(Enum.PartType.Cylinder)
			expect(top.shape).to.equal(Enum.PartType.Ball)
			expect(near(bottom.size.X, 2 * C.RADIUS)).to.equal(true)
			expect(near(top.size.X, 2 * C.RADIUS)).to.equal(true)
			expect(near(middle.size.Y, 2 * C.RADIUS)).to.equal(true)
			expect(near(bottom.offset.Position.Y - C.RADIUS, C.BOTTOM)).to.equal(true)
			expect(near(top.offset.Position.Y + C.RADIUS, C.TOP)).to.equal(true)
			-- the cylinder's axis is X; stood upright it runs along Y between the two ball centres
			expect(near(middle.offset.RightVector.Y, 1)).to.equal(true)
			expect(near(middle.size.X, top.offset.Position.Y - bottom.offset.Position.Y)).to.equal(true)
			expect(near(middle.offset.Position.Y, (top.offset.Position.Y + bottom.offset.Position.Y) / 2)).to.equal(true)
		end)

		it("matches the measured rig numbers", function()
			local parts = CollisionShapeUtils.capsule(C.RADIUS, C.BOTTOM, C.TOP)
			expect(math.abs(parts[1].offset.Position.Y - -2.95) < 1e-4).to.equal(true)
			expect(math.abs(parts[2].offset.Position.Y - -1.26) < 1e-4).to.equal(true)
			expect(math.abs(parts[2].size.X - 3.38) < 1e-4).to.equal(true)
			expect(math.abs(parts[3].offset.Position.Y - 0.43) < 1e-4).to.equal(true)
		end)
	end)

	describe("restingOn", function()
		local theirs = Vector3.zero

		it("is true with my feet on their head top, inside two radii", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0.5, HEAD, 0), 0, theirs)).to.equal(true)
		end)

		it("holds inside the gap tolerance and fails just outside it", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD + 0.59, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD - 0.59, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD + 0.61, 0), 0, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD - 0.61, 0), 0, theirs)).to.equal(false)
		end)

		it("fails at two radii or more horizontally", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(2.19, HEAD, 0), 0, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(2.21, HEAD, 0), 0, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(1.6, HEAD, 1.6), 0, theirs)).to.equal(false)
		end)

		it("fails while rising faster than the limit, holds while falling", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), 1, theirs)).to.equal(true)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), 1.01, theirs)).to.equal(false)
			expect(CollisionShapeUtils.restingOn(Vector3.new(0, HEAD, 0), -20, theirs)).to.equal(true)
		end)

		it("is false when standing beside them on the same floor", function()
			expect(CollisionShapeUtils.restingOn(Vector3.new(1.5, 0, 0), 0, theirs)).to.equal(false)
		end)
	end)

	describe("pushDirection", function()
		it("points horizontally away from their centre", function()
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(3, 5, 4), Vector3.zero, Vector3.zAxis)
			expect(nearVector(direction, Vector3.new(0.6, 0, 0.8))).to.equal(true)
		end)

		it("follows my horizontal facing when I'm over their centre", function()
			local look = Vector3.new(0, -0.6, -0.8)
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(0.1, 5, 0), Vector3.zero, look)
			expect(nearVector(direction, Vector3.new(0, 0, -1))).to.equal(true)
		end)

		it("falls back to +X when I'm over their centre looking straight up", function()
			local direction = CollisionShapeUtils.pushDirection(Vector3.new(0, 5, 0), Vector3.zero, Vector3.yAxis)
			expect(nearVector(direction, Vector3.xAxis)).to.equal(true)
		end)
	end)

	describe("slideOffVelocity", function()
		it("raises the outward speed to the slide-off speed, keeping the rest", function()
			local pushed = CollisionShapeUtils.slideOffVelocity(Vector3.new(0, -3, 0), Vector3.xAxis)
			expect(nearVector(pushed, Vector3.new(12, -3, 0))).to.equal(true)
			local inward = CollisionShapeUtils.slideOffVelocity(Vector3.new(-4, 0, 2), Vector3.xAxis)
			expect(nearVector(inward, Vector3.new(12, 0, 2))).to.equal(true)
		end)

		it("returns nil when already moving out at least that fast", function()
			expect(CollisionShapeUtils.slideOffVelocity(Vector3.new(12, 0, 0), Vector3.xAxis)).to.equal(nil)
			expect(CollisionShapeUtils.slideOffVelocity(Vector3.new(15, 0, 0), Vector3.xAxis)).to.equal(nil)
		end)
	end)

	describe("nextSolid", function()
		it("turns solid at the solid range or closer", function()
			expect(CollisionShapeUtils.nextSolid(false, 20 * 20)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(false, 20.01 * 20.01)).to.equal(false)
			expect(CollisionShapeUtils.nextSolid(false, 21 * 21)).to.equal(false)
		end)

		it("stays solid through the buffer and releases beyond it", function()
			expect(CollisionShapeUtils.nextSolid(true, 21 * 21)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(true, 22 * 22)).to.equal(true)
			expect(CollisionShapeUtils.nextSolid(true, 22.01 * 22.01)).to.equal(false)
		end)
	end)
end
```

- [ ] **Step 4: Write the geometry module**

```lua
--!strict
--[=[
	CollisionShapeUtils (R6 spec 2026-10-08 §4, §5): pure player-collision geometry. No Instances.

	- `capsule` turns the size table into three primitive parts (Roblox has no capsule primitive): a bottom
	  ball, an upright cylinder, a top ball, each with its offset from the root.
	- `restingOn` / `pushDirection` / `slideOffVelocity` are the slide-off rule (heads aren't standable).
	- `nextSolid` is the range band with its buffer.

	@class CollisionShapeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)

export type PartSpec = { name: string, shape: Enum.PartType, size: Vector3, offset: CFrame }

local CollisionShapeUtils = {}

-- A Cylinder part's axis is X; this stands it up along Y.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local SOLID_SQUARED = CollisionConstants.SOLID_RANGE * CollisionConstants.SOLID_RANGE
local RELEASE_SQUARED = CollisionConstants.RELEASE_RANGE * CollisionConstants.RELEASE_RANGE
local REACH_SQUARED = (2 * CollisionConstants.RADIUS) * (2 * CollisionConstants.RADIUS)

--[=[
	The capsule's three parts, root-relative: bottom ball, middle cylinder, top ball.
	@param radius number
	@param bottom number -- root-relative Y of the capsule's bottom
	@param top number -- root-relative Y of the capsule's top
	@return { PartSpec }
]=]
function CollisionShapeUtils.capsule(radius: number, bottom: number, top: number): { PartSpec }
	local diameter = 2 * radius
	local low, high = bottom + radius, top - radius
	local ball = Vector3.new(diameter, diameter, diameter)
	return {
		{ name = "Bottom", shape = Enum.PartType.Ball, size = ball, offset = CFrame.new(0, low, 0) },
		{
			name = "Middle",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(high - low, diameter, diameter),
			offset = CFrame.new(0, (low + high) / 2, 0) * UPRIGHT,
		},
		{ name = "Top", shape = Enum.PartType.Ball, size = ball, offset = CFrame.new(0, high, 0) },
	}
end

--[=[
	Do my feet rest on their head? Inside two radii horizontally, my feet within ±REST_GAP of their head top,
	and not rising faster than REST_MAX_RISE.
	@param mine Vector3 -- my root position
	@param riseSpeed number -- my vertical velocity
	@param theirs Vector3 -- their root position
	@return boolean
]=]
function CollisionShapeUtils.restingOn(mine: Vector3, riseSpeed: number, theirs: Vector3): boolean
	local dx, dz = mine.X - theirs.X, mine.Z - theirs.Z
	if dx * dx + dz * dz >= REACH_SQUARED then
		return false
	end
	local gap = (mine.Y + CollisionConstants.BOTTOM) - (theirs.Y + CollisionConstants.TOP)
	return gap > -CollisionConstants.REST_GAP
		and gap < CollisionConstants.REST_GAP
		and riseSpeed <= CollisionConstants.REST_MAX_RISE
end

--[=[
	The horizontal unit direction to push me off them: away from their centre, or my horizontal facing when
	I'm within CENTRE_EPSILON of it (+X if I'm looking straight up or down).
	@param mine Vector3
	@param theirs Vector3
	@param look Vector3 -- my root's LookVector
	@return Vector3
]=]
function CollisionShapeUtils.pushDirection(mine: Vector3, theirs: Vector3, look: Vector3): Vector3
	local flat = Vector3.new(mine.X - theirs.X, 0, mine.Z - theirs.Z)
	if flat.Magnitude > CollisionConstants.CENTRE_EPSILON then
		return flat.Unit
	end
	local facing = Vector3.new(look.X, 0, look.Z)
	return if facing.Magnitude > 0 then facing.Unit else Vector3.xAxis
end

--[=[
	My velocity with its component along `direction` raised to SLIDE_OFF_SPEED, or nil when it already is.
	@param velocity Vector3
	@param direction Vector3 -- a horizontal unit vector
	@return Vector3?
]=]
function CollisionShapeUtils.slideOffVelocity(velocity: Vector3, direction: Vector3): Vector3?
	local along = velocity:Dot(direction)
	if along >= CollisionConstants.SLIDE_OFF_SPEED then
		return nil
	end
	return velocity + direction * (CollisionConstants.SLIDE_OFF_SPEED - along)
end

--[=[
	The range band: a blocker turns solid at SOLID_RANGE or closer and stays solid out to RELEASE_RANGE.
	@param solid boolean -- whether it is solid now
	@param distanceSquared number -- squared distance from my root to theirs
	@return boolean
]=]
function CollisionShapeUtils.nextSolid(solid: boolean, distanceSquared: number): boolean
	return distanceSquared <= (if solid then RELEASE_SQUARED else SOLID_SQUARED)
end

return CollisionShapeUtils
```

- [ ] **Step 5: Run the local gate**

Run: `bash scripts/check.sh` (the first run in this fresh worktree includes `wally install`)
Expected: PASS (selene, stylua, typecheck, PR rules including layout, file length, ruff). If stylua reformats, run `stylua src` and re-run with `--skip-install`.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Collision
git commit -m "feat(collision): shared size table and capsule geometry (R6)"
```

---

### Task 2: Server collision groups

**Files:**
- Create: `src/ServerScriptService/Features/Collision/CollisionServiceServer.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (add one `EXEMPT_MODULES` row next to `"ServerScriptService.Features.Voice.VoiceServiceServer"`)

**Interfaces:**
- Consumes: `CollisionConstants.PUPPET_GROUP`, `CollisionConstants.SELF_GROUP` (Task 1).
- Produces: groups `CollisionPuppetBlocker` and `CollisionSelfCollider` registered on the server, which replicate to clients. They collide only with each other. `getState(): { registered: boolean, groups: number }`.

- [ ] **Step 1: Add the exemption row**

In `SpecRoots.luau`, directly after the `"ServerScriptService.Features.Voice.VoiceServiceServer"` row:

```lua
	["ServerScriptService.Features.Collision.CollisionServiceServer"] = "PhysicsService shell (collision groups; verified by the Studio checklist)",
```

- [ ] **Step 2: Write the service**

```lua
--!strict
--[=[
	CollisionServiceServer (R6 spec 2026-10-08 §5): registers the two player-collision groups at start.

	`CollisionPuppetBlocker` (other players' capsules) and `CollisionSelfCollider` (your own capsule)
	collide ONLY with each other: each is set non-collidable with every registered group (Default, any
	group the place's art registers, and themselves), then the pair is set collidable. Blockers never touch
	the map, and your world movement is unchanged. Groups registered on the server replicate to clients.

	A group registered by code after start must set itself non-collidable with these two. None exists.

	Spec-exempt shell (PhysicsService); the capsules themselves are built client-side by CollisionBlockerSystem.

	@class CollisionServiceServer
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)

local log = Logger.new("CollisionServiceServer")
local registered = false

local function registerGroups()
	local pair = { CollisionConstants.PUPPET_GROUP, CollisionConstants.SELF_GROUP }
	for _, name in pair do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		local name = group.name
		if type(name) == "string" then
			for _, ours in pair do
				PhysicsService:CollisionGroupSetCollidable(ours, name, false)
			end
		end
	end
	PhysicsService:CollisionGroupSetCollidable(CollisionConstants.PUPPET_GROUP, CollisionConstants.SELF_GROUP, true)
	registered = true
end

export type CollisionServiceServer = {
	dependencies: { string },
	init: (self: CollisionServiceServer) -> (),
	start: (self: CollisionServiceServer) -> (),
	stop: (self: CollisionServiceServer) -> (),
	getState: (self: CollisionServiceServer) -> { registered: boolean, groups: number },
}

local CollisionServiceServer: CollisionServiceServer = {
	dependencies = {},

	init = function(_self)
		log:debug("CollisionServiceServer initialized")
	end,

	start = function(_self)
		registerGroups()
	end,

	stop = function(_self)
		-- Registered groups belong to the place for the server's life; nothing to undo.
	end,

	getState = function(_self)
		return { registered = registered, groups = #PhysicsService:GetRegisteredCollisionGroups() }
	end,
}

return CollisionServiceServer
```

If the typechecker types `GetRegisteredCollisionGroups()` entries so that `group.name` is already `string`, keep the `type(name) == "string"` narrowing anyway. It costs nothing and keeps `any` out if the API types are loose.

- [ ] **Step 3: Run the local gate**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Features/Collision src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "feat(collision): register the blocker and self-collider groups on the server (R6)"
```

---

### Task 3: Client blocker system

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionBlockerSystem.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionBlockerSystem.luau`

**Interfaces:**
- Consumes: `CollisionConstants` (all fields), `CollisionShapeUtils.capsule`, `CollisionShapeUtils.nextSolid` (Task 1).
- Produces:
  - `export type Capsule = { rig: Model, root: BasePart, parts: { BasePart }, solid: boolean, lastPosition: Vector3 }`
  - `export type State = { puppets: { [Model]: Capsule }, solid: { [Model]: Capsule }, own: Capsule?, debug: boolean, writes: number, sinceRangeCheck: number }`
  - `new(debug: boolean): State`
  - `rootOf(rig: Model?): BasePart?`: the rig's `HumanoidRootPart`
  - `addPuppet(state: State, rig: Model): boolean`: false when the rig has no root
  - `addSelf(state: State, rig: Model): boolean`
  - `remove(state: State, rig: Model)`: a puppet or the own rig, no-op when unknown
  - `updateRange(state: State, origin: Vector3)`
  - `updateVelocities(state: State, dt: number)`
  - `step(state: State, dt: number, origin: Vector3)`: range at RANGE_CHECK_HZ, velocities every call
  - `setDebug(state: State, on: boolean)`
  - `clear(state: State)`
  - `counts(state: State): { puppets: number, solid: number }`
  - `state.writes` counts solid/not-solid flips (each flip writes `CanCollide` on the capsule's 3 parts).

- [ ] **Step 1: Write the spec**

```lua
--!strict
--[=[
	Unit tests for CollisionBlockerSystem (R6 spec 2026-10-08 §4, §5): capsule build and weld, the parked-root
	offset, despawn and reuse, the range band with change-only writes, the 10 Hz check, contact velocity with
	the teleport guard, the self-collider, and debug view. Real Parts on a fake rig with an anchored root.
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionBlockerSystem = require(script.Parent.CollisionBlockerSystem)

return function()
	local C = CollisionConstants
	local rigs

	beforeAll(function()
		-- CollisionServiceServer registers these in a real session; a test session may not boot services.
		for _, name in { C.PUPPET_GROUP, C.SELF_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
	end)

	beforeEach(function()
		rigs = {}
	end)

	afterEach(function()
		for _, model in rigs do
			model:Destroy()
		end
	end)

	local function rig(at)
		local model = Instance.new("Model")
		model.Name = "CollisionSpecRig"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CanCollide = false
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = at
		root.Parent = model
		model.Parent = Workspace
		table.insert(rigs, model)
		return model, root
	end

	local function capsuleParts(model, group)
		local out = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.CollisionGroup == group then
				table.insert(out, child)
			end
		end
		return out
	end

	it("welds three non-solid, frictionless, query-free parts to a puppet's root", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(0, 100, 0))
		expect(CollisionBlockerSystem.addPuppet(state, model)).to.equal(true)
		local parts = capsuleParts(model, C.PUPPET_GROUP)
		expect(#parts).to.equal(3)
		for _, part in parts do
			expect(part.CanCollide).to.equal(false)
			expect(part.CanQuery).to.equal(false)
			expect(part.CanTouch).to.equal(false)
			expect(part.Massless).to.equal(true)
			expect(part.Anchored).to.equal(false)
			expect(part.Transparency).to.equal(1)
			expect(part.CustomPhysicalProperties.Friction).to.equal(0)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			expect(weld).to.be.ok()
			expect(weld.Part0).to.equal(root)
			expect(weld.Part1).to.equal(part)
		end
		expect(CollisionBlockerSystem.counts(state).puppets).to.equal(1)
	end)

	it("refuses a rig with no root", function()
		local state = CollisionBlockerSystem.new(false)
		local model = Instance.new("Model")
		model.Parent = Workspace
		table.insert(rigs, model)
		expect(CollisionBlockerSystem.addPuppet(state, model)).to.equal(false)
		expect(CollisionBlockerSystem.addSelf(state, model)).to.equal(false)
		expect(#model:GetChildren()).to.equal(0)
	end)

	it("keeps its offset when a root built while parked moves", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(0, 50000, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		root.CFrame = CFrame.new(10, 50, -10)
		local tops = 0
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(math.abs(part.Position.X - 10) < 0.01).to.equal(true)
			expect(math.abs(part.Position.Z + 10) < 0.01).to.equal(true)
			if math.abs(part.Position.Y - 50 - (C.TOP - C.RADIUS)) < 0.01 then
				tops += 1
			end
		end
		expect(tops).to.equal(1)
	end)

	it("destroys a puppet's capsule on despawn", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		CollisionBlockerSystem.remove(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(0)
		expect(state.puppets[model]).to.equal(nil)
		expect(state.solid[model]).to.equal(nil)
	end)

	it("despawn then spawn on the same model, or adding twice, leaves exactly one capsule", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.remove(state, model)
		CollisionBlockerSystem.addPuppet(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(3)
		CollisionBlockerSystem.addPuppet(state, model)
		expect(#capsuleParts(model, C.PUPPET_GROUP)).to.equal(3)
	end)

	it("flips solid only when crossing the band, writing CanCollide only on change", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(30, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(0)

		root.CFrame = CFrame.new(19, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(1)
		expect(state.solid[model]).to.be.ok()
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(part.CanCollide).to.equal(true)
		end

		root.CFrame = CFrame.new(21.5, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(1)

		root.CFrame = CFrame.new(23, 0, 0)
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		expect(state.writes).to.equal(2)
		expect(state.solid[model]).to.equal(nil)
		for _, part in capsuleParts(model, C.PUPPET_GROUP) do
			expect(part.CanCollide).to.equal(false)
		end
	end)

	it("checks the range at most ten times a second", function()
		local state = CollisionBlockerSystem.new(false)
		local model = rig(CFrame.new(10, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		CollisionBlockerSystem.step(state, 0.06, Vector3.zero)
		expect(state.writes).to.equal(0)
		CollisionBlockerSystem.step(state, 0.06, Vector3.zero)
		expect(state.writes).to.equal(1)
	end)

	it("gives a solid puppet its frame velocity, fresh on turning solid, zero after a teleport", function()
		local state = CollisionBlockerSystem.new(false)
		local model, root = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, model)
		root.CFrame = CFrame.new(6, 0, 0) -- moved while not solid: must not count once it turns solid
		CollisionBlockerSystem.updateRange(state, Vector3.zero)
		CollisionBlockerSystem.updateVelocities(state, 0.1)
		expect(root.AssemblyLinearVelocity.Magnitude < 1e-3).to.equal(true)

		root.CFrame = CFrame.new(7, 0, 0)
		CollisionBlockerSystem.updateVelocities(state, 0.1)
		expect((root.AssemblyLinearVelocity - Vector3.new(10, 0, 0)).Magnitude < 1e-3).to.equal(true)

		root.CFrame = CFrame.new(17, 0, 0) -- 100 studs/s: a teleport
		CollisionBlockerSystem.updateVelocities(state, 0.1)
		expect(root.AssemblyLinearVelocity.Magnitude).to.equal(0)
	end)

	it("builds the self-collider solid, massless, in the self group, and replaces it on respawn", function()
		local state = CollisionBlockerSystem.new(false)
		local first = rig(CFrame.new(0, 0, 0))
		expect(CollisionBlockerSystem.addSelf(state, first)).to.equal(true)
		local parts = capsuleParts(first, C.SELF_GROUP)
		expect(#parts).to.equal(3)
		for _, part in parts do
			expect(part.CanCollide).to.equal(true)
			expect(part.Massless).to.equal(true)
		end

		local second = rig(CFrame.new(0, 0, 0))
		CollisionBlockerSystem.addSelf(state, second)
		expect(#capsuleParts(first, C.SELF_GROUP)).to.equal(0)
		expect(#capsuleParts(second, C.SELF_GROUP)).to.equal(3)

		CollisionBlockerSystem.remove(state, second)
		expect(state.own).to.equal(nil)
		expect(#capsuleParts(second, C.SELF_GROUP)).to.equal(0)
	end)

	it("debug view shows existing and new capsules and hides them again", function()
		local state = CollisionBlockerSystem.new(false)
		local a = rig(CFrame.new(5, 0, 0))
		CollisionBlockerSystem.addPuppet(state, a)
		CollisionBlockerSystem.setDebug(state, true)
		local b = rig(CFrame.new(8, 0, 0))
		CollisionBlockerSystem.addPuppet(state, b)
		for _, model in { a, b } do
			for _, part in capsuleParts(model, C.PUPPET_GROUP) do
				expect(part.Transparency).to.equal(C.DEBUG_TRANSPARENCY)
				expect(part.Color).to.equal(C.PUPPET_COLOR)
			end
		end
		CollisionBlockerSystem.setDebug(state, false)
		for _, part in capsuleParts(a, C.PUPPET_GROUP) do
			expect(part.Transparency).to.equal(1)
		end
	end)

	it("clear removes every capsule", function()
		local state = CollisionBlockerSystem.new(false)
		local a = rig(CFrame.new(5, 0, 0))
		local me = rig(CFrame.new(0, 0, 0))
		CollisionBlockerSystem.addPuppet(state, a)
		CollisionBlockerSystem.addSelf(state, me)
		CollisionBlockerSystem.clear(state)
		expect(#capsuleParts(a, C.PUPPET_GROUP)).to.equal(0)
		expect(#capsuleParts(me, C.SELF_GROUP)).to.equal(0)
		expect(CollisionBlockerSystem.counts(state).puppets).to.equal(0)
		expect(state.own).to.equal(nil)
	end)
end
```

- [ ] **Step 2: Write the system**

```lua
--!strict
--[=[
	CollisionBlockerSystem (R6 spec 2026-10-08 §4, §5): the capsules.

	- Each other player's puppet gets a capsule (three primitive parts) welded into its anchored root
	  assembly, so the puppet's existing BulkMoveTo carries it: R6 writes no CFrames. It starts not solid.
	- The local rig gets the same capsule as its self-collider: solid, massless, welded to its root.
	- The connection is the spike's measured `puppet` mount: place the part at `root.CFrame * offset`,
	  unanchor it, WeldConstraint root → part, parent it into the rig. Placing first makes the weld's offset
	  exact wherever the root is (a pooled puppet parked far away included).
	- `step` checks the range RANGE_CHECK_HZ times a second with the buffer band and writes `CanCollide` only
	  on a flip; every call it gives each SOLID puppet's root its frame velocity, so contact pushes like a
	  moving body. A frame faster than MAX_CONTACT_SPEED is a teleport and writes zero.

	Parts are named `CollisionBlocker<Part>` / `CollisionSelf<Part>`, so they never match a rig part name the
	outfit tracker looks up.

	@class CollisionBlockerSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionShapeUtils = require(ReplicatedStorage.Shared.Features.Collision.Utils.CollisionShapeUtils)

export type Capsule = {
	rig: Model,
	root: BasePart,
	parts: { BasePart },
	solid: boolean,
	lastPosition: Vector3,
}

export type State = {
	puppets: { [Model]: Capsule },
	solid: { [Model]: Capsule }, -- the solid subset of `puppets`
	own: Capsule?,
	debug: boolean,
	writes: number, -- solid/not-solid flips so far
	sinceRangeCheck: number,
}

local CollisionBlockerSystem = {}

local ROOT_NAME = "HumanoidRootPart"
local SPECS = CollisionShapeUtils.capsule(CollisionConstants.RADIUS, CollisionConstants.BOTTOM, CollisionConstants.TOP)
local RANGE_INTERVAL = 1 / CollisionConstants.RANGE_CHECK_HZ

local function transparency(debug: boolean): number
	return if debug then CollisionConstants.DEBUG_TRANSPARENCY else 1
end

local function build(rig: Model, root: BasePart, isSelf: boolean, debug: boolean): Capsule
	local parts: { BasePart } = {}
	for _, spec in SPECS do
		local part = Instance.new("Part")
		part.Name = (if isSelf then "CollisionSelf" else "CollisionBlocker") .. spec.name
		part.Shape = spec.shape
		part.Size = spec.size
		part.CFrame = root.CFrame * spec.offset
		part.Anchored = false
		part.CanCollide = isSelf
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CustomPhysicalProperties = CollisionConstants.FRICTIONLESS
		part.CollisionGroup = if isSelf then CollisionConstants.SELF_GROUP else CollisionConstants.PUPPET_GROUP
		part.Color = if isSelf then CollisionConstants.SELF_COLOR else CollisionConstants.PUPPET_COLOR
		part.Transparency = transparency(debug)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = rig
		table.insert(parts, part)
	end
	return { rig = rig, root = root, parts = parts, solid = isSelf, lastPosition = root.Position }
end

local function destroy(capsule: Capsule)
	for _, part in capsule.parts do
		part:Destroy()
	end
end

--[=[
	@param debug boolean -- whether capsules start visible
	@return State
]=]
function CollisionBlockerSystem.new(debug: boolean): State
	return { puppets = {}, solid = {}, own = nil, debug = debug, writes = 0, sinceRangeCheck = 0 }
end

--[=[
	The rig's HumanoidRootPart, or nil.
	@param rig Model?
	@return BasePart?
]=]
function CollisionBlockerSystem.rootOf(rig: Model?): BasePart?
	local root = if rig ~= nil then rig:FindFirstChild(ROOT_NAME) else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

--[=[
	Removes the capsule of a puppet or of the own rig. Unknown rigs are a no-op.
	@param state State
	@param rig Model
]=]
function CollisionBlockerSystem.remove(state: State, rig: Model)
	local capsule = state.puppets[rig]
	if capsule ~= nil then
		destroy(capsule)
		state.puppets[rig] = nil
		state.solid[rig] = nil
	end
	local own = state.own
	if own ~= nil and own.rig == rig then
		destroy(own)
		state.own = nil
	end
end

--[=[
	Gives another player's puppet a capsule, not solid until the next range check. Replaces an existing one.
	@param state State
	@param rig Model
	@return boolean -- false when the rig has no root
]=]
function CollisionBlockerSystem.addPuppet(state: State, rig: Model): boolean
	CollisionBlockerSystem.remove(state, rig)
	local root = CollisionBlockerSystem.rootOf(rig)
	if root == nil then
		return false
	end
	state.puppets[rig] = build(rig, root, false, state.debug)
	return true
end

--[=[
	Gives the local rig its self-collider, replacing the previous rig's.
	@param state State
	@param rig Model
	@return boolean -- false when the rig has no root
]=]
function CollisionBlockerSystem.addSelf(state: State, rig: Model): boolean
	local root = CollisionBlockerSystem.rootOf(rig)
	if root == nil then
		return false
	end
	local own = state.own
	if own ~= nil then
		destroy(own)
	end
	state.own = build(rig, root, true, state.debug)
	return true
end

--[=[
	Flips each puppet's capsule solid or not by the range band, writing CanCollide only on a flip.
	@param state State
	@param origin Vector3 -- the local root's position
]=]
function CollisionBlockerSystem.updateRange(state: State, origin: Vector3)
	for rig, capsule in state.puppets do
		local offset = capsule.root.Position - origin
		local solid = CollisionShapeUtils.nextSolid(capsule.solid, offset:Dot(offset))
		if solid ~= capsule.solid then
			capsule.solid = solid
			for _, part in capsule.parts do
				part.CanCollide = solid
			end
			state.writes += 1
			if solid then
				capsule.lastPosition = capsule.root.Position
				state.solid[rig] = capsule
			else
				state.solid[rig] = nil
			end
		end
	end
end

--[=[
	Gives each solid puppet's root its velocity over the last frame (zero for a teleport).
	@param state State
	@param dt number
]=]
function CollisionBlockerSystem.updateVelocities(state: State, dt: number)
	if dt <= 0 then
		return
	end
	for _, capsule in state.solid do
		local position = capsule.root.Position
		local velocity = (position - capsule.lastPosition) / dt
		capsule.lastPosition = position
		capsule.root.AssemblyLinearVelocity = if velocity.Magnitude > CollisionConstants.MAX_CONTACT_SPEED
			then Vector3.zero
			else velocity
	end
end

--[=[
	One frame: the range check when its interval has passed, then contact velocities.
	@param state State
	@param dt number
	@param origin Vector3 -- the local root's position
]=]
function CollisionBlockerSystem.step(state: State, dt: number, origin: Vector3)
	state.sinceRangeCheck += dt
	if state.sinceRangeCheck >= RANGE_INTERVAL then
		state.sinceRangeCheck = 0
		CollisionBlockerSystem.updateRange(state, origin)
	end
	CollisionBlockerSystem.updateVelocities(state, dt)
end

--[=[
	Shows or hides every capsule (debug view). Capsules built later follow `state.debug`.
	@param state State
	@param on boolean
]=]
function CollisionBlockerSystem.setDebug(state: State, on: boolean)
	state.debug = on
	local value = transparency(on)
	for _, capsule in state.puppets do
		for _, part in capsule.parts do
			part.Transparency = value
		end
	end
	local own = state.own
	if own ~= nil then
		for _, part in own.parts do
			part.Transparency = value
		end
	end
end

--[=[
	Removes every capsule.
	@param state State
]=]
function CollisionBlockerSystem.clear(state: State)
	for _, capsule in state.puppets do
		destroy(capsule)
	end
	table.clear(state.puppets)
	table.clear(state.solid)
	local own = state.own
	if own ~= nil then
		destroy(own)
		state.own = nil
	end
end

--[=[
	@param state State
	@return { puppets: number, solid: number }
]=]
function CollisionBlockerSystem.counts(state: State): { puppets: number, solid: number }
	local puppets, solid = 0, 0
	for _ in state.puppets do
		puppets += 1
	end
	for _ in state.solid do
		solid += 1
	end
	return { puppets = puppets, solid = solid }
end

return CollisionBlockerSystem
```

- [ ] **Step 3: Run the local gate**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionBlockerSystem.luau src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionBlockerSystem.spec.luau
git commit -m "feat(collision): capsule blockers welded into puppets, range-gated, with contact velocity (R6)"
```

---

### Task 4: Client slide-off system

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionSlideOffSystem.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionSlideOffSystem.luau`

**Interfaces:**
- Consumes: `CollisionBlockerSystem.State`, `.new`, `.addPuppet`, `.updateRange` (Task 3). `CollisionShapeUtils.restingOn`, `.pushDirection`, `.slideOffVelocity` (Task 1).
- Produces: `CollisionSlideOffSystem.step(blockers: CollisionBlockerSystem.State, root: BasePart): boolean`. It is true when my feet rest on a solid puppet this frame (pushed or already moving off fast enough).

- [ ] **Step 1: Write the spec**

```lua
--!strict
--[=[
	Unit tests for CollisionSlideOffSystem (R6 spec 2026-10-08 §5 step 3): the push off a head, and the
	cases it leaves alone. "My root" is an anchored Part, so its velocity reads back as written.
]=]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)
local CollisionSlideOffSystem = require(script.Parent.CollisionSlideOffSystem)

return function()
	local C = CollisionConstants
	local HEAD = C.TOP - C.BOTTOM
	local instances

	beforeAll(function()
		for _, name in { C.PUPPET_GROUP, C.SELF_GROUP } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
	end)

	beforeEach(function()
		instances = {}
	end)

	afterEach(function()
		for _, instance in instances do
			instance:Destroy()
		end
	end)

	local function anchoredRoot(position)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CanCollide = false
		root.CFrame = CFrame.new(position)
		root.Parent = model
		model.Parent = Workspace
		table.insert(instances, model)
		return model, root
	end

	-- A solid puppet at `theirs` and my root at `mine` moving at `velocity`.
	local function setup(mine, theirs, velocity, solid)
		local state = CollisionBlockerSystem.new(false)
		local puppet = anchoredRoot(theirs)
		CollisionBlockerSystem.addPuppet(state, puppet)
		if solid then
			CollisionBlockerSystem.updateRange(state, mine)
		end
		local _, me = anchoredRoot(mine)
		me.AssemblyLinearVelocity = velocity
		return state, me
	end

	local function nearVector(a, b)
		return (a - b).Magnitude < 1e-3
	end

	it("pushes my feet off a head outward at the slide-off speed", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, -2, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(true)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(12, -2, 0))).to.equal(true)
	end)

	it("leaves a faster outward move alone", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(20, 0, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(true)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(20, 0, 0))).to.equal(true)
	end)

	it("ignores a player standing beside me", function()
		local state, me = setup(Vector3.new(1.5, 0, 0), Vector3.zero, Vector3.new(0, 0, -3), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, 0, -3))).to.equal(true)
	end)

	it("ignores me while rising", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, 5, 0), true)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, 5, 0))).to.equal(true)
	end)

	it("ignores a puppet that isn't solid", function()
		local state, me = setup(Vector3.new(1, HEAD, 0), Vector3.zero, Vector3.new(0, -2, 0), false)
		expect(CollisionSlideOffSystem.step(state, me)).to.equal(false)
		expect(nearVector(me.AssemblyLinearVelocity, Vector3.new(0, -2, 0))).to.equal(true)
	end)
end
```

- [ ] **Step 2: Write the system**

```lua
--!strict
--[=[
	CollisionSlideOffSystem (R6 spec 2026-10-08 §5 step 3): heads aren't standable.

	The Humanoid never treats a blocker as floor (the blocker groups don't collide with the rig's own
	parts) and blockers are frictionless, so without a push a dead-centre landing would sit on a head. While
	my feet rest on a SOLID puppet's head top, my outward horizontal speed is raised to SLIDE_OFF_SPEED (the
	CP7 spike's rule). Only the solid set is checked, which is typically 0–5 puppets. One push per frame.

	@class CollisionSlideOffSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionShapeUtils = require(ReplicatedStorage.Shared.Features.Collision.Utils.CollisionShapeUtils)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)

local CollisionSlideOffSystem = {}

--[=[
	Pushes `root` off the first solid puppet whose head its feet rest on.
	@param blockers CollisionBlockerSystem.State
	@param root BasePart -- the local rig's root
	@return boolean -- true when resting on a head this frame
]=]
function CollisionSlideOffSystem.step(blockers: CollisionBlockerSystem.State, root: BasePart): boolean
	local here = root.Position
	local velocity = root.AssemblyLinearVelocity
	for _, capsule in blockers.solid do
		local theirs = capsule.root.Position
		if CollisionShapeUtils.restingOn(here, velocity.Y, theirs) then
			local direction = CollisionShapeUtils.pushDirection(here, theirs, root.CFrame.LookVector)
			local pushed = CollisionShapeUtils.slideOffVelocity(velocity, direction)
			if pushed ~= nil then
				root.AssemblyLinearVelocity = pushed
			end
			return true
		end
	end
	return false
end

return CollisionSlideOffSystem
```

- [ ] **Step 3: Run the local gate**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionSlideOffSystem.luau src/ReplicatedStorage/Client/Features/Collision/Systems/CollisionSlideOffSystem.spec.luau
git commit -m "feat(collision): slide off heads (R6)"
```

---

### Task 5: Client service, module map and docs

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Collision/CollisionServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (one `EXEMPT_MODULES` row after `"ReplicatedStorage.Client.Features.Voice.VoiceServiceClient"`)
- Modify: `docs/project-structure.md` (regenerated by `module_map.py --write`)
- Modify: `docs/ROADMAP.md` (the Character replication row: the "R6 player collision" phrase)
- Modify: `docs/superpowers/specs/2026-09-22-character-replication-design.md` line 55 (the R6 build-phase row)

**Interfaces:**
- Consumes:
  - `ReplicationServiceClient.bodySpawned` / `.bodyDespawned` (`SignalTyped.Signal<Player, Model>`), `:getRig(player): Model?`, `:getLocalRig(): Model?`.
  - Task 3: `CollisionBlockerSystem.new`, `.addPuppet`, `.addSelf`, `.remove`, `.step`, `.setDebug`, `.clear`, `.counts`, `.rootOf`, `state.writes`.
  - Task 4: `CollisionSlideOffSystem.step`.
- Produces: `CollisionServiceClient` with `dependencies = { "ReplicationServiceClient" }` and `getState(): { puppets: number, solid: number, flipsPerSecond: number, pushesPerSecond: number, stepMs: number }`.

- [ ] **Step 1: Add the exemption row**

In `SpecRoots.luau`, directly after the `"ReplicatedStorage.Client.Features.Voice.VoiceServiceClient"` row:

```lua
	["ReplicatedStorage.Client.Features.Collision.CollisionServiceClient"] = "body-API/RunService shell (cores CollisionBlockerSystem and CollisionSlideOffSystem are specced)",
```

- [ ] **Step 2: Write the service**

```lua
--!strict
--[=[
	CollisionServiceClient (R6 spec 2026-10-08 §5): players are solid to each other.

	- Bodies come and go through ReplicationServiceClient's `bodySpawned` / `bodyDespawned`. Another
	  player's puppet gets a blocker; the local rig (every respawn) gets the self-collider. A pooled puppet
	  reused by another player is despawn → spawn, so a blocker never carries over.
	- Every PreSimulation: CollisionBlockerSystem.step (the range band at 10 Hz, contact velocities for the
	  solid set), then CollisionSlideOffSystem.step. Nothing runs without a local rig.
	- Workspace attribute `CollisionDebug = true` draws the capsules (read on change, never per frame).
	- F4: puppets, solid, flips and slide-off pushes in the last second, and the step's average ms.

	Spec-exempt shell (signals, RunService); its cores CollisionBlockerSystem and CollisionSlideOffSystem are
	specced. No server rules depend on it: each client stops only its own body.

	@class CollisionServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local ReplicationServiceClient = require(ReplicatedStorage.Client.Features.Replication.ReplicationServiceClient)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)
local CollisionSlideOffSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionSlideOffSystem)

type Window = { started: number, steps: number, stepSeconds: number, writesAtStart: number, pushes: number }
type Summary = { flipsPerSecond: number, pushesPerSecond: number, stepMs: number }

local log = Logger.new("CollisionServiceClient")
local janitor = Janitor.new()
local localPlayer = Players.LocalPlayer
local blockers = CollisionBlockerSystem.new(false)
local window: Window = { started = os.clock(), steps = 0, stepSeconds = 0, writesAtStart = 0, pushes = 0 }
local summary: Summary = { flipsPerSecond = 0, pushesPerSecond = 0, stepMs = 0 }

local function debugOn(): boolean
	return Workspace:GetAttribute(CollisionConstants.DEBUG_ATTRIBUTE) == true
end

local function onBodySpawned(player: Player, rig: Model)
	if player == localPlayer then
		CollisionBlockerSystem.addSelf(blockers, rig)
	else
		CollisionBlockerSystem.addPuppet(blockers, rig)
	end
end

local function onBodyDespawned(_player: Player, rig: Model)
	CollisionBlockerSystem.remove(blockers, rig)
end

local function step(dt: number)
	local started = os.clock()
	local root = CollisionBlockerSystem.rootOf(ReplicationServiceClient:getLocalRig())
	if root ~= nil then
		CollisionBlockerSystem.step(blockers, dt, root.Position)
		if CollisionSlideOffSystem.step(blockers, root) then
			window.pushes += 1
		end
	end
	window.steps += 1
	window.stepSeconds += os.clock() - started
	local elapsed = started - window.started
	if elapsed >= 1 then
		summary = {
			flipsPerSecond = (blockers.writes - window.writesAtStart) / elapsed,
			pushesPerSecond = window.pushes / elapsed,
			stepMs = window.stepSeconds / window.steps * 1000,
		}
		window = { started = started, steps = 0, stepSeconds = 0, writesAtStart = blockers.writes, pushes = 0 }
	end
end

export type CollisionServiceClient = {
	dependencies: { string },
	init: (self: CollisionServiceClient) -> (),
	start: (self: CollisionServiceClient) -> (),
	stop: (self: CollisionServiceClient) -> (),
	getState: (self: CollisionServiceClient) -> {
		puppets: number,
		solid: number,
		flipsPerSecond: number,
		pushesPerSecond: number,
		stepMs: number,
	},
}

local CollisionServiceClient: CollisionServiceClient = {
	dependencies = { "ReplicationServiceClient" },

	init = function(_self)
		log:debug("CollisionServiceClient initialized")
	end,

	start = function(_self)
		CollisionBlockerSystem.setDebug(blockers, debugOn())
		janitor:Add(
			Workspace:GetAttributeChangedSignal(CollisionConstants.DEBUG_ATTRIBUTE):Connect(function()
				CollisionBlockerSystem.setDebug(blockers, debugOn())
			end),
			"Disconnect"
		)
		janitor:Add(ReplicationServiceClient.bodySpawned:Connect(onBodySpawned), "Disconnect")
		janitor:Add(ReplicationServiceClient.bodyDespawned:Connect(onBodyDespawned), "Disconnect")
		for _, player in Players:GetPlayers() do
			local rig = ReplicationServiceClient:getRig(player)
			if rig ~= nil then
				onBodySpawned(player, rig)
			end
		end
		janitor:Add(RunService.PreSimulation:Connect(step), "Disconnect")
	end,

	stop = function(_self)
		janitor:Cleanup()
		CollisionBlockerSystem.clear(blockers)
	end,

	getState = function(_self)
		local counts = CollisionBlockerSystem.counts(blockers)
		return {
			puppets = counts.puppets,
			solid = counts.solid,
			flipsPerSecond = summary.flipsPerSecond,
			pushesPerSecond = summary.pushesPerSecond,
			stepMs = summary.stepMs,
		}
	end,
}

return CollisionServiceClient
```

- [ ] **Step 3: Regenerate the module map**

Run: `python3 scripts/python/module_map.py --write`
Expected: `docs/project-structure.md` gains the six Collision rows. Then `python3 scripts/python/module_map.py --check` exits 0.

- [ ] **Step 4: Update the docs**

In `docs/ROADMAP.md` (the Character replication row), replace the phrase `R6 player collision;` with:

```
R6 player collision (capsule blockers welded into puppets, solid within 20 studs, slide-off; the size table is the anti-cheat contract) — spec `docs/superpowers/specs/2026-10-08-character-replication-r6-collision-design.md`, plan `docs/superpowers/plans/2026-10-08-character-replication-r6-collision.md`;
```

In `docs/superpowers/specs/2026-09-22-character-replication-design.md`, replace the line

```
| R6 — player collision | Capsule blockers, server rules treating players as solid |
```

with

```
| R6 — player collision | Capsule blockers welded into puppets, solid within 20 studs, slide-off; the server registers the groups and the shared size table is the anti-cheat contract (R6 spec 2026-10-08, decision 3) |
```

- [ ] **Step 5: Run the local gate**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS, including the module map check.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Client/Features/Collision/CollisionServiceClient.luau src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md docs/ROADMAP.md docs/superpowers/specs/2026-09-22-character-replication-design.md
git commit -m "feat(collision): client service wiring blockers to the body API, module map and docs (R6)"
```

---

### Task 6: Verification (controller, with the developer)

This task is run by the controller, not an implementer subagent. It needs the developer to serve this worktree (`rojo serve` from `B:/Projects/venture-game-systems/.claude/worktrees/replication-collision`) and connect Studio. Never run `rojo` or `check.sh` in a tree the developer is serving, unless they allow it.

- [ ] **Step 1: TestEZ.** Set Workspace `RunTests = true`, Play, and read Output. Expected: the previous total (1928) plus the new specs, 0 failed.

- [ ] **Step 2: End check (spec §6).** In a solo Play session with the player standing still:
  1. Insert `docs/superpowers/plans/2026-10-08-character-replication-r6-collision/CollisionLoadProbe.client.luau` as a LocalScript under the local player's `PlayerScripts`, and keep it alive until it prints `R6PROBE done`.
  2. Read the `R6PROBE` lines. Pass bars, averaged over the two rounds:
     - busy: physics(on) − physics(off) ≤ 0.4 ms; step(on) ≤ 0.1 ms;
     - jitter: flips/s(on) = 0;
     - sweep: flips/s(on) ≤ 15;
     - idle: physics(on) − physics(off) within run-to-run noise (the off-round spread); step(on) ≤ 0.05 ms.
  3. A miss on any bar: stop, root-cause (systematic-debugging), fix, and re-run before Step 3.
  4. Record the table in the PR description.

- [ ] **Step 3: Two-player Studio checklist (developer, spec §8).**
  - Walk into each other head-on and at an angle: blocked, no trip, no fling.
  - Walk into a moving player: pushed aside.
  - Slide into each other: no FallingDown.
  - Jump onto a head: slid off, never stand.
  - Walk away past 22 studs, then come back: solid again at 20 (F4 → `CollisionServiceClient` solid count).
  - Respawn and rejoin: one capsule per body. `CollisionDebug = true` shows them in the right place.
  - Camera, clicks and tools are unaffected near other players. F4 → `CollisionServiceServer` shows `registered = true`.

- [ ] **Step 4: Push and open the PR** only when the developer says so. Base: `feature/module-layout` (#40). The description includes the end-check table and the checklist. Never merge before the developer verifies in Studio.
