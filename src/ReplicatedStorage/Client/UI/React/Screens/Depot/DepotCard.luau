--!strict
--[=[
	DepotCard: the travel-card HUD widget (registered by DepotServiceClient). Draws DepotCardPanel while
	DepotStore holds a card; DepotServiceClient moves the store on as cards expire.

	@class DepotCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)

local function DepotCard(): React.ReactNode
	local card = ReactCharm.useAtom(DepotStore.card)
	if card == nil then
		return nil
	end
	-- Widened on purpose: the panel takes any kind string (it shows an unknown one as written).
	local kind: string = card.kind
	return React.createElement(DepotCardPanel, { kind = kind, title = card.title, body = card.body })
end

return DepotCard
