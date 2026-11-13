--!strict
--[=[
	ShopPriceRules: what one player pays for an offer at a time (owner, 11-13: the price sheet).

	- A single item costs its regular price, unless it is on sale: its own `sale` (always with an end; a sale with no
	  end never counts, so a crossed-out price is never made up) or the daily rotation (the Featured item and the first
	  ShopConstants.DAILY_SALE.picks of Today's picks, DAILY_SALE.percent off until the shop changes; never an
	  employee, never a bundle). On sale, the regular price is crossed out (`was`) and `saleEnds` says when it ends.
	- A bundle costs its price (or its own sale price; a bundle's discount never stacks with the daily rotation), with
	  its items' regular prices alone crossed out when that is more.
	- A bundle the player already owns part of costs only the missing part's share, at the bundle's own discount:
	  bundle price x (the missing items' regular prices / all its items' regular prices), rounded up to
	  ShopConstants.PRICE_STEP; never more than the missing items bought alone at today's prices, never below 1. An
	  owned item (on sale or not) only ever takes off its regular share.

	Without a time (`now` nil) nothing is on sale: regular prices only. Pure: the server charges this price and the
	client shows it.

	@class ShopPriceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Offer = ShopTypes.Offer

-- A price now: what is paid, and when that price ends (nil: it is the regular price).
export type Now = { price: number, ends: number? }

local ShopPriceRules = {}

-- Each priced copy's source offer, so pricing a priced copy again starts from the same offer (weak keys: a copy
-- nobody holds is forgotten).
local sources: { [Offer]: Offer } = {}
setmetatable(sources, { __mode = "k" })

local function stepUp(value: number): number
	local step = ShopConstants.PRICE_STEP
	return math.ceil(value / step) * step
end

-- A sale's price at `now`, or nil when it is not running. A sale with no end never counts (no forever-sales).
function ShopPriceRules.saleAt(sale: CosmeticTypes.Sale?, now: number?): Now?
	if sale == nil or now == nil or sale.ends == nil then
		return nil
	end
	local starts, ends = sale.starts, sale.ends
	if (starts ~= nil and now < starts) or now >= ends then
		return nil
	end
	return { price = sale.price, ends = ends }
end

-- The ids on the daily rotation's sale at `now` (single items only), each with when its sale ends.
function ShopPriceRules.daily(now: number): { [string]: number }
	local live = ShopRotationUtils.live(ShopRegistry.all(), now)
	local onSale: { [string]: number } = {}
	local function add(offer: Offer)
		local item = CosmeticRegistry.get(offer.id)
		if #offer.items == 1 and item ~= nil and item.kind ~= "employee" then
			onSale[offer.id] = live.nextRotation
		end
	end
	local featured = live.featured
	if featured ~= nil then
		add(featured)
	end
	for index = 1, math.min(ShopConstants.DAILY_SALE.picks, #live.picks) do
		add(live.picks[index])
	end
	return onSale
end

-- A single item's price at `now`: its own sale first, then the daily rotation, else its regular price.
local function itemNow(id: string, regular: number, now: number?, daily: { [string]: number }?): Now
	local item = CosmeticRegistry.get(id)
	local own = ShopPriceRules.saleAt(if item ~= nil then item.sale else nil, now)
	if own ~= nil and own.price < regular then
		return own
	end
	local ends = if daily ~= nil then daily[id] else nil
	if ends ~= nil then
		return { price = stepUp(regular * (100 - ShopConstants.DAILY_SALE.percent) / 100), ends = ends }
	end
	return { price = regular }
end

local function regularOf(id: string): number
	local item = CosmeticRegistry.get(id)
	return if item ~= nil and item.price ~= nil then item.price else 0
end

-- `offer` priced for a player who owns what `owns` says, at `now`: a copy with `price` (what they pay), `was` (a
-- real, higher price to cross out, or nil) and `saleEnds` (when a sale price ends). A priced copy is priced again from
-- its source offer, so pricing twice is the same as once.
function ShopPriceRules.forPlayer(offer: Offer, owns: (id: string) -> boolean, now: number?): Offer
	local base = sources[offer] or offer
	local daily = if now ~= nil then ShopPriceRules.daily(now) else nil
	local priced = table.clone(base)
	priced.was = nil
	priced.saleEnds = nil
	sources[priced] = base
	if #base.items < 2 then
		local current = itemNow(base.id, base.price, now, daily)
		priced.price = current.price
		if current.ends ~= nil then
			priced.was = base.price
			priced.saleEnds = current.ends
		end
		return priced
	end

	local bundle = CosmeticBundleRegistry.get(base.id)
	local own = ShopPriceRules.saleAt(if bundle ~= nil then bundle.sale else nil, now)
	local bundlePrice = if own ~= nil and own.price < base.price then own.price else base.price
	local all, missing, alone = 0, 0, 0
	for _, id in base.items do
		local value = regularOf(id)
		all += value
		if not owns(id) then
			missing += value
			alone += itemNow(id, value, now, daily).price
		end
	end
	if missing <= 0 or all <= 0 then
		return priced
	end
	local price = bundlePrice
	if missing < all then
		price = math.max(1, math.min(stepUp(bundlePrice * missing / all), alone))
	end
	priced.price = price
	priced.was = if missing > price then missing else nil
	priced.saleEnds = if own ~= nil and own.price < base.price then own.ends else nil
	return priced
end

return ShopPriceRules
