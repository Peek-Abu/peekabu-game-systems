local PaperScaleContext = require(script.Parent.PaperScaleContext)

return function()
	describe("limit", function()
		it("keeps the design size at scale 1", function()
			expect(PaperScaleContext.limit(24, 1)).to.equal(24)
		end)

		it("follows the sign's scale, down and up", function()
			expect(PaperScaleContext.limit(24, 0.5)).to.equal(12)
			expect(PaperScaleContext.limit(24, 2)).to.equal(48)
		end)

		it("stays inside the constraint's 1..100 range", function()
			expect(PaperScaleContext.limit(24, 0.001)).to.equal(1)
			expect(PaperScaleContext.limit(58, 5)).to.equal(100)
			expect(PaperScaleContext.limit(24, 0)).to.equal(1)
		end)
	end)

	describe("floor", function()
		it("lets fitted text shrink to 60% of its design size at the drawn scale", function()
			-- 40 design px at 1: the floor is 24 real px.
			expect(PaperScaleContext.floor(40, 1, 12)).to.equal(24)
			expect(PaperScaleContext.floor(40, 2, 12)).to.equal(48)
		end)

		it("never lets fitted text shrink below the readable px", function()
			-- 20 design px at 0.75 would shrink to 9 real px; it stops at 12.
			expect(PaperScaleContext.floor(20, 0.75, 12)).to.equal(12)
			expect(PaperScaleContext.floor(16, 0.75, 12)).to.equal(12)
		end)

		it("lets a world sign shrink with distance (its readable floor is 1)", function()
			expect(PaperScaleContext.floor(20, 0.25, 1)).to.equal(3)
		end)

		it("is never above the label's own limit (a label designed small never grows)", function()
			expect(PaperScaleContext.floor(10, 1, 12)).to.equal(PaperScaleContext.limit(10, 1))
			expect(PaperScaleContext.floor(14, 0.75, 12) <= PaperScaleContext.limit(14, 0.75)).to.equal(true)
		end)
	end)
end
