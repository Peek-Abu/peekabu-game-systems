--!strict
--[=[
	ShopServiceServer: runs Shop purchases. `buy(userId, offerId)` checks the offer exists, the player is not in a
	shift, and (ShopRules) it is on sale, not already owned and affordable; then ONE PlayerData transaction spends the
	price (Gleam through MarketplaceServiceServer:premiumOp, Credits through CurrencyServiceServer:currencyOp) and
	grants the items with their bundles (CosmeticServiceServer:grantOps). Either all of it happens or none of it: a
	player can never pay without getting the item, or get it without paying. A bought item is announced
	(CosmeticServiceServer:announce, source "shop") so the client plays the reveal.

	The buy request is rate-limited and shape-checked (ShopRequestRules); the result goes back as
	ShopEvents.BuyResult. Gleam bundles (Robux developer products) register with the Marketplace receipts only once
	their product ids exist (ShopConstants.PRODUCT_IDS); each receipt adds its Gleam once.

	@class ShopServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shop = ReplicatedStorage.Shared.Features.Shop
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShopConstants = require(Shop.Data.ShopConstants)
local ShopEvents = require(Shop.Net.ShopEvents)
local ShopRegistry = require(Shop.Data.ShopRegistry)
local ShopRequestRules = require(Shop.Rules.ShopRequestRules)
local ShopRules = require(Shop.Rules.ShopRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CosmeticServiceServer = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local CurrencyServiceServer = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

local log = Logger.new("ShopServiceServer")

local CREDITS: CurrencyConstants.CurrencyType = "credits"
local janitor = Janitor.new()

local function buyImpl(userId: number, offerId: string): (boolean, string?)
	Guard.userId(userId)
	local offer = ShopRegistry.get(offerId)
	if offer == nil then
		return false, "unknown offer"
	end
	if CosmeticServiceServer:isLocked() then
		return false, "locked during a shift"
	end
	if CosmeticServiceServer:getLoadout(userId) == nil then
		return false, "no profile loaded"
	end
	local balance = if offer.currency == "gleam"
		then MarketplaceServiceServer:getPremium(userId)
		else CurrencyServiceServer:getCurrencyAmount(userId, "credits")
	if balance == nil then
		return false, "no profile loaded"
	end
	local function owns(id: string): boolean
		return CosmeticServiceServer:owns(userId, id)
	end
	local allowed, refusal = ShopRules.check(offer, owns, balance, os.time())
	if not allowed then
		return false, refusal
	end

	local price = offer.price
	local ops: { PlayerDataService.TransactionOperation } = {}
	if offer.currency == "gleam" then
		table.insert(
			ops,
			MarketplaceServiceServer:premiumOp(userId, function(premium): boolean
				if premium.balance < price then
					return false
				end
				premium.balance -= price
				return true
			end)
		)
	else
		table.insert(
			ops,
			CurrencyServiceServer:currencyOp(userId, function(currency): boolean
				local have = currency[CREDITS] or 0
				if have < price then
					return false
				end
				currency[CREDITS] = have - price
				return true
			end)
		)
	end
	for _, id in offer.items do
		for _, op in CosmeticServiceServer:grantOps(userId, id) do
			table.insert(ops, op)
		end
	end
	local committed, result = PlayerDataService:transaction(ops)
	if not committed then
		return false, result.rejectionReason or "transaction failed"
	end
	log:audit(`userId={userId}`, "SHOP_BOUGHT", offer.id, offer.currency, price)
	CosmeticServiceServer:announce(userId, offer.items, "shop")
	return true, nil
end

local onBuyRequest = RequestHandler.wrap({
	name = "ShopBuyRequest",
	rateLimit = { maxRequests = 5, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local offer, reason = ShopRequestRules.parseBuy(payload)
		if offer == nil then
			log:warn(`bad BuyRequest from {player.Name}: {reason or "?"}`)
			return
		end
		local ok, refusal = buyImpl(player.UserId, offer)
		if not ok then
			log:debug(`BuyRequest refused for {player.Name}: {refusal or "?"}`)
		end
		-- Specs pass a stand-in table for the player; only a real player is answered.
		if typeof(player) == "Instance" then
			ShopEvents.packets.BuyResult.sendTo(
				{ offer = offer, reason = if ok then "" else refusal or "failed" },
				player
			)
		end
	end,
})

-- Registers each Gleam bundle that has a product id with the Marketplace receipts.
local function registerBundles()
	for _, bundle in ShopConstants.BUNDLES do
		local productId = ShopConstants.PRODUCT_IDS[bundle.key]
		if productId ~= nil and MarketplaceRegistry.product(bundle.key) == nil then
			MarketplaceRegistry.registerProduct(bundle.key, { productId = productId })
			local gleam = bundle.gleam
			MarketplaceServiceServer:onProduct(bundle.key, function(player: Player)
				return {
					MarketplaceServiceServer:premiumOp(player.UserId, function(premium): boolean
						premium.balance += gleam
						return true
					end),
				}
			end)
		end
	end
end

export type ShopServiceServer = {
	dependencies: { string },
	init: (self: ShopServiceServer) -> (),
	stop: (self: ShopServiceServer) -> (),
	buy: (self: ShopServiceServer, userId: number, offerId: string) -> (boolean, string?),
	getState: (self: ShopServiceServer) -> { [string]: any },
	-- TEST SEAM: the RequestHandler-wrapped buy handler (payload, player).
	_onBuyRequest: (payload: unknown, player: Player) -> any,
}

local ShopServiceServer: ShopServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"CosmeticServiceServer",
		"CurrencyServiceServer",
		"MarketplaceServiceServer",
	},

	init = function(_self)
		registerBundles()
		janitor:Add(
			ShopEvents.packets.BuyRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onBuyRequest(payload, player)
				end
			end),
			true
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	buy = function(_self, userId, offerId)
		return buyImpl(userId, offerId)
	end,

	getState = function(_self)
		return { offers = #ShopRegistry.all() }
	end,

	_onBuyRequest = onBuyRequest,
}

return ShopServiceServer
