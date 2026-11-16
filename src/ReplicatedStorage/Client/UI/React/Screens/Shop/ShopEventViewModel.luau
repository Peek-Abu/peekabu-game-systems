--!strict
--[=[
	ShopEventViewModel: what the Shop's event tab shows while a limited-time event is live (so-event, owner picks r1):
	the event's name with its days left and the player's acorns, the event's items as offer cards (ShopViewModel.card,
	priciest first), the event's own Locker, and the Locker keys it sells for acorns (EventRegistry keys).

	@class ShopEventViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)
local EventUtils = require(ReplicatedStorage.Shared.Features.Event.Utils.EventUtils)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local ShopViewModel = require(script.Parent.ShopViewModel)

type Event = EventTypes.Event

export type Header = { title: string, days: string, acorns: string }

export type KeyOffer = {
	locker: LockerTypes.LockerId,
	name: string,
	price: string,
	enabled: boolean,
}

local VM = {}

function VM.header(event: Event, now: number, previewed: boolean, acorns: number): Header
	local days = EventUtils.daysLeft(event, now, previewed)
	return {
		title = event.name,
		days = if days <= 1 then "Last day!" else `{days} days left`,
		acorns = ToonStyleViewModel.grouped(acorns),
	}
end

function VM.offers(
	event: Event,
	owns: (id: string) -> boolean,
	balances: ShopViewModel.Balances
): { ShopViewModel.OfferCard }
	local list = {}
	for _, offer in ShopRegistry.all() do
		if offer.event == event.id then
			table.insert(list, offer)
		end
	end
	table.sort(list, function(a, b): boolean
		if a.price ~= b.price then
			return a.price > b.price
		end
		return a.id < b.id
	end)
	local cards: { ShopViewModel.OfferCard } = {}
	for _, offer in list do
		table.insert(cards, ShopViewModel.card(offer, owns, balances))
	end
	return cards
end

function VM.keys(event: Event, acorns: number): { KeyOffer }
	local out: { KeyOffer } = {}
	for _, offer in event.keys do
		local locker = LockerRules.get(offer.locker)
		if locker ~= nil then
			table.insert(out, {
				locker = locker.id,
				name = `{locker.name} key`,
				price = ToonStyleViewModel.grouped(offer.price),
				enabled = acorns >= offer.price,
			})
		end
	end
	return out
end

-- The event's own Locker, or nil.
function VM.locker(event: { id: string }): LockerTypes.Locker?
	for _, id in LockerConstants.ORDER do
		local locker = LockerConstants.BY_ID[id]
		if locker ~= nil and locker.event == event.id then
			return locker
		end
	end
	return nil
end

function VM.resultText(reason: string): string?
	if reason == "" then
		return nil
	elseif reason == "short" then
		return "Not enough acorns yet!"
	elseif reason == "not on sale" then
		return "The event is over."
	elseif reason == "locked during a shift" then
		return "Keys are sold at the depot."
	end
	return "That didn't work. Try again!"
end

return VM
