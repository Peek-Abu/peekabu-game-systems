--!strict
--[=[
	ShopTypes: offers, the live shop and Gleam bundles (design: docs/superpowers/specs/
	2026-10-24-odd-hours-character-systems-design.md §9; plan: docs/superpowers/plans/
	2026-10-24-character-step4-shop-reveals.md).

	@class ShopTypes
]=]

export type Currency = "gleam" | "credits"

-- Where an offer shows: the big Featured banner (one a day), Today's picks (rotating), or always listed (employees).
export type Pool = "featured" | "picks" | "always"

export type Flag = "new" | "lastDay"

export type Offer = {
	-- The offer id (the main item's catalogue id).
	id: string,
	-- What buying it grants (each with its CosmeticRegistry bundle).
	items: { string },
	currency: Currency,
	price: number,
	pool: Pool,
	-- An event offer is only sold between these UTC times (unix seconds).
	starts: number?,
	ends: number?,
	-- A real, higher price to cross out: what a bundle's items cost alone (ShopPriceRules), or the price before a
	-- sale. nil otherwise (never an invented "was" price).
	was: number?,
	-- When the sale price ends (ShopPriceRules); nil when it is the regular price.
	saleEnds: number?,
}

export type LiveShop = {
	featured: Offer?,
	picks: { Offer },
	-- When Today's picks next change (unix seconds).
	nextRotation: number,
}

-- A Gleam bundle sold for Robux (a developer product).
export type GleamBundle = {
	key: string,
	gleam: number,
	robux: number,
	-- The developer product's own icon (rbxassetid), the one its Roblox store page shows; the Shop shows the icon
	-- Roblox reports for the product once it answers, this one until then.
	image: string,
}

return {}
