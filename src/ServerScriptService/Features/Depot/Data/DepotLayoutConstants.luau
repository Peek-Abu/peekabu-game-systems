--!strict
--[=[
	DepotLayoutConstants: where the depot sits, its authored graybox layout and its sizes (Cleanup Crew spec
	§1 "polished feel on graybox", §3 step 1, §5). Every number is a tuning hypothesis. Static data
	(spec-exempt; LAYOUT is checked by DepotLayoutRules.spec).

	@class DepotLayoutConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

-- A closed garage: three trucks along the back wall, the boards at the front, spawns between.
local LAYOUT: DepotTypes.Layout = {
	floor = { minX = 0, minZ = 0, maxX = 96, maxZ = 72 },
	trucks = {
		{ id = "truck1", x = 20, z = 48, capacity = 4, countdown = 15 },
		{ id = "truck2", x = 48, z = 48, capacity = 4, countdown = 15 },
		{ id = "truck3", x = 76, z = 48, capacity = 4, countdown = 15 },
	},
	contractBoard = { x = 34, z = 12 },
	resultBoard = { x = 62, z = 12 },
	spawns = {
		{ x = 40, z = 26 },
		{ x = 46, z = 26 },
		{ x = 52, z = 26 },
		{ x = 58, z = 26 },
	},
}

return table.freeze({
	-- Where the depot's local 0, 0 sits in the world. The office is at x = 1000 (OfficeConstants.ORIGIN), so in
	-- Studio, where one server plays both roles, the two never meet. Lifted (like the office) so the whole floor,
	-- joint bed included, stands clear of the place's Baseplate, whose top is at y = 0 under the depot: a floor
	-- flush with it z-fights and shows the Baseplate's grid through.
	ORIGIN = CFrame.new(-1000, 1.25, 0),
	MODEL_NAME = "CleanupCrewDepot",
	LAYOUT = LAYOUT,
	-- Tall enough for a truck's tag sign above the box (the truck is ~11.7 studs high on its 3-stud bed).
	WALL_HEIGHT = 22,
	WALL_THICKNESS = 1,
	FLOOR_THICKNESS = 1,
	-- A truck's bed (the queue pad, boarded up the ramp; the same height as the office truck's, so one truck art
	-- fits both), the cab behind it (+z), the ramp and scanner arch in front of it (-z), and the truck's full width
	-- (DepotTruckVisualConstants checks its art fits these).
	BED_SIZE = Vector3.new(12, 3, 16),
	CAB_SIZE = Vector3.new(12, 10, 7),
	RAMP_DEPTH = 4.5,
	TRUCK_WIDTH = 15,
	BOARD_SIZE = Vector3.new(12, 8, 1),
	-- Trucks, boards and spawns keep this far inside the walls.
	MARGIN = 3,
	-- Space between two trucks.
	TRUCK_GAP = 4,
	-- A spawn keeps this far from any truck, so nobody spawns aboard a pad.
	SPAWN_CLEARANCE = 6,
	-- Spec §3: 3-4 trucks of 1-4 players, a ~15 s countdown.
	MIN_TRUCKS = 3,
	MAX_TRUCKS = 4,
	MAX_CAPACITY = 4,
	MIN_COUNTDOWN = 5,
	MAX_COUNTDOWN = 60,
	-- Players appear this high above a spawn point.
	SPAWN_HEIGHT = 3,
	-- How often each player's public `truck` field is checked against the bed they stand in (seconds).
	TRUCK_INTERVAL = 0.5,
	-- World sign shells are sized from their design (DepotConstants.BILLBOARD_PX); offsets from the part's centre.
	-- The truck tag floats over the box: its wire's tip clears the arch (DepotTruckVisualConstants.TOP above the bed).
	PAD_TAG_OFFSET = Vector3.new(0, 14.5, 0),
	CONTRACT_OFFSET = Vector3.new(0, 2, 0),
	RESULT_OFFSET = Vector3.new(0, 2.5, 0),
	LABEL_MAX_DISTANCE = 120,
	-- The returning player's card, in their PlayerGui.
	CARD_NAME = "DepotResultCard",
	PLAYER_GUI_WAIT = 10,
	-- Hub v1 lighting: warm tungsten ceiling strips over the trucks (LIGHT_XS at LIGHT_Z), and a brighter, slightly
	-- whiter strip over each board, BOARD_LIGHT_SETBACK in front of it, so the reading wall is the best-lit spot.
	-- They are fills: under the place's Soft lighting style 1.6 / 2 blew every character out to a glowing white.
	LIGHT_XS = table.freeze({ 20, 48, 76 }),
	LIGHT_Z = 36,
	LIGHT_SIZE = Vector3.new(8, 0.3, 2),
	LIGHT_COLOR = Color3.fromRGB(255, 206, 148),
	LIGHT_RANGE = 45,
	LIGHT_BRIGHTNESS = 0.35,
	BOARD_LIGHT_SETBACK = 5,
	BOARD_LIGHT_COLOR = Color3.fromRGB(255, 228, 188),
	BOARD_LIGHT_RANGE = 32,
	BOARD_LIGHT_BRIGHTNESS = 0.45,
	-- Hub v1 floor paint (DepotMarkingUtils plans it, DepotBuildSystem lays it): thin, non-colliding parts LIFT above the
	-- floor. Per truck: a "BAY n" stencil in front of the ramp, a hazard band of STRIPE-wide yellow/black stripes across
	-- the ramp's foot, two side lines BAY_HALF_WIDTH from the truck's centre from the bay's front to BAY_BACK_GAP short
	-- of the back wall, and a dashed lane from LANE_START_Z (behind the spawn strip) to the bay's front.
	MARKING = table.freeze({
		YELLOW = Color3.fromRGB(240, 190, 40),
		BLACK = Color3.fromRGB(26, 26, 28),
		THICKNESS = 0.04,
		LIFT = 0.01,
		LINE_WIDTH = 0.5,
		BAY_HALF_WIDTH = 9,
		BAY_BACK_GAP = 1,
		-- The bay's front: this far in front of the ramp's foot (the stencil sits in between).
		BAY_FRONT = 6,
		LABEL_SIZE = Vector2.new(10, 4.5),
		HAZARD_WIDTH = 9,
		HAZARD_DEPTH = 1.5,
		STRIPE = 1,
		LANE_START_Z = 18,
		DASH = 2,
		GAP = 1.5,
		-- The concrete floor: SLAB-stud slabs JOINT_DEPTH thick on the darker joint bed (FLOOR_COLOR), JOINT apart,
		-- so the expansion joints are real gaps, not paint, and nothing lies flush on anything else.
		SLAB = 12,
		JOINT = 0.15,
		JOINT_DEPTH = 0.1,
		SLAB_COLORS = table.freeze({
			Color3.fromRGB(118, 111, 102),
			Color3.fromRGB(112, 106, 98),
			Color3.fromRGB(124, 116, 106),
		}),
		-- Faint oil stains just in front of some bays: which truck, the offset from the bay front's centre, the size.
		STAIN_COLOR = Color3.fromRGB(52, 42, 34),
		STAIN_TRANSPARENCY = 0.7,
		STAINS = table.freeze({
			table.freeze({ truck = 1, dx = -3, dz = -1.8, diameter = 2.4 }),
			table.freeze({ truck = 3, dx = 2.6, dz = -1.4, diameter = 2 }),
		}),
	}),
	-- The BAY n stencil's text resolution on the floor: low enough that TextScaled's 100 px cap still fills the stencil.
	STENCIL_PIXELS_PER_STUD = 20,
	-- The joint bed under the concrete slabs (seen only in the expansion joints).
	FLOOR_COLOR = Color3.fromRGB(58, 54, 50),
	WALL_COLOR = Color3.fromRGB(150, 140, 120),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BOARD_COLOR = Color3.fromRGB(120, 95, 60),
})
