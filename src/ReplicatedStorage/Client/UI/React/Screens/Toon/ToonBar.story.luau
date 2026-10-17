--!strict
--[=[
	ToonBar.story: Every meter kind with a label, driven by the Fill control. In Studio's edit mode (UI Labs).

	@class ToonBar.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)

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
	controls = { Fill = 0.59 },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	nodes.gloom = e(ToonBar, {
		kind = "gloom",
		fill = controls.Fill,
		label = "312 / 530",
		position = UDim2.fromOffset(60, 60),
		size = UDim2.fromOffset(760, 44),
	})
	nodes.xp = e(ToonBar, {
		kind = "xp",
		fill = controls.Fill,
		label = "45 / 120 XP",
		position = UDim2.fromOffset(60, 140),
		size = UDim2.fromOffset(760, 40),
	})
	nodes.stamina = e(ToonBar, {
		kind = "stamina",
		fill = controls.Fill,
		position = UDim2.fromOffset(60, 220),
		size = UDim2.fromOffset(380, 24),
	})
	nodes.load = e(ToonBar, {
		kind = "load",
		fill = controls.Fill,
		label = "UNLOCKING THE BUILDING... 64%",
		position = UDim2.fromOffset(60, 290),
		size = UDim2.fromOffset(1100, 44),
	})
	return backdrop(nodes)
end)
