--!strict
--[=[
	ToonSparkle.story: Gleam sparkles twinkling on a stagger around a gold number. In Studio's edit mode (UI Labs).

	@class ToonSparkle.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)

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
	controls = { Size = 40 },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	nodes.number = e(ToonText, {
		text = "+585",
		meaning = "gold",
		textSize = 96,
		position = UDim2.fromOffset(120, 100),
		size = UDim2.fromOffset(400, 120),
	})
	nodes.sparkles = e(ToonSparkle, {
		spots = {
			{ position = UDim2.fromOffset(120, 100), size = controls.Size },
			{ position = UDim2.fromOffset(420, 96), size = controls.Size * 0.7 },
			{ position = UDim2.fromOffset(380, 230), size = controls.Size * 0.55 },
		},
		zIndex = 5,
	})
	return backdrop(nodes)
end)
