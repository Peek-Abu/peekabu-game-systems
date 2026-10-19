local AnalyticsEconomyUtils = require(script.Parent.AnalyticsEconomyUtils)

local function change(overrides)
	local base = {
		userId = 1,
		currency = "credits",
		flow = "source",
		amount = 120,
		balance = 340,
		reason = "shiftPay",
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

return function()
	it("a gain is a source at the display name", function()
		local call = AnalyticsEconomyUtils.call(change({}))
		expect(call ~= nil).to.equal(true)
		expect(call.flow).to.equal("source")
		expect(call.currency).to.equal("Credits")
		expect(call.amount).to.equal(120)
		expect(call.endingBalance).to.equal(340)
		expect(call.transactionType).to.equal("Gameplay")
		expect(call.sku).to.equal("shiftPay")
	end)

	it("a spend is a sink with a positive amount", function()
		local call = AnalyticsEconomyUtils.call(change({ flow = "sink", amount = 50, balance = 290 }))
		expect(call ~= nil).to.equal(true)
		expect(call.flow).to.equal("sink")
		expect(call.amount).to.equal(50)
		expect(call.endingBalance).to.equal(290)
	end)

	it("names Gloom and Gleam too", function()
		expect(AnalyticsEconomyUtils.call(change({ currency = "gloom" })).currency).to.equal("Gloom")
		expect(AnalyticsEconomyUtils.call(change({ currency = "gleam" })).currency).to.equal("Gleam")
	end)

	it("nothing for a zero change, an unlogged reason, an unknown currency or an unknown reason", function()
		expect(AnalyticsEconomyUtils.call(change({ amount = 0 }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "migration" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "admin" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "other" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ currency = "coins" }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ reason = "who-knows" }))).to.equal(nil)
	end)

	it("non-finite amounts are dropped", function()
		expect(AnalyticsEconomyUtils.call(change({ amount = 0 / 0 }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ amount = math.huge }))).to.equal(nil)
		expect(AnalyticsEconomyUtils.call(change({ balance = 0 / 0 }))).to.equal(nil)
	end)
end
