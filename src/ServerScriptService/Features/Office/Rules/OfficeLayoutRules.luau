--!strict
--[=[
	OfficeLayoutRules: is a layout buildable and playable? `validate` lists every problem: duplicate or empty
	rooms, overlapping rooms, doors that name missing rooms, are too narrow or are not on a wall both rooms
	share, rooms the start room cannot reach, markers outside their room (or within MARKER_MARGIN of a
	wall), and a truck outside the start room. `checkCapacity` says whether the spawn roll has the markers
	it needs. `checkRoute` (M2) says whether Harlow's patrol route and rest point are usable. OfficeServiceServer refuses to build a layout that fails either. Pure.

	@class OfficeLayoutRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room

local OfficeLayoutRules = {}

local function inside(room: Room, x: number, z: number, margin: number): boolean
	return x >= room.minX + margin and x <= room.maxX - margin and z >= room.minZ + margin and z <= room.maxZ - margin
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
		elseif not inside(room, marker.x, marker.z, OfficeConstants.MARKER_MARGIN) then
			table.insert(errors, `marker "{marker.id}" is not inside room "{room.id}"`)
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
