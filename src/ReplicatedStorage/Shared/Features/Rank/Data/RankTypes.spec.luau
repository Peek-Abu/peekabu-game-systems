-- RankTypes is types only; this spec keeps the spec-sibling rule without an exemption and checks it loads.
local RankTypes = require(script.Parent.RankTypes)

return function()
	describe("RankTypes", function()
		it("loads as an empty types-only module", function()
			expect(type(RankTypes)).to.equal("table")
			expect(next(RankTypes)).to.equal(nil)
		end)
	end)
end
