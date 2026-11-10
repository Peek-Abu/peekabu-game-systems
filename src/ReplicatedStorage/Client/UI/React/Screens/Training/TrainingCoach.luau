--!strict
--[=[
	TrainingCoach: Pippa telling the player what to do (tutorial v3). ONE cream card (owner, 11-10: portrait and words
	must read as one piece; a close-up of her head and upper body, never her whole figure, never cut at the top): her
	real 3D model, head, ears and chest, sits in the card's left end, cropped at the chest by the card's own edge
	(`inset`: a warm window set into the card, her head popping out above its top; `bleed`: no window, the crop is the
	card's bottom edge and a dashed divider splits her from the words), facing the player, in the pose for her kind of
	line (EmployeePoseRegistry's coach poses: go this way, careful, cheer, shh, hide; shared poses on the kit rig, so any
	employee could coach); her name tag and the line on the right. Presentational (exempt; the line and pose are the
	specced TrainingGuideRules.coach via TrainingCoachStore).

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
-- How her portrait joins the card (two options for the owner, 11-10).
export type Variant = "inset" | "bleed"
local VARIANT: Variant = "inset"
-- Her close-up frame's height per unit of its width (head, ears and chest).
local PORTRAIT_TALL = 1.2

local function TrainingCoach(props: TrainingCoachProps): React.ReactNode
	local phone = props.phone
	local z = props.zIndex or 30
	local k = if phone then 0.48 else 1
	local ink = UIToonConstants.COLOR.ink
	local cream = UIToonConstants.shade("cream")
	local line = if phone then 3 else 5
	local radius = if phone then 14 else 24
	local card = if phone then Vector2.new(330, 78) else Vector2.new(690, 150)
	local pad = math.floor(14 * k)
	-- Her close-up: as wide as the card's left end, cropped at the card (the window's or the card's) bottom.
	local window = Vector2.new(math.floor(190 * k), card.Y - pad * 2)
	local portrait = Vector2.new(window.X + math.floor(10 * k), math.floor(window.X * PORTRAIT_TALL))
	local cropFromBottom = if VARIANT == "inset" then pad else math.floor(8 * k)
	local rise = math.max(0, portrait.Y - (card.Y - cropFromBottom))
	local tall = card.Y + rise
	local textLeft = pad + window.X + math.floor(18 * k)
	local face: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = "PIPPA",
			meaning = "coral",
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(textLeft, if phone then 6 else 14),
			size = UDim2.fromOffset(card.X / 2, if phone then 15 else 26),
			zIndex = z + 3,
		}),
		words = e(ToonText, {
			text = props.line.text,
			font = "body",
			textSize = if phone then 15 else 28,
			position = UDim2.fromOffset(textLeft, if phone then 22 else 42),
			size = UDim2.new(1, -textLeft - pad, 1, if phone then -30 else -56),
			wrapped = true,
			fit = true,
			alignY = "top",
			zIndex = z + 3,
		}),
	}
	if VARIANT == "inset" then
		-- A warm window set into the card's left end: the card's darker cream, an ink rim, a white inner light.
		face.window = e("Frame", {
			Position = UDim2.fromOffset(pad, pad),
			Size = UDim2.fromOffset(window.X, window.Y),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = z + 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius - pad / 2) }),
			stroke = e("UIStroke", { Color = ink, Thickness = math.max(2, line - 1) }),
			light = e("UIGradient", {
				Color = ColorSequence.new(cream.base, cream.lo),
				Rotation = 90,
			}),
		})
	else
		-- A dashed divider between her and her words, in the card's darker cream.
		local dashes = 6
		for index = 1, dashes do
			local gap = (card.Y - pad * 2) / dashes
			face[`dash{index}`] = e("Frame", {
				Position = UDim2.fromOffset(pad + window.X + math.floor(6 * k), pad + (index - 1) * gap),
				Size = UDim2.fromOffset(math.max(2, math.floor(4 * k)), math.floor(gap * 0.6)),
				BackgroundColor3 = cream.lo,
				BorderSizePixel = 0,
				ZIndex = z + 2,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
		end
	end
	local children: { [string]: React.ReactNode } = {
		card = e(ToonPanel, {
			size = card,
			anchor = Vector2.new(0, 1),
			position = UDim2.fromScale(0, 1),
			hue = "cream",
			radius = radius,
			pop = true,
			zIndex = z + 1,
			children = face,
		}),
	}
	if props.scale ~= nil then
		children.scale = e("UIScale", { Scale = props.scale })
	end
	-- Keyed by the pose: ToonViewport rebuilds its model only when the employee or look changes, not the pose. Its
	-- bottom is the crop line (the window's or the card's bottom); its top rises over the card, so nothing cuts her
	-- head or ears.
	children[`pippa_{props.line.pose}`] = e(ToonViewport, {
		employee = COACH,
		framing = "upper",
		context = CONTEXTS[props.line.pose],
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0, pad + window.X / 2, 1, -cropFromBottom),
		size = UDim2.fromOffset(portrait.X, portrait.Y),
		zIndex = z + 4,
	})
	return e("Frame", {
		AnchorPoint = props.anchor or Vector2.new(0, 1),
		Position = props.position,
		Size = UDim2.fromOffset(card.X, tall),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, children)
end

return TrainingCoach
