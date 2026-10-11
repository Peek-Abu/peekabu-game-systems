--!strict
--[=[
	CatchRehiredPanel: the HR "Rehired." notice around the respawn (Figma 4c desktop 22:263, 4e phone 22:299). A dark
	scrim, and centred on it a cream sheet: the ink "HARLOW & FINCH — HUMAN RESOURCES" header band, "NOTICE OF
	RE-EMPLOYMENT", the big typewriter "Rehired.", the ruled rows, a red REHIRED stamp in the empty lower-right area (clear
	of the headline) and "Respawning at the loading bay…". Every string comes from the specced CatchViewModel.rehired.
	Presentational.

	@class CatchRehiredPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CatchViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Catch.CatchViewModel)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type CatchRehiredPanelProps = {
	view: CatchViewModel.RehiredView,
	layout: UIPaperConstants.Layout,
}

-- Every measurement per layout, in px, from the Figma frames (positions are inside the card).
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
	rowStep: number,
	rowSize: number,
	-- How far below a row's top its rule sits, and the rule's width.
	ruleBelow: number,
	ruleWidth: number,
	stampCentre: Vector2,
	stampSize: number,
	footerAt: Vector2,
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
		rowStep = 44,
		rowSize = 22,
		ruleBelow = 34,
		ruleWidth = 680,
		stampCentre = Vector2.new(555, 525),
		stampSize = 60,
		footerAt = Vector2.new(40, 550),
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
		rowStep = 24,
		rowSize = 15,
		ruleBelow = 20,
		ruleWidth = 394,
		stampCentre = Vector2.new(319, 253),
		stampSize = 30,
		footerAt = Vector2.new(23, 313),
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

local function CatchRehiredPanel(props: CatchRehiredPanelProps): React.ReactNode
	local view = props.view
	local spec = SPEC[props.layout]

	local content: { [string]: React.ReactNode } = {
		band = e("Frame", {
			Size = UDim2.new(1, 0, 0, spec.band),
			BackgroundColor3 = COLOR.ink,
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
			position = UDim2.fromOffset(spec.stampCentre.X, spec.stampCentre.Y),
		}),
		footer = e(PaperLabel, {
			text = view.footer,
			role = "body",
			size = spec.footerSize,
			color = FOOTER_INK,
			position = UDim2.fromOffset(spec.footerAt.X, spec.footerAt.Y),
			fit = true,
		}),
	}
	for index, row in view.rows do
		local top = spec.rowsAt.Y + (index - 1) * spec.rowStep
		content[`row{index}`] = e(PaperLabel, {
			text = row,
			role = "body",
			size = spec.rowSize,
			color = COLOR.ink,
			position = UDim2.fromOffset(spec.rowsAt.X, top),
			frame = UDim2.fromOffset(spec.ruleWidth, 0),
			wrapped = false,
		})
		content[`rule{index}`] = e("Frame", {
			Position = UDim2.fromOffset(spec.rowsAt.X, top + spec.ruleBelow),
			Size = UDim2.fromOffset(spec.ruleWidth, 1),
			BackgroundColor3 = RULE,
			BorderSizePixel = 0,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = SCRIM,
		BackgroundTransparency = SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
	}, {
		card = e(PaperSheet, {
			size = UDim2.fromOffset(spec.card.X, spec.card.Y),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			paper = COLOR.cream,
			padding = 0,
			children = content,
		}),
	})
end

return CatchRehiredPanel
