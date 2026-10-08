--[=[
	Unit tests for the AnimationLocomotionRegistry animation domain — the seed set AnimationLocomotionSystem plays, captured
	from the ids the old game's running Animate fork ACTUALLY played (its config children), not its
	stale tables.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationLocomotionRegistry =
	require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationLocomotionRegistry)
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

-- The poses this phase animates. Their presence is a contract with AnimationLocomotionSystem: a missing
-- key here is a pose the animator cannot play.
local CORE_POSES = {
	"idle",
	"walk",
	"run",
	"jump",
	"fall",
	"climb",
	"swim",
	"swimidle",
	"sit",
}

return function()
	describe("core pose coverage", function()
		it("declares every pose AnimationLocomotionSystem animates", function()
			for _, pose in CORE_POSES do
				expect(AnimationLocomotionRegistry[pose]).to.be.ok()
			end
		end)
	end)

	describe("entry well-formedness", function()
		it("gives every entry a canonical asset id, valid class, and boolean looped", function()
			for _key, def in AnimationLocomotionRegistry do
				expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
				expect(AnimationTypes.isInterruptionClass(def.interruption)).to.equal(true)
				expect(type(def.looped)).to.equal("boolean")
				expect(def.priority).to.be.ok()
				if def.variants ~= nil then
					expect(#def.variants > 0).to.equal(true)
					for _, variantId in def.variants do
						expect(AnimationTypes.isCanonicalAssetId(variantId)).to.equal(true)
					end
				end
			end
		end)

		it("declares every locomotion entry ambient — bulk combat stops must never kill locomotion", function()
			for _, def in AnimationLocomotionRegistry do
				expect(def.interruption).to.equal("ambient")
			end
		end)

		it("loops sustained poses and does not loop one-shots", function()
			expect(AnimationLocomotionRegistry.idle.looped).to.equal(true)
			expect(AnimationLocomotionRegistry.walk.looped).to.equal(true)
			expect(AnimationLocomotionRegistry.run.looped).to.equal(true)
			expect(AnimationLocomotionRegistry.jump.looped).to.equal(false)
		end)

		it("declares no locomotion entry replicable — locomotion stays local (R3)", function()
			for _, def in AnimationLocomotionRegistry do
				expect(def.replicable).to.equal(nil)
				expect(def.wireId).to.equal(nil)
			end
		end)

		it("declares NO death entry — the old game deprecated its death animation (V5 decision)", function()
			expect(AnimationLocomotionRegistry.death).to.equal(nil)
		end)
	end)

	describe("frozen data", function()
		it("is frozen at every level — a domain is data, not a mutable table", function()
			expect(table.isfrozen(AnimationLocomotionRegistry)).to.equal(true)
			expect(table.isfrozen(AnimationLocomotionRegistry.idle)).to.equal(true)
		end)
	end)
end
