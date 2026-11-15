--!strict
--[=[
	TrainingStopDots: the training run's five stop dots (done = gold with a check, this one = lilac, bigger, with its
	number), drawn on the top edge of Prickles' card (TrainingCoach `badge`) now that the goal bar is gone (owner
	2026-11-15: training shows no goals). A row of `phone`-sized dots, right-aligned in the frame it is given.
	Presentational (exempt).

	@class TrainingStopDots
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type TrainingStopDotsProps = {
	-- The stop the player is on (1-based).
	stop: number,
	phone: boolean,
	-- Added to every layer's ZIndex (the card it sits on).
	zIndex: number?,
}

local INK = UIToonConstants.COLOR.ink
local DOT = {
	todo = Color3.fromHex("3A2470"),
	done = Color3.fromHex("FFC93A"),
	now = Color3.fromHex("B48BFF"),
}

-- A check mark from two ink strokes (no glyph), centred in a `size` box.
local function check(size: number, z: number): React.ReactNode
	local thick = math.max(3, math.floor(size * 0.16))
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(size * 0.62, size * 0.36),
		BackgroundTransparency = 1,
		Rotation = -45,
		ZIndex = z + 9,
	}, {
		down = e("Frame", {
			Size = UDim2.new(0, thick, 1, 0),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = z + 9,
		}),
		across = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, thick),
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = z + 9,
		}),
	})
end

local function dot(
	index: number,
	stop: number,
	base: number,
	phone: boolean,
	layoutOrder: number,
	z: number
): React.ReactNode
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
		children.check = check(size, z)
	elseif now then
		children.number = e(ToonText, {
			text = tostring(index),
			textSize = if phone then 14 else 22,
			size = UDim2.fromScale(1, 1),
			align = "center",
			alignY = "center",
			zIndex = z + 9,
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
		ZIndex = z + 8,
	}, children)
end

-- A dot's side (design px) on each layout; the row's height is this x 1.3 (the current dot is bigger).
local DOT_SIZE = { phone = 18, desktop = 30 }

local function TrainingStopDots(props: TrainingStopDotsProps): React.ReactNode
	local phone = props.phone
	local z = props.zIndex or 0
	local dotSize = if phone then DOT_SIZE.phone else DOT_SIZE.desktop
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
		dots[`dot{index}`] = dot(index, props.stop, dotSize, phone, index, z)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 8,
	}, dots)
end

return TrainingStopDots
