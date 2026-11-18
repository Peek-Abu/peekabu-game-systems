--!strict
--[=[
	ShiftNightConstants: the Night Shift mode's tuning (owner picks 2026-11-18 on the threat page, concept B "The Night
	Shift"). A run is nights in a row with no end: every WEEK_NIGHTS nights is a week with a weekly quota (the sum of its
	nights' goals). Miss the weekly quota and the crew is fired (the run ends). Each new week the nights get longer
	and the goals bigger; each night pays more and starts the manager angrier; the anomaly level rises a drop a week.
	Every number is a tuning hypothesis. Static data (spec-exempt).

	@class ShiftNightConstants
]=]

return table.freeze({
	-- Nights in a week (owner cn3: "a week is 3 nights").
	WEEK_NIGHTS = 3,
	-- A night's length (seconds) by week: short at first (owner fl2: "start with short shifts"), the last entry for
	-- every later week (the full shift, ShiftConstants.SHIFT_SECONDS).
	NIGHT_SECONDS = table.freeze({ 180, 300, 420, 510 }),
	-- A night's goal as a share of the shift contract (ShiftQuotaFormulas.quota) by week; after the table, +QUOTA_GROWTH a
	-- week, never above QUOTA_SCALE_CAP (the site holds about 1070 Gloom and a contract stays under ~80% of it,
	-- ShiftConstants QUOTA notes: past that, later weeks grow harder through the manager, not the goal).
	QUOTA_SCALE = table.freeze({ 0.35, 0.6, 0.85, 1 }),
	QUOTA_GROWTH = 0.05,
	QUOTA_SCALE_CAP = 1.2,
	QUOTA_STEP = 5,
	-- Each night pays 1 + PAY_STEP x (night - 1) times a normal shift's pay (owner fl6: each round pays more).
	PAY_STEP = 0.25,
	-- Meeting a weekly quota pays WEEK_BONUS x the week number in Credits to each crew member.
	WEEK_BONUS = 100,
	-- The manager's starting tier: one step angrier a week (owner fl5), up to the top tier.
	TIER_PER_WEEK = 1,
	-- The readout's ANOMALY LEVEL: the map's danger (DepotConstants MapSite.danger) + one drop a week after the first,
	-- at most this many drops.
	ANOMALY_MAX = 5,
	-- Coats: a crew member out of coats sits out the rest of the night and starts the next one with RETURN_LIVES
	-- (owner fl4); one who joins mid-run starts with the normal starting lives.
	RETURN_LIVES = 1,
	-- The depart payload's key for the run mode (DepotServiceServer's setDepartData; ShiftTripSystem reads it), and its
	-- values. Night Shift is the main way to play (owner fl7); "quick" is today's single shift.
	MODE_KEY = "runMode",
	MODE_NIGHT = "night",
	MODE_QUICK = "quick",
	DEFAULT_MODE = "night",
})
