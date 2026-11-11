local ServerScriptService = game:GetService("ServerScriptService")

local SchoolNetworkUtils = require(script.Parent.SchoolNetworkUtils)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)

local SEEDS = 200
-- The lattice's edge count (a COLS x ROWS grid).
local LATTICE_EDGES = (SchoolConstants.LATTICE_COLS - 1) * SchoolConstants.LATTICE_ROWS
	+ SchoolConstants.LATTICE_COLS * (SchoolConstants.LATTICE_ROWS - 1)

local function networkFor(seed)
	return SchoolNetworkUtils.network(Random.new(seed))
end

local function overlaps(a, b)
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- The four halls round lattice block (col, row), or nil for each one not drawn.
local function blockHalls(network, col, row)
	return {
		SchoolNetworkUtils.hall(network, { col = col, row = row }, { col = col + 1, row = row }),
		SchoolNetworkUtils.hall(network, { col = col, row = row + 1 }, { col = col + 1, row = row + 1 }),
		SchoolNetworkUtils.hall(network, { col = col, row = row }, { col = col, row = row + 1 }),
		SchoolNetworkUtils.hall(network, { col = col + 1, row = row }, { col = col + 1, row = row + 1 }),
	}
end

-- The rooms reachable from the front junction over the network's doors, among `alive` (all when nil).
local function reachable(network, alive)
	local seen = { [network.front.id] = true }
	local queue = { network.front.id }
	while #queue > 0 do
		local id = table.remove(queue, 1)
		for _, door in network.doors do
			local other = if door.a == id then door.b elseif door.b == id then door.a else nil
			if other ~= nil and not seen[other] and (alive == nil or alive[other]) then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return seen
end

return function()
	describe("School hall network", function()
		it("is seed-stable and varied", function()
			local signatures = {}
			for seed = 1, SEEDS do
				if seed % 20 == 0 then
					task.wait()
				end
				local a, b = networkFor(seed), networkFor(seed)
				expect(#a.rooms).to.equal(#b.rooms)
				expect(#a.doors).to.equal(#b.doors)
				local signature = {}
				for index, room in a.rooms do
					local other = b.rooms[index]
					expect(`{room.id} {room.minX} {room.minZ} {room.maxX} {room.maxZ}`).to.equal(
						`{other.id} {other.minX} {other.minZ} {other.maxX} {other.maxZ}`
					)
					table.insert(signature, `{room.id}:{room.minX}:{room.minZ}`)
				end
				for _, landmark in a.landmarks do
					table.insert(signature, `{landmark.roomType}@{landmark.col},{landmark.row}`)
				end
				signatures[table.concat(signature, ";")] = true
			end
			local distinct = 0
			for _ in signatures do
				distinct += 1
			end
			expect(distinct >= 100).to.equal(true)
		end)

		it(
			"draws the gym and the cafeteria every time and the library about 70% of the time, each in its own block",
			function()
				local libraries = 0
				for seed = 1, SEEDS do
					local network = networkFor(seed)
					local byType, blocks = {}, {}
					for _, landmark in network.landmarks do
						byType[landmark.roomType] = (byType[landmark.roomType] or 0) + 1
						local key = `{landmark.col},{landmark.row}`
						expect(blocks[key]).to.equal(nil)
						blocks[key] = true
						expect(landmark.col >= 1 and landmark.col < SchoolConstants.LATTICE_COLS).to.equal(true)
						expect(landmark.row >= 1 and landmark.row < SchoolConstants.LATTICE_ROWS).to.equal(true)
					end
					expect(byType.gym).to.equal(1)
					expect(byType.cafeteria).to.equal(1)
					expect((byType.library or 0) <= 1).to.equal(true)
					libraries += byType.library or 0
				end
				expect(`libraries {libraries}: {libraries >= SEEDS * 0.55 and libraries <= SEEDS * 0.85}`).to.equal(
					`libraries {libraries}: true`
				)
			end
		)

		it("draws all four halls round every landmark block", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				for _, landmark in network.landmarks do
					local halls = blockHalls(network, landmark.col, landmark.row)
					for side = 1, 4 do
						expect(`seed {seed} {landmark.roomType} side {side} {halls[side] ~= nil}`).to.equal(
							`seed {seed} {landmark.roomType} side {side} true`
						)
					end
				end
			end
		end)

		it("runs a wide spine from the front node on the front row straight back to the last row", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				expect(table.find(SchoolConstants.FRONT_COLS, network.frontCol) ~= nil).to.equal(true)
				expect(network.front.id).to.equal(`hallJ{network.frontCol}_1`)
				expect(#network.spine).to.equal(SchoolConstants.LATTICE_ROWS - 1)
				for row = 1, SchoolConstants.LATTICE_ROWS - 1 do
					local hall = SchoolNetworkUtils.hall(
						network,
						{ col = network.frontCol, row = row },
						{ col = network.frontCol, row = row + 1 }
					)
					expect(hall ~= nil).to.equal(true)
					expect(hall.horizontal).to.equal(false)
					expect(hall.room.maxX - hall.room.minX).to.equal(SchoolConstants.CORRIDOR_WIDE)
					expect(network.spine[row]).to.equal(hall.room.id)
				end
			end
		end)

		it("keeps the outer lines and the front column still and jitters the inner lines a little", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				local jitter = SchoolConstants.LATTICE_JITTER
				for col = 1, SchoolConstants.LATTICE_COLS do
					local base = SchoolConstants.LATTICE_ORIGIN_X + (col - 1) * SchoolConstants.LATTICE_STEP_X
					local still = col == 1 or col == SchoolConstants.LATTICE_COLS or col == network.frontCol
					if still then
						expect(network.lineX[col]).to.equal(base)
					else
						expect(math.abs(network.lineX[col] - base) <= jitter).to.equal(true)
					end
				end
				for row = 1, SchoolConstants.LATTICE_ROWS do
					local base = SchoolConstants.LATTICE_ORIGIN_Z + (row - 1) * SchoolConstants.LATTICE_STEP_Z
					if row == 1 or row == SchoolConstants.LATTICE_ROWS then
						expect(network.lineZ[row]).to.equal(base)
					else
						expect(math.abs(network.lineZ[row] - base) <= jitter).to.equal(true)
					end
				end
			end
		end)

		it("draws HALL_EDGES halls on average and never fewer than the minimum", function()
			local total = 0
			for seed = 1, SEEDS do
				local count = #networkFor(seed).segments
				expect(count >= SchoolConstants.HALL_EDGES.min and count <= LATTICE_EDGES).to.equal(true)
				total += count
			end
			local mean = total / SEEDS
			expect(`mean {mean}: {mean >= SchoolConstants.HALL_EDGES.min and mean <= SchoolConstants.HALL_EDGES.max}`).to.equal(
				`mean {mean}: true`
			)
		end)

		it("is connected: every junction and hall is reachable from the front", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				local seen = reachable(network, nil)
				for _, room in network.rooms do
					expect(`seed {seed} {room.id} {seen[room.id] == true}`).to.equal(`seed {seed} {room.id} true`)
				end
			end
		end)

		it("sizes halls 14 or 10 wide, junctions square and at least JUNCTION_MIN, with no overlaps", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				for _, segment in network.segments do
					local room = segment.room
					local width = if segment.horizontal then room.maxZ - room.minZ else room.maxX - room.minX
					expect(width == SchoolConstants.CORRIDOR_WIDE or width == SchoolConstants.CORRIDOR_NARROW).to.equal(
						true
					)
					expect(room.zone).to.equal("hallway")
					expect(segment.to > segment.from).to.equal(true)
				end
				for _, junction in network.junctions do
					local side = junction.maxX - junction.minX
					expect(side).to.equal(junction.maxZ - junction.minZ)
					expect(side >= SchoolConstants.JUNCTION_MIN).to.equal(true)
					expect(junction.zone).to.equal("hallway")
				end
				for index, a in network.rooms do
					for other = index + 1, #network.rooms do
						local b = network.rooms[other]
						expect(`{a.id}/{b.id} {overlaps(a, b)}`).to.equal(`{a.id}/{b.id} false`)
					end
				end
			end
		end)

		it("joins each hall to its two junctions with open doorways on the walls they share", function()
			for seed = 1, 50 do
				local network = networkFor(seed)
				local byId = {}
				for _, room in network.rooms do
					byId[room.id] = room
				end
				local perSegment = {}
				for _, door in network.doors do
					expect(network.junctions[door.a] ~= nil).to.equal(true)
					expect(door.kind).to.equal("open")
					expect(OfficeLayoutUtils.doorEdge(byId[door.a], door) ~= nil).to.equal(true)
					expect(OfficeLayoutUtils.doorEdge(byId[door.b], door) ~= nil).to.equal(true)
					perSegment[door.b] = (perSegment[door.b] or 0) + 1
				end
				for _, segment in network.segments do
					expect(perSegment[segment.room.id]).to.equal(2)
					local face = if segment.horizontal then segment.room.minX else segment.room.minZ
					expect(face).to.equal(segment.from)
				end
			end
		end)

		it("prunes dead-end stubs that serve no room, and keeps every served hall and the front", function()
			for seed = 1, SEEDS do
				local network = networkFor(seed)
				-- Serve a seeded half of the halls.
				local rng = Random.new(seed + 1000)
				local served = {}
				for _, segment in network.segments do
					if rng:NextNumber() < 0.5 then
						served[segment.room.id] = true
					end
				end
				local alive = SchoolNetworkUtils.prune(network, served)
				expect(alive[network.front.id]).to.equal(true)
				for id in served do
					expect(`seed {seed} {id} {alive[id] == true}`).to.equal(`seed {seed} {id} true`)
				end
				-- Still connected, and no live junction but the front is a dead end onto an unserved hall.
				local seen = reachable(network, alive)
				for id, live in alive do
					if live then
						expect(`seed {seed} {id} reached {seen[id] == true}`).to.equal(`seed {seed} {id} reached true`)
					end
				end
				for id, _ in network.junctions do
					if alive[id] and id ~= network.front.id then
						local links = {}
						for _, door in network.doors do
							if door.a == id and alive[door.b] then
								table.insert(links, door.b)
							end
						end
						if #links == 1 then
							expect(`seed {seed} {id} stub {served[links[1]] == true}`).to.equal(
								`seed {seed} {id} stub true`
							)
						end
					end
				end
			end
		end)

		it("prunes nothing when every hall serves a room", function()
			for seed = 1, 50 do
				local network = networkFor(seed)
				local served = {}
				for _, segment in network.segments do
					served[segment.room.id] = true
				end
				local alive = SchoolNetworkUtils.prune(network, served)
				for _, room in network.rooms do
					expect(alive[room.id]).to.equal(true)
				end
			end
		end)
	end)
end
