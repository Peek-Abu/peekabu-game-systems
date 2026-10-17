local OccupantDreadTracker = require(script.Parent.OccupantDreadTracker)

return function()
	afterEach(function()
		OccupantDreadTracker.clear()
	end)

	it("starts clear: nothing on screen", function()
		local frame = OccupantDreadTracker.get()
		expect(frame.vignette).to.equal(0)
		expect(frame.grain).to.equal(0)
		expect(frame.edge).to.equal(0)
		expect(frame.still).to.equal(false)
	end)

	it("keeps the last frame set, as a copy", function()
		local frame = { vignette = 0.4, grain = 0.2, edge = 0.7, still = true }
		OccupantDreadTracker.set(frame)
		frame.vignette = 1
		local got = OccupantDreadTracker.get()
		expect(got.vignette).to.equal(0.4)
		expect(got.grain).to.equal(0.2)
		expect(got.edge).to.equal(0.7)
		expect(got.still).to.equal(true)
	end)

	it("clears back to nothing", function()
		OccupantDreadTracker.set({ vignette = 0.4, grain = 0.2, edge = 0.7, still = false })
		OccupantDreadTracker.clear()
		expect(OccupantDreadTracker.get().vignette).to.equal(0)
	end)
end
