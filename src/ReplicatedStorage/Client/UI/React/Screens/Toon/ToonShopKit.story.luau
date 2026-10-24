--!strict
--[=[
	ToonShopKit.story: the Shop kit pieces together: deal bursts, the Owned stamp, prices (with a real sale's struck
	price) and ribbon flags. In Studio's edit mode (UI Labs).

	@class ToonShopKit.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBurst = require(Toon.ToonBurst)
local ToonFlag = require(Toon.ToonFlag)
local ToonPrice = require(Toon.ToonPrice)
local ToonStamp = require(Toon.ToonStamp)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
}, function()
	local nodes: { [string]: React.ReactNode } = {
		bonus = e(
			ToonBurst,
			{ text = "+20%", sub = "BONUS", hue = "mint", size = 120, position = UDim2.fromOffset(40, 40) }
		),
		sale = e(ToonBurst, { text = "-30%", size = 120, position = UDim2.fromOffset(200, 40) }),
		owned = e(ToonStamp, { text = "OWNED", size = 140, position = UDim2.fromOffset(360, 30) }),
		gleam = e(ToonPrice, {
			currency = "gleam",
			amount = "1,500",
			textSize = 40,
			align = "left",
			position = UDim2.fromOffset(40, 220),
			size = UDim2.fromOffset(300, 60),
		}),
		sold = e(ToonPrice, {
			currency = "credits",
			amount = "1,750",
			was = "2,500",
			textSize = 40,
			align = "left",
			position = UDim2.fromOffset(40, 300),
			size = UDim2.fromOffset(400, 60),
		}),
		legendary = e(ToonFlag, {
			text = "LEGENDARY",
			rarity = "legendary",
			position = UDim2.fromOffset(560, 60),
			size = UDim2.fromOffset(190, 40),
		}),
		new = e(
			ToonFlag,
			{ text = "New!", hue = "coral", position = UDim2.fromOffset(770, 60), size = UDim2.fromOffset(100, 40) }
		),
	}
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("2B1856") }, nodes)
end)
