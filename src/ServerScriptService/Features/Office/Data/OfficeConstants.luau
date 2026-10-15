--!strict
--[=[
	OfficeConstants: the office's placement, graybox sizes and the spawn roll's knobs (Cleanup Crew spec §4
	"Spawn guarantees", §5). Every number is a tuning hypothesis. Static data (spec-exempt).

	@class OfficeConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local PILES: OfficeTypes.Range = { min = 18, max = 24 }
local SALVAGE: OfficeTypes.Range = { min = 6, max = 9 }
-- Sizes small enough to hide under a pile (variant B).
local HIDEABLE: { [string]: boolean } = { tiny = true, medium = true }
-- Original catalog dimensions, rounded upward for visual fit without shrinking readable props.
local DESK_PROP_SIZES: { [string]: Vector3 } = {
	mug = Vector3.new(0.685, 0.56, 0.48),
	paperTray = Vector3.new(1.075, 0.54, 1.355),
	folder = Vector3.new(1.15, 0.104, 1.495),
	paperStack = Vector3.new(0.987, 0.131, 1.294),
	bookStack = Vector3.new(1.007, 0.465, 1.14),
	deskCalendar = Vector3.new(0.78, 0.597, 0.445),
	stationeryCup = Vector3.new(0.34, 0.721, 0.34),
}
local FLOOR_COLORS: { Color3 } = {
	Color3.fromRGB(96, 92, 86),
	Color3.fromRGB(70, 82, 96),
	Color3.fromRGB(88, 96, 78),
	Color3.fromRGB(100, 86, 80),
}

return table.freeze({
	-- Where the office's local 0, 0 sits in the world: far from the origin, where M4 builds the depot.
	-- One-stud foundation clears the artist-owned baseplate top at Y=0.
	ORIGIN = CFrame.new(1000, 1, 0),
	MODEL_NAME = "CleanupCrewOffice",
	ART_KIT_ID = "client-office-slate",
	DESK_PROP_SIZES = table.freeze(DESK_PROP_SIZES),
	OFFICE_CHAIR_SIZE = Vector3.new(2.27, 3.562, 2.26),
	DECOR_KEYBOARD_SIZE = Vector3.new(1.8, 0.212, 0.8),
	DECOR_MOUSE_SIZE = Vector3.new(0.35, 0.258, 0.53),
	SHELF_SIZE = Vector3.new(5, 6, 2),
	COUNTER_SIZE = Vector3.new(6, 3, 2.5),
	PLANT_SIZE = Vector3.new(2, 4, 2),
	BOARD_SIZE = Vector3.new(5, 4, 0.3),
	BOARD_CENTER_HEIGHT = 6,
	-- Corner filing cabinets and meeting/break tables: art-sized proxies with lootable tops.
	CABINET_SIZE = Vector3.new(1.9, 4.2, 2),
	TABLE_SIZE = Vector3.new(5, 3.1, 3),
	-- Loot (bulkiest kind is 3.5 wide) never spawns clipped into surface furniture.
	SURFACE_ITEM_CLEAR = 1.8,
	-- Visual-only monitor/elevator envelopes include the authored stand/surround depth.
	DECOR_MONITOR_SIZE = Vector3.new(2.25, 1.845, 0.7),
	ELEVATOR_FRONT_SIZE = Vector3.new(6, 8, 0.5),
	SHIFT_FOLDER_NAME = "Shift",
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 1,
	FLOOR_THICKNESS = 1,
	-- A marker sits at least this far inside its room's walls.
	MARKER_MARGIN = 2,
	DOOR_MIN_WIDTH = 4,
	-- Rooms this many doors from the loading bay, or more, are "deep" (where the greed target goes).
	DEEP_DEPTH = 2,
	-- Trash on the floor, counting the piles' dust bags, is at least this times the quota.
	TRASH_FACTOR = 1.5,
	PILES = table.freeze(PILES),
	SALVAGE = table.freeze(SALVAGE),
	-- Chance a desk or locker holds something.
	SEARCH_FILL_CHANCE = 0.5,
	-- Variant B: chance a hideable salvage item goes under a pile instead of in the open.
	HIDE_CHANCE = 0.35,
	HIDEABLE = table.freeze(HIDEABLE),
	-- Seeds tried (seed, seed + 1, ...) before a roll that misses a guarantee is an error.
	ROLL_ATTEMPTS = 5,
	DESK_SIZE = Vector3.new(5, 3, 3),
	LOCKER_SIZE = Vector3.new(2.5, 7, 2.5),
	-- The truck bed is a platform this tall; the cab sits behind it.
	BED_HEIGHT = 3,
	CAB_SIZE = Vector3.new(12, 8, 6),
	CLOCK_SIZE = Vector3.new(1.5, 4, 1.5),
	-- Shift's overtime sheet: a post this size, OVERTIME_OFFSET (layout space) from the time clock. -X keeps it off the
	-- bay's spawn markers and the truck bed on every generated side.
	OVERTIME_SIZE = Vector3.new(1.5, 4, 1.5),
	OVERTIME_OFFSET = Vector3.new(-4, 0, 0),
	-- Players appear this high above a spawn marker (and above the truck bed's top, where a shift starts).
	SPAWN_HEIGHT = 3,
	-- The loading bay (the start room, Harlow's safe zone), studs along X and Z (OfficeLoadingBayUtils). The truck
	-- runs along Z, cab toward +Z: the depth fits the whole truck plus RAMP_CLEARANCE of floor behind its ramp.
	BAY_WIDTH = 44,
	BAY_DEPTH = 42,
	RAMP_CLEARANCE = 12,
	-- The bed's centre: TRUCK_SIDE_INSET from the bay's side wall away from a side door, TRUCK_CAB_INSET from the
	-- +Z wall (the bumper then stands 1.6 studs off its face).
	TRUCK_SIDE_INSET = 12,
	TRUCK_CAB_INSET = 17,
	-- The time clock from the bed's centre: CLOCK_SIDE toward the open side of the bay, CLOCK_BACK toward the ramp.
	CLOCK_SIDE = 14,
	CLOCK_BACK = 10,
	-- Where the crew stands on the bed at the start of a shift (offsets from the bed's centre, X and Z), facing the
	-- open back and the ramp (-Z).
	ARRIVAL_OFFSETS = table.freeze({
		Vector2.new(-2.75, 0),
		Vector2.new(2.75, 0),
		Vector2.new(-2.75, 4),
		Vector2.new(2.75, 4),
	}),
	FLOOR_COLORS = table.freeze(FLOOR_COLORS),
	WALL_COLOR = Color3.fromRGB(200, 198, 190),
	DESK_COLOR = Color3.fromRGB(140, 110, 80),
	LOCKER_COLOR = Color3.fromRGB(110, 120, 130),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	CLOCK_COLOR = Color3.fromRGB(200, 60, 50),
	OVERTIME_COLOR = Color3.fromRGB(230, 170, 40),
	-- M2: a ceiling light about every LIGHT_SPACING studs in each room (Harlow's tells flicker them).
	LIGHT_SPACING = 15,
	LIGHT_SIZE = Vector3.new(3, 0.3, 1.2),
	LIGHT_COLOR = Color3.fromRGB(235, 240, 255),
	LIGHT_RANGE = 22,
	LIGHT_BRIGHTNESS = 0.7,
	-- M2: the invisible volume over the loading bay that Harlow's paths never enter.
	SAFE_ZONE_NAME = "SafeZone",
	-- M2: Harlow's route needs at least this many points.
	ROUTE_MIN = 3,
})
