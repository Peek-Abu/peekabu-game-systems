--!nocheck
--[=[
	Unit tests for UIRenderCounters — the per-screen render tally the F4 UI tab displays.

	Its whole reason to exist is to make a performance CLAIM checkable: the Vitals HUD drives health
	through a React binding rather than state, so its render count must stay flat while health changes.
	Without a counter that assertion is just a comment.
]=]

local UIRenderCounters = require(script.Parent.UIRenderCounters)

return function()
	beforeEach(function()
		UIRenderCounters.reset()
	end)
	afterEach(function()
		UIRenderCounters.reset() -- leave the shared tally clean for other specs
	end)

	it("starts with no counters", function()
		expect(next(UIRenderCounters.snapshot())).to.equal(nil)
	end)

	it("counts ticks per name independently", function()
		UIRenderCounters.tick("VitalsHud")
		UIRenderCounters.tick("VitalsHud")
		UIRenderCounters.tick("Inventory")
		local snapshot = UIRenderCounters.snapshot()
		expect(snapshot.VitalsHud).to.equal(2)
		expect(snapshot.Inventory).to.equal(1)
	end)

	it("returns a copy, so callers cannot corrupt the tally", function()
		UIRenderCounters.tick("VitalsHud")
		local snapshot = UIRenderCounters.snapshot()
		snapshot.VitalsHud = 999
		expect(UIRenderCounters.snapshot().VitalsHud).to.equal(1)
	end)

	it("clears on reset", function()
		UIRenderCounters.tick("VitalsHud")
		UIRenderCounters.reset()
		expect(next(UIRenderCounters.snapshot())).to.equal(nil)
	end)
end
