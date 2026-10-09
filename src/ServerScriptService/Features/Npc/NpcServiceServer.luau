--!strict
--[=[
	NpcServiceServer: server-owned NPCs with a small behaviour layer (design:
	docs/superpowers/specs/2026-10-09-npc-design.md).

	- `spawn(kind, cframe)` clones the kind's template from ServerStorage.Assets.Npcs; any model tagged
	  `Npc` with a registered `NpcKind` is adopted the same way. The root's network owner is the server and
	  DeathServiceServer tracks the model (ragdoll, `humanoidDied`).
	- Each NPC thinks every THINK_INTERVAL (staggered) through NpcBehaviourSystem: perception
	  (NpcSenseRules + one line-of-sight ray), NpcBrainRules.decide, then the intent through its
	  NpcMoverSystem.
	- Attacks use the kind's cooldown and damage through DeathServiceServer:damage (credited to the kind),
	  unless the game registered `onAttack(kind, fn)`.
	- Poses play through AnimationServiceServer:playOnRig from the kind's `animations`.

	Spec-exempt shell (Instances, physics, raycasts, signals); the decisions are the specced NpcRegistry,
	NpcSenseRules, NpcBrainRules, NpcPathRules and NpcRosterTracker.

	@class NpcServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local NpcServer = ServerScriptService.Features.Npc
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)
local NpcConstants = require(NpcServer.Data.NpcConstants)
local NpcRegistry = require(NpcServer.Data.NpcRegistry)
local NpcTypes = require(NpcServer.Data.NpcTypes)
local NpcRosterTracker = require(NpcServer.State.NpcRosterTracker)
local NpcBehaviourSystem = require(NpcServer.Systems.NpcBehaviourSystem)
local NpcMoverSystem = require(NpcServer.Systems.NpcMoverSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)

type NpcDef = NpcTypes.NpcDef

type Agent = NpcBehaviourSystem.Agent
type AttackHandler = NpcBehaviourSystem.AttackHandler

local log = Logger.new("NpcServiceServer")

local spawned: SignalTyped.Signal<Model, string> = SignalTyped.new()
local died: SignalTyped.Signal<Model, string, DeathTypes.DeathInfo> = SignalTyped.new()

local roster = NpcRosterTracker.new()
local agents: { [number]: Agent } = {}
local attackHandlers: { [string]: AttackHandler } = {}
local random = Random.new()
local counters = { spawned = 0, died = 0, attacks = 0 }
local stoppers: { () -> () } = {}

local thinkDeps: NpcBehaviourSystem.ThinkDeps = {
	attackHandlers = attackHandlers,
	targetFilter = nil,
	onAttack = function()
		counters.attacks += 1
	end,
}

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function patrolPoints(model: Model): { BasePart }
	local points: { BasePart } = {}
	local folderName = model:GetAttribute(NpcConstants.PATROL_ATTRIBUTE)
	if type(folderName) ~= "string" then
		return points
	end
	local folder = Workspace:FindFirstChild(folderName, true)
	if folder == nil then
		log:warn(`{model:GetFullName()}: patrol folder "{folderName}" not found`)
		return points
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	return points
end

local function removeAgent(model: Model)
	local id = roster:idOf(model)
	if id == nil then
		return
	end
	roster:remove(id)
	local agent = agents[id]
	agents[id] = nil
	if agent ~= nil then
		agent.mover:destroy()
		local handle = agent.poseHandle
		if handle ~= nil then
			handle:stop()
		end
	end
end

-- Adopts a tagged model; returns its cleanup, or nil when it is not a valid NPC.
local function adopt(instance: Instance): (() -> ())?
	if not instance:IsA("Model") then
		return nil
	end
	local model = instance
	local kind = model:GetAttribute(NpcConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then NpcRegistry.get(kind) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	if type(kind) ~= "string" or def == nil or humanoid == nil or root == nil then
		log:warn(`{model:GetFullName()} is tagged {NpcConstants.TAG} but has no registered kind, Humanoid or root`)
		return nil
	end
	if not root.Anchored then
		-- The server owns NPC physics; a client may never claim it.
		local ok, err = pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if not ok then
			log:warn(`{model.Name}: could not take network ownership: {err}`)
		end
	end
	humanoid.WalkSpeed = def.walkSpeed
	DeathServiceServer:track(model)
	local id = roster:add(model, kind)
	agents[id] = {
		id = id,
		model = model,
		kind = kind,
		def = def,
		humanoid = humanoid,
		root = root,
		mover = NpcMoverSystem.new(humanoid, root),
		home = root.Position,
		patrol = patrolPoints(model),
		patrolIndex = 1,
		targetUserId = nil,
		lastSeenAt = nil,
		lastAttackAt = -math.huge,
		-- Staggered so a crowd does not think on the same frame.
		nextThinkAt = os.clock() + random:NextNumber(0, NpcConstants.THINK_INTERVAL),
		wanderPauseUntil = 0,
		pose = nil,
		poseHandle = nil,
	}
	counters.spawned += 1
	spawned:Fire(model, kind)
	return function()
		removeAgent(model)
	end
end

local function templateFolder(): Instance?
	local root = ServerStorage:FindFirstChild(NpcConstants.TEMPLATE_ROOT)
	return if root ~= nil then root:FindFirstChild(NpcConstants.TEMPLATE_FOLDER) else nil
end

local function workspaceFolder(): Folder
	local existing = Workspace:FindFirstChild(NpcConstants.WORKSPACE_FOLDER)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = NpcConstants.WORKSPACE_FOLDER
	folder.Parent = Workspace
	return folder
end

export type NpcServiceServer = {
	dependencies: { string },
	spawned: SignalTyped.Signal<Model, string>,
	died: SignalTyped.Signal<Model, string, DeathTypes.DeathInfo>,

	start: (self: NpcServiceServer) -> (),
	stop: (self: NpcServiceServer) -> (),
	getState: (self: NpcServiceServer) -> { [string]: any },

	spawn: (self: NpcServiceServer, kind: string, cframe: CFrame) -> (Model?, string?),
	despawn: (self: NpcServiceServer, npc: Model) -> (),
	clear: (self: NpcServiceServer, kind: string?) -> number,
	kindOf: (self: NpcServiceServer, npc: Model) -> string?,
	list: (self: NpcServiceServer, kind: string?) -> { Model },
	onAttack: (self: NpcServiceServer, kind: string, handler: AttackHandler) -> (),
	setTargetFilter: (self: NpcServiceServer, filter: ((player: Player) -> boolean)?) -> (),
	setTarget: (self: NpcServiceServer, npc: Model, player: Player?) -> boolean,
}

local NpcServiceServer: NpcServiceServer = {
	dependencies = { "AnimationServiceServer", "DeathServiceServer" },
	spawned = spawned,
	died = died,

	--[=[
		Adopts tagged NPCs, runs the think loop, and cleans up the dead after their corpse time.
	]=]
	start = function(_self)
		table.insert(stoppers, Observers.observeTag(NpcConstants.TAG, adopt))

		local deaths = DeathServiceServer.humanoidDied:Connect(function(model: Model, info: DeathTypes.DeathInfo)
			local id = roster:idOf(model)
			local agent = if id ~= nil then agents[id] else nil
			if agent == nil then
				return
			end
			counters.died += 1
			removeAgent(model)
			died:Fire(model, agent.kind, info)
			task.delay(agent.def.corpseTime, function()
				if model.Parent ~= nil then
					model:Destroy()
				end
			end)
		end)
		table.insert(stoppers, function()
			deaths:Disconnect()
		end)

		local heartbeat = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			for _, agent in agents do
				if agent.humanoid.Health > 0 then
					agent.mover:step()
					if now >= agent.nextThinkAt then
						agent.nextThinkAt = now + NpcConstants.THINK_INTERVAL
						local ok, err = pcall(function()
							NpcBehaviourSystem.think(agent, now, thinkDeps)
						end)
						if not ok then
							log:error(`NPC {agent.model.Name} think failed: {err}`)
						end
					end
				end
			end
		end)
		table.insert(stoppers, function()
			heartbeat:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Spawns a registered kind from its template (ServerStorage.Assets.Npcs.<template>) at `cframe`.
		Nil plus a reason when the kind or its template is missing.
	]=]
	spawn = function(_self, kind, cframe)
		local def = NpcRegistry.get(kind)
		if def == nil then
			return nil, `unknown npc kind "{kind}"`
		end
		local templateName = def.template
		local folder = templateFolder()
		local template = if folder ~= nil and templateName ~= nil then folder:FindFirstChild(templateName) else nil
		if template == nil or not template:IsA("Model") then
			return nil,
				`no template "{tostring(templateName)}" in ServerStorage.{NpcConstants.TEMPLATE_ROOT}.{NpcConstants.TEMPLATE_FOLDER}`
		end
		local model = template:Clone()
		model:PivotTo(cframe)
		model:SetAttribute(NpcConstants.KIND_ATTRIBUTE, kind)
		CollectionService:AddTag(model, NpcConstants.TAG)
		model.Parent = workspaceFolder()
		return model, nil
	end,

	despawn = function(_self, npc)
		removeAgent(npc)
		npc:Destroy()
	end,

	--[=[
		Removes every NPC (or every NPC of one kind). Returns how many.
	]=]
	clear = function(self, kind)
		local removed = 0
		for _, model in self:list(kind) do
			self:despawn(model)
			removed += 1
		end
		return removed
	end,

	kindOf = function(_self, npc)
		local id = roster:idOf(npc)
		local entry = if id ~= nil then roster:get(id) else nil
		return if entry ~= nil then entry.kind else nil
	end,

	list = function(_self, kind)
		local models: { Model } = {}
		for _, id in roster:ids() do
			local entry = roster:get(id)
			if entry ~= nil and (kind == nil or entry.kind == kind) then
				table.insert(models, entry.model)
			end
		end
		return models
	end,

	--[=[
		Replaces the kind's default attack (damage through Death) with a game's own (a grab, a jumpscare).
	]=]
	onAttack = function(_self, kind, handler)
		assert(NpcRegistry.has(kind), `onAttack: "{kind}" is not a registered npc kind`)
		attackHandlers[kind] = handler
	end,

	--[=[
		Limits who NPCs may target (e.g. alive round participants). Nil allows every living player.
	]=]
	setTargetFilter = function(_self, filter)
		thinkDeps.targetFilter = filter
	end,

	--[=[
		Points an NPC at a player as if it had just seen them (a noise, a trap); nil makes it forget.
		The NPC still loses them after loseSightTime without seeing them.
	]=]
	setTarget = function(_self, npc, player)
		local id = roster:idOf(npc)
		local agent = if id ~= nil then agents[id] else nil
		if agent == nil then
			return false
		end
		agent.targetUserId = if player ~= nil then player.UserId else nil
		agent.lastSeenAt = if player ~= nil then os.clock() else nil
		return true
	end,

	getState = function(_self)
		local byKind: { [string]: number } = {}
		for _, kind in NpcRegistry.kinds() do
			byKind[kind] = roster:countOf(kind)
		end
		return { alive = roster:count(), byKind = byKind, counters = table.clone(counters) }
	end,
}

return NpcServiceServer
