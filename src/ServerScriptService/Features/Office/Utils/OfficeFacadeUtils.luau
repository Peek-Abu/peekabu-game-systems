--!strict
--[=[
	OfficeFacadeUtils: where a generated office's stairwell or elevator may stand. Each is a 6-wide facade on a junction
	wall that has no door and no other facade, whose junction holds no closet (a dead end's closet stands against its
	far wall), and whose 6 x 4 probe outside the wall touches no room. OfficeLayoutGenerationUtils draws one of the
	candidates from its seed. Pure.

	@class OfficeFacadeUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Room = OfficeTypes.Room
type Edge = OfficeTypes.Edge
type Facade = OfficeTypes.Facade

-- A junction wall: its midpoint and the direction that points out of the junction.
type Wall = { edge: Edge, x: number, z: number, dx: number, dz: number }

local FACADE_WIDTH = 6
local FACADE_DEPTH = 4

local OfficeFacadeUtils = {}

local function overlaps(a: Room, b: Room): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- The probe outside `wall`: FACADE_WIDTH along it, FACADE_DEPTH out of the junction.
local function probe(wall: Wall): Room
	local alongX = if wall.dx == 0 then FACADE_WIDTH / 2 else 0
	local alongZ = if wall.dz == 0 then FACADE_WIDTH / 2 else 0
	return {
		id = "probe",
		name = "probe",
		minX = math.min(wall.x, wall.x + wall.dx * FACADE_DEPTH) - alongX,
		maxX = math.max(wall.x, wall.x + wall.dx * FACADE_DEPTH) + alongX,
		minZ = math.min(wall.z, wall.z + wall.dz * FACADE_DEPTH) - alongZ,
		maxZ = math.max(wall.z, wall.z + wall.dz * FACADE_DEPTH) + alongZ,
	}
end

--[=[
	Every place a facade of `kind` may stand in `layout`, on the walls of `junctions` (the live corridor junctions, in
	the generator's order) given the facades placed so far: in junction order, then walls minX, maxX, minZ, maxZ, so a
	seeded draw from the list replays.
]=]
function OfficeFacadeUtils.candidates(
	layout: OfficeTypes.Layout,
	junctions: { Room },
	facades: { Facade },
	kind: "stairwell" | "elevator"
): { Facade }
	local candidates: { Facade } = {}
	local closeted: { [string]: boolean } = {}
	for _, marker in layout.markers do
		if marker.kind == "closet" then
			closeted[marker.room] = true
		end
	end
	for _, junction in junctions do
		if closeted[junction.id] then
			continue
		end
		local used: { [string]: boolean } = {}
		for _, door in layout.doors do
			local edge = if door.a == junction.id or door.b == junction.id
				then OfficeLayoutUtils.doorEdge(junction, door)
				else nil
			if edge ~= nil then
				used[edge] = true
			end
		end
		for _, facade in facades do
			local edge = if facade.room == junction.id then OfficeLayoutUtils.facadeEdge(junction, facade) else nil
			if edge ~= nil then
				used[edge] = true
			end
		end
		local cx, cz = (junction.minX + junction.maxX) / 2, (junction.minZ + junction.maxZ) / 2
		local walls: { Wall } = {
			{ edge = "minX", x = junction.minX, z = cz, dx = -1, dz = 0 },
			{ edge = "maxX", x = junction.maxX, z = cz, dx = 1, dz = 0 },
			{ edge = "minZ", x = cx, z = junction.minZ, dx = 0, dz = -1 },
			{ edge = "maxZ", x = cx, z = junction.maxZ, dx = 0, dz = 1 },
		}
		for _, wall in walls do
			if used[wall.edge] then
				continue
			end
			local outside = probe(wall)
			local clear = true
			for _, room in layout.rooms do
				if overlaps(outside, room) then
					clear = false
					break
				end
			end
			if clear then
				table.insert(
					candidates,
					{ room = junction.id, x = wall.x, z = wall.z, width = FACADE_WIDTH, kind = kind }
				)
			end
		end
	end
	return candidates
end

return OfficeFacadeUtils
