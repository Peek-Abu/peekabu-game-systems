local Rules = require(script.Parent.WorkOrderRules)
local Registry = require(script.Parent.Parent.Data.WorkOrderRegistry)
return function()
	it("notifies progress milestones and completion without repeating payment", function()
		local order = { target = 10, label = "Clear 10 piles", kind = "piles", id = "test" }
		expect(Rules.feedback(0, 1, false, order)).to.equal("Today's job: 1/10")
		expect(Rules.feedback(1, 2, false, order)).to.equal(nil)
		expect(Rules.feedback(4, 5, false, order)).to.equal("Today's job: 5/10")
		expect(Rules.feedback(9, 10, true, order)).to.equal("TODAY'S JOB DONE • +100 Credits")
	end)

	describe("WorkOrderRules", function()
		it("resets progress and reward at UTC midnight without mutating yesterday", function()
			local old = { day = 20000, progress = 8, claimed = true }
			local rolled = Rules.roll(old, 20001 * 86400)
			expect(rolled.day).to.equal(20001)
			expect(rolled.progress).to.equal(0)
			expect(rolled.claimed).to.equal(false)
			expect(old.progress).to.equal(8)
		end)
		it("validates finite integers, target cap and earned claims", function()
			local day = 20000
			local target = Registry.orderFor(day * 86400).target
			expect(Rules.validate({ day = day, progress = target, claimed = true })).to.equal(true)
			expect(Rules.validate({ day = day, progress = target - 1, claimed = true })).to.equal(false)
			expect(Rules.validate({ day = day, progress = target + 1, claimed = false })).to.equal(false)
			expect(Rules.validate({ day = "bad", progress = 0, claimed = false })).to.equal(false)
			expect(Rules.validate({ day = math.huge, progress = 0, claimed = false })).to.equal(false)
			expect(Rules.validate({ day = day, progress = 0 / 0, claimed = false })).to.equal(false)
		end)
	end)
end
