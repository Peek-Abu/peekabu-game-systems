--!strict
--[=[
	AnimationCarryMeasureSystem: reads a carrier from its rig for the carry planner, at the rig's REST pose (its joint
	chain, never the frame an idle is on: Pippa's idle nods her head ~0.15 stud and leans her torso).

	- the arms bone by bone (`armOf`; the palm from the rig, `palmOf`), through Motor6D joints or the upgraded avatar
	  joints' AnimationConstraints (a stock R15 built in this place has those);
	- the torso and head as stacked slices of their REAL surface (`slices`: rays from four sides at each height), not
	  their boxes: a round body is narrow at the shoulders and wide at the belly, and its box's ellipsoid, widest at the
	  shoulders, put Pippa's arms "into" a chest she does not have there;
	- the torso's front and half width, the head's front, bottom and top (a toon's face plate and ears are jointed to
	  its head and count), the floor.

	@class AnimationCarryMeasureSystem
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Animation = ReplicatedStorage.Shared.Features.Animation
local AnimationTypes = require(Animation.Data.AnimationTypes)
local AnimationCarryContactUtils = require(Animation.Utils.AnimationCarryContactUtils)
local AnimationCarrySurfaceSystem = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySurfaceSystem)

local AnimationCarryMeasureSystem = {}

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end
local function attachment(bodyPart: BasePart, name: string): Attachment?
	local found = bodyPart:FindFirstChild(name)
	return if found ~= nil and found:IsA("Attachment") then found else nil
end
-- The joint holding `bodyPart` to the part above it: that part and `bodyPart`'s rest frame in it. A Motor6D
-- (C0 * C1:Inverse()), or an AnimationConstraint, which the upgraded avatar joints use in place of Motor6Ds (a stock
-- R15 built in this place has them: Attachment0's frame * Attachment1's:Inverse()). Nil without either.
local function jointOf(bodyPart: BasePart): (BasePart?, CFrame?)
	for _, child in bodyPart:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == bodyPart and child.Part0 ~= nil then
			return child.Part0, child.C0 * child.C1:Inverse()
		end
	end
	for _, child in bodyPart:GetChildren() do
		if child:IsA("AnimationConstraint") then
			local above, below = child.Attachment0, child.Attachment1
			if above ~= nil and below ~= nil and below.Parent == bodyPart then
				local parent = above.Parent
				if parent ~= nil and parent:IsA("BasePart") then
					return parent, above.CFrame * below.CFrame:Inverse()
				end
			end
		end
	end
	return nil, nil
end
-- The part's rest frame relative to the root: its joint chain without the animation's Transforms. Nil when the chain
-- does not reach the root.
local function restFrameOf(bodyPart: BasePart, root: BasePart): CFrame?
	local rest = CFrame.identity
	local current = bodyPart
	for _ = 1, 8 do
		if current == root then
			return rest
		end
		local above, frame = jointOf(current)
		if above == nil or frame == nil then
			return nil
		end
		rest = frame * rest
		current = above
	end
	return nil
end
-- Where the part sits relative to the root at rest, or where it is now when it has no joint chain to the root.
local function frameOf(bodyPart: BasePart, root: BasePart): CFrame
	return restFrameOf(bodyPart, root) or root.CFrame:ToObjectSpace(bodyPart.CFrame)
end

--[=[
	`bodyPart`'s frame relative to the carrier's root at rest (its joint chain without the animation's Transforms), or
	where it is now when it has no joint chain to the root.
]=]
function AnimationCarryMeasureSystem.restFrame(bodyPart: BasePart, root: BasePart): CFrame
	return frameOf(bodyPart, root)
end

--[=[
	`side`'s palm frame in its hand's space (AnimationCarryContactUtils.palmFrame): the fingers point from the
	wrist to the hand's grip (or its middle), the palm is the side facing the body at rest. Nil without the arm.
]=]
function AnimationCarryMeasureSystem.palmOf(character: Model, side: string): CFrame?
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
		frameOf(hand, root).Rotation,
		if side == "Right" then 1 else -1,
		hand.Size
	)
end

--[=[
	`side`'s arm as AnimationCarryArmUtils solves it, read from the rig at rest. Nil without a full R15 arm (its parts
	and the shoulder, elbow and wrist rig attachments).
]=]
function AnimationCarryMeasureSystem.armOf(character: Model, side: string): AnimationTypes.CarryArm?
	local root = part(character, "HumanoidRootPart")
	local upper = part(character, side .. "UpperArm")
	local lower = part(character, side .. "LowerArm")
	local hand = part(character, side .. "Hand")
	if root == nil or upper == nil or lower == nil or hand == nil then
		return nil
	end
	local shoulder = attachment(upper, side .. "ShoulderRigAttachment")
	local upperElbow = attachment(upper, side .. "ElbowRigAttachment")
	local lowerElbow = attachment(lower, side .. "ElbowRigAttachment")
	local lowerWrist = attachment(lower, side .. "WristRigAttachment")
	local handWrist = attachment(hand, side .. "WristRigAttachment")
	local palm = AnimationCarryMeasureSystem.palmOf(character, side)
	if
		shoulder == nil
		or upperElbow == nil
		or lowerElbow == nil
		or lowerWrist == nil
		or handWrist == nil
		or palm == nil
	then
		return nil
	end
	local upperRest = frameOf(upper, root)
	local along = palm.LookVector
	local grip = attachment(hand, side .. "GripAttachment")
	return {
		side = if side == "Right" then 1 else -1,
		shoulder = upperRest:PointToWorldSpace(shoulder.Position),
		upperRest = upperRest,
		lowerRest = frameOf(lower, root),
		handRest = frameOf(hand, root),
		shoulderInUpper = shoulder.Position,
		elbowInUpper = upperElbow.Position,
		elbowInLower = lowerElbow.Position,
		wristInLower = lowerWrist.Position,
		wristInHand = handWrist.Position,
		palmInHand = palm,
		gripInHand = if grip ~= nil then CFrame.new(grip.Position) * palm.Rotation else palm,
		handLength = math.abs(along.X) * hand.Size.X
			+ math.abs(along.Y) * hand.Size.Y
			+ math.abs(along.Z) * hand.Size.Z,
	}
end

-- The most extreme corner of `bodyPart` (at rest) along root-space `axis` (min when `sign` is -1).
local function extreme(root: BasePart, bodyPart: BasePart, axis: Vector3, sign: number, at: CFrame?): number
	local frame = at or frameOf(bodyPart, root)
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

-- How many slices a torso part and the head are measured in.
local TORSO_SLICES = 8
local HEAD_SLICES = 6

-- `bodyPart` at rest as an ellipsoid in root space, from its box.
local function ellipsoid(root: BasePart, bodyPart: BasePart): AnimationTypes.CarryBody
	local low = Vector3.new(
		extreme(root, bodyPart, Vector3.xAxis, -1),
		extreme(root, bodyPart, Vector3.yAxis, -1),
		extreme(root, bodyPart, Vector3.zAxis, -1)
	)
	local high = Vector3.new(
		extreme(root, bodyPart, Vector3.xAxis, 1),
		extreme(root, bodyPart, Vector3.yAxis, 1),
		extreme(root, bodyPart, Vector3.zAxis, 1)
	)
	return { centre = (low + high) / 2, radii = (high - low) / 2 }
end

--[=[
	`bodyPart` at rest as `count` stacked slices of its REAL surface (root space): at each height, rays from its four
	sides find how far the mesh reaches, and the slice is the ellipse through those points, as tall as the gap to the
	next. A round body is narrow at the shoulders and wide at the belly; its box's ellipsoid was widest at the shoulders,
	so it put Pippa's arms "into" a chest she does not have there. A slice the rays miss is left out; when every one
	is missed (no collision geometry), the box's ellipsoid.
]=]
function AnimationCarryMeasureSystem.slices(
	root: BasePart,
	bodyPart: BasePart,
	count: number,
	at: CFrame?
): { AnimationTypes.CarryBody }
	local surface = AnimationCarrySurfaceSystem.open(bodyPart, bodyPart.CFrame)
	local rest = at or frameOf(bodyPart, root)
	local size = bodyPart.Size
	local found: { AnimationTypes.CarryBody } = {}
	for k = 1, count do
		local y = -size.Y / 2 + size.Y * (k - 0.5) / count
		local function reach(axis: Vector3, half: number): number?
			local hit = surface.probe(axis * (half + 0.5) + Vector3.new(0, y, 0), -axis * (half * 2 + 1))
			return if hit ~= nil then hit:Dot(axis) else nil
		end
		local right, left = reach(Vector3.xAxis, size.X / 2), reach(-Vector3.xAxis, size.X / 2)
		local back, front = reach(Vector3.zAxis, size.Z / 2), reach(-Vector3.zAxis, size.Z / 2)
		if right ~= nil and left ~= nil and back ~= nil and front ~= nil then
			local centre = Vector3.new((right - left) / 2, y, (back - front) / 2)
			local radii = Vector3.new((right + left) / 2, size.Y / count, (back + front) / 2)
			local axes = rest.Rotation
			table.insert(found, {
				centre = rest:PointToWorldSpace(centre),
				radii = Vector3.new(
					math.abs(axes.XVector.X) * radii.X
						+ math.abs(axes.YVector.X) * radii.Y
						+ math.abs(axes.ZVector.X) * radii.Z,
					math.abs(axes.XVector.Y) * radii.X
						+ math.abs(axes.YVector.Y) * radii.Y
						+ math.abs(axes.ZVector.Y) * radii.Z,
					math.abs(axes.XVector.Z) * radii.X
						+ math.abs(axes.YVector.Z) * radii.Y
						+ math.abs(axes.ZVector.Z) * radii.Z
				),
			})
		end
	end
	surface.release()
	if #found == 0 then
		table.insert(found, ellipsoid(root, bodyPart))
	end
	return found
end

--[=[
	The visible parts of `character` joined straight to `bodyPart` by a Motor6D, a Weld or a WeldConstraint, except
	the joint that holds `bodyPart` itself to the body (the head's neck).
]=]
function AnimationCarryMeasureSystem.joinedTo(bodyPart: BasePart, character: Model): { BasePart }
	local above = jointOf(bodyPart)
	local found: { BasePart } = {}
	for _, descendant in character:GetDescendants() do
		local a: BasePart? = nil
		local b: BasePart? = nil
		if descendant:IsA("JointInstance") then
			a, b = descendant.Part0, descendant.Part1
		elseif descendant:IsA("WeldConstraint") then
			a, b = descendant.Part0, descendant.Part1
		end
		local other = if a == bodyPart then b elseif b == bodyPart then a else nil
		if
			other ~= nil
			and other ~= above
			and other:IsDescendantOf(character)
			and other.Transparency < 1
			and table.find(found, other) == nil
		then
			table.insert(found, other)
		end
	end
	return found
end

--[=[
	The carrier as the carry planner sees it, in HumanoidRootPart space at rest (AnimationTypes.CarryRig). Nil for a
	rig without native R15 arms, torso and head.
]=]
function AnimationCarryMeasureSystem.measure(character: Model): AnimationTypes.CarryRig?
	local root = part(character, "HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upperTorso = part(character, "UpperTorso")
	local head = part(character, "Head")
	local right = AnimationCarryMeasureSystem.armOf(character, "Right")
	local left = AnimationCarryMeasureSystem.armOf(character, "Left")
	if root == nil or humanoid == nil or upperTorso == nil or head == nil or right == nil or left == nil then
		return nil
	end
	local body: { AnimationTypes.CarryBody } = {}
	for _, name in { "UpperTorso", "LowerTorso" } do
		local torso = part(character, name)
		if torso ~= nil then
			for _, slice in AnimationCarryMeasureSystem.slices(root, torso, TORSO_SLICES) do
				table.insert(body, slice)
			end
		end
	end
	-- The head with everything joined to it (a toon's face plate, ears, glasses: Motor6Ds, welds or weld
	-- constraints), each where it sits on the rest-posed head.
	local heads: { AnimationTypes.CarryBody } = AnimationCarryMeasureSystem.slices(root, head, HEAD_SLICES)
	local headFront = extreme(root, head, Vector3.zAxis, -1)
	local headRest = frameOf(head, root)
	for _, attached in AnimationCarryMeasureSystem.joinedTo(head, character) do
		local at = headRest * head.CFrame:ToObjectSpace(attached.CFrame)
		headFront = math.min(headFront, extreme(root, attached, Vector3.zAxis, -1, at))
		for _, slice in AnimationCarryMeasureSystem.slices(root, attached, HEAD_SLICES, at) do
			table.insert(heads, slice)
		end
	end
	-- The torso's front and half width from its real surface.
	local front, halfWidth = math.huge, 0
	for _, slice in body do
		front = math.min(front, slice.centre.Z - slice.radii.Z)
		halfWidth = math.max(halfWidth, math.abs(slice.centre.X) + slice.radii.X)
	end
	return {
		right = right,
		left = left,
		front = front,
		headFront = headFront,
		headBottom = extreme(root, head, Vector3.yAxis, -1),
		headTop = extreme(root, head, Vector3.yAxis, 1),
		floor = -root.Size.Y / 2 - humanoid.HipHeight,
		torsoHalfWidth = halfWidth,
		body = body,
		head = heads,
	}
end

return AnimationCarryMeasureSystem
