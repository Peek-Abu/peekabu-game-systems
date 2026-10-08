--!strict
--[=[
	CustomizationRigLookSystem: edits to a rig's own parts that can always be undone (R4 spec, Section 2) — colours,
	head-part visibility, surfaces — plus the lookup of place-owned art.

	"Authored" state is captured the first time it is overwritten (an attribute on the instance, or a
	clone for a SurfaceAppearance), so a nil from the diff restores exactly what the rig or art was
	built with. That is what keeps a pooled rig from showing its last owner's look.

	ART BOUNDARY: cosmetic art is owned by the Studio place, not this Rojo tree, so it is looked up at
	runtime under the root the registry declares, each folder read as a direct child (ids are reused
	across folders, so a root-wide search would pick a duplicate at random). Missing art is nil.

	@class CustomizationRigLookSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)
local CustomizationRigOutfitTracker =
	require(ReplicatedStorage.Client.Features.Customization.State.CustomizationRigOutfitTracker)

local log = Logger.new("CustomizationRigLookSystem")

-- Marks a SurfaceAppearance this module applied, so restoring never deletes the rig's own.
local COSMETIC_TAG = "VentureCosmetic"
local APPLIED_PATTERN_ATTRIBUTE = "VentureAppliedPattern"
local AUTHORED_COLOR_ATTRIBUTE = "VentureAuthoredColor"
local AUTHORED_TRANSPARENCY_ATTRIBUTE = "VentureAuthoredTransparency"
local AUTHORED_TEXTURE_ATTRIBUTE = "VentureAuthoredTexture"

local CustomizationRigLookSystem = {}

-- The place-owned art root, or nil when any step of the registry's path is missing.
local function artRoot(): Instance?
	local current: Instance = ReplicatedStorage
	for _, segment in ipairs(CustomizationCosmeticRegistry.artRootPath()) do
		local nextFolder = current:FindFirstChild(segment)
		if not nextFolder then
			return nil
		end
		current = nextFolder
	end
	return current
end

-- A direct child of one declared folder, never a root-wide search: ids are reused across folders.
function CustomizationRigLookSystem.findArt(folderName: string, id: string): Instance?
	local root = artRoot()
	local folder = if root ~= nil then root:FindFirstChild(folderName) else nil
	if folder == nil then
		log:debug(`art folder "{folderName}" is missing from the art root — cannot resolve "{id}"`)
		return nil
	end
	return folder:FindFirstChild(id)
end

-- The SurfaceAppearance a pattern entry provides: the entry itself, or one nested in a Model wrapper.
local function findPattern(folderName: string, id: string): SurfaceAppearance?
	local entry = CustomizationRigLookSystem.findArt(folderName, id)
	if entry == nil then
		return nil
	end
	if entry:IsA("SurfaceAppearance") then
		return entry
	end
	return entry:FindFirstChildWhichIsA("SurfaceAppearance", true)
end

-- Texture ids are authored as StringValues.
local function findTextureId(id: string): string?
	local folderName = CustomizationCosmeticRegistry.artFolder("texture")
	local holder = if folderName ~= nil then CustomizationRigLookSystem.findArt(folderName, id) else nil
	if holder ~= nil and holder:IsA("StringValue") and holder.Value ~= "" then
		return holder.Value
	end
	return nil
end

local function toColor3(rgb: CustomizationOutfitDiffUtils.Rgb): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

-- Sets a part's colour, or restores the colour it was authored with when `rgb` is nil.
function CustomizationRigLookSystem.setColor(part: BasePart, rgb: CustomizationOutfitDiffUtils.Rgb?)
	local authored = part:GetAttribute(AUTHORED_COLOR_ATTRIBUTE)
	if typeof(authored) ~= "Color3" then
		authored = part.Color
		part:SetAttribute(AUTHORED_COLOR_ATTRIBUTE, authored)
	end
	if rgb ~= nil then
		part.Color = toColor3(rgb)
	elseif typeof(authored) == "Color3" then
		part.Color = authored
	end
end

-- Shows/hides one head part and everything under it, or restores its authored transparency (nil).
local function targetTransparency(instance: Instance, current: number, visible: boolean?): number
	local authored = instance:GetAttribute(AUTHORED_TRANSPARENCY_ATTRIBUTE)
	if type(authored) ~= "number" then
		authored = current
		instance:SetAttribute(AUTHORED_TRANSPARENCY_ATTRIBUTE, current)
	end
	if visible == nil then
		return if type(authored) == "number" then authored else current
	end
	return if visible then 0 else 1
end

function CustomizationRigLookSystem.setVisibility(target: Instance, visible: boolean?)
	local instances = target:GetDescendants()
	table.insert(instances, target)
	for _, instance in instances do
		-- Two identical branches on purpose: each narrows `instance` to one class, and the type checker
		-- cannot write `.Transparency` through a `BasePart | Decal` union.
		-- selene: allow(if_same_then_else)
		if instance:IsA("BasePart") then
			instance.Transparency = targetTransparency(instance, instance.Transparency, visible)
		elseif instance:IsA("Decal") then
			instance.Transparency = targetTransparency(instance, instance.Transparency, visible)
		end
	end
end

-- The rig part's authored SurfaceAppearance, captured the first time a pattern replaces it.
-- Two weak tables rather than one `SurfaceAppearance | false` map: "captured, and it had none" must be
-- told apart from "not captured yet".
local authoredSurfaces: { [BasePart]: SurfaceAppearance } = {}
local capturedSurfaces: { [BasePart]: boolean } = {}
setmetatable(authoredSurfaces, { __mode = "k" })
setmetatable(capturedSurfaces, { __mode = "k" })

function CustomizationRigLookSystem.setSurface(
	outfit: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker,
	surface: CustomizationOutfitDiffUtils.Surface
)
	local pattern = surface.pattern
	local patternSource = if pattern ~= nil then findPattern(surface.artFolder, pattern) else nil
	local textureId = if surface.texture ~= nil then findTextureId(surface.texture) else nil
	for _, part in CustomizationRigOutfitTracker.partsFor(outfit, surface.part) do
		local existing = part:FindFirstChildOfClass("SurfaceAppearance")
		if not capturedSurfaces[part] then
			capturedSurfaces[part] = true
			if existing ~= nil then
				authoredSurfaces[part] = existing:Clone()
			end
		end
		if patternSource ~= nil and part:IsA("MeshPart") then
			if existing == nil or existing:GetAttribute(APPLIED_PATTERN_ATTRIBUTE) ~= pattern then
				if existing ~= nil then
					existing:Destroy()
				end
				local applied = patternSource:Clone()
				applied:SetAttribute(COSMETIC_TAG, true)
				applied:SetAttribute(APPLIED_PATTERN_ATTRIBUTE, pattern)
				applied.Parent = part
			end
		elseif existing ~= nil and existing:GetAttribute(COSMETIC_TAG) == true then
			existing:Destroy()
			local authored: SurfaceAppearance? = authoredSurfaces[part]
			if authored ~= nil then
				authored:Clone().Parent = part
			end
		end
		for _, child in part:GetChildren() do
			if child:IsA("Texture") then
				local authored = child:GetAttribute(AUTHORED_TEXTURE_ATTRIBUTE)
				if type(authored) ~= "string" then
					authored = child.Texture
					child:SetAttribute(AUTHORED_TEXTURE_ATTRIBUTE, authored)
				end
				if textureId ~= nil then
					child.Texture = textureId
				elseif type(authored) == "string" then
					child.Texture = authored
				end
			end
		end
	end
end

return CustomizationRigLookSystem
