--!strict
--[=[
	EmployeeSkinSystem: dresses a freshly spawned employee character in a skin (EmployeeRegistry SkinDef),
	on the server, so every client sees the same look through normal replication.

	- Palette: the skin's palette image becomes the TextureID of every MeshPart except the FacePlate (whose
	  face is a SurfaceAppearance; a TextureID there would render its transparent areas black). A skin with
	  no palette yet (art pending) or a malformed id leaves the model's own palette alone.
	- Faces: when the skin names a face set and the character carries that folder, it replaces `Faces`
	  (the client re-shows the current face from it, EmployeeFaceSystem).
	- Accessories: each named Accessory found under `accessorySource` is cloned onto the Humanoid; a named
	  fitted-gear Model is fitted onto its mount part instead (EmployeeGearSystem: scaled with the character, which an
	  Accessory is not); missing ones are skipped.

	Every part is optional: a skin that names nothing changes nothing.

	@class EmployeeSkinSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local EmployeeGearSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeGearSystem)

export type SkinResult = {
	-- MeshParts given the skin's palette.
	textured: number,
	facesSwapped: boolean,
	accessories: number,
}

local EmployeeSkinSystem = {}

local function swapFaces(character: Model, folderName: string): boolean
	local replacement = character:FindFirstChild(folderName)
	if replacement == nil or not replacement:IsA("Folder") then
		return false
	end
	-- A fresh child, not a rename: clients notice a new `Faces` (ChildAdded), never a Name change.
	local copy = replacement:Clone()
	copy.Name = EmployeeConstants.FACES_FOLDER
	local own = character:FindFirstChild(EmployeeConstants.FACES_FOLDER)
	if own ~= nil then
		own:Destroy()
	end
	replacement:Destroy()
	copy.Parent = character
	return true
end

--[=[
	Applies `skin` to `character`.
	@param accessorySource Where the skin's accessories are looked up by name (the folder at
	EmployeeConstants.ACCESSORIES_PATH in the game); nil skips accessories.
]=]
function EmployeeSkinSystem.apply(
	character: Model,
	skin: EmployeeRegistry.SkinDef,
	accessorySource: Instance?
): SkinResult
	local result: SkinResult = { textured = 0, facesSwapped = false, accessories = 0 }

	local palette = EmployeeSkinRules.palette(skin)
	if palette ~= nil then
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("MeshPart") and descendant.Name ~= EmployeeConstants.FACE_PLATE then
				descendant.TextureID = palette
				result.textured += 1
			end
		end
	end

	local facesFolder = skin.facesFolder
	if facesFolder ~= nil then
		result.facesSwapped = swapFaces(character, facesFolder)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if accessorySource ~= nil and humanoid ~= nil then
		for _, name in skin.accessories do
			local source = accessorySource:FindFirstChild(name)
			if source ~= nil and source:IsA("Accessory") then
				humanoid:AddAccessory(source:Clone())
				result.accessories += 1
			elseif source ~= nil and source:IsA("Model") and EmployeeGearSystem.fit(character, source) ~= nil then
				result.accessories += 1
			end
		end
	end

	return result
end

return EmployeeSkinSystem
