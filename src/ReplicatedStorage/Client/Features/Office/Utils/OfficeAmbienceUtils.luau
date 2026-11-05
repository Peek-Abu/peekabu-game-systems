--!strict
--[=[
	OfficeAmbienceUtils: the ambient dread's choices (Cleanup Crew spec §7 "phones ringing in empty rooms, an
	elevator dinging on its own, typing that stops when you enter"). A spot is empty when no crew member is within
	the radius; a phone (or the elevator) is picked by roll among the empty spots of its kind; typing stops when
	you come within its radius; the wait before the next one is a roll between a minimum and a maximum; a fixed
	emitter's loop plays while the camera is near (with a margin, so it never flickers); a yard sound comes from its
	emitter volume (the nearest point of it for a loop, a rolled point inside it for a one-shot), picked among those
	within the sound's reach. Pure.

	@class OfficeAmbienceUtils
]=]

export type Emitter = {
	kind: string,
	position: Vector3,
}

local OfficeAmbienceUtils = {
	-- A rolled one-shot point stays within this share of its sound's reach (well inside the silent edge).
	REACH_SHARE = 0.8,
}

function OfficeAmbienceUtils.empty(position: Vector3, crew: { Vector3 }, radius: number): boolean
	for _, member in crew do
		if (member - position).Magnitude <= radius then
			return false
		end
	end
	return true
end

--[=[
	The index of the emitter of `kind` to play, chosen by `roll` (0..1) among the empty ones; nil when none.
]=]
function OfficeAmbienceUtils.pick(
	emitters: { Emitter },
	kind: string,
	crew: { Vector3 },
	radius: number,
	roll: number
): number?
	local eligible: { number } = {}
	for index, emitter in emitters do
		if emitter.kind == kind and OfficeAmbienceUtils.empty(emitter.position, crew, radius) then
			table.insert(eligible, index)
		end
	end
	if #eligible == 0 then
		return nil
	end
	return eligible[math.clamp(math.floor(math.clamp(roll, 0, 1) * #eligible) + 1, 1, #eligible)]
end

function OfficeAmbienceUtils.typingStops(distance: number, radius: number): boolean
	return distance <= radius
end

function OfficeAmbienceUtils.delay(roll: number, min: number, max: number): number
	return min + (max - min) * math.clamp(roll, 0, 1)
end

--[=[
	Where a scattered bed sweetener (a ceiling tick, a pipe knock...) sounds: on a level ring around `listener`, at the
	angle `angleRoll` (0-1) and between `min` and `max` studs out by `distanceRoll` (0-1).
]=]
function OfficeAmbienceUtils.sweetenerAt(
	listener: Vector3,
	angleRoll: number,
	distanceRoll: number,
	min: number,
	max: number
): Vector3
	local angle = math.clamp(angleRoll, 0, 1) * 2 * math.pi
	local distance = min + (max - min) * math.clamp(distanceRoll, 0, 1)
	return listener + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

--[=[
	Which of `count` variants a roll (0-1) picks (1-based), never `last` again when there is a choice.
]=]
function OfficeAmbienceUtils.variant(roll: number, count: number, last: number?): number
	local r = math.clamp(roll, 0, 1)
	if count <= 1 or last == nil or last < 1 or last > count then
		return math.clamp(math.floor(r * count) + 1, 1, count)
	end
	-- Choose among the others, then step over `last`.
	local index = math.clamp(math.floor(r * (count - 1)) + 1, 1, count - 1)
	return if index >= last then index + 1 else index
end

--[=[
	Whether a fixed emitter's loop plays with the camera `distance` studs away: it starts within `radius` and, once
	`playing`, keeps on until `radius + margin`.
]=]
function OfficeAmbienceUtils.loopOn(distance: number, radius: number, margin: number, playing: boolean): boolean
	return distance <= (if playing then radius + margin else radius)
end

--[=[
	The point of an emitter volume (a box at `cframe` of `size`) nearest to `point`: `point` itself when inside. A
	traffic loop plays from the road side's nearest point, so it comes from the road's direction wherever you stand.
]=]
function OfficeAmbienceUtils.nearestInBox(point: Vector3, cframe: CFrame, size: Vector3): Vector3
	local half = size / 2
	local rel = cframe:PointToObjectSpace(point)
	local clamped = Vector3.new(
		math.clamp(rel.X, -half.X, half.X),
		math.clamp(rel.Y, -half.Y, half.Y),
		math.clamp(rel.Z, -half.Z, half.Z)
	)
	return cframe:PointToWorldSpace(clamped)
end

--[=[
	How far `point` is from an emitter volume (0 inside it).
]=]
function OfficeAmbienceUtils.boxDistance(point: Vector3, cframe: CFrame, size: Vector3): number
	return (point - OfficeAmbienceUtils.nearestInBox(point, cframe, size)).Magnitude
end

--[=[
	A point inside an emitter volume by three rolls (0-1 along its X, Y and Z): where a one-shot from a long source (a
	fence line, a treeline, a stretch of road) sounds.
]=]
function OfficeAmbienceUtils.pointInBox(cframe: CFrame, size: Vector3, rx: number, ry: number, rz: number): Vector3
	local half = size / 2
	return cframe:PointToWorldSpace(
		Vector3.new(
			(math.clamp(rx, 0, 1) * 2 - 1) * half.X,
			(math.clamp(ry, 0, 1) * 2 - 1) * half.Y,
			(math.clamp(rz, 0, 1) * 2 - 1) * half.Z
		)
	)
end

--[=[
	Where a one-shot from a long source sounds for a listener: the rolled point inside the volume (pointInBox) when it is
	within REACH_SHARE of the sound's `reach`; else the point on the way from the volume's nearest point to it where it
	is, so a far car on a 400-stud road is never rolled past where it can be heard (the nearest point itself when even
	that is too far).
]=]
function OfficeAmbienceUtils.pointInReach(
	listener: Vector3,
	cframe: CFrame,
	size: Vector3,
	reach: number,
	rx: number,
	ry: number,
	rz: number
): Vector3
	local limit = reach * OfficeAmbienceUtils.REACH_SHARE
	local rolled = OfficeAmbienceUtils.pointInBox(cframe, size, rx, ry, rz)
	if (rolled - listener).Magnitude <= limit then
		return rolled
	end
	local nearest = OfficeAmbienceUtils.nearestInBox(listener, cframe, size)
	if (nearest - listener).Magnitude >= limit then
		return nearest
	end
	-- The distance grows from the nearest point toward the rolled one (the box is convex): halve to the limit.
	local low, high = 0, 1
	for _ = 1, 16 do
		local mid = (low + high) / 2
		if (nearest:Lerp(rolled, mid) - listener).Magnitude <= limit then
			low = mid
		else
			high = mid
		end
	end
	return nearest:Lerp(rolled, low)
end

--[=[
	Which of the sources (their `distances` from the listener) a roll (0-1) picks among those within `radius`; nil
	when none is.
]=]
function OfficeAmbienceUtils.pickNear(distances: { number }, radius: number, roll: number): number?
	local eligible: { number } = {}
	for index, distance in distances do
		if distance <= radius then
			table.insert(eligible, index)
		end
	end
	if #eligible == 0 then
		return nil
	end
	return eligible[OfficeAmbienceUtils.variant(roll, #eligible)]
end

return OfficeAmbienceUtils
