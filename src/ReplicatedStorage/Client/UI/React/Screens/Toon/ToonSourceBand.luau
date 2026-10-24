--!strict
--[=[
	ToonSourceBand: the footer band across the bottom of an item card that says where the item comes from, coloured by
	kind so the grid reads at a glance: gold "credits" / "gleam" (a price, with its currency icon), night "locker" (the Gloom Locker),
	mint "goal" (earned by playing), steel "missed" (an event that ended), lilac "later" (not out yet), and mint
	"wearing" on the item you have on. Owned items show no band. It fills its parent's width and squares its top
	corners, so a card with a rounded foot just lays it along the bottom. Presentational (exempt; story in
	ToonSourceBand.story; which band a card gets is specced in InventoryViewModel).

	@class ToonSourceBand
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type Kind = "credits" | "gleam" | "locker" | "goal" | "missed" | "later" | "wearing"

export type ToonSourceBandProps = {
	kind: Kind,
	text: string,
	-- The band's height (px); it spans the parent's width along its bottom.
	height: number,
	-- The parent card's corner radius, so the band's foot matches it.
	radius: number?,
	textSize: number?,
	-- A narrow card (phone): no icon, so the words keep their size.
	compact: boolean?,
	zIndex: number?,
}

local HUE: { [Kind]: UIToonConstants.Hue } = {
	credits = "gold",
	gleam = "gold",
	locker = "night",
	goal = "mint",
	missed = "steel",
	later = "lilac",
	wearing = "mint",
}

local ICON: { [Kind]: UIAssets.ToonIcon? } = {
	credits = "credits",
	gleam = "gleam",
	locker = "lockNight",
}

local function ToonSourceBand(props: ToonSourceBandProps): React.ReactNode
	local shade = UIToonConstants.shade(HUE[props.kind])
	local radius = props.radius or 0
	local textSize = props.textSize or math.floor(props.height * 0.58)
	local icon: UIAssets.ToonIcon? = if props.compact == true then nil else ICON[props.kind]
	local iconSize = math.floor(props.height * 0.9)
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, props.height),
		BackgroundColor3 = shade.base,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
		gradient = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(shade.hi:Lerp(shade.base, 0.55), shade.lo:Lerp(shade.base, 0.35)),
		}),
		-- Squares the top corners (the band meets the card's art in a straight line).
		top = e("Frame", {
			Size = UDim2.new(1, 0, 0, math.min(radius, props.height)),
			BackgroundColor3 = shade.base,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}, {
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(shade.hi:Lerp(shade.base, 0.55)),
			}),
		}),
		-- The ink seam between the art and the band.
		seam = e("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = UIToonConstants.COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = props.zIndex,
		}),
		row = e("Frame", {
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.new(1, 0, 1, -2),
			BackgroundTransparency = 1,
			ZIndex = props.zIndex,
		}, {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			icon = if icon ~= nil
				then e(ToonIcon, {
					icon = icon,
					size = UDim2.fromOffset(iconSize, iconSize),
					drop = 2,
					zIndex = props.zIndex,
					layoutOrder = 1,
				})
				else nil,
			label = e(ToonText, {
				text = props.text,
				textSize = textSize,
				-- Fills what the icon leaves and shrinks to fit (a long "Gleam Locker" on a phone card).
				size = UDim2.new(1, -(if icon ~= nil then iconSize + 4 else 0) - 12, 1, 0),
				align = "center",
				fit = true,
				zIndex = props.zIndex,
				layoutOrder = 2,
			}),
		}),
	})
end

return ToonSourceBand
