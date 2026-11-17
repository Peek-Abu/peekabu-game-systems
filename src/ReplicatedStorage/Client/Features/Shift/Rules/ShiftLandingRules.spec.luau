local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftLandingRules = require(script.Parent.ShiftLandingRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

local TIMING = ShiftLandingRules.TIMING

return function()
	describe("shows", function()
		it("shows on an arrival at a shift", function()
			expect(ShiftLandingRules.shows({ hub = false, client = "Harlow & Finch Ltd." })).to.equal(true)
			expect(ShiftLandingRules.shows({ hub = false, client = nil })).to.equal(true)
		end)

		it("never shows in the hub", function()
			expect(ShiftLandingRules.shows({ hub = true, client = "Harlow & Finch Ltd." })).to.equal(false)
		end)

		it("never shows in training", function()
			expect(ShiftLandingRules.shows({ hub = false, client = TrainingConstants.CONTRACT.client })).to.equal(false)
		end)
	end)

	describe("seedOf", function()
		it("uses the built office's layout seed", function()
			expect(ShiftLandingRules.seedOf({ userId = 1, id = 5, built = true, seed = 9001 })).to.equal(9001)
		end)

		it("falls back on the hold's id, which the whole crew shares, when the office has no seed", function()
			expect(ShiftLandingRules.seedOf({ userId = 1, id = 5, built = true })).to.equal(5)
		end)
	end)

	describe("alpha", function()
		it("waits until the route slip has lifted", function()
			expect(TIMING.delay >= ShiftConstants.TRANSIT_ARRIVED_SECONDS + ShiftConstants.TRANSIT_FADE_OUT).to.equal(
				true
			)
			expect(ShiftLandingRules.alpha(0)).to.equal(0)
			expect(ShiftLandingRules.alpha(TIMING.delay - 0.01)).to.equal(0)
		end)

		it("comes in, holds for about six seconds, then goes", function()
			local fadeInMid = TIMING.delay + TIMING.fadeIn / 2
			local alpha = ShiftLandingRules.alpha(fadeInMid)
			expect(alpha > 0 and alpha < 1).to.equal(true)
			expect(ShiftLandingRules.alpha(TIMING.delay + TIMING.fadeIn)).to.equal(1)
			expect(ShiftLandingRules.alpha(TIMING.delay + TIMING.fadeIn + TIMING.hold - 0.01)).to.equal(1)
			local outMid = TIMING.delay + TIMING.fadeIn + TIMING.hold + TIMING.fadeOut / 2
			local leaving = ShiftLandingRules.alpha(outMid)
			expect(leaving > 0 and leaving < 1).to.equal(true)
			expect(ShiftLandingRules.alpha(ShiftLandingRules.total())).to.equal(0)
			expect(TIMING.hold >= 5 and TIMING.hold <= 7).to.equal(true)
		end)

		it("is 0 for a bad time", function()
			expect(ShiftLandingRules.alpha(0 / 0)).to.equal(0)
			expect(ShiftLandingRules.alpha(-1)).to.equal(0)
		end)
	end)

	describe("over", function()
		it("is over once the card has gone", function()
			expect(ShiftLandingRules.over(0)).to.equal(false)
			expect(ShiftLandingRules.over(ShiftLandingRules.total() - 0.01)).to.equal(false)
			expect(ShiftLandingRules.over(ShiftLandingRules.total())).to.equal(true)
		end)
	end)
end
