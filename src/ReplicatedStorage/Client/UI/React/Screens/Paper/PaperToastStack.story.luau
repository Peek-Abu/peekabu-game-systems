--!strict
--[=[
	PaperToastStack.story: the paper toast layer on the dark office, in Studio's edit mode (UI Labs), for the check
	against Figma 1f. `Notes` is how many sticky notes are stacked (the stack shows at most three), `Stamp` shows the
	centre QUOTA MET stamp, `Slips` how many appraisal slips are stacked bottom-right (the newest a jackpot when
	`Jackpot` is on) and `Phone` switches to the phone layout (250 px notes, 40 px stamp). It builds its own
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

local SAMPLE_SLIPS = {
	"Desk lamp\n$18",
	"Employee of the Month plaque\n$42 at the truck",
	"Monitor\n$36",
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Notes = 3,
		Stamp = true,
		Slips = 2,
		Jackpot = true,
		Phone = false,
	},
}, function(props)
	local noteCount: number = props.controls.Notes
	local stamp: boolean = props.controls.Stamp
	local phone: boolean = props.controls.Phone
	local slipCount: number = props.controls.Slips
	local jackpot: boolean = props.controls.Jackpot

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

	for index = 1, slipCount do
		local last = index == slipCount
		table.insert(toasts, {
			id = noteCount + 1 + index,
			text = if last and jackpot
				then "Gold-trim monitor\n$250"
				else SAMPLE_SLIPS[(index - 1) % #SAMPLE_SLIPS + 1],
			style = if last and jackpot then ShiftConstants.TOAST_SLIP_JACKPOT else ShiftConstants.TOAST_SLIP,
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
