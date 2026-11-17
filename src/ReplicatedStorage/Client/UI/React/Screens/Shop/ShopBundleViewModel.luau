--!strict
--[=[
	ShopBundleViewModel: the Gleam bundles the Gleam tab and the Featured page's Gleam row sell (each one's amount, Robux
	price, icon, bonus, colour, picture size and corner tag), and which bundle to point at for some missing Gleam. Pure.
	Split out of ShopViewModel, which still exposes `bundles`, `featuredBundles`, `bestBundle` and the two constants
	under its own name.

	@class ShopBundleViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Bundle = {
	key: string,
	amount: string,
	robux: string,
	bonus: string?,
	-- The product's icon (rbxassetid).
	image: string,
	available: boolean,
	-- The one that best covers what the player came for (the smallest that is enough; VM.bestBundle).
	best: boolean,
	-- The card's colour on the Gleam tab: it climbs with the pack (VM.BUNDLE_HUES).
	hue: UIToonConstants.Hue,
	-- The picture's size on its card, VM.BUNDLE_ICON_MIN for the smallest pack up to 1 for the biggest.
	iconScale: number,
	-- "POPULAR" / "BEST VALUE" on its card's corner, or nil.
	tag: string?,
}

local ShopBundleViewModel = {}

-- The Gleam tab's cards climb like a ladder (owner 11-16, Gleam page round 5): blue for the two small packs, purple
-- for the middle two, gold for the two big ones (the same order as the pack icons' rays); a pack past the list keeps
-- the last colour.
local BUNDLE_HUES: { UIToonConstants.Hue } = { "sky", "sky", "grape", "grape", "gold", "gold" }
-- The smallest pack's picture size on its card; the rest grow evenly up to 1 for the biggest.
ShopBundleViewModel.BUNDLE_ICON_MIN = 0.62
-- The corner tags, by bundle key; the biggest pack is always BEST VALUE.
local BUNDLE_TAGS: { [string]: string } = { gleam1950 = "POPULAR" }

-- The Gleam bundles; each one's price and icon as Roblox reported them in `infos` (by bundle key), the known ones
-- (ShopConstants.BUNDLES) until it does; `best` (a bundle key) is marked as the one to buy.
function ShopBundleViewModel.bundles(infos: { [string]: ShopStore.ProductInfo }, best: string?): { Bundle }
	local list: { Bundle } = {}
	local function robuxOf(bundle: ShopTypes.GleamBundle): number
		local info = infos[bundle.key]
		return if info ~= nil and info.price ~= nil then info.price else bundle.robux
	end
	-- The bonus is worked out from the numbers: Gleam per Robux over the first (smallest) pack's.
	local first = ShopConstants.BUNDLES[1]
	local baseRate = if first ~= nil then first.gleam / robuxOf(first) else 0
	local count = #ShopConstants.BUNDLES
	for index, bundle in ShopConstants.BUNDLES do
		local info = infos[bundle.key]
		local price = robuxOf(bundle)
		local step = if count > 1 then (index - 1) / (count - 1) else 1
		local bonus = if baseRate > 0 and price > 0
			then math.floor(((bundle.gleam / price) / baseRate - 1) * 100 + 0.5)
			else 0
		table.insert(list, {
			key = bundle.key,
			amount = ToonStyleViewModel.grouped(bundle.gleam),
			robux = `R$ {ToonStyleViewModel.grouped(price)}`,
			bonus = if bonus > 0 then `+{bonus}%` else nil,
			image = if info ~= nil and info.icon ~= nil then info.icon else bundle.image,
			available = ShopConstants.PRODUCT_IDS[bundle.key] ~= nil,
			best = bundle.key == best,
			hue = BUNDLE_HUES[math.min(index, #BUNDLE_HUES)],
			iconScale = ShopBundleViewModel.BUNDLE_ICON_MIN + (1 - ShopBundleViewModel.BUNDLE_ICON_MIN) * step,
			tag = if index == count and count > 1 then "BEST VALUE" else BUNDLE_TAGS[bundle.key],
		})
	end
	return list
end

-- How many packs the Featured page's Gleam row shows (desktop). Its cards are short and wide, with the amount beside
-- the art, so six would leave "12,500" no room; the Gleam tab shows them all.
ShopBundleViewModel.FEATURED_BUNDLES = 4

-- The Featured page's Gleam row: the first ShopBundleViewModel.FEATURED_BUNDLES packs.
function ShopBundleViewModel.featuredBundles(bundles: { Bundle }): { Bundle }
	return { table.unpack(bundles, 1, math.min(#bundles, ShopBundleViewModel.FEATURED_BUNDLES)) }
end

-- The bundle to point at for `missing` Gleam: the smallest one on sale that covers it, else the biggest on sale.
function ShopBundleViewModel.bestBundle(missing: number): string?
	local best: ShopTypes.GleamBundle? = nil
	local biggest: ShopTypes.GleamBundle? = nil
	for _, bundle in ShopConstants.BUNDLES do
		if ShopConstants.PRODUCT_IDS[bundle.key] ~= nil then
			if bundle.gleam >= missing and (best == nil or bundle.gleam < best.gleam) then
				best = bundle
			end
			if biggest == nil or bundle.gleam > biggest.gleam then
				biggest = bundle
			end
		end
	end
	local picked = best or biggest
	return if picked ~= nil then picked.key else nil
end

return ShopBundleViewModel
