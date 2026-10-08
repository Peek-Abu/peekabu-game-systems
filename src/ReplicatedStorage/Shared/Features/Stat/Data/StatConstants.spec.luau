local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function()
	describe("StatConstants", function()
		it("registers the eight launch stats", function()
			expect(#StatConstants.STAT_IDS).to.equal(8)
		end)

		it("every definition has a valid pool, base, and perPoint", function()
			for _, def in StatConstants.DEFINITIONS do
				expect(def.pool == "main" or def.pool == "sub").to.equal(true)
				expect(type(def.base)).to.equal("number")
				expect(type(def.perPoint)).to.equal("number")
			end
		end)

		it("validates stat ids", function()
			expect(StatConstants.isValidStatId("health")).to.equal(true)
			expect(StatConstants.isValidStatId("mana")).to.equal(false) -- dropped from the old game
			expect(StatConstants.isValidStatId("")).to.equal(false)
		end)

		it("STAT_IDS is sorted and matches DEFINITIONS exactly", function()
			local count = 0
			for _ in StatConstants.DEFINITIONS do
				count += 1
			end
			expect(#StatConstants.STAT_IDS).to.equal(count)
			for index = 2, #StatConstants.STAT_IDS do
				expect(StatConstants.STAT_IDS[index - 1] < StatConstants.STAT_IDS[index]).to.equal(true)
			end
		end)

		it("exposes the provisional tuning constants", function()
			expect(StatConstants.MAX_LEVEL).to.equal(30)
			expect(StatConstants.XP_PER_LEVEL_FACTOR).to.equal(25)
			expect(StatConstants.POINTS_PER_LEVEL.main).to.equal(1)
			expect(StatConstants.POINTS_PER_LEVEL.sub).to.equal(3)
		end)
	end)
end
