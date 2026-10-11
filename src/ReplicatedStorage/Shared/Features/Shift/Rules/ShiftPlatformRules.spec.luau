local ShiftPlatformRules = require(script.Parent.ShiftPlatformRules)

local function signals(overrides)
	local base = { touch = false, keyboard = true, gamepad = false, tenFoot = false, shortSide = 1080 }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("detect", function()
		it("calls a keyboard device a pc, even with a touch screen", function()
			expect(ShiftPlatformRules.detect(signals())).to.equal("pc")
			expect(ShiftPlatformRules.detect(signals({ touch = true }))).to.equal("pc")
		end)

		it("splits touch-only devices into phone and tablet by the short side", function()
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = 390 }))).to.equal(
				"phone"
			)
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = 768 }))).to.equal(
				"tablet"
			)
			local edge = ShiftPlatformRules.PHONE_SHORT_SIDE
			expect(ShiftPlatformRules.detect(signals({ touch = true, keyboard = false, shortSide = edge }))).to.equal(
				"tablet"
			)
		end)

		it("calls a ten-foot interface or a gamepad-only device a console", function()
			expect(ShiftPlatformRules.detect(signals({ tenFoot = true }))).to.equal("console")
			expect(ShiftPlatformRules.detect(signals({ keyboard = false, gamepad = true }))).to.equal("console")
		end)

		it("is unknown with nothing to go on", function()
			expect(ShiftPlatformRules.detect(signals({ keyboard = false }))).to.equal("unknown")
		end)
	end)

	describe("code and parse", function()
		it("round-trips the four reportable platforms", function()
			for _, platform in { "pc", "phone", "tablet", "console" } do
				local code = ShiftPlatformRules.code(platform)
				expect(code >= 1 and code <= 4).to.equal(true)
				expect(ShiftPlatformRules.parse(code)).to.equal(platform)
			end
		end)

		it("gives unknown no code", function()
			expect(ShiftPlatformRules.code("unknown")).to.equal(0)
		end)

		it("parses only the four reportable codes", function()
			for _, raw in { 0, 5, 9, 255, -1, 2.5, 0 / 0, math.huge, "2", true } do
				expect(ShiftPlatformRules.parse(raw)).to.equal(nil)
			end
			expect(ShiftPlatformRules.parse(nil)).to.equal(nil)
		end)
	end)
end
