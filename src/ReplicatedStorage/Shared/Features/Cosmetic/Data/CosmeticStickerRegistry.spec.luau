local CosmeticConstants = require(script.Parent.CosmeticConstants)
local CosmeticStickerRegistry = require(script.Parent.CosmeticStickerRegistry)

return function()
	describe("CosmeticStickerRegistry", function()
		it("holds only sticker packs and stickers, each sticker in a pack listed here", function()
			local packs = {}
			for _, item in CosmeticStickerRegistry do
				expect(item.kind == "stickerPack" or item.kind == "sticker").to.equal(true)
				if item.kind == "stickerPack" then
					packs[item.id] = true
				end
			end
			for _, item in CosmeticStickerRegistry do
				if item.kind == "sticker" then
					expect(item.pack ~= nil and packs[item.pack] == true).to.equal(true)
				end
			end
		end)

		it("prices and rates each pack by its sticker count, and gives each sticker its pack's rarity", function()
			local counts, rarity = {}, {}
			for _, item in CosmeticStickerRegistry do
				if item.kind == "stickerPack" then
					rarity[item.id] = item.rarity
				end
			end
			for _, item in CosmeticStickerRegistry do
				if item.kind == "sticker" then
					counts[item.pack] = (counts[item.pack] or 0) + 1
					expect(item.rarity).to.equal(rarity[item.pack])
				end
			end
			for _, item in CosmeticStickerRegistry do
				if item.kind == "stickerPack" then
					local rule = CosmeticConstants.STICKER_PACKS[counts[item.id] or 0]
					expect(rule).to.be.ok()
					expect(item.rarity).to.equal(rule.rarity)
					expect(item.price).to.equal(rule.price)
				end
			end
		end)
	end)
end
