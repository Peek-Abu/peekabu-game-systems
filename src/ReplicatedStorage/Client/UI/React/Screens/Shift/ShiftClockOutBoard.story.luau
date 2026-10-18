--!strict
--[=[
	ShiftClockOutBoard.story: the clock-out board in UI Labs. Variant: one of three clocked out (no countdown yet), the
	truck's countdown with two of four out, and the local player on the truck in the countdown's ticking seconds.
	Phone uses the phone sizes.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftClockOutBoard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutBoard)
local ShiftClockOutViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutViewModel)
local ShiftStoryFixtures = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures)

local e = React.createElement

local WAITING = "1 of 3 out"
local COUNTING = "2 of 4: truck leaves"
local ABOARD = "you aboard, last seconds"
local ME = 1

local function changesFor(variant: string): ShiftStoryFixtures.SnapshotChanges
	local now = Workspace:GetServerTimeNow()
	if variant == COUNTING then
		return { punched = { 2, 3 }, crewIn = 4, sub = "clockout", clockOutAt = now + 24 }
	elseif variant == ABOARD then
		return { punched = { 1, 3 }, crewIn = 3, sub = "clockout", clockOutAt = now + 8 }
	end
	return { punched = { 3 }, crewIn = 3 }
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Variant = UILabs.Choose({ WAITING, COUNTING, ABOARD }),
		Phone = false,
	},
}, function(props)
	local variant: string = props.controls.Variant
	local phone: boolean = props.controls.Phone
	local snapshot = ShiftStoryFixtures.snapshot(changesFor(variant))
	-- The fixture crew is three; the four-member variant adds one.
	if variant == COUNTING then
		snapshot.crew = { 1, 2, 3, 4 }
	end
	local view = ShiftClockOutViewModel.board(snapshot, ME)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		board = if view ~= nil then e(ShiftClockOutBoard, { view = view, phone = phone, top = 40 }) else nil,
	})
end)
