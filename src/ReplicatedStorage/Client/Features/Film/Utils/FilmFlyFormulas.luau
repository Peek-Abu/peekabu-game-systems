--!strict
--[=[
	FilmFlyFormulas: the film camera's free flight (FilmCameraSystem). Pure.

	The camera flies along its own axes (W/S forward and back, A/D sideways, E/Q straight up and down in the world)
	with its velocity easing toward the wanted one, so starts and stops are smooth on camera. The mouse turns it (no
	roll, never quite straight up or down), the wheel steps the speed, and an orbit turns an offset around a target.

	@class FilmFlyFormulas
]=]

local FilmFlyFormulas = {}

FilmFlyFormulas.MAX_PITCH = 85
FilmFlyFormulas.MIN_SPEED = 1
FilmFlyFormulas.MAX_SPEED = 200
FilmFlyFormulas.MIN_FOV = 10
FilmFlyFormulas.MAX_FOV = 100
-- Each wheel notch multiplies the speed by this.
local SPEED_STEP = 1.25

--[=[
	`velocity` eased toward `wanted` over `dt` seconds (exponential, `sharpness` per second).
]=]
function FilmFlyFormulas.approach(velocity: Vector3, wanted: Vector3, dt: number, sharpness: number): Vector3
	local blend = 1 - math.exp(-sharpness * dt)
	return velocity + (wanted - velocity) * blend
end

--[=[
	The wanted velocity from the held keys (`input`: x right, y up, z back, each -1, 0 or 1) at `speed`, along the
	camera's axes (up is the world's).
]=]
function FilmFlyFormulas.wanted(camera: CFrame, input: Vector3, speed: number): Vector3
	local direction = camera.RightVector * input.X + Vector3.yAxis * input.Y - camera.LookVector * input.Z
	if direction.Magnitude < 1e-6 then
		return Vector3.zero
	end
	return direction.Unit * speed
end

--[=[
	Yaw and pitch (radians) after a mouse move of `delta` pixels at `sensitivity` degrees per pixel.
]=]
function FilmFlyFormulas.look(yaw: number, pitch: number, delta: Vector2, sensitivity: number): (number, number)
	local limit = math.rad(FilmFlyFormulas.MAX_PITCH)
	local nextYaw = yaw - math.rad(delta.X * sensitivity)
	local nextPitch = math.clamp(pitch - math.rad(delta.Y * sensitivity), -limit, limit)
	return nextYaw, nextPitch
end

--[=[
	The speed after `notches` wheel notches (up is faster), kept in range.
]=]
function FilmFlyFormulas.speed(speed: number, notches: number): number
	return math.clamp(speed * SPEED_STEP ^ notches, FilmFlyFormulas.MIN_SPEED, FilmFlyFormulas.MAX_SPEED)
end

--[=[
	`offset` (camera minus target) turned `degrees` around the world's up axis.
]=]
function FilmFlyFormulas.orbit(offset: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0) * offset
end

--[=[
	The field of view after a zoom of `degrees` (negative zooms in), kept in range.
]=]
function FilmFlyFormulas.fov(fov: number, degrees: number): number
	return math.clamp(fov + degrees, FilmFlyFormulas.MIN_FOV, FilmFlyFormulas.MAX_FOV)
end

return FilmFlyFormulas
