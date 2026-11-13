--!strict
--[=[
	ShopTopUpRules: Gleam pays the rest of a purchase the player is short for (owner, 11-13: "any Credits/Gloom purchase
	you can't afford can use Gleam for the rest"). Only a currency with a rate in ShopConstants.TOP_UP can be topped up;
	the Gleam is always rounded up, and the player keeps whatever the rounding over-covers (only the Credits the Gleam
	does not cover are taken). Pure: the server runs the same plan inside the purchase, the client uses it to draw the
	button and the question.

	@class ShopTopUpRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)

-- What a topped-up purchase takes: `gleam` Gleam, and `spend` of the purchase's own currency (never more than the
-- player has).
export type Plan = { gleam: number, spend: number }

local ShopTopUpRules = {}

-- The Gleam that covers `missing` of `currency`, rounded up; nil when that currency cannot be topped up.
function ShopTopUpRules.gleamFor(currency: string, missing: number): number?
	local rate = ShopConstants.TOP_UP[currency]
	if rate == nil or rate <= 0 then
		return nil
	end
	return math.ceil(math.max(0, missing) / rate)
end

-- How a `price` in `currency` is paid when the player has `have` of it and is short; nil when they are not short or
-- the currency cannot be topped up.
function ShopTopUpRules.plan(currency: string, price: number, have: number): Plan?
	local balance = math.max(0, have)
	if balance >= price then
		return nil
	end
	local gleam = ShopTopUpRules.gleamFor(currency, price - balance)
	local rate = ShopConstants.TOP_UP[currency]
	if gleam == nil or rate == nil then
		return nil
	end
	return { gleam = gleam, spend = math.max(0, price - gleam * rate) }
end

return ShopTopUpRules
