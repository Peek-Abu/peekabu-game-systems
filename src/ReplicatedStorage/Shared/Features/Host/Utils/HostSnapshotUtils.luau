--!strict
--[=[
	HostSnapshotUtils: turns the replicated `host` world entry (plain data off the wire) back into a typed
	HostSnapshot, or nil when it is malformed, and finds a truck's host. The server builds the entry
	(HostTruckTracker:snapshot); this is the client's trust boundary.

	@class HostSnapshotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local HostTypes = require(ReplicatedStorage.Shared.Features.Host.Data.HostTypes)

type WorldValue = WorldTypes.WorldValue

local function truckFrom(value: WorldValue?): HostTypes.TruckView?
	if type(value) ~= "table" then
		return nil
	end
	local host = value.host
	local locked = value.locked
	if type(host) ~= "number" or (locked ~= nil and type(locked) ~= "boolean") then
		return nil
	end
	return { host = host, locked = locked == true }
end

local HostSnapshotUtils = {}

--[=[
	Decodes the `host` world entry. Absent trucks decode as none; a wrong type anywhere rejects the whole value.
]=]
function HostSnapshotUtils.decode(value: WorldValue?): HostTypes.HostSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local trucks: { [string]: HostTypes.TruckView } = {}
	local raw = value.trucks
	if raw ~= nil then
		if type(raw) ~= "table" then
			return nil
		end
		for key, item in raw do
			local truck = truckFrom(item)
			if type(key) ~= "string" or truck == nil then
				return nil
			end
			trucks[key] = truck
		end
	end
	return { trucks = trucks }
end

function HostSnapshotUtils.hostOf(snapshot: HostTypes.HostSnapshot?, padId: string): number?
	if snapshot == nil then
		return nil
	end
	local truck = snapshot.trucks[padId]
	return if truck ~= nil then truck.host else nil
end

return HostSnapshotUtils
