--!strict
--[=[
	DepotAtmosphereConstants: the depot garage's light on the client (hub v1: "a warm sodium/tungsten garage at
	dusk; readable, not dark, slightly cozy"). One preset, registered with Vfx at load by OfficeAtmosphereSystem
	(the one owner of Lighting, which blends to it whenever the local player is in the hub:
	DepotAtmosphereUtils). Every number is a tuning hypothesis; DepotAtmosphereConstants.spec keeps it warm and
	readable.

	@class DepotAtmosphereConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

local PRESETS: { [string]: VfxTypes.Atmosphere } = {
	depotEvening = {
		-- Just after sunset: the sky behind the place goes orange, the sun is too low to light the garage.
		clockTime = 18.3,
		brightness = 1.4,
		exposure = 0,
		-- The garage is lit by its own warm lamps; the ambient keeps every corner readable.
		ambient = Color3.fromRGB(138, 104, 76),
		outdoorAmbient = Color3.fromRGB(118, 90, 70),
		fogColor = Color3.fromRGB(96, 66, 46),
		fogStart = 160,
		fogEnd = 600,
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	EVENING = "depotEvening",
})
