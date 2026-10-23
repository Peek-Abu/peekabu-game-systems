--!strict
--[=[
	OfficeLayoutGenerationUtils: a fresh workplace from a seed. The corridor network (OfficeCorridorUtils) is the
	skeleton; the loading bay hangs off the dock junction, the reception off the lobby junction, and hand-authored
	kit rooms (OfficeKitRegistry, placed by OfficeKitUtils) line the corridor segments on both sides; a kit's glass
	pane is clipped to the corridor it faces, so no window looks out of the building. Dead-end
	corridors that serve no room are pruned (a closet stands in each dead end left), a stairwell facade goes on a
	free junction wall, and Mr. Harlow's patrol route and rest point are derived from the result.

	`generate` builds up to GENERATE_ATTEMPTS layouts (seed * 31 + attempt) and returns the first that is valid,
	has the markers the spawn roll needs, the hiding places and the walking distance the map promises, and the room
	mix (one server room and one reception, at least one breakout, KIT_ROOMS rooms in all). Pure.

	@class OfficeLayoutGenerationUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Features.Office
local OfficeConstants = require(Server.Data.OfficeConstants)
local OfficeCorridorUtils = require(script.Parent.OfficeCorridorUtils)
local OfficeKitRegistry = require(Server.Data.OfficeKitRegistry)
local OfficeKitUtils = require(script.Parent.OfficeKitUtils)
local OfficeLayoutRules = require(Server.Rules.OfficeLayoutRules)
local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLoadingBayUtils = require(script.Parent.OfficeLoadingBayUtils)
local OfficeTypes = require(Server.Data.OfficeTypes)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Kit = OfficeTypes.Kit
type Edge = OfficeTypes.Edge
type RoomType = OfficeTypes.RoomType
type Network = OfficeCorridorUtils.Network
type Run = OfficeCorridorUtils.Run

-- The kit types that are drawn from KIT_WEIGHTS, in a fixed order so draws replay from the seed.
local DRAWN: { RoomType } = { "pods", "conference", "storage", "breakout" }
-- The depth assumed for a slot before its kit is chosen, to tell whether its back wall reaches the perimeter: the
-- mean depth of the drawn kits (OfficeKitRegistry), so it follows the catalogue.
local SLOT_DEPTH = 0
do
	local total, count = 0, 0
	for _, roomType: RoomType in DRAWN do
		for _, kit in OfficeKitRegistry.ofType(roomType) do
			total += kit.depth
			count += 1
		end
	end
	SLOT_DEPTH = if count > 0 then total / count else 0
end
local STAIR_WIDTH = 6
local STAIR_DEPTH = 4
local ENTRANCE_WIDTH = 12
-- A patrol point keeps this far (Harlow's agent radius) from a closet's front.
local PATROL_CLEARANCE = 2
-- A glass pane clipped to its corridor is dropped when less than this is left.
local MIN_PANE = 2
local CLOSET_YAW: { [Edge]: number } = { minX = math.pi / 2, maxX = -math.pi / 2, minZ = 0, maxZ = math.pi }

-- The mutable state of one attempt.
type Build = {
	rng: Random,
	layout: Layout,
	-- Every room placed so far, pruned corridors included: they stay blockers.
	solid: { Room },
	box: Room,
	counts: { [string]: number },
	facades: { OfficeTypes.Facade },
	panes: { OfficeTypes.Segment },
	-- Kit rooms placed along the corridors (the reception is not counted).
	placed: number,
	needServer: boolean,
	needBreakout: boolean,
	pending: RoomType?,
}

local OfficeLayoutGenerationUtils = {}

local function overlaps(a: Room, b: Room): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

local function shuffle<T>(rng: Random, list: { T })
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

local function center(room: Room): (number, number)
	return (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
end

-- The draw weight of a room type; the server room and reception are never drawn.
local function weightOf(roomType: RoomType): number
	local weights = OfficeConstants.KIT_WEIGHTS
	if roomType == "pods" then
		return weights.pods
	elseif roomType == "conference" then
		return weights.conference
	elseif roomType == "storage" then
		return weights.storage
	elseif roomType == "breakout" then
		return weights.breakout
	end
	return 0
end

-- A weighted pick of one of `pool`; conference is boosted at the perimeter. Removes it from `pool`.
local function draw(rng: Random, pool: { RoomType }, boosted: boolean): RoomType
	local weights: { number } = {}
	local total = 0
	for index, roomType: RoomType in pool do
		local weight = weightOf(roomType)
		if boosted and roomType == "conference" then
			weight *= OfficeConstants.PERIMETER_CONFERENCE_BOOST
		end
		weights[index] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, roomType: RoomType in pool do
		roll -= weights[index]
		if roll < 0 or index == #pool then
			table.remove(pool, index)
			return roomType
		end
	end
	error("draw from an empty pool")
end

-- Whether a room hung on `segment`'s side (+1 toward +x/+z, -1 toward -x/-z) would reach the perimeter.
local function atPerimeter(build: Build, segment: Run, side: number): boolean
	local room, box = segment.room, build.box
	local margin = OfficeConstants.ROOM_MARGIN
	if segment.horizontal then
		if side > 0 then
			return box.maxZ - (room.maxZ + SLOT_DEPTH) <= margin
		end
		return room.minZ - SLOT_DEPTH - box.minZ <= margin
	end
	if side > 0 then
		return box.maxX - (room.maxX + SLOT_DEPTH) <= margin
	end
	return room.minX - SLOT_DEPTH - box.minX <= margin
end

local function kitsLargestFirst(roomType: RoomType): { Kit }
	local kits = OfficeKitRegistry.ofType(roomType)
	table.sort(kits, function(a, b)
		return a.width * a.depth > b.width * b.depth
	end)
	return kits
end

local function addMarkers(build: Build, markers: { OfficeTypes.Marker })
	for _, marker in markers do
		table.insert(build.layout.markers, marker)
	end
end

local function commit(build: Build, room: Room, door: OfficeTypes.Door, markers: { OfficeTypes.Marker })
	table.insert(build.layout.rooms, room)
	table.insert(build.solid, room)
	table.insert(build.layout.doors, door)
	addMarkers(build, markers)
	local roomType = room.roomType
	if roomType == "server" then
		build.needServer = false
	elseif roomType == "breakout" then
		build.needBreakout = false
	end
end

local function nextId(build: Build, roomType: RoomType): string
	return `{roomType}{(build.counts[roomType] or 0) + 1}`
end

-- The front-left corner and facing of a kit `width` wide whose slot starts at `cursor` on `segment`'s `side`.
local function slotFront(segment: Run, side: number, cursor: number, width: number): (number, number, Edge)
	local room = segment.room
	if segment.horizontal then
		if side > 0 then
			return cursor, room.maxZ, "minZ"
		end
		return cursor + width, room.minZ, "maxZ"
	elseif side > 0 then
		return room.maxX, cursor + width, "minX"
	end
	return room.minX, cursor, "maxX"
end

-- `pane` cut to the part that faces `segment` (its span along the corridor), so glass never looks past a
-- corridor's end into the void; nil when less than MIN_PANE is left.
local function clipPane(pane: OfficeTypes.Segment, segment: Run): OfficeTypes.Segment?
	if segment.horizontal then
		local x1, x2 = math.max(pane.x1, segment.from), math.min(pane.x2, segment.to)
		if x2 - x1 < MIN_PANE then
			return nil
		end
		return { x1 = x1, z1 = pane.z1, x2 = x2, z2 = pane.z2 }
	end
	local z1, z2 = math.max(pane.z1, segment.from), math.min(pane.z2, segment.to)
	if z2 - z1 < MIN_PANE then
		return nil
	end
	return { x1 = pane.x1, z1 = z1, x2 = pane.x2, z2 = z2 }
end

-- Tries every kit of `roomType` (largest first, randomly mirrored) in the slot starting at `cursor` along
-- `segment`'s `side`; places the first that fits. Returns the placed kit's width, or nil. The kit's glass pane is
-- clipped to the corridor it faces (the front wall may run on past the corridor's end).
local function tryPlace(build: Build, segment: Run, side: number, cursor: number, roomType: RoomType): number?
	local room = segment.room
	for _, kit in kitsLargestFirst(roomType) do
		local mirrored = build.rng:NextInteger(0, 1) == 1
		local frontX: number, frontZ: number, facing: Edge = slotFront(segment, side, cursor, kit.width)
		local id = nextId(build, roomType)
		local placement = OfficeKitUtils.place(kit, id, frontX, frontZ, facing, mirrored)
		-- The whole doorway lies along the segment, and the room clears every room and the margin box.
		local along = if segment.horizontal then placement.doorX else placement.doorZ
		local fits = along - placement.doorWidth / 2 >= segment.from and along + placement.doorWidth / 2 <= segment.to
		local kitRoom = placement.room
		local margin = OfficeConstants.ROOM_MARGIN
		fits = fits
			and kitRoom.minX >= build.box.minX - margin
			and kitRoom.maxX <= build.box.maxX + margin
			and kitRoom.minZ >= build.box.minZ - margin
			and kitRoom.maxZ <= build.box.maxZ + margin
		if fits then
			for _, other in build.solid do
				if overlaps(kitRoom, other) then
					fits = false
					break
				end
			end
		end
		if fits then
			build.counts[roomType] = (build.counts[roomType] or 0) + 1
			build.placed += 1
			commit(build, kitRoom, {
				a = id,
				b = room.id,
				x = placement.doorX,
				z = placement.doorZ,
				width = placement.doorWidth,
				kind = placement.doorKind,
			}, placement.markers)
			local pane = if placement.pane ~= nil then clipPane(placement.pane, segment) else nil
			if pane ~= nil then
				table.insert(build.panes, pane)
			end
			return kit.width
		end
	end
	return nil
end

-- One slot: the deck's next type first, then the other drawn types (never a second server room or reception).
local function fillSlot(build: Build, segment: Run, side: number, cursor: number): number?
	local rng = build.rng
	local boosted = atPerimeter(build, segment, side)
	local pool: { RoomType } = table.clone(DRAWN)
	local first: RoomType
	local pending: RoomType? = build.pending
	if pending ~= nil then
		first = pending
	elseif build.needServer then
		first = "server"
	elseif build.needBreakout then
		first = "breakout"
	else
		first = draw(rng, pool, boosted)
	end
	build.pending = first
	local order: { RoomType } = { first }
	local index = table.find(pool, first)
	if index ~= nil then
		table.remove(pool, index)
	end
	while #pool > 0 do
		table.insert(order, draw(rng, pool, boosted))
	end
	for _, roomType: RoomType in order do
		local width = tryPlace(build, segment, side, cursor, roomType)
		if width ~= nil then
			if roomType == first then
				build.pending = nil
			end
			return width
		end
	end
	return nil
end

-- Lines the segments, in shuffled order and both sides in random order, until the deck is spent.
local function lineSegments(build: Build, network: Network, wanted: number)
	local order: { Run } = table.clone(network.segments)
	shuffle(build.rng, order)
	for _, segment in order do
		local sides = { 1, -1 }
		shuffle(build.rng, sides)
		for _, side in sides do
			local cursor = segment.from
			while cursor < segment.to and build.placed < wanted do
				local width = fillSlot(build, segment, side, cursor)
				cursor += width or OfficeConstants.ROOM_STEP
			end
		end
	end
end

-- The corridor rooms left once dead-end junction/segment pairs that serve no room are removed, repeatedly.
local function pruneDeadEnds(network: Network, served: { [string]: boolean }): { [string]: boolean }
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
local function junctionEdge(junction: Room, segment: Room): Edge
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

-- Marks the junctions: a patrol point for each (in the junction, or in its segment for a tight dead end), and a closet in each dead end left after pruning.
local function markJunctions(build: Build, network: Network, alive: { [string]: boolean })
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
				edge = junctionEdge(junction, own[1])
			end
			addMarkers(build, junctionMarkers(junction, edge, own[1]))
		end
	end
end

-- A junction wall: its midpoint and the direction that points out of the junction.
type Wall = { edge: Edge, x: number, z: number, dx: number, dz: number }

-- The stairwell: a 6-wide facade on a door-free junction wall whose 6 x 4 probe outside touches no room.
local function addStairwell(build: Build, network: Network, alive: { [string]: boolean }): boolean
	local candidates: { OfficeTypes.Facade } = {}
	-- A dead end's closet stands against its far wall: no stairwell there.
	local closeted: { [string]: boolean } = {}
	for _, marker in build.layout.markers do
		if marker.kind == "closet" then
			closeted[marker.room] = true
		end
	end
	for _, junction in network.rooms do
		if not alive[junction.id] or network.junctions[junction.id] == nil or closeted[junction.id] then
			continue
		end
		local used: { [string]: boolean } = {}
		for _, door in build.layout.doors do
			if door.a == junction.id or door.b == junction.id then
				local edge = OfficeLayoutUtils.doorEdge(junction, door)
				if edge ~= nil then
					used[edge] = true
				end
			end
		end
		-- A fixed order, so the pick replays from the seed.
		local cx, cz = center(junction)
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
			local probe: Room = {
				id = "probe",
				name = "probe",
				minX = math.min(wall.x, wall.x + wall.dx * STAIR_DEPTH) - (if wall.dx == 0 then STAIR_WIDTH / 2 else 0),
				maxX = math.max(wall.x, wall.x + wall.dx * STAIR_DEPTH) + (if wall.dx == 0 then STAIR_WIDTH / 2 else 0),
				minZ = math.min(wall.z, wall.z + wall.dz * STAIR_DEPTH) - (if wall.dz == 0 then STAIR_WIDTH / 2 else 0),
				maxZ = math.max(wall.z, wall.z + wall.dz * STAIR_DEPTH) + (if wall.dz == 0 then STAIR_WIDTH / 2 else 0),
			}
			local clear = true
			for _, room in build.layout.rooms do
				if overlaps(probe, room) then
					clear = false
					break
				end
			end
			if clear then
				table.insert(
					candidates,
					{ room = junction.id, x = wall.x, z = wall.z, width = STAIR_WIDTH, kind = "stairwell" }
				)
			end
		end
	end
	if #candidates == 0 then
		return false
	end
	table.insert(build.facades, candidates[build.rng:NextInteger(1, #candidates)])
	return true
end

-- Harlow's loop: a DFS from the dock junction over doors (never into the bay) that appends each room's patrol
-- marker on entry and the parent's again on backtrack.
local function buildRoute(layout: Layout, network: Network): { string }
	local patrols: { [string]: string } = {}
	for _, marker in layout.markers do
		if marker.kind == "patrol" then
			patrols[marker.room] = marker.id
		end
	end
	local adjacent: { [string]: { string } } = {}
	for _, door in layout.doors do
		if door.a ~= "bay" and door.b ~= "bay" then
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
	walk(network.dock.id)
	-- Into the loading bay and back once, from the dock junction's first visit.
	local entry = patrols[network.dock.id]
	local at = if entry ~= nil then table.find(route, entry) else nil
	if entry ~= nil and at ~= nil then
		table.insert(route, at + 1, "bay.patrol.1")
		table.insert(route, at + 2, entry)
	end
	return route
end

-- One attempt at a map; nil and the reason when this roll cannot make one.
local function construct(base: Layout, rng: Random): (Layout?, string?)
	local network = OfficeCorridorUtils.network(rng)
	if #network.segments < #network.rooms - #network.segments then
		return nil, "the corridor network has no loop"
	end
	local layout: Layout = {
		artKit = OfficeConstants.GENERATED_ART_KIT,
		startRoom = "bay",
		rooms = {},
		doors = {},
		markers = {},
		truck = table.clone(base.truck),
		route = {},
		rest = "",
	}
	local box: Room =
		{ id = "box", name = "box", minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, room in network.rooms do
		box.minX, box.maxX = math.min(box.minX, room.minX), math.max(box.maxX, room.maxX)
		box.minZ, box.maxZ = math.min(box.minZ, room.minZ), math.max(box.maxZ, room.maxZ)
	end
	local state: Build = {
		rng = rng,
		layout = layout,
		solid = table.clone(network.rooms),
		box = box,
		counts = {},
		facades = {},
		panes = {},
		placed = 0,
		needServer = true,
		needBreakout = true,
		pending = nil,
	}

	-- The loading bay, south of the dock junction, with the truck and the crew's arrival points.
	local bay, bayDoor = OfficeLoadingBayUtils.bay(3, network.dock)
	table.insert(state.solid, bay)
	layout.truck = OfficeLoadingBayUtils.truck(bay, 3)
	for index, point in OfficeLoadingBayUtils.arrivals(layout.truck) do
		table.insert(layout.markers, {
			id = `bay.spawn.{index}`,
			room = "bay",
			kind = "spawn",
			x = point.X,
			z = point.Z,
			rotation = 0,
		})
	end
	local patrol = OfficeLoadingBayUtils.patrolPoint(bay, 3)
	table.insert(
		layout.markers,
		{ id = "bay.patrol.1", room = "bay", kind = "patrol", x = patrol.X, z = patrol.Y, rotation = 0 }
	)

	-- The reception faces the lobby junction's -X wall, its door on the junction's centre line.
	local lobby = network.lobby
	local _, lobbyZ = center(lobby)
	local kit = OfficeKitRegistry.ofType("reception")[1]
	local reception = OfficeKitUtils.place(kit, "reception1", lobby.minX, lobbyZ - kit.door.offset, "maxX", false)
	for _, other in state.solid do
		if overlaps(reception.room, other) then
			return nil, `the reception overlaps {other.id}`
		end
	end
	state.counts.reception = 1
	commit(state, reception.room, {
		a = "reception1",
		b = lobby.id,
		x = reception.doorX,
		z = reception.doorZ,
		width = reception.doorWidth,
		kind = reception.doorKind,
	}, reception.markers)
	local _, receptionZ = center(reception.room)
	table.insert(
		state.facades,
		{ room = "reception1", x = reception.room.minX, z = receptionZ, width = ENTRANCE_WIDTH, kind = "entrance" }
	)

	-- The deck: a server room and a breakout lounge, then weighted draws up to the target (reception counts).
	local target = rng:NextInteger(OfficeConstants.KIT_ROOMS.min, OfficeConstants.KIT_ROOMS.max)
	lineSegments(state, network, target - 1)

	-- Prune dead ends that serve no room; closets and patrol points on what is left.
	local served: { [string]: boolean } = {}
	for _, door in layout.doors do
		served[door.b] = true
	end
	local alive = pruneDeadEnds(network, served)
	local rooms: { Room } = {}
	for _, room in network.rooms do
		if alive[room.id] then
			table.insert(rooms, room)
		end
	end
	table.insert(rooms, bay)
	for _, room in layout.rooms do
		table.insert(rooms, room)
	end
	layout.rooms = rooms
	local doors: { OfficeTypes.Door } = {}
	for _, door in network.doors do
		if alive[door.a] and alive[door.b] then
			table.insert(doors, door)
		end
	end
	table.insert(doors, bayDoor)
	for _, door in layout.doors do
		table.insert(doors, door)
	end
	layout.doors = doors
	-- Every room's depth: its walk from the bay in DEPTH_STUDS steps (corridor pieces add doors, not distance).
	local walked = OfficeLayoutUtils.walkDistances(layout)
	for _, room in layout.rooms do
		local distance = walked[room.id]
		if distance ~= nil then
			room.depth = math.floor(distance / OfficeConstants.DEPTH_STUDS)
		end
	end
	markJunctions(state, network, alive)

	if not addStairwell(state, network, alive) then
		return nil, "no junction wall has room for the stairwell"
	end

	layout.facades, layout.panes = state.facades, state.panes
	layout.route = buildRoute(layout, network)
	for _, room in layout.rooms do
		if room.roomType == "breakout" then
			layout.rest = `{room.id}.rest.1`
			break
		end
	end
	return layout, nil
end

-- Why `layout` is not good enough, or nil.
local function problem(layout: Layout): string?
	local ok, errors = OfficeLayoutRules.validate(layout)
	if not ok then
		return `invalid: {table.concat(errors, "; ")}`
	end
	for _, check in
		{
			OfficeLayoutRules.checkCapacity,
			OfficeLayoutRules.checkRoute,
			OfficeLayoutRules.checkHideSpots,
		}
	do
		local passed, reason = check(layout)
		if not passed then
			return reason
		end
	end
	local walked, walkReason =
		OfficeLayoutRules.checkWalk(layout, OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS)
	if not walked then
		return walkReason
	end
	local kits, servers, receptions, breakouts = 0, 0, 0, 0
	for _, room in layout.rooms do
		if room.kit ~= nil then
			kits += 1
			servers += if room.roomType == "server" then 1 else 0
			receptions += if room.roomType == "reception" then 1 else 0
			breakouts += if room.roomType == "breakout" then 1 else 0
		end
	end
	if kits < OfficeConstants.KIT_ROOMS.min or kits > OfficeConstants.KIT_ROOMS.max then
		return `{kits} kit rooms (wanted {OfficeConstants.KIT_ROOMS.min}-{OfficeConstants.KIT_ROOMS.max})`
	end
	if servers ~= 1 or receptions ~= 1 or breakouts < 1 then
		return `{servers} server rooms, {receptions} receptions, {breakouts} breakouts`
	end
	return nil
end

--[=[
	A fresh map for `seed`: the first of GENERATE_ATTEMPTS builds (Random seed * 31 + attempt) that passes
	`problem`. Errors, listing why each attempt failed, when none does.
]=]
function OfficeLayoutGenerationUtils.generate(base: Layout, seed: number): Layout
	local reasons: { string } = {}
	for attempt = 0, OfficeConstants.GENERATE_ATTEMPTS - 1 do
		local layout, reason = construct(base, Random.new(seed * 31 + attempt))
		if layout ~= nil then
			reason = problem(layout)
			if reason == nil then
				return layout
			end
		end
		table.insert(reasons, `attempt {attempt}: {reason or "?"}`)
	end
	error(`no office layout for seed {seed}: {table.concat(reasons, " | ")}`)
end

return OfficeLayoutGenerationUtils
