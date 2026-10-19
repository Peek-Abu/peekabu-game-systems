local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsConstants = require(script.Parent.AnalyticsConstants)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

return function()
	it("has the ten funnel steps in order, unique", function()
		expect(#AnalyticsConstants.FUNNEL_STEPS).to.equal(10)
		expect(AnalyticsConstants.stepNumber("joined_hub")).to.equal(1)
		expect(AnalyticsConstants.stepNumber("next_shift")).to.equal(10)
		expect(AnalyticsConstants.stepNumber("nope")).to.equal(nil)
		local seen = {}
		for _, step in AnalyticsConstants.FUNNEL_STEPS do
			expect(seen[step]).to.equal(nil)
			seen[step] = true
		end
	end)

	it("tags only known experiments, at most MAX_TAGS per event", function()
		for _, id in AnalyticsConstants.FUNNEL_EXPERIMENTS do
			expect(ExperimentRegistry.get(id) ~= nil).to.equal(true)
		end
		expect(#AnalyticsConstants.FUNNEL_EXPERIMENTS <= AnalyticsConstants.MAX_TAGS).to.equal(true)
		for _, ids in AnalyticsConstants.CURRENCY_EXPERIMENTS do
			expect(#ids <= AnalyticsConstants.MAX_TAGS).to.equal(true)
			for _, id in ids do
				expect(ExperimentRegistry.get(id) ~= nil).to.equal(true)
			end
		end
	end)

	it("every currency with a name has its experiments, and every transaction type is a Roblox name", function()
		for currency in AnalyticsConstants.CURRENCY_NAMES do
			expect(AnalyticsConstants.CURRENCY_EXPERIMENTS[currency] ~= nil).to.equal(true)
		end
		for _, transactionType in AnalyticsConstants.TRANSACTION_TYPES do
			local ok, item = pcall(function()
				return Enum.AnalyticsEconomyTransactionType:FromName(transactionType)
			end)
			expect(ok).to.equal(true)
			expect(item ~= nil).to.equal(true)
		end
	end)
end
