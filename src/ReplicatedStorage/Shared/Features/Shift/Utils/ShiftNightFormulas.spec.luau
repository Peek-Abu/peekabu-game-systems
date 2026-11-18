local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftNightConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftNightConstants)
local ShiftNightFormulas = require(script.Parent.ShiftNightFormulas)

return function()
	local N = ShiftNightConstants.WEEK_NIGHTS

	describe("week and nightOfWeek", function()
		it("groups nights into weeks of WEEK_NIGHTS", function()
			expect(ShiftNightFormulas.week(1)).to.equal(1)
			expect(ShiftNightFormulas.week(N)).to.equal(1)
			expect(ShiftNightFormulas.week(N + 1)).to.equal(2)
			expect(ShiftNightFormulas.nightOfWeek(1)).to.equal(1)
			expect(ShiftNightFormulas.nightOfWeek(N)).to.equal(N)
			expect(ShiftNightFormulas.nightOfWeek(N + 1)).to.equal(1)
		end)

		it("ends a week on its last night", function()
			expect(ShiftNightFormulas.endsWeek(N)).to.equal(true)
			expect(ShiftNightFormulas.endsWeek(N - 1)).to.equal(false)
			expect(ShiftNightFormulas.endsWeek(2 * N)).to.equal(true)
		end)

		it("treats nights below 1 as night 1", function()
			expect(ShiftNightFormulas.week(0)).to.equal(1)
			expect(ShiftNightFormulas.nightOfWeek(-3)).to.equal(1)
		end)
	end)

	describe("seconds", function()
		it("starts short and grows week by week up to the full shift", function()
			local first = ShiftNightFormulas.seconds(1)
			local last = ShiftNightFormulas.seconds(N * 20)
			expect(first < last).to.equal(true)
			local previous = 0
			for week = 1, 8 do
				local s = ShiftNightFormulas.seconds((week - 1) * N + 1)
				expect(s >= previous).to.equal(true)
				previous = s
			end
			expect(last).to.equal(ShiftNightConstants.NIGHT_SECONDS[#ShiftNightConstants.NIGHT_SECONDS])
		end)

		it("is the same for every night of one week", function()
			expect(ShiftNightFormulas.seconds(1)).to.equal(ShiftNightFormulas.seconds(N))
		end)
	end)

	describe("quotaScale", function()
		it("grows by week and never passes the site's safe cap", function()
			local previous = 0
			for week = 1, 30 do
				local s = ShiftNightFormulas.quotaScale((week - 1) * N + 1)
				expect(s >= previous).to.equal(true)
				expect(s <= ShiftNightConstants.QUOTA_SCALE_CAP).to.equal(true)
				previous = s
			end
		end)
	end)

	describe("nightQuota and weekQuota", function()
		it("scales the shift contract and rounds to the quota step", function()
			local q = ShiftNightFormulas.nightQuota(1000, 1)
			expect(q % 5).to.equal(0)
			expect(q > 0 and q <= 1000).to.equal(true)
		end)

		it("makes the week's quota the sum of its nights", function()
			for _, night in { 1, N + 2, 5 * N } do
				expect(ShiftNightFormulas.weekQuota(800, night)).to.equal(ShiftNightFormulas.nightQuota(800, night) * N)
			end
		end)
	end)

	describe("payScale", function()
		it("is 1 on night 1 and grows PAY_STEP a night", function()
			expect(ShiftNightFormulas.payScale(1)).to.equal(1)
			expect(ShiftNightFormulas.payScale(2)).to.equal(1 + ShiftNightConstants.PAY_STEP)
			expect(ShiftNightFormulas.payScale(5)).to.equal(1 + 4 * ShiftNightConstants.PAY_STEP)
		end)
	end)

	describe("weekBonus", function()
		it("grows with the week", function()
			expect(ShiftNightFormulas.weekBonus(1)).to.equal(ShiftNightConstants.WEEK_BONUS)
			expect(ShiftNightFormulas.weekBonus(3)).to.equal(3 * ShiftNightConstants.WEEK_BONUS)
		end)
	end)

	describe("startTier", function()
		it("is calm on week 1 and rises a step a week to the top tier", function()
			expect(ShiftNightFormulas.startTier(1, 2)).to.equal(0)
			expect(ShiftNightFormulas.startTier(N + 1, 2)).to.equal(1)
			expect(ShiftNightFormulas.startTier(10 * N, 2)).to.equal(2)
		end)
	end)

	describe("anomaly", function()
		it("adds a drop each week to the map's danger, up to ANOMALY_MAX", function()
			expect(ShiftNightFormulas.anomaly(1, 1)).to.equal(1)
			expect(ShiftNightFormulas.anomaly(N + 1, 1)).to.equal(2)
			expect(ShiftNightFormulas.anomaly(1, 2)).to.equal(2)
			expect(ShiftNightFormulas.anomaly(100 * N, 1)).to.equal(ShiftNightConstants.ANOMALY_MAX)
		end)
	end)
end
