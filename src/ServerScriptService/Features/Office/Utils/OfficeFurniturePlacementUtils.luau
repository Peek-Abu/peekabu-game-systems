--!strict
-- Normalize legacy authored dressing once, before the same markers feed spawn and build.
local Server = game:GetService("ServerScriptService").Features.Office
local Constants = require(Server.Data.OfficeConstants)
local Types = require(Server.Data.OfficeTypes)
local LayoutUtils = require(Server.Utils.OfficeLayoutUtils)
local Utils = {}
local WALL_SIZES: { [string]: Vector3? } = {
	locker = Constants.LOCKER_SIZE,
	shelf = Constants.SHELF_SIZE,
	counter = Constants.COUNTER_SIZE,
	cabinet = Constants.CABINET_SIZE,
	board = Constants.BOARD_SIZE,
}
local FLOOR_SIZES: { [string]: Vector3? } = {
	desk = Constants.DESK_SIZE,
	locker = Constants.LOCKER_SIZE,
	shelf = Constants.SHELF_SIZE,
	counter = Constants.COUNTER_SIZE,
	cabinet = Constants.CABINET_SIZE,
	closet = Constants.CLOSET_SIZE,
	table = Constants.TABLE_SIZE,
	-- A board stands on the floor on its own legs: a floor footprint like any other.
	board = Constants.BOARD_SIZE,
	plant = Constants.PLANT_SIZE,
	-- Preserve authoritative cargo/pile positions and walkable player/NPC route points.
	item = Vector3.new(3.6, 3.6, 3.6),
	pile = Vector3.new(3.6, 0.2, 3.6),
	spawn = Vector3.new(4, 0.2, 4),
	patrol = Vector3.new(4, 0.2, 4),
	rest = Vector3.new(4, 0.2, 4),
}
local function halfExtents(size: Vector3, yaw: number): (number, number)
	local cosine, sine = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	return (size.X * cosine + size.Z * sine) / 2, (size.X * sine + size.Z * cosine) / 2
end
local function clear(candidate: Types.Marker, size: Vector3, layout: Types.Layout): boolean
	local halfX, halfZ = halfExtents(size, candidate.rotation or 0)
	for _, other in layout.markers do
		if other.id ~= candidate.id and other.room == candidate.room then
			local otherSize = FLOOR_SIZES[other.kind]
			if otherSize ~= nil then
				local otherX, otherZ = halfExtents(otherSize, other.rotation or 0)
				if
					math.abs(candidate.x - other.x) < halfX + otherX + 0.2
					and math.abs(candidate.z - other.z) < halfZ + otherZ + 0.2
				then
					return false
				end
			end
		end
	end
	for _, door in layout.doors do
		if door.a == candidate.room or door.b == candidate.room then
			if
				math.abs(candidate.x - door.x) < halfX + door.width / 2 + 1.5
				and math.abs(candidate.z - door.z) < halfZ + door.width / 2 + 1.5
			then
				return false
			end
		end
	end
	return true
end
local function mount(marker: Types.Marker, room: Types.Room, size: Vector3, layout: Types.Layout): Types.Marker?
	local best: Types.Marker? = nil
	local distance = math.huge
	local inset = Constants.WALL_THICKNESS / 2 + size.Z / 2 + 0.1
	for _, segment in LayoutUtils.wallSegments(room, layout.doors) do
		local horizontal = segment.z1 == segment.z2
		local start = if horizontal then segment.x1 else segment.z1
		local finish = if horizontal then segment.x2 else segment.z2
		local low, high = start + size.X / 2 + 0.6, finish - size.X / 2 - 0.6
		if low > high then
			continue
		end
		local target = math.clamp(if horizontal then marker.x else marker.z, low, high)
		local coordinates = { target, low, high }
		for step = math.ceil(low), math.floor(high) do
			table.insert(coordinates, step)
		end
		for _, coordinate in coordinates do
			local candidate = table.clone(marker)
			if horizontal then
				local near = segment.z1 == room.minZ
				candidate.x, candidate.z = coordinate, segment.z1 + (if near then inset else -inset)
				candidate.rotation = if near then math.pi else 0
			else
				local near = segment.x1 == room.minX
				candidate.x, candidate.z = segment.x1 + (if near then inset else -inset), coordinate
				candidate.rotation = if near then -math.pi / 2 else math.pi / 2
			end
			local halfX, halfZ = halfExtents(size, candidate.rotation or 0)
			local inside = candidate.x - halfX >= room.minX + 0.5
				and candidate.x + halfX <= room.maxX - 0.5
				and candidate.z - halfZ >= room.minZ + 0.5
				and candidate.z + halfZ <= room.maxZ - 0.5
			local squared = (candidate.x - marker.x) ^ 2 + (candidate.z - marker.z) ^ 2
			if inside and squared < distance and clear(candidate, size, layout) then
				best, distance = candidate, squared
			end
		end
	end
	return best
end
function Utils.normalize(layout: Types.Layout): Types.Layout
	local result = table.clone(layout)
	result.markers = {}
	for _, marker in layout.markers do
		table.insert(result.markers, table.clone(marker))
	end
	for index, marker in result.markers do
		if marker.rotation ~= nil then
			continue
		end
		local room = LayoutUtils.room(result, marker.room)
		if room == nil then
			continue
		end
		local size = WALL_SIZES[marker.kind]
		if size ~= nil then
			local placed = mount(marker, room, size, result)
			if placed == nil then
				error(`no clear wall placement for "{marker.id}"`)
			end
			result.markers[index] = placed
		elseif marker.kind == "plant" then
			local inset = Constants.WALL_THICKNESS / 2 + Constants.PLANT_SIZE.X / 2 + 0.1
			local best: Types.Marker? = nil
			local distance = math.huge
			for _, x in { room.minX + inset, room.maxX - inset } do
				for _, z in { room.minZ + inset, room.maxZ - inset } do
					local candidate = table.clone(marker)
					candidate.x, candidate.z, candidate.rotation = x, z, 0
					local squared = (x - marker.x) ^ 2 + (z - marker.z) ^ 2
					if squared < distance and clear(candidate, Constants.PLANT_SIZE, result) then
						best, distance = candidate, squared
					end
				end
			end
			if best == nil then
				error(`no clear corner placement for "{marker.id}"`)
			end
			result.markers[index] = best
		end
	end
	return result
end
return Utils
