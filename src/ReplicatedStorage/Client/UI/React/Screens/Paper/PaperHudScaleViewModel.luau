--!strict
--[=[
	PaperHudScaleViewModel: the ONE rule every screen-space UI in the game is scaled by (HUD widgets, the hub pages,
	the fitted screens, toasts, prompts; world UI has its own `WorldBillboardViewModel.fit`).

	Desktop (and touch tablets, which use the desktop layout) is laid out in px for the 1920x1080 design
	(UIPaperConstants.REFERENCE) and drawn at `scale` = the tighter of width / 1920 and height / 1080, clamped to
	[HUD_SCALE_MIN, HUD_SCALE_MAX]: the UI keeps the same share of the screen on a 1080p, 1440p or 4K monitor (Roblox
	reports a desktop viewport in physical px), and stops shrinking at HUD_SCALE_MIN so the smallest text
	(UIPaperConstants.TEXT_MIN) is still drawn at READABLE_PX on a small laptop. Only a window too short to hold
	HUD_FIT_HEIGHT design px at that minimum (under ~690 px tall, e.g. Studio's play pane) goes lower, to the scale that
	fits, never below HUD_SCALE_FLOOR. The phone layout is its own 844x390
	design in DPI-normalised points (one point is about the same physical size on every phone), so it stays at 1.

	`topShift` moves a shrunk HUD down so its design top bar sits on the real (unscaled) Roblox top bar; a grown HUD is
	not moved (moving it up would push what is designed beside the top bar off the screen). `virtual` is a screen area
	in HUD design px (what the scaled HUD lays out in), so viewport-based layout rules are fed it. `cap` limits a
	screen's own fit-to-window scale to the HUD's, so a modal grows with the HUD but still shrinks to fit. Pure.

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
	-- The readable minimum, unless the window is too short to fit HUD_FIT_HEIGHT design px under the real top bar at
	-- it: then the largest scale that still fits ((h - topBar) / (fit - topBar), from virtual height >= fit with the
	-- top shift), never below the absolute floor.
	local topBar = UIPaperConstants.SAFE.desktop.topBar
	local fits = (viewport.Y - topBar) / (UIPaperConstants.HUD_FIT_HEIGHT - topBar)
	local floor = math.max(UIPaperConstants.HUD_SCALE_FLOOR, math.min(UIPaperConstants.HUD_SCALE_MIN, fits))
	return math.clamp(ratio, floor, UIPaperConstants.HUD_SCALE_MAX)
end

-- How far down (real px) the scaled HUD starts. The Roblox top bar stays the same real height at any scale, so a
-- shrunk HUD's design top bar (SAFE.desktop.topBar) is moved down onto it and nothing designed below it slides under
-- it. A grown HUD starts at the screen top: its design top bar is then taller than the real one, which only adds room.
function PaperHudScaleViewModel.topShift(scale: number): number
	return UIPaperConstants.SAFE.desktop.topBar * math.max(0, 1 - scale)
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

-- A fitted screen's scale (the largest that fits its design on the window) limited to the HUD's `scale`, so every
-- screen grows and shrinks with the same rule and only shrinks further when it would not fit.
function PaperHudScaleViewModel.cap(fit: number, viewport: Vector2, layout: UIPaperConstants.Layout): number
	return math.min(fit, PaperHudScaleViewModel.scale(viewport, layout))
end

return PaperHudScaleViewModel
