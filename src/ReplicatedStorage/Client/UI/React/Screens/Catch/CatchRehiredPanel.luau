--!strict
--[=[
	CatchRehiredPanel: the HR "Rehired." notice around the respawn (Figma 4c desktop 22:263, 4e phone 22:299). A dark
	scrim, and centred on it a cream sheet: the ink "HARLOW & FINCH — HUMAN RESOURCES" header band, "NOTICE OF
	RE-EMPLOYMENT", the big typewriter "Rehired.", the ruled rows, a red REHIRED stamp in the empty lower-right area (clear
	of the headline) and "Respawning at the loading bay…". The rows wrap and stack by their real height (a long "Dropped:"
	row takes two lines); the card grows by whatever the rows take beyond the Figma's one-line rows, so the stamp and the
	footer (placed from the card's bottom) stay below the last row. Every string comes from the specced
	CatchViewModel.rehired. Presentational.

	@class CatchRehiredPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type CatchRehiredPanelProps = {
	view: CatchViewModel.RehiredView,
	layout: UIPaperConstants.Layout,
}

-- Every measurement per layout, in px, from the Figma frames (positions are inside the card; the card's height is its
-- height with one-line rows).
type Spec = {
	card: Vector2,
	band: number,
	headerSize: number,
	headerX: number,
	noticeAt: Vector2,
	noticeSize: number,
	titleAt: Vector2,
	titleSize: number,
	rowsAt: Vector2,
	rowSize: number,
	-- The gap from a row's text to its rule, from a rule to the next row, and the rules' width.
	ruleGap: number,
	rowGap: number,
	ruleWidth: number,
	-- The rows' height in the Figma (one line each): the card grows by anything beyond it.
	rowsHeight: number,
	-- The stamp's centre (x from the left, y from the bottom) and the footer's top (from the bottom).
	stampCentre: Vector2,
	stampSize: number,
	footerX: number,
	footerFromBottom: number,
	footerSize: number,
}

local SPEC: { [UIPaperConstants.Layout]: Spec } = {
	desktop = {
		card = Vector2.new(760, 600),
		band = 48,
		headerSize = 22,
		headerX = 24,
		noticeAt = Vector2.new(40, 76),
		noticeSize = 22,
		titleAt = Vector2.new(36, 108),
		titleSize = 104,
		rowsAt = Vector2.new(40, 270),
		rowSize = 22,
		ruleGap = 12,
		rowGap = 9,
		ruleWidth = 680,
		rowsHeight = 167,
		stampCentre = Vector2.new(555, 75),
		stampSize = 60,
		footerX = 40,
		footerFromBottom = 50,
		footerSize = 20,
	},
	phone = {
		card = Vector2.new(440, 347),
		band = 28,
		headerSize = 14,
		headerX = 14,
		noticeAt = Vector2.new(23, 44),
		noticeSize = 15,
		titleAt = Vector2.new(21, 63),
		titleSize = 56,
		rowsAt = Vector2.new(23, 145),
		rowSize = 15,
		ruleGap = 5,
		rowGap = 3,
		ruleWidth = 394,
		rowsHeight = 45,
		stampCentre = Vector2.new(319, 94),
		stampSize = 30,
		footerX = 23,
		footerFromBottom = 34,
		footerSize = 14,
	},
}

local COLOR = UIPaperConstants.COLOR
-- Figma 4c/4e: the scrim (#050506 at 82%), the notice line's brown ink, the rules' manila and the footer's faded ink.
local SCRIM = Color3.fromHex("050506")
local SCRIM_TRANSPARENCY = 0.18
local NOTICE_INK = Color3.fromHex("5B4A2E")
local RULE = Color3.fromHex("C9B994")
local FOOTER_INK = Color3.fromHex("8A7F6A")
-- The stamp turns 8° clockwise (Figma -8°).
local STAMP_TILT = 8
-- Roblox caps TextSize at 100: a bigger headline is drawn at 100 and enlarged by a UIScale.
local MAX_TEXT_SIZE = 100

local function headline(text: string, spec: Spec): React.ReactNode
	local size = math.min(spec.titleSize, MAX_TEXT_SIZE)
	return e("Frame", {
		Position = UDim2.fromOffset(spec.titleAt.X, spec.titleAt.Y),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		scale = if spec.titleSize > size then e("UIScale", { Scale = spec.titleSize / size }) else nil,
		label = e(PaperLabel, { text = text, role = "body", size = size, color = COLOR.ink, fit = true }),
	})
end

-- One row: its wrapped text, then its rule.
local function row(text: string, order: number, spec: Spec): React.ReactNode
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, spec.ruleGap) }),
		text = e(PaperLabel, { text = text, role = "body", size = spec.rowSize, color = COLOR.ink, layoutOrder = 1 }),
		rule = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = RULE,
			BorderSizePixel = 0,
		}),
	})
end

local function CatchRehiredPanel(props: CatchRehiredPanelProps): React.ReactNode
	local view = props.view
	local spec = SPEC[props.layout]
	-- The rows' measured height in design px (0 until they are laid out); the card grows by what they take beyond the
	-- Figma's. AbsoluteSize is real px, so it is divided by the scale the notice is drawn at (PaperHudFrame).
	local measured, setMeasured = React.useState(0)
	local drawnScale = React.useContext(PaperScaleContext.Context)
	local grow = math.max(0, measured - spec.rowsHeight)

	local rows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, spec.rowGap) }),
	}
	for index, text in view.rows do
		rows[`row{index}`] = row(text, index, spec)
	end

	local content: { [string]: React.ReactNode } = {
		band = e("Frame", {
			Size = UDim2.new(1, 0, 0, spec.band),
			BackgroundColor3 = COLOR.companyTeal,
			BorderSizePixel = 0,
		}, {
			header = e(PaperLabel, {
				text = view.header,
				role = "heading",
				size = spec.headerSize,
				color = COLOR.cream,
				position = UDim2.fromOffset(spec.headerX, 0),
				frame = UDim2.new(1, -2 * spec.headerX, 1, 0),
				autoSize = false,
				wrapped = false,
			}),
		}),
		notice = e(PaperLabel, {
			text = view.notice,
			role = "body",
			size = spec.noticeSize,
			color = NOTICE_INK,
			position = UDim2.fromOffset(spec.noticeAt.X, spec.noticeAt.Y),
			fit = true,
		}),
		title = headline(view.title, spec),
		stamp = e(PaperStamp, {
			text = view.stamp,
			size = spec.stampSize,
			tilt = STAMP_TILT,
			pop = true,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0, spec.stampCentre.X, 1, -spec.stampCentre.Y),
		}),
		footer = e(PaperLabel, {
			text = view.footer,
			role = "body",
			size = spec.footerSize,
			color = FOOTER_INK,
			position = UDim2.new(0, spec.footerX, 1, -spec.footerFromBottom),
			fit = true,
		}),
		rows = e("Frame", {
			Position = UDim2.fromOffset(spec.rowsAt.X, spec.rowsAt.Y),
			Size = UDim2.fromOffset(spec.ruleWidth, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setMeasured(frame.AbsoluteSize.Y / drawnScale:getValue())
			end,
		}, rows),
	}

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SCRIM,
		BackgroundTransparency = SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
	}, {
		card = e(PaperSheet, {
			size = UDim2.fromOffset(spec.card.X, spec.card.Y + grow),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			paper = COLOR.cream,
			padding = 0,
			children = content,
		}),
	})
end

return CatchRehiredPanel
