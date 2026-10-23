--!strict
--[=[
	OfficeLayoutRules: is a layout buildable and playable? `validate` lists every problem: duplicate or empty
	rooms, overlapping rooms, doors that name missing rooms, are too narrow or are not on a wall both rooms
	share, rooms the start room cannot reach, markers outside their room (or within MARKER_MARGIN of a
	wall), surface furniture (counters, tables, cabinets) crowded by floor loot spots or overlapping desks,
	lockers or piles, wall props (PROP_WALL_HEIGHT) hung over a door or facade of their wall, floor `prop` markers (art-only dressing sized by OfficeConstants.PROP_SIZES) treated like surface
	furniture for those tests (furniture sizes come from OfficeLayoutUtils.markerSize, art-sized where the marker's `art`
	has an ART_SIZES entry), and a truck outside the start room. `checkCapacity` says whether the spawn roll has the markers
	it needs. `checkRoute` (M2) says whether Harlow's patrol route and rest point are usable. `checkHideSpots` and `checkWalk` hold generated maps to the hiding-place count and the walking distance from the bay. OfficeServiceServer refuses to build a layout that fails them. Pure.

	@class OfficeLayoutRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeGroundsUtils = require(OfficeServer.Utils.OfficeGroundsUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Edge = OfficeTypes.Edge

local PILE_HALF = 0
for _, style in VacuumConstants.PILE_KINDS do
	PILE_HALF = math.max(PILE_HALF, style.size.X / 2, style.size.Z / 2)
end

-- The kinds whose footprint the surface tests use (a floor `prop` too); other kinds are tested as points.
local SURFACE_KINDS: { [string]: boolean } =
	{ counter = true, table = true, cabinet = true, desk = true, locker = true }

-- Props hung on a wall or standing on a desk are above the floor, and a flat one (a rug) is under what stands on it;
-- the rest take floor space.
local isFloorProp = OfficeLayoutUtils.isFloorProp

local function halfExtents(marker: OfficeTypes.Marker): Vector2?
	if marker.kind ~= "prop" and not SURFACE_KINDS[marker.kind] then
		return nil
	end
	local size = OfficeLayoutUtils.markerSize(marker)
	return if size ~= nil then Vector2.new(size.X / 2, size.Z / 2) else nil
end

local function rotatedHalf(marker: OfficeTypes.Marker): Vector2?
	local half = halfExtents(marker)
	if half == nil then
		return nil
	end
	local angle = marker.rotation or 0
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return Vector2.new(half.X * c + half.Y * s, half.X * s + half.Y * c)
end

-- Whether a desk or locker footprint overlaps the surface furniture `marker`.
local function overlapsFootprint(marker: OfficeTypes.Marker, half: Vector2, other: OfficeTypes.Marker): boolean
	local ohalf = rotatedHalf(other)
	return ohalf ~= nil
		and math.abs(other.x - marker.x) < half.X + ohalf.X
		and math.abs(other.z - marker.z) < half.Y + ohalf.Y
end

-- What crowds the surface furniture or floor prop `marker` (none for any other kind).
local function surfaceProblems(layout: Layout, marker: OfficeTypes.Marker): { string }
	local problems: { string } = {}
	if OfficeLayoutUtils.surfaceTopY(marker.kind) == nil and not isFloorProp(marker) then
		return problems
	end
	local half = rotatedHalf(marker)
	if half == nil then
		table.insert(problems, `prop marker "{marker.id}" names no sized art`)
		return problems
	end
	for _, other in layout.markers do
		if other.id ~= marker.id then
			if other.kind == "item" then
				local clear = OfficeConstants.SURFACE_ITEM_CLEAR
				if math.abs(other.x - marker.x) < half.X + clear and math.abs(other.z - marker.z) < half.Y + clear then
					table.insert(problems, `surface marker "{marker.id}" crowds item marker "{other.id}"`)
				end
			elseif other.kind == "desk" or other.kind == "locker" then
				if overlapsFootprint(marker, half, other) then
					table.insert(problems, `surface marker "{marker.id}" overlaps "{other.id}"`)
				end
			elseif other.kind == "pile" then
				if
					math.abs(other.x - marker.x) < half.X + PILE_HALF
					and math.abs(other.z - marker.z) < half.Y + PILE_HALF
				then
					table.insert(problems, `surface marker "{marker.id}" overlaps "{other.id}"`)
				end
			end
		end
	end
	return problems
end

-- Whether `marker` is a prop hung on a wall.
local function isWallProp(marker: OfficeTypes.Marker): boolean
	return marker.kind == "prop" and marker.art ~= nil and OfficeConstants.PROP_WALL_HEIGHT[marker.art] ~= nil
end

-- Wall-mounted `marker` hung over a door or facade of `room` on the wall it lies against (spans overlapping along it).
local function coversOpening(layout: Layout, room: Room, marker: OfficeTypes.Marker): boolean
	local half = rotatedHalf(marker)
	if half == nil then
		return false
	end
	local box =
		{ minX = marker.x - half.X, maxX = marker.x + half.X, minZ = marker.z - half.Y, maxZ = marker.z + half.Y }
	for _, edge: Edge in OfficeLayoutUtils.wallsAgainst(room, box) do
		local openings = OfficeLayoutUtils.openingsOn(layout, room, edge)
		local horizontal = edge == "minZ" or edge == "maxZ"
		local from = if horizontal then box.minX else box.minZ
		local to = if horizontal then box.maxX else box.maxZ
		for _, span in openings do
			if from < span[2] - 0.001 and span[1] < to - 0.001 then
				return true
			end
		end
	end
	return false
end

local OfficeLayoutRules = {}

local function inside(room: Room, x: number, z: number, margin: number): boolean
	return x >= room.minX + margin and x <= room.maxX - margin and z >= room.minZ + margin and z <= room.maxZ - margin
end

local function markerInside(room: Room, marker: OfficeTypes.Marker): boolean
	-- Plants are tested as points; every other furniture kind and prop by its footprint.
	local size: Vector3? = if marker.kind == "plant" then nil else OfficeLayoutUtils.markerSize(marker)
	local rotation = marker.rotation or (if marker.kind == "prop" then 0 else nil)
	if size == nil or rotation == nil then
		return inside(room, marker.x, marker.z, OfficeConstants.MARKER_MARGIN)
	end
	local cosine, sine = math.abs(math.cos(rotation)), math.abs(math.sin(rotation))
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

	-- A spawn marker may name a ground (the yard); nothing else does.
	local groundsById: { [string]: Room } = {}
	local grounds: { Room } = layout.grounds or {}
	for _, ground in grounds do
		groundsById[ground.id] = ground
	end
	local seen: { [string]: boolean } = {}
	for _, marker in layout.markers do
		if seen[marker.id] then
			table.insert(errors, `marker "{marker.id}" is defined twice`)
		end
		seen[marker.id] = true
		local room = roomsById[marker.room] or groundsById[marker.room]
		if room == nil then
			table.insert(errors, `marker "{marker.id}" names a missing room`)
		elseif not markerInside(room, marker) then
			table.insert(errors, `marker "{marker.id}" is not inside room "{room.id}"`)
		elseif isWallProp(marker) and coversOpening(layout, room, marker) then
			table.insert(errors, `wall prop "{marker.id}" hangs over a door or facade of room "{room.id}"`)
		end
	end

	-- Surface furniture stands clear: loot never clips into it and it never swallows gameplay volumes.
	for _, marker in layout.markers do
		for _, problem in surfaceProblems(layout, marker) do
			table.insert(errors, problem)
		end
	end

	local truck = layout.truck
	if layout.grounds ~= nil then
		for _, problem in OfficeGroundsUtils.problems(layout) do
			table.insert(errors, problem)
		end
	elseif
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
	Whether `marker` passes the per-marker checks `validate` runs: inside its room's walls, and clear of what it
	would crowd (surface furniture of loot, desks, lockers and piles; a desk or locker of surface furniture).
	Used to drop furniture that no longer fits. Pure.
]=]
function OfficeLayoutRules.markerFits(layout: Layout, marker: OfficeTypes.Marker): boolean
	local room: Room? = nil
	for _, candidate in layout.rooms do
		if candidate.id == marker.room then
			room = candidate
			break
		end
	end
	if room == nil or not markerInside(room, marker) then
		return false
	end
	if #surfaceProblems(layout, marker) > 0 then
		return false
	end
	if marker.kind == "desk" or marker.kind == "locker" then
		for _, other in layout.markers do
			if other.id ~= marker.id and (OfficeLayoutUtils.surfaceTopY(other.kind) ~= nil or isFloorProp(other)) then
				-- The surface piece's own half-extent, against this desk or locker's.
				local otherHalf = rotatedHalf(other)
				if otherHalf ~= nil and overlapsFootprint(other, otherHalf, marker) then
					return false
				end
			end
		end
	end
	return true
end

--[=[
	Whether the spawn roll can always run on this layout: enough rooms with room for a dirty room's piles (at least
	DIRTY_ROOMS.max rooms holding PILES_PER_ROOM.min pile markers or more), a spawn marker, and a deep item marker and a
	deep desk or locker for the greed target.
]=]
function OfficeLayoutRules.checkCapacity(layout: Layout): (boolean, string?)
	local perRoom: { [string]: number } = {}
	for _, marker in OfficeLayoutUtils.markersOf(layout, "pile") do
		perRoom[marker.room] = (perRoom[marker.room] or 0) + 1
	end
	local dirtyable = 0
	for _, count in perRoom do
		if count >= OfficeConstants.PILES_PER_ROOM.min then
			dirtyable += 1
		end
	end
	if dirtyable < OfficeConstants.DIRTY_ROOMS.max then
		return false,
			`{dirtyable} rooms have {OfficeConstants.PILES_PER_ROOM.min} pile markers; the roll needs {OfficeConstants.DIRTY_ROOMS.max}`
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
	Whether Mr. Harlow can patrol this layout (M2): at least ROUTE_MIN route points, each a patrol marker off the truck
	(he may walk the loading bay; the truck's box is the safe place), and a rest marker outside the loading bay (his
	break never parks him by the truck).
]=]
-- On the truck or its ramp: the bed's footprint grown by TRUCK_ROUTE_CLEAR, and the ramp's length behind it.
local function onTruck(truck: OfficeTypes.Truck, marker: OfficeTypes.Marker): boolean
	local clear = OfficeConstants.TRUCK_ROUTE_CLEAR
	return marker.x >= truck.minX - clear
		and marker.x <= truck.maxX + clear
		and marker.z >= truck.minZ - TruckVisual.RAMP_LENGTH - clear
		and marker.z <= truck.maxZ + clear
end

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
		if marker.room == layout.startRoom and onTruck(layout.truck, marker) then
			return false, `route point "{id}" is on the truck`
		end
	end
	local rest = byId[layout.rest]
	if rest == nil or rest.kind ~= "rest" then
		return false, `rest point "{layout.rest}" is not a rest marker`
	end
	if rest.room == layout.startRoom then
		return false, `rest point "{layout.rest}" is in the loading bay`
	end
	return true, nil
end

--[=[
	Whether the map has enough places to hide: at least HIDE_SPOTS_MIN desk and closet markers.
]=]
function OfficeLayoutRules.checkHideSpots(layout: Layout): (boolean, string?)
	local count = #OfficeLayoutUtils.markersOf(layout, "desk") + #OfficeLayoutUtils.markersOf(layout, "closet")
	if count < OfficeConstants.HIDE_SPOTS_MIN then
		return false, `{count} hide spots (desks and closets); the map needs {OfficeConstants.HIDE_SPOTS_MIN}`
	end
	return true, nil
end

--[=[
	Whether every room is within `maxStuds` of walking from the start room: Dijkstra over door centres (a door
	touching the start room is at 0; two doors on one room are joined by their straight-line distance), then the
	step from the nearest door to the room's centre. Fails naming the farthest room.
]=]
function OfficeLayoutRules.checkWalk(layout: Layout, maxStuds: number): (boolean, string?)
	local distances = OfficeLayoutUtils.walkDistances(layout)
	local worstId, worst = "", 0
	for _, room in layout.rooms do
		local reach = distances[room.id] or math.huge
		if reach > worst then
			worstId, worst = room.id, reach
		end
	end
	if worst > maxStuds then
		return false, `room "{worstId}" is {math.floor(worst)} studs from the start (limit {maxStuds})`
	end
	return true, nil
end

return OfficeLayoutRules
