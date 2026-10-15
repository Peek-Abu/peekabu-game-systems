local ServerScriptService = game:GetService("ServerScriptService")

local OfficeLoadingBayUtils = require(script.Parent.OfficeLoadingBayUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local TARGET = { id = "work1", name = "Work", minX = 100, maxX = 134, minZ = 200, maxZ = 230 }
local HALF_WALL = OfficeConstants.WALL_THICKNESS / 2

-- The whole truck's footprint in layout space (arch, ramp foot, bumper), cab toward +Z.
local function footprint(truck)
	local cx, cz = (truck.minX + truck.maxX) / 2, (truck.minZ + truck.maxZ) / 2
	return {
		minX = cx - TruckVisual.HALF_WIDTH,
		maxX = cx + TruckVisual.HALF_WIDTH,
		rampFoot = cz - TruckVisual.BACK,
		bumper = cz + TruckVisual.FRONT,
	}
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

	describe("truck", function()
		it("keeps the whole truck inside the bay with RAMP_CLEARANCE of floor behind the ramp", function()
			for side = 1, 4 do
				local bay = OfficeLoadingBayUtils.bay(side, TARGET)
				local truck = OfficeLoadingBayUtils.truck(bay, side)
				local shape = footprint(truck)
				expect(truck.maxX - truck.minX).to.equal(TruckVisual.BED_SIZE.X)
				expect(truck.maxZ - truck.minZ).to.equal(TruckVisual.BED_SIZE.Z)
				expect(shape.minX > bay.minX + HALF_WALL).to.equal(true)
				expect(shape.maxX < bay.maxX - HALF_WALL).to.equal(true)
				expect(shape.bumper < bay.maxZ - HALF_WALL).to.equal(true)
				expect(shape.rampFoot - (bay.minZ + HALF_WALL) >= OfficeConstants.RAMP_CLEARANCE).to.equal(true)
			end
		end)

		it("keeps the truck off the door's approach", function()
			for side = 1, 4 do
				local bay, door = OfficeLoadingBayUtils.bay(side, TARGET)
				local truck = OfficeLoadingBayUtils.truck(bay, side)
				if side == 1 then
					expect(bay.maxX - truck.maxX >= 20).to.equal(true)
				elseif side == 2 then
					expect(truck.minX - bay.minX >= 20).to.equal(true)
				else
					expect(truck.maxX <= door.x - 4).to.equal(true)
				end
			end
		end)

		it("puts the time clock and overtime sheet on the floor clear of the truck, inside the bay", function()
			local clock = OfficeConstants.CLOCK_SIZE
			for side = 1, 4 do
				local bay = OfficeLoadingBayUtils.bay(side, TARGET)
				local truck = OfficeLoadingBayUtils.truck(bay, side)
				local shape = footprint(truck)
				for _, x in { truck.clockX, truck.clockX + OfficeConstants.OVERTIME_OFFSET.X } do
					local z = truck.clockZ + OfficeConstants.OVERTIME_OFFSET.Z
					expect(x - clock.X / 2 > bay.minX + HALF_WALL).to.equal(true)
					expect(x + clock.X / 2 < bay.maxX - HALF_WALL).to.equal(true)
					expect(z > bay.minZ + HALF_WALL and z < bay.maxZ - HALF_WALL).to.equal(true)
					local clear = x - clock.X / 2 > shape.maxX + 1 or x + clock.X / 2 < shape.minX - 1
					expect(clear).to.equal(true)
				end
			end
		end)
	end)

	describe("arrivals", function()
		it("gives four spread points on the bed, at least 4 studs apart and clear of its edges", function()
			local bay = OfficeLoadingBayUtils.bay(4, TARGET)
			local truck = OfficeLoadingBayUtils.truck(bay, 4)
			local points = OfficeLoadingBayUtils.arrivals(truck)
			expect(#points).to.equal(4)
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
end
