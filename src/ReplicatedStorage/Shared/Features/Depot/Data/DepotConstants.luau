--!strict
--[=[
	DepotConstants: the depot's names, the place ids, tonight's contracts, and the travel cards'
	timings and texts (Cleanup Crew spec §2, §3, §5). Static data (spec-exempt).

	@class DepotConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

-- The contract board's work order (Figma 2a/2b). Quota and shift lines are filled from ShiftConstants by
-- DepotBoardViewModel; NOTES is the contract's own note. The quota line is for the crew in the reader's truck
-- (ShiftQuotaFormulas), or the range by crew size when they are not in one; worded for young players.
local BOARD_COPY = table.freeze({
	title = "TONIGHT'S JOB",
	-- The contract is Gloom removed (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §5):
	-- dust counts the moment it is vacuumed, a valuable only for the grime cleaned off it.
	-- string.format patterns: the contract, then the crew size (or the largest crew's contract).
	quotaCrew = "Remove %d Gloom for your crew of %d. Vacuum the dust; clean treasure before you pick it up.",
	quotaSolo = "Remove %d Gloom on your own. Vacuum the dust; clean treasure before you pick it up.",
	quotaRange = "Remove %d Gloom for one player, up to %d for four. Vacuum the dust; clean treasure before you pick it up.",
	quotaPhoneCrew = "Remove %d Gloom",
	quotaPhoneRange = "Remove %d–%d Gloom",
	-- The PAY row: Credits per Gloom at the end of the shift, plus the valuables banked.
	pay = "1 Credit per Gloom removed, paid at the end of the shift, plus every treasure you load, at its value (x1.5 in overtime).",
	payPhone = "1 Credit per Gloom, plus treasure",
	shift = "on the clock. Clock out at the truck any time.",
	shiftPhone = "clock out at the truck",
	crew = "1–4 per truck. 6 with Big Crew.",
	-- Any map's monster (a truck may pick the Office or the School).
	hazard = "Monsters roam the site. They hear vacuums and things you drop. Empty hands run faster.",
	hazardPhone = "Monsters hear vacuums and drops",
	sticky = "Lights on the 4th floor again?? — night guard",
	approved = "APPROVED",
	dispatchLabel = "DISPATCH · HOW TO START",
	dispatchTitle = "JOIN A SHIFT",
	dispatchSteps = "1.  Walk up a truck ramp in any bay.\n2.  The first one in is the host. The host presses START.",
	dispatchPhone = "Walk up a truck ramp in any bay.",
	close = "CLOSE  [Esc]",
})

-- The hub: the experience's start place (public servers, the lobby).
-- Both ids are registered through DepotPlaceUtils.roles; while either is 0, both register as 0 and the server plays both roles.
local HUB_PLACE_ID = 113354563835664
local SHIFT_PLACE_ID = 118845637680835

-- Tonight's job rotates by UTC day (DepotContractUtils.tonight). The Office's jobs are all Harlow & Finch: there is one
-- office. A School run's jobs are SCHOOL_CONTRACTS (DepotMapRules.contractsOf picks a map's list).
local CONTRACTS: { DepotTypes.Contract } = {
	{
		id = "harlow-finch-1",
		client = "Harlow & Finch Ltd.",
		job = "Clear the office before the sale.",
		note = "The bank says the building is empty.",
	},
	{
		id = "harlow-finch-2",
		client = "Harlow & Finch Ltd.",
		job = "The bank wants every floor spotless.",
		note = "Someone saw lights on after midnight.",
	},
	{
		id = "harlow-finch-3",
		client = "Harlow & Finch Ltd.",
		job = "Final clearance before the auction.",
		note = "The manager never handed in his keys.",
	},
}

-- The School's jobs (the School map plan): Maple Hill School, worded for young players. Ids never repeat the Office's.
local SCHOOL_CONTRACTS: { DepotTypes.Contract } = {
	{
		id = "maple-hill-1",
		client = "Maple Hill School",
		job = "Clean the school before Monday.",
		note = "The owl mascot is not where we left it.",
	},
	{
		id = "maple-hill-2",
		client = "Maple Hill School",
		job = "Make the halls shine for picture day.",
		note = "The night guard heard wings in the gym.",
	},
	{
		id = "maple-hill-3",
		client = "Maple Hill School",
		job = "Clean every classroom before the bell.",
		note = "Someone keeps moving the owl.",
	},
}

-- Each map's words during a run (DepotMapRules.siteOf): the route slip's site line and tip (the tip is about the map's
-- monster, its OccupantRosterRegistry pick), the HUD meter's site line, and the shift review's tab and closing quote
-- when the goal is met, and the monster kind the tip is about (its portrait). The Office's are the words it always had.
local OFFICE_SITE: DepotTypes.MapSite = {
	site = "4th floor offices",
	hud = "Harlow & Finch · offices",
	tip = "The Manager is here. He hears vacuums and things you drop. Empty hands run faster.",
	reviewTab = "SHIFT REVIEW · HARLOW & FINCH",
	quote = ShiftConstants.REVIEW_QUOTES.met,
	monster = "harlow",
}
local SCHOOL_SITE: DepotTypes.MapSite = {
	site = "School halls",
	hud = "Maple Hill · school",
	tip = "Bramble the owl can't move while you look at it. Watch it and take turns!",
	reviewTab = "SHIFT REVIEW · MAPLE HILL SCHOOL",
	quote = table.freeze({ line = '"The halls have never been so shiny!"', by = "— Maple Hill School, Front Desk" }),
	monster = "bramble",
}

return table.freeze({
	ROLE_DEPOT = "depot",
	ROLE_SHIFT = "shift",
	HUB_PLACE_ID = HUB_PLACE_ID,
	SHIFT_PLACE_ID = SHIFT_PLACE_ID,
	CONTRACTS = table.freeze(CONTRACTS),
	SCHOOL_CONTRACTS = table.freeze(SCHOOL_CONTRACTS),
	OFFICE_SITE = table.freeze(OFFICE_SITE),
	SCHOOL_SITE = table.freeze(SCHOOL_SITE),
	-- How long each travel card stays up; a card that arrives while another shows waits behind it.
	DRIVE_CARD_SECONDS = 3,
	ARRIVAL_CARD_SECONDS = 5,
	MAX_QUEUED_CARDS = 3,
	-- HUD widget order: above Queue's pad widget (900), under the toasts (1000).
	HUD_ORDER = 950,
	RESULT_BOARD_TITLE = "HOW YOU DID",
	-- M3 UI. The most trucks a depot layout has (the truck number riding the teleport is checked against it).
	MAX_TRUCKS = 4,
	-- The map pick (the School map plan; the ids and who may pick are DepotMapRules): the world entry that publishes
	-- each truck's pick ({ [Queue pad id]: map id }), the pick's request rate, and the cards' words (kid reading level).
	MAP_WORLD_ENTRY = "depotMap",
	MAP_REQUEST_RATE = table.freeze({ maxRequests = 6, windowSeconds = 5 }),
	MAP_TEXT = table.freeze({
		office = "OFFICE",
		school = "SCHOOL",
		hostPicks = "The host picks the place.",
		youPick = "Tap to pick a place!",
	}),
	-- Public player field: the truck whose bed a player stands in (the queue pad card's "TRUCK 2").
	PUBLIC_TRUCK = "truck",
	-- The contract board's Interaction kind (its prompt opens the board scene).
	BOARD_KIND = "depot-board",
	-- The contract board's scene (DepotScene registers it; DepotBoardScreen's CLOSE removes it).
	BOARD_SCENE = "depot.Board",
	-- Every Office contract is the same office (open question 8); a School run's site is SCHOOL_SITE's.
	SITE = OFFICE_SITE.site,
	JOB_TITLE = "HARLOW & FINCH JOB",
	BOARD_COPY = BOARD_COPY,
	RETURN_TEXT = "Back at the depot. See how you did on the board.",
	-- M3b world UI. The depot's signs are drawn at Figma's "1 px ≈ 1/40 stud": a shell's size in studs is its design
	-- size in px times STUDS_PER_PX. BILLBOARD_PX is each sign's design size (the truck tag includes its 60 px wire).
	STUDS_PER_PX = 1 / 40,
	-- The small signs (the clock's and the daily sheet) are drawn finer: 64 px a stud.
	SMALL_SIGN_STUDS_PER_PX = 1 / 64,
	BILLBOARD_PX = table.freeze({
		truck = Vector2.new(340, 310),
		contract = Vector2.new(600, 420),
		result = Vector2.new(1140, 446),
		-- The weekly crew leaderboard (LeaderboardBoard).
		crew = Vector2.new(720, 560),
		-- The weekly time clock's sign over the clock, and the daily bonus sheet (owner 11-11: the game's kit).
		clock = Vector2.new(320, 150),
		daily = Vector2.new(300, 380),
		-- The rank ladder on the hub's rank poster (a Studio-placed shell; owner 11-12, kit mock round 2 #2).
		rank = Vector2.new(420, 588),
	}),
	-- The tags the client finds each kind of depot shell by (DepotBillboardSystem); `review` is your own card's shell.
	BILLBOARD_TAGS = table.freeze({
		truck = "DepotTruckTag",
		contract = "DepotContractBoard",
		result = "DepotResultBoard",
		review = "DepotReviewCard",
		crew = "DepotCrewBoard",
		clock = "DepotClockSign",
		daily = "DepotDailySign",
		rank = "DepotRankBoard",
	}),
	-- A truck tag shell's truck number and seats, written once by the server.
	TRUCK_ATTRIBUTE = "DepotTruck",
	CAPACITY_ATTRIBUTE = "DepotCapacity",
	-- The truck's scanner arch light (DepotTruckVisualSystem tags it; DepotTruckScannerSystem flashes it on a bank):
	-- its sweep runs from the SCANNER_SWEEP_TOP attachment down to SCANNER_SWEEP_BOTTOM, SCANNER_WIDTH wide, and it
	-- settles back to its SCANNER_IDLE colour.
	SCANNER_TAG = "DepotTruckScanner",
	-- Crew hosting (batch 4): a truck's art model is tagged TRUCK_ART_TAG with an ObjectValue TRUCK_BED_LINK to its bed,
	-- and its opaque camera-shell cores carry TRUCK_SHELL_ATTRIBUTE, so the client draws an empty held bay as a ghost
	-- and pops the host's truck in (DepotTruckGhostSystem).
	TRUCK_ART_TAG = "DepotTruckArt",
	TRUCK_BED_LINK = "Bed",
	TRUCK_SHELL_ATTRIBUTE = "DepotTruckShell",
	SCANNER_SWEEP_TOP = "ScanSweepTop",
	SCANNER_SWEEP_BOTTOM = "ScanSweepBottom",
	SCANNER_WIDTH_ATTRIBUTE = "ScanSweepWidth",
	SCANNER_IDLE_ATTRIBUTE = "ScanIdleColor",
	-- A truck tag's line 3 turns red ("Leaving in 0:08") when the truck is full or this many seconds or fewer remain.
	TAG_WARN_SECONDS = 10,
	-- The contract board shell's attributes (DepotContractUtils.boardAttributes -> DepotWorldViewModel.workOrder).
	CONTRACT_KEYS = table.freeze({
		id = "ContractId",
		client = "ContractClient",
		job = "ContractJob",
	}),
	-- Your review card shell's attributes (ShiftCardUtils.attributes -> DepotWorldViewModel.review). `crew`,
	-- `awardTitle` and `awardName` are prefixes: crew line i is "ReviewCrew<i>", award i "ReviewAwardTitle<i>" and
	-- "ReviewAwardName<i>".
	REVIEW_KEYS = table.freeze({
		client = "ReviewClient",
		cleared = "ReviewCleared",
		quota = "ReviewQuota",
		bonus = "ReviewBonus",
		catches = "ReviewCatches",
		salvage = "ReviewSalvage",
		offered = "ReviewOffered",
		met = "ReviewMet",
		rating = "ReviewRating",
		truck = "ReviewTruck",
		crew = "ReviewCrew",
		awardTitle = "ReviewAwardTitle",
		awardName = "ReviewAwardName",
	}),
})
