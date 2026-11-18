--!strict
--[=[
	ShopRules: whether a player may buy an offer now: it is on sale (inside its dates; an event's offer while `live`, the
	live event's id, is its event), they don't already own
	everything it grants (owning a bundled extra is fine: the rest is still new), and their balance in the offer's
	currency covers the price. The server runs the same check inside the purchase; the client uses it to draw the
	button. `topRarity` is a buy's rarity for its sound: a bundle's highest-rarity item (owner, 2026-11-17).

	@class ShopRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

local ShopRules = {}

-- The rarities worst to best (Odd above Legendary, as the Locker rolls them).
local RARITY_RANK: { [CosmeticTypes.Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

export type Refusal = "owned" | "short" | "not on sale"

function ShopRules.owned(offer: ShopTypes.Offer, owns: (id: string) -> boolean): boolean
	for _, id in offer.items do
		if not owns(id) then
			return false
		end
	end
	return true
end

function ShopRules.check(
	offer: ShopTypes.Offer,
	owns: (id: string) -> boolean,
	balance: number,
	now: number,
	live: string?
): (boolean, Refusal?)
	if not ShopRotationUtils.available(offer, now, live) then
		return false, "not on sale"
	end
	if ShopRules.owned(offer, owns) then
		return false, "owned"
	end
	if balance < offer.price then
		return false, "short"
	end
	return true, nil
end

-- How much more of the offer's currency the player needs (0 when they have enough).
function ShopRules.missing(offer: ShopTypes.Offer, balance: number): number
	return math.max(0, offer.price - balance)
end

--[=[
	An offer's rarity: its one item's, or a bundle's highest-rarity item's (owner, 2026-11-17: "if bundle - highest
	rarity item"). Items the catalogue doesn't know are skipped; nil when it knows none.
]=]
function ShopRules.topRarity(offer: ShopTypes.Offer): CosmeticTypes.Rarity?
	local top: CosmeticTypes.Rarity? = nil
	for _, id in offer.items do
		local item = CosmeticRegistry.get(id)
		if item ~= nil and (top == nil or RARITY_RANK[item.rarity] > RARITY_RANK[top]) then
			top = item.rarity
		end
	end
	return top
end

return ShopRules
