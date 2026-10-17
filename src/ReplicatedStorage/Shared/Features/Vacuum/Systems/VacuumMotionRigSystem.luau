--!strict
--[=[
	VacuumMotionRigSystem: lays a vacuum motion pose (VacuumMotionFormulas) onto one holder's rig, on this machine
	only. Every client runs it for every holder it sees (VacuumMotionSystem); the vacuum harness runs it on the server
	to check the hands stay on the wand at every layer's extremes (AnimationVacuumHarness).

	`bind` reads the holder's rest hold: the two IK target Attachments AnimationVacuumHoldSystem made on its
	HumanoidRootPart (their planned frame, recorded on them as VacuumMotionConstants.REST_ATTRIBUTE), and from the
	held Tool the wand's pivot (the left paw's grip, GripLower, from its target; GripUpper one-handed) and the floor head's
	bottom corners, all in root space at rest. `apply`, called in RunService.PreSimulation (after the frame's
	animation and IK), then:

	- leans the body for the brace: the hips drop (Root), the knees fold with the feet planted (hips, knees, ankles:
	  VacuumMotionFormulas.legFold) and the torso leans forward over the waist (Waist), each written as a Motor6D
	  Transform over the animation's; the upper body's motion this makes is returned;
	- moves both IK targets by the pose's wand transform `W` (target = W * rest; the left paw, whose wrap point is
	  the pivot, is moved with it but turned only VacuumMotionConstants.leftTurn of the way). The engine solves the IKControls
	  after PreSimulation, on the leaned torso, so the hands land on `W * rest` and the wand is exactly where the pose
	  put it, the floor head over the floor (taking the lean back out of the targets, as first written, lifted the
	  floor head 0.5 stud off the floor in the brace: AnimationVacuumHarness, Studio 2026-10-17).

	A Transform it wrote is recognised next frame: a joint the Animator did not rewrite is posed from the animation's
	value again, never on top of its own last write. Setting an Attachment's CFrame and a Motor6D's Transform locally
	is never replicated (the server never rewrites either after creating them), so nothing authoritative moves.
	`release` puts the targets back at rest and the joints back on the animation.

	Spec-exempt shell (Instances, Motor6Ds); the maths is the specced VacuumMotionFormulas.

	@class VacuumMotionRigSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local VacuumMotionFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumMotionFormulas)

-- What `apply` lays on: the wand's root-space transform (VacuumMotionFormulas.wand), the hip drop (studs) and the
-- torso's forward lean (radians).
export type Pose = { wand: CFrame, drop: number, lean: number }

export type Rig = {
	character: Model,
	tool: Tool,
	rest: VacuumMotionFormulas.WandRest,
	-- Lays `pose` on the rig; returns the upper body's root-space motion.
	apply: (pose: Pose) -> CFrame,
	-- Whether the rig is still the one bound (same Tool held, targets in place).
	valid: () -> boolean,
	release: () -> (),
}

type Joint = { motor: Motor6D, base: CFrame?, wrote: CFrame? }
type Leg = { hip: Joint, knee: Joint, ankle: Joint, thigh: number, shin: number }

local VacuumMotionRigSystem = {}

-- The IK targets AnimationVacuumHoldSystem makes on the root.
local RIGHT_TARGET = "VacuumHoldTarget"
local LEFT_TARGET = "VacuumSupportTarget"

local function part(container: Instance, name: string): BasePart?
	local found = container:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

local function attachmentOn(bodyPart: BasePart?, name: string): Attachment?
	local found = if bodyPart ~= nil then bodyPart:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Attachment") then found else nil
end

local function jointOf(character: Model, partName: string, motorName: string): Joint?
	local bodyPart = part(character, partName)
	local found = if bodyPart ~= nil then bodyPart:FindFirstChild(motorName) else nil
	return if found ~= nil and found:IsA("Motor6D") then { motor = found } else nil
end

local function span(character: Model, partName: string, from: string, to: string): number?
	local bodyPart = part(character, partName)
	local a, b = attachmentOn(bodyPart, from), attachmentOn(bodyPart, to)
	return if a ~= nil and b ~= nil then (a.Position - b.Position).Magnitude else nil
end

local function restOf(target: Attachment): CFrame
	local rest = target:GetAttribute(Constants.REST_ATTRIBUTE)
	return if typeof(rest) == "CFrame" then rest else target.CFrame
end

-- The joint's Transform as the animation left it this frame (its own last write recognised and undone).
local function animated(joint: Joint): CFrame
	local now = joint.motor.Transform
	local wrote, base = joint.wrote, joint.base
	if wrote ~= nil and base ~= nil and now == wrote then
		return base
	end
	return now
end

local function write(joint: Joint, base: CFrame, value: CFrame)
	joint.base = base
	joint.wrote = value
	joint.motor.Transform = value
end

local function unwrite(joint: Joint)
	local wrote, base = joint.wrote, joint.base
	if wrote ~= nil and base ~= nil and joint.motor.Transform == wrote then
		joint.motor.Transform = base
	end
	joint.wrote = nil
	joint.base = nil
end

-- A child part's frame from its parent's through its joint (the engine's Part0 * C0 * Transform * C1:Inverse()).
local function through(parent: CFrame, motor: Motor6D, transform: CFrame): CFrame
	return parent * motor.C0 * transform * motor.C1:Inverse()
end

-- The joint's Transform that puts its child at `child` with its parent at `parent`.
local function transformFor(parent: CFrame, motor: Motor6D, child: CFrame): CFrame
	return motor.C0:Inverse() * parent:Inverse() * child * motor.C1
end

-- A turn of `angle` about the root's X axis through `point`.
local function turnAbout(point: Vector3, angle: number): CFrame
	return CFrame.new(point) * CFrame.Angles(angle, 0, 0) * CFrame.new(-point)
end

local function legOf(character: Model, side: string): Leg?
	local hip = jointOf(character, side .. "UpperLeg", side .. "Hip")
	local knee = jointOf(character, side .. "LowerLeg", side .. "Knee")
	local ankle = jointOf(character, side .. "Foot", side .. "Ankle")
	local thigh = span(character, side .. "UpperLeg", side .. "HipRigAttachment", side .. "KneeRigAttachment")
	local shin = span(character, side .. "LowerLeg", side .. "KneeRigAttachment", side .. "AnkleRigAttachment")
	if hip == nil or knee == nil or ankle == nil or thigh == nil or shin == nil then
		return nil
	end
	return { hip = hip, knee = knee, ankle = ankle, thigh = thigh, shin = shin }
end

-- The floor head's bottom corners in handle space.
local function headCorners(handle: BasePart, head: BasePart): { Vector3 }
	local inHandle = handle.CFrame:ToObjectSpace(head.CFrame)
	local half = head.Size / 2
	local corners: { Vector3 } = {}
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(corners, inHandle * Vector3.new(half.X * x, -half.Y, half.Z * z))
		end
	end
	return corners
end

--[=[
	Binds `character`'s held vacuum: nil unless it holds the vacuum Tool (with its floor head and GripUpper) and its
	root carries the hold's right IK target.
]=]
function VacuumMotionRigSystem.bind(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = part(character, "HumanoidRootPart")
	local found = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local tool: Tool? = if found ~= nil and found:IsA("Tool") then found else nil
	if humanoid == nil or root == nil or tool == nil then
		return nil
	end
	local handle = part(tool, "Handle")
	local head = part(tool, VacuumConstants.FLOOR_HEAD_NAME)
	local upper = tool:FindFirstChild("GripUpper", true)
	local right = attachmentOn(root, RIGHT_TARGET)
	local left = attachmentOn(root, LEFT_TARGET)
	if handle == nil or head == nil or upper == nil or not upper:IsA("Attachment") or right == nil then
		return nil
	end
	local rightRest = restOf(right)
	local leftRest = if left ~= nil then restOf(left) else nil
	-- The handle at rest: the right hand's grip attachment at its target, the Tool's Grip from it.
	local handleRest = rightRest * tool.Grip:Inverse()
	local corners: { Vector3 } = {}
	for _, corner in headCorners(handle, head) do
		table.insert(corners, handleRest * corner)
	end
	local rootJoint = jointOf(character, "LowerTorso", "Root")
	local waist = jointOf(character, "UpperTorso", "Waist")
	-- The left paw's hold, as the server planned it (on its target).
	local leftHold: VacuumMotionFormulas.LeftHold? = nil
	if left ~= nil then
		local at = left:GetAttribute(Constants.AT_ATTRIBUTE)
		local shoulder = left:GetAttribute(Constants.SHOULDER_ATTRIBUTE)
		local reach = left:GetAttribute(Constants.REACH_ATTRIBUTE)
		if typeof(at) == "Vector3" and typeof(shoulder) == "Vector3" and type(reach) == "number" then
			leftHold = { at = at, shoulder = shoulder, reach = reach }
		end
	end
	local rest: VacuumMotionFormulas.WandRest = {
		-- Every layer turns about the left paw's grip (its arm is planned near full reach; the right has room).
		pivot = if leftHold ~= nil
			then leftHold.at
			else handleRest * handle.CFrame:PointToObjectSpace(upper.WorldPosition),
		corners = corners,
		floorY = -(root.Size.Y / 2 + humanoid.HipHeight),
		left = leftHold,
		-- The waist joint at rest (the brace leans over it).
		waist = if rootJoint ~= nil and waist ~= nil
			then (rootJoint.motor.C0 * rootJoint.motor.C1:Inverse() * waist.motor.C0).Position
			else nil,
	}
	local legs: { Leg } = {}
	for _, side in { "Right", "Left" } do
		local leg = legOf(character, side)
		if leg ~= nil then
			table.insert(legs, leg)
		end
	end
	local joints: { Joint } = {}
	for _, joint in { rootJoint, waist } do
		if joint ~= nil then
			table.insert(joints, joint)
		end
	end
	for _, leg in legs do
		table.insert(joints, leg.hip)
		table.insert(joints, leg.knee)
		table.insert(joints, leg.ankle)
	end
	local posed = false

	-- Writes the brace's Transforms; returns the upper body's root-space motion.
	local function lean(drop: number, angle: number): CFrame
		if rootJoint == nil or waist == nil or (drop < 1e-4 and math.abs(angle) < 1e-5) then
			if posed then
				for _, joint in joints do
					unwrite(joint)
				end
				posed = false
			end
			return CFrame.identity
		end
		posed = true
		local rootT, waistT = animated(rootJoint), animated(waist)
		local lower = through(CFrame.identity, rootJoint.motor, rootT)
		local upperTorso = through(lower, waist.motor, waistT)
		local down = CFrame.new(0, -drop, 0)
		-- Forward over the waist joint (a negative turn about X tips the top toward -Z).
		local motion = down * turnAbout((lower * waist.motor.C0).Position, -angle)
		local lowerNew = down * lower
		write(rootJoint, rootT, transformFor(CFrame.identity, rootJoint.motor, lowerNew))
		write(waist, waistT, transformFor(lowerNew, waist.motor, motion * upperTorso))
		for _, leg in legs do
			local hipT, kneeT, ankleT = animated(leg.hip), animated(leg.knee), animated(leg.ankle)
			local thigh = through(lower, leg.hip.motor, hipT)
			local shin = through(thigh, leg.knee.motor, kneeT)
			local foot = through(shin, leg.ankle.motor, ankleT)
			local hipTurn, kneeTurn, ankleTurn = VacuumMotionFormulas.legFold(leg.thigh, leg.shin, drop)
			local a = down * turnAbout((lower * leg.hip.motor.C0).Position, hipTurn)
			local b = a * turnAbout((thigh * leg.knee.motor.C0).Position, kneeTurn)
			local c = b * turnAbout((shin * leg.ankle.motor.C0).Position, ankleTurn)
			local thighNew, shinNew = a * thigh, b * shin
			write(leg.hip, hipT, transformFor(lowerNew, leg.hip.motor, thighNew))
			write(leg.knee, kneeT, transformFor(thighNew, leg.knee.motor, shinNew))
			write(leg.ankle, ankleT, transformFor(shinNew, leg.ankle.motor, c * foot))
		end
		return motion
	end

	local released = false
	return {
		character = character,
		tool = tool,
		rest = rest,
		apply = function(pose)
			if released then
				return CFrame.identity
			end
			local motion = lean(pose.drop, pose.lean)
			local wand = pose.wand
			right.CFrame = wand * rightRest
			if left ~= nil and leftRest ~= nil then
				-- The left paw's wrap point is the pivot: it goes where the wand takes it, turned only part way.
				local turned = CFrame.identity:Lerp(wand.Rotation, Constants.leftTurn)
				left.CFrame = CFrame.new(wand * rest.pivot) * turned * CFrame.new(-rest.pivot) * leftRest
			end
			return motion
		end,
		valid = function()
			return not released
				and tool.Parent == character
				and right.Parent == root
				and (left == nil or left.Parent == root)
				and handle.Parent == tool
		end,
		release = function()
			if released then
				return
			end
			released = true
			right.CFrame = rightRest
			if left ~= nil and leftRest ~= nil then
				left.CFrame = leftRest
			end
			for _, joint in joints do
				unwrite(joint)
			end
		end,
	}
end

return VacuumMotionRigSystem
