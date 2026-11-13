--!strict
--[=[
	LockerOddsSheet: modal sheet showing a Locker's real rarity chances, per-item chances, the one-sentence pity rule,
	and the duplicate refunds (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	Presentational React component over `LockerViewModel.OddsSheet` (exempt; values specced in `LockerViewModel`).

	@class LockerOddsSheet
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type LockerOddsSheetProps = {
	sheet: VM.OddsSheet,
	phone: boolean,
	textSize: number,
	onClose: () -> (),
}

local function rarityBlock(row: VM.OddsRarityRow, phone: boolean, size: number, order: number): React.ReactNode
	local names: { string } = {}
	for _, item in row.items do
		table.insert(names, `{item.name} ({item.chanceText})`)
	end
	local itemsLine = table.concat(names, "  ·  ")
	local rowHeight = if phone then 74 else 118
	local face: Nodes = {
		flag = e(ToonFlag, {
			text = string.upper(row.label),
			rarity = row.rarity,
			tilt = -3,
			textSize = if phone then 12 else 18,
			position = UDim2.fromOffset(12, 10),
			size = UDim2.fromOffset(if phone then 96 else 150, if phone then 22 else 34),
		}),
		chance = e(ToonText, {
			text = `{row.chanceText}  ({row.itemChanceText})`,
			textSize = size + 2,
			meaning = "grape",
			position = UDim2.fromOffset(if phone then 116 else 174, 10),
			size = UDim2.fromOffset(if phone then 170 else 280, size + 6),
			fit = true,
		}),
		refund = e(ToonPill, {
			text = `Duplicate: {row.refundText}`,
			hue = "night",
			textSize = math.max(12, size - 4),
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 10),
			size = UDim2.fromOffset(if phone then 160 else 250, if phone then 22 else 34),
		}),
		items = e(ToonText, {
			text = itemsLine,
			font = "body",
			color = COLOR.ink,
			textSize = math.max(12, size - 2),
			position = UDim2.fromOffset(14, if phone then 36 else 52),
			size = UDim2.new(1, -28, 0, rowHeight - (if phone then 44 else 62)),
			wrapped = true,
			fit = true,
		}),
	}
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, rowHeight + DEPTH.drop),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 16,
			size = UDim2.new(1, 0, 0, rowHeight),
			children = face,
		}),
	})
end

local function LockerOddsSheet(props: LockerOddsSheetProps): React.ReactNode
	local sheet = props.sheet
	local phone = props.phone
	local size = props.textSize
	local width = if phone then 520 else 920
	local height = if phone then 320 else 580
	local pad = if phone then 16 else 28

	local list: Nodes = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, if phone then 6 else 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, row in sheet.rarities do
		list[row.rarity] = rarityBlock(row, phone, size, index)
	end

	local titleSize = if phone then 24 else 42
	local pityY = pad + titleSize + 8
	local listTop = pityY + size + (if phone then 14 else 24)
	local buttonHeight = if phone then 40 else 64

	local children: Nodes = {
		title = e(ToonText, {
			text = sheet.title,
			textSize = titleSize,
			meaning = "grape",
			position = UDim2.fromOffset(pad, pad),
			size = UDim2.new(1, -pad * 2, 0, titleSize + 4),
			fit = true,
		}),
		pity = e(ToonText, {
			text = sheet.pityRule,
			font = "body",
			color = COLOR.ink,
			textSize = size,
			position = UDim2.fromOffset(pad, pityY),
			size = UDim2.new(1, -pad * 2, 0, size + 8),
			fit = true,
		}),
		rows = e("ScrollingFrame", {
			Position = UDim2.fromOffset(pad, listTop),
			Size = UDim2.new(1, -pad * 2, 1, -listTop - buttonHeight - pad - 12),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
		}, list),
		close = e(ToonButton, {
			variant = "primary",
			text = "Got it!",
			textSize = size + 4,
			small = phone,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -pad),
			size = UDim2.fromOffset(if phone then 160 else 260, buttonHeight),
			onActivated = props.onClose,
		}),
	}

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = 0.4,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
		[React.Event.Activated] = props.onClose,
	}, {
		panel = e(ToonSurface, {
			hue = "cream",
			pattern = "rings",
			radius = 28,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromOffset(width, height),
			zIndex = 21,
			children = children,
		}),
	})
end

return LockerOddsSheet
