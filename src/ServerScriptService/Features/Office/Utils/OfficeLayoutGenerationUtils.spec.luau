local Server = game:GetService("ServerScriptService").Features.Office
local Gen = require(script.Parent.OfficeLayoutGenerationUtils)
local Base = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Rules = require(Server.Rules.OfficeLayoutRules)
local Utils = require(script.Parent.OfficeLayoutUtils)
local Spawn = require(script.Parent.OfficeSpawnUtils)
local SpawnRules = require(Server.Rules.OfficeSpawnRules)
local Constants = require(Server.Data.OfficeConstants)
return function()
	describe("fresh procedural office", function()
		it("creates distinct reproducible occupancy, sizes and connections with 16–24 work rooms", function()
			local signatures, entrances = {}, {}
			for seed = 1, 40 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local layout, again = Gen.generate(Base, seed), Gen.generate(Base, seed)
				local count, signature = 0, {}
				for index, room in layout.rooms do
					expect(room.minX).to.equal(again.rooms[index].minX)
					if room.zone ~= "hallway" and room.id ~= "bay" then
						count += 1
					end
					table.insert(signature, room.id .. ":" .. room.minX .. ":" .. room.maxZ)
				end
				expect(count >= 16 and count <= 24).to.equal(true)
				for _, door in layout.doors do
					table.insert(signature, door.a .. ":" .. door.b)
					if door.a == "bay" then
						entrances[Utils.doorEdge(Utils.room(layout, "bay"), door)] = true
					end
				end
				signatures[table.concat(signature, ";")] = true
			end
			local n, sides = 0, 0
			for _ in signatures do
				n += 1
			end
			for _ in entrances do
				sides += 1
			end
			expect(n >= 30).to.equal(true)
			expect(sides).to.equal(4)
		end)
		it("mixes actual shared-wall room doors with corridor links and smaller varied rooms in every seed", function()
			for seed = 1, 60 do
				if seed % 5 == 0 then
					task.wait()
				end
				local layout = Gen.generate(Base, seed)
				local direct, corridors, dimensions, workRooms = 0, 0, {}, 0
				for _, room in layout.rooms do
					if room.id ~= "bay" and room.zone ~= "hallway" then
						local width, depth = room.maxX - room.minX, room.maxZ - room.minZ
						expect(width >= 30 and width <= 40 and depth >= 28 and depth <= 38).to.equal(true)
						dimensions[width .. ":" .. depth] = true
						workRooms += 1
					elseif room.zone == "hallway" then
						corridors += 1
					end
				end
				for _, door in layout.doors do
					local a, b = Utils.room(layout, door.a), Utils.room(layout, door.b)
					if a.id ~= "bay" and b.id ~= "bay" and a.zone ~= "hallway" and b.zone ~= "hallway" then
						direct += 1
						expect(Utils.doorEdge(a, door) ~= nil and Utils.doorEdge(b, door) ~= nil).to.equal(true)
						expect(a.maxX == b.minX or b.maxX == a.minX or a.maxZ == b.minZ or b.maxZ == a.minZ).to.equal(
							true
						)
					end
				end
				local distinct = 0
				for _ in dimensions do
					distinct += 1
				end
				expect(direct >= 1 and corridors >= 1 and distinct == workRooms).to.equal(true)
			end
		end)
		it("has connected nonoverlapping geometry, cycles and at most four physical cardinal ports", function()
			for seed = 1, 60 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local layout = Gen.generate(Base, seed)
				local ok, errors = Rules.validate(layout)
				if not ok then
					error(table.concat(errors, "\n"))
				end
				expect(#layout.doors >= #layout.rooms).to.equal(true)
				for _, room in layout.rooms do
					local edges = {}
					for _, door in layout.doors do
						if door.a == room.id or door.b == room.id then
							local edge = Utils.doorEdge(room, door)
							expect(edges[edge]).to.equal(nil)
							edges[edge] = true
						end
					end
				end
				local walls = Utils.mergedWallSegments(layout)
				for _, door in layout.doors do
					-- Native radius-2 probes rejected seven-stud collision apertures.
					-- Wall caps intrude half their thickness at either jamb.
					expect(door.width >= 10).to.equal(true)
					expect(door.width - Constants.WALL_THICKNESS >= 9).to.equal(true)
					for _, wall in walls do
						local blocked = if wall.x1 == wall.x2
							then math.abs(door.x - wall.x1) < 0.01 and door.z > wall.z1 and door.z < wall.z2
							else math.abs(door.z - wall.z1) < 0.01 and door.x > wall.x1 and door.x < wall.x2
						expect(blocked).to.equal(false)
					end
				end
			end
		end)
		it("keeps furniture, chairs and truck clear of all physical door approaches", function()
			local sizes = {
				desk = Constants.DESK_SIZE,
				locker = Constants.LOCKER_SIZE,
				shelf = Constants.SHELF_SIZE,
				counter = Constants.COUNTER_SIZE,
				table = Constants.TABLE_SIZE,
				cabinet = Constants.CABINET_SIZE,
				plant = Constants.PLANT_SIZE,
			}
			for seed = 1, 60 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local layout = Gen.generate(Base, seed)
				local function clear(x, z, hx, hz, roomId)
					for _, door in layout.doors do
						if door.a == roomId or door.b == roomId then
							local valid = math.abs(x - door.x) >= hx + door.width / 2 + 2 - 0.001
								or math.abs(z - door.z) >= hz + door.width / 2 + 2 - 0.001
							if not valid then
								error(roomId .. " blocked " .. door.a .. "/" .. door.b .. " at " .. x .. "," .. z)
							end
						end
					end
				end
				for _, marker in layout.markers do
					local size = sizes[marker.kind]
					if size then
						local cosine, sine = math.abs(math.cos(marker.rotation)), math.abs(math.sin(marker.rotation))
						clear(
							marker.x,
							marker.z,
							(size.X * cosine + size.Z * sine) / 2,
							(size.X * sine + size.Z * cosine) / 2,
							marker.room
						)
						if marker.kind == "desk" then
							local yaw = marker.rotation
							clear(
								marker.x - 3.05 * math.sin(yaw),
								marker.z - 3.05 * math.cos(yaw),
								1.14,
								1.14,
								marker.room
							)
						end
					end
				end
				local truck = layout.truck
				-- A wide approach all the way to the bay's central path avoids truck/clock interception.
				local bayDoor = layout.doors[#layout.doors]
				local bay = Utils.room(layout, "bay")
				local edge = Utils.doorEdge(bay, bayDoor)
				expect(truck.maxZ + 6.425 < bay.maxZ - 0.5).to.equal(true)
				expect(truck.minZ - 2 > bay.minZ + 0.5).to.equal(true)
				if edge == "minX" or edge == "maxX" then
					local boundary = if edge == "minX" then truck.minX - bay.minX else bay.maxX - truck.maxX
					expect(boundary >= 20).to.equal(true)
				else
					expect(truck.maxX <= bayDoor.x - 4).to.equal(true)
				end
			end
		end)
		it("preserves capacity, patrol safe-zone and A/B greed/trash/reward guarantees over the seed matrix", function()
			for seed = 1, 60 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local layout = Gen.generate(Base, seed)
				expect(Rules.checkCapacity(layout)).to.equal(true)
				expect(#Utils.markersOf(layout, "counter") >= 16).to.equal(true)
				expect(#Utils.markersOf(layout, "item") >= 64).to.equal(true)
				expect(#Utils.markersOf(layout, "pile") >= 32).to.equal(true)
				expect(Rules.checkRoute(layout)).to.equal(true)
				local plans = {}
				for _, variant in { "A", "B" } do
					local plan = Spawn.roll(
						layout,
						{ quota = 350, variant = variant, piles = Constants.PILES, salvage = Constants.SALVAGE },
						Random.new(seed)
					)
					local ok, reason = SpawnRules.check(plan, layout, 350)
					if not ok then
						error(reason)
					end
					plans[variant] = plan
				end
				expect(Spawn.salvageCount(plans.A)).to.equal(Spawn.salvageCount(plans.B))
			end
		end)
		it("keeps input immutable and map kits local to the selected map", function()
			local selected = table.clone(Base)
			selected.artKit = "alternate-office-kit"
			local count = #Base.rooms
			expect(Gen.generate(selected, 19).artKit).to.equal(selected.artKit)
			expect(#Base.rooms).to.equal(count)
			expect(Base.rooms[1].minX).to.equal(0)
		end)
	end)
end
