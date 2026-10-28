--!strict
--[=[
	TimecardRules: what a stored card must look like, and what the card may do right now.

	Pure; the moment is passed in. The calendar itself (weeks, day numbers, milestones, the paycheque run) is
	TimecardCalendarFormulas' — this module adds only the profile-slice validator and the handful of facts a caller
	or the HUD asks for: can I punch today, how many punches until the next reward, how many weeks until the
	paycheque.

	The numbers (five to fill, third punch pays the key, four weeks to the paycheque) are TimecardConstants'.

	@class TimecardRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local TimecardCalendarFormulas = require(ReplicatedStorage.Shared.Features.Timecard.Utils.TimecardCalendarFormulas)

type Card = PlayerDataTypes.Timecard

export type Status = {
	week: number, -- the Monday 00:00 UTC the card covers, as a Unix timestamp
	weekKey: string, -- that Monday's UTC date ("2026-10-26")
	today: number, -- today's day number, Monday = 1 ... Sunday = 7
	punched: { number }, -- the days punched, ascending
	count: number,
	complete: boolean,
	canPunch: boolean, -- today is not already on the card
	nextMilestone: TimecardCalendarFormulas.Milestone?, -- nil once the card is full
	punchesToMilestone: number?, -- punches still needed for `nextMilestone`
	weeks: number, -- consecutive filled weeks so far
	weeksToPaycheque: number, -- filled weeks still needed before the next paycheque (1 ... PAYCHEQUE_WEEKS)
}

local TimecardRules = {}

local function isWhole(value: number, atLeast: number): boolean
	return type(value) == "number" and value >= atLeast and value < math.huge and value == math.floor(value)
end

--[=[
	The profile-slice invariant, enforced by the data layer on every write: a whole week stamp, whole day numbers
	inside the week, ascending and unique, and no punches on a card that has no week yet.
]=]
function TimecardRules.validate(card: Card): (boolean, string?)
	if not isWhole(card.week, 0) then
		return false, "timecard.week must be a whole Unix timestamp of at least 0"
	end
	if card.week ~= 0 and TimecardCalendarFormulas.weekStart(card.week) ~= card.week then
		return false, "timecard.week must be Monday 00:00 UTC"
	end
	if not isWhole(card.weeks, 0) then
		return false, "timecard.weeks must be a whole number of at least 0"
	end
	if type(card.punched) ~= "table" then
		return false, "timecard.punched must be a list of day numbers"
	end
	local count = 0
	for index, day in card.punched do
		count += 1
		if not isWhole(index, 1) or index > #card.punched or #card.punched > TimecardConstants.DAYS_PER_WEEK then
			return false, "timecard.punched must be a dense list of at most seven days"
		end
		if not isWhole(day, 1) or day > TimecardConstants.DAYS_PER_WEEK then
			return false,
				`timecard.punched[{index}] must be a whole day number from 1 to {TimecardConstants.DAYS_PER_WEEK}`
		end
		if index > 1 and (card.punched[index - 1] == nil or day <= card.punched[index - 1]) then
			return false, "timecard.punched must be ascending and hold each day once"
		end
	end
	if count ~= #card.punched then
		return false, "timecard.punched must be a dense list"
	end
	if card.week == 0 and #card.punched > 0 then
		return false, "a timecard with no week cannot hold punches"
	end
	return true, nil
end

--[=[
	Whether a punch would land right now: today is inside the card's week and not on it yet.
]=]
function TimecardRules.canPunch(card: Card, now: number): boolean
	local current = TimecardCalendarFormulas.roll(card, now)
	return table.find(current.punched, TimecardCalendarFormulas.dayOfWeek(now)) == nil
end

--[=[
	The card as it stands in `now`'s week: rolled forward for display, with the facts the caller needs. The card
	passed in is never mutated.
]=]
function TimecardRules.status(card: Card, now: number): Status
	local current = TimecardCalendarFormulas.roll(card, now)
	local today = TimecardCalendarFormulas.dayOfWeek(now)
	local count = #current.punched
	local milestone: TimecardCalendarFormulas.Milestone? = nil
	local toMilestone: number? = nil
	if count < TimecardConstants.KEY_PUNCH then
		milestone, toMilestone = "key", TimecardConstants.KEY_PUNCH - count
	elseif count < TimecardConstants.PUNCHES_TO_FILL then
		milestone, toMilestone = "stars", TimecardConstants.PUNCHES_TO_FILL - count
	end
	return {
		week = current.week,
		weekKey = TimecardCalendarFormulas.weekKey(now),
		today = today,
		punched = table.clone(current.punched),
		count = count,
		complete = TimecardCalendarFormulas.complete(current),
		canPunch = table.find(current.punched, today) == nil,
		nextMilestone = milestone,
		punchesToMilestone = toMilestone,
		weeks = current.weeks,
		-- A run already at a multiple of four is four more weeks from the next paycheque, not zero.
		weeksToPaycheque = TimecardConstants.PAYCHEQUE_WEEKS - (current.weeks % TimecardConstants.PAYCHEQUE_WEEKS),
	}
end

return TimecardRules
