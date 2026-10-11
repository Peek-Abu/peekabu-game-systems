--!strict
--[=[
	DepotServiceClient: the depot on this client. Registers the travel-card HUD widget (DepotCard) during init,
	takes the server's cards (DepotEvents.Card) into DepotStore and moves the card on as its time runs out.
	The board's prompt (DepotEvents.Board) opens the contract board scene (DepotScene, registered at require):
	pushing it twice is a no-op, and once the scene leaves the stack (CLOSE or Escape) the store's board is cleared.
	The truck queue pad card (DepotPad, with Depart now) replaces Queue's placeholder pad widget, which init hides
	with QueueServiceClient:setDefaultWidget(false); the depot's world signs (truck tags, the boards) are drawn by DepotBillboardSystem into the shells the server builds.

	Spec-exempt shell (ByteNet, HUD registration, scene stack, RunService); the card queue is the specced DepotStore.

	@class DepotServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local React = require(ReplicatedStorage.Packages.React)

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotBillboardSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotBillboardSystem)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local QueueServiceClient = require(ReplicatedStorage.Client.Features.Queue.QueueServiceClient)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local DepotCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard)
local DepotPad = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPad)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
-- Registers the contract board scene at require.
require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotScene)

local HUD_KEY = "depotCard"
local PAD_HUD_KEY = "depotPad"

local stoppers: { () -> () } = {}

export type DepotServiceClient = {
	dependencies: { string },
	init: (self: DepotServiceClient) -> (),
	start: (self: DepotServiceClient) -> (),
	stop: (self: DepotServiceClient) -> (),
	getState: (self: DepotServiceClient) -> { [string]: string | number | boolean },
}

local DepotServiceClient: DepotServiceClient = {
	dependencies = { "QueueServiceClient", "StateSyncServiceClient" },

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, DepotCard, DepotConstants.HUD_ORDER)
		end
		-- The truck pad card replaces the base placeholder pad panel.
		QueueServiceClient:setDefaultWidget(false)
		if not HudRegistry.has(PAD_HUD_KEY) then
			HudRegistry.register(PAD_HUD_KEY, function()
				return React.createElement(DepotPad, {
					onDepart = function()
						QueueServiceClient:departNow()
					end,
				})
			end, DepotConstants.HUD_ORDER - 1)
		end
	end,

	start = function(_self)
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
		DepotEvents.packets.Ready.send(true)
		local ticking = RunService.Heartbeat:Connect(function()
			if DepotStore.card() ~= nil then
				DepotStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
		DepotBillboardSystem.start()
	end,

	stop = function(_self)
		DepotBillboardSystem.stop()
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		SceneStack.remove(DepotConstants.BOARD_SCENE)
		DepotStore.clear()
	end,

	getState = function(_self)
		local card = DepotStore.card()
		return { card = if card ~= nil then card.kind else "none", signs = DepotBillboardSystem.getState().mounted }
	end,
}

return DepotServiceClient
