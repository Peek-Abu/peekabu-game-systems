local ServerScriptService = game:GetService("ServerScriptService")

local Office = ServerScriptService.Features.Office
local Gen = require(script.Parent.SchoolLayoutGenerationUtils)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local Base = require(Office.Data.OfficeLayoutConstants).LAYOUT
local OfficeConstants = require(Office.Data.OfficeConstants)
local Rules = require(Office.Rules.OfficeLayoutRules)
local Utils = require(Office.Utils.OfficeLayoutUtils)
local Spawn = require(Office.Utils.OfficeSpawnUtils)
local SpawnRules = require(Office.Rules.OfficeSpawnRules)
local ShiftConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Shift.Data.ShiftConstants)
-- The biggest crew's contract (Gloom): every generated School must be able to meet it, as the Office does.
local CONTRACT = ShiftConstants.QUOTA_BY_CREW[#ShiftConstants.QUOTA_BY_CREW]

local SEEDS = 50
local LANDMARKS = { gym = true, cafeteria = true, library = true }
local CLASSROOM_KITS = { classroom_rows = true, classroom_groups = true }

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

local function doorsOf(layout, roomId)
	local found = {}
	for _, door in layout.doors do
		if door.a == roomId or door.b == roomId then
			table.insert(found, door)
		end
	end
	return found
end

return function()
	describe("procedural School generator", function()
		it("is deterministic and varied", function()
			local signatures = {}
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout, again = layoutFor(seed), Gen.generate(Base, seed)
				expect(#layout.rooms).to.equal(#again.rooms)
				expect(#layout.markers).to.equal(#again.markers)
				local signature = {}
				for index, room in layout.rooms do
					local other = again.rooms[index]
					expect(`{room.id} {room.minX} {room.minZ}`).to.equal(`{other.id} {other.minX} {other.minZ}`)
					table.insert(signature, `{room.id}:{room.kit}:{room.minX}:{room.minZ}`)
				end
				signatures[table.concat(signature, ";")] = true
			end
			local distinct = 0
			for _ in signatures do
				distinct += 1
			end
			expect(distinct >= 40).to.equal(true)
		end)

		it("passes every layout rule, the capacity, route, hide-spot and walk checks on every seed", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				local ok, errors = Rules.validate(layout)
				if not ok then
					error(`seed {seed}: {table.concat(errors, "; ")}`)
				end
				local limit = OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS
				local checks = {
					{ "capacity", Rules.checkCapacity(layout) },
					{ "route", Rules.checkRoute(layout) },
					{ "hide spots", Rules.checkHideSpots(layout) },
					{ "walk", Rules.checkWalk(layout, limit) },
				}
				for _, check in checks do
					expect(`seed {seed} {check[1]} {check[2]}`).to.equal(`seed {seed} {check[1]} true`)
				end
			end
		end)

		it("holds one gym, one cafeteria, at most one library, one lounge and enough classrooms", function()
			for seed = 1, SEEDS do
				local byType, classrooms = {}, 0
				for _, room in layoutFor(seed).rooms do
					if room.roomType ~= nil then
						byType[room.roomType] = (byType[room.roomType] or 0) + 1
					end
					if room.kit ~= nil and CLASSROOM_KITS[room.kit] then
						classrooms += 1
					end
				end
				local tag = `seed {seed}`
				expect(`{tag} gym {byType.gym}`).to.equal(`{tag} gym 1`)
				expect(`{tag} cafeteria {byType.cafeteria}`).to.equal(`{tag} cafeteria 1`)
				expect(`{tag} library {(byType.library or 0) <= 1}`).to.equal(`{tag} library true`)
				expect(`{tag} lounge {byType.lounge}`).to.equal(`{tag} lounge 1`)
				expect(`{tag} front hall {byType.fronthall}`).to.equal(`{tag} front hall 1`)
				expect(`{tag} classrooms {classrooms >= SchoolConstants.CLASSROOMS_MIN}`).to.equal(
					`{tag} classrooms true`
				)
			end
		end)

		it("deals each small room at most as often as the deck holds it", function()
			local deck = {}
			for _, id in SchoolConstants.DECK do
				deck[id] = (deck[id] or 0) + 1
			end
			for seed = 1, SEEDS do
				local placed = {}
				for _, room in layoutFor(seed).rooms do
					if room.kit ~= nil and deck[room.kit] ~= nil then
						placed[room.kit] = (placed[room.kit] or 0) + 1
					end
				end
				for id, count in placed do
					expect(`seed {seed} {id} {count <= deck[id]}`).to.equal(`seed {seed} {id} true`)
				end
			end
		end)

		it("has at least 8 hiding places and a patrol route, and rests in the lounge", function()
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				local hides = #Utils.markersOf(layout, "desk") + #Utils.markersOf(layout, "closet")
				expect(hides >= 8).to.equal(true)
				expect(#layout.route > 0).to.equal(true)
				local rest = Utils.marker(layout, layout.rest)
				expect(rest ~= nil and rest.kind).to.equal("rest")
				expect(Utils.room(layout, rest.room).roomType).to.equal("lounge")
				for _, id in layout.route do
					expect(Utils.marker(layout, id).kind).to.equal("patrol")
				end
			end
		end)

		it("never overlaps two rooms, and keeps every room inside the exterior shell", function()
			local envelope = OfficeConstants.OUTSIDE.ENVELOPE
			for seed = 1, SEEDS do
				local rooms = layoutFor(seed).rooms
				for index, a in rooms do
					expect(
						a.minX >= envelope.minX
							and a.maxX <= envelope.maxX
							and a.minZ >= envelope.minZ
							and a.maxZ <= envelope.maxZ
					).to.equal(true)
					for other = index + 1, #rooms do
						local b = rooms[other]
						expect(`seed {seed} {a.id}/{b.id} {overlaps(a, b)}`).to.equal(`seed {seed} {a.id}/{b.id} false`)
					end
				end
			end
		end)

		it(
			"starts in the front hall off the front node, with the truck in the yard and both entrances into it",
			function()
				for seed = 1, SEEDS do
					local layout = layoutFor(seed)
					expect(layout.startRoom).to.equal("bay")
					local hall = Utils.room(layout, "bay")
					expect(hall.roomType).to.equal("fronthall")
					expect(hall.maxX - hall.minX).to.equal(OfficeConstants.BAY_WIDTH)
					expect(hall.maxZ - hall.minZ).to.equal(OfficeConstants.BAY_DEPTH)
					local doors = doorsOf(layout, "bay")
					expect(#doors).to.equal(1)
					local front = Utils.room(layout, doors[1].b)
					expect(front.zone).to.equal("hallway")
					expect(front.minZ).to.equal(hall.maxZ)
					expect(string.match(front.id, "^hallJ%d_1$") ~= nil).to.equal(true)
					expect(#layout.grounds).to.equal(2)
					expect(layout.truck.maxZ < OfficeConstants.OUTSIDE.yard.maxZ).to.equal(true)
					local ids = {}
					for _, entrance in layout.entrances do
						ids[entrance.id] = entrance.exit.a
					end
					expect(ids.dock).to.equal("bay")
					expect(ids.lobby).to.equal("bay")
					expect(Utils.marker(layout, "bay.patrol.1") ~= nil).to.equal(true)
					expect(table.find(layout.route, "bay.patrol.1") ~= nil).to.equal(true)
				end
			end
		)

		it("opens each landmark onto two halls, front and back, and every other room onto one", function()
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				for _, room in layout.rooms do
					if room.kit ~= nil and room.id ~= "bay" then
						local doors = doorsOf(layout, room.id)
						local wanted = if LANDMARKS[room.roomType] then 2 else 1
						expect(`seed {seed} {room.id} doors {#doors}`).to.equal(`seed {seed} {room.id} doors {wanted}`)
						local edges = {}
						for _, door in doors do
							local other = Utils.room(layout, if door.a == room.id then door.b else door.a)
							expect(other.zone).to.equal("hallway")
							local edge = Utils.doorEdge(room, door)
							expect(edge ~= nil).to.equal(true)
							expect(Utils.doorEdge(other, door) ~= nil).to.equal(true)
							edges[edge] = true
						end
						if wanted == 2 then
							expect(edges.minZ and edges.maxZ).to.equal(true)
						end
					end
				end
			end
		end)

		it("lines the wide halls with locker banks, clear of every doorway", function()
			local total = 0
			for seed = 1, SEEDS do
				local layout = layoutFor(seed)
				for _, marker in Utils.markersOf(layout, "locker") do
					total += 1
					local room = Utils.room(layout, marker.room)
					expect(room.zone).to.equal("hallway")
					local horizontal = room.maxX - room.minX >= room.maxZ - room.minZ
					local width = if horizontal then room.maxZ - room.minZ else room.maxX - room.minX
					expect(width).to.equal(SchoolConstants.CORRIDOR_WIDE)
					-- The long wall the locker stands against.
					local wall = if horizontal
						then (if marker.z < (room.minZ + room.maxZ) / 2 then "minZ" else "maxZ")
						else (if marker.x < (room.minX + room.maxX) / 2 then "minX" else "maxX")
					for _, door in doorsOf(layout, room.id) do
						local along = if horizontal then marker.x else marker.z
						local centre = if horizontal then door.x else door.z
						if Utils.doorEdge(room, door) == wall then
							local clear = math.abs(along - centre) - door.width / 2 - OfficeConstants.LOCKER_SIZE.X / 2
							expect(`seed {seed} {marker.id} {clear >= SchoolConstants.LOCKER_CLEAR}`).to.equal(
								`seed {seed} {marker.id} true`
							)
						end
					end
				end
			end
			expect(total >= SEEDS * 6).to.equal(true)
		end)

		it("rolls spawns that meet the biggest crew's contract on every seed", function()
			for seed = 1, SEEDS do
				if seed % 10 == 0 then
					task.wait()
				end
				local layout = layoutFor(seed)
				-- Mirrors OfficeServiceServer's rollPlan: roll seeds seed, seed + 1, ... until one meets the contract.
				local failure
				local met = false
				for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
					local plan = Spawn.roll(layout, {
						quota = CONTRACT,
						variant = "A",
						dirtyRooms = OfficeConstants.DIRTY_ROOMS,
						pilesPerRoom = OfficeConstants.PILES_PER_ROOM,
						valuables = OfficeConstants.VALUABLES,
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
		end)

		it("keeps the input immutable and builds on the generated art kit", function()
			local before = #Base.rooms
			local layout = layoutFor(1)
			expect(#Base.rooms).to.equal(before)
			expect(Base.startRoom).to.equal("bay")
			expect(layout.artKit).to.equal(OfficeConstants.GENERATED_ART_KIT)
		end)
	end)
end
