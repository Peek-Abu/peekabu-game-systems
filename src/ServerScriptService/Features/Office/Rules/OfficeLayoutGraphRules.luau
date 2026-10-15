--!strict
-- Randomized cardinal connectivity for a connected irregular workplace footprint.
local Rules = {}
export type Node = { col: number, row: number }
export type Edge = { a: number, b: number }
export type Graph = { nodes: { Node }, edges: { Edge } }
local function key(col: number, row: number): string
	return `{col}:{row}`
end
function Rules.generate(rng: Random): Graph
	local nodes: { Node } = { { col = 2, row = 2 }, { col = 3, row = 2 }, { col = 2, row = 3 }, { col = 3, row = 3 } }
	local occupied: { [string]: number } = {}
	for index, node in nodes do
		occupied[key(node.col, node.row)] = index
	end
	local count = rng:NextInteger(16, 24)
	local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	while #nodes < count do
		local frontier: { Node } = {}
		local seen: { [string]: boolean } = {}
		for _, node in nodes do
			for _, direction in directions do
				local col, row = node.col + direction[1], node.row + direction[2]
				local id = key(col, row)
				if col >= 1 and col <= 5 and row >= 1 and row <= 5 and occupied[id] == nil and not seen[id] then
					seen[id] = true
					table.insert(frontier, { col = col, row = row })
				end
			end
		end
		local node = frontier[rng:NextInteger(1, #frontier)]
		table.insert(nodes, node)
		occupied[key(node.col, node.row)] = #nodes
	end
	local candidates: { Edge } = {}
	for index, node in nodes do
		for _, direction in { { 1, 0 }, { 0, 1 } } do
			local other = occupied[key(node.col + direction[1], node.row + direction[2])]
			if other ~= nil then
				table.insert(candidates, { a = index, b = other })
			end
		end
	end
	for index = #candidates, 2, -1 do
		local swap = rng:NextInteger(1, index)
		candidates[index], candidates[swap] = candidates[swap], candidates[index]
	end
	local roots: { number } = {}
	for index in nodes do
		roots[index] = index
	end
	local function root(index: number): number
		while roots[index] ~= index do
			index = roots[index]
		end
		return index
	end
	local edges: { Edge } = {}
	local extras: { Edge } = {}
	for _, edge in candidates do
		local a, b = root(edge.a), root(edge.b)
		if a ~= b then
			roots[a] = b
			table.insert(edges, edge)
		else
			table.insert(extras, edge)
		end
	end
	-- At least one cycle; the dense connected polyomino always supplies surplus adjacency.
	local cycles = math.min(#extras, rng:NextInteger(2, 5))
	assert(cycles > 0, "office footprint must admit a corridor loop")
	for index = 1, cycles do
		table.insert(edges, extras[index])
	end
	return { nodes = nodes, edges = edges }
end
return Rules
