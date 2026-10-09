local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local RoundContainerUtils = require(script.Parent.RoundContainerUtils)

return function()
	beforeAll(function()
		ItemContentRegistry.init()
	end)

	describe("addStack", function()
		it("merges into an existing stack, then opens new stacks", function()
			local items = { { itemType = "scrap", quantity = 25 } }
			expect(RoundContainerUtils.addStack(items, "scrap", 10, 5)).to.equal(true)
			expect(#items).to.equal(2)
			expect(items[1].quantity).to.equal(30)
			expect(items[2].quantity).to.equal(5)
			expect(RoundContainerUtils.countOf(items, "scrap")).to.equal(35)
		end)

		it("refuses when the container is full and leaves it unchanged", function()
			local items = { { itemType = "scrap", quantity = 30 } }
			local ok, reason = RoundContainerUtils.addStack(items, "scrap", 1, 1)
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
			expect(#items).to.equal(1)
			expect(items[1].quantity).to.equal(30)
		end)

		it("honours the item's own maxStacks", function()
			local items = {}
			expect(RoundContainerUtils.addStack(items, "flare", 10, 20)).to.equal(true)
			expect((RoundContainerUtils.addStack(items, "flare", 1, 20))).to.equal(false)
		end)

		it("refuses a unique item, an unregistered item and a non-positive count", function()
			local items = {}
			expect((RoundContainerUtils.addStack(items, "wrench", 1, 20))).to.equal(false)
			expect((RoundContainerUtils.addStack(items, "no-such-item", 1, 20))).to.equal(false)
			expect((RoundContainerUtils.addStack(items, "scrap", 0, 20))).to.equal(false)
			expect((RoundContainerUtils.addStack(items, "scrap", 1.5, 20))).to.equal(false)
			expect(#items).to.equal(0)
		end)
	end)

	describe("addUnique", function()
		it("adds a unique entry with its uid and attrs", function()
			local items = {}
			expect(RoundContainerUtils.addUnique(items, "wrench", "r1-1", { durability = 3 }, 20)).to.equal(true)
			expect(items[1].uid).to.equal("r1-1")
			expect(items[1].attrs.durability).to.equal(3)
		end)

		it("refuses a duplicate uid, a stackable item, bad attrs or a full container", function()
			local items = { { itemType = "wrench", uid = "r1-1" } }
			expect((RoundContainerUtils.addUnique(items, "wrench", "r1-1", nil, 20))).to.equal(false)
			expect((RoundContainerUtils.addUnique(items, "scrap", "r1-2", nil, 20))).to.equal(false)
			expect((RoundContainerUtils.addUnique(items, "wrench", "r1-3", { bad = string.rep("x", 100) }, 20))).to.equal(
				false
			)
			expect((RoundContainerUtils.addUnique(items, "wrench", "r1-4", nil, 1))).to.equal(false)
			expect(#items).to.equal(1)
		end)
	end)

	describe("removeStack", function()
		it("takes from the last stacks first and drops emptied ones", function()
			local items = { { itemType = "scrap", quantity = 30 }, { itemType = "scrap", quantity = 5 } }
			expect(RoundContainerUtils.removeStack(items, "scrap", 10)).to.equal(true)
			expect(#items).to.equal(1)
			expect(items[1].quantity).to.equal(25)
		end)

		it("refuses to take more than there is, changing nothing", function()
			local items = { { itemType = "scrap", quantity = 3 } }
			expect((RoundContainerUtils.removeStack(items, "scrap", 4))).to.equal(false)
			expect(items[1].quantity).to.equal(3)
		end)
	end)

	describe("removeUnique", function()
		it("removes by uid", function()
			local items = { { itemType = "wrench", uid = "a" }, { itemType = "wrench", uid = "b" } }
			expect(RoundContainerUtils.removeUnique(items, "a")).to.equal(true)
			expect(#items).to.equal(1)
			expect(items[1].uid).to.equal("b")
			expect(RoundContainerUtils.removeUnique(items, "missing")).to.equal(false)
		end)
	end)
end
