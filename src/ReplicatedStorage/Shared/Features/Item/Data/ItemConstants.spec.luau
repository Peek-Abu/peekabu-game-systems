local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)

return function()
	describe("ItemConstants", function()
		it("registers the six rarities including cursed", function()
			expect(#ItemConstants.RARITIES).to.equal(6)
			expect(table.find(ItemConstants.RARITIES, "cursed") ~= nil).to.equal(true)
		end)

		it("RARITIES is sorted", function()
			for index = 2, #ItemConstants.RARITIES do
				expect(ItemConstants.RARITIES[index - 1] < ItemConstants.RARITIES[index]).to.equal(true)
			end
		end)

		it("registers the four kinds", function()
			expect(#ItemConstants.KINDS).to.equal(4)
			expect(table.find(ItemConstants.KINDS, "weapon") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "armour") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "consumable") ~= nil).to.equal(true)
			expect(table.find(ItemConstants.KINDS, "misc") ~= nil).to.equal(true)
		end)

		it("KINDS is sorted", function()
			for index = 2, #ItemConstants.KINDS do
				expect(ItemConstants.KINDS[index - 1] < ItemConstants.KINDS[index]).to.equal(true)
			end
		end)

		it("validates rarities", function()
			expect(ItemConstants.isValidRarity("cursed")).to.equal(true)
			expect(ItemConstants.isValidRarity("mythic")).to.equal(false)
			expect(ItemConstants.isValidRarity("")).to.equal(false)
		end)

		it("validates kinds", function()
			expect(ItemConstants.isValidKind("weapon")).to.equal(true)
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

		it("has the provisional per-kind caps", function()
			expect(ItemConstants.KIND_CAPS.weapon).to.equal(30)
			expect(ItemConstants.KIND_CAPS.armour).to.equal(30)
			expect(ItemConstants.KIND_CAPS.consumable).to.equal(40)
			expect(ItemConstants.KIND_CAPS.misc).to.equal(40)
		end)
	end)
end
