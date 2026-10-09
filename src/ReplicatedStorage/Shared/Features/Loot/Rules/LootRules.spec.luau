local LootRules = require(script.Parent.LootRules)

-- A random source that returns the given numbers in order (then repeats the last).
local function sequence(...)
	local values = { ... }
	local index = 0
	return function()
		index = math.min(index + 1, #values)
		return values[index]
	end
end

local TABLE = {
	entries = {
		{ id = "common", weight = 7 },
		{ id = "rare", weight = 2, min = 1, max = 3 },
		{ nothing = true, weight = 1 },
	},
}

return function()
	describe("pick", function()
		it("maps the roll across the cumulative weights", function()
			expect(LootRules.pick(TABLE.entries, 0).id).to.equal("common")
			expect(LootRules.pick(TABLE.entries, 0.69).id).to.equal("common")
			expect(LootRules.pick(TABLE.entries, 0.75).id).to.equal("rare")
			expect(LootRules.pick(TABLE.entries, 0.95).nothing).to.equal(true)
		end)
	end)

	describe("roll", function()
		it("returns one drop per roll, counting min..max", function()
			local drops = LootRules.roll(TABLE, sequence(0.8, 0.99))
			expect(#drops).to.equal(1)
			expect(drops[1].id).to.equal("rare")
			expect(drops[1].count).to.equal(3)
		end)

		it("drops nothing on a nothing entry", function()
			expect(#LootRules.roll(TABLE, sequence(0.95))).to.equal(0)
		end)

		it("merges repeated ids across rolls", function()
			local several = { rolls = 3, entries = { { id = "coin", weight = 1, min = 2, max = 2 } } }
			local drops = LootRules.roll(several, sequence(0.1))
			expect(#drops).to.equal(1)
			expect(drops[1].count).to.equal(6)
		end)

		it("keeps the expected proportions over many rolls", function()
			local rng = Random.new(42)
			local counts = { common = 0, rare = 0 }
			for _ = 1, 5000 do
				for _, drop in
					LootRules.roll(TABLE, function()
						return rng:NextNumber()
					end)
				do
					counts[drop.id] += 1
				end
			end
			expect(math.abs(counts.common / 5000 - 0.7) < 0.03).to.equal(true)
			expect(math.abs(counts.rare / 5000 - 0.2) < 0.03).to.equal(true)
		end)
	end)

	describe("chances", function()
		it("lists each outcome's probability", function()
			local chances = LootRules.chances(TABLE)
			expect(math.abs(chances.common - 0.7) < 1e-9).to.equal(true)
			expect(math.abs(chances.rare - 0.2) < 1e-9).to.equal(true)
			expect(chances.nothing).to.equal(nil)
		end)
	end)
end
