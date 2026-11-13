local CosmeticCollectionRegistry = require(script.Parent.CosmeticCollectionRegistry)
local CosmeticRegistry = require(script.Parent.CosmeticRegistry)

return function()
	local all = CosmeticCollectionRegistry.all()

	it("lists unique Collection.* ids, sorted, over real items", function()
		expect(#all > 0).to.equal(true)
		for index, collection in all do
			expect(string.sub(collection.id, 1, 11)).to.equal("Collection.")
			expect(collection.name ~= "").to.equal(true)
			expect(#collection.items >= 2).to.equal(true)
			if index > 1 then
				expect(all[index - 1].id < collection.id).to.equal(true)
			end
			local seen = {}
			for _, id in collection.items do
				expect(seen[id]).never.to.be.ok()
				seen[id] = true
				expect(CosmeticRegistry.has(id)).to.equal(true)
			end
			expect(CosmeticCollectionRegistry.get(collection.id)).to.equal(collection)
		end
		expect(CosmeticCollectionRegistry.get("nope")).to.equal(nil)
	end)

	it("has Gloom-Touched: the 3 Gloom-Touched skins, across employees", function()
		local collection = CosmeticCollectionRegistry.get("Collection.GloomTouched")
		expect(collection).to.be.ok()
		expect(table.concat(collection.items, ",")).to.equal(
			"Pippa.GloomTouched,Cappy.GloomTouched,Prickles.GloomTouched"
		)
	end)

	it("keeps each Legendary set linked: skin, emote and sticker pack", function()
		local expected = {
			["Collection.BubbleBuddy"] = "Pippa.BubbleBuddy,Pippa.Bubbles,BubblePack,Pippa.BubbleBuddyIdle",
			["Collection.PJCappy"] = "Cappy.PJ,Cappy.CocoaSip,CozyPack,Cappy.PJIdle",
			["Collection.SheriffPrickles"] = "Prickles.Sheriff,Prickles.Lasso,SheriffPack,Prickles.SheriffIdle",
		}
		for id, items in expected do
			local collection = CosmeticCollectionRegistry.get(id)
			expect(collection).to.be.ok()
			expect(table.concat(collection.items, ",")).to.equal(items)
		end
	end)

	it("finds the collections an item is in", function()
		local found = CosmeticCollectionRegistry.containing("Cappy.GloomTouched")
		expect(#found).to.equal(1)
		expect(found[1].id).to.equal("Collection.GloomTouched")
		expect(#CosmeticCollectionRegistry.containing("nope")).to.equal(0)
	end)
end
