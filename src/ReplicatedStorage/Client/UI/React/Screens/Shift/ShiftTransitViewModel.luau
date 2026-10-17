--!strict
--[=[
	ShiftTransitViewModel: the transit screen's route slip (ShiftTransitPanel). A dispatch slip on the company's paper:
	the "MORROW & MORROW — DISPATCH" band with "TRUCK n" (none when unknown), ROUTE SLIP, FROM the company depot TO the
	contract's client (cut at CLIENT_MAX; "Site on file" before the server names one), a note, and the red IN TRANSIT
	stamp, which turns to ARRIVED once this client is ready. Pure.

	@class ShiftTransitViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type SlipView = {
	band: string,
	truck: string?,
	title: string,
	from: string,
	to: string,
	note: string,
	stamp: string,
	arrived: boolean,
	-- V1: the card's heading over the client ("EN ROUTE TO" / "ARRIVED AT"), the client in caps without its company
	-- suffix, the site line, the Manager tip and the loading bar's words.
	heading: string,
	client: string,
	site: string,
	tip: string,
	bar: string,
}

local ShiftTransitViewModel = {}

ShiftTransitViewModel.CLIENT_MAX = 30
ShiftTransitViewModel.NO_CLIENT = "Site on file"

-- The V1 load screen's design canvas (1440x720) fitted to a window: never under 0.3 or over 1.25.
function ShiftTransitViewModel.fit(viewport: Vector2): number
	return math.clamp(math.min(viewport.X / 1500, viewport.Y / 780), 0.3, 1.25)
end

function ShiftTransitViewModel.slip(snapshot: ShiftTypes.TransitSnapshot?, arrived: boolean): SlipView
	local client = if snapshot ~= nil then snapshot.client else nil
	local truck = if snapshot ~= nil then snapshot.truck else nil
	local to = if client ~= nil
		then WorldBillboardViewModel.clip(client, ShiftTransitViewModel.CLIENT_MAX)
		else ShiftTransitViewModel.NO_CLIENT
	return {
		heading = if arrived then "ARRIVED AT" else "EN ROUTE TO",
		client = (string.gsub(string.upper(to), "%s+LTD%.?$", "")),
		site = `{DepotConstants.SITE} · {ShiftHudViewModel.clock(ShiftConstants.SHIFT_SECONDS)} shift`,
		tip = DepotConstants.BOARD_COPY.hazard,
		bar = if arrived then "DOORS OPEN!" else "DRIVING TO THE SITE...",
		band = `{ShiftConstants.EMPLOYER_BAND} — DISPATCH`,
		truck = if truck ~= nil and truck > 0 then `TRUCK {truck}` else nil,
		title = "ROUTE SLIP",
		from = "Company depot",
		to = to,
		note = "Stay in the truck. Doors open on arrival.",
		stamp = if arrived then "ARRIVED" else "IN TRANSIT",
		arrived = arrived,
	}
end

return ShiftTransitViewModel
