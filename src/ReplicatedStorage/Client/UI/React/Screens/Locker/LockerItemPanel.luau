--!strict
--[=[
	LockerItemPanel: a Locker "What's inside" item's own page. It is the Shop's product page (ShopProductPanel over
	ShopViewModel.itemProduct: the same rarity flag, name, type line, lore, colour styles and live, spinnable model;
	owner, 2026-11-14: "it should still leverage similar components") with a Locker `foot`: where the item comes from
	and its chance each open, and its one button (LockerViewModel.itemPage: the direct buy where the card offers it,
	Get more Gleam when that buy is too dear, else Back), with a small Back above a buy. Presentational (exempt; values
	specced in LockerViewModel and ShopViewModel).

	@class LockerItemPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local ShopProductPanel = require(script.Parent.Parent.Shop.ShopProductPanel)
local ShopViewModel = require(script.Parent.Parent.Shop.ShopViewModel)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement

export type LockerItemPanelProps = {
	item: VM.InsideItem,
	page: VM.ItemPage,
	owns: (id: string) -> boolean,
	gleam: number,
	layout: InventoryViewModel.Layout,
	onBack: () -> (),
	onBuy: () -> (),
	onGetGleam: () -> (),
}

local function LockerItemPanel(props: LockerItemPanelProps): React.ReactNode
	local item, page = props.item, props.page
	local product = ShopViewModel.itemProduct(item.id, props.owns, { gleam = props.gleam, credits = 0 })
	if product == nil then
		return nil
	end
	local main: ShopProductPanel.Foot = {
		from = page.from,
		chance = page.chance,
		button = if page.button == "buy"
			then { kind = "buy", text = `Buy for {item.directPrice} Gleam`, onActivated = props.onBuy }
			elseif page.button == "getGleam" then {
				kind = "getGleam",
				text = "Get more Gleam",
				onActivated = props.onGetGleam,
			}
			else { kind = "back", text = "Back", onActivated = props.onBack },
		onBack = props.onBack,
	}
	return e(ShopProductPanel, {
		product = product,
		layout = props.layout,
		onBuy = props.onBuy,
		onGetMore = props.onGetGleam,
		foot = main,
	})
end

return LockerItemPanel
