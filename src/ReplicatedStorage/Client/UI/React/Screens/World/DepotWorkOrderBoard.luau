--!strict
--[=[
	DepotWorkOrderBoard: the contract board (Figma World UI 2a, W2) at its 600x420 design size: a cork board in a 20 px
	wood frame (CorkBoard) with tonight's work order pinned on it, a 310x360 cream sheet at (150, 34) tilted 1.5° under
	a red "WORK ORDER #0471" band: TONIGHT'S JOB, the client, the job line, a rule, the red CLEAR n, its deadline, and
	the E key chip with "Read the work order" (always shown: prompt range is not tracked at the depot). Presentational;
	the words are DepotWorldViewModel.workOrder.

	@class DepotWorkOrderBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CorkBoard = require(ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotWorkOrderBoardProps = {
	view: DepotWorldViewModel.WorkOrderView,
}

local COLOR = UIPaperConstants.COLOR

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	y: number,
	height: number,
	scaled: boolean?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = UDim2.fromOffset(0, y),
		frame = UDim2.new(1, 0, 0, height),
		autoSize = false,
		scaled = scaled,
	})
end

local function DepotWorkOrderBoard(props: DepotWorkOrderBoardProps): React.ReactNode
	local view = props.view
	local sheet: { [string]: React.ReactNode } = {
		kicker = label(view.kicker, "body", 16, COLOR.ink, 0, 22),
		client = label(view.client, "heading", 40, COLOR.ink, 22, 50, true),
		job = label(view.job, "body", 18, COLOR.ink, 74, 46),
		rule = e("Frame", {
			Position = UDim2.fromOffset(0, 124),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		}),
		clear = label(view.clear, "heading", 40, COLOR.stamp, 134, 46, true),
		before = label(view.before, "body", 18, COLOR.ink, 180, 24, true),
		prompt = e("Frame", {
			Position = UDim2.fromOffset(0, 228),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			chip = e(KeyChip, { label = view.key, size = 24, layoutOrder = 1 }),
			action = e(PaperLabel, {
				text = view.action,
				role = "body",
				size = 20,
				color = COLOR.ink,
				fit = true,
				layoutOrder = 2,
			}),
		}),
	}
	return e(CorkBoard, { size = UDim2.fromOffset(600, 420), frame = 20 }, {
		order = e(PaperSheet, {
			position = UDim2.fromOffset(150, 34),
			size = UDim2.fromOffset(310, 360),
			paper = COLOR.cream,
			tilt = 1.5,
			band = view.number,
			fastener = "pin",
			padding = 18,
		}, sheet),
	})
end

return DepotWorkOrderBoard
