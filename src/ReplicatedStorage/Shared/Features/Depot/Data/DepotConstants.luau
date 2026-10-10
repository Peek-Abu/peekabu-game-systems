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
	RETURN_TEXT = "Back at the depot. Your performance review is pinned on the board.",
})
