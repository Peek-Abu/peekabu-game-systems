--!strict
--[=[
	InventoryChatPanel: the Inventory's Chat wheel tab (the round-3 concept): on the left the player's 4 sticker slots
	(press one to choose where the next sticker goes; the chosen one has a white ring) and the six free pings; on the
	right every sticker pack, its stickers to press (an owned pack puts the pressed sticker in the chosen slot, else
	the first empty one), "In Shop" on a pack not owned yet. Everything shown is InventoryViewModel.chat.
	Presentational (exempt; values specced in InventoryViewModel).

	@class InventoryChatPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CalloutAssets = require(ReplicatedStorage.Client.Features.Callout.Data.CalloutAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

export type InventoryChatPanelProps = {
	view: VM.ChatView,
	layout: VM.Layout,
	-- Put sticker `id` in sticker slot `slot`.
	onPut: (slot: number, id: string) -> (),
	-- Open a pack's Shop page.
	onShop: (id: string) -> (),
}

type Nodes = { [string]: React.ReactNode }

local function picture(image: string, size: number, zIndex: number): React.ReactNode
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex,
	})
end

local function InventoryChatPanel(props: InventoryChatPanelProps): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local size = layout.textSize
	local chosen, setChosen = React.useState(function(): number?
		return nil
	end)
	local leftWidth = math.floor(layout.content.width * (if phone then 0.42 else 0.38))
	local rightWidth = layout.content.width - leftWidth - layout.gap
	local slotSize = math.floor(math.min((leftWidth - 30) / 2, (layout.content.height * 0.55) / 2))

	-- Left: the 4 slots in a 2 x 2 square, then the pings.
	local slots: Nodes = {
		title = e(ToonText, {
			text = "YOUR STICKERS",
			textSize = math.floor(layout.headingSize * 0.6),
			size = UDim2.new(1, 0, 0, math.floor(layout.headingSize * 0.6) + 6),
			fit = true,
		}),
	}
	local top = math.floor(layout.headingSize * 0.6) + 16
	for index, slot in props.view.slots do
		local column, rowIndex = (index - 1) % 2, math.floor((index - 1) / 2)
		local face: Nodes = {
			number = e(ToonText, {
				text = tostring(slot.slot),
				textSize = size - 4,
				position = UDim2.fromOffset(10, 6),
				size = UDim2.fromOffset(30, size),
				zIndex = 5,
			}),
			name = e(ToonText, {
				text = slot.name,
				textSize = size - 4,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -DEPTH.lip - 6),
				size = UDim2.new(1, -16, 0, size),
				align = "center",
				fit = true,
				zIndex = 5,
			}),
		}
		local image = slot.image
		if image ~= nil then
			face.picture = picture(image, math.floor(slotSize * 0.55), 4)
		end
		slots[`slot{slot.slot}`] = e(ToonButton, {
			variant = if chosen == slot.slot then "gleam" elseif slot.empty then "night" else "grape",
			selected = chosen == slot.slot,
			position = UDim2.fromOffset(column * (slotSize + 16), top + rowIndex * (slotSize + 16)),
			size = UDim2.fromOffset(slotSize, slotSize),
			content = face,
			onActivated = function()
				setChosen(if chosen == slot.slot then nil else slot.slot)
			end,
		})
	end
	local pingsTop = top + 2 * (slotSize + 16) + 8
	local pingRow: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local chip = if phone then 30 else 46
	for index, ping in CalloutRegistry.pings() do
		pingRow[ping.id] = e("ImageLabel", {
			Size = UDim2.fromOffset(chip, chip),
			BackgroundTransparency = 1,
			Image = CalloutAssets.pingImage(ping.id),
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = index,
		})
	end
	local pingFace: Nodes = {
		title = e(ToonText, {
			text = "PINGS",
			textSize = size,
			position = UDim2.fromOffset(14, 8),
			size = UDim2.fromOffset(120, size + 4),
		}),
		note = e(ToonText, {
			text = "Free, the same for everyone. Hold T in game; they mark a spot with a small sound.",
			font = "body",
			color = COLOR.white,
			textSize = size - 6,
			position = UDim2.fromOffset(14, size + 12),
			size = UDim2.new(1, -28, 0, size + 4),
			wrapped = true,
			fit = true,
		}),
		row = e("Frame", {
			Position = UDim2.fromOffset(14, size * 2 + 22),
			Size = UDim2.new(1, -28, 0, chip),
			BackgroundTransparency = 1,
		}, pingRow),
	}
	slots.pings = e(ToonSurface, {
		hue = "night",
		radius = 18,
		position = UDim2.fromOffset(0, pingsTop),
		size = UDim2.new(1, 0, 0, chip + size * 2 + 40),
		children = pingFace,
	})

	-- Right: the packs.
	local packs: Nodes = {
		list = e("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 16),
		}),
	}
	local tile = if phone then 64 else 112
	local packHeight = tile + size + 40 + DEPTH.lip + DEPTH.drop
	for index, pack in props.view.packs do
		local face: Nodes = {
			name = e(ToonText, {
				text = string.upper(pack.name),
				textSize = size,
				position = UDim2.fromOffset(16, 10),
				size = UDim2.new(0.6, 0, 0, size + 4),
				fit = true,
			}),
		}
		if pack.owned then
			face.owned = e(ToonText, {
				text = "OWNED",
				textSize = size - 6,
				meaning = "mint",
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -16, 0, 12),
				size = UDim2.fromOffset(120, size),
				align = "right",
			})
		else
			face.shop = e(ToonButton, {
				variant = "gleam",
				text = if pack.price ~= nil then `In Shop · {pack.price}` else "In Shop",
				textSize = size - 6,
				small = true,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -12, 0, 8),
				size = UDim2.fromOffset(if phone then 120 else 200, size + 12),
				onActivated = function()
					props.onShop(pack.id)
				end,
			})
		end
		for stickerIndex, sticker in pack.stickers do
			local inner: Nodes = {
				picture = picture(sticker.image, math.floor(tile * 0.62), 4),
				name = e(ToonText, {
					text = sticker.name,
					textSize = size - 8,
					anchor = Vector2.new(0.5, 1),
					position = UDim2.new(0.5, 0, 1, -DEPTH.lip - 4),
					size = UDim2.new(1, -8, 0, size - 6),
					align = "center",
					fit = true,
					zIndex = 5,
				}),
			}
			face[`sticker{stickerIndex}`] = e(ToonButton, {
				variant = if pack.owned then "secondary" else "night",
				disabled = not pack.owned,
				position = UDim2.fromOffset(16 + (stickerIndex - 1) * (tile + 14), size + 24),
				size = UDim2.fromOffset(tile, tile),
				content = inner,
				onActivated = function()
					if pack.owned then
						props.onPut(VM.stickerSlotFor(props.view.slots, chosen), sticker.id)
						setChosen(nil)
					end
				end,
			})
		end
		packs[pack.id] = e("Frame", {
			Size = UDim2.new(1, 0, 0, packHeight),
			BackgroundTransparency = 1,
			LayoutOrder = index,
		}, {
			card = e(ToonSurface, {
				hue = if pack.owned then "cream" else "lilac",
				radius = 20,
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = face,
			}),
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		left = e("Frame", {
			Size = UDim2.new(0, leftWidth, 1, 0),
			BackgroundTransparency = 1,
		}, slots),
		right = e("ScrollingFrame", {
			Position = UDim2.fromOffset(leftWidth + layout.gap, 0),
			Size = UDim2.new(0, rightWidth, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = UIToonConstants.shade("lilac").base,
		}, packs),
	})
end

return InventoryChatPanel
