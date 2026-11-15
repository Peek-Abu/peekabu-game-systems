--!strict
--[=[
	VacuumAirFormulas: the shape of the air a vacuum gulps (P1 v2 2026-11-15, after the owner turned down straight
	streaks: "random lines going sideways into vacuum"). Pure.

	Suction games draw air as a swirl, not lines: things are pulled round in an inward spiral that tightens and speeds
	up as it nears the mouth, and the goo it pulls tears off in blobs that stretch along their flight.

	- `travel`: how far along its trip a thing is at an age (starts slow, rushes into the mouth).
	- `spiral`: where it is then: on a ring about the source at the start, round and in, in the mouth at the end,
	  turning faster as it closes in.
	- `blob` / `blobSize`: a goo blob's stretch by its speed, and its size along its trip.

	@class VacuumAirFormulas
]=]

local VacuumAirFormulas = {}

-- A goo blob stretches at most this much past round, at BLOB_FAST studs per second.
VacuumAirFormulas.MAX_BLOB_STRETCH = 1.6
local BLOB_FAST = 10
-- The ring closes on the axis by this power of what is left of the trip (under 1: it holds its width a while).
local CLOSE_POWER = 0.75
-- The turn bunches toward the mouth by this power of the trip.
local TURN_POWER = 1.6
-- A blob swells to full size over this share of its trip, and is this share of it as it enters the mouth.
local SWELL = 0.3
local MOUTH_SIZE = 0.35

--[=[
	How far (0..1) along its trip a thing `age` seconds old is on a trip of `life` seconds: slow at first, rushing
	into the mouth at the end.
]=]
function VacuumAirFormulas.travel(age: number, life: number): number
	if life <= 0 then
		return 1
	end
	local t = math.clamp(age / life, 0, 1)
	return t * t
end

--[=[
	Where a thing is at `u` (0..1) along its trip from a ring of `radius` about `source` into `sink`, starting at angle
	`phase` and going round `turns` times: an inward spiral about the line from the sink to the source, turning
	faster as it closes in.
]=]
function VacuumAirFormulas.spiral(
	source: Vector3,
	sink: Vector3,
	radius: number,
	u: number,
	phase: number,
	turns: number
): Vector3
	local p = math.clamp(u, 0, 1)
	local span = source - sink
	local axis = if span.Magnitude > 1e-4 then span.Unit else Vector3.yAxis
	local side = axis:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = axis:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local up = side:Cross(axis)
	local angle = phase + 2 * math.pi * turns * p ^ TURN_POWER
	local r = radius * (1 - p) ^ CLOSE_POWER
	return sink + span * (1 - p) + (side * math.cos(angle) + up * math.sin(angle)) * r
end

--[=[
	A goo blob's shape at `speed` studs per second: its length along its flight and its width across (its volume
	about kept).
]=]
function VacuumAirFormulas.blob(speed: number): (number, number)
	local along = 1 + VacuumAirFormulas.MAX_BLOB_STRETCH * math.clamp(speed / BLOB_FAST, 0, 1)
	return along, 1 / math.sqrt(along)
end

--[=[
	A goo blob's size (1 = full) at `u` along its trip: it swells as it tears off, then shrinks into the mouth.
]=]
function VacuumAirFormulas.blobSize(u: number): number
	local p = math.clamp(u, 0, 1)
	if p < SWELL then
		local t = p / SWELL
		return 1 - (1 - t) * (1 - t)
	end
	local t = (p - SWELL) / (1 - SWELL)
	return 1 - (1 - MOUTH_SIZE) * t * t
end

return VacuumAirFormulas
