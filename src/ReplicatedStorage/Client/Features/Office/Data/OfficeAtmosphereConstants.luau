--!strict
--[=[
	OfficeAtmosphereConstants: the office's look and dread on the client (Cleanup Crew spec §7 "The office at
	night: dim, buzzing fluorescents (some flickering) …"; "Overtime: lighting shifts dim red"; ambient dread). The
	atmosphere presets (registered with Vfx at load by OfficeAtmosphereSystem), the overtime tint and light colour,
	the broken fluorescents' share, reach and blink, and the ambience timing. Every number is a tuning hypothesis.
	Static data (spec-exempt).

	@class OfficeAtmosphereConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

local PRESETS: { [string]: VfxTypes.Atmosphere } = {
	officeNight = {
		clockTime = 0,
		brightness = 0.6,
		exposure = -0.2,
		ambient = Color3.fromRGB(40, 44, 58),
		outdoorAmbient = Color3.fromRGB(22, 24, 34),
		fogColor = Color3.fromRGB(10, 12, 18),
		fogStart = 60,
		fogEnd = 260,
	},
	officeTier1 = {
		clockTime = 0,
		brightness = 0.5,
		exposure = -0.3,
		ambient = Color3.fromRGB(34, 36, 50),
		outdoorAmbient = Color3.fromRGB(18, 20, 28),
		fogColor = Color3.fromRGB(8, 9, 14),
		fogStart = 50,
		fogEnd = 220,
	},
	officeTier2 = {
		clockTime = 0,
		brightness = 0.4,
		exposure = -0.4,
		ambient = Color3.fromRGB(28, 28, 42),
		outdoorAmbient = Color3.fromRGB(14, 14, 22),
		fogColor = Color3.fromRGB(6, 6, 10),
		fogStart = 40,
		fogEnd = 180,
	},
	officeBreak = {
		clockTime = 0,
		brightness = 0.65,
		exposure = -0.15,
		ambient = Color3.fromRGB(48, 50, 62),
		outdoorAmbient = Color3.fromRGB(24, 26, 36),
		fogColor = Color3.fromRGB(12, 14, 20),
		fogStart = 70,
		fogEnd = 280,
	},
	officeOvertime = {
		clockTime = 0,
		brightness = 0.35,
		exposure = -0.45,
		ambient = Color3.fromRGB(78, 26, 26),
		outdoorAmbient = Color3.fromRGB(40, 12, 12),
		fogColor = Color3.fromRGB(28, 6, 6),
		fogStart = 35,
		fogEnd = 170,
	},
}

return table.freeze({
	PRESETS = table.freeze(PRESETS),
	NIGHT = "officeNight",
	TIER1 = "officeTier1",
	TIER2 = "officeTier2",
	BREAK = "officeBreak",
	OVERTIME = "officeOvertime",
	-- Seconds to blend between presets.
	FADE = 3,
	-- Overtime: a red, slightly drained screen and red ceiling lights.
	OVERTIME_TINT = Color3.fromRGB(255, 185, 185),
	OVERTIME_SATURATION = -0.2,
	OVERTIME_LIGHT_COLOR = Color3.fromRGB(255, 95, 80),
	-- The fluorescent hum's ambience slot.
	HUM_LAYER = "officeHum",
	-- Broken fluorescents: this share of the lights (stable per light), within this many studs of the camera,
	-- blink to BROKEN_DIM when their noise (at BROKEN_RATE) drops below BROKEN_THRESHOLD.
	BROKEN_FRACTION = 0.18,
	BROKEN_RADIUS = 80,
	BROKEN_RATE = 6,
	BROKEN_THRESHOLD = -0.3,
	BROKEN_DIM = 0.15,
	-- A blinking light's neon fades this far while dim.
	BROKEN_TRANSPARENCY = 0.6,
	ATMOSPHERE_INTERVAL = 0.05,
	-- Ambient dread (OfficeAmbienceSystem): phone and elevator waits, an "empty room" radius, when typing stops and
	-- how long it stays quiet, how often it re-checks.
	PHONE_MIN = 20,
	PHONE_MAX = 50,
	ELEVATOR_MIN = 50,
	ELEVATOR_MAX = 110,
	EMPTY_RADIUS = 28,
	TYPING_STOP_RADIUS = 20,
	TYPING_QUIET_SECONDS = 25,
	TYPING_FADE = 0.2,
	AMBIENCE_INTERVAL = 0.25,
})
