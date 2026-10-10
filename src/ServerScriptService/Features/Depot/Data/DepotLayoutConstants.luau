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
	-- Studio, where one server plays both roles, the two never meet.
	ORIGIN = CFrame.new(-1000, 0, 0),
	MODEL_NAME = "CleanupCrewDepot",
	LAYOUT = LAYOUT,
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 1,
	FLOOR_THICKNESS = 1,
	-- A truck's bed (the queue pad: low enough to step onto) and the cab behind it.
	BED_SIZE = Vector3.new(12, 1, 16),
	CAB_SIZE = Vector3.new(12, 8, 6),
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
	-- How often the pad labels recount who is aboard (seconds).
	LABEL_INTERVAL = 0.5,
	-- Billboard sizes are in studs (BillboardGui scale); offsets from the part's centre.
	PAD_LABEL_SIZE = Vector2.new(8, 3),
	PAD_LABEL_OFFSET = Vector3.new(0, 7, 0),
	BOARD_LABEL_SIZE = Vector2.new(12, 8),
	BOARD_LABEL_OFFSET = Vector3.new(0, 1, 0),
	TITLE_LABEL_SIZE = Vector2.new(10, 1.5),
	TITLE_LABEL_OFFSET = Vector3.new(0, 6, 0),
	CARD_LABEL_SIZE = Vector2.new(12, 9),
	CARD_LABEL_OFFSET = Vector3.new(0, 0.5, 0),
	LABEL_MAX_DISTANCE = 120,
	-- The returning player's card, in their PlayerGui.
	CARD_NAME = "DepotResultCard",
	PLAYER_GUI_WAIT = 10,
	FLOOR_COLOR = Color3.fromRGB(84, 86, 90),
	WALL_COLOR = Color3.fromRGB(150, 140, 120),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BOARD_COLOR = Color3.fromRGB(120, 95, 60),
	LABEL_BACKGROUND = Color3.fromRGB(245, 235, 200),
	LABEL_TEXT = Color3.fromRGB(30, 30, 30),
})
