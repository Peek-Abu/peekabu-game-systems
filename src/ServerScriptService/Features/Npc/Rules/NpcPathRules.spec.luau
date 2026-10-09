local NpcPathRules = require(script.Parent.NpcPathRules)

local HOME = Vector3.new(100, 5, 100)

return function()
	describe("wanderGoal", function()
		it("stays within the radius of home, on home's height", function()
			for _, rolls in { { 0, 0 }, { 0.25, 1 }, { 0.9, 0.5 } } do
				local goal = NpcPathRules.wanderGoal(HOME, 20, rolls[1], rolls[2])
				expect((goal - HOME).Magnitude <= 20 + 1e-6).to.equal(true)
				expect(goal.Y).to.equal(HOME.Y)
			end
		end)

		it("reaches the edge with a full distance roll", function()
			local goal = NpcPathRules.wanderGoal(HOME, 20, 0, 1)
			expect(math.abs((goal - HOME).Magnitude - 20) < 1e-6).to.equal(true)
		end)
	end)

	describe("fleeGoal", function()
		it("runs directly away from the threat, flat", function()
			local goal = NpcPathRules.fleeGoal(Vector3.new(0, 0, 0), Vector3.new(10, 3, 0), 30)
			expect(math.abs(goal.X + 30) < 1e-6).to.equal(true)
			expect(goal.Y).to.equal(0)
			expect(math.abs(goal.Z) < 1e-6).to.equal(true)
		end)

		it("still picks a direction when the threat is on top of it", function()
			local goal = NpcPathRules.fleeGoal(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), 10)
			expect(math.abs(goal.Magnitude - 10) < 1e-6).to.equal(true)
		end)
	end)

	describe("shouldRepath", function()
		it("paths when there is no current path", function()
			expect(NpcPathRules.shouldRepath(nil, HOME, nil, 0, 4, 2)).to.equal(true)
		end)

		it("re-paths when the goal moved past the threshold or the path is old", function()
			expect(NpcPathRules.shouldRepath(HOME, HOME + Vector3.new(1, 0, 0), 10, 11, 4, 2)).to.equal(false)
			expect(NpcPathRules.shouldRepath(HOME, HOME + Vector3.new(5, 0, 0), 10, 11, 4, 2)).to.equal(true)
			expect(NpcPathRules.shouldRepath(HOME, HOME, 10, 12.5, 4, 2)).to.equal(true)
		end)
	end)

	describe("nextPatrolIndex", function()
		it("walks the route in order and loops", function()
			expect(NpcPathRules.nextPatrolIndex(1, 3)).to.equal(2)
			expect(NpcPathRules.nextPatrolIndex(3, 3)).to.equal(1)
		end)
	end)
end
