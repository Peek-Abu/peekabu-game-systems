--!strict
--[=[
	QueueSnapshotUtils: turns the replicated `queue` world entry (plain data off the wire, typed as a
	WorldValue) back into a typed QueueSnapshot, or nil when it is malformed, and finds the pad a player is
	aboard. The server builds the entry (QueuePadTracker:snapshot); this is the client's trust boundary.

	@class QueueSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type WorldValue = WorldTypes.WorldValue
type PadSnapshot = QueueTypes.PadSnapshot
type QueueSnapshot = QueueTypes.QueueSnapshot

-- A list of numbers; nil decodes as empty (an empty list does not survive the wire).
local function numberList(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for _, item in value do
		if type(item) ~= "number" then
			return nil
		end
		table.insert(result, item)
	end
	return result
end

local function padFrom(value: WorldValue?): PadSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local members = numberList(value.members)
	local capacity = value.capacity
	local destination = value.destination
	local endsAt = value.endsAt
	local departing = value.departing
	if members == nil or type(capacity) ~= "number" or type(destination) ~= "string" then
		return nil
	end
	if endsAt ~= nil and type(endsAt) ~= "number" then
		return nil
	end
	if type(departing) ~= "boolean" then
		return nil
	end
	return {
		members = members,
		capacity = capacity,
		destination = destination,
		endsAt = if type(endsAt) == "number" then endsAt else nil,
		departing = departing,
	}
end

local QueueSnapshotUtils = {}

--[=[
	Decodes the `queue` world entry. Absent pads decode as none; a wrong type anywhere rejects the whole value.
]=]
function QueueSnapshotUtils.decode(value: WorldValue?): QueueSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local pads: { [string]: PadSnapshot } = {}
	local raw = value.pads
	if raw ~= nil then
		if type(raw) ~= "table" then
			return nil
		end
		for key, item in raw do
			local pad = padFrom(item)
			if type(key) ~= "string" or pad == nil then
				return nil
			end
			pads[key] = pad
		end
	end
	return { pads = pads }
end

-- The pad `userId` is aboard (its id and snapshot), or nil.
function QueueSnapshotUtils.padOf(snapshot: QueueSnapshot?, userId: number): (string?, PadSnapshot?)
	if snapshot == nil then
		return nil, nil
	end
	for padId, pad in snapshot.pads do
		if table.find(pad.members, userId) ~= nil then
			return padId, pad
		end
	end
	return nil, nil
end

return QueueSnapshotUtils
