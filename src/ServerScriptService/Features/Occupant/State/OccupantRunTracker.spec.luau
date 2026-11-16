local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantRunTracker = require(script.Parent.OccupantRunTracker)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

return function()
	describe("new", function()
		it("is a run with no monster yet: no rig, mind, shift, layout, noise, door beat or walk target", function()
			local run = OccupantRunTracker.new()
			expect(run.rig).to.equal(nil)
			expect(run.mind).to.equal(nil)
			expect(run.shift).to.equal(nil)
			expect(run.place).to.equal(nil)
			expect(run.pendingNoise).to.equal(nil)
			expect(run.holdUntil).to.equal(0)
			expect(run.lastGoal).to.equal(nil)
		end)

		it("starts on the default kind with random rolls and no QA seam or forced turn", function()
			local run = OccupantRunTracker.new()
			expect(run.currentKind).to.equal(OccupantKindRegistry.DEFAULT)
			expect(typeof(run.rng)).to.equal("Random")
			expect(run.fixedRolls).to.equal(nil)
			expect(run.pendingForce).to.equal(nil)
		end)

		it("starts every counter at 0", function()
			local counters = OccupantRunTracker.new().counters
			for _, name in { "spawned", "heard", "chases", "catches", "watchThinks", "watchJerks" } do
				expect(counters[name]).to.equal(0)
			end
		end)

		it("gives each run its own counters", function()
			local first = OccupantRunTracker.new()
			local second = OccupantRunTracker.new()
			first.counters.spawned += 1
			expect(second.counters.spawned).to.equal(0)
		end)
	end)

	describe("run", function()
		it("is the one live run the service and its brain share", function()
			expect(OccupantRunTracker.run).to.be.ok()
			expect(OccupantRunTracker.run.counters).to.be.ok()
		end)
	end)
end
