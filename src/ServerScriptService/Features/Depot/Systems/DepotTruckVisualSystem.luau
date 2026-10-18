--!strict
--[=[
	DepotTruckVisualSystem: the Morrow & Morrow "Mobile Recovery Unit" (truck design A) round a truck bed, for the
	depot's queue trucks and the office's loading-bay truck. The bed part stays the authority (queue pad, banking
	bed, load prompt) at its full size; this only adds round it, in DepotTruckVisualConstants' deck space:

	- the art: a clone of the approved template (ReplicatedStorage.Assets.CleanupCrew.Truck, RuntimeApproved,
	  pivoted at the middle of the bed's top face, cab toward +Z) or the graybox fallback. Every art part is
	  anchored and inert (no collision, query or touch); the bed is hidden under the art's floor;
	- invisible native collision, parented to the bed: box walls, roof, arch posts, cab and the loading ramp (a
	  wedge from the ground to the bed's back edge). Collidable parts are always queryable; as the bed's
	  descendants they count as the bed for the load prompt's sight check, so the prompt is seen through the box;
	- an opaque camera shell, parented to the bed: cores hidden inside the art's walls, roof, door drum, arch
	  posts, clock and floor, so the default camera (Popper, which ignores the inert meshes and the invisible
	  collision) pops in at the box's walls instead of seeing through the truck. The floor core sits over the
	  deck, so a camera ray meets it before the invisible bed (Popper drops a part it passes through together
	  with all its descendants);
	- the time clock on the inside of the front wall (template CLOCK_TEMPLATE_PATH or a graybox). The office's
	  Clock out and Start overtime parts go at `paperwork(bed, which)`;
	- the box-side livery (a SurfaceGui per side), a warm lamp under the roof, and the scanner arch light tagged
	  for the client's bank flash (DepotTruckScannerSystem) with its sweep path.

	@class DepotTruckVisualSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local Constants = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

type Shape = Constants.Shape

local DepotTruckVisualSystem = {}

local function shaped(shape: Shape): BasePart
	if shape == "Wedge" then
		return Instance.new("WedgePart")
	end
	local part = Instance.new("Part")
	if shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function find(path: { string }): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in path do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end
	return if current ~= nil and current:IsA("Model") then current else nil
end

-- The approved art in ReplicatedStorage, or nil (the graybox is used).
function DepotTruckVisualSystem.template(): Model?
	return find(Constants.TEMPLATE_PATH)
end

-- The approved time clock art in ReplicatedStorage, or nil (its graybox is used).
function DepotTruckVisualSystem.clockTemplate(): Model?
	return find(Constants.CLOCK_TEMPLATE_PATH)
end

-- A clone of an approved `source` pivoted at `at`, else `graybox` built there; named `name`, not yet inert.
local function placed(name: string, at: CFrame, source: Model?, graybox: { Constants.Piece }): Model
	local model: Model
	if source ~= nil and source:GetAttribute(Constants.APPROVED_ATTRIBUTE) == true then
		model = source:Clone()
		model:PivotTo(at)
		model:SetAttribute(Constants.ART_KIND_ATTRIBUTE, "approved-mesh")
	else
		model = Instance.new("Model")
		for _, piece in graybox do
			local part = shaped(piece.shape)
			part.Name = piece.name
			part.Size = piece.size
			part.CFrame = at * CFrame.new(piece.centre)
			part.Color = piece.color
			part.Material = piece.material
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = model
		end
		model.WorldPivot = at
		model:SetAttribute(Constants.ART_KIND_ATTRIBUTE, "graybox")
	end
	model.Name = name
	model:SetAttribute(Constants.APPROVED_ATTRIBUTE, nil)
	return model
end

local function art(deck: CFrame, source: Model?, clockSource: Model?): Model
	local model = placed(Constants.ART_NAME, deck, source, Constants.GRAYBOX)
	local clock =
		placed(Constants.CLOCK_NAME, deck * CFrame.new(Constants.CLOCK_MOUNT), clockSource, Constants.CLOCK_GRAYBOX)
	clock.Parent = model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			inert(descendant)
		end
	end
	return model
end

local function livery(model: Model)
	for _, target in Constants.LIVERY_FACES do
		local part = model:FindFirstChild(target.piece)
		if part ~= nil and part:IsA("BasePart") then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Livery"
			gui.Face = target.face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = Constants.LIVERY_PIXELS_PER_STUD
			gui.LightInfluence = 1
			gui.MaxDistance = 250
			local image = Instance.new("ImageLabel")
			image.Name = "Livery"
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = Constants.LIVERY_IMAGE
			image.ScaleType = Enum.ScaleType.Stretch
			image.Parent = gui
			gui.Parent = part
		end
	end
end

local function lamp(model: Model)
	local roof = model:FindFirstChild(Constants.ROOF_PIECE)
	if roof ~= nil and roof:IsA("BasePart") then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = Constants.LAMP_COLOR
		light.Brightness = Constants.LAMP_BRIGHTNESS
		light.Range = Constants.LAMP_RANGE
		light.Angle = 120
		light.Shadows = false
		light.Parent = roof
	end
end

local function scanner(model: Model, deck: CFrame)
	local light = model:FindFirstChild(Constants.SCANNER_PIECE)
	if light == nil or not light:IsA("BasePart") then
		return
	end
	light.Material = Enum.Material.Neon
	light.Color = Constants.SCANNER_IDLE
	light:SetAttribute(DepotConstants.SCANNER_IDLE_ATTRIBUTE, Constants.SCANNER_IDLE)
	light:SetAttribute(DepotConstants.SCANNER_WIDTH_ATTRIBUTE, Constants.SWEEP_WIDTH)
	for name, point in
		{
			[DepotConstants.SCANNER_SWEEP_TOP] = Constants.SWEEP_TOP,
			[DepotConstants.SCANNER_SWEEP_BOTTOM] = Constants.SWEEP_BOTTOM,
		}
	do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = light.CFrame:ToObjectSpace(deck * CFrame.new(point))
		attachment.Parent = light
	end
	local glow = Instance.new("PointLight")
	glow.Name = Constants.SCANNER_GLOW_NAME
	glow.Color = Constants.SCANNER_IDLE
	glow.Brightness = 0
	glow.Range = Constants.SCANNER_GLOW_RANGE
	glow.Shadows = false
	glow.Parent = light
	CollectionService:AddTag(light, DepotConstants.SCANNER_TAG)
end

local function shell(deck: CFrame, bed: BasePart)
	for _, entry in Constants.SHELL do
		local part = Instance.new("Part")
		part.Name = entry.name
		part.Size = entry.size
		part.CFrame = deck * CFrame.new(entry.centre)
		part.Color = Constants.IVORY
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
		part.CastShadow = false
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.Parent = bed
	end
end

local function collision(deck: CFrame, bed: BasePart)
	for _, entry in Constants.COLLISION do
		local part = shaped(entry.shape)
		part.Name = entry.name
		part.Size = entry.size
		part.CFrame = deck * CFrame.new(entry.centre)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		if entry.occludes == true then
			part:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
		end
		part.Parent = bed
	end
end

--[=[
	Builds the truck round `bed` into `parent` from `source` (an approved template, or nil for the graybox) and
	`clockSource` (the time clock's, or nil) and returns the art model. The bed keeps its size and place.
]=]
function DepotTruckVisualSystem.buildWith(bed: BasePart, parent: Instance, source: Model?, clockSource: Model?): Model
	local deck = bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)
	local model = art(deck, source, clockSource)
	livery(model)
	lamp(model)
	scanner(model, deck)
	bed.Transparency = Constants.BED_TRANSPARENCY
	collision(deck, bed)
	shell(deck, bed)
	model.Parent = parent
	return model
end

-- Builds the truck round `bed` from the approved templates when the place has them, else the graybox.
function DepotTruckVisualSystem.build(bed: BasePart, parent: Instance): Model
	return DepotTruckVisualSystem.buildWith(
		bed,
		parent,
		DepotTruckVisualSystem.template(),
		DepotTruckVisualSystem.clockTemplate()
	)
end

--[=[
	Where the truck on `bed` keeps its paperwork: the frame (facing out of the front wall, toward the open back) and
	size of the time clock's hit box round its art, or of the overtime sheet.
]=]
function DepotTruckVisualSystem.paperwork(bed: BasePart, which: Constants.Paperwork): (CFrame, Vector3)
	local frame = Constants.PAPERWORK[which]
	return bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0) * CFrame.new(frame.centre), frame.size
end

return DepotTruckVisualSystem
