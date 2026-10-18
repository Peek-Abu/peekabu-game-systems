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

		it("grows with a bigger monitor, so the UI keeps its share of the screen", function()
			expect(near(PaperHudScaleViewModel.scale(Vector2.new(2560, 1440), "desktop"), 4 / 3)).to.equal(true)
			expect(PaperHudScaleViewModel.scale(Vector2.new(3840, 2160), "desktop")).to.equal(2)
		end)

		it("stops growing at the maximum", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(7680, 4320), "desktop")).to.equal(
				UIPaperConstants.HUD_SCALE_MAX
			)
		end)

		it("follows the tighter side of a smaller screen", function()
			expect(near(PaperHudScaleViewModel.scale(Vector2.new(1600, 900), "desktop"), 1600 / 1920)).to.equal(true)
			expect(near(PaperHudScaleViewModel.scale(Vector2.new(1440, 1080), "desktop"), 1440 / 1920)).to.equal(true)
		end)

		it("stops shrinking at the readable minimum on a small laptop or tablet", function()
			local min = UIPaperConstants.HUD_SCALE_MIN
			expect(PaperHudScaleViewModel.scale(Vector2.new(1366, 768), "desktop")).to.equal(min)
			expect(PaperHudScaleViewModel.scale(Vector2.new(1280, 720), "desktop")).to.equal(min)
			expect(PaperHudScaleViewModel.scale(Vector2.new(1024, 768), "desktop")).to.equal(min)
			expect(PaperHudScaleViewModel.scale(Vector2.new(1280, 690), "desktop")).to.equal(min)
		end)

		it("goes below the readable minimum only when a window is too short for the tallest column", function()
			-- Studio's 1192x548 play window: the scale that still fits HUD_FIT_HEIGHT design px under the top bar.
			local viewport = Vector2.new(1192, 548)
			local scale = PaperHudScaleViewModel.scale(viewport, "desktop")
			expect(scale < UIPaperConstants.HUD_SCALE_MIN).to.equal(true)
			local drawn = viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale))
			expect(near(PaperHudScaleViewModel.virtual(drawn, scale).Y, UIPaperConstants.HUD_FIT_HEIGHT)).to.equal(true)
		end)

		it("never goes below the absolute floor on a tiny or empty window", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(0, 0), "desktop")).to.equal(
				UIPaperConstants.HUD_SCALE_FLOOR
			)
			expect(PaperHudScaleViewModel.scale(Vector2.new(400, 200), "desktop")).to.equal(
				UIPaperConstants.HUD_SCALE_FLOOR
			)
		end)

		it("leaves the phone layout at 1 (its 844x390 design is in DPI-normalised points)", function()
			expect(PaperHudScaleViewModel.scale(Vector2.new(844, 390), "phone")).to.equal(1)
			expect(PaperHudScaleViewModel.scale(Vector2.new(1192, 548), "phone")).to.equal(1)
		end)

		it("keeps the smallest desktop text readable at the minimum", function()
			-- The kit's smallest desktop text (UIPaperConstants.TEXT_MIN) drawn at the minimum scale.
			local drawn = UIPaperConstants.TEXT_MIN.desktop * UIPaperConstants.HUD_SCALE_MIN
			expect(drawn >= UIPaperConstants.READABLE_PX).to.equal(true)
			expect(UIPaperConstants.TEXT_MIN.phone >= UIPaperConstants.READABLE_PX).to.equal(true)
		end)
	end)

	describe("topShift", function()
		it("is 0 at scale 1", function()
			expect(PaperHudScaleViewModel.topShift(1)).to.equal(0)
		end)

		it("keeps the design top bar's foot on the real top bar's foot when shrunk", function()
			local topBar = UIPaperConstants.SAFE.desktop.topBar
			local scale = 0.75
			local shift = PaperHudScaleViewModel.topShift(scale)
			expect(near(shift + topBar * scale, topBar)).to.equal(true)
		end)

		it("is 0 when grown, so nothing designed beside the top bar is pushed off the top", function()
			expect(PaperHudScaleViewModel.topShift(4 / 3)).to.equal(0)
			expect(PaperHudScaleViewModel.topShift(2)).to.equal(0)
		end)
	end)

	describe("bleed", function()
		it("is 0 at scale 1 and above (the frame already starts at the screen top)", function()
			expect(PaperHudScaleViewModel.bleed(1)).to.equal(0)
			expect(PaperHudScaleViewModel.bleed(2)).to.equal(0)
		end)

		it("reaches from the scaled frame's top up to the real screen top, in design px", function()
			local scale = 0.75
			-- Drawn at `scale`, the bleed covers exactly the real px the frame was shifted down.
			expect(near(PaperHudScaleViewModel.bleed(scale) * scale, PaperHudScaleViewModel.topShift(scale))).to.equal(
				true
			)
		end)
	end)

	describe("virtual", function()
		it("is the screen in HUD design px", function()
			local virtual = PaperHudScaleViewModel.virtual(Vector2.new(1366, 768), 0.75)
			expect(near(virtual.X, 1366 / 0.75)).to.equal(true)
			expect(near(virtual.Y, 768 / 0.75)).to.equal(true)
		end)

		it("is the screen itself at scale 1", function()
			expect(PaperHudScaleViewModel.virtual(Vector2.new(1920, 1080), 1)).to.equal(Vector2.new(1920, 1080))
		end)

		it("is the design screen on a 4K monitor", function()
			expect(PaperHudScaleViewModel.virtual(Vector2.new(3840, 2160), 2)).to.equal(Vector2.new(1920, 1080))
		end)
	end)

	describe("cap", function()
		it("lets a fitted screen grow with the HUD but never past what fits", function()
			-- A screen that fits at 1.5 on a 2560x1440 monitor draws at the HUD's 4/3.
			expect(near(PaperHudScaleViewModel.cap(1.5, Vector2.new(2560, 1440), "desktop"), 4 / 3)).to.equal(true)
			-- One that only fits at 0.7 stays at 0.7.
			expect(PaperHudScaleViewModel.cap(0.7, Vector2.new(1366, 768), "desktop")).to.equal(0.7)
			expect(PaperHudScaleViewModel.cap(1.2, Vector2.new(844, 390), "phone")).to.equal(1)
		end)
	end)
end
