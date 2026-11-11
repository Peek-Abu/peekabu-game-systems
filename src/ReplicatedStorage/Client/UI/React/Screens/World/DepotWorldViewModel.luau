--!strict
--[=[
	DepotWorldViewModel: what the depot's world signs say (Figma World UI 2a). The truck pad tag (W1): "TRUCK n", a seat
	per place (filled = aboard), "n / 4 ABOARD" and line 3: the red "Leaving in m:ss" when the truck is full or
	DepotConstants.TAG_WARN_SECONDS or fewer remain, "Leaving now" while it departs, else how to join: an empty truck
	asks someone to host it, a hosted one names its host ("Sam's truck" with the crown icon, or "Sam's friends only"
	with the lock; `icon` names the kit icon, never an emoji in the words). The seats are the pad's live seats (4, or 6
	for a Big Crew host). `padFor` finds the Queue pad (and its id) whose crew stand in a
	truck (by their public `truck` field); `sameTag` says whether two tags draw the same,
	so an unchanged tag is not re-rendered. The contract board (W2): the work order from the board's attributes, its CLEAR
	line for the crew in the viewer's truck (else the range by crew size). Your review
	card (W4): the card from its attributes, with the award stickies; nil for anything that is not a card. Pure.

	@class DepotWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

-- A hosted truck's host, for its tag: their name and whether the truck is friends only.
export type TruckHost = { name: string, locked: boolean }

export type TruckTagView = {
	title: string,
	seats: { boolean },
	count: string,
	line: string,
	-- The kit icon before line 3 (a hosted truck's crown or lock), nil for none.
	icon: UIAssets.ToonIcon?,
	warn: boolean,
}

export type WorkOrderView = {
	number: string,
	kicker: string,
	client: string,
	job: string,
	clear: string,
	-- The Gloom to remove as a bare number (a range while the viewer is in no truck): the board's big number.
	quota: string,
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
	-- The run's monster kind (DepotMapRules.siteOf of the client's map): its render on MOST CAUGHT.
	monster: string,
}

local JOIN_LINE = "Stand in the bed to join"
local HOST_LINE = "Step in to host!"
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
	now: number,
	host: TruckHost?
): TruckTagView
	local aboard = if pad ~= nil then #pad.members else 0
	capacity = if pad ~= nil then pad.capacity else capacity
	local seats: { boolean } = {}
	for seat = 1, capacity do
		table.insert(seats, seat <= aboard)
	end
	local endsAt = if pad ~= nil then pad.endsAt else nil
	local line = if aboard == 0 then HOST_LINE else JOIN_LINE
	local icon: UIAssets.ToonIcon? = nil
	if host ~= nil then
		line = if host.locked then `{host.name}'s friends only` else `{host.name}'s truck`
		icon = if host.locked then "friendsLock" else "hostCrown"
	end
	local warn = false
	if pad ~= nil and pad.departing then
		line = LEAVING_NOW
		icon = nil
		warn = true
	elseif endsAt ~= nil then
		local left = endsAt - now
		if aboard >= capacity or left <= DepotConstants.TAG_WARN_SECONDS then
			line = `Leaving in {ShiftHudViewModel.clock(left)}`
			icon = nil
			warn = true
		end
	end
	return {
		title = `TRUCK {truck}`,
		seats = seats,
		count = `{aboard} / {capacity} ABOARD`,
		line = line,
		icon = icon,
		warn = warn,
	}
end

-- The Queue pad of `truck`: the first pad with a member whose public `truck` field names it; nil when nobody is aboard.
function DepotWorldViewModel.padFor(
	snapshot: QueueTypes.QueueSnapshot?,
	truck: number,
	players: PublicPlayerTypes.PublicPlayerMap
): (QueueTypes.PadSnapshot?, string?)
	if snapshot == nil then
		return nil, nil
	end
	for padId, pad in snapshot.pads do
		for _, userId in pad.members do
			local entry = players[StateSyncConstants.publicEntryKey(userId)]
			if entry ~= nil and entry[DepotConstants.PUBLIC_TRUCK] == truck then
				return pad, padId
			end
		end
	end
	return nil, nil
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
	if
		a.title ~= b.title
		or a.count ~= b.count
		or a.line ~= b.line
		or a.icon ~= b.icon
		or a.warn ~= b.warn
		or #a.seats ~= #b.seats
	then
		return false
	end
	for index, filled in a.seats do
		if b.seats[index] ~= filled then
			return false
		end
	end
	return true
end

-- `crew`: the size of the viewer's truck crew (DepotBoardViewModel.crewOf); nil when they are not in a truck.
function DepotWorldViewModel.workOrder(attributes: { [string]: unknown }, crew: number?): WorkOrderView?
	local keys = DepotConstants.CONTRACT_KEYS
	local id = attributes[keys.id]
	local client = attributes[keys.client]
	local job = attributes[keys.job]
	if type(id) ~= "string" or type(client) ~= "string" or type(job) ~= "string" then
		return nil
	end
	local clear: string
	local who: string
	local quota: string
	if crew == nil then
		quota = `{ShiftQuotaFormulas.quota(1)}–{ShiftQuotaFormulas.quota(HostConstants.SEATS)}`
		clear = `REMOVE {ShiftQuotaFormulas.quota(1)}–{ShiftQuotaFormulas.quota(HostConstants.SEATS)} GLOOM`
		who = "more crew, more Gloom"
	else
		clear = string.upper(ShiftCurrencyUtils.contract(ShiftQuotaFormulas.quota(crew)))
		quota = tostring(ShiftQuotaFormulas.quota(crew))
		who = if crew <= 1 then "for one player" else `for a crew of {crew}`
	end
	return {
		number = `JOB {DepotBoardViewModel.workOrder(id)}`,
		kicker = DepotConstants.BOARD_COPY.title,
		client = WorldBillboardViewModel.clip(client, DepotWorldViewModel.WORK_CLIENT_MAX),
		job = job,
		clear = clear,
		quota = quota,
		before = `{who} · {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)} on the clock`,
		key = "E",
		action = "Read today's job",
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
	-- The run's map (from its client) picks the met quote and the monster, like the shift's own review.
	local site = DepotMapRules.siteOf(DepotMapRules.mapOfClient(client))
	local quote = if met then site.quote else ShiftConstants.REVIEW_QUOTES.missed
	local band = string.upper(WorldBillboardViewModel.clip(client, DepotWorldViewModel.BAND_CLIENT_MAX))
	return {
		band = `SHIFT REVIEW · {band}`,
		rows = {
			{ label = "GLOOM", value = `{cleared} / {quota}` },
			-- Every Gloom removed paid its Credits at clock-out, on top of the valuables banked.
			{
				label = ShiftCurrencyUtils.earnedLabel(),
				value = ShiftCurrencyUtils.amount(ShiftQuotaFormulas.breakdown(cleared, 0, bonus).credits),
			},
			{ label = "CREW CAUGHT", value = tostring(catches) },
			{ label = "ASSETS", value = `{salvage} of {offered}` },
		},
		headline = if met then "GOAL DONE!" else "GOAL MISSED",
		met = met,
		rating = stamp,
		crew = if #names > 0 then `Crew: {table.concat(names, " · ")}` else "",
		quote = `{quote.line} {quote.by}`,
		stickies = stickies,
		monster = site.monster,
	}
end

-- Whether the shared result board's shell draws: not while this client has its own review shell (one sign per spot).
function DepotWorldViewModel.drawsSharedBoard(hasReview: boolean): boolean
	return not hasReview
end

return DepotWorldViewModel
