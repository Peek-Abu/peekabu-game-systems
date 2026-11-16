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
	  walk but never lingers in, the office's desks and hiding spots (OccupantSenseSystem.known, refreshed every
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
	  the jumpscare, lights out, then the throw: a catch that leaves a life knocks the player down for about a second
	  (Death's knockdown), the last life's catch kills them (out for the shift); every catch counts in Shift's review.
	- Doors: each think, before he senses, he opens the closed doors he is walking through, on his line of travel
	  (OfficeServiceServer:openDoorsNear, handed his heading: OccupantDoorRules.heading of his velocity, else his last
	  walk target; with neither he opens only a door he stands at, DOOR_CLOSE_REACH) and, when he opened one, stands still for a DOOR_BEAT_SECONDS (0.5 s)
	  beat (OccupantDoorRules); a catch is never held.
	- Escapes: a chased or stared-down player he stops tracking while they are still hidden fires `escaped`
	  (OccupantEscapeRules; the Hide and Squeak badge).
	- A freeze kind (Bramble): OccupantWatchSystem decides who watches it; while frozen its brain holds
	  (Senses.frozen: OccupantBrainRules.hold), it opens no door and its root never turns (no look-around, no jerk); on
	  the think after it unfreezes, the kid its head held becomes its chase target (Senses.lunge).
	  Harlow's kind has no freeze twist, so for him OccupantWatchSystem.freezeFor is nil and none of this runs.
	- Kind (the monster roster): when a shift's site is built and the shift runs, the kind is the map's roster pick
	  (OccupantRosterRules.kindForShift: OfficeServiceServer:map() and :seed(), so the same run gets the same kind;
	  Office → harlow, School → bramble at launch; a training run is always harlow). OccupantRigSystem builds that kind's
	  rig (stamping OccupantKind) and OccupantTuningFormulas takes its speeds.
	- Role: he exists only where the shift role runs (QueueServiceServer:runsRole); a hub-only server spawns no Harlow.

	Twin guard: OccupantRigSystem.build (before it builds) and `despawn` (after it removes the current rig) sweep away
	every other model tagged OccupantConstants.TAG (OccupantRigSystem.sweep, which warns "removed N stray manager
	rig(s)"): a shift transit whose cleanup errored (it runs guarded) must not leave a second, inactive Harlow
	standing in the world.

	Split: the brain shell (each think's senses, the door beat, tells, effects, escapes; the catch, Hide's witness, tuning,
	the per-frame watch and the noises he hears) is OccupantBrainSystem; what both know about him now (rig, kind, mind,
	shift, rolls, counters) is OccupantRunTracker.run. This file keeps his life (spawn, despawn, the shift, the heartbeat)
	and the service's API.

	Spec-exempt shell (Instances, raycasts, Players, signals); the decisions are the specced OccupantBrainRules (and
	its Work, Stare and Director rules), OccupantCatchRules, OccupantTuningFormulas and OccupantTellRules.

	@class OccupantServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantKindRegistry = require(OccupantShared.Data.OccupantKindRegistry)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantEvents = require(OccupantShared.Net.OccupantEvents)
local OccupantAnimationUtils = require(OccupantShared.Utils.OccupantAnimationUtils)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local NpcRegistry = require(ServerScriptService.Features.Npc.Data.NpcRegistry)
local OccupantBrainRules = require(OccupantServer.Rules.OccupantBrainRules)
local OccupantRosterRules = require(OccupantServer.Rules.OccupantRosterRules)
local OccupantMindUtils = require(OccupantServer.Utils.OccupantMindUtils)
local OccupantWorkRules = require(OccupantServer.Rules.OccupantWorkRules)
local OccupantStageRules = require(OccupantServer.Rules.OccupantStageRules)
local OccupantRunTracker = require(OccupantServer.State.OccupantRunTracker)
local OccupantStageSystem = require(OccupantServer.Systems.OccupantStageSystem)
local Sense = require(OccupantServer.Systems.OccupantSenseSystem)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)
local OccupantCatchSystem = require(OccupantServer.Systems.OccupantCatchSystem)
local OccupantEffectSystem = require(OccupantServer.Systems.OccupantEffectSystem)
local OccupantSeatSystem = require(OccupantServer.Systems.OccupantSeatSystem)
local OccupantWatchSystem = require(OccupantServer.Systems.OccupantWatchSystem)
local OccupantBrainSystem = require(OccupantServer.Systems.OccupantBrainSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

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

local log = Logger.new("OccupantServiceServer")

-- What is true now about him (OccupantRunTracker), shared with his brain (OccupantBrainSystem).
local run = OccupantRunTracker.run
local escaped = OccupantBrainSystem.escaped
local applyTuning, show, world = OccupantBrainSystem.applyTuning, OccupantBrainSystem.show, OccupantBrainSystem.world
local witness, brain, onCatch = OccupantBrainSystem.witness, OccupantBrainSystem.brain, OccupantBrainSystem.onCatch
local watch, onNoise = OccupantBrainSystem.watch, OccupantBrainSystem.onNoise
local spawning = false
local tuningElapsed = 0
local stoppers: { () -> () } = {}

local function despawn()
	local current = run.rig
	run.rig = nil
	run.mind = nil
	OccupantStageSystem.reset()
	run.holdUntil = 0
	run.lastGoal = nil
	run.pendingNoise = nil
	Sense.forget()
	-- A catch in the last seconds: the next shift must not show a stale deadline.
	OccupantCatchSystem.dropRehires()
	-- A hit in the last second: nobody stays down into the next shift.
	OccupantCatchSystem.standUpAll()
	if current ~= nil and current.model.Parent ~= nil then
		NpcServiceServer:despawn(current.model)
	end
	-- Guard: any other manager rig (a twin a past cleanup missed) goes too, with a warning as evidence.
	OccupantRigSystem.sweep()
end

-- Builds the shift's monster (its map's roster pick) for the running shift (yields while the rig is generated).
local function spawnMonster()
	if run.rig ~= nil or spawning then
		return
	end
	local parent = OfficeServiceServer:container()
	local points = OfficeServiceServer:route()
	if parent == nil or #points == 0 then
		log:warn("no shift container or patrol route: Harlow stays home")
		return
	end
	spawning = true
	local start = run.rng:NextInteger(1, #points)
	local direction = if run.rng:NextNumber() < 0.5 then -1 else 1
	local at = CFrame.new(points[start] + Vector3.new(0, OccupantConstants.SPAWN_HEIGHT, 0))
	local map = OfficeServiceServer:map()
	local chosen: OccupantKindRegistry.KindId =
		OccupantRosterRules.kindForShift(map, OfficeServiceServer:seed() or 0, ShiftServiceServer:isTraining())
	local ok, built = pcall(OccupantRigSystem.build, at, parent, chosen)
	spawning = false
	if not ok then
		log:error(`{chosen}'s rig failed to build: {tostring(built)}`)
		return
	end
	local state = run.shift
	if state == nil or state.phase ~= "running" or parent.Parent == nil then
		built.model:Destroy()
		return
	end
	run.place = Sense.layout(points)
	local fresh = OccupantBrainRules.newMind(start, direction, os.clock(), run.rng:NextNumber())
	run.rig = built
	run.currentKind = chosen
	run.mind = fresh
	run.holdUntil = 0
	run.lastGoal = nil
	run.pendingNoise = nil
	Sense.forget()
	built.model.Destroying:Connect(function()
		if run.rig == built then
			run.rig = nil
			run.mind = nil
			run.holdUntil = 0
			run.lastGoal = nil
		end
	end)
	run.counters.spawned += 1
	show(built, fresh, nil)
	applyTuning()
	log:info(
		`{chosen} clocks in ({map}) at route point {start}, walking {if direction > 0 then "forward" else "backward"}`
	)
end

local function onShift(state: ShiftTypes.ShiftState)
	local previous = run.shift
	run.shift = state
	if state.phase ~= "running" then
		despawn()
		return
	end
	if previous ~= nil and previous.phase == "running" and state.tier > previous.tier then
		OccupantEvents.packets.Flicker.sendToAll(true)
	end
	if run.rig == nil then
		spawnMonster()
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
	local now = os.clock()
	watch(now)
	-- A frozen freeze kind never turns (always false for Harlow).
	if not OccupantWatchSystem.frozen() then
		OccupantSeatSystem.look(run.rig, run.mind, now)
		OccupantSeatSystem.jerk(run.rig, run.mind, now)
	end
end

export type OccupantServiceServer = {
	dependencies: { string },
	escaped: SignalTyped.Signal<Player>,
	start: (self: OccupantServiceServer) -> (),
	stop: (self: OccupantServiceServer) -> (),
	getState: (self: OccupantServiceServer) -> { [string]: any },
	getHarlow: (self: OccupantServiceServer) -> Model?,
	getMind: (self: OccupantServiceServer) -> OccupantTypes.Mind?,
	_setRolls: (self: OccupantServiceServer, rolls: { number }?) -> (),
	summonToDesk: (self: OccupantServiceServer, player: Player) -> (boolean, string),
	forceTurn: (
		self: OccupantServiceServer,
		player: Player,
		kind: OccupantTypes.TurnKind | "auto"
	) -> (boolean, string),
	stage: (
		self: OccupantServiceServer,
		player: Player,
		action: OccupantStageRules.Action,
		target: Player?
	) -> (boolean, string),
	direct: (self: OccupantServiceServer, order: OccupantStageRules.Order) -> boolean,
	directed: (self: OccupantServiceServer) -> OccupantStageRules.Stage?,
}

local OccupantServiceServer: OccupantServiceServer = {
	escaped = escaped,
	dependencies = {
		"NpcServiceServer",
		"ShiftServiceServer",
		"OfficeServiceServer",
		"NoiseServiceServer",
		"DeathServiceServer",
		"RoundServiceServer",
		"ToastServiceServer",
		"HideServiceServer",
		"QueueServiceServer",
	},

	--[=[
		Gives the kind its brain, follows the shift, listens for noise and turns him while he looks around.
	]=]
	start = function(_self)
		if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			log:info("not a shift server: the Manager does not run here")
			return
		end
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, brain)
		HideServiceServer:setWitness(witness)
		-- The same witness for stealth (NpcServiceServer:conceal): he is never fooled by a plant he saw, or one he chases.
		NpcServiceServer:setWitness(OccupantConstants.NPC_KIND, function(npc: Model, player: Player): boolean
			local current = run.rig
			return current ~= nil and npc == current.model and witness(player)
		end)
		NpcServiceServer:onAttack(OccupantConstants.NPC_KIND, onCatch)
		-- The "watched" check for a freeze kind (idle while the rig is Harlow).
		OccupantWatchSystem.start({
			rig = function(): OccupantRigSystem.Rig?
				return run.rig
			end,
			mind = function(): OccupantTypes.Mind?
				return run.mind
			end,
			zone = function(): OccupantTypes.Zone?
				return world().zone
			end,
		})
		table.insert(stoppers, OccupantWatchSystem.stop)
		-- ~8 s of spectating before the respawn (spec §4); Shift's resolver respawns in the loading bay.
		DeathServiceServer:configure({ respawnDelay = OccupantConstants.SPECTATE_SECONDS })
		table.insert(stoppers, OccupantCatchSystem.watchRehires())
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
		run.shift = nil
		NpcServiceServer:setBrain(OccupantConstants.NPC_KIND, nil)
		HideServiceServer:setWitness(nil)
		NpcServiceServer:setWitness(OccupantConstants.NPC_KIND, nil)
		despawn()
	end,

	getHarlow = function(_self)
		return if run.rig ~= nil then run.rig.model else nil
	end,

	-- QA seam (live verification only): every think uses these rolls (OccupantTypes.Senses.rolls) until cleared.
	_setRolls = function(_self, rolls)
		run.fixedRolls = if rolls ~= nil then table.clone(rolls) else nil
	end,

	--[=[
		A developer's ambush repro (the `occupantwork` command, Admins only): sends him to the free desk nearest
		`player`, at least SUMMON_DISTANCE studs off, for a work break now. False and why when he cannot go.
	]=]
	summonToDesk = function(_self, player)
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local current, currentMind = run.rig, run.mind
		if current == nil or currentMind == nil or root == nil or not root:IsA("BasePart") then
			return false, "no shift is running, or you have no character"
		end
		local def = OccupantKindRegistry.get(run.currentKind)
		local blocks = if def ~= nil then def.blocks else nil
		if blocks ~= nil and not blocks.desks then
			return false, `{run.currentKind} never works at a desk`
		end
		local desks = Sense.known(current, os.clock(), true)
		local hiders = Sense.hiders(RoundServiceServer:participants())
		local nextMind, desk =
			OccupantWorkRules.summonNear(currentMind, desks, hiders, root.Position, os.clock(), blocks)
		run.mind = nextMind or currentMind
		return desk ~= nil, if desk ~= nil then `desk {desk.id}` else "no free desk that far from you"
	end,

	--[=[
		A developer's forced head-turn variant (the `occupantturn` command, Admins only; behaviours design §11.1):
		`kind` for his next head turn ("auto" clears it), started at once at `player` when he can see them. Applied on
		his next think. False and why when there is no Manager or no character.
	]=]
	forceTurn = function(_self, player, kind)
		local character = player.Character
		if run.rig == nil or run.mind == nil or character == nil then
			return false, "no shift is running, or you have no character"
		end
		run.pendingForce = { kind = kind, userId = player.UserId }
		return true, "queued"
	end,

	--[=[
		A filmmaker's staging (the `harlow` command, Admins only; OccupantStageRules): freeze, free, come or rush to
		`player`, here (moved to `player`, frozen), calm, or chase `target`. False and why when it cannot.
	]=]
	stage = function(_self, player, action, target)
		local current, currentMind = run.rig, run.mind
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if current == nil or currentMind == nil or root == nil or not root:IsA("BasePart") then
			return false, "no shift is running, or you have no character"
		end
		local ok, message, nextMind = OccupantStageSystem.command({
			rig = current,
			mind = currentMind,
			caller = root,
			callerHip = if humanoid ~= nil then humanoid.HipHeight else 2,
			action = action,
			target = target,
		})
		run.mind = nextMind or currentMind
		return ok, message
	end,

	-- A game system directs him (the tutorial's scripted pass). False when he is not here.
	direct = function(_self, order)
		local current = run.rig
		if current == nil then
			return false
		end
		OccupantStageSystem.direct(current, order)
		return true
	end,

	directed = function(_self)
		return OccupantStageSystem.current()
	end,

	getMind = function(_self)
		local current = run.mind
		return if current ~= nil then table.clone(current) else nil
	end,

	getState = function(_self)
		local current = run.mind
		return {
			present = run.rig ~= nil,
			mind = if current ~= nil then OccupantMindUtils.summary(current) else nil,
			desks = Sense.knownDesks(),
			hearing = NoiseServiceServer:getHearingScale(),
			counters = table.clone(run.counters),
			effects = OccupantEffectSystem.getState(),
			watch = OccupantWatchSystem.getState(),
		}
	end,
}

return OccupantServiceServer
