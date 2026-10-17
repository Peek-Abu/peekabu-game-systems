--!strict
--[=[
	VfxBurstRegistry: the catalog of code-built particle bursts by id (the ItemRegistry contract: validated, loud at
	boot, no re-registration). A burst is a short stack of emitter layers (VfxTypes.Burst) that VfxBurstSystem builds
	once, pools, and plays at a point; a layer with a `rate` instead of a `count` streams in a funnel instead.

	Validation holds the VFX budget (the authoring-roblox-skill-vfx "Impact budget"): 1..MAX_LAYERS layers, at most
	MAX_PARTICLES burst particles in all, at most one light, no brighter than MAX_LIGHT_BRIGHTNESS and no longer than
	MAX_LIGHT_SECONDS (kid-safe: never a white-out).

	@class VfxBurstRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

type Burst = VfxTypes.Burst

local MAX_LAYERS = 6
local MAX_PARTICLES = 150
local MAX_LIGHT_BRIGHTNESS = 6
local MAX_LIGHT_SECONDS = 1

local bursts: { [string]: Burst } = {}

local VfxBurstRegistry = {}

--[=[
	Registers a burst. Asserts: the id is new; 1..6 layers; each layer has a texture, a positive lifetime, a
	non-negative delay and exactly one of `count` / `rate` (positive); at most 150 burst particles; a light within
	0..6 brightness, a positive range and 0..1 seconds.
]=]
function VfxBurstRegistry.register(id: string, burst: Burst)
	assert(bursts[id] == nil, `vfx burst "{id}" is already registered`)
	local layers = burst.layers
	assert(#layers >= 1 and #layers <= MAX_LAYERS, `vfx burst "{id}": needs 1..{MAX_LAYERS} layers`)
	local particles = 0
	for index, layer in layers do
		local where = `vfx burst "{id}" layer {index}`
		assert(type(layer.texture) == "string" and layer.texture ~= "", `{where}: texture is required`)
		assert(layer.lifetime.Min > 0, `{where}: lifetime must be positive`)
		local delay = layer.delay
		assert(delay == nil or delay >= 0, `{where}: delay must not be negative`)
		local count = if type(layer.count) == "number" then layer.count else nil
		local rate = if type(layer.rate) == "number" then layer.rate else nil
		assert((count == nil) ~= (rate == nil), `{where}: needs exactly one of count and rate`)
		assert((count or rate or 0) > 0, `{where}: count / rate must be positive`)
		particles += count or 0
	end
	assert(particles <= MAX_PARTICLES, `vfx burst "{id}": {particles} particles is over the {MAX_PARTICLES} budget`)
	local light = burst.light
	if light ~= nil then
		assert(
			light.brightness > 0 and light.brightness <= MAX_LIGHT_BRIGHTNESS,
			`vfx burst "{id}": light brightness must be within 0..{MAX_LIGHT_BRIGHTNESS}`
		)
		assert(light.range > 0, `vfx burst "{id}": light range must be positive`)
		assert(
			light.seconds > 0 and light.seconds <= MAX_LIGHT_SECONDS,
			`vfx burst "{id}": light must last 0..{MAX_LIGHT_SECONDS} s`
		)
	end
	bursts[id] = burst
end

function VfxBurstRegistry.get(id: string): Burst?
	return bursts[id]
end

function VfxBurstRegistry.has(id: string): boolean
	return bursts[id] ~= nil
end

function VfxBurstRegistry.ids(): { string }
	local ids: { string } = {}
	for id in bursts do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

--[=[
	Seconds from the burst's start until its last particle has died (each layer's delay plus its longest lifetime).
]=]
function VfxBurstRegistry.tail(burst: Burst): number
	local tail = 0
	for _, layer in burst.layers do
		tail = math.max(tail, (layer.delay or 0) + layer.lifetime.Max)
	end
	return tail
end

return VfxBurstRegistry
