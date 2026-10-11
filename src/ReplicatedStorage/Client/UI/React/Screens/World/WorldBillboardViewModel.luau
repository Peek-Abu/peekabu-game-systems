--!strict
--[=[
	WorldBillboardViewModel: the maths every world sign shares (M3b world UI). `fit` is the UIScale that maps a
	component's Figma px design onto a stud-sized shell's drawn size (it changes with distance); `screenScale` is the
	UIScale of a px-sized shell, by the screen against the 1920x1080 reference, never above 1 and never below 0.6 so a
	phone's signs stay readable; `clip` cuts text to a character limit with an ellipsis. Pure.

	@class WorldBillboardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local WorldBillboardViewModel = {}

WorldBillboardViewModel.REFERENCE = UIPaperConstants.REFERENCE
WorldBillboardViewModel.MIN_SCREEN_SCALE = 0.6

function WorldBillboardViewModel.fit(absolute: Vector2, design: Vector2): number
	if design.X <= 0 or design.Y <= 0 then
		return 1
	end
	return math.max(0, math.min(absolute.X / design.X, absolute.Y / design.Y))
end

function WorldBillboardViewModel.screenScale(viewport: Vector2): number
	local reference = WorldBillboardViewModel.REFERENCE
	local ratio = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(ratio, WorldBillboardViewModel.MIN_SCREEN_SCALE, 1)
end

-- At most `max` characters; a longer text keeps `max - 1` and ends in "…". Invalid UTF-8 reads "?".
function WorldBillboardViewModel.clip(text: string, max: number): string
	local length = utf8.len(text)
	if length == nil then
		return "?"
	end
	if length <= max then
		return text
	end
	local stop = utf8.offset(text, max)
	if stop == nil then
		return text
	end
	return string.sub(text, 1, stop - 1) .. "…"
end

return WorldBillboardViewModel
