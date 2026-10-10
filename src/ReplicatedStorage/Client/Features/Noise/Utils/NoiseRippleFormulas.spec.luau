local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseRippleFormulas = require(script.Parent.NoiseRippleFormulas)
local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)

return function()
	describe("ring", function()
		it("starts small, faint and banded", function()
			local ring = NoiseRippleFormulas.ring(40, 0)
			expect(ring.outer).to.be.near(40 * NoiseConstants.RIPPLE_START_FRACTION, 1e-6)
			expect(ring.outer - ring.inner).to.be.near(40 * NoiseConstants.RIPPLE_WIDTH_FRACTION, 1e-6)
			expect(ring.transparency).to.be.near(NoiseConstants.RIPPLE_START_TRANSPARENCY, 1e-6)
		end)

		it("ends exactly at the heard radius, at its thinnest, invisible", function()
			local ring = NoiseRippleFormulas.ring(40, 1)
			expect(ring.outer).to.be.near(40, 1e-6)
			expect(ring.outer - ring.inner).to.be.near(NoiseConstants.RIPPLE_MIN_WIDTH, 1e-6)
			expect(ring.transparency).to.be.near(1, 1e-6)
		end)

		it("spreads fast then slows (eases out)", function()
			local early = NoiseRippleFormulas.ring(40, 0.25).outer - NoiseRippleFormulas.ring(40, 0).outer
			local late = NoiseRippleFormulas.ring(40, 1).outer - NoiseRippleFormulas.ring(40, 0.75).outer
			expect(early > late).to.equal(true)
		end)

		it("never inverts the band on a tiny noise", function()
			local ring = NoiseRippleFormulas.ring(1, 0.5)
			expect(ring.inner >= 0).to.equal(true)
			expect(ring.inner <= ring.outer).to.equal(true)
		end)

		it("clamps alpha and a negative radius", function()
			expect(NoiseRippleFormulas.ring(40, 2).outer).to.be.near(40, 1e-6)
			expect(NoiseRippleFormulas.ring(40, -1).outer).to.be.near(40 * NoiseConstants.RIPPLE_START_FRACTION, 1e-6)
			expect(NoiseRippleFormulas.ring(-5, 0.5).outer).to.equal(0)
		end)
	end)

	describe("shown", function()
		it("draws a ripple whose ring comes within reach of the camera", function()
			local far = NoiseConstants.RIPPLE_MAX_DISTANCE
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.new(far + 30, 0, 0), 40)).to.equal(true)
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.new(far + 50, 0, 0), 40)).to.equal(false)
		end)

		it("never draws a noise with no radius", function()
			expect(NoiseRippleFormulas.shown(Vector3.zero, Vector3.zero, 0)).to.equal(false)
		end)
	end)
end
