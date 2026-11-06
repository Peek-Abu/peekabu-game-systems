local ShiftOutlineRules = require(script.Parent.ShiftOutlineRules)

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		quotaMet = false,
		endsAt = 1000,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("truckShown", function()
		it("stays hidden early in a normal shift", function()
			expect(ShiftOutlineRules.truckShown(snapshot(), 100)).to.equal(false)
		end)

		it("shows the way back once it is time to go", function()
			expect(ShiftOutlineRules.truckShown(snapshot({ quotaMet = true }), 100)).to.equal(true)
			expect(ShiftOutlineRules.truckShown(snapshot({ sub = "clockout" }), 100)).to.equal(true)
			expect(ShiftOutlineRules.truckShown(snapshot({ stage = "warning" }), 100)).to.equal(true)
			expect(ShiftOutlineRules.truckShown(snapshot({ stage = "overtime" }), 100)).to.equal(true)
		end)

		it("shows it in the shift's last minute", function()
			local endsAt = 1000
			expect(ShiftOutlineRules.truckShown(snapshot(), endsAt - ShiftOutlineRules.LAST_SECONDS - 1)).to.equal(
				false
			)
			expect(ShiftOutlineRules.truckShown(snapshot(), endsAt - ShiftOutlineRules.LAST_SECONDS)).to.equal(true)
		end)

		it("never shows outside a running shift", function()
			expect(ShiftOutlineRules.truckShown(nil, 0)).to.equal(false)
			expect(ShiftOutlineRules.truckShown(snapshot({ phase = "results", quotaMet = true }), 0)).to.equal(false)
		end)
	end)

	describe("teammateTransparency", function()
		it("hides an outline on a teammate right beside you", function()
			expect(ShiftOutlineRules.teammateTransparency(ShiftOutlineRules.NEAR - 1)).to.equal(nil)
		end)

		it("fades in with distance and holds at its strongest far away", function()
			local nearish = ShiftOutlineRules.teammateTransparency(ShiftOutlineRules.NEAR + 1)
			local mid = ShiftOutlineRules.teammateTransparency((ShiftOutlineRules.NEAR + ShiftOutlineRules.FAR) / 2)
			local far = ShiftOutlineRules.teammateTransparency(ShiftOutlineRules.FAR)
			local beyond = ShiftOutlineRules.teammateTransparency(ShiftOutlineRules.FAR * 4)
			expect(nearish > mid and mid > far).to.equal(true)
			expect(beyond).to.equal(far)
			expect(far >= 0 and nearish < 1).to.equal(true)
		end)
	end)
end
