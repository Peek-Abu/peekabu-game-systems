local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryContainerRules = require(ReplicatedStorage.Shared.Features.Inventory.Rules.InventoryContainerRules)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

return function()
	beforeAll(function()
		ItemContentRegistry.init()
	end)

	describe("checkEntryShapes", function()
		it("accepts a well-formed mix of stacks and uniques, returning counts", function()
			local items: { PlayerDataTypes.InventoryEntry } = {
				{ itemType = "wood", quantity = 10 },
				{ itemType = "wood", quantity = 5 },
				{ itemType = "rusted-saw", uid = "u1" },
				{ itemType = "phoenix-blade", uid = "u2" },
			}
			local ok, reason, result = InventoryContainerRules.checkEntryShapes(items, "bank")
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			assert(result, "result on success")
			expect(result.kindCounts.misc).to.equal(2)
			expect(result.kindCounts.weapon).to.equal(2)
			expect(result.stackCountsByType.wood).to.equal(2)
		end)

		it("uses the given label in messages", function()
			local ok, reason = InventoryContainerRules.checkEntryShapes("nope" :: any, "bank")
			expect(ok).to.equal(false)
			expect((reason :: string):find("bank.items must be a table", 1, true)).to.be.ok()
		end)

		it("rejects an unregistered itemType", function()
			local ok = InventoryContainerRules.checkEntryShapes({ { itemType = "not-real", uid = "u1" } }, "bank")
			expect(ok).to.equal(false)
		end)

		it("rejects a stackable entry carrying a uid", function()
			local ok = InventoryContainerRules.checkEntryShapes(
				{ { itemType = "wood", quantity = 1, uid = "u1" } :: any },
				"bank"
			)
			expect(ok).to.equal(false)
		end)

		it("rejects a unique entry carrying a quantity", function()
			local ok = InventoryContainerRules.checkEntryShapes(
				{ { itemType = "rusted-saw", uid = "u1", quantity = 1 } :: any },
				"bank"
			)
			expect(ok).to.equal(false)
		end)

		it("rejects a duplicate uid", function()
			local ok = InventoryContainerRules.checkEntryShapes({
				{ itemType = "rusted-saw", uid = "dup" },
				{ itemType = "phoenix-blade", uid = "dup" },
			}, "bank")
			expect(ok).to.equal(false)
		end)

		it("rejects a unique entry with a malformed affix value (modifier validation preserved)", function()
			local bad = { itemType = "rusted-saw", uid = "u1", affixes = { warriors = "big" } } :: any
			local ok = InventoryContainerRules.checkEntryShapes({ bad }, "bank")
			expect(ok).to.equal(false)
		end)

		it("rejects exceeding a stackable's maxStacks", function()
			-- throwing-knife declares maxStacks = 1; two stacks of it must fail.
			local ok = InventoryContainerRules.checkEntryShapes({
				{ itemType = "throwing-knife", quantity = 1 },
				{ itemType = "throwing-knife", quantity = 1 },
			}, "bank")
			expect(ok).to.equal(false)
		end)
	end)
end
