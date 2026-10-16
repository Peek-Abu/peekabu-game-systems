--!strict
-- A fresh irregular workplace: seeded occupied cells, variable rooms and physical corridor links.
local Server = game:GetService("ServerScriptService").Features.Office
local Types = require(Server.Data.OfficeTypes)
local Graph = require(Server.Rules.OfficeLayoutGraphRules)
local Rooms = require(script.Parent.OfficeLayoutRoomUtils)
local Bay = require(script.Parent.OfficeLoadingBayUtils)
local Utils = {}
function Utils.generate(base: Types.Layout, seed: number): Types.Layout
	local rng = Random.new(seed)
	local graph = Graph.generate(rng)
	local layout: Types.Layout = {
		artKit = base.artKit,
		startRoom = "bay",
		rooms = {},
		doors = {},
		markers = {},
		truck = table.clone(base.truck),
		route = {},
		rest = "",
	}
	-- Columns/rows own shared boundaries: a zero gap is a real shared wall.
	local widths: { number } = {}
	local depths: { number } = {}
	local xGaps: { number } = {}
	local zGaps: { number } = {}
	-- Draw without replacement so every occupied cell has a distinct size pair.
	local widthPool: { number } = {}
	local depthPool: { number } = {}
	for offset = 0, 10 do
		widthPool[offset + 1], depthPool[offset + 1] = 30 + offset, 28 + offset
	end
	for index = 1, 5 do
		local w, d = rng:NextInteger(1, #widthPool), rng:NextInteger(1, #depthPool)
		widths[index], depths[index] = widthPool[w], depthPool[d]
		table.remove(widthPool, w)
		table.remove(depthPool, d)
		if index < 5 then
			xGaps[index] = if rng:NextInteger(1, 3) <= 2 then 0 else rng:NextInteger(10, 22)
			zGaps[index] = if rng:NextInteger(1, 3) <= 2 then 0 else rng:NextInteger(10, 22)
		end
	end
	local function boundary(edge: Graph.Edge): ({ number }, number)
		local a, b = graph.nodes[edge.a], graph.nodes[edge.b]
		if a.row == b.row then
			return xGaps, math.min(a.col, b.col)
		end
		return zGaps, math.min(a.row, b.row)
	end
	local directGaps, directIndex = boundary(graph.edges[1])
	directGaps[directIndex] = 0
	for _, edge in graph.edges do
		local gaps, index = boundary(edge)
		if gaps ~= directGaps or index ~= directIndex then
			gaps[index] = rng:NextInteger(10, 22)
			break
		end
	end
	local function starts(sizes: { number }, gaps: { number }): { number }
		local result: { number } = { 0 }
		for index = 2, 5 do
			result[index] = result[index - 1] + sizes[index - 1] + gaps[index - 1]
		end
		return result
	end
	local xs, zs = starts(widths, xGaps), starts(depths, zGaps)
	local work: { Types.Room } = {}
	local zones = { "meeting", "kitchenette", "training", "storage", "office", "records", "laboratory", "breakRoom" }
	for index, node in graph.nodes do
		local width, depth = widths[node.col], depths[node.row]
		local minX, minZ = xs[node.col], zs[node.row]
		local zone = zones[(index + rng:NextInteger(0, #zones - 1) - 1) % #zones + 1]
		local room: Types.Room = {
			id = `work{index}`,
			name = `{zone} {index}`,
			zone = zone,
			minX = minX,
			maxX = minX + width,
			minZ = minZ,
			maxZ = minZ + depth,
		}
		table.insert(work, room)
		table.insert(layout.rooms, room)
		for _, marker in Rooms.markers(room, rng) do
			table.insert(layout.markers, marker)
		end
	end
	local function door(a: string, b: string, x: number, z: number, width: number)
		table.insert(layout.doors, { a = a, b = b, x = x, z = z, width = width })
	end
	for index, edge in graph.edges do
		local a, b = work[edge.a], work[edge.b]
		local id = `corridor{index}`
		local cx, cz = (a.minX + a.maxX) / 2, (a.minZ + a.maxZ) / 2
		local hall: Types.Room? = nil
		if graph.nodes[edge.a].row == graph.nodes[edge.b].row then
			local left, right = if a.minX < b.minX then a else b, if a.minX < b.minX then b else a
			if left.maxX == right.minX then
				door(left.id, right.id, left.maxX, cz, 10)
			else
				hall = {
					id = id,
					name = "Office corridor",
					zone = "hallway",
					minX = left.maxX,
					maxX = right.minX,
					minZ = cz - 5,
					maxZ = cz + 5,
				}
				door(left.id, id, left.maxX, cz, 10)
				door(id, right.id, right.minX, cz, 10)
			end
		else
			local north, south = if a.minZ < b.minZ then a else b, if a.minZ < b.minZ then b else a
			if north.maxZ == south.minZ then
				door(north.id, south.id, cx, north.maxZ, 10)
			else
				hall = {
					id = id,
					name = "Office corridor",
					zone = "hallway",
					minX = cx - 5,
					maxX = cx + 5,
					minZ = north.maxZ,
					maxZ = south.minZ,
				}
				door(north.id, id, cx, north.maxZ, 10)
				door(id, south.id, cx, south.minZ, 10)
			end
		end
		if hall ~= nil then
			table.insert(layout.rooms, hall)
			table.insert(layout.markers, {
				id = `{id}.patrol.1`,
				room = id,
				kind = "patrol",
				x = (hall.minX + hall.maxX) / 2,
				z = (hall.minZ + hall.maxZ) / 2,
				rotation = 0,
			})
		end
	end
	-- Bay attaches to the global exterior, so neither it nor its cab can overlap another cell/corridor.
	local side = rng:NextInteger(1, 4)
	local extreme = if side == 1 or side == 3 then math.huge else -math.huge
	local candidates: { number } = {}
	for index, node in graph.nodes do
		local coordinate = if side <= 2 then node.col else node.row
		local better = if side == 1 or side == 3 then coordinate < extreme else coordinate > extreme
		if better then
			extreme = coordinate
			candidates = {}
		end
		if coordinate == extreme then
			table.insert(candidates, index)
		end
	end
	local target = work[candidates[rng:NextInteger(1, #candidates)]]
	-- The bay, its door, the truck (ramp clear of the walls) and the crew's arrival points in the bed.
	local bay, bayDoor = Bay.bay(side, target)
	table.insert(layout.doors, bayDoor)
	table.insert(layout.rooms, bay)
	layout.truck = Bay.truck(bay, side)
	for index, point in Bay.arrivals(layout.truck) do
		table.insert(layout.markers, {
			id = `bay.spawn.{index}`,
			room = "bay",
			kind = "spawn",
			x = point.X,
			z = point.Z,
			rotation = 0,
		})
	end
	-- DFS walk on the actual selected graph keeps adjacent patrol steps local, including backtracking.
	local adjacency: { { number } } = {}
	for index in work do
		adjacency[index] = {}
	end
	for _, edge in graph.edges do
		table.insert(adjacency[edge.a], edge.b)
		table.insert(adjacency[edge.b], edge.a)
	end
	local seen: { [number]: boolean } = {}
	local function walk(index: number)
		seen[index] = true
		table.insert(layout.route, `work{index}.patrol.1`)
		for _, other in adjacency[index] do
			if not seen[other] then
				walk(other)
				table.insert(layout.route, `work{index}.patrol.1`)
			end
		end
	end
	walk(1)
	-- Harlow walks into the loading bay and back once a loop (only the truck's box is safe): from the room its door
	-- opens into, on the first visit there.
	local patrol = Bay.patrolPoint(bay, side)
	table.insert(
		layout.markers,
		{ id = "bay.patrol.1", room = "bay", kind = "patrol", x = patrol.X, z = patrol.Y, rotation = 0 }
	)
	local entry = table.find(layout.route, `{target.id}.patrol.1`)
	if entry ~= nil then
		table.insert(layout.route, entry + 1, "bay.patrol.1")
		table.insert(layout.route, entry + 2, `{target.id}.patrol.1`)
	end
	local restRoom = work[rng:NextInteger(1, #work)]
	layout.rest = `{restRoom.id}.rest.1`
	table.insert(layout.markers, {
		id = layout.rest,
		room = restRoom.id,
		kind = "rest",
		x = (restRoom.minX + restRoom.maxX) / 2,
		z = (restRoom.minZ + restRoom.maxZ) / 2 + 4,
		rotation = 0,
	})
	return layout
end
return Utils
