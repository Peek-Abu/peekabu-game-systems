local SkillCheckRingTracker = require(script.Parent.SkillCheckRingTracker)

local CONFIG = {
	travel = 1.2,
	firstDelay = 0.35,
	between = 0.4,
	widthStart = 120,
	widthEnd = 60,
	minShift = 90,
	tolerance = 8,
	early = 0.25,
	late = 0.6,
}

-- A random source that hands out the given rolls in turn (then repeats the last).
local function rolls(list)
	local index = 0
	return function()
		index = math.min(index + 1, #list)
		return list[index]
	end
end

-- Starts one ring for `userId` at `now` (on a pile at `progress`), returning it.
local function startRing(tracker, userId, now, progress)
	tracker:step(userId, true, progress or 0, now)
	return tracker:step(userId, true, progress or 0, now + CONFIG.firstDelay)
end

return function()
	describe("scheduling", function()
		it("starts no ring until the first delay has passed on a pile", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			expect(tracker:step(1, true, 0, 10)).to.equal(nil)
			expect(tracker:step(1, true, 0, 10.3)).to.equal(nil)
			local ring = tracker:step(1, true, 0, 10.35)
			expect(ring).to.be.ok()
			expect(tracker:pending(1)).to.equal(ring)
		end)

		it("starts nothing off a pile", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			for t = 0, 5, 0.5 do
				expect(tracker:step(1, false, 0, t)).to.equal(nil)
			end
			expect(tracker:pending(1)).to.equal(nil)
		end)

		it("restarts the first delay after leaving the pile before a ring", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			tracker:step(1, true, 0, 10)
			tracker:step(1, false, 0, 10.2)
			expect(tracker:step(1, true, 0, 10.36)).to.equal(nil)
			expect(tracker:step(1, true, 0, 10.72)).to.be.ok()
		end)

		it("keeps one ring at a time", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			expect(ring).to.be.ok()
			expect(tracker:step(1, true, 0, 10.8)).to.equal(nil)
			expect(tracker:pending(1)).to.equal(ring)
		end)

		it("sets the arrival one travel after the start", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			expect(math.abs(ring.arriveAt - (10.35 + 1.2)) < 1e-9).to.equal(true)
			expect(ring.travel).to.equal(1.2)
		end)

		it("narrows the opening with the pile's progress", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			expect(startRing(tracker, 1, 10, 0).width).to.equal(120)
			expect(startRing(tracker, 2, 10, 0.5).width).to.equal(90)
			expect(startRing(tracker, 3, 10, 1).width).to.equal(60)
		end)

		it("places the first opening by the roll and later ones well away from the last", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0.25, 0, 0.5 }))
			local first = startRing(tracker, 1, 10)
			expect(first.gap).to.equal(90)
			tracker:report(1, first.id, 0, first.arriveAt)
			local second = tracker:step(1, true, 0, first.arriveAt + CONFIG.between)
			expect(second).to.be.ok()
			expect(second.gap).to.equal(180)
		end)

		it("waits the gap between rings after a verdict", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			tracker:report(1, ring.id, 0, ring.arriveAt)
			expect(tracker:step(1, true, 0, ring.arriveAt + 0.39)).to.equal(nil)
			expect(tracker:step(1, true, 0, ring.arriveAt + 0.4)).to.be.ok()
		end)

		it("still waits the gap after a verdict when the player lets go and starts again", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			tracker:report(1, ring.id, 0, ring.arriveAt)
			tracker:step(1, false, 0, ring.arriveAt)
			-- First delay (0.35) is shorter than the gap (0.4): the gap still holds.
			tracker:step(1, true, 0, ring.arriveAt + 0.01)
			expect(tracker:step(1, true, 0, ring.arriveAt + 0.37)).to.equal(nil)
			expect(tracker:step(1, true, 0, ring.arriveAt + 0.41)).to.be.ok()
		end)

		it("gives every ring its own increasing id across players", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local a = startRing(tracker, 1, 10)
			local b = startRing(tracker, 2, 10)
			expect(a.id >= 1).to.equal(true)
			expect(b.id > a.id).to.equal(true)
		end)
	end)

	describe("report", function()
		it("judges an angle inside the opening a hit", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0.25 }))
			local ring = startRing(tracker, 1, 10)
			local verdict = tracker:report(1, ring.id, 100, ring.arriveAt + 0.1)
			expect(verdict).to.be.ok()
			expect(verdict.hit).to.equal(true)
			expect(verdict.userId).to.equal(1)
			expect(verdict.ring).to.equal(ring)
			expect(tracker:pending(1)).to.equal(nil)
		end)

		it("judges an angle outside the opening a miss", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0.25 }))
			local ring = startRing(tracker, 1, 10)
			local verdict = tracker:report(1, ring.id, 270, ring.arriveAt)
			expect(verdict.hit).to.equal(false)
		end)

		it("counts the tolerance either side as a hit", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0.25 }))
			-- Gap 90, width 120: 30..150, plus 8 = 22..158.
			local ring = startRing(tracker, 1, 10)
			expect(tracker:report(1, ring.id, 157, ring.arriveAt).hit).to.equal(true)
			local other = startRing(tracker, 2, 10)
			expect(tracker:report(2, other.id, 159, other.arriveAt).hit).to.equal(false)
		end)

		it("judges across 0/360", function()
			-- Roll 0.99 puts the opening at 356.4.
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0.99 }))
			local ring = startRing(tracker, 1, 10)
			expect(tracker:report(1, ring.id, 20, ring.arriveAt).hit).to.equal(true)
		end)

		it("ignores a report for another ring and keeps the ring", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			local verdict, reason = tracker:report(1, ring.id + 1, 0, ring.arriveAt)
			expect(verdict).to.equal(nil)
			expect(reason).to.equal("wrong ring")
			expect(tracker:pending(1)).to.equal(ring)
		end)

		it("ignores another player's ring id", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local mine = startRing(tracker, 1, 10)
			startRing(tracker, 2, 10)
			local verdict, reason = tracker:report(2, mine.id, 0, mine.arriveAt)
			expect(verdict).to.equal(nil)
			expect(reason).to.equal("wrong ring")
		end)

		it("ignores a report with no ring out", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local verdict, reason = tracker:report(1, 1, 0, 10)
			expect(verdict).to.equal(nil)
			expect(reason).to.equal("no ring")
		end)

		it("ignores an early report and still takes one in the window", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			local verdict, reason = tracker:report(1, ring.id, 0, ring.arriveAt - 0.3)
			expect(verdict).to.equal(nil)
			expect(reason).to.equal("early")
			expect(tracker:pending(1)).to.equal(ring)
			expect(tracker:report(1, ring.id, 0, ring.arriveAt - 0.2).hit).to.equal(true)
		end)

		it("judges a late report a miss, whatever its angle", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			local verdict = tracker:report(1, ring.id, 0, ring.arriveAt + 0.7)
			expect(verdict.hit).to.equal(false)
			expect(tracker:pending(1)).to.equal(nil)
		end)

		it("judges a ring only once", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			tracker:report(1, ring.id, 0, ring.arriveAt)
			expect(tracker:report(1, ring.id, 0, ring.arriveAt)).to.equal(nil)
		end)

		it("still judges a ring in flight after the player left the pile", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			expect(tracker:step(1, false, 0, 10.8)).to.equal(nil)
			expect(tracker:pending(1)).to.equal(ring)
			expect(tracker:report(1, ring.id, 0, ring.arriveAt).hit).to.equal(true)
		end)
	end)

	describe("expire", function()
		it("misses a ring with no report once its window closes", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			expect(#tracker:expire(ring.arriveAt + 0.6)).to.equal(0)
			local missed = tracker:expire(ring.arriveAt + 0.61)
			expect(#missed).to.equal(1)
			expect(missed[1].userId).to.equal(1)
			expect(missed[1].hit).to.equal(false)
			expect(missed[1].ring).to.equal(ring)
			expect(tracker:pending(1)).to.equal(nil)
			expect(#tracker:expire(ring.arriveAt + 5)).to.equal(0)
		end)

		it("lists several players' misses in user order", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			startRing(tracker, 7, 10)
			startRing(tracker, 3, 10)
			local missed = tracker:expire(20)
			expect(#missed).to.equal(2)
			expect(missed[1].userId).to.equal(3)
			expect(missed[2].userId).to.equal(7)
		end)

		it("waits the gap after an expiry too", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			local ring = startRing(tracker, 1, 10)
			local closed = ring.arriveAt + 0.61
			tracker:expire(closed)
			expect(tracker:step(1, true, 0, closed + 0.3)).to.equal(nil)
			expect(tracker:step(1, true, 0, closed + 0.4)).to.be.ok()
		end)
	end)

	describe("forget and clear", function()
		it("forgets one player's ring and schedule", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			startRing(tracker, 1, 10)
			startRing(tracker, 2, 10)
			tracker:forget(1)
			expect(tracker:pending(1)).to.equal(nil)
			expect(tracker:pending(2)).to.be.ok()
			expect(#tracker:expire(20)).to.equal(1)
		end)

		it("clears everyone", function()
			local tracker = SkillCheckRingTracker.new(CONFIG, rolls({ 0 }))
			startRing(tracker, 1, 10)
			startRing(tracker, 2, 10)
			tracker:clear()
			expect(tracker:pending(1)).to.equal(nil)
			expect(tracker:pending(2)).to.equal(nil)
			expect(#tracker:expire(20)).to.equal(0)
			-- A cleared player starts from the first delay again.
			expect(tracker:step(1, true, 0, 30)).to.equal(nil)
			expect(tracker:step(1, true, 0, 30.35)).to.be.ok()
		end)
	end)
end
