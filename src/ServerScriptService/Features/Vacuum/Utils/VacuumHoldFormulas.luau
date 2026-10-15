--!strict
--[=[
	VacuumHoldFormulas: how a holder holds the backpack vacuum's wand, and how the wand is laid out. Pure.

	The canister rides on the back; the hands hold only a light wand with a floor head, as a real vacuum's wand is
	held: the right hand on the upper grip by the hose joint, the left hand lower down the wand. Each wand skin
	says where with two Attachments (the grip contract, characters/vacuum/README.md): `GripUpper` on `WandGrip`
	(the right hand) and `GripLower` on `WandTube` (the left hand); `WandDims.upper` / `lower` are read from them.

	The right hand is planned in HumanoidRootPart space (+Y up, -Z front): in front of the belly on the right,
	a little below the shoulder, inside the arm's reach so the elbow bends (the hand is turned so the forearm runs
	straight into it: no wrist-only bend). The wand runs from it forward and down at a fixed lean, turned in
	toward the middle (`yaw`), so its lower grip lies in front of the body where the left hand reaches it with
	its elbow out and forward (the forearm passes in front of the belly, not through it). The wand telescopes:
	its tube is as long as rests the floor head flat on the floor from the grip's height, so a short chibi and a
	tall stock avatar both clean with the head on the floor and nothing in it.

	@class VacuumHoldFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- An arm in root space: its shoulder pivot, the upper arm's length, and the forearm + hand's to the grip.
export type Arm = { shoulder: Vector3, upper: number, lower: number }

-- The wand's measurements (studs, as built): half the grip's length, the hose inlet's height above it, the
-- swivel's radius and the floor head's height; and the grips: how far up the wand from the grip's centre the
-- right hand holds (`GripUpper`), and how far down the tube from its top the left hand holds (`GripLower`).
export type WandDims = {
	gripHalf: number,
	inlet: number,
	swivel: number,
	head: number,
	upper: number,
	lower: number,
}

-- The hold's tuning (VacuumVisualConstants.hold): where the right hand sits as fractions of the arm's reach
-- (down, forward, out; a negative `out` is in toward the middle), the wand's lean from vertical and its turn
-- in toward the middle (radians), the head's clearance over the floor and the shortest tube.
export type Tuning = {
	down: number,
	forward: number,
	out: number,
	angle: number,
	yaw: number,
	clearance: number,
	minTube: number,
}

export type Hold = {
	-- Root-space frame for the RightGripAttachment (an IK target): the hand on the wand's GripUpper.
	grip: CFrame,
	-- The Tool's Grip: with the hand there, the handle (the WandGrip's centre) sits square to the root, GripUpper
	-- in the hand.
	toolGrip: CFrame,
	-- Root-space points the elbows bend toward.
	rightPole: Vector3,
	leftPole: Vector3,
	-- Root-space frame for the LeftGripAttachment on the wand's GripLower (its hand turned along its forearm, like
	-- the right), nil when the left arm cannot reach it.
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
-- The right elbow bends outward and a little down and forward: its forearm then reaches the grip from the side,
-- clear of the chest (bent down and back, it lay along Pippa's vest). The left hand reaches forward to the wand in
-- front of the body, so its elbow bends outward and well FORWARD: the forearm then comes in round the front of a
-- round chibi belly instead of through it (bent down and back, the forearm ran through Pippa's torso and vest).
local RIGHT_POLE = Vector3.new(1, -0.3, -0.3).Unit
local LEFT_POLE = Vector3.new(-1, 0, -1).Unit
-- Never plan the left hand at the arm's full stretch.
local REACH_USE = 0.95
local X_AXIS = Vector3.new(1, 0, 0)

--[=[
	The wand's axis in root space, from the grip toward the floor head, leaning `angle` forward from vertical and
	turned `yaw` about the vertical (a positive yaw swings its lower end toward -X, the wearer's left).
]=]
function VacuumHoldFormulas.axis(angle: number, yaw: number): Vector3
	return Vector3.new(-math.sin(angle) * math.sin(yaw), -math.cos(angle), -math.sin(angle) * math.cos(yaw))
end

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
	The stowed wand's tube (studs): telescoped so that, hanging from its grip on the pack at `lean` from vertical,
	the floor head's bottom is level with the hip joint `gripAboveHip` below the grip's centre. Hip height keeps
	it clear of the floor through the walk, the run's lean and a landing's crouch, and above the feet. Never
	longer than the held tube (`maxTube`) nor shorter than `minTube`.
]=]
function VacuumHoldFormulas.stowTube(
	gripAboveHip: number,
	wand: WandDims,
	lean: number,
	minTube: number,
	maxTube: number
): number
	return math.min(maxTube, VacuumHoldFormulas.tube(gripAboveHip, wand, lean, 0, minTube))
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
	local along = VacuumHoldFormulas.axis(tuning.angle, tuning.yaw)
	-- The handle (the grip's centre) is `upper` down the wand from the right hand.
	local handle = target + along * wand.upper
	local height = handle.Y - floorY
	local tube = VacuumHoldFormulas.tube(height, wand, tuning.angle, tuning.clearance, tuning.minTube)
	local leftTarget: CFrame? = nil
	local leftPole = right.shoulder * Vector3.new(-1, 1, 1) + LEFT_POLE * reach
	if left ~= nil then
		leftPole = left.shoulder + LEFT_POLE * (left.upper + left.lower)
		local candidate = handle + along * (wand.gripHalf + math.min(wand.lower, tube))
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
		-- handle = grip * toolGrip:Inverse(): square to the root, `upper` down the wand from the hand.
		toolGrip = CFrame.new(-along * wand.upper) * grip.Rotation,
		rightPole = rightPole,
		leftPole = leftPole,
		left = leftTarget,
		tube = tube,
		height = height,
	}
end

--[=[
	The wand's pieces in handle space for a `tube` this long leaning `angle` forward from vertical and turned
	`yaw` in (VacuumHoldFormulas.axis): the grip at the handle, the inlet on top of it, the tube and swivel down
	the wand, and the floor head flat and square to the handle (turned `headYaw` about the vertical) under the
	swivel. Every piece on the wand's axis has its +Y up the wand.
]=]
function VacuumHoldFormulas.wand(
	wand: WandDims,
	tube: number,
	angle: number,
	headYaw: number?,
	yaw: number?
): WandFrames
	local turn = yaw or 0
	local along = VacuumHoldFormulas.axis(angle, turn)
	local up = -along
	local across = Vector3.new(math.cos(turn), 0, -math.sin(turn))
	local function onAxis(at: Vector3): CFrame
		return CFrame.fromMatrix(at, across, up)
	end
	local swivel = along * (wand.gripHalf + tube + wand.swivel)
	local top = up * (wand.gripHalf + wand.inlet)
	return {
		grip = onAxis(Vector3.zero),
		inlet = onAxis(up * (wand.gripHalf + wand.inlet / 2)),
		tube = onAxis(along * (wand.gripHalf + tube / 2)),
		swivel = CFrame.new(swivel),
		head = CFrame.new(swivel - Vector3.new(0, wand.swivel + wand.head / 2, 0)) * CFrame.Angles(0, headYaw or 0, 0),
		hose = CFrame.fromMatrix(top, along, across),
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
