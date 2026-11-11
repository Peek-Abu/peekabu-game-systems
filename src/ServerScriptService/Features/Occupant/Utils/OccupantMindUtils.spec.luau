local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local M = require(script.Parent.OccupantMindUtils)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }
local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }

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

local function fresh()
	return OccupantBrainRules.newMind(1, 1, 0)
end

return function()
	describe("inZone", function()
		local YARD = { min = Vector3.new(200, 0, 0), max = Vector3.new(260, 20, 40) }
		it("is true in the box, false outside it, false without a zone", function()
			expect(M.inZone(Vector3.new(10, 3, 10), ZONE)).to.equal(true)
			expect(M.inZone(Vector3.new(230, 3, 10), ZONE)).to.equal(false)
			expect(M.inZone(Vector3.new(10, 3, 10), nil)).to.equal(false)
		end)
		it("is true in any `more` box, and unchanged with more = nil", function()
			local zone = { min = ZONE.min, max = ZONE.max, more = { YARD } }
			expect(M.inZone(Vector3.new(230, 3, 10), zone)).to.equal(true)
			expect(M.inZone(Vector3.new(10, 3, 10), zone)).to.equal(true)
			expect(M.inZone(Vector3.new(120, 3, 10), zone)).to.equal(false)
			expect(M.inZone(Vector3.new(230, 3, 10), { min = ZONE.min, max = ZONE.max })).to.equal(false)
		end)
	end)

	describe("enter", function()
		it("copies into the mode and forgets any desk or spot", function()
			local mind = fresh()
			mind.phase = "type"
			mind.desk = { id = "d", seat = CFrame.new(), front = true }
			local entered = M.enter(mind, "chase", 5)
			expect(entered.mode).to.equal("chase")
			expect(entered.since).to.equal(5)
			expect(entered.phase).to.equal(nil)
			expect(entered.desk).to.equal(nil)
			expect(mind.phase).to.equal("type")
		end)
	end)

	describe("roll", function()
		it("reads this think's rolls, 0.5 when absent", function()
			expect(M.roll(senses({ rolls = { 0.1, 0.9 } }), 2)).to.equal(0.9)
			expect(M.roll(senses(), 1)).to.equal(0.5)
		end)
	end)

	describe("patrol", function()
		it("walks to the director's steer point first, then rejoins the route at its nearest point", function()
			local mind = fresh()
			mind.steer = Vector3.new(80, 0, 60)
			local going = M.patrol(mind, senses(), nil)
			expect(going.intent.position).to.equal(Vector3.new(80, 0, 60))
			local there = M.patrol(mind, senses({ position = Vector3.new(80, 3, 61) }), nil)
			expect(there.mind.steer).to.equal(nil)
			expect(there.intent.position).to.equal(ROUTE[1])
		end)
	end)

	describe("visible", function()
		it("never sees a hiding player, even one he saw go in", function()
			local seen = M.visible(
				fresh(),
				senses({
					players = {
						{ userId = 7, position = Vector3.new(80, 3, 60), clear = true, hidden = true, seen = true },
					},
				})
			)
			expect(#seen).to.equal(0)
		end)
	end)

	describe("chase", function()
		it("waits a startled beat when a hider bolts", function()
			local step =
				M.chase(fresh(), senses(), { userId = 7, position = Vector3.new(62, 3, 60), clear = true }, true)
			expect(step.mind.mode).to.equal("chase")
			expect(step.intent.kind).to.equal("idle")
			expect(step.mind.reactUntil).to.equal(100 + C.STARTLE_SECONDS)
			expect(step.cue).to.equal("spotted")
		end)
		it("bumps the menace gauge on a sighting", function()
			local step =
				M.chase(fresh(), senses(), { userId = 7, position = Vector3.new(80, 3, 60), clear = true }, false)
			expect(step.mind.menace).to.equal(C.MENACE_SPOTTED)
		end)
		it("grabs a player in reach, but walks round to one he sees only through glass", function()
			local near = Vector3.new(62, 3, 60)
			local open = M.chase(fresh(), senses(), { userId = 7, position = near, clear = true }, false)
			expect(open.intent.kind).to.equal("attack")
			local glass =
				M.chase(fresh(), senses(), { userId = 7, position = near, clear = true, glassed = true }, false)
			expect(glass.mind.mode).to.equal("chase")
			expect(glass.intent.kind).to.equal("goTo")
		end)
	end)

	describe("summary", function()
		it("names his mode, phase and target for the debugger", function()
			local mind = fresh()
			local summary = M.summary(mind)
			expect(summary.mode).to.equal("patrol")
			expect(summary.phase).to.equal("")
			expect(summary.target).to.equal(0)
			expect(summary.menace).to.equal(0)
		end)
	end)

	describe("beginStare", function()
		it("remembers how far from him the hider went in", function()
			local spot = { id = "s", center = Vector3.new(66, 1.5, 60), stand = Vector3.new(64, 0, 60) }
			local step = M.beginStare(fresh(), senses(), spot, 7)
			expect(step.mind.mode).to.equal("stare")
			expect(step.mind.phase).to.equal("approach")
			expect(step.mind.entered[7]).to.be.near(6)
			expect(step.intent.position).to.equal(spot.stand)
		end)
	end)

	describe("uses (a kind's behaviour blocks)", function()
		local DESK = { id = "d1", seat = CFrame.new(90, 4.6, 60), front = true, spotId = "s1" }

		it("uses every block with no blocks in the senses (Harlow as before)", function()
			expect(M.uses(senses(), "desks")).to.equal(true)
			expect(M.uses(senses(), "stares")).to.equal(true)
			expect(#M.desks(senses({ desks = { DESK } }))).to.equal(1)
		end)

		it("follows the registry: Harlow uses desks and stares, Bramble only stares", function()
			local harlow = OccupantKindRegistry.get("harlow").blocks
			local bramble = OccupantKindRegistry.get("bramble").blocks
			expect(M.uses(senses({ blocks = harlow }), "desks")).to.equal(true)
			expect(M.uses(senses({ blocks = harlow }), "stares")).to.equal(true)
			expect(M.uses(senses({ blocks = bramble }), "desks")).to.equal(false)
			expect(M.uses(senses({ blocks = bramble }), "stares")).to.equal(true)
		end)

		it("hides every desk from a kind without the desk block, so no sit-in finds one", function()
			local bramble = OccupantKindRegistry.get("bramble").blocks
			local value = senses({ desks = { DESK }, blocks = bramble })
			expect(#M.desks(value)).to.equal(0)
			expect(M.findDesk(value, "d1")).to.equal(nil)
			expect(M.findDesk(senses({ desks = { DESK } }), "d1")).to.equal(DESK)
		end)
	end)
end
