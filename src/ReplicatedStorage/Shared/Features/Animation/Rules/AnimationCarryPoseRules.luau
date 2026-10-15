--!strict
--[=[
	AnimationCarryPoseRules: whether a held pose is right, measured, not eyeballed. The same rules judge every
	candidate hold while planning (AnimationCarryContactUtils.plan keeps the first that passes) and the live pose the
	engine actually shows (AnimationCarryHarness, the carry validator), so a hold that would display wrong fails.

	A pose passes when, for each hand in use:
	- the palm is ON the item's visible surface: its centre within `TOLERANCE.contact` of the surface along the way it
	  faces, facing into it within `TOLERANCE.facing` (one hand: the handle in the fist, at the hand's grip);
	- every joint is inside AnimationCarryArmUtils.LIMITS (elbow flexion and side bend, forearm roll, wrist, shoulder
	  elevation and extension, no chicken-wing elbow);
	- the arm stays out of the torso (deepest sample at most `TOLERANCE.bodyDepth` of the way to its centre) and out of
	  the item;
	and the item stays out of the torso and the head (pressing in at most `TOLERANCE.itemTorso` / `TOLERANCE.itemHead`;
	a pushed item `TOLERANCE.itemHeadPushed`),
	and off the floor (`under` / `hand`: at least `TOLERANCE.floorLift` clear; `push`: standing on it).

	@class AnimationCarryPoseRules
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)
local AnimationCarryArmUtils = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryArmUtils)

type Rig = AnimationTypes.CarryRig
type Hold = AnimationTypes.CarryHold
type Probe = AnimationTypes.CarryProbe
type Arm = AnimationTypes.CarryArm
type Pose = AnimationTypes.CarryPose

--[=[
	One hand's measurements.
	@interface Side
	.angles AnimationCarryArmUtils.Angles
	.contact number? -- the palm's centre to the visible surface along the way it faces (studs: + short of it,
	- sunk in); for one hand, the fist (grip) to the handle; nil when there is no surface in front of the palm
	.facing number? -- degrees between the way the palm faces and into the surface
	.bodyDepth number -- the arm's deepest sample inside the torso (0 outside .. 1 at its centre)
	.inItem boolean -- some of the arm is inside the item
]=]
export type Side = {
	angles: AnimationCarryArmUtils.Angles,
	contact: number?,
	facing: number?,
	bodyDepth: number,
	inItem: boolean,
}
export type Report = {
	ok: boolean,
	violations: { string },
	right: Side,
	left: Side?,
	-- The item's lowest point above the floor, and its highest against the head's bottom (+ above the chin).
	floorGap: number,
	overChin: number,
	-- How far (studs) the item's real surface reaches into the torso and into the head.
	torsoDepth: number,
	headDepth: number,
}

local AnimationCarryPoseRules = {}

AnimationCarryPoseRules.TOLERANCE = table.freeze({
	-- The palm's centre to the surface (studs), either way: the hand's own round edges then touch it.
	contact = 0.06,
	-- The palm facing the surface (degrees).
	facing = 45,
	-- One hand: the fist (the hand's grip) to the handle (studs).
	handle = 0.06,
	-- How deep an arm's centre line may sit in the torso (fraction of the way to the middle of the torso slice it is
	-- in): the arm is ~0.4 stud thick, so its line a little inside the torso's surface is the arm resting against it
	-- (Pippa's own idle and walk reach 0.12 at the shoulder, measured 2026-10-15).
	bodyDepth = 0.15,
	-- How far the torso's / the head's surface may sink into the item (studs): pressed against the belly; under a toon's
	-- chin, whose big head and face plate overhang its belly (Pippa's face plate is 0.45 in front of her belly: a box
	-- held at her belly that is taller than ~1 stud meets her muzzle, 0.13-0.18 deep, as the recycling box the playtest
	-- approved does; her 1-stud arms cannot hold it lower or further out).
	itemTorso = 0.06,
	itemHead = 0.2,
	-- Nothing presses a pushed item into the face: it stands on the floor, and can stand further out.
	itemHeadPushed = 0.03,
	-- The item's bottom above the floor (studs), lifted; pushed: between these.
	floorLift = 0.1,
	pushFloorMin = -0.05,
	pushFloorMax = 0.3,
})

-- The arm's checked stretches: the upper arm past its shoulder joint (inside the torso on a round body), and the
-- forearm short of the hand (which touches the item).
local ARM_BODY_UPPER = { 0.5, 1 }
local ARM_BODY_FORE = { 0, 0.7 }
local ARM_ITEM_UPPER = { 0.25, 1 }
local ARM_ITEM_FORE = { 0, 0.6 }
local SAMPLES = 6
-- The contact ray starts this far behind the palm and runs twice as far.
local CONTACT_BACK = 0.3
local AXES = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }

-- Whether box-space `point` is inside the item: every axis ray from outside toward it hits the surface first.
-- How deep box-space `point` is inside the item (studs): every axis ray from outside toward it hits the surface first,
-- and the nearest way out along those axes is this far. 0 outside.
local function sunk(probe: Probe, size: Vector3, point: Vector3): number
	local half = size / 2
	if math.abs(point.X) > half.X or math.abs(point.Y) > half.Y or math.abs(point.Z) > half.Z then
		return 0
	end
	local far = size.Magnitude + 1
	local out = math.huge
	for _, axis in AXES do
		local hit = probe(point + axis * far, -axis * far)
		if hit == nil then
			return 0
		end
		out = math.min(out, (hit - point).Magnitude)
	end
	return out
end

--[=[
	Whether root-space `point` is inside the item `hold` places (`probe` and `size` in its box space).
]=]
function AnimationCarryPoseRules.inItem(probe: Probe, size: Vector3, offset: CFrame, point: Vector3): boolean
	return sunk(probe, size, offset:PointToObjectSpace(point)) > 0
end

local function joints(arm: Arm, pose: Pose): (Vector3, Vector3, Vector3)
	return pose.upper:PointToWorldSpace(arm.shoulderInUpper),
		pose.upper:PointToWorldSpace(arm.elbowInUpper),
		pose.lower:PointToWorldSpace(arm.wristInLower)
end

local function samples(from: Vector3, to: Vector3, span: { number }): { Vector3 }
	local points: { Vector3 } = {}
	for k = 0, SAMPLES do
		table.insert(points, from:Lerp(to, span[1] + (span[2] - span[1]) * k / SAMPLES))
	end
	return points
end

local function side(
	rig: Rig,
	arm: Arm,
	pose: Pose,
	contact: CFrame,
	hold: Hold,
	probe: Probe,
	size: Vector3,
	name: string,
	violations: { string },
	torso: CFrame?
): Side
	local limits = AnimationCarryArmUtils.LIMITS
	local tolerance = AnimationCarryPoseRules.TOLERANCE
	local angles = AnimationCarryArmUtils.angles(arm, pose, torso)
	local function fail(text: string)
		table.insert(violations, `{name}: {text}`)
	end
	if angles.flex < limits.flexMin or angles.flex > limits.flexMax then
		fail(string.format("elbow flexed %.0f deg (allowed %d..%d)", angles.flex, limits.flexMin, limits.flexMax))
	end
	if math.abs(angles.sideBend) > limits.sideBend then
		fail(string.format("elbow bent %.0f deg sideways out of its hinge", angles.sideBend))
	end
	local roll = angles.roll
	if roll ~= nil and (roll < -limits.pronate or roll > limits.supinate) then
		fail(string.format("forearm rolled %.0f deg (allowed -%d..%d)", roll, limits.pronate, limits.supinate))
	end
	if math.abs(angles.wristFlex) > limits.wristFlex then
		fail(string.format("wrist bent %.0f deg", angles.wristFlex))
	end
	if math.abs(angles.wristDeviation) > limits.wristDeviation then
		fail(string.format("wrist bent %.0f deg sideways", angles.wristDeviation))
	end
	if math.abs(angles.wristTwist) > limits.wristTwist then
		fail(string.format("wrist twisted %.0f deg", angles.wristTwist))
	end
	if angles.elevation > limits.elevation then
		fail(string.format("upper arm raised %.0f deg above level", angles.elevation))
	end
	if angles.behind > limits.behind then
		fail(string.format("upper arm %.0f deg behind the body", angles.behind))
	end
	if angles.elbowForward > limits.elbowForward then
		fail("elbow pointing forward")
	end
	-- The palm on the surface.
	local palm = AnimationCarryArmUtils.palm(arm, pose)
	local measured: number? = nil
	local facing: number? = nil
	if hold.style == "hand" then
		local fist = pose.hand:PointToWorldSpace(arm.gripInHand.Position)
		local distance = (fist - hold.offset:PointToWorldSpace(contact.Position)).Magnitude
		measured = distance
		if distance > tolerance.handle then
			fail(string.format("palm %.3f from the handle", distance))
		end
	else
		local at = hold.offset:PointToObjectSpace(palm.Position)
		local normal = hold.offset:VectorToObjectSpace(palm.UpVector)
		local hit, surface = probe(at - normal * CONTACT_BACK, normal * CONTACT_BACK * 2)
		if hit ~= nil and surface ~= nil then
			local gap = (hit - at):Dot(normal)
			measured = gap
			local angle = math.deg(math.acos(math.clamp(normal:Dot(-surface), -1, 1)))
			facing = angle
			if math.abs(gap) > tolerance.contact then
				fail(
					string.format(
						"palm %.3f %s the visible surface",
						math.abs(gap),
						if gap > 0 then "short of" else "sunk into"
					)
				)
			end
			if angle > tolerance.facing then
				fail(string.format("palm %.0f deg off flat on the surface", angle))
			end
		else
			fail("no visible surface in front of the palm")
		end
	end
	-- The arm out of the torso and the item.
	local shoulder, elbow, wrist = joints(arm, pose)
	local depth = 0
	for _, point in samples(shoulder, elbow, ARM_BODY_UPPER) do
		depth = math.max(depth, AnimationCarryArmUtils.depthIn(point, rig.body, 0))
	end
	for _, point in samples(elbow, wrist, ARM_BODY_FORE) do
		depth = math.max(depth, AnimationCarryArmUtils.depthIn(point, rig.body, 0))
	end
	if depth > tolerance.bodyDepth then
		fail(string.format("arm %.0f%% into the torso", depth * 100))
	end
	local through = false
	if hold.style ~= "hand" then
		for _, point in samples(shoulder, elbow, ARM_ITEM_UPPER) do
			through = through or AnimationCarryPoseRules.inItem(probe, size, hold.offset, point)
		end
		for _, point in samples(elbow, wrist, ARM_ITEM_FORE) do
			through = through or AnimationCarryPoseRules.inItem(probe, size, hold.offset, point)
		end
		if through then
			fail("arm inside the item")
		end
	end
	return { angles = angles, contact = measured, facing = facing, bodyDepth = depth, inItem = through }
end

-- How far a body's surface is sunk into an item, at most (studs): its shell (just inside its surface) point that is
-- deepest in the item, by the nearest way out of it.
local SHELL_INSET = 0.03
-- Points just inside an ellipsoid's surface (26 directions).
local function shell(body: AnimationTypes.CarryBody, inset: number): { Vector3 }
	local points: { Vector3 } = {}
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local direction = Vector3.new(x, y, z)
				if direction.Magnitude > 0 then
					local onSurface = body.radii * direction.Unit
					table.insert(points, body.centre + onSurface - onSurface.Unit * inset)
				end
			end
		end
	end
	return points
end

local function depthOf(bodies: { AnimationTypes.CarryBody }, probe: Probe, size: Vector3, offset: CFrame): number
	local deepest = 0
	for _, body in bodies do
		for _, point in shell(body, SHELL_INSET) do
			deepest = math.max(deepest, sunk(probe, size, offset:PointToObjectSpace(point)))
		end
	end
	return deepest
end

--[=[
	Checks `hold` (planned, or rebuilt from the live pose) on `rig` against the item's visible surface (`probe` and
	`size` in its box space). `torso` is how the torso is turned from rest in the hold's space (live, a pushed item's
	pose is read on the root while the walk leans the torso; omitted: at rest). Every failure is listed in plain words.
]=]
function AnimationCarryPoseRules.check(rig: Rig, hold: Hold, probe: Probe, size: Vector3, torso: CFrame?): Report
	local tolerance = AnimationCarryPoseRules.TOLERANCE
	local violations: { string } = {}
	local right = side(rig, rig.right, hold.rightPose, hold.right, hold, probe, size, "right", violations, torso)
	local leftContact, leftPose = hold.left, hold.leftPose
	local left = if leftContact ~= nil and leftPose ~= nil
		then side(rig, rig.left, leftPose, leftContact, hold, probe, size, "left", violations, torso)
		else nil
	-- The item out of the body: how far into the torso and the head its real surface reaches.
	local torsoDepth = depthOf(rig.body, probe, size, hold.offset)
	if torsoDepth > tolerance.itemTorso then
		table.insert(violations, string.format("item: %.2f into the torso", torsoDepth))
	end
	local headDepth = depthOf(rig.head, probe, size, hold.offset)
	if headDepth > (if hold.style == "push" then tolerance.itemHeadPushed else tolerance.itemHead) then
		table.insert(violations, string.format("item: %.2f into the head", headDepth))
	end
	-- Off the floor (or standing on it, pushed).
	local low, high = math.huge, -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = hold.offset:PointToWorldSpace(Vector3.new(x, y, z) * size / 2)
				low = math.min(low, corner.Y)
				high = math.max(high, corner.Y)
			end
		end
	end
	local floorGap = low - rig.floor
	if hold.style == "push" then
		if floorGap < tolerance.pushFloorMin or floorGap > tolerance.pushFloorMax then
			table.insert(violations, string.format("item: %.2f off the floor while pushed", floorGap))
		end
	elseif floorGap < tolerance.floorLift then
		table.insert(violations, string.format("item: only %.2f off the floor", floorGap))
	end
	return {
		ok = #violations == 0,
		violations = violations,
		right = right,
		left = left,
		floorGap = floorGap,
		overChin = high - rig.headBottom,
		torsoDepth = torsoDepth,
		headDepth = headDepth,
	}
end

return table.freeze(AnimationCarryPoseRules)
