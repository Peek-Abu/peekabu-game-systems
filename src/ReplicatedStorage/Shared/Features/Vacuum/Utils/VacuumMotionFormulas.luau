--!strict
--[=[
	VacuumMotionFormulas: the maths of the held vacuum's motion layers (VacuumMotionConstants). Pure.

	Every layer moves the wand as ONE rigid body turned about one point on it, the pivot (`wand`; the left paw's grip,
	GripLower, as Pippa's left arm is planned near its full reach and the right one has room): the two IK
	targets (AnimationVacuumHoldSystem) are both moved by the same root-space transform, so the right hand carries
	the wand (the Tool is welded to it) and the left hand's target is still exactly on GripLower, wherever the wand
	goes. The floor head is never let under the floor: a pose that would sink it is flattened out about the pivot
	(the head slides further out along the floor) until it just clears.

	- `aim`: the camera's look pitch to a raise (radians) and a reach (0..1). `encodeAim` / `decodeAim`: the byte the
	  client sends and the server checks.
	- `offsetOf`: the layers' state to the wand's offset (`wand`'s input).
	- `kickScale` / `kickImpulse`: how hard a pile's pop kicks, as the spring's starting speed; `shimmy` the suction
	  shimmy at a pile's progress.
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
}

-- How the wand is moved off its rest: the pivot translated `offset` (root space), and turned about it by `yaw`
-- (about the vertical), `pitch` (about the root's X: positive raises the floor head out in front) and `roll` (about
-- the root's Z).
export type WandOffset = { offset: Vector3, pitch: number, yaw: number, roll: number }

-- The layers' state: the aim's raise (radians) and reach (0..1), the brace's weight (0..1), the pop kick (its
-- spring: 1 is a reference pile's peak) and the suction shimmy's turn and roll (radians).
export type Layers = {
	raise: number,
	reach: number,
	brace: number,
	kick: number,
	shimmyYaw: number,
	shimmyRoll: number,
}

export type AimTuning = {
	deadLow: number,
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
	The camera's look pitch (radians, up positive) to the wand's raise (radians about the wand's pivot) and its reach for
	the floor (0..1); both 0 in the dead band round the default third-person view.
]=]
function VacuumMotionFormulas.aim(look: number, tuning: AimTuning): (number, number)
	local raise = if look > tuning.deadHigh then math.min(tuning.maxUp, (look - tuning.deadHigh) * tuning.gainUp) else 0
	local reach = if look < tuning.deadLow
		then math.min(1, (tuning.deadLow - look) / (tuning.deadLow - tuning.fullDown))
		else 0
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
	The wand's offset for the layers' state: the aim's raise turns it about its pivot; its reach and the brace
	move the hands (down and out for the reach, down and in toward the body for the brace); the kick jolts them back
	and up and hops the floor head; the shimmy turns and rolls it.
]=]
function VacuumMotionFormulas.offsetOf(layers: Layers): WandOffset
	local aim, brace, kick = Constants.aim, Constants.brace, Constants.kick
	return {
		offset = Vector3.new(
			0,
			-(layers.reach * aim.reachDrop + layers.brace * brace.handDrop) + layers.kick * kick.lift,
			-layers.reach * aim.reachForward + layers.brace * brace.pull + layers.kick * kick.lift * kick.back
		),
		pitch = layers.raise + layers.kick * kick.pitch,
		yaw = layers.shimmyYaw,
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

-- The offset scaled by `k` (every layer together).
local function scaledBy(offset: WandOffset, k: number): WandOffset
	return { offset = offset.offset * k, pitch = offset.pitch * k, yaw = offset.yaw * k, roll = offset.roll * k }
end

--[=[
	The upper body's root-space motion for a brace that drops the hips `drop` and leans `lean` forward over the waist
	joint at `waist` (identity without one): the left shoulder rides it.
]=]
function VacuumMotionFormulas.motion(waist: Vector3?, drop: number, lean: number): CFrame
	if waist == nil then
		return CFrame.identity
	end
	return CFrame.new(0, -drop, 0) * CFrame.new(waist) * CFrame.Angles(-lean, 0, 0) * CFrame.new(-waist)
end

--[=[
	Whether the left paw can still reach its grip with the wand moved by `transform` and the upper body by `body`.
]=]
function VacuumMotionFormulas.reaches(rest: WandRest, transform: CFrame, body: CFrame): boolean
	local left = rest.left
	if left == nil then
		return true
	end
	return (transform * left.at - body * left.shoulder).Magnitude <= Constants.reachUse * left.reach
end

--[=[
	The root-space transform that moves the rest hold by `offset` (both IK targets are moved by it), with the floor
	head's lowest corner kept `margin` over the floor (flattened about the pivot by the least pitch that clears,
	else lifted), and the left paw's grip kept within its arm's reach (`reaches`, the upper body moved by `body`): if
	it would not be, every layer is scaled back together until it is. Also returns the pitch used.
]=]
function VacuumMotionFormulas.wand(rest: WandRest, offset: WandOffset, margin: number, body: CFrame?): (CFrame, number)
	local moved = body or CFrame.identity
	local transform, pitch = clamped(rest, offset, margin)
	if VacuumMotionFormulas.reaches(rest, transform, moved) then
		return transform, pitch
	end
	local low, high = 0, 1
	for _ = 1, BISECTIONS do
		local middle = (low + high) / 2
		local candidate = clamped(rest, scaledBy(offset, middle), margin)
		if VacuumMotionFormulas.reaches(rest, candidate, moved) then
			low = middle
		else
			high = middle
		end
	end
	return clamped(rest, scaledBy(offset, low), margin)
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
	The hip drop (studs) and forward lean (radians) of a brace this deep.
]=]
function VacuumMotionFormulas.body(brace: number): (number, number)
	return brace * Constants.brace.drop, brace * Constants.brace.lean
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
