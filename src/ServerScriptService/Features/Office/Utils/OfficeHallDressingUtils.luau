--!strict
--[=[
	OfficeHallDressingUtils: the prop markers that make a hallway read as a lived-in corridor, as in the approved
	spike: a sconce on each free sconce spot (OfficeLightingUtils.sconceSpots), then along each long wall of a run
	alternating art frames (about every 20 studs) and planters or sofa benches, at most one wall clock, and a planter
	and a water cooler in the corners of a junction.

	Walking lanes come first. A collidable prop (planter, sofa, water cooler) stands within MAX_WALL_GAP of its wall, keeps
	OPENING_CLEAR studs from every door casing and junction mouth and PATROL_CLEAR from a patrol point or other floor
	furniture, stands COLLIDABLE_SPACING apart from the last one on its wall and OPPOSITE_GAP along from any on the
	wall across. The loading bay's and the reception's junctions take wall props only. Wall props never cover a door,
	facade or glass pane, and collidables keep OPENING_CLEAR from them too (a collidable stands MAX_WALL_GAP =
	SHELL.trimClearance off the plaster, clear of the trim; wall props hang flat on it). Layout space; pure and deterministic for a given rng.

	@class OfficeHallDressingUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Features.Office
local OfficeConstants = require(Server.Data.OfficeConstants)
local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLightingUtils = require(script.Parent.OfficeLightingUtils)
local OfficeTypes = require(Server.Data.OfficeTypes)

type Room = OfficeTypes.Room
type Layout = OfficeTypes.Layout
type Marker = OfficeTypes.Marker
type Edge = OfficeTypes.Edge
type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
-- A prop standing against `edge`, centred at `along` and `half` wide along the wall.
type Stand = { edge: Edge, along: number, half: number, rect: Rect }

-- A collidable stands exactly SHELL.trimClearance off the plaster face: the wainscot, rail and skirt run behind it.
local MAX_WALL_GAP = OfficeConstants.SHELL.trimClearance
-- Mr. Harlow's lanes come first: a hall narrower than WIDE_HALL keeps NARROW_CLEAR studs clear beside a prop, a
-- WIDE_HALL one keeps WIDE_CLEAR; a prop too deep for the hall's width (a planter or sofa off the trim leaves a 14 hall
-- under 10) gives way to a water cooler. Junctions and the atrium are wider.
local WIDE_HALL = 14
local NARROW_CLEAR = 7
local WIDE_CLEAR = 10
local OPENING_CLEAR = 3
local PATROL_CLEAR = 2
local FURNITURE_CLEAR = 1
local COLLIDABLE_SPACING = 12
local OPPOSITE_GAP = 9
local SCONCE_DOOR_CLEAR = 1
local WALL_PROP_GAP = 2
local SLOT_STEP = 10
local SLOT_JITTER = 2
local SLOT_START = 5
local SLOT_SKIP = 0.25
local SLOT_SHIFTS = { 0, 2, -2, 4, -4 }
local CLOCK_SHIFTS = { 0, 5, -5, 10, -10, 15, -15 }
local MIN_CLOCK_RUN = 30

-- Yaw that turns a prop's front (local -Z) into the room from each wall.
local FACE_YAW: { [Edge]: number } = { minX = -math.pi / 2, maxX = math.pi / 2, minZ = math.pi, maxZ = 0 }
local ALL_EDGES: { Edge } = { "minX", "maxX", "minZ", "maxZ" }
local ALONG_X_WALLS: { Edge } = { "minZ", "maxZ" }
local ALONG_Z_WALLS: { Edge } = { "minX", "maxX" }
local OPPOSITE: { [Edge]: Edge } = { minX = "maxX", maxX = "minX", minZ = "maxZ", maxZ = "minZ" }
local HALF_WALL = OfficeConstants.WALL_THICKNESS / 2

local OfficeHallDressingUtils = {
	MAX_WALL_GAP = MAX_WALL_GAP,
	WIDE_HALL = WIDE_HALL,
	OPENING_CLEAR = OPENING_CLEAR,
	PATROL_CLEAR = PATROL_CLEAR,
	COLLIDABLE_SPACING = COLLIDABLE_SPACING,
	SCONCE_DOOR_CLEAR = SCONCE_DOOR_CLEAR,
}

local function horizontal(edge: Edge): boolean
	return edge == "minZ" or edge == "maxZ"
end

-- The coordinate of `edge`'s inner wall face, and the sign that points from it into the room.
local function face(room: Room, edge: Edge): (number, number)
	if edge == "minX" then
		return room.minX + HALF_WALL, 1
	elseif edge == "maxX" then
		return room.maxX - HALF_WALL, -1
	elseif edge == "minZ" then
		return room.minZ + HALF_WALL, 1
	end
	return room.maxZ - HALF_WALL, -1
end

-- The span along `edge` between the inner faces of its corners.
local function span(room: Room, edge: Edge): (number, number)
	if horizontal(edge) then
		return room.minX + HALF_WALL, room.maxX - HALF_WALL
	end
	return room.minZ + HALF_WALL, room.maxZ - HALF_WALL
end

local function sizeOf(art: string): Vector3
	local size: Vector3? = OfficeConstants.PROP_SIZES[art]
	assert(size ~= nil, `no PROP_SIZES entry for {art}`)
	return size
end

-- The footprint of `art` standing `gap` off `edge`, centred at `along`.
local function footprint(room: Room, edge: Edge, art: string, along: number, gap: number): Rect
	local size = sizeOf(art)
	local wall, sign = face(room, edge)
	local inner, outer = wall + sign * gap, wall + sign * (gap + size.Z)
	local low, high = math.min(inner, outer), math.max(inner, outer)
	if horizontal(edge) then
		return { minX = along - size.X / 2, maxX = along + size.X / 2, minZ = low, maxZ = high }
	end
	return { minX = low, maxX = high, minZ = along - size.X / 2, maxZ = along + size.X / 2 }
end

local function marker(room: Room, n: number, art: string, edge: Edge, along: number, gap: number): Marker
	local size = sizeOf(art)
	local wall, sign = face(room, edge)
	local across = wall + sign * (gap + size.Z / 2)
	local wallHeight: number? = OfficeConstants.PROP_WALL_HEIGHT[art]
	assert(wallHeight ~= nil or gap == MAX_WALL_GAP, "floor props stand at the wall gap")
	return {
		id = `{room.id}.prop.{n}`,
		room = room.id,
		kind = "prop",
		art = art,
		x = if horizontal(edge) then along else across,
		z = if horizontal(edge) then across else along,
		rotation = FACE_YAW[edge],
	}
end

-- Whether two rectangles are closer than `clear` studs (touching at exactly `clear` is fine).
local function closer(a: Rect, b: Rect, clear: number): boolean
	return a.minX - clear < b.maxX and b.minX < a.maxX + clear and a.minZ - clear < b.maxZ and b.minZ < a.maxZ + clear
end

-- Every gap in `room`'s `edge` wall that props keep off: its doors and facades, and the glass panes on it (a conference
-- room's front), as spans along the wall.
local function gapsOn(layout: Layout, room: Room, edge: Edge): { { number } }
	local spans = OfficeLayoutUtils.openingsOn(layout, room, edge)
	local line = if edge == "minZ"
		then room.minZ
		elseif edge == "maxZ" then room.maxZ
		elseif edge == "minX" then room.minX
		else room.maxX
	for _, pane in OfficeLayoutUtils.panes(layout) do
		local paneHorizontal = pane.z1 == pane.z2
		local fixed = if paneHorizontal then pane.z1 else pane.x1
		if paneHorizontal == horizontal(edge) and math.abs(fixed - line) <= 1e-6 then
			table.insert(spans, if paneHorizontal then { pane.x1, pane.x2 } else { pane.z1, pane.z2 })
		end
	end
	return spans
end

-- Every door, facade and glass pane of `room`, as the wall rectangle it opens with its casing added.
local function openings(layout: Layout, room: Room): { Rect }
	local rects: { Rect } = {}
	for _, edge: Edge in ALL_EDGES do
		local wall = if horizontal(edge)
			then (if edge == "minZ" then room.minZ else room.maxZ)
			else (if edge == "minX" then room.minX else room.maxX)
		for _, opening in gapsOn(layout, room, edge) do
			local from, to = opening[1] - OfficeConstants.SHELL.casing, opening[2] + OfficeConstants.SHELL.casing
			if horizontal(edge) then
				table.insert(rects, { minX = from, maxX = to, minZ = wall - HALF_WALL, maxZ = wall + HALF_WALL })
			else
				table.insert(rects, { minX = wall - HALF_WALL, maxX = wall + HALF_WALL, minZ = from, maxZ = to })
			end
		end
	end
	return rects
end

-- The state of dressing one room.
type State = {
	room: Room,
	layout: Layout,
	rng: Random,
	rects: { Rect },
	-- Floor furniture and patrol points that already stand in or near the room.
	floor: { Rect },
	patrols: { Vector2 },
	stands: { Stand },
	-- Every wall prop and collidable footprint along each wall, as { from, to }.
	hung: { [Edge]: { { number } } },
	-- The art frames among them, which a collidable prop never stands under.
	frames: { [Edge]: { { number } } },
	collidable: boolean,
	-- Hall width (short side) and the clear width a prop must leave across it; nil in a junction.
	width: number?,
	clear: number,
	markers: { Marker },
	next: number,
}

local function add(state: State, new: Marker)
	state.next += 1
	table.insert(state.markers, new)
end

local function hungOn(state: State, edge: Edge): { { number } }
	local list = state.hung[edge] or {}
	state.hung[edge] = list
	return list
end

-- Whether a wall prop `half` wide centred at `along` clears the doors and facades by `clear`, and the other props.
local function hangs(state: State, edge: Edge, along: number, half: number, clear: number): boolean
	local from, to = span(state.room, edge)
	if along - half < from or along + half > to then
		return false
	end
	for _, opening in gapsOn(state.layout, state.room, edge) do
		local casing = OfficeConstants.SHELL.casing + clear
		if along - half < opening[2] + casing and opening[1] - casing < along + half then
			return false
		end
	end
	for _, taken in hungOn(state, edge) do
		if along - half < taken[2] + WALL_PROP_GAP and taken[1] - WALL_PROP_GAP < along + half then
			return false
		end
	end
	return true
end

local function hang(state: State, edge: Edge, art: string, along: number)
	local half = sizeOf(art).X / 2
	table.insert(hungOn(state, edge), { along - half, along + half })
	if art == "artFrame" then
		local frames = state.frames[edge] or {}
		state.frames[edge] = frames
		table.insert(frames, { along - half, along + half })
	end
	add(state, marker(state.room, state.next, art, edge, along, 0))
end

-- Whether a collidable `art` can stand at `along` against `edge` without pinching a lane.
local function canStand(state: State, edge: Edge, art: string, along: number): boolean
	if not state.collidable then
		return false
	end
	local half = sizeOf(art).X / 2
	local from, to = span(state.room, edge)
	if along - half < from or along + half > to then
		return false
	end
	local rect = footprint(state.room, edge, art, along, MAX_WALL_GAP)
	local width = state.width
	if width ~= nil and width - sizeOf(art).Z - MAX_WALL_GAP < state.clear then
		return false
	end
	for _, opening in state.rects do
		if closer(rect, opening, OPENING_CLEAR) then
			return false
		end
	end
	local frames: { { number } } = state.frames[edge] or {}
	for _, frame in frames do
		if along - half < frame[2] and frame[1] < along + half then
			return false
		end
	end
	for _, furniture in state.floor do
		if closer(rect, furniture, FURNITURE_CLEAR) then
			return false
		end
	end
	for _, patrol in state.patrols do
		local point = { minX = patrol.X, maxX = patrol.X, minZ = patrol.Y, maxZ = patrol.Y }
		if closer(rect, point, PATROL_CLEAR) then
			return false
		end
	end
	for _, other in state.stands do
		if closer(rect, other.rect, FURNITURE_CLEAR) then
			return false
		end
		local apart = math.abs(other.along - along)
		if other.edge == edge and apart < COLLIDABLE_SPACING then
			return false
		elseif other.edge == OPPOSITE[edge] and apart < OPPOSITE_GAP then
			return false
		end
	end
	return true
end

local function standAt(state: State, edge: Edge, art: string, along: number)
	local half = sizeOf(art).X / 2
	table.insert(
		state.stands,
		{ edge = edge, along = along, half = half, rect = footprint(state.room, edge, art, along, MAX_WALL_GAP) }
	)
	table.insert(hungOn(state, edge), { along - half, along + half })
	add(state, marker(state.room, state.next, art, edge, along, MAX_WALL_GAP))
end

local function sconces(state: State)
	local half = sizeOf("sconce").X / 2
	for _, spot in OfficeLightingUtils.sconceSpots(state.room) do
		local along = if horizontal(spot.side) then spot.x else spot.z
		if hangs(state, spot.side, along, half, SCONCE_DOOR_CLEAR) then
			hang(state, spot.side, "sconce", along)
		end
	end
end

-- Along one long wall: art and collidables in turn, a slot every SLOT_STEP.
local function dressWall(state: State, edge: Edge)
	local rng = state.rng
	local from, to = span(state.room, edge)
	local turn = rng:NextInteger(0, 1)
	local at = from + SLOT_START + rng:NextNumber() * SLOT_JITTER
	local index = 0
	while at < to - OPENING_CLEAR do
		if (index + turn) % 2 == 0 then
			for _, shift in { 0, 2, -2 } do
				if hangs(state, edge, at + shift, sizeOf("artFrame").X / 2, 1) then
					hang(state, edge, "artFrame", at + shift)
					break
				end
			end
		elseif rng:NextNumber() >= SLOT_SKIP then
			local art = if rng:NextInteger(0, 1) == 0 then "planter" else "sofa"
			local width = state.width
			if width ~= nil and width - sizeOf(art).Z - MAX_WALL_GAP < state.clear then
				art = "waterCooler"
			end
			for _, shift in SLOT_SHIFTS do
				if canStand(state, edge, art, at + shift) then
					standAt(state, edge, art, at + shift)
					break
				end
			end
		end
		index += 1
		at += SLOT_STEP + rng:NextNumber() * SLOT_JITTER
	end
end

-- One clock on a long wall, near the middle of the run.
local function clock(state: State, edges: { Edge })
	local edge: Edge = edges[state.rng:NextInteger(1, #edges)]
	local from, to = span(state.room, edge)
	local middle = (from + to) / 2
	for _, shift in CLOCK_SHIFTS do
		if hangs(state, edge, middle + shift, sizeOf("wallClock").X / 2, 1) then
			hang(state, edge, "wallClock", middle + shift)
			return
		end
	end
end

-- A planter and a water cooler in junction corners, the corners tried in a seeded order.
local function corners(state: State)
	local rng = state.rng
	local candidates: { { edge: Edge, atStart: boolean } } = {}
	for _, edge: Edge in ALL_EDGES do
		table.insert(candidates, { edge = edge, atStart = true })
		table.insert(candidates, { edge = edge, atStart = false })
	end
	for index = #candidates, 2, -1 do
		local other = rng:NextInteger(1, index)
		candidates[index], candidates[other] = candidates[other], candidates[index]
	end
	for _, art in { "planter", "waterCooler" } do
		local half = sizeOf(art).X / 2
		for _, candidate in candidates do
			local from, to = span(state.room, candidate.edge)
			local along = if candidate.atStart then from + half else to - half
			if canStand(state, candidate.edge, art, along) then
				standAt(state, candidate.edge, art, along)
				break
			end
		end
	end
end

-- Whether the room opens onto the loading bay or the reception: no furniture in front of those entrances.
local function entrance(room: Room, layout: Layout): boolean
	local byId: { [string]: Room } = {}
	for _, other in layout.rooms do
		byId[other.id] = other
	end
	for _, door in layout.doors do
		local other = if door.a == room.id then door.b elseif door.b == room.id then door.a else nil
		local neighbour = if other ~= nil then byId[other] else nil
		if other == "bay" or (neighbour ~= nil and neighbour.roomType == "reception") then
			return true
		end
	end
	return false
end

--[=[
	The prop markers that dress hallway `room` (a run, or a junction when `junction`): sconces, art, planters, benches
	and a clock, using only `rng`. Call after the room's doors, facades and patrol points are in `layout`; the caller
	appends the result to `layout.markers`.
]=]
function OfficeHallDressingUtils.dress(room: Room, layout: Layout, rng: Random, junction: boolean?): { Marker }
	local state: State = {
		room = room,
		layout = layout,
		rng = rng,
		rects = openings(layout, room),
		floor = {},
		patrols = {},
		stands = {},
		hung = {},
		frames = {},
		collidable = not entrance(room, layout),
		width = if junction == true then nil else math.min(room.maxX - room.minX, room.maxZ - room.minZ),
		clear = NARROW_CLEAR,
		markers = {},
		next = 1,
	}
	for _, existing in layout.markers do
		if existing.kind == "prop" and existing.room == room.id then
			state.next += 1
		elseif existing.kind == "patrol" then
			table.insert(state.patrols, Vector2.new(existing.x, existing.z))
		elseif existing.room == room.id then
			local size = OfficeLayoutUtils.markerSize(existing)
			if size ~= nil then
				local angle = existing.rotation or 0
				local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
				local hx, hz = (size.X * c + size.Z * s) / 2, (size.X * s + size.Z * c) / 2
				table.insert(
					state.floor,
					{ minX = existing.x - hx, maxX = existing.x + hx, minZ = existing.z - hz, maxZ = existing.z + hz }
				)
			end
		end
	end

	local width = state.width
	if width ~= nil and width >= WIDE_HALL then
		state.clear = WIDE_CLEAR
	end
	sconces(state)
	if junction == true then
		corners(state)
		return state.markers
	end
	local edges: { Edge } = if room.maxX - room.minX >= room.maxZ - room.minZ then ALONG_X_WALLS else ALONG_Z_WALLS
	for _, edge: Edge in edges do
		dressWall(state, edge)
	end
	local from, to = span(room, edges[1])
	if to - from >= MIN_CLOCK_RUN then
		clock(state, edges)
	end
	return state.markers
end

return OfficeHallDressingUtils
