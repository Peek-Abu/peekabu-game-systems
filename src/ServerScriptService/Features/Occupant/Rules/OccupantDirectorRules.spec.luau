local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantDirectorRules = require(script.Parent.OccupantDirectorRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = {
	Vector3.new(100, 0, 100),
	Vector3.new(150, 0, 100),
	Vector3.new(150, 0, 150),
	Vector3.new(300, 0, 300),
}
local PACING = { tier = 0, solo = false, overtime = false }

local function senses(extra)
	local value = {
		position = Vector3.new(60, 3, 60),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = C.SIGHT_RANGE,
		sightAngle = C.SIGHT_ANGLE,
		players = {},
		resting = false,
		route = ROUTE,
		restPoint = Vector3.new(200, 0, 200),
		zone = ZONE,
		pacing = PACING,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

-- A crew member he cannot see (behind a wall), out by the second route point.
local UNSEEN = { userId = 7, position = Vector3.new(150, 3, 110), clear = false }

local function mind(extra)
	local value = OccupantBrainRules.newMind(1, 1, 0)
	value.nextCalloutAt = 1000
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("steering", function()
		it("steers him toward a crew member's general area when a steer is due", function()
			local step = OccupantBrainRules.step(mind(), senses({ players = { UNSEEN }, rolls = { 0, 0, 0, 0 } }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.steer).to.be.ok()
			expect(step.intent.position).to.equal(step.mind.steer)
			-- Never their exact spot.
			expect((step.mind.steer - UNSEEN.position).Magnitude >= C.STEER_MIN).to.equal(true)
			expect(step.mind.nextSteerAt).to.equal(100 + C.STEER_CREW)
		end)

		it("does nothing without pacing (bare rules) or with no crew", function()
			local bare = senses({ players = { UNSEEN } })
			bare.pacing = nil
			expect(OccupantBrainRules.step(mind(), bare).mind.steer).to.equal(nil)
			expect(OccupantBrainRules.step(mind(), senses()).mind.steer).to.equal(nil)
		end)

		it("leaves out players in the truck's box", function()
			local inBox = { userId = 7, position = Vector3.new(20, 3, 10), clear = false }
			expect(OccupantBrainRules.step(mind(), senses({ players = { inBox } })).mind.steer).to.equal(nil)
		end)
	end)

	describe("the PA call-out", function()
		it("calls out the crew member farthest from him, then steers to them soon", function()
			local near = { userId = 8, position = Vector3.new(70, 3, 75), clear = false }
			local step = OccupantBrainRules.step(mind({ nextCalloutAt = 50 }), senses({ players = { UNSEEN, near } }))
			expect(step.effects[1].kind).to.equal("callout")
			expect(step.effects[1].userId).to.equal(7)
			expect(step.mind.focus).to.equal(7)
			expect(step.mind.nextSteerAt).to.equal(100 + C.CALLOUT_STEER_DELAY)
			local steer = OccupantBrainRules.step(
				step.mind,
				senses({ now = 100 + C.CALLOUT_STEER_DELAY, players = { UNSEEN, near } })
			)
			expect(steer.mind.steer).to.be.ok()
			expect((steer.mind.steer - UNSEEN.position).Magnitude < (steer.mind.steer - near.position).Magnitude).to.equal(
				true
			)
			expect(steer.mind.focus).to.equal(nil)
		end)
	end)

	describe("the menace gauge and the breather", function()
		it("rises while he chases", function()
			local seen = { userId = 7, position = Vector3.new(90, 3, 60), clear = true }
			local first = OccupantBrainRules.step(mind(), senses({ players = { seen } }))
			local second = OccupantBrainRules.step(first.mind, senses({ now = 100.25, players = { seen } }))
			expect(second.mind.menace > first.mind.menace).to.equal(true)
		end)

		it("takes a breather at the far side when it is full, and leaves the crew be", function()
			local step = OccupantBrainRules.step(
				mind({ menace = C.MENACE_MAX }),
				senses({ players = { UNSEEN }, rolls = { 0.5, 0.5, 0.5, 0 } })
			)
			expect(step.mind.menace).to.equal(0)
			expect(step.mind.breatherUntil).to.equal(100 + C.BREATHER_CREW.min)
			expect(step.mind.steer).to.equal(Vector3.new(300, 0, 300))
			-- On the breather: no steer, and a noise far from him is ignored.
			local later = OccupantBrainRules.step(
				step.mind,
				senses({
					now = 120,
					position = Vector3.new(300, 3, 300),
					players = { UNSEEN },
					heard = Vector3.new(150, 0, 110),
				})
			)
			expect(later.mind.mode).to.equal("patrol")
			expect(later.mind.steer).to.equal(nil)
		end)
	end)

	describe("track", function()
		it("counts the seconds he has someone in sight, and keeps them while they hide", function()
			local before = mind({ lastThink = 99 })
			local seen = { userId = 7, position = Vector3.new(90, 3, 60), clear = true }
			local result = OccupantDirectorRules.track(
				before,
				{ mind = before, intent = { kind = "idle" } },
				senses({ players = { seen } })
			)
			expect(result.mind.watched[7]).to.be.near(0.5)
			local hidden = OccupantDirectorRules.track(
				result.mind,
				{ mind = result.mind, intent = { kind = "idle" } },
				senses({ now = 110, hiders = { { userId = 7, spotId = "s", seen = true } } })
			)
			expect(hidden.mind.watched[7]).to.be.near(0.5)
		end)
	end)
end
