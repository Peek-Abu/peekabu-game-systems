local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantStareRules = require(script.Parent.OccupantStareRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function sitInput(extra)
	local value = { roll = 0, sitIns = 0, lastSitInAt = nil, now = 500, front = true, occupied = true }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("duration", function()
		it("rolls a known stare in STARE_SECONDS and a suspicion stare in SUSPECT_SECONDS", function()
			expect(OccupantStareRules.duration(false, 0)).to.equal(C.STARE_SECONDS.min)
			expect(OccupantStareRules.duration(false, 1)).to.equal(C.STARE_SECONDS.max)
			expect(OccupantStareRules.duration(true, 1)).to.equal(C.SUSPECT_SECONDS.max)
		end)
	end)

	describe("checkChance", function()
		it("grows with the seconds he had eyes on you", function()
			expect(OccupantStareRules.checkChance(0, false)).to.equal(C.CHECK_BASE)
			expect(OccupantStareRules.checkChance(2, false)).to.be.near(C.CHECK_BASE + 2 * C.CHECK_PER_SECOND)
		end)
		it("is higher when you went in close to him", function()
			expect(OccupantStareRules.checkChance(0, true)).to.be.near(C.CHECK_BASE + C.CHECK_CLOSE)
		end)
		it("is capped", function()
			expect(OccupantStareRules.checkChance(100, true)).to.equal(C.CHECK_MAX)
		end)
	end)

	describe("checks", function()
		it("always checks after a noise near the spot", function()
			expect(OccupantStareRules.checks({ watched = 0, close = false, noisy = true, roll = 0.999 })).to.equal(true)
		end)
		it("checks when the roll falls under the chance, else leaves", function()
			expect(OccupantStareRules.checks({ watched = 0, close = false, noisy = false, roll = 0.1 })).to.equal(true)
			expect(OccupantStareRules.checks({ watched = 0, close = false, noisy = false, roll = 0.5 })).to.equal(false)
		end)
	end)

	describe("sitsIn", function()
		it("sits in on a low roll at an occupied desk with a front chair", function()
			expect(OccupantStareRules.sitsIn(sitInput())).to.equal(true)
		end)
		it("never above the roll, without a hider, or without a front chair", function()
			expect(OccupantStareRules.sitsIn(sitInput({ roll = C.SIT_IN_CHANCE + 0.01 }))).to.equal(false)
			expect(OccupantStareRules.sitsIn(sitInput({ occupied = false }))).to.equal(false)
			expect(OccupantStareRules.sitsIn(sitInput({ front = false }))).to.equal(false)
		end)
		it("keeps it rare: a cap per shift and a gap", function()
			expect(OccupantStareRules.sitsIn(sitInput({ sitIns = C.SIT_IN_MAX }))).to.equal(false)
			expect(OccupantStareRules.sitsIn(sitInput({ sitIns = 1, lastSitInAt = 500 - C.SIT_IN_GAP + 1 }))).to.equal(
				false
			)
			expect(OccupantStareRules.sitsIn(sitInput({ sitIns = 1, lastSitInAt = 500 - C.SIT_IN_GAP }))).to.equal(true)
		end)
	end)

	describe("sitInCatches", function()
		it("catches after a noise; otherwise on the roll", function()
			expect(OccupantStareRules.sitInCatches(true, 0.99)).to.equal(true)
			expect(OccupantStareRules.sitInCatches(false, C.SIT_IN_CATCH - 0.01)).to.equal(true)
			expect(OccupantStareRules.sitInCatches(false, C.SIT_IN_CATCH + 0.01)).to.equal(false)
		end)
	end)

	describe("ambushes", function()
		it("springs on a noise, a sighting or a player close by", function()
			expect(OccupantStareRules.ambushes({ heard = true, seen = false, nearest = nil })).to.equal(true)
			expect(OccupantStareRules.ambushes({ heard = false, seen = true, nearest = nil })).to.equal(true)
			expect(OccupantStareRules.ambushes({ heard = false, seen = false, nearest = C.AMBUSH_RADIUS })).to.equal(
				true
			)
		end)
		it("stays seated otherwise", function()
			expect(OccupantStareRules.ambushes({ heard = false, seen = false, nearest = C.AMBUSH_RADIUS + 1 })).to.equal(
				false
			)
			expect(OccupantStareRules.ambushes({ heard = false, seen = false, nearest = nil })).to.equal(false)
		end)
	end)
end
