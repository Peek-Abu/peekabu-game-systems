--!strict
--[=[
	CatchCctvPanel.story: the CCTV spectating overlay in Studio's edit mode (UI Labs), for the side-by-side check against
	Figma 4b (22:249, desktop) and 4d (22:285, phone). `Phone` switches to the phone layout drawn in an 844x390
	landscape-phone frame (with the "<" / ">" buttons, which print when pressed), `Target` picks Sam carrying a coffee machine
	two rooms from the truck or NO SIGNAL (nobody to watch), and `Dropped` whether the incident report says cargo was
	dropped. Built from CatchViewModel.cctv with fixture inputs, so it never touches the stores.

	@class CatchCctvPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CatchCctvPanel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchCctvPanel)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftStoryFixtures = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures)

local e = React.createElement

local SAM = "Sam carrying"
local NO_SIGNAL = "no signal"
-- Figma 4d: a landscape phone (iPhone 14).
local PHONE_WIDTH = 844
local PHONE_HEIGHT = 390
-- Story time; caught 6 s before the respawn, 3:42 left on the shift clock at the catch.
local NOW = 0

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Phone = false,
		Target = UILabs.Choose({ SAM, NO_SIGNAL }),
		Dropped = true,
	},
}, function(props)
	local phone: boolean = props.controls.Phone
	local target: string = props.controls.Target
	local dropped: boolean = props.controls.Dropped
	local watching = target == SAM
	local me: PublicPlayerTypes.PublicPlayer = { dead = true, caughtUntil = NOW + 6 }
	local feed: PublicPlayerTypes.PublicPlayer =
		{ carrying = "coffeeMachine", room = "Copy room", roomDepth = 2, cam = 4 }
	local view = CatchViewModel.cctv({
		snapshot = ShiftStoryFixtures.snapshot({ endsAt = 168 }),
		me = me,
		report = {
			room = "Copy room",
			clock = 222,
			backAt = NOW + 6,
			dropped = if dropped then { "Coffee machine" } else {},
		},
		targetName = if watching then "Sam" else nil,
		target = if watching then feed else nil,
		now = NOW,
		prevKey = "←",
		nextKey = "→",
		phone = phone,
	})
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	local panel = if view ~= nil
		then e(CatchCctvPanel, {
			view = view,
			layout = layout,
			onPrev = function()
				print("CatchCctvPanel.story: previous teammate")
			end,
			onNext = function()
				print("CatchCctvPanel.story: next teammate")
			end,
			jump = ShiftHudViewModel.arcFor(PHONE_HEIGHT).jump,
		})
		else nil
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		-- On phone, a landscape phone screen centred in the viewport; on desktop, the viewport itself. The office
		-- colour stands in for the teammate's view under the feed.
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if phone then UDim2.fromOffset(PHONE_WIDTH, PHONE_HEIGHT) else UDim2.fromScale(1, 1),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = phone,
		}, { panel = panel }),
	})
end)
