--!strict
--[=[
	VfxFormulas: the Vfx feature's pure maths — shake falloff, combining screen-effect requests, easing
	between screen states, resolving / blending atmosphere values, and the particle budget and funnel maths of
	code-built bursts (VfxBurstSystem).

	@class VfxFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

type ScreenRequest = VfxTypes.ScreenRequest
type ScreenState = VfxTypes.ScreenState
type Atmosphere = VfxTypes.Atmosphere
type AtmosphereValues = VfxTypes.AtmosphereValues

local WHITE = Color3.new(1, 1, 1)

local VfxFormulas = {}

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

--[=[
	The camera trauma an effect causes at `distance`: full at the centre, falling off quadratically to
	zero at `radius`.
]=]
function VfxFormulas.traumaAtDistance(trauma: number, distance: number, radius: number): number
	if radius <= 0 or distance >= radius then
		return 0
	end
	local falloff = 1 - distance / radius
	return trauma * falloff * falloff
end

--[=[
	Every live request combined into one state: the strongest blur and depth of field, summed colour
	offsets, multiplied tints. Neutral with no requests.
]=]
function VfxFormulas.combineScreen(requests: { ScreenRequest }): ScreenState
	local state: ScreenState = {
		blur = 0,
		brightness = 0,
		contrast = 0,
		saturation = 0,
		tint = WHITE,
		depthOfField = 0,
	}
	for _, request in requests do
		state.blur = math.max(state.blur, request.blur or 0)
		state.depthOfField = math.max(state.depthOfField, request.depthOfField or 0)
		state.brightness += request.brightness or 0
		state.contrast += request.contrast or 0
		state.saturation += request.saturation or 0
		local tint = request.tint
		if tint ~= nil then
			state.tint = Color3.new(state.tint.R * tint.R, state.tint.G * tint.G, state.tint.B * tint.B)
		end
	end
	return state
end

--[=[
	A screen state `alpha` (0..1) of the way from `from` to `to`.
]=]
function VfxFormulas.lerpScreen(from: ScreenState, to: ScreenState, alpha: number): ScreenState
	return {
		blur = lerp(from.blur, to.blur, alpha),
		brightness = lerp(from.brightness, to.brightness, alpha),
		contrast = lerp(from.contrast, to.contrast, alpha),
		saturation = lerp(from.saturation, to.saturation, alpha),
		tint = from.tint:Lerp(to.tint, alpha),
		depthOfField = lerp(from.depthOfField, to.depthOfField, alpha),
	}
end

-- Below this a screen value is invisible (a thousandth of a blur pixel, of a colour step, of depth of field).
local SCREEN_EPSILON = 1e-3

local function nonzero(value: number): boolean
	return math.abs(value) > SCREEN_EPSILON
end

local function sameScreen(a: ScreenState, b: ScreenState): boolean
	return not nonzero(a.blur - b.blur)
		and not nonzero(a.brightness - b.brightness)
		and not nonzero(a.contrast - b.contrast)
		and not nonzero(a.saturation - b.saturation)
		and not nonzero(a.tint.R - b.tint.R)
		and not nonzero(a.tint.G - b.tint.G)
		and not nonzero(a.tint.B - b.tint.B)
		and not nonzero(a.depthOfField - b.depthOfField)
end

--[=[
	Which post effects a screen state needs switched on. A neutral effect changes nothing on screen, but an
	enabled Blur / ColorCorrection / DepthOfField still costs its GPU pass every frame (heavy on phones), so the
	effects are only enabled while their values are visibly away from neutral.
]=]
function VfxFormulas.screenActive(state: ScreenState): { blur: boolean, color: boolean, depth: boolean }
	return {
		blur = nonzero(state.blur),
		color = nonzero(state.brightness) or nonzero(state.contrast) or nonzero(state.saturation) or nonzero(
			state.tint.R - 1
		) or nonzero(state.tint.G - 1) or nonzero(state.tint.B - 1),
		depth = nonzero(state.depthOfField),
	}
end

--[=[
	Whether the eased screen `applied` has (visibly) arrived at `target`, so the per-frame ease can stop writing.
]=]
function VfxFormulas.screenSettled(applied: ScreenState, target: ScreenState): boolean
	return sameScreen(applied, target)
end

--[=[
	The full atmosphere a preset produces: its values where it sets them, the base elsewhere.
]=]
function VfxFormulas.resolveAtmosphere(base: AtmosphereValues, preset: Atmosphere?): AtmosphereValues
	if preset == nil then
		return table.clone(base)
	end
	return {
		clockTime = if preset.clockTime ~= nil then preset.clockTime else base.clockTime,
		brightness = if preset.brightness ~= nil then preset.brightness else base.brightness,
		exposure = if preset.exposure ~= nil then preset.exposure else base.exposure,
		ambient = if preset.ambient ~= nil then preset.ambient else base.ambient,
		outdoorAmbient = if preset.outdoorAmbient ~= nil then preset.outdoorAmbient else base.outdoorAmbient,
		fogColor = if preset.fogColor ~= nil then preset.fogColor else base.fogColor,
		fogStart = if preset.fogStart ~= nil then preset.fogStart else base.fogStart,
		fogEnd = if preset.fogEnd ~= nil then preset.fogEnd else base.fogEnd,
	}
end

--[=[
	Atmosphere values `alpha` (clamped to 0..1) of the way from `from` to `to`. ClockTime blends linearly.
]=]
function VfxFormulas.blendAtmosphere(from: AtmosphereValues, to: AtmosphereValues, alpha: number): AtmosphereValues
	local t = math.clamp(alpha, 0, 1)
	return {
		clockTime = lerp(from.clockTime, to.clockTime, t),
		brightness = lerp(from.brightness, to.brightness, t),
		exposure = lerp(from.exposure, to.exposure, t),
		ambient = from.ambient:Lerp(to.ambient, t),
		outdoorAmbient = from.outdoorAmbient:Lerp(to.outdoorAmbient, t),
		fogColor = from.fogColor:Lerp(to.fogColor, t),
		fogStart = lerp(from.fogStart, to.fogStart, t),
		fogEnd = lerp(from.fogEnd, to.fogEnd, t),
	}
end

-- A burst or stream's share at a graphics quality level (UserGameSettings.SavedQualityLevel: 0 = Automatic, kept
-- full; 1..10 scale from about 40% to all of it).
local function qualityShare(quality: number): number
	if quality <= 0 then
		return 1
	end
	return math.clamp(0.35 + 0.065 * quality, 0.35, 1)
end

--[=[
	How many particles a burst layer of `count` emits at graphics `quality` (Emit is not thinned by the engine):
	rounded, never below one.
]=]
function VfxFormulas.burstCount(count: number, quality: number): number
	return math.max(1, math.floor(count * qualityShare(quality) + 0.5))
end

--[=[
	A stream layer's Rate at `strength` (clamped to 0..1) and graphics `quality`.
]=]
function VfxFormulas.streamRate(rate: number, strength: number, quality: number): number
	return rate * math.clamp(strength, 0, 1) * qualityShare(quality)
end

--[=[
	The ShapePartial of a funnel's inward sphere (centred on the sink, its radius the distance to the source) whose
	cap just covers a source of `radius` studs: the source's angular radius as a share of a hemisphere, 0.02..1.
]=]
function VfxFormulas.funnelPartial(radius: number, distance: number): number
	local angle = math.atan2(math.max(radius, 0), math.max(distance, 1e-3))
	return math.clamp(angle / (math.pi / 2), 0.02, 1)
end

--[=[
	The inward speed that carries a funnel particle `distance` studs to the sink in `lifetime` seconds (0 for no life).
]=]
function VfxFormulas.funnelSpeed(distance: number, lifetime: number): number
	if lifetime <= 0 then
		return 0
	end
	return distance / lifetime
end

--[=[
	Whether `after` differs from `before` by more than `share` of `before` (any change from 0 counts): emitter writes
	are throttled to real changes.
]=]
function VfxFormulas.changedBy(before: number, after: number, share: number): boolean
	if before == 0 then
		return after ~= 0
	end
	return math.abs(after - before) > math.abs(before) * share
end

--[=[
	A NumberSequence from `{ time, value }` pairs (times 0..1, first 0 and last 1), for writing burst layers tersely.
]=]
function VfxFormulas.sequence(points: { { number } }): NumberSequence
	local keypoints: { NumberSequenceKeypoint } = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
	end
	return NumberSequence.new(keypoints)
end

--[=[
	A ColorSequence from colours spread evenly over the lifetime (one colour = a constant).
]=]
function VfxFormulas.gradient(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints: { ColorSequenceKeypoint } = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

return VfxFormulas
