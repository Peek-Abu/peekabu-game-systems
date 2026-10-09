local LootRegistry = require(script.Parent.LootRegistry)

local function ensure(id, lootTable)
	if LootRegistry.get(id) == nil then
		LootRegistry.register(id, lootTable)
	end
end

return function()
	it("registers a table and returns it", function()
		ensure(
			"spec-chest",
			{ rolls = 2, entries = { { id = "coins", weight = 3, min = 5, max = 10 }, { nothing = true, weight = 1 } } }
		)
		expect(LootRegistry.get("spec-chest").rolls).to.equal(2)
		expect(#LootRegistry.get("spec-chest").entries).to.equal(2)
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup-loot", { entries = { { id = "a", weight = 1 } } })
		expect(function()
			LootRegistry.register("spec-dup-loot", { entries = { { id = "a", weight = 1 } } })
		end).to.throw()
	end)

	it("rejects bad tables", function()
		local bad = {
			{ entries = {} },
			{ entries = { { id = "a", weight = 0 } } },
			{ entries = { { weight = 1 } } },
			{ entries = { { id = "a", nothing = true, weight = 1 } } },
			{ entries = { { id = "a", weight = 1, min = 3, max = 2 } } },
			{ entries = { { id = "a", weight = 1, min = 0.5 } } },
			{ rolls = 0, entries = { { id = "a", weight = 1 } } },
		}
		for index, lootTable in bad do
			expect(function()
				LootRegistry.register(`spec-bad-loot-{index}`, lootTable)
			end).to.throw()
		end
	end)
end
