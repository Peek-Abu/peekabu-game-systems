--!strict
--[=[
	DepotServiceClient: the depot on this client. Registers the travel-card HUD widget (DepotCard) during init,
	takes the server's cards (DepotEvents.Card) into DepotStore and moves the card on as its time runs out.
	The pad countdown and Depart now are Queue's own placeholder widget; the boards and truck labels are
	world billboards the server builds.

	Spec-exempt shell (ByteNet, HUD registration, RunService); the card queue is the specced DepotStore.

	@class DepotServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local DepotCard = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCard)

local HUD_KEY = "depotCard"

local stoppers: { () -> () } = {}

export type DepotServiceClient = {
	dependencies: { string },
	init: (self: DepotServiceClient) -> (),
	start: (self: DepotServiceClient) -> (),
	stop: (self: DepotServiceClient) -> (),
	getState: (self: DepotServiceClient) -> { [string]: string | number | boolean },
}

local DepotServiceClient: DepotServiceClient = {
	dependencies = {},

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			HudRegistry.register(HUD_KEY, DepotCard, DepotConstants.HUD_ORDER)
		end
	end,

	start = function(_self)
		table.insert(
			stoppers,
			DepotEvents.packets.Card.listen(function(data: DepotTypes.CardMessage)
				DepotStore.show(data.kind, data.title, data.body, os.clock())
			end)
		)
		local ticking = RunService.Heartbeat:Connect(function()
			if DepotStore.card() ~= nil then
				DepotStore.expire(os.clock())
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		DepotStore.clear()
	end,

	getState = function(_self)
		local card = DepotStore.card()
		return { card = if card ~= nil then card.kind else "none" }
	end,
}

return DepotServiceClient
