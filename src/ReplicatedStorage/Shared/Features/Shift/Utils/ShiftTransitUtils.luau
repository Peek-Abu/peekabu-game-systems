--!strict
--[=[
	ShiftTransitUtils: the `shiftTransit` world entry (ShiftConstants.TRANSIT_ENTRY): who the transit holds behind the
	load screen, and the route slip's lines. `build` turns the server's holds into plain data (a spot rides as x, y, z:
	charm-sync ships no Vector3); `decode` is the client's trust boundary for it (a wrong type anywhere rejects the whole
	value); `holdOf` finds one player's hold. Pure.

	@class ShiftTransitUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type WorldValue = WorldTypes.WorldValue
type WorldTable = WorldTypes.WorldTable
type TransitHold = ShiftTypes.TransitHold
type TransitSnapshot = ShiftTypes.TransitSnapshot

local function holdOfValue(value: WorldValue): TransitHold?
	if type(value) ~= "table" then
		return nil
	end
	local userId = value.userId
	local id = value.id
	local built = value.built
	if type(userId) ~= "number" or type(id) ~= "number" or type(built) ~= "boolean" then
		return nil
	end
	local seed = value.seed
	if seed ~= nil and type(seed) ~= "number" then
		return nil
	end
	local x, y, z = value.x, value.y, value.z
	local spot: Vector3? = nil
	if x ~= nil or y ~= nil or z ~= nil then
		if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
			return nil
		end
		spot = Vector3.new(x, y, z)
	end
	return {
		userId = userId,
		id = id,
		built = built,
		seed = if type(seed) == "number" then seed else nil,
		spot = spot,
	}
end

local ShiftTransitUtils = {}

--[=[
	The world entry for `holds` (a fresh table: publish a new one every time).
]=]
function ShiftTransitUtils.build(holds: { TransitHold }, client: string?, truck: number?): WorldTable
	local list: { WorldValue } = {}
	for _, hold in holds do
		local entry: WorldTable = { userId = hold.userId, id = hold.id, built = hold.built }
		local seed = hold.seed
		if seed ~= nil then
			entry.seed = seed
		end
		local spot = hold.spot
		if spot ~= nil then
			entry.x = spot.X
			entry.y = spot.Y
			entry.z = spot.Z
		end
		table.insert(list, entry)
	end
	local result: WorldTable = { holds = list }
	if client ~= nil then
		result.client = client
	end
	if truck ~= nil then
		result.truck = truck
	end
	return result
end

--[=[
	Decodes a replicated transit entry, or nil when it is malformed. Absent holds read as none.
]=]
function ShiftTransitUtils.decode(value: WorldValue?): TransitSnapshot?
	if type(value) ~= "table" then
		return nil
	end
	local holds: { TransitHold } = {}
	local rawHolds = value.holds
	if rawHolds ~= nil then
		if type(rawHolds) ~= "table" then
			return nil
		end
		for _, item in rawHolds do
			local hold = holdOfValue(item)
			if hold == nil then
				return nil
			end
			table.insert(holds, hold)
		end
	end
	local client = value.client
	local truck = value.truck
	if client ~= nil and type(client) ~= "string" then
		return nil
	end
	if truck ~= nil and type(truck) ~= "number" then
		return nil
	end
	return {
		holds = holds,
		client = if type(client) == "string" then client else nil,
		truck = if type(truck) == "number" then truck else nil,
	}
end

--[=[
	The hold for `userId`, or nil (no snapshot, or not held).
]=]
function ShiftTransitUtils.holdOf(snapshot: TransitSnapshot?, userId: number): TransitHold?
	if snapshot == nil then
		return nil
	end
	for _, hold in snapshot.holds do
		if hold.userId == userId then
			return hold
		end
	end
	return nil
end

return ShiftTransitUtils
