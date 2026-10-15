local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTimeClockRules = require(script.Parent.ShiftTimeClockRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local REACH = ShiftConstants.PAPERWORK_REACH

return function()
	describe("canUse", function()
		it("lets an empty-handed crew member standing in front of the clock use it", function()
			expect(ShiftTimeClockRules.canUse(Vector3.new(0, -1, -2), false)).to.equal(true)
			expect(ShiftTimeClockRules.canUse(Vector3.new(REACH.halfWidth, -REACH.below, -REACH.depth), false)).to.equal(
				true
			)
		end)

		it("refuses while carrying, so it never competes with Bank cargo", function()
			local ok, reason = ShiftTimeClockRules.canUse(Vector3.new(0, -1, -2), true)
			expect(ok).to.equal(false)
			expect(reason).to.equal("carrying")
		end)

		it("refuses from deeper in the box, behind the wall, or off to the side", function()
			for _, offset in
				{
					Vector3.new(0, -1, -REACH.depth - 0.1),
					Vector3.new(0, -1, 0.1),
					Vector3.new(REACH.halfWidth + 0.1, -1, -2),
					Vector3.new(-REACH.halfWidth - 0.1, -1, -2),
				}
			do
				local ok, reason = ShiftTimeClockRules.canUse(offset, false)
				expect(ok).to.equal(false)
				expect(reason).to.equal("out-of-reach")
			end
		end)

		it("refuses from the ground outside the truck (the deck is 3 studs up) and from above", function()
			expect(ShiftTimeClockRules.canUse(Vector3.new(0, -REACH.below - 0.1, -2), false)).to.equal(false)
			expect(ShiftTimeClockRules.canUse(Vector3.new(0, REACH.above + 0.1, -2), false)).to.equal(false)
		end)

		it("reaches no further than the prompt itself shows", function()
			expect(REACH.depth <= ShiftConstants.PAPERWORK_DISTANCE).to.equal(true)
			expect(ShiftConstants.CLOCK_OUT_HOLD >= 1.5).to.equal(true)
		end)
	end)
end
