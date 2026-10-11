--!strict
--[=[
	PaperHudFrame: draws a paper HUD widget's content at `scale` (usePaperHudScale). A transparent frame the size of the
	screen in HUD design px (1 / scale of the real screen) holds the content and a UIScale of `scale`, so the content
	lays out in design px against the screen's edges and is drawn shrunk to fit it. It starts
	PaperHudScaleViewModel.topShift real px down (and ends at the screen's foot), so the design top bar lands on the
	real Roblox top bar, which does not scale. It also provides PaperScaleContext
	at the outer context's scale times `scale`, because a UITextSizeConstraint counts real px and ignores UIScale. At
	scale 1 the content is drawn exactly as without it. Presentational.

	@class PaperHudFrame
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)

local e = React.createElement

export type PaperHudFrameProps = {
	scale: number,
	-- Drawn inside the scaled frame, under any key but "scale" (the frame's UIScale).
	children: { [string]: React.ReactNode },
}

local function PaperHudFrame(props: PaperHudFrameProps): React.ReactNode
	local scale = props.scale
	local shift = PaperHudScaleViewModel.topShift(scale)
	local outer = React.useContext(PaperScaleContext.Context)
	-- Rebuilt when the outer binding or the scale changes.
	local deps: { unknown } = { outer, scale }
	local combined = React.useMemo(function(): React.Binding<number>
		return outer:map(function(value: number): number
			return value * scale
		end)
	end, deps)
	local inside: { [string]: React.ReactNode } = { scale = e("UIScale", { Scale = scale }) }
	for key, node in props.children do
		if key ~= "scale" then
			inside[key] = node
		end
	end
	return e(PaperScaleContext.Context.Provider, { value = combined }, {
		frame = e("Frame", {
			-- The size is in design px (the UIScale multiplies it): the screen less the shift, over the scale.
			Position = UDim2.fromOffset(0, shift),
			Size = UDim2.new(1 / scale, 0, 1 / scale, -shift / scale),
			BackgroundTransparency = 1,
		}, inside),
	})
end

return PaperHudFrame
