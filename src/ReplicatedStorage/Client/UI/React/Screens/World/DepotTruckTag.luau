--!strict
--[=[
	DepotTruckTag: the truck pad tag in the V1 kit at its 340x310 design size: a 60 px ink wire down to a cream panel on
	the depth stack with a grape header band ("TRUCK n" in stroked white, the truck render breaking its top-left
	corner), a seat per place (a round mint seat once taken, an empty night one otherwise), "n / 4 ABOARD" and line 3 (how to
	join, or a coral "Leaving in m:ss" pill when `warn`). Presentational; the words and the warn rule are
	DepotWorldViewModel.truckTag.

	@class DepotTruckTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotTruckTagProps = {
	view: DepotWorldViewModel.TruckTagView,
}

local WIRE = 60
-- The panel inside the 340x250 tag area, its hard drop included.
local TAG = Vector2.new(332, 240)
local HEADER = 72
local SEAT = 38
local SEAT_GAP = 14

local function seatsOf(seats: { boolean }): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, SEAT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, filled in seats do
		children[`seat{index}`] = e(ToonSurface, {
			hue = if filled then "mint" else "night",
			small = true,
			radius = 999,
			gloss = filled,
			layoutOrder = index,
			size = UDim2.fromOffset(SEAT, SEAT),
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(0, HEADER + 14),
		Size = UDim2.new(1, 0, 0, SEAT + 6),
		BackgroundTransparency = 1,
	}, children)
end

local function DepotTruckTag(props: DepotTruckTagProps): React.ReactNode
	local view = props.view
	local face: { [string]: React.ReactNode } = {
		seats = seatsOf(view.seats),
		count = e(ToonText, {
			text = view.count,
			textSize = 26,
			position = UDim2.fromOffset(16, HEADER + 62),
			size = UDim2.new(1, -32, 0, 34),
			align = "center",
			fit = true,
		}),
	}
	if view.warn then
		face.line = e(ToonPill, {
			text = view.line,
			hue = "coral",
			textSize = 20,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, HEADER + 102),
			size = UDim2.fromOffset(TAG.X - 64, 36),
		})
	else
		face.line = e(ToonText, {
			text = view.line,
			font = "body",
			textSize = 20,
			position = UDim2.fromOffset(16, HEADER + 104),
			size = UDim2.new(1, -32, 0, 28),
			align = "center",
			fit = true,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(340, WIRE + 250),
		BackgroundTransparency = 1,
	}, {
		wire = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(5, WIRE + 8),
			BackgroundColor3 = UIToonConstants.COLOR.ink,
			BorderSizePixel = 0,
		}),
		tag = e(ToonPanel, {
			position = UDim2.fromOffset((340 - TAG.X) / 2, WIRE),
			size = TAG,
			header = {
				title = view.title,
				icon = "truck",
				height = HEADER,
				titleSize = 44,
			},
			children = face,
		}),
	})
end

return DepotTruckTag
