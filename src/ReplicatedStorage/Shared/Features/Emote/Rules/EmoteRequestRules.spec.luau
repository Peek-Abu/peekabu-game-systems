local EmoteRequestRules = require(script.Parent.EmoteRequestRules)

return function()
	it("round-trips a slot and drops anything malformed", function()
		expect(EmoteRequestRules.parsePlay(EmoteRequestRules.buildPlay(3))).to.equal(3)
		for _, bad in { "x", 2, {}, { slot = 0 }, { slot = 5 }, { slot = 1.5 }, { slot = "1" } } do
			local slot, reason = EmoteRequestRules.parsePlay(bad)
			expect(slot).never.to.be.ok()
			expect(reason).to.be.a("string")
		end
	end)
end
