--!strict
--[=[
	ShiftClearancePanel: the clearance folder and the finder's fee plate (Figma 1a-1c, top left). The folder is a manila
	sheet with a "CLEARANCE CONTRACT" tab: the cleared number, "/ 350 cleared", MET in green ink once the quota is met
	and the green clearance bar. Under it the fee plate is a dark strip, not paper (Figma's dark plate = a live number):
	"FINDER'S FEE", the fee and, in overtime, the "×1.5 now" boost. On phone (Figma 1d/1e "Clearance (compact)" and
	"Finder's fee (compact)", 236 wide at (48, 66) / (48, 130)) the folder loses its tab: "CLEARANCE", "212 / 350" and a
	14 px bar, and the plate is 34 px tall. Presentational.

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
local PHONE_TEXT = UIPaperConstants.TEXT.phone
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

-- Figma 1d: "Clearance (compact)" (48, 66) 236x58, "Finder's fee (compact)" (48, 130) 236x34.
local PHONE_LEFT = 48
local PHONE_WIDTH = 236
local PHONE_FOLDER_TOP = 66
local PHONE_FEE_TOP = 130
local PHONE_INSET = 12
-- Figma's fee title is a light monitor blue (#9CC7FF), the palette's monitor lifted towards white.
local PHONE_FEE_TITLE = COLOR.monitor:Lerp(COLOR.fluorescent, 0.5)

local function phoneFolder(view: ShiftHudViewModel.HudView): React.ReactNode
	local inner = PHONE_WIDTH - 2 * PHONE_INSET
	local children: { [string]: React.ReactNode } = {
		title = e(PaperLabel, {
			text = "CLEARANCE",
			role = "heading",
			size = PHONE_TEXT.label,
			position = UDim2.fromOffset(PHONE_INSET, 4),
			frame = UDim2.fromOffset(100, 21),
			autoSize = false,
			wrapped = false,
		}),
		count = e(PaperLabel, {
			text = view.clearedShort,
			role = "number",
			size = PHONE_TEXT.value,
			align = "right",
			position = UDim2.fromOffset(PHONE_INSET + inner - 110, 2),
			frame = UDim2.fromOffset(110, 27),
			autoSize = false,
			wrapped = false,
		}),
		track = e("Frame", {
			Position = UDim2.fromOffset(PHONE_INSET, 34),
			Size = UDim2.fromOffset(inner, 14),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			fill = e("Frame", {
				Size = UDim2.fromScale(view.fill, 1),
				BackgroundColor3 = COLOR.exitGreen,
				BorderSizePixel = 0,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 3) }) }),
		}),
	}
	return e(PaperSheet, {
		position = UDim2.fromOffset(PHONE_LEFT, PHONE_FOLDER_TOP),
		size = UDim2.fromOffset(PHONE_WIDTH, 58),
		padding = 0,
		children = children,
	})
end

local function phoneFee(view: ShiftHudViewModel.HudView): React.ReactNode
	local feeBoost = view.feeBoost
	return e("Frame", {
		Position = UDim2.fromOffset(PHONE_LEFT, PHONE_FEE_TOP),
		Size = UDim2.fromOffset(PHONE_WIDTH, 34),
		BackgroundColor3 = COLOR.monitorDeep,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		title = e(PaperLabel, {
			text = "FINDER'S FEE",
			role = "body",
			size = PHONE_TEXT.label,
			color = PHONE_FEE_TITLE,
			position = UDim2.fromOffset(PHONE_INSET, 0),
			frame = UDim2.new(0, 110, 1, 0),
			autoSize = false,
			wrapped = false,
		}),
		values = e("Frame", {
			Position = UDim2.fromOffset(PHONE_INSET, 0),
			Size = UDim2.new(1, -2 * PHONE_INSET, 1, 0),
			BackgroundTransparency = 1,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			fee = e(PaperLabel, {
				text = view.fee,
				role = "number",
				size = PHONE_TEXT.value,
				color = COLOR.fluorescent,
				fit = true,
				layoutOrder = 1,
			}),
			boost = if feeBoost ~= nil
				then e(PaperLabel, {
					text = feeBoost,
					role = "number",
					size = PHONE_TEXT.value,
					color = COLOR.fluorGlow,
					fit = true,
					layoutOrder = 2,
				})
				else nil,
		}),
	})
end

local function ShiftClearancePanel(props: ShiftClearancePanelProps): React.ReactNode
	if props.layout == "phone" then
		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			folder = phoneFolder(props.view),
			fee = phoneFee(props.view),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		folder = folder(props.view),
		fee = feePlate(props.view),
	})
end

return ShiftClearancePanel
