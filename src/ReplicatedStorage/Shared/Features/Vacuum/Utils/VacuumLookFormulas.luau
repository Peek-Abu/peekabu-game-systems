--!strict
--[=[
	VacuumLookFormulas: the look half of the held vacuum's maths (VacuumMotionConstants). Pure. Split out of
	VacuumMotionFormulas, which re-exports every function here under its old name, so callers are unchanged.

	- `encodeAim` / `decodeAim`, `encodeYaw` / `decodeYaw`: the look's pitch and yaw as the bytes the client sends and
	  the server checks.
	- `heading` / `wrapAngle` / `relativeYaw`: flat headings and the angle between two of them; `faceToward` the body
	  easing round toward the camera.
	- `pointerLook`: the look of a mouse pointer's ray; `lookHeading` / `lookDistance`: the look's heading and the
	  floor look point's distance the wand aims at.

	@class VacuumLookFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)

local VacuumLookFormulas = {}

-- The look pitch on the wire: whole quanta of degrees from -90.
local AIM_LOW = -90
local AIM_STEPS = 36
-- The look yaw on the wire: whole quanta of degrees from -YAW_RANGE.
local YAW_RANGE = 60
local YAW_STEPS = 24

--[=[
	The look pitch (radians) as the byte the client sends: whole quanta of degrees from -90, clamped to +-90.
]=]
function VacuumLookFormulas.encodeAim(look: number): number
	local quantum = math.deg(Constants.aim.quantum)
	return math.clamp(math.round((math.deg(look) - AIM_LOW) / quantum), 0, AIM_STEPS)
end

--[=[
	The look pitch in degrees a sent byte stands for; nil for anything the client cannot send.
]=]
function VacuumLookFormulas.decodeAim(byte: number): number?
	if byte ~= byte or byte ~= math.floor(byte) or byte < 0 or byte > AIM_STEPS then
		return nil
	end
	return AIM_LOW + byte * math.deg(Constants.aim.quantum)
end

--[=[
	A look's flat heading (radians, left positive, -pi..pi; 0 is the -Z axis).
]=]
function VacuumLookFormulas.heading(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

--[=[
	An angle wrapped into -pi..pi.
]=]
function VacuumLookFormulas.wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

--[=[
	The body's next heading as it eases from `heading` toward the camera's `target` over `dt` (Constants.face): the
	short way round, a share of the gap each frame (time constant `ease`), never faster than `maxRate`.
]=]
function VacuumLookFormulas.faceToward(heading: number, target: number, dt: number): number
	if dt <= 0 then
		return heading
	end
	local tuning = Constants.face
	local gap = VacuumLookFormulas.wrapAngle(target - heading)
	local turn = gap * (1 - math.exp(-math.min(dt, Constants.maxStep) / tuning.ease))
	local most = tuning.maxRate * dt
	return VacuumLookFormulas.wrapAngle(heading + math.clamp(turn, -most, most))
end

--[=[
	Where the camera looks relative to the body, left or right (radians, left positive, -pi..pi): the flat headings of
	the camera's look and the body's look.
]=]
function VacuumLookFormulas.relativeYaw(cameraLook: Vector3, bodyLook: Vector3): number
	return VacuumLookFormulas.wrapAngle(VacuumLookFormulas.heading(cameraLook) - VacuumLookFormulas.heading(bodyLook))
end

-- Closer than this (studs, flat) to the body, where the pointer meets the floor gives no steady heading.
local POINTER_NEAR = 0.75

--[=[
	The look (pitch and yaw off the body, radians: up and left positive) of a pointer whose ray leaves `origin` along
	`direction` (the camera through the mouse cursor), for a body at `body` (its root frame) over a floor at height
	`floorY` (P1 2026-11-14: the nozzle follows the mouse). The pitch is the ray's own, so a cursor low on the screen
	brings the floor head in and one high on it sends it out, exactly as tilting the camera does (`aim`); the yaw is
	where the ray meets the floor seen from the body, so the nozzle turns toward the very spot under the cursor. A ray
	that never meets the floor ahead (above the horizon), or meets it right at the body's feet, turns by its own heading.
]=]
function VacuumLookFormulas.pointerLook(
	origin: Vector3,
	direction: Vector3,
	body: CFrame,
	floorY: number
): (number, number)
	local unit = if direction.Magnitude > 1e-6 then direction.Unit else body.LookVector
	local pitch = math.asin(math.clamp(unit.Y, -1, 1))
	if unit.Y < -1e-3 then
		local along = (floorY - origin.Y) / unit.Y
		if along > 0 then
			local spot = body:PointToObjectSpace(origin + unit * along)
			local flat = Vector3.new(spot.X, 0, spot.Z)
			if flat.Magnitude >= POINTER_NEAR then
				return pitch, VacuumLookFormulas.heading(flat)
			end
		end
	end
	return pitch, VacuumLookFormulas.relativeYaw(unit, body.LookVector)
end

--[=[
	The look's heading off the body (radians, left positive) the wand aims at: `relative` within Constants.aim.maxLook
	either way; looking back past the side, it eases back to straight ahead (0 straight behind), so a look swung
	across the back never snaps the wand from one side to the other.
]=]
function VacuumLookFormulas.lookHeading(relative: number): number
	local most = Constants.aim.maxLook
	local turn = VacuumLookFormulas.wrapAngle(relative)
	local size = math.abs(turn)
	if size <= math.pi / 2 then
		return math.clamp(turn, -most, most)
	end
	local side = if turn >= 0 then 1 else -1
	return side * most * (math.pi - size) / (math.pi / 2)
end

--[=[
	How far out on the floor (studs from the root) a look `pitch` (radians, up positive) lands, within near..far:
	near at nearPitch and below, far at farPitch and above.
]=]
function VacuumLookFormulas.lookDistance(pitch: number): number
	local aim = Constants.aim
	local share = math.clamp((pitch - aim.nearPitch) / (aim.farPitch - aim.nearPitch), 0, 1)
	return aim.near + (aim.far - aim.near) * share
end

--[=[
	The look yaw (radians, relative to the body) as the byte the client sends: whole quanta of degrees from -60, clamped.
]=]
function VacuumLookFormulas.encodeYaw(relative: number): number
	local quantum = math.deg(Constants.aim.quantum)
	return math.clamp(math.round((math.deg(relative) + YAW_RANGE) / quantum), 0, YAW_STEPS)
end

--[=[
	The look yaw in degrees a sent byte stands for; nil for anything the client cannot send.
]=]
function VacuumLookFormulas.decodeYaw(byte: number): number?
	if byte ~= byte or byte ~= math.floor(byte) or byte < 0 or byte > YAW_STEPS then
		return nil
	end
	return -YAW_RANGE + byte * math.deg(Constants.aim.quantum)
end

return VacuumLookFormulas
