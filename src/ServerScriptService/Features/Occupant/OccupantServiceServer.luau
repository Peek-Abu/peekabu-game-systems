--!strict
--[=[
	OccupantServiceServer: Mr. Harlow (Cleanup Crew spec §4 "Mr. Harlow", §6.2 "Occupant"). He is the `harlow`
	NPC kind (NpcServiceServer) driven by this service's brain:

	- Life: when a shift starts running he is built (OccupantRigSystem) on a random point of the Office's
	  patrol route and walks the loop in a random direction; when it stops he is despawned. He lives in the
	  shift's container, so a reset removes him too.
	- Senses, gathered in the brain each think and handed to the pure OccupantBrainRules: each crew member's
	  position with one synchronous line-of-sight ray (Workspace:Raycast never yields; at most one ray per
	  crew member per 0.25 s think, the base's own cost), the latest noise he heard outside the loading bay
	  (NoiseServiceServer through NoiseRules and the hearing scale), the shift's break, the route, the rest
	  point and the safe loading bay.
	- Pacing: OccupantTuningFormulas turns the shift's tier and the crew size into his speeds (setTuning) and
	  his hearing scale (NoiseServiceServer:setHearingScale), refreshed every TUNING_INTERVAL; a tier rise
	  flickers every light (OccupantEvents.Flicker).
	- Tells: his mode and target as attributes (the client's heartbeat), a "?" / "!" cue and a speech bubble
	  (OccupantRigSystem); while he looks around he turns his root through a sweep. Placeholders; M3 replaces
	  them.
	- Catch: the kind's attack (onAttack) → OccupantCatchRules → OccupantCatchSystem: camera snap, lights out,
	  ragdoll launch; ~8 s spectating (Death's respawn delay); "Rehired." on the respawn in the loading bay; the
	  catch counts in Shift's review.

	Spec-exempt shell (Instances, raycasts, Players, signals); the decisions are the specced OccupantBrainRules,
	OccupantCatchRules, OccupantTuningFormulas and OccupantTellRules.

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
local Observers = require(ReplicatedStorage.Packages.Observers)
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
local OccupantCatchRules = require(OccupantServer.Rules.OccupantCatchRules)
local OccupantTuningFormulas = require(OccupantServer.Utils.OccupantTuningFormulas)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)
local OccupantCatchSystem = require(OccupantServer.Systems.OccupantCatchSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

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
-- UserIds caught this life: their next character gets the "Rehired." toast.
local rehire: { [number]: boolean } = {}
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
		if
			root ~= nil
			and humanoid ~= nil
			and humanoid.Health > 0
			and not DeathServiceServer:isDead(player)
			and not OccupantCatchSystem.isCatching(player.UserId)
		then
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

-- A noise: remembered for the next think if he hears it (not while resting or standing over a catch). A noise
-- inside the loading bay is dropped here, before it can replace an earlier valid one: `Senses.heard` carries
-- one point, so the one passed is the latest heard noise OUTSIDE the bay.
local function onNoise(noise: NoiseTypes.NoiseEvent)
	local current = rig
	local currentMind = mind
	if current == nil or currentMind == nil or currentMind.mode == "rest" or currentMind.mode == "catch" then
		return
	end
	if OccupantBrainRules.inZone(noise.position, zone) then
		return
	end
	local scale = NoiseServiceServer:getHearingScale()
	if NoiseRules.hears(current.root.Position, noise.position, noise.radius, scale) then
		pendingNoise = noise.position
		counters.heard += 1
	end
end

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

-- The kind's attack is the catch: re-checked on the server (OccupantCatchRules), then the sequence. Never yields.
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
		-- 3D, the same distance the brain measures.
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

local function despawn()
	local current = rig
	rig = nil
	mind = nil
	pendingNoise = nil
	lookBase = nil
	table.clear(rehire)
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
	local look = current.root.CFrame.LookVector
	local base: number = if lookBase ~= nil then lookBase else math.atan2(-look.X, -look.Z)
	lookBase = base
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
		"ToastServiceServer",
	},

	--[=[
		Gives the kind its brain, follows the shift, listens for noise and turns him while he looks around.
	]=]
	start = function(_self)
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, brain)
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
		OccupantCatchSystem.clear()
		table.clear(rehire)
		shift = nil
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
