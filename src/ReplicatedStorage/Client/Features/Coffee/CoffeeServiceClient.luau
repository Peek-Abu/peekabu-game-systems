--!strict
--[=[
	CoffeeServiceClient: Coffee for the crew on this client (owner 11-08; 30 minutes, owner 11-10). Registers the
	CoffeeButton HUD widget, which reads the shift snapshot, the `training` world entry and the
	CoffeeConstants.WORLD_ENTRY world entry (whose coffee runs and how long it has left, CoffeeRules.badge). With no
	coffee running it offers "2x PAY" (CoffeeRules.offered); while one runs it shows the gold countdown badge. Either
	press opens CoffeeChoice: the Robux price (Roblox's purchase prompt; at start it asks Roblox for the product's
	live price, into CoffeeStore.robux, so the button shows what the prompt charges) or "250 Gleam" (CoffeeEvents.BuyGleam; the server
	checks the balance). Buying while coffee runs adds 30 minutes. The PA line, the countdown and the doubled pay are
	the server's.

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
local CoffeeStore = require(ReplicatedStorage.Client.Features.Coffee.State.CoffeeStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local CoffeeButton = require(ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeButton)
local CoffeeChoice = require(ReplicatedStorage.Client.UI.React.Screens.Coffee.CoffeeChoice)

-- Tries at the product's price, and the wait between them (seconds).
local INFO_ATTEMPTS = 3
local INFO_RETRY_SECONDS = 2

-- The coffee product's live Robux price from Roblox, into CoffeeStore; nothing is stored when every try fails (the
-- button keeps CoffeeConstants.ROBUX_PRICE).
local function fetchPrice(productId: number)
	for attempt = 1, INFO_ATTEMPTS do
		local ok, data = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and type(data) == "table" then
			local price = data.PriceInRobux
			if type(price) == "number" then
				CoffeeStore.setRobux(price)
			end
			return
		end
		if attempt < INFO_ATTEMPTS then
			task.wait(INFO_RETRY_SECONDS)
		end
	end
end

local function buyRobux()
	local productId = CoffeeConstants.PRODUCT_ID
	if productId ~= nil then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
	end
end

local function buyGleam()
	CoffeeEvents.packets.BuyGleam.send(true)
end

local function widget(): React.ReactNode
	local snapshot = ReactCharm.useAtom(ShiftStore.snapshot)
	local world = ReactCharm.useAtom(StateSyncClientStore.world)
	local scale = usePaperHudScale()
	local choosing, setChoosing = React.useState(false)
	local premium = ReactCharm.useAtom(StateSyncClientStore.premium)
	local robux = ReactCharm.useAtom(CoffeeStore.robux)
	local badge = CoffeeRules.badge(world[CoffeeConstants.WORLD_ENTRY])
	local training = world[TrainingConstants.WORLD_ENTRY] ~= nil
	local phase = if snapshot ~= nil then snapshot.phase else "lobby"
	-- Gleam always pays, so the button shows whenever CoffeeRules.offered says so (Robux only when the product exists).
	local offered = CoffeeRules.offered(phase, training, badge ~= nil)
	if badge == nil and not offered then
		return nil
	end
	local phone = scale.layout == "phone"
	local open = choosing and phase == "running" and not training
	local function close()
		setChoosing(false)
	end
	return React.createElement(PaperHudFrame, {
		scale = scale.scale,
		children = {
			coffee = React.createElement(CoffeeButton, {
				phone = phone,
				offered = offered,
				badge = if badge ~= nil then CoffeeRules.badgeText(badge.buyer, badge.seconds) else nil,
				onPress = if training
					then nil
					else function()
						setChoosing(not choosing)
					end,
			}),
			choice = if open
				then React.createElement(CoffeeChoice, {
					phone = phone,
					onRobux = if CoffeeConstants.PRODUCT_ID ~= nil
						then function()
							close()
							buyRobux()
						end
						else nil,
					robuxText = CoffeeRules.robuxText(robux),
					onGleam = function()
						close()
						buyGleam()
					end,
					onClose = close,
					short = not CoffeeRules.affords(premium.balance),
					shortLine = CoffeeRules.shortLine(),
				})
				else nil,
		},
	})
end

export type CoffeeServiceClient = {
	dependencies: { string },
	init: (self: CoffeeServiceClient) -> (),
	start: (self: CoffeeServiceClient) -> (),
	stop: (self: CoffeeServiceClient) -> (),
	-- The two ways to pay (the HUD's choice and the hub's coffee machine): Roblox's purchase prompt, or Gleam
	-- (the server checks it).
	buyRobux: (self: CoffeeServiceClient) -> (),
	buyGleam: (self: CoffeeServiceClient) -> (),
}

local CoffeeServiceClient: CoffeeServiceClient = {
	dependencies = { "StateSyncServiceClient", "UIServiceClient" },

	init = function(_self)
		if not HudRegistry.has("coffee") then
			-- Over the shift HUD, under the training guide.
			HudRegistry.register("coffee", widget, ShiftConstants.HUD_ORDER + 6)
		end
	end,

	start = function(_self)
		local productId = CoffeeConstants.PRODUCT_ID
		if productId ~= nil then
			task.spawn(fetchPrice, productId)
		end
	end,

	stop = function(_self) end,

	buyRobux = function(_self)
		buyRobux()
	end,

	buyGleam = function(_self)
		buyGleam()
	end,
}

return CoffeeServiceClient
