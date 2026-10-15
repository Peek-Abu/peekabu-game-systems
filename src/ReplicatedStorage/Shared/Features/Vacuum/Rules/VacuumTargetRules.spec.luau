local VacuumTargetRules = require(script.Parent.VacuumTargetRules)

return function()
	-- The holder stands at the origin facing -Z, its root 1.4 above the floor; the floor head rests 2.2 ahead.
	local ROOT = Vector3.new(0, 1.4, 0)
	local FACING = Vector3.new(0, 0, -1)
	local HEAD = Vector3.new(0.3, 0.05, -2.2)
	local REACH = { head = 2, underfoot = 1, range = 5, minDot = 0.5, height = 6 }

	local function pile(x: number, z: number, radius: number?, y: number?)
		return { position = Vector3.new(x, y or 0.5, z), radius = radius or 2 }
	end

	describe("reaches", function()
		it("takes a pile the floor head is on or near, whatever the facing", function()
			-- Rim 1.8 from the floor head, but behind the body's facing (it faces +Z here).
			local beside = pile(-3.5, -2.2)
			expect(VacuumTargetRules.reaches(ROOT, Vector3.new(0, 0, 1), HEAD, beside, REACH)).to.equal(true)
			expect(VacuumTargetRules.reaches(ROOT, Vector3.new(0, 0, 1), nil, beside, REACH)).to.equal(false)
		end)

		it("takes a pile in a short cone in front of the character", function()
			-- 6.5 ahead (edge 4.5 from the root), past the floor head's reach.
			expect(VacuumTargetRules.reaches(ROOT, FACING, HEAD, pile(0, -6.5), REACH)).to.equal(true)
		end)

		it("refuses a pile off to the side or past the cone's range", function()
			expect(VacuumTargetRules.reaches(ROOT, FACING, HEAD, pile(6, 1), REACH)).to.equal(false)
			expect(VacuumTargetRules.reaches(ROOT, FACING, HEAD, pile(0, -7.5), REACH)).to.equal(false)
		end)

		it("takes a pile the character stands on, whatever the facing", function()
			expect(VacuumTargetRules.reaches(ROOT, Vector3.new(1, 0, 0), nil, pile(0, 2.5), REACH)).to.equal(true)
		end)

		it("measures to the pile's edge, so a big pile counts from its rim", function()
			-- Centre 4.5 from the head: its rim is 1.5 from it at radius 3, 3.5 at radius 1.
			expect(VacuumTargetRules.reaches(ROOT, Vector3.new(0, 0, 1), HEAD, pile(0.3, -6.7, 3), REACH)).to.equal(
				true
			)
			expect(VacuumTargetRules.reaches(ROOT, Vector3.new(0, 0, 1), HEAD, pile(0.3, -6.7, 1), REACH)).to.equal(
				false
			)
		end)

		it("ignores the camera: only the body's facing and the floor head count", function()
			-- A pile straight ahead of the body is reached even though nothing here says where the camera looks.
			expect(VacuumTargetRules.reaches(ROOT, FACING, nil, pile(0, -4), REACH)).to.equal(true)
		end)

		it("refuses a pile on another floor", function()
			expect(VacuumTargetRules.reaches(ROOT, FACING, HEAD, pile(0, -2.2, 2, 12), REACH)).to.equal(false)
		end)
	end)

	describe("pick", function()
		it("picks the pile nearest the floor head", function()
			local piles = { pile(0, -7), pile(0.3, -4.5), pile(-3, 1) }
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, piles, REACH, nil)).to.equal(2)
		end)

		it("keeps the pile already being cleaned while it is still in reach", function()
			-- Pile 1 is a little nearer the head now, but pile 2 is the one being cleaned.
			local piles = { pile(0.3, -4.3), pile(1.5, -4.6) }
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, piles, REACH, 2)).to.equal(2)
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, piles, REACH, nil)).to.equal(1)
		end)

		it("moves on when the current pile leaves reach", function()
			local piles = { pile(0.3, -4.3), pile(12, 0) }
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, piles, REACH, 2)).to.equal(1)
		end)

		it("returns nil when nothing is in reach", function()
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, { pile(0, 9) }, REACH, nil)).to.equal(nil)
			expect(VacuumTargetRules.pick(ROOT, FACING, HEAD, {}, REACH, nil)).to.equal(nil)
		end)
	end)

	describe("radius", function()
		it("is half the pile's widest flat side as spawned, so shrinking does not move its rim", function()
			expect(VacuumTargetRules.radius(Vector3.new(1.4, 0.4, 1.4), Vector3.new(4, 1.2, 3))).to.equal(2)
			expect(VacuumTargetRules.radius(Vector3.new(3, 1, 3.5), nil)).to.equal(1.75)
		end)
	end)

	describe("widened", function()
		it("gives the server's re-check slack over the client's pick", function()
			local wide = VacuumTargetRules.widened(REACH, 2)
			expect(wide.head).to.equal(4)
			expect(wide.underfoot).to.equal(3)
			expect(wide.range).to.equal(7)
			expect(wide.minDot < REACH.minDot).to.equal(true)
			expect(wide.height).to.equal(REACH.height)
			-- A pile the client picked a moment ago is still accepted after a step away.
			local stepped = Vector3.new(0, 1.4, 1.5)
			expect(VacuumTargetRules.reaches(stepped, FACING, HEAD + Vector3.new(0, 0, 1.5), pile(0, -6.5), wide)).to.equal(
				true
			)
		end)
	end)
end
