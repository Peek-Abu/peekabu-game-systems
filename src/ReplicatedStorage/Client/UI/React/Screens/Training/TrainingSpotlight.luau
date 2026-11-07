--!strict
--[=[
	TrainingSpotlight: the training spotlight (tutorial design v2), drawn on the Coach layer over everything it points
	into. A UI step dims the whole screen except a hole round the one button to press, with a gold ring round the hole
	and one line of words beside it; tapping the dark skips the step (the hole itself lets the tap through to the
	button). A world step dims nothing: a gold arrow points down at the target, or from the screen's edge towards it,
	with its line under it. Presentational; the layout is the specced TrainingSpotlightUtils.

	@class TrainingSpotlight
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TrainingSpotlightUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingSpotlightUtils)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type TrainingSpotlightProps = {
	-- The UI step's hole (nil for a world step).
	hole: TrainingSpotlightUtils.Rect?,
	-- The world step's arrow: where, and its rotation.
	arrow: { position: Vector2, rotation: number }?,
	line: string,
	linePosition: Vector2,
	lineSize: Vector2,
	screen: Vector2,
	-- 0..1, the ring's pulse.
	pulse: number,
	onSkip: () -> (),
}

-- The kit's gold (UIToonConstants' gold hue, its base shade).
local GOLD = Color3.fromHex("FFC93A")
local SHADE_TRANSPARENCY = 0.3
local RING_THICKNESS = 5
local ARROW_SIZE = 64

local function LineCard(props: TrainingSpotlightProps): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(props.linePosition.X, props.linePosition.Y),
		Size = UDim2.fromOffset(props.lineSize.X, props.lineSize.Y),
		BackgroundColor3 = UIToonConstants.COLOR.ink,
		BackgroundTransparency = 0.15,
		ZIndex = 20,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
		stroke = e("UIStroke", { Color = GOLD, Thickness = 3 }),
		words = e(ToonText, {
			text = props.line,
			textSize = 30,
			position = UDim2.fromOffset(14, 6),
			size = UDim2.new(1, -28, 1, -12),
			align = "center",
			wrapped = true,
			fit = true,
			zIndex = 21,
		}),
	})
end

local function TrainingSpotlight(props: TrainingSpotlightProps): React.ReactNode
	local children: { [string]: React.ReactNode } = { line = e(LineCard, props) }
	local hole = props.hole
	if hole ~= nil then
		for index, shade in TrainingSpotlightUtils.shades(hole, props.screen) do
			children[`shade{index}`] = e("TextButton", {
				Position = UDim2.fromOffset(shade.position.X, shade.position.Y),
				Size = UDim2.fromOffset(shade.size.X, shade.size.Y),
				BackgroundColor3 = UIToonConstants.COLOR.ink,
				BackgroundTransparency = SHADE_TRANSPARENCY,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 10,
				[React.Event.Activated] = props.onSkip,
			})
		end
		local grow = props.pulse * 8
		children.ring = e("Frame", {
			Position = UDim2.fromOffset(hole.position.X - grow, hole.position.Y - grow),
			Size = UDim2.fromOffset(hole.size.X + grow * 2, hole.size.Y + grow * 2),
			BackgroundTransparency = 1,
			ZIndex = 15,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 24) }),
			stroke = e("UIStroke", {
				Color = GOLD,
				Thickness = RING_THICKNESS,
				Transparency = props.pulse * 0.4,
			}),
		})
	end
	local arrow = props.arrow
	if arrow ~= nil then
		children.arrow = e(ToonText, {
			text = "▼",
			meaning = "gold",
			textSize = ARROW_SIZE,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromOffset(arrow.position.X, arrow.position.Y - props.pulse * 10),
			size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
			align = "center",
			rotation = arrow.rotation,
			zIndex = 20,
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return TrainingSpotlight
