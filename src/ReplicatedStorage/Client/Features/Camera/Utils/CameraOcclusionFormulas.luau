--!strict
--[=[
	CameraOcclusionFormulas: the occlusion pass's pure maths (CameraOcclusionSystem, CameraServiceClient).

	- `limit`: how far from the subject the camera may stand this frame. Something new in the way snaps it in at once
	  (never a frame inside a wall); a clear view lets it ease back out exponentially (alpha = 1 - e^(-sharpness*dt),
	  frame-rate independent), so the camera does not pop back and forth along a wall.
	- `applies`: the pass only ever pulls the camera closer than the engine put it, never pushes it out.

	@class CameraOcclusionFormulas
]=]

-- Below this difference (studs) the pass leaves the engine's camera alone.
local EPSILON = 1e-3

local CameraOcclusionFormulas = {}

--[=[
	The limit after `dt` seconds: `previous` (nil = none yet) moved toward `clear`, the farthest the camera may stand
	this frame. Down at once, up at `sharpness` per second.
]=]
function CameraOcclusionFormulas.limit(previous: number?, clear: number, dt: number, sharpness: number): number
	if previous == nil or clear <= previous then
		return clear
	end
	local alpha = 1 - math.exp(-sharpness * dt)
	return math.min(previous + (clear - previous) * alpha, clear)
end

--[=[
	Whether the pass moves a camera the engine put `engine` studs from its focus, given the `limit`.
]=]
function CameraOcclusionFormulas.applies(engine: number, limit: number): boolean
	return limit < engine - EPSILON
end

return CameraOcclusionFormulas
