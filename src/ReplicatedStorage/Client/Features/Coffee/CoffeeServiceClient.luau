--!strict
--[=[
	CoffeeServiceClient: Coffee for the crew on this client (owner 11-08). Registers the CoffeeButton HUD widget, which
	reads the shift snapshot, the `training` and CoffeeConstants.WORLD_ENTRY world entries and the player's saved
	coffees (the synced `coffee` slice) through CoffeeRules.offered. A press spends a saved coffee (CoffeeEvents.Use)
	or opens Roblox's purchase prompt for the developer product (once the owner has created it). The PA line and the
	doubled pay are the server's.

	Spec-exempt shell (the HUD registry, MarketplaceService, ByteNet); the decisions are the specced CoffeeRules.

	@class CoffeeServiceClient
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeEvents = require(ReplicatedStorage.Shared.Features.Coffee.Net.CoffeeEvents)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local CoffeeButton = require(ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeButton)

local function press(free: boolean)
	if free then
		CoffeeEvents.packets.Use.send(true)
		return
	end
	local productId = CoffeeConstants.PRODUCT_ID
	if productId ~= nil then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
	end
end

local function widget(): React.ReactNode
	local snapshot = ReactCharm.useAtom(ShiftStore.snapshot)
	local world = ReactCharm.useAtom(StateSyncClientStore.world)
	local saved = ReactCharm.useAtom(StateSyncClientStore.coffee)
	local scale = usePaperHudScale()
	local rawBuyer = world[CoffeeConstants.WORLD_ENTRY]
	local buyer = if type(rawBuyer) == "string" then rawBuyer else nil
	local training = world[TrainingConstants.WORLD_ENTRY] ~= nil
	local phase = if snapshot ~= nil then snapshot.phase else "lobby"
	local free = saved.vouchers > 0
	-- No product yet (the owner creates it): only a saved coffee can be used.
	local offered = CoffeeRules.offered(phase, training, buyer ~= nil) and (free or CoffeeConstants.PRODUCT_ID ~= nil)
	if buyer == nil and not offered then
		return nil
	end
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			coffee = React.createElement(CoffeeButton, {
				phone = scale.layout == "phone",
				offered = offered,
				free = free,
				buyer = buyer,
				onPress = function()
					press(free)
				end,
			}),
		},
	})
end

export type CoffeeServiceClient = {
	dependencies: { string },
	init: (self: CoffeeServiceClient) -> (),
	start: (self: CoffeeServiceClient) -> (),
	stop: (self: CoffeeServiceClient) -> (),
}

local CoffeeServiceClient: CoffeeServiceClient = {
	dependencies = { "StateSyncServiceClient", "UIServiceClient" },

	init = function(_self)
		if not HudRegistry.has("coffee") then
			-- Over the shift HUD, under the training guide.
			HudRegistry.register("coffee", widget, ShiftConstants.HUD_ORDER + 6)
		end
	end,

	start = function(_self) end,

	stop = function(_self) end,
}

return CoffeeServiceClient
