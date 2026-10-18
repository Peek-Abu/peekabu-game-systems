--!strict
--[=[
	CatchRehiredPanel: the HR "Rehired." notice around the respawn (Figma 4c desktop 22:263, 4e phone 22:299) in the V1
	kit. A dark scrim, and centred on it a cream panel on the depth stack popping in: the grape header band ("MORROW &
	MORROW — HUMAN RESOURCES", the rehired player's own character, worried, breaking its corner), "NOTICE OF
	RE-EMPLOYMENT", the big stroked mint "Rehired.", the ruled rows, a tilted mint REHIRED sticker in the empty
	lower-right area (clear of the headline) and "Respawning at the loading bay…". The rows wrap and stack by their real
	height (a long "Dropped:" row takes two lines); the card grows by whatever the rows take beyond the Figma's one-line
	rows, so the sticker and the footer (placed from the card's bottom) stay below the last row. Every string comes from
	the specced CatchViewModel.rehired. Presentational.

	@class CatchRehiredPanel
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type CatchRehiredPanelProps = {
	view: CatchViewModel.RehiredView,
	layout: UIPaperConstants.Layout,
	-- Design px the scrim reaches above the panel's top so it covers the whole screen when the panel is drawn in a
	-- shifted PaperHudFrame (PaperHudScaleViewModel.bleed). nil = 0 (a story, or an unshifted frame).
	bleedTop: number?,
	-- Whose character breaks the header's corner (the rehired player); nil = the local player.
	userId: number?,
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

local COLOR = UIToonConstants.COLOR
-- The scrim (the night's darkest shade at 82%) and the notice and footer lines in a quiet grape.
local SCRIM = UIToonConstants.shade("night").lo
local SCRIM_TRANSPARENCY = 0.18
local QUIET = UIToonConstants.shade("grape").lo
local RULE = UIToonConstants.shade("cream").lo
-- The REHIRED sticker turns 8° clockwise.
local STAMP_TILT = 8
-- Roblox caps TextSize at 100: a bigger headline is drawn at 100 and enlarged by a UIScale.
local MAX_TEXT_SIZE = 100

local function headline(text: string, spec: Spec): React.ReactNode
	local size = math.min(spec.titleSize, MAX_TEXT_SIZE)
	return e("Frame", {
		Position = UDim2.fromOffset(spec.titleAt.X, spec.titleAt.Y),
		Size = UDim2.fromOffset(spec.ruleWidth / (spec.titleSize / size), math.ceil(size * 1.3)),
		BackgroundTransparency = 1,
	}, {
		scale = if spec.titleSize > size then e("UIScale", { Scale = spec.titleSize / size }) else nil,
		label = e(ToonText, {
			text = text,
			meaning = "mint",
			textSize = size,
			size = UDim2.fromScale(1, 1),
			fit = true,
		}),
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
		text = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextWrapped = true,
			FontFace = UIToonConstants.FONT.body,
			TextSize = spec.rowSize,
			TextColor3 = COLOR.ink,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		rule = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = RULE,
			BorderSizePixel = 0,
		}),
	})
end

local function CatchRehiredPanel(props: CatchRehiredPanelProps): React.ReactNode
	local view = props.view
	local me = Players.LocalPlayer
	local userId = props.userId or (if me ~= nil then me.UserId else nil)
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
		notice = e(ToonText, {
			text = view.notice,
			font = "body",
			color = QUIET,
			textSize = spec.noticeSize,
			position = UDim2.fromOffset(spec.noticeAt.X, spec.noticeAt.Y),
			size = UDim2.fromOffset(spec.ruleWidth, math.ceil(spec.noticeSize * 1.35)),
			fit = true,
		}),
		title = headline(view.title, spec),
		stamp = e(ToonPill, {
			text = view.stamp,
			hue = "mint",
			textSize = math.floor(spec.stampSize * 0.6),
			tilt = STAMP_TILT,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0, spec.stampCentre.X, 1, -spec.stampCentre.Y),
			size = UDim2.fromOffset(math.floor(spec.stampSize * 4.4), math.floor(spec.stampSize * 1.15)),
			zIndex = 6,
		}),
		footer = e(ToonText, {
			text = view.footer,
			font = "body",
			color = QUIET,
			textSize = spec.footerSize,
			position = UDim2.new(0, spec.footerX, 1, -spec.footerFromBottom - UIToonConstants.DEPTH.lip),
			size = UDim2.fromOffset(spec.ruleWidth * 0.6, math.ceil(spec.footerSize * 1.35)),
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

	local bleed = props.bleedTop or 0
	local card = Vector2.new(spec.card.X, spec.card.Y + grow)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- The scrim covers the whole screen, top bar included: it reaches `bleed` above the panel. The card is its
		-- sibling, so it stays centred in the panel.
		scrim = e("Frame", {
			Position = UDim2.fromOffset(0, -bleed),
			Size = UDim2.new(1, 0, 1, bleed),
			ZIndex = 0,
			BackgroundColor3 = SCRIM,
			BackgroundTransparency = SCRIM_TRANSPARENCY,
			BorderSizePixel = 0,
		}),
		card = e(ToonPanel, {
			size = card,
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			header = {
				title = view.header,
				-- The rehired player's own character, worried (the "caught" pose), where the kit's render would be: head,
				-- ears and chest (no edge of the unclipped frame cuts an ear), a little larger than the render.
				art = function(size: number): React.ReactNode
					return e(CharacterPortrait, {
						userId = userId,
						context = "caught",
						framing = "upper",
						anchor = Vector2.new(0.5, 0.5),
						position = UDim2.fromScale(0.5, 0.5),
						size = UDim2.fromOffset(size * 1.25, size * 1.25),
					})
				end,
				height = spec.band + 12,
				titleSize = spec.headerSize + 4,
			},
			pop = true,
			children = content,
		}),
	})
end

return CatchRehiredPanel
