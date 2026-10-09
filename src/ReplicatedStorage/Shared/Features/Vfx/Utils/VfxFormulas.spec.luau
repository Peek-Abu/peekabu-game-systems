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
end
