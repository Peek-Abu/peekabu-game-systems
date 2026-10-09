--!strict
--[=[
	VfxFormulas: the Vfx feature's pure maths — shake falloff, combining screen-effect requests, easing
	between screen states, and resolving / blending atmosphere values.

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

return VfxFormulas
