--!strict
--[=[
	OfficeDoorLeafSystem: one door leaf's Instance. `leafPart` builds the anchored greybox leaf (wood, or half
	see-through glass tagged SightThrough) under a parent; `dress` attaches the kit's `doorLeaf` / `doorLeafGlass` art
	to it through OfficeArtKeyUtils (a glass leaf's art never occludes the camera). Split out of OfficeDoorSystem,
	which builds every door and facade leaf through it.

	@class OfficeDoorLeafSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeArtKeyUtils = require(ServerScriptService.Features.Office.Utils.OfficeArtKeyUtils)

local OfficeDoorLeafSystem = {}

function OfficeDoorLeafSystem.leafPart(name: string, size: Vector3, glass: boolean, parent: Instance): Part
	local leaf = Instance.new("Part")
	leaf.Name = name
	leaf.Size = size
	leaf.Anchored = true
	leaf.CanCollide = true
	leaf.CanQuery = true
	leaf.CanTouch = false
	leaf.TopSurface = Enum.SurfaceType.Smooth
	leaf.BottomSurface = Enum.SurfaceType.Smooth
	leaf.Color = OfficeConstants.DOOR_COLOR
	if glass then
		leaf.Material = Enum.Material.Glass
		leaf.Transparency = 0.5
		CollectionService:AddTag(leaf, OccupantConstants.SIGHT_THROUGH_TAG)
	else
		leaf.Material = Enum.Material.WoodPlanks
	end
	leaf.Parent = parent
	return leaf
end

-- Attaches the leaf's door art; true when it did and the leaf is solid (so it occludes while closed).
function OfficeDoorLeafSystem.dress(art: ArtVisualSystem.Controller, leaf: BasePart, glass: boolean): boolean
	local visual = OfficeArtKeyUtils.attachFirst(
		art,
		leaf,
		"building",
		OfficeArtKeyUtils.candidates(if glass then "doorLeafGlass" else "doorLeaf", nil, nil)
	)
	if visual ~= nil and glass then
		leaf:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
	end
	return visual ~= nil and not glass
end

return OfficeDoorLeafSystem
