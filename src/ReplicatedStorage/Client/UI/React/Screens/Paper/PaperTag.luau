--!strict
--[=[
	PaperTag: a paper tag with a drop shadow (M3b world UI). `hole = "top"` is a luggage tag: rounded corners and a
	22 px punched hole near the top. `hole = "left"` is a price tag: a square turned 45 degrees forms the point on the
	left (side size.Y / sqrt 2, centred at x = size.Y / 2), the body starts at x = size.Y / 2, and a 12 px hole sits
	near the point. `children` fill the tag's body. Presentational.

	@class PaperTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type PaperTagProps = {
	size: Vector2,
	paper: Color3,
	hole: "top" | "left",
	children: { [string]: React.ReactNode }?,
}

local COLOR = UIPaperConstants.COLOR
local SHADOW = Vector2.new(4, 6)
local TOP_HOLE = 22
local TOP_HOLE_Y = 26
local LEFT_HOLE = 12
local LEFT_HOLE_X = 16

local function shadowOf(center: Vector2, size: Vector2, corner: number, rotation: number): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X + SHADOW.X, center.Y + SHADOW.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = rotation,
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, { corner = if corner > 0 then e("UICorner", { CornerRadius = UDim.new(0, corner) }) else nil })
end

local function holeOf(diameter: number, center: Vector2, ring: boolean): React.ReactNode
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundColor3 = COLOR.office,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		ring = if ring
			then e("UIStroke", {
				Color = COLOR.manilaDeep,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			else nil,
	})
end

local function bodyOf(
	paper: Color3,
	position: UDim2,
	size: UDim2,
	corner: number,
	children: { [string]: React.ReactNode }?
): React.ReactNode
	return e("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = paper,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		corner = if corner > 0 then e("UICorner", { CornerRadius = UDim.new(0, corner) }) else nil,
		texture = e(PaperTexture, { paper = paper, corner = corner }),
		content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, children),
	})
end

local function PaperTag(props: PaperTagProps): React.ReactNode
	local size = props.size
	local paper = props.paper
	local parts: { [string]: React.ReactNode }

	if props.hole == "top" then
		parts = {
			shadow = shadowOf(size / 2, size, 10, 0),
			body = bodyOf(paper, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 10, props.children),
			hole = holeOf(TOP_HOLE, Vector2.new(size.X / 2, TOP_HOLE_Y), true),
		}
	else
		local half = size.Y / 2
		local side = size.Y / math.sqrt(2)
		local bodyWidth = size.X - half
		parts = {
			shadowBody = shadowOf(Vector2.new(half + bodyWidth / 2, half), Vector2.new(bodyWidth, size.Y), 0, 0),
			shadowPoint = shadowOf(Vector2.new(half, half), Vector2.new(side, side), 0, 45),
			point = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(half, half),
				Size = UDim2.fromOffset(side, side),
				Rotation = 45,
				BackgroundColor3 = paper,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			body = bodyOf(paper, UDim2.fromOffset(half, 0), UDim2.new(1, -half, 1, 0), 0, props.children),
			hole = holeOf(LEFT_HOLE, Vector2.new(LEFT_HOLE_X, half), false),
		}
	end

	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, parts)
end

return PaperTag
