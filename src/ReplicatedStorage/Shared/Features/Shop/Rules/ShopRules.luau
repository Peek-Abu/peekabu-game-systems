--!strict
--[=[
	ShopRules: whether a player may buy an offer now: it is on sale (inside its dates), they don't already own
	everything it grants (owning a bundled extra is fine: the rest is still new), and their balance in the offer's
	currency covers the price. The server runs the same check inside the purchase; the client uses it to draw the
	button.

	@class ShopRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

local ShopRules = {}

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
	now: number
): (boolean, Refusal?)
	if not ShopRotationUtils.available(offer, now) then
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

return ShopRules
