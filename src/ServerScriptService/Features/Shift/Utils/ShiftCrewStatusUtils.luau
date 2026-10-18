--!strict
--[=[
	ShiftCrewStatusUtils: one crew member's public status fields (Cleanup Crew M3 UI: the crew roster and the CCTV): in
	the truck bed, vacuuming, and the room they stand in (name, rooms from the loading bay, camera number). Flags are
	published only while true (absent = false) so the public map stays small; `changes` says what to set and what to
	clear since the last publish, so the system sends nothing when nothing moved. Pure.

	@class ShiftCrewStatusUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

type PublicPlayer = PublicPlayerTypes.PublicPlayer

export type Status = {
	inTruck: boolean,
	vacuuming: boolean,
	room: string?,
	roomDepth: number?,
	cam: number?,
}

export type Change = {
	set: PublicPlayer,
	clear: { string },
}

local ShiftCrewStatusUtils = {}

function ShiftCrewStatusUtils.fields(status: Status): PublicPlayer
	local fields: PublicPlayer = {}
	if status.inTruck then
		fields[ShiftConstants.PUBLIC_IN_TRUCK] = true
	end
	if status.vacuuming then
		fields[ShiftConstants.PUBLIC_VACUUMING] = true
	end
	local room, depth, cam = status.room, status.roomDepth, status.cam
	if room ~= nil then
		fields[ShiftConstants.PUBLIC_ROOM] = room
	end
	if depth ~= nil then
		fields[ShiftConstants.PUBLIC_ROOM_DEPTH] = depth
	end
	if cam ~= nil then
		fields[ShiftConstants.PUBLIC_CAM] = cam
	end
	return fields
end

function ShiftCrewStatusUtils.changes(before: Status?, after: Status?): Change
	local old: PublicPlayer = if before ~= nil then ShiftCrewStatusUtils.fields(before) else {}
	local new: PublicPlayer = if after ~= nil then ShiftCrewStatusUtils.fields(after) else {}
	local set: PublicPlayer = {}
	local clear: { string } = {}
	for field, value in new do
		if old[field] ~= value then
			set[field] = value
		end
	end
	for field in old do
		if new[field] == nil then
			table.insert(clear, field)
		end
	end
	return { set = set, clear = clear }
end

return ShiftCrewStatusUtils
