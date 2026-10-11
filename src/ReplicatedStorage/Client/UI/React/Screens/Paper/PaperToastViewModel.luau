--!strict
--[=[
	PaperToastViewModel: how the toasts on screen are drawn on paper (Figma 1f): stamp-style toasts (QUOTA MET,
	OVERTIME) are one big centre stamp, the newest only; everything else is a taped sticky note, newest on top, at
	most MAX_NOTES, each tilted ±STICKY_TILT by its id so it keeps its tilt while others come and go. Pure.

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

export type ToastView = {
	stamp: NoteView?,
	notes: { NoteView },
}

local PaperToastViewModel = {
	MAX_NOTES = 3,
}

function PaperToastViewModel.layout(toasts: { ToastTypes.Toast }, maxNotes: number): ToastView
	local stamp: NoteView? = nil
	local notes: { NoteView } = {}
	for index = #toasts, 1, -1 do
		local toast = toasts[index]
		if toast.style == ShiftConstants.TOAST_STAMP then
			if stamp == nil then
				stamp = { id = toast.id, text = toast.text, tilt = UIPaperConstants.STAMP_TILT }
			end
		elseif #notes < maxNotes then
			local tilt = if toast.id % 2 == 0 then UIPaperConstants.STICKY_TILT else -UIPaperConstants.STICKY_TILT
			table.insert(notes, { id = toast.id, text = toast.text, tilt = tilt })
		end
	end
	return { stamp = stamp, notes = notes }
end

return PaperToastViewModel
