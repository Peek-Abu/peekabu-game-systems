local SkillCheckAngleFormulas = require(script.Parent.SkillCheckAngleFormulas)

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

return function()
	describe("normalize", function()
		it("keeps angles already in [0, 360)", function()
			expect(SkillCheckAngleFormulas.normalize(0)).to.equal(0)
			expect(SkillCheckAngleFormulas.normalize(359.5)).to.equal(359.5)
		end)

		it("wraps 360 and above back round", function()
			expect(SkillCheckAngleFormulas.normalize(360)).to.equal(0)
			expect(SkillCheckAngleFormulas.normalize(725)).to.equal(5)
		end)

		it("wraps negative angles forward", function()
			expect(SkillCheckAngleFormulas.normalize(-10)).to.equal(350)
			expect(SkillCheckAngleFormulas.normalize(-370)).to.equal(350)
		end)
	end)

	describe("distance", function()
		it("is the short way round", function()
			expect(SkillCheckAngleFormulas.distance(10, 40)).to.equal(30)
			expect(SkillCheckAngleFormulas.distance(40, 10)).to.equal(30)
		end)

		it("crosses 0/360 the short way", function()
			expect(SkillCheckAngleFormulas.distance(355, 5)).to.equal(10)
			expect(SkillCheckAngleFormulas.distance(5, 355)).to.equal(10)
			expect(SkillCheckAngleFormulas.distance(0, 359)).to.equal(1)
		end)

		it("never exceeds 180", function()
			expect(SkillCheckAngleFormulas.distance(0, 180)).to.equal(180)
			expect(SkillCheckAngleFormulas.distance(10, 200)).to.equal(170)
		end)

		it("treats unnormalised inputs the same", function()
			expect(SkillCheckAngleFormulas.distance(-5, 365)).to.equal(10)
			expect(SkillCheckAngleFormulas.distance(720, 0)).to.equal(0)
		end)
	end)

	describe("inGap", function()
		it("hits inside the opening", function()
			expect(SkillCheckAngleFormulas.inGap(100, 90, 60, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(90, 90, 60, 0)).to.equal(true)
		end)

		it("hits exactly on the opening's edge", function()
			expect(SkillCheckAngleFormulas.inGap(120, 90, 60, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(60, 90, 60, 0)).to.equal(true)
		end)

		it("misses just outside the opening", function()
			expect(SkillCheckAngleFormulas.inGap(121, 90, 60, 0)).to.equal(false)
			expect(SkillCheckAngleFormulas.inGap(270, 90, 60, 0)).to.equal(false)
		end)

		it("widens each side by the tolerance", function()
			expect(SkillCheckAngleFormulas.inGap(125, 90, 60, 8)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(55, 90, 60, 8)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(129, 90, 60, 8)).to.equal(false)
		end)

		it("wraps an opening that straddles 0/360", function()
			-- Opening centred on 350, 40 wide: 330..10.
			expect(SkillCheckAngleFormulas.inGap(5, 350, 40, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(0, 350, 40, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(335, 350, 40, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(15, 350, 40, 0)).to.equal(false)
			expect(SkillCheckAngleFormulas.inGap(325, 350, 40, 0)).to.equal(false)
		end)

		it("wraps an opening centred on 0", function()
			expect(SkillCheckAngleFormulas.inGap(355, 0, 30, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(14, 0, 30, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(16, 0, 30, 0)).to.equal(false)
		end)

		it("accepts unnormalised reported angles", function()
			expect(SkillCheckAngleFormulas.inGap(-5, 0, 30, 0)).to.equal(true)
			expect(SkillCheckAngleFormulas.inGap(370, 0, 30, 0)).to.equal(true)
		end)

		it("misses on a non-finite angle", function()
			expect(SkillCheckAngleFormulas.inGap(0 / 0, 0, 360, 0)).to.equal(false)
			expect(SkillCheckAngleFormulas.inGap(math.huge, 0, 360, 0)).to.equal(false)
			expect(SkillCheckAngleFormulas.inGap(-math.huge, 0, 360, 0)).to.equal(false)
		end)

		it("hits everywhere with a full-circle opening", function()
			expect(SkillCheckAngleFormulas.inGap(180, 0, 360, 0)).to.equal(true)
		end)
	end)

	describe("gapWidth", function()
		it("starts wide and ends narrow", function()
			expect(SkillCheckAngleFormulas.gapWidth(0, 120, 60)).to.equal(120)
			expect(SkillCheckAngleFormulas.gapWidth(1, 120, 60)).to.equal(60)
			expect(SkillCheckAngleFormulas.gapWidth(0.5, 120, 60)).to.equal(90)
		end)

		it("narrows as progress rises", function()
			local a = SkillCheckAngleFormulas.gapWidth(0.2, 120, 60)
			local b = SkillCheckAngleFormulas.gapWidth(0.7, 120, 60)
			expect(b < a).to.equal(true)
		end)

		it("clamps progress outside [0, 1]", function()
			expect(SkillCheckAngleFormulas.gapWidth(-1, 120, 60)).to.equal(120)
			expect(SkillCheckAngleFormulas.gapWidth(3, 120, 60)).to.equal(60)
		end)

		it("treats NaN progress as the start", function()
			expect(SkillCheckAngleFormulas.gapWidth(0 / 0, 120, 60)).to.equal(120)
		end)
	end)

	describe("weekScale", function()
		it("is 1 in week 1 and with no week (Quick shift)", function()
			expect(SkillCheckAngleFormulas.weekScale(1, 0.1, 0.6)).to.equal(1)
			expect(SkillCheckAngleFormulas.weekScale(nil, 0.1, 0.6)).to.equal(1)
			expect(SkillCheckAngleFormulas.weekScale(0, 0.1, 0.6)).to.equal(1)
			expect(SkillCheckAngleFormulas.weekScale(0 / 0, 0.1, 0.6)).to.equal(1)
		end)

		it("drops a step a week from week 2", function()
			expect(math.abs(SkillCheckAngleFormulas.weekScale(2, 0.1, 0.6) - 0.9) < 1e-9).to.equal(true)
			expect(math.abs(SkillCheckAngleFormulas.weekScale(3, 0.1, 0.6) - 0.8) < 1e-9).to.equal(true)
			expect(math.abs(SkillCheckAngleFormulas.weekScale(3.9, 0.1, 0.6) - 0.8) < 1e-9).to.equal(true)
		end)

		it("stops at the floor", function()
			expect(math.abs(SkillCheckAngleFormulas.weekScale(5, 0.1, 0.6) - 0.6) < 1e-9).to.equal(true)
			expect(SkillCheckAngleFormulas.weekScale(6, 0.1, 0.6)).to.equal(0.6)
			expect(SkillCheckAngleFormulas.weekScale(40, 0.1, 0.6)).to.equal(0.6)
		end)
	end)

	describe("nextGap", function()
		it("places the first opening anywhere by the roll", function()
			expect(SkillCheckAngleFormulas.nextGap(nil, 0, 90)).to.equal(0)
			expect(SkillCheckAngleFormulas.nextGap(nil, 0.25, 90)).to.equal(90)
		end)

		it("keeps later openings at least minShift from the last", function()
			for _, previous in { 0, 45, 180, 300, 359 } do
				for _, roll in { 0, 0.1, 0.5, 0.9, 0.999 } do
					local gap = SkillCheckAngleFormulas.nextGap(previous, roll, 90)
					expect(gap >= 0 and gap < 360).to.equal(true)
					expect(SkillCheckAngleFormulas.distance(gap, previous) >= 90 - 1e-6).to.equal(true)
				end
			end
		end)

		it("wraps past 360", function()
			expect(SkillCheckAngleFormulas.nextGap(300, 0, 90)).to.equal(30)
		end)

		it("clamps a roll outside [0, 1)", function()
			local low = SkillCheckAngleFormulas.nextGap(nil, -2, 90)
			local high = SkillCheckAngleFormulas.nextGap(nil, 7, 90)
			expect(low >= 0 and low < 360).to.equal(true)
			expect(high >= 0 and high < 360).to.equal(true)
		end)
	end)

	describe("fromVector / toVector", function()
		it("reads straight up as 0 and goes clockwise on the screen (y down)", function()
			expect(near(SkillCheckAngleFormulas.fromVector(Vector2.new(0, -1)), 0)).to.equal(true)
			expect(near(SkillCheckAngleFormulas.fromVector(Vector2.new(1, 0)), 90)).to.equal(true)
			expect(near(SkillCheckAngleFormulas.fromVector(Vector2.new(0, 1)), 180)).to.equal(true)
			expect(near(SkillCheckAngleFormulas.fromVector(Vector2.new(-1, 0)), 270)).to.equal(true)
		end)

		it("ignores length", function()
			expect(near(SkillCheckAngleFormulas.fromVector(Vector2.new(50, -50)), 45)).to.equal(true)
		end)

		it("has no angle for a zero or non-finite vector", function()
			expect(SkillCheckAngleFormulas.fromVector(Vector2.zero)).to.equal(nil)
			expect(SkillCheckAngleFormulas.fromVector(Vector2.new(0 / 0, 1))).to.equal(nil)
		end)

		it("round-trips through toVector", function()
			for _, angle in { 0, 30, 90, 179, 250, 359 } do
				local back = SkillCheckAngleFormulas.fromVector(SkillCheckAngleFormulas.toVector(angle))
				expect(near(back, angle, 1e-4)).to.equal(true)
			end
		end)

		it("toVector is a unit vector pointing the screen way", function()
			local right = SkillCheckAngleFormulas.toVector(90)
			expect(near(right.X, 1)).to.equal(true)
			expect(near(right.Y, 0)).to.equal(true)
			local up = SkillCheckAngleFormulas.toVector(0)
			expect(near(up.Y, -1)).to.equal(true)
		end)
	end)
end
