--!strict
--[=[
	ShiftLandingReadout: one screen of the landing readout, "big stamps" (owner's look C): no card, no panel, no frame.
	Each line is a rendered icon (ToonIcon, with its hard ink drop) and the value in the HUD's toon type (ToonText:
	Luckiest Guy, white fill, ink stroke, hard ink drop), over a soft dark glow (the kit's 9-slice glow tinted ink) so
	it reads on a bright floor. A line whose icon slot is still empty (ShiftLandingViewModel.image) starts its value
	where the icon would have (ShiftLandingViewModel.textLeft). The anomaly level's Gloom drops (the kit's faceless Gloom
	render, drawn as tall as the words' caps) sit side by side under it (ShiftLandingViewModel.dropLeft). The whole screen fades with `alpha` (a binding, one CanvasGroup) and rises a little into place
	(ShiftLandingViewModel.rise). Laid out in HUD design px at `frame` (ShiftLandingHud draws it inside PaperHudFrame).
	Presentational (exempt; story in ShiftLandingReadout.story; words, place and motion specced in
	ShiftLandingViewModel, timing in ShiftLandingRules).

	@class ShiftLandingReadout
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type ShiftLandingReadoutProps = {
	screen: ShiftLandingViewModel.Screen,
	layout: UIPaperConstants.Layout,
	-- The readout's top-left corner in HUD design px (ShiftLandingViewModel.frame).
	frame: Vector2,
	alpha: React.Binding<number>,
}

-- Room around the lines inside the fading group, so the glow, the strokes and the hard drops are not clipped.
local MARGIN = 32
-- The dark glow behind each value: how far it reaches past the text, and how see-through it is.
local GLOW_PAD = table.freeze({ desktop = 26, phone = 16 })
local GLOW_TRANSPARENCY = 0.5

-- A value's width in design px at `size` (Luckiest Guy), measured once per text.
local measured: { [string]: number } = {}
local function widthOf(text: string, size: number): number
	local key = `{size}:{text}`
	local width = measured[key]
	if width == nil then
		width = TextService:GetTextSize(text, size, Enum.Font.LuckiestGuy, Vector2.new(10000, 1000)).X
		measured[key] = width
	end
	return width
end

local function ShiftLandingReadout(props: ShiftLandingReadoutProps): React.ReactNode
	local layout: UIPaperConstants.Layout = props.layout
	local metrics: ShiftLandingViewModel.Metrics = ShiftLandingViewModel.METRICS[layout]
	local pad = GLOW_PAD[layout]
	local nodes: { [string]: React.ReactNode } = {}
	for index, line in props.screen.lines do
		local top = MARGIN + (index - 1) * metrics.line
		local textWidth = widthOf(line.text, metrics.text)
		local left = ShiftLandingViewModel.textLeft(layout, line)
		nodes[`glow{index}`] = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(MARGIN + left - pad, top + metrics.line / 2),
			Size = UDim2.fromOffset(textWidth + 2 * pad, metrics.line + pad),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.glow,
			ImageColor3 = UIToonConstants.COLOR.ink,
			ImageTransparency = GLOW_TRANSPARENCY,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 80, 80),
			ZIndex = 1,
		})
		local image = ShiftLandingViewModel.image(line.icon)
		if image ~= nil then
			nodes[`icon{index}`] = e(ToonIcon, {
				image = image,
				position = UDim2.fromOffset(MARGIN, top + (metrics.line - metrics.icon) / 2),
				size = UDim2.fromOffset(metrics.icon, metrics.icon),
				drop = if layout == "phone" then 3 else 4,
				zIndex = 2,
			})
		end
		nodes[`text{index}`] = e(ToonText, {
			text = line.text,
			textSize = metrics.text,
			align = "left",
			position = UDim2.fromOffset(MARGIN + left, top),
			size = UDim2.fromOffset(metrics.room - left, metrics.line),
			zIndex = 3,
		})
	end
	local dropsTop = MARGIN + #props.screen.lines * metrics.line
	for drop = 1, props.screen.drops do
		nodes[`drop{drop}`] = e(ToonIcon, {
			icon = "gloom",
			position = UDim2.fromOffset(MARGIN + ShiftLandingViewModel.dropLeft(layout, drop), dropsTop),
			size = UDim2.fromOffset(metrics.drop, metrics.drop),
			drop = if layout == "phone" then 3 else 4,
			zIndex = 2,
		})
	end
	local height = ShiftLandingViewModel.blockHeight(layout)
	local alpha = props.alpha
	local frame = props.frame
	return e("CanvasGroup", {
		Position = alpha:map(function(value: number): UDim2
			return UDim2.fromOffset(frame.X - MARGIN, frame.Y - MARGIN + ShiftLandingViewModel.rise(value))
		end),
		Size = UDim2.fromOffset(metrics.room + 2 * MARGIN, height + 2 * MARGIN),
		BackgroundTransparency = 1,
		GroupTransparency = alpha:map(function(value: number): number
			return 1 - math.clamp(value, 0, 1)
		end),
		Visible = alpha:map(function(value: number): boolean
			return value > 0
		end),
	}, nodes)
end

return ShiftLandingReadout
