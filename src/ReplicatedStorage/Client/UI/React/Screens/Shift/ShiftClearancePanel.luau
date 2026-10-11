--!strict
--[=[
	ShiftClearancePanel: the clearance folder and the finder's fee plate (Figma 1a-1c, top left). The folder is a manila
	sheet with a "CLEARANCE CONTRACT" tab: the cleared number, "/ 350 cleared", MET in green ink once the quota is met
	and the green clearance bar. Under it the fee plate is a dark strip, not paper (Figma's dark plate = a live number):
	"FINDER'S FEE", the fee and, in overtime, the "×1.5 now" boost. Presentational (desktop; phone is Task 10).

	@class ShiftClearancePanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

export type ShiftClearancePanelProps = {
	view: ShiftHudViewModel.HudView,
	layout: UIPaperConstants.Layout,
}

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop
-- Figma 1a: "Clearance body" (48, 120) 470x118 under its tab, "Finder's fee" (48, 250) 470x58.
local LEFT = 48
local WIDTH = 470
local FOLDER_TOP = 120
local FEE_TOP = 250

local function folder(view: ShiftHudViewModel.HudView): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		-- "362 / 350 cleared": the number and the quota sit on one baseline, the quota after the number.
		count = e("Frame", {
			Position = UDim2.fromOffset(20, 6),
			Size = UDim2.fromOffset(360, 62),
			BackgroundTransparency = 1,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 18),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			cleared = e(PaperLabel, {
				text = view.cleared,
				role = "number",
				size = TEXT.big,
				fit = true,
				layoutOrder = 1,
			}),
			quota = e(PaperLabel, {
				text = view.quotaText,
				role = "body",
				size = TEXT.body,
				fit = true,
				layoutOrder = 2,
			}),
		}),
		met = if view.quotaMet
			then e(PaperLabel, {
				text = "MET",
				role = "heading",
				size = TEXT.body,
				color = COLOR.inkGreen,
				align = "right",
				position = UDim2.fromOffset(WIDTH - 20 - 80, 22),
				frame = UDim2.fromOffset(80, 33),
				autoSize = false,
			})
			else nil,
		track = e("Frame", {
			Position = UDim2.fromOffset(20, 72),
			Size = UDim2.fromOffset(WIDTH - 40, 26),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, {
			fill = e("Frame", {
				Size = UDim2.fromScale(view.fill, 1),
				BackgroundColor3 = COLOR.exitGreen,
				BorderSizePixel = 0,
			}),
		}),
	}
	return e(PaperSheet, {
		position = UDim2.fromOffset(LEFT, FOLDER_TOP),
		size = UDim2.fromOffset(WIDTH, 118),
		tab = "CLEARANCE CONTRACT",
		padding = 0,
		children = children,
	})
end

local function feePlate(view: ShiftHudViewModel.HudView): React.ReactNode
	local feeBoost = view.feeBoost
	return e("Frame", {
		Position = UDim2.fromOffset(LEFT, FEE_TOP),
		Size = UDim2.fromOffset(WIDTH, 58),
		BackgroundColor3 = COLOR.monitorDeep,
		BorderSizePixel = 0,
	}, {
		title = e(PaperLabel, {
			text = "FINDER'S FEE",
			role = "body",
			size = TEXT.label,
			color = COLOR.monitor,
			position = UDim2.fromOffset(20, 0),
			frame = UDim2.new(0, 200, 1, 0),
			autoSize = false,
			wrapped = false,
		}),
		values = e("Frame", {
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -40, 1, 0),
			BackgroundTransparency = 1,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 20),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			fee = e(PaperLabel, {
				text = view.fee,
				role = "number",
				size = TEXT.value,
				color = COLOR.cream,
				fit = true,
				layoutOrder = 1,
			}),
			boost = if feeBoost ~= nil
				then e(PaperLabel, {
					text = feeBoost,
					role = "number",
					size = TEXT.value,
					color = COLOR.fluorGlow,
					fit = true,
					layoutOrder = 2,
				})
				else nil,
		}),
	})
end

local function ShiftClearancePanel(props: ShiftClearancePanelProps): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		folder = folder(props.view),
		fee = feePlate(props.view),
	})
end

return ShiftClearancePanel
