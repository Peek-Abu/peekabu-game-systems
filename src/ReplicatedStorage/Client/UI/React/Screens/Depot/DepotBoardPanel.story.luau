--!strict
--[=[
	DepotBoardPanel.story: the depot's contract board over the dark depot, in Studio's edit mode (UI Labs), for the
	side-by-side check against Figma 2a (31:458) and 2b (31:516). The board is drawn in a fixed screen-sized frame
	centred in the viewport: `Phone` switches to the 844x390 landscape phone, `Small` draws desktop at 1366x768 (the
	board scales down to fit), `LastShift` shows or omits the returning player's card and `QuotaMet` stamps it.

	@class DepotBoardPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotBoardPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardPanel)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)

local e = React.createElement

local PHONE = Vector2.new(844, 390)
local DESKTOP = Vector2.new(1920, 1080)
local SMALL = Vector2.new(1366, 768)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Phone = false,
		Small = false,
		LastShift = true,
		QuotaMet = true,
	},
}, function(props)
	local phone: boolean = props.controls.Phone
	local small: boolean = props.controls.Small
	local quotaMet: boolean = props.controls.QuotaMet
	local last: DepotTypes.LastShift? = if props.controls.LastShift
		then {
			cleared = if quotaMet then 362 else 214,
			quota = 350,
			bonus = 215,
			catches = 2,
			salvage = 6,
			offered = 9,
			quotaMet = quotaMet,
			rating = if quotaMet then "satisfactory" else "needsImprovement",
			truck = 2,
		}
		else nil
	local screen = if phone then PHONE elseif small then SMALL else DESKTOP
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	local panelProps: DepotBoardPanel.DepotBoardPanelProps = {
		view = DepotBoardViewModel.board(DepotConstants.CONTRACTS[1].id, last, phone),
		layout = layout,
		scale = DepotBoardViewModel.fit(screen, phone),
		onClose = function()
			print("close")
		end,
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		-- The depot behind the board (Figma's graybox garage placeholder), in a fixed screen-sized frame.
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(screen.X, screen.Y),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, { board = e(DepotBoardPanel, panelProps) }),
	})
end)
