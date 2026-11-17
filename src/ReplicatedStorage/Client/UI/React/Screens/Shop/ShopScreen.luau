--!strict
--[=[
	ShopScreen: the Shop (concepts: characters/ui/character-ui/frames3/shop.jpg and product.jpg). On a coral-to-grape
	ToonBackdrop over the blurred depot, under a ToonMenuBar (the gift render, tabs Featured · Skins · Gleam, both
	wallets, close; a back button on a product page):
	- Featured: the day's Featured banner (the item posed, its name, what's inside, its price button, when the shop
	  changes; owner, 2026-10-29: only a product page animates) and Today's picks (6 cards), with the Gleam bundles along the bottom;
	- Skins: every item for sale, filterable by employee, owned ones stamped OWNED;
	- Hire: every employee for sale (their card opens the hire page);
	- Gleam: the six Gleam bundles side by side as tall cards (a sideways scroll on a phone) (greyed "Soon" until their Robux products exist); when the player came here short
	  on Gleam for something (ShopStore.returnTo), it says how much more for what, marks the bundle that is just right,
	  has a Back button, and goes back to that item with its Yes/No question up as soon as the Gleam arrives;
	- Passes: every registered game pass (ShopPassesPanel), its price and icon as Roblox reported them, Owned once the
	  player's public `pass:` field says so (live after a purchase); greyed "Soon" while no pass is registered;
	- a product page (ShopProductPanel) when ShopStore.product is set (a card, or "See in Shop" in the Inventory).
	Buying asks Yes / No first, then sends ShopServiceClient:requestBuy (with the Gleam the player said yes to when
	Gleam pays the rest of a Credits price); what was bought arrives through the synced
	entitlements and the reveal. Values are ShopViewModel's. `preview` swaps the stores for fixed data (the story).
	The parts are split out of this file: ShopTabBody (a list tab's body) with ShopFeaturedTab (Featured),
	ShopOfferCard (an offer's card), ShopBundleCards (the Gleam bundles), ShopConfirmDialog (the Yes / No question),
	the hooks useShopCarousel (the banner carousel) and useShopBuying ("Buying..."), and the shared pieces in
	ShopScreenBlocks; this file keeps the stores, the bar, the product page and the backdrop.
	Exempt (wires stores; story in ShopScreen.story).

	@class ShopScreen
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local DealStore = require(ReplicatedStorage.Client.Features.Deal.State.DealStore)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local MarketplaceServiceClient = require(ReplicatedStorage.Client.Features.Marketplace.MarketplaceServiceClient)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local EventServiceClient = require(ReplicatedStorage.Client.Features.Event.EventServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonArrival = require(Toon.ToonArrival)
local ToonBackdrop = require(Toon.ToonBackdrop)
local ShopRarityLookViewModel = require(script.Parent.ShopRarityLookViewModel)
local ToonMenuBar = require(Toon.ToonMenuBar)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local ShopProductPanel = require(script.Parent.ShopProductPanel)
local ShopConfirmDialog = require(script.Parent.ShopConfirmDialog)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local ShopTabBody = require(script.Parent.ShopTabBody)
local useShopBuying = require(script.Parent.useShopBuying)
local useShopCarousel = require(script.Parent.useShopCarousel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local MOTION = UIToonConstants.MOTION
-- Where the open item's model stands across the screen (its rays and its rarity word centre on it).
local HERO_X = 0.72

type Nodes = ShopScreenBlocks.Nodes

export type Preview = ShopScreenBlocks.Preview

export type ShopScreenProps = {
	preview: Preview?,
	viewport: Vector2?,
	phone: boolean?,
	-- Open on this tab, or on this item's page (the story).
	tab: string?,
	item: string?,
}

local function ShopScreen(props: ShopScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local loadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local currency = ReactCharm.useAtom(StateSyncClientStore.currency)
	local premium = ReactCharm.useAtom(StateSyncClientStore.premium)
	local storeProduct = ReactCharm.useAtom(ShopStore.product)
	local result = ReactCharm.useAtom(ShopStore.result)
	local lockerOpening = ReactCharm.useAtom(LockerStore.opening)
	local lockerViewing = ReactCharm.useAtom(LockerStore.viewing)
	-- The last Locker answer (an event key buy's refusal shows on the event tab).
	local keyResult = ReactCharm.useAtom(LockerStore.result)
	local passInfo = ReactCharm.useAtom(ShopStore.passInfo)
	local bundleInfo = ReactCharm.useAtom(ShopStore.bundleInfo)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local deals = ReactCharm.useAtom(StateSyncClientStore.deals)
	local dealPrices = ReactCharm.useAtom(DealStore.robux)
	local passKeys = MarketplaceRegistry.passKeys()
	-- A live limited-time event (never in a preview): its tab comes first, and the Shop opens on it the first time
	-- only (owner Y1, 11-16); the server remembers it in the `events` slice.
	local liveEvent = if props.preview ~= nil then nil else EventServiceClient:live()
	local eventsSeen = ReactCharm.useAtom(StateSyncClientStore.events)
	local firstEventOpen = liveEvent ~= nil and eventsSeen.shown[liveEvent.id] ~= true
	local tab, setTab = React.useState(props.tab or (if firstEventOpen then "event" else "featured"))
	local firstEventId = if firstEventOpen and liveEvent ~= nil then liveEvent.id else ""
	React.useEffect(function()
		if firstEventId ~= "" then
			EventServiceClient:markShown(firstEventId)
		end
	end, { firstEventId })
	local carousel = useShopCarousel(tab, storeProduct ~= nil)
	local slot = carousel.slot
	local pickSlide = carousel.pickSlide
	local filter, setFilter = React.useState(function(): string?
		return nil
	end)
	local confirming, setConfirming = React.useState(false)
	local buying, setBuying = useShopBuying(result)
	-- The Yes / No question pops in over a back that dims (M6).
	local asked = useToonPlay(MOTION.popSeconds, 0, if confirming then "ask" else "")
	local returnTo = ReactCharm.useAtom(ShopStore.returnTo)
	local ask = ReactCharm.useAtom(ShopStore.ask)
	-- Back to what the player went to get Gleam for, as soon as the Gleam they bought arrives (never in a preview).
	local gleamNow = if props.preview ~= nil then props.preview.gleam else premium.balance
	React.useEffect(function()
		if props.preview == nil and returnTo ~= nil and VM.returnReady(returnTo, gleamNow) then
			setTab(returnTo.tab)
			ShopStore.goBack()
		end
	end, { gleamNow, if returnTo ~= nil then returnTo.gleam else -1 })
	-- Landed back on the item: put its Yes/No question up.
	React.useEffect(function()
		if ask then
			ShopStore.asked()
			setConfirming(true)
		end
	end, { ask })
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	React.useEffect(function(): () -> ()
		local running = true
		task.spawn(function()
			while running do
				task.wait(30)
				if running then
					setNow(workspace:GetServerTimeNow())
				end
			end
		end)
		return function()
			running = false
		end
	end, {})

	local preview = props.preview
	if preview == nil and lockerOpening ~= nil then
		return nil
	end
	local owns = if preview ~= nil
		then preview.owns
		else function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end
	local balances: VM.Balances = if preview ~= nil
		then { gleam = preview.gleam, credits = preview.credits }
		else {
			gleam = premium.balance,
			credits = CurrencyUtils.getCurrencyAmount(currency, "credits"),
			acorns = CurrencyUtils.getCurrencyAmount(currency, "acorns"),
			-- Sales run on the server's clock.
			now = now,
		}
	local productId = if preview ~= nil then props.item else storeProduct

	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = InventoryViewModel.layout(virtual, phone)
	local content = layout.content
	local size = layout.textSize

	local function close()
		SceneStack.remove(VM.SCENE)
	end
	-- Roblox's price and icon for each bundle once fetched (the story keeps the known ones).
	local bundles = VM.bundles(
		if preview ~= nil then {} else bundleInfo,
		if returnTo ~= nil then VM.bestBundle(returnTo.gleam - balances.gleam) else nil
	)
	local function buyBundle(key: string)
		if preview == nil then
			MarketplaceServiceClient:promptProduct(key)
		end
	end
	local function buyPass(key: string)
		if preview == nil then
			MarketplaceServiceClient:promptPass(key)
		end
	end
	-- Owned: the server publishes each pass the player has as their public `pass:<key>` field (never in a preview).
	local function ownsPass(key: string): boolean
		local me = publicPlayers[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
		return preview == nil and me ~= nil and me[MarketplaceConstants.passField(key)] == true
	end
	local function open(id: string)
		if preview == nil then
			ShopStore.open(id)
		end
	end

	local tabs: { ToonMenuBar.Tab } = {}
	for _, entry in VM.tabs(#passKeys > 0, liveEvent) do
		table.insert(tabs, { id = entry.id, text = entry.text, icon = entry.icon, soon = entry.soon })
	end
	local tabIds: { string } = {}
	for _, entry in tabs do
		table.insert(tabIds, entry.id)
	end
	local offer = if productId ~= nil then ShopRegistry.get(productId) else nil
	local backText = "Back"
	for _, entry in VM.tabs(#passKeys > 0, liveEvent) do
		if entry.id == tab then
			backText = entry.text
		end
	end
	local bar = e(ToonMenuBar, {
		title = "SHOP",
		icon = "shop",
		-- Each screen has its own colour (owner pick 2026-11-13): the Shop is mint.
		hue = "mint",
		-- A product page has its back button instead of the tabs (the bar has no room for both).
		tabs = if offer ~= nil then {} else tabs,
		current = if offer ~= nil then nil else tab,
		onTab = function(id: string)
			setTab(id)
			if preview == nil then
				ShopStore.close()
				if id ~= "gleam" then
					ShopStore.setReturn(nil)
				end
			end
		end,
		-- Back to the tab the page was opened from (named, so it never repeats the SHOP plate beside it).
		back = if offer ~= nil
			then {
				text = backText,
				onActivated = function()
					if preview == nil then
						ShopStore.close()
					end
				end,
			}
			else nil,
		credits = balances.credits,
		gleam = balances.gleam,
		onClose = close,
		x = layout.titleX,
		height = layout.barHeight,
		phone = phone,
		-- Six tabs: they shrink to fit beside the wallets.
		width = virtual.X,
	})

	local body: React.ReactNode
	local modal: React.ReactNode = nil
	if offer ~= nil then
		local product = VM.product(offer, owns, balances)
		local resultNow = if result ~= nil and result.offer == offer.id
			then VM.resultText(result.reason)
			else VM.saleText(product.card.saleEnds, balances.now)
		body = e(ShopProductPanel, {
			product = product,
			-- What you wear now: a vacuum's page shows it on you.
			outfit = CosmeticOutfitRules.current(
				if preview ~= nil then CosmeticConstants.defaultLoadout() else loadout,
				owns
			),
			layout = layout,
			note = resultNow,
			buying = buying == offer.id,
			onBuy = function()
				setConfirming(true)
			end,
			-- Short: the Gleam tab with the smallest pack that covers it, and Roblox's purchase prompt for that pack
			-- straight away; once the Gleam lands the Shop goes back to the item with its question up.
			onGetMore = function()
				local back = VM.returnTo(offer, owns, balances, tab)
				local pack = product.button.pack
				setTab("gleam")
				if preview == nil then
					ShopStore.close()
					ShopStore.setReturn(back)
					if pack ~= nil then
						MarketplaceServiceClient:promptProduct(pack)
					end
				end
			end,
		})
		if confirming then
			modal = ShopConfirmDialog({
				product = product,
				offer = offer,
				owns = owns,
				balances = balances,
				preview = preview,
				size = size,
				phone = phone,
				asked = asked,
				setConfirming = setConfirming,
				setBuying = setBuying,
			})
		end
	else
		body = ShopTabBody({
			tab = tab,
			setTab = setTab,
			preview = preview,
			liveEvent = liveEvent,
			now = now,
			owns = owns,
			balances = balances,
			keyResult = keyResult,
			layout = layout,
			phone = phone,
			open = open,
			filter = filter,
			setFilter = setFilter,
			currency = currency,
			passKeys = passKeys,
			passInfo = passInfo,
			ownsPass = ownsPass,
			buyPass = buyPass,
			returnTo = returnTo,
			bundles = bundles,
			buyBundle = buyBundle,
			deals = deals,
			dealPrices = dealPrices,
			slot = slot,
			pickSlide = pickSlide,
		})
	end

	local screen: Nodes = {
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				bar = e("Frame", {
					Position = UDim2.fromOffset(0, layout.barY),
					Size = UDim2.new(1, 0, 0, layout.barHeight),
					BackgroundTransparency = 1,
					ZIndex = 2,
				}, { bar = bar }),
				-- The page rises in as the Shop opens and slides in from the side of a tab picked (M2, M3).
				body = e(ToonArrival, {
					position = UDim2.fromOffset(content.x, content.y),
					size = UDim2.fromOffset(content.width, content.height),
					tabs = tabIds,
					tab = if offer ~= nil then `item:{offer.id}` else tab,
					content = body,
				}),
				modal = modal,
			},
		}),
	}
	-- An open item's page takes its rarity's look (ShopRarityLookViewModel); the lists keep the shop's own colours.
	local viewedItem = if offer == nil
			and tab == "lockers"
			and lockerViewing ~= nil
		then CosmeticRegistry.get(lockerViewing)
		else nil
	-- A Locker item's own page (LockerItemPanel) takes its rarity's look too.
	local look = if offer ~= nil
		then ShopRarityLookViewModel.look(VM.card(offer, owns, balances).rarity)
		elseif viewedItem ~= nil then ShopRarityLookViewModel.look(viewedItem.rarity)
		else nil
	local function raysOf(layer: ShopRarityLookViewModel.RayLayer?): ToonBackdrop.Rays?
		return if layer ~= nil
			then {
				position = UDim2.fromScale(HERO_X, 0.5),
				size = 0.7,
				color = layer.color,
				transparency = layer.transparency,
			}
			else nil
	end
	return e(ToonBackdrop, {
		top = if look ~= nil then look.top else UIToonConstants.shade("coral").base,
		bottom = if look ~= nil then look.bottom else UIToonConstants.shade("grape").lo,
		-- A tier's colours are opaque (play-check 2026-11-14: the depot showed through the pale ones); the lists keep the
		-- world faintly behind them.
		see = if look ~= nil then 0 else 0.2,
		blur = preview == nil,
		rays = if look ~= nil then raysOf(look.rays) else nil,
		counterRays = if look ~= nil then raysOf(look.counterRays) else nil,
		word = if look ~= nil
			then {
				text = look.word,
				color = look.wordColor,
				transparency = look.wordTransparency,
				position = UDim2.fromScale(HERO_X, 0.34),
				size = UDim2.fromScale(0.5, 0.2),
			}
			else nil,
		edge = if look ~= nil then look.edge else nil,
		goo = look ~= nil and look.goo,
		children = screen,
	})
end

return ShopScreen
