--!strict
--[=[
	PaperToastViewModel: how the toasts on screen are drawn on paper (Figma 1f): stamp-style toasts (QUOTA MET,
	OVERTIME) are one big centre stamp, the newest only; slip-style toasts (an appraisal: the item and its value) are
	small sticky slips stacked off-centre, newest first, at most MAX_SLIPS, a jackpot one marked; everything else is a
	taped sticky note, newest on top, at most MAX_NOTES. Notes and slips are tilted alternately by id so each keeps its
	tilt while others come and go. Pure.

	@class PaperToastViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

export type NoteView = {
	id: number,
	text: string,
	tilt: number,
}

-- A slip's text is its title (the item), then on the next line its detail (the value): "Monitor\n$36".
export type SlipView = {
	id: number,
	title: string,
	detail: string?,
	tilt: number,
	jackpot: boolean,
}

-- A screen rectangle (screen px), such as Pippa's coach card while it shows (TrainingCoachStore.area).
export type Area = {
	left: number,
	top: number,
	right: number,
	bottom: number,
}

export type ToastView = {
	stamp: NoteView?,
	notes: { NoteView },
	slips: { SlipView },
}

local PaperToastViewModel = {
	MAX_NOTES = 3,
	MAX_SLIPS = 3,
}

-- A slip leans half as far as a note: it is meant to be glanced at, not read.
local SLIP_TILT = UIPaperConstants.STICKY_TILT / 2

function PaperToastViewModel.layout(toasts: { ToastTypes.Toast }, maxNotes: number, maxSlips: number?): ToastView
	local slipLimit = maxSlips or PaperToastViewModel.MAX_SLIPS
	local stamp: NoteView? = nil
	local notes: { NoteView } = {}
	local slips: { SlipView } = {}
	for index = #toasts, 1, -1 do
		local toast = toasts[index]
		local jackpot: boolean = toast.style == ShiftConstants.TOAST_SLIP_JACKPOT
		if toast.style == ShiftConstants.TOAST_STAMP then
			if stamp == nil then
				stamp = { id = toast.id, text = toast.text, tilt = UIPaperConstants.STAMP_TILT }
			end
		elseif jackpot or toast.style == ShiftConstants.TOAST_SLIP then
			if #slips < slipLimit then
				local tilt = if toast.id % 2 == 0 then SLIP_TILT else -SLIP_TILT
				local title, detail = string.match(toast.text, "^([^\n]*)\n(.*)$")
				local slip: SlipView = {
					id = toast.id,
					title = title or toast.text,
					detail = if detail ~= nil and detail ~= "" then detail else nil,
					tilt = tilt,
					jackpot = jackpot,
				}
				table.insert(slips, slip)
			end
		elseif #notes < maxNotes then
			local tilt = if toast.id % 2 == 0 then UIPaperConstants.STICKY_TILT else -UIPaperConstants.STICKY_TILT
			table.insert(notes, { id = toast.id, text = toast.text, tilt = tilt })
		end
	end
	return { stamp = stamp, notes = notes, slips = slips }
end

-- The phone's sticky-note column (design px): centred, 250 wide, from y 86 (Figma 1d), reaching at most this far down
-- (three notes).
PaperToastViewModel.PHONE_NOTES_TOP = 86
local PHONE_NOTES_WIDTH = 250
local PHONE_NOTES_REACH = 220
local PHONE_NOTES_GAP = 10

--[=[
	Where the phone's sticky notes start (design px from the HUD frame's top): their top-centre spot, or, when Pippa's
	coach card (`coach`, screen px from the layer's top-left: TrainingCoachStore.areaOf; nil = not showing) covers that spot, just under the card, so a note is never
	hidden behind her (the card is on the Coach layer, over the HUD). `screenWidth` is the screen's width (px), `scale`
	and `shift` the HUD frame's scale and top shift (PaperHudFrame): design px = (screen px - shift) / scale.
]=]
function PaperToastViewModel.phoneNotesTop(coach: Area?, screenWidth: number, scale: number, shift: number): number
	local top = PaperToastViewModel.PHONE_NOTES_TOP
	if coach == nil or scale <= 0 then
		return top
	end
	local centre = screenWidth / scale / 2
	local left = centre - PHONE_NOTES_WIDTH / 2
	local right = centre + PHONE_NOTES_WIDTH / 2
	local coachLeft = coach.left / scale
	local coachRight = coach.right / scale
	local coachTop = (coach.top - shift) / scale
	local coachBottom = (coach.bottom - shift) / scale
	if coachRight <= left or coachLeft >= right then
		return top
	end
	if coachBottom <= top or coachTop >= top + PHONE_NOTES_REACH then
		return top
	end
	return math.ceil(coachBottom + PHONE_NOTES_GAP)
end

return PaperToastViewModel
