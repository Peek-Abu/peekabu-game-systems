--!strict
--[=[
	DailyRewardConstants: the streak cycle and when a day starts.

	@class DailyRewardConstants
]=]

local DailyRewardConstants = {
	-- The streak's reward days repeat every CYCLE_LENGTH days (day 8 gives day 1's reward again).
	CYCLE_LENGTH = 7,
	-- Hours added to UTC before cutting days (0 = days start at midnight UTC).
	DAY_OFFSET_HOURS = 0,
	-- Claim requests per player per window.
	CLAIM_RATE = { maxRequests = 5, windowSeconds = 10 },
}

return DailyRewardConstants
