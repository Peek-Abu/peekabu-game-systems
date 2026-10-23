local Server = game:GetService("ServerScriptService").Features.Office
local Gen = require(script.Parent.OfficeLayoutGenerationUtils)
local Base = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Rules = require(Server.Rules.OfficeLayoutRules)
local Utils = require(script.Parent.OfficeLayoutUtils)
local Spawn = require(script.Parent.OfficeSpawnUtils)
local SpawnRules = require(Server.Rules.OfficeSpawnRules)
local Constants = require(Server.Data.OfficeConstants)
local ShiftConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Shift.Data.ShiftConstants)
-- The biggest crew's contract (Gloom): every generated office must be able to meet it.
local CONTRACT = ShiftConstants.QUOTA_BY_CREW[#ShiftConstants.QUOTA_BY_CREW]
local SEEDS = 200

local function overlaps(a, b)
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- Generated once per seed for the whole file (the specs below only read the layouts).
local cache = {}
local function layoutFor(seed)
	local layout = cache[seed]
	if layout == nil then
		layout = Gen.generate(Base, seed)
		cache[seed] = layout
	end
	return layout
end

local function isKit(room)
	return room.zone ~= "hallway" and room.id ~= "bay"
end

return function()
	describe("kit-room office generator", function()
		it("is deterministic and varied", function()
			local signatures = {}
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout, again = Gen.generate(Base, seed), Gen.generate(Base, seed)
				expect(#layout.rooms).to.equal(#again.rooms)
				local signature = {}
				for index, room in layout.rooms do
					expect(room.id).to.equal(again.rooms[index].id)
					expect(room.minX).to.equal(again.rooms[index].minX)
					expect(room.minZ).to.equal(again.rooms[index].minZ)
					table.insert(signature, `{room.id}:{room.kit}:{room.minX}:{room.minZ}`)
				end
				signatures[table.concat(signature, ";")] = true
			end
			local distinct = 0
			for _ in signatures do
				distinct += 1
			end
			expect(distinct >= 30).to.equal(true)
		end)

		it("passes every layout rule on every seed", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local ok, errors = Rules.validate(layout)
				if not ok then
					error(`seed {seed}: {table.concat(errors, "; ")}`)
				end
				local checks = {
					{ "capacity", Rules.checkCapacity(layout) },
					{ "route", Rules.checkRoute(layout) },
					{ "hide spots", Rules.checkHideSpots(layout) },
					{ "walk", Rules.checkWalk(layout, 640) },
				}
				for _, check in checks do
					if not check[2] then
						error(`seed {seed}: {check[1]} failed`)
					end
				end
				local _, walk = Rules.checkWalk(layout, Constants.WALK_SPEED * Constants.MAX_WALK_SECONDS)
				expect(walk).to.equal(nil)
			end
		end)

		it("holds 14-20 kit rooms: one server room, one reception, at least one breakout, 4+ kit ids", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local total, byType, kits = 0, {}, {}
				for _, room in layout.rooms do
					if isKit(room) then
						total += 1
						expect(room.kit ~= nil).to.equal(true)
						expect(room.floor).to.equal(1)
						byType[room.roomType] = (byType[room.roomType] or 0) + 1
						kits[room.kit] = true
					end
				end
				expect(total >= Constants.KIT_ROOMS.min and total <= Constants.KIT_ROOMS.max).to.equal(true)
				expect(byType.server).to.equal(1)
				expect(byType.reception).to.equal(1)
				expect((byType.breakout or 0) >= 1).to.equal(true)
				local distinct = 0
				for _ in kits do
					distinct += 1
				end
				expect(distinct >= 4).to.equal(true)
			end
		end)

		it(
			"mixes the room types: desk pods are at least a quarter of the kit rooms over seeds 1-50, conference at most 40%",
			function()
				local pods, conference, total = 0, 0, 0
				for seed = 1, 50 do
					if seed % 10 == 0 then
						task.wait()
					end
					for _, room in layoutFor(seed).rooms do
						if room.kit ~= nil then
							total += 1
							pods += if room.roomType == "pods" then 1 else 0
							conference += if room.roomType == "conference" then 1 else 0
						end
					end
				end
				expect(`pods {pods}/{total}: {pods >= total * 0.25}`).to.equal(`pods {pods}/{total}: true`)
				expect(`conference {conference}/{total}: {conference <= total * 0.4}`).to.equal(
					`conference {conference}/{total}: true`
				)
			end
		)

		it("gives every kit room exactly one door, onto a hallway, on a wall they share", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				for _, room in layout.rooms do
					if isKit(room) then
						local count = 0
						for _, door in layout.doors do
							if door.a == room.id or door.b == room.id then
								count += 1
								local other = Utils.room(layout, if door.a == room.id then door.b else door.a)
								expect(other.zone).to.equal("hallway")
								expect(Utils.doorEdge(room, door) ~= nil).to.equal(true)
								expect(Utils.doorEdge(other, door) ~= nil).to.equal(true)
							end
						end
						expect(count).to.equal(1)
					end
				end
			end
		end)

		it("lays every glass pane on a hallway room's edge, so no window shows the outside", function()
			local EPS = 1e-6
			local total = 0
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				for _, pane in layout.panes or {} do
					total += 1
					expect(pane.x1 <= pane.x2 and pane.z1 <= pane.z2).to.equal(true)
					local length = (pane.x2 - pane.x1) + (pane.z2 - pane.z1)
					expect(length >= 2 - EPS).to.equal(true)
					local onHallway = false
					for _, room in layout.rooms do
						if room.zone == "hallway" then
							if math.abs(pane.z1 - pane.z2) < EPS then
								onHallway = onHallway
									or (
										(math.abs(pane.z1 - room.minZ) < EPS or math.abs(pane.z1 - room.maxZ) < EPS)
										and pane.x1 >= room.minX - EPS
										and pane.x2 <= room.maxX + EPS
									)
							elseif math.abs(pane.x1 - pane.x2) < EPS then
								onHallway = onHallway
									or (
										(math.abs(pane.x1 - room.minX) < EPS or math.abs(pane.x1 - room.maxX) < EPS)
										and pane.z1 >= room.minZ - EPS
										and pane.z2 <= room.maxZ + EPS
									)
							end
						end
					end
					if not onHallway then
						error(
							`seed {seed}: pane ({pane.x1}, {pane.z1})-({pane.x2}, {pane.z2}) is not on a hallway edge`
						)
					end
				end
			end
			-- Conference rooms carry glass; the seeds must actually exercise it.
			expect(total > 0).to.equal(true)
		end)

		it("places the reception identically on every seed, with the entrance behind it", function()
			local first = nil
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local reception = nil
				for _, room in layout.rooms do
					if room.roomType == "reception" then
						reception = room
					end
				end
				if first == nil then
					first = reception
				end
				expect(reception.minX).to.equal(first.minX)
				expect(reception.minZ).to.equal(first.minZ)
				expect(reception.maxX).to.equal(first.maxX)
				expect(reception.maxZ).to.equal(first.maxZ)
				local entrances = 0
				for _, facade in layout.facades or {} do
					if facade.kind == "entrance" then
						entrances += 1
						expect(facade.room).to.equal(reception.id)
						expect(facade.x).to.equal(reception.minX)
						expect(facade.width).to.equal(12)
					end
				end
				expect(entrances).to.equal(1)
			end
		end)

		it("puts one stairwell facade on a junction wall with nothing behind it", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local stairwells = 0
				for _, facade in layout.facades or {} do
					if facade.kind == "stairwell" then
						stairwells += 1
						local junction = Utils.room(layout, facade.room)
						expect(junction.zone).to.equal("hallway")
						for _, closet in Utils.markersOf(layout, "closet") do
							expect(closet.room ~= junction.id).to.equal(true)
						end
						-- A 6 x 4 probe on the outside of the junction's wall touches no room.
						local probe
						if facade.x == junction.minX then
							probe = { minX = facade.x - 4, maxX = facade.x, minZ = facade.z - 3, maxZ = facade.z + 3 }
						elseif facade.x == junction.maxX then
							probe = { minX = facade.x, maxX = facade.x + 4, minZ = facade.z - 3, maxZ = facade.z + 3 }
						elseif facade.z == junction.minZ then
							probe = { minX = facade.x - 3, maxX = facade.x + 3, minZ = facade.z - 4, maxZ = facade.z }
						else
							expect(facade.z).to.equal(junction.maxZ)
							probe = { minX = facade.x - 3, maxX = facade.x + 3, minZ = facade.z, maxZ = facade.z + 4 }
						end
						for _, room in layout.rooms do
							expect(overlaps(probe, room)).to.equal(false)
						end
						expect(facade.width).to.equal(6)
					end
				end
				expect(stairwells).to.equal(1)
			end
		end)

		it("totals about the measured floor area, hallways included and the bay left out", function()
			local sum = 0
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				for _, room in layoutFor(seed).rooms do
					if room.id ~= "bay" then
						sum += (room.maxX - room.minX) * (room.maxZ - room.minZ)
					end
				end
			end
			local mean = sum / SEEDS
			expect(math.abs(mean - Constants.TARGET_FLOOR_AREA) <= Constants.TARGET_FLOOR_AREA * 0.3).to.equal(true)
		end)

		it("prunes dead-end corridors that serve no room and stands a closet in each dead end left", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local degree = {}
				for _, door in layout.doors do
					local a, b = Utils.room(layout, door.a), Utils.room(layout, door.b)
					if a.zone == "hallway" and b.zone == "hallway" then
						degree[a.id] = (degree[a.id] or 0) + 1
						degree[b.id] = (degree[b.id] or 0) + 1
					end
				end
				local closets = {}
				for _, marker in Utils.markersOf(layout, "closet") do
					closets[marker.room] = true
				end
				for _, room in layout.rooms do
					if string.sub(room.id, 1, 5) == "hallJ" and degree[room.id] == 1 then
						local lobby = room.id == "hallJ1_3"
						local dock = room.id == "hallJ3_1"
						if not lobby and not dock then
							expect(closets[room.id]).to.equal(true)
						end
					end
				end
			end
		end)

		it("patrols every junction and rests in the first breakout", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				for _, room in layout.rooms do
					if string.sub(room.id, 1, 5) == "hallJ" then
						-- A tight dead end's patrol point lies in its corridor piece instead.
						local own = Utils.marker(layout, `{room.id}.patrol.1`)
						if own == nil then
							local closet = Utils.marker(layout, `{room.id}.closet.1`)
							expect(closet ~= nil).to.equal(true)
							local found = false
							for _, door in layout.doors do
								local other = if door.a == room.id
									then door.b
									elseif door.b == room.id then door.a
									else nil
								if other ~= nil and Utils.marker(layout, `{other}.patrol.1`) ~= nil then
									found = true
								end
							end
							expect(found).to.equal(true)
						end
					end
				end
				expect(string.match(layout.rest, "^breakout%d+%.rest%.1$") ~= nil).to.equal(true)
				expect(Utils.marker(layout, layout.rest) ~= nil).to.equal(true)
				local bayVisits = 0
				for index, id in layout.route do
					if id == "bay.patrol.1" then
						bayVisits += 1
						expect(layout.route[index - 1]).to.equal(layout.route[index + 1])
					end
				end
				expect(bayVisits).to.equal(1)
			end
		end)

		it("keeps every patrol point 2 studs clear of every closet", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				for _, closet in Utils.markersOf(layout, "closet") do
					local yaw = closet.rotation or 0
					local cosine, sine = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
					local halfX = (Constants.CLOSET_SIZE.X * cosine + Constants.CLOSET_SIZE.Z * sine) / 2
					local halfZ = (Constants.CLOSET_SIZE.X * sine + Constants.CLOSET_SIZE.Z * cosine) / 2
					for _, patrol in Utils.markersOf(layout, "patrol") do
						local dx = math.max(math.abs(patrol.x - closet.x) - halfX, 0)
						local dz = math.max(math.abs(patrol.z - closet.z) - halfZ, 0)
						if math.sqrt(dx * dx + dz * dz) < 2 then
							error(`seed {seed}: {patrol.id} is within 2 studs of {closet.id}`)
						end
					end
				end
			end
		end)

		it("gives every room a depth from its walk, with loot both shallow and deep", function()
			local shallow, deep = 0, 0
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local walked = Utils.walkDistances(layout)
				local depths = Utils.depths(layout)
				for _, room in layout.rooms do
					expect(room.depth).to.equal(math.floor(walked[room.id] / Constants.DEPTH_STUDS))
					expect(depths[room.id]).to.equal(room.depth)
				end
				expect(depths.bay).to.equal(0)
				for _, marker in Utils.markersOf(layout, "item") do
					local depth = depths[marker.room]
					shallow += if depth <= 1 then 1 else 0
					deep += if depth >= Constants.DEEP_DEPTH then 1 else 0
				end
			end
			expect(shallow > 0 and deep > 0).to.equal(true)
		end)

		it("rolls spawns that meet the biggest crew's contract on every seed", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				for _, variant in { "A", "B" } do
					-- Mirrors OfficeServiceServer's rollPlan: roll seeds seed, seed + 1, ... until one meets the contract.
					local failure
					local met = false
					for attempt = 0, Constants.ROLL_ATTEMPTS - 1 do
						local plan = Spawn.roll(layout, {
							quota = CONTRACT,
							variant = variant,
							dirtyRooms = Constants.DIRTY_ROOMS,
							pilesPerRoom = Constants.PILES_PER_ROOM,
							valuables = Constants.VALUABLES,
						}, Random.new(seed + attempt))
						local ok, reason = SpawnRules.check(plan, layout, CONTRACT)
						if ok then
							met = true
							break
						end
						failure = reason
					end
					if not met then
						error(`seed {seed}: {failure}`)
					end
				end
			end
		end)

		it("keeps the input immutable and always selects the generated art kit", function()
			local selected = table.clone(Base)
			selected.artKit = "alternate-office-kit"
			local count = #Base.rooms
			expect(Gen.generate(selected, 19).artKit).to.equal(Constants.GENERATED_ART_KIT)
			expect(selected.artKit).to.equal("alternate-office-kit")
			expect(#Base.rooms).to.equal(count)
			expect(Base.rooms[1].minX).to.equal(0)
		end)
	end)
end
