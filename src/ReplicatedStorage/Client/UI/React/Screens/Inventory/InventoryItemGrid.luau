--!strict
--[=[
	InventoryItemGrid: the left column of an Inventory character page (InventoryCharacterPanel): the page's rows of item
	cards, each under its heading, in one scrolling column. A card is rarity-coloured with an inset stage holding the
	item in 3D, a rarity ribbon, the name, the footer band saying where it comes from, New! / On ribbons and the
	selected ring. Values: InventoryViewModel.sections. Split out of InventoryCharacterPanel. Presentational (exempt).

	@class InventoryItemGrid
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonRarityFrame = require(Toon.ToonRarityFrame)
local ToonSourceBand = require(Toon.ToonSourceBand)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryPanelBlocks = require(script.Parent.InventoryPanelBlocks)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
local CARD_RADIUS = 18

type InventoryCharacterPanelProps = InventoryPanelBlocks.InventoryCharacterPanelProps
type Nodes = InventoryPanelBlocks.Nodes

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
			icon = VM.lockIcon(entry),
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
local function InventoryItemGrid(
	props: InventoryCharacterPanelProps,
	sections: { VM.Section },
	selected: string
): React.ReactNode
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

return InventoryItemGrid
