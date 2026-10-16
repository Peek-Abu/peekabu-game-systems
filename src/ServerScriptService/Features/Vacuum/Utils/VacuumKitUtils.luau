--!strict
--[=[
	VacuumKitUtils: a fresh copy of a vacuum skin's art (VacuumSkinRegistry), for VacuumVisualSystem to wear and
	build. The art is the skin's approved template (ReplicatedStorage.Assets.CleanupCrew.<template>,
	`RuntimeApproved`: `Backpack` pivoted at its mount, `Straps` pivoted at the torso they were modelled round,
	`Wand` pieces), Standard Issue's when the skin's is missing, or VacuumVisualConstants' graybox when neither is
	there. A template is complete only with every wand piece and the grip contract's two Attachments
	(characters/vacuum/README.md); an incomplete one is never half-worn.

	@class VacuumKitUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local Constants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)

-- `kind`: "approved-mesh" (a template's) or "native-source" (the graybox).
export type Kit = { pack: Model, straps: Model?, wand: { [string]: BasePart }, kind: string }

local WAND_PIECES = { "WandGrip", "WandInlet", "WandTube", "WandSwivel", "FloorHead", "FloorHeadLip" }
local GRIPS = { Constants.grips.upper, Constants.grips.lower }

local VacuumKitUtils = {}

local function partOf(container: Instance, name: string): BasePart?
	local found = container:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function fromPiece(source: Constants.Piece): BasePart
	local part = Instance.new("Part")
	part.Name = source.name
	part.Shape = source.shape
	part.Size = source.size
	part.CFrame = source.frame
	part.Color = source.color
	part.Material = source.material
	part.Transparency = source.transparency
	return part
end

local function approved(root: Instance, name: string): Model?
	local current: Instance? = root
	for _, step in Constants.TEMPLATE_FOLDER do
		current = if current ~= nil then current:FindFirstChild(step) else nil
	end
	local found = if current ~= nil then current:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") and found:GetAttribute("RuntimeApproved") == true then found else nil
end

--[=[
	The approved template `skin` is drawn from under `root` (ReplicatedStorage when nil): its own, else Standard
	Issue's, else nil (the graybox).
]=]
function VacuumKitUtils.templateFor(skin: VacuumSkinRegistry.SkinDef, root: Instance?): Model?
	local from = root or ReplicatedStorage
	return approved(from, skin.template) or approved(from, VacuumSkinRules.select(nil).template)
end

-- The template's pieces, detached from a copy of it; nil when the copy is incomplete (it is then destroyed).
local function fromTemplate(source: Model): Kit?
	local copy = source:Clone()
	local pack = copy:FindFirstChild("Backpack")
	local straps = copy:FindFirstChild("Straps")
	local wandFolder = copy:FindFirstChild("Wand")
	local wand: { [string]: BasePart } = {}
	local complete = pack ~= nil and pack:IsA("Model") and wandFolder ~= nil
	for _, name in WAND_PIECES do
		local part = if wandFolder ~= nil then partOf(wandFolder, name) else nil
		if part ~= nil then
			wand[name] = part
		end
		complete = complete and part ~= nil
	end
	-- The grip contract: a wand without both grips is not a complete skin.
	for _, grip in GRIPS do
		local holder: BasePart? = wand[grip.piece]
		local found = if holder ~= nil then holder:FindFirstChild(grip.name) else nil
		complete = complete and found ~= nil and found:IsA("Attachment")
	end
	if not complete or pack == nil or not pack:IsA("Model") then
		copy:Destroy()
		return nil
	end
	pack.Parent = nil
	local strapModel = if straps ~= nil and straps:IsA("Model") then straps else nil
	if strapModel ~= nil then
		strapModel.Parent = nil
	end
	for _, part in wand do
		part.Parent = nil
	end
	copy:Destroy()
	return { pack = pack, straps = strapModel, wand = wand, kind = "approved-mesh" }
end

-- The graybox (the pack pivoted at its mount), with the grip contract's Attachments.
local function graybox(): Kit
	local pack = Instance.new("Model")
	pack.Name = "Backpack"
	for _, piece in Constants.backpack do
		fromPiece(piece).Parent = pack
	end
	pack.WorldPivot = CFrame.identity
	local wand: { [string]: BasePart } = {}
	for _, piece in Constants.wand do
		wand[piece.name] = fromPiece(piece)
	end
	for _, grip in GRIPS do
		local attachment = Instance.new("Attachment")
		attachment.Name = grip.name
		attachment.Position = grip.position
		attachment.Parent = wand[grip.piece]
	end
	return { pack = pack, straps = nil, wand = wand, kind = "native-source" }
end

--[=[
	A fresh copy of `skin`'s art (see the class notes), its templates looked up under `root` (ReplicatedStorage when
	nil). The caller owns every piece.
]=]
function VacuumKitUtils.kit(skin: VacuumSkinRegistry.SkinDef, root: Instance?): Kit
	local source = VacuumKitUtils.templateFor(skin, root)
	local art = if source ~= nil then fromTemplate(source) else nil
	return art or graybox()
end

return VacuumKitUtils
