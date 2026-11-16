local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantNoticeRules = require(script.Parent.OccupantNoticeRules)
local OccupantBrainRules = require(script.Parent.OccupantBrainRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ROUTE = { Vector3.new(100, 0, 100), Vector3.new(150, 0, 100), Vector3.new(150, 0, 150) }
-- 110 studs down his look: past his near sight, inside his long cone.
local FAR = Vector3.new(170, 3, 60)

-- Harlow at (60, 3, 60) looking along +X, at os.clock 100, with his long sight.
local function senses(extra)
	local value = {
		position = Vector3.new(60, 3, 60),
		look = Vector3.new(1, 0, 0),
		now = 100,
		sightRange = OccupantConstants.SIGHT_RANGE,
		sightAngle = OccupantConstants.SIGHT_ANGLE,
		longRange = OccupantConstants.LONG_SIGHT_RANGE,
		longAngle = OccupantConstants.LONG_SIGHT_ANGLE,
		players = {},
		resting = false,
		route = ROUTE,
		restPoint = Vector3.new(200, 0, 200),
		zone = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) },
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function far(clear)
	return { { userId = 7, position = FAR, clear = clear ~= false } }
end

return function()
	describe("notice", function()
		it("is nil with nobody far down his cone", function()
			expect(OccupantNoticeRules.notice(OccupantBrainRules.newMind(1, 1, 0), senses())).to.equal(nil)
		end)

		it("is nil when he is not looking far (at a desk)", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.mode = "work"
			expect(OccupantNoticeRules.notice(mind, senses({ players = far() }))).to.equal(nil)
		end)

		it("starts the beat: he stops, his head turned to them", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			local step = OccupantNoticeRules.notice(mind, senses({ players = far() }))
			expect(step).to.be.ok()
			expect(step.mind.noticeId).to.equal(7)
			expect(step.mind.noticeSeconds).to.equal(0)
			expect(step.mind.point).to.equal(FAR)
			expect(step.mind.swivelUntil).to.be.near(100.3)
			expect(step.intent.kind).to.equal("idle")
			expect(mind.noticeId).to.equal(nil)
		end)

		it("counts the beat up by the time since his last think (at most 0.5 s)", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.noticeId = 7
			mind.noticeSeconds = 0.1
			mind.lastThink = 99.8
			local step = OccupantNoticeRules.notice(mind, senses({ players = far() }))
			expect(step.mind.mode).to.equal("patrol")
			expect(step.mind.noticeSeconds).to.be.near(0.3)
		end)

		it("chases once the beat is long enough for the distance, and drops the noticing", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.noticeId = 7
			mind.noticeSeconds = OccupantConstants.NOTICE_SECONDS.max
			mind.lastThink = 100
			local step = OccupantNoticeRules.notice(mind, senses({ players = far() }))
			expect(step.mind.mode).to.equal("chase")
			expect(step.mind.noticeId).to.equal(nil)
			expect(step.mind.noticeSeconds).to.equal(nil)
		end)
	end)

	describe("fade", function()
		it("returns the same mind when nothing is being noticed", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			expect(OccupantNoticeRules.fade(mind, senses())).to.equal(mind)
		end)

		it("falls back NOTICE_DECAY a second and keeps whom he was noticing", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.noticeId = 7
			mind.noticeSeconds = 1
			mind.lastThink = 99.9
			local faded = OccupantNoticeRules.fade(mind, senses())
			expect(faded.noticeSeconds).to.be.near(1 - 0.1 * OccupantConstants.NOTICE_DECAY)
			expect(faded.noticeId).to.equal(7)
			expect(mind.noticeSeconds).to.equal(1)
		end)

		it("drops the noticing at 0", function()
			local mind = OccupantBrainRules.newMind(1, 1, 0)
			mind.noticeId = 7
			mind.noticeSeconds = 0.1
			mind.lastThink = 99.5
			local faded = OccupantNoticeRules.fade(mind, senses())
			expect(faded.noticeSeconds).to.equal(0)
			expect(faded.noticeId).to.equal(nil)
		end)
	end)
end
