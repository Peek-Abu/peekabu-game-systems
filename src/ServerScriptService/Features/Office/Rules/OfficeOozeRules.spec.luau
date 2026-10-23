local OfficeOozeRules = require(script.Parent.OfficeOozeRules)

return function()
	it("is none below a third of the site range", function()
		expect(OfficeOozeRules.level(0)).to.equal("none")
		expect(OfficeOozeRules.level(984)).to.equal("none")
	end)

	it("is little in the middle third", function()
		expect(OfficeOozeRules.level(985)).to.equal("little")
		expect(OfficeOozeRules.level(1239)).to.equal("little")
	end)

	it("is lot in the top third", function()
		expect(OfficeOozeRules.level(1240)).to.equal("lot")
		expect(OfficeOozeRules.level(1495)).to.equal("lot")
	end)
end
