local DealStore = require(script.Parent.DealStore)

return function()
	afterEach(function()
		DealStore.reset()
	end)

	it("keeps each deal product's live Robux price, and forgets them on reset", function()
		expect(DealStore.robux().pickLegendary).to.equal(nil)
		DealStore.setRobux("pickLegendary", 449)
		DealStore.setRobux("pickNewHire", 499)
		expect(DealStore.robux().pickLegendary).to.equal(449)
		expect(DealStore.robux().pickNewHire).to.equal(499)
		DealStore.reset()
		expect(DealStore.robux().pickNewHire).to.equal(nil)
	end)
end
