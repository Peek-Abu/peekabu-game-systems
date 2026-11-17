--!strict
--[=[
	ShopCardViewModel: an offer's card in the Shop (name, "Skin · Pippa", price with any crossed-out price and percent
	off, owned / affordable / too dear, who to show in 3D), plus the small lookups every Shop view model shares (the
	offer's main item, a bundle and whose it is, the balance an offer is paid from). Pure. Split out of ShopViewModel,
	which still exposes `card` and `off` under its own name.

	@class ShopCardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
local ShopRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopRules)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Offer = ShopTypes.Offer
type Owns = (id: string) -> boolean

-- What the player has, and `now`: the server time prices are worked out at (sales; nil: regular prices only). `acorns`:
-- a live event's money (absent reads 0).
export type Balances = { gleam: number, credits: number, acorns: number?, now: number? }

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
	-- A real, higher price to cross out (a bundle's items alone, the price before a sale); nil when there is none.
	was: string?,
	-- "-20%" next to a crossed-out price; nil when there is none.
	off: string?,
	-- When a sale price ends (server time); nil when it is the regular price.
	saleEnds: number?,
	state: CardState,
	-- Who to show in 3D (the item's employee, the employee itself, or Pippa for a shared item).
	employee: string,
	-- The EmployeeRegistry skin key for a skin.
	skinKey: string?,
	-- A vacuum (Cosmetic id): its card shows the vacuum alone, its page shows it on your employee.
	vacuum: string?,
	-- An emote (Cosmetic id): its page loops the emote on its employee.
	emote: string?,
	-- An idle (the item's key after the dot): it plays on its employee in the Classic skin, never the skin it came
	-- from, so nobody thinks they are buying the skin (owner, 2026-11-13).
	idle: string?,
}

local KIND_WORD: { [CosmeticTypes.Kind]: string } = {
	employee = "Employee",
	skin = "Skin",
	idle = "Idle",
	emote = "Emote",
	stickerPack = "Sticker pack",
	sticker = "Sticker",
	vacuum = "Vacuum",
}

local ShopCardViewModel = {}

ShopCardViewModel.KIND_WORD = KIND_WORD

function ShopCardViewModel.main(offer: Offer): CosmeticTypes.Item?
	return CosmeticRegistry.get(offer.items[1])
end

-- The bundle an offer sells (nil for a single item's offer).
function ShopCardViewModel.bundleOf(offer: Offer): CosmeticTypes.Bundle?
	return CosmeticBundleRegistry.get(offer.id)
end

-- Whose a bundle is: the one employee all its items belong to, else nil (a bundle can mix employees).
function ShopCardViewModel.bundleEmployee(bundle: CosmeticTypes.Bundle): string?
	local who: string? = nil
	for _, id in bundle.items do
		local item = CosmeticRegistry.get(id)
		local employee = if item ~= nil then item.employee else nil
		if employee ~= nil then
			if who ~= nil and who ~= employee then
				return nil
			end
			who = employee
		end
	end
	return who
end

function ShopCardViewModel.balanceOf(offer: Offer, balances: Balances): number
	if offer.currency == "gleam" then
		return balances.gleam
	elseif offer.currency == "acorns" then
		return balances.acorns or 0
	end
	return balances.credits
end

local function lineOf(item: CosmeticTypes.Item): string
	local word = KIND_WORD[item.kind]
	if item.kind == "employee" or item.kind == "stickerPack" then
		return word
	elseif item.kind == "vacuum" then
		return `{word} · every employee`
	end
	return `{word} · {item.employee or "any employee"}`
end

function ShopCardViewModel.card(listed: Offer, owns: Owns, balances: Balances): OfferCard
	local offer = ShopPriceRules.forPlayer(listed, owns, balances.now)
	local item = ShopCardViewModel.main(offer)
	local state: CardState = if ShopRules.owned(offer, owns)
		then "owned"
		elseif ShopCardViewModel.balanceOf(offer, balances) >= offer.price then "afford"
		else "short"
	local employee = if item == nil
		then "Pippa"
		elseif item.kind == "employee" then item.id
		else item.employee or "Pippa"
	-- A bundle's card is the bundle's (its name and rarity), drawn with its first item (the hero).
	local bundle = ShopCardViewModel.bundleOf(offer)
	local bundleWho = if bundle ~= nil then ShopCardViewModel.bundleEmployee(bundle) else nil
	return {
		id = offer.id,
		name = if bundle ~= nil then bundle.name elseif item ~= nil then item.name else offer.id,
		line = if bundle ~= nil
			then (if bundleWho ~= nil then `Bundle · {bundleWho}` else "Bundle")
			elseif item ~= nil then lineOf(item)
			else "",
		kind = if item ~= nil then item.kind else "skin",
		rarity = if bundle ~= nil then bundle.rarity elseif item ~= nil then item.rarity else "default",
		currency = offer.currency,
		price = ToonStyleViewModel.grouped(offer.price),
		was = if offer.was ~= nil then ToonStyleViewModel.grouped(offer.was) else nil,
		off = ShopCardViewModel.off(offer.price, offer.was),
		saleEnds = offer.saleEnds,
		state = state,
		employee = employee,
		skinKey = if item ~= nil and item.kind == "skin" then string.match(item.id, "^[^%.]+%.(.+)$") else nil,
		vacuum = if item ~= nil and item.kind == "vacuum" then item.id else nil,
		emote = if item ~= nil and item.kind == "emote" then item.id else nil,
		idle = if item ~= nil and item.kind == "idle" and bundle == nil then CosmeticRegistry.keyOf(item.id) else nil,
	}
end

-- "-20%": how much less than the crossed-out price, rounded to a whole percent; nil when nothing is crossed out.
function ShopCardViewModel.off(price: number, was: number?): string?
	if was == nil or was <= price then
		return nil
	end
	return `-{math.floor((was - price) / was * 100 + 0.5)}%`
end

return ShopCardViewModel
