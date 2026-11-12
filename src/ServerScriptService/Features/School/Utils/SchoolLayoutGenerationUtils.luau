--!strict
--[=[
	SchoolLayoutGenerationUtils: a fresh School from a seed, as the Office's own OfficeTypes.Layout, so the Office's
	build, spawn roll, Hide, Harlow's route and rest, lighting and layout checks take it unchanged
	(docs/superpowers/plans/2026-11-10-odd-hours-school-map.md). Mirrors OfficeLayoutGenerationUtils:

	1. The hall network (SchoolNetworkUtils) is the skeleton.
	2. The front hall (the start room, id "bay" like the Office's loading bay) hangs off the front node's south wall;
	   the truck, the yard and the car park are the Office's (OfficeGroundsUtils), and both entrances lead into the
	   front hall: the dock door through its front wall, the lobby door through its west wall.
	3. Each landmark (gym, cafeteria, library) fills its lattice block between its two row halls: its kit's front door
	   on one of them, an open back door on the other.
	4. Room slots (SchoolRoomSlotUtils: block quarters facing their drawn halls, and the wall band outside the edge
	   halls) are dealt in a seeded order: the deck's rooms first (the lounge leads, so Harlow always has his rest), then
	   classrooms, each kit centred in the first of its place's slots it fits.
	5. Dead-end stubs that serve no room are pruned; junctions get a patrol point and the wide halls locker banks
	   (SchoolHallUtils), then every hall the Office's hall dressing; the route is the Office's walk over the doors
	   (SchoolHallUtils.route) and rest is the lounge.

	`generate` builds up to GENERATE_ATTEMPTS layouts (seed * 31 + attempt) and returns the first that passes the
	Office's checks (validate, capacity, route, hide spots, walk) and has the School's room mix. Pure.

	@class SchoolLayoutGenerationUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Office = ServerScriptService.Features.Office
local OfficeConstants = require(Office.Data.OfficeConstants)
local OfficeGroundsUtils = require(Office.Utils.OfficeGroundsUtils)
local OfficeHallDressingUtils = require(Office.Utils.OfficeHallDressingUtils)
local OfficeKitUtils = require(Office.Utils.OfficeKitUtils)
local OfficeLayoutRules = require(Office.Rules.OfficeLayoutRules)
local OfficeLayoutUtils = require(Office.Utils.OfficeLayoutUtils)
local OfficeTypes = require(Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local SchoolKitRegistry = require(ServerScriptService.Features.School.Data.SchoolKitRegistry)
local SchoolHallUtils = require(script.Parent.SchoolHallUtils)
local SchoolNetworkUtils = require(script.Parent.SchoolNetworkUtils)
local SchoolRoomSlotUtils = require(script.Parent.SchoolRoomSlotUtils)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Door = OfficeTypes.Door
type Kit = OfficeTypes.Kit
type Edge = OfficeTypes.Edge
type Marker = OfficeTypes.Marker
type Network = SchoolNetworkUtils.Network

type Slot = SchoolRoomSlotUtils.Slot

-- The mutable state of one attempt.
type Build = {
	rng: Random,
	layout: Layout,
	network: Network,
	-- Every room placed so far (and the front hall's keep-out): what a new room may not overlap.
	solid: { Room },
	counts: { [string]: number },
	-- The deck's kit ids still to deal, in order.
	deck: { string },
}

local SchoolLayoutGenerationUtils = {}

local function overlaps(a: Room, b: Room): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

local function shuffle<T>(rng: Random, list: { T })
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

local function addMarkers(build: Build, markers: { Marker })
	for _, marker in markers do
		table.insert(build.layout.markers, marker)
	end
end

local function nextId(build: Build, roomType: string): string
	return `{roomType}{(build.counts[roomType] or 0) + 1}`
end

local function commit(build: Build, room: Room, doors: { Door }, markers: { Marker })
	local roomType: string = room.roomType or "room"
	build.counts[roomType] = (build.counts[roomType] or 0) + 1
	table.insert(build.layout.rooms, room)
	table.insert(build.solid, room)
	for _, door in doors do
		table.insert(build.layout.doors, door)
	end
	addMarkers(build, markers)
end

-- Whether `room` lies inside the exterior shell and clear of everything placed.
local function fits(build: Build, room: Room): boolean
	local envelope = OfficeConstants.OUTSIDE.ENVELOPE
	if
		room.minX < envelope.minX
		or room.maxX > envelope.maxX
		or room.minZ < envelope.minZ
		or room.maxZ > envelope.maxZ
	then
		return false
	end
	for _, other in build.solid do
		if overlaps(room, other) then
			return false
		end
	end
	return true
end

-- Places `kit` centred in `slot` (randomly mirrored) when it fits; true when it did.
local function tryKit(build: Build, slot: Slot, kit: Kit): boolean
	if kit.width > slot.to - slot.from or kit.depth > slot.depth then
		return false
	end
	local cursor = slot.from + math.floor((slot.to - slot.from - kit.width) / 2)
	local mirrored = build.rng:NextInteger(0, 1) == 1
	local frontX: number, frontZ: number, facing: Edge = SchoolRoomSlotUtils.front(slot, cursor, kit.width)
	local id = nextId(build, kit.roomType)
	local placement = OfficeKitUtils.place(kit, id, frontX, frontZ, facing, mirrored)
	if not fits(build, placement.room) then
		return false
	end
	local door: Door = {
		a = id,
		b = slot.segment.room.id,
		x = placement.doorX,
		z = placement.doorZ,
		width = placement.doorWidth,
		kind = placement.doorKind,
	}
	commit(build, placement.room, { door }, placement.markers)
	return true
end

-- Deals one room into the first of `options` it fits: the deck's next kit, else a classroom.
local function deal(build: Build, options: { Slot })
	local order: { Kit } = {}
	local head = build.deck[1]
	local headKit = if head ~= nil then SchoolKitRegistry.get(head) else nil
	if headKit ~= nil then
		table.insert(order, headKit)
	end
	local classrooms: { string } = table.clone(SchoolConstants.CLASSROOM_KITS)
	shuffle(build.rng, classrooms)
	for _, id in classrooms do
		local kit = SchoolKitRegistry.get(id)
		if kit ~= nil then
			table.insert(order, kit)
		end
	end
	for index, kit in order do
		for _, slot in options do
			if tryKit(build, slot, kit) then
				if index == 1 and headKit ~= nil then
					table.remove(build.deck, 1)
				end
				return
			end
		end
	end
end

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

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
function SchoolLayoutGenerationUtils.snapToWalls(markers: { Marker }, kit: Rect, room: Rect, hold: Edge?)
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
function SchoolLayoutGenerationUtils.freeDoorX(
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

-- A landmark fills its block between its two row halls: the kit's front door on one, an open back door on the other.
local function placeLandmark(build: Build, landmark: SchoolNetworkUtils.Landmark): string?
	local network = build.network
	local col, row = landmark.col, landmark.row
	local top = SchoolNetworkUtils.hall(network, { col = col, row = row }, { col = col + 1, row = row })
	local bottom = SchoolNetworkUtils.hall(network, { col = col, row = row + 1 }, { col = col + 1, row = row + 1 })
	local kit = SchoolKitRegistry.ofType(landmark.roomType)[1]
	if top == nil or bottom == nil or kit == nil then
		return `the {landmark.roomType} block has no row halls`
	end
	local minX, maxX = math.max(top.from, bottom.from), math.min(top.to, bottom.to)
	local minZ, maxZ = top.room.maxZ, bottom.room.minZ
	if maxX - minX < kit.width or maxZ - minZ < kit.depth + SchoolConstants.LANDMARK_BACK_AISLE then
		return `the {landmark.roomType} does not fit its block`
	end
	local rng = build.rng
	local frontTop = rng:NextInteger(0, 1) == 0
	local cursor = minX + math.floor((maxX - minX - kit.width) / 2)
	local id = nextId(build, kit.roomType)
	local mirrored = rng:NextInteger(0, 1) == 1
	local placement = if frontTop
		then OfficeKitUtils.place(kit, id, cursor, minZ, "minZ", mirrored)
		else OfficeKitUtils.place(kit, id, cursor + kit.width, maxZ, "maxZ", mirrored)
	local room = placement.room
	local kitRect: Rect = { minX = room.minX, maxX = room.maxX, minZ = room.minZ, maxZ = room.maxZ }
	room.minX, room.maxX, room.minZ, room.maxZ = minX, maxX, minZ, maxZ
	-- The kit's wall pieces follow the room's real walls (the block is wider and deeper than the kit). The back door
	-- keeps clear of the pieces then standing along the back wall; when they leave it no room (a cafeteria's serving
	-- line), the back wall's floor pieces stay where the kit put them (an island, the door behind) and only its wall
	-- props move.
	local width = SchoolConstants.LANDMARK_DOOR_WIDTH
	local inset = SchoolConstants.LANDMARK_DOOR_INSET + width / 2
	local want = minX + inset + rng:NextNumber() * math.max(0, maxX - minX - 2 * inset)
	local backEdge: Edge = if frontTop then "maxZ" else "minZ"
	local backZ = if frontTop then maxZ else minZ
	local snapped = table.clone(placement.markers)
	for index, marker in snapped do
		snapped[index] = table.clone(marker)
	end
	SchoolLayoutGenerationUtils.snapToWalls(snapped, kitRect, room)
	local backX = SchoolLayoutGenerationUtils.freeDoorX(snapped, room, backZ, width, inset, want)
	if backX == nil then
		SchoolLayoutGenerationUtils.snapToWalls(placement.markers, kitRect, room, backEdge)
		backX = SchoolLayoutGenerationUtils.freeDoorX(placement.markers, room, backZ, width, inset, want)
	else
		placement.markers = snapped
	end
	if backX == nil then
		return `the {landmark.roomType}'s back wall has no free stretch for its back door`
	end
	local doors: { Door } = {
		{
			a = id,
			b = if frontTop then top.room.id else bottom.room.id,
			x = placement.doorX,
			z = placement.doorZ,
			width = placement.doorWidth,
			kind = placement.doorKind,
		},
		{
			a = id,
			b = if frontTop then bottom.room.id else top.room.id,
			x = math.round(backX),
			z = if frontTop then maxZ else minZ,
			width = width,
			kind = "open",
		},
	}
	commit(build, room, doors, placement.markers)
	return nil
end

-- One attempt at a map; nil and the reason when this roll cannot make one.
local function construct(base: Layout, rng: Random): (Layout?, string?)
	local network = SchoolNetworkUtils.network(rng)
	local layout: Layout = {
		artKit = SchoolConstants.ART_KIT,
		startRoom = "bay",
		rooms = {},
		doors = {},
		markers = {},
		truck = table.clone(base.truck),
		route = {},
		rest = "",
		facades = {},
		panes = {},
	}
	local deck: { string } = table.clone(SchoolConstants.DECK)
	local lounge = table.remove(deck, 1)
	shuffle(rng, deck)
	if lounge ~= nil then
		table.insert(deck, 1, lounge)
	end
	local build: Build =
		{ rng = rng, layout = layout, network = network, solid = table.clone(network.rooms), counts = {}, deck = deck }

	-- The front hall, south of the front node (never mirrored: SchoolKitRegistry), and the outside.
	local front = network.front
	local hallKit = SchoolKitRegistry.ofType("fronthall")[1]
	if hallKit == nil then
		return nil, "no front hall kit"
	end
	local frontX = (front.minX + front.maxX) / 2 + hallKit.width / 2
	local entry = OfficeKitUtils.place(hallKit, "bay", frontX, front.minZ, "maxZ", false)
	local hall = entry.room
	commit(build, hall, {
		{ a = "bay", b = front.id, x = entry.doorX, z = entry.doorZ, width = entry.doorWidth, kind = entry.doorKind },
	}, entry.markers)
	local keepOut = SchoolConstants.FRONT_KEEP_OUT
	table.insert(build.solid, {
		id = "keepOut",
		name = "keepOut",
		minX = hall.minX - keepOut,
		maxX = hall.minX,
		minZ = hall.minZ,
		maxZ = hall.maxZ,
	})
	layout.grounds = OfficeGroundsUtils.grounds()
	layout.truck = OfficeGroundsUtils.truck()
	addMarkers(build, OfficeGroundsUtils.arrivalMarkers(layout.truck))
	layout.entrances = {
		OfficeGroundsUtils.dockEntrance(hall),
		OfficeGroundsUtils.lobbyEntrance(hall, (hall.minZ + hall.maxZ) / 2, SchoolConstants.ENTRANCE_WIDTH),
	}

	for _, landmark in network.landmarks do
		local reason = placeLandmark(build, landmark)
		if reason ~= nil then
			return nil, reason
		end
	end
	for _, options in SchoolRoomSlotUtils.slots(network, rng) do
		deal(build, options)
	end

	-- Prune dead ends that serve no room; the network's live rooms and doors go first, as in the Office.
	local served: { [string]: boolean } = {}
	for _, door in layout.doors do
		served[door.b] = true
	end
	local alive = SchoolNetworkUtils.prune(network, served)
	local rooms: { Room } = {}
	for _, room in network.rooms do
		if alive[room.id] then
			table.insert(rooms, room)
		end
	end
	for _, room in layout.rooms do
		table.insert(rooms, room)
	end
	layout.rooms = rooms
	local doors: { Door } = {}
	for _, door in network.doors do
		if alive[door.a] and alive[door.b] then
			table.insert(doors, door)
		end
	end
	for _, door in layout.doors do
		table.insert(doors, door)
	end
	layout.doors = doors
	local walked = OfficeLayoutUtils.walkDistances(layout)
	for _, room in layout.rooms do
		local distance = walked[room.id]
		if distance ~= nil then
			room.depth = math.floor(distance / OfficeConstants.DEPTH_STUDS)
		end
	end

	-- Halls: a patrol point in each junction, lockers on the wide halls, then the Office's dressing.
	for _, room in network.rooms do
		if alive[room.id] and network.junctions[room.id] ~= nil then
			table.insert(layout.markers, SchoolHallUtils.patrolPoint(room))
		end
	end
	for _, segment in network.segments do
		local room = segment.room
		local width = if segment.horizontal then room.maxZ - room.minZ else room.maxX - room.minX
		if alive[room.id] and width >= SchoolConstants.CORRIDOR_WIDE then
			addMarkers(build, SchoolHallUtils.lockers(layout, room))
		end
	end
	for _, room in layout.rooms do
		if room.zone == "hallway" then
			addMarkers(
				build,
				OfficeHallDressingUtils.dress(
					room,
					layout,
					rng,
					network.junctions[room.id] ~= nil,
					{ seat = SchoolConstants.HALL_SEAT, junctionCorners = false }
				)
			)
		end
	end
	layout.route = SchoolHallUtils.route(layout, front.id)
	for _, room in layout.rooms do
		if room.roomType == "lounge" then
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
	local byType: { [string]: number } = {}
	local classrooms = 0
	for _, room in layout.rooms do
		local roomType = room.roomType
		if roomType ~= nil then
			byType[roomType] = (byType[roomType] or 0) + 1
		end
		if room.kit ~= nil and table.find(SchoolConstants.CLASSROOM_KITS, room.kit) ~= nil then
			classrooms += 1
		end
	end
	local gyms, cafeterias, libraries, lounges =
		byType.gym or 0, byType.cafeteria or 0, byType.library or 0, byType.lounge or 0
	if gyms ~= 1 or cafeterias ~= 1 or libraries > 1 or lounges ~= 1 then
		return `{gyms} gyms, {cafeterias} cafeterias, {libraries} libraries, {lounges} lounges`
	end
	if classrooms < SchoolConstants.CLASSROOMS_MIN then
		return `{classrooms} classrooms (wanted {SchoolConstants.CLASSROOMS_MIN})`
	end
	return nil
end

--[=[
	A fresh School for `seed`: the first of GENERATE_ATTEMPTS builds (Random seed * 31 + attempt) that passes
	`problem`. Errors, listing why each attempt failed, when none does.
]=]
function SchoolLayoutGenerationUtils.generate(base: Layout, seed: number): Layout
	local reasons: { string } = {}
	for attempt = 0, SchoolConstants.GENERATE_ATTEMPTS - 1 do
		local layout, reason = construct(base, Random.new(seed * 31 + attempt))
		if layout ~= nil then
			reason = problem(layout)
			if reason == nil then
				return layout
			end
		end
		table.insert(reasons, `attempt {attempt}: {reason or "?"}`)
	end
	error(`no school layout for seed {seed}: {table.concat(reasons, " | ")}`)
end

return SchoolLayoutGenerationUtils
