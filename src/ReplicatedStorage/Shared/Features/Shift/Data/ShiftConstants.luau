--!strict
--[=[
	ShiftConstants: the shift's pacing and names (Cleanup Crew spec §3, §4 "Pacing"). Every number is a
	tuning hypothesis. Static data (spec-exempt).

	@class ShiftConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local VARIANT: ShiftTypes.Variant = "B"

return table.freeze({
	-- The StateSyncWorldStore entry the snapshot is published under.
	WORLD_ENTRY = "shift",
	-- Clearance (trash value) the crew must load.
	QUOTA = 350,
	-- 7:00 on the clock.
	SHIFT_SECONDS = 420,
	-- The arrival card (Round's countdown).
	ARRIVAL_SECONDS = 5,
	CLOCK_OUT_SECONDS = 10,
	-- How long the results vote stays open.
	VOTE_SECONDS = 30,
	MIN_PLAYERS = 1,
	VARIANT = VARIANT,
	-- Salvage multiplier now, and in overtime (M2).
	SALVAGE_MULTIPLIER = 1,
	OVERTIME_SALVAGE_MULTIPLIER = 1.5,
	-- Round team counters and per-player scores.
	CLEARANCE = "clearance",
	BONUS = "bonus",
	SCORE_BANKED = "banked",
	SCORE_PILES = "piles",
	SCORE_SALVAGE = "salvage",
	-- The outcome a clock out ends the run with (Round sets "timeout" and "abandoned" itself).
	OUTCOME_CLOCKOUT = "clockout",
	-- The outcome a mid-shift reset (Studio test runs) ends the run with; no results are shown for it.
	OUTCOME_RESET = "reset",
	-- The interaction kind on the truck's time clock.
	CLOCK_OUT_KIND = "shift-clockout",
	TICK_INTERVAL = 0.25,
	-- HUD widget order (the Toast stack draws above, at 1000).
	HUD_ORDER = 10,
})
