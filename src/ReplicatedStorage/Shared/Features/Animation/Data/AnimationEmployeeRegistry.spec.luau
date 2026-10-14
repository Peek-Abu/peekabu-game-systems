local AnimationEmployeeRegistry = require(script.Parent.AnimationEmployeeRegistry)
local AnimationRegistry = require(script.Parent.AnimationRegistry)
local AnimationTypes = require(script.Parent.AnimationTypes)

return function()
	it("holds Pippa's idle, walk and run as looped Core locomotion with canonical ids", function()
		for _, key in { "pippaidle", "pippawalk", "pipparun" } do
			local def = AnimationEmployeeRegistry[key]
			expect(def).to.be.ok()
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
			expect(def.looped).to.equal(true)
			expect(def.priority).to.equal(Enum.AnimationPriority.Core)
			expect(def.interruption).to.equal("ambient")
			expect(def.replicable).never.to.equal(true)
		end
	end)

	it("is composed as the employee domain", function()
		expect(AnimationRegistry.domain("employee")).to.equal(AnimationEmployeeRegistry)
		expect(AnimationRegistry.domainOf("pippawalk")).to.equal("employee")
	end)

	it("is frozen", function()
		expect(table.isfrozen(AnimationEmployeeRegistry)).to.equal(true)
	end)
end
