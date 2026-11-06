--!strict
--[=[
	EmployeeOutfitSystem: fits a skin's skinned outfit (a Model under EmployeeConstants.OUTFITS_PATH, named by the
	SkinDef's `outfit`) onto a character. The server fits it as it dresses a spawned character, so every client sees it
	through normal replication; a client fits its own preview models the same way.

	The outfit is authored at the template's size (the contract is in EmployeeConstants): skinned meshes, a Rig of
	placeholder Parts holding each body part's Bones, Styles of SurfaceAppearances and emote Props. Fitting:
	- Bones: each placeholder's Bones are cloned under the character's body part of the same name, their offset scaled
	  by the character's scale (EmployeeOutfitFormulas). A Bone under a body part rides its Motor6D, so the skinned
	  meshes follow the animation.
	- Meshes: cloned into a Folder (EmployeeConstants.OUTFIT_FOLDER) directly under the character, sized and placed
	  from LowerTorso's rest, and welded to LowerTorso. Both rules were found in Play (2026-10-29): in a sub-Model the
	  meshes do not find the Bones, and welded to HumanoidRootPart they stay rigid.
	- Style: each mesh wears the style folder's SurfaceAppearance named by its StyleSlot attribute, each prop the one
	  named after the prop; an unknown style keeps the outfit's own looks.
	- Props: cloned into EmployeeConstants.PROPS_FOLDER, hidden (Transparency 1: the emote shows them), on their
	  Motor6D from the hand its `Hand` attribute names, with C0/C1 scaled. A prop whose hand is missing is skipped.
	- Worn props: a prop with a `Holster` body part and `HolsterOffset` frame also gets a shown twin in
	  EmployeeConstants.HOLSTER_FOLDER, welded there at the scaled offset (the duck ring at the waist, the hose on the
	  hip). The emote hides it while the hand copy shows.
	- Covering: the body parts and template pieces or Accessories the outfit's HideParts / HideAccessories attributes
	  name are made invisible.
	A second fit replaces the first. An outfit missing its meshes or Rig, an outfit whose Bone is named like a body part
	(every clip posing that part would drive the Bone too, rotating the coat twice), or a character missing LowerTorso's
	Root joint or a body part the Rig needs, is refused before anything changes. The source outfit is never changed.

	@class EmployeeOutfitSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeOutfitFormulas)

local EmployeeOutfitSystem = {}

-- LowerTorso's Root joint: the meshes are placed from its rest, so the animated pose at fit time does not matter.
local function rootJoint(lower: BasePart): (Motor6D?, BasePart?)
	for _, child in lower:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == lower then
			local part0 = child.Part0
			if part0 ~= nil then
				return child, part0
			end
		end
	end
	return nil, nil
end

local function bodyPart(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

-- The comma-separated names in one of the outfit's attributes, trimmed.
local function names(outfit: Model, attribute: string): { string }
	local value = outfit:GetAttribute(attribute)
	local out = {}
	if type(value) == "string" then
		for name in string.gmatch(value, "[^,]+") do
			local trimmed = string.match(name, "^%s*(.-)%s*$")
			if trimmed ~= nil and trimmed ~= "" then
				table.insert(out, trimmed)
			end
		end
	end
	return out
end

-- Puts the style folder's SurfaceAppearance `look` on `part` in place of its own; nothing without one.
local function restyle(part: BasePart, styleFolder: Instance?, look: string?)
	if styleFolder == nil or look == nil then
		return
	end
	local source = styleFolder:FindFirstChild(look)
	if source == nil or not source:IsA("SurfaceAppearance") then
		return
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	local copy = source:Clone()
	copy.Name = "SurfaceAppearance"
	copy.Parent = part
end

local function weightless(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

local function hide(root: Instance)
	local parts: { Instance } = root:GetDescendants()
	table.insert(parts, root)
	for _, item in parts do
		if item:IsA("BasePart") then
			item.Transparency = 1
		end
	end
end

-- A hidden copy of the hand prop `prop` on its Motor6D from the hand its `Hand` attribute names, C0/C1 and size scaled,
-- in the style folder's look; nil without a Motor6D or that hand. Unparented.
local function mountProp(character: Model, prop: BasePart, scale: number, styleFolder: Instance?): BasePart?
	local joint = prop:FindFirstChildOfClass("Motor6D")
	local handName = if joint ~= nil then joint:GetAttribute(EmployeeConstants.PROP_HAND_ATTRIBUTE) else nil
	local hand = if type(handName) == "string" then bodyPart(character, handName) else nil
	if joint == nil or hand == nil then
		return nil
	end
	local copy = prop:Clone()
	local copyJoint = copy:FindFirstChildOfClass("Motor6D")
	if copyJoint == nil then
		copy:Destroy()
		return nil
	end
	local c0, c1 = EmployeeOutfitFormulas.joint(joint.C0, joint.C1, scale)
	copy.Size = prop.Size * scale
	copy.CFrame = EmployeeOutfitFormulas.rest(hand.CFrame, c0, c1)
	weightless(copy)
	copy.Transparency = 1
	restyle(copy, styleFolder, prop.Name)
	copyJoint.Part0 = hand
	copyJoint.Part1 = copy
	copyJoint.C0 = c0
	copyJoint.C1 = c1
	return copy
end

-- Removes an earlier fit: the outfit and props folders, and the Bones it added.
local function unfit(character: Model)
	for _, child in character:GetChildren() do
		if
			child:IsA("Folder")
			and (
				child.Name == EmployeeConstants.OUTFIT_FOLDER
				or child.Name == EmployeeConstants.PROPS_FOLDER
				or child.Name == EmployeeConstants.HOLSTER_FOLDER
			)
		then
			child:Destroy()
		end
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Bone") and descendant:GetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE) == true then
			descendant:Destroy()
		end
	end
end

--[=[
	Fits `outfit` onto `character` in style `style` (a folder name under the outfit's Styles; nil or unknown keeps the
	outfit's own looks). Returns false, changing nothing, when the outfit or the character is incomplete (see the
	header).
]=]
function EmployeeOutfitSystem.fit(character: Model, outfit: Model, style: string?): boolean
	local meshes = outfit:FindFirstChild(EmployeeConstants.OUTFIT_MESHES)
	local rig = outfit:FindFirstChild(EmployeeConstants.OUTFIT_RIG)
	local lower = bodyPart(character, "LowerTorso")
	if meshes == nil or rig == nil or lower == nil then
		return false
	end
	local root, part0 = rootJoint(lower)
	local rigLower = rig:FindFirstChild("LowerTorso")
	if root == nil or part0 == nil or rigLower == nil or not rigLower:IsA("BasePart") then
		return false
	end
	for _, holder in rig:GetChildren() do
		if bodyPart(character, holder.Name) == nil then
			return false
		end
		-- A Bone named like a body part is driven by every clip that poses that part (the Animator animates Bones by
		-- name), on top of the part carrying it: the coat double-rotates (the stock jump, found in Play 2026-10-29).
		for _, bone in holder:GetChildren() do
			if bone:IsA("Bone") and bodyPart(character, bone.Name) ~= nil then
				return false
			end
		end
	end

	unfit(character)
	local scale = character:GetScale()
	local stylesFolder = outfit:FindFirstChild(EmployeeConstants.OUTFIT_STYLES)
	local styleFolder = if style ~= nil and stylesFolder ~= nil then stylesFolder:FindFirstChild(style) else nil

	for _, holder in rig:GetChildren() do
		local target = bodyPart(character, holder.Name)
		for _, bone in holder:GetChildren() do
			if target ~= nil and bone:IsA("Bone") then
				local copy = bone:Clone()
				copy.CFrame = EmployeeOutfitFormulas.scaled(bone.CFrame, scale)
				copy:SetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE, true)
				copy.Parent = target
			end
		end
	end

	local rest = EmployeeOutfitFormulas.rest(part0.CFrame, root.C0, root.C1)
	local folder = Instance.new("Folder")
	folder.Name = EmployeeConstants.OUTFIT_FOLDER
	for _, mesh in meshes:GetChildren() do
		if mesh:IsA("BasePart") then
			local copy = mesh:Clone()
			copy.Size = mesh.Size * scale
			copy.CFrame = EmployeeOutfitFormulas.place(rest, rigLower.CFrame, mesh.CFrame, scale)
			weightless(copy)
			local slot = mesh:GetAttribute(EmployeeConstants.STYLE_SLOT_ATTRIBUTE)
			restyle(copy, styleFolder, if type(slot) == "string" then slot else nil)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = lower
			weld.Part1 = copy
			weld.Parent = copy
			copy.Parent = folder
		end
	end
	folder.Parent = character

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = EmployeeConstants.PROPS_FOLDER
	local holsterFolder = Instance.new("Folder")
	holsterFolder.Name = EmployeeConstants.HOLSTER_FOLDER
	local props = outfit:FindFirstChild(EmployeeConstants.OUTFIT_PROPS)
	if props ~= nil then
		for _, prop in props:GetChildren() do
			local holsterName = prop:GetAttribute(EmployeeConstants.PROP_HOLSTER_ATTRIBUTE)
			local offset = prop:GetAttribute(EmployeeConstants.PROP_HOLSTER_OFFSET_ATTRIBUTE)
			local holster = if type(holsterName) == "string" then bodyPart(character, holsterName) else nil
			if prop:IsA("BasePart") and holster ~= nil and typeof(offset) == "CFrame" then
				local worn = prop:Clone()
				for _, child in worn:GetChildren() do
					if child:IsA("JointInstance") then
						child:Destroy()
					end
				end
				local c0 = EmployeeOutfitFormulas.scaled(offset, scale)
				worn.Size = prop.Size * scale
				worn.CFrame = holster.CFrame * c0
				weightless(worn)
				worn.Transparency = 0
				restyle(worn, styleFolder, prop.Name)
				local weld = Instance.new("Weld")
				weld.Part0 = holster
				weld.Part1 = worn
				weld.C0 = c0
				weld.Parent = worn
				worn.Parent = holsterFolder
			end
			local copy = if prop:IsA("BasePart") then mountProp(character, prop, scale, styleFolder) else nil
			if copy ~= nil then
				copy.Parent = propsFolder
			end
		end
	end
	propsFolder.Parent = character
	holsterFolder.Parent = character

	for _, name in names(outfit, EmployeeConstants.HIDE_PARTS_ATTRIBUTE) do
		local covered = bodyPart(character, name)
		if covered ~= nil then
			covered.Transparency = 1
		end
	end
	EmployeeOutfitSystem.hidePieces(character, names(outfit, EmployeeConstants.HIDE_ACCESSORIES_ATTRIBUTE))
	return true
end

--[=[
	Hides each of `character`'s own pieces named in `pieceNames`: a child of its EmployeeConstants.PIECES_FOLDER, else an
	Accessory on the character; a missing name is skipped. An outfit's HideAccessories and a skin's `hidePieces` use it.
]=]
function EmployeeOutfitSystem.hidePieces(character: Model, pieceNames: { string })
	local pieces = character:FindFirstChild(EmployeeConstants.PIECES_FOLDER)
	for _, name in pieceNames do
		local piece = if pieces ~= nil then pieces:FindFirstChild(name) else nil
		local accessory = character:FindFirstChild(name)
		if piece ~= nil then
			hide(piece)
		elseif accessory ~= nil and accessory:IsA("Accessory") then
			hide(accessory)
		end
	end
end

--[=[
	A hidden copy of the hand prop `prop` (a BasePart with a Motor6D whose `Hand` attribute names a body part) mounted on
	`character` at its scale, in `styleFolder`'s look (nil keeps its own), unparented: the caller parents it. Nil when
	the prop has no Motor6D or the character lacks that hand. EmotePropSystem mounts an emote's own props with it.
]=]
function EmployeeOutfitSystem.mountProp(character: Model, prop: BasePart, styleFolder: Instance?): BasePart?
	return mountProp(character, prop, character:GetScale(), styleFolder)
end

--[=[
	Whether `part` is one of the outfit pieces fitted onto `character` (a mesh or a prop, or an emote's own mounted prop):
	the body palette skips them.
]=]
function EmployeeOutfitSystem.isOutfitPart(character: Model, part: Instance): boolean
	for _, name in
		{
			EmployeeConstants.OUTFIT_FOLDER,
			EmployeeConstants.PROPS_FOLDER,
			EmployeeConstants.HOLSTER_FOLDER,
			EmployeeConstants.EMOTE_MOUNTED_FOLDER,
		}
	do
		local folder = character:FindFirstChild(name)
		if folder ~= nil and folder:IsA("Folder") and part:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

return EmployeeOutfitSystem
