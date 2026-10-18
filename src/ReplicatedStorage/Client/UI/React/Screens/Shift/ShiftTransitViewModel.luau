--!strict
--[=[
	ShiftTransitViewModel: the transit screen's route slip (ShiftTransitPanel). A dispatch slip on the company's paper:
	the "MORROW & MORROW — DISPATCH" band with "TRUCK n" (none when unknown), ROUTE SLIP, FROM the company depot TO the
	contract's client (cut at CLIENT_MAX; "Site on file" before the server names one), a note, and the red IN TRANSIT
	stamp, which turns to ARRIVED once this client is ready. `advance` moves the loading bar toward the client's
	readiness. Pure.

	@class ShiftTransitViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
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

-- The V1 load screen's design canvas fitted to a window: never under 0.3, at most 1.25x the one UI scale.
function ShiftTransitViewModel.fit(viewport: Vector2): number
	-- The slip's 1500x780 design is drawn 1.25x on the 1920x1080 reference, and grows with the one UI scale above it.
	local cap = 1.25 * PaperHudScaleViewModel.scale(viewport, "desktop")
	return math.clamp(math.min(viewport.X / 1500, viewport.Y / 780), 0.3, cap)
end

-- The loading bar's motion (ShiftTransitViewModel.advance): it closes on the readiness at CATCH_RATE, then creeps on
-- at CREEP_RATE toward BAR_CREEP past it (never past BAR_CAP before arrival), and once arrived eases to full at
-- ARRIVE_RATE, no slower than ARRIVE_SPEED per second, so it is full within the ARRIVED beat.
ShiftTransitViewModel.CATCH_RATE = 4
ShiftTransitViewModel.CREEP_RATE = 0.25
ShiftTransitViewModel.BAR_CREEP = 0.12
ShiftTransitViewModel.BAR_CAP = 0.97
ShiftTransitViewModel.ARRIVE_RATE = 12
ShiftTransitViewModel.ARRIVE_SPEED = 2.5

--[=[
	The loading bar's next fill, `dt` seconds after it showed `shown`, with the client's readiness at `target`
	(ShiftTransitRules.progress) and `arrived` once it is ready: monotonic (never less than `shown`), never full before
	arrival, full once arrived.
]=]
function ShiftTransitViewModel.advance(shown: number, target: number, arrived: boolean, dt: number): number
	if dt ~= dt or dt <= 0 then
		return shown
	end
	local nextValue: number
	if arrived then
		local eased = shown + (1 - shown) * (1 - math.exp(-ShiftTransitViewModel.ARRIVE_RATE * dt))
		nextValue = math.max(eased, shown + ShiftTransitViewModel.ARRIVE_SPEED * dt)
		if nextValue >= 0.998 then
			nextValue = 1
		end
	else
		local safe = if target == target then math.clamp(target, 0, 1) else 0
		local goal = math.min(safe + ShiftTransitViewModel.BAR_CREEP, ShiftTransitViewModel.BAR_CAP)
		local rate = if shown < safe then ShiftTransitViewModel.CATCH_RATE else ShiftTransitViewModel.CREEP_RATE
		nextValue = shown + (goal - shown) * (1 - math.exp(-rate * dt))
	end
	return math.clamp(math.max(shown, nextValue), 0, 1)
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
