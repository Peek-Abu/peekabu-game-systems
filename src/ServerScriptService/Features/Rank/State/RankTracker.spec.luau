local RankTracker = require(script.Parent.RankTracker)

return function()
	describe("RankTracker", function()
		it("holds nothing until a player's rank is set", function()
			local tracker = RankTracker.new()
			expect(tracker:get(1)).to.equal(nil)
			expect(tracker:count()).to.equal(0)
		end)

		it("keeps each player's session rank and hands out copies", function()
			local tracker = RankTracker.new()
			tracker:set(1, { season = "s", xp = 10, lastAwardedRunId = "" })
			tracker:set(2, { season = "s", xp = 20, lastAwardedRunId = "" })
			local copy = tracker:get(1)
			copy.xp = 999
			expect(tracker:get(1).xp).to.equal(10)
			expect(tracker:get(2).xp).to.equal(20)
			expect(tracker:count()).to.equal(2)
		end)

		it("edits a rank in place through update, reporting whether it changed", function()
			local tracker = RankTracker.new()
			tracker:set(1, { season = "s", xp = 10, lastAwardedRunId = "" })
			expect(tracker:update(1, function(state)
				state.xp += 5
				return true
			end)).to.equal(true)
			expect(tracker:get(1).xp).to.equal(15)
			expect(tracker:update(1, function()
				return false
			end)).to.equal(false)
			expect(tracker:update(9, function()
				return true
			end)).to.equal(false)
		end)

		it("forgets a player and clears everyone", function()
			local tracker = RankTracker.new()
			tracker:set(1, { season = "s", xp = 10, lastAwardedRunId = "" })
			tracker:set(2, { season = "s", xp = 10, lastAwardedRunId = "" })
			tracker:forget(1)
			expect(tracker:get(1)).to.equal(nil)
			tracker:clear()
			expect(tracker:count()).to.equal(0)
		end)
	end)
end
