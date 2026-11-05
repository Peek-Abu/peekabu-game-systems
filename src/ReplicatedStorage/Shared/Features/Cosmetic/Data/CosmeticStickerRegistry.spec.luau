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
	end)
end
