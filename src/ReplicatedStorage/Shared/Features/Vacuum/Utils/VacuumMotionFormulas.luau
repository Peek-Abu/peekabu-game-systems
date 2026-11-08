--!strict
--[=[
	VacuumMotionFormulas: the maths of the held vacuum's motion layers (VacuumMotionConstants). Pure.

	Every layer moves the wand as ONE rigid body turned about one point on it, the pivot (`wand`; the left paw's grip,
	GripLower, as Pippa's left arm is planned near its full reach and the right one has room): the two IK
	targets (AnimationVacuumHoldSystem) are both moved by the same root-space transform, so the right hand carries
	the wand (the Tool is welded to it) and the left hand's target is still exactly on GripLower, wherever the wand
	goes. The floor head is never let under the floor: a pose that would sink it is flattened out about the pivot
	(the head slides further out along the floor) until it just clears.

	- `aim`: the camera's look pitch to a raise (radians) and a reach (-1..1, out positive). `encodeAim` / `decodeAim`: the byte the
	  client sends and the server checks.
	- `offsetOf`: the layers' state to the wand's offset (`wand`'s input).
	- `kickScale` / `kickImpulse`: how hard a pile's pop kicks, as the spring's starting speed; `shimmy` the suction
	  shimmy at a pile's progress.
	- `swayTargets`: where the wand's lag swings for a turn and a stop; `packTarget` / `packFrequency` / `packFrame`
	  the canister's bob on the back.
	- `braceTarget` / `body`: how deep a holder braces, and the hip drop and lean that makes; `legFold` the hip, knee
	  and ankle turns that drop the hips with the feet planted.
	- `step`: one damped spring.

	@class VacuumMotionFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)

-- The left paw's hold (root space, at rest): its point on the wand (GripLower), its shoulder, and the arm's reach.
export type LeftHold = { at: Vector3, shoulder: Vector3, reach: number }

-- The rest hold in root space: the point every layer turns about (the pivot: the left paw's grip, else the right's), the floor head's bottom corners, the
-- floor's height, the left paw's hold (nil: one-handed) and the waist joint the brace leans over (nil: no lean).
export type WandRest = {
	pivot: Vector3,
	corners: { Vector3 },
	floorY: number,
	left: LeftHold?,
	waist: Vector3?,
	-- The right paw's grip (root space, at rest) and the chest it must stay out of (the UpperTorso's centre and half
	-- size, root space): `turnLimit`. Nil: the turn right is not limited by the body.
	right: Vector3?,
	torso: { centre: Vector3, half: Vector3 }?,
}

-- How the wand is moved off its rest: the pivot translated `offset` (root space), and turned about it by `yaw`
-- (about the vertical), `pitch` (about the root's X: positive raises the floor head out in front) and `roll` (about
-- the root's Z).
export type WandOffset = { offset: Vector3, pitch: number, yaw: number, roll: number }

-- The layers' state: the aim's raise (radians) and reach (-1..1, out positive), the brace's weight (0..1), the pop kick (its
-- spring: 1 is a reference pile's peak), the suction shimmy's turn and roll and the wand's lag (its turn and tip;
-- radians).
export type Layers = {
	raise: number,
	reach: number,
	brace: number,
	kick: number,
	shimmyYaw: number,
	shimmyRoll: number,
	swayYaw: number,
	swayPitch: number,
	-- The aim's turn toward where its holder looks, left or right (radians; nil reads 0).
	aimYaw: number?,
	-- The look's heading off the body (radians, left positive; nil reads 0): the wand aims at it (`aimYaw`).
	lookYaw: number?,
}

export type AimTuning = {
	neutral: number,
	deadHigh: number,
	gainUp: number,
	maxUp: number,
	fullDown: number,
}

local VacuumMotionFormulas = {}

-- A floor clamp flattens the wand by at most this much (radians) before it lifts it instead.
local MAX_FLATTEN = 0.8
local BISECTIONS = 24
-- The look pitch on the wire: whole quanta of degrees from -90.
local AIM_LOW = -90
local AIM_STEPS = 36
-- The look yaw on the wire: whole quanta of degrees from -YAW_RANGE.
local YAW_RANGE = 60
local YAW_STEPS = 24

--[=[
	Advances a damped spring (`frequency` Hz, `damping` ratio) toward `target` by `dt`, exactly (the closed-form
	solution, so a kick's analytic peak is the one shown at any frame rate); a hitch longer than Constants.maxStep is
	only advanced that far.
	@return (position, velocity)
]=]
function VacuumMotionFormulas.step(
	x: number,
	v: number,
	target: number,
	dt: number,
	frequency: number,
	damping: number
): (number, number)
	if dt <= 0 then
		return x, v
	end
	local h = math.min(dt, Constants.maxStep)
	local omega = 2 * math.pi * frequency
	local zeta = math.max(damping, 0)
	local x0 = x - target
	if math.abs(zeta - 1) < 1e-4 then
		local decay = math.exp(-omega * h)
		local b = v + omega * x0
		return target + decay * (x0 + b * h), decay * (v - omega * b * h)
	elseif zeta < 1 then
		local damped = omega * math.sqrt(1 - zeta * zeta)
		local decay = math.exp(-zeta * omega * h)
		local c, s = math.cos(damped * h), math.sin(damped * h)
		return target + decay * (x0 * c + (v + zeta * omega * x0) / damped * s),
			decay * (v * c - (omega * omega * x0 + zeta * omega * v) / damped * s)
	end
	local root = math.sqrt(zeta * zeta - 1)
	local r1, r2 = -omega * (zeta - root), -omega * (zeta + root)
	local c1 = (v - r2 * x0) / (r1 - r2)
	local c2 = x0 - c1
	local e1, e2 = math.exp(r1 * h), math.exp(r2 * h)
	return target + c1 * e1 + c2 * e2, c1 * r1 * e1 + c2 * r2 * e2
end

--[=[
	The camera's look pitch (radians, up positive) to the wand's raise (radians about the wand's pivot) and its reach
	(-1..1: out positive, in negative): 0 and 0 at the default third-person view (`neutral`), the reach out toward
	`deadHigh` and in toward `fullDown`, the raise past `deadHigh`.
]=]
function VacuumMotionFormulas.aim(look: number, tuning: AimTuning): (number, number)
	local raise = if look > tuning.deadHigh then math.min(tuning.maxUp, (look - tuning.deadHigh) * tuning.gainUp) else 0
	local reach = if look >= tuning.neutral
		then math.min(1, (look - tuning.neutral) / (tuning.deadHigh - tuning.neutral))
		else -math.min(1, (tuning.neutral - look) / (tuning.neutral - tuning.fullDown))
	return raise, reach
end

--[=[
	The look pitch (radians) as the byte the client sends: whole quanta of degrees from -90, clamped to +-90.
]=]
function VacuumMotionFormulas.encodeAim(look: number): number
	local quantum = math.deg(Constants.aim.quantum)
	return math.clamp(math.round((math.deg(look) - AIM_LOW) / quantum), 0, AIM_STEPS)
end

--[=[
	The look pitch in degrees a sent byte stands for; nil for anything the client cannot send.
]=]
function VacuumMotionFormulas.decodeAim(byte: number): number?
	if byte ~= byte or byte ~= math.floor(byte) or byte < 0 or byte > AIM_STEPS then
		return nil
	end
	return AIM_LOW + byte * math.deg(Constants.aim.quantum)
end

--[=[
	A look's flat heading (radians, left positive, -pi..pi; 0 is the -Z axis).
]=]
function VacuumMotionFormulas.heading(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

--[=[
	The body's next heading as it eases from `heading` toward the camera's `target` over `dt` (Constants.face): the
	short way round, a share of the gap each frame (time constant `ease`), never faster than `maxRate`.
]=]
function VacuumMotionFormulas.faceToward(heading: number, target: number, dt: number): number
	if dt <= 0 then
		return heading
	end
	local tuning = Constants.face
	local gap = wrapAngle(target - heading)
	local turn = gap * (1 - math.exp(-math.min(dt, Constants.maxStep) / tuning.ease))
	local most = tuning.maxRate * dt
	return wrapAngle(heading + math.clamp(turn, -most, most))
end

--[=[
	Where the camera looks relative to the body, left or right (radians, left positive, -pi..pi): the flat headings of
	the camera's look and the body's look.
]=]
function VacuumMotionFormulas.relativeYaw(cameraLook: Vector3, bodyLook: Vector3): number
	return wrapAngle(VacuumMotionFormulas.heading(cameraLook) - VacuumMotionFormulas.heading(bodyLook))
end

--[=[
	The look's heading off the body (radians, left positive) the wand aims at: `relative` within Constants.aim.maxLook
	either way; looking back past the side, it eases back to straight ahead (0 straight behind), so a look swung
	across the back never snaps the wand from one side to the other.
]=]
function VacuumMotionFormulas.lookHeading(relative: number): number
	local most = Constants.aim.maxLook
	local turn = wrapAngle(relative)
	local size = math.abs(turn)
	if size <= math.pi / 2 then
		return math.clamp(turn, -most, most)
	end
	local side = if turn >= 0 then 1 else -1
	return side * most * (math.pi - size) / (math.pi / 2)
end

--[=[
	How far out on the floor (studs from the root) a look `pitch` (radians, up positive) lands, within near..far:
	near at nearPitch and below, far at farPitch and above.
]=]
function VacuumMotionFormulas.lookDistance(pitch: number): number
	local aim = Constants.aim
	local share = math.clamp((pitch - aim.nearPitch) / (aim.farPitch - aim.nearPitch), 0, 1)
	return aim.near + (aim.far - aim.near) * share
end

-- The floor head's centre at rest (root space): the middle of its bottom corners.
local function headCentre(rest: WandRest): Vector3
	local sum = Vector3.zero
	for _, corner in rest.corners do
		sum += corner
	end
	return if #rest.corners > 0 then sum / #rest.corners else rest.pivot
end

--[=[
	The most the wand may turn right about its pivot (radians, positive) before the right paw's grip, swung round
	with it, comes within Constants.armClear of the chest (an ellipse filling the UpperTorso, seen from above): its
	forearm would pass into the body (owner note 2026-11-08). At most aim.maxYawRight; 0 when it is there at rest.
]=]
function VacuumMotionFormulas.turnLimit(rest: WandRest): number
	local most = Constants.aim.maxYawRight
	local right, torso = rest.right, rest.torso
	if right == nil or torso == nil then
		return most
	end
	local a, b = torso.half.X + Constants.armClear, torso.half.Z + Constants.armClear
	local function inside(yaw: number): boolean
		local p = CFrame.new(rest.pivot) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-rest.pivot) * right
		return ((p.X - torso.centre.X) / a) ^ 2 + ((p.Z - torso.centre.Z) / b) ^ 2 < 1
	end
	if inside(0) then
		return 0
	end
	local step = math.rad(1)
	local yaw = 0
	while yaw + step <= most do
		if inside(yaw + step) then
			return yaw
		end
		yaw += step
	end
	return most
end

--[=[
	The wand's turn about its pivot (radians, left positive) that points the floor head at the look point `distance`
	studs out along the look's `heading` from the root, within Constants.aim's maxYawLeft / maxYawRight.
	Purely visual (the suction aims by the body, not the camera).
]=]
function VacuumMotionFormulas.aimYaw(rest: WandRest, heading: number, distance: number): number
	local aim = Constants.aim
	local pivot = rest.pivot
	local head = headCentre(rest)
	local target = Vector3.new(-math.sin(heading) * distance, 0, -math.cos(heading) * distance)
	local want = VacuumMotionFormulas.heading(Vector3.new(target.X - pivot.X, 0, target.Z - pivot.Z))
	local now = VacuumMotionFormulas.heading(Vector3.new(head.X - pivot.X, 0, head.Z - pivot.Z))
	return math.clamp(wrapAngle(want - now), -VacuumMotionFormulas.turnLimit(rest), aim.maxYawLeft)
end

--[=[
	The look yaw (radians, relative to the body) as the byte the client sends: whole quanta of degrees from -60, clamped.
]=]
function VacuumMotionFormulas.encodeYaw(relative: number): number
	local quantum = math.deg(Constants.aim.quantum)
	return math.clamp(math.round((math.deg(relative) + YAW_RANGE) / quantum), 0, YAW_STEPS)
end

--[=[
	The look yaw in degrees a sent byte stands for; nil for anything the client cannot send.
]=]
function VacuumMotionFormulas.decodeYaw(byte: number): number?
	if byte ~= byte or byte ~= math.floor(byte) or byte < 0 or byte > YAW_STEPS then
		return nil
	end
	return -YAW_RANGE + byte * math.deg(Constants.aim.quantum)
end

--[=[
	The wand's offset for the layers' state (its turns together within Constants.aim's maxYawLeft / maxYawRight):
	the aim's raise turns it about its pivot; its reach and the brace
	move the hands (down and out for a reach out, up and back for a reach in, down and in toward the body for
	the brace); the kick jolts them back
	and up and hops the floor head; the shimmy turns and rolls it; the sway turns and tips it.
]=]
function VacuumMotionFormulas.offsetOf(layers: Layers): WandOffset
	local aim, brace, kick = Constants.aim, Constants.brace, Constants.kick
	-- The reach out (positive) and in (negative).
	local out, inward = math.max(layers.reach, 0), math.max(-layers.reach, 0)
	return {
		offset = Vector3.new(
			0,
			-(out * aim.reachDrop + layers.brace * brace.handDrop) + inward * aim.inLift + layers.kick * kick.lift,
			-out * aim.reachForward
				+ inward * aim.inBack
				+ layers.brace * brace.pull
				+ layers.kick * kick.lift * kick.back
		),
		pitch = layers.raise + layers.kick * kick.pitch + layers.swayPitch,
		yaw = math.clamp(layers.shimmyYaw + layers.swayYaw + (layers.aimYaw or 0), -aim.maxYawRight, aim.maxYawLeft),
		roll = layers.shimmyRoll,
	}
end

--[=[
	How hard a pile `size` studs across (its base size's length) kicks the wand when it pops: 1 for a reference pile,
	within Constants.kick's bounds.
]=]
function VacuumMotionFormulas.kickScale(size: number): number
	local kick = Constants.kick
	return math.clamp(size / kick.sizeRef, kick.minScale, kick.maxScale)
end

--[=[
	The starting speed that makes the kick's spring (at rest, Constants.kick's frequency and damping) peak at `scale`.
	An underdamped spring started at speed v0 peaks at v0 / omega * exp(-damping * omega * t*), t* its peak's time.
]=]
function VacuumMotionFormulas.kickImpulse(scale: number): number
	local kick = Constants.kick
	local omega = 2 * math.pi * kick.frequency
	local zeta = math.clamp(kick.damping, 0.01, 0.99)
	local damped = omega * math.sqrt(1 - zeta * zeta)
	local peakAt = math.atan2(math.sqrt(1 - zeta * zeta), zeta) / damped
	return scale * omega * math.exp(zeta * omega * peakAt)
end

--[=[
	The suction shimmy's turn and roll (radians) at time `t` (seconds), for a holder `seed`, on a pile `progress`
	(0..1) done, faded by `weight` (0..1, how far into sucking the holder is): two layered sines each, from
	Constants.shimmy.base of the amplitude at the start of a pile to all of it as it nears done (progress squared).
]=]
function VacuumMotionFormulas.shimmy(t: number, seed: number, progress: number, weight: number): (number, number)
	local tuning = Constants.shimmy
	local p = math.clamp(progress, 0, 1)
	local amount = math.clamp(weight, 0, 1) * (tuning.base + (1 - tuning.base) * p * p)
	if amount <= 0 then
		return 0, 0
	end
	local w = 2 * math.pi * tuning.frequency
	local phase = seed * 1.618
	local yaw = 0.6 * math.sin(w * t + phase) + 0.4 * math.sin(w * 1.7 * t + phase * 2.3)
	local roll = 0.6 * math.sin(w * 0.83 * t + phase * 3.1 + 1) + 0.4 * math.sin(w * 1.37 * t + phase * 0.7 + 2)
	return amount * tuning.yaw * yaw, amount * tuning.roll * roll
end

local function frameAt(rest: WandRest, offset: WandOffset, pitch: number): CFrame
	return CFrame.new(rest.pivot + offset.offset)
		* CFrame.Angles(0, offset.yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.Angles(0, 0, offset.roll)
		* CFrame.new(-rest.pivot)
end

local function lowest(rest: WandRest, transform: CFrame): number
	local y = math.huge
	for _, corner in rest.corners do
		y = math.min(y, (transform * corner).Y)
	end
	return y
end

-- The floor clamp alone (`wand` without the reach).
local function clamped(rest: WandRest, offset: WandOffset, margin: number): (CFrame, number)
	local floor = rest.floorY + margin
	local transform = frameAt(rest, offset, offset.pitch)
	if lowest(rest, transform) >= floor then
		return transform, offset.pitch
	end
	local low, high = offset.pitch, offset.pitch + MAX_FLATTEN
	if lowest(rest, frameAt(rest, offset, high)) < floor then
		return CFrame.new(0, floor - lowest(rest, transform), 0) * transform, offset.pitch
	end
	for _ = 1, BISECTIONS do
		local middle = (low + high) / 2
		if lowest(rest, frameAt(rest, offset, middle)) >= floor then
			high = middle
		else
			low = middle
		end
	end
	return frameAt(rest, offset, high), high
end

-- The offset with only its move scaled by `k` (the turns whole).
local function movedBy(offset: WandOffset, k: number): WandOffset
	return { offset = offset.offset * k, pitch = offset.pitch, yaw = offset.yaw, roll = offset.roll }
end

-- The offset scaled by `k` (every layer together).
local function scaledBy(offset: WandOffset, k: number): WandOffset
	return { offset = offset.offset * k, pitch = offset.pitch * k, yaw = offset.yaw * k, roll = offset.roll * k }
end

--[=[
	The upper body's root-space motion for a brace that drops the hips `drop` and leans `lean` forward over the waist
	joint at `waist` (identity without one): the left shoulder rides it.
]=]
function VacuumMotionFormulas.motion(waist: Vector3?, drop: number, lean: number, twist: number?): CFrame
	if waist == nil then
		return CFrame.identity
	end
	return CFrame.new(0, -drop, 0)
		* CFrame.new(waist)
		* CFrame.Angles(-lean, 0, 0)
		* CFrame.Angles(0, twist or 0, 0)
		* CFrame.new(-waist)
end

--[=[
	How far the upper body turns over the waist with a turn of `heading` (radians): `twistShare` of it.
]=]
function VacuumMotionFormulas.twist(heading: number): number
	return heading * Constants.aim.twistShare
end

--[=[
	The upper body's twist for the layers' state (with the brace's `drop` and `lean`): a share of the wand's turn off
	its aim straight ahead (and its sway), so the shoulders follow the wand round, fitted by `fitTwist`.
]=]
function VacuumMotionFormulas.bodyTwist(rest: WandRest, layers: Layers, drop: number, lean: number): number
	local ahead = VacuumMotionFormulas.aimYaw(rest, 0, Constants.aim.far)
	local turn = (layers.aimYaw or ahead) - ahead + layers.swayYaw
	return VacuumMotionFormulas.fitTwist(rest, drop, lean, VacuumMotionFormulas.twist(turn))
end

--[=[
	The body's `twist` (with the brace's `drop` and `lean`) scaled back as far as it must so the left shoulder stays
	within reach of its grip at rest (`reaches`); whole when it does, or with no left paw.
]=]
function VacuumMotionFormulas.fitTwist(rest: WandRest, drop: number, lean: number, twist: number): number
	local waist = rest.waist
	local function fits(k: number): boolean
		return VacuumMotionFormulas.reaches(
			rest,
			CFrame.identity,
			VacuumMotionFormulas.motion(waist, drop, lean, twist * k)
		)
	end
	if rest.left == nil or fits(1) then
		return twist
	end
	if not fits(0) then
		return 0
	end
	local low, high = 0, 1
	for _ = 1, BISECTIONS do
		local middle = (low + high) / 2
		if fits(middle) then
			low = middle
		else
			high = middle
		end
	end
	return twist * low
end

--[=[
	Whether the left paw can still reach its grip with the wand moved by `transform` and the upper body by `body`.
]=]
function VacuumMotionFormulas.reaches(rest: WandRest, transform: CFrame, body: CFrame): boolean
	local left = rest.left
	if left == nil then
		return true
	end
	return (transform * left.at - body * left.shoulder).Magnitude
		<= Constants.reachUse * left.reach + Constants.reachSlack
end

--[=[
	The root-space transform that moves the rest hold by `offset` (both IK targets are moved by it), with the floor
	head's lowest corner kept `margin` over the floor (flattened about the pivot by the least pitch that clears,
	else lifted), and the left paw's grip kept within its arm's reach (`reaches`, the upper body moved by `body`): if
	it would not be, its move is scaled back (the turns kept whole) until it is, every layer together only if no move
	can help. Also returns the pitch used.
]=]
function VacuumMotionFormulas.wand(rest: WandRest, given: WandOffset, margin: number, body: CFrame?): (CFrame, number)
	local moved = body or CFrame.identity
	-- The turns together never take the right paw into the chest (turnLimit).
	local limit = VacuumMotionFormulas.turnLimit(rest)
	local offset = if given.yaw < -limit
		then { offset = given.offset, pitch = given.pitch, yaw = -limit, roll = given.roll }
		else given
	local transform, pitch = clamped(rest, offset, margin)
	if VacuumMotionFormulas.reaches(rest, transform, moved) then
		return transform, pitch
	end
	-- First scale back only the move (the turns kept whole: about the left paw's own grip they never take it away);
	-- only if even no move cannot keep it in reach is every layer scaled back together.
	local scale = movedBy
	if not VacuumMotionFormulas.reaches(rest, clamped(rest, movedBy(offset, 0), margin), moved) then
		scale = scaledBy
	end
	local low, high = 0, 1
	for _ = 1, BISECTIONS do
		local middle = (low + high) / 2
		local candidate = clamped(rest, scale(offset, middle), margin)
		if VacuumMotionFormulas.reaches(rest, candidate, moved) then
			low = middle
		else
			high = middle
		end
	end
	return clamped(rest, scale(offset, low), margin)
end

--[=[
	Where the wand's lag swings (radians, its spring's targets): turning at `yawRate` (radians a second, positive
	left) trails the head the other way; braking (`forwardAccel` studs/s/s along the facing, negative) slides it on
	forward and up. Each within its most.
]=]
function VacuumMotionFormulas.swayTargets(yawRate: number, forwardAccel: number): (number, number)
	local tuning = Constants.sway
	return math.clamp(-yawRate * tuning.yawPerRate, -tuning.maxYaw, tuning.maxYaw),
		math.clamp(-forwardAccel * tuning.pitchPerAccel, -tuning.maxPitch, tuning.maxPitch)
end

--[=[
	Where the canister's bob spring pulls (studs up its mount) for the torso's vertical acceleration `accel`
	(studs/s/s) with the gauge `fill` (0..1) full: it lags the bounce, further when full; within its most.
]=]
function VacuumMotionFormulas.packTarget(accel: number, fill: number): number
	local tuning = Constants.pack
	local gain = tuning.gain + (tuning.fullGain - tuning.gain) * math.clamp(fill, 0, 1)
	return math.clamp(-accel * gain, -tuning.max, tuning.max)
end

--[=[
	The canister's bob frequency (Hz) with the gauge `fill` full: a full canister is heavier and slower.
]=]
function VacuumMotionFormulas.packFrequency(fill: number): number
	local tuning = Constants.pack
	return tuning.frequency + (tuning.fullFrequency - tuning.frequency) * math.clamp(fill, 0, 1)
end

--[=[
	The canister's offset on its mount for a bob of `offset` studs: moved up by it and sloshed (tipped about its
	mount's X) in proportion.
]=]
function VacuumMotionFormulas.packFrame(offset: number): CFrame
	if offset == 0 then
		return CFrame.identity
	end
	return CFrame.new(0, offset, 0) * CFrame.Angles(offset * Constants.pack.tilt, 0, 0)
end

--[=[
	How deep a holder braces (0..1): Constants.brace.base the moment it sucks, all the way as the pile nears done
	(`progress` 0..1); 0 when it is not sucking.
]=]
function VacuumMotionFormulas.braceTarget(active: boolean, progress: number): number
	if not active then
		return 0
	end
	local base = Constants.brace.base
	return base + (1 - base) * math.clamp(progress, 0, 1)
end

--[=[
	The hip drop (studs) and forward lean (radians) of a brace this deep, the torso leaning in further (aim.reachLean)
	for a reach out (`reach` positive), so the shoulders follow the hands.
]=]
function VacuumMotionFormulas.body(brace: number, reach: number?): (number, number)
	local out = math.max(reach or 0, 0)
	return brace * Constants.brace.drop, brace * Constants.brace.lean + out * Constants.aim.reachLean
end

--[=[
	The turns (radians, about the root's X: positive swings a limb's lower end forward) of a leg's hip, knee and ankle
	that drop its hip by `drop` with the foot still under it and flat: the thigh swings forward, the shin back. At
	most an 80-degree hip fold.
]=]
function VacuumMotionFormulas.legFold(thigh: number, shin: number, drop: number): (number, number, number)
	if drop <= 0 or thigh <= 0 or shin <= 0 then
		return 0, 0, 0
	end
	local function shinAngle(hip: number): number
		return math.asin(math.clamp(thigh * math.sin(hip) / shin, -1, 1))
	end
	local function dropAt(hip: number): number
		return thigh * (1 - math.cos(hip)) + shin * (1 - math.cos(shinAngle(hip)))
	end
	local low, high = 0, math.rad(80)
	if dropAt(high) <= drop then
		low = high
	else
		for _ = 1, BISECTIONS do
			local middle = (low + high) / 2
			if dropAt(middle) < drop then
				low = middle
			else
				high = middle
			end
		end
		low = (low + high) / 2
	end
	local ankle = shinAngle(low)
	return low, -(low + ankle), ankle
end

return VacuumMotionFormulas
