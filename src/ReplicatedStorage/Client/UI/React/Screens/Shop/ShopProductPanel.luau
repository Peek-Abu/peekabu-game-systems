--!strict
--[=[
	ShopProductPanel: one offer's page in the Shop (concept: characters/ui/character-ui/frames3/product.jpg). Left, a
	cream panel: the rarity ribbon, the big name, "Bundle for Pippa · cosmetic only", the lore in a quote box, Styles
	(greyed until style art exists), a row per item inside (its kind, name and own price "alone 400"), and the big buy
	button (the price, Owned, or "Need 300 more"), with a refused buy's words under it. Right: the item LIVE on a
	raised platform in its rarity's colour. All of it is ShopViewModel.product; nothing is per item. Presentational
	(exempt; story in ShopScreen.story).

	@class ShopProductPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type ShopProductPanelProps = {
	product: VM.Product,
	layout: InventoryViewModel.Layout,
	-- A refused buy's words (nil when there is nothing to say).
	note: string?,
	onBuy: () -> (),
	-- Short on Gleam: open the Gleam tab.
	onGetMore: () -> (),
}

local function text(value: string, size: number, x: number, y: number, width: number, color: Color3?): React.ReactNode
	return e(ToonText, {
		text = value,
		font = "body",
		color = color or COLOR.ink,
		textSize = size,
		position = UDim2.fromOffset(x, y),
		size = UDim2.fromOffset(width, size * 3),
		wrapped = true,
		alignY = "top",
	})
end

local function insideRow(
	entry: VM.Inside,
	card: VM.OfferCard,
	size: number,
	height: number,
	order: number
): React.ReactNode
	local art: React.ReactNode = if entry.kind == "Sticker pack"
		then e(
			ToonIcon,
			{ icon = "shopGift", position = UDim2.fromScale(0.08, 0.08), size = UDim2.fromScale(0.84, 0.84) }
		)
		else e(ToonViewport, {
			employee = card.employee,
			skin = if entry.kind == "Skin" then card.skinKey else nil,
			framing = if entry.kind == "Skin" then "full" else "bust",
			size = UDim2.fromScale(1, 1),
		})
	local thumb: Nodes = { art = art }
	local face: Nodes = {
		thumb = e(ToonSurface, {
			hue = "gold",
			small = true,
			radius = 12,
			position = UDim2.fromOffset(8, 6),
			size = UDim2.fromOffset(height - 16, height - 16),
			children = thumb,
		}),
		kind = e(ToonText, {
			text = string.upper(entry.kind),
			textSize = size,
			meaning = "grape",
			position = UDim2.fromOffset(height + 4, 6),
			size = UDim2.new(1, -height - 160, 0, size + 4),
			fit = true,
		}),
		name = e(ToonText, {
			text = entry.name,
			font = "body",
			color = COLOR.ink,
			textSize = size - 4,
			position = UDim2.fromOffset(height + 4, size + 10),
			size = UDim2.new(1, -height - 160, 0, size),
			fit = true,
		}),
	}
	if entry.alone ~= nil then
		face.alone = e(ToonText, {
			text = entry.alone,
			font = "body",
			color = UIToonConstants.shade("steel").lo,
			textSize = size - 6,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -16, 0.5, -4),
			size = UDim2.fromOffset(140, size),
			align = "right",
			fit = true,
		})
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, height + DEPTH.drop),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		row = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 16,
			size = UDim2.new(1, 0, 0, height),
			children = face,
		}),
	})
end

local function ShopProductPanel(props: ShopProductPanelProps): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local product = props.product
	local card = product.card
	local size = layout.textSize
	local width = math.floor(layout.content.width * (if phone then 0.52 else 0.4))
	local inner = width - 2 * (if phone then 12 else 26)
	local pad = if phone then 12 else 26
	local nameSize = math.floor(layout.headingSize * (if phone then 0.9 else 1.25))

	local face: Nodes = {
		rarity = e(ToonFlag, {
			text = product.rarityText,
			rarity = card.rarity,
			tilt = -3,
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(pad, pad),
			size = UDim2.fromOffset(if phone then 110 else 180, if phone then 26 else 40),
		}),
		name = e(ToonText, {
			text = string.upper(card.name),
			textSize = nameSize,
			position = UDim2.fromOffset(pad, pad + (if phone then 30 else 50)),
			size = UDim2.fromOffset(inner, nameSize + 6),
			fit = true,
		}),
	}
	local y = pad + (if phone then 30 else 50) + nameSize + 8
	face.line = text(product.line, size, pad, y, inner, UIToonConstants.shade("grape").lo)
	y += size + 10
	local quoteHeight = size * 3 + (if phone then 12 else 30)
	local quote: Nodes = {
		mark = e(ToonText, {
			text = "\u{201C}",
			textSize = size * 3,
			meaning = "grape",
			position = UDim2.fromOffset(6, -math.floor(size * 0.6)),
			size = UDim2.fromOffset(size * 2, size * 3),
		}),
		lore = text(product.lore, size, size * 2 + 8, 10, inner - size * 2 - 24),
	}
	face.quote = e(ToonSurface, {
		hue = "cream",
		small = true,
		radius = 16,
		position = UDim2.fromOffset(pad, y),
		size = UDim2.fromOffset(inner, quoteHeight),
		children = quote,
	})
	y += quoteHeight + DEPTH.drop + 10
	if product.styles.visible then
		face.styles = e(ToonText, {
			text = `STYLES  ·  all {product.styles.count} come with it (art coming soon)`,
			textSize = size - 4,
			meaning = "grape",
			position = UDim2.fromOffset(pad, y),
			size = UDim2.fromOffset(inner, size),
			fit = true,
		})
		y += size + 10
	end
	local rowHeight = if phone then 40 else 84
	local rows: Nodes = {
		list = e(
			"UIListLayout",
			{ Padding = UDim.new(0, if phone then 4 else 8), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	}
	for index, entry in product.inside do
		rows[entry.id] = insideRow(entry, card, if phone then 13 else 24, rowHeight, index)
	end
	local buttonHeight = if phone then 46 else 96
	face.inside = e("ScrollingFrame", {
		Position = UDim2.fromOffset(pad, y),
		Size = UDim2.new(0, inner, 1, -y - buttonHeight - (if phone then 34 else 70)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, rows)

	local button = product.button
	local content: Nodes? = nil
	if button.kind == "buy" then
		local priced: Nodes = {
			price = e(ToonPrice, {
				currency = button.currency,
				amount = button.price,
				textSize = math.floor(buttonHeight * 0.5),
				meaning = "white",
				align = "center",
				size = UDim2.new(1, 0, 1, -DEPTH.lip),
			}),
		}
		content = priced
	end
	face.buy = e(ToonButton, {
		variant = if button.kind == "buy" then "primary" elseif button.kind == "short" then "gleam" else "secondary",
		text = if content == nil then button.text else nil,
		content = content,
		textSize = if phone then 18 else 34,
		disabled = not button.enabled,
		sound = if button.kind == "buy" then "cta" else nil,
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, pad, 1, -(if phone then 22 else 48)),
		size = UDim2.fromOffset(inner, buttonHeight),
		onActivated = function()
			if button.kind == "buy" then
				props.onBuy()
			elseif button.kind == "short" then
				props.onGetMore()
			end
		end,
	})
	if props.note ~= nil then
		face.note = e(ToonText, {
			text = props.note,
			font = "body",
			color = UIToonConstants.shade("coral").lo,
			textSize = size - 2,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -6),
			size = UDim2.fromOffset(inner, size + 4),
			align = "center",
			fit = true,
		})
	end

	local shade = UIToonConstants.rarity(card.rarity)
	local function disc(position: UDim2, a: Color3, b: Color3, zIndex: number): React.ReactNode
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(0.62, 0.1),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 5 }),
			gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		panel = e(ToonSurface, {
			hue = "cream",
			pattern = "sparkle",
			radius = 28,
			size = UDim2.new(0, width, 1, -DEPTH.drop),
			children = face,
		}),
		hero = e("Frame", {
			Position = UDim2.fromOffset(width + layout.gap, 0),
			Size = UDim2.new(1, -width - layout.gap, 1, 0),
			BackgroundTransparency = 1,
		}, {
			lip = disc(UDim2.fromScale(0.5, 0.9), shade.lo, shade.lo, 1),
			top = disc(UDim2.fromScale(0.5, 0.875), shade.hi, shade.base, 2),
			model = e(ToonViewport, {
				employee = card.employee,
				skin = card.skinKey,
				live = true,
				framing = "full",
				size = UDim2.fromScale(1, 0.92),
				zIndex = 3,
			}),
		}),
	})
end

return ShopProductPanel
