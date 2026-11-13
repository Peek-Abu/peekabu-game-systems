--!strict
--[=[
	LockerPanel: the Shop's Lockers tab (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).
	Left: the two Lost & Found Locker cards (Gloom Locker and Gleam Locker) with their render, key count, live pity
	line, Odds button and Open button. Right: "What's inside" for the selected Locker, with each item's rarity, Owned
	stamp, and (for restricted players on the Gleam Locker) direct purchase price and confirmation modal.

	Presentational React component over `LockerViewModel` and `LockerStore` (exempt; values specced in
	`LockerViewModel`).

	@class LockerPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local LockerServiceClient = require(ReplicatedStorage.Client.Features.Locker.LockerServiceClient)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonStamp = require(Toon.ToonStamp)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local LockerOddsSheet = require(script.Parent.LockerOddsSheet)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement
local COLOR, DEPTH = UIToonConstants.COLOR, UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }
type LockerId = LockerTypes.LockerId

export type LockerPanelProps = {
	owns: (id: string) -> boolean,
	balances: VM.Balances,
	layout: InventoryViewModel.Layout,
	preview: boolean,
	onGetGleam: () -> (),
}

local function itemArt(item: VM.InsideItem): React.ReactNode
	if item.kind == "stickerPack" or item.kind == "sticker" then
		return e(ToonIcon, {
			icon = "stickers",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromScale(0.7, 0.7),
			drop = 4,
		})
	end
	local vacuum = item.vacuum
	return e(ToonViewport, {
		employee = if vacuum ~= nil then nil else item.employee,
		vacuum = if vacuum ~= nil then CosmeticRegistry.keyOf(vacuum) else nil,
		skin = item.skinKey,
		framing = "full",
		size = UDim2.fromScale(1, 1),
	})
end

local function insideCard(
	item: VM.InsideItem,
	size: Vector2,
	phone: boolean,
	order: number,
	onBuyDirect: (item: VM.InsideItem) -> ()
): React.ReactNode
	local shade = UIToonConstants.rarity(item.rarity)
	local nameSize = if phone then 13 else 22
	local footer = math.floor(nameSize * 2.5)
	local face: Nodes = {
		stage = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -footer - 8 - DEPTH.lip),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
			gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(shade.hi, shade.base) }),
			art = itemArt(item),
		}),
		name = e(ToonText, {
			text = item.name,
			textSize = nameSize,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 10, 1, -DEPTH.lip - math.floor(nameSize * 1.15)),
			size = UDim2.new(0.64, -10, 0, nameSize + 4),
			fit = true,
			zIndex = 3,
		}),
		line = e(ToonText, {
			text = item.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 11 else 15, nameSize - 7),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 10, 1, -DEPTH.lip - 4),
			size = UDim2.new(0.64, -10, 0, nameSize),
			fit = true,
			zIndex = 3,
		}),
		price = if not item.owned and item.directPrice ~= nil
			then e(ToonPrice, {
				currency = "gleam",
				amount = item.directPrice,
				textSize = nameSize,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -8, 1, -DEPTH.lip - 6),
				size = UDim2.new(0.38, 0, 0, nameSize + 10),
				zIndex = 3,
			})
			else nil,
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
		rarity = e(ToonFlag, {
			text = string.upper(item.rarity),
			rarity = item.rarity,
			tilt = -5,
			textSize = if phone then 10 else 14,
			position = UDim2.fromOffset(-6, -8),
			size = UDim2.fromOffset(if phone then 70 else 120, if phone then 20 else 28),
			zIndex = 7,
		}),
		owned = if item.owned
			then e(ToonStamp, {
				text = "OWNED",
				size = math.floor(math.min(size.X, size.Y) * 0.48),
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.42),
				zIndex = 6,
			})
			else nil,
	}
	if item.directPrice ~= nil and not item.owned then
		return e("TextButton", {
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
			[React.Event.Activated] = function()
				onBuyDirect(item)
			end,
		}, nodes)
	end
	return e(
		"Frame",
		{ Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, LayoutOrder = order },
		nodes
	)
end

local function lockerCardView(
	card: VM.LockerCard,
	selected: boolean,
	size: Vector2,
	phone: boolean,
	textSize: number,
	order: number,
	onSelect: (id: LockerId) -> (),
	onOpen: (id: LockerId) -> (),
	onOpenOdds: (id: LockerId) -> (),
	onGetGleam: () -> ()
): React.ReactNode
	local hue: UIToonConstants.Hue = if card.id == "gleam" then "gold" else "grape"
	local pad = if phone then 12 else 20
	local iconSize = math.floor(size.Y * 0.48)
	local pillWidth = math.floor(size.Y * 0.62)
	local nameSize = if phone then 20 else 36
	local buttonHeight = if phone then 38 else 64
	local rightX = pillWidth + pad + (if phone then 8 else 16)
	local rightWidth = size.X - rightX - pad
	local openContent: Nodes? = nil
	if card.button.kind == "buy" then
		local priced: Nodes = {
			price = e(ToonPrice, {
				currency = card.button.currency,
				amount = card.button.price,
				textSize = if phone then 18 else 30,
				meaning = "white",
				align = "center",
				size = UDim2.new(1, 0, 1, -DEPTH.lip),
			}),
		}
		openContent = priced
	end
	local face: Nodes = {
		art = e(ToonIcon, {
			icon = "locker",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0, pad + math.floor(pillWidth / 2), 0.42, 0),
			size = UDim2.fromOffset(iconSize, iconSize),
			drop = 5,
		}),
		keys = e(ToonPill, {
			text = card.keysText,
			hue = "night",
			icon = "key",
			textSize = math.max(11, textSize - 5),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -DEPTH.lip - 8),
			size = UDim2.fromOffset(pillWidth, if phone then 24 else 38),
		}),
		name = e(ToonText, {
			text = string.upper(card.name),
			textSize = nameSize,
			position = UDim2.fromOffset(rightX, pad),
			size = UDim2.fromOffset(rightWidth - (if phone then 64 else 110), nameSize + 4),
			fit = true,
		}),
		odds = e(ToonButton, {
			variant = "secondary",
			text = "Odds",
			textSize = math.max(12, textSize - 2),
			small = true,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -pad, 0, pad),
			size = UDim2.fromOffset(if phone then 58 else 100, if phone then 26 else 42),
			onActivated = function()
				onOpenOdds(card.id)
			end,
		}),
		pity = e(ToonText, {
			text = card.pityText,
			font = "body",
			color = if card.id == "gleam" then COLOR.ink else COLOR.white,
			textSize = math.max(12, textSize - 2),
			position = UDim2.fromOffset(rightX, pad + nameSize + 6),
			size = UDim2.fromOffset(rightWidth, textSize * 2 + 4),
			wrapped = true,
			fit = true,
		}),
		open = e(ToonButton, {
			variant = if card.button.kind == "buy" or card.button.kind == "key"
				then "primary"
				elseif card.button.kind == "short" and card.button.enabled then "gleam"
				else "secondary",
			text = if openContent == nil then card.button.text else nil,
			content = openContent,
			textSize = if phone then 16 else 28,
			disabled = not card.button.enabled,
			small = phone,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, rightX, 1, -DEPTH.lip - (if phone then 8 else 14)),
			size = UDim2.fromOffset(rightWidth, buttonHeight),
			onActivated = function()
				onSelect(card.id)
				if card.button.kind == "short" and card.button.enabled then
					onGetGleam()
				elseif card.button.enabled then
					onOpen(card.id)
				end
			end,
		}),
	}
	return e("TextButton", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			onSelect(card.id)
		end,
	}, {
		surface = e(ToonSurface, {
			hue = hue,
			pattern = "rings",
			radius = 24,
			selected = selected,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	})
end

local function LockerPanel(props: LockerPanelProps): React.ReactNode
	local lockers = ReactCharm.useAtom(StateSyncClientStore.lockers)
	local storeRestricted = ReactCharm.useAtom(LockerStore.restricted)
	local selected = ReactCharm.useAtom(LockerStore.selected)
	local oddsFor = ReactCharm.useAtom(LockerStore.oddsFor)
	local result = ReactCharm.useAtom(LockerStore.result)
	local directConfirm, setDirectConfirm = React.useState(function(): VM.InsideItem?
		return nil
	end)

	local restricted = if props.preview then false else storeRestricted
	local state = if props.preview then LockerConstants.defaultLockers() else lockers
	local layout, content, phone, gap, size =
		props.layout, props.layout.content, props.layout.phone, props.layout.gap, props.layout.textSize

	local cards: { VM.LockerCard } = {
		VM.card(LockerConstants.LOCKERS.gloom, state, props.balances, restricted),
		VM.card(LockerConstants.LOCKERS.gleam, state, props.balances, restricted),
	}
	local activeLocker = LockerRules.get(selected) or LockerConstants.LOCKERS.gloom
	local inside = VM.inside(activeLocker, props.owns, props.balances, restricted)
	local note = if result ~= nil and result.locker == selected then VM.resultText(result.reason) else nil

	local leftWidth = math.floor(content.width * (if phone then 0.46 else 0.44))
	local cardHeight = math.floor((content.height - gap) / 2)
	local leftNodes: Nodes =
		{ list = e("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, card in cards do
		leftNodes[card.id] = lockerCardView(
			card,
			card.id == selected,
			Vector2.new(leftWidth, cardHeight),
			phone,
			size,
			index,
			LockerStore.select,
			function(id: LockerId)
				if not props.preview then
					LockerServiceClient:requestOpen(id)
				end
			end,
			LockerStore.openOdds,
			props.onGetGleam
		)
	end

	local rightX = leftWidth + gap + 8
	local rightWidth = content.width - rightX
	local headingSize = math.floor(layout.headingSize * 0.75)
	local columns = if phone then 2 else 3
	local pad = 14
	local cellWidth = math.floor((rightWidth - (columns - 1) * gap - pad * 2) / columns)
	local cellHeight = math.floor(cellWidth * 1.18)
	local grid: Nodes = {
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, pad),
			PaddingRight = UDim.new(0, pad),
			PaddingTop = UDim.new(0, pad),
			PaddingBottom = UDim.new(0, pad),
		}),
		layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth, cellHeight),
			CellPadding = UDim2.fromOffset(gap, gap + 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in inside do
		grid[item.id] = insideCard(item, Vector2.new(cellWidth, cellHeight), phone, index, function(entry)
			if entry.canBuyDirect then
				setDirectConfirm(entry)
			else
				props.onGetGleam()
			end
		end)
	end

	local selectedCard = if selected == "gleam" then cards[2] else cards[1]
	local headerText = if selectedCard.restricted
		then `BUY DIRECTLY  ·  {string.upper(selectedCard.name)}`
		else `WHAT'S INSIDE  ·  {string.upper(selectedCard.name)}`
	local oddsLocker = if oddsFor ~= nil then LockerRules.get(oddsFor) else nil
	local emptyFace: Nodes = {
		label = e(ToonText, {
			text = "New items for this Locker are on the way!",
			font = "body",
			color = COLOR.ink,
			textSize = size + 2,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.new(0.8, 0, 0, size * 2 + 8),
			align = "center",
			wrapped = true,
			fit = true,
		}),
	}
	local confirmFace: Nodes? = nil
	if directConfirm ~= nil then
		local dialog: Nodes = {
			question = e(ToonText, {
				text = directConfirm.confirm,
				textSize = size + 6,
				meaning = "grape",
				position = UDim2.fromOffset(24, 24),
				size = UDim2.new(1, -48, 0, (size + 6) * 2 + 8),
				wrapped = true,
				fit = true,
				align = "center",
			}),
			yes = e(ToonButton, {
				variant = "primary",
				text = "Yes!",
				textSize = size + 6,
				sound = "cta",
				anchor = Vector2.new(1, 1),
				position = UDim2.new(0.5, -10, 1, -24),
				size = UDim2.new(0.5, -34, 0, if phone then 44 else 70),
				onActivated = function()
					local chosen = directConfirm
					setDirectConfirm(nil)
					if not props.preview and chosen ~= nil then
						LockerServiceClient:requestBuy(activeLocker.id, chosen.id)
					end
				end,
			}),
			no = e(ToonButton, {
				variant = "secondary",
				text = "No",
				textSize = size + 6,
				sound = "back",
				anchor = Vector2.new(0, 1),
				position = UDim2.new(0.5, 10, 1, -24),
				size = UDim2.new(0.5, -34, 0, if phone then 44 else 70),
				onActivated = function()
					setDirectConfirm(nil)
				end,
			}),
		}
		confirmFace = dialog
	end

	local modalOpen = oddsLocker ~= nil or confirmFace ~= nil

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		left = if not modalOpen
			then e(
				"Frame",
				{ Size = UDim2.fromOffset(leftWidth, content.height), BackgroundTransparency = 1 },
				leftNodes
			)
			else nil,
		heading = if not modalOpen
			then e(ToonText, {
				text = headerText,
				textSize = headingSize,
				position = UDim2.fromOffset(rightX, 0),
				size = UDim2.fromOffset(rightWidth, headingSize + 6),
				fit = true,
			})
			else nil,
		note = if not modalOpen and note ~= nil
			then e(ToonPill, {
				text = note,
				hue = "coral",
				textSize = math.max(12, size - 2),
				anchor = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(if phone then 210 else 360, headingSize + 4),
			})
			else nil,
		inside = if modalOpen
			then nil
			elseif #inside > 0 then e("ScrollingFrame", {
				Position = UDim2.fromOffset(rightX, headingSize + 14),
				Size = UDim2.fromOffset(rightWidth, content.height - headingSize - 14),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
			}, grid)
			else e(ToonSurface, {
				hue = "cream",
				pattern = "rings",
				radius = 22,
				position = UDim2.fromOffset(rightX, headingSize + 16),
				size = UDim2.fromOffset(rightWidth, content.height - headingSize - 24),
				children = emptyFace,
			}),
		odds = if oddsLocker ~= nil
			then e(LockerOddsSheet, {
				sheet = VM.oddsSheet(oddsLocker, state),
				phone = phone,
				textSize = size,
				onClose = LockerStore.closeOdds,
			})
			else nil,
		confirm = if confirmFace ~= nil
			then e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLOR.ink,
				BackgroundTransparency = 0.4,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 20,
				[React.Event.Activated] = function()
					setDirectConfirm(nil)
				end,
			}, {
				panel = e(ToonSurface, {
					hue = "cream",
					pattern = "rings",
					radius = 28,
					anchor = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
					size = UDim2.fromOffset(if phone then 380 else 640, if phone then 170 else 300),
					zIndex = 21,
					children = confirmFace,
				}),
			})
			else nil,
	})
end

return LockerPanel
