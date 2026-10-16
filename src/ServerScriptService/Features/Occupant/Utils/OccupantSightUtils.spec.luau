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
end
