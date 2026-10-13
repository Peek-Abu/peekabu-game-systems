--!strict
--[=[
	PaperToastStack.story: the paper toast layer on the dark office, in Studio's edit mode (UI Labs), for the check
	against Figma 1f. `Notes` is how many sticky notes are stacked (the stack shows at most three), `Stamp` shows the
	centre QUOTA MET stamp and `Phone` switches to the phone layout (250 px notes, 40 px stamp). It builds its own
	toast list and renders PaperToastStack.Layer, so it never touches the stores.

	@class PaperToastStack.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local PaperToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastStack)
local PaperToastViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

local e = React.createElement

local SAMPLE_TEXT = {
	"Shift started. Clear 350 of trash.",
	"You hear the Manager pacing faster…",
	"Quota met. Keep going or clock out.",
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Notes = 3,
		Stamp = true,
		Phone = false,
	},
}, function(props)
	local noteCount: number = props.controls.Notes
	local stamp: boolean = props.controls.Stamp
	local phone: boolean = props.controls.Phone

	-- Oldest first, like ToastStore; the view model flips it.
	local toasts: { ToastTypes.Toast } = {}
	for index = 1, noteCount do
		table.insert(toasts, {
			id = index,
			text = SAMPLE_TEXT[(index - 1) % #SAMPLE_TEXT + 1],
			style = ShiftConstants.TOAST_STICKY,
			expiresAt = 0,
		})
	end
	if stamp then
		table.insert(toasts, {
			id = noteCount + 1,
			text = "QUOTA MET",
			style = ShiftConstants.TOAST_STAMP,
			expiresAt = 0,
		})
	end

	local layerProps: PaperToastStack.LayerProps = {
		view = PaperToastViewModel.layout(toasts, PaperToastViewModel.MAX_NOTES),
		layout = if phone then "phone" else "desktop",
	}

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		layer = e(PaperToastStack.Layer, layerProps),
	})
end)
