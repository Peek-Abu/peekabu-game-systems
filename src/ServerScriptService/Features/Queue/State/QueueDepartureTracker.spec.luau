local QueueDepartureTracker = require(script.Parent.QueueDepartureTracker)

return function()
	local tracker

	beforeEach(function()
		tracker = QueueDepartureTracker.new()
	end)

	it("finishes when every member has left the server", function()
		local id = tracker:begin({ 7, 8 })
		expect(tracker:departureOf(7)).to.equal(id)
		expect(tracker:arrive(7)).to.equal(id)
		expect(tracker:finished(id)).to.equal(nil)
		tracker:arrive(8)
		local outcome = tracker:finished(id)
		expect(#outcome.gaveUp).to.equal(0)
		expect(tracker:finished(id)).to.equal(nil) -- reported once
	end)

	it("counts failures per player, only while their teleport is in flight", function()
		tracker:begin({ 7, 8 })
		expect(tracker:fail(7)).to.equal(nil) -- no attempt started yet
		tracker:attempt(7, 100)
		tracker:attempt(8, 100)
		expect(tracker:fail(7)).to.equal(1)
		expect(tracker:fail(7)).to.equal(nil) -- a second report for the same attempt
		tracker:attempt(7, 101)
		expect(tracker:fail(7)).to.equal(2)
		expect(tracker:fail(8)).to.equal(1)
		expect(tracker:fail(99)).to.equal(nil)
	end)

	it("reports the players it gave up on, and why", function()
		local id = tracker:begin({ 7, 8 })
		tracker:arrive(7)
		expect(tracker:giveUp(8, "flooded")).to.equal(id)
		local outcome = tracker:finished(id)
		expect(#outcome.gaveUp).to.equal(1)
		expect(outcome.gaveUp[1]).to.equal(8)
		expect(outcome.reason).to.equal("flooded")
	end)

	it("ignores a player who leaves after being given up on", function()
		tracker:begin({ 7 })
		tracker:giveUp(7, "failed")
		expect(tracker:arrive(7)).to.equal(nil)
		expect(tracker:departureOf(7)).to.equal(nil)
	end)

	it("keeps a player with the departure they are already on", function()
		local first = tracker:begin({ 7 })
		local second = tracker:begin({ 7, 8 })
		expect(tracker:departureOf(7)).to.equal(first)
		tracker:arrive(8)
		expect(#tracker:finished(second).gaveUp).to.equal(0)
	end)

	it("finds teleports that never resolved", function()
		tracker:begin({ 7, 8 })
		tracker:attempt(7, 100)
		tracker:attempt(8, 110)
		expect(#tracker:stale(114, 15)).to.equal(0)
		local stale = tracker:stale(115, 15)
		expect(#stale).to.equal(1)
		expect(stale[1]).to.equal(7)
		tracker:fail(7) -- the failure stops 7's clock until the retry starts
		local later = tracker:stale(200, 15)
		expect(#later).to.equal(1)
		expect(later[1]).to.equal(8)
	end)
end
