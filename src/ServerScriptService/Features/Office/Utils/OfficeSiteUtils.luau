--!strict
--[=[
	OfficeSiteUtils: where things stand in the world for the map a shift plays on. Each answer comes from the authored
	site when one stands in (`site`, OfficeTypes.Site: the Training map), else from the generated layout at
	OfficeConstants.ORIGIN: a crew member's arrival frame, Harlow's route and rest point, the truck's box (the safe
	zone), the loading bay, the room or ground a point stands in, the outside grounds' boxes and an entrance's
	outside and inside frames. `floorAt` is the floor point under a marker. Split out of OfficeServiceServer, whose
	accessors answer through it with the layout standing now. Pure.

	@class OfficeSiteUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLoadingBayUtils = require(OfficeServer.Utils.OfficeLoadingBayUtils)
local OfficeGroundsUtils = require(OfficeServer.Utils.OfficeGroundsUtils)

type Marker = OfficeTypes.Marker
type Layout = OfficeTypes.Layout
type Site = OfficeTypes.Site

local OfficeSiteUtils = {}

-- The floor point under a marker, in the world.
local function floorAt(marker: Marker): CFrame
	return OfficeConstants.ORIGIN * CFrame.new(marker.x, 0, marker.z)
end

OfficeSiteUtils.floorAt = floorAt

--[=[
	Where the `index`-th crew member appears: the site's spawn, else in the truck's bed, facing out of its open back
	and down the ramp (OfficeLoadingBayUtils.arrivalFrame).
]=]
function OfficeSiteUtils.spawnCFrame(site: Site?, layout: Layout, index: number): CFrame
	local authored = site
	if authored ~= nil then
		return authored.spawnCFrame(index)
	end
	return OfficeConstants.ORIGIN * OfficeLoadingBayUtils.arrivalFrame(layout.truck, index)
end

-- Harlow's patrol points in the world, in walking order (a loop): the site's, else a copy of `routePoints`.
function OfficeSiteUtils.route(site: Site?, routePoints: { Vector3 }): { Vector3 }
	local authored = site
	if authored ~= nil then
		return authored.route()
	end
	return table.clone(routePoints)
end

-- Where Harlow takes his break: the site's rest point, else the floor at `restMarker` (an error when it is nil).
function OfficeSiteUtils.restPoint(site: Site?, restMarker: Marker?): Vector3
	local authored = site
	if authored ~= nil then
		return authored.restPoint()
	end
	if restMarker == nil then
		error("OfficeServiceServer:restPoint: the layout has no rest marker")
	end
	return floorAt(restMarker).Position
end

-- The inside of the truck's box in the world, min and max corners.
function OfficeSiteUtils.safeZone(site: Site?, layout: Layout): (Vector3, Vector3)
	local authored = site
	if authored ~= nil then
		return authored.safeZone()
	end
	local min, max = OfficeLoadingBayUtils.truckBox(layout.truck)
	local low = OfficeConstants.ORIGIN:PointToWorldSpace(min)
	local high = OfficeConstants.ORIGIN:PointToWorldSpace(max)
	return low:Min(high), low:Max(high)
end

-- The loading bay in the world: its min and max corners, floor to wall top (an error with no start room).
function OfficeSiteUtils.loadingBay(site: Site?, layout: Layout): (Vector3, Vector3)
	local authored = site
	if authored ~= nil then
		return authored.loadingBay()
	end
	local start = OfficeLayoutUtils.room(layout, layout.startRoom)
	if start == nil then
		error("OfficeServiceServer:loadingBay: the layout has no start room")
	end
	local min, max = OfficeLayoutUtils.bounds(start, OfficeConstants.WALL_HEIGHT)
	return OfficeConstants.ORIGIN:PointToWorldSpace(min), OfficeConstants.ORIGIN:PointToWorldSpace(max)
end

--[=[
	The room a world position stands in: its name, its depth (`depths`) and its index in the layout. On a ground
	outside: its name, depth 0 and no index. Nothing elsewhere.
]=]
function OfficeSiteUtils.whereIs(
	site: Site?,
	layout: Layout,
	depths: { [string]: number },
	position: Vector3
): (string?, number?, number?)
	local authored = site
	if authored ~= nil then
		return authored.whereIs(position)
	end
	local localPoint = OfficeConstants.ORIGIN:PointToObjectSpace(position)
	local room, index = OfficeLayoutUtils.roomAt(layout, localPoint.X, localPoint.Z)
	if room == nil then
		local ground = OfficeGroundsUtils.groundAt(layout.grounds or {}, localPoint.X, localPoint.Z)
		if ground ~= nil then
			return ground.name, 0, nil
		end
		return nil, nil, nil
	end
	return room.name, depths[room.id], index
end

-- The outside's grounds in the world, floor to OUTSIDE.VOLUME_HEIGHT; empty on a site or with no grounds.
function OfficeSiteUtils.outdoors(site: Site?, layout: Layout): { { min: Vector3, max: Vector3 } }
	local boxes: { { min: Vector3, max: Vector3 } } = {}
	if site ~= nil then
		return boxes
	end
	local grounds: { OfficeTypes.Room } = layout.grounds or {}
	for _, ground in grounds do
		local low = OfficeConstants.ORIGIN:PointToWorldSpace(Vector3.new(ground.minX, 0, ground.minZ))
		local high = OfficeConstants.ORIGIN:PointToWorldSpace(
			Vector3.new(ground.maxX, OfficeConstants.OUTSIDE.VOLUME_HEIGHT, ground.maxZ)
		)
		table.insert(boxes, { min = low:Min(high), max = low:Max(high) })
	end
	return boxes
end

-- Entrance `id`'s outside and inside frames in the world; nil, nil on a site or with no such entrance.
function OfficeSiteUtils.entrance(site: Site?, layout: Layout, id: OfficeTypes.EntranceId): (CFrame?, CFrame?)
	if site ~= nil then
		return nil, nil
	end
	local entrances: { OfficeTypes.Entrance } = layout.entrances or {}
	for _, entrance in entrances do
		local room = OfficeLayoutUtils.room(layout, entrance.exit.a)
		if entrance.id == id and room ~= nil then
			return OfficeConstants.ORIGIN * OfficeGroundsUtils.outsideFrame(entrance),
				OfficeConstants.ORIGIN * OfficeGroundsUtils.insideFrame(entrance, room)
		end
	end
	return nil, nil
end

return OfficeSiteUtils
