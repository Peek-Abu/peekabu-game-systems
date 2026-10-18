local VfxFormulas = require(script.Parent.VfxFormulas)

local WHITE = Color3.new(1, 1, 1)

local BASE = {
	clockTime = 14,
	brightness = 2,
	exposure = 0,
	ambient = Color3.new(0.5, 0.5, 0.5),
	outdoorAmbient = Color3.new(0.5, 0.5, 0.5),
	fogColor = Color3.new(0.7, 0.7, 0.7),
	fogStart = 0,
	fogEnd = 100000,
}

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function()
	describe("traumaAtDistance", function()
		it("is full at the centre and zero at or beyond the radius", function()
			expect(VfxFormulas.traumaAtDistance(0.8, 0, 50)).to.be.near(0.8)
			expect(VfxFormulas.traumaAtDistance(0.8, 50, 50)).to.equal(0)
			expect(VfxFormulas.traumaAtDistance(0.8, 80, 50)).to.equal(0)
		end)

		it("falls off quadratically", function()
			expect(VfxFormulas.traumaAtDistance(1, 25, 50)).to.be.near(0.25)
		end)
	end)

	describe("combineScreen", function()
		it("is neutral with no requests", function()
			local state = VfxFormulas.combineScreen({})
			expect(state.blur).to.equal(0)
			expect(state.brightness).to.equal(0)
			expect(state.depthOfField).to.equal(0)
			expect(state.tint).to.equal(WHITE)
		end)

		it("takes the strongest blur and depth of field", function()
			local state =
				VfxFormulas.combineScreen({ { blur = 8 }, { blur = 20, depthOfField = 0.3 }, { depthOfField = 0.6 } })
			expect(state.blur).to.equal(20)
			expect(state.depthOfField).to.equal(0.6)
		end)

		it("adds the colour offsets", function()
			local state = VfxFormulas.combineScreen({
				{ brightness = 0.1, saturation = -0.5 },
				{ brightness = 0.2, contrast = 0.1 },
			})
			expect(near(state.brightness, 0.3)).to.equal(true)
			expect(near(state.contrast, 0.1)).to.equal(true)
			expect(near(state.saturation, -0.5)).to.equal(true)
		end)

		it("multiplies tints", function()
			local state =
				VfxFormulas.combineScreen({ { tint = Color3.new(0.5, 1, 1) }, { tint = Color3.new(1, 0.5, 1) } })
			expect(near(state.tint.R, 0.5)).to.equal(true)
			expect(near(state.tint.G, 0.5)).to.equal(true)
			expect(near(state.tint.B, 1)).to.equal(true)
		end)
	end)

	describe("lerpScreen", function()
		it("moves every field by alpha", function()
			local from = VfxFormulas.combineScreen({})
			local to = VfxFormulas.combineScreen({ { blur = 10, brightness = 1, tint = Color3.new(0, 0, 0) } })
			local mid = VfxFormulas.lerpScreen(from, to, 0.5)
			expect(near(mid.blur, 5)).to.equal(true)
			expect(near(mid.brightness, 0.5)).to.equal(true)
			expect(near(mid.tint.R, 0.5)).to.equal(true)
		end)
	end)

	describe("screenActive", function()
		it("turns every effect off at the neutral state", function()
			local active = VfxFormulas.screenActive(VfxFormulas.combineScreen({}))
			expect(active.blur).to.equal(false)
			expect(active.color).to.equal(false)
			expect(active.depth).to.equal(false)
		end)

		it("turns on only the effect whose values differ from neutral", function()
			local blurOnly = VfxFormulas.screenActive(VfxFormulas.combineScreen({ { blur = 6 } }))
			expect(blurOnly.blur).to.equal(true)
			expect(blurOnly.color).to.equal(false)
			expect(blurOnly.depth).to.equal(false)
			local depthOnly = VfxFormulas.screenActive(VfxFormulas.combineScreen({ { depthOfField = 0.2 } }))
			expect(depthOnly.depth).to.equal(true)
			expect(depthOnly.blur).to.equal(false)
			for _, request in
				{
					{ brightness = 0.1 },
					{ contrast = -0.2 },
					{ saturation = -0.4 },
					{
						tint = Color3.new(1, 0.8, 1),
					},
				}
			do
				local active = VfxFormulas.screenActive(VfxFormulas.combineScreen({ request }))
				expect(active.color).to.equal(true)
				expect(active.blur).to.equal(false)
			end
		end)

		it("treats an ease that has all but arrived at neutral as neutral", function()
			local from = VfxFormulas.combineScreen({ { blur = 10, saturation = -0.5, depthOfField = 0.4 } })
			local almost = VfxFormulas.lerpScreen(from, VfxFormulas.combineScreen({}), 0.99999)
			local active = VfxFormulas.screenActive(almost)
			expect(active.blur).to.equal(false)
			expect(active.color).to.equal(false)
			expect(active.depth).to.equal(false)
		end)
	end)

	describe("screenSettled", function()
		it("is true only when the applied state has reached the target", function()
			local neutral = VfxFormulas.combineScreen({})
			local blurred = VfxFormulas.combineScreen({ { blur = 10 } })
			expect(VfxFormulas.screenSettled(neutral, neutral)).to.equal(true)
			expect(VfxFormulas.screenSettled(blurred, blurred)).to.equal(true)
			expect(VfxFormulas.screenSettled(blurred, neutral)).to.equal(false)
			expect(VfxFormulas.screenSettled(VfxFormulas.lerpScreen(blurred, neutral, 0.99999), neutral)).to.equal(true)
		end)
	end)

	describe("resolveAtmosphere", function()
		it("is the base with no preset", function()
			local values = VfxFormulas.resolveAtmosphere(BASE, nil)
			expect(values.clockTime).to.equal(14)
			expect(values.fogEnd).to.equal(100000)
		end)

		it("overrides only what the preset sets", function()
			local values = VfxFormulas.resolveAtmosphere(BASE, { clockTime = 0, fogEnd = 80 })
			expect(values.clockTime).to.equal(0)
			expect(values.fogEnd).to.equal(80)
			expect(values.brightness).to.equal(2)
		end)
	end)

	describe("blendAtmosphere", function()
		it("returns the endpoints at alpha 0 and 1 and blends between", function()
			local night =
				VfxFormulas.resolveAtmosphere(BASE, { clockTime = 0, brightness = 0, ambient = Color3.new(0, 0, 0) })
			expect(VfxFormulas.blendAtmosphere(BASE, night, 0).clockTime).to.equal(14)
			expect(VfxFormulas.blendAtmosphere(BASE, night, 1).clockTime).to.equal(0)
			local mid = VfxFormulas.blendAtmosphere(BASE, night, 0.5)
			expect(near(mid.clockTime, 7)).to.equal(true)
			expect(near(mid.brightness, 1)).to.equal(true)
			expect(near(mid.ambient.R, 0.25)).to.equal(true)
		end)

		it("clamps alpha", function()
			local night = VfxFormulas.resolveAtmosphere(BASE, { clockTime = 0 })
			expect(VfxFormulas.blendAtmosphere(BASE, night, 2).clockTime).to.equal(0)
		end)
	end)

	describe("burstCount", function()
		it("keeps the full count at the top quality and on Automatic", function()
			expect(VfxFormulas.burstCount(20, 10)).to.equal(20)
			expect(VfxFormulas.burstCount(20, 0)).to.equal(20)
		end)

		it("thins bursts on low quality but never below one", function()
			expect(VfxFormulas.burstCount(20, 1) < 10).to.equal(true)
			expect(VfxFormulas.burstCount(1, 1)).to.equal(1)
		end)
	end)

	describe("streamRate", function()
		it("scales with strength, clamped to 0..1", function()
			expect(near(VfxFormulas.streamRate(20, 0.5, 10), 10)).to.equal(true)
			expect(near(VfxFormulas.streamRate(20, 3, 10), 20)).to.equal(true)
			expect(VfxFormulas.streamRate(20, -1, 10)).to.equal(0)
		end)

		it("thins on low quality", function()
			expect(VfxFormulas.streamRate(20, 1, 1) < 10).to.equal(true)
		end)
	end)

	describe("funnel", function()
		it("opens the cap to the source's angular radius", function()
			expect(near(VfxFormulas.funnelPartial(1, 1), 0.5)).to.equal(true)
			expect(VfxFormulas.funnelPartial(1, 4) < VfxFormulas.funnelPartial(1, 2)).to.equal(true)
		end)

		it("keeps the cap within 0.02..1", function()
			expect(VfxFormulas.funnelPartial(0, 5)).to.equal(0.02)
			expect(VfxFormulas.funnelPartial(5, 0) <= 1).to.equal(true)
		end)

		it("sends particles the whole distance in their lifetime", function()
			expect(near(VfxFormulas.funnelSpeed(4, 0.5), 8)).to.equal(true)
			expect(VfxFormulas.funnelSpeed(4, 0)).to.equal(0)
		end)
	end)

	describe("changedBy", function()
		it("is true for a change over the threshold share", function()
			expect(VfxFormulas.changedBy(100, 104, 0.03)).to.equal(true)
			expect(VfxFormulas.changedBy(100, 102, 0.03)).to.equal(false)
			expect(VfxFormulas.changedBy(0, 0.01, 0.03)).to.equal(true)
			expect(VfxFormulas.changedBy(0, 0, 0.03)).to.equal(false)
		end)
	end)

	describe("sequence and gradient", function()
		it("builds a NumberSequence from pairs, with an optional envelope", function()
			local built = VfxFormulas.sequence({ { 0, 1 }, { 0.5, 2, 0.5 }, { 1, 0 } })
			expect(#built.Keypoints).to.equal(3)
			expect(built.Keypoints[2].Value).to.equal(2)
			expect(built.Keypoints[2].Envelope).to.equal(0.5)
		end)

		it("spreads colours evenly over the lifetime", function()
			local red, blue = Color3.new(1, 0, 0), Color3.new(0, 0, 1)
			local built = VfxFormulas.gradient({ red, WHITE, blue })
			expect(#built.Keypoints).to.equal(3)
			expect(built.Keypoints[2].Time).to.equal(0.5)
			expect(VfxFormulas.gradient({ red }).Keypoints[1].Value).to.equal(red)
		end)
	end)
end
