--!strict
--[=[
	CargoPriceTag: a cargo item's price tag (Figma World UI 2b, W5) at its 260x70 design size: a cream price tag with a
	pointed left end and a string hole (PaperTag), the name (Oswald 24, shrinking to fit the plaque's long name) and the
	price (Oswald 24, stamp red once cracked) on top, and the mark (Oswald 14 in a 2 px stamp-red outline) under the name.
	The name's smallest size is 8: a text-size constraint counts px before the billboard's UIScale, so a higher floor
	would overflow the tag when the screen is small. Presentational; the words are CargoWorldViewModel.priceTag.

	@class CargoPriceTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTag = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)

local e = React.createElement

export type CargoPriceTagProps = {
	view: CargoWorldViewModel.PriceTagView,
}

local COLOR = UIPaperConstants.COLOR

local function CargoPriceTag(props: CargoPriceTagProps): React.ReactNode
	local view = props.view
	local body: { [string]: React.ReactNode } = {
		name = e(PaperLabel, {
			text = view.name,
			role = "heading",
			size = 24,
			minSize = 8,
			scaled = true,
			color = COLOR.ink,
			position = UDim2.fromOffset(12, 6),
			frame = UDim2.fromOffset(150, 30),
			autoSize = false,
		}),
		price = e(PaperLabel, {
			text = view.price,
			role = "number",
			size = 24,
			minSize = 8,
			scaled = true,
			color = if view.cracked then COLOR.stamp else COLOR.ink,
			align = "right",
			position = UDim2.new(1, -72, 0, 6),
			frame = UDim2.fromOffset(60, 30),
			autoSize = false,
			wrapped = false,
		}),
	}
	local mark = view.mark
	if mark ~= nil then
		body.mark = e("Frame", {
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			outline = e("UIStroke", {
				Color = COLOR.stamp,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			label = e(PaperLabel, { text = mark, role = "heading", size = 14, color = COLOR.stamp, fit = true }),
		})
	end
	return e(PaperTag, { size = CargoConstants.LABEL_PX, paper = COLOR.cream, hole = "left" }, body)
end

return CargoPriceTag
