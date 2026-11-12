local ServerScriptService = game:GetService("ServerScriptService")

local TrainingZoneRules = require(ServerScriptService.Features.Training.Rules.TrainingZoneRules)

return function()
	describe("plan", function()
		it("keeps one empty pad ready in an empty bay", function()
			expect(TrainingZoneRules.plan(0, 0, 0, 12)).to.equal(1)
			expect(TrainingZoneRules.plan(0, 1, 0, 12)).to.equal(0)
		end)

		it("adds a pad for every player waiting in the bay, plus one spare", function()
			-- Three players walk in together: three seats for them and a spare for the next one.
			expect(TrainingZoneRules.plan(0, 1, 3, 12)).to.equal(3)
			-- Two are already counting down on their own pads, one more waits.
			expect(TrainingZoneRules.plan(2, 1, 1, 12)).to.equal(1)
		end)

		it("drops only empty pads, never one in use, down to the spare", function()
			expect(TrainingZoneRules.plan(0, 4, 0, 12)).to.equal(-3)
			expect(TrainingZoneRules.plan(3, 0, 0, 2)).to.equal(0)
			expect(TrainingZoneRules.plan(3, 2, 0, 2)).to.equal(-2)
		end)

		it("never grows past the cap", function()
			expect(TrainingZoneRules.plan(0, 0, 40, 12)).to.equal(12)
			expect(TrainingZoneRules.plan(12, 0, 5, 12)).to.equal(0)
			expect(TrainingZoneRules.plan(10, 1, 5, 12)).to.equal(1)
		end)
	end)

	describe("idle", function()
		it("lets a pad go only after it has been empty for the whole grace time", function()
			expect(TrainingZoneRules.idle(true, nil, 100, 60)).to.equal(false)
			expect(TrainingZoneRules.idle(false, nil, 100, 60)).to.equal(true)
			expect(TrainingZoneRules.idle(false, 50, 100, 60)).to.equal(false)
			expect(TrainingZoneRules.idle(false, 40, 100, 60)).to.equal(true)
		end)
	end)
end
