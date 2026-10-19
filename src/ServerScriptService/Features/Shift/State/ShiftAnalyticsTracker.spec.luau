local ShiftAnalyticsTracker = require(script.Parent.ShiftAnalyticsTracker)

local function record(event)
	return {
		event = event,
		session = "studio",
		build = "m5-dev",
		tags = "1.5s+10s",
		cohort = "new",
		platform = "pc",
		party = 1,
		target = "none",
		outcome = "none",
		reason = "none",
		value = 0,
	}
end

return function()
	describe("per shift", function()
		it("reports a player's first cleanup once per shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:firstCleanup(7)).to.equal(true)
			expect(tracker:firstCleanup(7)).to.equal(false)
			expect(tracker:firstCleanup(8)).to.equal(true)
			tracker:beginShift()
			expect(tracker:firstCleanup(7)).to.equal(true)
		end)

		it("counts piles per player and clears them with a new shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			tracker:addPile(7)
			tracker:addPile(7)
			tracker:addPile(8)
			expect(tracker:pilesOf(7)).to.equal(2)
			expect(tracker:pilesOf(8)).to.equal(1)
			expect(tracker:pilesOf(9)).to.equal(0)
			tracker:beginShift()
			expect(tracker:pilesOf(7)).to.equal(0)
		end)

		it("remembers only the first quota time in a shift", function()
			local tracker = ShiftAnalyticsTracker.new(10, 4)
			expect(tracker:quotaAt()).to.equal(nil)
			expect(tracker:markQuota(200)).to.equal(true)
			expect(tracker:markQuota(250)).to.equal(false)
			expect(tracker:quotaAt()).to.equal(200)
			tracker:beginShift()
			expect(tracker:quotaAt()).to.equal(nil)
		end)
	end)

	describe("rings", function()
		it("keeps the newest noises up to the limit, oldest first", function()
			local tracker = ShiftAnalyticsTracker.new(10, 2)
			for index = 1, 3 do
				tracker:noteNoise({ source = "vacuum", position = Vector3.new(index, 0, 0), radius = 40, at = index })
			end
			local noises = tracker:noises()
			expect(#noises).to.equal(2)
			expect(noises[1].at).to.equal(2)
			expect(noises[2].at).to.equal(3)
			tracker:beginShift()
			expect(#tracker:noises()).to.equal(0)
		end)

		it("keeps the newest records up to the limit and hands out a copy", function()
			local tracker = ShiftAnalyticsTracker.new(2, 4)
			tracker:remember(record("contract_started"))
			tracker:remember(record("pile_cleared"))
			tracker:remember(record("quota_met"))
			local recent = tracker:recent()
			expect(#recent).to.equal(2)
			expect(recent[1].event).to.equal("pile_cleared")
			expect(recent[2].event).to.equal("quota_met")
			table.clear(recent)
			expect(#tracker:recent()).to.equal(2)
		end)
	end)
end
