--!strict
--[=[
	ToonSurface.story: The depth stack at rest in every hue, plus the small chrome. In Studio's edit mode (UI Labs).

	@class ToonSurface.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local UIToonConstants = require(Toon.UIToonConstants)

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
	controls = { Pattern = true },
}, function(props)
	local controls = props.controls
	local nodes: { [string]: React.ReactNode } = {}
	local hues: { UIToonConstants.Hue } =
		{ "grape", "gold", "mint", "coral", "cream", "night", "sky", "lilac", "steel" }
	for index, hue: UIToonConstants.Hue in hues do
		local pattern: ToonSurface.Pattern = if hue == "cream" then "sparkle" else "bubbles"
		nodes[hue] = e(ToonSurface, {
			hue = hue,
			pattern = if controls.Pattern then pattern else nil,
			position = UDim2.fromOffset(40 + ((index - 1) % 5) * 200, 40 + math.floor((index - 1) / 5) * 160),
			size = UDim2.fromOffset(170, 120),
		})
		nodes[hue .. "Small"] = e(ToonSurface, {
			hue = hue,
			small = true,
			radius = 999,
			position = UDim2.fromOffset(40 + (index - 1) * 110, 380),
			size = UDim2.fromOffset(96, 36),
		})
	end
	return backdrop(nodes)
end)
