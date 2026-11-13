--!strict
--[=[
	ShopRegistry: the Shop's offers, built from the catalogue (CosmeticRegistry) so a new priced item is on sale by
	itself: every item sold for Credits or Gleam with a price (stickers come in their pack) is one offer at its
	catalogue price, and every bundle (CosmeticBundleRegistry) is one offer of all its items at the bundle's price.
	Employees are always listed. Bundles, Legendary skins without a bundle and vacuum skins take turns in the Featured
	banner (owner, 2026-11-13: promote the bundle, not the skin alone; a skin with no bundle is still promoted);
	everything else, a bundled skin sold alone included, rotates through Today's picks (ShopRotationUtils). Event offers (dates) and real sales (`was`) are added
	here when the owner runs one; there are none yet. It also registers the Gleam bundles' developer products with the
	Marketplace (MarketplaceRegistry) at load.

	@class ShopRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Offer = ShopTypes.Offer

local function poolOf(item: CosmeticTypes.Item): ShopTypes.Pool
	if item.kind == "employee" then
		return "always"
	elseif item.kind == "vacuum" then
		return "featured"
	elseif item.kind == "skin" and item.rarity == "legendary" then
		return if #CosmeticBundleRegistry.containing(item.id) == 0 then "featured" else "picks"
	end
	return "picks"
end

local offers: { Offer } = {}
local byId: { [string]: Offer } = {}
for _, item in CosmeticRegistry.all() do
	local source = item.source
	local price = item.price
	if (source == "credits" or source == "gleam") and price ~= nil and item.kind ~= "sticker" then
		local offer: Offer = table.freeze({
			id = item.id,
			items = table.freeze({ item.id }),
			currency = source,
			price = price,
			pool = poolOf(item),
		})
		table.insert(offers, offer)
		byId[item.id] = offer
	end
end
-- Bundles are promoted in the Featured banner.
local BUNDLE_POOL: ShopTypes.Pool = "featured"
for _, bundle in CosmeticBundleRegistry.all() do
	assert(byId[bundle.id] == nil, `ShopRegistry: bundle {bundle.id} clashes with an offer`)
	local offer: Offer = table.freeze({
		id = bundle.id,
		items = bundle.items,
		currency = bundle.currency,
		price = bundle.price,
		pool = BUNDLE_POOL,
	})
	table.insert(offers, offer)
	byId[bundle.id] = offer
end
table.sort(offers, function(a: Offer, b: Offer): boolean
	return a.id < b.id
end)
table.freeze(offers)

-- The Gleam bundles with a product id are registered with the Marketplace at load, in both realms: the client prompts
-- by the same key the server grants by.
for _, bundle in ShopConstants.BUNDLES do
	local productId = ShopConstants.PRODUCT_IDS[bundle.key]
	if productId ~= nil and MarketplaceRegistry.product(bundle.key) == nil then
		MarketplaceRegistry.registerProduct(bundle.key, { productId = productId })
	end
end

local ShopRegistry = {}

function ShopRegistry.get(id: string): Offer?
	return byId[id]
end

-- Every offer, sorted by id.
function ShopRegistry.all(): { Offer }
	return offers
end

return ShopRegistry
