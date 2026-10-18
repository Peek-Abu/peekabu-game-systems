--!strict
--[=[
	ToastStack.story: the toast stack with sample toasts, in Studio's edit mode (UI Labs).

	@class ToastStack.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local ToastStack = require(ReplicatedStorage.Client.UI.React.Screens.Hud.ToastStack)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Text = "You hear Harlow pacing faster…",
		Count = 2,
	},
}, function(props)
	local controls = props.controls
	ToastStore.toasts({})
	for _ = 1, controls.Count do
		ToastStore.push(controls.Text, "info", 60, os.clock())
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		stack = e(ToastStack),
	})
end)
