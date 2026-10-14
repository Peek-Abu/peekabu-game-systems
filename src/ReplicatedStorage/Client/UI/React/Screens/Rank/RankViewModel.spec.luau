local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankViewModel = require(script.Parent.RankViewModel)

local function line(userId, extra)
	local entry = { userId = userId, name = `P{userId}`, banked = 0, piles = 0, salvage = 0, caught = 0 }
	for key, value in extra or {} do
		entry[key] = value
	end
	return entry
end

local function results(lines, quotaMet)
	return {
		outcome = "clockout",
		quota = 100,
		cleared = 100,
		bonus = 0,
		salvage = 0,
		piles = 0,
		catches = 0,
		offered = 0,
		rating = "satisfactory",
		quotaMet = quotaMet,
		crew = lines,
		awards = {},
	}
end

local function entry(xp, prev)
	return { [RankConstants.PUBLIC_XP_FIELD] = xp, [RankConstants.PUBLIC_PREV_XP_FIELD] = prev }
end

return function()
	describe("rankOf", function()
		it("reads a player's XP from their public entry", function()
			local rank = RankViewModel.rankOf({ ["5"] = entry(60, 30) }, 5)
			expect(rank.xp).to.equal(60)
			expect(rank.prevXp).to.equal(30)
		end)

		it("is nil when the entry or the field is missing or malformed", function()
			expect(RankViewModel.rankOf({}, 5)).to.equal(nil)
			expect(RankViewModel.rankOf({ ["5"] = {} }, 5)).to.equal(nil)
			expect(RankViewModel.rankOf({ ["5"] = { [RankConstants.PUBLIC_XP_FIELD] = "60" } }, 5)).to.equal(nil)
		end)

		it("reads an absent previous XP as the current XP", function()
			expect(RankViewModel.rankOf({ ["5"] = entry(60) }, 5).prevXp).to.equal(60)
		end)
	end)

	describe("tag", function()
		it("shows the name, the rank and the lanyard colour", function()
			local view = RankViewModel.tag({ xp = 45, prevXp = 45 }, "Ava")
			expect(view.name).to.equal("Ava")
			expect(view.rank).to.equal("Probationary Associate")
			expect(view.level).to.equal("CL-2")
			expect(typeof(view.lanyard)).to.equal("Color3")
		end)

		it("is nil until the rank is known", function()
			expect(RankViewModel.tag(nil, "Ava")).to.equal(nil)
		end)
	end)

	describe("slip", function()
		it("shows the level, the bar, the XP and what unlocks next", function()
			local view = RankViewModel.slip({ xp = 60, prevXp = 60 }, nil, {}, 1)
			expect(view.heading).to.equal("CLEARANCE LEVEL 2")
			expect(view.rank).to.equal("PROBATIONARY ASSOCIATE")
			expect(view.fill).to.equal(0.25)
			expect(view.xpText).to.equal("60 / 120 XP")
			expect(view.next).to.equal("Next: Clearance Associate (blue lanyard) at 120 XP")
			expect(view.gain).to.equal(nil)
			expect(view.promoted).to.equal(false)
		end)

		it("breaks down this shift's XP from the review", function()
			local review = results({ line(1, { items = 3 }) }, true)
			local view = RankViewModel.slip({ xp = 38, prevXp = 0 }, review, { 1 }, 1)
			expect(view.gain).to.equal("+38 XP this shift")
			expect(view.breakdown).to.equal("Shift +10 · Quota +15 · Cargo +3 · Clocked out +5 · Whole crew out +5")
			expect(view.incident).to.equal(nil)
		end)

		it("stamps PROMOTED once the award that crossed a level has landed", function()
			local review = results({ line(1) }, true)
			local landed = RankViewModel.slip({ xp = 45, prevXp = 10 }, review, { 1 }, 1)
			expect(landed.promoted).to.equal(true)
			local pending = RankViewModel.slip({ xp = 45, prevXp = 45 }, review, { 1 }, 1)
			expect(pending.promoted).to.equal(false)
		end)

		it("files an incident report for a caught player", function()
			local review = results({ line(1, { caught = 1 }) }, false)
			local view = RankViewModel.slip({ xp = 10, prevXp = 0 }, review, { 1 }, 1)
			expect(view.incident).to.equal("Incident Report filed")
			expect(view.gain).to.equal("+10 XP this shift")
		end)

		it("says so at the top of the ladder", function()
			local view = RankViewModel.slip({ xp = 10 ^ 6, prevXp = 10 ^ 6 }, nil, {}, 1)
			expect(view.fill).to.equal(1)
			expect(view.next).to.equal("Top of the ladder (for now)")
		end)

		it("is nil until the rank is known", function()
			expect(RankViewModel.slip(nil, nil, {}, 1)).to.equal(nil)
		end)
	end)
end
