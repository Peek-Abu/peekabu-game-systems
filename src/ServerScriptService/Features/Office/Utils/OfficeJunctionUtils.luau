--!strict
--[=[
	OfficeJunctionUtils: the corridor network's junctions once the rooms are placed. Dead-end corridors that serve
	no room are pruned in junction/segment pairs, and every live junction gets its markers: a patrol point, plus a
	closet on the far wall of each dead end left. Split out of OfficeLayoutGenerationUtils, which calls it. Pure.

	@class OfficeJunctionUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Features.Office
local OfficeConstants = require(Server.Data.OfficeConstants)
local OfficeCorridorUtils = require(script.Parent.OfficeCorridorUtils)
local OfficeTypes = require(Server.Data.OfficeTypes)

type Room = OfficeTypes.Room
type Edge = OfficeTypes.Edge
type Network = OfficeCorridorUtils.Network

-- A patrol point keeps this far (Harlow's agent radius) from a closet's front.
local PATROL_CLEARANCE = 2
local CLOSET_YAW: { [Edge]: number } = { minX = math.pi / 2, maxX = -math.pi / 2, minZ = 0, maxZ = math.pi }

local OfficeJunctionUtils = {}

local function center(room: Room): (number, number)
	return (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
end

-- The corridor rooms left once dead-end junction/segment pairs that serve no room are removed, repeatedly.
function OfficeJunctionUtils.pruneDeadEnds(network: Network, served: { [string]: boolean }): { [string]: boolean }
	local alive: { [string]: boolean } = {}
	for _, room in network.rooms do
		alive[room.id] = true
	end
	local changed = true
	while changed do
		changed = false
		for _, junction in network.rooms do
			local id = junction.id
			if
				network.junctions[id] == nil
				or not alive[id]
				or junction == network.dock
				or junction == network.lobby
				or served[id]
			then
				continue
			end
			local links: { string } = {}
			for _, door in network.doors do
				local other = if door.a == id then door.b elseif door.b == id then door.a else nil
				if other ~= nil and alive[other] then
					table.insert(links, other)
				end
			end
			if #links == 1 and not served[links[1]] then
				alive[id] = false
				alive[links[1]] = false
				changed = true
			end
		end
	end
	return alive
end

-- The edge of `junction` that corridor `segment` leaves through.
function OfficeJunctionUtils.junctionEdge(junction: Room, segment: Room): Edge
	if segment.minX == junction.maxX then
		return "maxX"
	elseif segment.maxX == junction.minX then
		return "minX"
	elseif segment.minZ == junction.maxZ then
		return "maxZ"
	end
	return "minZ"
end

-- Unit direction from an edge into the junction.
local INWARD: { [Edge]: Vector2 } = {
	minX = Vector2.new(1, 0),
	maxX = Vector2.new(-1, 0),
	minZ = Vector2.new(0, 1),
	maxZ = Vector2.new(0, -1),
}

-- A junction's markers. A dead end (`edge`, the wall its corridor `segment` leaves through) gets a closet on its far
-- wall and its patrol point between the closet and the corridor; where that leaves under PATROL_CLEARANCE of the
-- closet's face (a 6-wide junction), the point moves to the middle of the segment instead.
local function junctionMarkers(junction: Room, edge: Edge?, segment: Room?): { OfficeTypes.Marker }
	local cx, cz = center(junction)
	local patrol: OfficeTypes.Marker =
		{ id = `{junction.id}.patrol.1`, room = junction.id, kind = "patrol", x = cx, z = cz, rotation = 0 }
	if edge == nil or segment == nil then
		return { patrol }
	end
	local inward = INWARD[edge]
	local half = (junction.maxX - junction.minX) / 2
	local wall = OfficeConstants.WALL_THICKNESS / 2
	local closetDepth = OfficeConstants.CLOSET_SIZE.Z
	-- Distances along `inward` from the centre: the closet's centre, and its face toward the corridor.
	local closetAt = half - wall - closetDepth / 2
	local faceAt = half - wall - closetDepth
	local patrolAt = math.max(-half + OfficeConstants.MARKER_MARGIN, (faceAt - half) / 2)
	patrol.x, patrol.z = cx + inward.X * patrolAt, cz + inward.Y * patrolAt
	if faceAt - patrolAt < PATROL_CLEARANCE then
		local sx, sz = center(segment)
		patrol = { id = `{segment.id}.patrol.1`, room = segment.id, kind = "patrol", x = sx, z = sz, rotation = 0 }
	end
	return {
		patrol,
		{
			id = `{junction.id}.closet.1`,
			room = junction.id,
			kind = "closet",
			x = cx + inward.X * closetAt,
			z = cz + inward.Y * closetAt,
			rotation = CLOSET_YAW[edge],
		},
	}
end

--[=[
	The junctions' markers, in network order: a patrol point for each live junction (in the junction, or in its
	segment for a tight dead end), and a closet in each dead end left after pruning (`alive`, from pruneDeadEnds).
]=]
function OfficeJunctionUtils.markers(network: Network, alive: { [string]: boolean }): { OfficeTypes.Marker }
	local markers: { OfficeTypes.Marker } = {}
	-- Network doors always run junction (a) to segment (b).
	local segments: { [string]: Room } = {}
	for _, segment in network.segments do
		segments[segment.room.id] = segment.room
	end
	local legs: { [string]: { Room } } = {}
	for _, door in network.doors do
		if alive[door.a] and alive[door.b] then
			legs[door.a] = legs[door.a] or {}
			table.insert(legs[door.a], segments[door.b])
		end
	end
	for _, junction in network.rooms do
		if alive[junction.id] and network.junctions[junction.id] ~= nil then
			local own = legs[junction.id] or {}
			local edge: Edge? = nil
			if #own == 1 and junction ~= network.dock and junction ~= network.lobby then
				edge = OfficeJunctionUtils.junctionEdge(junction, own[1])
			end
			for _, marker in junctionMarkers(junction, edge, own[1]) do
				table.insert(markers, marker)
			end
		end
	end
	return markers
end

return OfficeJunctionUtils
