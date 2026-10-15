--!strict
--[=[
	OfficeLayoutRules: is a layout buildable and playable? `validate` lists every problem: duplicate or empty
	rooms, overlapping rooms, doors that name missing rooms, are too narrow or are not on a wall both rooms
	share, rooms the start room cannot reach, markers outside their room (or within MARKER_MARGIN of a
	wall), surface furniture (counters, tables, cabinets) crowded by floor loot spots or overlapping desks,
	lockers or piles, and a truck outside the start room. `checkCapacity` says whether the spawn roll has the markers
	it needs. `checkRoute` (M2) says whether Harlow's patrol route and rest point are usable. OfficeServiceServer refuses to build a layout that fails either. Pure.

	@class OfficeLayoutRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room

local OfficeLayoutRules = {}

local function inside(room: Room, x: number, z: number, margin: number): boolean
	return x >= room.minX + margin and x <= room.maxX - margin and z >= room.minZ + margin and z <= room.maxZ - margin
end

local function markerInside(room: Room, marker: OfficeTypes.Marker): boolean
	local sizes: { [string]: Vector3 } = {
		counter = OfficeConstants.COUNTER_SIZE,
		table = OfficeConstants.TABLE_SIZE,
		cabinet = OfficeConstants.CABINET_SIZE,
		desk = OfficeConstants.DESK_SIZE,
		locker = OfficeConstants.LOCKER_SIZE,
		shelf = OfficeConstants.SHELF_SIZE,
		board = OfficeConstants.BOARD_SIZE,
	}
	local size: Vector3? = sizes[marker.kind]
	if size == nil or marker.rotation == nil then
		return inside(room, marker.x, marker.z, OfficeConstants.MARKER_MARGIN)
	end
	local cosine, sine = math.abs(math.cos(marker.rotation)), math.abs(math.sin(marker.rotation))
	local halfX = (size.X * cosine + size.Z * sine) / 2
	local halfZ = (size.X * sine + size.Z * cosine) / 2
	local wall = OfficeConstants.WALL_THICKNESS / 2
	return marker.x - halfX >= room.minX + wall - 0.001
		and marker.x + halfX <= room.maxX - wall + 0.001
		and marker.z - halfZ >= room.minZ + wall - 0.001
		and marker.z + halfZ <= room.maxZ - wall + 0.001
end

--[=[
	Every problem with `layout`; ok when there are none.
]=]
function OfficeLayoutRules.validate(layout: Layout): (boolean, { string })
	local errors: { string } = {}
	local roomsById: { [string]: Room } = {}
	for _, room in layout.rooms do
		if roomsById[room.id] ~= nil then
			table.insert(errors, `room "{room.id}" is defined twice`)
		end
		if room.minX >= room.maxX or room.minZ >= room.maxZ then
			table.insert(errors, `room "{room.id}" has no floor area`)
		end
		roomsById[room.id] = room
	end
	for index, a in layout.rooms do
		for other = index + 1, #layout.rooms do
			local b = layout.rooms[other]
			if a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ then
				table.insert(errors, `rooms "{a.id}" and "{b.id}" overlap`)
			end
		end
	end
	local start = roomsById[layout.startRoom]
	if start == nil then
		table.insert(errors, `start room "{layout.startRoom}" does not exist`)
	end

	for _, door in layout.doors do
		local a = roomsById[door.a]
		local b = roomsById[door.b]
		if a == nil or b == nil then
			table.insert(errors, `door {door.a}-{door.b} names a missing room`)
		elseif door.width < OfficeConstants.DOOR_MIN_WIDTH then
			table.insert(errors, `door {door.a}-{door.b} is narrower than {OfficeConstants.DOOR_MIN_WIDTH} studs`)
		elseif OfficeLayoutUtils.doorEdge(a, door) == nil or OfficeLayoutUtils.doorEdge(b, door) == nil then
			table.insert(errors, `door {door.a}-{door.b} is not on a wall both rooms share`)
		end
	end

	local depths = OfficeLayoutUtils.depths(layout)
	for _, room in layout.rooms do
		if depths[room.id] == nil then
			table.insert(errors, `room "{room.id}" cannot be reached from "{layout.startRoom}"`)
		end
	end

	local seen: { [string]: boolean } = {}
	for _, marker in layout.markers do
		if seen[marker.id] then
			table.insert(errors, `marker "{marker.id}" is defined twice`)
		end
		seen[marker.id] = true
		local room = roomsById[marker.room]
		if room == nil then
			table.insert(errors, `marker "{marker.id}" names a missing room`)
		elseif not markerInside(room, marker) then
			table.insert(errors, `marker "{marker.id}" is not inside room "{room.id}"`)
		end
	end

	-- Surface furniture stands clear: loot never clips into it and it never swallows gameplay volumes.
	local PILE_HALF = 0
	for _, style in VacuumConstants.PILE_KINDS do
		PILE_HALF = math.max(PILE_HALF, style.size.X / 2, style.size.Z / 2)
	end
	local function halfExtents(kind: OfficeTypes.MarkerKind): Vector2?
		if kind == "counter" then
			return Vector2.new(OfficeConstants.COUNTER_SIZE.X / 2, OfficeConstants.COUNTER_SIZE.Z / 2)
		elseif kind == "table" then
			return Vector2.new(OfficeConstants.TABLE_SIZE.X / 2, OfficeConstants.TABLE_SIZE.Z / 2)
		elseif kind == "cabinet" then
			return Vector2.new(OfficeConstants.CABINET_SIZE.X / 2, OfficeConstants.CABINET_SIZE.Z / 2)
		elseif kind == "desk" then
			return Vector2.new(OfficeConstants.DESK_SIZE.X / 2, OfficeConstants.DESK_SIZE.Z / 2)
		elseif kind == "locker" then
			return Vector2.new(OfficeConstants.LOCKER_SIZE.X / 2, OfficeConstants.LOCKER_SIZE.Z / 2)
		end
		return nil
	end
	local function rotatedHalf(marker: OfficeTypes.Marker): Vector2?
		local half = halfExtents(marker.kind)
		if half == nil then
			return nil
		end
		local angle = marker.rotation or 0
		local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
		return Vector2.new(half.X * c + half.Y * s, half.X * s + half.Y * c)
	end
	for _, marker in layout.markers do
		if OfficeLayoutUtils.surfaceTopY(marker.kind) ~= nil then
			local half = rotatedHalf(marker)
			assert(half ~= nil, `surface marker "{marker.id}" has no footprint`)
			for _, other in layout.markers do
				if other.id ~= marker.id then
					if other.kind == "item" then
						local clear = OfficeConstants.SURFACE_ITEM_CLEAR
						if
							math.abs(other.x - marker.x) < half.X + clear
							and math.abs(other.z - marker.z) < half.Y + clear
						then
							table.insert(errors, `surface marker "{marker.id}" crowds item marker "{other.id}"`)
						end
					elseif other.kind == "desk" or other.kind == "locker" then
						local ohalf = rotatedHalf(other)
						if
							ohalf ~= nil
							and math.abs(other.x - marker.x) < half.X + ohalf.X
							and math.abs(other.z - marker.z) < half.Y + ohalf.Y
						then
							table.insert(errors, `surface marker "{marker.id}" overlaps "{other.id}"`)
						end
					elseif other.kind == "pile" then
						if
							math.abs(other.x - marker.x) < half.X + PILE_HALF
							and math.abs(other.z - marker.z) < half.Y + PILE_HALF
						then
							table.insert(errors, `surface marker "{marker.id}" overlaps "{other.id}"`)
						end
					end
				end
			end
		end
	end

	local truck = layout.truck
	if
		start ~= nil
		and not (
			inside(start, truck.minX, truck.minZ, 0)
			and inside(start, truck.maxX, truck.maxZ, 0)
			and inside(start, truck.clockX, truck.clockZ, 0)
		)
	then
		table.insert(errors, `the truck is not inside the start room "{start.id}"`)
	end
	return #errors == 0, errors
end

--[=[
	Whether the spawn roll can always run on this layout: enough pile markers for the largest pile roll, a
	spawn marker, and a deep item marker and a deep desk or locker for the greed target.
]=]
function OfficeLayoutRules.checkCapacity(layout: Layout): (boolean, string?)
	local piles = #OfficeLayoutUtils.markersOf(layout, "pile")
	if piles < OfficeConstants.PILES.max then
		return false, `{piles} pile markers; the roll needs {OfficeConstants.PILES.max}`
	end
	if #OfficeLayoutUtils.markersOf(layout, "spawn") == 0 then
		return false, "no spawn markers"
	end
	local depths = OfficeLayoutUtils.depths(layout)
	local deepItem = false
	local deepSearch = false
	for _, marker in layout.markers do
		local deep = (depths[marker.room] or 0) >= OfficeConstants.DEEP_DEPTH
		if deep and marker.kind == "item" then
			deepItem = true
		elseif deep and (marker.kind == "desk" or marker.kind == "locker") then
			deepSearch = true
		end
	end
	if not deepItem then
		return false, "no deep item marker for the greed target"
	end
	if not deepSearch then
		return false, "no deep desk or locker for a hidden greed target"
	end
	return true, nil
end

--[=[
	Whether Mr. Harlow can patrol this layout (M2): at least ROUTE_MIN route points, each a patrol marker
	outside the start room (the loading bay is his no-go safe zone), and a rest marker outside it too.
]=]
function OfficeLayoutRules.checkRoute(layout: Layout): (boolean, string?)
	local byId: { [string]: OfficeTypes.Marker } = {}
	for _, marker in layout.markers do
		byId[marker.id] = marker
	end
	if #layout.route < OfficeConstants.ROUTE_MIN then
		return false, `the patrol route has {#layout.route} points; it needs {OfficeConstants.ROUTE_MIN}`
	end
	for _, id in layout.route do
		local marker = byId[id]
		if marker == nil or marker.kind ~= "patrol" then
			return false, `route point "{id}" is not a patrol marker`
		end
		if marker.room == layout.startRoom then
			return false, `route point "{id}" is in the safe start room`
		end
	end
	local rest = byId[layout.rest]
	if rest == nil or rest.kind ~= "rest" then
		return false, `rest point "{layout.rest}" is not a rest marker`
	end
	if rest.room == layout.startRoom then
		return false, `rest point "{layout.rest}" is in the safe start room`
	end
	return true, nil
end

return OfficeLayoutRules
