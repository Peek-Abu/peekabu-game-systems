--!strict
--[=[
	ShopRequestRules: the build/parse contract for the Shop's buy request. The client BUILDS it, the server PARSES it
	at the trust boundary (shape only: an offer id of 1-64 characters, and the Gleam the player agreed to pay for the
	rest when short, and the price they saw, each a whole number from 0 to ShopConstants.MAX_TOP_UP; whether it exists, can be bought and what the
	rest really costs is ShopRules' and ShopTopUpRules' job in the service).

	@class ShopRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)

-- `gleam`: the most Gleam the player said yes to paying for the rest (0 = pay in full or not at all). `price`: the
-- price the player saw (nil = not shown, e.g. the pick screen); the server never charges more than it.
export type BuyRequest = { offer: string, gleam: number, price: number? }

local function wholeAmount(value: unknown): number?
	if
		type(value) ~= "number"
		or value ~= value
		or value < 0
		or value > ShopConstants.MAX_TOP_UP
		or math.floor(value) ~= value
	then
		return nil
	end
	return value
end

local ShopRequestRules = {}

function ShopRequestRules.buildBuy(offer: string, gleam: number?, price: number?): BuyRequest
	return { offer = offer, gleam = gleam or 0, price = price }
end

function ShopRequestRules.parseBuy(payload: unknown): (BuyRequest?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the fields are shape-checked below
	local offer = fields.offer
	if type(offer) ~= "string" or #offer < 1 or #offer > ShopConstants.MAX_ID_LENGTH then
		return nil, "missing or malformed offer"
	end
	local gleam = 0
	if fields.gleam ~= nil then
		local parsed = wholeAmount(fields.gleam)
		if parsed == nil then
			return nil, "malformed gleam"
		end
		gleam = parsed
	end
	local price: number? = nil
	if fields.price ~= nil then
		price = wholeAmount(fields.price)
		if price == nil then
			return nil, "malformed price"
		end
	end
	return { offer = offer, gleam = gleam, price = price }, nil
end

return ShopRequestRules
