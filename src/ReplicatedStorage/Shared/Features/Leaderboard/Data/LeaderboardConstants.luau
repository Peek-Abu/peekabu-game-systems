--!strict
--[=[
	LeaderboardConstants: the weekly crew leaderboard (owner 11-05: weekly crew boards only, no all-time, no
	top-donor). A crew's score is the most Gloom it removed in one shift this week (Monday 00:00 UTC to the next,
	TimecardCalendarFormulas' week). Static data.

	@class LeaderboardConstants
]=]

return table.freeze({
	-- One OrderedDataStore per week, named STORE_PREFIX .. the week's Monday ("CrewWeek_2026-11-02"), so a new week
	-- starts empty and nothing is ever cleared by hand. Each crew's roster (ids and names at the time) is kept in
	-- ROSTER_STORE under "<week>:<crew key>".
	STORE_PREFIX = "CrewWeek_",
	ROSTER_STORE = "CrewWeekRosters",
	-- Rows on the hub's board, how often a hub server re-reads it (seconds), and the world entry it publishes.
	TOP = 10,
	REFRESH_SECONDS = 60,
	WORLD_ENTRY = "crewBoard",
	-- A crew key's length (OrderedDataStore keys are at most 50 characters).
	KEY_LENGTH = 16,
	-- The most crew members (and names) one row keeps.
	MAX_CREW = 6,
	MAX_NAME = 20,
})
