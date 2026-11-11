--!strict
--[=[
	SchoolConstants: the procedural School's knobs (docs/superpowers/plans/2026-11-10-odd-hours-school-map.md). The
	School is built from the Office's parts (OfficeTypes.Layout, its kits' rules, the grounds, the checks), so only
	the School's own shape lives here. Every number is a tuning hypothesis. Static data (spec-exempt).

	The lattice: LATTICE_COLS x LATTICE_ROWS junctions, LATTICE_STEP_X x LATTICE_STEP_Z apart, the first at
	(LATTICE_ORIGIN_X, LATTICE_ORIGIN_Z). Wider than the Office's 84 x 76, so a landmark block's inside (between the
	junction faces across, between the hall faces deep) holds a 64 x 56 kit with a back aisle even when the inner
	lines jitter by LATTICE_JITTER; the outer lines and the front column never jitter. 86 x 80 is as wide as the
	Office's exterior shell allows with a 30-deep wall band on both sides: x runs -2..256, the band out to -39 and 293
	(OfficeConstants.OUTSIDE.ENVELOPE is -39..294); z runs 0..160, the band to 197 at the back and the front hall to
	-52 at the front (the envelope is -52..203).

	@class SchoolConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

-- The small rooms dealt once each (kit ids, SchoolKitRegistry); the lounge is dealt first so Harlow always has his
-- break room. Every other room slot takes a classroom.
local DECK: { string } = { "lounge", "principal", "nurse", "bathroom", "bathroom", "art", "music", "janitor" }
-- The landmark rooms in the order their blocks are drawn: the gym and the cafeteria always, the library at
-- LIBRARY_CHANCE.
local LANDMARKS: { OfficeTypes.RoomType } = { "gym", "cafeteria", "library" }

return table.freeze({
	LATTICE_COLS = 4,
	LATTICE_ROWS = 3,
	LATTICE_STEP_X = 86,
	LATTICE_STEP_Z = 80,
	LATTICE_ORIGIN_X = -2,
	LATTICE_ORIGIN_Z = 0,
	LATTICE_JITTER = 1,
	-- The front node is on the front row (row 1, the south side by the yard), in one of these columns; the spine runs
	-- from it straight back to the last row, and the front hall hangs off its south wall.
	FRONT_COLS = table.freeze({ 2, 3 }),
	CORRIDOR_WIDE = 14,
	CORRIDOR_NARROW = 10,
	JUNCTION_MIN = 20,
	-- How many lattice edges the hall network has (landmark halls and the spine count), before joining stray pieces.
	HALL_EDGES = table.freeze({ min = 10, max = 13 }),
	LIBRARY_CHANCE = 0.7,
	LANDMARKS = table.freeze(LANDMARKS),
	DECK = table.freeze(DECK),
	-- The classroom kits a room slot takes when the deck has nothing for it.
	CLASSROOM_KITS = table.freeze({ "classroom_rows", "classroom_groups" }),
	-- A map has at least this many classrooms (classroom_rows or classroom_groups).
	CLASSROOMS_MIN = 6,
	-- The outer wall band: rooms at most BAND_DEPTH deep outside an edge hall, its run split into slots about
	-- BAND_SLOT long.
	BAND_DEPTH = 30,
	BAND_SLOT = 28,
	-- A landmark room keeps at least this much floor behind its kit, so its back door opens onto clear floor.
	LANDMARK_BACK_AISLE = 6,
	-- A landmark's back door: this wide, open, at least LANDMARK_DOOR_INSET from the room's corners.
	LANDMARK_DOOR_WIDTH = 10,
	LANDMARK_DOOR_INSET = 8,
	-- Locker banks on the wide halls: LOCKER_BANK lockers side by side, a bank every LOCKER_SPACING studs along each long
	-- wall (the two walls staggered by half of it), the first LOCKER_START from the hall's end, each bank at least
	-- LOCKER_CLEAR from a door's casing.
	LOCKER_BANK = 3,
	LOCKER_SPACING = 28,
	LOCKER_START = 8,
	LOCKER_CLEAR = 3,
	-- Nothing is built this close to the front hall's west wall, where the lobby entrance comes in.
	FRONT_KEEP_OUT = 6,
	-- The lobby entrance's glass doorway on the front hall's west wall.
	ENTRANCE_WIDTH = 12,
	GENERATE_ATTEMPTS = 8,
})
