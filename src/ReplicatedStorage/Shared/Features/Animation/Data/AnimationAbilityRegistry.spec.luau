local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)
local Registry = require(script.Parent.AnimationAbilityRegistry)

return function()
	it("makes every clip a protected replicated action with its own wire id", function()
		local seen = {}
		for _, def in Registry do
			expect(def.replicable).to.equal(true)
			expect(def.interruption).to.equal("protected")
			expect(def.priority).to.equal(Enum.AnimationPriority.Action)
			expect(seen[def.wireId]).to.equal(nil)
			seen[def.wireId] = true
			expect(def.wireId >= 100 and def.wireId < 200).to.equal(true)
		end
	end)

	it("only holds clips an ability names", function()
		local named = {}
		for _, ability in AbilityRegistry.all() do
			for _, key in ability.clips do
				named[key] = true
			end
		end
		for key in Registry do
			expect(named[key]).to.equal(true)
		end
	end)

	it("plays Let's Go! full-body standing and on the upper layer moving", function()
		expect(Registry.pippaletsgo.layer).to.equal("full")
		expect(Registry.pippaletsgoupper.layer).to.equal("upper")
		expect(Registry.pippaletsgo.looped).to.equal(false)
		expect(Registry.pippaletsgo.durationMs).to.equal(3000)
	end)

	it("loops only the plant's hold, and times every one-shot", function()
		expect(Registry.pricklesplanthold.looped).to.equal(true)
		expect(Registry.pricklesplantenter.looped).to.equal(false)
		expect(Registry.pricklesplantexit.durationMs).to.equal(1600)
		expect(Registry.cappyspotit.durationMs).to.equal(3667)
		for _, def in Registry do
			expect(def.looped or def.durationMs ~= nil).to.equal(true)
		end
	end)
end
