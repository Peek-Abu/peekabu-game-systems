--!strict
--[=[
	CameraMotionFormulas: the camera's pure maths.

	- Shake (the trauma model): rotation offset = max angle × trauma² × noise. Squaring makes small
	  trauma subtle and big trauma violent; `math.noise` keeps the motion smooth.
	- FOV kicks ease out quadratically to zero over their duration.
	- Follow smoothing is exponential: alpha = 1 − e^(−sharpness·dt), so it is frame-rate independent.

	@class CameraMotionFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraTypes = require(ReplicatedStorage.Client.Features.Camera.Data.CameraTypes)

export type ShakeConfig = {
	maxPitch: number,
	maxYaw: number,
	maxRoll: number,
	frequency: number,
}

local CameraMotionFormulas = {}

-- math.noise is documented to return values in [-1, 1]; clamp anyway so the bound is a guarantee.
local function noise(x: number, seed: number): number
	return math.clamp(math.noise(x, seed), -1, 1)
end

--[=[
	The shake rotation for `trauma` (0..1) at time `t` (seconds).
	@return number, number, number -- pitch, yaw, roll in radians
]=]
function CameraMotionFormulas.shakeAngles(trauma: number, t: number, config: ShakeConfig): (number, number, number)
	local strength = trauma * trauma
	if strength == 0 then
		return 0, 0, 0
	end
	local x = t * config.frequency
	return config.maxPitch * strength * noise(x, 1.37),
		config.maxYaw * strength * noise(x, 7.91),
		config.maxRoll * strength * noise(x, 13.53)
end

--[=[
	Trauma after adding `amount`, clamped to [0, 1]. A negative amount adds nothing.
]=]
function CameraMotionFormulas.addTrauma(trauma: number, amount: number): number
	return math.clamp(trauma + math.max(amount, 0), 0, 1)
end

--[=[
	Trauma after `dt` seconds of linear decay at `ratePerSecond`, never below zero.
]=]
function CameraMotionFormulas.decayTrauma(trauma: number, dt: number, ratePerSecond: number): number
	return math.max(trauma - ratePerSecond * dt, 0)
end

--[=[
	The FOV offset a kick contributes now: its amount, easing out quadratically to zero at its duration.
]=]
function CameraMotionFormulas.fovKickValue(kick: CameraTypes.FovKick): number
	if kick.duration <= 0 or kick.elapsed >= kick.duration then
		return 0
	end
	local remaining = 1 - kick.elapsed / kick.duration
	return kick.amount * remaining * remaining
end

--[=[
	The fraction of the way to move toward a target this frame, for exponential smoothing.
]=]
function CameraMotionFormulas.smoothingAlpha(sharpness: number, dt: number): number
	return 1 - math.exp(-sharpness * dt)
end

return CameraMotionFormulas
