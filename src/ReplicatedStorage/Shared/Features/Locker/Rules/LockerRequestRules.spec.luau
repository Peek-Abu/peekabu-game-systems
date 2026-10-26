local LockerRequestRules = require(script.Parent.LockerRequestRules)

return function()
	it("parses an open request for a known Locker", function()
		expect(LockerRequestRules.parseOpen(LockerRequestRules.buildOpen("gloom"))).to.equal("gloom")
		expect(LockerRequestRules.parseOpen(LockerRequestRules.buildOpen("gleam"))).to.equal("gleam")
	end)

	it("rejects unknown Lockers and bad shapes", function()
		expect(LockerRequestRules.parseOpen({ locker = "attic" })).to.equal(nil)
		expect(LockerRequestRules.parseOpen({ locker = 3 })).to.equal(nil)
		expect(LockerRequestRules.parseOpen("gloom")).to.equal(nil)
		expect(LockerRequestRules.parseOpen(nil)).to.equal(nil)
	end)

	it("parses a direct-buy request with a short item id", function()
		local locker, item = LockerRequestRules.parseBuy(LockerRequestRules.buildBuy("gleam", "Pippa.Thing"))
		expect(locker).to.equal("gleam")
		expect(item).to.equal("Pippa.Thing")
		expect((LockerRequestRules.parseBuy({ locker = "gleam", item = string.rep("x", 200) }))).to.equal(nil)
		expect((LockerRequestRules.parseBuy({ locker = "gleam" }))).to.equal(nil)
	end)
end
