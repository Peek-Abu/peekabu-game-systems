--!strict
--[=[
	LockerPanel: the Shop's Lockers tab (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).
	Left: the two Lost & Found Locker cards (Gloom Locker and Gleam Locker) with their render, key count, live pity
	line, Odds button and Open button. Right: "What's inside" for the selected Locker, with each item's rarity, Owned
	stamp, and (for restricted players on the Gleam Locker) direct purchase price. Tapping an item opens its own page
	(LockerItemPanel, LockerStore.viewing) in place of the tab, where its direct buy and confirmation modal live.

	Presentational React component over `LockerViewModel` and `LockerStore` (exempt; values specced in
	`LockerViewModel`). The Locker cards (LockerCardView) and the inside-grid item cards (LockerInsideCard) were split
	out of this file.

	@class LockerPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local LockerServiceClient = require(ReplicatedStorage.Client.Features.Locker.LockerServiceClient)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local LockerCardView = require(script.Parent.LockerCardView)
local LockerInsideCard = require(script.Parent.LockerInsideCard)
local LockerItemPanel = require(script.Parent.LockerItemPanel)
local LockerOddsSheet = require(script.Parent.LockerOddsSheet)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement
local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }
type LockerId = LockerTypes.LockerId

export type LockerPanelProps = {
	owns: (id: string) -> boolean,
	balances: VM.Balances,
	layout: InventoryViewModel.Layout,
	preview: boolean,
	onGetGleam: () -> (),
	-- The live limited-time event's id: its Locker shows as a third card while it is live.
	live: string?,
}

local function LockerPanel(props: LockerPanelProps): React.ReactNode
	local lockers = ReactCharm.useAtom(StateSyncClientStore.lockers)
	local storeRestricted = ReactCharm.useAtom(LockerStore.restricted)
	local selected = ReactCharm.useAtom(LockerStore.selected)
	local oddsFor = ReactCharm.useAtom(LockerStore.oddsFor)
	local result = ReactCharm.useAtom(LockerStore.result)
	local viewing = ReactCharm.useAtom(LockerStore.viewing)
	-- An item's page never outlives the Lockers tab.
	React.useEffect(function(): () -> ()
		return function()
			LockerStore.view(nil)
		end
	end, {})
	local directConfirm, setDirectConfirm = React.useState(function(): VM.InsideItem?
		return nil
	end)

	local restricted = if props.preview then false else storeRestricted
	local state = if props.preview then LockerConstants.defaultLockers() else lockers
	local layout, content, phone, gap, size =
		props.layout, props.layout.content, props.layout.phone, props.layout.gap, props.layout.textSize

	local cards: { VM.LockerCard } = {}
	for _, locker in VM.lockers(props.live) do
		table.insert(cards, VM.card(locker, state, props.balances, restricted))
	end
	local activeLocker = LockerRules.get(selected) or LockerConstants.LOCKERS.gloom
	local inside = VM.inside(activeLocker, props.owns, props.balances, restricted)
	local note = if result ~= nil and result.locker == selected then VM.resultText(result.reason) else nil

	local leftWidth = math.floor(content.width * (if phone then 0.46 else 0.44))
	local cardHeight = math.floor((content.height - gap * (#cards - 1)) / #cards)
	local leftNodes: Nodes =
		{ list = e("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, card in cards do
		leftNodes[card.id] = LockerCardView(
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
		grid[item.id] = LockerInsideCard(item, Vector2.new(cellWidth, cellHeight), phone, index, function(entry)
			LockerStore.view(entry.id)
		end)
	end
	local viewed: VM.InsideItem? = nil
	for _, item in inside do
		if item.id == viewing then
			viewed = item
		end
	end

	-- The selected Locker's card (the event's Locker too), else the first.
	local selectedCard = cards[1]
	for _, card in cards do
		if card.id == selected then
			selectedCard = card
		end
	end
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

	local modalOpen = oddsLocker ~= nil or confirmFace ~= nil or viewed ~= nil
	local page = if viewed ~= nil
		then e(LockerItemPanel, {
			item = viewed,
			page = VM.itemPage(activeLocker, viewed),
			owns = props.owns,
			gleam = props.balances.gleam,
			layout = layout,
			onBack = function()
				LockerStore.view(nil)
			end,
			onBuy = function()
				setDirectConfirm(viewed)
			end,
			onGetGleam = props.onGetGleam,
		})
		else nil

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
		page = if oddsLocker == nil then page else nil,
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
