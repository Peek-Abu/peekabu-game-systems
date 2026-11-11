--!strict
--[=[
	SchoolHallUtils: what the School's halls carry beyond the Office's hall dressing, and Harlow's walk over them. Pure.

	- `patrolPoint(junction)`: a junction's patrol point, at its centre.
	- `lockers(layout, room)`: locker banks (LOCKER_BANK `locker` markers side by side, searchable) along both long
	  walls of a hall, one bank every LOCKER_SPACING, the far wall's staggered by half of it, each standing
	  SHELL.trimClearance off the plaster, facing into the hall, and LOCKER_CLEAR clear of a doorway's casing on its
	  wall. Call once the hall's doors are in `layout`, before the hall dressing (which keeps clear of them).
	- `route(layout, frontId)`: Harlow's loop, as OfficeLayoutGenerationUtils builds it: a walk from the front junction
	  over the doors (never into the start room) that appends each room's patrol marker on entry and the parent's
	  again on backtrack, with the start room's point visited once after the first stop.

	@class SchoolHallUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Marker = OfficeTypes.Marker
type Edge = OfficeTypes.Edge

-- Yaw that turns a hall piece's front (local -Z) into the hall from each wall (OfficeHallDressingUtils).
local FACE_YAW: { [Edge]: number } = { minX = -math.pi / 2, maxX = math.pi / 2, minZ = math.pi, maxZ = 0 }
local LONG_WALLS_X: { Edge } = { "minZ", "maxZ" }
local LONG_WALLS_Z: { Edge } = { "minX", "maxX" }

local SchoolHallUtils = {}

--[=[
	The patrol point at the centre of `junction`.
]=]
function SchoolHallUtils.patrolPoint(junction: Room): Marker
	return {
		id = `{junction.id}.patrol.1`,
		room = junction.id,
		kind = "patrol",
		x = (junction.minX + junction.maxX) / 2,
		z = (junction.minZ + junction.maxZ) / 2,
		rotation = 0,
	}
end

--[=[
	The locker banks along both long walls of hall `room`.
]=]
function SchoolHallUtils.lockers(layout: Layout, room: Room): { Marker }
	local horizontal = room.maxX - room.minX >= room.maxZ - room.minZ
	local from = if horizontal then room.minX else room.minZ
	local to = if horizontal then room.maxX else room.maxZ
	local size = OfficeConstants.LOCKER_SIZE
	local bankLength = SchoolConstants.LOCKER_BANK * size.X
	local inset = OfficeConstants.WALL_THICKNESS / 2 + OfficeConstants.SHELL.trimClearance + size.Z / 2
	local clear = SchoolConstants.LOCKER_CLEAR + OfficeConstants.SHELL.casing
	local markers: { Marker } = {}
	local walls: { Edge } = if horizontal then LONG_WALLS_X else LONG_WALLS_Z
	for wall, edge: Edge in walls do
		local openings = OfficeLayoutUtils.openingsOn(layout, room, edge)
		local line = if edge == "minZ"
			then room.minZ + inset
			elseif edge == "maxZ" then room.maxZ - inset
			elseif edge == "minX" then room.minX + inset
			else room.maxX - inset
		local at = from + SchoolConstants.LOCKER_START + (wall - 1) * SchoolConstants.LOCKER_SPACING / 2
		while at + bankLength <= to - SchoolConstants.LOCKER_START do
			local blocked = false
			for _, span in openings do
				if at < span[2] + clear and span[1] - clear < at + bankLength then
					blocked = true
				end
			end
			if not blocked then
				for index = 1, SchoolConstants.LOCKER_BANK do
					local along = at + (index - 0.5) * size.X
					table.insert(markers, {
						id = `{room.id}.locker.{#markers + 1}`,
						room = room.id,
						kind = "locker",
						x = if horizontal then along else line,
						z = if horizontal then line else along,
						rotation = FACE_YAW[edge],
					})
				end
			end
			at += SchoolConstants.LOCKER_SPACING
		end
	end
	return markers
end

--[=[
	Harlow's patrol loop over `layout`'s doors from the junction `frontId`.
]=]
function SchoolHallUtils.route(layout: Layout, frontId: string): { string }
	local patrols: { [string]: string } = {}
	for _, marker in layout.markers do
		if marker.kind == "patrol" and patrols[marker.room] == nil then
			patrols[marker.room] = marker.id
		end
	end
	local adjacent: { [string]: { string } } = {}
	for _, door in layout.doors do
		if door.a ~= layout.startRoom and door.b ~= layout.startRoom then
			adjacent[door.a] = adjacent[door.a] or {}
			adjacent[door.b] = adjacent[door.b] or {}
			table.insert(adjacent[door.a], door.b)
			table.insert(adjacent[door.b], door.a)
		end
	end
	local route: { string } = {}
	local seen: { [string]: boolean } = {}
	local function walk(id: string)
		seen[id] = true
		local own = patrols[id]
		local function visit()
			if own ~= nil and route[#route] ~= own then
				table.insert(route, own)
			end
		end
		visit()
		local others: { string } = adjacent[id] or {}
		for _, other in others do
			if not seen[other] then
				walk(other)
				visit()
			end
		end
	end
	walk(frontId)
	local entry, start = patrols[frontId], patrols[layout.startRoom]
	local at = if entry ~= nil then table.find(route, entry) else nil
	if entry ~= nil and start ~= nil and at ~= nil then
		table.insert(route, at + 1, start)
		table.insert(route, at + 2, entry)
	end
	return route
end

return SchoolHallUtils
