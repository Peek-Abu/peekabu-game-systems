--!strict
--[=[
	PaperScaleContext: the scale a sign is drawn at, so PaperLabel's shrink-to-fit limits follow it. A
	UITextSizeConstraint counts real screen px and ignores the UIScale around a sign, so a `scaled` label needs its
	design-unit limits multiplied by that scale. WorldBillboard and DepotCardPanel provide a binding of their scale;
	the default is a binding of 1 (an unscaled surface). `limit` is the specced maths.

	@class PaperScaleContext
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

-- How far a fitted (TextScaled) label may shrink below its design size.
local FIT_SHRINK = 0.6

-- UITextSizeConstraint accepts 1..100.
local MIN_PX = 1
local MAX_PX = 100

local unscaled = React.createBinding(1)

local PaperScaleContext = {
	Context = React.createContext(unscaled),
	-- The smallest real px fitted text may shrink to: READABLE_PX on screen UI; a world sign provides 1, because it
	-- is meant to shrink with distance.
	Readable = React.createContext(UIPaperConstants.READABLE_PX),
}

-- A design-unit text size on a sign drawn at `scale`, as a valid UITextSizeConstraint limit.
function PaperScaleContext.limit(designSize: number, scale: number): number
	return math.clamp(designSize * scale, MIN_PX, MAX_PX)
end

-- The smallest real px a fitted label of `designSize` drawn at `scale` may shrink to: 60% of its drawn size, never
-- below `readable` (the Readable context: so a long name on screen overflows its box rather than turning into a
-- smudge), and never above the label's own `limit`.
function PaperScaleContext.floor(designSize: number, scale: number, readable: number): number
	local max = PaperScaleContext.limit(designSize, scale)
	local shrunk = PaperScaleContext.limit(designSize * FIT_SHRINK, scale)
	return math.min(max, math.max(shrunk, readable))
end

return PaperScaleContext
