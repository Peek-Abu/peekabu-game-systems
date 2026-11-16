--!strict
--[=[
	OfficeRoomLiningUtils: lines the corridor network with hand-authored kit rooms. The deck (a server room, a
	breakout lounge, then weighted draws, conference boosted at the perimeter) is spread round-robin over the
	segments, each segment taking one room per round on its sides in turn; each slot tries every kit of the drawn
	type largest first, randomly mirrored, and a kit's glass pane is clipped to the corridor it faces. Also holds the
	one attempt's mutable Build and the small helpers OfficeLayoutGenerationUtils shares with it. Split out of
	OfficeLayoutGenerationUtils; it changes only the Build it is handed.

	@class OfficeRoomLiningUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Features.Office
local OfficeConstants = require(Server.Data.OfficeConstants)
local OfficeCorridorUtils = require(script.Parent.OfficeCorridorUtils)
local OfficeKitRegistry = require(Server.Data.OfficeKitRegistry)
local OfficeKitUtils = require(script.Parent.OfficeKitUtils)
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
-- A glass pane clipped to its corridor is dropped when less than this is left.
local MIN_PANE = 2

-- The mutable state of one attempt.
export type Build = {
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

local OfficeRoomLiningUtils = {}

function OfficeRoomLiningUtils.overlaps(a: Room, b: Room): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

local function shuffle<T>(rng: Random, list: { T })
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
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

function OfficeRoomLiningUtils.addMarkers(build: Build, markers: { OfficeTypes.Marker })
	for _, marker in markers do
		table.insert(build.layout.markers, marker)
	end
end

function OfficeRoomLiningUtils.commit(build: Build, room: Room, door: OfficeTypes.Door, markers: { OfficeTypes.Marker })
	table.insert(build.layout.rooms, room)
	table.insert(build.solid, room)
	table.insert(build.layout.doors, door)
	OfficeRoomLiningUtils.addMarkers(build, markers)
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
				if OfficeRoomLiningUtils.overlaps(kitRoom, other) then
					fits = false
					break
				end
			end
		end
		if fits then
			build.counts[roomType] = (build.counts[roomType] or 0) + 1
			build.placed += 1
			OfficeRoomLiningUtils.commit(build, kitRoom, {
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

-- One segment being lined: its two sides in a random order, whose turn is next, and each side's cursor.
type Lane = { segment: Run, sides: { number }, turn: number, cursors: { [number]: number } }

-- Places one room on `side` of the lane at or after that side's cursor; false when the side is full.
local function placeOne(build: Build, lane: Lane, side: number): boolean
	local segment = lane.segment
	local cursor = lane.cursors[side]
	while cursor < segment.to do
		local width = fillSlot(build, segment, side, cursor)
		if width ~= nil then
			lane.cursors[side] = cursor + width
			return true
		end
		cursor += OfficeConstants.ROOM_STEP
	end
	lane.cursors[side] = cursor
	return false
end

-- Lines the segments round-robin until the deck is spent: each round gives every segment (shuffled order) one room,
-- on its sides in turn. Spreading the rooms over the network keeps them apart (the clustered dust needs clean rooms
-- between dirty ones: OfficeSpawnUtils' neighbours) and lets each segment's first slot take a full-length kit.
function OfficeRoomLiningUtils.lineSegments(build: Build, network: Network, wanted: number)
	local order: { Run } = table.clone(network.segments)
	shuffle(build.rng, order)
	local lanes: { Lane } = {}
	for _, segment in order do
		local sides = { 1, -1 }
		shuffle(build.rng, sides)
		table.insert(
			lanes,
			{ segment = segment, sides = sides, turn = 1, cursors = { [1] = segment.from, [-1] = segment.from } }
		)
	end
	local progressed = true
	while progressed and build.placed < wanted do
		progressed = false
		for _, lane in lanes do
			if build.placed >= wanted then
				break
			end
			for _ = 1, 2 do
				local side = lane.sides[lane.turn]
				lane.turn = 3 - lane.turn
				if placeOne(build, lane, side) then
					progressed = true
					break
				end
			end
		end
	end
end

return OfficeRoomLiningUtils
