local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)
local OfficeCorridorUtils = require(script.Parent.OfficeCorridorUtils)
local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)

local SEEDS = 100

local function overlaps(a, b)
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

local function roomsById(network)
	local byId = {}
	for _, room in network.rooms do
		byId[room.id] = room
	end
	return byId
end

local function junctionCount(network)
	local n = 0
	for _ in network.junctions do
		n += 1
	end
	return n
end

local function eachSeed(check)
	for seed = 1, SEEDS do
		check(seed, OfficeCorridorUtils.network(Random.new(seed)))
		if seed % 10 == 0 then
			task.wait()
		end
	end
end

return function()
	it("is deterministic per seed", function()
		for seed = 1, 20 do
			local a = OfficeCorridorUtils.network(Random.new(seed))
			local b = OfficeCorridorUtils.network(Random.new(seed))
			expect(#a.rooms).to.equal(#b.rooms)
			expect(#a.doors).to.equal(#b.doors)
			for i, room in a.rooms do
				expect(room.id).to.equal(b.rooms[i].id)
				expect(room.minX).to.equal(b.rooms[i].minX)
				expect(room.maxZ).to.equal(b.rooms[i].maxZ)
			end
		end
	end)

	it("makes hallway rooms on the office floor with no overlaps", function()
		eachSeed(function(seed, network)
			for i, a in network.rooms do
				expect(a.zone).to.equal("hallway")
				expect(a.floor).to.equal(OfficeConstants.FLOOR_NUMBER)
				expect(a.minX < a.maxX and a.minZ < a.maxZ).to.equal(true)
				for j = i + 1, #network.rooms do
					if overlaps(a, network.rooms[j]) then
						error(`seed {seed}: {a.id} overlaps {network.rooms[j].id}`)
					end
				end
			end
		end)
	end)

	it("puts every door on a wall both its rooms share", function()
		eachSeed(function(seed, network)
			local byId = roomsById(network)
			for _, door in network.doors do
				expect(door.kind).to.equal("open")
				local a, b = byId[door.a], byId[door.b]
				expect(a).to.be.ok()
				expect(b).to.be.ok()
				expect(OfficeLayoutUtils.doorEdge(a, door)).to.be.ok()
				expect(OfficeLayoutUtils.doorEdge(b, door)).to.be.ok()
			end
		end)
	end)

	it("connects every corridor room to the dock", function()
		eachSeed(function(seed, network)
			local seen = { [network.dock.id] = true }
			local queue = { network.dock.id }
			local head = 1
			while head <= #queue do
				local current = queue[head]
				head += 1
				for _, door in network.doors do
					local other = if door.a == current then door.b elseif door.b == current then door.a else nil
					if other ~= nil and not seen[other] then
						seen[other] = true
						table.insert(queue, other)
					end
				end
			end
			for _, room in network.rooms do
				if not seen[room.id] then
					error(`seed {seed}: {room.id} unreachable`)
				end
			end
			expect(seen[network.lobby.id]).to.equal(true)
		end)
	end)

	it("keeps the dock and lobby fixed across seeds", function()
		local first = OfficeCorridorUtils.network(Random.new(1))
		eachSeed(function(seed, network)
			for _, pair in { { network.dock, first.dock }, { network.lobby, first.lobby } } do
				expect(pair[1].id).to.equal(pair[2].id)
				expect(pair[1].minX).to.equal(pair[2].minX)
				expect(pair[1].maxX).to.equal(pair[2].maxX)
				expect(pair[1].minZ).to.equal(pair[2].minZ)
				expect(pair[1].maxZ).to.equal(pair[2].maxZ)
			end
		end)
	end)

	it("has 9 to 14 segments and at least one cycle", function()
		eachSeed(function(seed, network)
			local edges = #network.segments
			expect(edges >= OfficeConstants.CORRIDOR_EDGES.min).to.equal(true)
			expect(edges <= OfficeConstants.CORRIDOR_EDGES.max + OfficeConstants.LOOPS.max).to.equal(true)
			expect(edges >= junctionCount(network)).to.equal(true)
		end)
	end)

	it("keeps the dock-to-lobby spine wide", function()
		eachSeed(function(seed, network)
			local byId = roomsById(network)
			expect(#network.spine > 0).to.equal(true)
			for _, id in network.spine do
				local room = byId[id]
				local width = math.min(room.maxX - room.minX, room.maxZ - room.minZ)
				expect(width).to.equal(OfficeConstants.CORRIDOR_WIDE)
			end
		end)
	end)

	it("spans segments between junction faces and lists degree-1 junctions as leaves", function()
		eachSeed(function(seed, network)
			for _, segment in network.segments do
				expect(segment.from < segment.to).to.equal(true)
				local room = segment.room
				if segment.horizontal then
					expect(room.minX).to.equal(segment.from)
					expect(room.maxX).to.equal(segment.to)
				else
					expect(room.minZ).to.equal(segment.from)
					expect(room.maxZ).to.equal(segment.to)
				end
			end
			for _, leaf in network.leaves do
				expect(leaf).never.to.equal(network.dock)
				expect(leaf).never.to.equal(network.lobby)
				local degree = 0
				for _, door in network.doors do
					if door.a == leaf.id or door.b == leaf.id then
						degree += 1
					end
				end
				expect(degree).to.equal(1)
			end
		end)
	end)

	it("mixes widths and usually builds an atrium", function()
		local widths = {}
		local atriums = 0
		eachSeed(function(seed, network)
			for _, segment in network.segments do
				local room = segment.room
				widths[math.min(room.maxX - room.minX, room.maxZ - room.minZ)] = true
			end
			for _, room in network.junctions do
				if room.name == "Atrium" then
					atriums += 1
					expect(room.maxX - room.minX).to.equal(OfficeConstants.ATRIUM_SIZE)
				end
			end
		end)
		expect(widths[OfficeConstants.CORRIDOR_WIDE]).to.equal(true)
		expect(widths[OfficeConstants.CORRIDOR_NARROW]).to.equal(true)
		expect(atriums >= 80).to.equal(true)
	end)
end
