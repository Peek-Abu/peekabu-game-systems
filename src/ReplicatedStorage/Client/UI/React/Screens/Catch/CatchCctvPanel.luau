--!strict
--[=[
	CatchCctvPanel: the CCTV feed while the local player is caught (Figma 4b desktop 22:249, 4d phone 22:285, restyle
	approved 2026-10-11). Faint horizontal scanlines over the view, four white L-shaped corner brackets, top-left the
	red REC dot with "REC   CAM 04 · ROOM", "WATCHING  NAME" and the carrying line, top-right the night-clock timestamp,
	bottom-centre "BACK ON THE CLOCK IN 0:06", and the cream INCIDENT REPORT slip (a red band, tilted). Desktop draws
	the previous / next teammate key chips under the countdown; the phone draws two round "<" / ">" buttons at the sides
	instead (`onPrev` / `onNext`), clear of the engine's Jump button (`jump`, from ShiftHudViewModel.arcFor). Every string comes
	from the specced CatchViewModel. Presentational.

	@class CatchCctvPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperButton = require(script.Parent.Parent.Paper.PaperButton)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

export type CatchCctvPanelProps = {
	view: CatchViewModel.CctvView,
	layout: UIPaperConstants.Layout,
	onPrev: () -> (),
	onNext: () -> (),
	-- The engine's Jump button (offsets from the bottom-right corner); the phone buttons sit above its top.
	jump: ShiftHudViewModel.ArcSpot,
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

local COLOR = UIPaperConstants.COLOR
-- Figma: the scanlines at 7% opacity, a night wash at 25%, the carrying line at 85%, the slip tilted 1.2°.
local SCAN_TRANSPARENCY = 0.93
local WASH_TRANSPARENCY = 0.75
local DETAILS_TRANSPARENCY = 0.15
local SLIP_TILT = -1.2
-- The desktop key chips: 12 px from chip to label, 120 px between the two hints, 50 px under the countdown.
local CHIP_SIZE = 22
local CHIP_LABEL_GAP = 12
local HINT_GAP = 120
local CHIPS_BELOW_BACK = 50
-- The phone buttons (Figma "Mobile button"): 72 px, night at 72%, a 3 px fluorescent ring at 85%, a 30 px label; their
-- foot sits BUTTON_ABOVE_JUMP above the Jump button's offset (272 px on the 390 px phone, as in 4d).
local BUTTON_SIZE = 72
local BUTTON_FILL_TRANSPARENCY = 0.28
local BUTTON_STROKE_TRANSPARENCY = 0.15
local BUTTON_TEXT = 30
local BUTTON_ABOVE_JUMP = 28
-- Enough lines to cover any viewport height.
local SCAN_HEIGHT = 1600

-- `drawnScale` is the scale the panel is drawn at (PaperHudFrame): a line stays 1 real px thick when it is scaled down.
local function scanlines(gap: number, drawnScale: React.Binding<number>): React.ReactNode
	local thickness = drawnScale:map(function(value: number): UDim2
		return UDim2.new(1, 0, 0, 1 / value)
	end)
	local lines: { [string]: React.ReactNode } = {}
	for index = 0, SCAN_HEIGHT // gap do
		lines[`l{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, index * gap),
			Size = thickness,
			BackgroundColor3 = COLOR.fluorescent,
			BackgroundTransparency = SCAN_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.night,
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
			BackgroundColor3 = COLOR.fluorescent,
			BorderSizePixel = 0,
		})
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

local function incidentSlip(view: CatchViewModel.CctvView, spec: Spec): React.ReactNode
	local lines: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	}
	for index, line in view.incident do
		lines[`line{index}`] = e(PaperLabel, {
			text = line,
			role = "body",
			size = spec.slipText,
			color = COLOR.ink,
			layoutOrder = index,
		})
	end
	return e("Frame", {
		AnchorPoint = spec.slipAnchor,
		Position = spec.slipAt,
		Size = UDim2.fromOffset(spec.slipSize.X, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Rotation = SLIP_TILT,
		BackgroundColor3 = COLOR.cream,
		BorderSizePixel = 0,
	}, {
		least = e("UISizeConstraint", { MinSize = spec.slipSize }),
		padding = e("UIPadding", { PaddingBottom = UDim.new(0, spec.slipPad) }),
		band = e("Frame", {
			Size = UDim2.new(1, 0, 0, spec.slipBand),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
		}, {
			title = e(PaperLabel, {
				text = view.incidentTitle,
				role = "heading",
				size = spec.slipTitle,
				color = COLOR.cream,
				position = UDim2.fromOffset(spec.slipPad, 0),
				frame = UDim2.new(1, -2 * spec.slipPad, 1, 0),
				autoSize = false,
				wrapped = false,
			}),
		}),
		body = e("Frame", {
			Position = UDim2.fromOffset(spec.slipPad, spec.slipBand + 4),
			Size = UDim2.new(1, -2 * spec.slipPad, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, lines),
	})
end

local function hint(key: string, label: string, order: number): React.ReactNode
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CHIP_LABEL_GAP),
		}),
		chip = e(KeyChip, { label = key, size = CHIP_SIZE, layoutOrder = 1 }),
		label = e(PaperLabel, {
			text = label,
			role = "body",
			size = CHIP_SIZE,
			color = COLOR.fluorescent,
			fit = true,
			layoutOrder = 2,
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

-- A round phone button with an approved text label ("<" / ">"), `side` 0 on the left edge, 1 on the right.
local function roundButton(
	text: string,
	side: number,
	spec: Spec,
	jump: ShiftHudViewModel.ArcSpot,
	onPress: () -> ()
): React.ReactNode
	local edge = if side == 0 then spec.inset.left else -spec.inset.right
	local content: React.ReactNode = e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = BUTTON_FILL_TRANSPARENCY,
		BorderSizePixel = 0,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 3,
			Transparency = BUTTON_STROKE_TRANSPARENCY,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		label = e(PaperLabel, {
			text = text,
			role = "heading",
			size = BUTTON_TEXT,
			color = COLOR.fluorescent,
			align = "center",
			frame = UDim2.fromScale(1, 1),
			autoSize = false,
			wrapped = false,
		}),
	})
	return e(PaperButton, {
		text = "",
		variant = "surface",
		content = content,
		anchor = Vector2.new(side, 1),
		position = UDim2.new(side, edge, 1, jump.y - BUTTON_ABOVE_JUMP),
		size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		textSize = BUTTON_TEXT,
		onActivated = onPress,
	})
end

local function CatchCctvPanel(props: CatchCctvPanelProps): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local spec = SPEC[props.layout]
	-- The lines change only with the layout and the drawn scale: memoised, so the countdown's re-renders skip them.
	local drawnScale = React.useContext(PaperScaleContext.Context)
	local linesDeps: { unknown } = { spec.scanGap, drawnScale }
	local lines = React.useMemo(function(): React.ReactNode
		return scanlines(spec.scanGap, drawnScale)
	end, linesDeps)

	local children: { [string]: React.ReactNode } = {
		scanlines = lines,
		topLeft = bracket(spec, Vector2.new(0, 0)),
		topRight = bracket(spec, Vector2.new(1, 0)),
		bottomLeft = bracket(spec, Vector2.new(0, 1)),
		bottomRight = bracket(spec, Vector2.new(1, 1)),
		dot = e("Frame", {
			Position = UDim2.fromOffset(spec.dotAt.X, spec.dotAt.Y),
			Size = UDim2.fromOffset(spec.dot, spec.dot),
			BackgroundColor3 = COLOR.exitRed,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		rec = e(PaperLabel, {
			text = view.rec,
			role = "timer",
			size = spec.recSize,
			color = COLOR.fluorescent,
			position = UDim2.fromOffset(spec.recAt.X, spec.recAt.Y),
			fit = true,
		}),
		watching = e(PaperLabel, {
			text = view.watching,
			role = "heading",
			size = spec.watchingSize,
			color = COLOR.fluorescent,
			position = UDim2.fromOffset(spec.watchingAt.X, spec.watchingAt.Y),
			fit = true,
		}),
		details = e(PaperLabel, {
			text = view.details,
			role = "body",
			size = spec.detailsSize,
			color = COLOR.fluorescent,
			transparency = DETAILS_TRANSPARENCY,
			position = UDim2.fromOffset(spec.detailsAt.X, spec.detailsAt.Y),
			fit = true,
		}),
		stamp = e(PaperLabel, {
			text = view.stamp,
			role = "timer",
			size = spec.stampSize,
			color = COLOR.fluorescent,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -spec.stampRight, 0, spec.recAt.Y),
			fit = true,
		}),
		back = e(PaperLabel, {
			text = view.back,
			role = "timer",
			size = spec.backSize,
			color = COLOR.fluorescent,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 1, -spec.backBottom),
			fit = true,
		}),
		incident = if #view.incident > 0 then incidentSlip(view, spec) else nil,
	}
	if phone then
		children.prevButton = roundButton("<", 0, spec, props.jump, props.onPrev)
		children.nextButton = roundButton(">", 1, spec, props.jump, props.onNext)
	else
		children.hints = keyHints(view, spec)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return CatchCctvPanel
