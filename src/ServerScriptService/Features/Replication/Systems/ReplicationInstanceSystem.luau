--!strict
--[=[
	ReplicationInstanceSystem: the Instances the replication server owns (plan R2 Task 9) — the published rig
	template, the non-replicating focus container and per-player focus parts — and the spawn point. Kept
	apart so ReplicationServiceServer stays a small shell.

	Spec-exempt shell (Instances).

	@class ReplicationInstanceSystem
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ReplicationRigCheck = require(ServerScriptService.Features.Replication.Rules.ReplicationRigCheck)

local log = Logger.new("ReplicationInstanceSystem")

local ReplicationInstanceSystem = {}

ReplicationInstanceSystem.TEMPLATE_NAME = "CharacterRigTemplate"

-- The live map's spawn area, measured in the spike (CP1): used only when the place has no SpawnLocation.
local FALLBACK_SPAWN = Vector3.new(-1028, 80, -263)
local SPAWN_SCATTER = 8

--[=[
	Publishes `StarterPlayer.StarterCharacter`, scripts stripped, as `ReplicatedStorage.CharacterRigTemplate`
	for clients to clone (StarterCharacterScripts never reach a client-built rig; locomotion is bound by the
	client service). Returns nil when the place has no rig; the caller reports it and stays inert rather than
	taking the whole boot down.
]=]
function ReplicationInstanceSystem.publishRigTemplate(): Instance?
	local starter = StarterPlayer:FindFirstChild("StarterCharacter")
	if starter == nil or not starter:IsA("Model") then
		return nil
	end
	local existing = ReplicatedStorage:FindFirstChild(ReplicationInstanceSystem.TEMPLATE_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local template = starter:Clone()
	template.Name = ReplicationInstanceSystem.TEMPLATE_NAME
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local root = template:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		log:error("StarterCharacter has no HumanoidRootPart part: bodies cannot be built from it")
	else
		local loose = ReplicationRigCheck.unattachedParts(template, root)
		if #loose > 0 then
			log:error(
				`StarterCharacter has {#loose} unanchored part(s) not joined to HumanoidRootPart; they fall off every body at spawn. Fix the art: {ReplicationRigCheck.describe(
					template,
					loose
				)}`
			)
		end
	end
	template.Parent = ReplicatedStorage
	return template
end

--[=[
	A Camera never replicates, so focus parts under it stay server-only (spike CP2: no position leak). It
	sits in a Folder because a Camera directly under Workspace can be destroyed when CurrentCamera is
	reassigned.
]=]
function ReplicationInstanceSystem.createFocusHolder(): (Folder, Camera)
	local folder = Instance.new("Folder")
	folder.Name = "CharacterFocus"
	folder.Parent = Workspace
	local holder = Instance.new("Camera")
	holder.Name = "FocusHolder"
	holder.Parent = folder
	return folder, holder
end

-- One player's streaming focus (assign it to `player.ReplicationFocus`).
function ReplicationInstanceSystem.createFocus(holder: Camera, position: Vector3): Part
	local focus = Instance.new("Part")
	focus.Name = "Focus"
	focus.Anchored = true
	focus.CanCollide = false
	focus.CanQuery = false
	focus.CanTouch = false
	focus.Transparency = 1
	focus.Size = Vector3.one
	focus.Position = position
	focus.Parent = holder
	return focus
end

-- The SpawnLocation search walks the whole Workspace, so its result is cached (re-resolved once the part is gone).
local cachedSpawn: BasePart? = nil
local warnedFallback = false

local function findSpawn(): BasePart?
	local cached = cachedSpawn
	if cached ~= nil and cached:IsDescendantOf(Workspace) then
		return cached
	end
	local found = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	cachedSpawn = if found ~= nil and found:IsA("BasePart") then found else nil
	return cachedSpawn
end

function ReplicationInstanceSystem.spawnPoint(): Vector3
	local spawnLocation = findSpawn()
	if spawnLocation == nil and not warnedFallback then
		warnedFallback = true
		log:warn(
			`this place has no SpawnLocation: spawning at the fallback {FALLBACK_SPAWN}, which only suits the live map`
		)
	end
	local base = if spawnLocation ~= nil then spawnLocation.Position + Vector3.new(0, 4, 0) else FALLBACK_SPAWN
	local scatter =
		Vector3.new(math.random(-SPAWN_SCATTER, SPAWN_SCATTER), 0, math.random(-SPAWN_SCATTER, SPAWN_SCATTER))
	return base + scatter
end

return ReplicationInstanceSystem
