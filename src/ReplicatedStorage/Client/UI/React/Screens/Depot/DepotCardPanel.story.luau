--!strict
--[=[
	DepotCardPanel.story: the travel cards (Figma World UI 2c, S1) over the dark depot, in Studio's edit mode (UI Labs),
	in a fixed screen-sized frame: `Arrival` switches from the dispatch ticket to the job folder, `Truck` sets the
	truck number (0 hides it), `LongClient` tries a 60-character client and `Phone` draws them at the 844x390 phone's
	scale (0.6). Toggle `Replay` to run the drive card's truck across the road again.

	@class DepotCardPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotCardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardPanel)
local DepotCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotCardViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

local e = React.createElement

local PHONE = Vector2.new(844, 390)
local DESKTOP = Vector2.new(1920, 1080)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Arrival = false,
		Truck = 2,
		LongClient = false,
		Phone = false,
		Replay = false,
	},
}, function(props)
	local contract = DepotConstants.CONTRACTS[1]
	local card: DepotTypes.ShownCard = {
		kind = "drive",
		client = if props.controls.LongClient then string.rep("Pemberton ", 6) else contract.client,
		job = contract.job,
		note = contract.note,
		quota = ShiftConstants.QUOTA,
		truck = math.max(0, math.floor(props.controls.Truck)),
		expiresAt = 0,
	}
	local arrival: boolean = props.controls.Arrival
	if arrival then
		card.kind = "arrival"
	end
	local screen = if props.controls.Phone then PHONE else DESKTOP
	local panelProps: DepotCardPanel.DepotCardPanelProps = {
		drive = if arrival then nil else DepotCardViewModel.drive(card),
		arrival = if arrival then DepotCardViewModel.arrival(card) else nil,
		scale = WorldBillboardViewModel.screenScale(screen),
	}
	-- Keyed by Replay, so flipping it remounts the card and its truck starts again.
	local cards: { [string]: React.ReactNode } = {
		[if props.controls.Replay then "cardA" else "cardB"] = e(DepotCardPanel, panelProps),
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(screen.X, screen.Y),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, cards),
	})
end)
