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

return OfficeAmbienceUtils
