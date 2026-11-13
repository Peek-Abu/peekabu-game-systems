local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local ShopRegistry = require(script.Parent.ShopRegistry)

return function()
	it("sells every priced Credits or Gleam item in the catalogue, at its catalogue price", function()
		local count = 0
		for _, item in CosmeticRegistry.all() do
			local sold = (item.source == "credits" or item.source == "gleam")
				and item.price ~= nil
				and item.kind ~= "sticker"
			local offer = ShopRegistry.get(item.id)
			if sold then
				count += 1
				expect(offer).to.be.ok()
				expect(offer.price).to.equal(item.price)
				expect(offer.currency).to.equal(item.source)
				expect(offer.items[1]).to.equal(item.id)
			else
				expect(offer).to.equal(nil)
			end
		end
		expect(#ShopRegistry.all()).to.equal(count + #CosmeticBundleRegistry.all())
	end)

	it("sells every bundle as one offer of all its items, at the bundle's price, in the Featured banner", function()
		for _, bundle in CosmeticBundleRegistry.all() do
			local offer = ShopRegistry.get(bundle.id)
			expect(offer).to.be.ok()
			expect(table.concat(offer.items, ",")).to.equal(table.concat(bundle.items, ","))
			expect(offer.price).to.equal(bundle.price)
			expect(offer.currency).to.equal(bundle.currency)
			expect(offer.pool).to.equal("featured")
		end
	end)

	it("always lists employees, features bundles over their skins, and rotates the rest", function()
		expect(ShopRegistry.get("Prickles").pool).to.equal("always")
		-- A skin with a bundle is promoted as its bundle (owner, 2026-11-13); alone, it rotates with the rest.
		expect(ShopRegistry.get("Pippa.BubbleBuddy").pool).to.equal("picks")
		expect(ShopRegistry.get("Bundle.BubbleBuddy").pool).to.equal("featured")
		expect(ShopRegistry.get("Pippa.Bubbles").pool).to.equal("picks")
		expect(ShopRegistry.get("CozyPack").pool).to.equal("picks")
		expect(ShopRegistry.get("Vacuum.BrassBellows").pool).to.equal("featured")
		expect(ShopRegistry.get("Vacuum.StandardIssue")).never.to.be.ok()
	end)

	it("never carries an invented old price", function()
		for _, offer in ShopRegistry.all() do
			expect(offer.was).to.equal(nil)
		end
	end)

	it("registers every Gleam bundle that has a product id with the Marketplace", function()
		local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
		local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
		for _, bundle in ShopConstants.BUNDLES do
			local id = ShopConstants.PRODUCT_IDS[bundle.key]
			if id ~= nil then
				expect(MarketplaceRegistry.product(bundle.key).productId).to.equal(id)
			end
		end
	end)

	it("lists offers in a stable order", function()
		local all = ShopRegistry.all()
		for index = 2, #all do
			expect(all[index - 1].id < all[index].id).to.equal(true)
		end
	end)
end
