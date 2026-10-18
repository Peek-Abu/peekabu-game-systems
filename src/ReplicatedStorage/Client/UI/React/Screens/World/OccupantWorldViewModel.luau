--!strict
--[=[
	OccupantWorldViewModel: what Mr. Harlow's world signs show (Figma World UI 2b). The cue (W7): "?" (curious) is a
	sticky-yellow disc with a black ring, "!" (spotted) a red stamp disc with a cream ring and glyph, tilted -8°; any
	other value draws nothing. The memo (W8): the red letterhead, the line cut at LINE_MAX characters, and the shout rule:
	a line that ends with "!" or has MIN_SHOUT_LETTERS+ ASCII letters and none lowercase is shouted, drawn red at 38
	instead of ink at 30. An empty line, or a value that is not text, draws no memo. Pure.

	@class OccupantWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type CueView = {
	glyph: string,
	fill: Color3,
	ring: Color3,
	ink: Color3,
	tilt: number,
}

export type MemoView = {
	band: string,
	text: string,
	shouted: boolean,
	size: number,
	ink: UIPaperConstants.Ink,
}

local COLOR = UIPaperConstants.COLOR

local OccupantWorldViewModel = {}

OccupantWorldViewModel.LINE_MAX = 80
OccupantWorldViewModel.MIN_SHOUT_LETTERS = 3
OccupantWorldViewModel.MEMO_BAND = "MEMO — FROM THE DESK OF H. HARLOW"

function OccupantWorldViewModel.shouted(line: string): boolean
	local trimmed = string.match(line, "^%s*(.-)%s*$") or ""
	if string.sub(trimmed, -1) == "!" then
		return true
	end
	local _, letters = string.gsub(trimmed, "[A-Za-z]", "")
	return letters >= OccupantWorldViewModel.MIN_SHOUT_LETTERS and string.find(trimmed, "[a-z]") == nil
end

function OccupantWorldViewModel.memo(line: unknown): MemoView?
	if type(line) ~= "string" or line == "" then
		return nil
	end
	local loud = OccupantWorldViewModel.shouted(line)
	return {
		band = OccupantWorldViewModel.MEMO_BAND,
		text = WorldBillboardViewModel.clip(line, OccupantWorldViewModel.LINE_MAX),
		shouted = loud,
		size = if loud then 38 else 30,
		ink = if loud then "danger" else "ink",
	}
end

function OccupantWorldViewModel.cue(text: unknown): CueView?
	if text == "?" then
		return { glyph = "?", fill = COLOR.sticky, ring = COLOR.night, ink = COLOR.night, tilt = 0 }
	elseif text == "!" then
		return { glyph = "!", fill = COLOR.stamp, ring = COLOR.cream, ink = COLOR.cream, tilt = -8 }
	end
	return nil
end

return OccupantWorldViewModel
