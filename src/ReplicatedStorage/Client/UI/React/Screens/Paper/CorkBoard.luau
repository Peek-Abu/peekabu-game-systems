--!strict
--[=[
	CorkBoard: a pinboard (M3b world UI): a wood frame (textured) around a cork field (textured, with a dark inner
	edge). `frame` is the wood's width in px (20 by default). `children` fill the whole board, wood included, so a
	caller positions cards over the wood and the cork alike. Presentational.

	@class CorkBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type CorkBoardProps = {
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- The wood frame's width in px.
	frame: number?,
	layoutOrder: number?,
	children: { [string]: React.ReactNode }?,
}

local COLOR = UIPaperConstants.COLOR
local FRAME = 20

local function CorkBoard(props: CorkBoardProps): React.ReactNode
	local frame = props.frame or FRAME
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = COLOR.wood,
		BorderSizePixel = 0,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		woodTexture = e(PaperTexture, { paper = COLOR.wood, corner = 4 }),
		cork = e("Frame", {
			Position = UDim2.fromOffset(frame, frame),
			Size = UDim2.new(1, -2 * frame, 1, -2 * frame),
			BackgroundColor3 = COLOR.cork,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			texture = e(PaperTexture, { paper = COLOR.cork }),
			edge = e("UIStroke", {
				Color = COLOR.night,
				Thickness = 3,
				Transparency = 0.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, props.children),
	})
end

return CorkBoard
