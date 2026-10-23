--!strict
--[=[
	OfficeLayoutUtils: answers about a layout: lookups, each room's depth (doors from the start room, or its own
	`depth`), walking distances from the start room, which wall a door sits on, and the wall pieces a room's edges break into around
	its doors (per room, or merged across the layout). Pure.

	@class OfficeLayoutUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Door = OfficeTypes.Door
type Edge = OfficeTypes.Edge

-- What the size lookups need of a marker: a layout Marker or a kit's KitMarker.
type Sized = { kind: OfficeTypes.MarkerKind, art: string? }

-- What dropUnfit needs from OfficeLayoutRules (passed in: Rules requires this module).
type FitRules = { markerFits: (layout: Layout, marker: OfficeTypes.Marker) -> boolean }

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

-- The furniture top a surface spot stands on (office-local studs), or nil for floor spots.
-- Only marker kinds the spawn policy seats loot on report a height.
function OfficeLayoutUtils.surfaceTopY(kind: OfficeTypes.MarkerKind): number?
	if kind == "counter" then
		return OfficeConstants.COUNTER_SIZE.Y
	elseif kind == "table" then
		return OfficeConstants.TABLE_SIZE.Y
	elseif kind == "cabinet" then
		return OfficeConstants.CABINET_SIZE.Y
	end
	return nil
end

-- The proxy size of each furniture kind with no art override.
local KIND_SIZES: { [string]: Vector3 } = {
	desk = OfficeConstants.DESK_SIZE,
	locker = OfficeConstants.LOCKER_SIZE,
	closet = OfficeConstants.CLOSET_SIZE,
	shelf = OfficeConstants.SHELF_SIZE,
	counter = OfficeConstants.COUNTER_SIZE,
	cabinet = OfficeConstants.CABINET_SIZE,
	table = OfficeConstants.TABLE_SIZE,
	board = OfficeConstants.BOARD_SIZE,
	plant = OfficeConstants.PLANT_SIZE,
}

--[=[
	The size of this marker's furniture (X by Y by Z studs, before yaw), the one lookup builds, decor and the rules
	share: a prop is sized by PROP_SIZES[art] (nil when it names none), other furniture by ART_SIZES[art] when its
	`art` override has an entry (the proxy follows the restyled art) and by its kind otherwise; nil for a marker that
	is no furniture (piles, items, patrol...).
]=]
function OfficeLayoutUtils.markerSize(marker: Sized): Vector3?
	local art = marker.art
	if marker.kind == "prop" then
		return if art ~= nil then OfficeConstants.PROP_SIZES[art] else nil
	end
	if art ~= nil then
		local sized = OfficeConstants.ART_SIZES[art]
		if sized ~= nil then
			return sized
		end
	end
	return KIND_SIZES[marker.kind]
end

--[=[
	Whether `marker` is a prop standing on the floor (not hung on a wall, not on a desk): the ones that take floor
	space.
]=]
function OfficeLayoutUtils.isFloorProp(marker: Sized): boolean
	local art = marker.art
	return marker.kind == "prop"
		and (art == nil or (OfficeConstants.PROP_WALL_HEIGHT[art] == nil and OfficeConstants.PROP_DESK_TOP[art] == nil))
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
	`layout` without any desk or table `rules` rejects at the current furniture sizes (outside its room's walls, or
	overlapping another marker), and how many it dropped. Each is judged in layout order against the markers still
	standing, so two clashing pieces lose only the first. Nothing else is moved, resized or removed. Pure.
]=]
function OfficeLayoutUtils.dropUnfit(layout: Layout, rules: FitRules): (Layout, number)
	local working = table.clone(layout)
	working.markers = table.clone(layout.markers)
	local dropped = 0
	for _, marker in layout.markers do
		if marker.kind == "desk" or marker.kind == "table" then
			if not rules.markerFits(working, marker) then
				table.remove(working.markers, table.find(working.markers, marker))
				dropped += 1
			end
		end
	end
	if dropped == 0 then
		return layout, 0
	end
	return working, dropped
end

--[=[
	Each reachable room's depth (the start room is 0; unreachable rooms are absent): doors from the start room, by
	breadth-first search, unless the room carries its own `depth` (generated maps: walking distance in DEPTH_STUDS).
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
	for _, room in layout.rooms do
		local walked = room.depth
		if walked ~= nil and result[room.id] ~= nil then
			result[room.id] = walked
		end
	end
	return result
end

--[=[
	Studs of walking from the start room to the centre of every room it reaches (the start room is 0; others are
	absent): Dijkstra over door centres, where a door touching the start room is at 0 and two doors on one room are
	joined by their straight-line distance, then the step from the nearest door to the room's centre.
]=]
function OfficeLayoutUtils.walkDistances(layout: Layout): { [string]: number }
	local doors = layout.doors
	local byRoom: { [string]: { number } } = {}
	local dist: { number } = {}
	for index, door in doors do
		dist[index] = if door.a == layout.startRoom or door.b == layout.startRoom then 0 else math.huge
		for _, id in { door.a, door.b } do
			local list = byRoom[id] or {}
			byRoom[id] = list
			table.insert(list, index)
		end
	end
	local done: { [number]: boolean } = {}
	while true do
		local best: number? = nil
		for index in doors do
			if not done[index] and dist[index] < math.huge and (best == nil or dist[index] < dist[best]) then
				best = index
			end
		end
		if best == nil then
			break
		end
		done[best] = true
		local door = doors[best]
		for _, id in { door.a, door.b } do
			for _, other in byRoom[id] do
				local beside = doors[other]
				local step = math.sqrt((beside.x - door.x) ^ 2 + (beside.z - door.z) ^ 2)
				dist[other] = math.min(dist[other], dist[best] + step)
			end
		end
	end
	local result: { [string]: number } = { [layout.startRoom] = 0 }
	for _, room in layout.rooms do
		if room.id ~= layout.startRoom then
			local reach = math.huge
			local cx, cz = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
			local doorIndices: { number } = byRoom[room.id] or {}
			for _, index in doorIndices do
				local door = doors[index]
				reach = math.min(reach, dist[index] + math.sqrt((door.x - cx) ^ 2 + (door.z - cz) ^ 2))
			end
			if reach < math.huge then
				result[room.id] = reach
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
	wall line (touching pieces join), so each stretch of wall appears exactly once. The layout's glass panes are
	then cut out of the merged lines (after merging, so a neighbouring room's wall cannot refill the glass gap):
	a pane covering a piece removes it, a pane inside a piece splits it.
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
	local panes = OfficeLayoutUtils.panes(layout)
	if #panes == 0 then
		return merged
	end
	local result: { OfficeTypes.Segment } = {}
	for _, segment in merged do
		local horizontal = segment.z1 == segment.z2
		local fixed = if horizontal then segment.z1 else segment.x1
		local pieces: { { number } } =
			{ { if horizontal then segment.x1 else segment.z1, if horizontal then segment.x2 else segment.z2 } }
		for _, pane in panes do
			local paneHorizontal = pane.z1 == pane.z2
			local paneFixed = if paneHorizontal then pane.z1 else pane.x1
			if paneHorizontal == horizontal and math.abs(paneFixed - fixed) <= 1e-6 then
				local cutFrom = if horizontal then pane.x1 else pane.z1
				local cutTo = if horizontal then pane.x2 else pane.z2
				local remaining: { { number } } = {}
				for _, piece in pieces do
					if cutTo <= piece[1] + 1e-6 or cutFrom >= piece[2] - 1e-6 then
						table.insert(remaining, piece)
					else
						if cutFrom - piece[1] > 1e-6 then
							table.insert(remaining, { piece[1], cutFrom })
						end
						if piece[2] - cutTo > 1e-6 then
							table.insert(remaining, { cutTo, piece[2] })
						end
					end
				end
				pieces = remaining
			end
		end
		for _, piece in pieces do
			if horizontal then
				table.insert(result, { x1 = piece[1], z1 = fixed, x2 = piece[2], z2 = fixed })
			else
				table.insert(result, { x1 = fixed, z1 = piece[1], x2 = fixed, z2 = piece[2] })
			end
		end
	end
	return result
end

--[=[
	The layout's glass panes (wall spans the generator turned to glass, see mergedWallSegments); none when it has
	none. A copy of the list.
]=]
function OfficeLayoutUtils.panes(layout: Layout): { OfficeTypes.Segment }
	return table.clone(layout.panes or {})
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

--[=[
	The room a floor point (office-local studs) stands in, and its 1-based index in `layout.rooms` (the CCTV's camera
	number); a point on a shared wall belongs to the first room listed. Nothing outside every room.
]=]
function OfficeLayoutUtils.roomAt(layout: Layout, x: number, z: number): (Room?, number?)
	for index, room in layout.rooms do
		if x >= room.minX and x <= room.maxX and z >= room.minZ and z <= room.maxZ then
			return room, index
		end
	end
	return nil, nil
end

return OfficeLayoutUtils
