-- RankTagSystem is a Players/BillboardGui shell (its words are the specced RankViewModel, its roots the specced
-- UIBillboards core). The spec checks its surface and that it holds nothing before it starts.
local RankTagSystem = require(script.Parent.RankTagSystem)

return function()
	describe("RankTagSystem", function()
		it("exposes start, stop and getState", function()
			expect(type(RankTagSystem.start)).to.equal("function")
			expect(type(RankTagSystem.stop)).to.equal("function")
			expect(type(RankTagSystem.getState)).to.equal("function")
		end)

		it("holds no tags before it starts", function()
			local state = RankTagSystem.getState()
			expect(state.tags).to.equal(0)
			expect(state.mounted).to.equal(0)
		end)
	end)
end
