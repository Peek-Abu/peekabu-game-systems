--!strict
--[=[
	ToonCooldown.story: an ability's cooldown chip at the sizes the screens draw it (desktop and phone), on the grape
	ability card, with a minute-long one for range. In Studio's edit mode (UI Labs).

	@class ToonCooldown.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonCooldown = require(Toon.ToonCooldown)
local ToonSurface = require(Toon.ToonSurface)

local e = React.createElement

-- The chip sizes the ability cards use: desktop and phone.
local SIZES: { Vector2 } = { Vector2.new(84, 72), Vector2.new(56, 46) }

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Seconds = 8 },
}, function(props)
	local nodes: { [string]: React.ReactNode } = {}
	for index, chip in SIZES do
		for column, seconds in { props.controls.Seconds, 25, 90 } do
			nodes[`chip{index}_{column}`] = e(ToonCooldown, {
				seconds = seconds,
				height = chip.Y,
				size = UDim2.fromOffset(chip.X, chip.Y),
				position = UDim2.fromOffset(60 + (column - 1) * 140, 60 + (index - 1) * 120),
			})
		end
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, {
		card = e(ToonSurface, {
			hue = "grape",
			radius = 20,
			position = UDim2.fromOffset(20, 20),
			size = UDim2.fromOffset(480, 280),
			children = nodes,
		}),
	})
end)
