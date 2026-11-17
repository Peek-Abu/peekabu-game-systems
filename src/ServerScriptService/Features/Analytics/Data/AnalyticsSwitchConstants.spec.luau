local AnalyticsSwitchConstants = require(script.Parent.AnalyticsSwitchConstants)

return function()
	it("has a fallback and a config key for every switch, and nothing else", function()
		local count = 0
		for _, switch in AnalyticsSwitchConstants.ORDER do
			count += 1
			expect(type(AnalyticsSwitchConstants.SWITCHES[switch])).to.equal("boolean")
			expect(type(AnalyticsSwitchConstants.CONFIG_KEYS[switch])).to.equal("string")
		end
		local fallbacks = 0
		for _ in AnalyticsSwitchConstants.SWITCHES do
			fallbacks += 1
		end
		local keys = 0
		for _ in AnalyticsSwitchConstants.CONFIG_KEYS do
			keys += 1
		end
		expect(count).to.equal(5)
		expect(fallbacks).to.equal(count)
		expect(keys).to.equal(count)
	end)

	it("names every config key analytics_<pick>, all different", function()
		local seen = {}
		for _, key in AnalyticsSwitchConstants.CONFIG_KEYS do
			expect(string.match(key, "^analytics_[a-z_]+$")).to.be.ok()
			expect(seen[key]).to.equal(nil)
			seen[key] = true
		end
	end)

	it("ships with every pick on", function()
		for _, on in AnalyticsSwitchConstants.SWITCHES do
			expect(on).to.equal(true)
		end
	end)
end
