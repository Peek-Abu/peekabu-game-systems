local DepotModeTracker = require(script.Parent.DepotModeTracker)

return function()
	local tracker

	beforeEach(function()
		tracker = DepotModeTracker.new()
	end)

	it("plays Night Shift on a truck nobody picked for", function()
		expect(tracker:modeOf("pad1")).to.equal("night")
	end)

	it("keeps a pick per truck and says when it changed", function()
		expect(tracker:pick("pad1", "quick")).to.equal(true)
		expect(tracker:modeOf("pad1")).to.equal("quick")
		expect(tracker:modeOf("pad2")).to.equal("night")
		expect(tracker:pick("pad1", "quick")).to.equal(false)
		expect(tracker:pick("pad1", "night")).to.equal(true)
		expect(tracker:modeOf("pad1")).to.equal("night")
	end)

	it("forgets a truck's pick when it is cleared (the party left)", function()
		tracker:pick("pad1", "quick")
		expect(tracker:clear("pad1")).to.equal(true)
		expect(tracker:modeOf("pad1")).to.equal("night")
		expect(tracker:clear("pad1")).to.equal(false)
	end)

	it("keeps only the live trucks' picks", function()
		tracker:pick("pad1", "quick")
		tracker:pick("pad2", "quick")
		expect(tracker:retain({ pad1 = true })).to.equal(true)
		expect(tracker:modeOf("pad1")).to.equal("quick")
		expect(tracker:modeOf("pad2")).to.equal("night")
		expect(tracker:retain({ pad1 = true })).to.equal(false)
	end)

	it("snapshots the picks as a fresh table and resets", function()
		tracker:pick("pad1", "quick")
		local entry = tracker:snapshot()
		expect(entry.pad1).to.equal("quick")
		entry.pad1 = "night"
		expect(tracker:modeOf("pad1")).to.equal("quick")
		tracker:reset()
		expect(tracker:modeOf("pad1")).to.equal("night")
		expect(next(tracker:snapshot())).to.equal(nil)
	end)
end
