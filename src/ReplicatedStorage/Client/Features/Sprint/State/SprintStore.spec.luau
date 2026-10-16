local SprintStore = require(script.Parent.SprintStore)

return function()
	afterEach(function()
		SprintStore.apply(nil, nil)
	end)

	it("copies the server's stamina and sprint flag", function()
		SprintStore.apply(0.42, true)
		expect(SprintStore.stamina()).to.equal(0.42)
		expect(SprintStore.sprinting()).to.equal(true)
	end)

	it("reads a missing or broken stamina as full, and clamps it", function()
		SprintStore.apply(nil, nil)
		expect(SprintStore.stamina()).to.equal(1)
		expect(SprintStore.sprinting()).to.equal(false)
		SprintStore.apply(0 / 0, "yes")
		expect(SprintStore.stamina()).to.equal(1)
		expect(SprintStore.sprinting()).to.equal(false)
		SprintStore.apply(3, false)
		expect(SprintStore.stamina()).to.equal(1)
	end)
end
