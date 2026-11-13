--!strict
--[=[
	TrainingSpotlight: the training spotlight (tutorial v3 look), drawn on the Coach layer over everything it points
	into. A UI step dims the whole screen except a hole round the one button to press, with a gold ring (ink edged)
	round the hole and the gold arrow bobbing over it; tapping the dark skips the step (the hole itself lets the tap
	through to the button). A world step dims nothing: the gold arrow points down at the target, or from the screen's
	edge towards it. Either way Pippa says the line (TrainingCoach, pointing): next to what it points at, or, `pinned`,
	in one place at the bottom left that never moves with the camera. Presentational; the layout is the specced
	TrainingSpotlightUtils.

	@class TrainingSpotlight
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingCoach = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingCoach)
local TrainingSpotlightUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingSpotlightUtils)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
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
	-- Screen px from the left edge the coach keeps clear of (a button column there); nil = 0.
	leftInset: number?,
	-- Told where Pippa's card is on screen (TrainingCoach.onArea); nil = not reported.
	onArea: ((area: TrainingCoach.Area?) -> ())?,
	-- Pippa's card stays put at the bottom left (TrainingSpotlightUtils.pinnedCoach) instead of following the line
	-- spot, so it never swings around with the camera; nil = follows.
	pinned: boolean?,
	-- Who says the line (TrainingCoach.coach); nil = Pippa.
	coach: string?,
	-- false: no shade around the hole (nothing dimmed, no click caught); nil = shaded.
	dim: boolean?,
	-- The card at COMPACT_SCALE (the hub's hint, owner 11-13); nil = full size.
	compact: boolean?,
	-- A small button just above the card's right end (the hub's SKIP TRAINING); nil = none.
	action: { text: string, onPress: () -> () }?,
}

local GOLD = TrainingConstants.GUIDE.calm
local SHADE_TRANSPARENCY = 0.35
local RING_THICKNESS = 6
local RING_INK = 12
local ARROW_SIZE = 64
-- The coach's size on screen (TrainingCoach's desktop / phone sizes).
local COACH_DESKTOP = Vector2.new(706, 230)
local COACH_PHONE = Vector2.new(342, 110)
-- A pinned coach card's distance from the screen's bottom and from the button column (desktop px, scaled).
local PINNED_MARGIN = 24
-- A compact card's size against the full one (owner 11-13: the hub's card was too big over the lobby).
local COMPACT_SCALE = 0.65
-- The action button's size and its gap above the card (desktop px, scaled).
local ACTION_SIZE = Vector2.new(300, 64)
local ACTION_GAP = 10

-- The gold arrow image, its tip at `at`, rotated `rotation` degrees (0 = pointing down).
local function arrowAt(at: Vector2, rotation: number, bob: number): React.ReactNode
	local height = math.floor(ARROW_SIZE * 1.29)
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(at.X, at.Y - bob),
		Size = UDim2.fromOffset(ARROW_SIZE, height),
		BackgroundTransparency = 1,
		Image = TrainingConstants.GUIDE.arrow,
		ImageColor3 = GOLD,
		Rotation = rotation,
		ZIndex = 20,
	})
end

-- Pippa says the line, placed near the layout's line spot and kept on the screen.
local function Coach(props: TrainingSpotlightProps): React.ReactNode
	local phone = props.screen.Y < 500
	-- The Coach layer is in screen px: the coach is drawn at the HUD's scale for this screen (desktop sizes are for
	-- 1920x1080), never bigger than designed.
	local scale = if phone then 1 else math.clamp(math.min(props.screen.X / 1920, props.screen.Y / 1080), 0.5, 1)
	if props.compact == true and not phone then
		scale *= COMPACT_SCALE
	end
	local size = (if phone then COACH_PHONE else COACH_DESKTOP) * scale
	local left = (props.leftInset or 0) + 8
	local x = math.clamp(props.linePosition.X - size.X * 0.3, left, math.max(left, props.screen.X - size.X - 8))
	local bottom = math.clamp(props.linePosition.Y + size.Y * 0.7, size.Y + 8, props.screen.Y - 8)
	if props.pinned == true then
		local at =
			TrainingSpotlightUtils.pinnedCoach(props.screen, size, props.leftInset or 0, PINNED_MARGIN * scale, phone)
		x, bottom = at.X, at.Y
	end
	local card = e(TrainingCoach, {
		line = { text = props.line, pose = "point" },
		phone = phone,
		position = UDim2.fromOffset(x, bottom),
		zIndex = 22,
		scale = scale,
		onArea = props.onArea,
		coach = props.coach,
	})
	local action = props.action
	if action == nil then
		return card
	end
	-- The button keeps its full size on a compact card (it must stay easy to press).
	local buttonScale = if phone then 0.8 else math.max(scale, 0.6)
	local buttonSize = ACTION_SIZE * buttonScale
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		card = card,
		action = e(ToonButton, {
			variant = "secondary",
			small = true,
			text = action.text,
			textSize = math.floor(28 * buttonScale),
			size = UDim2.fromOffset(buttonSize.X, buttonSize.Y),
			-- Above the card; on a phone the card sits at the top of the screen, so the button goes under it.
			anchor = if phone then Vector2.new(1, 0) else Vector2.new(1, 1),
			position = if phone
				then UDim2.fromOffset(x + size.X, bottom + ACTION_GAP * buttonScale)
				else UDim2.fromOffset(x + size.X, bottom - size.Y - ACTION_GAP * buttonScale),
			onActivated = action.onPress,
			zIndex = 23,
		}),
	})
end
local function TrainingSpotlight(props: TrainingSpotlightProps): React.ReactNode
	local children: { [string]: React.ReactNode } = { line = e(Coach, props) }
	local hole = props.hole
	if hole ~= nil then
		local shades: { TrainingSpotlightUtils.Rect } = if props.dim == false
			then {}
			else TrainingSpotlightUtils.shades(hole, props.screen)
		for index, shade in shades do
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
		local ring = {
			position = UDim2.fromOffset(hole.position.X - grow, hole.position.Y - grow),
			size = UDim2.fromOffset(hole.size.X + grow * 2, hole.size.Y + grow * 2),
		}
		children.ringInk = e("Frame", {
			Position = ring.position,
			Size = ring.size,
			BackgroundTransparency = 1,
			ZIndex = 14,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 26) }),
			stroke = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = RING_INK }),
		})
		children.ring = e("Frame", {
			Position = ring.position,
			Size = ring.size,
			BackgroundTransparency = 1,
			ZIndex = 15,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 26) }),
			stroke = e("UIStroke", {
				Color = GOLD,
				Thickness = RING_THICKNESS,
				Transparency = props.pulse * 0.3,
			}),
		})
		-- The arrow bobs over the hole, pointing down at it (under it when the hole is at the top of the screen).
		local above = hole.position.Y > ARROW_SIZE * 1.6
		local tip = if above
			then Vector2.new(hole.position.X + hole.size.X / 2, hole.position.Y - RING_INK)
			else Vector2.new(
				hole.position.X + hole.size.X / 2,
				hole.position.Y + hole.size.Y + RING_INK + ARROW_SIZE * 1.29
			)
		children.pointer = arrowAt(tip, if above then 0 else 180, props.pulse * 10)
	end
	local arrow = props.arrow
	if arrow ~= nil then
		children.arrow = arrowAt(arrow.position, arrow.rotation, props.pulse * 10)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return TrainingSpotlight
