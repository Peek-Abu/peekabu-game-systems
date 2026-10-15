local CarryFormulas = require(script.Parent.CarryFormulas)

return function()
	describe("walkSpeedFor", function()
		it("is the base speed with no weight", function()
			expect(CarryFormulas.walkSpeedFor(16, 0, 0.05, 0.4)).to.equal(16)
		end)

		it("slows linearly with weight", function()
			expect(CarryFormulas.walkSpeedFor(16, 4, 0.05, 0.4)).to.be.near(16 * 0.8)
		end)

		it("never drops below the minimum multiplier", function()
			expect(CarryFormulas.walkSpeedFor(16, 100, 0.05, 0.4)).to.be.near(16 * 0.4)
		end)
	end)

	describe("throwVelocity", function()
		it("throws along the normalized aim at the given speed, plus lift", function()
			local velocity = CarryFormulas.throwVelocity(Vector3.new(0, 0, -10), 30, 5)
			expect(velocity.Z).to.be.near(-30)
			expect(velocity.Y).to.be.near(5)
		end)

		it("refuses a zero or non-finite aim", function()
			expect(CarryFormulas.throwVelocity(Vector3.zero, 30, 5)).to.equal(nil)
			expect(CarryFormulas.throwVelocity(Vector3.new(0 / 0, 0, 1), 30, 5)).to.equal(nil)
			expect(CarryFormulas.throwVelocity(Vector3.new(math.huge, 0, 0), 30, 5)).to.equal(nil)
		end)
	end)

	describe("clampAlong", function()
		local origin = Vector3.new(0, 2, 0)
		local target = Vector3.new(0, 2, -4)
		it("keeps the target when nothing is in the way", function()
			expect(CarryFormulas.clampAlong(origin, target, nil, 0.5)).to.equal(target)
		end)

		it("stops short of a wall by the margin", function()
			local point = CarryFormulas.clampAlong(origin, target, 2, 0.5)
			expect((point - Vector3.new(0, 2, -1.5)).Magnitude < 1e-6).to.equal(true)
		end)

		it("never goes behind the origin when the wall is closer than the margin", function()
			expect(CarryFormulas.clampAlong(origin, target, 0.3, 0.5)).to.equal(origin)
		end)

		it("treats a zero-length move as the origin", function()
			expect(CarryFormulas.clampAlong(origin, origin, 0, 0.5)).to.equal(origin)
		end)
	end)

	describe("isSupported", function()
		it("needs a floor, at about the origin's floor level, in the same structure", function()
			expect(CarryFormulas.isSupported(0, 0.2, true, 1.5)).to.equal(true)
			expect(CarryFormulas.isSupported(0, nil, true, 1.5)).to.equal(false)
			expect(CarryFormulas.isSupported(0, -4, true, 1.5)).to.equal(false)
			expect(CarryFormulas.isSupported(0, 0, false, 1.5)).to.equal(false)
		end)

		it("accepts any floor when the origin itself has none to compare with", function()
			expect(CarryFormulas.isSupported(nil, 3, true, 1.5)).to.equal(true)
		end)
	end)

	describe("pullBack", function()
		it("puts a part that crossed a wall back on the near side by the margin", function()
			local from = Vector3.new(0, 2, 0)
			local hit = Vector3.new(0, 2, -3)
			local point = CarryFormulas.pullBack(from, hit, 0.6)
			expect((point - Vector3.new(0, 2, -2.4)).Magnitude < 1e-6).to.equal(true)
		end)

		it("never pulls back past where the part was", function()
			expect(CarryFormulas.pullBack(Vector3.new(0, 2, 0), Vector3.new(0, 2, -0.2), 0.6)).to.equal(
				Vector3.new(0, 2, 0)
			)
		end)
	end)

	describe("swayStep", function()
		local tuning = { omega = 7, damping = 0.35, maxTilt = math.rad(25) }
		local function run(tilt, rate, accel, seconds)
			for _ = 1, math.floor(seconds * 60) do
				tilt, rate = CarryFormulas.swayStep(tilt, rate, accel, 1 / 60, 1, tuning)
			end
			return tilt, rate
		end

		it("rests hanging plumb when the hand holds still", function()
			local tilt, rate = run(Vector2.zero, Vector2.zero, Vector2.zero, 1)
			expect(tilt.Magnitude).to.equal(0)
			expect(rate.Magnitude).to.equal(0)
		end)

		it("swings back against the hand's acceleration, then settles plumb", function()
			-- The hand speeds up forward (+X): the bag's bottom trails behind (-X).
			local tilt = run(Vector2.zero, Vector2.zero, Vector2.new(20, 0), 0.1)
			expect(tilt.X < 0).to.equal(true)
			expect(math.abs(tilt.Y) < 1e-9).to.equal(true)
			local settled = run(tilt, Vector2.zero, Vector2.zero, 3)
			expect(settled.Magnitude < 0.01).to.equal(true)
		end)

		it("never swings past the largest tilt, and stays finite on a long frame", function()
			local tilt, rate = run(Vector2.zero, Vector2.zero, Vector2.new(0, 5000), 0.5)
			expect(tilt.Magnitude <= math.rad(25) + 1e-6).to.equal(true)
			local long, longRate = CarryFormulas.swayStep(tilt, rate, Vector2.new(5000, 0), 2, 1, tuning)
			expect(long.Magnitude <= math.rad(25) + 1e-6).to.equal(true)
			expect(longRate.X == longRate.X).to.equal(true)
		end)
	end)
end
