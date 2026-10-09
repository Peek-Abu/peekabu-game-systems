local NpcSenseRules = require(script.Parent.NpcSenseRules)

local ORIGIN = Vector3.new(0, 0, 0)
local FORWARD = Vector3.new(0, 0, -1)

return function()
	describe("inSight", function()
		it("sees inside range and inside the cone", function()
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(0, 0, -10), 20, 90)).to.equal(true)
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(5, 0, -10), 20, 90)).to.equal(true)
		end)

		it("does not see beyond range or outside the cone", function()
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(0, 0, -30), 20, 90)).to.equal(false)
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(0, 0, 10), 20, 90)).to.equal(false)
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(10, 0, -1), 20, 90)).to.equal(false)
		end)

		it("sees all around with a 360 degree cone, and something standing on it", function()
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, Vector3.new(0, 0, 10), 20, 360)).to.equal(true)
			expect(NpcSenseRules.inSight(ORIGIN, FORWARD, ORIGIN, 20, 10)).to.equal(true)
		end)
	end)

	describe("nearest", function()
		it("picks the closest candidate and its distance", function()
			local id, distance = NpcSenseRules.nearest(ORIGIN, {
				{ id = 1, position = Vector3.new(10, 0, 0) },
				{ id = 2, position = Vector3.new(3, 0, 4) },
			})
			expect(id).to.equal(2)
			expect(distance).to.equal(5)
		end)

		it("is nil with no candidates", function()
			expect(NpcSenseRules.nearest(ORIGIN, {})).to.equal(nil)
		end)
	end)

	describe("remembers", function()
		it("remembers a target for loseSightTime after it was last seen", function()
			expect(NpcSenseRules.remembers(10, 13, 4)).to.equal(true)
			expect(NpcSenseRules.remembers(10, 14.5, 4)).to.equal(false)
			expect(NpcSenseRules.remembers(nil, 1, 4)).to.equal(false)
		end)
	end)
end
