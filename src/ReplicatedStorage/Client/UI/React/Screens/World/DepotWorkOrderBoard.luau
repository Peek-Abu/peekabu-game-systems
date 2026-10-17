--!strict
--[=[
	DepotWorkOrderBoard: the contract board in the V1 kit at its 600x420 design size: tonight's work order as a cream
	panel on the depth stack, inset so its silhouette breaks stay on the board, under a grape header band (the order's
	number, the clipboard render breaking its top-left corner, Gloom dripping from its foot: the job is the Gloom). On
	it: TONIGHT'S JOB, the client in stroked display type, the job line, a lilac rule, the Gloom to remove as a big
	stroked grape number, its deadline, and the E key cap with "Read the work order" (always shown: prompt range is not
	tracked at the depot). Presentational; the words are DepotWorldViewModel.workOrder.

	@class DepotWorkOrderBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotWorkOrderBoardProps = {
	view: DepotWorldViewModel.WorkOrderView,
}

local BOARD = Vector2.new(600, 420)
-- The panel, inset so the render breaking its corner and its hard drop stay inside the board's canvas.
local PANEL_AT = Vector2.new(48, 40)
local PANEL = Vector2.new(BOARD.X - 2 * PANEL_AT.X + 12, BOARD.Y - PANEL_AT.Y - 22)
local HEADER = 76
local PAD = 28
local KEY = 34

local function body(text: string, size: number, y: number, height: number): React.ReactNode
	return e(ToonText, {
		text = text,
		font = "body",
		textSize = size,
		position = UDim2.fromOffset(PAD, y),
		size = UDim2.new(1, -2 * PAD, 0, height),
		fit = true,
	})
end

local function DepotWorkOrderBoard(props: DepotWorkOrderBoardProps): React.ReactNode
	local view = props.view
	-- Clear of the drips poured from the header's foot.
	local top = HEADER + 34
	local cap: { [string]: React.ReactNode } = {
		key = e(ToonText, {
			text = view.key,
			textSize = 20,
			size = UDim2.fromScale(1, 1),
			align = "center",
			fit = true,
		}),
	}
	local face: { [string]: React.ReactNode } = {
		kicker = body(view.kicker, 16, top, 20),
		client = e(ToonText, {
			text = view.client,
			textSize = 36,
			position = UDim2.fromOffset(PAD, top + 20),
			size = UDim2.new(1, -2 * PAD, 0, 44),
			fit = true,
		}),
		job = body(view.job, 18, top + 66, 24),
		rule = e("Frame", {
			Position = UDim2.fromOffset(PAD, top + 98),
			Size = UDim2.new(1, -2 * PAD, 0, 3),
			BackgroundColor3 = UIToonConstants.shade("lilac").base,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		clear = e(ToonText, {
			text = view.clear,
			meaning = "grape",
			textSize = 36,
			position = UDim2.fromOffset(PAD, top + 108),
			size = UDim2.new(1, -2 * PAD, 0, 44),
			fit = true,
		}),
		before = body(view.before, 17, top + 152, 22),
		key = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 9,
			position = UDim2.fromOffset(PAD, top + 184),
			size = UDim2.fromOffset(KEY, KEY),
			children = cap,
		}),
		action = e(ToonText, {
			text = view.action,
			font = "body",
			textSize = 18,
			position = UDim2.fromOffset(PAD + KEY + 12, top + 184),
			size = UDim2.new(1, -2 * PAD - KEY - 12, 0, KEY - 4),
			fit = true,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		BackgroundTransparency = 1,
	}, {
		order = e(ToonPanel, {
			position = UDim2.fromOffset(PANEL_AT.X, PANEL_AT.Y),
			size = PANEL,
			header = {
				title = view.number,
				icon = "jobs",
				height = HEADER,
				titleSize = 36,
				goo = true,
				gooScale = 0.55,
			},
			children = face,
		}),
	})
end

return DepotWorkOrderBoard
