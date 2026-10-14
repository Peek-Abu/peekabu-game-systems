local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(script.Parent.DepotTruckVisualConstants)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)

local function solid(name)
	for _, entry in Constants.COLLISION do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

local function extent(entry, axis, sign)
	return entry.centre[axis] + sign * entry.size[axis] / 2
end

return function()
	describe("the truck shape", function()
		it("is modelled for the depot's bed, so one art fits both places", function()
			expect(Constants.BED_SIZE).to.equal(DepotLayoutConstants.BED_SIZE)
			expect(Constants.DECK).to.equal(DepotLayoutConstants.BED_SIZE.Y)
		end)

		it("keeps the whole bed footprint clear inside the box", function()
			local half = Constants.BED_SIZE / 2
			for _, name in { "TruckWallLeft", "TruckWallRight" } do
				local wall = solid(name)
				expect(math.abs(wall.centre.X) - wall.size.X / 2 >= half.X - 1e-6).to.equal(true)
			end
			expect(extent(solid("TruckWallFront"), "Z", -1) >= half.Z - 1e-6).to.equal(true)
			expect(extent(solid("TruckCab"), "Z", -1) >= half.Z - 1e-6).to.equal(true)
			for _, name in { "TruckArchPostLeft", "TruckArchPostRight" } do
				local post = solid(name)
				expect(math.abs(post.centre.X) - post.size.X / 2 >= half.X - 1e-6).to.equal(true)
			end
		end)

		it("leaves headroom for a crew member and the boarding height under the roof", function()
			expect(extent(solid("TruckRoof"), "Y", -1) >= 6.5).to.equal(true)
			expect(Constants.DOOR_HEIGHT >= 5.6).to.equal(true)
		end)

		it("has a walkable ramp from the ground to the bed's back edge", function()
			local ramp = solid("TruckRamp")
			expect(ramp.shape).to.equal("Wedge")
			expect(extent(ramp, "Y", 1)).to.be.near(0, 1e-6)
			expect(extent(ramp, "Y", -1)).to.be.near(-Constants.DECK, 1e-6)
			expect(extent(ramp, "Z", 1)).to.be.near(-Constants.BED_SIZE.Z / 2, 1e-6)
			expect(ramp.size.Z).to.equal(Constants.RAMP_LENGTH)
			-- Under 45 degrees, well inside a Humanoid's MaxSlopeAngle.
			expect(math.deg(math.atan2(Constants.DECK, Constants.RAMP_LENGTH)) < 45).to.equal(true)
		end)

		it("fits the depot layout's truck footprint", function()
			expect(Constants.HALF_WIDTH <= DepotLayoutConstants.TRUCK_WIDTH / 2).to.equal(true)
			expect(Constants.BACK - Constants.BED_SIZE.Z / 2 <= DepotLayoutConstants.RAMP_DEPTH).to.equal(true)
			expect(Constants.FRONT - Constants.BED_SIZE.Z / 2 <= DepotLayoutConstants.CAB_SIZE.Z).to.equal(true)
			for _, entry in Constants.COLLISION do
				expect(math.abs(entry.centre.X) + entry.size.X / 2 <= Constants.HALF_WIDTH).to.equal(true)
				expect(extent(entry, "Z", -1) >= -Constants.BACK - 1e-6).to.equal(true)
				expect(extent(entry, "Z", 1) <= Constants.FRONT + 1e-6).to.equal(true)
			end
		end)

		it("gives every graybox piece a name, a size and a known shape", function()
			for _, entry in Constants.GRAYBOX do
				expect(#entry.name > 0).to.equal(true)
				expect(entry.size.X > 0 and entry.size.Y > 0 and entry.size.Z > 0).to.equal(true)
				expect(entry.shape == "Block" or entry.shape == "Cylinder" or entry.shape == "Wedge").to.equal(true)
			end
		end)
	end)
end
