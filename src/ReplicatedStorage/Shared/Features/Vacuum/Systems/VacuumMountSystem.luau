--!strict
--[=[
	VacuumMountSystem: the two Attachments a back-worn vacuum is joined by (VacuumMountFormulas), on server and
	client alike.

	- `plateOf(pack)`: the pack's mount plate (VacuumConstants.MOUNT.plateName): a skin's own when it authored one,
	  else one made on its `BackPad` at the middle of the pad's front face. It rides the pack, so it scales with
	  Model:ScaleTo. `plateFrame(pack)` is where it is in the pack's pivot space.
	- `seat(character, torso, mount, half, skip)`: the wearer's back attachment (MOUNT.backName on the UpperTorso),
	  at `mount`'s height and side, on the surface of whatever the body wears over its back under the pad: the
	  torso, a hoodie, a coat (`measure`). Seated again it moves (a new outfit).
	- `measure`: rays from behind over the pad's footprint, in torso space, against the body: every part of the
	  character but its root, head, limbs, what is worn on its head and `skip` (the pack itself, a Tool). Worn pieces
	  turn queries off (EmployeeGearSystem, EmployeeOutfitSystem), so each is let be hit for the measurement only and
	  turned back within the same call (nothing yields between: no frame ever sees the change).

	@class VacuumMountSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumMountFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMountFormulas)

local MOUNT = VacuumConstants.MOUNT

-- The R15 parts that are never the back under a pack (the limbs swing behind it; the head sits above it).
local NOT_BACK: { [string]: true } = {
	HumanoidRootPart = true,
	Head = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local VacuumMountSystem = {}

local function findAttachment(root: Instance, name: string): Attachment?
	local found = root:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

function VacuumMountSystem.plateOf(pack: Model): Attachment?
	local authored = findAttachment(pack, MOUNT.plateName)
	if authored ~= nil then
		return authored
	end
	local pad = pack:FindFirstChild("BackPad", true)
	if pad == nil or not pad:IsA("BasePart") then
		return nil
	end
	local plate = Instance.new("Attachment")
	plate.Name = MOUNT.plateName
	-- In the pad's own space: the middle of its front face.
	plate.CFrame = VacuumMountFormulas.plateFrame(CFrame.identity, pad.Size)
	plate.Parent = pad
	return plate
end

function VacuumMountSystem.plateFrame(pack: Model): CFrame
	local plate = VacuumMountSystem.plateOf(pack)
	return if plate ~= nil then pack:GetPivot():ToObjectSpace(plate.WorldCFrame) else CFrame.identity
end

-- Every part jointed or welded to the head (hair, ears, hats: hanging down the back, they are not the back), the
-- joint in either part.
local function headPieces(character: Model, head: Instance?): { [BasePart]: true }
	local pieces: { [BasePart]: true } = {}
	if head == nil then
		return pieces
	end
	for _, joint in character:GetDescendants() do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			local a: BasePart?, b: BasePart? = joint.Part0, joint.Part1
			if a == head and b ~= nil then
				pieces[b] = true
			elseif b == head and a ~= nil then
				pieces[a] = true
			end
		end
	end
	return pieces
end

local function skipped(part: BasePart, skip: { Instance }): boolean
	for _, instance in skip do
		if part == instance or part:IsDescendantOf(instance) then
			return true
		end
	end
	return false
end

function VacuumMountSystem.measure(
	character: Model,
	torso: BasePart,
	mount: CFrame,
	half: Vector2,
	skip: { Instance }
): { number }
	local onHead = headPieces(character, character:FindFirstChild("Head"))
	-- The neck joins the head to the torso: the torso is still the back.
	onHead[torso] = nil
	local body: { Instance } = {}
	local wasOff: { BasePart } = {}
	for _, descendant in character:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and not NOT_BACK[descendant.Name]
			and not descendant:FindFirstAncestorOfClass("Tool")
			and not skipped(descendant, skip)
			and not onHead[descendant]
		then
			table.insert(body, descendant)
			if not descendant.CanQuery then
				table.insert(wasOff, descendant)
			end
		end
	end
	if #body == 0 then
		return {}
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = body
	local from = torso.Size.Z * 2
	local depths: { number } = {}
	for _, part in wasOff do
		part.CanQuery = true
	end
	for _, origin in VacuumMountFormulas.rays(Vector2.new(mount.X, mount.Y), half, MOUNT.cols, MOUNT.rows, from) do
		local start = torso.CFrame:PointToWorldSpace(origin)
		local direction = torso.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -from * 2))
		local hit = Workspace:Raycast(start, direction, params)
		if hit ~= nil then
			table.insert(depths, torso.CFrame:PointToObjectSpace(hit.Position).Z)
		end
	end
	for _, part in wasOff do
		part.CanQuery = false
	end
	return depths
end

function VacuumMountSystem.seat(
	character: Model,
	torso: BasePart,
	mount: CFrame,
	half: Vector2,
	skip: { Instance }
): Attachment
	local depths = VacuumMountSystem.measure(character, torso, mount, half, skip)
	local maxDepth = torso.Size.Z * MOUNT.maxDepth
	local depth = if #depths > 0
		then VacuumMountFormulas.backDepth(depths, mount.Z, 0, maxDepth) + MOUNT.clearance
		else mount.Z
	local back = torso:FindFirstChild(MOUNT.backName)
	local attachment: Attachment
	if back ~= nil and back:IsA("Attachment") then
		attachment = back
	else
		attachment = Instance.new("Attachment")
		attachment.Name = MOUNT.backName
		attachment.Parent = torso
	end
	attachment.CFrame = VacuumMountFormulas.backFrame(mount, depth)
	return attachment
end

return VacuumMountSystem
