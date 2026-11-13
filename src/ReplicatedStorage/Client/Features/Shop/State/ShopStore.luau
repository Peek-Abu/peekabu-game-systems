--!strict
--[=[
	ShopStore: the Shop's client state: which product page is open (`product`, nil = the Shop's front) and the last
	buy result from the server (`result`, from ShopEvents.BuyResult) so the page can say "Need 300 more" or that it
	is already owned. Opening another page clears the old result. `passInfo` holds each game pass's price and icon as
	Roblox reported them (ShopServiceClient fetches them), by MarketplaceRegistry key; `bundleInfo` the same for each Gleam
	bundle's developer product (its Robux price and icon), by bundle key. `tab` is the tab the Shop opens on next (`openTab`, the hub's Lost & Found lockers).
	Charm atoms the Shop screen reads.

	@class ShopStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Result = { offer: string, reason: string }

-- A game pass as Roblox reports it (MarketplaceService product info): its Robux price (nil when not for sale), icon
-- and Dashboard name.
export type PassInfo = { price: number?, icon: string?, name: string?, forSale: boolean }

-- A Gleam bundle's developer product as Roblox reports it: its Robux price and icon (nil when Roblox gave none).
export type ProductInfo = { price: number?, icon: string? }

local noProduct: string? = nil
local product = Charm.atom(noProduct)
local noResult: Result? = nil
local result = Charm.atom(noResult)
local noPasses: { [string]: PassInfo } = {}
-- The tab the Shop opens on next (the hub's Lost & Found lockers open it on "lockers"); nil: the Featured tab.
local noTab: string? = nil
local tab = Charm.atom(noTab)
local passInfo = Charm.atom(noPasses)
local noBundles: { [string]: ProductInfo } = {}
local bundleInfo = Charm.atom(noBundles)

local ShopStore = {
	product = product,
	result = result,
	passInfo = passInfo,
	bundleInfo = bundleInfo,
	tab = tab,
}

function ShopStore.setPassInfo(key: string, info: PassInfo)
	local nextInfo = table.clone(passInfo())
	nextInfo[key] = info
	passInfo(nextInfo)
end

function ShopStore.setBundleInfo(key: string, info: ProductInfo)
	local nextInfo = table.clone(bundleInfo())
	nextInfo[key] = info
	bundleInfo(nextInfo)
end

function ShopStore.open(id: string?)
	product(id)
	result(nil)
	tab(nil)
end

-- Opens the Shop on a tab (no item page): the next ShopScene mount starts there.
function ShopStore.openTab(id: string)
	product(nil)
	result(nil)
	tab(id)
end

function ShopStore.close()
	product(nil)
	result(nil)
end

function ShopStore.setResult(value: Result)
	result(value)
end

-- Forgets everything (between specs).
function ShopStore.reset()
	product(nil)
	result(nil)
	passInfo({})
	bundleInfo({})
	tab(nil)
end

return ShopStore
