--!strict
--[=[
	CarryFormulas: the Carry feature's pure maths.

	@class CarryFormulas
]=]

local CarryFormulas = {}

--[=[
	A carrier's walk speed: `base × max(minMultiplier, 1 − weight × slowPerWeight)`.
]=]
function CarryFormulas.walkSpeedFor(base: number, weight: number, slowPerWeight: number, minMultiplier: number): number
	return base * math.max(minMultiplier, 1 - weight * slowPerWeight)
end

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

--[=[
	A throw's velocity: the normalized aim × speed, plus `lift` upward. Nil for a zero or non-finite aim
	(a client-sent direction is never trusted to be well-formed).
]=]
function CarryFormulas.throwVelocity(aim: Vector3, speed: number, lift: number): Vector3?
	if not (isFinite(aim.X) and isFinite(aim.Y) and isFinite(aim.Z)) or aim.Magnitude < 1e-6 then
		return nil
	end
	return aim.Unit * speed + Vector3.new(0, lift, 0)
end

--[=[
	Where something moved from `origin` towards `target` stops when a ray along that move hit a wall
	`hitDistance` studs out (nil = nothing hit): `margin` short of the hit, never behind the origin.
]=]
function CarryFormulas.clampAlong(origin: Vector3, target: Vector3, hitDistance: number?, margin: number): Vector3
	local move = target - origin
	if hitDistance == nil then
		return target
	end
	local length = move.Magnitude
	if length < 1e-6 then
		return origin
	end
	local distance = math.clamp(hitDistance - margin, 0, length)
	return if distance <= 0 then origin else origin + move.Unit * distance
end

--[=[
	Whether a placement has floor support: a floor was found (`floorY`), in the same structure as the floor
	under the safe origin (`sameStructure`: the building, not the ground outside it), within `step` studs of the
	origin's floor height. With no origin floor to compare against (`originFloorY` nil), any floor will do.
]=]
function CarryFormulas.isSupported(
	originFloorY: number?,
	floorY: number?,
	sameStructure: boolean,
	step: number
): boolean
	if floorY == nil or not sameStructure then
		return false
	end
	return originFloorY == nil or math.abs(floorY - originFloorY) <= step
end

--[=[
	Where a moving part that crossed a wall between `from` and the wall's `hit` point goes back to: `margin`
	studs before the hit, never further back than `from`.
]=]
function CarryFormulas.pullBack(from: Vector3, hit: Vector3, margin: number): Vector3
	return CarryFormulas.clampAlong(from, hit, (hit - from).Magnitude, margin)
end

export type SwayTuning = {
	-- The swing's natural frequency (rad/s), its damping ratio, and the largest tilt (radians).
	omega: number,
	damping: number,
	maxTilt: number,
}

--[=[
	The slide (a joint Transform, in the frame of the joint's `c0` on the carrier's root) that keeps a pushed item in
	the same place in front of the carrier's chest: the UpperTorso has moved `torsoOffset` (root space) from where it is
	at rest, and the item follows it level, along the floor, never up or down or tilted.
]=]
function CarryFormulas.pushFollow(torsoOffset: Vector3, c0: CFrame): CFrame
	return CFrame.new(c0:VectorToObjectSpace(Vector3.new(torsoOffset.X, 0, torsoOffset.Z)))
end

-- The longest step integrated at once; a longer frame is split.
local SWAY_SUBSTEP = 1 / 120

--[=[
	One step of a bag hanging from a hand, as a damped pendulum: `tilt` is how far its bottom has swung from plumb
	(radians, along world X and Z), `rate` how fast. The hand's horizontal acceleration `accel` (studs/s², world X and
	Z) swings the bottom the other way, by `length` (studs from the hand to the bag's middle). Returns the new tilt and
	rate, the tilt never past `tuning.maxTilt`.
]=]
function CarryFormulas.swayStep(
	tilt: Vector2,
	rate: Vector2,
	accel: Vector2,
	dt: number,
	length: number,
	tuning: SwayTuning
): (Vector2, Vector2)
	local remaining = math.clamp(dt, 0, 0.25)
	local push = accel / math.max(length, 0.1)
	while remaining > 1e-9 do
		local h = math.min(remaining, SWAY_SUBSTEP)
		remaining -= h
		local pull = -tilt * tuning.omega ^ 2 - rate * (2 * tuning.damping * tuning.omega) - push
		rate += pull * h
		tilt += rate * h
		if tilt.Magnitude > tuning.maxTilt then
			tilt = tilt.Unit * tuning.maxTilt
			-- At the stop the swing outward is spent.
			local outward = tilt.Unit
			rate -= outward * math.max(0, rate:Dot(outward))
		end
	end
	return tilt, rate
end

return CarryFormulas
