--!strict
--[=[
	KeyChip: a keyboard key cap ("E", "LMB", "←"): cream, at least square, growing sideways with its legend. The
	prop is `label` because React reserves `key` (it never reaches the component). `transparency` fades the whole cap
	(the desktop key hints sit at MOTION.hintTransparency). Presentational.

	@class KeyChip
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type KeyChipProps = {
	label: string,
	size: number,
	layoutOrder: number?,
	transparency: number?,
}

local COLOR = UIPaperConstants.COLOR

local function KeyChip(props: KeyChipProps): React.ReactNode
	local side = props.size + 10
	local transparency = props.transparency or 0
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(0, side),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLOR.cream,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
	}, {
		minimum = e("UISizeConstraint", { MinSize = Vector2.new(side, side) }),
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		stroke = e("UIStroke", {
			Color = COLOR.ink,
			Thickness = 1,
			Transparency = 1 - (1 - 0.6) * (1 - transparency),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label = e(PaperLabel, {
			text = props.label,
			role = "heading",
			size = props.size,
			color = COLOR.ink,
			transparency = transparency,
			fit = true,
		}),
	})
end

return KeyChip
