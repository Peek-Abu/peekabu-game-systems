--!strict
--[=[
	ToonWipe.story: The dirty -> clean squeegee pass over a grape panel (Replay plays it again). In Studio's edit mode (UI Labs).

	@class ToonWipe.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local ToonWipe = require(Toon.ToonWipe)

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
	controls = { Replay = 0 },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	local overlay: { [string]: React.ReactNode } = {}
	overlay.wipe = e(ToonWipe, { radius = 26, replay = tostring(controls.Replay), delay = 0.3 })
	nodes.panel = e(ToonSurface, {
		hue = "grape",
		radius = 26,
		pattern = "bubbles",
		position = UDim2.fromOffset(80, 80),
		size = UDim2.fromOffset(520, 300),
		overlay = overlay,
	})
	return backdrop(nodes)
end)
