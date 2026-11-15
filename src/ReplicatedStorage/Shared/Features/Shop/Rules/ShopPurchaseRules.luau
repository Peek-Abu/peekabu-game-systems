--!strict
--[=[
	ShopPurchaseRules: what the "You bought it!" screen shows for a Robux buy that is not a cosmetic (owner 11-15). A
	Gleam bundle's product is Gleam of its amount, the coffee product is coffee of its minutes, a game pass is that pass.
	The server sends one (ShopEvents.Purchased) only after the buy is granted: a product once its receipt's save has
	landed (MarketplaceServiceServer.productGranted), a pass once Roblox says it was bought. `parse` checks what the
	client got; `shows` keeps a coffee bought in a shift off the screen (the office PA already names the buyer).

	@class ShopPurchaseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Purchase = ShopTypes.Purchase

local KINDS: { [string]: ShopTypes.PurchaseKind } = { gleam = "gleam", pass = "pass", coffee = "coffee" }

local ShopPurchaseRules = {}

-- The purchase a developer product's grant shows; nil for a product with its own reveal (a deal) or none.
function ShopPurchaseRules.forProduct(key: string): Purchase?
	for _, bundle in ShopConstants.BUNDLES do
		if bundle.key == key then
			return { kind = "gleam", key = key, amount = bundle.gleam }
		end
	end
	if key == CoffeeConstants.PRODUCT_KEY then
		return { kind = "coffee", key = key, amount = CoffeeConstants.SECONDS // 60 }
	end
	return nil
end

function ShopPurchaseRules.forPass(key: string): Purchase?
	if key == "" then
		return nil
	end
	return { kind = "pass", key = key, amount = 1 }
end

-- What ShopEvents.Purchased carries (the packet types the fields; the kind is still a plain string).
export type Wire = { kind: string, key: string, amount: number }

-- A purchase from the wire, checked: a known kind, a key, a whole positive amount.
function ShopPurchaseRules.parse(wire: Wire): Purchase?
	local kind: ShopTypes.PurchaseKind? = KINDS[wire.kind]
	local amount = wire.amount
	if kind == nil then
		return nil
	end
	if wire.key == "" or amount ~= amount or amount < 1 or amount ~= math.floor(amount) then
		return nil
	end
	local purchase: Purchase = { kind = kind, key = wire.key, amount = amount }
	return purchase
end

-- Whether to put the screen up: always, except a coffee bought outside the hub (mid-shift, the PA thanks the buyer
-- and a full screen would hide the game).
function ShopPurchaseRules.shows(purchase: Purchase, inHub: boolean): boolean
	return purchase.kind ~= "coffee" or inHub
end

return ShopPurchaseRules
