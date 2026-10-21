local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsContextUtils = require(script.Parent.AnalyticsContextUtils)
local AnalyticsRules = require(ServerScriptService.Features.Analytics.Rules.AnalyticsRules)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

return function()
	describe("cohort", function()
		it("is new inside the first day, returning after, unknown without a timestamp", function()
			expect(AnalyticsContextUtils.cohort(1000, 1000 + 86399)).to.equal("new")
			expect(AnalyticsContextUtils.cohort(1000, 1000 + 86400)).to.equal("ret")
			expect(AnalyticsContextUtils.cohort(nil, 5)).to.equal("unk")
		end)

		it("a first-seen in the future reads new, not negative-returning", function()
			expect(AnalyticsContextUtils.cohort(2000, 1000)).to.equal("new")
		end)
	end)

	describe("tags", function()
		it("joins variants with + and is - for none", function()
			expect(AnalyticsContextUtils.tags({ "5beats", "skip" })).to.equal("5beats+skip")
			expect(AnalyticsContextUtils.tags({})).to.equal("-")
		end)
	end)

	describe("field", function()
		it("packs tags, platform, party, cohort and build", function()
			local field = AnalyticsContextUtils.field({
				tags = "5beats+skip",
				platform = "phone",
				party = 3,
				cohort = "new",
				build = "w1-v12",
			})
			expect(field).to.equal("5beats+skip|phone|3|new|w1-v12")
		end)

		it("clamps the party to 0..99", function()
			local field = AnalyticsContextUtils.field({
				tags = "-",
				platform = "pc",
				party = 250,
				cohort = "ret",
				build = "w1-dev",
			})
			expect(field).to.equal("-|pc|99|ret|w1-dev")
		end)

		it("the longest field fits in the engine's 50 characters", function()
			local longest = 0
			for _, def in ExperimentRegistry.list() do
				for _, variant in def.variants do
					longest = math.max(longest, #variant)
				end
			end
			local tags = string.rep("x", longest) .. "+" .. string.rep("x", longest)
			local field = AnalyticsContextUtils.field({
				tags = tags,
				platform = "unknown",
				party = 99,
				cohort = "unk",
				build = "w1-v99999",
			})
			expect(#field <= AnalyticsRules.MAX_NAME_LENGTH).to.equal(true)
		end)
	end)

	describe("build", function()
		it("appends the place version, or dev", function()
			expect(AnalyticsContextUtils.build("w1", 42)).to.equal("w1-v42")
			expect(AnalyticsContextUtils.build("w1", 0)).to.equal("w1-dev")
		end)
	end)
end
