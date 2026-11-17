--!strict
--[=[
	ShopOfferCard: one offer's card in the Shop's lists (Featured picks, Skins, Hire, the event tab): a rarity-coloured
	card with an inset stage holding the item (`art`: in 3D, or the sticker sheet for a sticker pack), its name, line
	and price, an OWNED stamp, a "-xx%" burst and a rarity flag; pressing it opens the item's page. Values:
	ShopViewModel.card. Split out of ShopScreen. Presentational (exempt).

	@class ShopOfferCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBurst = require(Toon.ToonBurst)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPrice = require(Toon.ToonPrice)
local ToonPressable = require(Toon.ToonPressable)
local ToonStamp = require(Toon.ToonStamp)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = ShopScreenBlocks.Nodes

-- The item on a card: in 3D (a skin, an employee, an emote or idle on its employee), or the sticker sheet for a sticker pack.
local function art(card: VM.OfferCard, live: boolean?): React.ReactNode
	if card.kind == "stickerPack" or card.kind == "sticker" then
		return e(ToonIcon, {
			icon = "stickers",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromScale(0.7, 0.7),
			drop = 4,
		})
	end
	local vacuum = card.vacuum
	return e(ToonViewport, {
		-- A vacuum's card shows the vacuum on its own.
		employee = if vacuum ~= nil then nil else card.employee,
		vacuum = if vacuum ~= nil then CosmeticRegistry.keyOf(vacuum) else nil,
		skin = card.skinKey,
		-- An idle's card plays it (live) on its employee in the Classic skin.
		idle = card.idle,
		framing = "full",
		live = live,
		size = UDim2.fromScale(1, 1),
	})
end

local function offerCard(
	card: VM.OfferCard,
	size: Vector2,
	phone: boolean,
	order: number,
	onOpen: (id: string) -> ()
): React.ReactNode
	local shade = UIToonConstants.rarity(card.rarity)
	local nameSize = if phone then 13 else 24
	local footer = math.floor(nameSize * 2.6)
	local stage: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(shade.hi, shade.base) }),
		art = art(card),
	}
	local face: Nodes = {
		stage = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -footer - 8 - DEPTH.lip),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, stage),
		name = e(ToonText, {
			text = card.name,
			textSize = nameSize,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 12, 1, -DEPTH.lip - math.floor(nameSize * 1.15)),
			size = UDim2.new(0.62, -12, 0, nameSize + 4),
			fit = true,
			zIndex = 3,
		}),
		line = e(ToonText, {
			text = card.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 11 else 17, nameSize - 8),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 12, 1, -DEPTH.lip - 4),
			size = UDim2.new(0.62, -12, 0, nameSize),
			fit = true,
			zIndex = 3,
		}),
		price = if card.state == "owned"
			then nil
			else e(ToonPrice, {
				currency = card.currency,
				amount = card.price,
				was = card.was,
				textSize = nameSize + 2,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -10, 1, -DEPTH.lip - 6),
				size = UDim2.new(0.4, 0, 0, nameSize + 12),
				zIndex = 3,
			}),
	}
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = { base = shade.lo:Lerp(shade.base, 0.4), hi = shade.base, lo = shade.lo },
			radius = 20,
			small = phone,
			gloss = false,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	}
	if card.state == "owned" then
		local stamp = math.floor(math.min(size.X, size.Y) * 0.5)
		nodes.owned = e(ToonStamp, {
			text = "OWNED",
			size = stamp,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.42),
			zIndex = 6,
		})
	end
	if card.off ~= nil and card.state ~= "owned" then
		nodes.off = e(ToonBurst, {
			text = card.off,
			hue = "coral",
			size = if phone then 40 else 68,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 10, 0, -12),
			zIndex = 7,
		})
	end
	if card.rarity ~= "default" then
		nodes.rarity = e(ToonFlag, {
			text = string.upper(card.rarity),
			rarity = card.rarity,
			tilt = -5,
			textSize = if phone then 10 else 15,
			position = UDim2.fromOffset(-6, -8),
			size = UDim2.fromOffset(if phone then 72 else 130, if phone then 20 else 30),
			zIndex = 7,
		})
	end
	return e(ToonPressable, {
		size = UDim2.fromOffset(size.X, size.Y),
		layoutOrder = order,
		deal = order,
		onActivated = function()
			onOpen(card.id)
		end,
		children = nodes,
	})
end

return {
	art = art,
	card = offerCard,
}
