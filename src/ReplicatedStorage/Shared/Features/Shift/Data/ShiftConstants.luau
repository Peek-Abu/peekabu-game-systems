--!strict
--[=[
	ShiftConstants: the shift's pacing and names (Cleanup Crew spec §3, §4 "Pacing": one constants module for
	the shift clock, the pressure tiers and the party-size scaling). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class ShiftConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local VARIANT: ShiftTypes.Variant = "B"

-- Seconds into the shift at which the pressure tier rises (2:00 and 4:00).
local TIER_TIMES: { number } = { 120, 240 }

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
	-- Salvage multiplier normally, and in overtime.
	SALVAGE_MULTIPLIER = 1,
	OVERTIME_SALVAGE_MULTIPLIER = 1.5,
	-- After the quota: Harlow's break, then the overtime warning, then overtime (until the shift ends).
	BREAK_SECONDS = 30,
	WARNING_SECONDS = 30,
	-- Pressure tiers: each step multiplies Harlow's hearing and adds to his patrol speed; overtime is the top.
	TIER_TIMES = table.freeze(TIER_TIMES),
	TOP_TIER = 2,
	TIER_HEARING = 1.2,
	TIER_PATROL_SPEED = 1,
	-- A solo player gets a gentler Harlow.
	SOLO_HEARING = 0.75,
	SOLO_CHASE_SPEED = -1,
	-- Round team counters and per-player scores.
	CLEARANCE = "clearance",
	BONUS = "bonus",
	SCORE_BANKED = "banked",
	SCORE_PILES = "piles",
	SCORE_SALVAGE = "salvage",
	SCORE_CAUGHT = "caught",
	-- The outcome a clock out ends the run with (Round sets "timeout" and "abandoned" itself).
	OUTCOME_CLOCKOUT = "clockout",
	-- The outcome a mid-shift reset (Studio test runs) ends the run with; no results are shown for it.
	OUTCOME_RESET = "reset",
	-- The interaction kind on the truck's time clock.
	CLOCK_OUT_KIND = "shift-clockout",
	TICK_INTERVAL = 0.25,
	-- How long the pacing notices stay up.
	NOTICE_SECONDS = 6,
	-- After Back to depot: how long the crew may still be here before the trip counts as failed and the next
	-- shift may start. Queue's return trip makes up to 4 tries, each watched for QueueConstants.TELEPORT_WATCHDOG
	-- (30 s), with 1 + 2 + 4 s between them: 127 s at worst. Only a crew still here waits it out.
	RETURN_WAIT_SECONDS = 130,
	-- HUD widget order (the Toast stack draws above, at 1000).
	HUD_ORDER = 10,
})
