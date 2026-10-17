--!strict
--[=[
	ToonIcon.story: Every kit icon with its hard ink drop, and greyed. In Studio's edit mode (UI Labs).

	@class ToonIcon.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

local e = React.createElement

local function backdrop(children: { [string]: React.ReactNode }): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, children)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Greyed = false },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	local index = 0
	for name: UIAssets.ToonIcon in UIAssets.toonIcons do
		index += 1
		nodes[name] = e(ToonIcon, {
			icon = name,
			greyed = controls.Greyed,
			position = UDim2.fromOffset(30 + ((index - 1) % 10) * 112, 30 + math.floor((index - 1) / 10) * 120),
			size = UDim2.fromOffset(96, 96),
		})
	end
	return backdrop(nodes)
end)
