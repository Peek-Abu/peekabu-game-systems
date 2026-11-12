--!strict
--[=[
	DepotClockSign: the sign over the hub's weekly time clock in the V1 kit at its 320x150 design size (owner 11-12, kit
	mock round 2 #2: numbers and pictures, not sentences): a grape kit plate with the clock render breaking its top-left
	corner, CLOCK IN in stroked gold display type, and a row of punch holes (one per day up to the locker key: mint with
	a tick once punched, today's open hole ringed in gold) leading to the key render, grey until it is earned.
	Presentational; the view is DepotSignViewModel.clock.

	@class DepotClockSign
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotSignViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotSignViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotClockSignProps = {
	view: DepotSignViewModel.ClockView,
}

local SIGN = Vector2.new(320, 150)
local ICON = 74
local HOLE = 40
local GAP = 10
local INK = UIToonConstants.COLOR.ink

-- One punch hole: a ringed circle, mint with an ink tick once punched, gold-ringed while it is today's to punch.
-- `slot` is a DepotSignViewModel.Slot (read off the view's list, which widens it to a string).
local function hole(slot: string, order: number): React.ReactNode
	local fill = if slot == "punched" then UIToonConstants.shade("mint").base else UIToonConstants.shade("night").lo
	local ring = if slot == "today" then UIToonConstants.shade("gold").base else INK
	-- The tick: a short and a long ink bar meeting at the bottom (drawn, so no font needs the glyph).
	local function bar(x: number, y: number, length: number, angle: number): React.ReactNode
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(length, 6),
			Rotation = angle,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	local tick: React.ReactNode = if slot == "punched"
		then e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			short = bar(HOLE * 0.36, HOLE * 0.56, HOLE * 0.32, 45),
			long = bar(HOLE * 0.56, HOLE * 0.48, HOLE * 0.52, -50),
		})
		else nil
	return e("Frame", {
		Size = UDim2.fromOffset(HOLE, HOLE),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke = e("UIStroke", {
			Color = ring,
			Thickness = if slot == "today" then 5 else 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		tick = tick,
	})
end

local function DepotClockSign(props: DepotClockSignProps): React.ReactNode
	local view = props.view
	local row: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}
	for index, slot in view.slots do
		row[`hole{index}`] = hole(slot, index)
	end
	row.equals = e(ToonText, {
		text = "=",
		meaning = "gold",
		textSize = 34,
		align = "center",
		size = UDim2.fromOffset(24, HOLE),
		layoutOrder = #view.slots + 1,
	})
	row.key = e(ToonIcon, {
		icon = "key",
		size = UDim2.fromOffset(HOLE + 18, HOLE + 18),
		greyed = not view.keyEarned,
		layoutOrder = #view.slots + 2,
	})
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = view.title,
			meaning = "gold",
			textSize = 36,
			position = UDim2.fromOffset(ICON - 6, 8),
			size = UDim2.new(1, -ICON - 4, 0, 42),
			fit = true,
		}),
		row = e("Frame", {
			Position = UDim2.fromOffset(0, 54),
			Size = UDim2.new(1, 0, 0, HOLE + 18),
			BackgroundTransparency = 1,
		}, row),
	}
	return e("Frame", { Size = UDim2.fromOffset(SIGN.X, SIGN.Y), BackgroundTransparency = 1 }, {
		plate = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			position = UDim2.fromOffset(14, 14),
			size = UDim2.fromOffset(SIGN.X - 22, SIGN.Y - 22),
			children = face,
		}),
		icon = e(ToonIcon, {
			icon = "clock",
			size = UDim2.fromOffset(ICON, ICON),
			position = UDim2.fromOffset(0, 0),
			rotation = -8,
			zIndex = 4,
		}),
	})
end

return DepotClockSign
