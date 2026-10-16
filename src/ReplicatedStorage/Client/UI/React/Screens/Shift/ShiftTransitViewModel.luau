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

export type SlipView = {
	band: string,
	truck: string?,
	title: string,
	from: string,
	to: string,
	note: string,
	stamp: string,
	arrived: boolean,
}

local ShiftTransitViewModel = {}

ShiftTransitViewModel.CLIENT_MAX = 30
ShiftTransitViewModel.NO_CLIENT = "Site on file"

function ShiftTransitViewModel.slip(snapshot: ShiftTypes.TransitSnapshot?, arrived: boolean): SlipView
	local client = if snapshot ~= nil then snapshot.client else nil
	local truck = if snapshot ~= nil then snapshot.truck else nil
	return {
		band = `{ShiftConstants.EMPLOYER_BAND} — DISPATCH`,
		truck = if truck ~= nil and truck > 0 then `TRUCK {truck}` else nil,
		title = "ROUTE SLIP",
		from = "Company depot",
		to = if client ~= nil
			then WorldBillboardViewModel.clip(client, ShiftTransitViewModel.CLIENT_MAX)
			else ShiftTransitViewModel.NO_CLIENT,
		note = "Stay in the truck. Doors open on arrival.",
		stamp = if arrived then "ARRIVED" else "IN TRANSIT",
		arrived = arrived,
	}
end

return ShiftTransitViewModel
