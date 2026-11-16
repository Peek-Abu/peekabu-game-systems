local Lining = require(script.Parent.OfficeRoomLiningUtils)
local Corridor = require(script.Parent.OfficeCorridorUtils)

local function room(id, minX, minZ, maxX, maxZ, roomType)
	return { id = id, name = id, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ, roomType = roomType }
end

-- A fresh attempt's Build over `network`, the way OfficeLayoutGenerationUtils starts one.
local function buildFor(network, rng)
	local box = { id = "box", name = "box", minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, corridor in network.rooms do
		box.minX, box.maxX = math.min(box.minX, corridor.minX), math.max(box.maxX, corridor.maxX)
		box.minZ, box.maxZ = math.min(box.minZ, corridor.minZ), math.max(box.maxZ, corridor.maxZ)
	end
	return {
		rng = rng,
		layout = { rooms = {}, doors = {}, markers = {} },
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
end

return function()
	describe("overlaps", function()
		it("is true only when two rooms share area", function()
			expect(Lining.overlaps(room("a", 0, 0, 10, 10), room("b", 5, 5, 15, 15))).to.equal(true)
			expect(Lining.overlaps(room("a", 0, 0, 10, 10), room("b", 10, 0, 20, 10))).to.equal(false)
			expect(Lining.overlaps(room("a", 0, 0, 10, 10), room("b", 0, 20, 10, 30))).to.equal(false)
		end)
	end)

	describe("commit", function()
		it("records the room, its door and markers, and clears the matching need", function()
			local build = buildFor({ rooms = {} }, Random.new(1))
			local server = room("server1", 0, 0, 10, 10, "server")
			local door = { a = "server1", b = "hallS1", x = 5, z = 0, width = 4 }
			local marker = { id = "server1.patrol.1", room = "server1", kind = "patrol", x = 5, z = 5 }
			Lining.commit(build, server, door, { marker })
			expect(build.layout.rooms[1]).to.equal(server)
			expect(build.solid[1]).to.equal(server)
			expect(build.layout.doors[1]).to.equal(door)
			expect(build.layout.markers[1]).to.equal(marker)
			expect(build.needServer).to.equal(false)
			expect(build.needBreakout).to.equal(true)
		end)
	end)

	describe("lineSegments", function()
		it("places no more rooms than wanted, none overlapping a corridor or another room", function()
			for seed = 1, 10 do
				local rng = Random.new(seed)
				local network = Corridor.network(rng)
				local build = buildFor(network, rng)
				Lining.lineSegments(build, network, 8)
				expect(build.placed <= 8).to.equal(true)
				expect(#build.layout.rooms).to.equal(build.placed)
				for index, placed in build.layout.rooms do
					for _, corridor in network.rooms do
						expect(Lining.overlaps(placed, corridor)).to.equal(false)
					end
					for other = index + 1, #build.layout.rooms do
						expect(Lining.overlaps(placed, build.layout.rooms[other])).to.equal(false)
					end
				end
			end
		end)

		it("gives every placed room a door onto a corridor", function()
			local rng = Random.new(7)
			local network = Corridor.network(rng)
			local build = buildFor(network, rng)
			Lining.lineSegments(build, network, 8)
			expect(#build.layout.doors).to.equal(build.placed)
			local corridors = {}
			for _, corridor in network.rooms do
				corridors[corridor.id] = true
			end
			for _, door in build.layout.doors do
				expect(corridors[door.b]).to.equal(true)
			end
		end)

		it("replays the same rooms from the same seed", function()
			local function ids(seed)
				local rng = Random.new(seed)
				local network = Corridor.network(rng)
				local build = buildFor(network, rng)
				Lining.lineSegments(build, network, 8)
				local out = {}
				for _, placed in build.layout.rooms do
					table.insert(out, `{placed.id}@{placed.minX},{placed.minZ}`)
				end
				return table.concat(out, " ")
			end
			expect(ids(11)).to.equal(ids(11))
		end)
	end)
end
