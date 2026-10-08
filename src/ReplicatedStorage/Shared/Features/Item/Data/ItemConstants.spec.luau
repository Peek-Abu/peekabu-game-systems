local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)

return function()
	describe("ItemConstants", function()
		it("registers the five rarities", function()
			expect(#ItemConstants.RARITIES).to.equal(5)
			expect(table.find(ItemConstants.RARITIES, "common") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.RARITIES, "uncommon") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.RARITIES, "rare") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.RARITIES, "epic") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.RARITIES, "legendary") ~= nil).to.equal(true)
		end)

		it("RARITIES is sorted", function()
			for index = 2, #ItemConstants.RARITIES do
				expect(ItemConstants.RARITIES[index - 1] < ItemConstants.RARITIES[index]).to.equal(true)
			end
		end)

		it("registers the four kinds", function()
			expect(#ItemConstants.KINDS).to.equal(4)
			expect(table.find(ItemConstants.KINDS, "tool") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "wearable") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "consumable") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "misc") ~= nil).to.equal(true)
		end)

		it("KINDS is sorted", function()
			for index = 2, #ItemConstants.KINDS do
				expect(ItemConstants.KINDS[index - 1] < ItemConstants.KINDS[index]).to.equal(true)
			end
		end)

		it("validates rarities", function()
			expect(ItemConstants.isValidRarity("legendary")).to.equal(true)
			expect(ItemConstants.isValidRarity("common")).to.equal(true)
			expect(ItemConstants.isValidRarity("mythic")).to.equal(false)
			expect(ItemConstants.isValidRarity("cursed")).to.equal(false)
			expect(ItemConstants.isValidRarity("")).to.equal(false)
		end)

		it("validates kinds", function()
			expect(ItemConstants.isValidKind("tool")).to.equal(true)
			expect(ItemConstants.isValidKind("wearable")).to.equal(true)
			expect(ItemConstants.isValidKind("consumable")).to.equal(true)
			expect(ItemConstants.isValidKind("misc")).to.equal(true)
			expect(ItemConstants.isValidKind("weapon")).to.equal(false)
			expect(ItemConstants.isValidKind("legendary-tool")).to.equal(false)
			expect(ItemConstants.isValidKind("")).to.equal(false)
		end)

		it("every KIND_CAPS key is a valid kind with a positive integer cap", function()
			local count = 0
			for kind, cap in ItemConstants.KIND_CAPS do
				count += 1
				expect(ItemConstants.isValidKind(kind)).to.equal(true)
				expect(type(cap)).to.equal("number")
				expect(cap > 0).to.equal(true)
				expect(cap % 1 == 0).to.equal(true)
			end
			expect(count).to.equal(4)
		end)

		it("has the placeholder per-kind caps", function()
			expect(ItemConstants.KIND_CAPS.tool).to.equal(30)
			expect(ItemConstants.KIND_CAPS.wearable).to.equal(30)
			expect(ItemConstants.KIND_CAPS.consumable).to.equal(40)
			expect(ItemConstants.KIND_CAPS.misc).to.equal(40)
		end)
	end)
end
