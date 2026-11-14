--!strict
--[=[
	DealServiceClient: the one-time deals on this client (DealConstants). `buy` opens Roblox's purchase prompt for a
	deal (once the owner has created its product); bought from the Pick Your Employee screen, it remembers the
	employee picked there, so the waiting pick is spent on them without asking again. Otherwise, while a pick waits
	(DealRules.pending on the synced `deals` slice) and the player is in the depot, the chooser scene opens; `choose`
	sends the choice (DealEvents.Choose). The server checks and grants; the cosmetic reveal shows what was got.

	At start it asks Roblox for each deal product's live Robux price (a few tries), into DealStore, so the cards show
	what the prompt charges and their % off follows it.

	Studio only: the workspace attribute `DevDealProducts` = true treats the products as made, so the cards and the
	pick screen's button can be seen before the owner creates them (a press then prompts nothing).

	Spec-exempt shell (Charm, MarketplaceService, ByteNet, SceneStack); the decisions are the specced DealRules and
	DealViewModel.

	@class DealServiceClient
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealEvents = require(ReplicatedStorage.Shared.Features.Deal.Net.DealEvents)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local DealStore = require(ReplicatedStorage.Client.Features.Deal.State.DealStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local CharacterPickViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickViewModel)
local RevealViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealViewModel)
local DealChooserScene = require(ReplicatedStorage.Client.UI.React.Screens.Deal.DealChooserScene)

type DealId = DealConstants.DealId

local DEV_ATTRIBUTE = "DevDealProducts"

-- Tries at a product's price, and the wait between them (seconds).
local INFO_ATTEMPTS = 3
local INFO_RETRY_SECONDS = 2

-- The choice to spend a pick on without asking (set when bought from the pick screen), per deal.
local preferred: { [string]: string } = {}
local sentAt: { [string]: number } = {}
local stoppers: { () -> () } = {}

local function owns(id: string): boolean
	return CosmeticRules.owns(StateSyncClientStore.entitlements(), id)
end

local function productReady(id: DealId): boolean
	if DealRules.deal(id).productId ~= nil then
		return true
	end
	return RunService:IsStudio() and workspace:GetAttribute(DEV_ATTRIBUTE) == true
end

-- Deal `id`'s live Robux price from Roblox, into DealStore; nothing is stored when every try fails (the card keeps
-- the DealConstants price).
local function fetchPrice(id: DealId, productId: number)
	for attempt = 1, INFO_ATTEMPTS do
		local ok, data = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and type(data) == "table" then
			local price = data.PriceInRobux
			if type(price) == "number" then
				DealStore.setRobux(id, price)
			end
			return
		end
		if attempt < INFO_ATTEMPTS then
			task.wait(INFO_RETRY_SECONDS)
		end
	end
end

local function send(deal: DealId, choice: string)
	-- One send per pick: the slice's change (the pick spent) reopens the question if it failed.
	local key = `{deal}:{choice}`
	local last = sentAt[key]
	if last ~= nil and os.clock() - last < 2 then
		return
	end
	sentAt[key] = os.clock()
	DealEvents.packets.Choose.send({ deal = deal, choice = choice })
end

-- Spends a waiting pick on the remembered choice, or shows the chooser while the player is in the depot.
local function sync()
	local slice = StateSyncClientStore.deals()
	local pending = DealRules.pending(slice, owns)
	local inDepot = DepotHubViewModel.visible(ShiftStore.snapshot(), Players.LocalPlayer.UserId)
	if pending ~= nil then
		local want = preferred[pending]
		if want ~= nil and table.find(DealRules.choices(pending, owns), want) ~= nil then
			preferred[pending] = nil
			send(pending, want)
			return
		end
	end
	local blocked = SceneStack.isActive(CharacterPickViewModel.SCENE) or SceneStack.isActive(RevealViewModel.SCENE)
	if pending ~= nil and inDepot and not blocked then
		if not SceneStack.isActive(DealConstants.SCENE) then
			SceneStack.push(DealConstants.SCENE)
		end
	elseif pending == nil or not inDepot then
		SceneStack.remove(DealConstants.SCENE)
	end
end

export type DealServiceClient = {
	dependencies: { string },
	init: (self: DealServiceClient) -> (),
	start: (self: DealServiceClient) -> (),
	stop: (self: DealServiceClient) -> (),
	productReady: (self: DealServiceClient, deal: DealId) -> boolean,
	buy: (self: DealServiceClient, deal: DealId, choice: string?) -> (),
	choose: (self: DealServiceClient, deal: DealId, choice: string) -> (),
}

local DealServiceClient: DealServiceClient = {
	dependencies = { "StateSyncServiceClient", "UIServiceClient", "DepotServiceClient" },

	init = function(_self)
		DealChooserScene.register(send)
	end,

	start = function(_self)
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.deals, sync))
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.entitlements, sync))
		table.insert(stoppers, Charm.subscribe(ShiftStore.snapshot, sync))
		table.insert(
			stoppers,
			Charm.subscribe(UIStore.sceneStack, function()
				-- The chooser waits for the pick screen and the reveal to close.
				task.defer(sync)
			end)
		)
		sync()
		for _, id in DealConstants.ORDER do
			local productId = DealRules.deal(id).productId
			if productId ~= nil then
				task.spawn(fetchPrice, id, productId)
			end
		end
	end,

	stop = function(_self)
		for _, stopper in stoppers do
			stopper()
		end
		table.clear(stoppers)
	end,

	productReady = function(_self, deal)
		return productReady(deal)
	end,

	buy = function(_self, deal, choice)
		if choice ~= nil then
			preferred[deal] = choice
		end
		local productId = DealRules.deal(deal).productId
		if productId ~= nil then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end
	end,

	choose = function(_self, deal, choice)
		send(deal, choice)
	end,
}

return DealServiceClient
