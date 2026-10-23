--!strict
--[=[
	OfficeGroundsUtils: the outside's geometry, in layout space. The grounds (yard and car park) are outdoor boxes that
	are never built as rooms; the yard truck stands on its pad turned toward the dock; two teleport entrances (dock
	and lobby) join a ground to a room.

	- `grounds()`: the yard and the car park.
	- `truck()`: the yard truck's bed and time clock, turned by TRUCK_YAW.
	- `dockEntrance(bay)` / `lobbyEntrance(reception, z, width)`: an entrance and its inside doorway.
	- `outsideFrame(entrance)` / `insideFrame(entrance, room)`: where a player arrives, outside or in.
	- `groundAt(grounds, x, z)`: the ground a point stands on.
	- `exitFacades(layout)`: each entrance's exit as a facade on its room (trim broken, cased and leafed like one).
	- `arrivalMarkers(truck)` / `bayShelves(bay)`: the crew's `yard.spawn.N` markers, and the bay's two wall shelves.
	- `problems(layout)`: what is wrong with a layout's grounds, truck and entrances (OfficeLayoutRules).

	@class OfficeGroundsUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLoadingBayUtils = require(script.Parent.OfficeLoadingBayUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local OUTSIDE = OfficeConstants.OUTSIDE

local OfficeGroundsUtils = {}

--[=[
	The yard, then the car park.
]=]
function OfficeGroundsUtils.grounds(): { OfficeTypes.Room }
	local yard, carpark = OUTSIDE.yard, OUTSIDE.carpark
	return {
		{ id = "yard", name = "Yard", minX = yard.minX, maxX = yard.maxX, minZ = yard.minZ, maxZ = yard.maxZ },
		{
			id = "carpark",
			name = "Car park",
			minX = carpark.minX,
			maxX = carpark.maxX,
			minZ = carpark.minZ,
			maxZ = carpark.maxZ,
		},
	}
end

--[=[
	The yard truck: the bed's footprint centred on TRUCK_CENTRE, turned TRUCK_YAW. The clock is at CLOCK_SIDE /
	CLOCK_BACK from the bed's centre, rotated by the yaw.
]=]
function OfficeGroundsUtils.truck(): OfficeTypes.Truck
	local bed = TruckVisual.BED_SIZE
	local centre = OUTSIDE.TRUCK_CENTRE
	local yaw = OUTSIDE.TRUCK_YAW
	local clockOffset = Vector3.new(OfficeConstants.CLOCK_SIDE, 0, -OfficeConstants.CLOCK_BACK)
	local clock = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(clockOffset)
	return {
		minX = centre.X - bed.X / 2,
		maxX = centre.X + bed.X / 2,
		minZ = centre.Y - bed.Z / 2,
		maxZ = centre.Y + bed.Z / 2,
		clockX = centre.X + clock.X,
		clockZ = centre.Y + clock.Z,
		yaw = yaw,
	}
end

--[=[
	The loading dock's entrance: the roller door in the yard, and an 8-wide solid doorway on the bay's minZ wall.
]=]
function OfficeGroundsUtils.dockEntrance(bay: OfficeTypes.Room): OfficeTypes.Entrance
	local outside = OUTSIDE.DOCK_OUTSIDE
	return {
		id = "dock",
		ground = "yard",
		outside = { x = outside.x, z = outside.z, yaw = outside.yaw },
		exit = {
			a = bay.id,
			b = "dock",
			x = (bay.minX + bay.maxX) / 2,
			z = bay.minZ,
			width = OUTSIDE.DOCK_EXIT_WIDTH,
			kind = "solid",
		},
	}
end

--[=[
	The lobby's entrance: the rotunda's doors by the car park, and a glass doorway at `z` on the reception's minX wall.
]=]
function OfficeGroundsUtils.lobbyEntrance(reception: OfficeTypes.Room, z: number, width: number): OfficeTypes.Entrance
	local outside = OUTSIDE.LOBBY_OUTSIDE
	return {
		id = "lobby",
		ground = "carpark",
		outside = { x = outside.x, z = outside.z, yaw = outside.yaw },
		exit = { a = reception.id, b = "lobby", x = reception.minX, z = z, width = width, kind = "glass" },
	}
end

--[=[
	Where a player arrives outside: OUTSIDE_STEP out from the outside door along its yaw, at floor height, facing it.
]=]
function OfficeGroundsUtils.outsideFrame(entrance: OfficeTypes.Entrance): CFrame
	local outside = entrance.outside
	local facing = CFrame.Angles(0, outside.yaw, 0)
	local at = Vector3.new(outside.x, 0, outside.z) + facing:VectorToWorldSpace(-Vector3.zAxis) * OUTSIDE.OUTSIDE_STEP
	return CFrame.new(at) * facing.Rotation
end

--[=[
	Where a player arrives inside: INSIDE_STEP into `room` from the exit's centre, square to its wall, facing in.
]=]
function OfficeGroundsUtils.insideFrame(entrance: OfficeTypes.Entrance, room: OfficeTypes.Room): CFrame
	local exit = entrance.exit
	local direction: Vector3
	if exit.z == room.minZ then
		direction = Vector3.zAxis
	elseif exit.z == room.maxZ then
		direction = -Vector3.zAxis
	elseif exit.x == room.minX then
		direction = Vector3.xAxis
	else
		direction = -Vector3.xAxis
	end
	local at = Vector3.new(exit.x, 0, exit.z) + direction * OUTSIDE.INSIDE_STEP
	return CFrame.lookAt(at, at + direction)
end

--[=[
	The ground the point (x, z) stands on, or nil.
]=]
function OfficeGroundsUtils.groundAt(grounds: { OfficeTypes.Room }, x: number, z: number): OfficeTypes.Room?
	for _, ground in grounds do
		if x >= ground.minX and x <= ground.maxX and z >= ground.minZ and z <= ground.maxZ then
			return ground
		end
	end
	return nil
end

--[=[
	The crew's spawn markers `yard.spawn.N`, one per arrival point on the yard truck's bed.
]=]
function OfficeGroundsUtils.arrivalMarkers(truck: OfficeTypes.Truck): { OfficeTypes.Marker }
	local markers: { OfficeTypes.Marker } = {}
	for index, point in OfficeLoadingBayUtils.arrivals(truck) do
		table.insert(
			markers,
			{ id = `yard.spawn.{index}`, room = "yard", kind = "spawn", x = point.X, z = point.Z, rotation = 0 }
		)
	end
	return markers
end

--[=[
	The bay's two shelves: one centred against each x wall, MARKER_MARGIN in, facing into the room
	by the kits' convention (OfficeKitRegistry: -pi/2 at the minX wall, +pi/2 at the maxX wall).
]=]
function OfficeGroundsUtils.bayShelves(bay: OfficeTypes.Room): { OfficeTypes.Marker }
	local z = (bay.minZ + bay.maxZ) / 2
	local margin = OfficeConstants.MARKER_MARGIN
	return {
		{ id = "bay.shelf.1", room = bay.id, kind = "shelf", x = bay.minX + margin, z = z, rotation = -math.pi / 2 },
		{ id = "bay.shelf.2", room = bay.id, kind = "shelf", x = bay.maxX - margin, z = z, rotation = math.pi / 2 },
	}
end

--[=[
	Each entrance's exit as a facade on its room (`exit.a`), so the shell breaks the trim at it and cases it, and its
	leaves are a facade's (OfficeDoorSystem.facadeLeaves): a solid exit takes the stairwell's one solid leaf, a glass
	exit the entrance's double glass door. Empty when the layout has no entrances.
]=]
function OfficeGroundsUtils.exitFacades(layout: OfficeTypes.Layout): { OfficeTypes.Facade }
	local facades: { OfficeTypes.Facade } = {}
	local entrances: { OfficeTypes.Entrance } = layout.entrances or {}
	for _, entrance in entrances do
		local exit = entrance.exit
		table.insert(facades, {
			room = exit.a,
			x = exit.x,
			z = exit.z,
			width = exit.width,
			kind = if exit.kind == "glass" then "entrance" else "stairwell",
		})
	end
	return facades
end

-- Whether the entrance's exit sits on one of `room`'s walls, its whole width within the wall's span.
local function exitOnWall(room: OfficeTypes.Room, exit: OfficeTypes.Door): boolean
	local half = exit.width / 2
	if exit.z == room.minZ or exit.z == room.maxZ then
		return exit.x - half >= room.minX and exit.x + half <= room.maxX
	elseif exit.x == room.minX or exit.x == room.maxX then
		return exit.z - half >= room.minZ and exit.z + half <= room.maxZ
	end
	return false
end

--[=[
	Every problem with a layout's grounds: the truck lies inside one ground, no ground overlaps a room, and each
	entrance's exit sits on its room's wall (within the wall's span) with its outside door on its ground (or within a
	stud of it). Empty when the layout has no grounds.
]=]
function OfficeGroundsUtils.problems(layout: OfficeTypes.Layout): { string }
	local errors: { string } = {}
	local grounds = layout.grounds
	if grounds == nil then
		return errors
	end
	local truck = layout.truck
	local stands = false
	for _, ground in grounds do
		local corners = { { truck.minX, truck.minZ }, { truck.maxX, truck.maxZ }, { truck.clockX, truck.clockZ } }
		local all = true
		for _, corner in corners do
			all = all and OfficeGroundsUtils.groundAt({ ground }, corner[1], corner[2]) ~= nil
		end
		stands = stands or all
	end
	if not stands then
		table.insert(errors, "the truck must stand on a ground")
	end
	for _, ground in grounds do
		for _, room in layout.rooms do
			if
				ground.minX < room.maxX
				and room.minX < ground.maxX
				and ground.minZ < room.maxZ
				and room.minZ < ground.maxZ
			then
				table.insert(errors, `ground "{ground.id}" overlaps room "{room.id}"`)
			end
		end
	end
	local entrances: { OfficeTypes.Entrance } = layout.entrances or {}
	for _, entrance in entrances do
		local room: OfficeTypes.Room? = nil
		for _, candidate in layout.rooms do
			if candidate.id == entrance.exit.a then
				room = candidate
			end
		end
		if room == nil or not exitOnWall(room, entrance.exit) then
			table.insert(errors, `entrance "{entrance.id}" exit is not on the wall of room "{entrance.exit.a}"`)
		end
		local ground: OfficeTypes.Room? = nil
		for _, candidate in grounds do
			if candidate.id == entrance.ground then
				ground = candidate
			end
		end
		local slack = 1
		if
			ground == nil
			or entrance.outside.x < ground.minX - slack
			or entrance.outside.x > ground.maxX + slack
			or entrance.outside.z < ground.minZ - slack
			or entrance.outside.z > ground.maxZ + slack
		then
			table.insert(errors, `entrance "{entrance.id}" outside door is not on ground "{entrance.ground}"`)
		end
	end
	return errors
end

return OfficeGroundsUtils
