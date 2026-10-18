--!strict
--[=[
	DepotCard: the travel-card HUD widget (registered by DepotServiceClient). While DepotStore holds a card it draws
	DepotCardPanel with the card's lines (DepotCardViewModel) at the game's one UI scale (PaperHudScaleViewModel.scale, desktop rule: the 520x260 card is a desktop design),
	keyed by the card's expiry so every card mounts fresh (the drive card's truck starts at the left again).
	DepotServiceClient moves the store on as cards expire.

	@class DepotCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)

local function DepotCard(): React.ReactNode
	local card = ReactCharm.useAtom(DepotStore.card)
	local viewport = usePaperViewport()
	if card == nil then
		return nil
	end
	local props: DepotCardPanel.DepotCardPanelProps = {
		drive = if card.kind == "drive" then DepotCardViewModel.drive(card) else nil,
		arrival = if card.kind == "arrival" then DepotCardViewModel.arrival(card) else nil,
		scale = PaperHudScaleViewModel.scale(viewport, "desktop"),
	}
	local keyed: { [string]: React.ReactNode } = {
		[`card{card.expiresAt}`] = React.createElement(DepotCardPanel, props),
	}
	return React.createElement(React.Fragment, nil, keyed)
end

return DepotCard
