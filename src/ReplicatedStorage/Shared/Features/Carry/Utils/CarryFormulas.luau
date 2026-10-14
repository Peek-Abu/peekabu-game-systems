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

return CarryFormulas
