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

-- UITextSizeConstraint accepts 1..100.
local MIN_PX = 1
local MAX_PX = 100

local unscaled = React.createBinding(1)

local PaperScaleContext = {
	Context = React.createContext(unscaled),
}

-- A design-unit text size on a sign drawn at `scale`, as a valid UITextSizeConstraint limit.
function PaperScaleContext.limit(designSize: number, scale: number): number
	return math.clamp(designSize * scale, MIN_PX, MAX_PX)
end

return PaperScaleContext
