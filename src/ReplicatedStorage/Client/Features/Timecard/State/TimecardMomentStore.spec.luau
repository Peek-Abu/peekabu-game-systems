local Store = require(script.Parent.TimecardMomentStore)

return function()
	afterEach(function()
		Store.reset()
	end)

	it("holds the stamp showing and clears only that one", function()
		local first = { day = 1, count = 1, paycheque = false, id = "a" }
		local second = { day = 2, count = 2, paycheque = false, id = "b" }
		Store.show(first)
		expect(Store.stamp()).to.equal(first)
		Store.show(second)
		Store.clear("a")
		expect(Store.stamp()).to.equal(second)
		Store.clear("b")
		expect(Store.stamp()).never.to.be.ok()
	end)

	it("remembers the day already greeted and whether a punch is awaited", function()
		expect(Store.greeted()).never.to.be.ok()
		Store.greet(20754)
		expect(Store.greeted()).to.equal(20754)
		Store.expect(true)
		expect(Store.expecting()).to.equal(true)
		Store.reset()
		expect(Store.greeted()).never.to.be.ok()
		expect(Store.expecting()).to.equal(false)
	end)
end
