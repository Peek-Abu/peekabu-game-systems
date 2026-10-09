--!strict
--[=[
	VfxAtmosphereRegistry: the catalog of atmosphere presets by id (the ItemRegistry contract). A preset
	lists only the Lighting values it changes; the rest stay at the place's own values.

	@class VfxAtmosphereRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

type Atmosphere = VfxTypes.Atmosphere

local presets: { [string]: Atmosphere } = {}

local VfxAtmosphereRegistry = {}

--[=[
	Registers a preset. Asserts: the id is new; it sets at least one value; clockTime is within 0..24;
	brightness is not negative; fogStart is not after fogEnd when both are set.
]=]
function VfxAtmosphereRegistry.register(id: string, preset: Atmosphere)
	assert(presets[id] == nil, `atmosphere "{id}" is already registered`)
	assert(next(preset) ~= nil, `atmosphere "{id}" sets nothing`)
	local clockTime = preset.clockTime
	if clockTime ~= nil then
		assert(clockTime >= 0 and clockTime <= 24, `atmosphere "{id}": clockTime must be within 0..24`)
	end
	local brightness = preset.brightness
	if brightness ~= nil then
		assert(brightness >= 0, `atmosphere "{id}": brightness must not be negative`)
	end
	local fogStart, fogEnd = preset.fogStart, preset.fogEnd
	if fogStart ~= nil and fogEnd ~= nil then
		assert(fogStart <= fogEnd, `atmosphere "{id}": fogStart must not be after fogEnd`)
	end
	presets[id] = preset
end

function VfxAtmosphereRegistry.get(id: string): Atmosphere?
	return presets[id]
end

function VfxAtmosphereRegistry.has(id: string): boolean
	return presets[id] ~= nil
end

return VfxAtmosphereRegistry
