local SkillCheckInputFormulas = require(script.Parent.SkillCheckInputFormulas)

local function near(a, b, eps)
	return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-6)
end

return function()
	describe("fromPoint", function()
		local centre = Vector2.new(500, 300)

		it("reads a point's angle round the ring's centre (0 up, clockwise, screen y down)", function()
			expect(near(SkillCheckInputFormulas.fromPoint(Vector2.new(500, 200), centre, 4), 0)).to.equal(true)
			expect(near(SkillCheckInputFormulas.fromPoint(Vector2.new(600, 300), centre, 4), 90)).to.equal(true)
			expect(near(SkillCheckInputFormulas.fromPoint(Vector2.new(500, 400), centre, 4), 180)).to.equal(true)
			expect(near(SkillCheckInputFormulas.fromPoint(Vector2.new(400, 300), centre, 4), 270)).to.equal(true)
		end)

		it("has no angle right on the centre", function()
			expect(SkillCheckInputFormulas.fromPoint(Vector2.new(502, 301), centre, 4)).to.equal(nil)
			expect(SkillCheckInputFormulas.fromPoint(centre, centre, 4)).to.equal(nil)
		end)

		it("wraps just left of straight up to near 360", function()
			local angle = SkillCheckInputFormulas.fromPoint(Vector2.new(499, 200), centre, 4)
			expect(angle > 359 and angle < 360).to.equal(true)
		end)
	end)

	describe("nudge", function()
		it("moves the virtual cursor by the mouse delta", function()
			local moved = SkillCheckInputFormulas.nudge(Vector2.new(0, -10), Vector2.new(3, 4), 50)
			expect(moved.X).to.equal(3)
			expect(moved.Y).to.equal(-6)
		end)

		it("keeps the cursor within the radius, along its direction", function()
			local moved = SkillCheckInputFormulas.nudge(Vector2.new(0, -40), Vector2.new(0, -100), 50)
			expect(near(moved.X, 0)).to.equal(true)
			expect(near(moved.Y, -50)).to.equal(true)
		end)

		it("swings round the circle when pushed sideways at the edge", function()
			local cursor = Vector2.new(0, -50)
			for _ = 1, 20 do
				cursor = SkillCheckInputFormulas.nudge(cursor, Vector2.new(10, 0), 50)
			end
			-- Pushed right long enough, it ends near 90 degrees.
			local angle = SkillCheckInputFormulas.fromPoint(cursor, Vector2.zero, 1)
			expect(angle > 70 and angle <= 90).to.equal(true)
			expect(near(cursor.Magnitude, 50, 1e-4)).to.equal(true)
		end)

		it("ignores a non-finite delta", function()
			local moved = SkillCheckInputFormulas.nudge(Vector2.new(5, 5), Vector2.new(0 / 0, 1), 50)
			expect(moved.X).to.equal(5)
			expect(moved.Y).to.equal(5)
		end)
	end)

	describe("stick", function()
		it("reads a stick pushed up as 0 and right as 90 (the stick's y is up)", function()
			expect(near(SkillCheckInputFormulas.stick(Vector2.new(0, 1), 0.35), 0)).to.equal(true)
			expect(near(SkillCheckInputFormulas.stick(Vector2.new(1, 0), 0.35), 90)).to.equal(true)
			expect(near(SkillCheckInputFormulas.stick(Vector2.new(0, -1), 0.35), 180)).to.equal(true)
			expect(near(SkillCheckInputFormulas.stick(Vector2.new(-1, 0), 0.35), 270)).to.equal(true)
		end)

		it("has no angle inside the deadzone", function()
			expect(SkillCheckInputFormulas.stick(Vector2.new(0.2, 0.2), 0.35)).to.equal(nil)
			expect(SkillCheckInputFormulas.stick(Vector2.zero, 0.35)).to.equal(nil)
		end)

		it("reads a stick just past the deadzone", function()
			expect(SkillCheckInputFormulas.stick(Vector2.new(0, 0.4), 0.35)).to.be.ok()
		end)
	end)

	describe("withinReach", function()
		it("takes touches near the ring and refuses far ones", function()
			local centre = Vector2.new(100, 100)
			expect(SkillCheckInputFormulas.withinReach(Vector2.new(130, 100), centre, 40)).to.equal(true)
			expect(SkillCheckInputFormulas.withinReach(Vector2.new(140, 100), centre, 40)).to.equal(true)
			expect(SkillCheckInputFormulas.withinReach(Vector2.new(141, 100), centre, 40)).to.equal(false)
		end)
	end)
end
