--!strict
--[=[
	Slot.story: the whole rarity ladder plus an empty slot, side by side, in Studio's edit mode.

	This is the case that cannot be checked in-game yet — an EMPTY slot has no way to appear until the
	equipment paperdoll lands, and no single character carries one item of every rarity.

	@class Slot.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local Slot = require(ReplicatedStorage.Client.UI.React.Primitives.Slot)
local StoryFixtures = require(ReplicatedStorage.Client.UI.React.StoryFixtures)

local e = React.createElement

local CELL_PX = 90

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Selected = false,
		ShowEmpty = true,
		Quantity = 1,
		-- PREVIEW: rotbound is a prop, not data (see StatusDisplay). Washes every filled slot in the
		-- status tint, which is how the treatment reads in the GRID rather than only on an open card.
		Rotbound = false,
	},
}, function(props)
	local controls = props.controls

	local children: { [string]: React.ReactNode } = {
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL_PX, CELL_PX),
			CellPadding = UDim2.fromOffset(Tokens.space.sm, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, item in StoryFixtures.rarityLadder() do
		local shown = table.clone(item)
		shown.quantity = if controls.Quantity > 1 then controls.Quantity else nil
		children[item.key] = e(Slot, {
			item = shown,
			layoutOrder = index,
			selected = controls.Selected,
			status = if controls.Rotbound then "rotbound" else nil,
			onActivate = function() end,
		})
	end

	if controls.ShowEmpty then
		children.empty = e(Slot, { layoutOrder = 0, selected = controls.Selected })
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
		BorderSizePixel = 0,
	}, children)
end)
