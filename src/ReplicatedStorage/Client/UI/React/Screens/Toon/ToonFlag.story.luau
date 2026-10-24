--!strict
--[=[
	ToonFlag.story: Rarity flags in every rarity colour, New! and Soon tags. In Studio's edit mode (UI Labs).

	@class ToonFlag.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonFlag = require(Toon.ToonFlag)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local RARITIES: { UIToonConstants.Rarity } = { "default", "uncommon", "rare", "epic", "legendary", "odd" }

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
}, function()
	local nodes: { [string]: React.ReactNode } = {}
	for index, rarity: UIToonConstants.Rarity in RARITIES do
		nodes[rarity] = e(ToonFlag, {
			text = string.upper(rarity),
			rarity = rarity,
			position = UDim2.fromOffset(40 + (index - 1) * 150, 60),
			size = UDim2.fromOffset(130, 38),
		})
	end
	nodes.new = e(
		ToonFlag,
		{ text = "New!", hue = "coral", position = UDim2.fromOffset(40, 140), size = UDim2.fromOffset(90, 38) }
	)
	nodes.soon = e(ToonFlag, {
		text = "Soon",
		hue = "steel",
		tilt = 3,
		position = UDim2.fromOffset(160, 140),
		size = UDim2.fromOffset(90, 38),
	})
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("2B1856") }, nodes)
end)
