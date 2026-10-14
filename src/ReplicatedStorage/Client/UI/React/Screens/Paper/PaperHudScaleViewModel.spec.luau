local PaperHudScaleViewModel = require(script.Parent.PaperHudScaleViewModel)
local UIPaperConstants = require(script.Parent.UIPaperConstants)

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-3
end

return function()
	describe("scale", function()
		it("is 1 on the 1920x1080 design screen", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(1920, 1080), "desktop")).to.equal(1)
		end)

		it("never draws the HUD larger than designed", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(2560, 1440), "desktop")).to.equal(1)
		end)

		it("follows the tighter side of a smaller screen", function()
			expect(near(PaperHudScaleViewModel.scale(Vector2.new(1600, 900), "desktop"), 1600 / 1920)).to.equal(true)
			expect(near(PaperHudScaleViewModel.scale(Vector2.new(1280, 1080), "desktop"), 1280 / 1920)).to.equal(true)
		end)

		it("stops at the minimum on a short window", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(1188, 588), "desktop")).to.equal(0.55)
		end)

		it("leaves the phone layout at 1 (it has its own design)", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(844, 390), "phone")).to.equal(1)
		end)
	end)

	describe("topShift", function()
		it("is 0 at scale 1", function()
			expect(PaperHudScaleViewModel.topShift(1)).to.equal(0)
		end)

		it("keeps the design top bar's foot on the real top bar's foot", function()
			local topBar = UIPaperConstants.SAFE.desktop.topBar
			local scale = 0.55
			local shift = PaperHudScaleViewModel.topShift(scale)
			expect(near(shift + topBar * scale, topBar)).to.equal(true)
		end)
	end)

	describe("bleed", function()
		it("is 0 at scale 1 (the frame already starts at the screen top)", function()
			expect(PaperHudScaleViewModel.bleed(1)).to.equal(0)
		end)

		it("reaches from the scaled frame's top up to the real screen top, in design px", function()
			local scale = 0.55
			-- Drawn at `scale`, the bleed covers exactly the real px the frame was shifted down.
			expect(near(PaperHudScaleViewModel.bleed(scale) * scale, PaperHudScaleViewModel.topShift(scale))).to.equal(
				true
			)
		end)
	end)

	describe("virtual", function()
		it("is the screen in HUD design px", function()
			local virtual = PaperHudScaleViewModel.virtual(Vector2.new(1188, 588), 0.55)
			expect(near(virtual.X, 2160)).to.equal(true)
			expect(near(virtual.Y, 588 / 0.55)).to.equal(true)
		end)

		it("is the screen itself at scale 1", function()
			expect(PaperHudScaleViewModel.virtual(Vector2.new(1920, 1080), 1)).to.equal(Vector2.new(1920, 1080))
		end)
	end)
end
