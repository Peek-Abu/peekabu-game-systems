--!strict
--[=[
	ShopTabBody: the body of the Shop's list tab that is up (ShopScreen, when no product page is open): the live
	event's tab (ShopEventPanel), Skins (employee filter chips over a grid of offer cards), Hire (a grid of employee
	cards), the Lockers (LockerPanel), Passes (ShopPassesPanel), Gleam (the note, a Back button when the player came
	short of Gleam, and the tall bundle cards) and otherwise Featured (ShopFeaturedTab). Values: ShopViewModel and
	ShopEventViewModel. Split out of ShopScreen. Presentational (exempt).

	@class ShopTabBody
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local LockerServiceClient = require(ReplicatedStorage.Client.Features.Locker.LockerServiceClient)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local LockerPanel = require(script.Parent.Parent.Locker.LockerPanel)
local ShopPassesPanel = require(script.Parent.ShopPassesPanel)
local ShopEventPanel = require(script.Parent.ShopEventPanel)
local EventVM = require(script.Parent.ShopEventViewModel)
local ShopBundleCards = require(script.Parent.ShopBundleCards)
local ShopFeaturedTab = require(script.Parent.ShopFeaturedTab)
local ShopOfferCard = require(script.Parent.ShopOfferCard)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = ShopScreenBlocks.Nodes

local EMPLOYEES = { "Pippa", "Cappy", "Prickles" }

local group = ShopScreenBlocks.group
local heading = ShopScreenBlocks.heading
local offerCard = ShopOfferCard.card
local bundleLadder = ShopBundleCards.ladder

local function ShopTabBody(ctx: ShopScreenBlocks.ShopTabContext): React.ReactNode
	local tab = ctx.tab
	local setTab = ctx.setTab
	local preview = ctx.preview
	local liveEvent = ctx.liveEvent
	local now = ctx.now
	local owns = ctx.owns
	local balances = ctx.balances
	local keyResult = ctx.keyResult
	local layout = ctx.layout
	local phone = ctx.phone
	local open = ctx.open
	local filter = ctx.filter
	local setFilter = ctx.setFilter
	local currency = ctx.currency
	local passKeys = ctx.passKeys
	local passInfo = ctx.passInfo
	local ownsPass = ctx.ownsPass
	local buyPass = ctx.buyPass
	local returnTo = ctx.returnTo
	local bundles = ctx.bundles
	local buyBundle = ctx.buyBundle
	local content = layout.content
	local gap = layout.gap
	local size = layout.textSize

	local body: React.ReactNode
	if tab == "event" and liveEvent ~= nil then
		local acorns = balances.acorns or 0
		-- Live outside its dates: the admin preview.
		local previewed = now < liveEvent.starts or now >= liveEvent.ends
		body = e(ShopEventPanel, {
			header = EventVM.header(liveEvent, now, previewed, acorns),
			cards = EventVM.offers(liveEvent, owns, balances),
			locker = EventVM.locker(liveEvent),
			keys = EventVM.keys(liveEvent, acorns),
			note = if keyResult ~= nil then EventVM.resultText(keyResult.reason) else nil,
			width = content.width,
			height = content.height,
			headingSize = layout.headingSize,
			textSize = size,
			gap = gap,
			phone = phone,
			renderCard = function(card: VM.OfferCard, cellSize: Vector2, order: number): React.ReactNode
				return offerCard(card, cellSize, phone, order, open)
			end,
			onLocker = function(id)
				LockerStore.select(id)
				setTab("lockers")
			end,
			onKey = function(id)
				LockerServiceClient:requestKey(id)
			end,
		})
	elseif tab == "skins" then
		local chips: Nodes = {
			list = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, option in VM.skinFilters(EMPLOYEES) do
			local value = option.value
			chips[option.text] = e(ToonButton, {
				variant = "grape",
				sound = "tab",
				text = option.text,
				textSize = size,
				selected = filter == value,
				receded = filter ~= value,
				size = UDim2.fromOffset(if phone then 84 else 150, if phone then 34 else 54),
				layoutOrder = index,
				onActivated = function()
					setFilter(value)
				end,
			})
		end
		local columns = if phone then 4 else 5
		local cellWidth = math.floor((content.width - (columns - 1) * gap - 32) / columns)
		local cell = Vector2.new(cellWidth, math.floor(cellWidth * 1.15))
		local grid: Nodes = {
			layout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(cell.X, cell.Y),
				CellPadding = UDim2.fromOffset(gap, gap + 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			-- Room for the rarity flags that stick out over the cards' top-left corners.
			pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 12),
			}),
		}
		for index, card in VM.skins(owns, balances, filter) do
			grid[card.id] = offerCard(card, cell, phone, index, open)
		end
		local chipHeight = if phone then 40 else 64
		body = group({
			chips = e("Frame", { Size = UDim2.new(1, 0, 0, chipHeight), BackgroundTransparency = 1 }, chips),
			grid = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, chipHeight + 4),
				Size = UDim2.new(1, 0, 1, -chipHeight - 4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
			}, grid),
		})
	elseif tab == "hires" then
		local columns = if phone then 3 else 4
		local cellWidth = math.floor((content.width - (columns - 1) * gap - 32) / columns)
		local cell = Vector2.new(cellWidth, math.floor(cellWidth * 1.3))
		local grid: Nodes = {
			layout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(cell.X, cell.Y),
				CellPadding = UDim2.fromOffset(gap, gap + 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 12),
			}),
		}
		for index, card in VM.hires(owns, balances) do
			grid[card.id] = offerCard(card, cell, phone, index, open)
		end
		local headingSize = math.floor(layout.headingSize * 0.75)
		body = group({
			heading = heading("HIRE A NEW EMPLOYEE", headingSize, UDim2.fromOffset(0, 0), 700),
			grid = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, headingSize + 14),
				Size = UDim2.new(1, 0, 1, -headingSize - 14),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
			}, grid),
		})
	elseif tab == "lockers" then
		local gloom = if preview ~= nil then preview.credits else CurrencyUtils.getCurrencyAmount(currency, "gloom")
		body = e(LockerPanel, {
			owns = owns,
			balances = { gloom = gloom, gleam = balances.gleam, acorns = balances.acorns },
			layout = layout,
			preview = preview ~= nil,
			live = if liveEvent ~= nil then liveEvent.id else nil,
			onGetGleam = function()
				setTab("gleam")
				if preview == nil then
					ShopStore.setReturn(VM.lockerReturn(balances.gleam))
				end
			end,
		})
	elseif tab == "passes" then
		body = e(ShopPassesPanel, {
			cards = VM.passes(passKeys, passInfo, ownsPass),
			width = content.width,
			height = content.height,
			headingSize = layout.headingSize,
			textSize = size,
			phone = phone,
			onBuy = buyPass,
		})
	elseif tab == "gleam" then
		local note = e(ToonText, {
			text = if returnTo ~= nil
				then VM.returnNote(returnTo, balances.gleam)
				else "Gleam buys skins, emotes and stickers. Everything is cosmetic: it never makes you stronger.",
			font = if returnTo ~= nil then "display" else "body",
			color = COLOR.white,
			textSize = size,
			position = UDim2.fromOffset(0, 0),
			size = UDim2.new(1, 0, 0, size * 2 + 6),
			wrapped = true,
			fit = true,
		})
		local backButton: React.ReactNode = nil
		if returnTo ~= nil then
			local back = returnTo
			backButton = e(ToonButton, {
				variant = "secondary",
				text = `Back to {back.name}`,
				textSize = if phone then 14 else 24,
				small = true,
				anchor = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				size = UDim2.fromOffset(if phone then 190 else 360, if phone then 32 else 54),
				onActivated = function()
					-- Back without buying: the page, but no question.
					setTab(back.tab)
					ShopStore.goBack()
					ShopStore.asked()
				end,
			})
		end
		-- The cards fill the page below the note, short of its bottom edge.
		local ladderHeight =
			math.floor(content.height - (layout.headingSize + size * 2 + 40) - (if phone then 6 else 24))
		body = group({
			heading = heading("GET GLEAM", layout.headingSize, UDim2.fromOffset(0, 0), 600),
			back = backButton,
			note = e("Frame", {
				Position = UDim2.fromOffset(0, layout.headingSize + 12),
				Size = UDim2.new(1, 0, 0, size * 2 + 6),
				BackgroundTransparency = 1,
			}, { note = note }),
			row = e("Frame", {
				Position = UDim2.fromOffset(0, layout.headingSize + size * 2 + 40),
				Size = UDim2.new(1, 0, 0, ladderHeight),
				BackgroundTransparency = 1,
			}, {
				ladder = bundleLadder(content.width, ladderHeight, phone, gap + 10, bundles, buyBundle),
			}),
		})
	else
		-- Featured: the banner, Today's picks, the Gleam row.
		body = ShopFeaturedTab(ctx)
	end
	return body
end

return ShopTabBody
