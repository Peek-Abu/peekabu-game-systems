--!strict
--[=[
	TrainingCoach: Pippa telling the player what to do (tutorial v3). ONE cream card: her real 3D model, head, ears and
	chest, in a warm window set into the card's left end (cropped at the window's bottom, never cut at the top), her
	name on a tab on the card's top edge and her line beside her. The card reacts to the line's mood
	(TrainingGuideRules.mood; owner pick 11-10, "caution tape"): calm lines wear the crew's yellow caution tape on the
	top-right corner and a mint tab; danger lines (careful, hide, shh) red emergency tape on two opposite corners (top-right, bottom-left), a red tab, a
	pink tint and a red glow. Her pose fits her kind of line (EmployeePoseRegistry's coach poses: go this way,
	careful, cheer, shh, hide). Presentational (exempt; the line, pose and mood are the specced TrainingGuideRules via
	TrainingCoachStore).

	@class TrainingCoach
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
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
	-- Told where the card is on screen (screen px) whenever it moves or resizes, and nil when it goes (so the phone's
	-- sticky notes can keep clear of it: TrainingCoachStore.setArea).
	onArea: ((area: Area?) -> ())?,
}

export type Area = {
	left: number,
	top: number,
	right: number,
	bottom: number,
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
-- Her close-up frame's height per unit of its width (head, ears and chest).
local PORTRAIT_TALL = 1.2

-- The card's look per mood (owner pick 11-10, option 2 "caution tape"): calm lines wear the crew's yellow caution
-- tape and a mint name tab; danger lines red emergency tape on two corners, a red name tab, a pink tint and a red glow
-- round the card. No purple; every accent is something from the building.
type MoodLook = {
	tape: { Color3 },
	tab: { Color3 },
	tint: Color3,
	glow: Color3?,
	tapes: number,
}
local MOOD: { [TrainingGuideRules.Mood]: MoodLook } = {
	calm = {
		tape = { Color3.fromHex("FFD23A"), Color3.fromHex("2A2230") },
		tab = { Color3.fromHex("5FF0BD"), Color3.fromHex("14B07C") },
		tint = Color3.fromHex("FFF7E8"),
		glow = nil,
		tapes = 1,
	},
	danger = {
		tape = { Color3.fromHex("FF4B4B"), Color3.fromHex("2A1820") },
		tab = { Color3.fromHex("FF7A7A"), Color3.fromHex("D92B3A") },
		tint = Color3.fromHex("FFE3DC"),
		glow = Color3.fromHex("FF3C3C"),
		tapes = 2,
	},
}

type TapeProps = {
	colors: { Color3 },
	size: Vector2,
	position: UDim2,
	rotation: number,
	line: number,
	zIndex: number,
}

-- A strip of tape: diagonal stripes in a rotated CanvasGroup (it clips them to the strip at any angle) with an ink
-- line along each long edge.
local function Tape(props: TapeProps): React.ReactNode
	local stripes: { [string]: React.ReactNode } = {}
	local stripe = math.max(6, math.floor(props.size.Y * 0.75))
	local count = math.ceil(props.size.X / (stripe * 2)) + 2
	for index = 0, count do
		stripes[`s{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(index * stripe * 2 - stripe, props.size.Y / 2),
			Size = UDim2.fromOffset(stripe, props.size.Y * 3),
			Rotation = 45,
			BackgroundColor3 = props.colors[2],
			BorderSizePixel = 0,
		})
	end
	stripes.edgeTop = e("Frame", {
		Size = UDim2.new(1, 0, 0, props.line),
		BackgroundColor3 = UIToonConstants.COLOR.ink,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	stripes.edgeBottom = e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, props.line),
		BackgroundColor3 = UIToonConstants.COLOR.ink,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	return e("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position,
		Size = UDim2.fromOffset(props.size.X, props.size.Y),
		Rotation = props.rotation,
		BackgroundColor3 = props.colors[1],
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, stripes)
end

-- Reports `frame`'s screen rectangle to `onArea` now and whenever it moves or resizes, and nil when it goes.
local function useArea(onArea: ((area: Area?) -> ())?): { current: Frame? }
	local none: Frame? = nil
	local ref = React.useRef(none)
	React.useEffect(function(): (() -> ())?
		local frame = ref.current
		if onArea == nil or frame == nil then
			return nil
		end
		local report = onArea
		local function send()
			local at = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			report({ left = at.X, top = at.Y, right = at.X + size.X, bottom = at.Y + size.Y })
		end
		send()
		local moved = frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(send)
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(send)
		return function()
			moved:Disconnect()
			resized:Disconnect()
			report(nil)
		end
	end, { onArea })
	return ref
end

local function TrainingCoach(props: TrainingCoachProps): React.ReactNode
	local ref = useArea(props.onArea)
	local phone = props.phone
	local z = props.zIndex or 30
	local k = if phone then 0.48 else 1
	local ink = UIToonConstants.COLOR.ink
	local cream = UIToonConstants.shade("cream")
	local look = MOOD[TrainingGuideRules.mood(props.line.pose)]
	local line = if phone then 3 else 5
	local radius = if phone then 14 else 24
	local card = if phone then Vector2.new(330, 78) else Vector2.new(690, 150)
	local pad = math.floor(14 * k)
	-- Her close-up sits in a warm window set into the card's left end, cropped at the window's bottom; her head and
	-- ears rise over the card's top, so nothing cuts them.
	local window = Vector2.new(math.floor(190 * k), card.Y - pad * 2)
	local portrait = Vector2.new(window.X + math.floor(10 * k), math.floor(window.X * PORTRAIT_TALL))
	local rise = math.max(0, portrait.Y - (card.Y - pad))
	-- Room over the card for her head, the name tab and the tape.
	local tall = card.Y + math.max(rise, math.floor(30 * k))
	local cardTop = tall - card.Y
	local textLeft = pad + window.X + math.floor(18 * k)
	local tabHeight = math.floor(34 * k)
	local face: { [string]: React.ReactNode } = {
		tint = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = look.tint,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius - line) }),
		}),
		words = e(ToonText, {
			text = props.line.text,
			font = "body",
			textSize = if phone then 15 else 28,
			position = UDim2.fromOffset(textLeft, tabHeight / 2 + (if phone then 6 else 12)),
			size = UDim2.new(1, -textLeft - pad, 1, -(tabHeight / 2 + (if phone then 12 else 24))),
			wrapped = true,
			fit = true,
			alignY = "top",
			zIndex = z + 3,
		}),
		-- A warm window set into the card's left end: the card's darker cream, an ink rim.
		window = e("Frame", {
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
		}),
	}
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
		-- Her name on a tab sitting on the card's top edge: mint when calm, red in danger.
		tab = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(textLeft - math.floor(4 * k), cardTop),
			Size = UDim2.fromOffset(math.floor(118 * k), tabHeight),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = z + 6,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, math.floor(10 * k)) }),
			stroke = e("UIStroke", { Color = ink, Thickness = math.max(2, line - 1) }),
			fill = e("UIGradient", { Color = ColorSequence.new(look.tab[1], look.tab[2]), Rotation = 90 }),
			name = e(ToonText, {
				text = "PIPPA",
				meaning = "white",
				textSize = if phone then 14 else 24,
				size = UDim2.fromScale(1, 1),
				align = "center",
				alignY = "center",
				zIndex = z + 7,
			}),
		}),
		-- The tape across the card's top-right corner (and, in danger, the bottom-left too).
		tape = e(Tape, {
			colors = look.tape,
			size = Vector2.new(math.floor(170 * k), math.floor(28 * k)),
			position = UDim2.fromOffset(card.X - math.floor(40 * k), cardTop + math.floor(6 * k)),
			rotation = 18,
			line = math.max(2, line - 2),
			zIndex = z + 8,
		}),
	}
	if look.tapes > 1 then
		-- The second strip on the diagonally opposite corner, bottom-left (owner, 11-10).
		children.tapeLow = e(Tape, {
			colors = look.tape,
			size = Vector2.new(math.floor(150 * k), math.floor(26 * k)),
			position = UDim2.fromOffset(math.floor(34 * k), tall - math.floor(8 * k)),
			rotation = 18,
			line = math.max(2, line - 2),
			zIndex = z + 8,
		})
	end
	local glowColor = look.glow
	if glowColor ~= nil then
		-- A red emergency glow round the card (the kit's 9-slice glow, tinted).
		local spread = math.floor(26 * k)
		children.glow = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(-spread, tall + spread),
			Size = UDim2.fromOffset(card.X + spread * 2, card.Y + spread * 2),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.glow,
			ImageColor3 = glowColor,
			ImageTransparency = 0.3,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 80, 80),
			ZIndex = z,
		})
	end
	if props.scale ~= nil then
		children.scale = e("UIScale", { Scale = props.scale })
	end
	-- Keyed by the pose: ToonViewport rebuilds its model only when the employee or look changes, not the pose. Its
	-- bottom is the window's bottom (the crop line); its top rises over the card.
	children[`pippa_{props.line.pose}`] = e(ToonViewport, {
		employee = COACH,
		framing = "upper",
		context = CONTEXTS[props.line.pose],
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0, pad + window.X / 2, 1, -pad),
		size = UDim2.fromOffset(portrait.X, portrait.Y),
		zIndex = z + 4,
	})
	return e("Frame", {
		ref = ref,
		AnchorPoint = props.anchor or Vector2.new(0, 1),
		Position = props.position,
		Size = UDim2.fromOffset(card.X, tall),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, children)
end

return TrainingCoach
