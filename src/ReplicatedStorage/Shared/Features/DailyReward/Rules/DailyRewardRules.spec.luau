local DailyRewardRules = require(script.Parent.DailyRewardRules)

local DAY = 86400

return function()
	describe("dayOf", function()
		it("counts whole days since the epoch, shifted by the offset", function()
			expect(DailyRewardRules.dayOf(0, 0)).to.equal(0)
			expect(DailyRewardRules.dayOf(DAY * 3 + 5, 0)).to.equal(3)
			expect(DailyRewardRules.dayOf(DAY * 3 - 3600, 2)).to.equal(3)
		end)
	end)

	describe("status", function()
		it("lets a new player claim day 1", function()
			local status = DailyRewardRules.status({ lastDay = 0, streak = 0 }, 100, 7)
			expect(status.claimable).to.equal(true)
			expect(status.nextStreak).to.equal(1)
			expect(status.cycleDay).to.equal(1)
		end)

		it("continues the streak the day after a claim", function()
			local status = DailyRewardRules.status({ lastDay = 99, streak = 3 }, 100, 7)
			expect(status.claimable).to.equal(true)
			expect(status.nextStreak).to.equal(4)
			expect(status.cycleDay).to.equal(4)
		end)

		it("restarts the streak after a missed day", function()
			local status = DailyRewardRules.status({ lastDay = 97, streak = 5 }, 100, 7)
			expect(status.nextStreak).to.equal(1)
		end)

		it("is not claimable twice in a day", function()
			expect(DailyRewardRules.status({ lastDay = 100, streak = 2 }, 100, 7).claimable).to.equal(false)
		end)

		it("cycles the reward day", function()
			expect(DailyRewardRules.status({ lastDay = 99, streak = 7 }, 100, 7).cycleDay).to.equal(1)
			expect(DailyRewardRules.status({ lastDay = 99, streak = 8 }, 100, 7).cycleDay).to.equal(2)
		end)
	end)

	describe("claim", function()
		it("records the claim and returns the reward day", function()
			local state = { lastDay = 99, streak = 2 }
			local ok, cycleDay = DailyRewardRules.claim(state, 100, 7)
			expect(ok).to.equal(true)
			expect(cycleDay).to.equal(3)
			expect(state.lastDay).to.equal(100)
			expect(state.streak).to.equal(3)
		end)

		it("refuses a second claim the same day, changing nothing", function()
			local state = { lastDay = 100, streak = 3 }
			expect((DailyRewardRules.claim(state, 100, 7))).to.equal(false)
			expect(state.streak).to.equal(3)
		end)
	end)

	describe("validate", function()
		it("accepts whole non-negative numbers only", function()
			expect(DailyRewardRules.validate({ lastDay = 0, streak = 0 })).to.equal(true)
			expect(DailyRewardRules.validate({ lastDay = 5, streak = 1.5 })).to.equal(false)
			expect(DailyRewardRules.validate({ lastDay = -1, streak = 0 })).to.equal(false)
			expect(DailyRewardRules.validate({ lastDay = "x", streak = 0 })).to.equal(false)
		end)
	end)
end
