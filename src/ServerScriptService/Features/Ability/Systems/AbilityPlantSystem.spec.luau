local ServerScriptService = game:GetService("ServerScriptService")

local AbilityPlantSystem = require(script.Parent.AbilityPlantSystem)
local AbilityCooldownTracker = require(ServerScriptService.Features.Ability.State.AbilityCooldownTracker)

local function contextWith(tracker)
	return {
		tracker = tracker,
		counters = { used = 0, refused = 0, plantsEnded = 0 },
		bodyOf = function()
			return nil, nil
		end,
		aliveOf = function()
			return false
		end,
		say = function() end,
	}
end

local function plant()
	return { startedAt = 0, origin = Vector3.zero, cancelled = false }
end

return function()
	describe("endAll", function()
		it("ends the plant of a planter who already left (no Player for the userId)", function()
			local tracker = AbilityCooldownTracker.new()
			tracker:startPlant(101, plant())
			tracker:startPlant(202, plant())
			AbilityPlantSystem.endAll(contextWith(tracker), function()
				return nil
			end)
			expect(#tracker:planters()).to.equal(0)
			expect(tracker:plantOf(101)).to.equal(nil)
			expect(tracker:plantOf(202)).to.equal(nil)
		end)

		it(
			"does not count a left planter's plant as an ended plant (the bookkeeping only, as on a shift change)",
			function()
				local tracker = AbilityCooldownTracker.new()
				tracker:startPlant(303, plant())
				local ctx = contextWith(tracker)
				AbilityPlantSystem.endAll(ctx, function()
					return nil
				end)
				expect(ctx.counters.plantsEnded).to.equal(0)
			end
		)

		it("does nothing when nobody is planted", function()
			local tracker = AbilityCooldownTracker.new()
			local asked = 0
			AbilityPlantSystem.endAll(contextWith(tracker), function()
				asked += 1
				return nil
			end)
			expect(asked).to.equal(0)
		end)
	end)
end
