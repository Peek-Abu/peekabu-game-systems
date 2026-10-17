local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAlertRules = require(script.Parent.OccupantAlertRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantTurnRules = require(script.Parent.OccupantTurnRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }

-- The rolls: 1-4 at 0.5, then the stare's (5) and the knowing turn's (6).
local KNOWING = { 0.5, 0.5, 0.5, 0, 1, 0 }
local STARE = { 0.5, 0.5, 0.5, 0, 0, 1 }

-- Him at (60, 3, 60) looking along +X, at os.clock `now`.
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
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function player(userId, position, extra)
	local value = { userId = userId, position = position, clear = true }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

-- 12 studs straight to his left: certain (within CERTAIN_RANGE), outside his front cone.
local BESIDE = Vector3.new(60, 3, 72)
-- Behind him, 10 studs.
local BEHIND = Vector3.new(50, 3, 60)
-- 30 studs to his left: too far to be certain without having seen them.
local FAR_SIDE = Vector3.new(60, 3, 90)

local function fresh(menace)
	local mind = OccupantBrainRules.newMind(1, 1, 0)
	mind.menace = menace or 40
	return mind
end

-- The slow turn begun at now 100 on player 7 beside him (`rolls`: KNOWING or STARE).
local function slow(rolls, menace)
	return OccupantAlertRules.begin(
		fresh(menace),
		senses({ rolls = rolls, players = { player(7, BESIDE) } }),
		BESIDE,
		7
	)
end

-- One think at `now` with `players`.
local function at(mind, now, players, extra)
	local value = { now = now, players = players }
	for key, item in extra or {} do
		value[key] = item
	end
	return OccupantBrainRules.step(mind, senses(value))
end

return function()
	describe("pick", function()
		it("is the snap without a target, or with one he is not certain of", function()
			expect(OccupantTurnRules.pick(fresh(), senses({ rolls = KNOWING }), nil)).to.equal("snap")
			local far = player(7, FAR_SIDE)
			expect(OccupantTurnRules.pick(fresh(), senses({ rolls = KNOWING, players = { far } }), far)).to.equal(
				"snap"
			)
		end)

		it("is certain of someone within CERTAIN_RANGE, or someone he saw a moment ago", function()
			local mind = fresh()
			expect(OccupantTurnRules.certain(mind, senses(), player(7, BESIDE))).to.equal(true)
			expect(OccupantTurnRules.certain(mind, senses(), player(7, FAR_SIDE))).to.equal(false)
			mind.watched = { [7] = C.CERTAIN_WATCHED }
			expect(OccupantTurnRules.certain(mind, senses(), player(7, FAR_SIDE))).to.equal(true)
			expect(OccupantTurnRules.certain(mind, senses(), player(7, BESIDE, { hidden = true }))).to.equal(false)
			expect(OccupantTurnRules.certain(mind, senses(), player(7, BESIDE, { clear = false }))).to.equal(false)
		end)

		it("is the knowing turn on its roll, once per player a shift", function()
			local who = player(7, BESIDE)
			local s = senses({ rolls = KNOWING })
			expect(OccupantTurnRules.pick(fresh(), s, who)).to.equal("knowing")
			local again = fresh()
			again.knowingFor = { [7] = true }
			expect(OccupantTurnRules.pick(again, s, who)).to.equal("snap")
			expect(OccupantTurnRules.pick(again, s, player(8, BESIDE))).to.equal("knowing")
		end)

		it("is the snap at the default rolls", function()
			expect(OccupantTurnRules.pick(fresh(), senses(), player(7, BESIDE))).to.equal("snap")
		end)

		it("is the staring contest on its roll with menace in its band, once a shift for the crew", function()
			local who = player(7, BESIDE)
			local s = senses({ rolls = STARE })
			expect(OccupantTurnRules.pick(fresh(40), s, who)).to.equal("stare")
			expect(OccupantTurnRules.pick(fresh(C.STARE_MENACE.min - 1), s, who)).to.equal("snap")
			expect(OccupantTurnRules.pick(fresh(C.STARE_MENACE.max + 1), s, who)).to.equal("snap")
			local used = fresh(40)
			used.stared = true
			expect(OccupantTurnRules.pick(used, s, who)).to.equal("snap")
		end)

		it("gates the knowing turn on the menace gauge", function()
			local s = senses({ rolls = KNOWING })
			expect(OccupantTurnRules.pick(fresh(C.KNOWING_MENACE_MAX + 1), s, player(7, BESIDE))).to.equal("snap")
		end)

		it("never picks two slow turns in a row, nor within SLOW_GAP, nor on a breather", function()
			local who = player(7, BESIDE)
			local s = senses({ rolls = KNOWING })
			local afterSlow = fresh()
			afterSlow.lastTurn = "stare"
			expect(OccupantTurnRules.pick(afterSlow, s, who)).to.equal("snap")
			local soon = fresh()
			soon.lastTurn = "snap"
			soon.slowAt = 100 - C.SLOW_GAP + 1
			expect(OccupantTurnRules.pick(soon, s, who)).to.equal("snap")
			soon.slowAt = 100 - C.SLOW_GAP - 1
			expect(OccupantTurnRules.pick(soon, s, who)).to.equal("knowing")
			local breathing = fresh()
			breathing.breatherUntil = 500
			expect(OccupantTurnRules.pick(breathing, s, who)).to.equal("snap")
		end)

		it("is certain of a player who walks up close behind him with a clear line (the report, 2026-10-17)", function()
			local mind = fresh()
			local behind = player(7, BEHIND, { speed = 8 })
			expect(OccupantTurnRules.certain(mind, senses(), behind)).to.equal(true)
			expect(OccupantTurnRules.pick(mind, senses({ rolls = KNOWING }), behind)).to.equal("knowing")
		end)

		it("takes a developer's forced variant over every gate, given someone to turn to", function()
			local forced = fresh(0)
			forced.forceTurn = "stare"
			forced.stared = true
			expect(OccupantTurnRules.pick(forced, senses(), player(7, FAR_SIDE))).to.equal("stare")
			expect(OccupantTurnRules.pick(forced, senses(), nil)).to.equal("snap")
		end)
	end)

	describe("moved", function()
		it("counts walking speed or a drift from where they stood, never standing still", function()
			local anchor = Vector3.new(0, 3, 0)
			expect(OccupantTurnRules.moved(player(7, anchor, { speed = 0 }), anchor)).to.equal(false)
			expect(OccupantTurnRules.moved(player(7, anchor, { speed = C.STILL_SPEED }), anchor)).to.equal(true)
			local drifted = anchor + Vector3.new(C.STILL_DISTANCE, 0, 0)
			expect(OccupantTurnRules.moved(player(7, drifted, { speed = 0 }), anchor)).to.equal(true)
			local jumped = anchor + Vector3.new(0, C.STILL_DISTANCE + 0.1, 0)
			expect(OccupantTurnRules.moved(player(7, jumped), anchor)).to.equal(true)
			expect(OccupantTurnRules.moved(player(7, anchor + Vector3.new(0.3, 0, 0)), anchor)).to.equal(false)
		end)
	end)

	describe("the knowing turn", function()
		it("begins as a slow turn of his head to them, stopped dead, booked for the shift", function()
			local step = slow(KNOWING)
			local mind = step.mind
			expect(mind.mode).to.equal("alert")
			expect(mind.phase).to.equal("slowTurn")
			expect(mind.turn).to.equal("knowing")
			expect(mind.target).to.equal(7)
			expect(mind.point).to.equal(BESIDE)
			expect(mind.swivelUntil).to.equal(math.huge)
			expect(mind.lastTurn).to.equal("knowing")
			expect(mind.slowAt).to.equal(100)
			expect(mind.knowingFor[7]).to.equal(true)
			expect(step.intent.kind).to.equal("idle")
			expect(OccupantTurnRules.turning(mind)).to.equal(true)
		end)

		it("holds the whole turn while they stay still, then the jerk and the chase", function()
			local mind = slow(KNOWING).mind
			local still = { player(7, BESIDE, { speed = 0 }) }
			local turning = at(mind, 100 + C.SLOW_TURN_SECONDS - 0.05, still)
			expect(turning.mind.phase).to.equal("slowTurn")
			expect(turning.intent.kind).to.equal("idle")
			local jerk = at(turning.mind, 100 + C.SLOW_TURN_SECONDS + 0.01, still)
			expect(jerk.mind.mode).to.equal("chase")
			expect(jerk.mind.phase).to.equal("jerk")
			expect(jerk.mind.target).to.equal(7)
			expect(jerk.mind.point).to.equal(BESIDE)
			expect(jerk.intent.kind).to.equal("goTo")
			expect(jerk.intent.run).to.equal(true)
			expect(jerk.mind.reactUntil == nil or jerk.mind.reactUntil <= jerk.mind.phaseAt).to.equal(true)
			expect(jerk.cue).to.equal("spotted")
		end)

		it("jerks into the chase at once when they move mid-turn", function()
			local mind = slow(KNOWING).mind
			local settled = at(mind, 100.4, { player(7, BESIDE, { speed = 0 }) })
			expect(settled.mind.phase).to.equal("slowTurn")
			local moving = at(settled.mind, 101, { player(7, BESIDE, { speed = 12 }) })
			expect(moving.mind.mode).to.equal("chase")
			expect(moving.mind.phase).to.equal("jerk")
			expect(moving.intent.kind).to.equal("goTo")
		end)

		it("counts a drift as moving", function()
			local mind = slow(KNOWING).mind
			local settled = at(mind, 100.4, { player(7, BESIDE) })
			local drifted = at(settled.mind, 101, { player(7, BESIDE + Vector3.new(0, 0, 2)) })
			expect(drifted.mind.phase).to.equal("jerk")
		end)

		it("gives them SLOW_SETTLE to freeze at the creak", function()
			local mind = slow(KNOWING).mind
			local walking = at(mind, 100.1, { player(7, BESIDE + Vector3.new(1, 0, 0), { speed = 10 }) })
			expect(walking.mind.phase).to.equal("slowTurn")
			local frozen = at(walking.mind, 100 + C.SLOW_SETTLE - 0.05, { player(7, BESIDE + Vector3.new(2, 0, 0)) })
			expect(frozen.mind.phase).to.equal("slowTurn")
			local still = at(frozen.mind, 100.8, { player(7, BESIDE + Vector3.new(2, 0, 0), { speed = 0 }) })
			expect(still.mind.phase).to.equal("slowTurn")
		end)

		it("searches when they hide before the turn ends", function()
			local mind = slow(KNOWING).mind
			local hid = at(mind, 101, { player(7, BESIDE, { hidden = true }) })
			expect(hid.mind.mode).to.equal("search")
			expect(hid.mind.target).to.equal(7)
			expect(hid.mind.lastSeen).to.equal(BESIDE)
			expect(hid.intent.kind).to.equal("goTo")
			expect(hid.intent.run).to.equal(true)
		end)

		it("searches when they break the line", function()
			local mind = slow(KNOWING).mind
			local broke = at(mind, 101, { player(7, BESIDE, { clear = false }) })
			expect(broke.mind.mode).to.equal("search")
		end)

		it("ignores another crew member moving behind him while he turns", function()
			local mind = slow(KNOWING).mind
			local players = { player(7, BESIDE), player(8, BEHIND, { speed = 14 }) }
			local turning = at(mind, 101, players)
			expect(turning.mind.phase).to.equal("slowTurn")
			expect(turning.mind.target).to.equal(7)
		end)
	end)

	describe("the staring contest", function()
		local function staring()
			local mind = slow(STARE).mind
			local still = { player(7, BESIDE) }
			return at(mind, 100 + C.SLOW_TURN_SECONDS + 0.01, still, { rolls = STARE }).mind
		end

		it("stares after the turn, stock still, for a rolled 4-7 s", function()
			local mind = staring()
			expect(mind.mode).to.equal("alert")
			expect(mind.phase).to.equal("staring")
			expect(mind.hold).to.be.near(C.STARE_CONTEST_SECONDS.min)
			expect(mind.stared).to.equal(true)
			local still = at(mind, mind.phaseAt + C.STARE_CONTEST_SECONDS.min - 0.05, { player(7, BESIDE) })
			expect(still.mind.phase).to.equal("staring")
			expect(still.intent.kind).to.equal("idle")
		end)

		it("bolts the moment the target moves", function()
			local mind = staring()
			local moved = at(mind, mind.phaseAt + 1, { player(7, BESIDE, { speed = 8 }) })
			expect(moved.mind.mode).to.equal("chase")
			expect(moved.mind.phase).to.equal("jerk")
			expect(moved.mind.target).to.equal(7)
		end)

		it("bolts anyway when nobody moves for the whole stare", function()
			local mind = staring()
			local done = at(mind, mind.phaseAt + C.STARE_CONTEST_SECONDS.min + 0.01, { player(7, BESIDE) })
			expect(done.mind.mode).to.equal("chase")
			expect(done.mind.phase).to.equal("jerk")
			expect(done.mind.target).to.equal(7)
		end)

		it("searches when the target hides during the stare", function()
			local mind = staring()
			local hid = at(mind, mind.phaseAt + 1, { player(7, BESIDE, { hidden = true }) })
			expect(hid.mind.mode).to.equal("search")
		end)

		it("bolts at another crew member he sees move down his head's cone", function()
			local mind = staring()
			local other = Vector3.new(58, 3, 80)
			local seen = at(mind, mind.phaseAt + 0.5, { player(7, BESIDE), player(8, other) })
			expect(seen.mind.phase).to.equal("staring")
			local moved = at(seen.mind, mind.phaseAt + 1, { player(7, BESIDE), player(8, other, { speed = 9 }) })
			expect(moved.mind.mode).to.equal("chase")
			expect(moved.mind.target).to.equal(8)
		end)

		it("never bolts at someone moving where he cannot see them", function()
			local mind = staring()
			local players = { player(7, BESIDE), player(8, Vector3.new(60, 3, 40), { speed = 16 }) }
			local still = at(mind, mind.phaseAt + 1, players)
			expect(still.mind.phase).to.equal("staring")
			local walled = { player(7, BESIDE), player(8, Vector3.new(58, 3, 80), { speed = 16, clear = false }) }
			expect(at(mind, mind.phaseAt + 1, walled).mind.phase).to.equal("staring")
		end)
	end)

	describe("the jerk", function()
		it("is over after JERK_SECONDS: an ordinary chase", function()
			local mind = slow(KNOWING).mind
			local jerk = at(mind, 100 + C.SLOW_TURN_SECONDS + 0.01, { player(7, BESIDE) }).mind
			expect(jerk.swivelUntil).to.be.near(jerk.phaseAt + C.JERK_SECONDS)
			local during = at(jerk, jerk.phaseAt + C.JERK_SECONDS / 2, { player(7, BESIDE) })
			expect(during.mind.phase).to.equal("jerk")
			local after = at(during.mind, jerk.phaseAt + C.JERK_SECONDS + 0.01, { player(7, BESIDE) })
			expect(after.mind.mode).to.equal("chase")
			expect(after.mind.phase).to.equal(nil)
		end)
	end)

	describe("jerkYaw", function()
		it("snaps his body round the short way, eased out, done at JERK_SECONDS", function()
			local from, to = 0, math.rad(170)
			local start, startDone = OccupantTurnRules.jerkYaw(from, to, 0)
			expect(start).to.be.near(0)
			expect(startDone).to.equal(false)
			local half = OccupantTurnRules.jerkYaw(from, to, C.JERK_SECONDS / 2)
			expect(half > to / 2).to.equal(true)
			local finish, done = OccupantTurnRules.jerkYaw(from, to, C.JERK_SECONDS)
			expect(finish).to.be.near(to, 1e-6)
			expect(done).to.equal(true)
			local wrapped = OccupantTurnRules.jerkYaw(math.rad(170), math.rad(-170), C.JERK_SECONDS)
			expect(wrapped).to.be.near(math.rad(190), 1e-6)
		end)

		it("faces a direction the way CFrame.Angles does", function()
			local yaw = OccupantTurnRules.yawOf(Vector3.new(1, 0, 0))
			expect(CFrame.Angles(0, yaw, 0).LookVector:Dot(Vector3.new(1, 0, 0))).to.be.near(1, 1e-6)
		end)
	end)

	describe("the snap", function()
		it("is booked as the last turn, so the next slow one may follow it", function()
			local step = OccupantAlertRules.begin(fresh(), senses({ players = { player(7, BESIDE) } }), BESIDE, 7)
			expect(step.mind.phase).to.equal(nil)
			expect(step.mind.turn).to.equal("snap")
			expect(step.mind.lastTurn).to.equal("snap")
		end)

		it("picks the slow variant for a noise when someone certain stands down that way", function()
			local step = OccupantBrainRules.step(
				fresh(),
				senses({ heard = BESIDE, rolls = KNOWING, players = { player(7, BESIDE) } })
			)
			expect(step.mind.phase).to.equal("slowTurn")
			expect(step.mind.target).to.equal(7)
		end)
	end)

	describe("force", function()
		it("starts the forced variant at once at a player he can see", function()
			local mind = OccupantAlertRules.force(fresh(0), senses({ players = { player(7, FAR_SIDE) } }), "stare", 7)
			expect(mind.mode).to.equal("alert")
			expect(mind.phase).to.equal("slowTurn")
			expect(mind.turn).to.equal("stare")
			expect(mind.target).to.equal(7)
			expect(mind.forceTurn).to.equal(nil)
		end)

		it("arms it for his next head turn when he cannot see them", function()
			local mind = OccupantAlertRules.force(
				fresh(),
				senses({ players = { player(7, BESIDE, { clear = false }) } }),
				"knowing",
				7
			)
			expect(mind.mode).to.equal("patrol")
			expect(mind.forceTurn).to.equal("knowing")
		end)

		it("clears with auto", function()
			local armed = fresh()
			armed.forceTurn = "stare"
			expect(OccupantAlertRules.force(armed, senses(), "auto", 7).forceTurn).to.equal(nil)
		end)
	end)

	describe("forcedBy (the ForceSlowTurn Workspace attribute)", function()
		it("reads a variant name, any case and spacing, only where it is allowed (Studio)", function()
			expect(OccupantTurnRules.forcedBy("knowing", true)).to.equal("knowing")
			expect(OccupantTurnRules.forcedBy(" Stare ", true)).to.equal("stare")
			expect(OccupantTurnRules.forcedBy("SNAP", true)).to.equal("snap")
		end)

		it("fails closed: outside Studio, unset, auto, junk or a non-string does nothing", function()
			expect(OccupantTurnRules.forcedBy("knowing", false)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy(nil, true)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy("auto", true)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy("", true)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy("spin", true)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy(1, true)).to.equal(nil)
			expect(OccupantTurnRules.forcedBy(true, true)).to.equal(nil)
		end)

		it(
			"arms every head turn while set: a mind without a forced variant gets it, an armed one keeps its own",
			function()
				local mind = fresh()
				expect(OccupantTurnRules.arm(mind, "knowing").forceTurn).to.equal("knowing")
				expect(mind.forceTurn).to.equal(nil)
				local armed = fresh()
				armed.forceTurn = "stare"
				expect(OccupantTurnRules.arm(armed, "knowing").forceTurn).to.equal("stare")
				expect(OccupantTurnRules.arm(mind, nil)).to.equal(mind)
			end
		)
	end)
end
