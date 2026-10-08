local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function()
	describe("StatFormulas", function()
		describe("levelOf / xpForLevel", function()
			it("starts at level 1 with zero xp", function()
				expect(StatFormulas.xpForLevel(1)).to.equal(0)
				expect(StatFormulas.levelOf(0)).to.equal(1)
			end)

			it("levels up at exactly the threshold (level 1 -> 2 at 25 xp)", function()
				expect(StatFormulas.levelOf(24)).to.equal(1)
				expect(StatFormulas.levelOf(25)).to.equal(2)
			end)

			it("xpForLevel and levelOf are mutual inverses at EVERY level boundary", function()
				for level = 1, StatConstants.MAX_LEVEL do
					local threshold = StatFormulas.xpForLevel(level)
					expect(StatFormulas.levelOf(threshold)).to.equal(level)
					if threshold > 0 then
						expect(StatFormulas.levelOf(threshold - 1)).to.equal(level - 1)
					end
				end
			end)

			it("clamps at MAX_LEVEL", function()
				expect(StatFormulas.levelOf(math.huge)).to.equal(StatConstants.MAX_LEVEL)
				expect(StatFormulas.levelOf(StatFormulas.maxTotalXp() + 1e6)).to.equal(StatConstants.MAX_LEVEL)
			end)

			it("a single grant crossing SEVERAL levels lands on the right level", function()
				-- 0 xp + 160 xp: 25 (->2) + 50 (->3) + 75 (->4) = 150, with 10 into level 4.
				expect(StatFormulas.levelOf(160)).to.equal(4)
				local progress = StatFormulas.progress(160)
				expect(progress.level).to.equal(4)
				expect(progress.xpIntoLevel).to.equal(10)
				expect(progress.xpToNext).to.equal(4 * StatConstants.XP_PER_LEVEL_FACTOR)
			end)

			it("progress reports nil xpToNext at max level", function()
				expect(StatFormulas.progress(StatFormulas.maxTotalXp()).xpToNext).to.never.be.ok()
			end)
		end)

		describe("point pools", function()
			it("level 1 has earned nothing", function()
				local earned = StatFormulas.pointsEarned(1)
				expect(earned.main).to.equal(0)
				expect(earned.sub).to.equal(0)
			end)

			it("earns per level from the config", function()
				local earned = StatFormulas.pointsEarned(5)
				expect(earned.main).to.equal(4 * StatConstants.POINTS_PER_LEVEL.main)
				expect(earned.sub).to.equal(4 * StatConstants.POINTS_PER_LEVEL.sub)
			end)

			it("spent sums per pool", function()
				local spent = StatFormulas.pointsSpent({ health = 2, stamina = 1, rotEndurance = 3 })
				expect(spent.main).to.equal(3)
				expect(spent.sub).to.equal(3)
			end)

			it("unspent = earned - spent", function()
				local totalXp = StatFormulas.xpForLevel(5) -- level 5: earned 4 main / 12 sub
				local unspent = StatFormulas.pointsUnspent(totalXp, { health = 3, strength = 2 })
				expect(unspent.main).to.equal(1)
				expect(unspent.sub).to.equal(10)
			end)
		end)

		describe("derive", function()
			it("returns base values for an empty build", function()
				local derived = StatFormulas.derive({})
				expect(derived.health).to.equal(200)
				expect(derived.stamina).to.equal(100)
				expect(derived.rotEndurance).to.equal(1)
			end)

			it("adds perPoint per invested point", function()
				local derived = StatFormulas.derive({ health = 3, rotEndurance = 2 })
				expect(derived.health).to.equal(200 + 3 * 5)
				expect(derived.rotEndurance).to.equal(1 + 2 * 1)
			end)

			it("covers EVERY registered stat, invested or not", function()
				local derived = StatFormulas.derive({})
				for _, id in StatConstants.STAT_IDS do
					expect(type(derived[id])).to.equal("number")
				end
			end)

			it("with no sources argument, behaves exactly as before", function()
				local derived = StatFormulas.derive({ health = 2 })
				expect(derived.health).to.equal(
					StatConstants.DEFINITIONS.health.base + 2 * StatConstants.DEFINITIONS.health.perPoint
				)
			end)

			it("adds a single source's contribution on top of the derived base", function()
				local derived = StatFormulas.derive({ health = 2 }, { { health = 10 } })
				expect(derived.health).to.equal(
					StatConstants.DEFINITIONS.health.base + 2 * StatConstants.DEFINITIONS.health.perPoint + 10
				)
			end)

			it("sums MULTIPLE sources for the same stat id", function()
				local derived = StatFormulas.derive({}, { { health = 5 }, { health = 3 } })
				expect(derived.health).to.equal(StatConstants.DEFINITIONS.health.base + 5 + 3)
			end)

			it("ignores an unknown stat id in a source rather than erroring", function()
				expect(function()
					StatFormulas.derive({}, { { notARealStat = 100 } })
				end).never.to.throw()
			end)

			it("a source can contribute to a stat the player has zero investment in", function()
				local derived = StatFormulas.derive({}, { { stamina = 7 } })
				expect(derived.stamina).to.equal(StatConstants.DEFINITIONS.stamina.base + 7)
			end)
		end)
	end)
end
