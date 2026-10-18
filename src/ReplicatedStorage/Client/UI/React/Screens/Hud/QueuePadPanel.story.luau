--!strict
--[=[
	QueuePadPanel.story: the placeholder pad panel in Studio's edit mode (UI Labs).

	@class QueuePadPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local QueuePadPanel = require(ReplicatedStorage.Client.UI.React.Screens.Hud.QueuePadPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Aboard = 2,
		Capacity = 4,
		SecondsLeft = 12,
		Departing = false,
	},
}, function(props)
	local controls = props.controls
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		panel = e(QueuePadPanel, {
			aboard = controls.Aboard,
			capacity = controls.Capacity,
			secondsLeft = if controls.Departing then nil else controls.SecondsLeft,
			departing = controls.Departing,
			onDepart = function()
				print("QueuePadPanel.story: Depart now")
			end,
		}),
	})
end)
