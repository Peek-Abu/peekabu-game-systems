--!strict
--[=[
	ShopScreen: the Shop (concepts: characters/ui/character-ui/frames3/shop.jpg and product.jpg). On a coral-to-grape
	ToonBackdrop over the blurred depot, under a ToonMenuBar (the gift render, tabs Featured · Skins · Gleam, both
	wallets, close; a back button on a product page):
	- Featured: the day's Featured banner (the item posed, its name, what's inside, its price button, when the shop
	  changes; owner, 2026-10-29: only a product page animates) and Today's picks (6 cards), with the Gleam bundles along the bottom;
	- Skins: every item for sale, filterable by employee, owned ones stamped OWNED;
	- Hire: every employee for sale (their card opens the hire page);
	- Gleam: the four Gleam bundles (greyed "Soon" until their Robux products exist); when the player came here short
	  on Gleam for something (ShopStore.returnTo), it says how much more for what, marks the bundle that is just right,
	  has a Back button, and goes back to that item with its Yes/No question up as soon as the Gleam arrives;
	- Passes: every registered game pass (ShopPassesPanel), its price and icon as Roblox reported them, Owned once the
	  player's public `pass:` field says so (live after a purchase); greyed "Soon" while no pass is registered;
	- a product page (ShopProductPanel) when ShopStore.product is set (a card, or "See in Shop" in the Inventory).
	Buying asks Yes / No first, then sends ShopServiceClient:requestBuy (with the Gleam the player said yes to when
	Gleam pays the rest of a Credits price); what was bought arrives through the synced
	entitlements and the reveal. Values are ShopViewModel's. `preview` swaps the stores for fixed data (the story).
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
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local DealServiceClient = require(ReplicatedStorage.Client.Features.Deal.DealServiceClient)
local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
local ShopServiceClient = require(ReplicatedStorage.Client.Features.Shop.ShopServiceClient)
local MarketplaceServiceClient = require(ReplicatedStorage.Client.Features.Marketplace.MarketplaceServiceClient)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)
local MarketplaceRegistry = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceRegistry)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ShopRarityLookViewModel = require(script.Parent.ShopRarityLookViewModel)
local ToonBurst = require(Toon.ToonBurst)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonMenuBar = require(Toon.ToonMenuBar)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonStamp = require(Toon.ToonStamp)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local LockerPanel = require(script.Parent.Parent.Locker.LockerPanel)
local ShopPassesPanel = require(script.Parent.ShopPassesPanel)
local DealBanner = require(script.Parent.Parent.Deal.DealBanner)
local DealViewModel = require(script.Parent.Parent.Deal.DealViewModel)
local ShopProductPanel = require(script.Parent.ShopProductPanel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
-- Space inside the picks list for the flags that stick out over its cards.
local PICK_PAD = 14
-- Where the open item's model stands across the screen (its rays and its rarity word centre on it).
local HERO_X = 0.72

type Nodes = { [string]: React.ReactNode }

export type Preview = { owns: (id: string) -> boolean, gleam: number, credits: number }

export type ShopScreenProps = {
	preview: Preview?,
	viewport: Vector2?,
	phone: boolean?,
	-- Open on this tab, or on this item's page (the story).
	tab: string?,
	item: string?,
}

local EMPLOYEES = { "Pippa", "Cappy", "Prickles" }

local function group(children: Nodes): React.ReactNode
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

-- The item on a card: in 3D (a skin, an employee, an emote or idle on its employee), or the gift for a sticker pack.
local function art(card: VM.OfferCard, live: boolean?): React.ReactNode
	if card.kind == "stickerPack" or card.kind == "sticker" then
		return e(ToonIcon, {
			icon = "shopGift",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromScale(0.7, 0.7),
			drop = 4,
		})
	end
	local vacuum = card.vacuum
	return e(ToonViewport, {
		-- A vacuum's card shows the vacuum on its own.
		employee = if vacuum ~= nil then nil else card.employee,
		vacuum = if vacuum ~= nil then CosmeticRegistry.keyOf(vacuum) else nil,
		skin = card.skinKey,
		framing = "full",
		live = live,
		size = UDim2.fromScale(1, 1),
	})
end

local function offerCard(
	card: VM.OfferCard,
	size: Vector2,
	phone: boolean,
	order: number,
	onOpen: (id: string) -> ()
): React.ReactNode
	local shade = UIToonConstants.rarity(card.rarity)
	local nameSize = if phone then 13 else 24
	local footer = math.floor(nameSize * 2.6)
	local stage: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(shade.hi, shade.base) }),
		art = art(card),
	}
	local face: Nodes = {
		stage = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -footer - 8 - DEPTH.lip),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, stage),
		name = e(ToonText, {
			text = card.name,
			textSize = nameSize,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 12, 1, -DEPTH.lip - math.floor(nameSize * 1.15)),
			size = UDim2.new(0.62, -12, 0, nameSize + 4),
			fit = true,
			zIndex = 3,
		}),
		line = e(ToonText, {
			text = card.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 11 else 16, nameSize - 8),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 12, 1, -DEPTH.lip - 4),
			size = UDim2.new(0.62, -12, 0, nameSize),
			fit = true,
			zIndex = 3,
		}),
		price = if card.state == "owned"
			then nil
			else e(ToonPrice, {
				currency = card.currency,
				amount = card.price,
				was = card.was,
				textSize = nameSize + 2,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -10, 1, -DEPTH.lip - 6),
				size = UDim2.new(0.4, 0, 0, nameSize + 12),
				zIndex = 3,
			}),
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
	}
	if card.state == "owned" then
		local stamp = math.floor(math.min(size.X, size.Y) * 0.5)
		nodes.owned = e(ToonStamp, {
			text = "OWNED",
			size = stamp,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.42),
			zIndex = 6,
		})
	end
	if card.off ~= nil and card.state ~= "owned" then
		nodes.off = e(ToonBurst, {
			text = card.off,
			hue = "coral",
			size = if phone then 40 else 68,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 10, 0, -12),
			zIndex = 7,
		})
	end
	if card.rarity ~= "default" then
		nodes.rarity = e(ToonFlag, {
			text = string.upper(card.rarity),
			rarity = card.rarity,
			tilt = -5,
			textSize = if phone then 10 else 15,
			position = UDim2.fromOffset(-6, -8),
			size = UDim2.fromOffset(if phone then 72 else 130, if phone then 20 else 30),
			zIndex = 7,
		})
	end
	return e("TextButton", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			onOpen(card.id)
		end,
	}, nodes)
end

local function bundleCard(
	bundle: VM.Bundle,
	size: Vector2,
	phone: boolean,
	order: number,
	onBuy: (key: string) -> ()
): React.ReactNode
	-- Tall cards (the Gleam tab) stack the render, the amount and the price; short ones (the Featured row) put the
	-- render on the left and the amount over the price on the right.
	local wide = size.Y < size.X * 0.62
	local amountSize = if phone then 18 else 40
	local pillHeight = if phone then 22 else 44
	local face: Nodes
	if wide then
		local artSize = math.floor((size.Y - DEPTH.drop - DEPTH.lip) * 0.92)
		face = {
			icon = e(ToonIcon, {
				image = bundle.image,
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, 8, 0.5, -DEPTH.lip / 2),
				size = UDim2.fromOffset(artSize, artSize),
				drop = 4,
				greyed = not bundle.available,
			}),
			amount = e(ToonText, {
				text = bundle.amount,
				textSize = amountSize,
				meaning = "white",
				position = UDim2.fromOffset(artSize + 14, 6),
				size = UDim2.new(1, -artSize - 24, 0, amountSize + 4),
				align = "center",
				fit = true,
			}),
			robux = e(ToonButton, {
				variant = if bundle.available then "primary" else "secondary",
				text = if bundle.available then bundle.robux else "Soon",
				textSize = if phone then 12 else 22,
				disabled = not bundle.available,
				small = true,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0, artSize + 14 + math.floor((size.X - artSize - 24) / 2), 1, -DEPTH.lip - 6),
				size = UDim2.fromOffset(math.floor((size.X - artSize - 24) * 0.8), pillHeight),
				onActivated = function()
					onBuy(bundle.key)
				end,
			}),
		}
	else
		face = {
			icon = e(ToonIcon, {
				image = bundle.image,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, if phone then 2 else 6),
				size = UDim2.fromOffset(math.floor(size.Y * 0.5), math.floor(size.Y * 0.5)),
				drop = 4,
				greyed = not bundle.available,
			}),
			amount = e(ToonText, {
				text = bundle.amount,
				textSize = amountSize,
				meaning = "white",
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -DEPTH.lip - pillHeight - 16),
				size = UDim2.new(1, -16, 0, amountSize + 4),
				align = "center",
				fit = true,
			}),
			robux = e(ToonButton, {
				variant = if bundle.available then "primary" else "secondary",
				text = if bundle.available then bundle.robux else "Soon",
				textSize = if phone then 12 else 24,
				disabled = not bundle.available,
				small = true,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -DEPTH.lip - 6),
				size = UDim2.fromOffset(math.floor(size.X * 0.56), pillHeight),
				onActivated = function()
					onBuy(bundle.key)
				end,
			}),
		}
	end
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			hue = "sky",
			radius = 20,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	}
	if bundle.best then
		nodes.best = e(ToonFlag, {
			text = "Just right!",
			hue = "mint",
			tilt = -5,
			textSize = if phone then 11 else 20,
			position = UDim2.fromOffset(-6, -10),
			size = UDim2.fromOffset(if phone then 90 else 170, if phone then 22 else 36),
			zIndex = 6,
		})
	end
	if bundle.bonus ~= nil then
		nodes.bonus = e(ToonBurst, {
			text = bundle.bonus,
			sub = "BONUS",
			hue = "mint",
			size = if phone then 46 else if wide then 84 else 96,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 12, 0, -14),
			zIndex = 5,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, nodes)
end

-- `onBuy` opens Roblox's purchase prompt for a bundle (nothing in the story).
local function bundleRow(
	width: number,
	height: number,
	phone: boolean,
	gap: number,
	bundles: { VM.Bundle },
	onBuy: (key: string) -> ()
): React.ReactNode
	local nodes: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local cardWidth = math.floor((width - (#bundles - 1) * gap) / #bundles)
	for index, bundle in bundles do
		nodes[bundle.key] = bundleCard(bundle, Vector2.new(cardWidth, height), phone, index, onBuy)
	end
	return group(nodes)
end

local function heading(textValue: string, size: number, position: UDim2, width: number): React.ReactNode
	return e(ToonText, {
		text = textValue,
		textSize = size,
		position = position,
		size = UDim2.fromOffset(width, size + 8),
		fit = true,
	})
end

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
	local passInfo = ReactCharm.useAtom(ShopStore.passInfo)
	local bundleInfo = ReactCharm.useAtom(ShopStore.bundleInfo)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local deals = ReactCharm.useAtom(StateSyncClientStore.deals)
	-- Which thing the Featured banner spot shows: the offered one-time deals first, then today's banner.
	local slot, setSlot = React.useState(1)
	local passKeys = MarketplaceRegistry.passKeys()
	local tab, setTab = React.useState(props.tab or "featured")
	local filter, setFilter = React.useState(function(): string?
		return nil
	end)
	local confirming, setConfirming = React.useState(false)
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
	local gap = layout.gap
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
	for _, entry in VM.tabs(#passKeys > 0) do
		table.insert(tabs, { id = entry.id, text = entry.text, icon = entry.icon, soon = entry.soon })
	end
	local offer = if productId ~= nil then ShopRegistry.get(productId) else nil
	local backText = "Back"
	for _, entry in VM.tabs(#passKeys > 0) do
		if entry.id == tab then
			backText = entry.text
		end
	end
	local bar = e(ToonMenuBar, {
		title = "SHOP",
		icon = "shopGift",
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
			onBuy = function()
				setConfirming(true)
			end,
			onGetMore = function()
				local back = VM.returnTo(offer, owns, balances, tab)
				setTab("gleam")
				if preview == nil then
					ShopStore.close()
					ShopStore.setReturn(back)
				end
			end,
		})
		if confirming then
			local dialog: Nodes = {
				question = e(ToonText, {
					text = product.confirm,
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
						setConfirming(false)
						if preview == nil then
							-- A yes to "Use 30 Gleam" is a yes to at most that much Gleam for the rest.
							local gleam = if product.button.kind == "topup" then product.button.gleam else nil
							-- The price the player saw: the server never charges more.
							local seen = ShopPriceRules.forPlayer(offer, owns, balances.now).price
							ShopServiceClient:requestBuy(offer.id, gleam, seen)
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
						setConfirming(false)
					end,
				}),
			}
			modal = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLOR.ink,
				BackgroundTransparency = 0.4,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 20,
			}, {
				panel = e(ToonSurface, {
					hue = "cream",
					pattern = "rings",
					radius = 28,
					anchor = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
					size = UDim2.fromOffset(if phone then 380 else 640, if phone then 170 else 300),
					zIndex = 21,
					children = dialog,
				}),
			})
		end
	elseif tab == "skins" then
		local chips: Nodes = {
			list = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		local options: { string } = { "All" }
		for _, name in EMPLOYEES do
			table.insert(options, name)
		end
		for index, name in options do
			local value: string? = if name == "All" then nil else name
			chips[name] = e(ToonButton, {
				variant = "grape",
				text = name,
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
			balances = { gloom = gloom, gleam = balances.gleam },
			layout = layout,
			preview = preview ~= nil,
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
				Size = UDim2.new(1, 0, 0, math.floor(content.height * 0.6)),
				BackgroundTransparency = 1,
			}, {
				row = bundleRow(content.width, math.floor(content.height * 0.6), phone, gap + 10, bundles, buyBundle),
			}),
		})
	else
		-- Featured: the banner, Today's picks, the Gleam row.
		local live = ShopRotationUtils.live(ShopRegistry.all(), now)
		local bannerWidth = math.floor(content.width * 0.47)
		-- On a phone the Gleam row is left to the Gleam tab: the banner and the picks take the whole height.
		local topHeight = if phone then content.height else math.floor(content.height * 0.64)
		local nodes: Nodes = {}
		local featured = live.featured
		local dealIds: { DealConstants.DealId } = if preview ~= nil then {} else DealRules.offeredList(deals, owns)
		local spots = #dealIds + (if featured ~= nil then 1 else 0)
		local spot = ((slot - 1) % math.max(1, spots)) + 1
		local onNext = if spots > 1
			then function()
				setSlot(spot + 1)
			end
			else nil
		local dealId = dealIds[spot]
		if dealId ~= nil then
			nodes.banner = e(DealBanner, {
				banner = DealViewModel.banner(dealId, DealServiceClient:productReady(dealId)),
				phone = phone,
				textSize = size,
				headingSize = layout.headingSize,
				size = UDim2.fromOffset(bannerWidth, topHeight),
				onBuy = function()
					DealServiceClient:buy(dealId, nil)
				end,
				onNext = onNext,
			})
		elseif featured ~= nil then
			local product = VM.product(featured, owns, balances)
			local card = product.card
			local nameSize = math.floor(layout.headingSize * (if phone then 1 else 1.4))
			local priced: Nodes = {
				price = e(ToonPrice, {
					currency = card.currency,
					amount = card.price,
					was = card.was,
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
					text = "Today's banner",
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
						open(featured.id)
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
				timer = e(ToonPill, {
					text = `Changes in {VM.timer(live.nextRotation - now)}`,
					hue = "night",
					textSize = size - 4,
					anchor = Vector2.new(0, 1),
					position = UDim2.new(0, if phone then 12 else 28, 1, -(if phone then 10 else 24)),
					size = UDim2.fromOffset(if phone then 150 else 260, if phone then 24 else 44),
					zIndex = 4,
				}),
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
		-- Today's picks: 3 x 2.
		local picksX = bannerWidth + gap + 10
		local picksWidth = content.width - picksX
		local headingSize = math.floor(layout.headingSize * 0.75)
		-- Desktop: a 3 x 2 grid. Phone: one row of bigger cards that scrolls sideways.
		-- PICK_PAD keeps the rarity flags (they stick out over the cards' top-left corners) inside the list.
		local cellHeight = if phone
			then topHeight - headingSize - 30 - PICK_PAD
			else math.floor((topHeight - headingSize - 20 - gap - PICK_PAD) / 2)
		local cellWidth = if phone
			then math.floor(cellHeight * 0.8)
			else math.floor((picksWidth - 2 * gap - PICK_PAD) / 3)
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
			grid[pick.id] =
				offerCard(VM.card(pick, owns, balances), Vector2.new(cellWidth, cellHeight), phone, index, open)
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
					bundles,
					buyBundle
				),
			})
		end
		body = group(nodes)
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
				body = e("Frame", {
					Position = UDim2.fromOffset(content.x, content.y),
					Size = UDim2.fromOffset(content.width, content.height),
					BackgroundTransparency = 1,
				}, { content = body }),
				modal = modal,
			},
		}),
	}
	-- An open item's page takes its rarity's look (ShopRarityLookViewModel); the lists keep the shop's own colours.
	local look = if offer ~= nil then ShopRarityLookViewModel.look(VM.card(offer, owns, balances).rarity) else nil
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
		see = 0.2,
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
