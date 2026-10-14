--!strict
-- Server-created native IK targets replicate; each Animator evaluates only arm chains.
-- Native AnimationConstraint support verified in Studio: 2-chain,1.643stud span,
-- hand target error .000127stud. No C0/C1/RigAttachment/Transform writes occur here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local AnimationCarryContactUtils = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
export type Controller = { destroy: () -> () }
export type Prepared = { pivot: CFrame, layout: AnimationCarryContactUtils.Layout }
local AnimationCarrySystem = {}
local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end
local function attachment(bodyPart: BasePart, name: string): Attachment?
	local found = bodyPart:FindFirstChild(name)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end
-- Shoulder (root space) and reach from the shoulder to the palm point the IK end effector drives (the arm's
-- two spans plus wrist to palm), read from the rig attachments so any scale or proportion is measured.
local function arm(character: Model, side: string, root: BasePart): (Vector3?, number?)
	local upper = part(character, side .. "UpperArm")
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	if upper == nil or lower == nil or hand == nil then
		return nil, nil
	end
	local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
	local elbow = attachment(upper, side .. "ElbowRigAttachment")
	local lowerElbow = attachment(lower, side .. "ElbowRigAttachment")
	local wrist = attachment(lower, side .. "WristRigAttachment")
	local handWrist = attachment(hand, side .. "WristRigAttachment")
	if shoulder == nil or elbow == nil or lowerElbow == nil or wrist == nil or handWrist == nil then
		return nil, nil
	end
	local palm = (Vector3.new(0, -hand.Size.Y / 2, 0) - handWrist.Position).Magnitude
	return root.CFrame:PointToObjectSpace(shoulder.WorldPosition),
		(shoulder.WorldPosition - elbow.WorldPosition).Magnitude
			+ (lowerElbow.WorldPosition - wrist.WorldPosition).Magnitude
			+ palm
end
-- The most extreme corner of `bodyPart` along root-space `axis` (min when `sign` is -1).
local function extreme(root: BasePart, bodyPart: BasePart, axis: Vector3, sign: number): number
	local frame = root.CFrame:ToObjectSpace(bodyPart.CFrame)
	local half = bodyPart.Size / 2
	local best = -sign * math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local along = (frame * Vector3.new(x * half.X, y * half.Y, z * half.Z)):Dot(axis)
				best = if sign < 0 then math.min(best, along) else math.max(best, along)
			end
		end
	end
	return best
end
--[=[
	The carrier as AnimationCarryContactUtils sees it, in HumanoidRootPart space: shoulders and reaches, the
	torso front, the head's front and bottom, and the floor. Nil for a rig without native R15 arms, torso and head.
]=]
function AnimationCarrySystem.measure(character: Model): AnimationCarryContactUtils.Rig?
	local root = part(character, "HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upperTorso = part(character, "UpperTorso")
	local head = part(character, "Head")
	if root == nil or humanoid == nil or upperTorso == nil or head == nil then
		return nil
	end
	local left, leftReach = arm(character, "Left", root)
	local right, rightReach = arm(character, "Right", root)
	if left == nil or leftReach == nil or right == nil or rightReach == nil then
		return nil
	end
	local front = extreme(root, upperTorso, Vector3.zAxis, -1)
	local lowerTorso = part(character, "LowerTorso")
	if lowerTorso ~= nil then
		front = math.min(front, extreme(root, lowerTorso, Vector3.zAxis, -1))
	end
	return {
		leftShoulder = left,
		rightShoulder = right,
		leftReach = leftReach,
		rightReach = rightReach,
		front = front,
		headFront = extreme(root, head, Vector3.zAxis, -1),
		headBottom = extreme(root, head, Vector3.yAxis, -1),
		floor = -root.Size.Y / 2 - humanoid.HipHeight,
	}
end
function AnimationCarrySystem.prepare(
	character: Model,
	target: PVInstance,
	kind: string,
	requestedOffset: CFrame?
): Prepared?
	local root = part(character, "HumanoidRootPart")
	local rig = AnimationCarrySystem.measure(character)
	if root == nil or rig == nil then
		return nil
	end
	local boxFrame: CFrame
	local size: Vector3
	if target:IsA("Model") then
		boxFrame, size = target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		boxFrame, size = target.CFrame, target.Size
	else
		return nil
	end
	local boxFromPivot = target:GetPivot():ToObjectSpace(boxFrame)
	local requestedBox = if requestedOffset ~= nil then requestedOffset * boxFromPivot else nil
	local plan = AnimationCarryContactUtils.plan(size, rig, AnimationCarryRegistry.get(kind), requestedBox)
	if plan == nil then
		return nil
	end
	local rightGrip = target:FindFirstChild("CarryGripRight", true)
	local leftGrip = target:FindFirstChild("CarryGripLeft", true)
	if rightGrip ~= nil and rightGrip:IsA("Attachment") then
		plan = AnimationCarryContactUtils.withGrips(
			plan,
			boxFrame:ToObjectSpace(rightGrip.WorldCFrame),
			if leftGrip ~= nil and leftGrip:IsA("Attachment") then boxFrame:ToObjectSpace(leftGrip.WorldCFrame) else nil,
			rig
		)
		if plan == nil then
			return nil
		end
	end
	local pivot = root.CFrame * plan.offset * boxFromPivot:Inverse()
	return { pivot = pivot, layout = plan }
end
-- layout contacts are relative to the carried bounding box. Caller converts them
-- to cargo-root coordinates after PivotTo; the physics weld remains server-owned.
function AnimationCarrySystem.bind(
	character: Model,
	cargoRoot: BasePart,
	layout: AnimationCarryContactUtils.Layout
): Controller?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rightUpper, rightHand = part(character, "RightUpperArm"), part(character, "RightHand")
	local leftUpper, leftHand = part(character, "LeftUpperArm"), part(character, "LeftHand")
	if
		humanoid == nil
		or humanoid.Health <= 0
		or rightUpper == nil
		or rightHand == nil
		or (layout.left ~= nil and (leftUpper == nil or leftHand == nil))
	then
		return nil
	end
	local controls: { IKControl } = {}
	local targets: { Attachment } = {}
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local function add(side: string, upper: BasePart, hand: BasePart, contact: CFrame)
		local target = Instance.new("Attachment")
		target.Name = "CleanupCarryGrip" .. side
		target.CFrame = contact
		target.Parent = cargoRoot
		table.insert(targets, target)
		local control = Instance.new("IKControl")
		control.Name = "CleanupCarryIK" .. side
		control.Type = Enum.IKControlType.Transform
		control.ChainRoot = upper
		control.EndEffector = hand
		control.EndEffectorOffset = CFrame.new(0, -hand.Size.Y / 2, 0)
		control.Target = target
		control.SmoothTime = 0.08
		control.Weight = 1
		control.Priority = 20
		control.Parent = humanoid
		table.insert(controls, control)
	end
	add("Right", rightUpper, rightHand, layout.right)
	if layout.left ~= nil then
		add("Left", leftUpper, leftHand, layout.left)
	end
	local controller: Controller = {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for _, control in controls do
				control:Destroy()
			end
			for _, target in targets do
				target:Destroy()
			end
			table.clear(controls)
			table.clear(targets)
		end,
	}
	table.insert(connections, cargoRoot.Destroying:Connect(controller.destroy))
	table.insert(connections, character.Destroying:Connect(controller.destroy))
	table.insert(connections, humanoid.Died:Connect(controller.destroy))
	table.insert(connections, humanoid.Destroying:Connect(controller.destroy))
	return controller
end
return AnimationCarrySystem
