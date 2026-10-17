local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local VM = require(script.Parent.ToonMotionViewModel)

local MOTION = UIToonConstants.MOTION

local function strictlyRising(points)
	for index = 2, #points do
		if points[index].time <= points[index - 1].time then
			return false
		end
	end
	return true
end

return function()
	describe("pop", function()
		it("runs 0.6 -> past 1 -> 1", function()
			expect(VM.pop(0)).to.equal(MOTION.popFrom)
			expect(VM.pop(1)).to.equal(1)
			local peak = 0
			for step = 0, 20 do
				peak = math.max(peak, VM.pop(step / 20))
			end
			expect(math.abs(peak - MOTION.popOvershoot) < 0.01).to.equal(true)
		end)

		it("clamps outside 0..1", function()
			expect(VM.pop(-1)).to.equal(MOTION.popFrom)
			expect(VM.pop(2)).to.equal(1)
		end)
	end)

	describe("wipe", function()
		it("is all dirt before the squeegee starts and all clean after it passes", function()
			local before = VM.wipe(0)
			local after = VM.wipe(1)
			for _, point in before.points do
				expect(point.value).to.equal(VM.DIRT_TRANSPARENCY)
			end
			for _, point in after.points do
				expect(point.value).to.equal(1)
			end
		end)

		it("is clean behind the squeegee and dirty ahead of it mid-wipe", function()
			local mid = VM.wipe(0.5)
			expect(mid.points[1].value).to.equal(1)
			expect(mid.points[#mid.points].value).to.equal(VM.DIRT_TRANSPARENCY)
			expect(mid.edge > 0 and mid.edge < 1).to.equal(true)
		end)

		it("always gives a valid gradient: from 0 to 1, times strictly rising", function()
			for step = 0, 40 do
				local wipe = VM.wipe(step / 40)
				expect(wipe.points[1].time).to.equal(0)
				expect(wipe.points[#wipe.points].time).to.equal(1)
				expect(strictlyRising(wipe.points)).to.equal(true)
			end
		end)

		it("moves the squeegee left to right", function()
			expect(VM.wipe(0.3).edge < VM.wipe(0.6).edge).to.equal(true)
		end)
	end)

	describe("twinkle", function()
		it("pulses each sparkle between small and full size", function()
			local low, high = math.huge, -math.huge
			for step = 0, 63 do
				local value = VM.twinkle(step * MOTION.sparklePeriod / 64, 1, 3)
				low = math.min(low, value)
				high = math.max(high, value)
			end
			expect(low >= 0.3 and low < 0.5).to.equal(true)
			expect(high > 0.95 and high <= 1).to.equal(true)
		end)

		it("staggers neighbouring sparkles", function()
			expect(VM.twinkle(0.2, 1, 3) ~= VM.twinkle(0.2, 2, 3)).to.equal(true)
		end)
	end)
end
