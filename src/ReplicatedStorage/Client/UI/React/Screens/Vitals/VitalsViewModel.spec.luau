--!nocheck
--[=[
	Unit tests for VitalsViewModel — the pure derivation behind the Vitals HUD.

	This is where the HUD's logic lives so the component stays a dumb renderer: XP progress from the
	stats slice, health fraction/label from raw numbers. Both are plain functions over plain values —
	no atoms, no Instances, no React — which is exactly why they're testable and the component isn't.

	Curve facts used below: XP_PER_LEVEL_FACTOR = 25, MAX_LEVEL = 30, so level 1 spans 0→25 and
	level 2 spans 25→75.
]=]

local VitalsViewModel = require(script.Parent.VitalsViewModel)

return function()
	describe("fromStats", function()
		it("reports a loading state before the first sync (never a bogus zero)", function()
			local display = VitalsViewModel.fromStats(nil)
			expect(display.loading).to.equal(true)
			expect(display.fraction).to.equal(0)
			-- Label must not read like a real value while unsynced.
			expect(display.label).never.to.equal("0 / 25")
		end)

		it("derives level 1 and an empty bar at zero XP", function()
			local display = VitalsViewModel.fromStats({ totalXp = 0, investments = {} })
			expect(display.loading).to.equal(false)
			expect(display.level).to.equal(1)
			expect(display.fraction).to.equal(0)
			expect(display.label).to.equal("0 / 25")
		end)

		it("derives partial progress within a level", function()
			local display = VitalsViewModel.fromStats({ totalXp = 10, investments = {} })
			expect(display.level).to.equal(1)
			expect(display.fraction).to.equal(0.4) -- 10 / 25
			expect(display.label).to.equal("10 / 25")
		end)

		it("rolls over to the next level at the boundary", function()
			local display = VitalsViewModel.fromStats({ totalXp = 25, investments = {} })
			expect(display.level).to.equal(2)
			expect(display.fraction).to.equal(0) -- 0 into level 2
			expect(display.label).to.equal("0 / 50") -- level 2 needs 2 * 25
		end)

		it("shows a full bar and MAX at the level cap", function()
			-- xpForLevel(30) = 25 * 29 * 30 / 2 = 10875
			local display = VitalsViewModel.fromStats({ totalXp = 10875, investments = {} })
			expect(display.level).to.equal(30)
			expect(display.fraction).to.equal(1)
			expect(display.label).to.equal("MAX")
		end)
	end)

	describe("fromHealth", function()
		it("derives fraction and label", function()
			local display = VitalsViewModel.fromHealth(85, 100)
			expect(display.fraction).to.equal(0.85)
			expect(display.label).to.equal("85 / 100")
		end)

		it("handles empty health", function()
			local display = VitalsViewModel.fromHealth(0, 100)
			expect(display.fraction).to.equal(0)
			expect(display.label).to.equal("0 / 100")
		end)

		it("never divides by zero when max health is 0", function()
			local display = VitalsViewModel.fromHealth(0, 0)
			expect(display.fraction).to.equal(0)
			expect(display.label).to.equal("0 / 0")
		end)

		it("clamps overheal and negative health into 0..1", function()
			expect(VitalsViewModel.fromHealth(150, 100).fraction).to.equal(1)
			expect(VitalsViewModel.fromHealth(-20, 100).fraction).to.equal(0)
		end)

		it("rounds fractional health for the label", function()
			local display = VitalsViewModel.fromHealth(85.6, 100)
			expect(display.label).to.equal("86 / 100")
		end)
	end)
end
