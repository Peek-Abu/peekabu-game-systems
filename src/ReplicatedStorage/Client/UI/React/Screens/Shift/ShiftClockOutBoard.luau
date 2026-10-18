--!strict
--[=[
	ShiftClockOutBoard: the clock-out board, top centre right under the Gloom meter while the crew clocks out (one card
	per crew member, ShiftClockOutRules). A dark night plate on the V1 stack with the time-clock render breaking its left
	edge, the headline (CLOCKING OUT, or TRUCK LEAVES IN with the countdown big in gold, coral and pulsing for its last
	ticking seconds), a row of time cards (mint once punched, a night slot until then; the local player's own card lifted in the
	lilac selected ring once they punched) and the tally pill ("2/4 CLOCKED OUT"), with the hint in body type under the
	plate's title. Only its countdown follows the clock (TruckCountdown), so the HUD around it never re-renders for it.
	Restrained on purpose (an in-run horror HUD): one plate, no gloss.

	Presentational (exempt; story in ShiftClockOutBoard.story; every word and count is specced in ShiftClockOutViewModel).

	@class ShiftClockOutBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local ShiftClockOutViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftClockOutViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type ShiftClockOutBoardProps = {
	view: ShiftClockOutViewModel.BoardView,
	phone: boolean,
	-- The board's top edge (px); default right under the Gloom meter (ShiftCompactHudPanel draws the meter from 40 px,
	-- 96 tall, on desktop; from 28 px, 70 tall, on phone).
	top: number?,
}

-- The local player's own punched card: lifted in the lilac selected ring (never animated, so one binding serves).
local SELECTED = React.createBinding(ToonStyleViewModel.pose({
	hovered = false,
	pressed = false,
	selected = true,
	disabled = false,
	receded = false,
}))

type CountdownProps = {
	leavesAt: number,
	textSize: number,
	position: UDim2,
	size: UDim2,
}

-- The truck's countdown, in gold; the one piece that follows the clock. Coral and pulsing (a beat bigger) in its last
-- ticking seconds.
local function TruckCountdown(props: CountdownProps): React.ReactNode
	local now = useServerClock(0.1)
	local left = props.leavesAt - now
	local urgent = ShiftClockOutViewModel.urgent(math.ceil(left))
	local beat = if urgent then 1 + 0.12 * math.max(0, (left % 1) - 0.6) / 0.4 else 1
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, {
		scale = e("UIScale", { Scale = beat }),
		text = e(ToonText, {
			text = ShiftHudViewModel.clock(left),
			meaning = if urgent then "coral" else "gold",
			textSize = props.textSize,
			size = UDim2.fromScale(1, 1),
			align = "right",
			fit = true,
		}),
	})
end

local function ShiftClockOutBoard(props: ShiftClockOutBoardProps): React.ReactNode
	local view = props.view
	local phone = props.phone
	local width = if phone then 330 else 470
	local height = if phone then 80 else 108
	local iconSize = if phone then 62 else 86
	local left = if phone then 44 else 62
	local cardW = if phone then 26 else 36
	local cardH = if phone then 20 else 28
	local face: { [string]: React.ReactNode } = {
		clock = e(ToonIcon, {
			icon = "clock",
			position = UDim2.fromOffset(-iconSize * 0.4, -iconSize * 0.1),
			size = UDim2.fromOffset(iconSize, iconSize),
			rotation = -8,
			drop = 4,
			zIndex = 5,
		}),
		headline = e(ToonText, {
			text = view.headline,
			textSize = if phone then 19 else 27,
			position = UDim2.fromOffset(left, if phone then 4 else 8),
			size = UDim2.fromOffset(if phone then 170 else 250, if phone then 24 else 32),
			fit = true,
			zIndex = 3,
		}),
		hint = e(ToonText, {
			text = view.hint,
			font = "body",
			color = UIToonConstants.shade("lilac").hi,
			textSize = if phone then 12 else 15,
			position = UDim2.fromOffset(left, if phone then 25 else 36),
			size = UDim2.fromOffset(width - left - 24, if phone then 15 else 19),
			fit = true,
			zIndex = 3,
		}),
		tally = e(ToonPill, {
			text = view.tally,
			hue = if view.punched >= view.total then "mint" else "cream",
			textSize = if phone then 12 else 16,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, -12, 1, if phone then -6 else -9),
			size = UDim2.fromOffset(if phone then 128 else 176, if phone then 24 else 32),
			zIndex = 4,
		}),
	}
	local leavesAt = view.leavesAt
	if leavesAt ~= nil then
		face.countdown = e(TruckCountdown, {
			leavesAt = leavesAt,
			textSize = if phone then 34 else 50,
			position = UDim2.new(1, if phone then -110 else -150, 0, if phone then 0 else 2),
			size = UDim2.fromOffset(if phone then 96 else 136, if phone then 38 else 54),
		})
	end
	local cardTop = height - cardH - (if phone then 9 else 12)
	for index, punched in view.cards do
		local stamp: { [string]: React.ReactNode }? = nil
		if punched then
			local nodes: { [string]: React.ReactNode } = {}
			nodes.out = e(ToonText, {
				text = "OUT",
				textSize = if phone then 10 else 13,
				size = UDim2.fromScale(1, 1),
				align = "center",
				fit = true,
			})
			stamp = nodes
		end
		face[`card{index}`] = e(ToonSurface, {
			hue = if punched then "mint" else "night",
			size = UDim2.fromOffset(cardW, cardH),
			position = UDim2.fromOffset(left + (index - 1) * (cardW + 8), cardTop),
			radius = 7,
			small = true,
			gloss = punched,
			pose = if view.selected == index then SELECTED else nil,
			zIndex = 3,
			children = stamp,
		})
	end
	return e(ToonPanel, {
		hue = "night",
		size = Vector2.new(width, height),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, props.top or (if phone then 28 + 70 + 16 else 40 + 96 + 20)),
		radius = 22,
		gloss = false,
		pop = true,
		children = face,
	})
end

return ShiftClockOutBoard
