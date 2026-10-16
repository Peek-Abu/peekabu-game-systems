local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local M = require(script.Parent.OccupantMindUtils)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

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
end
