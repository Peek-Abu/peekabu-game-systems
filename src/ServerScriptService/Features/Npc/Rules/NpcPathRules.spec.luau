local NpcPathRules = require(script.Parent.NpcPathRules)

local HOME = Vector3.new(100, 5, 100)

return function()
	describe("supportedGoal", function()
		it("keeps repeated jumps on the same supported walking destination", function()
			for _, height in { 4, 7, 11, 5 } do
				expect(NpcPathRules.supportedGoal(Vector3.new(20, height, 10), 1, 3.9)).to.equal(
					Vector3.new(20, 4.9, 10)
				)
			end
		end)
		it("preserves real elevated support and unknown destinations", function()
			expect(NpcPathRules.supportedGoal(Vector3.new(20, 16, 10), 13, 3.9)).to.equal(Vector3.new(20, 16.9, 10))
			expect(NpcPathRules.supportedGoal(Vector3.new(20, 16, 10), nil, 3.9)).to.equal(Vector3.new(20, 16, 10))
		end)
	end)

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

		it("refreshes before a 16-stud runner sample outruns the catch radius", function()
			local constants = require(script.Parent.Parent.Data.NpcConstants)
			local moved = Vector3.new(16 * constants.THINK_INTERVAL, 0, 0)
			expect(moved.Magnitude < 4).to.equal(true)
			expect(
				NpcPathRules.shouldRepath(
					Vector3.zero,
					moved,
					10,
					10 + constants.THINK_INTERVAL,
					constants.REPATH_DISTANCE,
					constants.REPATH_MAX_AGE
				)
			).to.equal(true)
			expect(constants.REPATH_MIN_INTERVAL <= constants.THINK_INTERVAL).to.equal(true)
		end)

		it("re-paths when the goal moved past the threshold or the path is old", function()
			expect(NpcPathRules.shouldRepath(HOME, HOME + Vector3.new(1, 0, 0), 10, 11, 4, 2)).to.equal(false)
			expect(NpcPathRules.shouldRepath(HOME, HOME + Vector3.new(5, 0, 0), 10, 11, 4, 2)).to.equal(true)
			expect(NpcPathRules.shouldRepath(HOME, HOME, 10, 12.5, 4, 2)).to.equal(true)
		end)
	end)

	describe("path recovery", function()
		it("repaths for blocked waypoints ahead, not already passed ones", function()
			expect(NpcPathRules.blockedAhead(4, 3, 6)).to.equal(true)
			expect(NpcPathRules.blockedAhead(3, 3, 6)).to.equal(true)
			expect(NpcPathRules.blockedAhead(2, 3, 6)).to.equal(false)
			expect(NpcPathRules.blockedAhead(4, 0, 0)).to.equal(false)
		end)
		it("requires elapsed lack of progress and a remaining goal to recover", function()
			expect(NpcPathRules.stalled(Vector3.zero, Vector3.new(0.2, 0, 0), 10, 12, 1, 1.5, true)).to.equal(true)
			expect(NpcPathRules.stalled(Vector3.zero, Vector3.new(2, 0, 0), 10, 12, 1, 1.5, true)).to.equal(false)
			expect(NpcPathRules.stalled(Vector3.zero, Vector3.zero, 10, 11, 1, 1.5, true)).to.equal(false)
			expect(NpcPathRules.stalled(Vector3.zero, Vector3.zero, 10, 12, 1, 1.5, false)).to.equal(false)
		end)
	end)

	describe("continuous route progress", function()
		local function waypoint(x, z, jump)
			return {
				Position = Vector3.new(x, 0, z or 0),
				Action = if jump then Enum.PathWaypointAction.Jump else Enum.PathWaypointAction.Walk,
			}
		end
		it("adopts the segment ahead after moving during computation, not waypoint two", function()
			local points = { waypoint(0), waypoint(4), waypoint(8), waypoint(12), waypoint(16) }
			expect(NpcPathRules.resumeIndex(points, Vector3.new(10, 0, 0), 12, 3)).to.equal(4)
		end)
		it("retains corners and cannot jump to a nearby parallel later route", function()
			local points = { waypoint(0), waypoint(8), waypoint(8, 8), waypoint(0, 8), waypoint(0, 1) }
			expect(NpcPathRules.resumeIndex(points, Vector3.new(7, 0, 0), 9, 3)).to.equal(2)
		end)
		it("rejects a route displaced beyond its adoption corridor", function()
			expect(NpcPathRules.resumeIndex({ waypoint(0), waypoint(8) }, Vector3.new(4, 0, 8), 10, 3)).to.equal(nil)
		end)
		it("never skips an unexecuted jump or indexes an empty path", function()
			expect(
				NpcPathRules.resumeIndex({ waypoint(0), waypoint(4, 0, true), waypoint(8) }, Vector3.new(6, 0, 0), 9, 3)
			).to.equal(2)
			expect(NpcPathRules.resumeIndex({}, Vector3.zero, 3, 3)).to.equal(nil)
		end)
		it("advances on crossing the waypoint plane without cutting distant corners", function()
			expect(NpcPathRules.passedWaypoint(Vector3.zero, Vector3.new(4, 0, 0), Vector3.new(4.4, 0, 0.4), 1)).to.equal(
				true
			)
			expect(NpcPathRules.passedWaypoint(Vector3.zero, Vector3.new(4, 0, 0), Vector3.new(5, 0, 4), 1)).to.equal(
				false
			)
			expect(NpcPathRules.passedWaypoint(Vector3.zero, Vector3.new(4, 0, 0), Vector3.new(2, 0, 0), 1)).to.equal(
				false
			)
		end)
	end)

	describe("headStraight", function()
		it("heads straight at a goal in clear line while its first path computes", function()
			expect(NpcPathRules.headStraight(true, 0, 0, true)).to.equal(true)
		end)

		it("follows the route once one has arrived", function()
			expect(NpcPathRules.headStraight(true, 2, 5, true)).to.equal(false)
		end)

		it("heads straight again once the route is used up and a fresh path computes", function()
			expect(NpcPathRules.headStraight(true, 6, 5, true)).to.equal(true)
		end)

		it("never heads straight at a goal out of line (a wall between)", function()
			expect(NpcPathRules.headStraight(false, 0, 0, true)).to.equal(false)
		end)

		it("leaves a finished computation to the mover's own fallback", function()
			expect(NpcPathRules.headStraight(true, 0, 0, false)).to.equal(false)
		end)
	end)

	describe("nextPatrolIndex", function()
		it("walks the route in order and loops", function()
			expect(NpcPathRules.nextPatrolIndex(1, 3)).to.equal(2)
			expect(NpcPathRules.nextPatrolIndex(3, 3)).to.equal(1)
		end)
	end)
end
