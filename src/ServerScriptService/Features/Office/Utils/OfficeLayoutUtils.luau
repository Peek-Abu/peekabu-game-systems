--!strict
--[=[
	OfficeLayoutUtils: answers about a layout: lookups, each room's depth (doors from the start room, by
	breadth-first search), which wall a door sits on, and the wall pieces a room's edges break into around
	its doors. Pure.

	@class OfficeLayoutUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Door = OfficeTypes.Door
type Edge = OfficeTypes.Edge

local OfficeLayoutUtils = {}

function OfficeLayoutUtils.room(layout: Layout, id: string): Room?
	for _, room in layout.rooms do
		if room.id == id then
			return room
		end
	end
	return nil
end

function OfficeLayoutUtils.marker(layout: Layout, id: string): OfficeTypes.Marker?
	for _, marker in layout.markers do
		if marker.id == id then
			return marker
		end
	end
	return nil
end

-- The markers of one kind, in layout order.
function OfficeLayoutUtils.markersOf(layout: Layout, kind: OfficeTypes.MarkerKind): { OfficeTypes.Marker }
	local list: { OfficeTypes.Marker } = {}
	for _, marker in layout.markers do
		if marker.kind == kind then
			table.insert(list, marker)
		end
	end
	return list
end

--[=[
	Doors from the start room to each reachable room (the start room is 0). Unreachable rooms are absent.
]=]
function OfficeLayoutUtils.depths(layout: Layout): { [string]: number }
	local result: { [string]: number } = { [layout.startRoom] = 0 }
	local queue: { string } = { layout.startRoom }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, door in layout.doors do
			local other: string? = nil
			if door.a == current then
				other = door.b
			elseif door.b == current then
				other = door.a
			end
			if other ~= nil and result[other] == nil then
				result[other] = result[current] + 1
				table.insert(queue, other)
			end
		end
	end
	return result
end

--[=[
	The wall of `room` the door's whole opening sits on, or nil when it is on none of them.
]=]
function OfficeLayoutUtils.doorEdge(room: Room, door: Door): Edge?
	local half = door.width / 2
	if door.z - half >= room.minZ and door.z + half <= room.maxZ then
		if door.x == room.minX then
			return "minX"
		elseif door.x == room.maxX then
			return "maxX"
		end
	end
	if door.x - half >= room.minX and door.x + half <= room.maxX then
		if door.z == room.minZ then
			return "minZ"
		elseif door.z == room.maxZ then
			return "maxZ"
		end
	end
	return nil
end

local EDGES: { Edge } = { "minZ", "maxZ", "minX", "maxX" }

--[=[
	The pieces of wall around `room`, edge by edge (minZ, maxZ, minX, maxX), each edge broken around the
	openings of the room's own doors (doors naming other rooms are ignored).
]=]
function OfficeLayoutUtils.wallSegments(room: Room, doors: { Door }): { OfficeTypes.Segment }
	local segments: { OfficeTypes.Segment } = {}
	for _, edge in EDGES do
		local horizontal = edge == "minZ" or edge == "maxZ"
		local fixed = if edge == "minZ"
			then room.minZ
			elseif edge == "maxZ" then room.maxZ
			elseif edge == "minX" then room.minX
			else room.maxX
		local from = if horizontal then room.minX else room.minZ
		local to = if horizontal then room.maxX else room.maxZ
		local gaps: { { number } } = {}
		for _, door in doors do
			if (door.a == room.id or door.b == room.id) and OfficeLayoutUtils.doorEdge(room, door) == edge then
				local centre = if horizontal then door.x else door.z
				table.insert(gaps, { centre - door.width / 2, centre + door.width / 2 })
			end
		end
		table.sort(gaps, function(a, b)
			return a[1] < b[1]
		end)
		local function emit(a: number, b: number)
			if b - a <= 1e-6 then
				return
			end
			if horizontal then
				table.insert(segments, { x1 = a, z1 = fixed, x2 = b, z2 = fixed })
			else
				table.insert(segments, { x1 = fixed, z1 = a, x2 = fixed, z2 = b })
			end
		end
		local cursor = from
		for _, gap in gaps do
			emit(cursor, gap[1])
			cursor = gap[2]
		end
		emit(cursor, to)
	end
	return segments
end

return OfficeLayoutUtils
