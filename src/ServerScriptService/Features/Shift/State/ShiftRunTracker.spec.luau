local ShiftRunTracker = require(script.Parent.ShiftRunTracker)

return function()
	describe("new", function()
		it("starts with no review, nothing pending, no coffee and no training run", function()
			local run = ShiftRunTracker.new()
			expect(run.results).to.equal(nil)
			expect(run.resetPending).to.equal(false)
			expect(run.endingRun).to.equal(false)
			expect(run.coffeeBy).to.equal(nil)
			expect(run.coffeeSeconds).to.equal(0)
			expect(run.training).to.equal(false)
		end)

		it("gives every shift service its own record", function()
			local first = ShiftRunTracker.new()
			local second = ShiftRunTracker.new()
			first.coffeeSeconds = 30
			first.training = true
			expect(second.coffeeSeconds).to.equal(0)
			expect(second.training).to.equal(false)
		end)
	end)
end
