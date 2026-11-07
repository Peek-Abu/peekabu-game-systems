--!strict
--[=[
	TrainingGoalBar: the training run's one goal, top centre, in the Gloom meter's place and size (so the lives hearts
	under it stay where they are). The stop's icon breaks the left edge, a TRAINING tab sits on the top edge, the five
	stop dots on the top-right edge (done = gold with a check, this one = lilac and bigger), the stop's title and one
	short line. The hide stop's plate is coral with the "!" mark. Presentational (exempt); its words and choices are
	the specced TrainingGuideRules.goal / tone.

	@class TrainingGoalBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type TrainingGoalBarProps = {
	stop: number,
	phone: boolean,
	top: number,
	-- The phone's plate width on a narrow screen; nil is the design width.
	width: number?,
}

local INK = UIToonConstants.COLOR.ink
-- The goal cards' icon names as ToonIcons (TrainingConstants.GOALS; "!" is drawn, not an icon).
local ICONS: { [string]: UIAssets.ToonIcon } = {
	vacuum = "vacuum",
	monitor = "monitor",
	flashlight = "flashlight",
	trophy = "trophy",
}
local DOT = {
	todo = Color3.fromHex("3A2470"),
	done = Color3.fromHex("FFC93A"),
	now = Color3.fromHex("B48BFF"),
}

-- A check mark from two ink strokes (no glyph), centred in a `size` box.
local function check(size: number): React.ReactNode
	local thick = math.max(3, math.floor(size * 0.16))
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(size * 0.62, size * 0.36),
		BackgroundTransparency = 1,
		Rotation = -45,
		ZIndex = 9,
	}, {
		down = e("Frame", {
			Size = UDim2.new(0, thick, 1, 0),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 9,
		}),
		across = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, thick),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 9,
		}),
	})
end

local function dot(index: number, stop: number, base: number, phone: boolean, layoutOrder: number): React.ReactNode
	local now = index == stop
	local size = if now then math.floor(base * 1.22) else base
	local color = if index < stop then DOT.done elseif now then DOT.now else DOT.todo
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", { Color = INK, Thickness = if phone then 3 else 4 }),
		gloss = e("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
			Rotation = 90,
		}),
	}
	if index < stop then
		children.check = check(size)
	elseif now then
		children.number = e(ToonText, {
			text = tostring(index),
			textSize = if phone then 14 else 22,
			size = UDim2.fromScale(1, 1),
			align = "center",
			alignY = "center",
			zIndex = 9,
		})
		children.glow = e("UIStroke", {
			Color = DOT.now,
			Thickness = if phone then 3 else 5,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		LayoutOrder = layoutOrder,
		ZIndex = 8,
	}, children)
end

local function TrainingGoalBar(props: TrainingGoalBarProps): React.ReactNode
	local phone = props.phone
	local goal = TrainingGuideRules.goal(props.stop)
	if goal == nil then
		return nil
	end
	local danger = TrainingGuideRules.tone(props.stop) == "danger"
	local metrics = if phone then ShiftHudViewModel.METER.phone else ShiftHudViewModel.METER.desktop
	local size = Vector2.new(props.width or metrics.size.X, metrics.size.Y)
	local iconSize = metrics.icon
	local left = if phone then 56 else 84
	local dotSize = if phone then 18 else 30
	local dots: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, if phone then 4 else 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, #TrainingConstants.STOPS do
		dots[`dot{index}`] = dot(index, props.stop, dotSize, phone, index)
	end
	local face: { [string]: React.ReactNode } = {
		tab = e(ToonPill, {
			text = TrainingConstants.TEXT.truckTag,
			hue = "grape",
			textSize = if phone then 12 else 18,
			position = UDim2.fromOffset(left, if phone then -12 else -20),
			size = UDim2.fromOffset(if phone then 74 else 120, if phone then 22 else 32),
			zIndex = 7,
		}),
		dots = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, if phone then -10 else -18, 0, 0),
			Size = UDim2.fromOffset(size.X - left, dotSize * 1.3),
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, dots),
		title = e(ToonText, {
			text = goal.title,
			textSize = if phone then 22 else 36,
			position = UDim2.fromOffset(left, if phone then 12 else 20),
			size = UDim2.fromOffset(size.X - left - 16, if phone then 26 else 42),
			fit = true,
			zIndex = 4,
		}),
		line = e(ToonText, {
			text = goal.line,
			font = "body",
			color = if danger then Color3.fromHex("FFE9EE") else Color3.fromHex("E9DDFF"),
			textSize = if phone then 13 else 20,
			position = UDim2.fromOffset(left, if phone then 40 else 66),
			size = UDim2.fromOffset(size.X - left - 16, if phone then 18 else 26),
			fit = true,
			zIndex = 4,
		}),
	}
	local iconAt = UDim2.fromOffset(-iconSize * ShiftHudViewModel.METER_ICON_OVERHANG, -iconSize * 0.12)
	if goal.icon == "!" then
		-- The danger mark: a coral medallion with a white "!" (the stop is about Mr. Harlow).
		local mark: { [string]: React.ReactNode } = {
			mark = e(ToonText, {
				text = "!",
				textSize = math.floor(iconSize * 0.7),
				size = UDim2.fromScale(1, 1),
				align = "center",
				alignY = "center",
				zIndex = 6,
			}),
		}
		face.icon = e(ToonPanel, {
			size = Vector2.new(iconSize * 0.86, iconSize * 0.86),
			position = iconAt,
			hue = "coral",
			radius = math.floor(iconSize * 0.43),
			zIndex = 5,
			children = mark,
		})
	else
		face.icon = e(ToonIcon, {
			icon = ICONS[goal.icon],
			position = iconAt,
			size = UDim2.fromOffset(iconSize, iconSize),
			drop = 5,
			zIndex = 5,
		})
	end
	return e(ToonPanel, {
		size = size,
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, props.top),
		hue = if danger then "coral" else "night",
		radius = if phone then 20 else 26,
		children = face,
	})
end

return TrainingGoalBar
