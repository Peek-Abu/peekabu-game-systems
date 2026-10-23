local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sight = require(script.Parent.OccupantSightUtils)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }

-- Him at (60, 3, 60) looking along +X, with his long sight.
local function senses(players)
	return {
		position = Vector3.new(60, 3, 60),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = C.SIGHT_RANGE,
		sightAngle = C.SIGHT_ANGLE,
		longRange = C.LONG_SIGHT_RANGE,
		longAngle = C.LONG_SIGHT_ANGLE,
		players = players or {},
		resting = false,
		route = {},
		restPoint = Vector3.zero,
		zone = ZONE,
	}
end

local function mind(extra)
	local value = { mode = "patrol", grace = {} }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function glimpse(userId, position, clear)
	return { userId = userId, position = position, clear = clear ~= false }
end

return function()
	describe("sightOf", function()
		it("sees near in the wide cone, far only straight ahead in the narrow one", function()
			local s = senses()
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(100, 3, 60)))).to.equal("near")
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(170, 3, 60)))).to.equal("far")
			-- 110 studs out but 34 degrees off his line: outside the 40 degree long cone.
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(150, 3, 120)))).to.equal(nil)
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(60 + C.LONG_SIGHT_RANGE + 5, 3, 60)))).to.equal(nil)
		end)
		it("never through a wall, nor anyone hiding, in their grace or in the safe zone", function()
			local s = senses()
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(100, 3, 60), false))).to.equal(nil)
			local hidden = glimpse(1, Vector3.new(100, 3, 60))
			hidden.hidden = true
			expect(Sight.sightOf(mind(), s, hidden)).to.equal(nil)
			expect(Sight.sightOf(mind({ grace = { [1] = 200 } }), s, glimpse(1, Vector3.new(100, 3, 60)))).to.equal(nil)
			local behind = senses()
			behind.look = Vector3.new(-1, 0, 0)
			expect(Sight.sightOf(mind(), behind, glimpse(1, Vector3.new(30, 3, 20)))).to.equal(nil)
		end)
		it("never sees someone in a `more` box of the zone", function()
			local s = senses()
			s.zone = {
				min = ZONE.min,
				max = ZONE.max,
				more = { { min = Vector3.new(90, 0, 50), max = Vector3.new(110, 20, 70) } },
			}
			expect(Sight.sightOf(mind(), s, glimpse(1, Vector3.new(100, 3, 60)))).to.equal(nil)
			expect(Sight.sightOf(mind(), senses(), glimpse(1, Vector3.new(100, 3, 60)))).to.equal("near")
		end)
		it("sees his chase target all round up close", function()
			local s = senses()
			local behind = glimpse(7, Vector3.new(40, 3, 60))
			expect(Sight.sightOf(mind(), s, behind)).to.equal(nil)
			expect(Sight.sightOf(mind({ mode = "chase", target = 7 }), s, behind)).to.equal("near")
		end)
	end)

	describe("visible and distant", function()
		it("counts a far glimpse as seen only for his target; others far off are to be noticed", function()
			local far = glimpse(7, Vector3.new(170, 3, 60))
			local s = senses({ far })
			expect(#Sight.visible(mind(), s)).to.equal(0)
			expect(#Sight.distant(mind(), s)).to.equal(1)
			local chasing = mind({ mode = "chase", target = 7 })
			expect(#Sight.visible(chasing, s)).to.equal(1)
			expect(#Sight.distant(chasing, s)).to.equal(0)
		end)
		it("lists the nearest first", function()
			local s = senses({ glimpse(2, Vector3.new(100, 3, 60)), glimpse(1, Vector3.new(80, 3, 60)) })
			local seen = Sight.visible(mind(), s)
			expect(seen[1].userId).to.equal(1)
			expect(seen[2].userId).to.equal(2)
		end)
	end)

	describe("noticeDelay", function()
		it(
			"rises from the quick notice at his near sight's edge to the slow one at the end of his long sight",
			function()
				expect(Sight.noticeDelay(C.SIGHT_RANGE)).to.be.near(C.NOTICE_SECONDS.min)
				expect(Sight.noticeDelay(C.LONG_SIGHT_RANGE)).to.be.near(C.NOTICE_SECONDS.max)
				local mid = Sight.noticeDelay((C.SIGHT_RANGE + C.LONG_SIGHT_RANGE) / 2)
				expect(mid).to.be.near((C.NOTICE_SECONDS.min + C.NOTICE_SECONDS.max) / 2)
			end
		)
	end)

	describe("peripheral", function()
		it("lists who stands beside him (outside the front cone, within the zone) with a clear line", function()
			-- 12 studs straight to his left (90 degrees off his heading).
			local beside = glimpse(7, Vector3.new(60, 3, 72))
			local s = senses({ beside })
			expect(Sight.sightOf(mind(), s, beside)).to.equal(nil)
			local list = Sight.peripheral(mind(), s)
			expect(#list).to.equal(1)
			expect(list[1].userId).to.equal(7)
		end)
		it("never in front (that is plain sight), behind him, too far, through a wall, hidden or in grace", function()
			local ahead = glimpse(1, Vector3.new(80, 3, 60))
			-- 120 degrees off his heading: behind the zone's edge.
			local behind =
				glimpse(2, Vector3.new(60 - 10 * math.cos(math.rad(60)), 3, 60 + 10 * math.sin(math.rad(60))))
			local far = glimpse(3, Vector3.new(60, 3, 60 + C.PERIPHERAL_RANGE + 2))
			local walled = glimpse(4, Vector3.new(60, 3, 50), false)
			local hidden = glimpse(5, Vector3.new(60, 3, 48))
			hidden.hidden = true
			local graced = glimpse(6, Vector3.new(60, 3, 70))
			local s = senses({ ahead, behind, far, walled, hidden, graced })
			expect(#Sight.peripheral(mind({ grace = { [6] = 200 } }), s)).to.equal(0)
		end)
		it("lists the nearest first", function()
			local s = senses({ glimpse(2, Vector3.new(60, 3, 80)), glimpse(1, Vector3.new(60, 3, 70)) })
			local list = Sight.peripheral(mind(), s)
			expect(list[1].userId).to.equal(1)
			expect(list[2].userId).to.equal(2)
		end)
	end)

	describe("behind (the felt presence)", function()
		-- 10 studs straight behind him, and 10 studs at 150 degrees off his heading (both past the peripheral zone).
		local BACK = Vector3.new(50, 3, 60)
		local REAR_SIDE = Vector3.new(60 - 10 * math.cos(math.rad(30)), 3, 60 + 10 * math.sin(math.rad(30)))
		it("lists who stands behind him (past the peripheral zone) within FELT_RANGE with a clear line", function()
			local s = senses({ glimpse(7, BACK), glimpse(8, REAR_SIDE) })
			local list = Sight.behind(mind(), s)
			expect(#list).to.equal(2)
			expect(#Sight.peripheral(mind(), s)).to.equal(0)
		end)
		it("never beside or in front of him, past FELT_RANGE, through a wall, hidden or in grace", function()
			local beside = glimpse(1, Vector3.new(60, 3, 72))
			local ahead = glimpse(2, Vector3.new(70, 3, 60))
			local far = glimpse(3, Vector3.new(60 - C.FELT_RANGE - 1, 3, 60))
			local walled = glimpse(4, BACK, false)
			local hidden = glimpse(5, Vector3.new(52, 3, 60))
			hidden.hidden = true
			local graced = glimpse(6, Vector3.new(54, 3, 60))
			local s = senses({ beside, ahead, far, walled, hidden, graced })
			expect(#Sight.behind(mind({ grace = { [6] = 200 } }), s)).to.equal(0)
		end)
		it("is felt over FELT_SECONDS, slower crouched", function()
			expect(Sight.feltDelay(false)).to.equal(C.FELT_SECONDS)
			expect(Sight.feltDelay(true)).to.be.near(C.FELT_SECONDS * C.GLANCE_CROUCH)
			expect(C.FELT_RANGE <= C.CERTAIN_RANGE).to.equal(true)
		end)
	end)

	describe("glanceDelay", function()
		it("is quicker close, slower at the zone's edge, slower again crouched", function()
			expect(Sight.glanceDelay(0, false)).to.be.near(C.GLANCE_SECONDS.min)
			expect(Sight.glanceDelay(C.PERIPHERAL_RANGE, false)).to.be.near(C.GLANCE_SECONDS.max)
			expect(Sight.glanceDelay(12, false)).to.be.near(1.98, 0.01)
			expect(Sight.glanceDelay(12, true)).to.be.near(1.98 * C.GLANCE_CROUCH, 0.02)
		end)
	end)

	describe("beside", function()
		it("tells a point outside his front cone (beside or behind him) from one in front", function()
			local s = senses()
			expect(Sight.beside(s, Vector3.new(90, 0, 62))).to.equal(false)
			expect(Sight.beside(s, Vector3.new(60, 0, 75))).to.equal(true)
			expect(Sight.beside(s, Vector3.new(40, 0, 60))).to.equal(true)
		end)
	end)

	describe("toward", function()
		it("lists who he sees down the cone his head is turned to, never hidden or through a wall", function()
			-- His head turned to his left (+Z) while his body faces +X.
			local point = Vector3.new(60, 3, 75)
			local there = glimpse(7, Vector3.new(62, 3, 80))
			local walled = glimpse(8, Vector3.new(58, 3, 80), false)
			local hidden = glimpse(9, Vector3.new(60, 3, 78))
			hidden.hidden = true
			local opposite = glimpse(10, Vector3.new(60, 3, 45))
			local list = Sight.toward(mind(), senses({ there, walled, hidden, opposite }), point)
			expect(#list).to.equal(1)
			expect(list[1].userId).to.equal(7)
		end)
		it("reaches as far as his near sight", function()
			local point = Vector3.new(60, 3, 75)
			local list = Sight.toward(mind(), senses({ glimpse(7, Vector3.new(60, 3, 60 + C.SIGHT_RANGE + 1)) }), point)
			expect(#list).to.equal(0)
		end)
	end)
end
