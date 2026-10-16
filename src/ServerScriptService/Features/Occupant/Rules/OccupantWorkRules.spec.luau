local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantWorkRules = require(script.Parent.OccupantWorkRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
-- A desk whose seat looks along -X (toward the desk) at (90, 4.6, 60); its spot "s1" in front of it.
local SEAT = CFrame.lookAt(Vector3.new(90, 4.6, 60), Vector3.new(87, 4.6, 60))
local DESK = { id = "d1", seat = SEAT, front = true, spotId = "s1" }
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
			expect(sat.intent.kind).to.equal("idle")
		end)

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

		it("springs on a player close by, even unseen", function()
			local near = { userId = 8, position = AT_SEAT + Vector3.new(0, 0, 10), clear = false }
			local step =
				OccupantBrainRules.step(seated(101), senses({ now = 102, position = AT_SEAT, players = { near } }))
			expect(step.mind.phase).to.equal("ambush")
			expect(step.mind.target).to.equal(8)
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

		it("tips his head down, holds it, then catches on the roll", function()
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
					rolls = { 0.5, 0.5, 0 },
				})
			)
			expect(kinds(catch)).to.equal("seen,catch")
			expect(catch.effects[2].userId).to.equal(7)
		end)

		it("lets a still hider be: head back up, a little more typing, then up and away, forgetting them", function()
			local typing = sitIn(100).mind
			local t = 100 + C.SIT_IN_TYPE.min
			local mind =
				OccupantBrainRules.step(typing, senses({ now = t, position = AT_SEAT, hiders = { HIDER } })).mind
			mind = OccupantBrainRules.step(
				mind,
				senses({ now = t + C.TIP_SECONDS + 0.01, position = AT_SEAT, hiders = { HIDER } })
			).mind
			local spared = OccupantBrainRules.step(
				mind,
				senses({
					now = t + C.TIP_SECONDS + C.TIP_HOLD + 0.02,
					position = AT_SEAT,
					hiders = { HIDER },
					rolls = { 0.5, 0.5, 0.99 },
				})
			)
			expect(spared.mind.phase).to.equal("tipBack")
			expect(spared.effects).to.equal(nil)
			local after = t + C.TIP_SECONDS + C.TIP_HOLD + C.TIP_BACK + 0.03
			local more =
				OccupantBrainRules.step(spared.mind, senses({ now = after, position = AT_SEAT, hiders = { HIDER } }))
			expect(more.mind.phase).to.equal("typeMore")
			local gone = OccupantBrainRules.step(
				more.mind,
				senses({ now = after + C.TYPE_MORE + 0.01, position = AT_SEAT, hiders = { HIDER } })
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
	end)
end
