--!strict
--[=[
	ShopRegistry: the Shop's offers, built from the catalogue (CosmeticRegistry) so a new priced item is on sale by
	itself: every item sold for Credits or Gleam with a price (stickers come in their pack) is one offer at its
	catalogue price. Employees are always listed, Legendary skins take turns in the Featured banner, everything
	else rotates through Today's picks (ShopRotationUtils). Event offers (dates) and real sales (`was`) are added
	here when the owner runs one; there are none yet.

	@class ShopRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Offer = ShopTypes.Offer

local function poolOf(item: CosmeticTypes.Item): ShopTypes.Pool
	if item.kind == "employee" then
		return "always"
	elseif item.kind == "skin" and item.rarity == "legendary" then
		return "featured"
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
table.sort(offers, function(a: Offer, b: Offer): boolean
	return a.id < b.id
end)
table.freeze(offers)

local ShopRegistry = {}

function ShopRegistry.get(id: string): Offer?
	return byId[id]
end

-- Every offer, sorted by id.
function ShopRegistry.all(): { Offer }
	return offers
end

return ShopRegistry
