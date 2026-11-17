--!strict
--[=[
	ShopFeaturedTab: the Shop's Featured tab (ShopScreen): the Featured banner spot (a carousel of the offered one-time
	deals (DealBanner), today's banner and the rest of the featured pool, with its Next button and dots), Today's
	picks (3 x 2 on a desktop, one sideways row on a phone) and, on a desktop, the Gleam row along the bottom. Values:
	ShopViewModel and ShopCarouselViewModel. Split out of ShopScreen. Presentational (exempt).

	@class ShopFeaturedTab
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local DealServiceClient = require(ReplicatedStorage.Client.Features.Deal.DealServiceClient)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBurst = require(Toon.ToonBurst)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local DealBanner = require(script.Parent.Parent.Deal.DealBanner)
local DealViewModel = require(script.Parent.Parent.Deal.DealViewModel)
local CarouselVM = require(script.Parent.ShopCarouselViewModel)
local ShopBundleCards = require(script.Parent.ShopBundleCards)
local ShopOfferCard = require(script.Parent.ShopOfferCard)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
-- Space inside the picks list for the flags that stick out over its cards.
local PICK_PAD = 14

type Nodes = ShopScreenBlocks.Nodes

local group = ShopScreenBlocks.group
local heading = ShopScreenBlocks.heading
local art = ShopOfferCard.art
local offerCard = ShopOfferCard.card
local bundleRow = ShopBundleCards.row

local function ShopFeaturedTab(ctx: ShopScreenBlocks.ShopTabContext): React.ReactNode
	local preview = ctx.preview
	local deals = ctx.deals
	local dealPrices = ctx.dealPrices
	local owns = ctx.owns
	local balances = ctx.balances
	local slot = ctx.slot
	local pickSlide = ctx.pickSlide
	local now = ctx.now
	local layout = ctx.layout
	local phone = ctx.phone
	local open = ctx.open
	local bundles = ctx.bundles
	local buyBundle = ctx.buyBundle
	local content = layout.content
	local gap = layout.gap
	local size = layout.textSize
	-- Featured: the banner, Today's picks, the Gleam row.
	local live = ShopRotationUtils.live(ShopRegistry.all(), now)
	local bannerWidth = math.floor(content.width * 0.47)
	-- On a phone the Gleam row is left to the Gleam tab: the banner and the picks take the whole height.
	local topHeight = if phone then content.height else math.floor(content.height * 0.64)
	local nodes: Nodes = {}
	local dealIds: { DealConstants.DealId } = if preview ~= nil then {} else DealRules.offeredList(deals, owns)
	local slides = CarouselVM.slides(dealIds, live)
	local spot = CarouselVM.at(slot, #slides)
	local slide = slides[spot]
	-- The item a featured slide shows (today's banner or another from the featured pool).
	local noOffer: typeof(live.featured) = nil
	local shown = noOffer
	local today = false
	if slide ~= nil and slide.kind == "today" then
		shown, today = slide.offer, true
	elseif slide ~= nil and slide.kind == "more" then
		shown = slide.offer
	end
	local onNext = if #slides > 1
		then function()
			pickSlide(spot + 1)
		end
		else nil
	if slide ~= nil and slide.kind == "deal" then
		local dealId = slide.deal
		nodes.banner = e(DealBanner, {
			banner = DealViewModel.banner(dealId, DealServiceClient:productReady(dealId), dealPrices[dealId]),
			phone = phone,
			textSize = size,
			headingSize = layout.headingSize,
			size = UDim2.fromOffset(bannerWidth, topHeight),
			onBuy = function()
				DealServiceClient:buy(dealId, nil)
			end,
			onNext = onNext,
		})
	elseif shown ~= nil then
		local product = VM.product(shown, owns, balances)
		local card = product.card
		local nameSize = CarouselVM.nameSize(
			math.floor(layout.headingSize * (if phone then 1 else 1.4)),
			string.upper(card.name),
			bannerWidth * 0.55
		)
		local priced: Nodes = {
			price = e(ToonPrice, {
				currency = card.currency,
				amount = card.price,
				was = card.was,
				inline = true,
				textSize = if phone then 20 else 44,
				meaning = "white",
				align = "center",
				size = UDim2.new(1, 0, 1, -DEPTH.lip),
			}),
		}
		local bannerFace: Nodes = {
			hero = e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromScale(0.55, 1.1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, { model = art(card) }),
			ribbon = e(ToonFlag, {
				text = if today then "Today's banner" else "Featured",
				hue = "mint",
				tilt = -5,
				textSize = if phone then 13 else 24,
				position = UDim2.fromOffset(if phone then 12 else 28, if phone then 10 else 26),
				size = UDim2.fromOffset(if phone then 140 else 260, if phone then 26 else 44),
				zIndex = 4,
			}),
			name = e(ToonText, {
				text = string.upper(card.name),
				textSize = nameSize,
				position = UDim2.fromOffset(if phone then 12 else 28, if phone then 40 else 84),
				size = UDim2.new(0.55, 0, 0, nameSize + 8),
				fit = true,
				zIndex = 4,
			}),
			line = e(ToonText, {
				text = card.line,
				font = "body",
				color = COLOR.ink,
				textSize = size,
				position = UDim2.fromOffset(if phone then 12 else 28, (if phone then 40 else 84) + nameSize + 10),
				size = UDim2.new(0.5, 0, 0, size + 4),
				fit = true,
				zIndex = 4,
			}),
			buy = e(ToonButton, {
				variant = if product.button.kind == "owned" then "secondary" else "primary",
				text = if product.button.kind == "owned" then "Owned" else nil,
				content = if product.button.kind == "owned" then nil else priced,
				textSize = if phone then 18 else 32,
				disabled = product.button.kind == "owned",
				anchor = Vector2.new(0, 1),
				position = UDim2.new(0, if phone then 12 else 28, 1, -(if phone then 40 else 84)),
				size = UDim2.new(0.46, 0, 0, if phone then 44 else 90),
				onActivated = function()
					open(shown.id)
				end,
				zIndex = 4,
			}),
			next = if onNext ~= nil
				then e(ToonButton, {
					variant = "night",
					text = "Next",
					textSize = if phone then 13 else 22,
					small = true,
					anchor = Vector2.new(1, 0),
					position = UDim2.new(1, if phone then -12 else -28, 0, if phone then 10 else 24),
					size = UDim2.fromOffset(if phone then 64 else 110, if phone then 28 else 46),
					onActivated = onNext,
					zIndex = 6,
				})
				else nil,
			-- A real discount shows its "-xx%" like the offer cards (a bundle's 30%, a sale), on the buy button's
			-- top-left corner, clear of the item art on the right.
			off = if card.off ~= nil and product.button.kind ~= "owned"
				then e(ToonBurst, {
					text = card.off,
					hue = "coral",
					size = if phone then 40 else 68,
					anchor = Vector2.new(0.5, 0.5),
					position = UDim2.new(
						0,
						(if phone then 12 else 28) + 6,
						1,
						-((if phone then 40 else 84) + (if phone then 44 else 90)) + 6
					),
					zIndex = 7,
				})
				else nil,
			timer = if today
				then e(ToonPill, {
					text = `Changes in {VM.timer(live.nextRotation - now)}`,
					hue = "night",
					textSize = size - 4,
					anchor = Vector2.new(0, 1),
					position = UDim2.new(0, if phone then 12 else 28, 1, -(if phone then 10 else 24)),
					size = UDim2.fromOffset(if phone then 150 else 260, if phone then 24 else 44),
					zIndex = 4,
				})
				else nil,
		}
		nodes.banner = e("Frame", {
			Size = UDim2.fromOffset(bannerWidth, topHeight),
			BackgroundTransparency = 1,
		}, {
			glow = e(ToonSurface, {
				hue = "gold",
				radius = 32,
				pattern = "rings",
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = bannerFace,
			}),
		})
	end
	-- The carousel's dots: one per slide (the current one gold), tap to jump. They sit in the text column under the
	-- item's line, never over its art (owner: nothing covers an item preview).
	if #slides > 1 then
		local hit = if phone then 24 else 36
		local dot = if phone then 12 else 16
		local dots: Nodes = {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index = 1, #slides do
			dots[`dot{index}`] = e("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(hit, hit),
				LayoutOrder = index,
				[React.Event.Activated] = function()
					pickSlide(index)
				end,
			}, {
				dot = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(dot, dot),
					-- The current dot is ink: gold vanished on the gold banner (play-check 2026-11-14).
					BackgroundColor3 = if index == spot then COLOR.ink else COLOR.white,
					BorderSizePixel = 0,
				}, {
					corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					stroke = e("UIStroke", { Color = COLOR.ink, Thickness = if phone then 2 else 3 }),
				}),
			})
		end
		local nameSize = math.floor(layout.headingSize * (if phone then 1 else 1.4))
		local pad = if phone then 12 else 28
		nodes.dots = e("Frame", {
			Position = UDim2.fromOffset(pad - (hit - dot) / 2, (if phone then 40 else 84) + nameSize + size + 28),
			Size = UDim2.fromOffset(hit * #slides, hit),
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, dots)
	end
	-- Today's picks: 3 x 2.
	local picksX = bannerWidth + gap + 10
	local picksWidth = content.width - picksX
	local headingSize = math.floor(layout.headingSize * 0.75)
	-- Desktop: a 3 x 2 grid. Phone: one row of bigger cards that scrolls sideways.
	-- PICK_PAD keeps the rarity flags (they stick out over the cards' top-left corners) inside the list.
	local cellHeight = if phone
		then topHeight - headingSize - 30 - PICK_PAD
		else math.floor((topHeight - headingSize - 20 - gap - PICK_PAD) / 2)
	local cellWidth = if phone then math.floor(cellHeight * 0.8) else math.floor((picksWidth - 2 * gap - PICK_PAD) / 3)
	local grid: Nodes = {
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, PICK_PAD),
			PaddingTop = UDim.new(0, PICK_PAD),
		}),
		layout = if phone
			then e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else e("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellWidth, cellHeight),
				CellPadding = UDim2.fromOffset(gap, gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
	}
	for index, pick in live.picks do
		grid[pick.id] = offerCard(VM.card(pick, owns, balances), Vector2.new(cellWidth, cellHeight), phone, index, open)
	end
	nodes.picksHeading =
		heading("TODAY'S PICKS", headingSize, UDim2.fromOffset(picksX, 0), math.floor(picksWidth * 0.55))
	nodes.picksTimer = e(ToonPill, {
		text = `New in {VM.timer(live.nextRotation - now)}`,
		hue = "night",
		textSize = size - 4,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 4),
		size = UDim2.fromOffset(if phone then 130 else 240, if phone then 24 else 44),
	})
	nodes.picks = e("ScrollingFrame", {
		Position = UDim2.fromOffset(picksX, headingSize + 20),
		Size = UDim2.fromOffset(picksWidth, topHeight - headingSize - 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = if phone then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = if phone then 4 else 0,
	}, grid)
	-- The Gleam row along the bottom (desktop).
	if not phone then
		local rowY = topHeight + gap + 6
		nodes.gleamHeading = heading("GET GLEAM", headingSize, UDim2.fromOffset(0, rowY), 400)
		nodes.gleam = e("Frame", {
			Position = UDim2.fromOffset(0, rowY + headingSize + 14),
			Size = UDim2.new(1, 0, 1, -rowY - headingSize - 14),
			BackgroundTransparency = 1,
		}, {
			row = bundleRow(
				content.width,
				content.height - rowY - headingSize - 14,
				phone,
				gap + 10,
				VM.featuredBundles(bundles),
				buyBundle
			),
		})
	end
	return group(nodes)
end

return ShopFeaturedTab
