--!strict
-- Seeded modular wing attached to the authored archive. The loading bay/core remain stable.
local Server = game:GetService("ServerScriptService").Features.Office
local Types = require(Server.Data.OfficeTypes)
local Utils = {}
function Utils.generate(base: Types.Layout, seed: number): Types.Layout
	local rng = Random.new(seed)
	local layout: Types.Layout = {
		startRoom = base.startRoom,
		rooms = {},
		doors = {},
		markers = {},
		truck = table.clone(base.truck),
		route = table.clone(base.route),
		rest = base.rest,
	}
	for _, room in base.rooms do
		table.insert(layout.rooms, table.clone(room))
	end
	for _, door in base.doors do
		table.insert(layout.doors, table.clone(door))
	end
	for _, marker in base.markers do
		table.insert(layout.markers, table.clone(marker))
	end
	local corridorX = 130 + rng:NextInteger(12, 16)
	local wingX = corridorX + rng:NextInteger(24, 32)
	table.insert(
		layout.rooms,
		{ id = "service", name = "Service corridor", minX = 130, minZ = 0, maxX = corridorX, maxZ = 90 }
	)
	table.insert(layout.doors, { a = "archive", b = "service", x = 130, z = 20, width = 8 })
	local names = { "Meeting room", "Accounts", "Training room", "Supply room" }
	local bottom = 0
	local previous: string? = nil
	for index, name in names do
		local top = if index == 4 then 90 else index * 22 + rng:NextInteger(-3, 3)
		local id = `wing{index}`
		local middle = (bottom + top) / 2
		table.insert(layout.rooms, { id = id, name = name, minX = corridorX, minZ = bottom, maxX = wingX, maxZ = top })
		table.insert(
			layout.doors,
			{ a = "service", b = id, x = corridorX, z = middle + rng:NextInteger(-2, 2), width = 8 }
		)
		if previous ~= nil then
			table.insert(layout.doors, { a = previous, b = id, x = (corridorX + wingX) / 2, z = bottom, width = 8 })
		end
		local function marker(kind: Types.MarkerKind, n: number, x: number, z: number)
			table.insert(layout.markers, { id = `{id}.{kind}.{n}`, room = id, kind = kind, x = x, z = z })
		end
		for n = 1, 3 do
			local x = corridorX + 5 + (n - 1) * 7
			marker("pile", n, x, bottom + 5)
			marker("item", n, x, top - 5)
			marker("item", n + 3, x, middle)
		end
		marker("desk", 1, wingX - 4, top - 10)
		marker("patrol", 1, corridorX + 3, middle + 3)
		table.insert(layout.route, `{id}.patrol.1`)
		previous = id
		bottom = top
	end
	return layout
end
return Utils
