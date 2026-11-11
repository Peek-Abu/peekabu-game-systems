local ServerScriptService = game:GetService("ServerScriptService")

local SchoolRoomSlotUtils = require(script.Parent.SchoolRoomSlotUtils)
local SchoolNetworkUtils = require(script.Parent.SchoolNetworkUtils)
local SchoolConstants = require(ServerScriptService.Features.School.Data.SchoolConstants)
local OfficeKitUtils = require(ServerScriptService.Features.Office.Utils.OfficeKitUtils)

local SEEDS = 100

-- A bare kit `width` x `depth` with its door in the middle of its front wall.
local function kitOf(width, depth)
	return {
		id = "probe",
		roomType = "classroom",
		name = "Probe",
		size = "S",
		width = width,
		depth = depth,
		door = { offset = width / 2, width = 6.8, kind = "solid" },
		markers = {},
	}
end

local function overlaps(a, b)
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- The kit filling `slot` as far as it reaches (its whole run, its whole depth), placed as the generator does.
local function fill(slot)
	local width, depth = slot.to - slot.from, slot.depth
	local frontX, frontZ, facing = SchoolRoomSlotUtils.front(slot, slot.from, width)
	return OfficeKitUtils.place(kitOf(width, depth), "probe", frontX, frontZ, facing, false)
end

return function()
	describe("School room slots", function()
		it("puts a kit's front on its hall's wall, its door inside the hall's run, in all four facings", function()
			local function run(horizontal)
				local room = if horizontal
					then { id = "h", name = "h", minX = 0, maxX = 60, minZ = 0, maxZ = 14 }
					else { id = "v", name = "v", minX = 0, maxX = 14, minZ = 0, maxZ = 60 }
				return { room = room, horizontal = horizontal, from = 0, to = 60 }
			end
			for _, horizontal in { true, false } do
				for _, side in { 1, -1 } do
					local slot = { segment = run(horizontal), side = side, from = 10, to = 40, depth = 20 }
					local placement = fill(slot)
					local room, hall = placement.room, slot.segment.room
					local tag = `horizontal={horizontal} side={side}`
					expect(`{tag} {overlaps(room, hall)}`).to.equal(`{tag} false`)
					if horizontal then
						expect(`{tag} {room.minX == 10 and room.maxX == 40}`).to.equal(`{tag} true`)
						expect(`{tag} {placement.doorZ == (if side > 0 then hall.maxZ else hall.minZ)}`).to.equal(
							`{tag} true`
						)
						expect(room.maxZ - room.minZ).to.equal(20)
					else
						expect(`{tag} {room.minZ == 10 and room.maxZ == 40}`).to.equal(`{tag} true`)
						expect(`{tag} {placement.doorX == (if side > 0 then hall.maxX else hall.minX)}`).to.equal(
							`{tag} true`
						)
						expect(room.maxX - room.minX).to.equal(20)
					end
				end
			end
		end)

		it("is seed-stable", function()
			for seed = 1, 20 do
				local network = SchoolNetworkUtils.network(Random.new(seed))
				local a = SchoolRoomSlotUtils.slots(network, Random.new(seed))
				local b = SchoolRoomSlotUtils.slots(network, Random.new(seed))
				expect(#a).to.equal(#b)
				for index, options in a do
					for option, slot in options do
						local other = b[index][option]
						expect(`{slot.segment.room.id} {slot.side} {slot.from} {slot.to} {slot.depth}`).to.equal(
							`{other.segment.room.id} {other.side} {other.from} {other.to} {other.depth}`
						)
					end
				end
			end
		end)

		it(
			"keeps every slot on its hall's run, never on a landmark block, and full rooms clear of the halls and each other",
			function()
				for seed = 1, SEEDS do
					local network = SchoolNetworkUtils.network(Random.new(seed))
					local places = SchoolRoomSlotUtils.slots(network, Random.new(seed + 7))
					expect(#places > 0).to.equal(true)
					local landmarkRooms = {}
					for _, landmark in network.landmarks do
						table.insert(landmarkRooms, {
							minX = network.lineX[landmark.col] + SchoolConstants.JUNCTION_MIN / 2,
							maxX = network.lineX[landmark.col + 1] - SchoolConstants.JUNCTION_MIN / 2,
							minZ = network.lineZ[landmark.row] + SchoolConstants.CORRIDOR_NARROW / 2,
							maxZ = network.lineZ[landmark.row + 1] - SchoolConstants.CORRIDOR_NARROW / 2,
						})
					end
					-- One room per place: each place's first option, filled to the brim.
					local placed = {}
					for _, options in places do
						expect(#options >= 1 and #options <= 2).to.equal(true)
						for _, slot in options do
							expect(slot.from >= slot.segment.from and slot.to <= slot.segment.to).to.equal(true)
							expect(slot.to - slot.from > 0 and slot.depth > 0).to.equal(true)
							local room = fill(slot).room
							for _, hall in network.rooms do
								expect(`seed {seed} {hall.id} {overlaps(room, hall)}`).to.equal(
									`seed {seed} {hall.id} false`
								)
							end
							for _, landmark in landmarkRooms do
								expect(`seed {seed} landmark {overlaps(room, landmark)}`).to.equal(
									`seed {seed} landmark false`
								)
							end
						end
						local room = fill(options[1]).room
						for _, other in placed do
							expect(`seed {seed} {overlaps(room, other)}`).to.equal(`seed {seed} false`)
						end
						table.insert(placed, room)
					end
				end
			end
		)

		it("gives a block quarter room for the School's room kits, and the wall band BAND_DEPTH", function()
			local quarterRun, bands = math.huge, 0
			for seed = 1, SEEDS do
				local network = SchoolNetworkUtils.network(Random.new(seed))
				for _, options in SchoolRoomSlotUtils.slots(network, Random.new(seed)) do
					for _, slot in options do
						if slot.depth == SchoolConstants.BAND_DEPTH then
							bands += 1
							expect(slot.to - slot.from >= SchoolConstants.BAND_SLOT).to.equal(true)
						else
							quarterRun = math.min(quarterRun, slot.to - slot.from)
							expect(slot.depth >= 28).to.equal(true)
						end
					end
				end
			end
			expect(quarterRun >= 28).to.equal(true)
			expect(bands > 0).to.equal(true)
		end)
	end)
end
