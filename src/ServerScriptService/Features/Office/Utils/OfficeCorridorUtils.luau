--!strict
--[=[
	OfficeCorridorUtils: the office's corridor network. A jittered lattice of junction squares (at least JUNCTION_MIN on a side) joined
	by straight corridor segments: a wide spine from the loading dock to the lobby, random branches, a loop or two, and one
	atrium where three or more corridors meet. The dock and lobby junctions sit at fixed coordinates. Kit rooms
	hang off this network (OfficeKitUtils). Pure.

	@class OfficeCorridorUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

type Room = OfficeTypes.Room
type Door = OfficeTypes.Door

-- A corridor run between two junction faces (a "segment" of the network; named Run so it does not collide with
-- OfficeTypes.Segment, a wall span). from/to are the span along the corridor (x when horizontal, else z).
export type Run = { room: Room, horizontal: boolean, from: number, to: number }

-- spine: the ids of the segments on the dock-to-lobby path, dock first.
export type Network = {
	rooms: { Room },
	doors: { Door },
	segments: { Run },
	junctions: { [string]: Room },
	dock: Room,
	lobby: Room,
	leaves: { Room },
	spine: { string },
}

type Node = { col: number, row: number }

-- A lattice edge from node a to the later node b (a is the lower column, then the lower row).
type Edge = { a: Node, b: Node, width: number }

local function nodeId(node: Node): string
	return `hallJ{node.col}_{node.row}`
end

local function ordered(a: Node, b: Node): (Node, Node)
	if a.col < b.col or (a.col == b.col and a.row < b.row) then
		return a, b
	end
	return b, a
end

local function edgeKey(a: Node, b: Node): string
	local first, second = ordered(a, b)
	return `{nodeId(first)}|{nodeId(second)}`
end

local OfficeCorridorUtils = {}

function OfficeCorridorUtils.network(rng: Random): Network
	local cols, rows = OfficeConstants.LATTICE_COLS, OfficeConstants.LATTICE_ROWS
	local dockNode, lobbyNode = OfficeConstants.DOCK_NODE, OfficeConstants.LOBBY_NODE
	local jitter = OfficeConstants.LATTICE_JITTER

	-- 1. Lattice lines. The dock's and lobby's lines stay put so those junctions never move.
	local lineX: { number } = {}
	for col = 1, cols do
		local offset = 0
		if col ~= dockNode.col and col ~= lobbyNode.col then
			offset = rng:NextInteger(-jitter, jitter)
		end
		lineX[col] = (col - 1) * OfficeConstants.LATTICE_STEP_X + offset
	end
	local lineZ: { number } = {}
	for row = 1, rows do
		local offset = 0
		if row ~= dockNode.row and row ~= lobbyNode.row then
			offset = rng:NextInteger(-jitter, jitter)
		end
		lineZ[row] = (row - 1) * OfficeConstants.LATTICE_STEP_Z + offset
	end

	local edges: { Edge } = {}
	local chosen: { [string]: boolean } = {}
	local inGraph: { [string]: boolean } = {}
	local spineKeys: { [string]: boolean } = {}
	local spineOrder: { string } = {}

	local function addEdge(a: Node, b: Node)
		local first, second = ordered(a, b)
		chosen[edgeKey(first, second)] = true
		inGraph[nodeId(first)] = true
		inGraph[nodeId(second)] = true
		table.insert(edges, { a = first, b = second, width = OfficeConstants.CORRIDOR_NARROW })
	end

	-- 2. Spine: step toward the lobby, choosing at random between the column and row step while both help.
	inGraph[nodeId(dockNode)] = true
	local current: Node = { col = dockNode.col, row = dockNode.row }
	while current.col ~= lobbyNode.col or current.row ~= lobbyNode.row do
		local colStep = math.sign(lobbyNode.col - current.col)
		local rowStep = math.sign(lobbyNode.row - current.row)
		local stepCol = colStep ~= 0
		if colStep ~= 0 and rowStep ~= 0 then
			stepCol = rng:NextInteger(0, 1) == 0
		end
		local nextNode: Node = if stepCol
			then { col = current.col + colStep, row = current.row }
			else { col = current.col, row = current.row + rowStep }
		addEdge(current, nextNode)
		local key = edgeKey(current, nextNode)
		spineKeys[key] = true
		table.insert(spineOrder, key)
		current = nextNode
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

	-- A random unchosen lattice edge touching the graph (both ends in it when `bothEnds`), or nil.
	local function pick(bothEnds: boolean): { Node }?
		local candidates: { { Node } } = {}
		for _, pair in lattice do
			local a, b = pair[1], pair[2]
			if not chosen[edgeKey(a, b)] then
				local hasA, hasB = inGraph[nodeId(a)] == true, inGraph[nodeId(b)] == true
				local touches = if bothEnds then hasA and hasB else hasA or hasB
				if touches then
					table.insert(candidates, pair)
				end
			end
		end
		if #candidates == 0 then
			return nil
		end
		return candidates[rng:NextInteger(1, #candidates)]
	end

	-- 3. Branches.
	local target = rng:NextInteger(OfficeConstants.CORRIDOR_EDGES.min, OfficeConstants.CORRIDOR_EDGES.max)
	while #edges < target do
		local pair = pick(false)
		if pair == nil then
			break
		end
		addEdge(pair[1], pair[2])
	end

	-- 4. Loops. A sparse tree may have no chord left; the first loop then grows a branch until it has one.
	local edgeCap = OfficeConstants.CORRIDOR_EDGES.max + OfficeConstants.LOOPS.max
	local loops = rng:NextInteger(OfficeConstants.LOOPS.min, OfficeConstants.LOOPS.max)
	for loop = 1, loops do
		local pair = pick(true)
		while pair == nil and loop == 1 and #edges < edgeCap - 1 do
			local branch = pick(false)
			if branch == nil then
				break
			end
			addEdge(branch[1], branch[2])
			pair = pick(true)
		end
		if pair == nil or #edges >= edgeCap then
			break
		end
		addEdge(pair[1], pair[2])
	end

	-- 5. Widths.
	for _, edge in edges do
		if spineKeys[edgeKey(edge.a, edge.b)] or rng:NextNumber() >= OfficeConstants.NARROW_CHANCE then
			edge.width = OfficeConstants.CORRIDOR_WIDE
		else
			edge.width = OfficeConstants.CORRIDOR_NARROW
		end
	end

	-- 6. Junctions: sized by their widest corridor, at least JUNCTION_MIN; one branching junction becomes the atrium.
	local degree: { [string]: number } = {}
	local side: { [string]: number } = {}
	for _, edge in edges do
		for _, node in { edge.a, edge.b } do
			local id = nodeId(node)
			degree[id] = (degree[id] or 0) + 1
			side[id] = math.max(side[id] or OfficeConstants.JUNCTION_MIN, edge.width)
		end
	end
	local dockId, lobbyId = nodeId(dockNode), nodeId(lobbyNode)
	local atriumId: string? = nil
	local branching: { string } = {}
	for row = 1, rows do
		for col = 1, cols do
			local id = nodeId({ col = col, row = row })
			if (degree[id] or 0) >= 3 and id ~= dockId and id ~= lobbyId then
				table.insert(branching, id)
			end
		end
	end
	if #branching > 0 then
		local chosenId = branching[rng:NextInteger(1, #branching)]
		atriumId = chosenId
		side[chosenId] = OfficeConstants.ATRIUM_SIZE
	end

	local floor = OfficeConstants.FLOOR_NUMBER
	local rooms: { Room } = {}
	local junctions: { [string]: Room } = {}
	local leaves: { Room } = {}
	for row = 1, rows do
		for col = 1, cols do
			local id = nodeId({ col = col, row = row })
			if degree[id] ~= nil then
				local half = side[id] / 2
				local room: Room = {
					id = id,
					name = if id == atriumId then "Atrium" else "Corridor",
					minX = lineX[col] - half,
					maxX = lineX[col] + half,
					minZ = lineZ[row] - half,
					maxZ = lineZ[row] + half,
					zone = "hallway",
					floor = floor,
				}
				junctions[id] = room
				table.insert(rooms, room)
				if degree[id] == 1 and id ~= dockId and id ~= lobbyId then
					table.insert(leaves, room)
				end
			end
		end
	end

	-- 7. Segments, junction face to junction face; spine edges first so the spine reads dock to lobby.
	local byKey: { [string]: Edge } = {}
	for _, edge in edges do
		byKey[edgeKey(edge.a, edge.b)] = edge
	end
	local sorted: { Edge } = {}
	for _, key in spineOrder do
		table.insert(sorted, byKey[key])
	end
	for _, edge in edges do
		if not spineKeys[edgeKey(edge.a, edge.b)] then
			table.insert(sorted, edge)
		end
	end

	local segments: { Run } = {}
	local doors: { Door } = {}
	local spine: { string } = {}
	for index, edge in sorted do
		local ja = junctions[nodeId(edge.a)]
		local jb = junctions[nodeId(edge.b)]
		local horizontal = edge.a.row == edge.b.row
		local half = edge.width / 2
		local id = `hallS{index}`
		local room: Room
		local from: number
		local to: number
		if horizontal then
			local z = lineZ[edge.a.row]
			from, to = ja.maxX, jb.minX
			room = {
				id = id,
				name = "Corridor",
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
				name = "Corridor",
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
		assert(to > from, `corridor {id} has no length`)
		table.insert(segments, { room = room, horizontal = horizontal, from = from, to = to })
		table.insert(rooms, room)
		if spineKeys[edgeKey(edge.a, edge.b)] then
			table.insert(spine, id)
		end
	end

	return {
		rooms = rooms,
		doors = doors,
		segments = segments,
		junctions = junctions,
		dock = junctions[dockId],
		lobby = junctions[lobbyId],
		leaves = leaves,
		spine = spine,
	}
end

return OfficeCorridorUtils
