--!strict
--[=[
	ShopRotationUtils: which offers the Shop shows at a UTC time, the same on every server: the day number (counted
	from the rotation hour) seeds the choice, so the Featured banner takes turns through the featured pool and Today's
	picks are a shuffled handful of the picks pool. Event offers count only inside their dates. Pure.

	@class ShopRotationUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)

type Offer = ShopTypes.Offer

local ShopRotationUtils = {}

-- The day number at `now` (days since the epoch, counted from the rotation hour).
function ShopRotationUtils.day(now: number): number
	return math.floor((now - ShopConstants.ROTATION_HOUR_UTC * 3600) / ShopConstants.DAY)
end

function ShopRotationUtils.available(offer: Offer, now: number): boolean
	local starts, ends = offer.starts, offer.ends
	if starts ~= nil and now < starts then
		return false
	end
	if ends ~= nil and now >= ends then
		return false
	end
	return true
end

-- New! for an event offer's first days, Last day! in its final hours.
function ShopRotationUtils.flags(offer: Offer, now: number): { ShopTypes.Flag }
	local flags: { ShopTypes.Flag } = {}
	local starts, ends = offer.starts, offer.ends
	if starts ~= nil and now >= starts and now - starts < ShopConstants.NEW_SECONDS then
		table.insert(flags, "new")
	end
	if ends ~= nil and now < ends and ends - now <= ShopConstants.LAST_DAY_SECONDS then
		table.insert(flags, "lastDay")
	end
	return flags
end

-- A small seeded generator (the same sequence for the same day everywhere).
local function generator(seed: number): () -> number
	local state = (seed * 2654435761 + 12345) % 2147483648
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end
end

function ShopRotationUtils.live(offers: { Offer }, now: number): ShopTypes.LiveShop
	local day = ShopRotationUtils.day(now)
	local featuredPool: { Offer } = {}
	local picksPool: { Offer } = {}
	for _, offer in offers do
		if ShopRotationUtils.available(offer, now) then
			if offer.pool == "featured" then
				table.insert(featuredPool, offer)
			elseif offer.pool == "picks" then
				table.insert(picksPool, offer)
			end
		end
	end
	local featured = if #featuredPool > 0 then featuredPool[day % #featuredPool + 1] else nil
	-- Shuffle the picks pool with the day's seed, then take the first PICKS.
	local nextNumber = generator(day)
	for index = #picksPool, 2, -1 do
		local other = nextNumber() % index + 1
		picksPool[index], picksPool[other] = picksPool[other], picksPool[index]
	end
	local picks: { Offer } = {}
	for index = 1, math.min(ShopConstants.PICKS, #picksPool) do
		picks[index] = picksPool[index]
	end
	return {
		featured = featured,
		picks = picks,
		nextRotation = (day + 1) * ShopConstants.DAY + ShopConstants.ROTATION_HOUR_UTC * 3600,
	}
end

return ShopRotationUtils
