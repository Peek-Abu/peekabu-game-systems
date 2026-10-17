local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantStuckRules = require(script.Parent.OccupantStuckRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
-- Wedged at (60, 3, 60): nowhere near any route point, and no path out.
local WEDGED = Vector3.new(60, 3, 60)

local function senses(extra)
	local value = {
		position = WEDGED,
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = C.SIGHT_RANGE,
		sightAngle = C.SIGHT_ANGLE,
		players = {},
		resting = false,
		route = ROUTE,
		restPoint = Vector3.new(200, 0, 200),
		zone = ZONE,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function kinds(step)
	local list = {}
	for _, effect in step.effects or {} do
		table.insert(list, effect.kind)
	end
	return table.concat(list, ",")
end

-- Thinks every 0.25 s for `seconds` from `start`, standing at `at` (or a function of the time), from `mind`.
local function run(mind, start, seconds, at, extra)
	local result
	local now = start
	while now <= start + seconds do
		local value = senses(extra)
		value.now = now
		value.position = if type(at) == "function" then at(now) else at
		result = OccupantBrainRules.step(mind, value)
		mind = result.mind
		now += 0.25
	end
	return result
end

return function()
	describe("a patrol leg that goes nowhere", function()
		it("skips to his next route point after STUCK_SECONDS standing still (a steer is dropped)", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.steer = Vector3.new(300, 0, 300)
			local result = run(mind, 100, C.STUCK_SECONDS + 0.1, WEDGED)
			expect(result.mind.mode).to.equal("patrol")
			expect(result.mind.steer).to.equal(nil)
			expect(result.intent.kind).to.equal("goTo")
			expect(result.mind.stuckCount).to.equal(1)
			expect(result.effects).to.equal(nil)
		end)

		it("is lifted to the nearest route point if he is still stuck after that", function()
			local result = run(OccupantBrainRules.newMind(1, 1, 0), 100, 2 * C.STUCK_SECONDS, WEDGED)
			expect(kinds(result)).to.equal("unstick")
			expect(result.effects[1].position).to.equal(ROUTE[1])
			expect(result.mind.stuckCount).to.equal(nil)
		end)

		it("leaves a Manager who is walking alone, however long the walk", function()
			local result = run(OccupantBrainRules.newMind(2, 1, 0), 100, 3 * C.STUCK_SECONDS, function(now)
				return WEDGED + Vector3.new((now - 100) * 10, 0, 0)
			end)
			expect(result.mind.stuckCount).to.equal(nil)
			expect(result.mind.routeIndex).to.equal(2)
		end)

		it("never counts standing still while he is not walking (his break)", function()
			local result = run(OccupantBrainRules.newMind(1, 1, 0), 100, 3 * C.STUCK_SECONDS, WEDGED, {
				resting = true,
			})
			expect(result.mind.mode).to.equal("rest")
			expect(result.effects).to.equal(nil)
			expect(result.mind.stuckCount).to.equal(nil)
		end)
	end)

	describe("abandon", function()
		it("leaves a stare's spot alone and forgets its hider, so he is not sent straight back", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "stare"
			mind.phase = "approach"
			mind.spot = { id = "s1", center = Vector3.new(80, 1.5, 60), stand = Vector3.new(76, 0, 60) }
			mind.quarry = 7
			local step = OccupantStuckRules.abandon({ mind = mind, intent = { kind = "idle" } }, senses())
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.cleared.s1).to.equal(100 + C.CLEARED_SECONDS)
			expect(kinds(step)).to.equal("seen")
			expect(step.effects[1].seen).to.equal(false)
		end)

		it("ends a desk walk's break with the next one scheduled", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "work"
			mind.phase = "toDesk"
			local step = OccupantStuckRules.abandon({ mind = mind, intent = { kind = "idle" } }, senses())
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.nextWorkAt >= 100 + C.WORK_GAP.min).to.equal(true)
		end)

		it("gives up a chase or an investigation with a sigh", function()
			for _, mode in { "chase", "search", "investigate" } do
				local mind = OccupantBrainRules.newMind(1, 1, 0)
				mind.mode = mode
				mind.target = 7
				local step = OccupantStuckRules.abandon({ mind = mind, intent = { kind = "idle" } }, senses())
				expect(step.mind.mode).to.equal("patrol")
				expect(step.mind.target).to.equal(nil)
				expect(step.cue).to.equal("giveUp")
			end
		end)
	end)

	describe("refuge", function()
		it("is the nearest route point that is not where he stands", function()
			expect(OccupantStuckRules.refuge(Vector3.new(101, 3, 100), ROUTE)).to.equal(ROUTE[2])
			expect(OccupantStuckRules.refuge(WEDGED, {})).to.equal(nil)
		end)
	end)
end
