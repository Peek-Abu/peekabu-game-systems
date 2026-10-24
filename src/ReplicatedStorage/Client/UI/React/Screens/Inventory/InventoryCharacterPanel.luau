--!strict
--[=[
	InventoryCharacterPanel: one employee's page in the Inventory, opened from a Crew card. A back button, the
	employee's name and the page tabs (Skins, Idles, About), then three columns:
	- left: a grid of item cards (a static 3D preview on the item's rarity stage, the rarity's halo and trim, a rarity
	  flag, the name and the footer band saying where it comes from); or, on About, who the employee is;
	- middle: the hero: the selected skin LIVE (idle playing) on a platform with rays in the rarity colour;
	- right: the selected item's detail (flags, name, lore, the Styles row when it has styles, Comes with, the main
	  button); or, on About, the stats and the ability.
	All of it is InventoryViewModel output; nothing is per character. Presentational (exempt; story in
	InventoryScreen.story).

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
local ToonPill = require(Toon.ToonPill)
local ToonRarityFrame = require(Toon.ToonRarityFrame)
local ToonSourceBand = require(Toon.ToonSourceBand)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
local CARD_RADIUS = 18

export type InventoryCharacterPanelProps = {
	employee: string,
	tab: VM.PageTab,
	layout: VM.Layout,
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	-- The selected item (nil = the worn one).
	selected: string?,
	onBack: () -> (),
	onTab: (tab: VM.PageTab) -> (),
	onSelect: (id: string) -> (),
	onWear: (change: CosmeticTypes.Change) -> (),
	-- The shown item was New! and has now been looked at.
	onSeen: (ids: { string }) -> (),
}

local TAB_TEXT: { [VM.PageTab]: string } = { skins = "Skins", idles = "Idles", about = "About" }

local function text(value: string, size: number, x: number, y: number, width: number, body: boolean?): React.ReactNode
	return e(ToonText, {
		text = value,
		font = if body then "body" else "display",
		color = if body then COLOR.ink else nil,
		textSize = size,
		position = UDim2.fromOffset(x, y),
		size = UDim2.fromOffset(width, if body then size * 4 else size + 8),
		fit = not body,
		wrapped = body,
		alignY = "top",
	})
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
	local bandHeight = if phone then 24 else 34
	local stage: { [string]: React.ReactNode } = {
		art = e(ToonViewport, {
			employee = props.employee,
			skin = skinKey,
			framing = "full",
			dim = entry.dim,
			position = UDim2.fromOffset(4, 4),
			size = UDim2.new(1, -8, 1, -bandHeight - (if phone then 26 else 36)),
			zIndex = 2,
		}),
		name = e(ToonText, {
			text = entry.name,
			textSize = if phone then 14 else 20,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 8, 1, -bandHeight - 4),
			size = UDim2.new(1, -16, 0, if phone then 18 else 26),
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
		band = if entry.band ~= nil
			then e(ToonSourceBand, {
				kind = entry.band.kind,
				text = entry.band.text,
				height = bandHeight,
				radius = CARD_RADIUS - 4,
				compact = phone,
				zIndex = 6,
			})
			else nil,
	}
	return e("TextButton", {
		Size = UDim2.fromOffset(cell.X, cell.Y + DEPTH.drop),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			props.onSelect(entry.id)
		end,
	}, {
		halo = e(ToonRarityFrame, {
			rarity = entry.rarity,
			part = "halo",
			width = cell.X,
			radius = CARD_RADIUS,
			size = UDim2.fromOffset(cell.X, cell.Y),
			zIndex = 1,
		}),
		surface = e(ToonSurface, {
			hue = "grape",
			shade = UIToonConstants.rarity(entry.rarity),
			radius = CARD_RADIUS,
			small = true,
			size = UDim2.fromOffset(cell.X, cell.Y),
			zIndex = 2,
			children = stage,
		}),
		ring = if selected
			then e("Frame", {
				Position = UDim2.fromOffset(-6, -6),
				Size = UDim2.fromOffset(cell.X + 12, cell.Y + 12),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, CARD_RADIUS + 6) }),
				stroke = e("UIStroke", { Color = COLOR.selected, Thickness = 5 }),
			})
			else nil,
		new = if entry.new
			then e(ToonFlag, {
				text = "New!",
				hue = "coral",
				tilt = 6,
				textSize = if phone then 12 else 16,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, 6, 0, -6),
				size = UDim2.fromOffset(if phone then 52 else 70, if phone then 22 else 30),
				zIndex = 7,
			})
			else nil,
	})
end

local function grid(props: InventoryCharacterPanelProps, cards: { VM.ItemCard }, selected: string): React.ReactNode
	local nodes: { [string]: React.ReactNode } = {
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(props.layout.cell.X, props.layout.cell.Y + DEPTH.drop),
			CellPadding = UDim2.fromOffset(props.layout.gap, props.layout.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 20),
		}),
	}
	local look = props.loadout.looks[props.employee]
	local wornSkin = if look ~= nil then look.skin else CosmeticRegistry.defaultOf(props.employee, "skin").id
	for index, entry in cards do
		local item = CosmeticRegistry.get(entry.id)
		local skinKey = if item ~= nil and item.kind == "skin" then VM.skinKey(entry.id) else VM.skinKey(wornSkin)
		nodes[entry.id] = itemCard(props, entry, skinKey, entry.id == selected, index)
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

local function hero(props: InventoryCharacterPanelProps, skinKey: string, rarity: CosmeticTypes.Rarity): React.ReactNode
	local shade = UIToonConstants.rarity(rarity)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		rays = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(1.3, 1.3),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = shade.hi,
			ImageTransparency = 0.55,
			ZIndex = 1,
		}),
		platform = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.9),
			Size = UDim2.fromScale(0.8, 0.09),
			BackgroundColor3 = shade.lo,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 4 }),
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(shade.base, shade.lo),
			}),
		}),
		model = e(ToonViewport, {
			employee = props.employee,
			skin = skinKey,
			live = true,
			framing = "full",
			position = UDim2.fromScale(0, 0.02),
			size = UDim2.fromScale(1, 0.92),
			zIndex = 3,
		}),
	})
end

local function detail(props: InventoryCharacterPanelProps, view: VM.Detail, item: CosmeticTypes.Item): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local width = layout.detailWidth - 36
	local size = layout.textSize
	local face: { [string]: React.ReactNode } = {}
	local y = if phone then 12 else 20
	face.rarity = e(ToonFlag, {
		text = view.rarityText,
		rarity = view.rarity,
		tilt = -3,
		textSize = if phone then 14 else 18,
		position = UDim2.fromOffset(18, y),
		size = UDim2.fromOffset(if phone then 90 else 130, if phone then 26 else 34),
	})
	if view.new then
		face.new = e(ToonFlag, {
			text = "New!",
			hue = "coral",
			tilt = 4,
			textSize = if phone then 14 else 18,
			position = UDim2.fromOffset(if phone then 116 else 160, y),
			size = UDim2.fromOffset(if phone then 60 else 80, if phone then 26 else 34),
		})
	end
	y += if phone then 34 else 50
	face.name = e(ToonText, {
		text = view.name,
		textSize = layout.headingSize,
		meaning = "grape",
		position = UDim2.fromOffset(18, y),
		size = UDim2.fromOffset(width, layout.headingSize + 6),
		fit = true,
	})
	y += layout.headingSize + 6
	face.line = text(view.line, size - 2, 18, y, width, true)
	y += size + 8
	face.lore = text(`"{view.lore}"`, size, 18, y, width, true)
	y += size * 3 + 10
	if view.styles.visible then
		face.stylesLabel = text("Styles", size, 18, y, 110)
		for index = 1, view.styles.count do
			face[`style{index}`] = e(ToonSurface, {
				hue = "steel",
				small = true,
				radius = 999,
				position = UDim2.fromOffset(18 + (if phone then 64 else 96) + (index - 1) * (size + 14), y),
				size = UDim2.fromOffset(size + 8, size + 8),
			})
		end
		face.stylesNote = e(ToonText, {
			text = view.styles.note,
			font = "body",
			color = UIToonConstants.shade("steel").lo,
			textSize = size - 4,
			position = UDim2.fromOffset(18 + (if phone then 64 else 96) + view.styles.count * (size + 14) + 6, y + 2),
			size = UDim2.fromOffset(140, size),
			fit = true,
		})
		y += size + 22
	end
	if #view.comesWith > 0 then
		face.bundle = text(`Comes with: {table.concat(view.comesWith, ", ")}`, size - 2, 18, y, width, true)
	end
	local action = view.action
	face.action = e(ToonButton, {
		variant = action.variant,
		text = action.text,
		textSize = if phone then 18 else 26,
		disabled = not action.enabled,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -(if phone then 16 else 26)),
		size = UDim2.new(1, -36, 0, if phone then 44 else 66),
		onActivated = function()
			if action.enabled then
				props.onWear(VM.change(item, props.employee))
			end
		end,
	})
	return e(ToonSurface, {
		hue = "cream",
		pattern = "sparkle",
		radius = 24,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = face,
	})
end

local function about(props: InventoryCharacterPanelProps): (React.ReactNode, React.ReactNode)
	local layout = props.layout
	local phone = layout.phone
	local profile = EmployeeProfileRegistry.get(props.employee)
	if profile == nil then
		return nil, nil
	end
	local size = layout.textSize
	local leftWidth = layout.gridWidth - 36
	local left: { [string]: React.ReactNode } = {
		kind = text(string.upper(profile.kind), layout.headingSize, 18, 16, leftWidth),
	}
	local y = 16 + layout.headingSize + 10
	for index, word in profile.words do
		left[`word{index}`] = e(ToonPill, {
			text = word,
			hue = "lilac",
			textSize = size - 2,
			padX = 6,
			position = UDim2.fromOffset(18 + (index - 1) * math.floor(leftWidth / 3), y),
			size = UDim2.fromOffset(math.floor(leftWidth / 3) - 8, size + 16),
		})
	end
	y += size + 28
	left.bio = text(profile.bio, size, 18, y, leftWidth, true)
	y += size * 4 + 6
	left.factTitle = text("Fun fact", size, 18, y, leftWidth)
	y += size + 8
	left.fact = text(profile.funFact, size, 18, y, leftWidth, true)
	-- The footer line needs room the phone card does not have.
	left.everyone = if phone
		then nil
		else e(ToonText, {
			text = "Every employee can finish every job, even alone.",
			font = "body",
			color = UIToonConstants.shade("grape").lo,
			textSize = size - 2,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 18, 1, -(if phone then 16 else 24)),
			size = UDim2.new(1, -36, 0, size * 2 + 4),
			wrapped = true,
			fit = true,
		})

	local rightWidth = layout.detailWidth - 36
	local right: { [string]: React.ReactNode } = {
		title = text("STATS", layout.headingSize - 6, 18, 16, rightWidth),
	}
	local row = if phone then 26 else 40
	local barX = if phone then 110 else 190
	y = 16 + layout.headingSize + 4
	for index, stat in VM.stats(props.employee) do
		local rowY = y + (index - 1) * row
		right[`icon{index}`] = e(ToonIcon, {
			icon = stat.icon,
			position = UDim2.fromOffset(14, rowY - 2),
			size = UDim2.fromOffset(row - 4, row - 4),
			drop = 2,
		})
		right[`label{index}`] = e(ToonText, {
			text = stat.label,
			font = "body",
			color = COLOR.ink,
			textSize = size - 2,
			position = UDim2.fromOffset(18 + row, rowY),
			size = UDim2.fromOffset(barX - row - 24, row - 8),
			fit = true,
		})
		for pip = 1, 5 do
			right[`pip{index}_{pip}`] = e("Frame", {
				Position = UDim2.fromOffset(barX + (pip - 1) * math.floor((rightWidth - barX) / 5), rowY + 4),
				Size = UDim2.fromOffset(math.floor((rightWidth - barX) / 5) - 6, row - 16),
				BackgroundColor3 = if pip <= stat.value
					then VM.color(props.employee).body
					else UIToonConstants.shade("cream").lo,
				BorderSizePixel = 0,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
			})
		end
	end
	y += 5 * row + 10
	local ability = profile.ability
	local abilityFace: { [string]: React.ReactNode } = {
		name = text(ability.name, size + 4, 14, 8, rightWidth - 28),
		-- The phone card has room for the one-liner only.
		line = text(if phone then ability.line else ability.detail, size - 2, 14, size + 16, rightWidth - 28, true),
		cooldown = e(ToonPill, {
			text = `Every {ability.cooldown}s`,
			hue = "night",
			textSize = size - 4,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -10, 0, 8),
			size = UDim2.fromOffset(if phone then 80 else 120, size + 10),
		}),
	}
	right.ability = e(ToonSurface, {
		hue = "grape",
		radius = 18,
		small = true,
		position = UDim2.fromOffset(14, y),
		size = UDim2.new(1, -28, 1, -y - (if phone then 14 else 22)),
		children = abilityFace,
	})
	return e(ToonSurface, {
		hue = "cream",
		pattern = "sparkle",
		radius = 24,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = left,
	}),
		e(ToonSurface, {
			hue = "cream",
			pattern = "sparkle",
			radius = 24,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = right,
		})
end

local function InventoryCharacterPanel(props: InventoryCharacterPanelProps): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local employee = CosmeticRegistry.get(props.employee)
	local look = props.loadout.looks[props.employee]
	local wornSkin = if look ~= nil then look.skin else CosmeticRegistry.defaultOf(props.employee, "skin").id

	-- The tab row: back, the name, the page tabs.
	local row: { [string]: React.ReactNode } = {
		back = e(ToonButton, {
			variant = "secondary",
			text = "< Crew",
			textSize = if phone then 16 else 22,
			sound = "back",
			size = UDim2.fromOffset(if phone then 90 else 130, layout.tabsHeight - 6),
			onActivated = props.onBack,
		}),
		name = e(ToonText, {
			text = string.upper(if employee ~= nil then employee.name else props.employee),
			textSize = layout.tabsHeight - 12,
			position = UDim2.fromOffset(if phone then 104 else 150, 0),
			size = UDim2.fromOffset(if phone then 150 else 260, layout.tabsHeight - 6),
			fit = true,
		}),
	}
	local tabWidth = if phone then 84 else 130
	for index, tab: VM.PageTab in VM.PAGE_TABS do
		row[tab] = e(ToonButton, {
			variant = "grape",
			text = TAB_TEXT[tab],
			textSize = if phone then 16 else 22,
			selected = props.tab == tab,
			receded = props.tab ~= tab,
			position = UDim2.fromOffset((if phone then 264 else 430) + (index - 1) * (tabWidth + 10), 0),
			size = UDim2.fromOffset(tabWidth, layout.tabsHeight - 6),
			onActivated = function()
				props.onTab(tab)
			end,
		})
	end

	local left: React.ReactNode
	local right: React.ReactNode
	local heroSkin = VM.skinKey(wornSkin)
	local heroRarity: CosmeticTypes.Rarity = "default"
	local seenId = ""
	if props.tab == "about" then
		left, right = about(props)
	else
		local kind: "skin" | "idle" = if props.tab == "skins" then "skin" else "idle"
		local cards = VM.items(kind, props.employee, props.loadout, props.owns)
		local selectedId = props.selected
		local selectedItem = if selectedId ~= nil then CosmeticRegistry.get(selectedId) else nil
		if selectedItem == nil or selectedItem.kind ~= kind then
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
			left = grid(props, cards, selectedItem.id)
			local view = VM.detail(selectedItem, props.loadout, props.owns)
			right = detail(props, view, selectedItem)
			if view.new then
				seenId = selectedItem.id
			end
			heroRarity = selectedItem.rarity
			if selectedItem.kind == "skin" then
				heroSkin = VM.skinKey(selectedItem.id)
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

	local bodyY = layout.tabsHeight + layout.gap
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		row = e("Frame", {
			Size = UDim2.new(1, 0, 0, layout.tabsHeight),
			BackgroundTransparency = 1,
		}, row),
		left = e("Frame", {
			Position = UDim2.fromOffset(0, bodyY),
			Size = UDim2.new(0, layout.gridWidth, 1, -bodyY),
			BackgroundTransparency = 1,
		}, { content = left }),
		hero = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.gap, bodyY),
			Size = UDim2.new(0, layout.heroWidth, 1, -bodyY),
			BackgroundTransparency = 1,
		}, { content = hero(props, heroSkin, heroRarity) }),
		right = e("Frame", {
			Position = UDim2.fromOffset(layout.gridWidth + layout.heroWidth + 2 * layout.gap, bodyY),
			Size = UDim2.new(0, layout.detailWidth, 1, -bodyY),
			BackgroundTransparency = 1,
		}, { content = right }),
	})
end

return InventoryCharacterPanel
