local OccupantCatchUtils = require(script.Parent.OccupantCatchUtils)

return function()
	describe("afterCatch", function()
		it("keeps a knocked-out player down: no back-at time, the out toast, no rehire", function()
			local after = OccupantCatchUtils.afterCatch(true, 123)
			expect(after.publishBack).to.equal(nil)
			expect(after.toast).to.equal("out")
			expect(after.rehire).to.equal(false)
		end)

		it("sends any other caught player back: the back-at time, the caught toast, a rehire", function()
			local after = OccupantCatchUtils.afterCatch(false, 123)
			expect(after.publishBack).to.equal(123)
			expect(after.toast).to.equal("caught")
			expect(after.rehire).to.equal(true)
		end)
	end)
end
