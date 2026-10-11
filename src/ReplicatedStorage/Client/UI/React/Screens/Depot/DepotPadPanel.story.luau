--!strict
--[=[
	DepotPadPanel.story: the truck queue card on the dark office, in Studio edit mode (UI Labs), for the check against
	Figma 3a (desktop) and 3b (phone). `Aboard` is how many of the four seats are filled (you are the last), `SecondsLeft`
	the departure countdown, `Departing` swaps the timer for the LEAVING stamp and disables DEPART NOW, `Phone` switches
	to the phone layout. It builds its own pad and renders the view model output, so it never touches the stores.

	@class DepotPadPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local DepotPadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadPanel)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

local ME = 1
local CREW_NAMES: { [number]: string } = { [2] = "Sam", [3] = "Alex", [4] = "Riley" }
local NOW = 100
local CAPACITY = 4

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Aboard = 3,
		SecondsLeft = 11,
		Departing = false,
		Phone = false,
	},
}, function(props)
	local aboard: number = math.clamp(props.controls.Aboard, 1, CAPACITY)
	local secondsLeft: number = props.controls.SecondsLeft
	local departing: boolean = props.controls.Departing
	local phone: boolean = props.controls.Phone

	-- The crew who got there first, then you.
	local members: { number } = {}
	for userId = 2, aboard do
		table.insert(members, userId)
	end
	table.insert(members, ME)
	local pad: QueueTypes.PadSnapshot = {
		members = members,
		capacity = CAPACITY,
		destination = "shift",
		endsAt = if departing then nil else NOW + secondsLeft,
		departing = departing,
	}
	local view = DepotPadViewModel.pad(pad, ME, CREW_NAMES, 2, NOW, phone)
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		card = if view ~= nil
			then e(DepotPadPanel, {
				view = view,
				layout = layout,
				onDepart = function() end,
			})
			else nil,
	})
end)
