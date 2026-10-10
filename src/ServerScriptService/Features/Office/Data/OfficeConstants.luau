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
local FLOOR_COLORS: { Color3 } = {
	Color3.fromRGB(96, 92, 86),
	Color3.fromRGB(70, 82, 96),
	Color3.fromRGB(88, 96, 78),
	Color3.fromRGB(100, 86, 80),
}

return table.freeze({
	-- Where the office's local 0, 0 sits in the world: far from the origin, where M4 builds the depot.
	ORIGIN = CFrame.new(1000, 0, 0),
	MODEL_NAME = "CleanupCrewOffice",
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
	-- Players appear this high above a spawn marker.
	SPAWN_HEIGHT = 3,
	FLOOR_COLORS = table.freeze(FLOOR_COLORS),
	WALL_COLOR = Color3.fromRGB(200, 198, 190),
	DESK_COLOR = Color3.fromRGB(140, 110, 80),
	LOCKER_COLOR = Color3.fromRGB(110, 120, 130),
	TRUCK_COLOR = Color3.fromRGB(230, 230, 235),
	BED_COLOR = Color3.fromRGB(60, 60, 64),
	CLOCK_COLOR = Color3.fromRGB(200, 60, 50),
})
