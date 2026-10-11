--!strict
--[=[
	ShiftHudPanel.story: the Shift HUD filling the viewport on the dark office (each piece anchors to its screen edge, so
	resize the viewport to check 1366x768), in Studio's edit mode (UI Labs), for the
	side-by-side check against Figma 1a (6:2), 1b (6:67) and 1c (6:136). `Variant` picks the frame, `SecondsLeft` sets
	the clock (story time is 0) and `Phone` switches to the phone layout (empty until Task 10).

	@class ShiftHudPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftStoryFixtures = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures)

local e = React.createElement

local NORMAL = "1a normal"
local QUOTA_MET = "1b quota met"
local OVERTIME = "1c overtime + clock-out"

local function changesFor(variant: string, secondsLeft: number): ShiftStoryFixtures.SnapshotChanges
	if variant == QUOTA_MET then
		return { endsAt = secondsLeft, cleared = 362, quotaMet = true }
	elseif variant == OVERTIME then
		return {
			endsAt = secondsLeft,
			cleared = 362,
			quotaMet = true,
			stage = "overtime",
			tier = 2,
			sub = "clockout",
			clockOutAt = 7,
		}
	end
	return { endsAt = secondsLeft }
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Variant = UILabs.Choose({ NORMAL, QUOTA_MET, OVERTIME }),
		Phone = false,
		SecondsLeft = 252,
	},
}, function(props)
	local variant: string = props.controls.Variant
	local phone: boolean = props.controls.Phone
	local secondsLeft: number = props.controls.SecondsLeft
	local snapshot = ShiftStoryFixtures.snapshot(changesFor(variant, secondsLeft))
	local view = ShiftHudViewModel.hud(snapshot, ShiftStoryFixtures.me, 0, false)
	local roster = ShiftCrewViewModel.roster(
		snapshot.crew,
		ShiftStoryFixtures.players,
		ShiftStoryFixtures.names,
		snapshot.truck,
		variant == OVERTIME,
		0
	)
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		hud = if view ~= nil then e(ShiftHudPanel, { view = view, roster = roster, layout = layout }) else nil,
	})
end)
