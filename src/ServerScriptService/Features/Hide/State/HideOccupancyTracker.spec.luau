local HideOccupancyTracker = require(script.Parent.HideOccupancyTracker)

return function()
	local tracker
	beforeEach(function()
		tracker = HideOccupancyTracker.new()
	end)

	it("puts one player in one spot, and remembers when and whether they were seen", function()
		expect(tracker:enter(1, "desk.1", 10, true)).to.equal(true)
		local entry = tracker:of(1)
		expect(entry.spotId).to.equal("desk.1")
		expect(entry.since).to.equal(10)
		expect(entry.seenEntering).to.equal(true)
		expect(tracker:occupant("desk.1")).to.equal(1)
	end)

	it("refuses a taken spot and a second spot for someone already hidden", function()
		tracker:enter(1, "desk.1", 10, false)
		expect(tracker:enter(2, "desk.1", 11, false)).to.equal(false)
		expect(tracker:enter(1, "locker.1", 11, false)).to.equal(false)
		expect(tracker:occupant("locker.1")).to.equal(nil)
	end)

	it("hands back the stay on leaving and frees the spot", function()
		tracker:enter(1, "desk.1", 10, false)
		local left = tracker:leave(1)
		expect(left.spotId).to.equal("desk.1")
		expect(tracker:of(1)).to.equal(nil)
		expect(tracker:occupant("desk.1")).to.equal(nil)
		expect(tracker:leave(1)).to.equal(nil)
	end)

	it("marks a hiding player seen later (a stare-down that finds them)", function()
		tracker:enter(1, "desk.1", 10, false)
		expect(tracker:setSeen(1, true)).to.equal(true)
		expect(tracker:of(1).seenEntering).to.equal(true)
		expect(tracker:setSeen(2, true)).to.equal(false)
	end)

	it("cools a spot off for one player only, until the given time", function()
		tracker:cool(1, "desk.1", 20)
		expect(tracker:cooling(1, "desk.1", 19.9)).to.equal(true)
		expect(tracker:cooling(1, "desk.1", 20)).to.equal(false)
		expect(tracker:cooling(2, "desk.1", 10)).to.equal(false)
	end)

	it("lists who is hidden, and forgets everything on clear", function()
		tracker:enter(1, "desk.1", 10, false)
		tracker:enter(2, "locker.1", 10, false)
		local count = 0
		for _ in tracker:all() do
			count += 1
		end
		expect(count).to.equal(2)
		tracker:cool(1, "desk.1", 99)
		tracker:clear()
		expect(tracker:of(1)).to.equal(nil)
		expect(tracker:cooling(1, "desk.1", 0)).to.equal(false)
	end)

	it("forgets a player who left: their stay and their cooling spots", function()
		tracker:enter(1, "desk.1", 10, false)
		tracker:cool(1, "locker.1", 99)
		tracker:cool(2, "locker.1", 99)
		tracker:forget(1)
		expect(tracker:of(1)).to.equal(nil)
		expect(tracker:occupant("desk.1")).to.equal(nil)
		expect(tracker:cooling(1, "locker.1", 0)).to.equal(false)
		expect(tracker:cooling(2, "locker.1", 0)).to.equal(true)
	end)
end
