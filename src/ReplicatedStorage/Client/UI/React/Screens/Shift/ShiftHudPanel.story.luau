--!strict
--[=[
	ShiftHudPanel.story: the placeholder Shift HUD with sample values, in Studio's edit mode (UI Labs).

	@class ShiftHudPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		SecondsLeft = 312,
		Cleared = 120,
		ClockingOut = false,
	},
}, function(props)
	local controls = props.controls
	local sub: ShiftTypes.ShiftSub = "normal"
	if controls.ClockingOut then
		sub = "clockout"
	end
	local snapshot: ShiftTypes.ShiftSnapshot = {
		phase = "running",
		sub = sub,
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = controls.SecondsLeft,
		clockOutAt = 7,
		quota = 350,
		cleared = controls.Cleared,
		bonus = 40,
		quotaMet = controls.Cleared >= 350,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	local me: PublicPlayerTypes.PublicPlayer = { canister = 2, carrying = "monitor", pocket1 = "plaque" }
	local view = ShiftHudViewModel.hud(snapshot, me, 0)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		hud = if view ~= nil then e(ShiftHudPanel, { view = view }) else nil,
	})
end)
