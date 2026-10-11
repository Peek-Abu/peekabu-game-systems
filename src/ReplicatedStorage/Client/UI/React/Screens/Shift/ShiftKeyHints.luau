--!strict
--[=[
	ShiftKeyHints: the desktop key hints row along the bottom of the screen (Figma 1a "key hints", y 1030), just under
	the carry panel: "Hold [LMB] vacuum   [G] drop   [F] throw   [Q] pocket   [E] load / search", each key drawn as a
	KeyChip, in the fluorescent white at 80% opacity, 32 px between hints. Presentational: it draws the hints it is
	given (ShiftHudViewModel.keyHints, from the live bindings); ShiftHudPanel draws it on desktop with a keyboard only.

	@class ShiftKeyHints
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

export type ShiftKeyHintsProps = {
	hints: { ShiftHudViewModel.HintView },
}

local COLOR = UIPaperConstants.COLOR
local SIZE = UIPaperConstants.TEXT.desktop.hint
local FADE = UIPaperConstants.MOTION.hintTransparency
-- Figma 1a puts the row's text at y 1030-1050 on a 1080 screen; the 30 px key caps make the row taller, so its top
-- sits at y 1032 (48 px above the bottom), level with the carry panel's bottom edge, which it must not overlap.
local TOP_FROM_BOTTOM = 48
local HINT_GAP = 32
local PART_GAP = 8

local function words(text: string, order: number): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = "body",
		size = SIZE,
		color = COLOR.fluorescent,
		transparency = FADE,
		fit = true,
		layoutOrder = order,
	})
end

local function hint(view: ShiftHudViewModel.HintView, order: number): React.ReactNode
	local prefix = view.prefix
	return e("Frame", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, PART_GAP),
		}),
		prefix = if prefix ~= nil then words(prefix, 1) else nil,
		key = e(KeyChip, { label = view.key, size = SIZE, transparency = FADE, layoutOrder = 2 }),
		label = words(view.label, 3),
	})
end

local function ShiftKeyHints(props: ShiftKeyHintsProps): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, HINT_GAP),
		}),
	}
	for index, view in props.hints do
		children[`hint{index}`] = hint(view, index)
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -TOP_FROM_BOTTOM),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, children)
end

return ShiftKeyHints
