--!strict
--[=[
	ShopConstants: how many picks a day, the UTC hour they change, how long an item counts as New! / its event's
	last day, the four Gleam bundles (Robux developer products; a bundle without a product id shows greyed
	"Soon"), and the Passes tab's words for each game pass (PASS_COPY, by its MarketplaceRegistry key; a registered
	pass with no copy shows its Dashboard name). A pass's price and icon come from Roblox, never from here.

	@class ShopConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

-- `robux` and `image` are the products' price and icon on Roblox (Creator Dashboard, read 2026-11-12); the Shop shows
-- what Roblox reports at runtime and these only until it answers, so a Dashboard change shows without a code change.
local BUNDLES: { ShopTypes.GleamBundle } = {
	-- Owner, 11-13 (price sheet Q1): each bigger pack is a better deal; pack 2 gives 150 (its key keeps the old name, it
	-- is the developer product's registration key). The bonus shown is worked out from the numbers (ShopViewModel).
	{ key = "gleam100", gleam = 100, robux = 99, image = "rbxassetid://112673750570330" },
	{ key = "gleam275", gleam = 150, robux = 129, image = "rbxassetid://82923918698099" },
	{ key = "gleam600", gleam = 600, robux = 449, image = "rbxassetid://138358363514131" },
	{ key = "gleam1500", gleam = 1500, robux = 999, image = "rbxassetid://138262914648345" },
}

-- The developer product id of each bundle (owner, Creator Dashboard, 2026-10-24). The Gleam amounts and Robux prices
-- above are not final: change them here and on the products together.
local PRODUCT_IDS: { [string]: number } = {
	gleam100 = 3722076056,
	gleam275 = 3722076494,
	gleam600 = 3722076599,
	gleam1500 = 3722076697,
}

-- Gleam pays the rest when a player is short (ShopTopUpRules): how much of each currency one Gleam covers. Only the
-- currencies listed can be topped up. Owner, 11-13: 1 Gleam = 10 Credits (a good shift is about 1,000 Credits, so one
-- shift of play is about 100 Gleam), and "no gleam top up on the gloom locker!" (it would make that open a paid random
-- item), so Gloom is never listed.
local TOP_UP: { [string]: number } = {
	credits = 10,
}

-- The Passes tab's card words (kid reading level), by MarketplaceRegistry pass key.
local PASS_COPY: { [string]: { name: string, line: string } } = {
	bigCrew = { name = "Big Crew", line = "Your truck holds 6 friends! Only you need it." },
}

return table.freeze({
	PICKS = 6,
	-- Today's picks change at 00:00 UTC.
	ROTATION_HOUR_UTC = 0,
	DAY = 86400,
	-- An event offer is New! for its first 3 days and says Last day! in its final 24 hours.
	NEW_SECONDS = 3 * 86400,
	LAST_DAY_SECONDS = 86400,
	MAX_ID_LENGTH = 64,
	-- A worked-out price (a bundle you own part of) is rounded up to a multiple of this.
	PRICE_STEP = 10,
	-- The daily rotation's sale (owner, 11-13: price sheet Q6): the Featured item and the first `picks` of Today's
	-- picks are `percent` off until the shop changes (single items only; never an employee or a bundle).
	DAILY_SALE = table.freeze({ percent = 20, picks = 2 }),
	-- The most Gleam one buy request may agree to top up with (a hire from zero Credits is 250).
	MAX_TOP_UP = 100000,
	BUNDLES = table.freeze(BUNDLES),
	PRODUCT_IDS = table.freeze(PRODUCT_IDS),
	PASS_COPY = table.freeze(PASS_COPY),
	TOP_UP = table.freeze(TOP_UP),
})
