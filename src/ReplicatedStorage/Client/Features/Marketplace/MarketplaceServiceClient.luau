--!strict
--[=[
	MarketplaceServiceClient: purchase prompts by game key, owned passes and the premium balance (design:
	docs/superpowers/specs/2026-10-09-marketplace-design.md). The client only prompts and reads; every grant
	happens on the server.

	- `ownsPass(key)` reads the local player's public `pass:<key>` field (published by the server).
	- `premium` is the replicated account balance (StateSyncClientStore.premium), for React `useAtom`.

	Spec-exempt shell (MarketplaceService prompts, the public store); the registry is specced.

	@class MarketplaceServiceClient
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

export type MarketplaceServiceClient = {
	dependencies: { string },
	premium: () -> PlayerDataTypes.Premium,

	promptProduct: (self: MarketplaceServiceClient, key: string) -> (),
	promptPass: (self: MarketplaceServiceClient, key: string) -> (),
	ownsPass: (self: MarketplaceServiceClient, key: string, userId: number?) -> boolean,
	getPremium: (self: MarketplaceServiceClient) -> number,
}

local MarketplaceServiceClient: MarketplaceServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	premium = StateSyncClientStore.premium,

	--[=[
		Opens Roblox's purchase prompt for a registered product. Asserts the key is registered.
	]=]
	promptProduct = function(_self, key)
		local def = MarketplaceRegistry.product(key)
		assert(def ~= nil, `promptProduct: "{key}" is not a registered product`)
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.productId)
	end,

	--[=[
		Opens the purchase prompt for a registered pass the local player does not own yet.
	]=]
	promptPass = function(self, key)
		local def = MarketplaceRegistry.pass(key)
		assert(def ~= nil, `promptPass: "{key}" is not a registered pass`)
		if not self:ownsPass(key) then
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.passId)
		end
	end,

	--[=[
		Whether a player (default: the local player) owns a pass, as published by the server. False until
		the server's ownership check has finished.
	]=]
	ownsPass = function(_self, key, userId)
		local entryKey = StateSyncConstants.publicEntryKey(userId or Players.LocalPlayer.UserId)
		local entry = StateSyncClientStore.publicPlayers()[entryKey]
		return entry ~= nil and entry[MarketplaceConstants.passField(key)] == true
	end,

	getPremium = function(_self)
		return StateSyncClientStore.premium().balance
	end,
}

return MarketplaceServiceClient
