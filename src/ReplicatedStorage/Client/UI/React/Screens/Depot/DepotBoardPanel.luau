--!strict
--[=[
	DepotBoardPanel: the depot's contract board (Figma 2a desktop 31:458, 2b phone 31:516) on the paperwork look: a cork
	pinboard (CorkBoard: wood frame, cork) over a dimmed depot with tonight's work order (folder tab, six rows on desktop and four on phone, the HAZARD
	row on a red wash, the APPROVED stamp and the night guard's sticky on desktop), the returning player's last-shift
	card (omitted when the view has none), the pinned dispatch slip ("JOIN A SHIFT" over a green marker stroke) and
	CLOSE. The board is drawn at its Figma size and positions and scaled by `scale` (DepotBoardViewModel.fit): centred
	on desktop, bottom-centred inside the phone safe area. Presentational: it draws the view it is given.

	Tilts are the Figma rotations with the sign flipped (Figma turns counter-clockwise, Roblox clockwise).

	@class DepotBoardPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CorkBoard = require(ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard)
local PaperButton = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton)
local PaperPropIcon = require(script.Parent.Parent.Paper.PaperPropIcon)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)

local e = React.createElement

export type DepotBoardPanelProps = {
	view: DepotBoardViewModel.BoardView,
	layout: UIPaperConstants.Layout,
	-- The board's scale on this screen (DepotBoardViewModel.fit).
	scale: number,
	onClose: () -> (),
}

-- One device's measurements, all Figma px in the board's own space.
type Geometry = {
	board: Vector2,
	border: number,
	sheet: { pos: Vector2, size: Vector2 },
	rows: { pos: Vector2, step: number, textX: number, textWidth: number, rule: number, label: number, text: number },
	last: { pos: Vector2, size: Vector2 },
	dispatch: { pos: Vector2, size: Vector2 },
	close: { pos: Vector2, size: Vector2, text: number },
}

local COLOR = UIPaperConstants.COLOR
-- Figma 2a/2b inks not on the Style page: the row labels' brown and the hazard text's dark red.
local LABEL_INK = Color3.fromHex("5B4A2E")
local HAZARD_INK = Color3.fromHex("7A1018")
-- Figma 2a scrim: night at 55% over the depot.
local SCRIM_TRANSPARENCY = 0.45
-- Board-level stacking: sheets, then the stamp and sticky over the work order's foot.
local Z_SHEET = 2
local Z_OVER = 4

local GEOMETRY: { [UIPaperConstants.Layout]: Geometry } = table.freeze({
	desktop = {
		board = Vector2.new(1580, 900),
		border = 10,
		sheet = { pos = Vector2.new(40, 128), size = Vector2.new(880, 730) },
		rows = {
			pos = Vector2.new(36, 134),
			step = 84,
			textX = 214,
			textWidth = 590,
			rule = 2,
			label = 22,
			text = 24,
		},
		last = { pos = Vector2.new(980, 128), size = Vector2.new(540, 400) },
		dispatch = { pos = Vector2.new(988, 566), size = Vector2.new(520, 206) },
		close = { pos = Vector2.new(1300, 790), size = Vector2.new(218, 74), text = 24 },
	},
	phone = {
		board = Vector2.new(748, 308),
		border = 5,
		sheet = { pos = Vector2.new(12, 12), size = Vector2.new(452, 284) },
		rows = {
			pos = Vector2.new(14, 70),
			step = 52,
			textX = 98,
			textWidth = 320,
			rule = 1,
			label = 15,
			text = 16,
		},
		last = { pos = Vector2.new(478, 12), size = Vector2.new(258, 112) },
		dispatch = { pos = Vector2.new(480, 136), size = Vector2.new(254, 90) },
		close = { pos = Vector2.new(560, 236), size = Vector2.new(130, 62), text = 16 },
	},
})

local function at(point: Vector2): UDim2
	return UDim2.fromOffset(point.X, point.Y)
end

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	x: number,
	y: number,
	width: number?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = UDim2.fromOffset(x, y),
		frame = if width ~= nil then UDim2.fromOffset(width, 0) else nil,
		fit = width == nil,
	})
end

-- The work order's rows: a rule over each, the label in a fixed column, the text wrapped beside it; HAZARD in red on
-- a red wash.
local function rowsOf(view: DepotBoardViewModel.BoardView, geometry: Geometry): React.ReactNode
	local rows = geometry.rows
	local width = geometry.sheet.size.X - 2 * rows.pos.X
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, row in view.rows do
		children[`row{index}`] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(width, rows.step),
			BackgroundTransparency = 1,
		}, {
			rule = e("Frame", {
				Size = UDim2.new(1, 0, 0, rows.rule),
				BackgroundColor3 = COLOR.manilaDeep,
				BorderSizePixel = 0,
			}),
			wash = if row.hazard
				then e("Frame", {
					Position = UDim2.fromOffset(0, rows.rule + 2),
					Size = UDim2.new(1, 0, 1, -rows.rule - 6),
					BackgroundColor3 = COLOR.stamp,
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
				})
				else nil,
			label = label(row.label, "heading", rows.label, if row.hazard then COLOR.inkRed else LABEL_INK, 0, 12),
			text = label(
				row.text,
				"body",
				rows.text,
				if row.hazard then HAZARD_INK else COLOR.ink,
				rows.textX,
				12,
				rows.textWidth
			),
		})
	end
	return e("Frame", {
		Position = at(rows.pos),
		Size = UDim2.fromOffset(width, rows.step * #view.rows),
		BackgroundTransparency = 1,
	}, children)
end

local function workOrderOf(view: DepotBoardViewModel.BoardView, layout: UIPaperConstants.Layout): React.ReactNode
	local geometry = GEOMETRY[layout]
	local phone = layout == "phone"
	local content: { [string]: React.ReactNode } = { rows = rowsOf(view, geometry) }
	if phone then
		content.number = label(view.workOrder, "heading", 16, LABEL_INK, 14, 8)
		content.headline = label(view.subline, "heading", 20, COLOR.ink, 14, 30, 424)
	else
		content.prop = e(
			"Frame",
			{ Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1 },
			{ art = e(PaperPropIcon, { kind = "jobs" }) }
		)
		content.headline = label(view.headline, "heading", 34, COLOR.ink, 104, 28)
		content.subline = label(view.subline, "body", 22, COLOR.ink, 36, 80, 800)
	end
	return e(PaperSheet, {
		position = at(geometry.sheet.pos),
		size = UDim2.fromOffset(geometry.sheet.size.X, geometry.sheet.size.Y),
		tab = if phone then nil else view.workOrder,
		paper = COLOR.cream,
		fastener = if phone then nil else "clip",
		padding = 0,
	}, content)
end

local function lastShiftOf(last: DepotBoardViewModel.LastView, layout: UIPaperConstants.Layout): React.ReactNode
	local geometry = GEOMETRY[layout]
	local content: { [string]: React.ReactNode } = {}
	if layout == "phone" then
		for index, line in last.lines do
			content[`line{index}`] = label(line, "medium", 17, COLOR.ink, 12, 12 + (index - 1) * 32)
		end
	else
		-- Figma rows are 56 apart from y 58 under a 40 px band; the kit's band is 26, so the rows sit 26 higher.
		for index, row in last.rows do
			local y = 32 + (index - 1) * 56
			content[`label{index}`] = label(row.label, "body", 24, COLOR.ink, 28, y + 8)
			content[`value{index}`] = e(PaperLabel, {
				text = row.value,
				role = "number",
				size = 32,
				color = COLOR.ink,
				align = "right",
				position = UDim2.fromOffset(330, y),
				frame = UDim2.fromOffset(180, 47),
				autoSize = false,
				wrapped = false,
			})
		end
		content.stamp = e(PaperStamp, {
			text = last.stamp,
			size = 30,
			tilt = 6,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(429, 311),
		})
	end
	return e(PaperSheet, {
		position = at(geometry.last.pos),
		size = UDim2.fromOffset(geometry.last.size.X, geometry.last.size.Y),
		paper = COLOR.cream,
		tilt = if layout == "phone" then 0 else -1.5,
		fastener = if layout == "phone" then nil else "clip",
		band = last.title,
		padding = 0,
	}, content)
end

local function dispatchOf(view: DepotBoardViewModel.BoardView, layout: UIPaperConstants.Layout): React.ReactNode
	local geometry = GEOMETRY[layout]
	local phone = layout == "phone"
	local content: { [string]: React.ReactNode }
	if phone then
		content = {
			label = label(view.dispatchLabel, "body", 14, LABEL_INK, 12, 8),
			marker = e("Frame", {
				Position = UDim2.fromOffset(12, 62),
				Size = UDim2.fromOffset(150, 5),
				BackgroundColor3 = COLOR.exitGreen,
				BorderSizePixel = 0,
			}),
			title = label(view.dispatchTitle, "heading", 26, COLOR.ink, 12, 24),
			steps = label(view.dispatchSteps, "body", 14, COLOR.ink, 12, 70, 236),
		}
	else
		content = {
			label = label(view.dispatchLabel, "body", 20, LABEL_INK, 28, 22),
			-- The green marker stroke under the title (drawn first, so the title's ink sits on it).
			marker = e("Frame", {
				Position = UDim2.fromOffset(28, 118),
				Size = UDim2.fromOffset(300, 7),
				BackgroundColor3 = COLOR.exitGreen,
				BorderSizePixel = 0,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
			title = label(view.dispatchTitle, "heading", 52, COLOR.ink, 26, 50),
			steps = label(view.dispatchSteps, "body", 22, COLOR.ink, 28, 136, 470),
		}
	end
	return e(PaperSheet, {
		position = at(geometry.dispatch.pos),
		size = UDim2.fromOffset(geometry.dispatch.size.X, geometry.dispatch.size.Y),
		paper = COLOR.cream,
		tilt = 1,
		fastener = "pin",
		padding = 0,
	}, content)
end

local function DepotBoardPanel(props: DepotBoardPanelProps): React.ReactNode
	local view = props.view
	local layout: UIPaperConstants.Layout = props.layout
	local geometry = GEOMETRY[layout]
	local phone = layout == "phone"
	local last = view.last

	-- Everything pinned on the board; the CorkBoard (wood frame and cork) sits under it, inside the scaled outer Frame.
	local cards: { [string]: React.ReactNode } = {
		workOrder = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = Z_SHEET,
		}, { sheet = workOrderOf(view, layout) }),
		last = if last ~= nil
			then e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = Z_SHEET,
			}, { sheet = lastShiftOf(last, layout) })
			else nil,
		dispatch = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = Z_SHEET,
		}, { sheet = dispatchOf(view, layout) }),
		close = e(PaperButton, {
			text = view.close,
			variant = "secondary",
			onActivated = props.onClose,
			position = at(geometry.close.pos),
			size = UDim2.fromOffset(geometry.close.size.X, geometry.close.size.Y),
			textSize = geometry.close.text,
		}),
	}
	if not phone then
		cards.title = label(view.title, "heading", 30, COLOR.cream, 40, 24)
		cards.over = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = Z_OVER,
		}, {
			approved = e(PaperStamp, {
				text = view.approved,
				size = 44,
				tilt = 7,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromOffset(761, 806),
			}),
			sticky = e(StickyNote, {
				text = view.sticky,
				width = 340,
				size = 24,
				tilt = -2,
				position = UDim2.fromOffset(70, 770),
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
	}, {
		board = e("Frame", {
			AnchorPoint = if phone then Vector2.new(0.5, 1) else Vector2.new(0.5, 0.5),
			Position = if phone
				then UDim2.new(0.5, 0, 1, -UIPaperConstants.SAFE.phone.bottom)
				else UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(geometry.board.X, geometry.board.Y),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			border = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = geometry.border,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scale = e("UIScale", { Scale = props.scale }),
			board = e(CorkBoard, { size = UDim2.fromScale(1, 1), frame = 12, children = cards }),
		}),
	})
end

return DepotBoardPanel
