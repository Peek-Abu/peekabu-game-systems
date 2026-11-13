--!strict
--[=[
	ShopPriceRules: what one player pays for an offer. A single item costs its price. A bundle costs its price, with
	its items' prices alone crossed out (`was`) when that is more. A bundle the player already owns part of costs only
	the part they don't have, at the bundle's own discount (owner, 11-13): bundle price × (the missing items' regular
	prices ÷ all its items' regular prices), rounded up to ShopConstants.PRICE_STEP. It is never more than the missing
	items bought alone, and never below 1, so an owned item never takes off more than its share. Pure: the server
	charges this price and the client shows it.

	@class ShopPriceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Offer = ShopTypes.Offer

local ShopPriceRules = {}

local function regularOf(id: string): number
	local item = CosmeticRegistry.get(id)
	return if item ~= nil and item.price ~= nil then item.price else 0
end

-- `offer` priced for a player who owns what `owns` says: a copy with `price` (what they pay) and `was` (a real,
-- higher price to cross out, or nil). Always from the registered offer when there is one, so pricing twice is the
-- same as once.
function ShopPriceRules.forPlayer(offer: Offer, owns: (id: string) -> boolean): Offer
	local base = ShopRegistry.get(offer.id) or offer
	if #base.items < 2 then
		return base
	end
	local all, missing = 0, 0
	for _, id in base.items do
		local value = regularOf(id)
		all += value
		if not owns(id) then
			missing += value
		end
	end
	if missing <= 0 or all <= 0 then
		return base
	end
	local price = base.price
	if missing < all then
		local step = ShopConstants.PRICE_STEP
		local share = math.ceil(base.price * missing / all / step) * step
		price = math.max(1, math.min(share, missing))
	end
	local priced = table.clone(base)
	priced.price = price
	priced.was = if missing > price then missing else nil
	return priced
end

return ShopPriceRules
