--!strict
--[=[
	TrainingCoach: Pippa telling the player what to do (tutorial v3). Pippa is her real 3D model, her whole figure
	standing on the gold floor of a lilac plate that sits over the left edge of her words' card, so plate and card read
	as one piece (owner, 11-10: a belly-up crop read as cut off; the portrait and the card must look like one UI), her
	head and ears breaking out above the plate, facing the player, in the pose for her kind of line (EmployeePoseRegistry's coach poses: go this way, careful, cheer, shh,
	hide; shared poses on the kit rig, so any employee could coach); beside her the cream card with her name and the
	line. Presentational (exempt; the line and pose are the specced TrainingGuideRules.coach
	via TrainingCoachStore).

	@class TrainingCoach
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type TrainingCoachProps = {
	line: TrainingConstants.CoachLine,
	phone: boolean,
	-- The coach's bottom-left corner (design px).
	position: UDim2,
	anchor: Vector2?,
	zIndex: number?,
	-- Drawn at this scale (a screen-px layer, the hub tour's Coach layer); nil = 1 (inside a scaled HUD frame).
	scale: number?,
}

-- Who coaches (an EmployeeRegistry key).
local COACH = "Pippa"
local CONTEXTS: { [TrainingConstants.CoachPose]: EmployeePoseRegistry.PortraitContext } = {
	point = "coachPoint",
	warn = "coachWarn",
	cheer = "coachCheer",
	shh = "coachShh",
	hide = "coachHide",
}
-- Her figure frame's height per unit of its width, and the plate she stands in, per unit of the figure's width.
local FIGURE_TALL = 1.15
local PLATE = Vector2.new(0.86, 0.82)

local function TrainingCoach(props: TrainingCoachProps): React.ReactNode
	local phone = props.phone
	local z = props.zIndex or 30
	local k = if phone then 0.48 else 1
	local ink = UIToonConstants.COLOR.ink
	local line = if phone then 3 else 5
	local drop = if phone then 3 else 6
	local figure = Vector2.new(math.floor(230 * k), math.floor(230 * k * FIGURE_TALL))
	local plate = Vector2.new(math.floor(figure.X * PLATE.X), math.floor(figure.X * PLATE.Y))
	local bubble = if phone then Vector2.new(250, 74) else Vector2.new(520, 140)
	-- How far the plate sits over the card's left edge (the two read as one piece, like the hub's profile card).
	local overlap = math.floor(34 * k)
	local radius = if phone then 14 else 24
	local floor = math.floor(26 * k)
	local width = plate.X - overlap + bubble.X
	-- Her feet stand on the plate's gold floor; her head and ears break out above the plate's top.
	local feet = drop + floor - math.floor(8 * k)
	local tall = math.max(plate.Y, feet + figure.Y) + drop
	local textLeft = overlap + (if phone then 12 else 24)
	local bubbleFace: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = "PIPPA",
			meaning = "coral",
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(textLeft, if phone then 5 else 12),
			size = UDim2.fromOffset(bubble.X / 2, if phone then 15 else 26),
			zIndex = z + 3,
		}),
		words = e(ToonText, {
			text = props.line.text,
			font = "body",
			textSize = if phone then 15 else 28,
			position = UDim2.fromOffset(textLeft, if phone then 21 else 40),
			size = UDim2.new(1, -textLeft - (if phone then 10 else 20), 1, if phone then -28 else -54),
			wrapped = true,
			fit = true,
			alignY = "top",
			zIndex = z + 3,
		}),
	}
	local children: { [string]: React.ReactNode } = {
		-- The card her words are on: its left edge runs under her plate, so plate and card are one shape.
		bubble = e(ToonPanel, {
			size = bubble,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, plate.X - overlap, 1, -drop),
			hue = "cream",
			radius = radius,
			pop = true,
			zIndex = z + 1,
			children = bubbleFace,
		}),
		-- The plate's hard ink drop, the same as the card's.
		plateDrop = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(plate.X, plate.Y),
			BackgroundColor3 = ink,
			ZIndex = z + 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
		}),
		-- Her lilac window: ink outline, a white inner rim, lit from the top, a gold floor she stands on.
		plate = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -drop),
			Size = UDim2.fromOffset(plate.X, plate.Y),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = z + 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
			stroke = e("UIStroke", { Color = ink, Thickness = line }),
			light = e("UIGradient", {
				Color = ColorSequence.new(UIToonConstants.shade("lilac").hi, UIToonConstants.shade("lilac").base),
				Rotation = 90,
			}),
			rim = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -line * 2, 1, -line * 2),
				BackgroundTransparency = 1,
				ZIndex = z + 2,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, radius - line) }),
				stroke = e("UIStroke", {
					Color = UIToonConstants.COLOR.white,
					Thickness = if phone then 2 else 3,
					Transparency = 0.25,
				}),
			}),
			floor = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, floor),
				BackgroundColor3 = UIToonConstants.COLOR.selected,
				ZIndex = z + 3,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
				-- Squares the floor's top corners off (only the plate's bottom corners are round).
				top = e("Frame", {
					Size = UDim2.fromScale(1, 0.5),
					BackgroundColor3 = UIToonConstants.COLOR.selected,
					BorderSizePixel = 0,
					ZIndex = z + 3,
				}),
				edge = e("Frame", {
					Size = UDim2.new(1, 0, 0, line),
					BackgroundColor3 = ink,
					BorderSizePixel = 0,
					ZIndex = z + 3,
				}),
				shine = e("Frame", {
					Position = UDim2.fromOffset(floor / 2, line + (if phone then 1 else 3)),
					Size = UDim2.new(1, -floor, 0, if phone then 2 else 4),
					BackgroundColor3 = UIToonConstants.COLOR.white,
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					ZIndex = z + 3,
				}, {
					corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
		}),
	}
	if props.scale ~= nil then
		children.scale = e("UIScale", { Scale = props.scale })
	end
	-- Keyed by the pose: ToonViewport rebuilds its model only when the employee or look changes, not the pose.
	children[`pippa_{props.line.pose}`] = e(ToonViewport, {
		employee = COACH,
		framing = "full",
		context = CONTEXTS[props.line.pose],
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0, plate.X / 2, 1, -feet),
		size = UDim2.fromOffset(figure.X, figure.Y),
		zIndex = z + 4,
	})
	return e("Frame", {
		AnchorPoint = props.anchor or Vector2.new(0, 1),
		Position = props.position,
		Size = UDim2.fromOffset(width, tall),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, children)
end

return TrainingCoach
