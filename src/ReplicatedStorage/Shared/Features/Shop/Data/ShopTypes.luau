--!strict
--[=[
	ShopTypes: offers, the live shop and Gleam bundles (design: docs/superpowers/specs/
	2026-10-24-odd-hours-character-systems-design.md §9; plan: docs/superpowers/plans/
	2026-10-24-character-step4-shop-reveals.md).

	@class ShopTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

-- Gleam (premium) or a slot currency: Credits, or a limited-time event's money (`acorns`, EventRegistry; earned only,
-- Gleam never pays the rest).
export type Currency = "gleam" | CurrencyConstants.CurrencyType

-- Where an offer shows: the big Featured banner (one a day), Today's picks (rotating), always listed (employees), or a
-- limited-time event's own tab (only while that event is live).
export type Pool = "featured" | "picks" | "always" | "event"

export type Flag = "new" | "lastDay"

export type Offer = {
	-- The offer id (the main item's catalogue id).
	id: string,
	-- What buying it grants (each with its CosmeticRegistry bundle).
	items: { string },
	currency: Currency,
	price: number,
	pool: Pool,
	-- A dated offer is only sold between these UTC times (unix seconds). An event's offer carries its event's dates for
	-- the New! / Last day! flags, but is sold while its `event` is live (dates or admin preview).
	starts: number?,
	ends: number?,
	-- A limited-time event's offer: the EventRegistry id.
	event: string?,
	-- A real, higher price to cross out: what a bundle's items cost alone (ShopPriceRules), or the price before a
	-- sale. nil otherwise (never an invented "was" price).
	was: number?,
	-- When the sale price ends (ShopPriceRules); nil when it is the regular price.
	saleEnds: number?,
}

export type LiveShop = {
	featured: Offer?,
	-- The rest of the featured pool, in turn order after today's (the banner carousel's other slides).
	more: { Offer },
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

-- What a Robux buy that is not a cosmetic gave, for the "You bought it!" screen (ShopPurchaseRules): Gleam (`amount`
-- Gleam), a game pass (`key` is its MarketplaceRegistry key, `amount` 1) or coffee (`amount` minutes).
export type PurchaseKind = "gleam" | "pass" | "coffee"
export type Purchase = { kind: PurchaseKind, key: string, amount: number }

return {}
