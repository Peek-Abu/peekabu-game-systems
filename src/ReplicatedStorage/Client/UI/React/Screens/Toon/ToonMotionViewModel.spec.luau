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

	describe("highlight", function()
		it(
			"only breathes a border: strong, soft, strong again over one period (owner 2026-11-14: no whole-button pulse)",
			function()
				local period = MOTION.highlightPeriod
				local low, high = math.huge, -math.huge
				for step = 0, 63 do
					local ring = VM.highlight(step * period / 64)
					low = math.min(low, ring)
					high = math.max(high, ring)
				end
				-- ring is a UIStroke Transparency: always visible, clearly stronger at the start of each period
				expect(low <= 0.2).to.equal(true)
				expect(high >= 0.6 and high <= 0.8).to.equal(true)
				expect(math.abs(VM.highlight(0) - VM.highlight(period)) < 1e-6).to.equal(true)
				-- Reduced Motion holds the clock at its end: the border stays at its strongest
				expect(math.abs(VM.highlight(period) - low) < 1e-6).to.equal(true)
			end
		)
	end)

	describe("deal", function()
		it("runs dealFrom -> past 1 -> 1, clamped", function()
			expect(VM.deal(0)).to.equal(MOTION.dealFrom)
			expect(VM.deal(1)).to.equal(1)
			expect(VM.deal(-1)).to.equal(MOTION.dealFrom)
			expect(VM.deal(3)).to.equal(1)
			local peak = 0
			for step = 0, 40 do
				peak = math.max(peak, VM.deal(step / 40))
			end
			expect(math.abs(peak - MOTION.dealOvershoot) < 0.01).to.equal(true)
		end)

		it("staggers the first dealCount cards and leaves the rest still", function()
			expect(VM.dealDelay(1)).to.equal(0)
			expect(math.abs(VM.dealDelay(2) - MOTION.dealStagger) < 1e-9).to.equal(true)
			expect(VM.dealDelay(MOTION.dealCount) ~= nil).to.equal(true)
			expect(VM.dealDelay(MOTION.dealCount + 1)).to.equal(nil)
			expect(VM.dealDelay(0)).to.equal(nil)
		end)
	end)

	describe("arrive", function()
		it("starts `from` px away and lands exactly on 0, never past it", function()
			expect(VM.arrive(0, 24)).to.equal(24)
			expect(VM.arrive(1, 24)).to.equal(0)
			expect(VM.arrive(1, -16)).to.equal(0)
			local last = 24
			for step = 1, 20 do
				local now = VM.arrive(step / 20, 24)
				expect(now <= last).to.equal(true)
				expect(now >= 0).to.equal(true)
				last = now
			end
		end)
	end)

	describe("slideFrom", function()
		it("comes in from the side of the tab picked", function()
			local tabs = { "a", "b", "c" }
			expect(VM.slideFrom(tabs, "a", "c")).to.equal(MOTION.slideShift)
			expect(VM.slideFrom(tabs, "c", "a")).to.equal(-MOTION.slideShift)
			expect(VM.slideFrom(tabs, "b", "b")).to.equal(0)
			expect(VM.slideFrom(tabs, "x", "a")).to.equal(0)
			expect(VM.slideFrom(tabs, nil, "a")).to.equal(0)
		end)
	end)

	describe("count", function()
		it("eases from the old balance to the new one in whole numbers", function()
			expect(VM.count(100, 140, 0)).to.equal(100)
			expect(VM.count(100, 140, 1)).to.equal(140)
			expect(VM.count(100, 140, 2)).to.equal(140)
			expect(VM.count(140, 100, 1)).to.equal(100)
			local mid = VM.count(100, 140, 0.5)
			expect(mid > 120 and mid < 140).to.equal(true)
			expect(mid % 1).to.equal(0)
		end)
	end)

	describe("bump", function()
		it("swells once to bumpScale and settles at 1", function()
			expect(VM.bump(0)).to.equal(1)
			expect(VM.bump(1)).to.equal(1)
			local peak = 0
			for step = 0, 40 do
				peak = math.max(peak, VM.bump(step / 40))
			end
			expect(math.abs(peak - MOTION.bumpScale) < 0.01).to.equal(true)
		end)
	end)

	describe("float", function()
		it("fades in, rises floatRise px and is gone at the end", function()
			local start = VM.float(0)
			local finish = VM.float(1)
			expect(start.transparency).to.equal(1)
			expect(finish.transparency).to.equal(1)
			expect(finish.rise).to.equal(MOTION.floatRise)
			local shown = VM.float(0.5)
			expect(shown.transparency).to.equal(0)
			expect(shown.rise > 0 and shown.rise < MOTION.floatRise).to.equal(true)
		end)
	end)
end
