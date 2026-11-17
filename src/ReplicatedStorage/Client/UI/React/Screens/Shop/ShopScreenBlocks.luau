--!strict
--[=[
	ShopScreenBlocks: the Shop screen's shared pieces: the preview data, what a tab's body needs from the screen
	(ShopTabContext), the node map type and the layout pieces (a full-size group, a heading), shared by ShopScreen and
	its parts (ShopOfferCard, ShopBundleCards, ShopTabBody, ShopFeaturedTab). Split out of ShopScreen.
	Presentational (exempt).

	@class ShopScreenBlocks
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonText = require(Toon.ToonText)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

export type Nodes = { [string]: React.ReactNode }

export type Preview = { owns: (id: string) -> boolean, gleam: number, credits: number }

-- What a list tab's body (ShopTabBody, ShopFeaturedTab) reads from the screen: its state, stores and callbacks.
export type ShopTabContext = {
	tab: string,
	setTab: (id: string) -> (),
	preview: Preview?,
	liveEvent: EventTypes.Event?,
	now: number,
	owns: (id: string) -> boolean,
	balances: VM.Balances,
	keyResult: LockerStore.Result?,
	layout: InventoryViewModel.Layout,
	phone: boolean,
	open: (id: string) -> (),
	filter: string?,
	setFilter: (value: string?) -> (),
	currency: PlayerDataTypes.Currency?,
	passKeys: { string },
	passInfo: { [string]: ShopStore.PassInfo },
	ownsPass: (key: string) -> boolean,
	buyPass: (key: string) -> (),
	returnTo: ShopStore.Return?,
	bundles: { VM.Bundle },
	buyBundle: (key: string) -> (),
	deals: PlayerDataTypes.Deals,
	dealPrices: { [string]: number },
	slot: number,
	pickSlide: (index: number) -> (),
}

local function group(children: Nodes): React.ReactNode
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

local function heading(textValue: string, size: number, position: UDim2, width: number): React.ReactNode
	return e(ToonText, {
		text = textValue,
		textSize = size,
		position = position,
		size = UDim2.fromOffset(width, size + 8),
		fit = true,
	})
end

return {
	group = group,
	heading = heading,
}
