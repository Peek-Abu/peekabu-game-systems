--!strict
--[=[
	DepotWorldViewModel: what the depot's world signs say (Figma World UI 2a). The truck pad tag (W1): "TRUCK n", a seat
	per place (filled = aboard), "n / 4 ABOARD" and line 3: the red "Leaving in m:ss" when the truck is full or
	DepotConstants.TAG_WARN_SECONDS or fewer remain, "Leaving now" while it departs, else how to join. `padFor` finds the
	Queue pad whose crew stand in a truck (by their public `truck` field); `sameTag` says whether two tags draw the same,
	so an unchanged tag is not re-rendered. The contract board (W2): the work order from the board's attributes. Your review
	card (W4): the card from its attributes, with the award stickies; nil for anything that is not a card. Pure.

	@class DepotWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type TruckTagView = {
	title: string,
	seats: { boolean },
	count: string,
	line: string,
	warn: boolean,
}

export type WorkOrderView = {
	number: string,
	kicker: string,
	client: string,
	job: string,
	clear: string,
	before: string,
	key: string,
	action: string,
}

export type ReviewRow = { label: string, value: string }
export type StickyView = { title: string, name: string }

export type ReviewView = {
	band: string,
	rows: { ReviewRow },
	headline: string,
	met: boolean,
	rating: string,
	crew: string,
	quote: string,
	stickies: { StickyView },
}

local JOIN_LINE = "Stand in the bed to join"
local LEAVING_NOW = "Leaving now"

local DepotWorldViewModel = {}

-- Character limits: the work order's client line, the review band's client, a sticky's line, a crew name.
DepotWorldViewModel.WORK_CLIENT_MAX = 24
DepotWorldViewModel.BAND_CLIENT_MAX = 22
DepotWorldViewModel.STICKY_MAX = 24
DepotWorldViewModel.CREW_NAME_MAX = 16
-- The most crew lines and award stickies a card shows (ShiftCardUtils keeps the same caps).
DepotWorldViewModel.MAX_CREW = 4
DepotWorldViewModel.MAX_AWARDS = 3

function DepotWorldViewModel.truckTag(
	truck: number,
	capacity: number,
	pad: QueueTypes.PadSnapshot?,
	now: number
): TruckTagView
	local aboard = if pad ~= nil then #pad.members else 0
	local seats: { boolean } = {}
	for seat = 1, capacity do
		table.insert(seats, seat <= aboard)
	end
	local endsAt = if pad ~= nil then pad.endsAt else nil
	local line = JOIN_LINE
	local warn = false
	if pad ~= nil and pad.departing then
		line = LEAVING_NOW
		warn = true
	elseif endsAt ~= nil then
		local left = endsAt - now
		if aboard >= capacity or left <= DepotConstants.TAG_WARN_SECONDS then
			line = `Leaving in {ShiftHudViewModel.clock(left)}`
			warn = true
		end
	end
	return {
		title = `TRUCK {truck}`,
		seats = seats,
		count = `{aboard} / {capacity} ABOARD`,
		line = line,
		warn = warn,
	}
end

-- The Queue pad of `truck`: the first pad with a member whose public `truck` field names it; nil when nobody is aboard.
function DepotWorldViewModel.padFor(
	snapshot: QueueTypes.QueueSnapshot?,
	truck: number,
	players: PublicPlayerTypes.PublicPlayerMap
): QueueTypes.PadSnapshot?
	if snapshot == nil then
		return nil
	end
	for _, pad in snapshot.pads do
		for _, userId in pad.members do
			local entry = players[StateSyncConstants.publicEntryKey(userId)]
			if entry ~= nil and entry[DepotConstants.PUBLIC_TRUCK] == truck then
				return pad
			end
		end
	end
	return nil
end

-- A whole, non-negative number read off an attribute; nil for anything else.
local function count(value: unknown): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.max(0, math.floor(value))
end

function DepotWorldViewModel.sameTag(a: TruckTagView?, b: TruckTagView?): boolean
	if a == nil or b == nil then
		return a == nil and b == nil
	end
	if a.title ~= b.title or a.count ~= b.count or a.line ~= b.line or a.warn ~= b.warn or #a.seats ~= #b.seats then
		return false
	end
	for index, filled in a.seats do
		if b.seats[index] ~= filled then
			return false
		end
	end
	return true
end

function DepotWorldViewModel.workOrder(attributes: { [string]: unknown }): WorkOrderView?
	local keys = DepotConstants.CONTRACT_KEYS
	local id = attributes[keys.id]
	local client = attributes[keys.client]
	local job = attributes[keys.job]
	if type(id) ~= "string" or type(client) ~= "string" or type(job) ~= "string" then
		return nil
	end
	return {
		number = `WORK ORDER {DepotBoardViewModel.workOrder(id)}`,
		kicker = DepotConstants.BOARD_COPY.title,
		client = WorldBillboardViewModel.clip(client, DepotWorldViewModel.WORK_CLIENT_MAX),
		job = job,
		clear = `CLEAR {ShiftConstants.QUOTA}`,
		before = `of site buildup before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`,
		key = "E",
		action = "Read the work order",
	}
end

function DepotWorldViewModel.review(attributes: { [string]: unknown }): ReviewView?
	local keys = DepotConstants.REVIEW_KEYS
	local client = attributes[keys.client]
	local met = attributes[keys.met]
	local rating = attributes[keys.rating]
	local cleared = count(attributes[keys.cleared])
	local quota = count(attributes[keys.quota])
	local bonus = count(attributes[keys.bonus])
	local catches = count(attributes[keys.catches])
	local salvage = count(attributes[keys.salvage])
	local offered = count(attributes[keys.offered])
	if
		type(client) ~= "string"
		or type(met) ~= "boolean"
		or type(rating) ~= "string"
		or cleared == nil
		or quota == nil
		or bonus == nil
		or catches == nil
		or salvage == nil
		or offered == nil
	then
		return nil
	end
	local names: { string } = {}
	for index = 1, DepotWorldViewModel.MAX_CREW do
		local name = attributes[`{keys.crew}{index}`]
		if type(name) ~= "string" then
			break
		end
		table.insert(names, WorldBillboardViewModel.clip(name, DepotWorldViewModel.CREW_NAME_MAX))
	end
	local stickies: { StickyView } = {}
	for index = 1, DepotWorldViewModel.MAX_AWARDS do
		local title = attributes[`{keys.awardTitle}{index}`]
		local name = attributes[`{keys.awardName}{index}`]
		if type(title) ~= "string" or type(name) ~= "string" then
			break
		end
		table.insert(stickies, {
			title = WorldBillboardViewModel.clip(title, DepotWorldViewModel.STICKY_MAX),
			name = WorldBillboardViewModel.clip(name, DepotWorldViewModel.STICKY_MAX),
		})
	end
	local text = ShiftConstants.RATING_TEXT
	-- A missed quota never rates above NEEDS IMPROVEMENT (the review's rule); an unknown word reads as it too.
	local stamp = if met then text[rating] or text.needsImprovement else text.needsImprovement
	local quote = if met then ShiftConstants.REVIEW_QUOTES.met else ShiftConstants.REVIEW_QUOTES.missed
	local band = string.upper(WorldBillboardViewModel.clip(client, DepotWorldViewModel.BAND_CLIENT_MAX))
	return {
		band = `SHIFT REVIEW · {band}`,
		rows = {
			{ label = "CLEARED", value = `{cleared} / {quota}` },
			{ label = ShiftCurrencyUtils.earnedLabel(), value = `+{bonus}` },
			{ label = "TIMES CAUGHT", value = tostring(catches) },
			{ label = "ASSETS", value = `{salvage} of {offered}` },
		},
		headline = if met then "QUOTA MET" else "QUOTA MISSED",
		met = met,
		rating = stamp,
		crew = if #names > 0 then `Crew: {table.concat(names, " · ")}` else "",
		quote = `{quote.line} {quote.by}`,
		stickies = stickies,
	}
end

-- Whether the shared result board's shell draws: not while this client has its own review shell (one sign per spot).
function DepotWorldViewModel.drawsSharedBoard(hasReview: boolean): boolean
	return not hasReview
end

return DepotWorldViewModel
