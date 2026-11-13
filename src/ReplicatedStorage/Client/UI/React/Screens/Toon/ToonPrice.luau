--!strict
--[=[
	ToonPrice: a price as the kit draws money: the currency render (Gleam crystal or Credits ticket) overlapping a gold
	number, and, only for a real sale or a bundle's items alone, the old price small and struck through just above it
	(owner, 11-13: Marvel Rivals style), lined up with the row. A row with no plate of its own: it sits
	on a card's footer or inside a buy button. Presentational (exempt; story in ToonShopKit.story).

	@class ToonPrice
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type Currency = "gleam" | "credits" | "gloom"

export type ToonPriceProps = {
	currency: Currency,
	-- Already grouped ("1,500").
	amount: string,
	-- A real higher price (grouped): before a sale, or a bundle's items alone. Struck through, above the price (on a
	-- card), or beside it (`inline`, inside a button, where there is no room above).
	was: string?,
	inline: boolean?,
	textSize: number,
	-- "gold" (default) on dark or coloured plates, "white" inside a coloured button.
	meaning: UIToonConstants.Meaning?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- Where the row sits in its box (default right).
	align: ("left" | "center" | "right")?,
	zIndex: number?,
}

local function ToonPrice(props: ToonPriceProps): React.ReactNode
	local size = props.textSize
	local icon = math.floor(size * 1.5)
	local nodes: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if props.align == "left"
				then Enum.HorizontalAlignment.Left
				elseif props.align == "center" then Enum.HorizontalAlignment.Center
				else Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, math.floor(size * 0.15)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		icon = e(ToonIcon, {
			icon = props.currency,
			size = UDim2.fromOffset(icon, icon),
			drop = 3,
			layoutOrder = 1,
			zIndex = props.zIndex,
		}),
		amount = e(ToonText, {
			text = props.amount,
			textSize = size,
			meaning = props.meaning or "gold",
			size = UDim2.fromOffset(0, size + 6),
			automaticWidth = true,
			layoutOrder = 2,
			zIndex = props.zIndex,
		}),
	}
	local outer: { [string]: React.ReactNode } = {}
	local was = props.was
	if was ~= nil then
		local inline = props.inline == true
		local wasSize = math.floor(size * (if inline then 0.6 else 0.8))
		local xAnchor = if props.align == "left" then 0 elseif props.align == "center" then 0.5 else 1
		local struck = e("Frame", {
			AnchorPoint = if inline then nil else Vector2.new(xAnchor, 1),
			Position = if inline then nil else UDim2.new(xAnchor, 0, 0, 2),
			Size = UDim2.fromOffset(0, wasSize + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			ZIndex = props.zIndex,
		}, {
			text = e(ToonText, {
				text = was,
				textSize = wasSize,
				meaning = "coral",
				size = UDim2.fromOffset(0, wasSize + 4),
				automaticWidth = true,
				zIndex = props.zIndex,
			}),
			strike = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(-0.05, 0.5),
				Size = UDim2.new(1.1, 0, 0, 3),
				Rotation = -8,
				BackgroundColor3 = UIToonConstants.shade("coral").lo,
				BorderSizePixel = 0,
				-- Over the old price.
				ZIndex = (props.zIndex or 1) + 1,
			}),
		})
		if inline then
			nodes.was = struck
		else
			outer.was = struck
		end
	end
	outer.row = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = props.zIndex }, nodes)
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, outer)
end

return ToonPrice
