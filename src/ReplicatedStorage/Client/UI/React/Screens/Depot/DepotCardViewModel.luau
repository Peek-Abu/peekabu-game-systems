--!strict
--[=[
	DepotCardViewModel: the travel cards' lines (Figma World UI 2c, S1). The drive card is a dispatch ticket: the
	"MORROW & MORROW — DISPATCH" letterhead, "TRUCK n" (none when unknown), ON THE ROAD and where the truck is heading,
	shown for DepotConstants.DRIVE_CARD_SECONDS (the truck crosses the road in that time). The arrival card is the job
	folder: the ARRIVAL tab, the client as headline, the job line, the clearance-contract slip ("CLEAR 350 / of trash
	before 7:00") and the contract's note. A client name is cut at CLIENT_MAX on both (it rides the teleport). Pure.

	@class DepotCardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type DriveView = {
	band: string,
	truck: string?,
	title: string,
	heading: string,
	-- How long the card shows: the truck block crosses the road in this time.
	seconds: number,
}

export type ArrivalView = {
	tab: string,
	client: string,
	job: string,
	slip: string,
	clear: string,
	before: string,
	note: string,
}

local DepotCardViewModel = {}

DepotCardViewModel.CLIENT_MAX = 30

function DepotCardViewModel.drive(card: DepotTypes.ShownCard): DriveView
	return {
		band = `{ShiftConstants.EMPLOYER_BAND} — DISPATCH`,
		truck = if card.truck > 0 then `TRUCK {card.truck}` else nil,
		title = "ON THE ROAD",
		heading = `Heading to {WorldBillboardViewModel.clip(card.client, DepotCardViewModel.CLIENT_MAX)}`,
		seconds = DepotConstants.DRIVE_CARD_SECONDS,
	}
end

function DepotCardViewModel.arrival(card: DepotTypes.ShownCard): ArrivalView
	return {
		tab = "ARRIVAL",
		client = WorldBillboardViewModel.clip(card.client, DepotCardViewModel.CLIENT_MAX),
		job = card.job,
		slip = "CLEARANCE CONTRACT",
		clear = `CLEAR {card.quota}`,
		before = `of site buildup before {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)}`,
		note = card.note,
	}
end

return DepotCardViewModel
