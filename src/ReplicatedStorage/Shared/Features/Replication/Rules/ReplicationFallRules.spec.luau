local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local ReplicationFallRules = require(ReplicatedStorage.Shared.Features.Replication.Rules.ReplicationFallRules)

return function()
	describe("hasFallen", function()
		it("accepts a position at or below the destroy height plus the margin", function()
			expect(ReplicationFallRules.hasFallen(-400, -500)).to.equal(true)
			expect(ReplicationFallRules.hasFallen(-300, -500)).to.equal(false)
		end)

		it("uses the codec floor when the destroy height is below what a record can carry", function()
			-- The wire clamps Y at the floor, so a fall in a deep-void place still reads as the floor.
			expect(ReplicationFallRules.hasFallen(Codec.Y_FLOOR, -5000)).to.equal(true)
			expect(ReplicationFallRules.hasFallen(Codec.Y_FLOOR + ReplicationFallRules.MARGIN + 1, -5000)).to.equal(
				false
			)
		end)

		it("refuses a body standing well above the plane", function()
			expect(ReplicationFallRules.hasFallen(50, -500)).to.equal(false)
		end)
	end)

	describe("decide", function()
		it("answers fell when the last accepted position is near the plane", function()
			expect(ReplicationFallRules.decide(-450, -500, nil, 0)).to.equal("fell")
			expect(ReplicationFallRules.decide(-450, -500, 1000, 1500)).to.equal("fell")
		end)

		it("refuses a body above the plane until it has been asking for STRANDED_MS", function()
			expect(ReplicationFallRules.decide(5, -500, nil, 10000)).to.equal("refuse")
			expect(ReplicationFallRules.decide(5, -500, 10000, 10000 + ReplicationFallRules.STRANDED_MS - 1)).to.equal(
				"refuse"
			)
		end)

		it("answers stranded once refused requests have spanned STRANDED_MS", function()
			-- The rig is gone but the server last saw it on the ground (a teleport below the plane, or a
			-- hitch mid-fall): without this the player stays bodiless until they rejoin.
			expect(ReplicationFallRules.decide(5, -500, 10000, 10000 + ReplicationFallRules.STRANDED_MS)).to.equal(
				"stranded"
			)
		end)
	end)

	describe("runStart", function()
		it("starts a run on the first refusal and keeps it while requests keep coming", function()
			expect(ReplicationFallRules.runStart(nil, nil, 1000)).to.equal(1000)
			expect(ReplicationFallRules.runStart(1000, 2000, 3000)).to.equal(1000)
		end)

		it("starts a fresh run after a silence longer than RUN_GAP_MS", function()
			-- Leftover retries from an earlier respawn must not count toward a later death's wait.
			expect(ReplicationFallRules.runStart(1000, 2000, 2000 + ReplicationFallRules.RUN_GAP_MS + 1)).to.equal(
				2000 + ReplicationFallRules.RUN_GAP_MS + 1
			)
		end)
	end)

	describe("answer", function()
		it("records refusals into a run and answers stranded once it spans STRANDED_MS", function()
			local runs = ReplicationFallRules.newRuns()
			expect(ReplicationFallRules.answer(runs, 7, 5, -500, 1000)).to.equal("refuse")
			expect(ReplicationFallRules.answer(runs, 7, 5, -500, 2000)).to.equal("refuse")
			expect(ReplicationFallRules.answer(runs, 7, 5, -500, 1000 + ReplicationFallRules.STRANDED_MS)).to.equal(
				"stranded"
			)
		end)

		it("answers fell near the plane without touching the run", function()
			local runs = ReplicationFallRules.newRuns()
			expect(ReplicationFallRules.answer(runs, 7, -450, -500, 1000)).to.equal("fell")
			expect(runs.since[7]).to.equal(nil)
		end)

		it("clear forgets the run, so the next refusal starts a new one", function()
			local runs = ReplicationFallRules.newRuns()
			ReplicationFallRules.answer(runs, 7, 5, -500, 1000)
			ReplicationFallRules.clear(runs, 7)
			expect(ReplicationFallRules.answer(runs, 7, 5, -500, 1000 + ReplicationFallRules.STRANDED_MS)).to.equal(
				"refuse"
			)
		end)
	end)
end
