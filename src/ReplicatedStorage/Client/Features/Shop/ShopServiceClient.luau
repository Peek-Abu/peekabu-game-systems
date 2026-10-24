--!strict
--[=[
	ShopServiceClient: the Shop on the client: today's live shop (ShopRotationUtils over the catalogue at the server's
	clock, so it matches every server), an offer by id, and the buy request. The server answers every buy with
	ShopEvents.BuyResult, kept in ShopStore for the screen; what was bought arrives through the synced entitlements
	and the reveal (CosmeticEvents.Granted). Fire-and-forget: the server is authoritative.

	@class ShopServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = ReplicatedStorage.Shared.Features.Shop
local ShopEvents = require(Shop.Net.ShopEvents)
local ShopRegistry = require(Shop.Data.ShopRegistry)
local ShopRequestRules = require(Shop.Rules.ShopRequestRules)
local ShopRotationUtils = require(Shop.Utils.ShopRotationUtils)
local ShopTypes = require(Shop.Data.ShopTypes)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)

local stoppers: { () -> () } = {}

export type ShopServiceClient = {
	dependencies: { string },
	init: (self: ShopServiceClient) -> (),
	stop: (self: ShopServiceClient) -> (),
	live: (self: ShopServiceClient) -> ShopTypes.LiveShop,
	offer: (self: ShopServiceClient, id: string) -> ShopTypes.Offer?,
	requestBuy: (self: ShopServiceClient, id: string) -> (),
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

	requestBuy = function(_self, id)
		if ShopRegistry.get(id) == nil then
			return
		end
		ShopEvents.packets.BuyRequest.send(ShopRequestRules.buildBuy(id))
	end,
}

return ShopServiceClient
