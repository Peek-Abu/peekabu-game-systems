--!strict
--[=[
	ToonBackdrop.story: the menu backdrop in Pippa's coral and in the night purple, with rays. In Studio's edit mode
	(UI Labs).

	@class ToonBackdrop.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ToonBackdrop = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonBackdrop)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Night = false },
}, function(props)
	local night = props.controls.Night == true
	return e(ToonBackdrop, {
		top = if night then Color3.fromHex("4D3290") else Color3.fromHex("FF8A4C"),
		bottom = if night then Color3.fromHex("170B33") else Color3.fromHex("7A2A12"),
		rays = { position = UDim2.fromScale(0.5, 0.45), size = 0.8, color = Color3.fromHex("FFC29A") },
	})
end)
