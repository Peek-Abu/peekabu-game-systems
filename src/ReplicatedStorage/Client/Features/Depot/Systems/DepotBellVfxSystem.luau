--!strict
--[=[
	DepotBellVfxSystem: the shift bell's ring on this client (launch VFX 2026-11-16, owner pick C; DepotSpotSystem calls
	`play` on every DepotEvents.Bell, as it swings the bell). Two gold rings roll out across the hub floor from the bell
	post (Decals on flat invisible plates on the floor under the cup: a full-colour image with its deep-gold edge baked
	in), gold soap bubbles float up and a short warm glow lights the bell (unless the player set graphics 1 to 4 by
	hand, VfxFormulas.lightsShown). The glow's PointLight is made at brightness 0, fades up, holds and fades back to 0
	before it is removed (owner: never snap a light; DepotBellFormulas.glow). One RenderStepped connection drives it all
	until DepotBellFormulas.duration(), then everything is destroyed. Client-local instances.

	Spec-exempt shell (Instances, raycasts, RunService); the shapes over time are the specced DepotBellFormulas.

	@class DepotBellVfxSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DepotBellFormulas = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotBellFormulas)
local VfxAssets = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxAssets)
local VfxConstants = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxConstants)
local VfxFormulas = require(ReplicatedStorage.Shared.Features.Vfx.Utils.VfxFormulas)

local T = DepotBellFormulas.TUNING
local GOLD = VfxConstants.PALETTE.gleam
local GOLD_LIGHT = VfxConstants.PALETTE.gleamLight

type Plate = { part: Part, decal: Decal }

local DepotBellVfxSystem = {}

local function host(folder: Folder, at: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = CFrame.new(at)
	part.Parent = folder
	return part
end

-- The floor under the bell's cup (the bell itself, characters and non-colliding parts ignored), or the cup itself.
local function floorUnder(cup: Vector3, folder: Folder, bell: Instance?): Vector3
	local ignore: { Instance } = { folder }
	if bell ~= nil then
		table.insert(ignore, bell)
	end
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(cup, Vector3.new(0, -T.floorProbe, 0), params)
	return if hit ~= nil then hit.Position else cup
end

local function plate(folder: Folder, floor: Vector3): Plate
	local part = host(folder, floor + Vector3.new(0, T.ringLift, 0), Vector3.new(0.1, 0.02, 0.1))
	local decal = Instance.new("Decal")
	decal.Texture = VfxAssets.TEXTURES.bellWave
	decal.Face = Enum.NormalId.Top
	decal.Transparency = 1
	decal.Parent = part
	return { part = part, decal = decal }
end

local function bubbles(folder: Folder, at: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Parent = host(folder, at, Vector3.new(0.2, 0.2, 0.2))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VfxAssets.TEXTURES.bubble
	emitter.Color = ColorSequence.new(GOLD, GOLD_LIGHT)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.1, 1.5)
	emitter.Speed = NumberRange.new(2.5, 4)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Drag = 1.5
	emitter.LightEmission = 0.4
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(T.bubbles)
end

--[=[
	Plays the ring at `cup` (world space: the bell's cup; the floor rings start on the floor under it, the `bell` model
	itself never taken for the floor).
]=]
function DepotBellVfxSystem.play(cup: Vector3, bell: Instance?)
	local folder = Instance.new("Folder")
	folder.Name = "BellRing"
	folder.Parent = Workspace
	local floor = floorUnder(cup, folder, bell)
	local rings: { Plate } = {}
	for _ in T.rings do
		table.insert(rings, plate(folder, floor))
	end
	local light: PointLight? = nil
	if VfxFormulas.lightsShown(UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value) then
		local made = Instance.new("PointLight")
		made.Color = GOLD
		made.Range = T.glowRange
		made.Brightness = 0
		made.Parent = host(folder, cup, Vector3.new(0.2, 0.2, 0.2))
		light = made
	end
	bubbles(folder, cup)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		for index, ring in rings do
			local shape = DepotBellFormulas.ring(index, elapsed)
			local across = shape.radius * 2
			ring.part.Size = Vector3.new(across, 0.02, across)
			ring.decal.Transparency = if shape.live then shape.transparency else 1
		end
		if light ~= nil then
			light.Brightness = DepotBellFormulas.glow(elapsed)
		end
		if elapsed >= DepotBellFormulas.duration() + 1.5 or folder.Parent == nil then
			connection:Disconnect()
			folder:Destroy()
		end
	end)
end

return DepotBellVfxSystem
