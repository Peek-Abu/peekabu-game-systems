--!strict
--[=[
	SchoolKitRegistry: the greybox catalogue of the School's room kits (docs/superpowers/plans/2026-11-10-odd-hours-school-map.md),
	as pure data in each kit's local frame (OfficeTypes.Kit), so the Office's placement (OfficeKitUtils), rules
	(OfficeKitRules, OfficeLayoutRules) and build take them unchanged. Every kit passes OfficeKitRules; the spec also
	places each one in every facing and mirror and validates it as a layout.

	The pieces: two classroom layouts (rows facing a chalkboard, and desk groups), the art and music rooms, the nurse,
	the principal, the teachers' lounge (Harlow's rest, the Office breakout's role), a bathroom (stalls are closets), the
	janitor's closet, the front hall (the start room, the loading bay's size) and the three landmarks that fill a
	lattice block: the gym, the cafeteria and the library (64 x 56). Hiding places are the Office's: desks at the
	Office's 1.65x size (Hide's HUG_FREE_MIN fits under) and closets. School furniture uses the existing marker kinds
	with school art keys (chalkboard, bookshelf, trophyCase...); a key the art kit lacks falls back to the kind's own
	art (OfficeArtKeyUtils), which is the greybox. Props name existing PROP_SIZES art only.

	The front hall is placed facing maxZ and never mirrored: its back wall is the building front (the dock exit) and its
	right wall (local x = width) the west wall (the lobby exit); both stay clear.

	Static data, but spec'd on purpose (SchoolKitRegistry.spec), like OfficeKitRegistry.

	@class SchoolKitRegistry
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

type Kit = OfficeTypes.Kit
type KitMarker = OfficeTypes.KitMarker
type RoomType = OfficeTypes.RoomType

local QUARTER = math.pi / 2
local HALF = math.pi

local function at(kind: OfficeTypes.MarkerKind, x: number, z: number, rotation: number?): KitMarker
	return { kind = kind, x = x, z = z, rotation = rotation }
end

-- Furniture with a School art key (sized by OfficeConstants.ART_SIZES when it has an entry, else by its kind).
local function styled(kind: OfficeTypes.MarkerKind, art: string, x: number, z: number, rotation: number?): KitMarker
	return { kind = kind, x = x, z = z, rotation = rotation, art = art }
end

-- An art-only dressing prop (OfficeConstants.PROP_SIZES).
local function prop(art: string, x: number, z: number, rotation: number?): KitMarker
	return { kind = "prop", x = x, z = z, rotation = rotation, art = art }
end

local KITS: { Kit } = {
	{
		id = "classroom_rows",
		roomType = "classroom",
		name = "Classroom",
		size = "M",
		width = 32,
		depth = 26,
		door = { offset = 6, width = 6.8, kind = "solid" },
		markers = {
			-- Two rows of student desks facing the chalkboard on the back wall (their chairs on the front-wall side), and
			-- the teacher's desk turned to face them.
			at("desk", 5.5, 10, 0),
			at("desk", 16, 10, 0),
			at("desk", 26.5, 10, 0),
			at("desk", 5.5, 19.5, 0),
			at("desk", 16, 19.5, 0),
			at("desk", 26.5, 18.8, HALF),
			styled("board", "chalkboard", 11, 24.8, 0),
			prop("artFrame", 0.635, 15, -QUARTER),
			prop("wallClock", 31.375, 15, QUARTER),
			at("pile", 22, 3.5),
			at("pile", 28, 4),
			at("pile", 3, 3.5),
			at("pile", 2.5, 24),
			at("item", 10.75, 14.75),
			at("item", 12, 3.5),
			at("patrol", 16, 4.5),
		},
	},
	{
		id = "classroom_groups",
		roomType = "classroom",
		name = "Classroom",
		size = "M",
		width = 28,
		depth = 28,
		door = { offset = 22, width = 6.8, kind = "solid" },
		markers = {
			-- A group of four desks back to back, the chalkboard on the back wall and cubbies on the right wall.
			at("desk", 6, 10, 0),
			at("desk", 14.4, 10, 0),
			at("desk", 6, 16.8, HALF),
			at("desk", 14.4, 16.8, HALF),
			styled("board", "chalkboard", 14, 26.8, 0),
			styled("shelf", "cubbies", 25.95, 18, QUARTER),
			prop("artFrame", 0.635, 16, -QUARTER),
			at("pile", 22, 10),
			at("pile", 22, 24),
			at("pile", 4, 25),
			at("pile", 10, 4),
			at("item", 22, 4),
			at("item", 10, 23),
			at("patrol", 22, 18),
		},
	},
	{
		id = "art",
		roomType = "classroom",
		name = "Art room",
		size = "M",
		width = 28,
		depth = 26,
		door = { offset = 6, width = 6.8, kind = "solid" },
		markers = {
			-- Two paint tables, a sink on the right wall, a supply closet and an easel.
			at("desk", 19, 10.5, 0),
			at("desk", 19, 19.7, 0),
			at("closet", 2.775, 20, -QUARTER),
			styled("counter", "artSink", 25.7, 6, QUARTER),
			styled("board", "easel", 8, 24.8, 0),
			prop("artFrame", 0.635, 12, -QUARTER),
			at("pile", 8, 12),
			at("pile", 4, 4),
			at("pile", 25.9, 15),
			at("item", 10, 16),
			at("item", 12, 22),
			at("patrol", 10, 10),
		},
	},
	{
		id = "music",
		roomType = "classroom",
		name = "Music room",
		size = "M",
		width = 28,
		depth = 26,
		door = { offset = 22, width = 6.8, kind = "solid" },
		markers = {
			-- Two risers to hide under, the piano and the instrument closet.
			at("desk", 9, 12, 0),
			at("desk", 9, 21.2, 0),
			at("closet", 2.775, 3.3, -QUARTER),
			styled("table", "piano", 20, 16, 0),
			prop("artFrame", 27.365, 20, QUARTER),
			prop("wallClock", 14, 25.375, 0),
			at("pile", 20, 9),
			at("pile", 16, 23),
			at("pile", 2.5, 16),
			at("pile", 24, 23),
			at("item", 14.5, 4),
			at("item", 24, 4),
			at("patrol", 20, 10),
		},
	},
	{
		id = "nurse",
		roomType = "nurse",
		name = "Nurse's office",
		size = "S",
		width = 24,
		depth = 22,
		door = { offset = 12, width = 6.8, kind = "solid" },
		markers = {
			-- Two cots to hide under and the medicine cabinet.
			styled("desk", "cot", 5.5, 15, 0),
			styled("desk", "cot", 18.5, 15, 0),
			styled("cabinet", "medicineCabinet", 21.6, 4, 0),
			prop("wasteBin", 2.5, 3.5, 0),
			prop("artFrame", 12, 21.365, 0),
			at("pile", 12, 12),
			at("pile", 12, 19),
			at("pile", 5.5, 7),
			at("pile", 18, 7),
			at("item", 12, 4),
			at("item", 3, 20),
			at("patrol", 12, 8),
		},
	},
	{
		id = "principal",
		roomType = "principal",
		name = "Principal's office",
		size = "S",
		width = 24,
		depth = 22,
		door = { offset = 12, width = 6.8, kind = "solid" },
		markers = {
			-- The big desk facing the door, filing cabinets in the back corners, planters by the door.
			at("desk", 12, 13, HALF),
			at("cabinet", 2.1, 19.5, -QUARTER),
			at("cabinet", 21.9, 19.5, QUARTER),
			prop("planter", 3.08, 3.01, HALF),
			prop("planter", 20.92, 3.01, HALF),
			prop("artFrame", 12, 21.365, 0),
			at("pile", 5, 10),
			at("pile", 19, 10),
			at("pile", 12, 5),
			at("item", 19, 15),
			at("item", 5, 15),
			at("patrol", 12, 7),
		},
	},
	{
		id = "lounge",
		roomType = "lounge",
		name = "Teachers' lounge",
		size = "M",
		width = 28,
		depth = 24,
		door = { offset = 14, width = 6.8, kind = "solid" },
		markers = {
			-- The Office breakout's role: a break table on a rug with a sofa, a work desk, the kitchen counter and a
			-- vending machine. Harlow rests in the back-left corner.
			styled("table", "breakTable", 8, 12, QUARTER),
			prop("rug", 8, 12, QUARTER),
			prop("sofa", 2.86, 12, -QUARTER),
			at("desk", 18, 14, 0),
			styled("counter", "kitchenCounter", 20, 21.41, 0),
			prop("vending", 24.665, 12, QUARTER),
			prop("wallClock", 8, 23.375, 0),
			at("pile", 24, 4),
			at("pile", 4, 4),
			at("pile", 12, 20),
			at("pile", 25.5, 17),
			at("item", 14, 18.5),
			at("item", 8, 21),
			at("rest", 6, 20),
			at("patrol", 14, 4),
		},
	},
	{
		id = "bathroom",
		roomType = "bathroom",
		name = "Bathroom",
		size = "S",
		width = 22,
		depth = 18,
		door = { offset = 11, width = 6.8, kind = "solid" },
		markers = {
			-- Four stalls on the back wall (closets: hide inside) and the sinks on the right wall.
			styled("closet", "stall", 3.21, 15.225, 0),
			styled("closet", "stall", 7.53, 15.225, 0),
			styled("closet", "stall", 11.85, 15.225, 0),
			styled("closet", "stall", 16.17, 15.225, 0),
			styled("counter", "sinkCounter", 19.7, 6, QUARTER),
			at("pile", 4, 4),
			at("pile", 11, 9),
			at("pile", 16, 10),
			at("pile", 4, 10),
			at("item", 8, 11),
			at("item", 15, 4),
			at("patrol", 11, 8),
		},
	},
	{
		id = "janitor",
		roomType = "janitor",
		name = "Janitor's closet",
		size = "S",
		width = 14,
		depth = 12,
		door = { offset = 4.4, width = 6.8, kind = "solid" },
		markers = {
			-- The Office storage closet's plan: two supply cabinets on the back wall and a shelf on the right wall.
			at("closet", 3.21, 9.225, 0),
			at("closet", 7.53, 9.225, 0),
			styled("shelf", "shelf", 11.91, 3.82, QUARTER),
			at("pile", 2.5, 2.5),
			at("pile", 6.5, 2.5),
			at("pile", 4.5, 5.5),
			at("item", 6, 4.5),
			at("patrol", 5, 3),
		},
	},
	{
		id = "fronthall",
		roomType = "fronthall",
		name = "Front hall",
		size = "L",
		width = 44,
		depth = 42,
		door = { offset = 22, width = 10, kind = "open" },
		markers = {
			-- The start room: trophy cases and a bench on the left wall, a bench under the clock by the front doors, the
			-- office counter, planters by the doorway into the school. The back wall's middle (the front doors) and the
			-- right wall's middle (the side doors) stay clear.
			styled("shelf", "trophyCase", 2.1, 10, -QUARTER),
			styled("shelf", "trophyCase", 2.1, 32, -QUARTER),
			prop("sofa", 2.86, 21, -QUARTER),
			prop("sofa", 8, 39.14, 0),
			styled("counter", "officeCounter", 32, 36, 0),
			prop("planter", 3.08, 3.01, HALF),
			prop("planter", 40.92, 3.01, HALF),
			prop("artFrame", 0.635, 26, -QUARTER),
			prop("wallClock", 8, 41.375, 0),
			at("pile", 8, 8),
			at("pile", 30, 10),
			at("pile", 12, 28),
			at("pile", 34, 24),
			at("pile", 16, 20),
			at("item", 22, 12),
			at("item", 36, 12),
			at("item", 20, 30),
			at("patrol", 22, 18),
		},
	},
	{
		id = "gym",
		roomType = "gym",
		name = "Gym",
		size = "L",
		width = 64,
		depth = 56,
		door = { offset = 32, width = 10, kind = "open" },
		markers = {
			-- Equipment closets down the left wall, benches down the right, the scorers' tables and the scoreboard at the
			-- back, crash mats in the middle.
			styled("closet", "equipmentCloset", 2.775, 12, -QUARTER),
			styled("closet", "equipmentCloset", 2.775, 20, -QUARTER),
			styled("closet", "equipmentCloset", 2.775, 36, -QUARTER),
			styled("closet", "equipmentCloset", 2.775, 44, -QUARTER),
			styled("desk", "scorersTable", 24, 46, 0),
			styled("desk", "scorersTable", 40, 46, 0),
			styled("board", "scoreboard", 32, 54.8, 0),
			prop("rug", 32, 24, 0),
			prop("sofa", 61.14, 14, QUARTER),
			prop("sofa", 61.14, 28, QUARTER),
			prop("sofa", 61.14, 42, QUARTER),
			prop("planter", 3.08, 52.99, 0),
			prop("wallClock", 20, 55.375, 0),
			at("pile", 16, 10),
			at("pile", 48, 10),
			at("pile", 32, 14),
			at("pile", 20, 30),
			at("pile", 44, 30),
			at("pile", 32, 36),
			at("pile", 12, 50),
			at("pile", 52, 50),
			at("item", 32, 8),
			at("item", 10, 28),
			at("item", 54, 22),
			at("item", 32, 48),
			at("patrol", 32, 28),
		},
	},
	{
		id = "cafeteria",
		roomType = "cafeteria",
		name = "Cafeteria",
		size = "L",
		width = 64,
		depth = 56,
		door = { offset = 32, width = 10, kind = "open" },
		markers = {
			-- Two lunch tables of four seats to hide under, two small tables, the serving line on the back wall and a
			-- vending machine and cooler on the right wall.
			styled("desk", "lunchTable", 6.5, 12, 0),
			styled("desk", "lunchTable", 14.9, 12, 0),
			styled("desk", "lunchTable", 6.5, 18.8, HALF),
			styled("desk", "lunchTable", 14.9, 18.8, HALF),
			styled("desk", "lunchTable", 49.1, 12, 0),
			styled("desk", "lunchTable", 57.5, 12, 0),
			styled("desk", "lunchTable", 49.1, 18.8, HALF),
			styled("desk", "lunchTable", 57.5, 18.8, HALF),
			styled("table", "breakTable", 24, 34, 0),
			styled("table", "breakTable", 40, 34, 0),
			styled("counter", "kitchenCounter", 20, 53.41, 0),
			styled("counter", "kitchenCounter", 28.1, 53.41, 0),
			styled("counter", "kitchenCounter", 36.2, 53.41, 0),
			styled("counter", "kitchenCounter", 44.3, 53.41, 0),
			prop("vending", 60.665, 32, QUARTER),
			prop("waterCooler", 62.2425, 38, QUARTER),
			prop("planter", 3.08, 52.99, 0),
			prop("artFrame", 0.635, 34, -QUARTER),
			prop("wallClock", 8, 55.375, 0),
			at("pile", 26, 12),
			at("pile", 38, 18),
			at("pile", 32, 26),
			at("pile", 10, 30),
			at("pile", 54, 28),
			at("pile", 20, 46),
			at("pile", 44, 46),
			at("item", 32, 8),
			at("item", 12, 28),
			at("item", 52, 40),
			at("item", 32, 44),
			at("patrol", 32, 24),
		},
	},
	{
		id = "library",
		roomType = "library",
		name = "Library",
		size = "L",
		width = 64,
		depth = 56,
		door = { offset = 32, width = 10, kind = "open" },
		markers = {
			-- Rows of bookshelves on the left, two reading tables of four to hide under on the right, the front desk by the
			-- door and a book-return closet in the back corner.
			styled("shelf", "bookshelf", 4.5, 12, 0),
			styled("shelf", "bookshelf", 9.5, 12, 0),
			styled("shelf", "bookshelf", 14.5, 12, 0),
			styled("shelf", "bookshelf", 4.5, 20, 0),
			styled("shelf", "bookshelf", 9.5, 20, 0),
			styled("shelf", "bookshelf", 14.5, 20, 0),
			styled("shelf", "bookshelf", 4.5, 28, 0),
			styled("shelf", "bookshelf", 9.5, 28, 0),
			styled("shelf", "bookshelf", 14.5, 28, 0),
			styled("shelf", "bookshelf", 4.5, 36, 0),
			styled("shelf", "bookshelf", 9.5, 36, 0),
			styled("shelf", "bookshelf", 14.5, 36, 0),
			styled("shelf", "bookshelf", 4.5, 44, 0),
			styled("shelf", "bookshelf", 9.5, 44, 0),
			styled("shelf", "bookshelf", 14.5, 44, 0),
			styled("desk", "readingTable", 40, 22, 0),
			styled("desk", "readingTable", 48.4, 22, 0),
			styled("desk", "readingTable", 40, 28.8, HALF),
			styled("desk", "readingTable", 48.4, 28.8, HALF),
			styled("desk", "readingTable", 40, 42, 0),
			styled("desk", "readingTable", 48.4, 42, 0),
			styled("desk", "readingTable", 40, 48.8, HALF),
			styled("desk", "readingTable", 48.4, 48.8, HALF),
			styled("counter", "libraryDesk", 52, 8, 0),
			styled("closet", "bookReturn", 2.775, 51, -QUARTER),
			prop("planter", 60.92, 3.01, HALF),
			prop("artFrame", 63.365, 30, QUARTER),
			prop("wallClock", 32, 55.375, 0),
			at("pile", 24, 10),
			at("pile", 24, 30),
			at("pile", 12, 16),
			at("pile", 12, 32),
			at("pile", 30, 48),
			at("pile", 58, 20),
			at("item", 32, 20),
			at("item", 58, 40),
			at("item", 24, 50),
			at("patrol", 30, 30),
		},
	},
}

local SchoolKitRegistry = {}

SchoolKitRegistry.KITS = KITS

--[=[
	The kit with this id, if any.
]=]
function SchoolKitRegistry.get(id: string): Kit?
	for _, kit in KITS do
		if kit.id == id then
			return kit
		end
	end
	return nil
end

--[=[
	Every kit of one room type, in catalogue order.
]=]
function SchoolKitRegistry.ofType(roomType: RoomType): { Kit }
	local found: { Kit } = {}
	for _, kit in KITS do
		if kit.roomType == roomType then
			table.insert(found, kit)
		end
	end
	return found
end

return SchoolKitRegistry
