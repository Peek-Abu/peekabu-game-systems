local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantPerchRules = require(script.Parent.OccupantPerchRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- He stands at the origin; one kid 60 studs off along +X (well past PERCH_CREW_MIN).
local KID = Vector3.new(60, 0, 0)

-- A cling spot on the front (+Z) face of a 7-tall locker bank at `x`: its top edge, where his chest hangs, the checked
-- landing in front, lots of headroom over the edge and the edge 7 over the floor.
local function face(id, x, extra)
	local value = {
		id = id,
		edge = Vector3.new(x, 7, 0),
		normal = Vector3.zAxis,
		at = Vector3.new(x, 5, 1),
		landing = Vector3.new(x, 0, 4),
		headroom = 6,
		floorDrop = 7,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function perch(id, x, seen, extra)
	return { perch = face(id, x, extra), seen = seen == true }
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

	describe("fits (owner play-check 11-14: clinging to a face, never through the ceiling or the floor)", function()
		it("fits when his head clears the ceiling over the edge and his body clears the floor below it", function()
			expect(OccupantPerchRules.fits(face("a", 0), 6)).to.equal(true)
		end)

		it("never where the ceiling is closer over the edge than his peek and the spare room", function()
			local low = face("a", 0, { headroom = C.PERCH_CLING_PEEK + C.PERCH_HEAD_CLEAR - 0.01 })
			expect(OccupantPerchRules.fits(low, 6)).to.equal(false)
			local ok = face("a", 0, { headroom = C.PERCH_CLING_PEEK + C.PERCH_HEAD_CLEAR })
			expect(OccupantPerchRules.fits(ok, 6)).to.equal(true)
		end)

		it("never where his hanging body would reach into the floor (a prop too low for him)", function()
			-- Hanging, his lowest point is floorDrop + PERCH_CLING_PEEK - height over the floor.
			local height = 7 + C.PERCH_CLING_PEEK - C.PERCH_FLOOR_CLEAR
			expect(OccupantPerchRules.fits(face("a", 0), height)).to.equal(true)
			expect(OccupantPerchRules.fits(face("a", 0), height + 0.01)).to.equal(false)
			expect(OccupantPerchRules.fits(face("table", 0, { floorDrop = 3 }), 6)).to.equal(false)
		end)

		it("checks only the ceiling when his height is unknown", function()
			expect(OccupantPerchRules.fits(face("table", 0, { floorDrop = 3 }), nil)).to.equal(true)
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

		it("never a perch his body does not fit", function()
			local low = senses({ perches = { perch("lockers", 30, false, { headroom = 0.5 }) } })
			expect(OccupantPerchRules.pick(low)).to.equal(nil)
			local short = senses({ perches = { perch("table", 30, false, { floorDrop = 2 }) }, perchHeight = 8 })
			expect(OccupantPerchRules.pick(short)).to.equal(nil)
		end)

		it("ignores hidden crew and nothing fits with nobody out", function()
			local hidden = { { userId = 7, position = KID, clear = false, hidden = true } }
			expect(OccupantPerchRules.pick(senses({ players = hidden }))).to.equal(nil)
		end)
	end)

	describe("begin", function()
		it("clings to the picked face unseen, facing out from it, standing still", function()
			local step = OccupantPerchRules.begin(mind(), senses())
			expect(step).to.be.ok()
			expect(step.mind.mode).to.equal("perch")
			expect(step.mind.perch.id).to.equal("lockers")
			expect(step.mind.perchedAt).to.equal(100)
			expect(step.mind.target).to.equal(nil)
			expect(step.intent.kind).to.equal("idle")
			local up = effectOf(step, "perch")
			expect(up.edge).to.equal(Vector3.new(30, 7, 0))
			expect(up.normal).to.equal(Vector3.zAxis)
			expect(up.at).to.equal(Vector3.new(30, 5, 1))
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
				perch = face("lockers", 30),
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

		it("drops to the face's checked landing once someone watched him up there and looked away", function()
			local step = OccupantPerchRules.think(perched(), senses({ now = 106, unfrozenAt = 105.5 }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.perch).to.equal(nil)
			expect(step.mind.perchReadyAt).to.equal(106 + C.PERCH_COOLDOWN)
			expect(step.mind.droppedAt).to.equal(106)
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

	describe("faces (where a prop can be clung to)", function()
		it("offers the four side faces of a box: each one's top-edge centre and outward normal", function()
			local frame = CFrame.new(10, 3.5, 5)
			local faces = OccupantPerchRules.faces(frame, Vector3.new(4, 7, 2))
			expect(#faces).to.equal(4)
			local found = {}
			for _, item in faces do
				expect(item.edge.Y).to.be.near(7, 1e-6)
				expect(math.abs(item.normal.Magnitude - 1) < 1e-6).to.equal(true)
				expect(item.normal.Y).to.be.near(0, 1e-6)
				found[string.format("%d,%d", math.round(item.normal.X), math.round(item.normal.Z))] = item.edge
			end
			expect(found["0,1"]).to.equal(Vector3.new(10, 7, 6))
			expect(found["0,-1"]).to.equal(Vector3.new(10, 7, 4))
			expect(found["1,0"]).to.equal(Vector3.new(12, 7, 5))
			expect(found["-1,0"]).to.equal(Vector3.new(8, 7, 5))
		end)

		it("turns them with a turned box", function()
			local faces =
				OccupantPerchRules.faces(CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(4, 2, 2))
			for _, item in faces do
				local flat = Vector3.new(item.edge.X, 0, item.edge.Z)
				local expected = if math.abs(item.normal.X) > 0.5 then 1 else 2
				expect(flat.Magnitude).to.be.near(expected, 1e-6)
			end
		end)
	end)

	describe("fallAt (the drop's path)", function()
		local FROM = Vector3.new(0, 10, 0)
		local TO = Vector3.new(8, 2, 0)

		it("starts on the perch and ends on the floor point", function()
			expect((OccupantPerchRules.fallAt(FROM, TO, 0, 1.5) - FROM).Magnitude < 1e-6).to.equal(true)
			expect((OccupantPerchRules.fallAt(FROM, TO, 1, 1.5) - TO).Magnitude < 1e-6).to.equal(true)
			expect((OccupantPerchRules.fallAt(FROM, TO, 2, 1.5) - TO).Magnitude < 1e-6).to.equal(true)
		end)

		it("hops up off the top first, then falls faster and faster", function()
			local early = OccupantPerchRules.fallAt(FROM, TO, 0.15, 1.5)
			expect(early.Y > FROM.Y).to.equal(true)
			local a = OccupantPerchRules.fallAt(FROM, TO, 0.6, 1.5).Y - OccupantPerchRules.fallAt(FROM, TO, 0.7, 1.5).Y
			local b = OccupantPerchRules.fallAt(FROM, TO, 0.85, 1.5).Y
				- OccupantPerchRules.fallAt(FROM, TO, 0.95, 1.5).Y
			expect(b > a).to.equal(true)
		end)

		it("moves out from the face first, then down (it clears the prop before it drops)", function()
			local half = OccupantPerchRules.fallAt(FROM, TO, 0.5, 1.5)
			expect(half.X > 4 + 1).to.equal(true)
		end)
	end)
end
