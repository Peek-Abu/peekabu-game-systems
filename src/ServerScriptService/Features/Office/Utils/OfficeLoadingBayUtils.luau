--!strict
--[=[
	OfficeLoadingBayUtils: the loading bay's geometry (the start room), in layout space. Harlow may walk the bay; only
	the truck's box is safe (`truckBox`).

	- `bay(side, target)`: the BAY_WIDTH x BAY_DEPTH room on one exterior side of `target` (1 -X, 2 +X, 3 -Z,
	  4 +Z) and the 10-stud door between them, centred on their shared wall.
	- `arrivals(truck)` / `arrivalFrame(truck, index)`: where the crew stands on the bed at the start of a shift,
	  facing the open back and the ramp.
	- `truckBox(truck)`: the inside of the truck's box (the bed's footprint, from its top to the truck's top): the one
	  place Harlow never sees, hears, catches or walks into.
	- `patrolPoint(bay, side)`: the point his patrol route visits in the bay, on its open side, clear of the truck.

	@class OfficeLoadingBayUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local DOOR_WIDTH = 10

local OfficeLoadingBayUtils = {}

--[=[
	The loading bay on side `side` of `target` (1 -X, 2 +X, 3 -Z, 4 +Z) and its door into `target`.
]=]
function OfficeLoadingBayUtils.bay(side: number, target: OfficeTypes.Room): (OfficeTypes.Room, OfficeTypes.Door)
	local width, depth = OfficeConstants.BAY_WIDTH, OfficeConstants.BAY_DEPTH
	local cx, cz = (target.minX + target.maxX) / 2, (target.minZ + target.maxZ) / 2
	local minX: number, minZ: number, doorX: number, doorZ: number
	if side == 1 then
		minX, minZ, doorX, doorZ = target.minX - width, cz - depth / 2, target.minX, cz
	elseif side == 2 then
		minX, minZ, doorX, doorZ = target.maxX, cz - depth / 2, target.maxX, cz
	elseif side == 3 then
		minX, minZ, doorX, doorZ = cx - width / 2, target.minZ - depth, cx, target.minZ
	else
		minX, minZ, doorX, doorZ = cx - width / 2, target.maxZ, cx, target.maxZ
	end
	local bay: OfficeTypes.Room = {
		id = "bay",
		name = "Loading bay",
		minX = minX,
		maxX = minX + width,
		minZ = minZ,
		maxZ = minZ + depth,
	}
	return bay, { a = "bay", b = target.id, x = doorX, z = doorZ, width = DOOR_WIDTH }
end

--[=[
	The crew's arrival points on the bed (layout x, 0, z), spread so a full crew never overlaps.
]=]
function OfficeLoadingBayUtils.arrivals(truck: OfficeTypes.Truck): { Vector3 }
	local cx, cz = (truck.minX + truck.maxX) / 2, (truck.minZ + truck.maxZ) / 2
	local turn = CFrame.Angles(0, truck.yaw or 0, 0)
	local points: { Vector3 } = {}
	for _, offset in OfficeConstants.ARRIVAL_OFFSETS do
		local turned = turn:VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Y))
		table.insert(points, Vector3.new(cx + turned.X, 0, cz + turned.Z))
	end
	return points
end

--[=[
	Where the `index`-th crew member appears (layout space, wrapping over the arrival points): SPAWN_HEIGHT over
	the bed's top, facing out of the open back and down the ramp (-Z at yaw 0, +Z at yaw pi).
]=]
function OfficeLoadingBayUtils.arrivalFrame(truck: OfficeTypes.Truck, index: number): CFrame
	local points = OfficeLoadingBayUtils.arrivals(truck)
	local point = points[(math.max(index, 1) - 1) % #points + 1]
	local at = Vector3.new(point.X, OfficeConstants.BED_HEIGHT + OfficeConstants.SPAWN_HEIGHT, point.Z)
	return CFrame.lookAt(at, at + CFrame.Angles(0, truck.yaw or 0, 0):VectorToWorldSpace(-Vector3.zAxis))
end

--[=[
	The inside of the truck's box (layout space, min and max corners): the bed's footprint, from the bed's top to the
	truck's top. The ramp and the bay floor around it are outside.
]=]
function OfficeLoadingBayUtils.truckBox(truck: OfficeTypes.Truck): (Vector3, Vector3)
	local deck = OfficeConstants.BED_HEIGHT
	return Vector3.new(truck.minX, deck, truck.minZ), Vector3.new(truck.maxX, deck + TruckVisual.TOP, truck.maxZ)
end

--[=[
	Where Harlow's patrol route visits the bay (layout x as X, z as Y): its centre line across, PATROL_SIDE_INSET from
	the side wall away from the door's (the open side, by the door into the office).
]=]
function OfficeLoadingBayUtils.patrolPoint(bay: OfficeTypes.Room, side: number): Vector2
	local x = if side == 2
		then bay.minX + OfficeConstants.PATROL_SIDE_INSET
		else bay.maxX - OfficeConstants.PATROL_SIDE_INSET
	return Vector2.new(x, (bay.minZ + bay.maxZ) / 2)
end

return OfficeLoadingBayUtils
