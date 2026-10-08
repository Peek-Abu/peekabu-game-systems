--!strict
--[=[
	ExperienceHud: the XP/level HUD widget. Owns the XP data path — `useAtom(StateSyncClientStore.stats)` derived
	through `VitalsViewModel.fromStats` — and hands the readout, plus an eased fill and lead trail, to the
	presentational `ExperienceBar` (top-centre). Composed onto the Hud layer by `HudRoot`.

	Split out of VitalsHud on purpose: XP is not a vital (different source, different place on screen),
	and the HUD is meant to grow one independent widget at a time. Level/XP changes rarely, so the
	readout rides `useAtom` (a re-render on change) — that re-render on an XP grant is EXPECTED and cheap.
	It's `React.memo`'d so `HudRoot` re-rendering (e.g. a scene opening) never cascades a re-render here.

	**The gain lead.** The synced fraction is the target; `useEasedTrail` (the same hook health uses)
	eases a `fill` that tweens UP to it slowly and a `trail` that races AHEAD to it — so a gain shows the
	lead jump to the new value and the fill rise to meet it. Both are bindings (Heartbeat writes, no
	re-render). The level-up fill-sweep + badge popup are still deferred.

	@class ExperienceHud
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)
local useEasedTrail = require(ReplicatedStorage.Client.UI.React.Hooks.useEasedTrail)
local ExperienceBar = require(ReplicatedStorage.Client.UI.React.Screens.Experience.ExperienceBar)
local VitalsViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Vitals.VitalsViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local COMPONENT_NAME = "ExperienceHud"

-- XP easing: on a gain the dark lead trail runs ahead to the target immediately, then after a 0.4s HOLD
-- the bright fill sweeps UP to meet it (the lead previews, the fill fills in). The fill snaps down on a
-- level-up reset. Rates are per-second (higher = faster). To drop the hold: remove hold/holdDir from
-- `fill`.
local XP_TRAIL: useEasedTrail.TrailConfig = {
	fill = { up = 4, down = 25, hold = 0.4, holdDir = "up" },
	trail = { up = 12, down = 25 },
}

--[=[
	@return React.ReactNode
]=]
local function ExperienceHud(): React.ReactNode
	local stats = useAtom(StateSyncClientStore.stats)

	-- Tally every render (no dependency array) so the F4 UI tab can show this widget's render count.
	React.useEffect(function()
		UIRenderCounters.tick(COMPONENT_NAME)
	end)

	local xp = VitalsViewModel.fromStats(stats)

	-- Mirror the (re-render-driven) fraction into a binding so the eased fill/trail can chase it every
	-- frame without further re-renders.
	local target, setTarget = React.useBinding(xp.fraction)
	React.useEffect(function()
		setTarget(xp.fraction)
	end, { xp.fraction })
	local fill, lead = useEasedTrail(target, XP_TRAIL)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		experience = e(ExperienceBar, { xp = xp, fraction = fill, catchup = lead }),
	})
end

return React.memo(ExperienceHud)
