--!strict
--[=[
	ToonMotionViewModel: the V1 kit's motion curves, as pure functions of progress so a binding can drive them. `pop` is
	a panel's pop-in scale (0.6 -> 1.08 -> 1); `wipe` is the dirty -> clean squeegee pass across a panel that opens
	(the dirt layer's transparency gradient and where the squeegee is); `twinkle` is a sparkle's size at a moment,
	staggered by its index. Pure.

	@class ToonMotionViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Point = { time: number, value: number }
export type Wipe = {
	-- The dirt layer's transparency along the panel, left to right (UIGradient keypoints).
	points: { Point },
	-- Where the squeegee is, 0..1 across the panel (it starts and ends just off it).
	edge: number,
}

local MOTION = UIToonConstants.MOTION

-- Where the overshoot peaks, as a share of the pop.
local POP_PEAK = 0.6
-- The dirt's softness ahead of the squeegee (a share of the panel's width) and its travel past both ends.
local SOFT = 0.05
local TRAVEL = 0.12

local ToonMotionViewModel = {}

-- The dirt's transparency (a goo smear over the panel, see-through enough to read it).
ToonMotionViewModel.DIRT_TRANSPARENCY = 0.35

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function easeInOut(t: number): number
	return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
end

function ToonMotionViewModel.pop(t: number): number
	local clamped = math.clamp(t, 0, 1)
	if clamped < POP_PEAK then
		return MOTION.popFrom + (MOTION.popOvershoot - MOTION.popFrom) * easeOut(clamped / POP_PEAK)
	end
	return MOTION.popOvershoot + (1 - MOTION.popOvershoot) * easeInOut((clamped - POP_PEAK) / (1 - POP_PEAK))
end

function ToonMotionViewModel.wipe(t: number): Wipe
	local dirt = ToonMotionViewModel.DIRT_TRANSPARENCY
	local edge = -TRAVEL + (1 + 2 * TRAVEL) * easeInOut(math.clamp(t, 0, 1))
	local points: { Point } = { { time = 0, value = if edge > 0 then 1 else dirt } }
	-- The clean side ends at the squeegee; the dirt fades back in over SOFT ahead of it.
	local cleanTo = edge
	local dirtFrom = edge + SOFT
	if cleanTo > 0 and cleanTo < 1 then
		table.insert(points, { time = cleanTo, value = 1 })
	end
	if dirtFrom > 0 and dirtFrom < 1 then
		table.insert(points, { time = dirtFrom, value = dirt })
	end
	table.insert(points, { time = 1, value = if dirtFrom < 1 then dirt else 1 })
	return { points = points, edge = edge }
end

function ToonMotionViewModel.twinkle(seconds: number, index: number, count: number): number
	local phase = seconds / MOTION.sparklePeriod + (index - 1) / math.max(1, count)
	local wave = (math.sin(phase * 2 * math.pi) + 1) / 2
	return 0.35 + 0.65 * wave * wave
end

-- A waiting button's highlight (owner 2026-11-14: the button stays still, only a border colour gently pulses): the
-- border's UIStroke Transparency over one MOTION.highlightPeriod, strongest at the start and end of each period (so
-- Reduced Motion, which holds the clock at its end, shows a steady strong border).
function ToonMotionViewModel.highlight(seconds: number): number
	local wave = (1 - math.cos(seconds / MOTION.highlightPeriod * 2 * math.pi)) / 2
	return 0.1 + 0.6 * wave
end

-- A card dealt in as a menu page opens (owner pick M4): MOTION.dealFrom -> dealOvershoot -> 1, the pop's shape but
-- softer.
function ToonMotionViewModel.deal(t: number): number
	local clamped = math.clamp(t, 0, 1)
	if clamped < POP_PEAK then
		return MOTION.dealFrom + (MOTION.dealOvershoot - MOTION.dealFrom) * easeOut(clamped / POP_PEAK)
	end
	return MOTION.dealOvershoot + (1 - MOTION.dealOvershoot) * easeInOut((clamped - POP_PEAK) / (1 - POP_PEAK))
end

-- When the `index`-th card (1-based) starts its deal, or nil past the first MOTION.dealCount (those are simply there).
function ToonMotionViewModel.dealDelay(index: number): number?
	if index < 1 or index > MOTION.dealCount then
		return nil
	end
	return (index - 1) * MOTION.dealStagger
end

-- How far (design px) a page still is from its place `t` of the way through its arrival or slide, starting `from` px
-- away (M2 rise, M3 slide): eased out, landing exactly on 0 with no overshoot.
function ToonMotionViewModel.arrive(t: number, from: number): number
	local clamped = math.clamp(t, 0, 1)
	if clamped >= 1 then
		return 0
	end
	return from * (1 - easeOut(clamped))
end

-- Where a new tab's page slides in from (M3): from the right when the tab picked sits right of the last one, from the
-- left when it sits left, not at all when either is unknown or it is the same tab.
function ToonMotionViewModel.slideFrom(tabs: { string }, previous: string?, current: string): number
	local from = if previous ~= nil then table.find(tabs, previous) else nil
	local to = table.find(tabs, current)
	if from == nil or to == nil or from == to then
		return 0
	end
	return if to > from then MOTION.slideShift else -MOTION.slideShift
end

-- A wallet's number `t` of the way from its old balance to its new one (M5): eased out, whole numbers only.
function ToonMotionViewModel.count(from: number, to: number, t: number): number
	local clamped = math.clamp(t, 0, 1)
	if clamped >= 1 then
		return to
	end
	return math.floor(from + (to - from) * easeOut(clamped) + 0.5)
end

-- A wallet pill's one bump when its balance grows (M5): 1 -> MOTION.bumpScale -> 1.
function ToonMotionViewModel.bump(t: number): number
	local clamped = math.clamp(t, 0, 1)
	local peak = 0.35
	if clamped < peak then
		return 1 + (MOTION.bumpScale - 1) * easeOut(clamped / peak)
	end
	return MOTION.bumpScale + (1 - MOTION.bumpScale) * easeInOut((clamped - peak) / (1 - peak))
end

export type Float = { rise: number, transparency: number }

-- The "+40" floating off a wallet (M5): fades in over the first quarter, rises MOTION.floatRise px in all, fades out
-- over the last quarter.
function ToonMotionViewModel.float(t: number): Float
	local clamped = math.clamp(t, 0, 1)
	local transparency = if clamped < 0.25
		then 1 - clamped / 0.25
		elseif clamped > 0.75 then (clamped - 0.75) / 0.25
		else 0
	return { rise = MOTION.floatRise * easeOut(clamped), transparency = transparency }
end

return ToonMotionViewModel
