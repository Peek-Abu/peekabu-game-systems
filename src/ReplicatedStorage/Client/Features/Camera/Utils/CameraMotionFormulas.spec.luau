local CameraMotionFormulas = require(script.Parent.CameraMotionFormulas)

local CONFIG = { maxPitch = 0.1, maxYaw = 0.1, maxRoll = 0.05, frequency = 10 }

return function()
	describe("shakeAngles", function()
		it("is zero with no trauma", function()
			local pitch, yaw, roll = CameraMotionFormulas.shakeAngles(0, 1.234, CONFIG)
			expect(pitch).to.equal(0)
			expect(yaw).to.equal(0)
			expect(roll).to.equal(0)
		end)

		it("never exceeds the configured maximum, at any time", function()
			for step = 0, 200 do
				local pitch, yaw, roll = CameraMotionFormulas.shakeAngles(1, step * 0.037, CONFIG)
				expect(math.abs(pitch) <= CONFIG.maxPitch + 1e-9).to.equal(true)
				expect(math.abs(yaw) <= CONFIG.maxYaw + 1e-9).to.equal(true)
				expect(math.abs(roll) <= CONFIG.maxRoll + 1e-9).to.equal(true)
			end
		end)

		it("scales with trauma squared", function()
			local t = 0.77
			local fullPitch = CameraMotionFormulas.shakeAngles(1, t, CONFIG)
			local halfPitch = CameraMotionFormulas.shakeAngles(0.5, t, CONFIG)
			expect(math.abs(halfPitch - fullPitch * 0.25) < 1e-9).to.equal(true)
		end)

		it("is deterministic for the same time", function()
			local a = CameraMotionFormulas.shakeAngles(0.8, 3.21, CONFIG)
			local b = CameraMotionFormulas.shakeAngles(0.8, 3.21, CONFIG)
			expect(a).to.equal(b)
		end)
	end)

	describe("addTrauma / decayTrauma", function()
		it("adds and clamps to 1", function()
			expect(CameraMotionFormulas.addTrauma(0.5, 0.3)).to.be.near(0.8)
			expect(CameraMotionFormulas.addTrauma(0.9, 0.5)).to.equal(1)
		end)

		it("ignores a negative amount", function()
			expect(CameraMotionFormulas.addTrauma(0.5, -1)).to.equal(0.5)
		end)

		it("decays linearly and never below zero", function()
			expect(CameraMotionFormulas.decayTrauma(1, 0.25, 2)).to.be.near(0.5)
			expect(CameraMotionFormulas.decayTrauma(0.1, 1, 2)).to.equal(0)
		end)
	end)

	describe("fovKickValue", function()
		it("starts at the full amount and eases out to zero at the duration", function()
			expect(CameraMotionFormulas.fovKickValue({ amount = 10, duration = 1, elapsed = 0 })).to.equal(10)
			expect(CameraMotionFormulas.fovKickValue({ amount = 10, duration = 1, elapsed = 0.5 })).to.be.near(2.5)
			expect(CameraMotionFormulas.fovKickValue({ amount = 10, duration = 1, elapsed = 1 })).to.equal(0)
			expect(CameraMotionFormulas.fovKickValue({ amount = 10, duration = 1, elapsed = 2 })).to.equal(0)
		end)

		it("supports negative kicks (a zoom-in)", function()
			expect(CameraMotionFormulas.fovKickValue({ amount = -6, duration = 1, elapsed = 0 })).to.equal(-6)
		end)

		it("treats a zero duration as already finished", function()
			expect(CameraMotionFormulas.fovKickValue({ amount = 10, duration = 0, elapsed = 0 })).to.equal(0)
		end)
	end)

	describe("smoothingAlpha", function()
		it("is 0 for no time and approaches 1 for a long step", function()
			expect(CameraMotionFormulas.smoothingAlpha(12, 0)).to.equal(0)
			expect(CameraMotionFormulas.smoothingAlpha(12, 10) > 0.999).to.equal(true)
		end)

		it("is frame-rate independent: two half steps equal one full step", function()
			local full = CameraMotionFormulas.smoothingAlpha(8, 0.1)
			local half = CameraMotionFormulas.smoothingAlpha(8, 0.05)
			local twoHalves = 1 - (1 - half) * (1 - half)
			expect(math.abs(full - twoHalves) < 1e-9).to.equal(true)
		end)
	end)
end
