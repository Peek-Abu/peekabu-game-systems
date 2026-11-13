--!strict
--[=[
	VacuumPileFormulas: where a dust pile stands and how it shrinks. A pile's base is always on the floor it spawned
	on: it stands on the floor point (`standing`), and as it is vacuumed it scales down toward that base (`shrunk`),
	never about its centre, so it can neither float nor sink.

	@class VacuumPileFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

local VacuumPileFormulas = {}

-- The frame of a pile of `size` whose base sits on `floor` (a floor point, facing the pile's way).
function VacuumPileFormulas.standing(floor: CFrame, size: Vector3): CFrame
	return floor * CFrame.new(0, size.Y / 2, 0)
end

-- The pile's scale (1 = full size) at channel `progress` 0..1: MIN_SCALE once cleared.
function VacuumPileFormulas.scaleAt(progress: number): number
	local fraction = math.clamp(progress, 0, 1)
	return 1 - (1 - VacuumConstants.MIN_SCALE) * fraction
end

-- The frame and size of a pile now at `frame` and `size` (full size `base`) shrunk to `progress`, its base kept where
-- it is.
function VacuumPileFormulas.shrunk(frame: CFrame, size: Vector3, base: Vector3, progress: number): (CFrame, Vector3)
	local nextSize = base * VacuumPileFormulas.scaleAt(progress)
	local floor = frame * CFrame.new(0, -size.Y / 2, 0)
	return VacuumPileFormulas.standing(floor, nextSize), nextSize
end

return VacuumPileFormulas
