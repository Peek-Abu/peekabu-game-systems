--!strict
--[=[
	DepotPlaceConstants: the places a crew can work (p1-places-menu, 2026-11-14): each map's Credits price (0 = free)
	and its DANGER level on the places menu's meter (like Lethal Company's risk level: a harder place rates higher).
	The Office is the free, easier first place; the School is the second, bought once with Credits by a truck's host
	(DepotPlaceSystem) and harder (more Gloom, a bigger contract, richer valuables: ShiftConstants.QUOTA_SCALE_BY_MAP,
	OfficeConstants.SPAWN_BY_MAP; Bramble). Static data (spec-exempt; read through DepotPlaceRules).

	@class DepotPlaceConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type Place = {
	-- Credits to unlock it for good; 0 = free for everyone.
	price: number,
	-- Its DANGER level, 1 to DANGER_MAX.
	danger: number,
}

local PLACES: { office: Place, school: Place } = {
	office = table.freeze({ price = 0, danger = 1 }),
	school = table.freeze({ price = 1500, danger = 3 }),
}

local ORDER: { ShiftTypes.MapId } = { "office", "school" }

local DepotPlaceConstants = table.freeze({
	PLACES = table.freeze(PLACES),
	-- The places in menu order.
	ORDER = table.freeze(ORDER),
	-- The meter's full scale (later places, the Hospital, Motel and Mall, rate up to it).
	DANGER_MAX = 5,
	-- The account slice the bought places are saved in (PlayerDataTypes.Places).
	SLICE = "places",
	-- BuyPlace requests per player.
	BUY_REQUEST_RATE = table.freeze({ maxRequests = 5, windowSeconds = 10 }),
	-- How long the BUY button waits on its second tap (SURE?) before it goes back.
	CONFIRM_SECONDS = 4,
	-- The places menu's words (3rd-grade reading level).
	TEXT = table.freeze({
		title = "PLACES",
		subtitle = "Pick where your crew cleans tonight",
		danger = "DANGER",
		picked = "TONIGHT!",
		open = "OPEN",
		locked = "LOCKED",
		buy = "BUY",
		sure = "SURE?",
		tooPoor = "Need more Credits",
		youPick = "Tap a place to pick it!",
		hostPicks = "The host picks the place.",
		hostNeeds = "The host must unlock it first.",
		findTruck = "Get on a truck to pick a place.",
		placeButton = "PLACE",
	}),
})

return DepotPlaceConstants
