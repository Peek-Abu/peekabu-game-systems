--!strict
--[=[
	usePaperHudScale: the desktop paper HUD's scale for the live window (PaperHudScaleViewModel.scale; 1 on phone), the
	area PaperHudFrame draws in, in HUD design px (`viewport`, the virtual viewport every layout rule reads) and the
	device layout. Re-renders when the viewport changes. React hook (exempt: needs a renderer; the maths is the specced
	PaperHudScaleViewModel).

	@class usePaperHudScale
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaperHudScaleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudScaleViewModel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)

export type PaperHudScale = {
	scale: number,
	viewport: Vector2,
	layout: UIPaperConstants.Layout,
}

local function usePaperHudScale(): PaperHudScale
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local viewport = usePaperViewport()
	local scale = PaperHudScaleViewModel.scale(viewport, layout)
	-- PaperHudFrame starts the scaled HUD topShift px down, so the area it lays out in is that much shorter.
	local drawn = viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale))
	return {
		scale = scale,
		viewport = PaperHudScaleViewModel.virtual(drawn, scale),
		layout = layout,
	}
end

return usePaperHudScale
