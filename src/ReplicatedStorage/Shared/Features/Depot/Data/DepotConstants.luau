--!strict
--[=[
	DepotConstants: the depot's names, the place-role table, tonight's contracts, and the travel cards'
	timings and texts (Cleanup Crew spec §2, §3, §5). Static data (spec-exempt).

	@class DepotConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

-- The place-role table, registered in Queue's QueueRegistry by DepotServiceServer at load. Keys are the
-- role names below. 0 is Queue's placeholder PlaceId: that role is reached by a local move (both roles in
-- one server) until its real PlaceId is filled in. See docs/cleanup-crew-publish.md.
-- The contract board's work order (Figma 2a/2b). Quota and shift lines are filled from ShiftConstants by
-- DepotBoardViewModel; NOTES is the contract's own note.
local BOARD_COPY = table.freeze({
	title = "TONIGHT'S JOB",
	quota = "clearance (rubbish bags, dust bags, recycling)",
	quotaPhone = "clearance",
	shift = "on the clock. Clock out at the truck any time.",
	shiftPhone = "clock out at the truck",
	fee = "Salvage you load is auctioned. The crew keeps the fee.",
	feePhone = "Salvage → finder's fee",
	crew = "1–4 per truck.",
	hazard = "The Manager is on site. Hears vacuums and dropped items. Empty hands run faster.",
	hazardPhone = "The Manager hears vacuums and drops",
	sticky = "Lights on the 4th floor again?? — night guard",
	approved = "APPROVED",
	dispatchLabel = "DISPATCH · HOW TO START",
	dispatchTitle = "JOIN A SHIFT",
	dispatchSteps = "1.  Walk into a truck bed outside.\n2.  Anyone aboard presses DEPART NOW.",
	dispatchPhone = "Walk into a truck bed outside.",
	close = "CLOSE  [Esc]",
})

local PLACE_IDS: { [string]: number } = {
	-- PLACEHOLDER: the depot place (the experience's start place).
	depot = 0,
	-- PLACEHOLDER: the shift place, once the developer creates it in the experience.
	shift = 0,
}

-- Tonight's job rotates by UTC day (DepotContractUtils.tonight). All are Harlow & Finch: there is one office.
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
		note = "Someone reported lights on after midnight.",
	},
	{
		id = "harlow-finch-3",
		client = "Harlow & Finch Ltd.",
		job = "Final clearance before the auction.",
		note = "The manager never handed in his keys.",
	},
}

return table.freeze({
	ROLE_DEPOT = "depot",
	ROLE_SHIFT = "shift",
	PLACE_IDS = table.freeze(PLACE_IDS),
	CONTRACTS = table.freeze(CONTRACTS),
	-- How long each travel card stays up; a card that arrives while another shows waits behind it.
	DRIVE_CARD_SECONDS = 3,
	ARRIVAL_CARD_SECONDS = 5,
	MAX_QUEUED_CARDS = 3,
	-- HUD widget order: above Queue's pad widget (900), under the toasts (1000).
	HUD_ORDER = 950,
	RESULT_BOARD_TITLE = "PERFORMANCE REVIEWS",
	-- M3 UI. The most trucks a depot layout has (the truck number riding the teleport is checked against it).
	MAX_TRUCKS = 4,
	-- Public player field: the truck whose bed a player stands in (the queue pad card's "TRUCK 2").
	PUBLIC_TRUCK = "truck",
	-- The contract board's Interaction kind (its prompt opens the board scene).
	BOARD_KIND = "depot-board",
	-- The contract board's scene (DepotScene registers it; DepotBoardScreen's CLOSE removes it).
	BOARD_SCENE = "depot.Board",
	-- Every contract is the same office (open question 8).
	SITE = "4th floor offices",
	JOB_TITLE = "HARLOW & FINCH JOB",
	BOARD_COPY = BOARD_COPY,
	RETURN_TEXT = "Back at the depot. Your performance review is pinned on the board.",
	-- M3b world UI. The depot's signs are drawn at Figma's "1 px ≈ 1/40 stud": a shell's size in studs is its design
	-- size in px times STUDS_PER_PX. BILLBOARD_PX is each sign's design size (the truck tag includes its 60 px wire).
	STUDS_PER_PX = 1 / 40,
	BILLBOARD_PX = table.freeze({
		truck = Vector2.new(340, 310),
		contract = Vector2.new(600, 420),
		result = Vector2.new(1140, 446),
	}),
	-- The tags the client finds each kind of depot shell by (DepotBillboardSystem); `review` is your own card's shell.
	BILLBOARD_TAGS = table.freeze({
		truck = "DepotTruckTag",
		contract = "DepotContractBoard",
		result = "DepotResultBoard",
		review = "DepotReviewCard",
	}),
	-- A truck tag shell's truck number and seats, written once by the server.
	TRUCK_ATTRIBUTE = "DepotTruck",
	CAPACITY_ATTRIBUTE = "DepotCapacity",
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
