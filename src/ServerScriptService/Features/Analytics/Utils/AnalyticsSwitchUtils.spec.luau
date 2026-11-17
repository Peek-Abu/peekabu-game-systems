local AnalyticsSwitchUtils = require(script.Parent.AnalyticsSwitchUtils)

return function()
	describe("resolve", function()
		it("a boolean config value wins over the fallback", function()
			expect(AnalyticsSwitchUtils.resolve(false, true)).to.equal(false)
			expect(AnalyticsSwitchUtils.resolve(true, false)).to.equal(true)
		end)

		it("a missing config uses the fallback", function()
			expect(AnalyticsSwitchUtils.resolve(nil, true)).to.equal(true)
			expect(AnalyticsSwitchUtils.resolve(nil, false)).to.equal(false)
		end)

		it("a config of the wrong type uses the fallback", function()
			expect(AnalyticsSwitchUtils.resolve("false", true)).to.equal(true)
			expect(AnalyticsSwitchUtils.resolve(0, true)).to.equal(true)
			expect(AnalyticsSwitchUtils.resolve({ on = false }, true)).to.equal(true)
		end)
	end)
end
