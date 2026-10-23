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

	@class OfficeGroundsUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
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

return OfficeGroundsUtils
