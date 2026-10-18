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
		brightness = 0.42,
		exposure = -0.5,
		ambient = Color3.fromRGB(26, 30, 46),
		outdoorAmbient = Color3.fromRGB(14, 16, 27),
		fogColor = Color3.fromRGB(8, 10, 18),
		fogStart = 45,
		fogEnd = 200,
	},
	officeTier1 = {
		clockTime = 0,
		brightness = 0.35,
		exposure = -0.6,
		ambient = Color3.fromRGB(22, 25, 40),
		outdoorAmbient = Color3.fromRGB(12, 13, 23),
		fogColor = Color3.fromRGB(6, 8, 14),
		fogStart = 38,
		fogEnd = 170,
	},
	officeTier2 = {
		clockTime = 0,
		brightness = 0.28,
		exposure = -0.7,
		ambient = Color3.fromRGB(18, 19, 34),
		outdoorAmbient = Color3.fromRGB(9, 10, 18),
		fogColor = Color3.fromRGB(4, 5, 10),
		fogStart = 30,
		fogEnd = 140,
	},
	officeBreak = {
		clockTime = 0,
		brightness = 0.46,
		exposure = -0.45,
		ambient = Color3.fromRGB(32, 36, 52),
		outdoorAmbient = Color3.fromRGB(16, 18, 29),
		fogColor = Color3.fromRGB(10, 12, 20),
		fogStart = 52,
		fogEnd = 215,
	},
	officeOvertime = {
		clockTime = 0,
		brightness = 0.25,
		exposure = -0.7,
		ambient = Color3.fromRGB(56, 18, 22),
		outdoorAmbient = Color3.fromRGB(28, 8, 10),
		fogColor = Color3.fromRGB(20, 4, 6),
		fogStart = 28,
		fogEnd = 130,
	},
}

-- Seconds between two sounds of each office bed sweetener kind (OfficeAssets.SWEETENERS).
local SWEETENER_EVERY: { [string]: { min: number, max: number } } = {
	ceilingTick = table.freeze({ min = 5, max = 12 }),
	drawer = table.freeze({ min = 18, max = 30 }),
	farDing = table.freeze({ min = 25, max = 40 }),
	typeKey = table.freeze({ min = 6, max = 15 }),
	floorCreak = table.freeze({ min = 8, max = 18 }),
	musicBox = table.freeze({ min = 20, max = 35 }),
	pipeKnock = table.freeze({ min = 9, max = 20 }),
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
	-- The office bed's sweeteners (OfficeAmbienceSystem): each kind waits its own `min`..`max` seconds (the round-2 bed
	-- plan A), then one variant sounds SWEETENER_NEAR..SWEETENER_FAR studs from the listener, on a level ring.
	SWEETENER_EVERY = table.freeze(SWEETENER_EVERY),
	SWEETENER_NEAR = 12,
	SWEETENER_FAR = 30,
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
	-- A broken tube's zap (OfficeLightUtils.zaps): only a burst's first blink (one after ZAP_BURST_GAP seconds without
	-- a blink starts a burst), ZAP_TUBE_GAP seconds apart per tube and ZAP_GLOBAL_GAP apart across every tube (at most
	-- 12 a minute; simulated ~10 a minute with eight broken tubes in range, which blink ~620 times a minute).
	ZAP_BURST_GAP = 1.5,
	ZAP_TUBE_GAP = 12,
	ZAP_GLOBAL_GAP = 5,
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
