--!strict
--[=[
	NoiseRules: who hears a noise (Cleanup Crew spec §4, §6.2 "Noise"): a listener hears it when within the
	noise's radius times the listener's hearing scale (Harlow's comes from OccupantTuningFormulas: pressure
	tiers widen it, a solo crew narrows it). Straight-line distance; walls do not muffle (spec: "3D footsteps
	and muttering through walls" works both ways). Pure.

	@class NoiseRules
]=]

local NoiseRules = {}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

--[=[
	Whether a noise can be made: a finite position and a positive, finite radius.
]=]
function NoiseRules.valid(position: Vector3, radius: number): boolean
	return finite(radius) and radius > 0 and finite(position.X) and finite(position.Y) and finite(position.Z)
end

--[=[
	Whether `scale` is a usable hearing scale: finite and positive.
]=]
function NoiseRules.validScale(scale: number): boolean
	return finite(scale) and scale > 0
end

--[=[
	How far a noise of `radius` is heard by a listener with hearing `scale` (never negative).
]=]
function NoiseRules.heardRadius(radius: number, scale: number): number
	return math.max(0, radius) * math.max(0, scale)
end

--[=[
	Whether a listener at `listener` hears a noise at `origin`.
]=]
function NoiseRules.hears(listener: Vector3, origin: Vector3, radius: number, scale: number): boolean
	local reach = NoiseRules.heardRadius(radius, scale)
	return reach > 0 and (listener - origin).Magnitude <= reach
end

return NoiseRules
