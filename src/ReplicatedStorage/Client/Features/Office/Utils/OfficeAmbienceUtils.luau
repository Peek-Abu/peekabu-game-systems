--!strict
--[=[
	OfficeAmbienceUtils: the ambient dread's choices (Cleanup Crew spec §7 "phones ringing in empty rooms, an
	elevator dinging on its own, typing that stops when you enter"). A spot is empty when no crew member is within
	the radius; a phone (or the elevator) is picked by roll among the empty spots of its kind; typing stops when
	you come within its radius; the wait before the next one is a roll between a minimum and a maximum. Pure.

	@class OfficeAmbienceUtils
]=]

export type Emitter = {
	kind: string,
	position: Vector3,
}

local OfficeAmbienceUtils = {}

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
	Which of `count` variants a roll (0-1) picks (1-based).
]=]
function OfficeAmbienceUtils.variant(roll: number, count: number): number
	return math.clamp(math.floor(math.clamp(roll, 0, 1) * count) + 1, 1, count)
end

return OfficeAmbienceUtils
