--!strict
--[=[
	SchoolNetworkUtils: the School's hall network, in the Office's terms (junction Rooms and corridor segment Rooms,
	zone "hallway", joined by open doorways from junction to segment, like OfficeCorridorUtils.network), so the Office's
	build, dressing and checks take it unchanged. Pure; every roll comes from the given Random.

	1. A LATTICE_COLS x LATTICE_ROWS lattice of junction lines (SchoolConstants), the inner lines jittered a little
	   (the outer lines and the front column never move).
	2. Landmark blocks: the gym and the cafeteria always and the library at LIBRARY_CHANCE, each in its own lattice
	   block, with all four halls round it drawn, so every landmark has a loop to run round.
	3. The spine: from the front node (row 1, a FRONT_COLS column) straight back to the last row.
	4. Random extra lattice edges up to HALL_EDGES, then joining edges until every piece hangs off the front.
	5. Widths: the spine, the front node's halls and the middle row's halls are main halls (CORRIDOR_WIDE); the rest are
	   side halls (CORRIDOR_NARROW). A junction is square, its widest hall or JUNCTION_MIN, whichever is bigger.

	`prune` removes dead-end stubs (a junction with one live hall, and that hall) that serve no room, repeatedly, once
	the layout knows which halls have rooms on them.

	@class SchoolNetworkUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeCorridorUtils = require(ServerScriptService.Features.Office.Utils.OfficeCorridorUtils)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)

type Room = OfficeTypes.Room
type Door = OfficeTypes.Door
type RoomType = OfficeTypes.RoomType
type Run = OfficeCorridorUtils.Run

-- A lattice node: its column (x line) and row (z line), both from 1.
export type Node = { col: number, row: number }

-- A landmark's block: the lattice cell between lines col..col + 1 and row..row + 1.
export type Landmark = { col: number, row: number, roomType: RoomType }

-- halls: every drawn segment by its lattice edge (SchoolNetworkUtils.edgeKey). spine: the spine's segment ids, front
-- first. lineX/lineZ: each lattice line's coordinate.
export type Network = {
	rooms: { Room },
	doors: { Door },
	segments: { Run },
	junctions: { [string]: Room },
	front: Room,
	frontCol: number,
	lineX: { number },
	lineZ: { number },
	halls: { [string]: Run },
	landmarks: { Landmark },
	spine: { string },
}

-- A drawn lattice edge from node a to the later node b (a is the lower column, then the lower row).
type Edge = { a: Node, b: Node, width: number }

local SchoolNetworkUtils = {}

local function nodeId(node: Node): string
	return `hallJ{node.col}_{node.row}`
end

local function ordered(a: Node, b: Node): (Node, Node)
	if a.col < b.col or (a.col == b.col and a.row < b.row) then
		return a, b
	end
	return b, a
end

--[=[
	The key of the lattice edge between nodes `a` and `b` (either order).
]=]
function SchoolNetworkUtils.edgeKey(a: Node, b: Node): string
	local first, second = ordered(a, b)
	return `{nodeId(first)}|{nodeId(second)}`
end

--[=[
	The drawn hall between lattice nodes `a` and `b`, or nil when that edge is not drawn.
]=]
function SchoolNetworkUtils.hall(network: Network, a: Node, b: Node): Run?
	return network.halls[SchoolNetworkUtils.edgeKey(a, b)]
end

local function shuffle<T>(rng: Random, list: { T })
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

--[=[
	A fresh hall network rolled from `rng`.
]=]
function SchoolNetworkUtils.network(rng: Random): Network
	local cols, rows = SchoolConstants.LATTICE_COLS, SchoolConstants.LATTICE_ROWS
	local jitter = SchoolConstants.LATTICE_JITTER
	local frontCols = SchoolConstants.FRONT_COLS
	local frontCol = frontCols[rng:NextInteger(1, #frontCols)]
	local front: Node = { col = frontCol, row = 1 }

	-- 1. Lattice lines.
	local lineX: { number } = {}
	for col = 1, cols do
		local offset = 0
		if col ~= 1 and col ~= cols and col ~= frontCol then
			offset = rng:NextInteger(-jitter, jitter)
		end
		lineX[col] = SchoolConstants.LATTICE_ORIGIN_X + (col - 1) * SchoolConstants.LATTICE_STEP_X + offset
	end
	local lineZ: { number } = {}
	for row = 1, rows do
		local offset = 0
		if row ~= 1 and row ~= rows then
			offset = rng:NextInteger(-jitter, jitter)
		end
		lineZ[row] = SchoolConstants.LATTICE_ORIGIN_Z + (row - 1) * SchoolConstants.LATTICE_STEP_Z + offset
	end

	local edges: { Edge } = {}
	local chosen: { [string]: boolean } = {}
	local inGraph: { [string]: boolean } = {}
	local spineKeys: { [string]: boolean } = {}
	local spineOrder: { string } = {}
	local function addEdge(a: Node, b: Node)
		local key = SchoolNetworkUtils.edgeKey(a, b)
		if chosen[key] then
			return
		end
		local first, second = ordered(a, b)
		chosen[key] = true
		inGraph[nodeId(first)] = true
		inGraph[nodeId(second)] = true
		table.insert(edges, { a = first, b = second, width = SchoolConstants.CORRIDOR_NARROW })
	end

	-- 2. Landmark blocks and their four halls.
	local blocks: { Node } = {}
	for row = 1, rows - 1 do
		for col = 1, cols - 1 do
			table.insert(blocks, { col = col, row = row })
		end
	end
	shuffle(rng, blocks)
	local wanted = #SchoolConstants.LANDMARKS - 1
	if rng:NextNumber() < SchoolConstants.LIBRARY_CHANCE then
		wanted += 1
	end
	local landmarks: { Landmark } = {}
	for index = 1, math.min(wanted, #blocks) do
		local block = blocks[index]
		local col, row = block.col, block.row
		table.insert(landmarks, { col = col, row = row, roomType = SchoolConstants.LANDMARKS[index] })
		addEdge({ col = col, row = row }, { col = col + 1, row = row })
		addEdge({ col = col, row = row + 1 }, { col = col + 1, row = row + 1 })
		addEdge({ col = col, row = row }, { col = col, row = row + 1 })
		addEdge({ col = col + 1, row = row }, { col = col + 1, row = row + 1 })
	end

	-- 3. The spine, front to back.
	for row = 1, rows - 1 do
		local a: Node, b: Node = { col = frontCol, row = row }, { col = frontCol, row = row + 1 }
		addEdge(a, b)
		local key = SchoolNetworkUtils.edgeKey(a, b)
		spineKeys[key] = true
		table.insert(spineOrder, key)
	end

	-- Every lattice edge, in a fixed order so the rolls below replay from the seed.
	local lattice: { { Node } } = {}
	for row = 1, rows do
		for col = 1, cols do
			if col < cols then
				table.insert(lattice, { { col = col, row = row }, { col = col + 1, row = row } })
			end
			if row < rows then
				table.insert(lattice, { { col = col, row = row }, { col = col, row = row + 1 } })
			end
		end
	end

	-- 4. Random extra edges, then join every piece to the front's.
	local target = rng:NextInteger(SchoolConstants.HALL_EDGES.min, SchoolConstants.HALL_EDGES.max)
	local pool: { { Node } } = {}
	for _, pair in lattice do
		if not chosen[SchoolNetworkUtils.edgeKey(pair[1], pair[2])] then
			table.insert(pool, pair)
		end
	end
	shuffle(rng, pool)
	while #edges < target do
		local pair = table.remove(pool)
		if pair == nil then
			break
		end
		addEdge(pair[1], pair[2])
	end
	-- The nodes the front's piece reaches.
	local function frontPiece(): { [string]: boolean }
		local seen: { [string]: boolean } = { [nodeId(front)] = true }
		local changed = true
		while changed do
			changed = false
			for _, edge in edges do
				local a, b = nodeId(edge.a), nodeId(edge.b)
				if seen[a] ~= seen[b] then
					seen[a], seen[b] = true, true
					changed = true
				end
			end
		end
		return seen
	end
	while true do
		local piece = frontPiece()
		local stray = false
		for id in inGraph do
			if not piece[id] then
				stray = true
				break
			end
		end
		if not stray then
			break
		end
		-- An undrawn lattice edge from the front's piece toward a stray piece's node, else any edge out of it.
		local toward: { { Node } } = {}
		local outward: { { Node } } = {}
		for _, pair in lattice do
			local a, b = nodeId(pair[1]), nodeId(pair[2])
			if
				not chosen[SchoolNetworkUtils.edgeKey(pair[1], pair[2])]
				and (piece[a] == true) ~= (piece[b] == true)
			then
				local other = if piece[a] then b else a
				table.insert(if inGraph[other] then toward else outward, pair)
			end
		end
		local candidates = if #toward > 0 then toward else outward
		local pair = candidates[rng:NextInteger(1, #candidates)]
		addEdge(pair[1], pair[2])
	end

	-- 5. Widths: the spine, the front node's halls and the middle row are main halls.
	local middleRow = math.ceil(rows / 2)
	local frontId = nodeId(front)
	for _, edge in edges do
		local horizontal = edge.a.row == edge.b.row
		local main = spineKeys[SchoolNetworkUtils.edgeKey(edge.a, edge.b)] == true
			or nodeId(edge.a) == frontId
			or nodeId(edge.b) == frontId
			or (horizontal and edge.a.row == middleRow)
		edge.width = if main then SchoolConstants.CORRIDOR_WIDE else SchoolConstants.CORRIDOR_NARROW
	end

	-- Junctions: square, sized by their widest hall, at least JUNCTION_MIN.
	local side: { [string]: number } = {}
	for _, edge in edges do
		for _, node in { edge.a, edge.b } do
			local id = nodeId(node)
			side[id] = math.max(side[id] or SchoolConstants.JUNCTION_MIN, edge.width)
		end
	end
	local floor = 1
	local rooms: { Room } = {}
	local junctions: { [string]: Room } = {}
	for row = 1, rows do
		for col = 1, cols do
			local id = nodeId({ col = col, row = row })
			local size = side[id]
			if size ~= nil then
				local half = size / 2
				local room: Room = {
					id = id,
					name = "Hall",
					minX = lineX[col] - half,
					maxX = lineX[col] + half,
					minZ = lineZ[row] - half,
					maxZ = lineZ[row] + half,
					zone = "hallway",
					floor = floor,
				}
				junctions[id] = room
				table.insert(rooms, room)
			end
		end
	end

	-- Segments, junction face to junction face: the spine first (front to back), then the rest in lattice order.
	local byKey: { [string]: Edge } = {}
	for _, edge in edges do
		byKey[SchoolNetworkUtils.edgeKey(edge.a, edge.b)] = edge
	end
	local sorted: { Edge } = {}
	for _, key in spineOrder do
		table.insert(sorted, byKey[key])
	end
	for _, pair in lattice do
		local key = SchoolNetworkUtils.edgeKey(pair[1], pair[2])
		local edge = byKey[key]
		if edge ~= nil and not spineKeys[key] then
			table.insert(sorted, edge)
		end
	end

	local segments: { Run } = {}
	local doors: { Door } = {}
	local halls: { [string]: Run } = {}
	local spine: { string } = {}
	for index, edge in sorted do
		local ja, jb = junctions[nodeId(edge.a)], junctions[nodeId(edge.b)]
		local horizontal = edge.a.row == edge.b.row
		local half = edge.width / 2
		local id = `hallS{index}`
		local room: Room
		local from: number, to: number
		if horizontal then
			local z = lineZ[edge.a.row]
			from, to = ja.maxX, jb.minX
			room = {
				id = id,
				name = "Hall",
				minX = from,
				maxX = to,
				minZ = z - half,
				maxZ = z + half,
				zone = "hallway",
				floor = floor,
			}
			table.insert(doors, { a = ja.id, b = id, x = from, z = z, width = edge.width, kind = "open" })
			table.insert(doors, { a = jb.id, b = id, x = to, z = z, width = edge.width, kind = "open" })
		else
			local x = lineX[edge.a.col]
			from, to = ja.maxZ, jb.minZ
			room = {
				id = id,
				name = "Hall",
				minX = x - half,
				maxX = x + half,
				minZ = from,
				maxZ = to,
				zone = "hallway",
				floor = floor,
			}
			table.insert(doors, { a = ja.id, b = id, x = x, z = from, width = edge.width, kind = "open" })
			table.insert(doors, { a = jb.id, b = id, x = x, z = to, width = edge.width, kind = "open" })
		end
		assert(to > from, `hall {id} has no length`)
		local run: Run = { room = room, horizontal = horizontal, from = from, to = to }
		table.insert(segments, run)
		table.insert(rooms, room)
		local key = SchoolNetworkUtils.edgeKey(edge.a, edge.b)
		halls[key] = run
		if spineKeys[key] then
			table.insert(spine, id)
		end
	end

	return {
		rooms = rooms,
		doors = doors,
		segments = segments,
		junctions = junctions,
		front = junctions[frontId],
		frontCol = frontCol,
		lineX = lineX,
		lineZ = lineZ,
		halls = halls,
		landmarks = landmarks,
		spine = spine,
	}
end

--[=[
	The network's rooms left alive (id -> true) once dead-end stubs that serve no room are removed, repeatedly: a
	junction (never the front) with one live hall that is not in `served` goes, with that hall.
]=]
function SchoolNetworkUtils.prune(network: Network, served: { [string]: boolean }): { [string]: boolean }
	local alive: { [string]: boolean } = {}
	for _, room in network.rooms do
		alive[room.id] = true
	end
	local changed = true
	while changed do
		changed = false
		for _, junction in network.rooms do
			local id = junction.id
			if network.junctions[id] == nil or not alive[id] or junction == network.front or served[id] then
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

return SchoolNetworkUtils
