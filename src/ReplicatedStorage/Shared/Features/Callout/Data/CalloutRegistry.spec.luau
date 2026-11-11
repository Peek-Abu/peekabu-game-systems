local CalloutRegistry = require(script.Parent.CalloutRegistry)

return function()
	it("has the six pings in wheel order, each with its word", function()
		local ids = {}
		for _, ping in CalloutRegistry.pings() do
			table.insert(ids, ping.id)
			expect(ping.word ~= "").to.equal(true)
			expect(CalloutRegistry.ping(ping.id)).to.equal(ping)
		end
		expect(table.concat(ids, ",")).to.equal("gloom,loot,manager,help,truck,okay")
		expect(CalloutRegistry.ping("nope")).never.to.be.ok()
	end)

	it("calls out any monster, not one map's", function()
		expect(CalloutRegistry.ping("manager").word).to.equal("Monster!")
	end)
end
