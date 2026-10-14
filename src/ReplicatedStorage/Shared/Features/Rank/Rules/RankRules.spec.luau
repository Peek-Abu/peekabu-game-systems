local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankRules = require(script.Parent.RankRules)

return function()
	describe("fresh", function()
		it("is level 1 with 0 XP in the given season, never awarded", function()
			local state = RankRules.fresh("s1")
			expect(state.season).to.equal("s1")
			expect(state.xp).to.equal(0)
			expect(state.lastAwardedRunId).to.equal("")
		end)
	end)

	describe("reconcileSeason", function()
		it("keeps a rank from the current season", function()
			local state = { season = "s1", xp = 50, lastAwardedRunId = "a:1" }
			expect(RankRules.reconcileSeason(state, "s1")).to.equal(false)
			expect(state.xp).to.equal(50)
		end)

		it("resets a rank from another season to level 1 / 0 XP", function()
			local state = { season = "s0", xp = 500, lastAwardedRunId = "a:1" }
			expect(RankRules.reconcileSeason(state, "s1")).to.equal(true)
			expect(state.season).to.equal("s1")
			expect(state.xp).to.equal(0)
			expect(state.lastAwardedRunId).to.equal("")
		end)
	end)

	describe("applyAward", function()
		it("adds the gain once per run", function()
			local state = RankRules.fresh("s1")
			expect(RankRules.applyAward(state, "srv:1", 35)).to.equal(true)
			expect(state.xp).to.equal(35)
			expect(state.lastAwardedRunId).to.equal("srv:1")
			expect(RankRules.applyAward(state, "srv:1", 35)).to.equal(false)
			expect(state.xp).to.equal(35)
			expect(RankRules.applyAward(state, "srv:2", 10)).to.equal(true)
			expect(state.xp).to.equal(45)
		end)

		it("refuses an empty run id, a negative or fractional gain", function()
			local state = RankRules.fresh("s1")
			expect(RankRules.applyAward(state, "", 5)).to.equal(false)
			expect(RankRules.applyAward(state, "r", -5)).to.equal(false)
			expect(RankRules.applyAward(state, "r", 1.5)).to.equal(false)
			expect(state.xp).to.equal(0)
		end)

		it("caps XP at MAX_XP (rank never goes down)", function()
			local state = { season = "s1", xp = RankConstants.MAX_XP - 1, lastAwardedRunId = "" }
			expect(RankRules.applyAward(state, "r", 50)).to.equal(true)
			expect(state.xp).to.equal(RankConstants.MAX_XP)
		end)
	end)

	describe("validate", function()
		it("accepts a well-formed rank", function()
			expect(RankRules.validate(RankRules.fresh("mvp-1"))).to.equal(true)
			expect(RankRules.validate({ season = "mvp-1", xp = 120, lastAwardedRunId = "abc:3" })).to.equal(true)
		end)

		it("rejects malformed fields", function()
			expect(RankRules.validate({ season = "", xp = 0, lastAwardedRunId = "" })).to.equal(false)
			expect(RankRules.validate({ season = "s", xp = -1, lastAwardedRunId = "" })).to.equal(false)
			expect(RankRules.validate({ season = "s", xp = 1.5, lastAwardedRunId = "" })).to.equal(false)
			expect(RankRules.validate({ season = "s", xp = RankConstants.MAX_XP + 1, lastAwardedRunId = "" })).to.equal(
				false
			)
			expect(RankRules.validate({ season = "s", xp = 0, lastAwardedRunId = 5 })).to.equal(false)
			expect(RankRules.validate({
				season = "s",
				xp = 0,
				lastAwardedRunId = string.rep("x", RankConstants.MAX_RUN_ID_LENGTH + 1),
			})).to.equal(false)
			expect(RankRules.validate({
				season = string.rep("x", RankConstants.MAX_SEASON_LENGTH + 1),
				xp = 0,
				lastAwardedRunId = "",
			})).to.equal(false)
		end)
	end)
end
