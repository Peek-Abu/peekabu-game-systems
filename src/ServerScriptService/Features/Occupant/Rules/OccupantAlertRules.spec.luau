local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAlertRules = require(script.Parent.OccupantAlertRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }

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

local function player(userId, position, clear, hidden)
	return { userId = userId, position = position, clear = clear ~= false, hidden = hidden }
end

-- 12 studs straight to his left: in his peripheral zone, out of his front cone.
local BESIDE = Vector3.new(60, 3, 72)
-- The default rolls (0.5): the hold before the check.
local HOLD = C.TURN_SWIVEL + (C.TURN_HOLD.min + C.TURN_HOLD.max) / 2

local function fresh()
	return OccupantBrainRules.newMind(1, 1, 0)
end

-- Steps him every `dt` seconds from `start` while `players` stand where they are; returns every step.
local function run(mind, start, dt, count, players)
	local steps = {}
	local current = mind
	for index = 0, count - 1 do
		local step = OccupantBrainRules.step(current, senses({ now = start + index * dt, players = players }))
		table.insert(steps, step)
		current = step.mind
	end
	return steps
end

-- He turned his head to `point` at now 100 (a noise, or a glance at `target`).
local function turned(point, target)
	return OccupantAlertRules.begin(fresh(), senses(), point, target)
end

return function()
	describe("the peripheral notice", function()
		it("notices someone beside him in about 2 s, walking on meanwhile, then turns his head", function()
			local steps = run(fresh(), 100, 0.5, 5, { player(7, BESIDE) })
			for index = 1, 4 do
				expect(steps[index].mind.mode).to.equal("patrol")
				expect(steps[index].intent.kind).to.equal("goTo")
			end
			expect(steps[4].mind.glanceId).to.equal(7)
			expect(steps[4].mind.glanceSeconds).to.be.near(1.5)
			local turn = steps[5]
			expect(turn.mind.mode).to.equal("alert")
			expect(turn.mind.point).to.equal(BESIDE)
			expect(turn.mind.target).to.equal(7)
			expect(turn.intent.kind).to.equal("idle")
			expect(turn.mind.swivelUntil > 102).to.equal(true)
			expect(turn.mind.glanceId).to.equal(nil)
		end)

		it("never sees a hidden player beside him", function()
			local steps = run(fresh(), 100, 0.5, 8, { player(7, BESIDE, true, true) })
			expect(steps[8].mind.mode).to.equal("patrol")
			expect(steps[8].mind.glanceId).to.equal(nil)
		end)

		it("is slower crouched", function()
			local crouched = player(7, BESIDE)
			crouched.crouched = true
			local steps = run(fresh(), 100, 0.5, 5, { crouched })
			expect(steps[5].mind.mode).to.equal("patrol")
		end)

		it("falls back once they leave the zone, and is dropped at 0", function()
			local steps = run(fresh(), 100, 0.5, 3, { player(7, BESIDE) })
			expect(steps[3].mind.glanceSeconds).to.be.near(1)
			local away = OccupantBrainRules.step(steps[3].mind, senses({ now = 101.25 }))
			expect(away.mind.glanceSeconds).to.be.near(1 - 0.25 * C.NOTICE_DECAY)
			local gone = OccupantBrainRules.step(away.mind, senses({ now = 101.75 }))
			expect(gone.mind.glanceSeconds).to.equal(nil)
			expect(gone.mind.glanceId).to.equal(nil)
		end)
	end)

	describe("the felt presence (behaviours design §11.7)", function()
		-- 10 studs straight behind him: his blind spot, within FELT_RANGE.
		local BACK = Vector3.new(50, 3, 60)

		it("feels someone lingering right behind him over FELT_SECONDS, then turns his head to them", function()
			local count = math.floor(C.FELT_SECONDS / 0.5) + 1
			local steps = run(fresh(), 100, 0.5, count, { player(7, BACK) })
			for index = 1, count - 1 do
				expect(steps[index].mind.mode).to.equal("patrol")
			end
			expect(steps[count - 1].mind.glanceId).to.equal(7)
			local turn = steps[count]
			expect(turn.mind.mode).to.equal("alert")
			expect(turn.mind.target).to.equal(7)
			expect(turn.mind.point).to.equal(BACK)
		end)

		it("is a turn he is certain of: the knowing turn on its roll (no forcing)", function()
			local count = math.floor(C.FELT_SECONDS / 0.5) + 1
			local mind = fresh()
			mind.menace = 40
			local turn
			for index = 0, count - 1 do
				turn = OccupantBrainRules.step(
					mind,
					senses({
						now = 100 + index * 0.5,
						players = { player(7, BACK) },
						rolls = { 0.5, 0.5, 0.5, 0, 1, 0 },
					})
				)
				mind = turn.mind
			end
			expect(turn.mind.mode).to.equal("alert")
			expect(turn.mind.phase).to.equal("slowTurn")
			expect(turn.mind.turn).to.equal("knowing")
		end)

		it("never feels a hidden player, nor one beyond FELT_RANGE behind him", function()
			local far = Vector3.new(60 - C.FELT_RANGE - 2, 3, 60)
			local steps = run(fresh(), 100, 0.5, 10, { player(7, BACK, true, true), player(8, far) })
			expect(steps[10].mind.mode).to.equal("patrol")
			expect(steps[10].mind.glanceId).to.equal(nil)
		end)
	end)

	describe("a noise beside or behind him", function()
		it("turns his head to it while he patrols or investigates", function()
			local noise = Vector3.new(40, 0, 60)
			local step = OccupantBrainRules.step(fresh(), senses({ heard = noise }))
			expect(step.mind.mode).to.equal("alert")
			expect(step.mind.point).to.equal(noise)
			expect(step.mind.target).to.equal(nil)
			expect(step.intent.kind).to.equal("idle")
			expect(step.cue).to.equal(nil)
			local investigating = OccupantBrainRules.step(fresh(), senses({ heard = Vector3.new(90, 0, 60) })).mind
			local again = OccupantBrainRules.step(investigating, senses({ now = 101, heard = Vector3.new(60, 0, 80) }))
			expect(again.mind.mode).to.equal("alert")
		end)

		it("walks to a noise in front of him as before", function()
			local step = OccupantBrainRules.step(fresh(), senses({ heard = Vector3.new(90, 0, 65) }))
			expect(step.mind.mode).to.equal("investigate")
		end)

		it("is not a reason to stop a search: a quick head snap to it, then he runs there", function()
			local mind = fresh()
			mind.mode = "search"
			mind.since = 99
			mind.target = 7
			mind.lastSeen = Vector3.new(80, 3, 60)
			local noise = Vector3.new(40, 0, 60)
			local step = OccupantBrainRules.step(mind, senses({ heard = noise }))
			expect(step.mind.mode).to.equal("search")
			expect(step.mind.point).to.equal(noise)
			expect(step.mind.swivelUntil).to.be.near(100 + C.SEARCH_SNAP)
			expect(step.intent.kind).to.equal("idle")
			local snapping = OccupantBrainRules.step(step.mind, senses({ now = 100 + C.SEARCH_SNAP - 0.05 }))
			expect(snapping.intent.kind).to.equal("idle")
			local off = OccupantBrainRules.step(step.mind, senses({ now = 100 + C.SEARCH_SNAP + 0.01 }))
			expect(off.mind.mode).to.equal("search")
			expect(off.intent.kind).to.equal("goTo")
			expect(off.intent.position).to.equal(noise)
			expect(off.intent.run).to.equal(true)
		end)

		it("on a breather, only a near one turns him", function()
			local mind = fresh()
			mind.breatherUntil = 500
			local far =
				OccupantBrainRules.step(mind, senses({ heard = Vector3.new(60, 0, 60 + C.BREATHER_HEARING + 5) }))
			expect(far.mind.mode).to.equal("patrol")
			local near = OccupantBrainRules.step(mind, senses({ heard = Vector3.new(60, 0, 70) }))
			expect(near.mind.mode).to.equal("alert")
		end)
	end)

	describe("the head turn", function()
		it("holds still, head turned, until the check", function()
			local turn = turned(BESIDE, 7)
			expect(turn.mind.hold).to.be.near(HOLD)
			expect(turn.mind.swivelUntil).to.be.near(100 + HOLD)
			local holding = OccupantBrainRules.step(turn.mind, senses({ now = 100 + HOLD - 0.05 }))
			expect(holding.mind.mode).to.equal("alert")
			expect(holding.intent.kind).to.equal("idle")
		end)

		it("rolls the hold within TURN_HOLD after the swivel", function()
			local quick = OccupantAlertRules.begin(fresh(), senses({ rolls = { 0, 0, 0, 0 } }), BESIDE, nil)
			local slow = OccupantAlertRules.begin(fresh(), senses({ rolls = { 1, 1, 1, 1 } }), BESIDE, nil)
			expect(quick.mind.hold).to.be.near(C.TURN_SWIVEL + C.TURN_HOLD.min)
			expect(slow.mind.hold).to.be.near(C.TURN_SWIVEL + C.TURN_HOLD.max)
		end)

		it("his head follows the player he turned to while he can see them", function()
			local turn = turned(BESIDE, 7)
			local moved = Vector3.new(58, 3, 74)
			local holding = OccupantBrainRules.step(turn.mind, senses({ now = 100.3, players = { player(7, moved) } }))
			expect(holding.mind.point).to.equal(moved)
		end)

		it("chases when he sees them down that way at the check", function()
			local turn = turned(BESIDE, 7)
			local up =
				OccupantBrainRules.step(turn.mind, senses({ now = 100 + HOLD + 0.01, players = { player(7, BESIDE) } }))
			expect(up.mind.mode).to.equal("chase")
			expect(up.mind.target).to.equal(7)
			expect(up.cue).to.equal("spotted")
			expect(up.intent.kind).to.equal("goTo")
			expect(up.intent.run).to.equal(true)
		end)

		it("chases whoever he sees down that way after a noise, nearest first", function()
			local turn = turned(Vector3.new(40, 0, 60), nil)
			local up = OccupantBrainRules.step(
				turn.mind,
				senses({
					now = 100 + HOLD + 0.01,
					players = { player(8, Vector3.new(30, 3, 62)), player(9, Vector3.new(45, 3, 58)) },
				})
			)
			expect(up.mind.mode).to.equal("chase")
			expect(up.mind.target).to.equal(9)
		end)

		it("investigates the point when they hid meanwhile", function()
			local turn = turned(BESIDE, 7)
			local up = OccupantBrainRules.step(
				turn.mind,
				senses({ now = 100 + HOLD + 0.01, players = { player(7, BESIDE, true, true) } })
			)
			expect(up.mind.mode).to.equal("investigate")
			expect(up.mind.noise).to.equal(BESIDE)
			expect(up.cue).to.equal("curious")
			expect(up.intent.kind).to.equal("goTo")
			expect(up.intent.run).to.equal(false)
		end)

		it("investigates the point when a wall is in the way", function()
			local turn = turned(BESIDE, 7)
			local up = OccupantBrainRules.step(
				turn.mind,
				senses({ now = 100 + HOLD + 0.01, players = { player(7, BESIDE, false) } })
			)
			expect(up.mind.mode).to.equal("investigate")
		end)

		it("chases at once anyone who walks into his front cone meanwhile", function()
			local turn = turned(BESIDE, 7)
			local seen = OccupantBrainRules.step(
				turn.mind,
				senses({ now = 100.2, players = { player(8, Vector3.new(80, 3, 60)) } })
			)
			expect(seen.mind.mode).to.equal("chase")
			expect(seen.mind.target).to.equal(8)
		end)

		it("ignores other noises while he holds", function()
			local turn = turned(BESIDE, 7)
			local holding = OccupantBrainRules.step(turn.mind, senses({ now = 100.2, heard = Vector3.new(40, 0, 40) }))
			expect(holding.mind.mode).to.equal("alert")
			expect(holding.mind.point).to.equal(BESIDE)
		end)

		it("gives way to the shift's break", function()
			local turn = turned(BESIDE, 7)
			local step = OccupantBrainRules.step(turn.mind, senses({ now = 100.2, resting = true }))
			expect(step.mind.mode).to.equal("rest")
		end)
	end)

	describe("turns", function()
		it("is a noise outside his front cone, while he patrols or investigates", function()
			local s = senses()
			local mind = fresh()
			expect(OccupantAlertRules.turns(mind, s, Vector3.new(40, 0, 60))).to.equal(true)
			expect(OccupantAlertRules.turns(mind, s, Vector3.new(90, 0, 60))).to.equal(false)
			mind.mode = "search"
			expect(OccupantAlertRules.turns(mind, s, Vector3.new(40, 0, 60))).to.equal(false)
		end)
	end)
end
