local OccupantDreadStore = require(script.Parent.OccupantDreadStore)

return function()
	afterEach(function()
		OccupantDreadStore.clear()
	end)

	it("starts with no dread and no danger", function()
		expect(OccupantDreadStore.stage()).to.equal("none")
		expect(OccupantDreadStore.danger()).to.equal(false)
	end)

	it("calls any dread stage a danger: near, aware, chase or a chased crewmate", function()
		for _, stage in { "near", "aware", "chase", "crew" } do
			OccupantDreadStore.setStage(stage)
			expect(OccupantDreadStore.stage()).to.equal(stage)
			expect(OccupantDreadStore.danger()).to.equal(true)
		end
		OccupantDreadStore.setStage("none")
		expect(OccupantDreadStore.danger()).to.equal(false)
	end)

	it("clears back to no dread", function()
		OccupantDreadStore.setStage("chase")
		OccupantDreadStore.clear()
		expect(OccupantDreadStore.stage()).to.equal("none")
	end)
end
