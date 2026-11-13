--!strict
--[=[
	DepotClipboardViewModel: what the Company Clipboard shows, in as few words as possible (owner pick 2026-11-13,
	layout A, "cut the small lines"). The Timecard is a track of punch slots (done, today's, empty), with the Gloom Key
	hung on the key punch and the Gleam on the last; the paycheck is a row of dots, one per full week. Today's Job counts
	down to the next UTC day in hours and minutes. Pure.

	@class DepotClipboardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local TimecardRules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)

export type SlotState = "done" | "today" | "empty"
export type Prize = "key" | "gleam"
export type Slot = { number: number, state: SlotState, prize: Prize? }
export type Paycheck = { filled: number, total: number, credits: number }

local DAY_SECONDS = 86400

local DepotClipboardViewModel = {}

-- The clipboard's layout in design px. The board holds the tabs and one sheet; everything on a sheet is in the sheet's
-- own px. The punch slots sit on one track, one every `SLOT_STEP`, so today's stamp lands on its slot (`slotCenter`).
DepotClipboardViewModel.BOARD = Vector2.new(680, 452)
DepotClipboardViewModel.SHEET = Vector2.new(640, 332)
DepotClipboardViewModel.SHEET_AT = Vector2.new(20, 100)
DepotClipboardViewModel.SLOT = 84
DepotClipboardViewModel.SLOT_STEP = 120
DepotClipboardViewModel.SLOT_FIRST = Vector2.new(80, 112)
-- Where today's punch banner pops (its centre, sheet px).
DepotClipboardViewModel.BANNER = Vector2.new(320, 196)

-- The centre of punch slot `number` (1-based) in sheet px.
function DepotClipboardViewModel.slotCenter(number: number): Vector2
	local first = DepotClipboardViewModel.SLOT_FIRST
	return Vector2.new(first.X + (number - 1) * DepotClipboardViewModel.SLOT_STEP, first.Y)
end

-- One slot per punch the card needs (TimecardConstants.PUNCHES_TO_FILL): the punches in, then today's (when today can
-- still be punched), then the empty ones.
function DepotClipboardViewModel.slots(status: TimecardRules.Status): { Slot }
	local slots: { Slot } = {}
	for number = 1, TimecardConstants.PUNCHES_TO_FILL do
		local state: SlotState = if number <= status.count
			then "done"
			elseif number == status.count + 1 and status.canPunch then "today"
			else "empty"
		local prize: Prize? = if number == TimecardConstants.KEY_PUNCH
			then "key"
			elseif number == TimecardConstants.PUNCHES_TO_FILL then "gleam"
			else nil
		table.insert(slots, { number = number, state = state, prize = prize })
	end
	return slots
end

-- "2 of 5 done", or "Card full!".
function DepotClipboardViewModel.done(status: TimecardRules.Status): string
	if status.count >= TimecardConstants.PUNCHES_TO_FILL then
		return "Card full!"
	end
	return `{status.count} of {TimecardConstants.PUNCHES_TO_FILL} done`
end

-- The paycheck row: a dot per full week toward it.
function DepotClipboardViewModel.paycheck(status: TimecardRules.Status): Paycheck
	local total = TimecardConstants.PAYCHEQUE_WEEKS
	return {
		filled = math.clamp(total - status.weeksToPaycheque, 0, total),
		total = total,
		credits = TimecardConstants.PAYCHEQUE_CREDITS,
	}
end

-- "NEW JOB IN 5H 12M" until the next UTC day (a new daily order); under an hour, minutes only (rounded up).
function DepotClipboardViewModel.newJob(now: number): string
	local remaining = DAY_SECONDS - (now % DAY_SECONDS)
	local minutes = math.ceil(remaining / 60)
	local hours = math.floor(minutes / 60)
	if hours == 0 then
		return `NEW JOB IN {minutes}M`
	end
	return `NEW JOB IN {hours}H {minutes % 60}M`
end

return DepotClipboardViewModel
