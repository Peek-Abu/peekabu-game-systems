--!strict
--[=[
	ShiftLandingCard: the landing status card, on the kit's depth stack: a cream panel (the route slip's paper, picking
	up where the slip left off) under a grape TONIGHT band with the truck render breaking its top-left corner, the
	map's site under it (desktop; on a phone the heading is the card's first line, in Gloom grape), then one row each for Temp, Time and Weather (a body label, the value in display type;
	the time in coral, the kit's colour for time) and Danger with the map's Gloom drops (the kit's faceless Gloom
	render). It sits on the HUD's left side (ShiftLandingViewModel.frame) and slides in from the left edge while it
	fades in, by `alpha` (a binding: 0 gone, 1 in), out of the way of play. Laid out in HUD design px (ShiftLandingHud
	draws it inside PaperHudFrame). Presentational (exempt; story in ShiftLandingCard.story; words, place and motion
	specced in ShiftLandingViewModel, timing in ShiftLandingRules).

	@class ShiftLandingCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type ShiftLandingCardProps = {
	view: ShiftLandingViewModel.LandingView,
	layout: UIPaperConstants.Layout,
	-- The HUD's area in design px (usePaperHudScale.viewport).
	viewport: Vector2,
	alpha: React.Binding<number>,
}

-- Room around the panel inside the fading group, so the corner render and the hard drops are not clipped.
local MARGIN = 40

type Metrics = {
	band: number,
	title: number,
	place: number?,
	rowsTop: number,
	row: number,
	label: number,
	value: number,
	drop: number,
	pad: number,
	labelWidth: number,
}

local METRICS: { [UIPaperConstants.Layout]: Metrics } = {
	desktop = {
		band = 60,
		title = 34,
		place = 17,
		rowsTop = 94,
		row = 40,
		label = 19,
		value = 26,
		drop = 34,
		pad = 22,
		labelWidth = 110,
	},
	-- Phone: no band (too narrow for one); the heading is the card's first line.
	phone = {
		band = 0,
		title = 20,
		place = nil,
		rowsTop = 34,
		row = 21,
		label = 13,
		value = 15,
		drop = 20,
		pad = 10,
		labelWidth = 56,
	},
}

local VALUE_MEANING: { UIToonConstants.Meaning } = { "white", "coral", "white" }

local function ShiftLandingCard(props: ShiftLandingCardProps): React.ReactNode
	local view = props.view
	local layout: UIPaperConstants.Layout = props.layout
	local size = ShiftLandingViewModel.SIZE[layout]
	local metrics = METRICS[layout]
	local frame = ShiftLandingViewModel.frame(layout, props.viewport)
	local width = size.X - 2 * metrics.pad
	local face: { [string]: React.ReactNode } = {}
	local placeSize = metrics.place
	if placeSize ~= nil then
		face.place = e(ToonText, {
			text = view.place,
			font = "body",
			textSize = placeSize,
			position = UDim2.fromOffset(metrics.pad, metrics.band + 8),
			size = UDim2.fromOffset(width, placeSize + 6),
			fit = true,
			zIndex = 3,
		})
	end
	local function label(index: number, text: string): React.ReactNode
		return e(ToonText, {
			text = text,
			font = "body",
			textSize = metrics.label,
			alignY = "center",
			position = UDim2.fromOffset(metrics.pad, metrics.rowsTop + (index - 1) * metrics.row),
			size = UDim2.fromOffset(metrics.labelWidth, metrics.row),
			fit = true,
			zIndex = 3,
		})
	end
	for index, row in view.rows do
		face[`label{index}`] = label(index, row.label)
		face[`value{index}`] = e(ToonText, {
			text = row.value,
			meaning = VALUE_MEANING[index] or "white",
			textSize = metrics.value,
			align = "right",
			alignY = "center",
			position = UDim2.fromOffset(metrics.pad + metrics.labelWidth, metrics.rowsTop + (index - 1) * metrics.row),
			size = UDim2.fromOffset(width - metrics.labelWidth, metrics.row),
			fit = true,
			zIndex = 3,
		})
	end
	-- Danger: the map's Gloom drops, right-aligned like the values.
	local dangerIndex = #view.rows + 1
	face.dangerLabel = label(dangerIndex, view.danger)
	local dropsTop = metrics.rowsTop + (dangerIndex - 1) * metrics.row + (metrics.row - metrics.drop) / 2
	for drop = 1, view.drops do
		face[`drop{drop}`] = e(ToonIcon, {
			icon = "gloom",
			anchor = Vector2.new(1, 0),
			position = UDim2.fromOffset(size.X - metrics.pad - (drop - 1) * (metrics.drop + 4), dropsTop),
			size = UDim2.fromOffset(metrics.drop, metrics.drop),
			drop = if layout == "phone" then 2 else 3,
			zIndex = 3,
		})
	end
	local phone = layout == "phone"
	if phone then
		face.heading = e(ToonText, {
			text = view.heading,
			textSize = metrics.title,
			meaning = "grape",
			align = "left",
			position = UDim2.fromOffset(metrics.pad, 6),
			size = UDim2.fromOffset(width, metrics.title + 6),
			fit = true,
			zIndex = 3,
		})
	end
	local alpha = props.alpha
	return e("CanvasGroup", {
		Position = alpha:map(function(value: number): UDim2
			return UDim2.fromOffset(ShiftLandingViewModel.slide(value, frame.X, size.X) - MARGIN, frame.Y - MARGIN)
		end),
		Size = UDim2.fromOffset(size.X + 2 * MARGIN, size.Y + 2 * MARGIN),
		BackgroundTransparency = 1,
		GroupTransparency = alpha:map(function(value: number): number
			return 1 - math.clamp(value, 0, 1)
		end),
		Visible = alpha:map(function(value: number): boolean
			return value > 0
		end),
	}, {
		panel = e(ToonPanel, {
			size = size,
			position = UDim2.fromOffset(MARGIN, MARGIN),
			radius = if phone then 16 else 22,
			header = if phone
				then nil
				else {
					title = view.heading,
					icon = "truck",
					height = metrics.band,
					titleSize = metrics.title,
				},
			children = face,
		}),
	})
end

return ShiftLandingCard
