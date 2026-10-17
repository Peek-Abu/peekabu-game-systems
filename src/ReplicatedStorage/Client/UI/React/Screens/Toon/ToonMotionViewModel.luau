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

return ToonMotionViewModel
