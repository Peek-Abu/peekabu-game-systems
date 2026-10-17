--!strict
--[=[
	ToonSlot.story: The hotbar slot: selected with a charge pill, valuables with their worth, empty and disabled. In Studio's edit mode (UI Labs).

	@class ToonSlot.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSlot = require(Toon.ToonSlot)
local UIToonConstants = require(Toon.UIToonConstants)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

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
	controls = { Side = 104 },
}, function(props)
	local controls = props.controls
	local function noop() end
	local nodes: { [string]: React.ReactNode } = {}
	local side = controls.Side
	type Slot = {
		hotkey: string,
		icon: UIAssets.ToonIcon?,
		caption: string?,
		captionIcon: UIAssets.ToonIcon?,
		meaning: UIToonConstants.Meaning?,
		selected: boolean?,
		disabled: boolean?,
	}
	local slots: { Slot } = {
		{ hotkey = "1", icon = "vacuum", caption = "58%", meaning = "grape", selected = true },
		{ hotkey = "2", icon = "monitor", caption = "36", captionIcon = "gleam", meaning = "gold" },
		{ hotkey = "3", icon = "fishtank", caption = "120", captionIcon = "gleam", meaning = "gold" },
		{ hotkey = "4" },
		{ hotkey = "5", icon = "stapler", disabled = true },
	}
	for index, slot in slots do
		nodes["slot" .. index] = e(ToonSlot, {
			side = side,
			hotkey = slot.hotkey,
			icon = slot.icon,
			caption = slot.caption,
			captionIcon = slot.captionIcon,
			captionMeaning = slot.meaning,
			selected = slot.selected,
			disabled = slot.disabled,
			position = UDim2.fromOffset(60 + (index - 1) * (side + 24), 80),
			onActivated = noop,
		})
	end
	return backdrop(nodes)
end)
