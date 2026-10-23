local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- The truck's box (the safe zone), a three-point route and the break room's rest point.
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
	describe("airborne grab", function()
		it("attacks a visible jumping victim whose feet remain reachable", function()
			local result = OccupantBrainRules.step(
				fresh(),
				senses({
					players = { { userId = 7, position = Vector3.new(62, 9, 60), feetY = 6, clear = true } },
					reachTopY = 6,
				})
			)
			expect(result.intent.kind).to.equal("attack")
			expect(result.intent.verticalReach).to.equal(8)
		end)
		it("keeps the sight radius three dimensional even with a horizontal cone", function()
			local seen = OccupantBrainRules.visible(
				fresh(),
				senses({
					players = { player(7, Vector3.new(62, 103, 60)) },
					sightRange = 40,
				})
			)
			expect(#seen).to.equal(0)
		end)
		it("does not grab a player above a genuinely separate ledge", function()
			local result = OccupantBrainRules.step(
				fresh(),
				senses({
					players = { { userId = 7, position = Vector3.new(62, 15, 60), feetY = 12, clear = true } },
					reachTopY = 6,
				})
			)
			expect(result.intent.kind).to.equal("goTo")
		end)
	end)

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

		it("turns to a newer noise in front of him without a second cue", function()
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = NOISE }))
			-- In his front cone (a newer one beside or behind him is the head turn: OccupantAlertRules.spec).
			local other = Vector3.new(90, 0, 70)
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

		it("searches the last place he saw them, then gives up without nearby route probes", function()
			local seenAt = Vector3.new(90, 3, 60)
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, seenAt) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101, route = {} }))
			expect(lost.mind.mode).to.equal("search")
			expect(lost.mind.target).to.equal(7)
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

		it("never spots a player standing in the yard, and ignores a noise there", function()
			local yard = { min = AHEAD - Vector3.new(5, 5, 5), max = AHEAD + Vector3.new(5, 5, 5) }
			local zone = { min = ZONE.min, max = ZONE.max, more = { yard } }
			local control = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			expect(control.mind.mode).to.equal("chase")
			local step = OccupantBrainRules.step(fresh(), senses({ zone = zone, players = { player(7, AHEAD) } }))
			expect(step.mind.mode).to.equal("patrol")
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = Vector3.new(82, 0, 60) }))
			expect(heard.mind.mode).to.equal("investigate")
			local noisy = OccupantBrainRules.step(fresh(), senses({ zone = zone, heard = Vector3.new(82, 0, 60) }))
			expect(noisy.mind.mode).to.equal("patrol")
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

	describe("persistent pursuit", function()
		it("keeps a visible known target outside the patrol cone while requiring sight", function()
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local behind = Vector3.new(50, 3, 60)
			local kept = OccupantBrainRules.step(chase.mind, senses({ now = 101, players = { player(7, behind) } }))
			expect(kept.mind.mode).to.equal("chase")
			expect(kept.mind.lastSeen).to.equal(behind)
			local hidden = OccupantBrainRules.step(
				kept.mind,
				senses({ now = 102, players = { player(7, Vector3.new(40, 3, 70), false) } })
			)
			expect(hidden.mind.mode).to.equal("search")
			expect(hidden.intent.position).to.equal(behind)
		end)

		it("follows successive visible runner samples and freezes memory after a wall", function()
			local mind = fresh()
			local last = AHEAD
			for tick = 1, 12 do
				last = AHEAD + Vector3.new(tick * 2, 0, 0)
				local result =
					OccupantBrainRules.step(mind, senses({ now = 100 + tick * 0.25, players = { player(7, last) } }))
				expect(result.mind.mode).to.equal("chase")
				expect(result.intent.position).to.equal(last)
				mind = result.mind
			end
			for tick = 1, 4 do
				local result = OccupantBrainRules.step(
					mind,
					senses({ now = 103 + tick * 0.25, players = { player(7, Vector3.new(300 + tick, 3, 300), false) } })
				)
				expect(result.mind.mode).to.equal("search")
				expect(result.mind.lastSeen).to.equal(last)
				expect(result.intent.position).to.equal(last)
				mind = result.mind
			end
		end)

		it("checks nearby authored route points instead of instantly relaxing at a corner", function()
			local route = { AHEAD + Vector3.new(12, 0, 0), AHEAD + Vector3.new(12, 0, 12), Vector3.new(300, 3, 300) }
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101, route = route }))
			local arrived = OccupantBrainRules.step(lost.mind, senses({ now = 102, position = AHEAD }))
			local probe = OccupantBrainRules.step(
				arrived.mind,
				senses({ now = 102 + OccupantConstants.SEARCH_SECONDS, position = AHEAD })
			)
			expect(probe.mind.mode).to.equal("search")
			expect(probe.intent.kind).to.equal("goTo")
			expect(probe.intent.run).to.equal(true)
			expect(probe.intent.position).to.equal(route[1])
			expect(lost.mind.searchIndex).to.equal(1)
		end)

		it("keeps a search urgent when hearing noise without tracking the hidden player", function()
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101 }))
			local noise = Vector3.new(88, 3, 80)
			local heard = OccupantBrainRules.step(
				lost.mind,
				senses({ now = 103, heard = noise, players = { player(7, Vector3.new(120, 3, 120), false) } })
			)
			expect(heard.mind.mode).to.equal("search")
			-- A quick head snap to it first (SEARCH_SNAP), then the run.
			expect(heard.intent.kind).to.equal("idle")
			expect(heard.mind.point).to.equal(noise)
			local running = OccupantBrainRules.step(
				heard.mind,
				senses({
					now = 103 + OccupantConstants.SEARCH_SNAP + 0.01,
					players = { player(7, Vector3.new(120, 3, 120), false) },
				})
			)
			expect(running.intent.position).to.equal(noise)
			expect(running.intent.run).to.equal(true)
			expect(heard.mind.lastSeen).to.equal(AHEAD)
			expect(heard.mind.since).to.equal(101)
		end)

		it("bounds the search even with repeated noises and never probes the safe bay", function()
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, AHEAD) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101, route = { Vector3.new(35, 3, 20) } }))
			for _, point in lost.mind.searchPoints do
				expect(OccupantBrainRules.inZone(point, ZONE)).to.equal(false)
			end
			local done = OccupantBrainRules.step(
				lost.mind,
				senses({ now = 101 + OccupantConstants.SEARCH_MAX_SECONDS, heard = AHEAD + Vector3.new(1, 0, 0) })
			)
			expect(done.mind.mode).to.equal("patrol")
			expect(done.mind.target).to.equal(nil)
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

	describe("the loading bay (only the truck's box is safe)", function()
		-- The bay around the box; a route whose second point is in the bay.
		local BAY = { min = Vector3.new(-20, -5, -20), max = Vector3.new(70, 20, 50) }
		local BAY_ROUTE = { Vector3.new(100, 0, 100), Vector3.new(55, 0, 40), Vector3.new(150, 0, 150) }
		local IN_BAY = Vector3.new(55, 3, 40)

		local function bay(extra)
			local value = senses({ bay = BAY, route = BAY_ROUTE, position = IN_BAY, look = Vector3.new(-1, 0, 0) })
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("sees and chases a player in the bay outside the box", function()
			local step = OccupantBrainRules.step(fresh(), bay({ players = { player(7, Vector3.new(45, 3, 40)) } }))
			expect(step.mind.mode).to.equal("chase")
		end)

		it("follows a noise in the bay, but never one inside the box", function()
			local bayNoise = OccupantBrainRules.step(fresh(), bay({ heard = Vector3.new(50, 0, 45) }))
			expect(bayNoise.mind.mode).to.equal("investigate")
			local boxNoise = OccupantBrainRules.step(fresh(), bay({ heard = Vector3.new(20, 0, 15) }))
			expect(boxNoise.mind.mode).to.equal("patrol")
		end)

		it("leaves after BAY_LINGER_SECONDS with nobody in sight, for a route point outside the bay", function()
			local first = OccupantBrainRules.step(fresh(), bay({ heard = Vector3.new(50, 0, 45) }))
			expect(first.mind.bayAt).to.equal(100)
			local later = OccupantBrainRules.step(first.mind, bay({ now = 100 + OccupantConstants.BAY_LINGER_SECONDS }))
			expect(later.mind.mode).to.equal("patrol")
			expect(later.cue).to.equal("giveUp")
			expect(later.intent.kind).to.equal("goTo")
			expect(OccupantBrainRules.inZone(later.intent.position, BAY)).to.equal(false)
			expect(later.mind.bayBarredUntil).to.equal(
				100 + OccupantConstants.BAY_LINGER_SECONDS + OccupantConstants.BAY_COOLDOWN_SECONDS
			)
		end)

		it("ignores bay noises and skips bay route points while barred", function()
			local mind = fresh()
			mind.bayBarredUntil = 130
			mind.routeIndex = 1
			local outside = Vector3.new(100, 3, 100)
			local heard = OccupantBrainRules.step(mind, bay({ position = outside, heard = Vector3.new(50, 0, 45) }))
			expect(heard.mind.mode).to.equal("patrol")
			-- Reaching point 1, the next is point 2 in the bay: skipped for point 3.
			expect(heard.intent.position).to.equal(BAY_ROUTE[3])
			local free = OccupantBrainRules.step(mind, bay({ position = outside, now = 131 }))
			expect(free.intent.position).to.equal(BAY_ROUTE[2])
		end)

		it("keeps chasing a player he sees in the bay past the linger time", function()
			local mind = fresh()
			mind.bayAt = 50
			local step = OccupantBrainRules.step(mind, bay({ players = { player(7, Vector3.new(45, 3, 40)) } }))
			expect(step.mind.mode).to.equal("chase")
		end)

		it("forgets when he entered the bay once he is out of it", function()
			local mind = fresh()
			mind.bayAt = 90
			local step = OccupantBrainRules.step(mind, bay({ position = Vector3.new(100, 3, 100) }))
			expect(step.mind.bayAt).to.equal(nil)
		end)
	end)

	describe("hiding players", function()
		it("never sees a hidden player he did not see go in", function()
			local seen = OccupantBrainRules.visible(
				fresh(),
				senses({ players = { { userId = 7, position = AHEAD, clear = true, hidden = true } } })
			)
			expect(#seen).to.equal(0)
		end)

		it("witnesses a player going in only when he sees them right then; never on his break", function()
			local seenNow = senses({ players = { player(7, AHEAD) } })
			expect(OccupantBrainRules.witnessed(fresh(), seenNow, 7)).to.equal(true)
			expect(OccupantBrainRules.witnessed(fresh(), senses({ players = { player(7, AHEAD, false) } }), 7)).to.equal(
				false
			)
			-- A chase alone is not enough: break his line of sight first and he did not see where you went.
			local chasing = fresh()
			chasing.mode = "chase"
			chasing.target = 7
			expect(OccupantBrainRules.witnessed(chasing, senses(), 7)).to.equal(false)
			expect(OccupantBrainRules.witnessed(chasing, senses({ players = { player(7, AHEAD, false) } }), 7)).to.equal(
				false
			)
			-- Far down a clear line, in his narrow long cone, he sees you go in too (from far: only a suspicion later).
			local far = senses({
				longRange = OccupantConstants.LONG_SIGHT_RANGE,
				longAngle = OccupantConstants.LONG_SIGHT_ANGLE,
				players = { player(7, Vector3.new(170, 3, 60)) },
			})
			expect(OccupantBrainRules.witnessed(fresh(), far, 7)).to.equal(true)
			expect(OccupantBrainRules.witnessed(fresh(), senses({ resting = true, players = { player(7, AHEAD) } }), 7)).to.equal(
				false
			)
		end)

		it("never chases a player he saw go in: he stares the spot down instead", function()
			local step = OccupantBrainRules.step(
				fresh(),
				senses({
					players = { { userId = 7, position = AHEAD, clear = false, hidden = true, seen = true } },
					spots = { { id = "s1", center = AHEAD, stand = AHEAD - Vector3.new(3, 3, 0) } },
					hiders = { { userId = 7, spotId = "s1", seen = true } },
				})
			)
			expect(step.mind.mode).to.equal("stare")
			expect(step.mind.quarry).to.equal(7)
		end)
	end)

	describe("settleBody", function()
		it("stands him up off the chair before he moves, faster into a chase", function()
			local mind = fresh()
			mind.mode = "chase"
			mind.seated = true
			local step = OccupantBrainRules.settleBody(
				{ mind = mind, intent = { kind = "goTo", position = Vector3.zero, run = true } },
				10
			)
			expect(step.mind.seated).to.equal(false)
			expect(step.intent.kind).to.equal("idle")
			expect(step.effects[1].kind).to.equal("stand")
			expect(step.effects[1].speed).to.equal(OccupantConstants.AMBUSH_STAND_SPEED)
			expect(step.mind.standUntil).to.equal(
				10 + OccupantConstants.STAND_SECONDS / OccupantConstants.AMBUSH_STAND_SPEED
			)
		end)
		it("keeps him seated while he types, and through a catch", function()
			local mind = fresh()
			mind.mode = "work"
			mind.phase = "type"
			mind.seated = true
			expect(OccupantBrainRules.settleBody({ mind = mind, intent = { kind = "idle" } }, 0).effects).to.equal(nil)
			mind.mode = "catch"
			mind.phase = nil
			expect(OccupantBrainRules.settleBody({ mind = mind, intent = { kind = "idle" } }, 0).effects).to.equal(nil)
		end)
		it("lets him go from a spot once he walks on", function()
			local mind = fresh()
			mind.planted = true
			local step = OccupantBrainRules.settleBody({ mind = mind, intent = { kind = "idle" } }, 0)
			expect(step.mind.planted).to.equal(false)
			expect(step.effects[1].kind).to.equal("release")
		end)
	end)

	describe("the stare-down", function()
		local CENTER = Vector3.new(80, 1.5, 60)
		local STAND = Vector3.new(76.4, 0, 60)
		local AT_STAND = Vector3.new(76.4, 4.6, 60)
		local SPOT = { id = "s1", center = CENTER, stand = STAND }
		local HIDER = { userId = 7, spotId = "s1", seen = true }
		local HIDDEN =
			{ userId = 7, position = CENTER + Vector3.new(0, 3, 0), clear = false, hidden = true, seen = true }

		local function stare(extra)
			local value = senses({ players = { HIDDEN }, spots = { SPOT }, hiders = { HIDER } })
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

		-- Walked to the spot and planted, staring for the rolled time (roll 0: the shortest).
		local function planted()
			local walking = OccupantBrainRules.step(fresh(), stare())
			return OccupantBrainRules.step(walking.mind, stare({ now = 101, position = AT_STAND, rolls = { 0 } }))
		end

		it("walks to the spot's front, then plants there facing it, holding the camping push-out", function()
			local walking = OccupantBrainRules.step(fresh(), stare())
			expect(walking.mind.phase).to.equal("approach")
			expect(walking.intent.position).to.equal(STAND)
			local step = planted()
			expect(step.mind.phase).to.equal("hold")
			expect(step.mind.hold).to.equal(OccupantConstants.STARE_SECONDS.min)
			expect(step.mind.planted).to.equal(true)
			expect(kinds(step)).to.equal("plant,holdCamp")
			expect(step.intent.kind).to.equal("idle")
		end)

		it("stands perfectly still for the stare", function()
			local step = planted()
			local still = OccupantBrainRules.step(
				step.mind,
				stare({ now = 101 + OccupantConstants.STARE_SECONDS.min - 0.1, position = AT_STAND })
			)
			expect(still.mind.phase).to.equal("hold")
			expect(still.intent.kind).to.equal("idle")
		end)

		it("ends in a check (bend down, then the catch) on a low roll", function()
			local step = planted()
			local check = OccupantBrainRules.step(
				step.mind,
				stare({ now = 101 + OccupantConstants.STARE_SECONDS.min, position = AT_STAND, rolls = { 0.5, 0 } })
			)
			expect(check.mind.phase).to.equal("check")
			expect(kinds(check)).to.equal("seen,holdCamp")
			local catch = OccupantBrainRules.step(
				check.mind,
				stare({
					now = 101 + OccupantConstants.STARE_SECONDS.min + OccupantConstants.CHECK_SECONDS + 0.01,
					position = AT_STAND,
				})
			)
			expect(kinds(catch)).to.equal("catch,seen,release")
			expect(catch.effects[1].userId).to.equal(7)
			-- A catch the server refuses must not loop him back into another stare at the same spot.
			expect(catch.effects[2].seen).to.equal(false)
			expect(catch.mind.cleared.s1).to.be.ok()
		end)

		it("gives up a stand point he cannot reach: forgets the hider and leaves the spot alone", function()
			local walking = OccupantBrainRules.step(fresh(), stare())
			local stuck = OccupantBrainRules.step(
				walking.mind,
				stare({ now = 100 + OccupantConstants.GIVE_UP_SECONDS, position = Vector3.new(60, 3, 70) })
			)
			expect(stuck.mind.mode).to.equal("patrol")
			expect(kinds(stuck)).to.equal("seen")
			expect(stuck.effects[1].seen).to.equal(false)
			expect(stuck.mind.cleared.s1).to.be.ok()
		end)

		it("ends with him walking away on a high roll, forgetting the hider", function()
			local step = planted()
			local leave = OccupantBrainRules.step(
				step.mind,
				stare({
					now = 101 + OccupantConstants.STARE_SECONDS.min,
					position = AT_STAND,
					rolls = { 0.5, 0.99, 0.99 },
				})
			)
			expect(leave.mind.mode).to.equal("patrol")
			expect(kinds(leave)).to.equal("seen,release")
			expect(leave.effects[1].seen).to.equal(false)
			expect(leave.mind.cleared.s1).to.be.ok()
		end)

		it("always checks after a noise near the spot during the stare", function()
			local step = planted()
			local heard = OccupantBrainRules.step(
				step.mind,
				stare({ now = 102, position = AT_STAND, heard = CENTER + Vector3.new(2, 0, 0) })
			)
			expect(heard.mind.noisy).to.equal(true)
			local check = OccupantBrainRules.step(
				heard.mind,
				stare({ now = 101 + OccupantConstants.STARE_SECONDS.min, position = AT_STAND, rolls = { 0.5, 0.99 } })
			)
			expect(check.mind.phase).to.equal("check")
		end)

		it("sometimes sits down at that very desk instead of leaving", function()
			local desk = {
				id = "d1",
				seat = CFrame.lookAt(Vector3.new(76.95, 4.6, 60), Vector3.new(80, 4.6, 60)),
				front = true,
				spotId = "s1",
			}
			local spot = { id = "s1", center = CENTER, stand = STAND, deskId = "d1" }
			local walking = OccupantBrainRules.step(fresh(), stare({ spots = { spot }, desks = { desk } }))
			local step = OccupantBrainRules.step(
				walking.mind,
				stare({ now = 101, position = AT_STAND, spots = { spot }, desks = { desk }, rolls = { 0 } })
			)
			local sits = OccupantBrainRules.step(
				step.mind,
				stare({
					now = 101 + OccupantConstants.STARE_SECONDS.min,
					position = AT_STAND,
					spots = { spot },
					desks = { desk },
					rolls = { 0.5, 0.99, 0 },
				})
			)
			expect(sits.mind.mode).to.equal("work")
			expect(sits.mind.sitIn).to.equal(true)
			expect(sits.mind.quarry).to.equal(7)
			expect(sits.mind.sitIns).to.equal(1)
			expect(kinds(sits)).to.equal("release")
		end)

		it("is startled by a hider who bolts, then chases them", function()
			local step = planted()
			local out = { userId = 7, position = AT_STAND + Vector3.new(4, 0, 0), clear = true }
			local bolt = OccupantBrainRules.step(
				step.mind,
				stare({ now = 103, position = AT_STAND, players = { out }, hiders = {} })
			)
			expect(bolt.mind.mode).to.equal("chase")
			expect(bolt.mind.target).to.equal(7)
			expect(bolt.intent.kind).to.equal("idle")
			expect(bolt.mind.reactUntil).to.equal(103 + OccupantConstants.STARTLE_SECONDS)
			expect(kinds(bolt)).to.equal("release")
			local after = OccupantBrainRules.step(
				bolt.mind,
				stare({
					now = 103 + OccupantConstants.STARTLE_SECONDS,
					position = AT_STAND,
					players = { out },
					hiders = {},
				})
			)
			expect(after.intent.kind).never.to.equal("idle")
		end)

		it("stares a moment at a hiding spot by a noise he walked up to (a suspicion stare)", function()
			local noise = Vector3.new(90, 0, 60)
			local heard = OccupantBrainRules.step(fresh(), senses({ heard = noise, spots = { SPOT } }))
			local arrived = OccupantBrainRules.step(
				heard.mind,
				senses({ now = 101, position = Vector3.new(90, 3, 61), spots = { SPOT } })
			)
			expect(arrived.mind.mode).to.equal("stare")
			expect(arrived.mind.quarry).to.equal(nil)
			local planted_ = OccupantBrainRules.step(
				arrived.mind,
				senses({ now = 102, position = AT_STAND, spots = { SPOT }, rolls = { 1 } })
			)
			expect(planted_.mind.hold).to.equal(OccupantConstants.SUSPECT_SECONDS.max)
		end)
	end)
	describe("long sight", function()
		local FAR = Vector3.new(170, 3, 60)
		local function long(extra)
			local value = senses({
				longRange = OccupantConstants.LONG_SIGHT_RANGE,
				longAngle = OccupantConstants.LONG_SIGHT_ANGLE,
			})
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("needs a beat to notice someone far down a clear line: he stops and turns his head to them", function()
			local step = OccupantBrainRules.step(fresh(), long({ players = { player(7, FAR) } }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.noticeId).to.equal(7)
			expect(step.intent.kind).to.equal("idle")
			expect(step.mind.point).to.equal(FAR)
			expect(step.mind.swivelUntil > 100).to.equal(true)
		end)

		it("chases once the notice delay for the distance has passed", function()
			local mind = fresh()
			local now = 100
			local result
			repeat
				result = OccupantBrainRules.step(mind, long({ now = now, players = { player(7, FAR) } }))
				mind = result.mind
				now += 0.25
			until result.mind.mode == "chase" or now > 104
			expect(result.mind.mode).to.equal("chase")
			expect(result.cue).to.equal("spotted")
			-- 110 studs away: most of the way to the slowest notice.
			expect(now - 100 >= OccupantConstants.NOTICE_SECONDS.min + 0.5).to.equal(true)
			expect(now - 100 <= OccupantConstants.NOTICE_SECONDS.max + 0.5).to.equal(true)
		end)

		it("sees at once within his near sight, as before", function()
			local step = OccupantBrainRules.step(fresh(), long({ players = { player(7, AHEAD) } }))
			expect(step.mind.mode).to.equal("chase")
		end)

		it("never notices far off to the side, behind a wall, or past his long range", function()
			for _, glimpse in
				{
					player(7, Vector3.new(150, 3, 120)),
					player(7, FAR, false),
					player(7, Vector3.new(60 + OccupantConstants.LONG_SIGHT_RANGE + 5, 3, 60)),
				}
			do
				local step = OccupantBrainRules.step(fresh(), long({ players = { glimpse } }))
				expect(step.mind.mode).to.equal("patrol")
				expect(step.mind.noticeId).to.equal(nil)
			end
		end)

		it("lets a noticing fade once the line is broken, and walks on", function()
			local first = OccupantBrainRules.step(fresh(), long({ players = { player(7, FAR) } }))
			local second = OccupantBrainRules.step(first.mind, long({ now = 100.5, players = { player(7, FAR) } }))
			expect(second.mind.noticeSeconds).to.be.near(0.5)
			local lost =
				OccupantBrainRules.step(second.mind, long({ now = 100.75, players = { player(7, FAR, false) } }))
			expect(lost.mind.mode).to.equal("patrol")
			expect(lost.intent.kind).to.equal("goTo")
			expect(lost.mind.noticeSeconds).to.be.near(0)
		end)

		it("keeps his chase target in sight far down a straight line, in his long cone", function()
			local chase = OccupantBrainRules.step(fresh(), long({ players = { player(7, AHEAD) } }))
			local kept = OccupantBrainRules.step(chase.mind, long({ now = 101, players = { player(7, FAR) } }))
			expect(kept.mind.mode).to.equal("chase")
			expect(kept.mind.lastSeen).to.equal(FAR)
		end)
	end)

	describe("hiding during a chase", function()
		local CENTER = Vector3.new(80, 1.5, 60)
		local STAND = Vector3.new(76.4, 0, 60)
		local AT_STAND = Vector3.new(76.4, 4.6, 60)
		local SPOT = { id = "s1", center = CENTER, stand = STAND }

		local function kinds(step)
			local list = {}
			for _, effect in step.effects or {} do
				table.insert(list, effect.kind)
			end
			return table.concat(list, ",")
		end

		it("searching where he lost them, he stares a moment at a spot there on a hunch", function()
			local seenAt = Vector3.new(84, 3, 60)
			local chase = OccupantBrainRules.step(fresh(), senses({ players = { player(7, seenAt) } }))
			local lost = OccupantBrainRules.step(chase.mind, senses({ now = 101, spots = { SPOT } }))
			expect(lost.mind.mode).to.equal("search")
			local arrived = OccupantBrainRules.step(
				lost.mind,
				senses({ now = 102, position = Vector3.new(84, 3, 61), spots = { SPOT } })
			)
			expect(arrived.mind.mode).to.equal("stare")
			expect(arrived.mind.quarry).to.equal(nil)
			expect(arrived.mind.hunch).to.equal(true)
		end)

		it("a hunch looks only on a low roll, even with someone under there", function()
			local hidden = { userId = 7, position = CENTER, clear = false, hidden = true, seen = false }
			local mind = fresh()
			mind.mode = "stare"
			mind.phase = "hold"
			mind.phaseAt = 100
			mind.hold = 2
			mind.spot = SPOT
			mind.hunch = true
			mind.planted = true
			local hiders = { { userId = 7, spotId = "s1", seen = false } }
			local function decide(roll)
				return OccupantBrainRules.step(
					mind,
					senses({
						now = 102,
						position = AT_STAND,
						players = { hidden },
						spots = { SPOT },
						hiders = hiders,
						rolls = { 0.5, roll, 0.99 },
					})
				)
			end
			expect(decide(OccupantConstants.HUNCH_CHECK - 0.01).mind.phase).to.equal("check")
			expect(decide(OccupantConstants.HUNCH_CHECK + 0.01).mind.mode).to.equal("patrol")
		end)

		it("watched you crawl in from far off: only a short suspicion stare", function()
			local far = Vector3.new(60 + OccupantConstants.CHECK_FAR + 5, 1.5, 60)
			local spot = { id = "s2", center = far, stand = far - Vector3.new(3.6, 1.5, 0) }
			local hidden = { userId = 7, position = far, clear = false, hidden = true, seen = true }
			local hiders = { { userId = 7, spotId = "s2", seen = true } }
			local walking =
				OccupantBrainRules.step(fresh(), senses({ players = { hidden }, spots = { spot }, hiders = hiders }))
			expect(walking.mind.entered[7] >= OccupantConstants.CHECK_FAR).to.equal(true)
			local planted = OccupantBrainRules.step(
				walking.mind,
				senses({
					now = 105,
					position = spot.stand + Vector3.new(0, 4.6, 0),
					players = { hidden },
					spots = { spot },
					hiders = hiders,
					rolls = { 1 },
				})
			)
			expect(planted.mind.hold).to.equal(OccupantConstants.SUSPECT_SECONDS.max)
		end)

		it("plants near a stand point the path cannot quite reach instead of circling it", function()
			local hidden = { userId = 7, position = CENTER, clear = false, hidden = true, seen = true }
			local hiders = { { userId = 7, spotId = "s1", seen = true } }
			local near = STAND + Vector3.new(-4.5, 4.6, 0)
			local walking =
				OccupantBrainRules.step(fresh(), senses({ players = { hidden }, spots = { SPOT }, hiders = hiders }))
			local close = OccupantBrainRules.step(
				walking.mind,
				senses({ now = 101, position = near, players = { hidden }, spots = { SPOT }, hiders = hiders })
			)
			expect(close.mind.phase).to.equal("approach")
			local settled = OccupantBrainRules.step(
				close.mind,
				senses({
					now = 101 + OccupantConstants.STAND_SETTLE + 0.01,
					position = near,
					players = { hidden },
					spots = { SPOT },
					hiders = hiders,
				})
			)
			expect(settled.mind.phase).to.equal("hold")
			expect(kinds(settled)).to.equal("plant,holdCamp")
		end)
	end)

	describe("a secure supply cabinet", function()
		local function cabinet(at)
			return { id = "c1", center = at, stand = at - Vector3.new(3.6, 1.5, 0), secure = true }
		end
		local function kinds(step)
			local list = {}
			for _, effect in step.effects or {} do
				table.insert(list, effect.kind)
			end
			return table.concat(list, ",")
		end
		local function staredAt(spot, rolls)
			local hidden = { userId = 7, position = spot.center, clear = false, hidden = true, seen = true }
			local hiders = { { userId = 7, spotId = "c1", seen = true } }
			local function at(now, extra)
				local value = senses({
					now = now,
					position = spot.stand + Vector3.new(0, 4.6, 0),
					players = { hidden },
					spots = { spot },
					hiders = hiders,
					rolls = rolls,
				})
				for key, item in extra or {} do
					value[key] = item
				end
				return value
			end
			local walking = OccupantBrainRules.step(fresh(), at(100, { position = Vector3.new(60, 3, 60) }))
			local planted = OccupantBrainRules.step(walking.mind, at(101))
			return OccupantBrainRules.step(planted.mind, at(101 + planted.mind.hold)), at
		end

		it("he opens it (slow and telegraphed) when he watched you get in up close, then catches you", function()
			local spot = cabinet(Vector3.new(70, 1.5, 60))
			local opening, at = staredAt(spot, { 0, 0, 0.99 })
			expect(opening.mind.phase).to.equal("open")
			expect(kinds(opening)).to.equal("seen,holdCamp,door")
			local mid =
				OccupantBrainRules.step(opening.mind, at(opening.mind.phaseAt + OccupantConstants.OPEN_SECONDS - 0.1))
			expect(mid.mind.phase).to.equal("open")
			local caught =
				OccupantBrainRules.step(opening.mind, at(opening.mind.phaseAt + OccupantConstants.OPEN_SECONDS))
			expect(kinds(caught)).to.equal("catch,seen,door,release")
		end)

		it("shuts the door again if the hider bolts while it swings open", function()
			local spot = cabinet(Vector3.new(70, 1.5, 60))
			local opening, at = staredAt(spot, { 0, 0, 0.99 })
			local out = { userId = 7, position = spot.stand + Vector3.new(2, 4.6, 1.5), clear = true }
			local bolt = OccupantBrainRules.step(
				opening.mind,
				at(opening.mind.phaseAt + 0.5, { players = { out }, hiders = {} })
			)
			expect(bolt.mind.mode).to.equal("chase")
			local door = nil
			for _, effect in bolt.effects or {} do
				if effect.kind == "door" then
					door = effect
				end
			end
			expect(door).to.be.ok()
			expect(door.spotId).to.equal("c1")
			expect(door.open).to.equal(false)
		end)

		it("shuts the door again if the shift's break starts while it swings open", function()
			local spot = cabinet(Vector3.new(70, 1.5, 60))
			local opening, at = staredAt(spot, { 0, 0, 0.99 })
			local rest = OccupantBrainRules.step(opening.mind, at(opening.mind.phaseAt + 0.5, { resting = true }))
			expect(rest.mind.mode).to.equal("rest")
			expect(kinds(rest)).to.equal("door,release")
		end)

		it(
			"he never looks in casually: from further than OPEN_RADIUS he stares and walks on, whatever the roll",
			function()
				local spot = cabinet(Vector3.new(60 + OccupantConstants.OPEN_RADIUS + 6, 1.5, 60))
				local leave = staredAt(spot, { 0, 0, 0 })
				expect(leave.mind.mode).to.equal("patrol")
			end
		)
	end)
end
