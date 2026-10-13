local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonEarFormulas = require(script.Parent.ToonEarFormulas)

return function()
	local MAX = ToonConstants.EAR_MAX_ANGLE
	local STILL = { forward = 0, lateral = 0, vertical = 0, yawRate = 0 }

	describe("step", function()
		it("settles on the target", function()
			local x, v = 0, 0
			for _ = 1, 240 do
				x, v = ToonEarFormulas.step(x, v, 0.3, 1 / 60)
			end
			expect(math.abs(x - 0.3) < 1e-3).to.equal(true)
			expect(math.abs(v) < 1e-2).to.equal(true)
		end)

		it("overshoots a little (the ears are bouncy, not critically damped)", function()
			local x, v = 0, 0
			local peak = 0
			for _ = 1, 120 do
				x, v = ToonEarFormulas.step(x, v, 0.3, 1 / 60)
				peak = math.max(peak, x)
			end
			expect(peak > 0.3).to.equal(true)
		end)

		it("stays stable through a long hitch", function()
			local x, v = ToonEarFormulas.step(0, 0, 0.3, 2)
			expect(x == x and v == v).to.equal(true)
			expect(math.abs(x) <= 1).to.equal(true)
		end)

		it("does nothing for a zero or negative dt", function()
			local x, v = ToonEarFormulas.step(0.1, 0.2, 0.3, 0)
			expect(x).to.equal(0.1)
			expect(v).to.equal(0.2)
		end)
	end)

	describe("targets", function()
		it("only sways (within the sway amplitude) when standing still", function()
			for t = 0, 10, 0.37 do
				local pitch, outward = ToonEarFormulas.targets(STILL, -1, t, 0)
				expect(math.abs(pitch) <= ToonConstants.EAR_SWAY_AMPLITUDE + 1e-6).to.equal(true)
				expect(math.abs(outward) <= ToonConstants.EAR_SWAY_AMPLITUDE + 1e-6).to.equal(true)
			end
		end)

		it("leans the ears back when running forward, more when faster", function()
			local walk = ToonEarFormulas.targets({ forward = 8, lateral = 0, vertical = 0, yawRate = 0 }, 1, 0, 0)
			local run = ToonEarFormulas.targets({ forward = 16, lateral = 0, vertical = 0, yawRate = 0 }, 1, 0, 0)
			expect(walk > 0).to.equal(true)
			expect(run > walk).to.equal(true)
		end)

		it("swings both ears outward while turning either way", function()
			for _, yaw in { 4, -4 } do
				local motion = { forward = 0, lateral = 0, vertical = 0, yawRate = yaw }
				local _, left = ToonEarFormulas.targets(motion, -1, 0, 0)
				local _, right = ToonEarFormulas.targets(motion, 1, 0, 0)
				expect(left > 0).to.equal(true)
				expect(right > 0).to.equal(true)
			end
		end)

		it("drags the ears against sideways motion (one out, one in)", function()
			local motion = { forward = 0, lateral = 10, vertical = 0, yawRate = 0 }
			local _, left = ToonEarFormulas.targets(motion, -1, 0, 0)
			local _, right = ToonEarFormulas.targets(motion, 1, 0, 0)
			expect(left > 0).to.equal(true)
			expect(right < 0).to.equal(true)
		end)

		it("droops outward on the way up and presses in on the way down", function()
			local _, rising = ToonEarFormulas.targets({ forward = 0, lateral = 0, vertical = 30, yawRate = 0 }, 1, 0, 0)
			local _, falling =
				ToonEarFormulas.targets({ forward = 0, lateral = 0, vertical = -30, yawRate = 0 }, 1, 0, 0)
			expect(rising > 0).to.equal(true)
			expect(falling < 0).to.equal(true)
		end)

		it("never asks for more than the ear limit", function()
			local wild = { forward = 500, lateral = 500, vertical = 500, yawRate = 50 }
			local pitch, outward = ToonEarFormulas.targets(wild, -1, 1, 2)
			expect(math.abs(pitch) <= MAX + 1e-6).to.equal(true)
			expect(math.abs(outward) <= MAX + 1e-6).to.equal(true)
		end)
	end)

	describe("landingKick", function()
		it("kicks the ears out when a fall stops sharply", function()
			expect(ToonEarFormulas.landingKick(-50, 0) > 0).to.equal(true)
		end)

		it("ignores gentle changes and take-offs", function()
			expect(ToonEarFormulas.landingKick(-2, 0)).to.equal(0)
			expect(ToonEarFormulas.landingKick(0, 50)).to.equal(0)
			expect(ToonEarFormulas.landingKick(50, 0)).to.equal(0)
		end)

		it("is bounded", function()
			expect(ToonEarFormulas.landingKick(-10000, 0) <= ToonConstants.EAR_LANDING_KICK_MAX).to.equal(true)
		end)
	end)

	describe("motion", function()
		it("reads forward speed in the root's own frame", function()
			local from = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
			local to = from * CFrame.new(0, 0, -1)
			local motion = ToonEarFormulas.motion(from, to, 0.1)
			expect(math.abs(motion.forward - 10) < 1e-3).to.equal(true)
			expect(math.abs(motion.lateral) < 1e-3).to.equal(true)
		end)

		it("reads vertical speed in world space and the yaw rate", function()
			local from = CFrame.new(0, 0, 0)
			local to = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0.5, 0)
			local motion = ToonEarFormulas.motion(from, to, 0.5)
			expect(math.abs(motion.vertical - 4) < 1e-3).to.equal(true)
			expect(math.abs(motion.yawRate - 1) < 1e-3).to.equal(true)
		end)

		it("is still for a zero dt", function()
			local motion = ToonEarFormulas.motion(CFrame.new(), CFrame.new(5, 5, 5), 0)
			expect(motion.forward).to.equal(0)
			expect(motion.vertical).to.equal(0)
		end)
	end)

	describe("transform", function()
		it("tips a left ear outward toward -X and a right ear toward +X", function()
			local up = Vector3.new(0, 1, 0)
			local left = ToonEarFormulas.transform(0, 0.3, -1):VectorToWorldSpace(up)
			local right = ToonEarFormulas.transform(0, 0.3, 1):VectorToWorldSpace(up)
			expect(left.X < 0).to.equal(true)
			expect(right.X > 0).to.equal(true)
		end)

		it("tips a positive pitch backwards (+Z, the character faces -Z)", function()
			expect(ToonEarFormulas.transform(0.3, 0, 1):VectorToWorldSpace(Vector3.new(0, 1, 0)).Z > 0).to.equal(true)
		end)

		it("clamps to the ear limit", function()
			local tilted = ToonEarFormulas.transform(5, 0, 1):VectorToWorldSpace(Vector3.new(0, 1, 0))
			expect(math.abs(math.asin(tilted.Z) - MAX) < 1e-4).to.equal(true)
		end)
	end)
end
