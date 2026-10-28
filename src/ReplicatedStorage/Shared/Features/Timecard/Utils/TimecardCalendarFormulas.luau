--!strict
--[=[
	TimecardCalendarFormulas: the weekly timecard's calendar and counters. Pure and clockless: every function takes
	the moment it should answer for, so the server and its specs share one set of rules.

	The week is a UTC week: it starts Monday 00:00 UTC and ends Sunday 23:59:59 UTC. Any five of the seven days fill
	the card, and a missed day never clears the days already punched. The punch that fills the card advances the
	paycheque run; every fourth consecutive completed week pays a paycheque. The run breaks when the week that passed
	was not completed, or when more than one week went by.

	- `dayOfWeek`, `weekStart`, `weekEnd`, `weekKey`: where a moment sits in the UTC week.
	- `roll`: the card brought up to a moment's week (the only place a run can break).
	- `punch`: roll, then record the day, reporting the third punch's key and the fifth's stars.
	- `complete`: five of the seven days punched.

	The counts (days in a week, punches to fill, the key punch, weeks to the paycheque) are TimecardConstants'.

	@class TimecardCalendarFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)

export type Card = {
	week: number, -- the Monday 00:00 UTC this card covers, as a Unix timestamp
	punched: { number }, -- the days punched, Monday = 1 ... Sunday = 7, ascending and unique
	weeks: number, -- consecutive completed weeks so far (the paycheque run)
}

export type Milestone = "key" | "stars"

export type PunchResult = {
	card: Card,
	outcome: "punched" | "already",
	-- Days punched on the card after this punch.
	count: number,
	-- What this punch paid, when it landed on a milestone.
	milestone: Milestone?,
	-- Whether this punch completed a fourth consecutive week, so the paycheque is due.
	paycheck: boolean,
}

local DAY_SECONDS = 86400
local WEEK_SECONDS = 7 * DAY_SECONDS
local DAYS = TimecardConstants.DAYS_PER_WEEK
local GOAL = TimecardConstants.PUNCHES_TO_FILL
local KEY_PUNCH = TimecardConstants.KEY_PUNCH
local PAYCHEQUE_WEEKS = TimecardConstants.PAYCHEQUE_WEEKS

local TimecardCalendarFormulas = {}

-- Monday = 1 ... Sunday = 7. The Unix epoch (day 0) was a Thursday, day 4 of a Monday-first week.
function TimecardCalendarFormulas.dayOfWeek(now: number): number
	return (math.floor(now / DAY_SECONDS) + 3) % DAYS + 1
end

-- The Monday 00:00 UTC of the week `now` falls in.
function TimecardCalendarFormulas.weekStart(now: number): number
	return (math.floor(now / DAY_SECONDS) - (TimecardCalendarFormulas.dayOfWeek(now) - 1)) * DAY_SECONDS
end

-- The first second that is NOT the week `now` falls in (the next Monday 00:00 UTC).
function TimecardCalendarFormulas.weekEnd(now: number): number
	return TimecardCalendarFormulas.weekStart(now) + WEEK_SECONDS
end

-- That Monday's UTC date ("2026-10-26"): what the card is called on screen, and a stable key for logs.
function TimecardCalendarFormulas.weekKey(now: number): string
	return DateTime.fromUnixTimestamp(TimecardCalendarFormulas.weekStart(now))
		:FormatUniversalTime("YYYY-MM-DD", "en-us")
end

-- Five of the seven days is a full card.
function TimecardCalendarFormulas.complete(card: Card): boolean
	return #card.punched >= GOAL
end

-- The card as it stands in `now`'s week. A card already on this week comes back untouched; otherwise the punches
-- start over, and the paycheque run survives only from a completed week to the very next week.
function TimecardCalendarFormulas.roll(card: Card, now: number): Card
	local start = TimecardCalendarFormulas.weekStart(now)
	if card.week == start then
		return card
	end
	local kept = if card.week + WEEK_SECONDS == start and TimecardCalendarFormulas.complete(card) then card.weeks else 0
	return { week = start, punched = {}, weeks = kept }
end

-- Punches the clock for `now`: rolls the card to this week, then records the day. Punching a day twice changes
-- nothing and says so. The returned card is always a new table, never a mutation of the one passed in.
function TimecardCalendarFormulas.punch(card: Card, now: number): PunchResult
	local current = TimecardCalendarFormulas.roll(card, now)
	local day = TimecardCalendarFormulas.dayOfWeek(now)
	if table.find(current.punched, day) ~= nil then
		return { card = current, outcome = "already", count = #current.punched, milestone = nil, paycheck = false }
	end
	local punched = table.clone(current.punched)
	table.insert(punched, day)
	table.sort(punched)
	local count = #punched
	local filled = count >= GOAL and not TimecardCalendarFormulas.complete(current)
	local weeks = if filled then current.weeks + 1 else current.weeks
	local milestone: Milestone? = if count == KEY_PUNCH then "key" elseif count == GOAL then "stars" else nil
	return {
		card = { week = current.week, punched = punched, weeks = weeks },
		outcome = "punched",
		count = count,
		milestone = milestone,
		paycheck = filled and weeks % PAYCHEQUE_WEEKS == 0,
	}
end

return TimecardCalendarFormulas
