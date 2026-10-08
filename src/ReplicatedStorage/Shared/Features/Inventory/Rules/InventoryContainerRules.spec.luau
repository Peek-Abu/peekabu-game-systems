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
				{ itemType = "scrap", quantity = 10 },
				{ itemType = "scrap", quantity = 5 },
				{ itemType = "wrench", uid = "u1" },
				{ itemType = "golden-wrench", uid = "u2" },
			}
			local ok, reason, result = InventoryContainerRules.checkEntryShapes(items, "stash")
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			assert(result, "result on success")
			expect(result.kindCounts.misc).to.equal(2)
			expect(result.kindCounts.tool).to.equal(2)
			expect(result.stackCountsByType.scrap).to.equal(2)
		end)

		it("uses the given label in messages", function()
			local ok, reason = InventoryContainerRules.checkEntryShapes("nope" :: any, "stash")
			expect(ok).to.equal(false)
			expect((reason :: string):find("stash.items must be a table", 1, true)).to.be.ok()
		end)

		it("rejects an unregistered itemType", function()
			local ok = InventoryContainerRules.checkEntryShapes({ { itemType = "not-real", uid = "u1" } }, "stash")
			expect(ok).to.equal(false)
		end)

		it("rejects a stackable entry carrying a uid", function()
			local ok = InventoryContainerRules.checkEntryShapes(
				{ { itemType = "scrap", quantity = 1, uid = "u1" } :: any },
				"stash"
			)
			expect(ok).to.equal(false)
		end)

		it("rejects a unique entry carrying a quantity", function()
			local ok = InventoryContainerRules.checkEntryShapes(
				{ { itemType = "wrench", uid = "u1", quantity = 1 } :: any },
				"stash"
			)
			expect(ok).to.equal(false)
		end)

		it("rejects a duplicate uid", function()
			local ok = InventoryContainerRules.checkEntryShapes({
				{ itemType = "wrench", uid = "dup" },
				{ itemType = "golden-wrench", uid = "dup" },
			}, "stash")
			expect(ok).to.equal(false)
		end)

		it("accepts a unique entry carrying well-formed attrs", function()
			local ok = InventoryContainerRules.checkEntryShapes({
				{ itemType = "wrench", uid = "u1", attrs = { level = 3, nickname = "Old Faithful" } },
			}, "stash")
			expect(ok).to.equal(true)
		end)

		it("rejects a unique entry with a malformed attr value (attrs validation applied)", function()
			local bad = { itemType = "wrench", uid = "u1", attrs = { level = true } } :: any
			local ok, reason = InventoryContainerRules.checkEntryShapes({ bad }, "stash")
			expect(ok).to.equal(false)
			expect((reason :: string):find("stash.items[1]", 1, true)).to.be.ok()
		end)

		it("rejects a unique entry with an over-long string attr", function()
			local bad = { itemType = "wrench", uid = "u1", attrs = { nickname = string.rep("a", 65) } }
			local ok = InventoryContainerRules.checkEntryShapes({ bad }, "stash")
			expect(ok).to.equal(false)
		end)

		it("rejects exceeding a stackable's maxStacks", function()
			-- flare declares maxStacks = 1; two stacks of it must fail.
			local ok = InventoryContainerRules.checkEntryShapes({
				{ itemType = "flare", quantity = 1 },
				{ itemType = "flare", quantity = 1 },
			}, "stash")
			expect(ok).to.equal(false)
		end)
	end)

	describe("stackLimitsOf", function()
		it("returns a stackable definition's stackMax and maxStacks", function()
			local stackMax, maxStacks = InventoryContainerRules.stackLimitsOf({
				name = "Flare",
				rarity = "common",
				kind = "consumable",
				stackMax = 10,
				maxStacks = 1,
			})
			expect(stackMax).to.equal(10)
			expect(maxStacks).to.equal(1)
		end)

		it("throws on a definition without stackMax (a unique item)", function()
			expect(function()
				InventoryContainerRules.stackLimitsOf({ name = "Wrench", rarity = "common", kind = "tool" })
			end).to.throw()
		end)
	end)
end
