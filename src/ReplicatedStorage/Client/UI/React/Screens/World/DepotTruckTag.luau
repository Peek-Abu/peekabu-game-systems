--!strict
--[=[
	DepotTruckTag: the truck pad tag (Figma World UI 2a, W1) at its 340x310 design size: a 60 px wire down to a 340x250
	manila luggage tag (PaperTag, hole at the top), "TRUCK n" (Oswald 64), a punched seat per place (Ø32, 14 apart;
	filled = aboard), "n / 4 ABOARD" (Oswald 26) and line 3 (Special Elite 20, stamp red when `warn`). Presentational;
	the words and the warn rule are DepotWorldViewModel.truckTag.

	@class DepotTruckTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTag = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotTruckTagProps = {
	view: DepotWorldViewModel.TruckTagView,
}

local COLOR = UIPaperConstants.COLOR
local WIRE = 60
local TAG = Vector2.new(340, 250)
local SEAT = 32
local SEAT_GAP = 14

-- One centred line on the tag body, shrunk into its frame when long.
local function line(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	y: number,
	height: number
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		align = "center",
		position = UDim2.fromOffset(16, y),
		frame = UDim2.new(1, -32, 0, height),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
end

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
		children[`seat{index}`] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(SEAT, SEAT),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			ring = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, SEAT),
		BackgroundTransparency = 1,
	}, children)
end

local function DepotTruckTag(props: DepotTruckTagProps): React.ReactNode
	local view = props.view
	local body: { [string]: React.ReactNode } = {
		title = line(view.title, "heading", 64, COLOR.ink, 48, 76),
		seats = seatsOf(view.seats),
		count = line(view.count, "heading", 26, COLOR.ink, 176, 32),
		line = line(view.line, "body", 20, if view.warn then COLOR.stamp else COLOR.ink, 210, 28),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(TAG.X, WIRE + TAG.Y),
		BackgroundTransparency = 1,
	}, {
		wire = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(3, WIRE),
			BackgroundColor3 = COLOR.slotEmpty,
			BorderSizePixel = 0,
		}),
		tag = e("Frame", {
			Position = UDim2.fromOffset(0, WIRE),
			Size = UDim2.fromOffset(TAG.X, TAG.Y),
			BackgroundTransparency = 1,
		}, {
			paper = e(PaperTag, { size = TAG, paper = COLOR.manila, hole = "top" }, body),
		}),
	})
end

return DepotTruckTag
