--!strict
--[=[
	DepotServiceClient: the depot on this client. Registers the travel-card HUD widget (DepotCard) during init,
	takes the server's cards (DepotEvents.Card) into DepotStore and moves the card on as its time runs out.
	The board's prompt (DepotEvents.Board) opens the contract board scene (DepotScene, registered at require):
	pushing it twice is a no-op, and once the scene leaves the stack (CLOSE or Escape) the store's board is cleared.
	The hub HUD (DepotHub: profile, Credits, daily gift, Tonight, the menu tiles and
	the Next shift card) claims its gift through DailyRewardServiceClient. The truck queue pad card (DepotPad, with GO!
	to depart now) replaces Queue's placeholder pad widget, which init hides
	with QueueServiceClient:setDefaultWidget(false); the depot's world signs (truck tags, the boards) are drawn by DepotBillboardSystem into the shells the server builds;
	the trucks' scanner arches flash on each bank (DepotTruckScannerSystem), and an empty hub bay shows a ghost truck
	that pops in solid when a host steps in (DepotTruckGhostSystem). The hub's spots open what the server says
	(DepotSpotSystem) and a delivery truck drives past the yard now and then (DepotDriveBySystem). While Shift's transit screen covers the view
	(ShiftTransitStore.covered) no card runs out: the drive card is dropped when the route slip comes up, and the card
	behind the screen (the arrival folder) gets its full time once it clears.

	Spec-exempt shell (ByteNet, HUD registration, scene stack, RunService); the card queue is the specced DepotStore.

	@class DepotServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotBillboardSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem)
local DepotTruckScannerSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotTruckScannerSystem)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local QueueServiceClient = require(ReplicatedStorage.Client.Features.Queue.QueueServiceClient)
local HostServiceClient = require(ReplicatedStorage.Client.Features.Host.HostServiceClient)
local DepotTruckGhostSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotTruckGhostSystem)
local DepotSpotSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotSpotSystem)
local DepotClerkSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotClerkSystem)
local DepotIdleMotionSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotIdleMotionSystem)
local DepotLoungeSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotLoungeSystem)
local DepotTopperSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotTopperSystem)
local DepotFocusOutlineSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotFocusOutlineSystem)
local DepotDriveBySystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotDriveBySystem)
local SocialServiceClient = require(ReplicatedStorage.Client.Features.Social.SocialServiceClient)
local MarketplaceServiceClient = require(ReplicatedStorage.Client.Features.Marketplace.MarketplaceServiceClient)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local DailyRewardServiceClient = require(ReplicatedStorage.Client.Features.DailyReward.DailyRewardServiceClient)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local DepotCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard)
local DepotPad = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPad)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
-- Registers the contract board scene at require.
require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotScene)

local HUD_KEY = "depotCard"
local PAD_HUD_KEY = "depotPad"
local DepotHub = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHub)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubScene)
-- The Inventory (the hub's INVENTORY tile) and the first-join pick register their scenes at require.
require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryScene)
require(ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickScene)
require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopScene)
require(ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealScene)
local RevealViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Reveal.RevealViewModel)
local LockerViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Locker.LockerViewModel)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local ShopViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopViewModel)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryViewModel)
local CharacterPickViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Pick.CharacterPickViewModel)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

-- The loadout atom's placeholder (taken at require, before the first sync): until the atom holds another table the
-- server's loadout has not arrived, and the placeholder always says "not picked".
local loadoutSeed = StateSyncClientStore.loadout()

-- Opens the first-join pick when the loadout says it is not made and the player is in the depot; closes it once
-- the pick lands (or a shift takes the player away).
local function syncPick()
	local loadout = StateSyncClientStore.loadout()
	local inDepot = DepotHubViewModel.visible(ShiftStore.snapshot(), Players.LocalPlayer.UserId)
	local open = CharacterPickViewModel.shouldOpen(loadout, loadout ~= loadoutSeed, inDepot)
	if open and not SceneStack.isActive(CharacterPickViewModel.SCENE) then
		SceneStack.push(CharacterPickViewModel.SCENE)
	elseif not open then
		SceneStack.remove(CharacterPickViewModel.SCENE)
	end
end

-- Shows the reveal scene while a reveal waits and the player is in the depot (a reveal earned in a shift waits for
-- the depot); takes it off when the queue is empty.
local function syncReveal()
	local waiting = CosmeticRevealStore.current() ~= nil
	local inDepot = DepotHubViewModel.visible(ShiftStore.snapshot(), Players.LocalPlayer.UserId)
	if waiting and inDepot and not SceneStack.isActive(RevealViewModel.SCENE) then
		SceneStack.push(RevealViewModel.SCENE)
	elseif not waiting or not inDepot then
		SceneStack.remove(RevealViewModel.SCENE)
	end
end

local stoppers: { () -> () } = {}

export type DepotServiceClient = {
	dependencies: { string },
	init: (self: DepotServiceClient) -> (),
	start: (self: DepotServiceClient) -> (),
	stop: (self: DepotServiceClient) -> (),
	getState: (self: DepotServiceClient) -> { [string]: string | number | boolean },
}

local DepotServiceClient: DepotServiceClient = {
	dependencies = {
		"QueueServiceClient",
		"HostServiceClient",
		"SocialServiceClient",
		"MarketplaceServiceClient",
		"StateSyncServiceClient",
		"DailyRewardServiceClient",
	},

	init = function(_self)
		if not HudRegistry.has("depotHub") then
			-- The hub HUD's daily gift claims through the daily reward service (the server decides).
			HudRegistry.register("depotHub", function()
				return React.createElement(DepotHub, {
					onClaimGift = function()
						DailyRewardServiceClient:claim()
					end,
				})
			end, DepotConstants.HUD_ORDER - 2)
		end
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, DepotCard, DepotConstants.HUD_ORDER)
		end
		-- The truck pad card replaces the base placeholder pad panel.
		QueueServiceClient:setDefaultWidget(false)
		if not HudRegistry.has(PAD_HUD_KEY) then
			HudRegistry.register(PAD_HUD_KEY, function()
				return React.createElement(DepotPad, {
					onAction = function(action)
						if action == "depart" then
							QueueServiceClient:departNow()
						elseif action == "start" then
							HostServiceClient:startTrip()
						elseif action == "cancel" then
							HostServiceClient:cancelTrip()
						elseif action == "leave" then
							HostServiceClient:leaveTruck()
						end
					end,
					onKick = function(userId)
						HostServiceClient:kick(userId)
					end,
					onLock = function(locked)
						HostServiceClient:setLock(locked)
					end,
					onInvite = function()
						SocialServiceClient:invite()
					end,
					onUpgrade = function()
						MarketplaceServiceClient:promptPass(HostConstants.PASS_KEY)
					end,
					-- The PLACE button opens the places menu (the host picks there; DepotPlaceSender).
					onOpenPlaces = function()
						DepotStore.openBoard(DepotStore.board() or DepotConstants.CONTRACTS[1].id)
						SceneStack.push(DepotConstants.BOARD_SCENE)
					end,
				})
			end, DepotConstants.HUD_ORDER - 1)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			Charm.subscribe(ShiftStore.snapshot, function(snapshot)
				if not DepotHubViewModel.visible(snapshot, Players.LocalPlayer.UserId) then
					SceneStack.remove(DepotConstants.BOARD_SCENE)
					SceneStack.remove(DepotHubViewModel.scene("guide"))
					SceneStack.remove(DepotHubViewModel.scene("settings"))
					SceneStack.remove(InventoryViewModel.SCENE)
					SceneStack.remove(ShopViewModel.SCENE)
					SceneStack.remove(LockerViewModel.OPENING_SCENE)
					for _, scene in DepotSpotSystem.SCENES do
						SceneStack.remove(scene)
					end
				end
				syncPick()
				syncReveal()
			end)
		)
		table.insert(stoppers, Charm.subscribe(CosmeticRevealStore.current, syncReveal))
		table.insert(stoppers, Charm.subscribe(StateSyncClientStore.loadout, syncPick))
		syncPick()
		table.insert(
			stoppers,
			DepotEvents.packets.Card.listen(function(data: DepotTypes.CardMessage)
				DepotStore.show(data, os.clock())
			end)
		)
		table.insert(
			stoppers,
			DepotEvents.packets.Board.listen(function(id: string)
				DepotStore.openBoard(id)
				SceneStack.push(DepotConstants.BOARD_SCENE)
			end)
		)
		table.insert(
			stoppers,
			Charm.subscribe(UIStore.sceneStack, function()
				if DepotStore.board() ~= nil and not SceneStack.isActive(DepotConstants.BOARD_SCENE) then
					DepotStore.closeBoard()
				end
			end)
		)
		table.insert(
			stoppers,
			DepotEvents.packets.LastShift.listen(function(data: DepotTypes.LastShift)
				DepotStore.setLastShift(data)
			end)
		)
		table.insert(
			stoppers,
			Charm.subscribe(ShiftTransitStore.slip, function(slip: boolean)
				if slip then
					DepotStore.dropDrive(os.clock())
				end
			end)
		)
		table.insert(
			stoppers,
			Charm.subscribe(ShiftTransitStore.covered, function(covered: boolean)
				if not covered then
					DepotStore.restamp(os.clock())
				end
			end)
		)
		DepotEvents.packets.Ready.send(true)
		local ticking = RunService.Heartbeat:Connect(function()
			if ShiftTransitStore.covered() then
				return
			end
			if DepotStore.card() ~= nil then
				DepotStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
		DepotBillboardSystem.start()
		table.insert(stoppers, DepotTruckScannerSystem.start())
		table.insert(stoppers, DepotTruckGhostSystem.start())
		-- The hub's spots (Supply Counter, standees, coffee, crew wall, rank chart, radio, bell) and the truck outside.
		table.insert(stoppers, DepotSpotSystem.start())
		table.insert(stoppers, DepotDriveBySystem.start())
		-- Today's clerk behind the Supply Counter, stamping parcels.
		table.insert(stoppers, DepotClerkSystem.start())
		table.insert(stoppers, DepotIdleMotionSystem.start())
		table.insert(stoppers, DepotLoungeSystem.start())
		table.insert(stoppers, DepotTopperSystem.start())
		table.insert(stoppers, DepotFocusOutlineSystem.start())
	end,

	stop = function(_self)
		DepotBillboardSystem.stop()
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		SceneStack.remove(DepotConstants.BOARD_SCENE)
		SceneStack.remove(DepotHubViewModel.scene("guide"))
		SceneStack.remove(DepotHubViewModel.scene("settings"))
		DepotStore.clear()
	end,

	getState = function(_self)
		local card = DepotStore.card()
		return { card = if card ~= nil then card.kind else "none", signs = DepotBillboardSystem.getState().mounted }
	end,
}

return DepotServiceClient
