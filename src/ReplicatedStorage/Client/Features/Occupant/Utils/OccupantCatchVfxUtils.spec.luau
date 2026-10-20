local OccupantCatchVfxUtils = require(script.Parent.OccupantCatchVfxUtils)

return function()
	describe("thrown", function()
		it("is a throw when the deadline appears", function()
			expect(OccupantCatchVfxUtils.thrown(false, true, false, false)).to.equal(true)
		end)

		it("is a throw when the player turns knocked out with no deadline", function()
			expect(OccupantCatchVfxUtils.thrown(false, false, false, true)).to.equal(true)
		end)

		it("is one throw when both appear together", function()
			expect(OccupantCatchVfxUtils.thrown(false, true, false, true)).to.equal(true)
		end)

		it("is not a throw while knocked out stays on (a republish)", function()
			expect(OccupantCatchVfxUtils.thrown(false, false, true, true)).to.equal(false)
			expect(OccupantCatchVfxUtils.thrown(true, true, true, true)).to.equal(false)
		end)

		it("is not a throw when either clears", function()
			expect(OccupantCatchVfxUtils.thrown(true, false, false, false)).to.equal(false)
			expect(OccupantCatchVfxUtils.thrown(false, false, true, false)).to.equal(false)
		end)

		it("is not a throw when nothing is set", function()
			expect(OccupantCatchVfxUtils.thrown(false, false, false, false)).to.equal(false)
		end)
	end)
end
