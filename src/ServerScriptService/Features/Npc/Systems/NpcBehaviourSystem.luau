--!strict
--[=[
	NpcBehaviourSystem: one NPC's think — perception, the brain's decision, carrying the intent out through
	its mover, attacks, and its locomotion pose. NpcServiceServer owns the agents and calls `think` on each
	NPC's schedule (design: docs/superpowers/specs/2026-10-09-npc-design.md).

	Spec-exempt shell (Players, raycasts, Humanoids, animation); every decision is a specced rule module
	(NpcSenseRules, NpcBrainRules, NpcPathRules).

	@class NpcBehaviourSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local NpcServer = ServerScriptService.Features.Npc
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local NpcConstants = require(NpcServer.Data.NpcConstants)
local NpcTypes = require(NpcServer.Data.NpcTypes)
local NpcBrainRules = require(NpcServer.Rules.NpcBrainRules)
local NpcPathRules = require(NpcServer.Rules.NpcPathRules)
local NpcSenseRules = require(NpcServer.Rules.NpcSenseRules)
local NpcMoverSystem = require(NpcServer.Systems.NpcMoverSystem)
local AnimationServiceServer = require(ServerScriptService.Features.Animation.AnimationServiceServer)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)

type NpcDef = NpcTypes.NpcDef
type Intent = NpcTypes.Intent
export type AttackHandler = (npc: Model, target: Player) -> ()

-- One live NPC's state, owned by NpcServiceServer.
export type Agent = {
	id: number,
	model: Model,
	kind: string,
	def: NpcDef,
	baseDef: NpcDef, -- the registered def; `def` is it with setTuning's overrides
	humanoid: Humanoid,
	root: BasePart,
	mover: NpcMoverSystem.NpcMoverSystem,
	home: Vector3,
	patrol: { BasePart },
	patrolIndex: number,
	targetUserId: number?,
	lastSeenAt: number?,
	lastAttackAt: number,
	nextThinkAt: number,
	wanderPauseUntil: number,
	pose: NpcTypes.Pose?,
	poseHandle: AnimationPlayerSystem.PlayHandle?,
}

type Candidate = { id: number, position: Vector3, player: Player, character: Model, humanoid: Humanoid }

-- What a think needs from the service: the game's attack overrides and target filter, and a counter.
export type ThinkDeps = {
	attackHandlers: { [string]: AttackHandler },
	brains: { [string]: NpcTypes.Brain },
	targetFilter: ((player: Player) -> boolean)?,
	onAttack: () -> (),
}

local log = Logger.new("NpcBehaviourSystem")
local random = Random.new()

-- Players an NPC may target: a living character, not dead, passing the game's filter.
local function candidates(targetFilter: ((player: Player) -> boolean)?): { Candidate }
	local list: { Candidate } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if
			character ~= nil
			and humanoid ~= nil
			and humanoid.Health > 0
			and root ~= nil
			and root:IsA("BasePart")
			and not DeathServiceServer:isDead(player)
		then
			local filter = targetFilter
			if filter == nil or filter(player) then
				table.insert(list, {
					id = player.UserId,
					position = root.Position,
					player = player,
					character = character,
					humanoid = humanoid,
				})
			end
		end
	end
	return list
end

local function lineOfSight(agent: Agent, candidate: Candidate): boolean
	local origin = agent.root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { agent.model, candidate.character }
	return Workspace:Raycast(origin, candidate.position - origin, params) == nil
end

local function findCandidate(list: { Candidate }, userId: number?): Candidate?
	for _, candidate in list do
		if candidate.id == userId then
			return candidate
		end
	end
	return nil
end

local function updatePose(agent: Agent)
	local animations = agent.def.animations
	if animations == nil then
		return
	end
	local velocity = agent.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local pose: NpcTypes.Pose = NpcBrainRules.poseFor(speed, agent.def.walkSpeed)
	-- Annotated, and compared through a local: both keep the pose literal from widening to `string`.
	local unchanged = pose == agent.pose
	if unchanged then
		return
	end
	agent.pose = pose
	local previous = agent.poseHandle
	if previous ~= nil then
		previous:stop()
	end
	local id = if pose == "idle" then animations.idle elseif pose == "walk" then animations.walk else animations.run
	agent.poseHandle = if id ~= nil then AnimationServiceServer:playOnRig(agent.model, id) else nil
end

local function attack(agent: Agent, target: Candidate, now: number, deps: ThinkDeps)
	agent.mover:stop()
	if now - agent.lastAttackAt < agent.def.attackCooldown then
		return
	end
	agent.lastAttackAt = now
	deps.onAttack()
	local attackAnimation = if agent.def.animations ~= nil then agent.def.animations.attack else nil
	if attackAnimation ~= nil then
		AnimationServiceServer:playOnRig(agent.model, attackAnimation)
	end
	local handler = deps.attackHandlers[agent.kind]
	if handler == nil then
		DeathServiceServer:damage(target.humanoid, agent.def.attackDamage, { name = agent.kind })
		return
	end
	local ok, err = pcall(function()
		handler(agent.model, target.player)
	end)
	if not ok then
		log:error(`onAttack("{agent.kind}") errored: {err}`)
	end
end

local NpcBehaviourSystem = {}

--[=[
	One think for one NPC at `now` (os.clock).
]=]
function NpcBehaviourSystem.think(agent: Agent, now: number, deps: ThinkDeps)
	local def = agent.def
	local position = agent.root.Position
	local list = candidates(deps.targetFilter)

	-- Perception: a hostile NPC hunts what it sees (or still remembers); a timid one notes the nearest.
	local target: Candidate? = nil
	if def.attitude == "hostile" then
		local visible: { NpcSenseRules.Candidate } = {}
		for _, candidate in list do
			if
				NpcSenseRules.inSight(
					position,
					agent.root.CFrame.LookVector,
					candidate.position,
					def.sightRange,
					def.sightAngle
				) and lineOfSight(agent, candidate)
			then
				table.insert(visible, { id = candidate.id, position = candidate.position })
			end
		end
		local seen = NpcSenseRules.nearest(position, visible)
		if seen ~= nil then
			agent.targetUserId = seen
			agent.lastSeenAt = now
		elseif not NpcSenseRules.remembers(agent.lastSeenAt, now, def.loseSightTime) then
			agent.targetUserId = nil
		end
		target = findCandidate(list, agent.targetUserId)
	end
	local threat: { position: Vector3, distance: number }? = nil
	if def.attitude == "timid" then
		local points: { NpcSenseRules.Candidate } = {}
		for _, candidate in list do
			table.insert(points, { id = candidate.id, position = candidate.position })
		end
		local nearestId, distance = NpcSenseRules.nearest(position, points)
		local nearest = findCandidate(list, nearestId)
		if nearest ~= nil then
			threat = { position = nearest.position, distance = distance }
		end
	end

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
	elseif intent.kind == "flee" then
		agent.humanoid.WalkSpeed = def.runSpeed
		agent.mover:moveTo(NpcPathRules.fleeGoal(position, intent.from, def.fleeRange * 1.5), now)
	elseif intent.kind == "patrol" then
		agent.humanoid.WalkSpeed = def.walkSpeed
		local point = agent.patrol[agent.patrolIndex]
		local flat = Vector3.new(point.Position.X - position.X, 0, point.Position.Z - position.Z)
		if flat.Magnitude <= NpcConstants.REACHED_DISTANCE then
			agent.patrolIndex = NpcPathRules.nextPatrolIndex(agent.patrolIndex, #agent.patrol)
			point = agent.patrol[agent.patrolIndex]
		end
		agent.mover:moveTo(point.Position, now)
	elseif intent.kind == "wander" then
		agent.humanoid.WalkSpeed = def.walkSpeed
		if now >= agent.wanderPauseUntil then
			if agent.mover:goal() == nil then
				local goal =
					NpcPathRules.wanderGoal(agent.home, def.wanderRadius, random:NextNumber(), random:NextNumber())
				agent.mover:moveTo(goal, now)
			elseif agent.mover:reached() then
				agent.mover:stop()
				local pause = NpcConstants.WANDER_PAUSE
				agent.wanderPauseUntil = now + random:NextNumber(pause[1], pause[2])
			end
		end
	elseif agent.mover:goal() ~= nil then
		agent.mover:stop()
	end
	updatePose(agent)
end

return NpcBehaviourSystem
