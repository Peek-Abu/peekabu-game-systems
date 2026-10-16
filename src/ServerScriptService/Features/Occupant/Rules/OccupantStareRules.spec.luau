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
		it("is near-certain when he watched you crawl in up close", function()
			expect(OccupantStareRules.checkChance(0, 5)).to.equal(C.CHECK_NEAR_CHANCE)
			expect(OccupantStareRules.checkChance(0, C.CHECK_NEAR)).to.equal(C.CHECK_NEAR_CHANCE)
		end)
		it("falls with the distance he saw you go in from, to a mere suspicion far off", function()
			local mid = OccupantStareRules.checkChance(0, (C.CHECK_NEAR + C.CHECK_FAR) / 2)
			expect(mid).to.be.near((C.CHECK_NEAR_CHANCE + C.CHECK_FAR_CHANCE) / 2)
			expect(OccupantStareRules.checkChance(0, C.CHECK_FAR)).to.be.near(C.CHECK_FAR_CHANCE)
			expect(OccupantStareRules.checkChance(10, 90)).to.be.near(C.CHECK_FAR_CHANCE)
		end)
		it("grows with the seconds he had eyes on you, only up close, and is capped", function()
			expect(OccupantStareRules.checkChance(2, 0)).to.be.near(C.CHECK_NEAR_CHANCE + 2 * C.CHECK_PER_SECOND)
			expect(OccupantStareRules.checkChance(100, 0)).to.equal(C.CHECK_MAX)
		end)
	end)

	describe("suspicious", function()
		it("treats a hider he saw go in from CHECK_FAR or further as a suspicion (a short stare)", function()
			expect(OccupantStareRules.suspicious(nil)).to.equal(true)
			expect(OccupantStareRules.suspicious(C.CHECK_FAR)).to.equal(true)
			expect(OccupantStareRules.suspicious(C.CHECK_FAR - 1)).to.equal(false)
		end)
	end)

	describe("checks", function()
		it("always checks after a noise near the spot", function()
			expect(OccupantStareRules.checks({ watched = 0, entered = 90, noisy = true, roll = 0.999 })).to.equal(true)
		end)
		it("checks when the roll falls under the chance, else leaves", function()
			expect(OccupantStareRules.checks({ watched = 0, entered = 5, noisy = false, roll = 0.5 })).to.equal(true)
			expect(OccupantStareRules.checks({ watched = 0, entered = 60, noisy = false, roll = 0.5 })).to.equal(false)
		end)
		it("opens a secure cabinet only after a noise or when he saw you go in within OPEN_RADIUS", function()
			local close = { watched = 0, entered = C.OPEN_RADIUS, noisy = false, roll = 0, secure = true }
			expect(OccupantStareRules.checks(close)).to.equal(true)
			local far = { watched = 0, entered = C.OPEN_RADIUS + 1, noisy = false, roll = 0, secure = true }
			expect(OccupantStareRules.checks(far)).to.equal(false)
			local noisy = { watched = 0, entered = 90, noisy = true, roll = 0.99, secure = true }
			expect(OccupantStareRules.checks(noisy)).to.equal(true)
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
