--!strict
--[=[
	TimecardConstants: the weekly card's numbers and its request budget.

	The rules themselves are TimecardCalendarFormulas' (shared, pure); this file only says how long a week is, how
	many of its days fill the card, which punch pays the key, how many consecutive filled weeks pay the paycheque,
	and how hard a client may mash the punch request.

	@class TimecardConstants
]=]

local TimecardConstants = {
	-- Tunable MVP defaults; balance review may adjust values without changing calendar rules.
	CLOCK_KIND = "TimecardClock",
	DAILY_KIND = "DailyWorkOrder",
	KEY_REWARD = 1,
	STAR_REWARD = 5,
	STAR_LABEL = "Gleam",
	PAYCHEQUE_CREDITS = 500,
	-- Days in the UTC week: Monday = 1 ... Sunday = 7.
	DAYS_PER_WEEK = 7,
	-- Punches that fill the card: any five of the seven days, in any order.
	PUNCHES_TO_FILL = 5,
	-- The punch that pays a Gloom Locker key (the card's first reward).
	KEY_PUNCH = 3,
	-- Consecutive filled weeks that pay a paycheque.
	PAYCHEQUE_WEEKS = 4,
	-- Punch requests per player per window. The server decides what a punch pays; this only caps a flood.
	PUNCH_RATE = { maxRequests = 5, windowSeconds = 10 },
}

return TimecardConstants
