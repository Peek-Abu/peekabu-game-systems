--!strict
--[=[
	ToonSliderViewModel: the value maths behind ToonSlider. `fraction` places a value on the track; `snap` rounds a raw
	value to the slider's step (from `min`) and clamps it, with no float noise, so a drag sends clean values;
	`fromPointer` turns a pointer's x over the track into a stepped value; `nudge` moves one step for a key or d-pad
	press; `percent` is the value's whole percentage of the range ("75%"); `direction` reads a key as a step left (-1),
	right (1) or none (0). Pure.

	@class ToonSliderViewModel
]=]

local ToonSliderViewModel = {}

-- A slider without a step nudges by this share of its range.
local FREE_NUDGE = 1 / 20
-- Snapped values are rounded to this many decimals, so 0.3 stays 0.3 rather than 0.30000000000000004.
local PRECISION = 1e6

local DIRECTION: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.Left] = -1,
	[Enum.KeyCode.A] = -1,
	[Enum.KeyCode.DPadLeft] = -1,
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.D] = 1,
	[Enum.KeyCode.DPadRight] = 1,
}

function ToonSliderViewModel.fraction(value: number, min: number, max: number): number
	if max <= min then
		return 0
	end
	return math.clamp((value - min) / (max - min), 0, 1)
end

function ToonSliderViewModel.snap(value: number, min: number, max: number, step: number?): number
	local clamped = math.clamp(value, min, max)
	if step ~= nil and step > 0 then
		clamped = math.clamp(min + math.round((clamped - min) / step) * step, min, max)
	end
	return math.round(clamped * PRECISION) / PRECISION
end

function ToonSliderViewModel.fromPointer(
	x: number,
	left: number,
	width: number,
	min: number,
	max: number,
	step: number?
): number
	if width <= 0 then
		return min
	end
	local along = math.clamp((x - left) / width, 0, 1)
	return ToonSliderViewModel.snap(min + along * (max - min), min, max, step)
end

function ToonSliderViewModel.nudge(value: number, direction: number, min: number, max: number, step: number?): number
	local amount = if step ~= nil and step > 0 then step else (max - min) * FREE_NUDGE
	return ToonSliderViewModel.snap(value + direction * amount, min, max, step)
end

function ToonSliderViewModel.percent(value: number, min: number, max: number): string
	return `{math.round(ToonSliderViewModel.fraction(value, min, max) * 100)}%`
end

function ToonSliderViewModel.direction(key: Enum.KeyCode): number
	return DIRECTION[key] or 0
end

return ToonSliderViewModel
