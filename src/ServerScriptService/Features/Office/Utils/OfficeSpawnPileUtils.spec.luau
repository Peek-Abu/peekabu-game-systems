local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnPileUtils = require(script.Parent.OfficeSpawnPileUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local OfficeLayoutGenerationUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutGenerationUtils)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)

local LAYOUT = OfficeLayoutConstants.LAYOUT

local function options()
	return {
		quota = 0,
		variant = "B",
		dirtyRooms = OfficeConstants.DIRTY_ROOMS,
		pilesPerRoom = OfficeConstants.PILES_PER_ROOM,
		valuables = OfficeConstants.VALUABLES,
	}
end

local function room(id, zone)
	return { id = id, name = id, zone = zone, minX = 0, minZ = 0, maxX = 1, maxZ = 1 }
end

return function()
	describe("shuffled", function()
		it("returns a copy with the same items and leaves the list alone", function()
			local list = { 1, 2, 3, 4, 5, 6 }
			local copy = OfficeSpawnPileUtils.shuffled(list, Random.new(4))
			expect(#copy).to.equal(6)
			expect(copy).never.to.equal(list)
			table.sort(copy)
			expect(table.concat(copy, ",")).to.equal("1,2,3,4,5,6")
			expect(table.concat(list, ",")).to.equal("1,2,3,4,5,6")
		end)

		it("is the same for the same seed", function()
			local a = OfficeSpawnPileUtils.shuffled({ "a", "b", "c", "d", "e" }, Random.new(9))
			local b = OfficeSpawnPileUtils.shuffled({ "a", "b", "c", "d", "e" }, Random.new(9))
			expect(table.concat(a, ",")).to.equal(table.concat(b, ","))
		end)
	end)

	describe("crowds", function()
		local reach = OfficeSpawnPileUtils.PILE_REACH

		it("is true for a marker inside PILE_REACH of a taken one along both axes", function()
			local taken = { { x = 0, z = 0 } }
			expect(OfficeSpawnPileUtils.crowds({ x = reach.X / 2, z = reach.Y / 2 }, taken)).to.equal(true)
		end)

		it("is false once the markers are PILE_REACH apart along X or Z, or nothing is taken", function()
			local taken = { { x = 0, z = 0 } }
			expect(OfficeSpawnPileUtils.crowds({ x = reach.X, z = 0 }, taken)).to.equal(false)
			expect(OfficeSpawnPileUtils.crowds({ x = 0, z = reach.Y }, taken)).to.equal(false)
			expect(OfficeSpawnPileUtils.crowds({ x = 0, z = 0 }, {})).to.equal(false)
		end)
	end)

	describe("neighbours", function()
		it("joins two rooms that share a doorway, both ways", function()
			local layout = {
				rooms = { room("A", "office"), room("B", "office") },
				doors = { { a = "A", b = "B", x = 0, z = 0 } },
			}
			local near = OfficeSpawnPileUtils.neighbours(layout)
			expect(near.A.B).to.equal(true)
			expect(near.B.A).to.equal(true)
		end)

		it("joins rooms through one corridor only when their doors are within NEIGHBOUR_DOOR_STUDS", function()
			local far = OfficeConstants.NEIGHBOUR_DOOR_STUDS + 10
			local function layoutWith(apart)
				return {
					rooms = { room("A", "office"), room("H", "hallway"), room("C", "office") },
					doors = { { a = "A", b = "H", x = 0, z = 0 }, { a = "H", b = "C", x = apart, z = 0 } },
				}
			end
			local close = OfficeSpawnPileUtils.neighbours(layoutWith(1))
			expect(close.A.C).to.equal(true)
			expect(close.A.H).to.equal(nil)
			local distant = OfficeSpawnPileUtils.neighbours(layoutWith(far))
			expect(distant.A == nil or distant.A.C == nil).to.equal(true)
		end)
	end)

	describe("pileOrder", function()
		it("lists distinct pile markers, none crowding another, the piles first", function()
			for seed = 1, 10 do
				local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, seed)
				local markers, count = OfficeSpawnPileUtils.pileOrder(layout, options(), Random.new(seed))
				expect(count <= #markers).to.equal(true)
				local seen = {}
				for index, marker in markers do
					expect(marker.kind).to.equal("pile")
					expect(seen[marker.id]).to.equal(nil)
					seen[marker.id] = true
					for earlier = 1, index - 1 do
						expect(OfficeSpawnPileUtils.crowds(marker, { markers[earlier] })).to.equal(false)
					end
				end
				task.wait()
			end
		end)

		it("is the same for the same seed", function()
			local layout = OfficeLayoutGenerationUtils.generate(LAYOUT, 3)
			local a, countA = OfficeSpawnPileUtils.pileOrder(layout, options(), Random.new(3))
			local b, countB = OfficeSpawnPileUtils.pileOrder(layout, options(), Random.new(3))
			expect(countA).to.equal(countB)
			local idsA, idsB = {}, {}
			for _, marker in a do
				table.insert(idsA, marker.id)
			end
			for _, marker in b do
				table.insert(idsB, marker.id)
			end
			expect(table.concat(idsA, ",")).to.equal(table.concat(idsB, ","))
		end)

		it("only uses the layout's pile markers", function()
			local markers = OfficeSpawnPileUtils.pileOrder(LAYOUT, options(), Random.new(1))
			local piles = {}
			for _, marker in OfficeLayoutUtils.markersOf(LAYOUT, "pile") do
				piles[marker.id] = true
			end
			for _, marker in markers do
				expect(piles[marker.id]).to.equal(true)
			end
		end)
	end)
end
