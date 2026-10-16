--!strict
--[=[
	OccupantPaViewModel: the PA's paper subtitle (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-
	design.md §5): a torn cream strip at the bottom of the screen headed "PA · ALL STAFF" (a corporate line) or
	"PA · STAFF NOTICE" in stamp red (a call-out naming a crew member), the line in typewriter ink, cut at LINE_MAX
	characters. No notice, or an empty line, draws nothing. Pure.

	@class OccupantPaViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

export type Notice = { line: string, callout: boolean, untilTime: number }

export type PaView = {
	band: string,
	bandColor: Color3,
	text: string,
}

local OccupantPaViewModel = {}

OccupantPaViewModel.LINE_MAX = 72
OccupantPaViewModel.BAND = "PA · ALL STAFF"
OccupantPaViewModel.CALLOUT_BAND = "PA · STAFF NOTICE"

function OccupantPaViewModel.view(notice: Notice?): PaView?
	if notice == nil or notice.line == "" then
		return nil
	end
	local text = notice.line
	local length = utf8.len(text)
	if length ~= nil and length > OccupantPaViewModel.LINE_MAX then
		text = string.sub(text, 1, (utf8.offset(text, OccupantPaViewModel.LINE_MAX) or #text + 1) - 1) .. "…"
	end
	return {
		band = if notice.callout then OccupantPaViewModel.CALLOUT_BAND else OccupantPaViewModel.BAND,
		bandColor = if notice.callout then UIPaperConstants.COLOR.stamp else UIPaperConstants.COLOR.ink,
		text = text,
	}
end

return OccupantPaViewModel
