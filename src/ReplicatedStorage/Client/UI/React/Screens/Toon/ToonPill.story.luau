--!strict
--[=[
	ToonPill.story: The Gleam counter with its coin and + button, tags with a sticker tilt, number pills. In Studio's edit mode (UI Labs).

	@class ToonPill.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPill = require(Toon.ToonPill)
local ToonButton = require(Toon.ToonButton)

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
	controls = { Amount = "1,240" },
}, function(props)
	local controls = props.controls
	local function noop() end
	local nodes: { [string]: React.ReactNode } = {}
	local plus: React.ReactNode = e(ToonButton, {
		variant = "primary",
		text = "+",
		textSize = 40,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, 0),
		size = UDim2.fromOffset(62, 58),
		onActivated = noop,
	})
	nodes.gleam = e(ToonPill, {
		text = controls.Amount,
		meaning = "gold",
		textSize = 54,
		icon = "gleam",
		iconSize = 100,
		small = false,
		trailing = plus,
		trailingWidth = 80,
		position = UDim2.fromOffset(60, 60),
		size = UDim2.fromOffset(340, 76),
	})
	nodes.tonight = e(ToonPill, {
		text = "TONIGHT",
		hue = "mint",
		textSize = 24,
		tilt = -6,
		position = UDim2.fromOffset(460, 70),
		size = UDim2.fromOffset(150, 44),
	})
	nodes.level = e(ToonPill, {
		text = "LV 3",
		hue = "coral",
		textSize = 24,
		tilt = 6,
		position = UDim2.fromOffset(640, 70),
		size = UDim2.fromOffset(100, 44),
	})
	nodes.worth = e(ToonPill, {
		text = "36",
		meaning = "gold",
		icon = "gleam",
		textSize = 24,
		position = UDim2.fromOffset(460, 160),
		size = UDim2.fromOffset(110, 40),
	})
	nodes.timer = e(ToonPill, {
		text = "0:12",
		hue = "coral",
		textSize = 28,
		position = UDim2.fromOffset(600, 160),
		size = UDim2.fromOffset(100, 44),
	})
	return backdrop(nodes)
end)
