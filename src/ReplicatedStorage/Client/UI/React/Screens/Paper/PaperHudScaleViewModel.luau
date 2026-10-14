--!strict
--[=[
	PaperHudScaleViewModel: how far the desktop paper HUD is scaled down to fit the window. The desktop HUD is laid out
	in fixed px for the 1920x1080 design (UIPaperConstants.REFERENCE); on a smaller window `scale` is the tighter of
	width / 1920 and height / 1080, never above 1 and never below UIPaperConstants.HUD_SCALE_MIN. The phone layout is
	its own 844x390 design and stays at 1. `topShift` moves the scaled HUD down so its design top bar sits on the real
	(unscaled) Roblox top bar. `virtual` is a screen area in HUD design px (what the scaled HUD lays out in), so
	viewport-based layout rules (ShiftHudViewModel.centreShift / carryLeft) are fed it. Pure.

	@class PaperHudScaleViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local PaperHudScaleViewModel = {}

function PaperHudScaleViewModel.scale(viewport: Vector2, layout: UIPaperConstants.Layout): number
	if layout == "phone" then
		return 1
	end
	local reference = UIPaperConstants.REFERENCE
	local ratio = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(ratio, UIPaperConstants.HUD_SCALE_MIN, 1)
end

-- How far down (real px) the scaled HUD starts. The Roblox top bar stays the same real height at any scale, so the
-- HUD's design top bar (SAFE.desktop.topBar) is moved down onto it and nothing designed below it slides under it.
function PaperHudScaleViewModel.topShift(scale: number): number
	return UIPaperConstants.SAFE.desktop.topBar * (1 - scale)
end

-- How far (design px) a full-screen backdrop inside the scaled HUD must reach above the frame's top to cover the real
-- screen from its top edge: the top shift, in design px. A wash or scrim drawn at the frame's size alone leaves a
-- strip of the world uncovered across the top bar.
function PaperHudScaleViewModel.bleed(scale: number): number
	return PaperHudScaleViewModel.topShift(scale) / scale
end

function PaperHudScaleViewModel.virtual(viewport: Vector2, scale: number): Vector2
	return viewport / scale
end

return PaperHudScaleViewModel
