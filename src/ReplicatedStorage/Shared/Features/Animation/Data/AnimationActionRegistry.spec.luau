--[=[
	Unit tests for the AnimationActionRegistry domain — the replicated-action stand-ins R3 proves the pipeline with
	(`animationplay` until combat, abilities and emotes bring real actions).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationActionRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationActionRegistry)
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

return function()
	describe("stand-ins", function()
		it("declares testleap, testguard and testpose", function()
			expect(AnimationActionRegistry.testleap).to.be.ok()
			expect(AnimationActionRegistry.testguard).to.be.ok()
			expect(AnimationActionRegistry.testpose).to.be.ok()
		end)

		it("makes every entry a replicable action above locomotion's Core priority", function()
			for _, def in AnimationActionRegistry do
				expect(def.replicable).to.equal(true)
				expect(def.wireId).to.be.a("number")
				expect(AnimationTypes.isAnimationLayer(def.layer)).to.equal(true)
				-- Core is the base locomotion plays at: an action there blends at half weight with it.
				expect(def.priority).never.to.equal(Enum.AnimationPriority.Core)
			end
		end)

		it("declares durationMs for exactly the one-shots", function()
			for _, def in AnimationActionRegistry do
				if def.looped then
					expect(def.durationMs).to.equal(nil)
				else
					expect(def.durationMs > 0).to.equal(true)
				end
			end
		end)

		it("covers what the two-client checklist needs: a variant, two layers, attack vs protected", function()
			expect(#AnimationActionRegistry.testleap.variants >= 1).to.equal(true)
			expect(AnimationActionRegistry.testleap.layer).to.equal("full")
			expect(AnimationActionRegistry.testleap.interruption).to.equal("attack")
			expect(AnimationActionRegistry.testguard.layer).to.equal("full")
			expect(AnimationActionRegistry.testguard.interruption).to.equal("protected")
			expect(AnimationActionRegistry.testpose.layer).to.equal("upper")
			expect(AnimationActionRegistry.testpose.looped).to.equal(true)
		end)
	end)

	describe("frozen data", function()
		it("is frozen at every level", function()
			expect(table.isfrozen(AnimationActionRegistry)).to.equal(true)
			expect(table.isfrozen(AnimationActionRegistry.testleap)).to.equal(true)
			expect(table.isfrozen(AnimationActionRegistry.testleap.variants)).to.equal(true)
		end)
	end)
end
