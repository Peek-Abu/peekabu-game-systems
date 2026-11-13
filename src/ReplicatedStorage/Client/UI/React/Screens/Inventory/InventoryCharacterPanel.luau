--!strict
--[=[
	InventoryCharacterPanel: one employee's page in the Inventory, under the menu bar (back, the employee's head and
	name, the tabs Skins · Idles · About: InventoryScreen draws it). Concepts: characters/ui/character-ui/frames3/
	char-skins.jpg and char-about.jpg. Three columns:
	- left: a grid of item cards (rarity-coloured card, an inset stage with the item in 3D, a rarity ribbon, the name,
	  the footer band saying where it comes from, New! and "On" ribbons), or on About: who they are and a fun fact;
	- middle: the hero: the selected skin LIVE (idle playing) on a raised platform in the rarity's colour;
	- right: the selected item's detail (ribbons, the big name, the lore box (a quote when the employee speaks), Styles, Comes with tiles, the
	  main button: Wear / Wearing / See in Shop with its price / where else to get it), or on About: the ability card,
	  the stat bars and "Every employee can finish every job, even alone."
	All of it is InventoryViewModel output; nothing is per character. Looking at a New! item marks it seen.
	Presentational (exempt; story in InventoryScreen.story).

	@class InventoryCharacterPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonCooldown = require(Toon.ToonCooldown)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonRarityFrame = require(Toon.ToonRarityFrame)
local ToonSourceBand = require(Toon.ToonSourceBand)
local ToonStatRows = require(Toon.ToonStatRows)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
local CARD_RADIUS = 18
-- A vacuum skin's hero shows your employee from behind (a little round, so the face still shows): the pack is on the back.
local BACK_TURN = 150

export type InventoryCharacterPanelProps = {
	employee: string,
	tab: VM.PageTab,
	layout: VM.Layout,
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	-- The selected item (nil = the worn one).
	selected: string?,
	-- When this page was opened from the crew: the hero reacts to it (ToonViewport `react`).
	openedAt: number?,
	onSelect: (id: string) -> (),
	onWear: (change: CosmeticTypes.Change) -> (),
	-- Opens the item's Shop page.
	onShop: (id: string) -> (),
	-- The shown item was New! and has now been looked at.
	onSeen: (ids: { string }) -> (),
}

type Nodes = { [string]: React.ReactNode }

local function body(value: string, size: number, color: Color3?): React.ReactNode
	return e(ToonText, {
		text = value,
		font = "body",
		color = color or COLOR.ink,
		textSize = size,
		size = UDim2.fromScale(1, 1),
		wrapped = true,
		alignY = "top",
	})
end

local function group(children: Nodes): React.ReactNode
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

-- A column of blocks laid out top to bottom.
local function stack(children: Nodes, padding: number, inset: number): React.ReactNode
	local nodes: Nodes = {
		list = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding) }),
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, inset),
			PaddingRight = UDim.new(0, inset),
			PaddingTop = UDim.new(0, inset),
		}),
	}
	for key, node in children do
		nodes[key] = node
	end
	return group(nodes)
end

-- A block in a stack: a fixed-height frame holding one node.
local function block(height: number, order: number, node: React.ReactNode): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, { node = node })
end

local function itemCard(
	props: InventoryCharacterPanelProps,
	entry: VM.ItemCard,
	skinKey: string,
	selected: boolean,
	order: number
): React.ReactNode
	local cell = props.layout.cell
	local phone = props.layout.phone
	local bandHeight = if phone then 22 else 34
	local nameSize = if phone then 13 else 22
	local shade = UIToonConstants.rarity(entry.rarity)
	local stageHeight = cell.Y - bandHeight - nameSize - (if phone then 14 else 24)
	local stage: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, CARD_RADIUS - 6) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(shade.hi, shade.base) }),
		art = e(ToonViewport, {
			-- A vacuum card shows the vacuum on its own; a skin or idle card shows the employee.
			employee = if entry.vacuum then nil else props.employee,
			vacuum = if entry.vacuum then VM.skinKey(entry.id) else nil,
			skin = skinKey,
			framing = "full",
			dim = entry.dim,
			position = UDim2.fromOffset(0, 6),
			size = UDim2.new(1, 0, 1, -4),
			zIndex = 2,
		}),
	}
	if entry.rarity == "epic" or entry.rarity == "legendary" then
		stage.stripes = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.stripes,
			ImageColor3 = COLOR.white,
			ImageTransparency = 0.8,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(64, 64),
			ZIndex = 1,
		})
	end
	if entry.dim then
		stage.lock = e(ToonIcon, {
			icon = "lockNight",
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, -6, 1, -6),
			size = UDim2.fromOffset(if phone then 22 else 34, if phone then 22 else 34),
			drop = 2,
			zIndex = 3,
		})
	end
	local face: Nodes = {
		stage = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, stageHeight),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, stage),
		name = e(ToonText, {
			text = entry.name,
			textSize = nameSize,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 8, 1, -bandHeight - (if phone then 4 else 8)),
			size = UDim2.new(1, -16, 0, nameSize + 6),
			align = "center",
			fit = true,
			zIndex = 4,
		}),
		trim = e(ToonRarityFrame, {
			rarity = entry.rarity,
			part = "trim",
			width = cell.X,
			radius = CARD_RADIUS,
			zIndex = 5,
		}),
	}
	local band = entry.band
	if band ~= nil then
		face.band = e(ToonSourceBand, {
			kind = band.kind,
			text = band.text,
			height = bandHeight,
			radius = CARD_RADIUS - 4,
			compact = phone,
			zIndex = 6,
		})
	end
	local flagHeight = if phone then 20 else 30
	local nodes: Nodes = {
		halo = e(ToonRarityFrame, {
			rarity = entry.rarity,
			part = "halo",
			width = cell.X,
			radius = CARD_RADIUS,
			position = UDim2.fromOffset(0, 8),
			size = UDim2.fromOffset(cell.X, cell.Y),
			zIndex = 1,
		}),
		surface = e(ToonSurface, {
			hue = "grape",
			shade = shade,
			radius = CARD_RADIUS,
			small = true,
			gloss = false,
			position = UDim2.fromOffset(0, 8),
			size = UDim2.fromOffset(cell.X, cell.Y),
			zIndex = 3,
			children = face,
		}),
		rarity = e(ToonFlag, {
			text = if entry.rarity == "default" then "CLASSIC" else string.upper(entry.rarity),
			rarity = entry.rarity,
			tilt = -6,
			textSize = if phone then 10 else 14,
			position = UDim2.fromOffset(-6, 0),
			size = UDim2.fromOffset(if phone then 92 else 132, flagHeight),
			zIndex = 7,
		}),
	}
	if selected then
		nodes.ring = e("Frame", {
			Position = UDim2.fromOffset(-6, 2),
			Size = UDim2.fromOffset(cell.X + 12, cell.Y + 12),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, CARD_RADIUS + 6) }),
			stroke = e("UIStroke", { Color = COLOR.white, Thickness = 5 }),
		})
	end
	if entry.worn or entry.new then
		nodes.tag = e(ToonFlag, {
			text = if entry.worn then "On" else "New!",
			hue = if entry.worn then "mint" else "coral",
			tilt = 6,
			textSize = if phone then 11 else 18,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 8, 0, 0),
			size = UDim2.fromOffset(if phone then 52 else 78, flagHeight),
			zIndex = 7,
		})
	end
	return e("TextButton", {
		Size = UDim2.fromOffset(cell.X, cell.Y + DEPTH.drop + 8),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			props.onSelect(entry.id)
		end,
	}, nodes)
end

-- The page's rows of cards, each under its heading (if any), in one scrolling column.
local function grid(props: InventoryCharacterPanelProps, sections: { VM.Section }, selected: string): React.ReactNode
	local nodes: Nodes = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, props.layout.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for what sticks out past a card (the tilted flags, the selected ring), which the list would cut.
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 20),
		}),
	}
	local look = props.loadout.looks[props.employee]
	local wornSkin = if look ~= nil then look.skin else CosmeticRegistry.defaultOf(props.employee, "skin").id
	local headingSize = if props.layout.phone then 13 else 20
	local order = 0
	for sectionIndex, section in sections do
		local title = section.title
		if title ~= nil then
			order += 1
			nodes[`heading{sectionIndex}`] = e("Frame", {
				Size = UDim2.new(1, 0, 0, headingSize + 10),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, {
				text = e(ToonText, {
					text = string.upper(title),
					textSize = headingSize,
					meaning = "grape",
					size = UDim2.fromScale(1, 1),
				}),
			})
		end
		local cards: Nodes = {
			layout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(props.layout.cell.X, props.layout.cell.Y + DEPTH.drop + 8),
				CellPadding = UDim2.fromOffset(props.layout.gap, props.layout.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, entry in section.cards do
			local item = CosmeticRegistry.get(entry.id)
			local skinKey = if item ~= nil and item.kind == "skin" then VM.skinKey(entry.id) else VM.skinKey(wornSkin)
			cards[entry.id] = itemCard(props, entry, skinKey, entry.id == selected, index)
		end
		order += 1
		nodes[`section{sectionIndex}`] = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, cards)
	end
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIToonConstants.shade("lilac").base,
	}, nodes)
end

-- The hero: the item live on a 3D platform in the rarity's colour. For a vacuum skin: you (your employee as you
-- are now, rank lanyard and all) wearing the selected vacuum, from behind.
local function hero(
	props: InventoryCharacterPanelProps,
	skinKey: string,
	rarity: CosmeticTypes.Rarity,
	tryOn: string?,
	style: number,
	emote: string?,
	idle: string?
): React.ReactNode
	local shade = UIToonConstants.rarity(rarity)
	local outfit = if tryOn ~= nil
		then CosmeticOutfitRules.tryOn(CosmeticOutfitRules.current(props.loadout, props.owns), tryOn)
		else nil
	return group({
		model = e(ToonViewport, {
			employee = if outfit == nil then props.employee else nil,
			outfit = outfit,
			turn = if outfit ~= nil then BACK_TURN else nil,
			skin = skinKey,
			style = style,
			idle = if outfit == nil then idle else nil,
			live = true,
			react = props.openedAt,
			-- The player turns it round (drag, flick, right stick).
			spin = true,
			-- On the Emotes tab the hero loops the selected emote, in the skin you wear.
			emote = emote,
			framing = "full",
			platform = { top = shade.base, side = shade.lo },
			size = UDim2.fromScale(1, 0.94),
			zIndex = 3,
		}),
	})
end

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
			icon = "shopGift",
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

local function detail(
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

-- A grape card on the About tab: a title and the blocks under it.
local function aboutCard(title: string, size: number, inner: Nodes, height: number, order: number): React.ReactNode
	local rows: Nodes = {
		title = block(
			size + 12,
			0,
			e(ToonText, { text = string.upper(title), textSize = size + 8, size = UDim2.fromScale(1, 1), fit = true })
		),
	}
	for key, node in inner do
		rows[key] = node
	end
	local face: Nodes = { rows = stack(rows, 8, 20) }
	return block(
		height,
		order,
		e(ToonSurface, {
			hue = "grape",
			pattern = "bubbles",
			radius = 24,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		})
	)
end

local function about(props: InventoryCharacterPanelProps): (React.ReactNode, React.ReactNode)
	local layout = props.layout
	local phone = layout.phone
	local profile = EmployeeProfileRegistry.get(props.employee)
	if profile == nil then
		return nil, nil
	end
	local size = layout.textSize
	local words: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, word in profile.words do
		words[`word{index}`] = e(ToonPill, {
			text = word,
			hue = "gold",
			textSize = size - 4,
			padX = 10,
			size = UDim2.fromOffset(math.floor(#word * (size - 4) * 0.62) + 30, size + 12),
			layoutOrder = index,
		})
	end
	local whoRows: Nodes = { bio = block(size * 4, 1, body(profile.bio, size, COLOR.white)) }
	if not phone then
		whoRows.words = block(size + 14, 2, group(words))
	end
	local who = aboutCard(`Who is {props.employee}?`, size, whoRows, size * 5 + (if phone then 30 else size + 60), 1)
	local fact = aboutCard("Fun fact", size, {
		fact = block(size * 3, 1, body(profile.funFact, size, COLOR.white)),
	}, size * 4 + 46, 2)
	local left = stack({ who = who, fact = fact }, layout.gap, 0)

	-- The ability card (its render breaking the left edge), the stat bars, the everyone line.
	local abilitySize = if phone then 70 else 120
	local ability: Nodes = {
		name = e(ToonText, {
			text = profile.ability.name,
			textSize = size + 12,
			position = UDim2.fromOffset(math.floor(abilitySize * 0.75), 10),
			size = UDim2.new(1, -math.floor(abilitySize * 0.75) - 100, 0, size + 16),
			fit = true,
		}),
		detail = e("Frame", {
			Position = UDim2.fromOffset(math.floor(abilitySize * 0.75), size + 30),
			Size = UDim2.new(1, -math.floor(abilitySize * 0.75) - 20, 1, -size - 40),
			BackgroundTransparency = 1,
		}, { text = body(if phone then profile.ability.line else profile.ability.detail, size - 2, COLOR.white) }),
		cooldown = e(ToonCooldown, {
			seconds = profile.ability.cooldown,
			height = if phone then 44 else 66,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -14, 0, 10),
			size = UDim2.fromOffset(if phone then 54 else 78, if phone then 44 else 66),
		}),
	}
	local row = if phone then 22 else 50
	local statsFace: Nodes = {
		rows = e(ToonStatRows, {
			rows = VM.stats(props.employee),
			row = row,
			barX = if phone then 104 else 200,
			textSize = size,
			position = UDim2.fromOffset(18, if phone then 10 else 22),
			size = UDim2.new(1, -36, 1, -(if phone then 20 else 44)),
		}),
	}
	local rightRows: Nodes = {
		ability = block(
			if phone then 84 else 150,
			1,
			group({
				card = e(ToonSurface, {
					hue = "grape",
					radius = 24,
					position = UDim2.fromOffset(math.floor(abilitySize * 0.3), 0),
					size = UDim2.new(1, -math.floor(abilitySize * 0.3), 1, -DEPTH.drop),
					children = ability,
				}),
				art = e(ToonIcon, {
					image = UIAssets.iconImage(profile.ability.icon),
					anchor = Vector2.new(0, 0.5),
					position = UDim2.new(0, -8, 0.5, -4),
					size = UDim2.fromOffset(abilitySize, abilitySize),
					drop = 4,
					zIndex = 3,
				}),
			})
		),
		stats = block(
			5 * row + (if phone then 24 else 48),
			2,
			e(ToonSurface, {
				hue = "grape",
				pattern = "bubbles",
				radius = 24,
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = statsFace,
			})
		),
	}
	if not phone then
		local everyone: Nodes = {
			text = e("Frame", {
				Position = UDim2.fromOffset(18, 10),
				Size = UDim2.new(1, -36, 1, -20),
				BackgroundTransparency = 1,
			}, {
				text = body(
					"Every employee can finish every job, even alone. Stats only change how it feels.",
					size - 2,
					COLOR.white
				),
			}),
		}
		rightRows.everyone = block(
			size * 3 + 20,
			3,
			e(ToonSurface, {
				hue = "night",
				radius = 20,
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = everyone,
			})
		)
	end
	return left, stack(rightRows, layout.gap, 0)
end

local function InventoryCharacterPanel(props: InventoryCharacterPanelProps): React.ReactNode
	local layout = props.layout
	-- The colour style picked on a chip, for the item it was picked on (another item shows its worn style again).
	local picked, setPicked = React.useState({ id = "", style = 1 })
	local look = props.loadout.looks[props.employee]
	local wornSkin = if look ~= nil then look.skin else CosmeticRegistry.defaultOf(props.employee, "skin").id

	local left: React.ReactNode
	local right: React.ReactNode
	local heroSkin = VM.skinKey(wornSkin)
	local heroRarity: CosmeticTypes.Rarity = "default"
	local tryOn: string? = nil
	local heroStyle = 1
	local heroEmote: string? = nil
	local heroIdle: string? = VM.heroIdle(props.employee, props.loadout, props.owns, nil)
	local seenId = ""
	if props.tab == "about" then
		left, right = about(props)
	else
		local sections = VM.sections(props.tab, props.employee, props.loadout, props.owns)
		-- The kinds on this tab (Skins holds the vacuum skins too); the first row's kind opens selected.
		local kinds: { [string]: boolean } = {}
		for _, section in sections do
			for _, entry in section.cards do
				local item = CosmeticRegistry.get(entry.id)
				if item ~= nil then
					kinds[item.kind] = true
				end
			end
		end
		local first = sections[1]
		local cards: { VM.ItemCard } = if first ~= nil then first.cards else {}
		local selectedId = props.selected
		local selectedItem = if selectedId ~= nil then CosmeticRegistry.get(selectedId) else nil
		if selectedItem == nil or kinds[selectedItem.kind] ~= true then
			selectedItem = nil
			for _, entry in cards do
				if entry.worn then
					selectedItem = CosmeticRegistry.get(entry.id)
				end
			end
			if selectedItem == nil and cards[1] ~= nil then
				selectedItem = CosmeticRegistry.get(cards[1].id)
			end
		end
		if selectedItem ~= nil then
			local item = selectedItem
			local view = VM.detail(
				item,
				props.loadout,
				props.owns,
				props.employee,
				if picked.id == item.id then picked.style else nil
			)
			heroStyle = view.styles.selected
			left = grid(props, sections, item.id)
			-- A chip only previews the style; Wear (enabled for another style of a worn skin) puts it on.
			right = detail(props, view, item, heroStyle, function(index: number)
				setPicked({ id = item.id, style = index })
			end)
			heroRarity = selectedItem.rarity
			heroEmote = if selectedItem.kind == "emote" then selectedItem.id else nil
			heroIdle = VM.heroIdle(props.employee, props.loadout, props.owns, selectedItem)
			if selectedItem.kind == "skin" then
				heroSkin = VM.skinKey(selectedItem.id)
			elseif selectedItem.kind == "vacuum" then
				tryOn = selectedItem.id
			end
			if view.new then
				seenId = selectedItem.id
			end
		end
	end

	-- Looking at a New! item clears its flag (the server records it; the flag goes when the loadout syncs).
	local onSeen = props.onSeen
	React.useEffect(function()
		if seenId ~= "" then
			onSeen({ seenId })
		end
	end, { seenId })

	return group({
		left = e("Frame", {
			Size = UDim2.new(0, layout.gridWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = left }),
		hero = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.gap, 0),
			Size = UDim2.new(0, layout.heroWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = hero(props, heroSkin, heroRarity, tryOn, heroStyle, heroEmote, heroIdle) }),
		right = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.heroWidth + 2 * layout.gap, 0),
			Size = UDim2.new(0, layout.detailWidth, 1, 0),
			BackgroundTransparency = 1,
		}, { content = right }),
	})
end

return InventoryCharacterPanel
