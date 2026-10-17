--!strict
--[=[
	CatchCctvPanel: the CCTV feed while the local player is caught (Figma 4b desktop 22:249, 4d phone 22:285), in the V1
	kit. The feed itself stays diegetic and quiet: faint scanlines and a night wash over the view, four white L-shaped
	corner brackets. On it, in the kit: top-left a coral REC light with "REC   CAM 04 · ROOM" and "WATCHING  NAME" in
	stroked display type over the carrying line, top-right the night-clock timestamp, bottom-centre "BACK ON THE CLOCK
	IN 0:06" in coral on a dark pill, and the INCIDENT REPORT as a cream panel on the depth stack with its title on a
	coral pill breaking its top-left corner. Desktop draws the previous / next teammate key caps under the countdown; the
	phone draws two round PREV / NEXT buttons at the sides instead (`onPrev` / `onNext`), clear of the engine's Jump
	button (`jump`, from ShiftHudViewModel.arcFor). Every string comes
	from the specced CatchViewModel. Presentational.

	@class CatchCctvPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type CatchCctvPanelProps = {
	view: CatchViewModel.CctvView,
	layout: UIPaperConstants.Layout,
	onPrev: () -> (),
	onNext: () -> (),
	-- The engine's Jump button (offsets from the bottom-right corner); the phone buttons sit above its top.
	jump: ShiftHudViewModel.ArcSpot,
	-- Design px the night wash reaches above the panel's top so it covers the whole screen when the panel is drawn in
	-- a shifted PaperHudFrame (PaperHudScaleViewModel.bleed). nil = 0 (a story, or an unshifted frame).
	bleedTop: number?,
}

-- Every measurement per layout, in px, from the Figma frames (1920x1080 and 844x390).
type Spec = {
	scanGap: number,
	inset: { left: number, right: number, top: number, bottom: number },
	arm: number,
	thick: number,
	dot: number,
	dotAt: Vector2,
	recAt: Vector2,
	recSize: number,
	watchingAt: Vector2,
	watchingSize: number,
	detailsAt: Vector2,
	detailsSize: number,
	stampRight: number,
	stampSize: number,
	-- The countdown's top, from the bottom edge.
	backBottom: number,
	backSize: number,
	-- The slip: its width and least height (it grows with its text), and the corner it hangs from (desktop: its
	-- bottom-right, growing up; phone: its top-right below the timestamp, growing down).
	slipSize: Vector2,
	slipAnchor: Vector2,
	slipAt: UDim2,
	slipBand: number,
	slipTitle: number,
	slipText: number,
	slipPad: number,
}

local SPEC: { [UIPaperConstants.Layout]: Spec } = {
	desktop = {
		scanGap = 6,
		inset = { left = 64, right = 64, top = 84, bottom = 48 },
		arm = 70,
		thick = 4,
		dot = 18,
		dotAt = Vector2.new(96, 110),
		recAt = Vector2.new(124, 104),
		recSize = 24,
		watchingAt = Vector2.new(96, 140),
		watchingSize = 48,
		detailsAt = Vector2.new(96, 206),
		detailsSize = 22,
		stampRight = 96,
		stampSize = 24,
		backBottom = 150,
		backSize = 28,
		slipSize = Vector2.new(430, 128),
		slipAnchor = Vector2.new(1, 1),
		slipAt = UDim2.new(1, -95, 1, -90),
		slipBand = 39,
		slipTitle = 20,
		slipText = 20,
		slipPad = 14,
	},
	phone = {
		scanGap = 4,
		inset = { left = 48, right = 48, top = 62, bottom = 20 },
		arm = 34,
		thick = 3,
		dot = 10,
		dotAt = Vector2.new(62, 74),
		recAt = Vector2.new(78, 70),
		recSize = 14,
		watchingAt = Vector2.new(62, 90),
		watchingSize = 26,
		detailsAt = Vector2.new(62, 128),
		detailsSize = 14,
		stampRight = 62,
		stampSize = 14,
		backBottom = 56,
		backSize = 16,
		slipSize = Vector2.new(250, 60),
		slipAnchor = Vector2.new(1, 0),
		slipAt = UDim2.new(1, -61, 0, 94),
		slipBand = 21,
		slipTitle = 12,
		slipText = 14,
		slipPad = 8,
	},
}

local COLOR = UIToonConstants.COLOR
-- The feed's own light: scanlines and brackets in white, a night wash at 25%, the carrying line at 85%.
local FEED = COLOR.white
local WASH = UIToonConstants.shade("night").lo
local SCAN_TRANSPARENCY = 0.93
local WASH_TRANSPARENCY = 0.75
local DETAILS_TRANSPARENCY = 0.15
-- The desktop key caps: 12 px from cap to label, 120 px between the two hints, 50 px under the countdown.
local CHIP_SIZE = 22
local CHIP_LABEL_GAP = 12
local HINT_GAP = 120
local CHIPS_BELOW_BACK = 50
-- The phone buttons: 76 px round plates, their foot BUTTON_ABOVE_JUMP above the Jump button's offset.
local BUTTON_SIZE = 76
local BUTTON_TEXT = 18
local BUTTON_ABOVE_JUMP = 28
-- Enough lines to cover any viewport height.
local SCAN_HEIGHT = 1600

-- `drawnScale` is the scale the panel is drawn at (PaperHudFrame): a line stays 1 real px thick when it is scaled down.
local function scanlines(gap: number, drawnScale: React.Binding<number>, bleed: number): React.ReactNode
	local thickness = drawnScale:map(function(value: number): UDim2
		return UDim2.new(1, 0, 0, 1 / value)
	end)
	local lines: { [string]: React.ReactNode } = {}
	for index = 0, SCAN_HEIGHT // gap do
		lines[`l{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, index * gap),
			Size = thickness,
			BackgroundColor3 = FEED,
			BackgroundTransparency = SCAN_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	return e("Frame", {
		-- The wash covers the whole screen, top bar included: it reaches `bleed` above the panel.
		Position = UDim2.fromOffset(0, -bleed),
		Size = UDim2.new(1, 0, 1, bleed),
		ZIndex = 0,
		BackgroundColor3 = WASH,
		BackgroundTransparency = WASH_TRANSPARENCY,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, lines)
end

-- One L-shaped bracket in the corner `corner` ((0, 0) top-left ... (1, 1) bottom-right).
local function bracket(spec: Spec, corner: Vector2): React.ReactNode
	local x = if corner.X == 0 then spec.inset.left else -spec.inset.right
	local y = if corner.Y == 0 then spec.inset.top else -spec.inset.bottom
	local function bar(size: UDim2): React.ReactNode
		return e("Frame", {
			AnchorPoint = corner,
			Position = UDim2.fromScale(corner.X, corner.Y),
			Size = size,
			BackgroundColor3 = FEED,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return e("Frame", {
		AnchorPoint = corner,
		Position = UDim2.new(corner.X, x, corner.Y, y),
		Size = UDim2.fromOffset(spec.arm, spec.arm),
		BackgroundTransparency = 1,
	}, {
		across = bar(UDim2.fromOffset(spec.arm, spec.thick)),
		down = bar(UDim2.fromOffset(spec.thick, spec.arm)),
	})
end

-- How many lines `text` wraps to across `width` px of Fredoka at `size` (its average glyph is about 0.52 em wide).
local function linesOf(text: string, size: number, width: number): number
	return math.max(1, math.ceil((utf8.len(text) or #text) * size * 0.52 / width))
end

local function incidentSlip(view: CatchViewModel.CctvView, spec: Spec): React.ReactNode
	local lineHeight = math.ceil(spec.slipText * 1.3)
	local top = math.ceil(spec.slipBand * 0.6)
	local width = spec.slipSize.X - 2 * spec.slipPad
	local face: { [string]: React.ReactNode } = {}
	local y = top
	for index, line in view.incident do
		local height = linesOf(line, spec.slipText, width) * lineHeight
		face[`line{index}`] = e(ToonText, {
			text = line,
			font = "body",
			textSize = spec.slipText,
			position = UDim2.fromOffset(spec.slipPad, y),
			size = UDim2.new(1, -2 * spec.slipPad, 0, height),
			wrapped = true,
			fit = true,
			alignY = "top",
		})
		y += height
	end
	local height = math.max(spec.slipSize.Y, y + spec.slipPad + UIToonConstants.DEPTH.lip)
	return e("Frame", {
		AnchorPoint = spec.slipAnchor,
		Position = spec.slipAt,
		Size = UDim2.fromOffset(spec.slipSize.X, height + UIToonConstants.DEPTH.drop),
		BackgroundTransparency = 1,
	}, {
		panel = e(ToonPanel, {
			size = Vector2.new(spec.slipSize.X, height),
			radius = if spec.slipSize.X < 300 then 16 else 22,
			children = face,
		}),
		title = e(ToonPill, {
			text = view.incidentTitle,
			hue = "coral",
			textSize = spec.slipTitle,
			tilt = -3,
			position = UDim2.fromOffset(-spec.slipPad, -math.ceil(spec.slipBand * 0.55)),
			size = UDim2.fromOffset(
				math.min(
					spec.slipSize.X,
					40 + (utf8.len(view.incidentTitle) or #view.incidentTitle) * spec.slipTitle * 0.62
				),
				spec.slipBand
			),
			zIndex = 5,
		}),
	})
end

local function hint(key: string, label: string, order: number): React.ReactNode
	local cap: { [string]: React.ReactNode } = {
		key = e(ToonText, {
			text = key,
			textSize = CHIP_SIZE - 2,
			size = UDim2.fromScale(1, 1),
			align = "center",
			fit = true,
		}),
	}
	local capWidth = math.max(CHIP_SIZE + 18, (utf8.len(key) or #key) * CHIP_SIZE * 0.7 + 18)
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(
			capWidth + CHIP_LABEL_GAP + (utf8.len(label) or #label) * CHIP_SIZE * 0.55,
			CHIP_SIZE + 20
		),
		BackgroundTransparency = 1,
	}, {
		cap = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 9,
			size = UDim2.fromOffset(capWidth, CHIP_SIZE + 14),
			children = cap,
		}),
		label = e(ToonText, {
			text = label,
			font = "body",
			color = COLOR.white,
			textSize = CHIP_SIZE,
			position = UDim2.fromOffset(capWidth + CHIP_LABEL_GAP, 0),
			size = UDim2.new(1, -capWidth - CHIP_LABEL_GAP, 0, CHIP_SIZE + 14),
			fit = true,
		}),
	})
end

local function keyHints(view: CatchViewModel.CctvView, spec: Spec): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -spec.backBottom + CHIPS_BELOW_BACK),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, HINT_GAP),
		}),
		prev = hint(view.prevKey, "previous", 1),
		next = hint(view.nextKey, "next teammate", 2),
	})
end

-- A round phone button (PREV / NEXT), `side` 0 on the left edge, 1 on the right.
local function roundButton(
	text: string,
	side: number,
	spec: Spec,
	jump: ShiftHudViewModel.ArcSpot,
	onPress: () -> ()
): React.ReactNode
	local edge = if side == 0 then spec.inset.left else -spec.inset.right
	return e(ToonButton, {
		text = text,
		variant = "night",
		radius = 999,
		anchor = Vector2.new(side, 1),
		position = UDim2.new(side, edge, 1, jump.y - BUTTON_ABOVE_JUMP),
		size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		textSize = BUTTON_TEXT,
		onActivated = onPress,
	})
end

-- One line of the feed's own type in white: stroked display type, or Fredoka (`display` false).
local function feedText(
	text: string,
	size: number,
	position: UDim2,
	anchor: Vector2?,
	display: boolean,
	transparency: number?,
	align: ("left" | "right" | "center")?
): React.ReactNode
	return e(ToonText, {
		text = text,
		font = if display then "display" else "body",
		color = COLOR.white,
		textSize = size,
		anchor = anchor,
		position = position,
		size = UDim2.fromOffset(0, math.ceil(size * 1.35)),
		automaticWidth = true,
		align = align,
		transparency = transparency,
	})
end

local function CatchCctvPanel(props: CatchCctvPanelProps): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local spec = SPEC[props.layout]
	-- The lines change only with the layout and the drawn scale: memoised, so the countdown's re-renders skip them.
	local drawnScale = React.useContext(PaperScaleContext.Context)
	local bleed = props.bleedTop or 0
	local linesDeps: { unknown } = { spec.scanGap, drawnScale, bleed }
	local lines = React.useMemo(function(): React.ReactNode
		return scanlines(spec.scanGap, drawnScale, bleed)
	end, linesDeps)
	local backWidth = math.ceil((utf8.len(view.back) or #view.back) * spec.backSize * 0.62 + 48)

	local children: { [string]: React.ReactNode } = {
		scanlines = lines,
		topLeft = bracket(spec, Vector2.new(0, 0)),
		topRight = bracket(spec, Vector2.new(1, 0)),
		bottomLeft = bracket(spec, Vector2.new(0, 1)),
		bottomRight = bracket(spec, Vector2.new(1, 1)),
		dot = e(ToonSurface, {
			hue = "coral",
			small = true,
			radius = 999,
			position = UDim2.fromOffset(spec.dotAt.X - 2, spec.dotAt.Y - 2),
			size = UDim2.fromOffset(spec.dot + 4, spec.dot + 4),
		}),
		rec = feedText(view.rec, spec.recSize, UDim2.fromOffset(spec.recAt.X, spec.recAt.Y - 2), nil, true),
		watching = feedText(
			view.watching,
			spec.watchingSize,
			UDim2.fromOffset(spec.watchingAt.X, spec.watchingAt.Y),
			nil,
			true
		),
		details = feedText(
			view.details,
			spec.detailsSize,
			UDim2.fromOffset(spec.detailsAt.X, spec.detailsAt.Y),
			nil,
			false,
			DETAILS_TRANSPARENCY
		),
		stamp = feedText(
			view.stamp,
			spec.stampSize,
			UDim2.new(1, -spec.stampRight, 0, spec.recAt.Y - 2),
			Vector2.new(1, 0),
			true,
			nil,
			"right"
		),
		back = e(ToonPill, {
			text = view.back,
			hue = "night",
			meaning = "coral",
			textSize = spec.backSize,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 1, -spec.backBottom - 6),
			size = UDim2.fromOffset(backWidth, math.ceil(spec.backSize * 1.7)),
		}),
		incident = if #view.incident > 0 then incidentSlip(view, spec) else nil,
	}
	if phone then
		children.prevButton = roundButton("PREV", 0, spec, props.jump, props.onPrev)
		children.nextButton = roundButton("NEXT", 1, spec, props.jump, props.onNext)
	else
		children.hints = keyHints(view, spec)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return CatchCctvPanel
