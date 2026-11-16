local EventRules = require(script.Parent.EventRules)

return function()
	it("accepts a whole, non-negative day number", function()
		expect(EventRules.validate({ day = 0 })).to.equal(true)
		expect(EventRules.validate({ day = 20000 })).to.equal(true)
	end)

	it("refuses a broken slice", function()
		expect(EventRules.validate({ day = -1 })).to.equal(false)
		expect(EventRules.validate({ day = 1.5 })).to.equal(false)
		expect(EventRules.validate({ day = "1" })).to.equal(false)
		expect(EventRules.validate({})).to.equal(false)
	end)
end
