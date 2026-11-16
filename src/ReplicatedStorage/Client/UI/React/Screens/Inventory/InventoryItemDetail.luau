--!strict
--[=[
	InventoryItemDetail: the right column of an Inventory character page (InventoryCharacterPanel): the selected item's
	detail (ribbons, the big name, the lore box (a quote when the employee speaks), Styles chips, the emote wheel's
	slots, "In a bundle with" tiles, and the main button: Wear / Wearing / See in Shop with its price / where else to
	get it). Values: InventoryViewModel.detail and .change. Split out of InventoryCharacterPanel. Presentational
	(exempt).

	@class InventoryItemDetail
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryPanelBlocks = require(script.Parent.InventoryPanelBlocks)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type InventoryCharacterPanelProps = InventoryPanelBlocks.InventoryCharacterPanelProps
type Nodes = InventoryPanelBlocks.Nodes

local body = InventoryPanelBlocks.body
local group = InventoryPanelBlocks.group
local stack = InventoryPanelBlocks.stack
local block = InventoryPanelBlocks.block

-- An "In a bundle with" tile: a bundle mate on a small stage, its kind and name under it.
local function bundledTile(
	props: InventoryCharacterPanelProps,
	item: VM.Bundled,
	size: number,
	order: number
): React.ReactNode
	local textSize = if props.layout.phone then 11 else 17
	local art: React.ReactNode
	if item.kind == "skin" then
		art = e(ToonViewport, {
			employee = item.employee or props.employee,
			skin = VM.skinKey(item.id),
			framing = "full",
			size = UDim2.fromScale(1, 1),
		})
	elseif item.kind == "stickerPack" or item.kind == "sticker" then
		art = e(ToonIcon, {
			icon = "stickers",
			position = UDim2.fromScale(0.07, 0.07),
			size = UDim2.fromScale(0.86, 0.86),
		})
	else
		art = e(ToonViewport, {
			employee = item.employee or props.employee,
			framing = "bust",
			size = UDim2.fromScale(1, 1),
		})
	end
	local kindWord = if item.kind == "stickerPack"
		then "Stickers"
		else string.upper(string.sub(item.kind, 1, 1)) .. string.sub(item.kind, 2)
	local stage: Nodes = { art = art }
	return e("Frame", {
		Size = UDim2.fromOffset(size, size + 2 * textSize + 12),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		stage = e(ToonSurface, {
			hue = "gold",
			small = true,
			radius = 14,
			size = UDim2.fromOffset(size, size),
			children = stage,
		}),
		kind = e(ToonText, {
			text = kindWord,
			textSize = textSize,
			meaning = "grape",
			position = UDim2.fromOffset(0, size + 6),
			size = UDim2.fromOffset(size, textSize + 4),
			align = "center",
			fit = true,
		}),
		name = e(ToonText, {
			text = item.name,
			font = "body",
			color = COLOR.ink,
			textSize = textSize - 2,
			position = UDim2.fromOffset(0, size + textSize + 10),
			size = UDim2.fromOffset(size, textSize + 2),
			align = "center",
			fit = true,
		}),
	})
end

-- A colour style chip's face: its two colours (the fur, then the outfit) as dots, then its name.
local function chipFace(chip: VM.StyleChip, size: number): { [string]: React.ReactNode }
	local dot = size - 2
	local face: { [string]: React.ReactNode } = {
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

local function InventoryItemDetail(
	props: InventoryCharacterPanelProps,
	view: VM.Detail,
	item: CosmeticTypes.Item,
	style: number,
	onStyle: (index: number) -> ()
): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local size = layout.textSize
	local inset = if phone then 12 else 26
	local nameSize = math.floor(layout.headingSize * (if phone then 0.9 else 1.15))
	local flags: Nodes = {
		rarity = e(ToonFlag, {
			text = view.rarityText,
			rarity = view.rarity,
			tilt = -3,
			textSize = if phone then 13 else 22,
			size = UDim2.fromOffset(if phone then 100 else 170, if phone then 26 else 40),
		}),
	}
	if view.new then
		flags.new = e(ToonFlag, {
			text = "New!",
			hue = "coral",
			tilt = -3,
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(if phone then 108 else 184, 0),
			size = UDim2.fromOffset(if phone then 64 else 100, if phone then 26 else 40),
		})
	end
	local rows: Nodes = {
		flags = block(if phone then 28 else 42, 1, group(flags)),
		name = block(
			nameSize + 6,
			2,
			e(ToonText, {
				text = string.upper(view.name),
				textSize = nameSize,
				size = UDim2.fromScale(1, 1),
				fit = true,
			})
		),
		line = block(
			size + 6,
			3,
			body(
				if view.comingSoon then `{view.line} · moves coming soon` else view.line,
				size,
				UIToonConstants.shade("grape").lo
			)
		),
	}
	-- The lore in a cream box: a quote mark and the employee's signature when the employee is speaking (the item's
	-- choice), else the lore book (told about them).
	local signed = view.quote and not phone
	local quote: Nodes = {
		mark = if view.quote
			then e(ToonText, {
				text = "\u{201C}",
				textSize = size * 3,
				meaning = "grape",
				position = UDim2.fromOffset(6, -math.floor(size * 0.6)),
				size = UDim2.fromOffset(size * 2, size * 3),
			})
			else e(ToonIcon, {
				icon = "guide",
				rotation = -8,
				drop = 3,
				position = UDim2.fromOffset(4, 6),
				size = UDim2.fromOffset(size * 2, size * 2),
			}),
		lore = e("Frame", {
			Position = UDim2.fromOffset(size * 2 + 8, 10),
			-- Unsigned (or on a phone), the lore gets the whole box.
			Size = UDim2.new(1, -size * 2 - 20, 1, if signed then -size - 24 else -16),
			BackgroundTransparency = 1,
		}, { text = body(view.lore, size) }),
		who = if not signed
			then nil
			else e(ToonText, {
				text = string.upper(props.employee),
				textSize = size - 6,
				meaning = "grape",
				anchor = Vector2.new(0, 1),
				position = UDim2.new(0, size * 2 + 8, 1, -DEPTH.lip - 6),
				size = UDim2.fromOffset(160, size - 2),
				fit = true,
			}),
	}
	rows.quote = block(
		size * 3 + (if phone then 12 else 30),
		4,
		e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 16,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = quote,
		})
	)
	-- A phone's detail panel has room for the name, the lore and the button only.
	if view.styles.visible and not phone then
		local styles: Nodes = {
			label = e(ToonText, {
				text = "STYLES",
				textSize = size,
				meaning = "grape",
				size = UDim2.fromOffset(size * 5, size + 6),
			}),
		}
		-- One chip per style: pressing it shows that style on the hero; Wear puts it on.
		local count = view.styles.count
		local buttonWidth = math.floor((layout.detailWidth - 2 * inset - (count - 1) * 10) / count)
		for index, chip in view.styles.chips do
			styles[`style{index}`] = e(ToonButton, {
				variant = "secondary",
				selected = index == style,
				content = chipFace(chip, size),
				position = UDim2.fromOffset((index - 1) * (buttonWidth + 10), size + 12),
				size = UDim2.fromOffset(buttonWidth, size + 22),
				onActivated = function()
					onStyle(index)
				end,
			})
		end
		rows.styles = block(size * 2 + 44, 5, group(styles))
	end
	-- An emote's wheel: the employee's 4 slots; pressing one puts the shown emote there (when it is owned).
	local wheel = view.wheel
	if wheel ~= nil then
		local owned = props.owns(item.id)
		local slotHeight = if phone then 40 else 64
		local slots: Nodes = {
			label = e(ToonText, {
				text = "YOUR WHEEL",
				textSize = size,
				meaning = "grape",
				size = UDim2.fromOffset(size * 8, size + 6),
			}),
			hint = if phone
				then nil
				else e(ToonText, {
					text = if owned then "press a slot to put it there" else "get it to put it on your wheel",
					font = "body",
					color = UIToonConstants.shade("steel").lo,
					textSize = size - 6,
					position = UDim2.fromOffset(size * 8, 4),
					size = UDim2.new(1, -size * 8, 0, size),
					fit = true,
				}),
		}
		local count = #wheel
		local gap = 10
		local width = math.floor((layout.detailWidth - 2 * inset - (count - 1) * gap) / count)
		for index, slot in wheel do
			slots[`slot{index}`] = e(ToonButton, {
				variant = if slot.mine then "gleam" elseif slot.empty then "secondary" else "grape",
				text = `{slot.slot}  {slot.name}`,
				textSize = if phone then 11 else size - 6,
				selected = slot.mine,
				disabled = not owned or slot.mine,
				position = UDim2.fromOffset((index - 1) * (width + gap), size + 12),
				size = UDim2.fromOffset(width, slotHeight),
				onActivated = function()
					if owned and not slot.mine then
						props.onWear(VM.change(item, props.employee, slot.slot))
					end
				end,
			})
		end
		rows.wheel = block(size + 12 + slotHeight + DEPTH.drop + 8, 5, group(slots))
	end
	if #view.comesWith > 0 and not phone then
		local tile = if phone then 50 else 88
		local row: Nodes = {
			list = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, bundled in view.comesWith do
			row[bundled.id] = bundledTile(props, bundled, tile, index)
		end
		rows.bundle = block(
			size + 12 + tile + size * 2 + 16,
			6,
			group({
				label = e(ToonText, {
					text = "IN A BUNDLE WITH",
					textSize = size,
					meaning = "grape",
					size = UDim2.fromOffset(size * 12, size + 6),
				}),
				row = e("Frame", {
					Position = UDim2.fromOffset(0, size + 12),
					Size = UDim2.new(1, 0, 1, -size - 12),
					BackgroundTransparency = 1,
				}, row),
			})
		)
	end

	local action = view.action
	local buttonHeight = if phone then 44 else 76
	local content: Nodes? = nil
	local price = action.price
	if price ~= nil then
		local priced: Nodes = {
			label = e(ToonText, {
				text = action.text,
				textSize = math.floor(buttonHeight * 0.4),
				position = UDim2.fromOffset(16, -2),
				size = UDim2.new(0.55, -16, 1, -DEPTH.lip),
				fit = true,
			}),
			price = e(ToonPrice, {
				currency = price.currency,
				amount = price.amount,
				textSize = math.floor(buttonHeight * 0.42),
				meaning = "white",
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, -16, 0, -2),
				size = UDim2.new(0.45, 0, 1, -DEPTH.lip),
			}),
		}
		content = priced
	end
	local panel: Nodes = {
		rows = stack(rows, if phone then 6 else 12, inset),
		action = e(ToonButton, {
			variant = action.variant,
			text = if content == nil then action.text else nil,
			content = content,
			textSize = if phone then 18 else 30,
			disabled = not action.enabled,
			sound = if action.kind == "wear" then "cta" else nil,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -(if phone then 14 else 26)),
			size = UDim2.new(1, -2 * inset, 0, buttonHeight),
			onActivated = function()
				if action.kind == "wear" then
					props.onWear(VM.change(item, props.employee, view.wheelSlot, style))
				elseif action.kind == "shop" then
					props.onShop(item.id)
				end
			end,
		}),
	}
	return e(ToonSurface, {
		hue = "cream",
		pattern = "rings",
		radius = 28,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = panel,
	})
end

return InventoryItemDetail
