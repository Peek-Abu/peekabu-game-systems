--!strict
--[=[
	ShopProductRows: the small pieces of a product page in the Shop (ShopProductPanel): a wrapped line of body text, a
	row for one item inside (its thumbnail, kind, name and own price "alone 400") and a colour style chip's face (its
	two colours as dots, then its name). Presentational (exempt; story in ShopScreen.story). Split out of
	ShopProductPanel.

	@class ShopProductRows
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

local ShopProductRows = {}

function ShopProductRows.text(
	value: string,
	size: number,
	x: number,
	y: number,
	width: number,
	color: Color3?
): React.ReactNode
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

function ShopProductRows.insideRow(
	entry: VM.Inside,
	card: VM.OfferCard,
	size: number,
	height: number,
	order: number
): React.ReactNode
	local art: React.ReactNode = if entry.kind == "Sticker pack"
		then e(
			ToonIcon,
			{ icon = "stickers", position = UDim2.fromScale(0.08, 0.08), size = UDim2.fromScale(0.84, 0.84) }
		)
		elseif entry.kind == "Vacuum" then e(ToonViewport, {
			vacuum = string.match(entry.id, "^[^%.]+%.(.+)$"),
			framing = "full",
			size = UDim2.fromScale(1, 1),
		})
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

-- A colour style chip's face: its two colours (the fur, then the outfit) as dots, then its name.
function ShopProductRows.chipFace(chip: VM.StyleChip, size: number): Nodes
	local dot = size - 2
	local face: Nodes = {
		name = e(ToonText, {
			text = chip.name,
			textSize = size - 4,
			meaning = "grape",
			position = UDim2.fromOffset(dot * 2 + 14, 0),
			size = UDim2.new(1, -(dot * 2 + 18), 1, 0),
			fit = true,
		}),
	}
	for index, colour in chip.swatch do
		face[`dot{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6 + (index - 1) * (dot + 2), 0.5, 0),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
		}, {
			round = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			edge = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
		})
	end
	return face
end

return ShopProductRows
