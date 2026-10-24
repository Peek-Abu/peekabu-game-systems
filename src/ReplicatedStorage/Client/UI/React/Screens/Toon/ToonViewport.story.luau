--!strict
--[=[
	ToonViewport.story: Pippa static on a card, Pippa live (idle playing), Prickles locked and dimmed. Needs the art in ReplicatedStorage.Assets (the hub place). In Studio's edit mode (UI Labs).

	@class ToonViewport.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonViewport = require(Toon.ToonViewport)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Skin = "" },
}, function(props)
	local skin = if props.controls.Skin ~= "" then props.controls.Skin else nil
	local nodes: { [string]: React.ReactNode } = {
		card = e(ToonViewport, {
			employee = "Pippa",
			skin = skin,
			framing = "full",
			position = UDim2.fromOffset(40, 40),
			size = UDim2.fromOffset(220, 300),
		}),
		hero = e(ToonViewport, {
			employee = "Pippa",
			skin = skin,
			live = true,
			framing = "full",
			position = UDim2.fromOffset(300, 20),
			size = UDim2.fromOffset(340, 460),
		}),
		locked = e(ToonViewport, {
			employee = "Prickles",
			framing = "full",
			dim = true,
			position = UDim2.fromOffset(680, 40),
			size = UDim2.fromOffset(220, 300),
		}),
	}
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("7B3FF2") }, nodes)
end)
