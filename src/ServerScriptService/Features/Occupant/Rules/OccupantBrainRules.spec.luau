local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- The loading bay (safe), a three-point route and the break room's rest point.
local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
local REST = Vector3.new(200, 0, 200)

-- Harlow at (60, 3, 60) looking along +X, at os.clock 100.
local function senses(extra)
	local value = {
		position = Vector3.new(60, 3, 60),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = OccupantConstants.SIGHT_RANGE,
		sightAngle = OccupantConstants.SIGHT_ANGLE,
		players = {},
		resting = false,
		route = ROUTE,
		restPoint = REST,
		zone = ZONE,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function player(userId, position, clear)
	return { userId = userId, position = position, clear = clear ~= false }
end

local function fresh()
	return OccupantBrainRules.newMind(1, 1, 0)
end

local AHEAD = Vector3.new(80, 3, 60)

return function()
	describe("newMind", function()
		it("starts patrolling at the given point and direction", function()
			local mind = OccupantBrainRules.newMind(3, -1, 5)
			expect(mind.mode).to.equal("patrol")
			expect(mind.routeIndex).to.equal(3)
			expect(mind.routeStep).to.equal(-1)
			expect(mind.since).to.equal(5)
			expect(next(mind.grace)).to.equal(nil)
		end)
	end)

	describe("patrol", function()
		it("walks his route at patrol pace", function()
			local step = OccupantBrainRules.step(fresh(), senses())
			expect(step.mind.mode).to.equal("patrol")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(ROUTE[1])
			expect(step.intent.run).to.equal(false)
			expect(step.cue).to.equal(nil)
		end)

		it("heads for the next point on arrival, in his direction, wrapping round", function()
			local forward = OccupantBrainRules.step(fresh(), senses({ position = Vector3.new(101, 3, 100) }))
			expect(forward.mind.routeIndex).to.equal(2)
			expect(forward.intent.position).to.equal(ROUTE[2])
			local backward = OccupantBrainRules.step(
				OccupantBrainRules.newMind(1, -1, 0),
				senses({ position = Vector3.new(101, 3, 100) })
			)
			expect(backward.mind.routeIndex).to.equal(3)
			expect(backward.intent.position).to.equal(ROUTE[3])
		end)

		it("stands still with no route", function()
			expect(OccupantBrainRules.step(fresh(), senses({ route = {} })).intent.kind).to.equal("idle")
		end)
	end)

	describe("investigate", function()
		local NOISE = Vector3.new(90, 0, 60)

		it("walks to a noise he hears, curious", function()
			local step = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			expect(step.mind.mode).to.equal("investigate")
			expect(step.mind.noise).to.equal(NOISE)
			expect(step.cue).to.equal("curious")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(NOISE)
			expect(step.intent.run).to.equal(false)
		end)

		it("ignores a noise inside the loading bay", function()
			local step = OccupantBrainRules.step(fresh(), senses({ heard = Vector3.new(20, 0, 10) }))
			expect(step.mind.mode).to.equal("patrol")
		end)

		it("looks around on arrival, then gives up with a sigh", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local there = Vector3.new(90, 3, 61)
			local arrived = OccupantBrainRules.step(heard.mind, senses({ position = there, now = 101 }))
			expect(arrived.intent.kind).to.equal("idle")
			expect(arrived.mind.arrivedAt).to.equal(101)
			local looking = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = there, now = 101 + OccupantConstants.LOOK_SECONDS - 0.1 })
			)
			expect(looking.mind.mode).to.equal("investigate")
			expect(looking.intent.kind).to.equal("idle")
			local done = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = there, now = 101 + OccupantConstants.LOOK_SECONDS })
			)
			expect(done.mind.mode).to.equal("patrol")
			expect(done.cue).to.equal("giveUp")
			expect(done.mind.noise).to.equal(nil)
		end)

		it("gives up a noise he cannot reach", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local stuck = OccupantBrainRules.step(heard.mind, senses({ now = 100 + OccupantConstants.GIVE_UP_SECONDS }))
			expect(stuck.mind.mode).to.equal("patrol")
			expect(stuck.cue).to.equal("giveUp")
		end)

		it("turns to a newer noise without a second cue", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			local other = Vector3.new(70, 0, 90)
			local again = OccupantBrainRules.step(heard.mind, senses({ heard = other, now = 101 }))
			expect(again.mind.noise).to.equal(other)
			expect(again.cue).to.equal(nil)
		end)
	end)

	describe("chase", function()
		it("spots a player in his cone with a clear line of sight", function()
			local step = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			expect(step.mind.mode).to.equal("chase")
			expect(step.mind.target).to.equal(7)
			expect(step.mind.lastSeen).to.equal(AHEAD)
			expect(step.cue).to.equal("spotted")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(AHEAD)
			expect(step.intent.run).to.equal(true)
		end)

		it("does not see through walls, behind him, past his range or outside his cone", function()
			for _, glimpse in
				{
					player(7, AHEAD, false),
					player(7, Vector3.new(40, 3, 60)),
					player(7, Vector3.new(130, 3, 60)),
					player(7, Vector3.new(60, 3, 90)),
				}
			do
				local step = OccupantBrainRules.step(fresh(), senses({ players = { glimpse } }))
				expect(step.mind.mode).to.equal("patrol")
			end
		end)

		it("catches within reach", function()
			local step = OccupantBrainRules.step(fresh(), senses({ players = { player(7, Vector3.new(63, 3, 60)) } }))
			expect(step.intent.kind).to.equal("attack")
			expect(step.intent.target).to.equal(7)
		end)

		it("keeps chasing his target over a nearer player", function()
			local first = OccupantBrainRules.step(fresh(), senses({ players = { player(7, Vector3.new(90, 3, 60)) } }))
			local second = OccupantBrainRules.step(
				first.mind,
				senses({ now = 101, players = { player(7, Vector3.new(90, 3, 60)), player(8, Vector3.new(70, 3, 60)) } })
			)
			expect(second.mind.target).to.equal(7)
			expect(second.cue).to.equal(nil)
		end)

		it("searches the last place he saw them, then gives up", function()
			local seenAt = Vector3.new(90, 3, 60)
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, seenAt) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101 }))
			expect(lost.mind.mode).to.equal("search")
			expect(lost.mind.target).to.equal(nil)
			expect(lost.intent.kind).to.equal("goTo")
			expect(lost.intent.position).to.equal(seenAt)
			expect(lost.intent.run).to.equal(true)
			local arrived = OccupantBrainRules.step(lost.mind, senses({ position = seenAt, now = 102 }))
			expect(arrived.mind.arrivedAt).to.equal(102)
			local searching = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = seenAt, now = 102 + OccupantConstants.SEARCH_SECONDS - 0.1 })
			)
			expect(searching.mind.mode).to.equal("search")
			local done = OccupantBrainRules.step(
				arrived.mind,
				senses({ position = seenAt, now = 102 + OccupantConstants.SEARCH_SECONDS })
			)
			expect(done.mind.mode).to.equal("patrol")
			expect(done.cue).to.equal("giveUp")
		end)

		it("loses a player who steps into the loading bay and searches outside it", function()
			local base = { position = Vector3.new(60, 3, 20), look = Vector3.new(-1, 0, 0) }
			local outside = Vector3.new(45, 3, 20)
			local chase = OccupantBrainRules.step(
				fresh(),
				senses({ position = base.position, look = base.look, players = { player(7, outside) } })
			)
			expect(chase.mind.mode).to.equal("chase")
			local inside = OccupantBrainRules.step(
				chase.mind,
				senses({
					position = base.position,
					look = base.look,
					now = 101,
					players = { player(7, Vector3.new(35, 3, 20)) },
				})
			)
			expect(inside.mind.mode).to.equal("search")
			expect(inside.intent.position).to.equal(outside)
			expect(OccupantBrainRules.inZone(inside.intent.position, ZONE)).to.equal(false)
		end)

		it("never spots a player standing in the loading bay", function()
			local step = OccupantBrainRules.step(
				fresh(),
				senses({
					position = Vector3.new(60, 3, 20),
					look = Vector3.new(-1, 0, 0),
					players = { player(7, Vector3.new(35, 3, 20)) },
				})
			)
			expect(step.mind.mode).to.equal("patrol")
		end)
	end)

	describe("catch and grace", function()
		it("stands after a catch, then walks on to his next point", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			expect(caught.mode).to.equal("catch")
			expect(caught.grace[7]).to.equal(100 + OccupantConstants.GRACE_SECONDS)
			expect(caught.target).to.equal(7)
			local holding = OccupantBrainRules.step(caught, senses({ now = 100 + OccupantConstants.CATCH_HOLD - 0.1 }))
			expect(holding.mind.mode).to.equal("catch")
			expect(holding.intent.kind).to.equal("idle")
			local walking = OccupantBrainRules.step(caught, senses({ now = 100 + OccupantConstants.CATCH_HOLD }))
			expect(walking.mind.mode).to.equal("patrol")
			expect(walking.mind.target).to.equal(nil)
			expect(walking.mind.routeIndex).to.equal(2)
			expect(walking.intent.position).to.equal(ROUTE[2])
		end)

		it("ignores the caught player during the grace, and sees them after it", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			local during = OccupantBrainRules.step(
				caught,
				senses({ now = 100 + OccupantConstants.CATCH_HOLD + 1, players = { player(7, AHEAD) } })
			)
			expect(during.mind.mode).to.equal("patrol")
			local after = OccupantBrainRules.step(
				during.mind,
				senses({ now = 100 + OccupantConstants.GRACE_SECONDS, players = { player(7, AHEAD) } })
			)
			expect(after.mind.mode).to.equal("chase")
		end)

		it("still sees everyone else during one player's grace", function()
			local caught = OccupantBrainRules.caught(fresh(), 7, 100)
			local step = OccupantBrainRules.step(
				caught,
				senses({ now = 100 + OccupantConstants.CATCH_HOLD + 1, players = { player(8, AHEAD) } })
			)
			expect(step.mind.target).to.equal(8)
		end)

		it("does not change the mind he was given", function()
			local mind = fresh()
			OccupantBrainRules.caught(mind, 7, 100)
			expect(mind.mode).to.equal("patrol")
			expect(mind.grace[7]).to.equal(nil)
		end)
	end)

	describe("rest", function()
		it("walks to the break room on the break, ignoring everyone", function()
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local rest = OccupantBrainRules.step(chase.mind, senses({ resting = true, players = { player(7, AHEAD) } }))
			expect(rest.mind.mode).to.equal("rest")
			expect(rest.mind.target).to.equal(nil)
			expect(rest.cue).to.equal("resting")
			expect(rest.intent.kind).to.equal("goTo")
			expect(rest.intent.position).to.equal(REST)
			expect(rest.intent.run).to.equal(false)
		end)

		it("waits at the rest point and ignores noises", function()
			local rest = OccupantBrainRules.step(fresh(), senses({ resting = true }))
			local waiting = OccupantBrainRules.step(
				rest.mind,
				senses({ resting = true, position = Vector3.new(200, 3, 201), heard = Vector3.new(190, 0, 190) })
			)
			expect(waiting.mind.mode).to.equal("rest")
			expect(waiting.intent.kind).to.equal("idle")
			expect(waiting.cue).to.equal(nil)
		end)

		it("goes back to his route when the break ends", function()
			local rest = OccupantBrainRules.step(fresh(), senses({ resting = true }))
			local back = OccupantBrainRules.step(rest.mind, senses({ now = 140 }))
			expect(back.mind.mode).to.equal("patrol")
			expect(back.intent.kind).to.equal("goTo")
		end)
	end)

	describe("lookYaw", function()
		it("sweeps from straight ahead within the look sweep", function()
			expect(OccupantBrainRules.lookYaw(0)).to.equal(0)
			local limit = math.rad(OccupantConstants.LOOK_SWEEP) + 1e-6
			for index = 0, 80 do
				expect(math.abs(OccupantBrainRules.lookYaw(index * 0.1)) <= limit).to.equal(true)
			end
		end)
	end)
end
