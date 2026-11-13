local CosmeticBundleRegistry = require(script.Parent.CosmeticBundleRegistry)
local CosmeticRegistry = require(script.Parent.CosmeticRegistry)
local CosmeticConstants = require(script.Parent.CosmeticConstants)

return function()
	local all = CosmeticBundleRegistry.all()

	it("lists unique Bundle.* ids, sorted, that are never catalogue ids", function()
		expect(#all > 0).to.equal(true)
		for index, bundle in all do
			expect(string.sub(bundle.id, 1, 7)).to.equal("Bundle.")
			expect(#bundle.id <= CosmeticConstants.MAX_ID_LENGTH).to.equal(true)
			expect(CosmeticRegistry.has(bundle.id)).to.equal(false)
			expect(bundle.name ~= "").to.equal(true)
			expect(bundle.lore ~= "").to.equal(true)
			if index > 1 then
				expect(all[index - 1].id < bundle.id).to.equal(true)
			end
			expect(CosmeticBundleRegistry.get(bundle.id)).to.equal(bundle)
			expect(CosmeticBundleRegistry.has(bundle.id)).to.equal(true)
		end
		expect(CosmeticBundleRegistry.get("Pippa.BubbleBuddy")).to.equal(nil)
		expect(CosmeticBundleRegistry.has("nope")).to.equal(false)
	end)

	it("holds 2 or more distinct, buyable-alone kinds of item: no stickers, no free defaults", function()
		for _, bundle in all do
			expect(#bundle.items >= 2).to.equal(true)
			local seen = {}
			for _, id in bundle.items do
				expect(seen[id]).never.to.be.ok()
				seen[id] = true
				local item = CosmeticRegistry.get(id)
				expect(item).to.be.ok()
				expect(item.kind).never.to.equal("sticker")
				expect(item.source).never.to.equal("default")
			end
			expect(bundle.currency == "gleam" or bundle.currency == "credits").to.equal(true)
			expect(bundle.price > 0 and bundle.price == math.floor(bundle.price)).to.equal(true)
		end
	end)

	it("has the 3 Legendary bundles: the skin first, then its emote and sticker pack", function()
		local expected = {
			["Bundle.BubbleBuddy"] = "Pippa.BubbleBuddy,Pippa.Bubbles,BubblePack",
			["Bundle.PJCappy"] = "Cappy.PJ,Cappy.CocoaSip,CozyPack",
			["Bundle.SheriffPrickles"] = "Prickles.Sheriff,Prickles.Lasso,SheriffPack",
		}
		for id, items in expected do
			local bundle = CosmeticBundleRegistry.get(id)
			expect(bundle).to.be.ok()
			expect(table.concat(bundle.items, ",")).to.equal(items)
			expect(bundle.rarity).to.equal("legendary")
			expect(bundle.currency).to.equal("gleam")
		end
	end)

	it("finds the bundles an item is in", function()
		local found = CosmeticBundleRegistry.containing("Cappy.CocoaSip")
		expect(#found).to.equal(1)
		expect(found[1].id).to.equal("Bundle.PJCappy")
		expect(#CosmeticBundleRegistry.containing("Cappy.Backstage")).to.equal(0)
		expect(#CosmeticBundleRegistry.containing("nope")).to.equal(0)
	end)

	it("is read-only", function()
		expect(function()
			all[1].price = 1
		end).to.throw()
		expect(function()
			table.insert(all[1].items, "Cappy")
		end).to.throw()
	end)
end
