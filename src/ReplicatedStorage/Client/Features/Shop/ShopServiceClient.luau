--!strict
--[=[
	ShopServiceClient: the Shop on the client: today's live shop (ShopRotationUtils over the catalogue at the server's
	clock, so it matches every server), an offer by id, and the buy request. The server answers every buy with
	ShopEvents.BuyResult, kept in ShopStore for the screen; what was bought arrives through the synced entitlements
	and the reveal (CosmeticEvents.Granted). Fire-and-forget: the server is authoritative. At start it asks Roblox for
	each registered game pass's price, icon and name (MarketplaceService product info, a few tries) for the Passes
	tab, into ShopStore.passInfo, and each Gleam bundle's developer product price and icon, into ShopStore.bundleInfo
	(so the bundle cards show what the Roblox prompt and store page show).

	@class ShopServiceClient
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = ReplicatedStorage.Shared.Features.Shop
local ShopEvents = require(Shop.Net.ShopEvents)
local ShopRegistry = require(Shop.Data.ShopRegistry)
local ShopRequestRules = require(Shop.Rules.ShopRequestRules)
local ShopRotationUtils = require(Shop.Utils.ShopRotationUtils)
local ShopTypes = require(Shop.Data.ShopTypes)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local ShopConstants = require(Shop.Data.ShopConstants)

-- Tries at a pass's product info, and the wait between them (seconds).
local INFO_ATTEMPTS = 3
local INFO_RETRY_SECONDS = 2

local stoppers: { () -> () } = {}

-- Roblox's product info for an id, retried; nil when every try fails.
local function productInfo(id: number, infoType: Enum.InfoType): { [string]: unknown }?
	for attempt = 1, INFO_ATTEMPTS do
		local ok, data = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and type(data) == "table" then
			return data
		end
		if attempt < INFO_ATTEMPTS then
			task.wait(INFO_RETRY_SECONDS)
		end
	end
	return nil
end

local function iconOf(data: { [string]: unknown }): string?
	local icon = data.IconImageAssetId
	return if type(icon) == "number" and icon > 0 then `rbxassetid://{icon}` else nil
end

-- One pass's price, icon and name from Roblox; nothing is stored when every try fails (the card stays loading).
local function fetchPass(key: string, passId: number)
	local data = productInfo(passId, Enum.InfoType.GamePass)
	if data == nil then
		return
	end
	local price = data.PriceInRobux
	local name = data.Name
	ShopStore.setPassInfo(key, {
		price = if type(price) == "number" then price else nil,
		icon = iconOf(data),
		name = if type(name) == "string" then name else nil,
		forSale = data.IsForSale == true,
	})
end

-- One Gleam bundle's developer product price and icon from Roblox; nothing is stored when every try fails (the card
-- keeps the known ones).
local function fetchBundle(key: string, productId: number)
	local data = productInfo(productId, Enum.InfoType.Product)
	if data == nil then
		return
	end
	local price = data.PriceInRobux
	ShopStore.setBundleInfo(key, {
		price = if type(price) == "number" then price else nil,
		icon = iconOf(data),
	})
end

export type ShopServiceClient = {
	dependencies: { string },
	init: (self: ShopServiceClient) -> (),
	start: (self: ShopServiceClient) -> (),
	stop: (self: ShopServiceClient) -> (),
	live: (self: ShopServiceClient) -> ShopTypes.LiveShop,
	offer: (self: ShopServiceClient, id: string) -> ShopTypes.Offer?,
	-- `gleam`: the most Gleam the player said yes to paying for the rest of a Credits price they are short for.
	requestBuy: (self: ShopServiceClient, id: string, gleam: number?) -> (),
}

local ShopServiceClient: ShopServiceClient = {
	dependencies = {},

	init = function(_self)
		table.insert(
			stoppers,
			ShopEvents.packets.BuyResult.listen(function(data: { offer: string, reason: string })
				ShopStore.setResult({ offer = data.offer, reason = data.reason })
			end)
		)
	end,

	--[=[
		Fetches every registered game pass's price and icon for the Passes tab, and every Gleam bundle's.
	]=]
	start = function(_self)
		for _, key in MarketplaceRegistry.passKeys() do
			local def = MarketplaceRegistry.pass(key)
			if def ~= nil then
				task.spawn(fetchPass, key, def.passId)
			end
		end
		for _, bundle in ShopConstants.BUNDLES do
			local productId = ShopConstants.PRODUCT_IDS[bundle.key]
			if productId ~= nil then
				task.spawn(fetchBundle, bundle.key, productId)
			end
		end
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	live = function(_self)
		return ShopRotationUtils.live(ShopRegistry.all(), workspace:GetServerTimeNow())
	end,

	offer = function(_self, id)
		return ShopRegistry.get(id)
	end,

	requestBuy = function(_self, id, gleam)
		if ShopRegistry.get(id) == nil then
			return
		end
		ShopEvents.packets.BuyRequest.send(ShopRequestRules.buildBuy(id, gleam))
	end,
}

return ShopServiceClient
