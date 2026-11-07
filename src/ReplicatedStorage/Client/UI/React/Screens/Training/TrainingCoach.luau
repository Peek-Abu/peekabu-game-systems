--!strict
--[=[
	TrainingCoach: Pippa telling the player what to do (tutorial v3). Pippa is her real 3D model, belly and up, facing
	the player, in the pose for her kind of line (EmployeePoseRegistry's coach poses: go this way, careful, cheer, shh,
	hide; shared poses on the kit rig, so any employee could coach); beside her a cream bubble with her name and the
	line, its tail pointing at her. Presentational (exempt; the line and pose are the specced TrainingGuideRules.coach
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
local CREAM = Color3.fromHex("FFFCF6")

local function TrainingCoach(props: TrainingCoachProps): React.ReactNode
	local phone = props.phone
	local z = props.zIndex or 30
	local portrait = if phone then 110 else 230
	local bubble = if phone then Vector2.new(250, 74) else Vector2.new(520, 140)
	local overlap = if phone then 18 else 44
	local tail = if phone then 16 else 28
	local width = portrait + bubble.X - overlap
	local bubbleFace: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = "PIPPA",
			meaning = "coral",
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(if phone then 14 else 26, if phone then 5 else 12),
			size = UDim2.fromOffset(bubble.X / 2, if phone then 15 else 26),
			zIndex = z + 3,
		}),
		words = e(ToonText, {
			text = props.line.text,
			font = "body",
			textSize = if phone then 15 else 28,
			position = UDim2.fromOffset(if phone then 14 else 26, if phone then 21 else 40),
			size = UDim2.new(1, if phone then -24 else -46, 1, if phone then -28 else -54),
			wrapped = true,
			fit = true,
			alignY = "top",
			zIndex = z + 3,
		}),
		tail = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 1, if phone then -22 else -40),
			Size = UDim2.fromOffset(tail, tail),
			Rotation = 45,
			BackgroundColor3 = CREAM,
			ZIndex = z,
		}, {
			stroke = e("UIStroke", {
				Color = UIToonConstants.COLOR.ink,
				Thickness = if phone then 3 else 5,
			}),
		}),
	}
	return e("Frame", {
		AnchorPoint = props.anchor or Vector2.new(0, 1),
		Position = props.position,
		Size = UDim2.fromOffset(width, portrait),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, {
		scale = if props.scale ~= nil then e("UIScale", { Scale = props.scale }) else nil,
		pippa = e(ToonViewport, {
			employee = COACH,
			framing = "upper",
			context = CONTEXTS[props.line.pose],
			size = UDim2.fromOffset(portrait, portrait),
			zIndex = z + 2,
		}),
		bubble = e(ToonPanel, {
			size = bubble,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, portrait - overlap, 1, if phone then -8 else -18),
			hue = "cream",
			radius = if phone then 14 else 24,
			pop = true,
			zIndex = z + 1,
			children = bubbleFace,
		}),
	})
end

return TrainingCoach
