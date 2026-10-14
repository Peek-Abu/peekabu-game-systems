local Formulas = require(script.Parent.VacuumHoldFormulas)
return function()
	-- A vacuum in grip space (+Y up, -Z front): a body hanging 1.5 below the grip and a floor head 2 ahead and
	-- 1.9 below it, like the real one.
	local corners = {
		Vector3.new(-0.5, -1.5, -0.5),
		Vector3.new(0.5, -1.5, 0.5),
		Vector3.new(-0.7, -1.9, -2.4),
		Vector3.new(0.7, -1.9, -2.2),
	}

	describe("depth", function()
		it("is how far the lowest corner sits below the grip", function()
			expect(Formulas.depth(corners, 0)).to.be.near(1.9, 1e-6)
		end)

		it("tilting the front up raises the floor head and lowers the back", function()
			local tilt = math.rad(10)
			expect(Formulas.depth({ Vector3.new(0, -1.9, -2.4) }, tilt) < 1.9).to.equal(true)
			expect(Formulas.depth({ Vector3.new(0, -1.5, 0.5) }, tilt) > 1.5).to.equal(true)
		end)
	end)

	describe("fit", function()
		local clearance, maxTilt = 0.08, math.rad(25)
		it("leaves a stock avatar's vacuum upright and unlifted", function()
			local tilt, lift = Formulas.fit(corners, 2.11, clearance, maxTilt)
			expect(tilt).to.equal(0)
			expect(lift).to.equal(0)
		end)

		it("leaves it unchanged when the hand height is unknown", function()
			local tilt, lift = Formulas.fit(corners, nil, clearance, maxTilt)
			expect(tilt).to.equal(0)
			expect(lift).to.equal(0)
		end)

		it("only tilts a slightly short holder: the floor head rests just above the floor", function()
			local tilt, lift = Formulas.fit(corners, 1.85, clearance, maxTilt)
			expect(tilt > 0).to.equal(true)
			expect(tilt <= maxTilt).to.equal(true)
			expect(lift).to.equal(0)
			expect(Formulas.depth(corners, tilt) + clearance <= 1.85 + 1e-6).to.equal(true)
			-- The smallest tilt that does it.
			expect(Formulas.depth(corners, tilt - math.rad(1)) + clearance > 1.85).to.equal(true)
		end)

		it("tilts a much shorter holder no further than the limit, and lifts the hand for the rest", function()
			local tilt, lift = Formulas.fit(corners, 0.86, clearance, maxTilt)
			expect(tilt <= maxTilt + 1e-6).to.equal(true)
			expect(lift > 0).to.equal(true)
			-- With the hand lifted, the lowest point clears the floor by exactly the clearance.
			expect(0.86 + lift - Formulas.depth(corners, tilt)).to.be.near(clearance, 1e-6)
		end)
	end)

	describe("liftTarget", function()
		-- Shoulder 1.1 above the root, arm 1.3 to the grip, torso 0.6 half-wide, vacuum 0.7 half-wide.
		local shoulder = Vector3.new(0.45, 1.1, 0)
		it("raises the grip by the lift, beside the torso, within the arm's reach", function()
			local target = Formulas.liftTarget(shoulder, 1.3, 0.9, 0.6 + 0.7)
			expect(target.Y).to.be.near(1.1 - 1.3 + 0.9, 1e-6)
			expect(target.X >= 0.45).to.equal(true)
			expect((target - shoulder).Magnitude <= 1.3).to.equal(true)
			-- Held out in front, not behind.
			expect(target.Z <= 0).to.equal(true)
		end)

		it("keeps the grip on the shoulder's side when the clearance is out of reach", function()
			local target = Formulas.liftTarget(shoulder, 1.3, 0.9, 5)
			expect((target - shoulder).Magnitude <= 1.3).to.equal(true)
			expect(target.X >= 0.45).to.equal(true)
		end)
	end)
end
