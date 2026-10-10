--!strict
--[=[
	NoiseRules: who hears a noise (Cleanup Crew spec §4, §6.2 "Noise"): a listener hears it when within the
	noise's radius times the listener's hearing scale (Harlow's comes from OccupantTuningFormulas: pressure
	tiers widen it, a solo crew narrows it). Straight-line distance; walls do not muffle (spec: "3D footsteps
	and muttering through walls" works both ways). Pure.

	@class NoiseRules
]=]

local NoiseRules = {}

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
