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
end
