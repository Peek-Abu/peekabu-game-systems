--!strict
--[=[
	ToonPulse.story: a PUNCH IN! button asking to be pressed (Active) or resting. In Studio's edit mode (UI Labs).

	@class ToonPulse.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPulse = require(Toon.ToonPulse)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Active = true },
}, function(props)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, {
		pulse = e(ToonPulse, {
			active = props.controls.Active == true,
			position = UDim2.fromOffset(160, 120),
			size = UDim2.fromOffset(290, 56),
			children = {
				button = e(ToonButton, {
					text = "PUNCH IN!",
					textSize = 30,
					variant = "primary",
					size = UDim2.fromScale(1, 1),
					onActivated = function() end,
				}),
			},
		}),
	})
end)
