--!strict
--[=[
	OfficeLayoutUtils: answers about a layout: lookups, each room's depth (doors from the start room, by
	breadth-first search), which wall a door sits on, and the wall pieces a room's edges break into around
	its doors (per room, or merged across the layout). Pure.

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

--[=[
	Every wall of the layout with the duplicates removed. Each room emits its own walls, so a wall two rooms
	share comes out twice, and rooms of different lengths overlap only partly: the pieces are unioned per
	wall line (touching pieces join), so each stretch of wall appears exactly once.
]=]
function OfficeLayoutUtils.mergedWallSegments(layout: Layout): { OfficeTypes.Segment }
	local lines: { [string]: { horizontal: boolean, fixed: number, spans: { { number } } } } = {}
	for _, room in layout.rooms do
		for _, segment in OfficeLayoutUtils.wallSegments(room, layout.doors) do
			local horizontal = segment.z1 == segment.z2
			local fixed = if horizontal then segment.z1 else segment.x1
			local key = `{if horizontal then "h" else "v"}{fixed}`
			local line = lines[key]
			if line == nil then
				line = { horizontal = horizontal, fixed = fixed, spans = {} }
				lines[key] = line
			end
			local from = if horizontal then segment.x1 else segment.z1
			local to = if horizontal then segment.x2 else segment.z2
			table.insert(line.spans, { from, to })
		end
	end
	local merged: { OfficeTypes.Segment } = {}
	for _, line in lines do
		table.sort(line.spans, function(a, b)
			return a[1] < b[1]
		end)
		local from, to = line.spans[1][1], line.spans[1][2]
		local function emit()
			if line.horizontal then
				table.insert(merged, { x1 = from, z1 = line.fixed, x2 = to, z2 = line.fixed })
			else
				table.insert(merged, { x1 = line.fixed, z1 = from, x2 = line.fixed, z2 = to })
			end
		end
		for index = 2, #line.spans do
			local span = line.spans[index]
			if span[1] <= to + 1e-6 then
				to = math.max(to, span[2])
			else
				emit()
				from, to = span[1], span[2]
			end
		end
		emit()
	end
	return merged
end

--[=[
	Ceiling-light spots for a room ({ x, z }, office-local): an even grid of about `spacing` studs, at least one,
	each in the middle of its cell.
]=]
function OfficeLayoutUtils.lightPoints(room: Room, spacing: number): { { number } }
	local width = room.maxX - room.minX
	local depth = room.maxZ - room.minZ
	local across = math.max(1, math.floor(width / spacing))
	local deep = math.max(1, math.floor(depth / spacing))
	local points: { { number } } = {}
	for column = 1, across do
		for row = 1, deep do
			table.insert(points, {
				room.minX + width * (column - 0.5) / across,
				room.minZ + depth * (row - 0.5) / deep,
			})
		end
	end
	return points
end

--[=[
	The room's box, office-local: (min, max) from the floor to `height`.
]=]
function OfficeLayoutUtils.bounds(room: Room, height: number): (Vector3, Vector3)
	return Vector3.new(room.minX, 0, room.minZ), Vector3.new(room.maxX, height, room.maxZ)
end

return OfficeLayoutUtils
