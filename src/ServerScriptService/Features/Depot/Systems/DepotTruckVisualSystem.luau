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
	- the box-side livery (a SurfaceGui per side), a warm lamp under the roof, and the scanner arch light tagged
	  for the client's bank flash (DepotTruckScannerSystem) with its sweep path.

	@class DepotTruckVisualSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

-- The approved art in ReplicatedStorage, or nil (the graybox is used).
function DepotTruckVisualSystem.template(): Model?
	local current: Instance? = ReplicatedStorage
	for _, name in Constants.TEMPLATE_PATH do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end
	return if current ~= nil and current:IsA("Model") then current else nil
end

local function art(deck: CFrame, source: Model?): Model
	local model: Model
	if source ~= nil and source:GetAttribute(Constants.APPROVED_ATTRIBUTE) == true then
		model = source:Clone()
		model:PivotTo(deck)
		model:SetAttribute(Constants.ART_KIND_ATTRIBUTE, "approved-mesh")
	else
		model = Instance.new("Model")
		for _, piece in Constants.GRAYBOX do
			local part = shaped(piece.shape)
			part.Name = piece.name
			part.Size = piece.size
			part.CFrame = deck * CFrame.new(piece.centre)
			part.Color = piece.color
			part.Material = piece.material
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = model
		end
		model.WorldPivot = deck
		model:SetAttribute(Constants.ART_KIND_ATTRIBUTE, "graybox")
	end
	model.Name = Constants.ART_NAME
	model:SetAttribute(Constants.APPROVED_ATTRIBUTE, nil)
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
		part.Parent = bed
	end
end

--[=[
	Builds the truck round `bed` into `parent` from `source` (an approved template, or nil for the graybox) and
	returns the art model. The bed keeps its size and place.
]=]
function DepotTruckVisualSystem.buildWith(bed: BasePart, parent: Instance, source: Model?): Model
	local deck = bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)
	local model = art(deck, source)
	livery(model)
	lamp(model)
	scanner(model, deck)
	bed.Transparency = Constants.BED_TRANSPARENCY
	collision(deck, bed)
	model.Parent = parent
	return model
end

-- Builds the truck round `bed` from the approved template when the place has one, else the graybox.
function DepotTruckVisualSystem.build(bed: BasePart, parent: Instance): Model
	return DepotTruckVisualSystem.buildWith(bed, parent, DepotTruckVisualSystem.template())
end

return DepotTruckVisualSystem
