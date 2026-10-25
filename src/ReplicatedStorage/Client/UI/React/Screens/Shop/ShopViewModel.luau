--!strict
--[=[
	ShopViewModel: everything the Shop screens show, from the offers (ShopRegistry / today's ShopRotationUtils.live),
	the catalogue and what the player owns and has: offer cards (name, "Skin · Pippa", price, owned / affordable /
	too dear), the buy button (Buy / Owned / "Need 300 more"), the Yes/No question before spending, the product page
	(lore, styles, what's inside with each extra's own price), the Skins tab list, the Gleam bundles, the countdowns,
	and a refused buy in kid words. Nothing here is per item: a new offer shows up by itself.

	@class ShopViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopRules)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Offer = ShopTypes.Offer
type Owns = (id: string) -> boolean

export type Balances = { gleam: number, credits: number }
export type CardState = "owned" | "afford" | "short"

export type OfferCard = {
	id: string,
	name: string,
	-- "Skin · Pippa", "Idle · any employee", "Sticker pack", "Employee".
	line: string,
	kind: CosmeticTypes.Kind,
	rarity: CosmeticTypes.Rarity,
	currency: ShopTypes.Currency,
	price: string,
	state: CardState,
	-- Who to show in 3D (the item's employee, the employee itself, or Pippa for a shared item).
	employee: string,
	-- The EmployeeRegistry skin key for a skin.
	skinKey: string?,
}

export type Button = {
	text: string,
	enabled: boolean,
	kind: "buy" | "owned" | "short",
	currency: ShopTypes.Currency,
	price: string,
}

export type Inside = { id: string, name: string, kind: string, alone: string? }

export type Product = {
	card: OfferCard,
	rarityText: string,
	line: string,
	lore: string,
	-- The lore in a quote box: only for rarer items (Epic and up).
	quote: boolean,
	styles: { visible: boolean, count: number },
	inside: { Inside },
	button: Button,
	confirm: string,
}

export type Bundle = {
	key: string,
	amount: string,
	robux: string,
	bonus: string?,
	icon: UIAssets.ToonIcon,
	available: boolean,
}

local KIND_WORD: { [CosmeticTypes.Kind]: string } = {
	employee = "Employee",
	skin = "Skin",
	idle = "Idle",
	emote = "Emote",
	stickerPack = "Sticker pack",
	sticker = "Sticker",
}

local RARITY_RANK: { [CosmeticTypes.Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

-- Lore gets the quote box from Epic up (rarer items speak; the rest have a plain line).
local QUOTE_RANK = 3

local VM = {}

VM.SCENE = "shop"

-- The Shop's tabs; Lockers and Passes show greyed ("Soon") until they are built.
function VM.tabs(): { { id: string, text: string, icon: UIAssets.ToonIcon?, soon: boolean } }
	return {
		{ id = "featured", text = "Featured", icon = "shopGift", soon = false },
		{ id = "skins", text = "Skins", icon = "pippaHappy", soon = false },
		{ id = "gleam", text = "Gleam", icon = "gleam", soon = false },
		{ id = "lockers", text = "Lockers", icon = "locker", soon = true },
		{ id = "passes", text = "Passes", soon = true },
	}
end

local function main(offer: Offer): CosmeticTypes.Item?
	return CosmeticRegistry.get(offer.items[1])
end

local function balanceOf(offer: Offer, balances: Balances): number
	return if offer.currency == "gleam" then balances.gleam else balances.credits
end

local function lineOf(item: CosmeticTypes.Item): string
	local word = KIND_WORD[item.kind]
	if item.kind == "employee" or item.kind == "stickerPack" then
		return word
	end
	return `{word} · {item.employee or "any employee"}`
end

function VM.card(offer: Offer, owns: Owns, balances: Balances): OfferCard
	local item = main(offer)
	local state: CardState = if ShopRules.owned(offer, owns)
		then "owned"
		elseif balanceOf(offer, balances) >= offer.price then "afford"
		else "short"
	local employee = if item == nil
		then "Pippa"
		elseif item.kind == "employee" then item.id
		else item.employee or "Pippa"
	return {
		id = offer.id,
		name = if item ~= nil then item.name else offer.id,
		line = if item ~= nil then lineOf(item) else "",
		kind = if item ~= nil then item.kind else "skin",
		rarity = if item ~= nil then item.rarity else "default",
		currency = offer.currency,
		price = ToonStyleViewModel.grouped(offer.price),
		state = state,
		employee = employee,
		skinKey = if item ~= nil and item.kind == "skin" then string.match(item.id, "^[^%.]+%.(.+)$") else nil,
	}
end

function VM.button(offer: Offer, owns: Owns, balances: Balances): Button
	local price = ToonStyleViewModel.grouped(offer.price)
	if ShopRules.owned(offer, owns) then
		return { text = "Owned", enabled = false, kind = "owned", currency = offer.currency, price = price }
	end
	local missing = ShopRules.missing(offer, balanceOf(offer, balances))
	if missing > 0 then
		return {
			text = `Need {ToonStyleViewModel.grouped(missing)} more`,
			-- Short on Gleam: the button leads to the Gleam tab. Credits are earned on shifts.
			enabled = offer.currency == "gleam",
			kind = "short",
			currency = offer.currency,
			price = price,
		}
	end
	return { text = price, enabled = true, kind = "buy", currency = offer.currency, price = price }
end

function VM.confirm(offer: Offer): string
	local item = main(offer)
	local name = if item ~= nil then item.name else offer.id
	local verb = if item ~= nil and item.kind == "employee" then "Hire" else "Buy"
	local currency = if offer.currency == "gleam" then "Gleam" else "Credits"
	return `{verb} {name} for {ToonStyleViewModel.grouped(offer.price)} {currency}?`
end

function VM.product(offer: Offer, owns: Owns, balances: Balances): Product
	local item = main(offer)
	local card = VM.card(offer, owns, balances)
	local inside: { Inside } = {}
	local bundle = if item ~= nil then item.bundle else nil
	if item ~= nil then
		table.insert(inside, { id = item.id, name = item.name, kind = KIND_WORD[item.kind] })
		if bundle ~= nil then
			for _, id in bundle do
				local extra = CosmeticRegistry.get(id)
				if extra ~= nil then
					table.insert(inside, {
						id = extra.id,
						name = extra.name,
						kind = KIND_WORD[extra.kind],
						alone = if extra.price ~= nil then `alone {ToonStyleViewModel.grouped(extra.price)}` else nil,
					})
				end
			end
		end
	end
	local who = if item ~= nil and item.employee ~= nil then ` for {item.employee}` else ""
	local what = if bundle ~= nil and #bundle > 0
		then `Bundle{who}`
		elseif item ~= nil and item.kind == "employee" then "A new employee"
		elseif item ~= nil then `{KIND_WORD[item.kind]}{who}`
		else ""
	local styles = if item ~= nil then item.styles or 1 else 1
	return {
		card = card,
		rarityText = if card.rarity == "default" then "CLASSIC" else string.upper(card.rarity),
		line = if item ~= nil and item.kind == "employee" then what else `{what} · cosmetic only`,
		lore = if item ~= nil then item.lore else "",
		quote = RARITY_RANK[card.rarity] >= QUOTE_RANK,
		styles = { visible = styles > 1, count = styles },
		inside = inside,
		button = VM.button(offer, owns, balances),
		confirm = VM.confirm(offer),
	}
end

-- Every offer except employees (they are hired on the pick screen and the Crew tab), filtered to one employee's
-- items and the shared ones; what you can buy first (by rarity, highest first), what you own last.
function VM.skins(owns: Owns, balances: Balances, employee: string?): { OfferCard }
	local cards: { OfferCard } = {}
	for _, offer in ShopRegistry.all() do
		local item = main(offer)
		if
			item ~= nil
			and item.kind ~= "employee"
			and (employee == nil or item.employee == nil or item.employee == employee)
		then
			table.insert(cards, VM.card(offer, owns, balances))
		end
	end
	table.sort(cards, function(a: OfferCard, b: OfferCard): boolean
		local ownedA, ownedB = a.state == "owned", b.state == "owned"
		if ownedA ~= ownedB then
			return ownedB
		end
		if RARITY_RANK[a.rarity] ~= RARITY_RANK[b.rarity] then
			return RARITY_RANK[a.rarity] > RARITY_RANK[b.rarity]
		end
		return a.id < b.id
	end)
	return cards
end

function VM.bundles(): { Bundle }
	local list: { Bundle } = {}
	for _, bundle in ShopConstants.BUNDLES do
		local icon: UIAssets.ToonIcon = if bundle.icon == "gleamBucket"
			then "gleamBucket"
			elseif bundle.icon == "gleamCrate" then "gleamCrate"
			elseif bundle.icon == "gleamTruck" then "gleamTruck"
			else "gleamPile"
		table.insert(list, {
			key = bundle.key,
			amount = ToonStyleViewModel.grouped(bundle.gleam),
			robux = `R$ {bundle.robux}`,
			bonus = if bundle.bonus > 0 then `+{bundle.bonus}%` else nil,
			icon = icon,
			available = ShopConstants.PRODUCT_IDS[bundle.key] ~= nil,
		})
	end
	return list
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
	end
	return "That didn't work. Try again!"
end

return VM
