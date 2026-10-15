--!strict
--[=[
	VacuumHoldFormulas: how a holder holds the backpack vacuum's wand, and how the wand is laid out. Pure.

	The canister rides on the back; the hands hold only a light wand with a floor head. The right hand's grip is
	planned in HumanoidRootPart space (+Y up, -Z front): well in front of the belly, below the shoulder and a
	little in toward the middle, inside the arm's reach so the elbow bends (the hand is turned so the forearm
	runs straight into it: no wrist-only bend), the left hand on the wand just above it when it reaches, its
	elbow out and forward so the forearm passes in front of the body. The wand leans forward from the grip at a fixed
	angle and telescopes: its tube is as long as rests the floor head flat on the floor from that grip's height,
	so a short chibi and a tall stock avatar both clean with the head on the floor and nothing in it.

	@class VacuumHoldFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- An arm in root space: its shoulder pivot, the upper arm's length, and the forearm + hand's to the grip.
export type Arm = { shoulder: Vector3, upper: number, lower: number }

-- The wand's measurements (studs, as built): half the grip's length, the hose inlet's height above it, the
-- swivel's radius and the floor head's height.
export type WandDims = { gripHalf: number, inlet: number, swivel: number, head: number }

-- The hold's tuning (VacuumVisualConstants.hold): where the grip sits as fractions of the arm's reach
-- (down, forward, out; a negative `out` is in toward the middle), the wand's lean from vertical (radians), the head's clearance over the floor, the
-- shortest tube, and how far up the wand the left hand holds.
export type Tuning = {
	down: number,
	forward: number,
	out: number,
	angle: number,
	clearance: number,
	minTube: number,
	leftUp: number,
}

export type Hold = {
	-- Root-space frame for the right RightGripAttachment (an IK target).
	grip: CFrame,
	-- The Tool's Grip: with the hand there, the handle sits square to the root at the grip.
	toolGrip: CFrame,
	-- Root-space points the elbows bend toward.
	rightPole: Vector3,
	leftPole: Vector3,
	-- Root-space frame for the LeftGripAttachment on the wand (its hand turned along its forearm, like the
	-- right), nil when the left arm cannot reach the wand.
	left: CFrame?,
	-- The wand tube's length, and the grip's height above the floor.
	tube: number,
	height: number,
}

-- Handle-space frames of the wand's pieces (the handle is at the grip, square to the root).
export type WandFrames = {
	grip: CFrame,
	inlet: CFrame,
	tube: CFrame,
	swivel: CFrame,
	head: CFrame,
	-- Where the hose meets the wand; its X axis points into the wand (a Beam's Attachment1 axis).
	hose: CFrame,
}

local VacuumHoldFormulas = {}

-- The stock RightGripAttachment's turn in its hand (EmployeeRigUtils gives a generated one the same).
local STOCK_GRIP_TURN = CFrame.Angles(-math.pi / 2, 0, 0)
-- The right elbow bends outward, down and a little back. The left hand reaches across to the wand in front of
-- the right side, so its elbow bends outward and FORWARD: the forearm then comes in round the front of a round
-- chibi belly instead of through it (bent down and back, the forearm ran through Pippa's torso and vest).
local RIGHT_POLE = Vector3.new(1, -0.6, 0.5).Unit
local LEFT_POLE = Vector3.new(-1, 0, -0.6).Unit
-- Never plan the left hand at the arm's full stretch.
local REACH_USE = 0.95
local X_AXIS = Vector3.new(1, 0, 0)

--[=[
	Where an arm's elbow is when its hand is at `target`: `upper` from the shoulder, `lower` from the target,
	bent toward `pole` (a direction); straight toward a target out of reach.
]=]
function VacuumHoldFormulas.elbow(
	shoulder: Vector3,
	target: Vector3,
	upper: number,
	lower: number,
	pole: Vector3
): Vector3
	local offset = target - shoulder
	local distance = offset.Magnitude
	if distance < 1e-6 then
		return shoulder + pole.Unit * upper
	end
	local along = offset / distance
	if distance >= upper + lower then
		return shoulder + along * upper
	end
	distance = math.max(distance, math.abs(upper - lower) + 1e-6)
	local x = (upper * upper - lower * lower + distance * distance) / (2 * distance)
	local r = math.sqrt(math.max(0, upper * upper - x * x))
	local side = pole - along * pole:Dot(along)
	if side.Magnitude < 1e-6 then
		side = along:Cross(Vector3.zAxis)
		if side.Magnitude < 1e-6 then
			side = along:Cross(Vector3.xAxis)
		end
	end
	return shoulder + along * x + side.Unit * r
end

-- The grip attachment's frame at `target` for an arm whose elbow is at `elbow`: the stock hand's -Y laid along
-- the forearm, its X kept as near the root's as it goes, turned as the stock grip attachment is in its hand.
local function gripFrame(target: Vector3, elbow: Vector3): CFrame
	local handUp = -(target - elbow).Unit
	local handRight = (X_AXIS - handUp * X_AXIS:Dot(handUp)).Unit
	return CFrame.fromMatrix(target, handRight, handUp, handRight:Cross(handUp)) * STOCK_GRIP_TURN
end

--[=[
	The tube length (studs, at least `minTube`) that rests the floor head `clearance` above the floor for a grip
	`height` above it, the wand leaning `angle` from vertical.
]=]
function VacuumHoldFormulas.tube(
	height: number,
	wand: WandDims,
	angle: number,
	clearance: number,
	minTube: number
): number
	local along = (height - clearance - wand.swivel - wand.head) / math.cos(angle)
	return math.max(minTube, along - wand.gripHalf - wand.swivel)
end

--[=[
	The hold for a holder's arms (root space) over a floor `floorY` below the root.
]=]
function VacuumHoldFormulas.hold(right: Arm, left: Arm?, floorY: number, wand: WandDims, tuning: Tuning): Hold
	local reach = right.upper + right.lower
	local target = right.shoulder + Vector3.new(tuning.out, -tuning.down, -tuning.forward) * reach
	local rightPole = right.shoulder + RIGHT_POLE * reach
	local grip =
		gripFrame(target, VacuumHoldFormulas.elbow(right.shoulder, target, right.upper, right.lower, RIGHT_POLE))
	local height = target.Y - floorY
	local up = Vector3.new(0, math.cos(tuning.angle), math.sin(tuning.angle))
	local leftTarget: CFrame? = nil
	local leftPole = right.shoulder * Vector3.new(-1, 1, 1) + LEFT_POLE * reach
	if left ~= nil then
		leftPole = left.shoulder + LEFT_POLE * (left.upper + left.lower)
		local candidate = target + up * tuning.leftUp
		if (candidate - left.shoulder).Magnitude <= REACH_USE * (left.upper + left.lower) then
			-- A Transform target: the engine's Position-only solve left this hand ~0.75 studs off (Studio).
			leftTarget = gripFrame(
				candidate,
				VacuumHoldFormulas.elbow(left.shoulder, candidate, left.upper, left.lower, LEFT_POLE)
			)
		end
	end
	return {
		grip = grip,
		toolGrip = grip.Rotation,
		rightPole = rightPole,
		leftPole = leftPole,
		left = leftTarget,
		tube = VacuumHoldFormulas.tube(height, wand, tuning.angle, tuning.clearance, tuning.minTube),
		height = height,
	}
end

--[=[
	The wand's pieces in handle space for a `tube` this long leaning `angle` forward from vertical: the grip at
	the handle, the inlet on top of it, the tube and swivel down the wand, and the floor head flat (turned
	`headYaw` about the vertical) under the swivel.
]=]
function VacuumHoldFormulas.wand(wand: WandDims, tube: number, angle: number, headYaw: number?): WandFrames
	local along = Vector3.new(0, -math.cos(angle), -math.sin(angle))
	local up = -along
	local function onAxis(at: Vector3): CFrame
		return CFrame.fromMatrix(at, Vector3.xAxis, up)
	end
	local swivel = along * (wand.gripHalf + tube + wand.swivel)
	local top = up * (wand.gripHalf + wand.inlet)
	return {
		grip = onAxis(Vector3.zero),
		inlet = onAxis(up * (wand.gripHalf + wand.inlet / 2)),
		tube = onAxis(along * (wand.gripHalf + tube / 2)),
		swivel = CFrame.new(swivel),
		head = CFrame.new(swivel - Vector3.new(0, wand.swivel + wand.head / 2, 0)) * CFrame.Angles(0, headYaw or 0, 0),
		hose = CFrame.fromMatrix(top, along, Vector3.xAxis),
	}
end

--[=[
	A backpack fit for a body with no registry fit (a stock avatar), from its UpperTorso's size (studs): the pack
	on the torso's back face a little above its middle, `size` big; the straps (modelled round a torso
	`reference` big, their loops `strapDepth` deep) stretched to its width and height and deep enough to clear it.
]=]
function VacuumHoldFormulas.genericFit(
	torso: Vector3,
	reference: Vector3,
	strapDepth: number,
	size: number
): EmployeeRegistry.BackpackFit
	return {
		mount = CFrame.new(0, torso.Y * 0.1, torso.Z / 2),
		size = size,
		strapOffset = CFrame.identity,
		strapStretch = Vector3.new(torso.X / reference.X, torso.Y / reference.Y, (torso.Z + 0.1) / strapDepth),
	}
end

return VacuumHoldFormulas
