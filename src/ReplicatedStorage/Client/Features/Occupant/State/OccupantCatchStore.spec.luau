local OccupantCatchStore = require(script.Parent.OccupantCatchStore)

local REPORT = { room = "Archive", clock = 222, backAt = 1008, dropped = { "Monitor" } }

return function()
	afterEach(function()
		OccupantCatchStore.clear()
	end)

	it("holds the scare beat between snap and endSnap", function()
		expect(OccupantCatchStore.scaring()).to.equal(false)
		OccupantCatchStore.snap()
		expect(OccupantCatchStore.scaring()).to.equal(true)
		OccupantCatchStore.endSnap()
		expect(OccupantCatchStore.scaring()).to.equal(false)
	end)

	it("keeps the report and forgets an older rehire notice", function()
		OccupantCatchStore.rehired(5)
		OccupantCatchStore.setReport(REPORT)
		expect(OccupantCatchStore.report().room).to.equal("Archive")
		expect(OccupantCatchStore.rehiredAt()).to.equal(nil)
	end)

	it("keeps the report through the rehire (the card lists what dropped)", function()
		OccupantCatchStore.setReport(REPORT)
		OccupantCatchStore.rehired(12)
		expect(OccupantCatchStore.rehiredAt()).to.equal(12)
		expect(OccupantCatchStore.report().dropped[1]).to.equal("Monitor")
	end)

	it("copies the report it is given", function()
		local report = table.clone(REPORT)
		OccupantCatchStore.setReport(report)
		report.room = "changed"
		expect(OccupantCatchStore.report().room).to.equal("Archive")
	end)

	it("clears everything", function()
		OccupantCatchStore.snap()
		OccupantCatchStore.setReport(REPORT)
		OccupantCatchStore.rehired(1)
		OccupantCatchStore.clear()
		expect(OccupantCatchStore.scaring()).to.equal(false)
		expect(OccupantCatchStore.report()).to.equal(nil)
		expect(OccupantCatchStore.rehiredAt()).to.equal(nil)
	end)
end
