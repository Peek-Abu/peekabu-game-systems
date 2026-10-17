--!strict
--[=[
	ShiftTransitPanel.story: the transit screen in Studio's edit mode (UI Labs), in a fixed screen-sized frame: `Cover`
	switches the cover on and off (watch it fade), `Black` shows the plain black cover (booting, a respawn), `Arrived`
	stamps ARRIVED, `Truck` sets the truck number (0 hides it), `LongClient` tries a 60-character client, `Progress` sets the client's readiness (the bar
	catches up and creeps, never back; `Arrived` fills it) and `Phone` draws it at the 844x390 phone's scale.

	@class ShiftTransitPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftTransitPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitPanel)
local ShiftTransitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

local PHONE = Vector2.new(844, 390)
local DESKTOP = Vector2.new(1920, 1080)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Cover = true,
		Black = false,
		Arrived = false,
		Truck = 2,
		LongClient = false,
		Phone = false,
		Progress = 0.45,
	},
}, function(props)
	local snapshot: ShiftTypes.TransitSnapshot = {
		holds = {},
		client = if props.controls.LongClient then string.rep("Pemberton ", 6) else "Harlow & Finch Ltd.",
		truck = math.max(0, math.floor(props.controls.Truck)),
	}
	local cover: ShiftTypes.TransitCover = "none"
	if props.controls.Cover then
		cover = if props.controls.Black then "black" else "slip"
	end
	local screen = if props.controls.Phone then PHONE else DESKTOP
	local panelProps: ShiftTransitPanel.ShiftTransitPanelProps = {
		cover = cover,
		view = ShiftTransitViewModel.slip(snapshot, props.controls.Arrived),
		scale = ShiftTransitViewModel.fit(screen),
		progress = math.clamp(props.controls.Progress, 0, 1),
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(screen.X, screen.Y),
			BackgroundColor3 = UIPaperConstants.COLOR.monitorDeep,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			panel = e(ShiftTransitPanel, panelProps),
		}),
	})
end)
