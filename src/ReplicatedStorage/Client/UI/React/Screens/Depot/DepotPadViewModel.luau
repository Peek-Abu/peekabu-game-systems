--!strict
--[=[
	DepotPadViewModel: the truck's queue card for a player standing in its bed (Figma 3a/3b): the truck and the job
	with the quota for the crew aboard (ShiftQuotaFormulas), "3 / 4" aboard, a slot per seat (you marked, empty seats "open"), the departure countdown, and how to leave. Pure.
	`shown` is where the card may be up at all: only in the depot hub (DepotHubViewModel.visible), so never for a crew
	member once their shift is starting, running or in results, never behind the load screen, and never once the crew
	has departed (the drive card is up). The queue snapshot alone is not enough: after a departure the party is left
	standing on the bed until the transit moves them, so Queue briefly re-boards them.

	@class DepotPadViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotHubViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotHubViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type SlotView = { name: string, open: boolean, you: boolean, userId: number? }

export type PadView = {
	title: string,
	count: string,
	slots: { SlotView },
	names: string,
	departsIn: string?,
	departing: boolean,
	hint: string,
}

export type SeatView = { open: boolean, you: boolean, userId: number? }

-- The hub's Next shift card (V1): a CTA that is always there. Not aboard: find a truck (GO! opens the Jobs board).
-- Aboard: the truck's countdown in a coral pill, a seat per place (headshots by user id) and GO! to depart now,
-- withdrawn once the truck is leaving.
export type CtaView = {
	title: string,
	aboard: boolean,
	line: string,
	time: string?,
	seats: { SeatView },
	go: string,
	canGo: boolean,
}

local DepotPadViewModel = {}

-- Whether the queue card may show: in the depot hub, with no load screen and no drive card up.
function DepotPadViewModel.shown(
	shift: ShiftTypes.ShiftSnapshot?,
	myId: number,
	covered: boolean,
	card: DepotTypes.CardKind?
): boolean
	return not covered and card ~= "drive" and DepotHubViewModel.visible(shift, myId)
end

function DepotPadViewModel.pad(
	pad: QueueTypes.PadSnapshot?,
	myId: number,
	names: { [number]: string },
	truck: number?,
	now: number,
	phone: boolean
): PadView?
	if pad == nil or table.find(pad.members, myId) == nil then
		return nil
	end
	local slots: { SlotView } = {}
	local listed: { string } = {}
	for _, userId in pad.members do
		local name = if userId == myId then "you" else names[userId] or "Crew"
		table.insert(slots, { name = name, open = false, you = userId == myId, userId = userId })
		table.insert(listed, name)
	end
	for _ = #pad.members + 1, pad.capacity do
		table.insert(slots, { name = "open", open = true, you = false })
	end
	local endsAt = pad.endsAt
	local title: string
	if phone then
		title = if truck ~= nil then `TRUCK {truck} · CREW` else "CREW"
	else
		title = if truck ~= nil then `TRUCK {truck} — {DepotConstants.JOB_TITLE}` else DepotConstants.JOB_TITLE
	end
	title = `{title} · {ShiftQuotaFormulas.quota(#pad.members)} {string.upper(ShiftConstants.CONTRACT_UNIT)}`
	return {
		title = title,
		count = `{#pad.members} / {pad.capacity}`,
		slots = slots,
		names = table.concat(listed, " · "),
		departsIn = if not pad.departing and endsAt ~= nil then ShiftHudViewModel.clock(endsAt - now) else nil,
		departing = pad.departing,
		hint = if phone
			then "Step off the truck bed to leave"
			else "Step off the bed to leave · timer resets when someone joins",
	}
end

function DepotPadViewModel.cta(view: PadView?, truck: number?): CtaView
	if view == nil then
		return {
			title = "NEXT SHIFT",
			aboard = false,
			line = "Walk into a truck bed to join",
			time = nil,
			seats = {},
			go = "GO!",
			canGo = true,
		}
	end
	local name = if truck ~= nil then `Truck {truck}` else "Your truck"
	local seats: { SeatView } = {}
	for _, slot in view.slots do
		table.insert(seats, { open = slot.open, you = slot.you, userId = slot.userId })
	end
	return {
		title = "NEXT SHIFT",
		aboard = true,
		line = if view.departing
			then `{name} is leaving!`
			elseif view.departsIn ~= nil then `{name} departs in`
			else `{name} is boarding`,
		time = if view.departing then nil else view.departsIn,
		seats = seats,
		go = "GO!",
		canGo = not view.departing,
	}
end

return DepotPadViewModel
