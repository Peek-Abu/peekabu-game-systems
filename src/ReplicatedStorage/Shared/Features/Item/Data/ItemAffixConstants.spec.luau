local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemAffixConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemAffixConstants)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function()
	describe("POOLS", function()
		it("has weapon and armour pools, each non-empty", function()
			expect(ItemAffixConstants.POOLS.weapon).to.be.ok()
			expect(ItemAffixConstants.POOLS.armour).to.be.ok()
			expect(next(ItemAffixConstants.POOLS.weapon) ~= nil).to.equal(true)
			expect(next(ItemAffixConstants.POOLS.armour) ~= nil).to.equal(true)
		end)

		it("every affix targets a real StatConstants stat id with min <= max", function()
			for _, pool in ItemAffixConstants.POOLS do
				for _, def in pool do
					expect(StatConstants.isValidStatId(def.stat)).to.equal(true)
					expect(type(def.min)).to.equal("number")
					expect(type(def.max)).to.equal("number")
					expect(def.min <= def.max).to.equal(true)
					expect(type(def.displayName)).to.equal("string")
				end
			end
		end)
	end)

	describe("AFFIX_CHANCE", function()
		it("is a single flat probability in (0, 1] (rarity-independent)", function()
			expect(type(ItemAffixConstants.AFFIX_CHANCE)).to.equal("number")
			expect(ItemAffixConstants.AFFIX_CHANCE > 0 and ItemAffixConstants.AFFIX_CHANCE <= 1).to.equal(true)
		end)
	end)

	describe("get", function()
		it("returns a known affix definition", function()
			local def = ItemAffixConstants.get("warriors")
			expect(def).to.be.ok()
			expect(def.stat).to.equal("strength")
			expect(def.displayName).to.equal("Titan's")
		end)

		it("returns nil for a retired / unknown affixId", function()
			expect(ItemAffixConstants.get("not-a-real-affix")).to.equal(nil)
		end)
	end)

	describe("displayPrefix", function()
		it("returns nil for nil or empty affixes", function()
			expect(ItemAffixConstants.displayPrefix(nil)).to.equal(nil)
			expect(ItemAffixConstants.displayPrefix({})).to.equal(nil)
		end)

		it("returns the affix's displayName for a single known affix", function()
			expect(ItemAffixConstants.displayPrefix({ warriors = 2 })).to.equal("Titan's")
		end)

		it("returns nil when the only affix is retired", function()
			expect(ItemAffixConstants.displayPrefix({ ["retired-id"] = 2 })).to.equal(nil)
		end)

		it("is stable across repeated calls for a multi-affix map", function()
			local affixes = { warriors = 2, vigorous = 1 }
			local first = ItemAffixConstants.displayPrefix(affixes)
			for _ = 1, 5 do
				expect(ItemAffixConstants.displayPrefix(affixes)).to.equal(first)
			end
		end)
	end)
end
