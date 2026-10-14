--!strict
-- Server-created native IK targets replicate; each Animator evaluates only arm chains.
-- Native AnimationConstraint support verified in Studio: 2-chain,1.643stud span,
-- hand target error .000127stud. No C0/C1/RigAttachment/Transform writes occur here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCarryRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local AnimationCarryContactUtils = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
export type Controller = { destroy: () -> () }
-- `box` is the visible box relative to the item's pivot; `layout`'s contacts are relative to it.
export type Prepared = { pivot: CFrame, box: CFrame, layout: AnimationCarryContactUtils.Layout }
local AnimationCarrySystem = {}
-- Where an under-the-item hold bends each elbow toward, from its shoulder in root space, in upper arms (X is
-- outward): down, a little out and behind.
local POLE = Vector3.new(0.4, -2, 1)
local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end
local function attachment(bodyPart: BasePart, name: string): Attachment?
	local found = bodyPart:FindFirstChild(name)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end
-- The part's rest orientation relative to the root: its Motor6D chain (C0 * C1:Inverse()) without the
-- animation's Transforms. Identity when the chain does not reach the root.
local function restOf(bodyPart: BasePart, root: BasePart): CFrame
	local rest = CFrame.identity
	local current = bodyPart
	for _ = 1, 8 do
		if current == root then
			return rest.Rotation
		end
		local motor: Motor6D? = nil
		for _, child in current:GetChildren() do
			if child:IsA("Motor6D") and child.Part1 == current then
				motor = child
				break
			end
		end
		if motor == nil or motor.Part0 == nil then
			return CFrame.identity
		end
		rest = motor.C0 * motor.C1:Inverse() * rest
		current = motor.Part0
	end
	return CFrame.identity
end
--[=[
	`side`'s palm frame in its hand's space (AnimationCarryContactUtils.palmFrame): the fingers point from the
	wrist to the hand's grip (or its middle), the palm is the side facing the body at rest. Nil without the arm.
]=]
function AnimationCarrySystem.palmOf(character: Model, side: string): CFrame?
	local root = part(character, "HumanoidRootPart")
	local hand = part(character, side .. "Hand")
	if root == nil or hand == nil then
		return nil
	end
	local wrist = attachment(hand, side .. "WristRigAttachment")
	if wrist == nil then
		return nil
	end
	local grip = attachment(hand, side .. "GripAttachment")
	local fingers = (if grip ~= nil then grip.Position else Vector3.zero) - wrist.Position
	if fingers.Magnitude < 1e-3 then
		return nil
	end
	return AnimationCarryContactUtils.palmFrame(
		fingers,
		restOf(hand, root),
		if side == "Right" then 1 else -1,
		hand.Size
	)
end
-- Shoulder (root space), reach from the shoulder to the hand's end (the arm's two spans plus wrist to the end),
-- to the palm's centre, and the hand's length along its fingers, read from the rig so any scale or proportion
-- is measured.
local function arm(character: Model, side: string, root: BasePart): (Vector3?, number?, number?, number?)
	local upper = part(character, side .. "UpperArm")
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	if upper == nil or lower == nil or hand == nil then
		return nil, nil, nil, nil
	end
	local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
	local elbow = attachment(upper, side .. "ElbowRigAttachment")
	local lowerElbow = attachment(lower, side .. "ElbowRigAttachment")
	local wrist = attachment(lower, side .. "WristRigAttachment")
	local handWrist = attachment(hand, side .. "WristRigAttachment")
	local palmFrame = AnimationCarrySystem.palmOf(character, side)
	if shoulder == nil or elbow == nil or lowerElbow == nil or wrist == nil or handWrist == nil or palmFrame == nil then
		return nil, nil, nil, nil
	end
	local spans = (shoulder.WorldPosition - elbow.WorldPosition).Magnitude
		+ (lowerElbow.WorldPosition - wrist.WorldPosition).Magnitude
	local along = palmFrame.LookVector
	return root.CFrame:PointToObjectSpace(shoulder.WorldPosition),
		spans + (Vector3.new(0, -hand.Size.Y / 2, 0) - handWrist.Position).Magnitude,
		spans + (palmFrame.Position - handWrist.Position).Magnitude,
		math.abs(along.X) * hand.Size.X + math.abs(along.Y) * hand.Size.Y + math.abs(along.Z) * hand.Size.Z
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
	local left, leftReach, leftPalm, leftHand = arm(character, "Left", root)
	local right, rightReach, rightPalm, rightHand = arm(character, "Right", root)
	if
		left == nil
		or leftReach == nil
		or leftPalm == nil
		or leftHand == nil
		or right == nil
		or rightReach == nil
		or rightPalm == nil
		or rightHand == nil
	then
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
		leftPalmReach = leftPalm,
		rightPalmReach = rightPalm,
		handLength = math.min(leftHand, rightHand),
	}
end
-- The box around `parts`, axis-aligned in `frame`: its centre (in `frame`) and size. Nil for no parts.
local function boundsIn(frame: CFrame, parts: { BasePart }): (Vector3?, Vector3?)
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	for _, bodyPart in parts do
		local relative = frame:ToObjectSpace(bodyPart.CFrame)
		local half = bodyPart.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = relative * Vector3.new(x * half.X, y * half.Y, z * half.Z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	if #parts == 0 then
		return nil, nil
	end
	return (low + high) / 2, high - low
end
--[=[
	The box a carrier's hands go around: the item's VISIBLE parts (Transparency below 1), axis-aligned in the
	item's pivot frame, as (box relative to the pivot, size). Cargo is an invisible size-class proxy with its art
	(ArtVisualSystem's `ArtVisual`) uniformly fitted inside it and standing on its floor, so the art is up to
	1.5 studs shorter and 0.9 shallower than the proxy; planning on the proxy put the hands in empty air and the
	art out of reach of the belly. With nothing visible (a hidden item), the whole item.
]=]
function AnimationCarrySystem.visibleBox(target: PVInstance): (CFrame, Vector3)
	local pivot = target:GetPivot()
	local all: { BasePart } = {}
	local visible: { BasePart } = {}
	local candidates: { Instance } = target:GetDescendants()
	table.insert(candidates, target)
	for _, candidate in candidates do
		if candidate:IsA("BasePart") then
			table.insert(all, candidate)
			if candidate.Transparency < 1 then
				table.insert(visible, candidate)
			end
		end
	end
	local centre, size = boundsIn(pivot, if #visible > 0 then visible else all)
	if centre == nil or size == nil then
		return CFrame.identity, Vector3.zero
	end
	return CFrame.new(centre), size
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
	local boxFromPivot, size = AnimationCarrySystem.visibleBox(target)
	local boxFrame = target:GetPivot() * boxFromPivot
	local requestedBox = if requestedOffset ~= nil then requestedOffset * boxFromPivot else nil
	-- Authored on the art: the point held against the body (CarryBodyFront: a pot's front under leaves wider
	-- than it), in place of the box's near face. CarryGripRight / CarryGripLeft (handles on a pot's rim) are no
	-- longer read: the hands go under the item's bottom instead.
	local bodyFront = target:FindFirstChild("CarryBodyFront", true)
	local authored: AnimationCarryContactUtils.Authored = {
		bodyZ = if bodyFront ~= nil and bodyFront:IsA("Attachment")
			then boxFrame:PointToObjectSpace(bodyFront.WorldPosition).Z
			else nil,
	}
	local style: AnimationCarryRegistry.Style = AnimationCarryRegistry.get(kind)
	local plan = AnimationCarryContactUtils.plan(size, rig, style, requestedBox, authored)
	if plan == nil then
		return nil
	end
	local pivot = root.CFrame * plan.offset * boxFromPivot:Inverse()
	return { pivot = pivot, box = boxFromPivot, layout = plan }
end
-- layout contacts are relative to the visible box (`Prepared.box`, from the item's pivot). Caller converts
-- them to cargo-root coordinates after PivotTo; the physics weld remains server-owned.
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
	local root = part(character, "HumanoidRootPart")
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
		local sign = if side == "Right" then 1 else -1
		-- Under the item, the palm frame goes to the contact (palm up, fingers forward); on the cart, the hand's
		-- end.
		local palm = if layout.under then AnimationCarrySystem.palmOf(character, side) else nil
		control.EndEffectorOffset = if palm ~= nil then palm else CFrame.new(0, -hand.Size.Y / 2, 0)
		control.Target = target
		local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
		local elbow = attachment(upper, side .. "ElbowRigAttachment")
		if layout.under and root ~= nil and shoulder ~= nil and elbow ~= nil then
			-- The elbows bend down and back by the sides, not out like wings.
			local upperArm = (shoulder.WorldPosition - elbow.WorldPosition).Magnitude
			local pole = Instance.new("Attachment")
			pole.Name = "CleanupCarryPole" .. side
			pole.Parent = cargoRoot
			pole.WorldPosition = root.CFrame:PointToWorldSpace(
				root.CFrame:PointToObjectSpace(shoulder.WorldPosition) + POLE * Vector3.new(sign, 1, 1) * upperArm
			)
			table.insert(targets, pole)
			control.Pole = pole
		end
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
