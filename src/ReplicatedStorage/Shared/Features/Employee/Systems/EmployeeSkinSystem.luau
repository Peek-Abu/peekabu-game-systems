--!strict
--[=[
	EmployeeSkinSystem: dresses an employee model in a skin (EmployeeRegistry SkinDef). The server dresses each
	freshly spawned character (every client sees it through normal replication); the client dresses its own preview
	models the same way (EmployeePreviewSystem), so a preview never drifts from the real look.

	- Palette: the skin's palette image becomes the TextureID of every body MeshPart, so every one except the
	  FacePlate (whose face is a SurfaceAppearance; a TextureID there would render its transparent areas black) and
	  the clothes in the template's pieces folder. A skin with no palette yet (art pending) or a malformed id leaves
	  the model's own palette alone.
	- Pieces: each clothing piece the skin names (a child of EmployeeConstants.PIECES_FOLDER) gets its own palette
	  image on all its MeshParts, or, for a plain-coloured part, its Color. Missing pieces are skipped.
	- Faces: when the skin names a face set and the character carries that folder, it replaces `Faces`
	  (the client re-shows the current face from it, EmployeeFaceSystem).
	- Accessories: each named Accessory found under `accessorySource` is cloned onto the Humanoid; a named
	  fitted-gear Model is fitted onto its mount part instead (EmployeeGearSystem: scaled with the character, which an
	  Accessory is not); missing ones are skipped.
	- Outfit: a skin naming a skinned outfit has it fitted from `outfitSource` (the folder at
	  EmployeeConstants.OUTFITS_PATH) in the player's colour style (EmployeeOutfitSystem). A styled skin's palette is its
	  style's (each style recolours the body); the palette never reaches the outfit's meshes or props, except an
	  outfit mesh in the Body StyleSlot (painted with the body palette, e.g. trousers).

	- Covered pieces: the employee's own pieces the skin's `hidePieces` names are hidden (EmployeeOutfitSystem.hidePieces,
	  the outfit's HideAccessories rule), e.g. Cappy's hoodie under a layered-clothing jacket. A layered garment is an
	  ordinary Accessory (a WrapLayer on its Handle) in `accessories`: the engine wraps it over the employee's body cages,
	  baked into every template.

	Every part is optional: a skin that names nothing changes nothing.

	@class EmployeeSkinSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local EmployeeGearSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeGearSystem)
local EmployeeOutfitSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeOutfitSystem)

export type SkinResult = {
	-- MeshParts given the skin's palette.
	textured: number,
	-- Clothing pieces' MeshParts given the skin's piece palette or colour.
	pieces: number,
	facesSwapped: boolean,
	accessories: number,
	-- Whether the skin's skinned outfit was fitted.
	outfit: boolean,
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
	@param style The player's colour style of the skin (clamped: EmployeeSkinRules.styleIndex); nil = style 1.
	@param outfitSource Where the skin's outfit is looked up by name (the folder at EmployeeConstants.OUTFITS_PATH);
	nil skips the outfit.
]=]
function EmployeeSkinSystem.apply(
	character: Model,
	skin: EmployeeRegistry.SkinDef,
	accessorySource: Instance?,
	style: number?,
	outfitSource: Instance?
): SkinResult
	local result: SkinResult = { textured = 0, facesSwapped = false, accessories = 0, pieces = 0, outfit = false }
	local pieces = character:FindFirstChild(EmployeeConstants.PIECES_FOLDER)

	local outfitName = skin.outfit
	local outfit = if outfitName ~= nil and outfitSource ~= nil then outfitSource:FindFirstChild(outfitName) else nil
	if outfit ~= nil and outfit:IsA("Model") then
		local styleDef = EmployeeSkinRules.style(skin, style)
		result.outfit = EmployeeOutfitSystem.fit(character, outfit, if styleDef ~= nil then styleDef.folder else nil)
	end

	local palette = EmployeeSkinRules.palette(skin, style)
	if palette ~= nil then
		for _, descendant in character:GetDescendants() do
			if
				descendant:IsA("MeshPart")
				and descendant.Name ~= EmployeeConstants.FACE_PLATE
				and (pieces == nil or not descendant:IsDescendantOf(pieces))
				and (
					not EmployeeOutfitSystem.isOutfitPart(character, descendant)
					or descendant:GetAttribute(EmployeeConstants.STYLE_SLOT_ATTRIBUTE)
						== EmployeeConstants.BODY_STYLE_SLOT
				)
			then
				descendant.TextureID = palette
				result.textured += 1
			end
		end
	end

	local piecePalettes: { [string]: string } = skin.piecePalettes or {}
	local pieceColors: { [string]: Color3 } = skin.pieceColors or {}
	if pieces ~= nil then
		for name in piecePalettes do
			local piecePalette = EmployeeSkinRules.piecePalette(skin, name)
			local piece = pieces:FindFirstChild(name)
			if piecePalette ~= nil and piece ~= nil then
				local parts: { Instance } = piece:GetDescendants()
				table.insert(parts, piece)
				for _, part in parts do
					if part:IsA("MeshPart") then
						part.TextureID = piecePalette
						result.pieces += 1
					end
				end
			end
		end
		for name, color in pieceColors do
			local part = pieces:FindFirstChild(name)
			if part ~= nil and part:IsA("MeshPart") then
				part.Color = color
				result.pieces += 1
			end
		end
	end

	local hidePieces = skin.hidePieces
	if hidePieces ~= nil then
		EmployeeOutfitSystem.hidePieces(character, hidePieces)
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
