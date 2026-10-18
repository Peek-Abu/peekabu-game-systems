--!strict
--[=[
	ShiftGloomMeter: the shift's one big plate, top centre (V1 shift renders): the Gloom meter and the timer joined.
	The Gloom render breaks its left edge, CLEAN THE GLOOM (CONTRACT MET!, OVERTIME!) over the goo bar with the crew's
	Gloom removed of the contract, and the shift clock in coral with the time-clock render breaking the top-right
	corner, where a little Gloom is poured along the top edge (the Gloom is what this plate is about). The bar eases to
	each new total (useProgressTween); the total and time are drawn as they are. Restrained on purpose: one plate.
	With a `deadline` the time is a live ShiftCountdown to it (only the digits re-render as it ticks); without one (a
	story) it is the view's time.
	Presentational (exempt; story in ShiftCompactHudPanel.story; words specced in ShiftHudViewModel.meter).

	@class ShiftGloomMeter
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useProgressTween = require(ReplicatedStorage.Client.UI.React.Hooks.useProgressTween)
local ShiftCountdown = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCountdown)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type ShiftGloomMeterProps = {
	view: ShiftHudViewModel.HudView,
	phone: boolean,
	top: number,
	-- The server-clock time the shift clock counts down to, live (ShiftHud); nil draws `view.time` as it is.
	deadline: number?,
}

local function ShiftGloomMeter(props: ShiftGloomMeterProps): React.ReactNode
	local view = props.view
	local phone = props.phone
	local meter = ShiftHudViewModel.meter(view)
	local fill = useProgressTween(view.fill, 0.22, nil, true)
	local size = if phone then Vector2.new(400, 70) else Vector2.new(620, 96)
	local iconSize = if phone then 70 else 100
	local left = if phone then 50 else 74
	local clockWidth = if phone then 104 else 150
	local barHeight = if phone then 24 else 34
	local face: { [string]: React.ReactNode } = {
		gloom = e(ToonIcon, {
			icon = "gloom",
			position = UDim2.fromOffset(-iconSize * 0.38, -iconSize * 0.12),
			size = UDim2.fromOffset(iconSize, iconSize),
			drop = 5,
			zIndex = 5,
		}),
		title = e(ToonText, {
			text = meter.title,
			meaning = if meter.met then "mint" else "white",
			textSize = if phone then 20 else 28,
			position = UDim2.fromOffset(left, if phone then 4 else 8),
			size = UDim2.fromOffset(if phone then 190 else 260, if phone then 24 else 32),
			fit = true,
			zIndex = 3,
		}),
		bar = e(ToonBar, {
			kind = "gloom",
			fill = fill,
			label = view.clearedShort,
			labelSize = if phone then 17 else 24,
			position = UDim2.fromOffset(left, if phone then 34 else 48),
			size = UDim2.fromOffset(size.X - left - clockWidth - 10, barHeight),
			zIndex = 3,
		}),
		clock = e(ToonIcon, {
			icon = "stopwatch",
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, if phone then 16 else 22, 0, if phone then -24 else -34),
			size = UDim2.fromOffset(if phone then 46 else 66, if phone then 46 else 66),
			rotation = 10,
			drop = 4,
			zIndex = 6,
		}),
	}
	local function timeText(text: string): React.ReactNode
		return e(ToonText, {
			text = text,
			meaning = "coral",
			textSize = if phone then 32 else 50,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, if phone then -18 else -26, 1, if phone then -4 else -8),
			size = UDim2.fromOffset(clockWidth - 12, if phone then 38 else 58),
			align = "right",
			fit = true,
			zIndex = 4,
		})
	end
	local deadline = props.deadline
	face.time = if deadline ~= nil
		then e(ShiftCountdown, { deadline = deadline, render = timeText })
		else timeText(view.time)
	if not phone then
		face.site = e(ToonText, {
			text = meter.site,
			font = "body",
			textSize = 17,
			position = UDim2.fromOffset(left + 268, 14),
			size = UDim2.fromOffset(size.X - left - 268 - clockWidth - 16, 22),
			align = "right",
			fit = true,
			zIndex = 3,
		})
	end
	if view.overtime and view.feeBoostShort ~= nil then
		face.boost = e(ToonPill, {
			text = view.feeBoostShort,
			hue = "coral",
			textSize = if phone then 13 else 18,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 1, 2),
			size = UDim2.fromOffset(if phone then 110 else 150, if phone then 22 else 30),
			zIndex = 7,
		})
	end
	return e(ToonPanel, {
		size = size,
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, props.top),
		radius = if phone then 20 else 26,
		-- A short pour along the top edge between the site line and the clock, small enough to stay over the digits.
		goo = { kind = "cap", from = size.X - clockWidth + 6, to = size.X - 44, scale = if phone then 0.4 else 0.5 },
		children = face,
	})
end

return ShiftGloomMeter
