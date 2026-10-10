--!strict
--[=[
	NoiseRippleFormulas: the ripple ring over its life (Cleanup Crew spec §7 "faint ripple ring on the floor at the
	radius Harlow hears it"). At `alpha` (0 = the noise, 1 = gone) the ring's outer edge has eased out from
	RIPPLE_START_FRACTION of the heard radius to all of it, its band has thinned from RIPPLE_WIDTH_FRACTION of the
	radius to RIPPLE_MIN_WIDTH, and it has faded from RIPPLE_START_TRANSPARENCY to invisible. A ripple is drawn
	only when its ring can come within RIPPLE_MAX_DISTANCE of the camera. Pure.

	@class NoiseRippleFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)

export type Ring = {
	outer: number,
	inner: number,
	transparency: number,
}

local NoiseRippleFormulas = {}

function NoiseRippleFormulas.ring(radius: number, alpha: number): Ring
	local t = math.clamp(alpha, 0, 1)
	local size = math.max(radius, 0)
	local eased = 1 - (1 - t) * (1 - t)
	local start = NoiseConstants.RIPPLE_START_FRACTION
	local outer = size * (start + (1 - start) * eased)
	local width = math.max(NoiseConstants.RIPPLE_MIN_WIDTH, size * NoiseConstants.RIPPLE_WIDTH_FRACTION * (1 - t))
	local faint = NoiseConstants.RIPPLE_START_TRANSPARENCY
	return {
		outer = outer,
		inner = math.max(0, outer - width),
		transparency = faint + (1 - faint) * t,
	}
end

function NoiseRippleFormulas.shown(viewer: Vector3, origin: Vector3, radius: number): boolean
	return radius > 0 and (viewer - origin).Magnitude <= NoiseConstants.RIPPLE_MAX_DISTANCE + radius
end

return NoiseRippleFormulas
