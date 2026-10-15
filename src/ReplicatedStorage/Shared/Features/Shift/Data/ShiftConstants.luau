--!strict
--[=[
	ShiftConstants: the shift's pacing and names (Cleanup Crew spec §3, §4 "Pacing": one constants module for
	the shift clock, the pressure tiers and the party-size scaling). Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class ShiftConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

local VARIANT: ShiftTypes.Variant = "B"
-- How each shift's variant is chosen (ShiftVariantRules): "alternate" flips A/B per shift; "fixed" always plays VARIANT.
local VARIANT_MODE: ShiftTypes.VariantMode = "alternate"

-- Cleanup Crew's two toast styles (spec §6.1 "sticky note" and "stamp"; §7 "sticky-note toasts, rubber-stamp
-- announcements"). Look from the Figma style page, pending the developer's approval; each `sound` is a
-- ShiftAssets slot (silent while pending).
local TOAST_STYLES: { [string]: ToastTypes.ToastStyle } = {
	sticky = {
		background = Color3.fromRGB(255, 226, 102),
		text = Color3.fromRGB(46, 38, 20),
		accent = Color3.fromRGB(232, 160, 40),
		font = Enum.Font.PermanentMarker,
		sound = "shiftStickyNote",
	},
	stamp = {
		background = Color3.fromRGB(244, 236, 216),
		text = Color3.fromRGB(196, 38, 38),
		accent = Color3.fromRGB(196, 38, 38),
		font = Enum.Font.Oswald,
		sound = "shiftStamp",
	},
}

-- Seconds into the shift at which the pressure tier rises (2:00 and 4:00).
local TIER_TIMES: { number } = { 120, 240 }

-- The review's rating stamp text (Figma 5a/5c) per ShiftTypes.Rating.
local RATING_TEXT: { [string]: string } = {
	needsImprovement = "NEEDS IMPROVEMENT",
	satisfactory = "SATISFACTORY",
	exceeds = "EXCEEDS EXPECTATIONS",
}

-- The joke awards' titles (Figma 5a/5c sticky notes).
local AWARD_TITLES = {
	employee = "EMPLOYEE OF THE NIGHT",
	rehired = "MOST REHIRED",
	butterfingers = "BUTTERFINGERS",
	quietest = "QUIETEST FEET",
	loudest = "LOUDEST VACUUM",
}

-- The review's closing line (Figma 5a met / 5c missed).
local REVIEW_QUOTES = {
	met = { line = '"Those were COMPANY ASSETS."', by = "— The Manager, Site Supervisor Proxy" },
	missed = { line = '"We will discuss this on Monday."', by = "— Morrow & Morrow, Human Resources" },
}

return table.freeze({
	-- The crew's employer (docs/cleanup-crew-lore.md): its name, the letterhead form on every company paper (time
	-- card, dispatch, HR) and its slogan. The client whose site is cleared is the contract's (DepotConstants.CONTRACTS).
	EMPLOYER = "Morrow & Morrow Clearance",
	EMPLOYER_BAND = "MORROW & MORROW",
	EMPLOYER_SLOGAN = "A clean site is a compliant site.",
	-- The company scrip associates are paid in for banked Recoverable Assets. Display only (no saved balance yet):
	-- rename it here and every price tag, floater, plate and review follows (ShiftCurrencyUtils).
	CURRENCY_NAME = "Scrip",
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
	-- Seconds after the client starts before it reports its platform (the viewport has its real size by then).
	PLATFORM_REPORT_DELAY = 2,
	VARIANT_MODE = VARIANT_MODE,
	-- The Workspace attribute a developer sets to "A" or "B" to force the next shifts' variant (testing only;
	-- remove it before publishing: Workspace is the place's, so a saved attribute ships).
	VARIANT_ATTRIBUTE = "CleanupCrewVariant",
	-- Salvage multiplier normally, and in overtime.
	SALVAGE_MULTIPLIER = 1,
	OVERTIME_SALVAGE_MULTIPLIER = 1.5,
	-- After the quota: the Manager's break (time to bank and regroup), then the normal stage again. Overtime is opt-in:
	-- a crew member holds the truck's Start overtime prompt (OVERTIME_KIND, OVERTIME_HOLD seconds), the overtime warning
	-- runs WARNING_SECONDS, then overtime lasts until the shift ends.
	BREAK_SECONDS = 30,
	WARNING_SECONDS = 30,
	-- Pressure tiers: each step multiplies Harlow's hearing and adds to his patrol speed; overtime is the top.
	TIER_TIMES = table.freeze(TIER_TIMES),
	TOP_TIER = 2,
	TIER_HEARING = 1.2,
	TIER_PATROL_SPEED = 1,
	TIER_CHASE_SPEED = 0.5,
	-- A solo player gets a gentler Harlow.
	SOLO_HEARING = 0.75,
	SOLO_CHASE_SPEED = -0.5,
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
	-- The interaction kind on the truck's overtime sheet (beside the time clock), and how long its prompt is held: a
	-- deliberate choice, never a stray key press.
	OVERTIME_KIND = "shift-overtime",
	OVERTIME_HOLD = 1.5,
	-- The truck's paperwork (the time clock and the overtime sheet) hangs inside the box on its front wall. Clock out
	-- is held CLOCK_OUT_HOLD seconds; both prompts show within PAPERWORK_DISTANCE studs, and only to an empty-handed
	-- crew member standing in front of the item inside the box (ShiftTimeClockRules: PAPERWORK_REACH, studs in the
	-- item's own space, -Z out of the wall), so neither ever competes with Bank cargo.
	CLOCK_OUT_HOLD = 1.5,
	PAPERWORK_DISTANCE = 7,
	PAPERWORK_REACH = table.freeze({ depth = 6, halfWidth = 4.5, below = 3, above = 1.5 }),
	TICK_INTERVAL = 0.25,
	-- How long the pacing notices stay up.
	NOTICE_SECONDS = 6,
	-- After Back to depot: how long the crew may still be here before the trip counts as failed and the next
	-- shift may start. Queue's return trip makes up to 4 tries, each watched for QueueConstants.TELEPORT_WATCHDOG
	-- (30 s), with 1 + 2 + 4 s between them: 127 s at worst. Only a crew still here waits it out.
	RETURN_WAIT_SECONDS = 130,
	-- HUD widget order (the Toast stack draws above, at 1000).
	HUD_ORDER = 10,
	-- Toast styles (registered by both Shift services at load) and how long a stamp stays up.
	TOAST_STICKY = "sticky",
	TOAST_STAMP = "stamp",
	TOAST_STYLES = table.freeze(TOAST_STYLES),
	STAMP_SECONDS = 3,
	-- The review's rating (Figma 35:1096): quota met and at least LOADED of every OF salvage offered was loaded ->
	-- EXCEEDS EXPECTATIONS. Decided by the developer (the default share rule); integers so the comparison has no float edge.
	RATING_EXCEEDS_LOADED = 2,
	RATING_EXCEEDS_OF = 3,
	RATING_TEXT = table.freeze(RATING_TEXT),
	AWARD_TITLES = table.freeze(AWARD_TITLES),
	-- The fourth award is LOUDEST VACUUM when someone's noise sent Harlow to investigate this many times, else QUIETEST FEET.
	LOUDEST_MIN_WOKE = 3,
	REVIEW_QUOTES = table.freeze(REVIEW_QUOTES),
	-- The performance review scene (ShiftScene): pushed when results begin, removed when they end.
	REVIEW_SCENE = "shift.Review",
	-- Feel (spec §7): the quota's FOV kick, the camera shake of a tier rise and of overtime, the overtime ticking
	-- layer's ambience slot, and the clock-out countdown's louder last seconds. The client re-checks every
	-- FEEDBACK_INTERVAL seconds.
	QUOTA_FOV_KICK = 8,
	QUOTA_FOV_SECONDS = 0.6,
	TIER_TRAUMA = 0.2,
	OVERTIME_TRAUMA = 0.3,
	TICKING_LAYER = "shiftOvertime",
	COUNTDOWN_LOUD = 3,
	COUNTDOWN_LOUD_SCALE = 1.6,
	FEEDBACK_INTERVAL = 0.1,
	-- Crew status public fields (M3 UI: the crew roster and the CCTV), published by ShiftCrewStatusSystem every
	-- CREW_STATUS_INTERVAL seconds while a shift runs. Flags are present only while true.
	PUBLIC_IN_TRUCK = "inTruck",
	PUBLIC_VACUUMING = "vacuuming",
	PUBLIC_ROOM = "room",
	PUBLIC_ROOM_DEPTH = "roomDepth",
	PUBLIC_CAM = "cam",
	CREW_STATUS_INTERVAL = 0.25,
	-- The CCTV's fictional night clock (Figma 4b "THU 03:44:12"): 03:00:00 at the shift's start.
	NIGHT_CLOCK_START = 3 * 3600,
	NIGHT_DAY = "THU",
})
