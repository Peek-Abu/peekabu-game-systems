local OccupantDirectorUtils = require(script.Parent.OccupantDirectorUtils)

local ROUTE = {
	Vector3.new(0, 0, 0),
	Vector3.new(20, 0, 0),
	Vector3.new(40, 0, 0),
	Vector3.new(60, 0, 0),
	Vector3.new(100, 0, 0),
}

return function()
	describe("steerPoint", function()
		it("picks the route point nearest the aimed point, not the player's own spot", function()
			-- Aim 15 studs along +X from (20, 0, 0) (angle roll 0 = +X): (35, 0, 0) → the point at 40.
			local point =
				OccupantDirectorUtils.steerPoint(Vector3.new(20, 0, 0), ROUTE, { min = 15, max = 15 }, 0, 0, 8)
			expect(point).to.equal(Vector3.new(40, 0, 0))
		end)
		it("never picks a point within the minimum distance of the player", function()
			-- Aim at the player's own point (spread 0): the nearest candidate at least 8 away.
			local point = OccupantDirectorUtils.steerPoint(Vector3.new(20, 0, 0), ROUTE, { min = 0, max = 0 }, 0, 0, 8)
			expect(point).never.to.equal(Vector3.new(20, 0, 0))
			expect((point - Vector3.new(20, 0, 0)).Magnitude >= 8).to.equal(true)
		end)
		it("is nil without candidates", function()
			expect(OccupantDirectorUtils.steerPoint(Vector3.zero, {}, { min = 5, max = 5 }, 0, 0, 1)).to.equal(nil)
		end)
	end)

	describe("farPoint", function()
		it("picks the route point farthest from every crew member", function()
			local point = OccupantDirectorUtils.farPoint(ROUTE, { Vector3.new(0, 0, 0), Vector3.new(30, 0, 0) })
			expect(point).to.equal(Vector3.new(100, 0, 0))
		end)
		it("is nil for an empty route; any point with no crew", function()
			expect(OccupantDirectorUtils.farPoint({}, { Vector3.zero })).to.equal(nil)
			expect(OccupantDirectorUtils.farPoint(ROUTE, {})).to.equal(ROUTE[1])
		end)
	end)

	describe("pick", function()
		it("picks by roll, clamped", function()
			expect(OccupantDirectorUtils.pick(3, 0)).to.equal(1)
			expect(OccupantDirectorUtils.pick(3, 0.5)).to.equal(2)
			expect(OccupantDirectorUtils.pick(3, 1)).to.equal(3)
			expect(OccupantDirectorUtils.pick(0, 0.5)).to.equal(nil)
		end)
	end)

	describe("nearestIndex", function()
		it("is the nearest route point", function()
			expect(OccupantDirectorUtils.nearestIndex(ROUTE, Vector3.new(58, 3, 2))).to.equal(4)
			expect(OccupantDirectorUtils.nearestIndex({}, Vector3.zero)).to.equal(nil)
		end)
	end)
end
