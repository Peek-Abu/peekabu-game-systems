local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)
local AbilityRules = require(script.Parent.AbilityRules)

local function use(id, overrides)
	local input = {
		running = true,
		participant = true,
		alive = true,
		caught = false,
		hidden = false,
		now = 100,
		readyAt = 0,
		def = AbilityRegistry.get(id),
		grounded = true,
		holding = false,
		hasTarget = true,
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function plant(overrides)
	local input = {
		now = 103,
		startedAt = 100,
		maxSeconds = 8,
		moved = 0,
		grounded = true,
		acting = false,
		alive = true,
		caught = false,
		cancelled = false,
	}
	for key, value in overrides or {} do
		input[key] = value
	end
	return input
end

local function reason(input)
	local _, why = AbilityRules.canUse(input)
	return why
end

return function()
	describe("canUse", function()
		it("allows a use with everything in order", function()
			for _, id in { "letsGo", "spotIt", "pottedPlant" } do
				local ok, why = AbilityRules.canUse(use(id))
				expect(ok).to.equal(true)
				expect(why).to.equal(nil)
			end
		end)

		it("refuses without an ability", function()
			local input = use("letsGo")
			input.def = nil
			expect(reason(input)).to.equal("noAbility")
		end)

		it("refuses outside a running shift, and for someone not playing it", function()
			expect(reason(use("letsGo", { running = false }))).to.equal("notRunning")
			expect(reason(use("letsGo", { participant = false }))).to.equal("notPlaying")
		end)

		it("refuses the dead, the caught and the hidden", function()
			expect(reason(use("letsGo", { alive = false }))).to.equal("dead")
			expect(reason(use("letsGo", { caught = true }))).to.equal("caught")
			expect(reason(use("letsGo", { hidden = true }))).to.equal("hidden")
		end)

		it("refuses before the cooldown is over, and allows it exactly then", function()
			expect(reason(use("letsGo", { readyAt = 100.5 }))).to.equal("cooldown")
			expect((AbilityRules.canUse(use("letsGo", { readyAt = 100 })))).to.equal(true)
		end)

		it("plants only on the ground with empty hands", function()
			expect(reason(use("pottedPlant", { grounded = false }))).to.equal("airborne")
			expect(reason(use("pottedPlant", { holding = true }))).to.equal("holding")
			-- Only the plant cares.
			expect((AbilityRules.canUse(use("letsGo", { grounded = false, holding = true })))).to.equal(true)
			expect((AbilityRules.canUse(use("spotIt", { grounded = false, holding = true })))).to.equal(true)
		end)

		it("spots only when there is a treasure", function()
			expect(reason(use("spotIt", { hasTarget = false }))).to.equal("nothing")
			expect((AbilityRules.canUse(use("letsGo", { hasTarget = false })))).to.equal(true)
		end)

		it("checks the cooldown before the ability's own needs", function()
			expect(reason(use("spotIt", { readyAt = 200, hasTarget = false }))).to.equal("cooldown")
		end)
	end)

	describe("plantEnds", function()
		it("keeps a still plant going", function()
			expect(AbilityRules.plantEnds(plant())).to.equal(nil)
			expect(AbilityRules.plantEnds(plant({ moved = 0.9 }))).to.equal(nil)
		end)

		it("ends on moving more than a stud, a jump, an action or a cancel", function()
			expect(AbilityRules.plantEnds(plant({ moved = 1.1 }))).to.equal("moved")
			expect(AbilityRules.plantEnds(plant({ grounded = false }))).to.equal("jumped")
			expect(AbilityRules.plantEnds(plant({ acting = true }))).to.equal("acted")
			expect(AbilityRules.plantEnds(plant({ cancelled = true }))).to.equal("cancelled")
		end)

		it("ends at the cap", function()
			expect(AbilityRules.plantEnds(plant({ now = 107.9 }))).to.equal(nil)
			expect(AbilityRules.plantEnds(plant({ now = 108 }))).to.equal("timeout")
		end)

		it("ends on death and on a catch first", function()
			expect(AbilityRules.plantEnds(plant({ alive = false, moved = 5 }))).to.equal("dead")
			expect(AbilityRules.plantEnds(plant({ caught = true, moved = 5 }))).to.equal("caught")
		end)
	end)
end
