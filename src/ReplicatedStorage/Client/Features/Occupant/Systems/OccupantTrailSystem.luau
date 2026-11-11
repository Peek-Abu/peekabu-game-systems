--!strict
--[=[
	OccupantTrailSystem: loose green feathers where a freeze kind moved while nobody watched it (Bramble; the freeze
	variants note: its movement is never invisible, look back and the trail shows where it went and how close it got).

	Every FEATHER_INTERVAL, for each tagged Occupant rig whose kind has the trail twist: while it is not frozen
	(the server's FROZEN_ATTRIBUTE, OccupantWatchSystem) and it has moved FEATHER_SPACING flat studs since the last
	feather, a feather is laid flat on the floor under it (a ray down that skips characters and the rig) at a random
	yaw. Each feather fades out over FEATHER_FADE_SECONDS and is then removed; at most FEATHER_MAX lie about (the oldest
	goes first). Client-local: each client lays its own (the same positions, near enough), nothing replicates.
	Harlow's kind has no trail.

	`shouldDrop` and `feather` are specced; the rest is a RunService/raycast/tween shell.

	@class OccupantTrailSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

-- A loose feather: long, narrow and flat.
local FEATHER_SIZE = Vector3.new(0.45, 0.05, 1.3)
-- How far below the root the floor ray looks.
local FLOOR_REACH = 12

local connection: RBXScriptConnection? = nil
local folder: Folder? = nil
-- Where each rig last laid a feather (or stood while frozen).
local lastAt: { [Model]: Vector3 } = {}
local laid: { BasePart } = {}
local rng = Random.new()
local count = 0

local OccupantTrailSystem = {}

--[=[
	Whether a rig at `position` lays a feather: it moved FEATHER_SPACING flat studs since `last` (never without a last
	point: the first check only remembers where it stands).
]=]
function OccupantTrailSystem.shouldDrop(last: Vector3?, position: Vector3): boolean
	if last == nil then
		return false
	end
	local flat = Vector3.new(position.X - last.X, 0, position.Z - last.Z)
	return flat.Magnitude >= OccupantConstants.FEATHER_SPACING
end

--[=[
	A feather lying flat at `position` turned `yaw` radians (anchored, never collides, touched or hit by a ray, casts no
	shadow), not yet parented.
]=]
function OccupantTrailSystem.feather(position: Vector3, yaw: number): Part
	local part = Instance.new("Part")
	part.Name = "Feather"
	part.Size = FEATHER_SIZE
	part.CFrame = CFrame.new(position + Vector3.new(0, FEATHER_SIZE.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
	part.Color = OccupantConstants.FEATHER_COLOR
	part.Material = Enum.Material.Fabric
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function trails(model: Model): boolean
	local kind = OccupantKindRegistry.get(OccupantKindRegistry.kindOf(model))
	local twist = if kind ~= nil then kind.freeze else nil
	return twist ~= nil and twist.trail
end

local function container(): Folder
	local current = folder
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local made = Instance.new("Folder")
	made.Name = "OccupantFeathers"
	made.Parent = Workspace
	folder = made
	return made
end

-- The floor under `root` (a ray down that skips every character and the rig), else under its feet.
local function floorUnder(model: Model, root: BasePart): Vector3
	local exclude: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -FLOOR_REACH, 0), params)
	if hit ~= nil then
		return hit.Position
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
end

local function lay(position: Vector3)
	local part = OccupantTrailSystem.feather(position, rng:NextNumber() * math.pi * 2)
	part.Parent = container()
	table.insert(laid, part)
	count += 1
	while #laid > OccupantConstants.FEATHER_MAX do
		local oldest = table.remove(laid, 1)
		if oldest ~= nil then
			oldest:Destroy()
		end
	end
	local fade = TweenService:Create(
		part,
		TweenInfo.new(OccupantConstants.FEATHER_FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	)
	fade.Completed:Connect(function()
		local index = table.find(laid, part)
		if index ~= nil then
			table.remove(laid, index)
		end
		part:Destroy()
	end)
	fade:Play()
end

local function step()
	for model in lastAt do
		if model.Parent == nil then
			lastAt[model] = nil
		end
	end
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if not instance:IsA("Model") or not trails(instance) then
			continue
		end
		local root = instance:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local position = root.Position
		local frozen = instance:GetAttribute(OccupantConstants.FROZEN_ATTRIBUTE) == true
		local last: Vector3? = lastAt[instance]
		if not frozen and OccupantTrailSystem.shouldDrop(last, position) then
			lay(floorUnder(instance, root))
			lastAt[instance] = position
		elseif frozen or last == nil then
			lastAt[instance] = position
		end
	end
end

function OccupantTrailSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < OccupantConstants.FEATHER_INTERVAL then
			return
		end
		elapsed = 0
		step()
	end)
end

-- Stops the trail and removes every feather.
function OccupantTrailSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
	table.clear(lastAt)
	table.clear(laid)
	local made = folder
	folder = nil
	if made ~= nil then
		made:Destroy()
	end
end

function OccupantTrailSystem.getState(): { laid: number, lying: number }
	return { laid = count, lying = #laid }
end

return OccupantTrailSystem
