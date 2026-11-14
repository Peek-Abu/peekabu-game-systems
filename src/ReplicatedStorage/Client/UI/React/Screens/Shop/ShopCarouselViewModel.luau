--!strict
--[=[
	ShopCarouselViewModel: the Featured tab's banner as a carousel (owner, 2026-11-14: "Carousel on today's banner"). It
	slides through the one-time deals on offer, then today's banner, then the rest of the featured pool
	(ShopRotationUtils `more`). It moves on by itself every AUTO_SECONDS. A slide the player picks (a dot or Next)
	holds for HOLD_SECONDS first, so it never moves under their hand. Pure.

	@class ShopCarouselViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

local ShopCarouselViewModel = {}

export type Slide =
	{ kind: "deal", deal: DealConstants.DealId }
	| { kind: "today", offer: ShopTypes.Offer }
	| { kind: "more", offer: ShopTypes.Offer }

-- Seconds a slide shows before the banner moves on by itself, and after the player picked one.
ShopCarouselViewModel.AUTO_SECONDS = 6
ShopCarouselViewModel.HOLD_SECONDS = 12

function ShopCarouselViewModel.slides(deals: { DealConstants.DealId }, live: ShopTypes.LiveShop): { Slide }
	local slides: { Slide } = {}
	for _, deal in deals do
		table.insert(slides, { kind = "deal", deal = deal })
	end
	local featured = live.featured
	if featured ~= nil then
		table.insert(slides, { kind = "today", offer = featured })
	end
	for _, offer in live.more do
		table.insert(slides, { kind = "more", offer = offer })
	end
	return slides
end

-- Slide `index` wrapped into 1..count (1 with no slides).
function ShopCarouselViewModel.at(index: number, count: number): number
	if count <= 0 then
		return 1
	end
	return (index - 1) % count + 1
end

-- Whether the banner moves on, `since` seconds after the slide last changed (`picked`: the player changed it).
function ShopCarouselViewModel.due(since: number, picked: boolean): boolean
	return since >= if picked then ShopCarouselViewModel.HOLD_SECONDS else ShopCarouselViewModel.AUTO_SECONDS
end

return ShopCarouselViewModel
