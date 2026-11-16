--!strict
--[=[
	SchoolLandmarkWallUtils: a landmark's wall pieces once its kit is stretched to fill its lattice block. `snapToWalls`
	moves the pieces standing along a kit wall out to the room's real wall; `freeDoorX` finds the stretch of a wall no
	piece covers, for the back door. Split out of SchoolLayoutGenerationUtils, which calls it (and still offers both
	under its own name). Pure.

	@class SchoolLandmarkWallUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Office = ServerScriptService.Features.Office
local OfficeConstants = require(Office.Data.OfficeConstants)
local OfficeLayoutUtils = require(Office.Utils.OfficeLayoutUtils)
local OfficeTypes = require(Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)

type Edge = OfficeTypes.Edge
type Marker = OfficeTypes.Marker

local SchoolLandmarkWallUtils = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

-- The marker's footprint half-extents (layout space), nil for a marker that is no furniture or prop.
local function halfExtents(marker: Marker): (number?, number?)
	local size = OfficeLayoutUtils.markerSize(marker)
	if size == nil then
		return nil, nil
	end
	local angle = marker.rotation or 0
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return (size.X * c + size.Z * s) / 2, (size.X * s + size.Z * c) / 2
end

--[=[
	Moves every marker that stands within LANDMARK_WALL_SNAP of a wall of `kit` (the kit's placed rectangle) out by
	the distance from that kit wall to the same wall of `room` (the block it fills), on each axis: a vending machine,
	a serving line or a scoreboard ends against the room's real wall instead of where the kit's wall would be. A marker
	with no footprint (a pile, an item, a patrol point) snaps by its point. `hold`: a wall whose floor pieces stay
	where the kit put them (its wall props still move: nothing hangs in the air), used when the back door needs that
	wall's length. Pure: mutates `markers` only.
]=]
function SchoolLandmarkWallUtils.snapToWalls(markers: { Marker }, kit: Rect, room: Rect, hold: Edge?)
	local reach = SchoolConstants.LANDMARK_WALL_SNAP
	for _, marker in markers do
		local hx, hz = halfExtents(marker)
		local halfX, halfZ = hx or 0, hz or 0
		local hung = marker.kind == "prop" and marker.art ~= nil and OfficeConstants.PROP_WALL_HEIGHT[marker.art] ~= nil
		local function moves(edge: Edge): boolean
			return hung or edge ~= hold
		end
		if marker.x - halfX - kit.minX <= reach then
			if moves("minX") then
				marker.x += room.minX - kit.minX
			end
		elseif kit.maxX - (marker.x + halfX) <= reach then
			if moves("maxX") then
				marker.x += room.maxX - kit.maxX
			end
		end
		if marker.z - halfZ - kit.minZ <= reach then
			if moves("minZ") then
				marker.z += room.minZ - kit.minZ
			end
		elseif kit.maxZ - (marker.z + halfZ) <= reach then
			if moves("maxZ") then
				marker.z += room.maxZ - kit.maxZ
			end
		end
	end
end

--[=[
	The x of a `width` door on the wall at `wallZ` of `room` that no marker standing within LANDMARK_WALL_SNAP of that
	wall covers (with a stud either side), at least `inset` from each corner, nearest `want`; nil when none is free.
]=]
function SchoolLandmarkWallUtils.freeDoorX(
	markers: { Marker },
	room: Rect,
	wallZ: number,
	width: number,
	inset: number,
	want: number
): number?
	local blocked: { { number } } = {}
	for _, marker in markers do
		local hx, hz = halfExtents(marker)
		if
			hx ~= nil
			and hz ~= nil
			and math.min(math.abs(marker.z - hz - wallZ), math.abs(marker.z + hz - wallZ))
				<= SchoolConstants.LANDMARK_WALL_SNAP
		then
			table.insert(blocked, { marker.x - hx - 1, marker.x + hx + 1 })
		end
	end
	local best: number? = nil
	local x = room.minX + inset
	while x <= room.maxX - inset do
		local free = true
		for _, span in blocked do
			if x - width / 2 < span[2] and span[1] < x + width / 2 then
				free = false
				break
			end
		end
		if free and (best == nil or math.abs(x - want) < math.abs(best - want)) then
			best = x
		end
		x += 1
	end
	return best
end

return SchoolLandmarkWallUtils
