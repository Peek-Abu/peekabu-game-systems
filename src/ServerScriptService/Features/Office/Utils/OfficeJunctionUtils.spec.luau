local Junction = require(script.Parent.OfficeJunctionUtils)
local Corridor = require(script.Parent.OfficeCorridorUtils)

local function networkFor(seed)
	return Corridor.network(Random.new(seed))
end

local function allServed(network)
	local served = {}
	for _, room in network.rooms do
		served[room.id] = true
	end
	return served
end

local function room(id, minX, minZ, maxX, maxZ)
	return { id = id, name = id, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ }
end

return function()
	describe("pruneDeadEnds", function()
		it("keeps every corridor room when every room is served", function()
			local network = networkFor(7)
			local alive = Junction.pruneDeadEnds(network, allServed(network))
			for _, corridor in network.rooms do
				expect(alive[corridor.id]).to.equal(true)
			end
		end)

		it("always keeps the dock and lobby junctions", function()
			for seed = 1, 20 do
				local network = networkFor(seed)
				local alive = Junction.pruneDeadEnds(network, {})
				expect(alive[network.dock.id]).to.equal(true)
				expect(alive[network.lobby.id]).to.equal(true)
			end
		end)

		it("names every corridor room, alive or pruned", function()
			local network = networkFor(3)
			local alive = Junction.pruneDeadEnds(network, {})
			for _, corridor in network.rooms do
				expect(alive[corridor.id]).to.be.a("boolean")
			end
		end)
	end)

	describe("junctionEdge", function()
		it("names the junction wall a segment leaves through", function()
			local junction = room("j", 0, 0, 6, 6)
			expect(Junction.junctionEdge(junction, room("e", 6, 0, 20, 6))).to.equal("maxX")
			expect(Junction.junctionEdge(junction, room("w", -14, 0, 0, 6))).to.equal("minX")
			expect(Junction.junctionEdge(junction, room("n", 0, 6, 6, 20))).to.equal("maxZ")
			expect(Junction.junctionEdge(junction, room("s", 0, -14, 6, 0))).to.equal("minZ")
		end)
	end)

	describe("markers", function()
		it("gives every live junction one patrol point", function()
			for seed = 1, 20 do
				local network = networkFor(seed)
				local alive = Junction.pruneDeadEnds(network, {})
				local patrols = 0
				for _, marker in Junction.markers(network, alive) do
					if marker.kind == "patrol" then
						patrols += 1
					end
				end
				local junctions = 0
				for _, corridor in network.rooms do
					if alive[corridor.id] and network.junctions[corridor.id] ~= nil then
						junctions += 1
					end
				end
				expect(patrols).to.equal(junctions)
			end
		end)

		it("puts closets only in live junctions, never the dock or lobby", function()
			for seed = 1, 20 do
				local network = networkFor(seed)
				local alive = Junction.pruneDeadEnds(network, {})
				for _, marker in Junction.markers(network, alive) do
					if marker.kind == "closet" then
						expect(network.junctions[marker.room]).to.be.ok()
						expect(alive[marker.room]).to.equal(true)
						expect(marker.room).never.to.equal(network.dock.id)
						expect(marker.room).never.to.equal(network.lobby.id)
					end
				end
			end
		end)
	end)
end
