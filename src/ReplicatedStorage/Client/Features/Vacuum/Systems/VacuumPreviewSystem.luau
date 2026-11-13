--!strict
--[=[
	VacuumPreviewSystem: a vacuum skin's art for UI previews, on this client only (the real pack is the server's
	VacuumVisualSystem). Every skin shares one geometry (characters/vacuum: the same mount, straps and wand piece
	sizes), so a preview never re-fits anything: it copies the art over the pieces already there.

	- `swap(character, skin, source)`: on a CLONE of a character that wears a pack (VacuumConstants.BACKPACK_NAME),
	  puts `skin`'s art on it: the canister at the scale it was worn at with its mount plate where the old one met the
	  back (VacuumMountSystem), the straps fitted as the server fitted them (both read from the attributes the server
	  records, VacuumConstants.MOUNT), each stowed wand piece at the same
	  place and size (the tube stays telescoped), and the hose's texture. New pieces are welded to what they replace
	  was welded to (the pack's anchor, or the torso for the straps), so a live preview carries them as it animates.
	  False when there is no pack, no approved template for the skin, or it already wears that skin.
	- `alone(skin, source)`: the skin's canister on its own (anchored), for a card's art. Nil without a template.

	Templates are the server's: `<source>.Assets.CleanupCrew.<skin.template>` with `RuntimeApproved`.

	@class VacuumPreviewSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
local VacuumMountFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMountFormulas)
local VacuumMountSystem = require(ReplicatedStorage.Shared.Features.Vacuum.Systems.VacuumMountSystem)

type SkinDef = VacuumSkinRegistry.SkinDef

local MOUNT = VacuumConstants.MOUNT

-- Where the approved templates live (the same folder VacuumVisualConstants.TEMPLATE_FOLDER names on the server).
local TEMPLATE_FOLDER = { "Assets", "CleanupCrew" }

local VacuumPreviewSystem = {}

local function templateOf(skin: SkinDef, source: Instance): Model?
	local current: Instance? = source
	for _, step in TEMPLATE_FOLDER do
		current = if current ~= nil then current:FindFirstChild(step) else nil
	end
	local found = if current ~= nil then current:FindFirstChild(skin.template) else nil
	return if found ~= nil and found:IsA("Model") and found:GetAttribute("RuntimeApproved") == true then found else nil
end

local function modelChild(parent: Instance, name: string): Model?
	local found = parent:FindFirstChild(name)
	return if found ~= nil and found:IsA("Model") then found else nil
end

local function basePart(parent: Instance, name: string): BasePart?
	local found = parent:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- Welds every part of `art` to `to` (unanchored), so it moves with it in a live preview.
local function weldAll(art: Instance, to: BasePart?)
	local parts: { BasePart } = {}
	if art:IsA("BasePart") then
		table.insert(parts, art)
	end
	for _, descendant in art:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	for _, piece in parts do
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		if to ~= nil then
			piece.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = piece
			weld.Part1 = to
			weld.Parent = piece
		end
	end
end

-- What `old` was welded to (a Weld/Motor/WeldConstraint inside it, or one naming it from elsewhere in `scope`).
local function weldTarget(old: BasePart, scope: Instance): BasePart?
	for _, joint in scope:GetDescendants() do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			local a: BasePart? = if joint:IsA("JointInstance") then joint.Part0 else joint.Part0
			local b: BasePart? = if joint:IsA("JointInstance") then joint.Part1 else joint.Part1
			if a == old and b ~= nil then
				return b
			elseif b == old and a ~= nil then
				return a
			end
		end
	end
	return nil
end

-- The scale the server wore `model` at (VacuumConstants.MOUNT.scaleAttribute), else its own Model scale.
local function scaleOf(model: Model): number
	local recorded = model:GetAttribute(MOUNT.scaleAttribute)
	return if type(recorded) == "number" then recorded else model:GetScale()
end

-- Stretches a model's parts about its pivot (x across, y up, z through), as the server stretched the straps it wore.
local function stretch(model: Model, by: Vector3)
	if by == Vector3.one then
		return
	end
	local pivot = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(part.CFrame)
			part.Size *= by
			part.CFrame = pivot * CFrame.new(rel.Position * by) * rel.Rotation
		end
	end
end

-- Puts `copy` where `old` was, welded to `to`, and removes `old`. Attachments something else uses (the hose's mount
-- at the outlet) move to `to`, where they were in the world.
local function takeOver(old: Model, copy: Model, to: BasePart?)
	copy.Name = old.Name
	weldAll(copy, to)
	copy.Parent = old.Parent
	if to ~= nil then
		for _, descendant in old:GetDescendants() do
			if descendant:IsA("Attachment") and descendant.Name ~= MOUNT.plateName then
				local world = descendant.WorldCFrame
				descendant.Parent = to
				descendant.WorldCFrame = world
			end
		end
	end
	old:Destroy()
end

-- Replaces the worn pack `old` with a copy of the skin's `from`, at the scale it was worn at, its mount plate
-- exactly where the old one met the back (VacuumMountSystem: any skin's plate on the wearer's back attachment). The
-- gauge shows what the old one showed (empty in a fresh pack), not the template's full dust insert.
local function replacePack(old: Model, from: Model, to: BasePart?)
	local copy = from:Clone()
	local scale = scaleOf(old)
	copy:ScaleTo(scale)
	copy:SetAttribute(MOUNT.scaleAttribute, scale)
	local oldPlate = VacuumMountSystem.plateOf(old)
	local meet = if oldPlate ~= nil then oldPlate.WorldCFrame else old:GetPivot()
	copy:PivotTo(VacuumMountFormulas.pivotFor(meet, VacuumMountSystem.plateFrame(copy)))
	local oldFill, newFill =
		basePart(old, VacuumConstants.GAUGE_FILL_NAME), basePart(copy, VacuumConstants.GAUGE_FILL_NAME)
	if oldFill ~= nil and newFill ~= nil then
		newFill.Transparency = oldFill.Transparency
	end
	takeOver(old, copy, to)
end

-- Replaces the worn straps `old` with a copy of the skin's `from`, scaled and stretched as the server fitted them.
local function replaceStraps(old: Model, from: Model, to: BasePart?)
	local copy = from:Clone()
	copy:ScaleTo(scaleOf(old))
	local by = old:GetAttribute(MOUNT.stretchAttribute)
	stretch(copy, if typeof(by) == "Vector3" then by else Vector3.one)
	copy:PivotTo(old:GetPivot())
	takeOver(old, copy, to)
end

function VacuumPreviewSystem.swap(character: Model, skin: SkinDef, source: Instance): boolean
	local backpack = character:FindFirstChild(VacuumConstants.BACKPACK_NAME)
	if backpack == nil or backpack:GetAttribute("VacuumSkin") == skin.name then
		return false
	end
	local template = templateOf(skin, source)
	if template == nil then
		return false
	end
	local anchor = basePart(backpack, "PackAnchor")
	local torso = basePart(character, "UpperTorso")
	local pack, newPack = modelChild(backpack, "Pack"), modelChild(template, "Backpack")
	if pack ~= nil and newPack ~= nil then
		replacePack(pack, newPack, anchor)
	end
	local straps, newStraps = modelChild(backpack, "Straps"), modelChild(template, "Straps")
	if straps ~= nil and newStraps ~= nil then
		replaceStraps(straps, newStraps, torso)
	end
	local stowed, wand = modelChild(backpack, "StowedWand"), modelChild(template, "Wand")
	if stowed ~= nil and wand ~= nil then
		for _, old in stowed:GetChildren() do
			local from = if old:IsA("BasePart") then basePart(wand, old.Name) else nil
			if old:IsA("BasePart") and from ~= nil then
				local copy = from:Clone()
				copy.Size = old.Size
				copy.CFrame = old.CFrame
				-- Attachments (the hose inlet, the grips) stay with the piece they belong to.
				for _, child in old:GetChildren() do
					if child:IsA("Attachment") then
						child.Parent = copy
					end
				end
				weldAll(copy, weldTarget(old, backpack) or anchor)
				copy.Parent = stowed
				old:Destroy()
			end
		end
	end
	local hose = backpack:FindFirstChildOfClass("Beam")
	if hose ~= nil then
		hose.Texture = skin.hoseTexture
	end
	backpack:SetAttribute("VacuumSkin", skin.name)
	return true
end

function VacuumPreviewSystem.alone(skin: SkinDef, source: Instance): Model?
	local template = templateOf(skin, source)
	local pack = if template ~= nil then modelChild(template, "Backpack") else nil
	if pack == nil then
		return nil
	end
	local copy = pack:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	return copy
end

return VacuumPreviewSystem
