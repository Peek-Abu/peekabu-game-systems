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
-- Art-only dressing props (the `prop` marker kind), named by Marker.art: W x H x D studs, each the template's own
-- BaseSize (odd-hours-b1 KIT_MAP) so Uniform fit never shrinks one. Props over 1 stud tall collide. The wall-mounted
-- ones (PROP_WALL_HEIGHT) hang on a wall at that centre height; the desk-top ones (PROP_DESK_TOP) stand on a desk; a
-- flat one (under FLAT_PROP_HEIGHT tall: the rug) lies on the floor and furniture stands on it.
local PROP_SIZES: { [string]: Vector3 } = {
	sofa = Vector3.new(7.64, 3.5, 3.62),
	vending = Vector3.new(3.43, 7.5, 4.57),
	waterCooler = Vector3.new(1.34, 5, 1.415),
	copier = Vector3.new(4.6, 4.6, 3.28),
	floorLamp = Vector3.new(1.54, 6.52, 1.54),
	planter = Vector3.new(4.06, 5.97, 3.92),
	wasteBin = Vector3.new(1.85, 2, 1.86),
	artFrame = Vector3.new(4, 3, 0.27),
	wallScreen = Vector3.new(7, 4, 0.34),
	sconce = Vector3.new(0.88, 1.05, 0.98),
	wallClock = Vector3.new(1.8, 1.8, 0.25),
	deskPlant = Vector3.new(1.26, 1.39, 1.26),
	partition = Vector3.new(6, 5, 1.8),
	stairwellSign = Vector3.new(2, 1, 0.1),
	rug = Vector3.new(14, 0.1, 13),
	windowBay = Vector3.new(6, 10.3, 0.97),
	column = Vector3.new(2.8, 13, 2.8),
	receptionGlow = Vector3.new(14, 6, 0.6),
}
local PROP_WALL_HEIGHT: { [string]: number } = {
	artFrame = 6,
	wallScreen = 6.5,
	sconce = 7.5,
	wallClock = 8,
	stairwellSign = 7,
	-- Its bottom 1.5 above the floor.
	windowBay = 6.65,
	receptionGlow = 6.5,
}
-- A desk-top prop's marker sits at its desk's centre (and yaw); the prop stands on the desktop at
-- DESK_PLANT_OFFSET in the desk's frame (front is local -Z).
local PROP_DESK_TOP: { [string]: boolean } = { deskPlant = true }
-- The proxy size of furniture restyled by a marker's `art` override: the template's BaseSize (KIT_MAP), so the proxy
-- follows the art instead of Uniform fit shrinking it to the slate-tuned kind size. No entry for the desk (it keeps
-- DESK_SIZE for hide space), the locker (a single locker; the kit's is a bank) or the chair (decor-placed).
-- breakTable is a low coffee table: its proxy is the art's size x HIDE_FURNITURE_SCALE (what it renders at), so the
-- visible top is the proxy top, and it leaves no HUG_FREE_MIN under it: no hiding spot.
-- (The closets use CLOSET_SIZE and the partition is a prop: PROP_SIZES.)
local ART_SIZES: { [string]: Vector3 } = {
	corkboard = Vector3.new(6.4, 6.1, 1.9),
	breakTable = Vector3.new(5, 1.8, 3) * HIDE_FURNITURE_SCALE,
	shelf = Vector3.new(5.54, 8, 2.08),
	serverRack = Vector3.new(2, 7, 3.5),
	kitchenCounter = Vector3.new(8, 6.35, 3.08),
	receptionDesk = Vector3.new(12.86, 4.6, 5.16),
	conferenceTable = Vector3.new(14, 4.95, 6),
}
-- The spike's light recipe per room type (key = OfficeArtKeyUtils.roomType; an unknown type uses pods).
local LIGHTING: {
	[string]: {
		panelBrightness: number,
		panelRange: number,
		allLit: boolean,
		fillBrightness: number,
		fillRange: number,
	},
} =
	{
		hallway = { panelBrightness = 0.2, panelRange = 14, allLit = true, fillBrightness = 1.3, fillRange = 12 },
		pods = { panelBrightness = 0.22, panelRange = 14, allLit = false, fillBrightness = 1.7, fillRange = 11.5 },
		breakout = { panelBrightness = 0.22, panelRange = 14, allLit = false, fillBrightness = 1.7, fillRange = 11.5 },
		reception = { panelBrightness = 0.22, panelRange = 14, allLit = false, fillBrightness = 1.7, fillRange = 11.5 },
		conference = { panelBrightness = 0.22, panelRange = 14, allLit = false, fillBrightness = 1.5, fillRange = 11.5 },
		server = { panelBrightness = 0.12, panelRange = 14, allLit = false, fillBrightness = 0.6, fillRange = 10 },
		storage = { panelBrightness = 0.15, panelRange = 14, allLit = true, fillBrightness = 0.8, fillRange = 10 },
	}
-- Small accent lights by attachment name (they cast no shadows): every template OfficeBuildSystem or OfficeDecorSystem
-- attaches gets one on each descendant Attachment named here (a server rack's LedLight, a floor lamp's LampLight).
local ACCENT_LIGHTS: { [string]: { brightness: number, range: number, color: Color3 } } = {
	LedLight = { brightness = 0.4, range = 6, color = Color3.fromRGB(120, 170, 255) },
	ScreenLight = { brightness = 0.7, range = 6, color = Color3.fromRGB(190, 215, 255) },
	GlowLight = { brightness = 1.6, range = 11, color = Color3.fromRGB(255, 200, 140) },
	LampLight = { brightness = 1.6, range = 11, color = Color3.fromRGB(255, 168, 90) },
}
-- Shell geometry sizes in studs (OfficeShellUtils). slab: one plaster layer (a wall is two); slabOverhang: how far the
-- slabs run below the floor top and above the ceiling; wainscot/rail/skirt: trim heights and how far each stands off the
-- slab face; casing: door jamb thickness; pilaster: archway column width; mullion/mullionSpacing/glassFrame/baseRail:
-- framed glass; gridSpacing/gridWidth/gridThickness: ceiling grid strips; trimClearance: how far off the plaster face a
-- floor piece (or the window bay) backed against a wall stands, so the wainscot, rail and skirt (all under
-- railDepth proud) run behind it, as the spike backs every wall piece off by 0.55.
local SHELL = table.freeze({
	slab = 0.5,
	slabOverhang = 1,
	wainscotHeight = 3,
	wainscotProud = 0.3,
	railHeight = 0.25,
	railDepth = 0.5,
	skirtHeight = 0.6,
	skirtProud = 0.4,
	casing = 0.35,
	pilaster = 0.6,
	mullion = 0.4,
	mullionSpacing = 6,
	glassFrame = 0.6,
	baseRail = 0.35,
	gridSpacing = 4,
	gridWidth = 0.15,
	gridThickness = 0.08,
	trimClearance = 0.55,
})
-- What each shell box is made of (a nil variant is none). Values measured from the spike and the mock room.
local SHELL_MATERIALS: { [OfficeTypes.ShellMaterial]: { material: Enum.Material, variant: string?, color: Color3, transparency: number } } =
	{
		plaster = {
			material = Enum.Material.Plaster,
			variant = "OH_Plaster",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		oak = { material = Enum.Material.Wood, variant = "OH_Oak", color = Color3.new(1, 1, 1), transparency = 0 },
		rail = { material = Enum.Material.Wood, variant = nil, color = Color3.fromRGB(110, 80, 56), transparency = 0 },
		skirt = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(150, 112, 80),
			transparency = 0,
		},
		frame = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(46, 48, 56),
			transparency = 0,
		},
		grid = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(170, 165, 156),
			transparency = 0,
		},
		glass = {
			material = Enum.Material.Glass,
			variant = nil,
			color = Color3.fromRGB(170, 205, 215),
			transparency = 0.6,
		},
		ceiling = {
			material = Enum.Material.Concrete,
			variant = "OH_Ceiling",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		carpet = {
			material = Enum.Material.Fabric,
			variant = "OH_Carpet",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		hallcarpet = {
			material = Enum.Material.Fabric,
			variant = "OH_Carpet",
			color = Color3.fromRGB(191, 191, 198),
			transparency = 0,
		},
		lino = {
			material = Enum.Material.Plastic,
			variant = "OH_Lino",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		vinyl = {
			material = Enum.Material.Plastic,
			variant = "OH_Vinyl",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
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
	PROP_DESK_TOP = table.freeze(PROP_DESK_TOP),
	-- A prop shorter than this lies flat on the floor (a rug): it takes no floor space in the overlap tests.
	FLAT_PROP_HEIGHT = 0.5,
	-- On the left of the desk's front half, in the clear band between the mug (z -1.85) and the folder or paper stack
	-- (z 1.07) of OfficeDecorSystem.dressDesk (DESK_SPREAD 1.65).
	DESK_PLANT_OFFSET = Vector3.new(-3.4, 0, -0.6),
	ART_SIZES = table.freeze(ART_SIZES),
	-- The floor number kit rooms are placed on (one floor today).
	FLOOR_NUMBER = 1,
	-- The corridor network (OfficeCorridorUtils): a LATTICE_COLS x LATTICE_ROWS grid of junction nodes, each line
	-- jittered by up to LATTICE_JITTER studs (the dock and lobby lines are never jittered). At the spike's scale
	-- (docs/superpowers/specs/2026-10-23-odd-hours-office-map-spike-delta-design.md): main halls CORRIDOR_WIDE, side
	-- halls CORRIDOR_NARROW, every junction at least JUNCTION_MIN on a side. A step leaves a 60-64-stud run between
	-- junctions, so the 60-wide pods kit fits along a horizontal run and two kits back to back fit between rows; low
	-- jitter keeps the runs straight. CORRIDOR_EDGES of the lattice's 17 edges are drawn (plus LOOPS).
	LATTICE_COLS = 4,
	LATTICE_ROWS = 3,
	LATTICE_STEP_X = 84,
	LATTICE_STEP_Z = 76,
	LATTICE_JITTER = 3,
	DOCK_NODE = table.freeze({ col = 3, row = 1 }),
	LOBBY_NODE = table.freeze({ col = 1, row = 3 }),
	CORRIDOR_WIDE = 14,
	CORRIDOR_NARROW = 10,
	NARROW_CHANCE = 0.35,
	JUNCTION_MIN = 20,
	ATRIUM_SIZE = 26,
	CORRIDOR_EDGES = table.freeze({ min = 8, max = 11 }),
	LOOPS = table.freeze({ min = 1, max = 2 }),
	-- The kit generator (OfficeLayoutGenerationUtils): the number of kit rooms per map (reception included), how far
	-- past the corridor lattice's bounding box a room may reach, the cursor step when no kit fits a slot, the weights
	-- of the drawn room types (server and reception are fixed: one each), the extra conference weight at the
	-- perimeter, the attempts before generate gives up, and the area a map's rooms (bay excluded) should total.
	-- ROOM_MARGIN 44: the deepest kit (pods_a, 44) can hang off an outer hall (whose face is 3-5 studs inside the
	-- lattice box). Pods carry the hiding places (12 or 8 desks), so they get the biggest weight.
	KIT_ROOMS = table.freeze({ min = 6, max = 12 }),
	ROOM_MARGIN = 44,
	ROOM_STEP = 4,
	KIT_WEIGHTS = table.freeze({ pods = 60, conference = 18, storage = 12, breakout = 10 }),
	PERIMETER_CONFERENCE_BOOST = 1.5,
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
	-- A board (whiteboard or corkboard) stands on the floor on its own legs.
	BOARD_SIZE = Vector3.new(5, 4, 0.3),
	-- Corner filing cabinets and meeting/break tables: art-sized proxies with lootable tops.
	CABINET_SIZE = Vector3.new(1.9, 4.2, 2),
	-- The tall supply cabinet (a secure hiding spot): the supplyCabinet art's own bounds, room inside for a crew member.
	CLOSET_SIZE = Vector3.new(4.32, 8, 3.45),
	TABLE_SIZE = Vector3.new(5, 1.8, 3) * HIDE_FURNITURE_SCALE,
	-- Loot (bulkiest kind is 3.5 wide) never spawns clipped into surface furniture.
	SURFACE_ITEM_CLEAR = 1.8,
	-- Visual-only monitor/elevator envelopes include the authored stand/surround depth.
	DECOR_MONITOR_SIZE = Vector3.new(2.25, 1.845, 0.7),
	ELEVATOR_FRONT_SIZE = Vector3.new(6, 8, 0.5),
	SHIFT_FOLDER_NAME = "Shift",
	WALL_HEIGHT = 13,
	WALL_THICKNESS = 1,
	-- Shell trim and framing dimensions (OfficeShellUtils), measured from the approved spike.
	SHELL = SHELL,
	SHELL_MATERIALS = table.freeze(SHELL_MATERIALS),
	FLOOR_THICKNESS = 1,
	-- A marker sits at least this far inside its room's walls.
	MARKER_MARGIN = 2,
	DOOR_MIN_WIDTH = 4,
	-- Real doors (OfficeDoorSystem): the leaf's id kind / path label, size, swing and the noise / reach radii.
	-- The leaf stops short of the wall top (that gap above the leaf is left open). A leaf carries a
	-- PathfindingModifier (Label DOOR_PATH_LABEL, PassThrough) so Mr. Harlow's paths ignore it; he opens a door only
	-- when it lies on his line of travel (within DOOR_REACH, ahead of his heading and within its half-width plus his
	-- agent radius of his heading line: OfficeDoorUtils.reach; standing still, he opens none), a player cannot
	-- close a door while an NPC is within DOOR_REACH of it, and a door slammed by a player is heard DOOR_SLAM_RADIUS
	-- studs away. A facade leaf (locked set dressing) is tagged FACADE_KIND and rattles DOOR_RATTLE_ANGLE for
	-- DOOR_RATTLE_SECONDS when a player tries it.
	DOOR_KIND = "officeDoor",
	FACADE_KIND = "officeFacade",
	DOOR_PATH_LABEL = "OfficeDoor",
	DOOR_HEIGHT = 9.4,
	DOOR_LEAF_THICKNESS = 0.3,
	DOOR_SWING_SECONDS = 0.3,
	DOOR_OPEN_ANGLE = math.rad(95),
	DOOR_REACH = 8,
	DOOR_RATTLE_ANGLE = math.rad(1.5),
	DOOR_RATTLE_SECONDS = 0.25,
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
	WALL_COLOR = Color3.fromRGB(200, 198, 190),
	DESK_COLOR = Color3.fromRGB(140, 110, 80),
	LOCKER_COLOR = Color3.fromRGB(110, 120, 130),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	CLOCK_COLOR = Color3.fromRGB(200, 60, 50),
	OVERTIME_COLOR = Color3.fromRGB(230, 170, 40),
	-- The office's lights (OfficeLightingUtils / OfficeShellVisualSystem): LIGHTING is the per-room-type recipe.
	LIGHTING = table.freeze(LIGHTING),
	ACCENT_LIGHTS = table.freeze(ACCENT_LIGHTS),
	-- Troffer panel glow and the warm fill light colours (from the spike).
	PANEL_COLOR = Color3.fromRGB(255, 240, 220),
	FILL_COLOR = Color3.fromRGB(255, 232, 205),
	-- The invisible volume over the truck's box (the one safe place) that Harlow's paths never enter.
	SAFE_ZONE_NAME = "SafeZone",
	-- M2: Harlow's route needs at least this many points.
	ROUTE_MIN = 3,
	-- A route point in the loading bay keeps this far off the truck's bed and ramp (he walks the bay, never the box).
	TRUCK_ROUTE_CLEAR = 2,
})
