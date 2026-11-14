local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantPerchRules = require(script.Parent.OccupantPerchRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- He stands at the origin; one kid 60 studs off along +X (well past PERCH_CREW_MIN).
local KID = Vector3.new(60, 0, 0)

local function perch(id, x, seen)
	return { perch = { id = id, top = Vector3.new(x, 8, 0) }, seen = seen == true }
end

local function senses(extra)
	local value = {
		position = Vector3.zero,
		look = Vector3.zAxis,
		now = 100,
		sightRange = 60,
		sightAngle = 100,
		players = { { userId = 7, position = KID, clear = false } },
		resting = false,
		route = { Vector3.new(0, 0, 0), Vector3.new(30, 0, 4), Vector3.new(40, 0, -4) },
		restPoint = Vector3.zero,
		zone = { min = Vector3.new(-2, -2, -502), max = Vector3.new(2, 2, -498) },
		-- 30 studs from the kid (between PERCH_NEAR and PERCH_FAR), 50 studs (too far), 55 (too close: 5).
		perches = { perch("lockers", 30), perch("far", 10), perch("close", 55) },
		watchedAt = nil,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

-- A patrolling mind made long ago, so the first-perch wait has passed.
local function mind(extra)
	local value = OccupantBrainRules.newMind(1, 1, 0)
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function effectOf(step, kind)
	for _, effect in step.effects or {} do
		if effect.kind == kind then
			return effect
		end
	end
	return nil
end

return function()
	describe("ready", function()
		it("waits PERCH_UNSEEN_SECONDS after the run starts before the first perch", function()
			local fresh = OccupantBrainRules.newMind(1, 1, 100)
			expect(OccupantPerchRules.ready(fresh, senses())).to.equal(false)
			expect(OccupantPerchRules.ready(fresh, senses({ now = 100 + C.PERCH_UNSEEN_SECONDS }))).to.equal(true)
		end)

		it("needs PERCH_UNSEEN_SECONDS since anyone last watched him", function()
			expect(OccupantPerchRules.ready(mind(), senses({ watchedAt = 90 }))).to.equal(false)
			expect(OccupantPerchRules.ready(mind(), senses({ watchedAt = 100 - C.PERCH_UNSEEN_SECONDS }))).to.equal(
				true
			)
		end)

		it("only while patrolling, investigating or searching", function()
			expect(OccupantPerchRules.ready(mind({ mode = "investigate" }), senses())).to.equal(true)
			expect(OccupantPerchRules.ready(mind({ mode = "search" }), senses())).to.equal(true)
			expect(OccupantPerchRules.ready(mind({ mode = "chase", target = 7 }), senses())).to.equal(false)
			expect(OccupantPerchRules.ready(mind({ mode = "perch" }), senses())).to.equal(false)
			expect(OccupantPerchRules.ready(mind({ mode = "rest" }), senses())).to.equal(false)
		end)

		it("never with a crew member within PERCH_CREW_MIN of him", function()
			local near = { { userId = 7, position = Vector3.new(C.PERCH_CREW_MIN - 1, 0, 0), clear = false } }
			expect(OccupantPerchRules.ready(mind(), senses({ players = near }))).to.equal(false)
		end)

		it("never for a kind with no perches, nor during the cooldown after a drop", function()
			-- (A nil in the overrides table is no key at all, so drop the field after building.)
			local harlow = senses()
			harlow.perches = nil
			expect(OccupantPerchRules.ready(mind(), harlow)).to.equal(false)
			expect(OccupantPerchRules.ready(mind({ perchReadyAt = 101 }), senses())).to.equal(false)
		end)
	end)

	describe("pick", function()
		it("takes the unseen perch nearest a crew member, but no nearer than PERCH_NEAR", function()
			local picked = OccupantPerchRules.pick(senses())
			expect(picked).to.be.ok()
			expect(picked.id).to.equal("lockers")
		end)

		it("never a perch a crew camera sees", function()
			local seenOnly = senses({ perches = { perch("lockers", 30, true) } })
			expect(OccupantPerchRules.pick(seenOnly)).to.equal(nil)
		end)

		it("ignores hidden crew and nothing fits with nobody out", function()
			local hidden = { { userId = 7, position = KID, clear = false, hidden = true } }
			expect(OccupantPerchRules.pick(senses({ players = hidden }))).to.equal(nil)
		end)
	end)

	describe("begin", function()
		it("goes up onto the picked perch unseen, facing the nearest kid, standing still", function()
			local step = OccupantPerchRules.begin(mind(), senses())
			expect(step).to.be.ok()
			expect(step.mind.mode).to.equal("perch")
			expect(step.mind.perch.id).to.equal("lockers")
			expect(step.mind.perchedAt).to.equal(100)
			expect(step.mind.target).to.equal(nil)
			expect(step.intent.kind).to.equal("idle")
			local up = effectOf(step, "perch")
			expect(up.top).to.equal(Vector3.new(30, 8, 0))
			expect(up.facing).to.equal(KID)
		end)

		it("is nil when not ready or nothing fits", function()
			expect(OccupantPerchRules.begin(mind({ mode = "chase", target = 7 }), senses())).to.equal(nil)
			expect(OccupantPerchRules.begin(mind(), senses({ perches = {} }))).to.equal(nil)
		end)
	end)

	describe("think (on the perch)", function()
		local function perched()
			return mind({
				mode = "perch",
				perch = { id = "lockers", top = Vector3.new(30, 8, 0) },
				perchedAt = 100,
				since = 100,
			})
		end

		it("stays put, still, while nothing happens", function()
			local step = OccupantPerchRules.think(perched(), senses({ now = 105 }))
			expect(step.mind.mode).to.equal("perch")
			expect(step.intent.kind).to.equal("idle")
			expect(effectOf(step, "drop")).to.equal(nil)
		end)

		it("drops to the nearest route point once someone watched him up there and looked away", function()
			local step = OccupantPerchRules.think(perched(), senses({ now = 106, unfrozenAt = 105.5 }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.perch).to.equal(nil)
			expect(step.mind.perchReadyAt).to.equal(106 + C.PERCH_COOLDOWN)
			expect(effectOf(step, "drop").position).to.equal(Vector3.new(30, 0, 4))
		end)

		it("ignores an unfreeze from before he went up", function()
			local step = OccupantPerchRules.think(perched(), senses({ now = 106, unfrozenAt = 99 }))
			expect(step.mind.mode).to.equal("perch")
		end)

		it("drops when someone comes within PERCH_DROP_RANGE, or after PERCH_HOLD_MAX", function()
			local close = { { userId = 7, position = Vector3.new(30, 0, C.PERCH_DROP_RANGE - 1), clear = true } }
			local near = OccupantPerchRules.think(perched(), senses({ now = 103, players = close }))
			expect(near.mind.mode).to.equal("patrol")
			local timeout = OccupantPerchRules.think(perched(), senses({ now = 100 + C.PERCH_HOLD_MAX }))
			expect(timeout.mind.mode).to.equal("patrol")
			expect(effectOf(timeout, "drop")).to.be.ok()
		end)
	end)
end
