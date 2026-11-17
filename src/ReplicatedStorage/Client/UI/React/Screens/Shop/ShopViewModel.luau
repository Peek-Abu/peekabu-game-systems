--!strict
--[=[
	ShopViewModel: everything the Shop screens show, from the offers (ShopRegistry / today's ShopRotationUtils.live),
	the catalogue and what the player owns and has: offer cards (name, "Skin · Pippa", price, owned / affordable /
	too dear), the buy button (the price with any crossed-out price, short or not; Owned; "Use 30 Gleam" when Gleam pays the rest
	of a Credits price; short, it names the smallest Gleam pack that covers the rest, which the page opens straight
	away), the Yes/No question before spending, where to come back to after buying Gleam (returnTo, bestBundle), the product page
	(lore, styles, what's inside with each extra's own price, an employee's ability and five display stats), the Skins tab list, the Gleam bundles, the Passes cards
	(every registered game pass: its words from ShopConstants.PASS_COPY, its price and icon as Roblox reported them,
	Owned once bought), the countdowns, and a refused buy in kid words. Nothing here is per item: a new offer shows up by itself.
	The offer card (ShopCardViewModel), the Gleam bundles (ShopBundleViewModel) and the Hire / Skins lists
	(ShopListViewModel) are split out; this module still exposes them under its own name.

	@class ShopViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
local ShopRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopRules)
local ShopTopUpRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopTopUpRules)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local ShopBundleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopBundleViewModel)
local ShopCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopCardViewModel)
local ShopListViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopListViewModel)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryViewModel)

type Offer = ShopTypes.Offer
type Owns = (id: string) -> boolean

-- What the player has, and `now`: the server time prices are worked out at (sales; nil: regular prices only). `acorns`:
-- a live event's money (absent reads 0).
export type Balances = ShopCardViewModel.Balances
export type CardState = ShopCardViewModel.CardState
export type OfferCard = ShopCardViewModel.OfferCard
export type SkinFilter = ShopListViewModel.SkinFilter
export type Bundle = ShopBundleViewModel.Bundle

-- A game pass card: what its button says follows `state` (loading the price, on sale, owned, not for sale).
export type PassState = "loading" | "buy" | "owned" | "unavailable"
export type PassCard = {
	key: string,
	name: string,
	line: string,
	-- The pass's own icon (rbxassetid), once Roblox reported it.
	icon: string?,
	state: PassState,
	button: string,
}
-- One colour style's chip on a product page: a short name and its colours (the fur, then the outfit).
export type StyleChip = { name: string, swatch: { Color3 } }

export type Button = {
	text: string,
	enabled: boolean,
	-- "topup": short on Credits, and Gleam pays the rest (`gleam` of it) after a yes.
	kind: "buy" | "owned" | "short" | "topup",
	currency: ShopTypes.Currency,
	price: string,
	-- The crossed-out price on the button (VM.card's `was`); nil when there is none.
	was: string?,
	-- "topup": the Gleam for the rest. "short": the Gleam balance it needs (the price, or the rest of a Credits price).
	gleam: number?,
	-- "short": the Gleam pack to open (VM.bestBundle of what is missing; owner 11-14: no "Need 300 more" line, a press
	-- opens Roblox's purchase prompt for it and comes back to the item).
	pack: string?,
}

export type Inside = { id: string, name: string, kind: string, alone: string? }

export type Product = {
	card: OfferCard,
	rarityText: string,
	line: string,
	lore: string,
	-- The lore is the employee speaking (the item's choice): drawn with a quote mark; otherwise a book.
	quote: boolean,
	-- The colour styles: a chip each (name and colours) that swaps the preview, only for a skin with real styles.
	styles: { visible: boolean, count: number, text: string, chips: { StyleChip } },
	inside: { Inside },
	-- An employee's hire page: their five display stats (the same rows as the About tab); empty for anything else.
	stats: { InventoryViewModel.StatRow },
	-- An employee's hire page: their ability card (`icon` names its render, UIAssets.iconImage); nil for anything else.
	ability: { name: string, line: string, cooldown: number, icon: string }?,
	button: Button,
	confirm: string,
}

local KIND_WORD = ShopCardViewModel.KIND_WORD
local main = ShopCardViewModel.main
local bundleOf = ShopCardViewModel.bundleOf
local bundleEmployee = ShopCardViewModel.bundleEmployee
local balanceOf = ShopCardViewModel.balanceOf

local VM = {}

VM.card = ShopCardViewModel.card
VM.off = ShopCardViewModel.off
VM.bestBundle = ShopBundleViewModel.bestBundle
VM.bundles = ShopBundleViewModel.bundles
VM.featuredBundles = ShopBundleViewModel.featuredBundles
VM.BUNDLE_ICON_MIN = ShopBundleViewModel.BUNDLE_ICON_MIN
VM.FEATURED_BUNDLES = ShopBundleViewModel.FEATURED_BUNDLES
VM.hires = ShopListViewModel.hires
VM.skins = ShopListViewModel.skins
VM.skinFilters = ShopListViewModel.skinFilters
VM.VACUUMS = ShopListViewModel.VACUUMS

VM.SCENE = "shop"

-- The Shop's tabs; Passes shows greyed ("Soon") until a game pass is registered (`hasPasses`). A live limited-time
-- event's tab comes first (owner Y1).
function VM.tabs(
	hasPasses: boolean,
	event: { short: string }?
): { { id: string, text: string, icon: UIAssets.ToonIcon?, soon: boolean } }
	local tabs: { { id: string, text: string, icon: UIAssets.ToonIcon?, soon: boolean } } = {}
	if event ~= nil then
		table.insert(tabs, { id = "event", text = event.short, icon = "acorns", soon = false })
	end
	local fixed: { { id: string, text: string, icon: UIAssets.ToonIcon?, soon: boolean } } = {
		{ id = "featured", text = "Featured", icon = "featured", soon = false },
		{ id = "hires", text = "Hire", icon = "jobs", soon = false },
		{ id = "skins", text = "Skins", icon = "pippaSkins", soon = false },
		{ id = "gleam", text = "Gleam", icon = "gleam", soon = false },
		{ id = "lockers", text = "Lockers", icon = "locker", soon = false },
		{ id = "passes", text = "Passes", soon = not hasPasses },
	}
	for _, entry in fixed do
		table.insert(tabs, entry)
	end
	return tabs
end

-- "Sale ends in 6h 12m" while a sale price runs; nil otherwise.
function VM.saleText(saleEnds: number?, now: number?): string?
	if saleEnds == nil or now == nil or now >= saleEnds then
		return nil
	end
	return `Sale ends in {VM.timer(saleEnds - now)}`
end

-- The page's hero plays its menu reaction when the page opens: not on a vacuum's page (seen from behind) or an emote's.
function VM.reacts(card: OfferCard): boolean
	return card.vacuum == nil and card.emote == nil
end

-- How a short player pays the rest in Gleam (ShopTopUpRules); nil for a Gleam price or when not short.
local function topUpOf(offer: Offer, balances: Balances): ShopTopUpRules.Plan?
	-- Gleam never pays the rest of a Gleam price, or of an event's money (earned only, owner R2).
	if offer.currency == "gleam" or offer.currency == "acorns" then
		return nil
	end
	return ShopTopUpRules.plan(offer.currency, offer.price, balanceOf(offer, balances))
end

-- The Gleam balance the player needs for this offer: its price in Gleam, or the Gleam for the rest of a Credits price.
local function gleamNeeded(offer: Offer, balances: Balances): number
	if offer.currency == "gleam" then
		return offer.price
	end
	local plan = topUpOf(offer, balances)
	return if plan ~= nil then plan.gleam else 0
end

function VM.button(listed: Offer, owns: Owns, balances: Balances): Button
	local offer = ShopPriceRules.forPlayer(listed, owns, balances.now)
	local price = ToonStyleViewModel.grouped(offer.price)
	if ShopRules.owned(offer, owns) then
		return { text = "Owned", enabled = false, kind = "owned", currency = offer.currency, price = price }
	end
	local missing = ShopRules.missing(offer, balanceOf(offer, balances))
	if missing > 0 then
		local plan = topUpOf(offer, balances)
		if plan ~= nil and balances.gleam >= plan.gleam then
			return {
				text = `Use {ToonStyleViewModel.grouped(plan.gleam)} Gleam`,
				enabled = true,
				kind = "topup",
				currency = offer.currency,
				price = price,
				gleam = plan.gleam,
			}
		end
		local gleam = gleamNeeded(offer, balances)
		local canPay = offer.currency == "gleam" or plan ~= nil
		return {
			-- The price, as if they could buy it: the press opens the Gleam pack, then comes back here.
			text = price,
			enabled = canPay,
			kind = "short",
			currency = offer.currency,
			price = price,
			was = if offer.was ~= nil then ToonStyleViewModel.grouped(offer.was) else nil,
			gleam = gleam,
			pack = if canPay then VM.bestBundle(gleam - balances.gleam) else nil,
		}
	end
	return {
		text = price,
		enabled = true,
		kind = "buy",
		currency = offer.currency,
		price = price,
		was = if offer.was ~= nil then ToonStyleViewModel.grouped(offer.was) else nil,
	}
end

-- The Yes/No question before spending; with `balances`, a short Credits price asks about the Gleam for the rest.
function VM.confirm(offer: Offer, balances: Balances?): string
	local item = main(offer)
	local name = if item ~= nil then item.name else offer.id
	local hire = item ~= nil and item.kind == "employee"
	local plan = if balances ~= nil then topUpOf(offer, balances) else nil
	if plan ~= nil and balances ~= nil then
		local missing = ToonStyleViewModel.grouped(offer.price - math.max(0, balanceOf(offer, balances)))
		local gleam = ToonStyleViewModel.grouped(plan.gleam)
		return `You need {missing} more Credits. Use {gleam} Gleam to {if hire then "hire" else "buy"} {name}?`
	end
	local verb = if hire then "Hire" else "Buy"
	local currency = if offer.currency == "gleam" then "Gleam" else "Credits"
	return `{verb} {name} for {ToonStyleViewModel.grouped(offer.price)} {currency}?`
end

--[=[
	Where the Shop goes back to once the player has bought the Gleam they went for: this offer's page (opened from
	`tab`), when their Gleam reaches what it needs (the price, or the rest of a Credits price). Copied from the shops
	that do this well: say exactly how much more, point at the smallest bundle that covers it, and land back on the
	item with the Yes/No question already up, so finishing takes one tap.
]=]
function VM.returnTo(listed: Offer, owns: Owns, balances: Balances, tab: string): ShopStore.Return
	local offer = ShopPriceRules.forPlayer(listed, owns, balances.now)
	local item = main(offer)
	return {
		offer = offer.id,
		tab = tab,
		gleam = gleamNeeded(offer, balances),
		name = if item ~= nil then item.name else offer.id,
	}
end

function VM.returnReady(back: ShopStore.Return, gleam: number): boolean
	return gleam >= back.gleam
end

-- The way back from the Lockers tab: once the player has a Gleam key's worth, or (already enough, e.g. for an item a
-- restricted player buys directly) after any Gleam buy.
function VM.lockerReturn(gleam: number): ShopStore.Return
	local key = LockerConstants.LOCKERS.gleam.keyPrice
	return {
		offer = nil,
		tab = "lockers",
		gleam = if gleam < key then key else gleam + 1,
		name = "a Gleam key",
	}
end

-- The Gleam tab's line while the player is getting Gleam for something.
function VM.returnNote(back: ShopStore.Return, gleam: number): string
	local missing = back.gleam - gleam
	if missing <= 0 then
		return `You have enough for {back.name}!`
	end
	return `Get {ToonStyleViewModel.grouped(missing)} more Gleam for {back.name}!`
end

function VM.product(listed: Offer, owns: Owns, balances: Balances): Product
	local offer = ShopPriceRules.forPlayer(listed, owns, balances.now)
	local item = main(offer)
	local card = VM.card(offer, owns, balances)
	-- What it grants: the item, or every item of the bundle (the hero first, the rest with their own price alone).
	local inside: { Inside } = {}
	local bundle = bundleOf(offer)
	for index, id in offer.items do
		local part = CosmeticRegistry.get(id)
		if part ~= nil then
			local price = part.price
			table.insert(inside, {
				id = part.id,
				name = part.name,
				kind = KIND_WORD[part.kind],
				alone = if index > 1 and price ~= nil then `alone {ToonStyleViewModel.grouped(price)}` else nil,
			})
		end
	end
	local bundleWho = if bundle ~= nil then bundleEmployee(bundle) else nil
	local who = if bundle ~= nil
		then (if bundleWho ~= nil then ` for {bundleWho}` else "")
		elseif item ~= nil and item.employee ~= nil then ` for {item.employee}`
		elseif item ~= nil and item.kind == "vacuum" then " for every employee"
		else ""
	-- An idle is said plainly: it is shown on the Classic skin and comes without any skin.
	local what = if bundle ~= nil
		then `Bundle{who}`
		elseif item ~= nil and item.kind == "employee" then "A new employee"
		elseif item ~= nil and item.kind == "idle" then `Idle only (no skin){who}`
		elseif item ~= nil then `{KIND_WORD[item.kind]}{who}`
		else ""
	local profile = if item ~= nil and item.kind == "employee" then EmployeeProfileRegistry.get(item.id) else nil
	local chips: { StyleChip } = {}
	if item ~= nil and item.kind == "skin" then
		for _, style in EmployeeSkinRules.stylesFor(item.employee, CosmeticRegistry.keyOf(item.id)) do
			table.insert(chips, { name = style.name, swatch = style.swatch })
		end
	end
	return {
		card = card,
		rarityText = if card.rarity == "default" then "CLASSIC" else string.upper(card.rarity),
		line = if item ~= nil and item.kind == "employee" then what else `{what} · cosmetic only`,
		lore = if bundle ~= nil then bundle.lore elseif item ~= nil then item.lore else "",
		quote = bundle == nil and item ~= nil and item.quote == true,
		styles = {
			visible = #chips > 0,
			count = #chips,
			text = `STYLES  ·  all {#chips} come with it`,
			chips = chips,
		},
		inside = inside,
		stats = if profile ~= nil and item ~= nil then InventoryViewModel.stats(item.id) else {},
		ability = if profile ~= nil
			then {
				name = profile.ability.name,
				line = profile.ability.line,
				cooldown = profile.ability.cooldown,
				icon = profile.ability.icon,
			}
			else nil,
		button = VM.button(offer, owns, balances),
		confirm = VM.confirm(offer, balances),
	}
end

--[=[
	The page parts (VM.product) for any one cosmetic item, sold in the Shop or not (owner, 2026-11-14: a Locker item's
	page uses the same parts as the Shop's: rarity, line, lore, styles). It is described as a view-only offer of that one
	item that is never sold; the caller shows its own button instead of `button`. nil for an unknown id.
]=]
function VM.itemProduct(id: string, owns: Owns, balances: Balances): Product?
	local item = CosmeticRegistry.get(id)
	if item == nil then
		return nil
	end
	local viewOnly: Offer = { id = item.id, items = { item.id }, currency = "gleam", price = 0, pool = "picks" }
	return VM.product(viewOnly, owns, { gleam = balances.gleam, credits = balances.credits })
end

-- The Passes tab's cards, one per pass key (in `keys`' order): its words (PASS_COPY, else its Dashboard name), its
-- icon and price from `infos`, Owned when `owns(key)`.
function VM.passes(
	keys: { string },
	infos: { [string]: ShopStore.PassInfo },
	owns: (key: string) -> boolean
): { PassCard }
	local cards: { PassCard } = {}
	for _, key in keys do
		local info = infos[key]
		local copy = ShopConstants.PASS_COPY[key]
		local state: PassState
		local button: string
		local price = if info ~= nil then info.price else nil
		if owns(key) then
			state, button = "owned", "Owned"
		elseif info == nil then
			state, button = "loading", "..."
		elseif not info.forSale or price == nil then
			state, button = "unavailable", "Soon"
		else
			state, button = "buy", `R$ {ToonStyleViewModel.grouped(price)}`
		end
		table.insert(cards, {
			key = key,
			name = if copy ~= nil then copy.name elseif info ~= nil and info.name ~= nil then info.name else key,
			line = if copy ~= nil then copy.line else "",
			icon = if info ~= nil then info.icon else nil,
			state = state,
			button = button,
		})
	end
	return cards
end

-- "2d 14h", "6h 12m", "12m".
function VM.timer(seconds: number): string
	local left = math.max(0, math.floor(seconds))
	local days = left // 86400
	local hours = (left % 86400) // 3600
	local minutes = (left % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

function VM.resultText(reason: string): string?
	if reason == "" then
		return nil
	elseif reason == "short" then
		return "Not enough yet!"
	elseif reason == "owned" then
		return "You already have it!"
	elseif reason == "locked during a shift" then
		return "The Shop opens at the depot."
	elseif reason == "top up changed" or reason == "price changed" then
		return "The price changed. Look again!"
	end
	return "That didn't work. Try again!"
end

return VM
