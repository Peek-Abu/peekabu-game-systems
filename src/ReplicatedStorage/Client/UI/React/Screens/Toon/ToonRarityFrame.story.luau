--!strict
--[=[
	ToonRarityFrame.story: One card per rarity with its halo behind and trim in front (Legendary sparkles, Odd goo). In Studio's edit mode (UI Labs).

	@class ToonRarityFrame.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonRarityFrame = require(Toon.ToonRarityFrame)
local ToonSurface = require(Toon.ToonSurface)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local RARITIES: { UIToonConstants.Rarity } = { "default", "uncommon", "rare", "epic", "legendary", "odd" }

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
}, function()
	local nodes: { [string]: React.ReactNode } = {}
	for index, rarity: UIToonConstants.Rarity in RARITIES do
		local position = UDim2.fromOffset(40 + (index - 1) * 210, 80)
		local size = UDim2.fromOffset(180, 250)
		local trim: { [string]: React.ReactNode } = {
			trim = e(ToonRarityFrame, { rarity = rarity, part = "trim", width = 180, radius = 22, zIndex = 3 }),
		}
		nodes[rarity .. "Halo"] = e(ToonRarityFrame, {
			rarity = rarity,
			part = "halo",
			width = 180,
			radius = 22,
			position = position,
			size = size,
			zIndex = 1,
		})
		nodes[rarity] = e(ToonSurface, {
			hue = "grape",
			shade = UIToonConstants.rarity(rarity),
			position = position,
			size = size,
			radius = 22,
			zIndex = 2,
			children = trim,
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("2B1856") }, nodes)
end)
