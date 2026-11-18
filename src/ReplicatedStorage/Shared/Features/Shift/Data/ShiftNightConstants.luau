--!strict
--[=[
	ShiftNightConstants: the Night Shift mode's tuning (owner picks 2026-11-18 on the threat page, concept B "The Night
	Shift"; reworked 11-18 for readability). A run is nights in a row with no end, and each night's goal is the only
	fail line: miss tonight's goal and the crew is fired (the run ends). Every WEEK_NIGHTS nights is a week; surviving
	one pays the week bonus (a reward, never a goal) and shows a short week report. The goals climb a little every
	night; each new week the nights get longer, the manager starts angrier and the anomaly level rises a drop; each
	night pays more. Every number is a tuning hypothesis. Static data (spec-exempt).

	@class ShiftNightConstants
]=]

return table.freeze({
	-- Nights in a week (owner 11-18: "weeks as every 5 nights"; was 3). The per-week ramps below (and Occupant's
	-- STEER/BREATHER_PER_WEEK, SkillCheck's WIDTH_WEEK_STEP) keep their size a week, so a 5-night week ramps the
	-- manager, anomaly, director and ring more gently per night: the first nights stay easy (owner: "start first
	-- nights' goals low"); the goal is what climbs every night (quotaScale).
	WEEK_NIGHTS = 5,
	-- A night's length (seconds) by week: short at first (owner fl2: "start with short shifts"), the last entry for
	-- every later week (the full shift, ShiftConstants.SHIFT_SECONDS).
	NIGHT_SECONDS = table.freeze({ 180, 300, 420, 510 }),
	-- A night's goal as a share of the shift contract (ShiftQuotaFormulas.quota): each week starts at its entry and climbs
	-- evenly toward the next week's over its nights (week 1: 0.3, 0.35, 0.4, 0.45, 0.5; week 2 from 0.55); after the
	-- table, +QUOTA_GROWTH a week, never above QUOTA_SCALE_CAP (the site holds about 1070 Gloom and a contract stays
	-- under ~80% of it, ShiftConstants QUOTA notes: past that, later weeks grow harder through the manager, not the
	-- goal). Night 1 starts low (0.3: about 190 Gloom solo at the office) because missing any night now fires the crew.
	QUOTA_SCALE = table.freeze({ 0.3, 0.55, 0.8, 1 }),
	QUOTA_GROWTH = 0.05,
	QUOTA_SCALE_CAP = 1.2,
	QUOTA_STEP = 5,
	-- Each night pays 1 + PAY_STEP x (night - 1) times a normal shift's pay (owner fl6: each round pays more).
	PAY_STEP = 0.25,
	-- Surviving a week pays WEEK_BONUS x the week number in Credits to each crew member (a reward, never a goal; 150 for
	-- a 5-night week, was 100 for 3).
	WEEK_BONUS = 150,
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
