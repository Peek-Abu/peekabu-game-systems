--!strict
--[=[
	VacuumAimUtils: which pile the player is vacuuming: the nearest within `range` (straight-line, so height
	counts) whose flat direction is within the camera's flat look by at least `minDot`. A pile underfoot
	(within 1.5 studs flat) counts whatever the camera faces. Pure; the server re-checks range.

	@class VacuumAimUtils
]=]

local UNDERFOOT = 1.5

local VacuumAimUtils = {}

function VacuumAimUtils.pick(
	origin: Vector3,
	look: Vector3,
	candidates: { Vector3 },
	range: number,
	minDot: number
): number?
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local hasLook = flatLook.Magnitude > 1e-6
	local forward = if hasLook then flatLook.Unit else Vector3.zero
	local best: number? = nil
	local bestDistance = math.huge
	for index, position in candidates do
		local offset = position - origin
		local distance = offset.Magnitude
		if distance <= range and distance < bestDistance then
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local facing = flat.Magnitude <= UNDERFOOT or not hasLook or flat.Unit:Dot(forward) >= minDot
			if facing then
				best = index
				bestDistance = distance
			end
		end
	end
	return best
end

return VacuumAimUtils
