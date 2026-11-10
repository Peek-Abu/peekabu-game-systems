--!strict
--[=[
	CoffeeServiceClient: Coffee for the crew on this client (owner 11-08; 30 minutes, owner 11-10). Registers the
	CoffeeButton HUD widget, which reads the shift snapshot, the `training` world entry and the
	CoffeeConstants.WORLD_ENTRY world entry (whose coffee runs and how long it has left, CoffeeRules.badge). With no
	coffee running it offers "2x PAY" (CoffeeRules.offered); while one runs it shows the gold countdown badge. Either
	press opens Roblox's purchase prompt (buying while coffee runs adds 30 minutes). The PA line, the countdown and the
	doubled pay are the server's.

	Spec-exempt shell (the HUD registry, MarketplaceService); the decisions are the specced CoffeeRules.

	@class CoffeeServiceClient
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local CoffeeRules = require(ReplicatedStorage.Shared.Features.Coffee.Rules.CoffeeRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local CoffeeButton = require(ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeButton)

local function press()
	local productId = CoffeeConstants.PRODUCT_ID
	if productId ~= nil then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
	end
end

local function widget(): React.ReactNode
	local snapshot = ReactCharm.useAtom(ShiftStore.snapshot)
	local world = ReactCharm.useAtom(StateSyncClientStore.world)
	local scale = usePaperHudScale()
	local badge = CoffeeRules.badge(world[CoffeeConstants.WORLD_ENTRY])
	local training = world[TrainingConstants.WORLD_ENTRY] ~= nil
	local phase = if snapshot ~= nil then snapshot.phase else "lobby"
	local canBuy = CoffeeConstants.PRODUCT_ID ~= nil
	local offered = CoffeeRules.offered(phase, training, badge ~= nil) and canBuy
	if badge == nil and not offered then
		return nil
	end
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			coffee = React.createElement(CoffeeButton, {
				phone = scale.layout == "phone",
				offered = offered,
				badge = if badge ~= nil then CoffeeRules.badgeText(badge.buyer, badge.seconds) else nil,
				onPress = if canBuy then press else nil,
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
