--!strict
--[=[
	ToonButton.story: Every variant in every state (default, hover by pointing, disabled, selected, receded) and the three layouts. In Studio's edit mode (UI Labs).

	@class ToonButton.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
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
	controls = { Text = "DEPART", Disabled = false },
}, function(props)
	local controls = props.controls
	local function noop() end
	local nodes: { [string]: React.ReactNode } = {}
	local variants: { ToonStyleViewModel.Variant } = { "primary", "gleam", "danger", "secondary", "grape", "lilac" }
	for row, variant: ToonStyleViewModel.Variant in variants do
		nodes[variant] = e(ToonButton, {
			variant = variant,
			text = controls.Text,
			icon = if variant == "primary" then "truck" elseif variant == "gleam" then "gleam" else nil,
			textSize = 28,
			position = UDim2.fromOffset(40, 30 + (row - 1) * 84),
			size = UDim2.fromOffset(240, 64),
			disabled = controls.Disabled,
			onActivated = noop,
		})
		nodes[variant .. "Selected"] = e(ToonButton, {
			variant = variant,
			text = controls.Text,
			textSize = 28,
			selected = true,
			position = UDim2.fromOffset(320, 30 + (row - 1) * 84),
			size = UDim2.fromOffset(240, 64),
			onActivated = noop,
		})
		nodes[variant .. "Receded"] = e(ToonButton, {
			variant = variant,
			text = controls.Text,
			textSize = 28,
			receded = true,
			position = UDim2.fromOffset(600, 30 + (row - 1) * 84),
			size = UDim2.fromOffset(240, 64),
			onActivated = noop,
		})
	end
	type Tile = { variant: ToonStyleViewModel.Variant, icon: UIAssets.ToonIcon, label: string }
	local tiles: { Tile } = {
		{ variant = "gleam", icon = "jobs", label = "JOBS" },
		{ variant = "grape", icon = "locker", label = "LOCKER" },
		{ variant = "primary", icon = "guide", label = "GUIDE" },
		{ variant = "lilac", icon = "settings", label = "SETTINGS" },
	}
	for index, tile in tiles do
		nodes["tile" .. index] = e(ToonButton, {
			variant = tile.variant,
			layout = "tile",
			icon = tile.icon,
			text = tile.label,
			textSize = 26,
			badge = if index == 1 then "NEW" else nil,
			position = UDim2.fromOffset(900 + (index - 1) * 150, 60),
			size = UDim2.fromOffset(124, 124),
			disabled = controls.Disabled,
			onActivated = noop,
		})
	end
	nodes.iconOnly = e(ToonButton, {
		variant = "grape",
		layout = "icon",
		icon = "grab",
		position = UDim2.fromOffset(900, 260),
		size = UDim2.fromOffset(110, 110),
		onActivated = noop,
	})
	return backdrop(nodes)
end)
