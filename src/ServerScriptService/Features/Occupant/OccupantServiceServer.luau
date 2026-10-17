--!strict
--[=[
	OccupantServiceServer: Mr. Harlow (Cleanup Crew spec §4 "Mr. Harlow", §6.2 "Occupant"; the behaviour set,
	docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md). He is the `harlow` NPC kind
	(NpcServiceServer) driven by this service's brain:

	- Life: when a shift starts running he is built (OccupantRigSystem) on a random point of the Office's
	  patrol route and walks the loop in a random direction; when it stops he is despawned. He lives in the
	  shift's container, so a reset removes him too.
	- Senses, gathered in the brain each think and handed to the pure OccupantBrainRules: each crew member's
	  position with one synchronous line-of-sight ray (Workspace:Raycast never yields; at most one ray per
	  crew member per think, the base's own cost) and whether they hide (Hide: and whether he saw them go
	  in), the latest noise he heard outside the truck's box (NoiseServiceServer through NoiseRules and the
	  hearing scale), the shift's break, the route, the rest point, the safe truck box, the loading bay he may
	  walk but never lingers in, the office's desks and hiding spots (OccupantSenseSystem.furniture, refreshed every
	  FURNITURE_REFRESH), who hides where, the pacing (tier, crew size, overtime) and a few random rolls.
	- The brain's effects (OccupantEffectSystem): his body (OccupantSeatSystem: sitting at a desk, standing up, planted still at a spot,
	  let go), whether he knows a hider (Hide's `setSeen`), holding a hider's camping push-out while he is at their
	  spot (`hold`), and a catch of a found hider.
	- Hiding: he is Hide's witness (`setWitness`): a player who goes into a spot while he sees them (or while he
	  chases them) is "seen entering"; the brain stares them down. A catch drags them out first (`evict`).
	- Pacing: OccupantTuningFormulas turns the shift's tier and the crew size into his speeds (setTuning) and
	  his hearing scale (NoiseServiceServer:setHearingScale), refreshed every TUNING_INTERVAL; a tier rise
	  flickers every light (OccupantEvents.Flicker).
	- Tells: what he shows (OccupantTellRules.view: mode, target, phase, cue, face, gesture, tilt) as attributes
	  every think (OccupantRigSystem.present), and a speech bubble per cue (a paper memo; the line varies per cue,
	  OccupantFeedbackUtils.pickLine); the client voices and types it; while he looks around he turns his root.
	- Catch: the kind's attack (onAttack) or the brain's catch effect → OccupantCatchSystem.attempt (OccupantCatchRules):
	  the jumpscare, lights out, ragdoll launch; ~8 s spectating; the Rehired notice on the respawn in the loading bay;
	  the catch counts in Shift's review.

	Spec-exempt shell (Instances, raycasts, Players, signals); the decisions are the specced OccupantBrainRules (and
	its Work, Stare and Director rules), OccupantCatchRules, OccupantTuningFormulas and OccupantTellRules.

	@class OccupantServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Observers = require(ReplicatedStorage.Packages.Observers)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantEvents = require(OccupantShared.Net.OccupantEvents)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantAnimationUtils = require(OccupantShared.Utils.OccupantAnimationUtils)
local OccupantFeedbackUtils = require(OccupantShared.Utils.OccupantFeedbackUtils)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local NpcRegistry = require(ServerScriptService.Features.Npc.Data.NpcRegistry)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local OccupantBrainRules = require(OccupantServer.Rules.OccupantBrainRules)
local OccupantMindUtils = require(OccupantServer.Utils.OccupantMindUtils)
local OccupantWorkRules = require(OccupantServer.Rules.OccupantWorkRules)
local Sense = require(OccupantServer.Systems.OccupantSenseSystem)
local OccupantTuningFormulas = require(OccupantServer.Utils.OccupantTuningFormulas)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)
local OccupantCatchSystem = require(OccupantServer.Systems.OccupantCatchSystem)
local OccupantEffectSystem = require(OccupantServer.Systems.OccupantEffectSystem)
local OccupantSeatSystem = require(OccupantServer.Systems.OccupantSeatSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
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
		-- His own clips where uploaded (lurch walk, look-around as his standing pose), else the base ones.
		animations = OccupantAnimationUtils.poses(function(id: string): boolean
			return AnimationRegistry.get(id) ~= nil
		end),
		pathCosts = { [OccupantConstants.SAFE_ZONE_LABEL] = math.huge },
	})
end

-- How often the office's desks and hiding spots are re-read (the office rebuilds each shift; chairs attach with art).
local FURNITURE_REFRESH = 5

local log = Logger.new("OccupantServiceServer")

local rig: OccupantRigSystem.Rig? = nil
local mind: OccupantTypes.Mind? = nil
local spawning = false
local shift: ShiftTypes.ShiftState? = nil
local route: { Vector3 } = {}
local restPoint = Vector3.zero
local zone: OccupantTypes.Zone = { min = Vector3.zero, max = Vector3.zero }
local bay: OccupantTypes.Zone? = nil
local desks: { OccupantTypes.Desk } = {}
local spots: { OccupantTypes.Spot } = {}
local furnitureAt = -math.huge
local pendingNoise: Vector3? = nil
local tuningElapsed = 0
local rng = Random.new()
-- A QA seam (`_setRolls`): fixed rolls for the brain instead of random ones (nil = random).
local fixedRolls: { number }? = nil
local lastLine: string? = nil
local counters = { spawned = 0, heard = 0, chases = 0, catches = 0 }
-- UserIds caught this life: their next character gets the Rehired notice.
local rehire: { [number]: boolean } = {}
local stoppers: { () -> () } = {}

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

-- What he shows, and a line for a cue.
local function show(current: OccupantRigSystem.Rig, nextMind: OccupantTypes.Mind, cue: OccupantTypes.Cue?)
	OccupantRigSystem.present(current, OccupantTellRules.view(nextMind, os.clock()))
	local variants = if cue ~= nil then OccupantConstants.LINE_VARIANTS[cue] else nil
	local line = if variants ~= nil then OccupantFeedbackUtils.pickLine(variants, rng:NextNumber(), lastLine) else nil
	line = line or OccupantTellRules.lineFor(cue)
	if line ~= nil then
		lastLine = line
		OccupantRigSystem.say(current, line)
	end
end

-- Every crew member he could see this think, each with one line-of-sight ray from his head, and whether they hide
-- (and he saw them go in).
local function glimpses(current: OccupantRigSystem.Rig, sightRange: number): { OccupantTypes.Glimpse }
	local list = Sense.glimpses(current, sightRange, RoundServiceServer:participants(), function(player)
		return not DeathServiceServer:isDead(player) and not OccupantCatchSystem.isCatching(player.UserId)
	end)
	return Sense.markHidden(list)
end

local function world(): Sense.World
	return { resting = resting(), route = route, restPoint = restPoint, zone = zone, bay = bay }
end

-- Hide's witness: whether he sees `player` right now as they go into a spot (or is chasing them). Never yields.
local function witness(player: Player): boolean
	local current, currentMind = rig, mind
	local def = NpcRegistry.get(OccupantConstants.NPC_KIND)
	return current ~= nil
		and currentMind ~= nil
		and def ~= nil
		and Sense.witness(current, currentMind, def, world(), player)
end

-- The office's desks and hiding spots as he knows them, re-read every FURNITURE_REFRESH.
local function furniture(current: OccupantRigSystem.Rig, now: number)
	if now - furnitureAt < FURNITURE_REFRESH then
		return
	end
	furnitureAt = now
	desks, spots = Sense.furniture(HideServiceServer:spots(), current.humanoid.HipHeight + current.root.Size.Y / 2)
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
			text = OccupantFeedbackUtils.caughtText(player.DisplayName, OccupantConstants.SPECTATE_SECONDS),
			style = ShiftConstants.TOAST_STICKY,
			duration = 4,
		})
	end,
}

-- Catches `player` if the server's re-check allows (OccupantCatchSystem.attempt); `from` is the mind of the think that
-- asked (a catch from a sit-in or a stare keeps its pose); `found`: a hider he found at their spot (the brain's catch
-- effect), not a chase grab. Never yields.
local function catchPlayer(player: Player, from: OccupantTypes.Mind?, found: boolean)
	local current = rig
	local before = mind
	local state = shift
	if current == nil or before == nil or state == nil then
		return
	end
	local now = os.clock()
	local graceUntil = before.grace[player.UserId]
	local ok, reason = OccupantCatchSystem.attempt(current, player, {
		inGrace = graceUntil ~= nil and now < graceUntil,
		resting = state.stage == "break",
		zone = zone,
		-- A player he found in a hiding spot is in plain view to him (he knows where they are).
		inView = Sense.inView(glimpses(current, math.huge), player.UserId),
		found = found,
	}, catchHooks)
	if not ok then
		log:debug(`catch of {player.Name} refused: {reason or "?"}`)
		return
	end
	local nextMind = OccupantBrainRules.caught(before, player.UserId, now, from)
	mind = nextMind
	counters.catches += 1
	-- The catch line comes from OccupantCatchSystem; this clears the "!" and shows the catch (face, tilt).
	show(current, nextMind, nil)
end

-- The kind's attack is the catch. Never yields.
local function onCatch(npc: Model, player: Player)
	local current = rig
	if current ~= nil and npc == current.model then
		catchPlayer(player, mind, false)
	end
end

-- The `harlow` brain: senses → OccupantBrainRules.step → intent (and effects). Never yields.
local function brain(def: NpcTypes.NpcDef, context: NpcTypes.BrainContext, npc: Model): NpcTypes.Intent?
	local current = rig
	local before = mind
	local state = shift
	if current == nil or before == nil or state == nil or npc ~= current.model then
		return { kind = "idle" }
	end
	furniture(current, context.now)
	local participants = RoundServiceServer:participants()
	local senses = Sense.senses(current, def, context.now, glimpses(current, Sense.rayRange(def.sightRange)), world())
	senses.position = context.position
	senses.heard = pendingNoise
	senses.rolls = fixedRolls or { rng:NextNumber(), rng:NextNumber(), rng:NextNumber(), rng:NextNumber() }
	senses.desks = desks
	senses.spots = spots
	senses.hiders = Sense.hiders(participants)
	senses.pacing = { tier = state.tier, solo = #participants <= 1, overtime = state.stage == "overtime" }
	pendingNoise = nil
	local result = OccupantBrainRules.step(before, senses)
	mind = result.mind
	if result.mind.mode == "chase" and before.mode ~= "chase" then
		counters.chases += 1
	end
	show(current, result.mind, result.cue)
	-- After the mind is stored, so a catch builds on it.
	local effects = result.effects
	if effects ~= nil then
		OccupantEffectSystem.apply(current, effects, function(player: Player)
			catchPlayer(player, before, true)
		end)
	end
	return result.intent
end

-- A noise: remembered for the next think if he hears it (not while resting or standing over a catch). A noise
-- inside the truck's box is dropped here, before it can replace an earlier valid one: `Senses.heard` carries
-- one point, so the one passed is the latest heard noise OUTSIDE the box.
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

local function despawn()
	local current = rig
	rig = nil
	mind = nil
	pendingNoise = nil
	furnitureAt = -math.huge
	-- A catch in the last seconds: the next shift must not show a stale deadline.
	for userId in rehire do
		OccupantCatchSystem.clearDeadline(userId)
	end
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
	local bayMin, bayMax = OfficeServiceServer:loadingBay()
	bay = { min = bayMin, max = bayMax }
	local fresh = OccupantBrainRules.newMind(start, direction, os.clock(), rng:NextNumber())
	rig = built
	mind = fresh
	pendingNoise = nil
	furnitureAt = -math.huge
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

-- Per frame: turning while he looks around (never while his body is anchored); tuning every TUNING_INTERVAL.
local function onHeartbeat(deltaTime: number)
	tuningElapsed += deltaTime
	if tuningElapsed >= OccupantConstants.TUNING_INTERVAL then
		tuningElapsed = 0
		applyTuning()
	end
	OccupantSeatSystem.look(rig, mind, os.clock())
end

export type OccupantServiceServer = {
	dependencies: { string },
	start: (self: OccupantServiceServer) -> (),
	stop: (self: OccupantServiceServer) -> (),
	getState: (self: OccupantServiceServer) -> { [string]: any },
	getHarlow: (self: OccupantServiceServer) -> Model?,
	getMind: (self: OccupantServiceServer) -> OccupantTypes.Mind?,
	_setRolls: (self: OccupantServiceServer, rolls: { number }?) -> (),
	summonToDesk: (self: OccupantServiceServer, player: Player) -> (boolean, string),
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
		"HideServiceServer",
	},

	--[=[
		Gives the kind its brain, follows the shift, listens for noise and turns him while he looks around.
	]=]
	start = function(_self)
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, brain)
		HideServiceServer:setWitness(witness)
		NpcServiceServer:onAttack(OccupantConstants.NPC_KIND, onCatch)
		-- ~8 s of spectating before the respawn (spec §4); Shift's resolver respawns in the loading bay.
		DeathServiceServer:configure({ respawnDelay = OccupantConstants.SPECTATE_SECONDS })
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, _character: Model)
				if rehire[player.UserId] then
					rehire[player.UserId] = nil
					OccupantCatchSystem.rehired(player)
				end
				return nil
			end)
		)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			rehire[player.UserId] = nil
		end)
		local changed = ShiftServiceServer.changed:Connect(onShift)
		local noises = NoiseServiceServer.made:Connect(onNoise)
		local heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
		table.insert(stoppers, function()
			leaving:Disconnect()
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
		shift = nil
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, nil)
		HideServiceServer:setWitness(nil)
		despawn()
	end,

	getHarlow = function(_self)
		return if rig ~= nil then rig.model else nil
	end,

	-- QA seam (live verification only): every think uses these rolls (OccupantTypes.Senses.rolls) until cleared.
	_setRolls = function(_self, rolls)
		fixedRolls = if rolls ~= nil then table.clone(rolls) else nil
	end,

	--[=[
		A developer's ambush repro (the `occupantwork` command, Admins only): sends him to the free desk nearest
		`player`, at least SUMMON_DISTANCE studs off, for a work break now. False and why when he cannot go.
	]=]
	summonToDesk = function(_self, player)
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local current, currentMind = rig, mind
		if current == nil or currentMind == nil or root == nil or not root:IsA("BasePart") then
			return false, "no shift is running, or you have no character"
		end
		furnitureAt = -math.huge
		furniture(current, os.clock())
		local hiders = Sense.hiders(RoundServiceServer:participants())
		local nextMind, desk = OccupantWorkRules.summonNear(currentMind, desks, hiders, root.Position, os.clock())
		mind = nextMind or currentMind
		return desk ~= nil, if desk ~= nil then `desk {desk.id}` else "no free desk that far from you"
	end,

	getMind = function(_self)
		local current = mind
		return if current ~= nil then table.clone(current) else nil
	end,

	getState = function(_self)
		local current = mind
		return {
			present = rig ~= nil,
			mind = if current ~= nil then OccupantMindUtils.summary(current) else nil,
			desks = #desks,
			hearing = NoiseServiceServer:getHearingScale(),
			counters = table.clone(counters),
			effects = OccupantEffectSystem.getState(),
		}
	end,
}

return OccupantServiceServer
