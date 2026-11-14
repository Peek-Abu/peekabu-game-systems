local CoffeeStore = require(script.Parent.CoffeeStore)

return function()
	afterEach(function()
		CoffeeStore.reset()
	end)

	it("keeps the coffee product's live Robux price, and forgets it on reset", function()
		expect(CoffeeStore.robux()).to.equal(nil)
		CoffeeStore.setRobux(149)
		expect(CoffeeStore.robux()).to.equal(149)
		CoffeeStore.reset()
		expect(CoffeeStore.robux()).to.equal(nil)
	end)
end
