local DeathCreditTracker = require(script.Parent.DeathCreditTracker)

-- Any table works as a key in the tracker; the service uses Humanoids.
local victim = {}
local other = {}

return function()
	it("credits the last source within the window", function()
		local tracker = DeathCreditTracker.new()
		tracker:record(victim, { userId = 1, name = "A" }, 10)
		tracker:record(victim, { name = "monster" }, 12)
		local source = tracker:credit(victim, 15, 10)
		expect(source.name).to.equal("monster")
		expect(source.userId).to.equal(nil)
	end)

	it("credits nobody once the window has passed", function()
		local tracker = DeathCreditTracker.new()
		tracker:record(victim, { userId = 1, name = "A" }, 10)
		expect(tracker:credit(victim, 20.5, 10)).to.equal(nil)
	end)

	it("keeps victims apart and forgets one", function()
		local tracker = DeathCreditTracker.new()
		tracker:record(victim, { userId = 1, name = "A" }, 0)
		tracker:record(other, { userId = 2, name = "B" }, 0)
		tracker:forget(victim)
		expect(tracker:credit(victim, 1, 10)).to.equal(nil)
		expect(tracker:credit(other, 1, 10).userId).to.equal(2)
	end)
end
