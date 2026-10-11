--!strict
--[=[
	CatchRehiredPanel.story: the HR "Rehired." notice in Studio's edit mode (UI Labs), for the side-by-side check against
	Figma 4c (22:263, desktop) and 4e (22:299, phone). `Phone` switches to the phone layout drawn in an 844x390
	landscape-phone frame; `Dropped` lists two dropped items or "Dropped: nothing.". Built from CatchViewModel.rehired
	with fixture inputs (just before the respawn), so it never touches the stores.

	@class CatchRehiredPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CatchRehiredPanel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchRehiredPanel)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

-- Figma 4e: a landscape phone (iPhone 14).
local PHONE_WIDTH = 844
local PHONE_HEIGHT = 390
-- Story time: one second before the respawn.
local NOW = 0

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Phone = false,
		Dropped = true,
	},
}, function(props)
	local phone: boolean = props.controls.Phone
	local dropped: boolean = props.controls.Dropped
	local me: PublicPlayerTypes.PublicPlayer = { dead = true, caughtUntil = NOW + 1 }
	local view = CatchViewModel.rehired({
		report = {
			room = "Copy room",
			clock = 222,
			backAt = NOW + 1,
			dropped = if dropped then { "Monitor", "Plaque" } else {},
		},
		me = me,
		name = "you",
		rehiredAt = nil,
		nowServer = NOW,
		nowClock = NOW,
		phone = phone,
	})
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if phone then UDim2.fromOffset(PHONE_WIDTH, PHONE_HEIGHT) else UDim2.fromScale(1, 1),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = phone,
		}, {
			panel = if view ~= nil then e(CatchRehiredPanel, { view = view, layout = layout }) else nil,
		}),
	})
end)
