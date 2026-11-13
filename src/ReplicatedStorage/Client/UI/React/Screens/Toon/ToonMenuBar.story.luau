--!strict
--[=[
	ToonMenuBar.story: the Inventory's bar (locker render, Crew / Vacuums / Chat wheel with Soon) and the Shop's bar
	(gift render) with both wallets. In Studio's edit mode (UI Labs).

	@class ToonMenuBar.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ToonMenuBar = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMenuBar)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
}, function()
	local function noop() end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("2B1856") }, {
		inventory = e(
			"Frame",
			{ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1 },
			{
				bar = e(ToonMenuBar, {
					title = "INVENTORY",
					icon = "locker",
					tabs = {
						{ id = "crew", text = "Crew", icon = "pippaHappy" },
						{ id = "vacuums", text = "Vacuums", icon = "vacuum" },
						{ id = "wheel", text = "Chat wheel", soon = true },
					},
					current = "crew",
					onTab = noop,
					credits = 3180,
					gleam = 640,
					onClose = noop,
					x = 150,
					height = 76,
					phone = false,
				}),
			}
		),
		shop = e(
			"Frame",
			{ Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1 },
			{
				bar = e(ToonMenuBar, {
					title = "SHOP",
					icon = "shop",
					hue = "coral",
					tabs = {
						{ id = "featured", text = "Featured" },
						{ id = "skins", text = "Skins" },
						{ id = "gleam", text = "Gleam" },
					},
					current = "featured",
					onTab = noop,
					credits = 3180,
					gleam = 640,
					onClose = noop,
					x = 150,
					height = 76,
					phone = false,
				}),
			}
		),
	})
end)
