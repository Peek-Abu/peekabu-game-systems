--!strict
--[=[
	ShiftTimeCard: the punch-clock time card (Figma 1a-1c "Punch clock", 360x132, top centre): the red "HARLOW & FINCH —
	TIME CARD" band, five punch holes down the left edge (shift progress), the stage label, the Roboto Mono clock (red
	in overtime), OUT and the pressure pips; in overtime a "SALVAGE ×1.5" rubber stamp drops in under the card.
	On phone (Figma 1d/1e "Punch clock (compact)", 210x58 at top centre y 8) the card drops the band, the holes and the
	stamp: a red left edge, the clock and one line (OUT, or OVERTIME in red) over the three pips. Presentational: it
	draws the HudView it is given.

	@class ShiftTimeCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

export type ShiftTimeCardProps = {
	view: ShiftHudViewModel.HudView,
	layout: UIPaperConstants.Layout,
	-- How far the centred card and stamp move right (ShiftHudViewModel.centreShift); 0 when nil.
	centreShift: number?,
}

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop
local PHONE_TEXT = UIPaperConstants.TEXT.phone
-- Figma 1a: the card's top edge, and the overtime stamp's top edge (1c "Stamp" at y 166).
-- Both are anchored to the top centre: the card spans x 780-1140 (centred on 1920), the stamp's centre is 6 px right.
local CARD_TOP = 20
local STAMP_TOP = 166
local STAMP_CENTRE_OFFSET = 6
-- Content positions are Figma's minus the 26 px band (PaperSheet insets the content by the band).
local HOLE_TOP = 12
local HOLE_STEP = 18
local PIP_STEP = 32

local function card(view: ShiftHudViewModel.HudView, shift: number): React.ReactNode
	local holes: { [string]: React.ReactNode } = {}
	for index = 1, ShiftHudViewModel.PUNCH_HOLES do
		-- A punched hole is a dark slot; an unpunched one is a faint outline (shift progress, 1/5 each).
		holes[`hole{index}`] = e("Frame", {
			Position = UDim2.fromOffset(16, HOLE_TOP + (index - 1) * HOLE_STEP),
			Size = UDim2.fromOffset(10, 16),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = if index <= view.punched then 0 else 0.8,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	end
	local pips: { [string]: React.ReactNode } = {}
	for index = 1, ShiftHudViewModel.PRESSURE_PIPS do
		pips[`pip{index}`] = e("Frame", {
			Position = UDim2.fromOffset(236 + (index - 1) * PIP_STEP, 72),
			Size = UDim2.fromOffset(26, 12),
			BackgroundColor3 = COLOR.stamp,
			BackgroundTransparency = if index <= view.pressure then 0 else 0.75,
			BorderSizePixel = 0,
		})
	end
	local children: { [string]: React.ReactNode } = {
		holes = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holes),
		label = e(PaperLabel, {
			text = view.clockLabel,
			role = "body",
			size = TEXT.label,
			position = UDim2.fromOffset(40, 10),
			frame = UDim2.fromOffset(192, 22),
			autoSize = false,
			wrapped = false,
		}),
		time = e(PaperLabel, {
			text = view.time,
			role = "timer",
			size = TEXT.timer,
			position = UDim2.fromOffset(40, 26),
			frame = UDim2.fromOffset(190, 76),
			autoSize = false,
			wrapped = false,
			color = if view.overtime then COLOR.stamp else COLOR.ink,
		}),
		out = e(PaperLabel, {
			text = view.outText,
			role = "body",
			size = TEXT.label,
			position = UDim2.fromOffset(236, 10),
			frame = UDim2.fromOffset(110, 22),
			autoSize = false,
			wrapped = false,
		}),
		pressure = e(PaperLabel, {
			text = "PRESSURE",
			role = "body",
			size = TEXT.label,
			position = UDim2.fromOffset(236, 46),
			frame = UDim2.fromOffset(110, 22),
			autoSize = false,
			wrapped = false,
		}),
		pips = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pips),
	}
	return e(PaperSheet, {
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, shift, 0, CARD_TOP),
		size = UDim2.fromOffset(360, 132),
		paper = COLOR.cream,
		band = "HARLOW & FINCH — TIME CARD",
		padding = 0,
		children = children,
	})
end

-- Figma 1d "Punch clock (compact)": (317, 8) 210x58 on 844, centred; an 8 px red edge instead of the band.
local PHONE_TOP = 8
local PHONE_EDGE = 8
local PHONE_PIP_LEFT = 122
local PHONE_PIP_STEP = 24

local function phoneCard(view: ShiftHudViewModel.HudView): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		edge = e("Frame", {
			Size = UDim2.new(0, PHONE_EDGE, 1, 0),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
		}),
		time = e(PaperLabel, {
			text = view.time,
			role = "timer",
			size = PHONE_TEXT.timer,
			position = UDim2.fromOffset(18, 6),
			frame = UDim2.fromOffset(100, 42),
			autoSize = false,
			wrapped = false,
		}),
		sub = e(PaperLabel, {
			text = view.compactSub,
			role = "heading",
			size = PHONE_TEXT.label,
			color = if view.overtime then COLOR.stamp else COLOR.ink,
			position = UDim2.fromOffset(PHONE_PIP_LEFT, 6),
			frame = UDim2.fromOffset(84, 21),
			autoSize = false,
			wrapped = false,
		}),
	}
	for index = 1, ShiftHudViewModel.PRESSURE_PIPS do
		children[`pip{index}`] = e("Frame", {
			Position = UDim2.fromOffset(PHONE_PIP_LEFT + (index - 1) * PHONE_PIP_STEP, 34),
			Size = UDim2.fromOffset(18, 10),
			BackgroundColor3 = COLOR.stamp,
			BackgroundTransparency = if index <= view.pressure then 0 else 0.8,
			BorderSizePixel = 0,
		})
	end
	return e(PaperSheet, {
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, PHONE_TOP),
		size = UDim2.fromOffset(210, 58),
		paper = COLOR.cream,
		padding = 0,
		children = children,
	})
end

local function ShiftTimeCard(props: ShiftTimeCardProps): React.ReactNode
	local view = props.view
	if props.layout == "phone" then
		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, { card = phoneCard(view) })
	end
	local shift = props.centreShift or 0
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		card = card(view, shift),
		-- Mounted only in overtime, so it drops in (pop) once as overtime begins.
		stamp = if view.overtime
			then e(PaperStamp, {
				text = `SALVAGE ×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}`,
				size = 30,
				tilt = UIPaperConstants.STAMP_TILT,
				pop = true,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, STAMP_CENTRE_OFFSET + shift, 0, STAMP_TOP),
			})
			else nil,
	})
end

return ShiftTimeCard
