--!strict
--[=[
	AnimationCarryArmUtils: one arm of a carrier as three rigid bones (upper arm, lower arm, hand), and the
	anatomical pose that puts its palm on a contact.

	Everything is in the carrier's HumanoidRootPart space at the rig's rest pose, read from the rig (`Arm`), so any
	scale or proportion (Pippa's 1-stud arms in a T-pose, a stock R15's hanging 2-stud arms) is solved the same way.

	`solve` is a full analytic arm, not a generic IK guess:
	- the elbow bends toward a pole, swinging out of the body when that would run the arm through it (`elbow`);
	- the upper arm is rolled so the elbow bends in its own hinge plane: never sideways;
	- the forearm then rolls (pronation / supination) to face the palm, within anatomical limits measured from the
	  palm-facing-in neutral of a bent elbow;
	- the wrist bends (flexion / extension only) for the rest, within `LIMITS.wristFlex`;
	- the wrist aim is corrected until the palm lands on the contact.
	AnimationCarrySystem drives each bone to this pose exactly (one single-joint IKControl per joint), so the
	engine's solver has nothing left to choose: a generic 6-DoF two-bone solve kept the animation's upper-arm roll
	and bent Pippa's elbows ~50 degrees out of their hinge plane with the forearm twisted ~86 degrees (measured live
	2026-10-15 on the recycling box).

	`angles` reads the same joint angles back from any pose (planned or live) for AnimationCarryPoseRules.

	@class AnimationCarryArmUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

export type Arm = AnimationTypes.CarryArm
export type Pose = AnimationTypes.CarryPose
export type Body = AnimationTypes.CarryBody
--[=[
	@interface Angles
	.flex number -- elbow flexion (degrees): 0 straight, positive bent; negative is hyperextended
	.sideBend number -- the forearm out of the elbow's hinge plane (degrees)
	.roll number? -- forearm roll from neutral (palm facing in), + supinated (palm up), - pronated; nil when the
	elbow is too straight to tell (below LIMITS.rollFrom)
	.wristFlex number -- the hand bent toward its palm (+) or back (-), degrees
	.wristDeviation number -- the hand bent sideways (degrees)
	.wristTwist number -- the hand twisted about the forearm against it (degrees)
	.elevation number -- the upper arm above level (degrees; -90 hanging straight down)
	.behind number -- the upper arm back behind the shoulders' plane (degrees)
	.elbowForward number -- how far a bent elbow points forward (-1..1): a chicken-wing elbow is near 1
]=]
export type Angles = {
	flex: number,
	sideBend: number,
	roll: number?,
	wristFlex: number,
	wristDeviation: number,
	wristTwist: number,
	elevation: number,
	behind: number,
	elbowForward: number,
}

local AnimationCarryArmUtils = {}

-- The joint limits every carry pose stays inside (degrees, except `elbowForward`). `solve` clamps the forearm roll
-- and the wrist to them; AnimationCarryPoseRules checks all of them on the planned and the live pose.
-- Human ranges, kept short of the extremes: elbow 0-150 flexion; pronation ~80 and supination ~90 from the
-- palm-in neutral (a bent elbow); wrist extension ~70 (a palm flat on a wall you push, or under a tray held low
-- on straight arms), flexion ~80; sideways ~15.
AnimationCarryArmUtils.LIMITS = table.freeze({
	flexMin = -5,
	flexMax = 150,
	sideBend = 15,
	pronate = 85,
	supinate = 95,
	rollFrom = 20,
	wristFlex = 70,
	wristDeviation = 15,
	wristTwist = 10,
	elevation = 35,
	behind = 45,
	elbowForward = 0.75,
})
-- How far `solve` itself bends the wrist and rolls the forearm: the checked limits, less a margin (degrees).
local WRIST_FLEX = 65
local MARGIN = 10
-- `solve` re-aims the wrist until the palm lands within this of the contact (studs), in at most this many steps.
local LAND = 1e-4
local LAND_STEPS = 12
-- `elbow`: the bend directions tried round the shoulder-wrist axis, and the stretches of each bone checked against
-- the body (fractions from the shoulder to the elbow, the elbow to the wrist). The upper arm's root is the shoulder
-- joint, inside the torso on a round body, and the hand rests against the item, so neither end counts.
local ELBOW_STEPS = 72
local UPPER_SPAN = { 0.5, 1 }
local FORE_SPAN = { 0, 0.7 }
local SPAN_SAMPLES = 8
-- Below this |u x w| (the sine of the elbow's bend) the arm is straight: its hinge comes from the pole.
local STRAIGHT = 0.05
local FORWARD = Vector3.new(0, 0, -1)

local function unit(vector: Vector3, fallback: Vector3): Vector3
	return if vector.Magnitude > 1e-6 then vector.Unit else fallback
end

-- The rotation taking the orthonormal pair (a1, a2) onto (b1, b2).
local function basis(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3): CFrame
	local from = CFrame.fromMatrix(Vector3.zero, a1, a2, a1:Cross(a2))
	local to = CFrame.fromMatrix(Vector3.zero, b1, b2, b1:Cross(b2))
	return to * from:Inverse()
end

-- Rotates `frame` by `rotation` about the world point `pivot`.
local function about(pivot: Vector3, rotation: CFrame, frame: CFrame): CFrame
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot) * frame
end

-- The signed angle (radians) about unit `axis` from `a` to `b`, both projected off the axis.
local function angleAbout(a: Vector3, b: Vector3, axis: Vector3): number
	local pa = a - axis * a:Dot(axis)
	local pb = b - axis * b:Dot(axis)
	if pa.Magnitude < 1e-6 or pb.Magnitude < 1e-6 then
		return 0
	end
	return math.atan2(axis:Dot(pa:Cross(pb)), pa:Dot(pb))
end

-- The arm's bones, from its rest pose. The bone lines run joint to joint (a stock R15's shoulder joint is at its
-- upper arm's top inner corner, so its upper bone leans 33 degrees off the part's axis). The elbow is a hinge whose
-- axis is fixed in the upper arm: square to the forearm and to forward at rest, so flexing it from rest swings the
-- forearm forward (both a T-posed and a hanging rig); the forearm then rolls about its own line.
type Bones = {
	-- The upper bone's line, the elbow's hinge, and the forearm's line at rest, all in the upper arm's space.
	along: Vector3,
	hinge: Vector3,
	foreRest: Vector3,
	-- The forearm's line in the lower arm's space.
	foreAlong: Vector3,
	upper: number,
	fore: number,
	lowerInUpper: CFrame,
	handInLower: CFrame,
}

local function bones(arm: Arm): Bones
	local along = unit(arm.elbowInUpper - arm.shoulderInUpper, -Vector3.yAxis)
	local lowerInUpper = arm.upperRest:ToObjectSpace(arm.lowerRest)
	local foreAlong = unit(arm.wristInLower - arm.elbowInLower, -Vector3.yAxis)
	local foreRest = lowerInUpper:VectorToWorldSpace(foreAlong)
	local forward = arm.upperRest:VectorToObjectSpace(FORWARD)
	return {
		along = along,
		hinge = unit(foreRest:Cross(forward), unit(foreRest:Cross(Vector3.yAxis), Vector3.xAxis)),
		foreRest = foreRest,
		foreAlong = foreAlong,
		upper = (arm.elbowInUpper - arm.shoulderInUpper).Magnitude,
		fore = (arm.wristInLower - arm.elbowInLower).Magnitude,
		lowerInUpper = lowerInUpper,
		handInLower = arm.lowerRest:ToObjectSpace(arm.handRest),
	}
end

-- The forearm's line (upper arm space) with the elbow flexed `angle` radians from rest.
local function flexed(b: Bones, angle: number): Vector3
	return b.foreRest * math.cos(angle) + b.hinge:Cross(b.foreRest) * math.sin(angle)
end

-- The lower arm's frame in the upper arm's space with the elbow flexed `angle` radians from rest (no roll).
local function lowerAt(arm: Arm, b: Bones, angle: number): CFrame
	return about(arm.elbowInUpper, CFrame.fromAxisAngle(b.hinge, angle), b.lowerInUpper)
end

-- The flexion (radians, within the elbow's range) that opens the angle between the bones to `cosine`.
local function flexFor(b: Bones, cosine: number): number
	local a = b.along:Dot(b.foreRest)
	local c = b.along:Dot(b.hinge:Cross(b.foreRest))
	local r = math.sqrt(a * a + c * c)
	local phase = math.atan2(c, a)
	local spread = math.acos(math.clamp(cosine / math.max(r, 1e-6), -1, 1))
	local low = math.rad(AnimationCarryArmUtils.LIMITS.flexMin)
	local high = math.rad(AnimationCarryArmUtils.LIMITS.flexMax)
	local best = 0
	local bestError = math.huge
	for _, candidate in { phase + spread, phase - spread, phase + spread - 2 * math.pi, phase - spread + 2 * math.pi } do
		local clamped = math.clamp(candidate, low, high)
		local miss = math.abs(clamped - candidate) * 10 + math.abs(clamped)
		if miss < bestError then
			best, bestError = clamped, miss
		end
	end
	return best
end

-- How deep `point` is inside the bodies, each grown by `pad` (0 outside; up to 1 at a centre).
function AnimationCarryArmUtils.depthIn(point: Vector3, body: { Body }, pad: number): number
	local deepest = 0
	for _, shape in body do
		local d = ((point - shape.centre) / (shape.radii + Vector3.one * pad)).Magnitude
		deepest = math.max(deepest, 1 - d)
	end
	return deepest
end

-- How much of the arm (shoulder -> elbow -> wrist, each bone's checked stretch) is inside the body.
local function overlap(shoulder: Vector3, elbow: Vector3, wrist: Vector3, body: { Body }, pad: number): number
	local total = 0
	for k = 0, SPAN_SAMPLES do
		local t = k / SPAN_SAMPLES
		total += AnimationCarryArmUtils.depthIn(
			shoulder:Lerp(elbow, UPPER_SPAN[1] + (UPPER_SPAN[2] - UPPER_SPAN[1]) * t),
			body,
			pad
		)
		total += AnimationCarryArmUtils.depthIn(
			elbow:Lerp(wrist, FORE_SPAN[1] + (FORE_SPAN[2] - FORE_SPAN[1]) * t),
			body,
			pad
		)
	end
	return total
end

--[=[
	Where a two-bone arm (`upper`, `lower` long) from `shoulder` to `wrist` bends its elbow, all in root space. It
	bends toward `pole` (a direction from the shoulder, authored for the right arm: X outward; `side` 1 right, -1
	left) when that keeps the arm out of `body` (ellipsoids, grown by `pad`: worn gear); otherwise toward the bend that
	is least inside it, the nearest such to `pole`, which on a round body swings the elbow out to the side so the upper
	arm angles away from the torso and the forearm comes back in to the item. An out-of-reach wrist straightens the
	arm toward it.
]=]
function AnimationCarryArmUtils.elbow(
	shoulder: Vector3,
	wrist: Vector3,
	upper: number,
	lower: number,
	side: number,
	pole: Vector3,
	body: { Body },
	pad: number
): Vector3
	local toWrist = wrist - shoulder
	local axis = unit(toWrist, -Vector3.yAxis)
	local span = math.clamp(toWrist.Magnitude, math.abs(upper - lower) + 1e-4, upper + lower - 1e-4)
	-- The elbow's circle: centred on the axis `along` from the shoulder, `radius` round it.
	local along = (upper * upper - lower * lower + span * span) / (2 * span)
	local radius = math.sqrt(math.max(0, upper * upper - along * along))
	local centre = shoulder + axis * along
	local wanted = pole * Vector3.new(side, 1, 1)
	local bend = wanted - axis * wanted:Dot(axis)
	if bend.Magnitude < 1e-6 then
		bend = Vector3.new(0, 1, 0):Cross(axis)
	end
	local u = unit(bend, Vector3.xAxis)
	local v = axis:Cross(u)
	local reached = shoulder + axis * span
	local function at(angle: number): (Vector3, number)
		local elbow = centre + (u * math.cos(angle) + v * math.sin(angle)) * radius
		return elbow, overlap(shoulder, elbow, reached, body, pad)
	end
	local best, bestOverlap = at(0)
	if bestOverlap <= 0 then
		return best
	end
	-- Nearest to the pole first (0, +step, -step, ...), so a tie keeps the bend closest to it.
	for k = 1, ELBOW_STEPS // 2 do
		for _, sign in { 1, -1 } do
			local elbow, inside = at(sign * k * 2 * math.pi / ELBOW_STEPS)
			if inside < bestOverlap - 1e-6 then
				best, bestOverlap = elbow, inside
			end
		end
	end
	return best
end

-- The arm placed with its elbow at `elbowAt` and wrist toward `wristAt`: the elbow flexed in its own hinge to the
-- bones' angle and the upper arm turned to carry both bones onto their lines (a straight arm folds away from the pole),
-- the forearm rolled (within LIMITS) to face the palm toward `facing`, the wrist bent (within WRIST_FLEX) for the rest.
local function place(arm: Arm, b: Bones, elbowAt: Vector3, wristAt: Vector3, facing: Vector3, pole: Vector3): Pose
	local u = unit(elbowAt - arm.shoulder, -Vector3.yAxis)
	local w = unit(wristAt - elbowAt, u)
	local angle = flexFor(b, u:Dot(w))
	local d = flexed(b, angle)
	-- The second axis of each pair: the forearm's line square to the upper bone (the way the forearm folds).
	local partFold = d - b.along * b.along:Dot(d)
	local worldFold = w - u * u:Dot(w)
	if partFold.Magnitude < STRAIGHT or worldFold.Magnitude < STRAIGHT then
		local wanted = pole * Vector3.new(arm.side, 1, 1)
		partFold = b.hinge:Cross(b.along)
		worldFold = -(wanted - u * wanted:Dot(u))
		if worldFold.Magnitude < 1e-6 then
			worldFold = FORWARD - u * u:Dot(FORWARD)
		end
	end
	local rotation = basis(b.along, partFold.Unit, u, worldFold.Unit)
	local upper = CFrame.new(arm.shoulder) * rotation * CFrame.new(-arm.shoulderInUpper)
	local elbowWorld = upper:PointToWorldSpace(arm.elbowInUpper)
	local bent = upper * lowerAt(arm, b, angle)
	local line = bent:VectorToWorldSpace(b.foreAlong)
	-- Forearm roll: toward the palm's wanted facing, kept inside pronation / supination of the palm-in neutral.
	local hinge = upper:VectorToWorldSpace(b.hinge)
	local normal = (bent * b.handInLower * arm.palmInHand).UpVector
	local roll = angleAbout(normal, facing, line)
	local limits = AnimationCarryArmUtils.LIMITS
	if math.deg(angle) >= limits.rollFrom then
		local across = unit(hinge - line * hinge:Dot(line), hinge)
		local medial = -arm.side * across
		local palmUp = across:Cross(line)
		local rolled = CFrame.fromAxisAngle(line, roll):VectorToWorldSpace(normal)
		local psi = math.deg(math.atan2(rolled:Dot(palmUp), rolled:Dot(medial)))
		local clamped = math.clamp(psi, -limits.pronate + MARGIN, limits.supinate - MARGIN)
		-- Rolling +a about the forearm turns the palm from medial toward palmUp on the right arm, away on the left.
		roll += math.rad(clamped - psi) * arm.side
	end
	local lower = about(elbowWorld, CFrame.fromAxisAngle(line, roll), bent)
	-- The wrist bends (flexion / extension about the palm's side axis) for what the forearm could not turn.
	local neutral = lower * b.handInLower
	local palm = neutral * arm.palmInHand
	local sideAxis = palm.RightVector
	local bend = math.clamp(angleAbout(palm.UpVector, facing, sideAxis), -math.rad(WRIST_FLEX), math.rad(WRIST_FLEX))
	local wristWorld = lower:PointToWorldSpace(arm.wristInLower)
	local hand = about(wristWorld, CFrame.fromAxisAngle(sideAxis, bend), neutral)
	return { upper = upper, lower = lower, hand = hand }
end

--[=[
	The arm's pose (root space) that puts its palm on `contact` (a palm frame in root space: UpVector the way the palm
	faces, into the item), elbow toward `pole` (see `elbow`) and out of `body`. `effector` is the point of the hand
	that goes there (hand space, turned as the palm): the palm (default), or the grip for a handle held in the fist.
	Unreachable contacts leave it short, along the arm toward it (AnimationCarryPoseRules reports the gap).
]=]
function AnimationCarryArmUtils.solve(
	arm: Arm,
	contact: CFrame,
	pole: Vector3,
	body: { Body },
	pad: number,
	effector: CFrame?
): Pose
	local b = bones(arm)
	local reaching = effector or arm.palmInHand
	local wristInEffector = reaching:PointToObjectSpace(arm.wristInHand)
	local aim = contact:PointToWorldSpace(wristInEffector)
	local pose: Pose = { upper = arm.upperRest, lower = arm.lowerRest, hand = arm.handRest }
	for _ = 1, LAND_STEPS do
		local elbowAt = AnimationCarryArmUtils.elbow(arm.shoulder, aim, b.upper, b.fore, arm.side, pole, body, pad)
		local toAim = aim - arm.shoulder
		local span = math.clamp(toAim.Magnitude, math.abs(b.upper - b.fore) + 1e-4, b.upper + b.fore - 1e-4)
		local wristAt = arm.shoulder + unit(toAim, -Vector3.yAxis) * span
		pose = place(arm, b, elbowAt, wristAt, contact.UpVector, pole)
		local miss = contact.Position - (pose.hand * reaching).Position
		if miss.Magnitude < LAND then
			break
		end
		aim += miss
	end
	return pose
end

--[=[
	The palm's frame (root space) in `pose`.
]=]
function AnimationCarryArmUtils.palm(arm: Arm, pose: Pose): CFrame
	return pose.hand * arm.palmInHand
end

--[=[
	The arm's reach to the palm's centre from the shoulder, straight with the wrist at rest.
]=]
function AnimationCarryArmUtils.reach(arm: Arm): number
	local b = bones(arm)
	return b.upper + b.fore + (arm.palmInHand.Position - arm.wristInHand).Magnitude
end

--[=[
	Where the arm can put its palm's centre (or `effector`, see `solve`) with the palm held at `rotation` (root space)
	and the wrist at rest: a sphere round the shoulder less the point's offset from the wrist (a big mitt's palm is
	well off the wrist), its radius the arm's length to the wrist. Returns (centre, radius).
]=]
function AnimationCarryArmUtils.palmSphere(arm: Arm, rotation: CFrame, effector: CFrame?): (Vector3, number)
	local b = bones(arm)
	local wristInEffector = (effector or arm.palmInHand):PointToObjectSpace(arm.wristInHand)
	return arm.shoulder - rotation:VectorToWorldSpace(wristInEffector), b.upper + b.fore
end

--[=[
	The arm's joint angles in `pose` (planned or live, root space), measured against its rest pose (see `Angles`). The
	shoulder is read against the torso: `torso` is how the torso is turned from its rest pose in the same space
	(identity when the pose is planned, or carried back onto the rest-posed torso).
]=]
function AnimationCarryArmUtils.angles(arm: Arm, pose: Pose, torso: CFrame?): Angles
	local b = bones(arm)
	local limits = AnimationCarryArmUtils.LIMITS
	-- The elbow: the forearm's line in the upper arm's space against its hinge.
	local d = pose.upper:VectorToObjectSpace(pose.lower:VectorToWorldSpace(b.foreAlong))
	local sideBend = math.deg(math.asin(math.clamp(d:Dot(b.hinge), -1, 1)))
	local flex = math.deg(angleAbout(b.foreRest, d, b.hinge))
	local u = pose.upper:VectorToWorldSpace(b.along)
	local line = pose.lower:VectorToWorldSpace(b.foreAlong)
	local hinge = pose.upper:VectorToWorldSpace(b.hinge)
	local turn = torso or CFrame.identity
	-- The forearm's roll, against the palm-in neutral of a bent elbow.
	local roll: number? = nil
	if flex >= limits.rollFrom then
		local across = unit(hinge - line * hinge:Dot(line), hinge)
		local normal = (pose.lower * b.handInLower * arm.palmInHand).UpVector
		roll = math.deg(math.atan2(normal:Dot(across:Cross(line)), normal:Dot(-arm.side * across)))
	end
	-- The hand against the hand the forearm carries at rest, in the palm's axes (X its side, Y out of it, -Z fingers).
	local neutral = (pose.lower * b.handInLower * arm.palmInHand).Rotation
	local actual = (pose.hand * arm.palmInHand).Rotation
	local relative = neutral:ToObjectSpace(actual)
	local fingers = relative.LookVector
	local out = relative.UpVector
	-- Which way a bent elbow points: away from where the forearm folds. The shoulder's angles in the torso's frame.
	local folds = turn:VectorToObjectSpace(pose.upper:VectorToWorldSpace(b.hinge:Cross(b.along)))
	local upperLine = turn:VectorToObjectSpace(u)
	return {
		flex = flex,
		sideBend = sideBend,
		roll = roll,
		wristFlex = math.deg(math.atan2(fingers.Y, -fingers.Z)),
		wristDeviation = math.deg(math.atan2(fingers.X, -fingers.Z)),
		wristTwist = math.deg(math.atan2(out.X, out.Y)),
		elevation = math.deg(math.asin(math.clamp(upperLine.Y, -1, 1))),
		behind = math.deg(math.asin(math.clamp(upperLine.Z, -1, 1))),
		elbowForward = if flex >= limits.rollFrom then unit(folds - upperLine * folds:Dot(upperLine), FORWARD).Z else 0,
	}
end

return AnimationCarryArmUtils
