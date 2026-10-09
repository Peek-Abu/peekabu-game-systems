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
end
