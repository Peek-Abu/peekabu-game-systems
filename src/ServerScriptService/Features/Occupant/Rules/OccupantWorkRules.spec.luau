local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantWorkRules = require(script.Parent.OccupantWorkRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
-- A desk whose seat looks along -X (toward the desk) at (90, 4.6, 60); its spot "s1" in front of it.
local SEAT = CFrame.lookAt(Vector3.new(90, 4.6, 60), Vector3.new(87, 4.6, 60))
local DESK_FRAME = CFrame.new(80, 1.5, 60)
local DESK_SIZE = Vector3.new(5, 3, 3)
local DESK = { id = "d1", seat = SEAT, front = true, spotId = "s1", frame = DESK_FRAME, size = DESK_SIZE }
local SPOT = { id = "s1", center = Vector3.new(87, 1.5, 60), stand = Vector3.new(90.6, 0, 60), deskId = "d1" }
local AT_SEAT = Vector3.new(90, 4.6, 60)

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
		desks = { DESK },
		spots = { SPOT },
		hiders = {},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function due()
	local mind = OccupantBrainRules.newMind(1, 1, 0)
	mind.nextWorkAt = 50
	return mind
end

-- Walks to the desk and sits: the mind typing at `now`.
local function seated(now, rolls)
	local walking = OccupantBrainRules.step(due(), senses({ now = now - 1 }))
	return OccupantBrainRules.step(walking.mind, senses({ now = now, position = AT_SEAT, rolls = rolls })).mind
end

local function kinds(step)
	local list = {}
	for _, effect in step.effects or {} do
		table.insert(list, effect.kind)
	end
	return table.concat(list, ",")
end

return function()
	describe("work breaks", function()
		it("walks to a desk when a break is due", function()
			local step = OccupantBrainRules.step(due(), senses())
			expect(step.mind.mode).to.equal("work")
			expect(step.mind.phase).to.equal("toDesk")
			expect(step.mind.desk.id).to.equal("d1")
			expect(step.intent.kind).to.equal("goTo")
			expect(step.intent.position).to.equal(AT_SEAT)
		end)

		it("is not due before its time, nor without desks", function()
			local mind = due()
			mind.nextWorkAt = 500
			expect(OccupantWorkRules.due(mind, senses())).to.equal(nil)
			local bare = senses()
			bare.desks = nil
			expect(OccupantWorkRules.due(due(), bare)).to.equal(nil)
		end)

		it("never picks the desk someone hides under", function()
			local step =
				OccupantBrainRules.step(due(), senses({ hiders = { { userId = 7, spotId = "s1", seen = false } } }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.nextWorkAt).to.equal(110)
		end)

		it("sits at the chair, then types WORK_SECONDS", function()
			local walking = OccupantBrainRules.step(due(), senses())
			local sat = OccupantBrainRules.step(walking.mind, senses({ now = 101, position = AT_SEAT, rolls = { 0 } }))
			expect(sat.mind.phase).to.equal("type")
			expect(sat.mind.seated).to.equal(true)
			expect(sat.mind.hold).to.equal(C.WORK_SECONDS.min)
			expect(kinds(sat)).to.equal("sit")
			expect(sat.effects[1].seat).to.equal(SEAT)
			-- The desk goes with the seat, so standing up ends clear of it (OccupantDeskUtils.standUp).
			expect(sat.effects[1].desk).to.equal(DESK_FRAME)
			expect(sat.effects[1].deskSize).to.equal(DESK_SIZE)
			expect(sat.intent.kind).to.equal("idle")
		end)

		it(
			"someone hid under the desk while he walked to it: he sits back clear of them and holds their push-out",
			function()
				local walking = OccupantBrainRules.step(due(), senses())
				local hider = { userId = 7, spotId = "s1", seen = false }
				local sat = OccupantBrainRules.step(
					walking.mind,
					senses({ now = 101, position = AT_SEAT, rolls = { 0 }, hiders = { hider } })
				)
				-- An ordinary work break (he does not know): no tip, no sit-in cue, but his knees stay out of their huddle
				-- and being cramped never throws them into his lap.
				expect(sat.mind.phase).to.equal("type")
				expect(sat.mind.sitIn).to.equal(nil)
				expect(sat.cue).to.equal(nil)
				expect(kinds(sat)).to.equal("sit,holdCamp")
				expect((sat.effects[1].seat.Position - SEAT.Position).Magnitude).to.be.near(C.SIT_IN_BACK, 1e-3)
				expect(sat.effects[2].userId).to.equal(7)
				expect(sat.effects[2].untilTime > 101 + C.WORK_SECONDS.min).to.equal(true)
			end
		)

		it("stands up and walks on when the typing is done", function()
			local mind = seated(101, { 0 })
			local still =
				OccupantBrainRules.step(mind, senses({ now = 101 + C.WORK_SECONDS.min - 0.1, position = AT_SEAT }))
			expect(still.mind.phase).to.equal("type")
			local up = OccupantBrainRules.step(mind, senses({ now = 101 + C.WORK_SECONDS.min, position = AT_SEAT }))
			expect(up.mind.mode).to.equal("patrol")
			expect(kinds(up)).to.equal("stand")
			expect(up.effects[1].speed).to.equal(1)
			expect(up.intent.kind).to.equal("idle")
			expect(up.mind.nextWorkAt > 101 + C.WORK_SECONDS.min).to.equal(true)
		end)
	end)

	describe("summon", function()
		it("sends him straight to that desk for a work break, out of whatever he was doing", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "chase"
			mind.target = 8
			mind.steer = Vector3.new(1, 0, 1)
			local summoned = OccupantWorkRules.summon(mind, DESK, 100)
			expect(summoned.mode).to.equal("work")
			expect(summoned.phase).to.equal("toDesk")
			expect(summoned.desk.id).to.equal("d1")
			expect(summoned.target).to.equal(nil)
			expect(summoned.steer).to.equal(nil)
			expect(summoned.sitIn).to.equal(nil)
			expect(mind.mode).to.equal("chase")
			local walking = OccupantBrainRules.step(summoned, senses({ now = 100.2 }))
			expect(walking.intent.position).to.equal(AT_SEAT)
		end)
	end)

	describe("summonNear", function()
		it(
			"sends him to the free desk nearest a point but at least SUMMON_DISTANCE off, never one a hider is under",
			function()
				local mind = OccupantBrainRules.newMind(1, 1, 0)
				local far = Vector3.new(90 + C.SUMMON_DISTANCE + 5, 3, 60)
				local summoned, desk = OccupantWorkRules.summonNear(mind, { DESK }, {}, far, 100)
				expect(desk.id).to.equal("d1")
				expect(summoned.mode).to.equal("work")
				local none = OccupantWorkRules.summonNear(mind, { DESK }, {}, AT_SEAT, 100)
				expect(none).to.equal(nil)
				local hidden = OccupantWorkRules.summonNear(
					mind,
					{ DESK },
					{ { userId = 7, spotId = "s1", seen = false } },
					far,
					100
				)
				expect(hidden).to.equal(nil)
			end
		)
	end)

	describe("the ambush", function()
		it("springs on a noise: typing stops, the head swivels to it, a cue", function()
			local noise = Vector3.new(120, 0, 70)
			local step = OccupantBrainRules.step(seated(101), senses({ now = 102, position = AT_SEAT, heard = noise }))
			expect(step.mind.phase).to.equal("ambush")
			expect(step.mind.point).to.equal(noise)
			expect(step.mind.swivelUntil).to.equal(math.huge)
			expect(step.cue).to.equal("ambush")
			expect(step.intent.kind).to.equal("idle")
		end)

		it("springs on a player close by with a clear line, even behind him", function()
			-- Seated looking along -X; the player 10 studs behind him (+X).
			local near = { userId = 8, position = AT_SEAT + Vector3.new(10, 0, 0), clear = true }
			local step = OccupantBrainRules.step(
				seated(101),
				senses({ now = 102, position = AT_SEAT, look = Vector3.new(-1, 0, 0), players = { near } })
			)
			expect(step.mind.phase).to.equal("ambush")
			expect(step.mind.target).to.equal(8)
		end)

		it("never springs on a player close by through a wall (no line of sight, no noise)", function()
			local near = { userId = 8, position = AT_SEAT + Vector3.new(0, 0, 10), clear = false }
			local step =
				OccupantBrainRules.step(seated(101), senses({ now = 102, position = AT_SEAT, players = { near } }))
			expect(step.mind.phase).to.equal("type")
		end)

		it("turns on a player behind him and chases them once up (his head turned to them)", function()
			local look = Vector3.new(-1, 0, 0)
			local behind = { userId = 8, position = AT_SEAT + Vector3.new(10, 0, 0), clear = true }
			local ambush = OccupantBrainRules.step(
				seated(101),
				senses({ now = 102, position = AT_SEAT, look = look, players = { behind } })
			)
			expect(ambush.mind.point).to.equal(behind.position)
			local up = OccupantBrainRules.step(
				ambush.mind,
				senses({ now = 102 + C.AMBUSH_HOLD + 0.01, position = AT_SEAT, look = look, players = { behind } })
			)
			expect(up.mind.mode).to.equal("chase")
			expect(up.mind.target).to.equal(8)
			expect(kinds(up)).to.equal("stand")
		end)

		it("turns slowly on a player behind him when it is a knowing turn, then pops up on the jerk", function()
			local look = Vector3.new(-1, 0, 0)
			local behind = { userId = 8, position = AT_SEAT + Vector3.new(10, 0, 0), clear = true, speed = 0 }
			local rolls = { 0.5, 0.5, 0.5, 0, 1, 0 }
			local mind = seated(101)
			mind.menace = 30
			local turn = OccupantBrainRules.step(
				mind,
				senses({ now = 102, position = AT_SEAT, look = look, players = { behind }, rolls = rolls })
			)
			expect(turn.mind.mode).to.equal("work")
			expect(turn.mind.phase).to.equal("slowTurn")
			expect(turn.mind.turn).to.equal("knowing")
			expect(turn.mind.seated).to.equal(true)
			expect(turn.mind.target).to.equal(8)
			expect(turn.cue).to.equal(nil)
			expect(kinds(turn)).to.equal("")
			local now = 102 + C.SLOW_TURN_SECONDS + 0.01
			local jerk = OccupantBrainRules.step(
				turn.mind,
				senses({ now = now, position = AT_SEAT, look = look, players = { behind } })
			)
			expect(jerk.mind.mode).to.equal("chase")
			expect(jerk.mind.phase).to.equal("jerk")
			expect(jerk.mind.target).to.equal(8)
			expect(kinds(jerk)).to.equal("stand")
			expect(jerk.effects[1].speed).to.equal(C.JERK_STAND_SPEED)
			expect(jerk.mind.standUntil).to.be.near(now + C.STAND_SECONDS / C.JERK_STAND_SPEED)
			expect(jerk.mind.swivelUntil).to.be.near(now + C.JERK_SECONDS + C.STAND_SECONDS / C.JERK_STAND_SPEED)
		end)

		it("investigates instead when the player behind him hid during the beat", function()
			local look = Vector3.new(-1, 0, 0)
			local behind = { userId = 8, position = AT_SEAT + Vector3.new(10, 0, 0), clear = true }
			local ambush = OccupantBrainRules.step(
				seated(101),
				senses({ now = 102, position = AT_SEAT, look = look, players = { behind } })
			)
			local hidden = { userId = 8, position = behind.position, clear = true, hidden = true }
			local up = OccupantBrainRules.step(
				ambush.mind,
				senses({ now = 102 + C.AMBUSH_HOLD + 0.01, position = AT_SEAT, look = look, players = { hidden } })
			)
			expect(up.mind.mode).to.equal("investigate")
			expect(up.mind.noise).to.equal(behind.position)
		end)

		it("holds a beat, then stands up fast and investigates the point", function()
			local noise = Vector3.new(120, 0, 70)
			local ambush =
				OccupantBrainRules.step(seated(101), senses({ now = 102, position = AT_SEAT, heard = noise }))
			local holding =
				OccupantBrainRules.step(ambush.mind, senses({ now = 102 + C.AMBUSH_HOLD - 0.1, position = AT_SEAT }))
			expect(holding.mind.phase).to.equal("ambush")
			local up =
				OccupantBrainRules.step(ambush.mind, senses({ now = 102 + C.AMBUSH_HOLD + 0.01, position = AT_SEAT }))
			expect(up.mind.mode).to.equal("investigate")
			expect(up.mind.noise).to.equal(noise)
			-- The head stays turned to the noise while he stands.
			expect(up.mind.point).to.equal(noise)
			expect(up.mind.swivelUntil).to.be.near(102 + C.AMBUSH_HOLD + 0.01 + C.STAND_SECONDS / C.AMBUSH_STAND_SPEED)
			expect(kinds(up)).to.equal("stand")
			expect(up.effects[1].speed).to.equal(C.AMBUSH_STAND_SPEED)
			expect(up.intent.kind).to.equal("idle")
		end)

		it("chases whoever he sees when he is up", function()
			local seen = { userId = 8, position = Vector3.new(80, 3, 60), clear = true }
			-- Seated looking along -X: the player is in front of him.
			local look = Vector3.new(-1, 0, 0)
			local ambush = OccupantBrainRules.step(
				seated(101),
				senses({ now = 102, position = AT_SEAT, look = look, players = { seen } })
			)
			local up = OccupantBrainRules.step(
				ambush.mind,
				senses({ now = 102 + C.AMBUSH_HOLD + 0.01, position = AT_SEAT, look = look, players = { seen } })
			)
			expect(up.mind.mode).to.equal("chase")
			expect(up.mind.target).to.equal(8)
			expect(up.intent.kind).to.equal("idle")
			expect(kinds(up)).to.equal("stand")
		end)
	end)

	describe("the sit-in", function()
		local HIDER = { userId = 7, spotId = "s1", seen = false }

		local function sitIn(now)
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "work"
			mind.phase = "toDesk"
			mind.phaseAt = now - 1
			mind.desk = DESK
			mind.sitIn = true
			mind.quarry = 7
			mind.spot = SPOT
			return OccupantBrainRules.step(
				mind,
				senses({ now = now, position = AT_SEAT, hiders = { HIDER }, rolls = { 0, 0.5, 0.5, 0.5 } })
			)
		end

		it("sits further back over the hider and holds their camping push-out", function()
			local step = sitIn(100)
			expect(step.mind.phase).to.equal("type")
			expect(step.cue).to.equal("sitIn")
			expect(kinds(step)).to.equal("sit,holdCamp")
			local seat = step.effects[1].seat
			expect((seat.Position - SEAT.Position).Magnitude).to.be.near(C.SIT_IN_BACK, 1e-3)
			expect(step.effects[2].userId).to.equal(7)
		end)

		it("tips his head down, holds it, then always catches the hider he finds there (2026-10-17)", function()
			for _, roll in { 0, 0.5, 0.99 } do
				local typing = sitIn(100).mind
				local t = 100 + C.SIT_IN_TYPE.min
				local tip = OccupantBrainRules.step(typing, senses({ now = t, position = AT_SEAT, hiders = { HIDER } }))
				expect(tip.mind.phase).to.equal("tip")
				local hold = OccupantBrainRules.step(
					tip.mind,
					senses({ now = t + C.TIP_SECONDS + 0.01, position = AT_SEAT, hiders = { HIDER } })
				)
				expect(hold.mind.phase).to.equal("tipHold")
				local catch = OccupantBrainRules.step(
					hold.mind,
					senses({
						now = t + C.TIP_SECONDS + C.TIP_HOLD + 0.02,
						position = AT_SEAT,
						hiders = { HIDER },
						rolls = { 0.5, 0.5, roll },
					})
				)
				expect(kinds(catch)).to.equal("seen,catch")
				expect(catch.effects[2].userId).to.equal(7)
			end
		end)

		it("with nobody left under the desk: head back up, a little more typing, then up and away", function()
			local typing = sitIn(100).mind
			local t = 100 + C.SIT_IN_TYPE.min
			local mind =
				OccupantBrainRules.step(typing, senses({ now = t, position = AT_SEAT, hiders = { HIDER } })).mind
			mind = OccupantBrainRules.step(
				mind,
				senses({ now = t + C.TIP_SECONDS + 0.01, position = AT_SEAT, hiders = { HIDER } })
			).mind
			-- They were caught by someone else, or left the game: gone without a sound.
			local empty = OccupantBrainRules.step(
				mind,
				senses({ now = t + C.TIP_SECONDS + C.TIP_HOLD + 0.02, position = AT_SEAT, hiders = {} })
			)
			expect(empty.mind.phase).to.equal("tipBack")
			expect(empty.effects).to.equal(nil)
			local after = t + C.TIP_SECONDS + C.TIP_HOLD + C.TIP_BACK + 0.03
			local more = OccupantBrainRules.step(empty.mind, senses({ now = after, position = AT_SEAT, hiders = {} }))
			expect(more.mind.phase).to.equal("typeMore")
			local gone = OccupantBrainRules.step(
				more.mind,
				senses({ now = after + C.TYPE_MORE + 0.01, position = AT_SEAT, hiders = {} })
			)
			expect(gone.mind.mode).to.equal("patrol")
			expect(kinds(gone)).to.equal("seen,stand")
			expect(gone.effects[1].seen).to.equal(false)
			expect(gone.mind.cleared.s1).to.be.near(after + C.TYPE_MORE + 0.01 + C.CLEARED_SECONDS)
		end)

		it("is certain to catch after a noise by the spot", function()
			local typing = sitIn(100).mind
			local noisy = OccupantBrainRules.step(
				typing,
				senses({ now = 101, position = AT_SEAT, hiders = { HIDER }, heard = Vector3.new(86, 0, 61) })
			)
			expect(noisy.mind.phase).to.equal("type")
			expect(noisy.mind.noisy).to.equal(true)
		end)

		it("springs the ambush on a hider who bolts out from under him (their exit noise)", function()
			local typing = sitIn(100).mind
			local bolted = OccupantBrainRules.step(
				typing,
				senses({ now = 101, position = AT_SEAT, hiders = {}, heard = Vector3.new(86, 0, 61) })
			)
			expect(bolted.mind.phase).to.equal("ambush")
			expect(bolted.mind.point).to.equal(Vector3.new(86, 0, 61))
		end)
	end)
end
