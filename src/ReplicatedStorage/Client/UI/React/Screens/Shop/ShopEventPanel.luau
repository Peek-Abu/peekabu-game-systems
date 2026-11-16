--!strict
--[=[
	ShopEventPanel: the Shop's tab for a live limited-time event (so-event; plan page mock, owner picks r1). The event's
	name over a "10 days left" pill and the player's acorns; the event's items as the Shop's own offer cards
	(`renderCard`, the ShopScreen card, so they look and open like every other item), and on the right the event's
	Locker (its name, what is in it, the acorn price, "See inside" opens it in the Lockers tab) with the Locker keys the
	event sells for acorns underneath. Built from the Toon kit only. Presentational (exempt; story in
	ShopEventPanel.story).

	@class ShopEventPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local EventVM = require(script.Parent.ShopEventViewModel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type ShopEventPanelProps = {
	header: EventVM.Header,
	cards: { VM.OfferCard },
	locker: LockerTypes.Locker?,
	keys: { EventVM.KeyOffer },
	-- A refused key buy in kid words (nil when there is nothing to say).
	note: string?,
	width: number,
	height: number,
	headingSize: number,
	textSize: number,
	gap: number,
	phone: boolean,
	renderCard: (card: VM.OfferCard, size: Vector2, order: number) -> React.ReactNode,
	onLocker: (id: LockerTypes.LockerId) -> (),
	onKey: (id: LockerTypes.LockerId) -> (),
}

local function lockerCard(props: ShopEventPanelProps, locker: LockerTypes.Locker, size: Vector2): React.ReactNode
	local phone, text = props.phone, props.textSize
	local nameSize = if phone then 20 else 36
	local face: Nodes = {
		name = e(ToonText, {
			text = locker.name,
			textSize = nameSize,
			meaning = "white",
			position = UDim2.fromOffset(16, if phone then 8 else 16),
			size = UDim2.new(1, -32, 0, nameSize + 6),
			fit = true,
		}),
		line = e(ToonText, {
			text = "Gloom skins and fall items. Doubles give acorns back.",
			font = "body",
			color = COLOR.white,
			textSize = text - 2,
			position = UDim2.fromOffset(16, (if phone then 8 else 16) + nameSize + 6),
			size = UDim2.new(1, -32, 0, (text - 2) * 2 + 6),
			wrapped = true,
			fit = true,
		}),
		price = e(ToonPrice, {
			currency = locker.currency,
			amount = ToonStyleViewModel.grouped(locker.keyPrice),
			textSize = if phone then 18 else 30,
			align = "left",
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 16, 1, -DEPTH.lip - (if phone then 12 else 22)),
			size = UDim2.fromOffset(if phone then 100 else 180, if phone then 30 else 50),
		}),
		open = e(ToonButton, {
			variant = "primary",
			text = "See inside",
			textSize = if phone then 15 else 26,
			sound = "cta",
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, -16, 1, -DEPTH.lip - (if phone then 8 else 16)),
			size = UDim2.fromOffset(if phone then 110 else 200, if phone then 36 else 60),
			onActivated = function()
				props.onLocker(locker.id)
			end,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, {
		surface = e(ToonSurface, {
			hue = "coral",
			pattern = "rings",
			radius = 22,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	})
end

local function keyRow(
	props: ShopEventPanelProps,
	offer: EventVM.KeyOffer,
	size: Vector2,
	order: number
): React.ReactNode
	local phone = props.phone
	local face: Nodes = {
		name = e(ToonText, {
			text = offer.name,
			textSize = props.textSize,
			meaning = "white",
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0, 14, 0.5, -DEPTH.lip / 2),
			size = UDim2.new(0.5, -14, 0, props.textSize + 6),
			fit = true,
		}),
		buy = e(ToonButton, {
			variant = "primary",
			text = offer.price,
			textSize = if phone then 15 else 24,
			disabled = not offer.enabled,
			sound = "cta",
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, -DEPTH.lip / 2),
			size = UDim2.fromOffset(if phone then 96 else 170, if phone then 32 else 52),
			onActivated = function()
				if offer.enabled then
					props.onKey(offer.locker)
				end
			end,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "night",
			radius = 18,
			small = true,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	})
end

local function ShopEventPanel(props: ShopEventPanelProps): React.ReactNode
	local phone, gap = props.phone, props.gap
	local headingSize = props.headingSize
	local top = headingSize + (if phone then 14 else 24)
	local rightWidth = math.floor(props.width * (if phone then 0.4 else 0.33))
	local leftWidth = props.width - rightWidth - gap - 8
	local bodyHeight = props.height - top

	-- The event's items: the Shop's own cards.
	local columns = if phone then 2 else 3
	local pad = 14
	local cellWidth = math.floor((leftWidth - (columns - 1) * gap - pad * 2) / columns)
	local cell = Vector2.new(cellWidth, math.floor(cellWidth * 1.15))
	local grid: Nodes = {
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(gap, gap + 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the rarity flags that stick out over the cards' top-left corners.
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, pad),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 12),
		}),
	}
	for index, card in props.cards do
		grid[card.id] = props.renderCard(card, cell, index)
	end

	-- The right column: the event's Locker, then its keys and a refusal note.
	local right: Nodes = {
		list = e("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local locker = props.locker
	if locker ~= nil then
		right.locker = lockerCard(props, locker, Vector2.new(rightWidth, math.floor(bodyHeight * 0.52)))
	end
	local rowHeight = if phone then 52 else 84
	for index, offer in props.keys do
		right[offer.locker] = keyRow(props, offer, Vector2.new(rightWidth, rowHeight), index + 1)
	end
	if props.note ~= nil then
		right.note = e(ToonText, {
			text = props.note,
			font = "body",
			color = COLOR.white,
			textSize = props.textSize,
			size = UDim2.fromOffset(rightWidth, props.textSize * 2 + 6),
			wrapped = true,
			fit = true,
			layoutOrder = 99,
		})
	end

	local pillHeight = if phone then 28 else 46
	return e("Frame", {
		Size = UDim2.fromOffset(props.width, props.height),
		BackgroundTransparency = 1,
	}, {
		heading = e(ToonText, {
			text = string.upper(props.header.title),
			textSize = headingSize,
			position = UDim2.fromOffset(0, 0),
			size = UDim2.fromOffset(math.floor(props.width * 0.5), headingSize + 8),
			fit = true,
		}),
		days = e(ToonPill, {
			text = props.header.days,
			hue = "night",
			textSize = props.textSize - 2,
			position = UDim2.new(0.5, gap, 0, math.floor((headingSize - pillHeight) / 2) + 4),
			size = UDim2.fromOffset(if phone then 120 else 220, pillHeight),
		}),
		acorns = e(ToonPill, {
			text = props.header.acorns,
			hue = "coral",
			meaning = "gold",
			icon = "acorns",
			textSize = props.textSize,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, math.floor((headingSize - pillHeight) / 2) + 4),
			size = UDim2.fromOffset(if phone then 110 else 200, pillHeight),
		}),
		items = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.fromOffset(leftWidth, bodyHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
		}, grid),
		right = e("Frame", {
			Position = UDim2.fromOffset(leftWidth + gap + 8, top + 16),
			Size = UDim2.fromOffset(rightWidth, bodyHeight - 16),
			BackgroundTransparency = 1,
		}, right),
	})
end

return ShopEventPanel
