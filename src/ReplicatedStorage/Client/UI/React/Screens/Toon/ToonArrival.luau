--!strict
--[=[
	ToonArrival: the frame a full-screen menu's page sits in, moving it into place (owner picks M2 + M3, 2026-11-16):
	when the menu opens the page rises MOTION.arriveRise design px into place, and when `tab` changes the new page slides
	in MOTION.slideShift px from the side of the tab picked (ToonMotionViewModel.slideFrom over `tabs`). Position only:
	nothing scales (no zooms) and nothing fades (a CanvasGroup over the menus' live viewports would cost a texture a
	frame). Closing is not animated. Reduced Motion: the page is simply there. Presentational (exempt; the curves are
	specced in ToonMotionViewModel.arrive / slideFrom).

	@class ToonArrival
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

local MOTION = UIToonConstants.MOTION

export type ToonArrivalProps = {
	-- The page's resting place and size.
	position: UDim2,
	size: UDim2,
	-- The menu's tab ids in bar order and the one shown (none: a menu without tabs).
	tabs: { string }?,
	tab: string?,
	zIndex: number?,
	-- The page.
	content: React.ReactNode,
}

type Move = { x: number, y: number, seconds: number }

local function ToonArrival(props: ToonArrivalProps): React.ReactNode
	-- The tab shown before this one ("" before any).
	local shown = React.useRef("")
	local opened = React.useRef(false)
	local tab = props.tab or ""
	-- Where this play starts, fixed when the tab changes (the ref still holds the tab before it).
	local move = React.useMemo(function(): Move
		if not opened.current then
			return { x = 0, y = MOTION.arriveRise, seconds = MOTION.arriveSeconds }
		end
		local from = ToonMotionViewModel.slideFrom(props.tabs or {}, shown.current, tab)
		return { x = from, y = 0, seconds = MOTION.slideSeconds }
	end, { tab })
	React.useEffect(function()
		opened.current = true
		shown.current = tab
	end, { tab })
	local alpha = useToonPlay(move.seconds, 0, tab)
	return e("Frame", {
		Position = alpha:map(function(t: number): UDim2
			local base = props.position
			return UDim2.new(
				base.X.Scale,
				base.X.Offset + ToonMotionViewModel.arrive(t, move.x),
				base.Y.Scale,
				base.Y.Offset + ToonMotionViewModel.arrive(t, move.y)
			)
		end),
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, { content = props.content })
end

return ToonArrival
