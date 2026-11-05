local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLoadingBayUtils = require(script.Parent.OfficeLoadingBayUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local TARGET = { id = "work1", name = "Work", minX = 100, maxX = 134, minZ = 200, maxZ = 230 }

-- A truck bed in layout space, its minimum corner at the origin.
local function bedTruck()
	local bed = TruckVisual.BED_SIZE
	return { minX = 0, maxX = bed.X, minZ = 0, maxZ = bed.Z, clockX = bed.X + 8, clockZ = 0 }
end

return function()
	describe("bay", function()
		it("attaches a BAY_WIDTH x BAY_DEPTH room to the chosen side of the target, sharing its door wall", function()
			local width, depth = OfficeConstants.BAY_WIDTH, OfficeConstants.BAY_DEPTH
			for side = 1, 4 do
				local bay, door = OfficeLoadingBayUtils.bay(side, TARGET)
				expect(bay.id).to.equal("bay")
				expect(bay.maxX - bay.minX).to.equal(width)
				expect(bay.maxZ - bay.minZ).to.equal(depth)
				expect(door.a).to.equal("bay")
				expect(door.b).to.equal(TARGET.id)
				expect(door.width).to.equal(10)
				if side == 1 then
					expect(bay.maxX).to.equal(TARGET.minX)
					expect(door.x).to.equal(TARGET.minX)
				elseif side == 2 then
					expect(bay.minX).to.equal(TARGET.maxX)
					expect(door.x).to.equal(TARGET.maxX)
				elseif side == 3 then
					expect(bay.maxZ).to.equal(TARGET.minZ)
					expect(door.z).to.equal(TARGET.minZ)
				else
					expect(bay.minZ).to.equal(TARGET.maxZ)
					expect(door.z).to.equal(TARGET.maxZ)
				end
			end
		end)
	end)

	describe("arrivals", function()
		it("gives six spread points on the bed (a Big Crew), at least 4 studs apart and clear of its edges", function()
			local truck = bedTruck()
			local points = OfficeLoadingBayUtils.arrivals(truck)
			expect(#points).to.equal(6)
			for index, point in points do
				expect(point.X > truck.minX + 1.5 and point.X < truck.maxX - 1.5).to.equal(true)
				expect(point.Z > truck.minZ + 1.5 and point.Z < truck.maxZ - 1.5).to.equal(true)
				for other = index + 1, #points do
					expect((point - points[other]).Magnitude >= 4).to.equal(true)
				end
			end
		end)

		it("stands an arrival above the bed's top, facing the open back and the ramp (-Z)", function()
			local truck = { minX = 0, maxX = 12, minZ = 0, maxZ = 16, clockX = 20, clockZ = 0 }
			local frame = OfficeLoadingBayUtils.arrivalFrame(truck, 1)
			local first = OfficeLoadingBayUtils.arrivals(truck)[1]
			expect(frame.Position.X).to.be.near(first.X, 1e-6)
			expect(frame.Position.Z).to.be.near(first.Z, 1e-6)
			expect(frame.Position.Y).to.be.near(OfficeConstants.BED_HEIGHT + OfficeConstants.SPAWN_HEIGHT, 1e-6)
			expect(frame.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1, 1e-6)
		end)

		it("wraps the crew index over the arrival points", function()
			local truck = { minX = 0, maxX = 12, minZ = 0, maxZ = 16, clockX = 20, clockZ = 0 }
			local count = #OfficeLoadingBayUtils.arrivals(truck)
			local first = OfficeLoadingBayUtils.arrivalFrame(truck, 1)
			expect(OfficeLoadingBayUtils.arrivalFrame(truck, count + 1).Position).to.equal(first.Position)
			expect(OfficeLoadingBayUtils.arrivalFrame(truck, 0).Position).to.equal(first.Position)
		end)
	end)

	describe("truckBox", function()
		it("is the bed's footprint from the bed's top to the truck's top: the one safe place", function()
			local truck = { minX = 0, maxX = 12, minZ = 0, maxZ = 16, clockX = 20, clockZ = 0 }
			local min, max = OfficeLoadingBayUtils.truckBox(truck)
			expect(min).to.equal(Vector3.new(0, OfficeConstants.BED_HEIGHT, 0))
			expect(max).to.equal(Vector3.new(12, OfficeConstants.BED_HEIGHT + TruckVisual.TOP, 16))
		end)

		it("holds every arrival point (a respawn lands safe) and leaves the ramp outside", function()
			local truck = bedTruck()
			local min, max = OfficeLoadingBayUtils.truckBox(truck)
			for index = 1, 4 do
				local at = OfficeLoadingBayUtils.arrivalFrame(truck, index).Position - Vector3.new(0, 1, 0)
				expect(at.X >= min.X and at.X <= max.X and at.Z >= min.Z and at.Z <= max.Z).to.equal(true)
				expect(at.Y >= min.Y and at.Y <= max.Y).to.equal(true)
			end
			local cz = (truck.minZ + truck.maxZ) / 2
			expect(cz - TruckVisual.BACK < min.Z).to.equal(true)
		end)
	end)

	describe("patrolPoint", function()
		it("stands in the bay, on its open side by the door", function()
			for side = 1, 4 do
				local bay = OfficeLoadingBayUtils.bay(side, TARGET)
				local point = OfficeLoadingBayUtils.patrolPoint(bay, side)
				expect(point.X > bay.minX + OfficeConstants.MARKER_MARGIN).to.equal(true)
				expect(point.X < bay.maxX - OfficeConstants.MARKER_MARGIN).to.equal(true)
				expect(point.Y > bay.minZ + OfficeConstants.MARKER_MARGIN).to.equal(true)
				expect(point.Y < bay.maxZ - OfficeConstants.MARKER_MARGIN).to.equal(true)
			end
		end)
	end)

	describe("yaw", function()
		local function turned()
			local truck = bedTruck()
			local flipped = table.clone(truck)
			flipped.yaw = math.pi
			return truck, flipped
		end

		local function near(a, b)
			return (a - b).Magnitude < 1e-3
		end

		it("faces +Z out of the open back at yaw pi and -Z with no yaw", function()
			local truck, flipped = turned()
			expect(near(OfficeLoadingBayUtils.arrivalFrame(truck, 1).LookVector, Vector3.new(0, 0, -1))).to.equal(true)
			expect(near(OfficeLoadingBayUtils.arrivalFrame(flipped, 1).LookVector, Vector3.new(0, 0, 1))).to.equal(true)
		end)

		it("turns the arrival points 180 degrees about the bed centre", function()
			local truck, flipped = turned()
			local cx, cz = (truck.minX + truck.maxX) / 2, (truck.minZ + truck.maxZ) / 2
			local plain = OfficeLoadingBayUtils.arrivals(truck)
			local turnedPoints = OfficeLoadingBayUtils.arrivals(flipped)
			expect(#turnedPoints).to.equal(#plain)
			for index, point in plain do
				local expected = Vector3.new(2 * cx - point.X, 0, 2 * cz - point.Z)
				expect(near(turnedPoints[index], expected)).to.equal(true)
			end
		end)

		it("keeps the truck's box the same when turned 180 degrees", function()
			local truck, flipped = turned()
			local min1, max1 = OfficeLoadingBayUtils.truckBox(truck)
			local min2, max2 = OfficeLoadingBayUtils.truckBox(flipped)
			expect(near(min1, min2)).to.equal(true)
			expect(near(max1, max2)).to.equal(true)
		end)
	end)
end
