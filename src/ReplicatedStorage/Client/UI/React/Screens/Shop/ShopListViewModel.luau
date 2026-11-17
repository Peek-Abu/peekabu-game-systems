--!strict
--[=[
	ShopListViewModel: the Shop's card lists: the Hire tab (every employee for sale, cheapest first, hired last) and the
	Skins tab (every other offer, the filters above it, what you can buy first by rarity, what you own last). Pure. Split
	out of ShopViewModel, which still exposes `hires`, `skins`, `skinFilters` and `VACUUMS` under its own name.

	@class ShopListViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopCardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shop.ShopCardViewModel)

type Owns = (id: string) -> boolean
type Balances = ShopCardViewModel.Balances
type OfferCard = ShopCardViewModel.OfferCard

-- One Skins-tab filter: its words and what it keeps (nil = everything).
export type SkinFilter = { text: string, value: string? }

local RARITY_RANK: { [CosmeticTypes.Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

local ShopListViewModel = {}

-- The Hire tab: every employee for sale (a new hire shows up by itself), cheapest first, the ones already hired last.
function ShopListViewModel.hires(owns: Owns, balances: Balances): { OfferCard }
	local cards: { OfferCard } = {}
	local prices: { [string]: number } = {}
	for _, offer in ShopRegistry.all() do
		local item = ShopCardViewModel.main(offer)
		if item ~= nil and item.kind == "employee" then
			table.insert(cards, ShopCardViewModel.card(offer, owns, balances))
			prices[offer.id] = offer.price
		end
	end
	table.sort(cards, function(a: OfferCard, b: OfferCard): boolean
		local ownedA, ownedB = a.state == "owned", b.state == "owned"
		if ownedA ~= ownedB then
			return ownedB
		end
		if prices[a.id] ~= prices[b.id] then
			return prices[a.id] < prices[b.id]
		end
		return a.id < b.id
	end)
	return cards
end

-- The Skins tab's Vacuums filter value.
ShopListViewModel.VACUUMS = "vacuums"

-- The Skins tab's filters: All, then Vacuums, then one per employee (owner, 2026-11-13: vacuums right after All).
function ShopListViewModel.skinFilters(employees: { string }): { SkinFilter }
	local filters: { SkinFilter } =
		{ { text = "All", value = nil }, { text = "Vacuums", value = ShopListViewModel.VACUUMS } }
	for _, name in employees do
		table.insert(filters, { text = name, value = name })
	end
	return filters
end

--[=[
	Every offer except employees (they are on the Hire tab, the pick screen and the Crew tab): all of them, only the
	vacuum skins (`ShopListViewModel.VACUUMS`), or one employee's items and the shared ones (not the vacuums, which have their own
	filter); what you can buy first (by rarity, highest first), what you own last.
]=]
function ShopListViewModel.skins(owns: Owns, balances: Balances, filter: string?): { OfferCard }
	local cards: { OfferCard } = {}
	for _, offer in ShopRegistry.all() do
		local item = ShopCardViewModel.main(offer)
		local keep = if item == nil or item.kind == "employee"
			then false
			elseif filter == nil then true
			elseif filter == ShopListViewModel.VACUUMS then item.kind == "vacuum"
			else item.kind ~= "vacuum" and (item.employee == nil or item.employee == filter)
		if keep then
			table.insert(cards, ShopCardViewModel.card(offer, owns, balances))
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

return ShopListViewModel
