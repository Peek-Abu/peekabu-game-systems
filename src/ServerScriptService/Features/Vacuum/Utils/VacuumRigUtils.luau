--!strict
--[=[
	VacuumRigUtils: what the vacuum needs to know about the body holding it, read from its rig (split out of
	VacuumVisualSystem, which builds and wears the vacuum from these answers). It remembers nothing and changes
	nothing.

	- `arm`: an arm's shoulder (at the rig's rest pose) and its reach, for the hold (VacuumHoldFormulas.hold).
	- `wrapOf`: where a paw closes round the wand.
	- `hipInTorso`: the right hip in the torso's space, where the stowed wand's floor head hangs.
	- `fitOf`: where the backpack sits and at what scale (the employee's registry fit, else one from the torso).

	@class VacuumRigUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local Constants = require(ServerScriptService.Features.Vacuum.Data.VacuumVisualConstants)
local VacuumHoldFormulas = require(ServerScriptService.Features.Vacuum.Utils.VacuumHoldFormulas)
local AnimationCarryMeasureSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarryMeasureSystem)

local VacuumRigUtils = {}

local function attachmentOf(model: Model, partName: string, name: string): Attachment?
	local part = model:FindFirstChild(partName)
	local found = if part ~= nil then part:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function span(model: Model, partName: string, from: string, to: string): number?
	local a, b = attachmentOf(model, partName, from), attachmentOf(model, partName, to)
	return if a ~= nil and b ~= nil then (a.Position - b.Position).Magnitude else nil
end

--[=[
	The right hip joint in `torso`'s space at the rig's rest pose (the Waist joint's C0 / C1, not an animated
	frame), or the root's centre (live) on a rig without one, else the torso's bottom.
]=]
function VacuumRigUtils.hipInTorso(character: Model, torso: BasePart): Vector3
	local waist: Motor6D? = nil
	for _, child in torso:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == torso and child.Part0 ~= nil then
			waist = child
			break
		end
	end
	if waist ~= nil and waist.Part0 ~= nil then
		local hip = waist.Part0:FindFirstChild("RightHipRigAttachment")
		if hip ~= nil and hip:IsA("Attachment") then
			-- torso = lower * C0 * C1:Inverse(), so lower in torso space is C1 * C0:Inverse().
			return (waist.C1 * waist.C0:Inverse()) * hip.Position
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return torso.CFrame:PointToObjectSpace(root.Position)
	end
	return Vector3.new(0, -torso.Size.Y / 2, 0)
end

--[=[
	`side` ("Left"/"Right") arm of `character` in HumanoidRootPart space, from its rig attachments (its reach to the
	paw's wrap point, VacuumRigUtils.wrapOf, and that point in the grip attachment's space), with the shoulder
	where it is at the rig's REST pose (its joint chain without the animation's Transforms,
	AnimationCarryMeasureSystem.restFrame), so the hold never depends on the pose of the moment it is planned in. The
	Tool is made as a shift starts, mid-stride or while the crew is placed in the truck: read live, Pippa's shoulders
	were once measured 0.43 stud forward of rest, the left hand's target lay out of her reach, and that arm hung at
	full stretch, swaying with the idle, 0.21-0.30 stud off the wand. Nil when the rig lacks the attachments.
]=]
function VacuumRigUtils.arm(character: Model, side: string): VacuumHoldFormulas.Arm?
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso")
	local shoulder = attachmentOf(character, "UpperTorso", side .. "ShoulderRigAttachment")
	local upper = span(character, side .. "UpperArm", side .. "ShoulderRigAttachment", side .. "ElbowRigAttachment")
	local lower = span(character, side .. "LowerArm", side .. "ElbowRigAttachment", side .. "WristRigAttachment")
	local wrap = VacuumRigUtils.wrapOf(character, side)
	local wrist = attachmentOf(character, side .. "Hand", side .. "WristRigAttachment")
	local grip = attachmentOf(character, side .. "Hand", side .. "GripAttachment")
	if
		root == nil
		or not root:IsA("BasePart")
		or torso == nil
		or not torso:IsA("BasePart")
		or shoulder == nil
		or upper == nil
		or lower == nil
		or wrap == nil
		or wrist == nil
		or grip == nil
	then
		return nil
	end
	return {
		shoulder = AnimationCarryMeasureSystem.restFrame(torso, root):PointToWorldSpace(shoulder.Position),
		upper = upper,
		lower = lower + (wrap - wrist.Position).Magnitude,
		wrap = grip.CFrame:PointToObjectSpace(wrap),
	}
end

--[=[
	Where `character`'s `side` paw holds the wand, in its hand's space: Constants.WRAP of the way from its wrist to
	its grip attachment (VacuumHoldFormulas.Arm.wrap). Nil without both attachments.
]=]
function VacuumRigUtils.wrapOf(character: Model, side: string): Vector3?
	local wrist = attachmentOf(character, side .. "Hand", side .. "WristRigAttachment")
	local grip = attachmentOf(character, side .. "Hand", side .. "GripAttachment")
	if wrist == nil or grip == nil then
		return nil
	end
	return wrist.Position:Lerp(grip.Position, Constants.WRAP)
end

--[=[
	Where `character`'s backpack sits and the scale its fit is in: the employee's registry fit at the
	employee's scale, else one fitted from its UpperTorso's size (scale 1).
]=]
function VacuumRigUtils.fitOf(character: Model?): (EmployeeRegistry.BackpackFit, number)
	local name = if character ~= nil then character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	local def = if type(name) == "string" then EmployeeRegistry.get(name) else nil
	if def ~= nil and def.backpack ~= nil then
		return def.backpack, def.scale
	end
	local torso = if character ~= nil then character:FindFirstChild("UpperTorso") else nil
	local size = if torso ~= nil and torso:IsA("BasePart")
		then torso.Size
		else Constants.REFERENCE_TORSO * Constants.GENERIC_SIZE
	return VacuumHoldFormulas.genericFit(size, Constants.REFERENCE_TORSO, Constants.STRAP_DEPTH, Constants.GENERIC_SIZE),
		1
end

return VacuumRigUtils
