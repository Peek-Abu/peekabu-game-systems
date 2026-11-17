local AnalyticsVisitRules = require(script.Parent.AnalyticsVisitRules)

return function()
	describe("validate", function()
		it("accepts whole numbers of 0 and up", function()
			expect(AnalyticsVisitRules.validate({ shifts = 0, current = 0, handoffAt = 0 })).to.equal(true)
			expect(AnalyticsVisitRules.validate({ shifts = 40, current = 3, handoffAt = 1763400000 })).to.equal(true)
		end)

		it("refuses a missing slice, a missing field, a fraction or a negative", function()
			expect(AnalyticsVisitRules.validate(nil)).to.equal(false)
			expect(AnalyticsVisitRules.validate({ shifts = 0, current = 0 })).to.equal(false)
			expect(AnalyticsVisitRules.validate({ shifts = 1.5, current = 0, handoffAt = 0 })).to.equal(false)
			expect(AnalyticsVisitRules.validate({ shifts = 0, current = -1, handoffAt = 0 })).to.equal(false)
			expect(AnalyticsVisitRules.validate({ shifts = 0, current = 0, handoffAt = "x" })).to.equal(false)
		end)

		it("refuses a visit count above the lifetime total", function()
			expect(AnalyticsVisitRules.validate({ shifts = 2, current = 3, handoffAt = 0 })).to.equal(false)
		end)
	end)

	describe("arrive", function()
		it("a load soon after a truck ride keeps the visit's count and clears the stamp", function()
			local slice = { shifts = 9, current = 2, handoffAt = 1000 }
			expect(AnalyticsVisitRules.arrive(slice, 1060)).to.equal(true)
			expect(slice.current).to.equal(2)
			expect(slice.handoffAt).to.equal(0)
			expect(slice.shifts).to.equal(9)
		end)

		it("any other load starts a new visit", function()
			local slice = { shifts = 9, current = 2, handoffAt = 0 }
			expect(AnalyticsVisitRules.arrive(slice, 1060)).to.equal(false)
			expect(slice.current).to.equal(0)
			expect(slice.shifts).to.equal(9)
		end)
	end)

	describe("worked", function()
		it("counts a shift into the visit and the lifetime total", function()
			local slice = { shifts = 9, current = 2, handoffAt = 0 }
			AnalyticsVisitRules.worked(slice)
			expect(slice.current).to.equal(3)
			expect(slice.shifts).to.equal(10)
		end)
	end)
end
