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

return CarryFormulas
