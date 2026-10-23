--!strict
--[=[
	OfficeConstants: the office's placement, graybox sizes and the spawn roll's knobs (Cleanup Crew spec §4
	"Spawn guarantees", §5). Every number is a tuning hypothesis. Static data (spec-exempt).

	@class OfficeConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

-- The dust is clustered (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.1): a few
-- properly dirty rooms with clean rooms between them, each holding PILES_PER_ROOM piles. About a third of the piles
-- bury a valuable, and a map offers 10-14 valuables in all (open, buried and in desks; the loot loop,
-- docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.5).
-- Desks, break tables and chairs are built this many times their catalog size, so a full-size employee fits
-- underneath in the hide pose (Hide HUG_FREE_MIN).
local HIDE_FURNITURE_SCALE = 1.65
local DIRTY_ROOMS: OfficeTypes.Range = { min = 4, max = 6 }
local PILES_PER_ROOM: OfficeTypes.Range = { min = 3, max = 5 }
local VALUABLES: OfficeTypes.Range = { min = 10, max = 14 }
-- Original catalog dimensions, rounded upward for visual fit without shrinking readable props.
local DESK_PROP_SIZES: { [string]: Vector3 } = {
	mug = Vector3.new(0.685, 0.56, 0.48),
	paperTray = Vector3.new(1.075, 0.54, 1.355),
	folder = Vector3.new(1.15, 0.104, 1.495),
	paperStack = Vector3.new(0.987, 0.131, 1.294),
	bookStack = Vector3.new(1.007, 0.465, 1.14),
	stationeryCup = Vector3.new(0.34, 0.721, 0.34),
}
-- Art-only dressing props (the `prop` marker kind), named by Marker.art: W x H x D studs. Props over 1 stud tall
-- collide. The wall-mounted ones (PROP_WALL_HEIGHT) hang on a wall at that centre height.
local PROP_SIZES: { [string]: Vector3 } = {
	sofa = Vector3.new(7, 3.2, 3.2),
	vending = Vector3.new(3.6, 7, 3),
	waterCooler = Vector3.new(1.6, 4.2, 1.6),
	copier = Vector3.new(3.6, 4, 3),
	floorLamp = Vector3.new(1.6, 6, 1.6),
	planter = Vector3.new(2.4, 4.5, 2.4),
	wasteBin = Vector3.new(1.4, 1.8, 1.4),
	artFrame = Vector3.new(3.5, 2.5, 0.25),
	wallScreen = Vector3.new(5, 3, 0.3),
	sconce = Vector3.new(1, 1.4, 0.6),
	wallClock = Vector3.new(1.4, 1.4, 0.2),
	deskPlant = Vector3.new(0.9, 1.2, 0.9),
	partition = Vector3.new(6, 4.5, 0.4),
	stairwellSign = Vector3.new(2, 1, 0.1),
}
local PROP_WALL_HEIGHT: { [string]: number } = {
	artFrame = 6,
	wallScreen = 6.5,
	sconce = 7.5,
	wallClock = 8,
	stairwellSign = 7,
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
	-- The art kit every generated map uses (OfficeLayoutGenerationUtils); the authored boot layout keeps ART_KIT_ID.
	GENERATED_ART_KIT = "odd-hours-b1",
	PROP_SIZES = table.freeze(PROP_SIZES),
	PROP_WALL_HEIGHT = table.freeze(PROP_WALL_HEIGHT),
	-- The floor number kit rooms are placed on (one floor today).
	FLOOR_NUMBER = 1,
	-- The corridor network (OfficeCorridorUtils): a LATTICE_COLS x LATTICE_ROWS grid of junction nodes, each line
	-- jittered by up to LATTICE_JITTER studs (the dock and lobby lines are never jittered).
	LATTICE_COLS = 5,
	LATTICE_ROWS = 4,
	LATTICE_STEP_X = 64,
	LATTICE_STEP_Z = 60,
	LATTICE_JITTER = 6,
	DOCK_NODE = table.freeze({ col = 3, row = 1 }),
	LOBBY_NODE = table.freeze({ col = 1, row = 3 }),
	CORRIDOR_WIDE = 10,
	CORRIDOR_NARROW = 6,
	NARROW_CHANCE = 0.35,
	ATRIUM_SIZE = 26,
	CORRIDOR_EDGES = table.freeze({ min = 9, max = 12 }),
	LOOPS = table.freeze({ min = 1, max = 2 }),
	-- The kit generator (OfficeLayoutGenerationUtils): the number of kit rooms per map (reception included), how far
	-- past the corridor lattice's bounding box a room may reach, the cursor step when no kit fits a slot, the weights
	-- of the drawn room types (server and reception are fixed: one each), the extra conference weight at the
	-- perimeter, the attempts before generate gives up, and the area a map's rooms (bay excluded) should total.
	KIT_ROOMS = table.freeze({ min = 14, max = 20 }),
	ROOM_MARGIN = 36,
	ROOM_STEP = 4,
	KIT_WEIGHTS = table.freeze({ pods = 45, conference = 25, storage = 20, breakout = 10 }),
	PERIMETER_CONFERENCE_BOOST = 3,
	GENERATE_ATTEMPTS = 8,
	-- A generated map needs this many hiding places (desks and closets), and every room within WALK_SPEED *
	-- MAX_WALK_SECONDS studs of walking from the bay.
	HIDE_SPOTS_MIN = 8,
	WALK_SPEED = 16,
	MAX_WALK_SECONDS = 40,
	TARGET_FLOOR_AREA = 24300,
	-- A generated room's depth is its walking distance from the bay over DEPTH_STUDS, rounded down: about one room of the
	-- old grid crossed, so DEEP_DEPTH keeps meaning "a couple of rooms in" now that corridors add doors.
	DEPTH_STUDS = 48,
	-- Two kit rooms joined through one corridor piece are next to each other (no clean room between them) only when
	-- their doors are this close; further along a long corridor is not "next door".
	NEIGHBOUR_DOOR_STUDS = 24,
	DESK_PROP_SIZES = table.freeze(DESK_PROP_SIZES),
	HIDE_FURNITURE_SCALE = HIDE_FURNITURE_SCALE,
	OFFICE_CHAIR_SIZE = Vector3.new(2.27, 3.562, 2.26) * HIDE_FURNITURE_SCALE,
	-- The gap between a desk's edge and the chair drawn beside it.
	OFFICE_CHAIR_GAP = 0.42,
	DECOR_KEYBOARD_SIZE = Vector3.new(1.8, 0.212, 0.8),
	DECOR_MOUSE_SIZE = Vector3.new(0.35, 0.258, 0.53),
	SHELF_SIZE = Vector3.new(5, 6, 2),
	COUNTER_SIZE = Vector3.new(6, 3, 2.5),
	PLANT_SIZE = Vector3.new(2, 4, 2),
	BOARD_SIZE = Vector3.new(5, 4, 0.3),
	BOARD_CENTER_HEIGHT = 6,
	-- Corner filing cabinets and meeting/break tables: art-sized proxies with lootable tops.
	CABINET_SIZE = Vector3.new(1.9, 4.2, 2),
	-- The tall supply cabinet (a secure hiding spot): the supplyCabinet art's own bounds, room inside for a crew member.
	CLOSET_SIZE = Vector3.new(4.32, 8, 3.45),
	TABLE_SIZE = Vector3.new(5, 3.1, 3) * HIDE_FURNITURE_SCALE,
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
	-- Real doors (OfficeDoorSystem): the leaf's id kind / path label, size, swing and the noise / auto-open radii.
	-- The leaf stops 3 studs short of the 12-stud wall top (that gap above the leaf is left open). A leaf carries a
	-- PathfindingModifier (Label DOOR_PATH_LABEL, PassThrough) so Mr. Harlow's paths ignore it; he opens doors within
	-- DOOR_AUTO_OPEN_RADIUS of himself, and a door slammed by a player is heard DOOR_SLAM_RADIUS studs away.
	DOOR_KIND = "officeDoor",
	DOOR_PATH_LABEL = "OfficeDoor",
	DOOR_HEIGHT = 9,
	DOOR_LEAF_THICKNESS = 0.3,
	DOOR_SWING_SECONDS = 0.3,
	DOOR_OPEN_ANGLE = math.rad(95),
	DOOR_AUTO_OPEN_RADIUS = 10,
	DOOR_SLAM_RADIUS = 18,
	DOOR_COLOR = Color3.fromRGB(122, 92, 64),
	-- Kit rooms: furniture stays out of a box this deep behind the front door (OfficeKitRules).
	DOOR_APPROACH = 5,
	-- Rooms this many doors from the loading bay, or more, are "deep" (where the greed target goes).
	DEEP_DEPTH = 2,
	DIRTY_ROOMS = table.freeze(DIRTY_ROOMS),
	PILES_PER_ROOM = table.freeze(PILES_PER_ROOM),
	-- How many valuables a map offers, counting the greed target, desk valuables and buried ones (no trash: the Gloom
	-- economy rolls none).
	VALUABLES = table.freeze(VALUABLES),
	-- Chance a desk or locker holds a valuable; once DESK_VALUABLES_MAX of them hold one, the rest hold nothing (a
	-- generated office has dozens of desks: uncapped, they would eat the whole valuables budget).
	SEARCH_FILL_CHANCE = 0.5,
	DESK_VALUABLES_MAX = 3,
	-- Chance each pile buries a valuable (a buriable kind, CargoRegistry), capped so at least MIN_OPEN valuables of
	-- the budget still lie in the open.
	BURY_CHANCE = 0.35,
	MIN_OPEN = 2,
	-- The cleanliness a map's valuables are priced at for the logs (a grime factor of 0.65).
	LOOT_AVERAGE_CLEAN = 0.5,
	-- The contract guarantee (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.4): the
	-- contract may ask at most CONTRACT_SHARE_MAX of the site's Gloom (piles plus valuables' grime); a thinner roll
	-- adds up to TOP_UP_MAX more piles on free pile markers (plain, burying nothing; the dirty rooms' spare markers
	-- first). 6: the thinnest clustered roll (4 dirty rooms of 3 piles, about 730 Gloom at 50 a pile) needs about 6
	-- more for the biggest crew.
	CONTRACT_SHARE_MAX = 0.8,
	TOP_UP_MAX = 6,
	-- Seeds tried (seed, seed + 1, ...) before a roll that misses a guarantee is an error.
	ROLL_ATTEMPTS = 5,
	-- The overtime batch (Shift spec §3): this share of the shift's valuables, rounded, at least 1, spawned once when
	-- overtime begins on the spots the first roll left free. Only these items pay the overtime multiplier.
	OVERTIME_LOOT_SHARE = 0.5,
	DESK_SIZE = Vector3.new(5, 3, 3) * HIDE_FURNITURE_SCALE,
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
	-- The loading bay (the start room; Harlow may walk it, only the truck's box is safe), studs along X and Z
	-- (OfficeLoadingBayUtils). The truck runs along Z, cab toward +Z: the depth fits the whole truck plus
	-- RAMP_CLEARANCE of floor behind its ramp.
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
	LIGHT_COLOR = Color3.fromRGB(215, 228, 255),
	-- At least 1.25x the reach from a lamp to the floor corner between neighbouring lamps
	-- (sqrt(WALL_HEIGHT^2 + 2 * (LIGHT_SPACING / 2)^2) = 16.02 studs, so 20.02), or the corners go dark
	-- (OfficeBuildSystem.spec "ceiling lamp coverage"). The night is dimmed by LIGHT_BRIGHTNESS, not the range.
	LIGHT_RANGE = 21,
	LIGHT_BRIGHTNESS = 0.5,
	-- The invisible volume over the truck's box (the one safe place) that Harlow's paths never enter.
	SAFE_ZONE_NAME = "SafeZone",
	-- M2: Harlow's route needs at least this many points.
	ROUTE_MIN = 3,
	-- A route point in the loading bay keeps this far off the truck's bed and ramp (he walks the bay, never the box).
	TRUCK_ROUTE_CLEAR = 2,
})
