local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemShared = ReplicatedStorage.Shared.Features.Item
local ItemAffixFormulas = require(ItemShared.Utils.ItemAffixFormulas)
local ItemAffixConstants = require(ItemShared.Data.ItemAffixConstants)
local ItemContentRegistry = require(ItemShared.Data.ItemContentRegistry)

-- Real fixtures: phoenix-blade (weapon, legendary), rusted-saw (weapon, common), chambered-helmet
-- (armour, epic) — all roll at the SAME flat AFFIX_CHANCE regardless of rarity; healing-tonic
-- (consumable) has no pool and never rolls.
ItemContentRegistry.init()

local function countHits(itemType: string, trials: number, seed: number): number
	local random = Random.new(seed)
	local hits = 0
	for _ = 1, trials do
		if ItemAffixFormulas.roll(itemType, random) ~= nil then
			hits += 1
		end
	end
	return hits
end

return function()
	describe("roll", function()
		it("never rolls an affix for an item kind with no pool", function()
			expect(countHits("healing-tonic", 500, 1)).to.equal(0)
		end)

		it("returns nil for an unregistered itemType", function()
			expect(ItemAffixFormulas.roll("not-a-real-item", Random.new(1))).to.equal(nil)
		end)

		it("hit rate is FLAT and rarity-independent — common and legendary both approximate AFFIX_CHANCE", function()
			local trials = 4000
			local expected = ItemAffixConstants.AFFIX_CHANCE
			-- Tolerance band, not an exact count — environment-robust like the currency subscription spec.
			local commonRate = countHits("rusted-saw", trials, 20250717) / trials -- common
			local legendaryRate = countHits("phoenix-blade", trials, 20250718) / trials -- legendary
			expect(commonRate > expected - 0.06 and commonRate < expected + 0.06).to.equal(true)
			expect(legendaryRate > expected - 0.06 and legendaryRate < expected + 0.06).to.equal(true)
		end)

		it("on a hit, returns exactly one weapon-pool affix with an in-range value", function()
			local random = Random.new(7)
			local result: { [string]: number }? = nil
			for _ = 1, 500 do
				result = ItemAffixFormulas.roll("phoenix-blade", random)
				if result then
					break
				end
			end
			expect(result).to.be.ok()

			local count = 0
			for affixId, value in result :: { [string]: number } do
				count += 1
				local def = ItemAffixConstants.POOLS.weapon[affixId]
				expect(def).to.be.ok()
				expect(value >= def.min and value <= def.max).to.equal(true)
				expect(value == math.floor(value)).to.equal(true)
			end
			expect(count).to.equal(1)
		end)

		it("produces varied outcomes across draws (independent rolls)", function()
			local random = Random.new(99)
			local seen: { [string]: boolean } = {}
			for _ = 1, 200 do
				local result = ItemAffixFormulas.roll("phoenix-blade", random)
				if result then
					for affixId, value in result do
						seen[`{affixId}:{value}`] = true
					end
				end
			end
			-- With two possible affixes and multiple values each, many draws must yield >1 distinct roll.
			local distinct = 0
			for _ in seen do
				distinct += 1
			end
			expect(distinct > 1).to.equal(true)
		end)
	end)
end
