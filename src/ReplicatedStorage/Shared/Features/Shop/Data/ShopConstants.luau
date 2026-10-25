--!strict
--[=[
	ShopConstants: how many picks a day, the UTC hour they change, how long an item counts as New! / its event's
	last day, and the four Gleam bundles (Robux developer products; a bundle without a product id shows greyed
	"Soon").

	@class ShopConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

local BUNDLES: { ShopTypes.GleamBundle } = {
	{ key = "gleam100", gleam = 100, robux = 49, bonus = 0, icon = "gleamPile" },
	{ key = "gleam275", gleam = 275, robux = 129, bonus = 10, icon = "gleamBucket" },
	{ key = "gleam600", gleam = 600, robux = 249, bonus = 20, icon = "gleamCrate" },
	{ key = "gleam1500", gleam = 1500, robux = 549, bonus = 35, icon = "gleamTruck" },
}

-- The developer product id of each bundle (owner, Creator Dashboard, 2026-10-24). The Gleam amounts and Robux prices
-- above are not final: change them here and on the products together.
local PRODUCT_IDS: { [string]: number } = {
	gleam100 = 3722076056,
	gleam275 = 3722076494,
	gleam600 = 3722076599,
	gleam1500 = 3722076697,
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
	BUNDLES = table.freeze(BUNDLES),
	PRODUCT_IDS = table.freeze(PRODUCT_IDS),
})
