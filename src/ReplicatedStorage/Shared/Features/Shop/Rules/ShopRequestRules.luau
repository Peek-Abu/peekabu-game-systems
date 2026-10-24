--!strict
--[=[
	ShopRequestRules: the build/parse contract for the Shop's buy request. The client BUILDS it, the server PARSES it
	at the trust boundary (shape only: an offer id of 1-64 characters; whether it exists and can be bought is
	ShopRules' job in the service).

	@class ShopRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)

export type BuyRequest = { offer: string }

local ShopRequestRules = {}

function ShopRequestRules.buildBuy(offer: string): BuyRequest
	return { offer = offer }
end

function ShopRequestRules.parseBuy(payload: unknown): (string?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the field is shape-checked below
	local offer = fields.offer
	if type(offer) ~= "string" or #offer < 1 or #offer > ShopConstants.MAX_ID_LENGTH then
		return nil, "missing or malformed offer"
	end
	return offer, nil
end

return ShopRequestRules
