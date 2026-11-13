--!strict
--[=[
	ShopRequestRules: the build/parse contract for the Shop's buy request. The client BUILDS it, the server PARSES it
	at the trust boundary (shape only: an offer id of 1-64 characters, and the Gleam the player agreed to pay for the
	rest when short, a whole number from 0 to ShopConstants.MAX_TOP_UP; whether it exists, can be bought and what the
	rest really costs is ShopRules' and ShopTopUpRules' job in the service).

	@class ShopRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)

-- `gleam`: the most Gleam the player said yes to paying for the rest (0 = pay in full or not at all).
export type BuyRequest = { offer: string, gleam: number }

local ShopRequestRules = {}

function ShopRequestRules.buildBuy(offer: string, gleam: number?): BuyRequest
	return { offer = offer, gleam = gleam or 0 }
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
	local gleam = fields.gleam
	if gleam == nil then
		return { offer = offer, gleam = 0 }, nil
	end
	if
		type(gleam) ~= "number"
		or gleam ~= gleam
		or gleam < 0
		or gleam > ShopConstants.MAX_TOP_UP
		or math.floor(gleam) ~= gleam
	then
		return nil, "malformed gleam"
	end
	return { offer = offer, gleam = gleam }, nil
end

return ShopRequestRules
