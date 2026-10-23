--!strict
--[=[
	OfficeKitRegistry: the greybox catalogue of hand-authored office kits (stage 1 of the office map rebuild):
	eight rooms across the six room types, as pure data in each kit's local frame (OfficeTypes.Kit), at the sizes and
	with the contents of the approved spike (design/production-art/map-kits/odd-hours-b1/spike). Every kit passes
	OfficeKitRules; the spec also places each one in every facing and mirror and validates it as a layout. Aisles are
	kept at least 4 studs wide for Mr. Harlow. Every floor piece backed on a wall stands SHELL.trimClearance (0.55) off its
	plaster face so the wall trim runs behind it, and the window bay stands off the same way. A desk's front (local -Z:
	knee-hole and chair, the side HideSpotUtils and OfficeDecorSystem use) faces the room's open floor. A door with a leaf is
	the 6.8-stud rough opening; a glass front
	runs beside its door. Each kit keeps at least its room type's old pile and item density (per square stud), so the
	contract roll holds with fewer, bigger rooms. Counts are minimums; the coordinates are tuning.

	Static data, but spec'd on purpose (OfficeKitRegistry.spec) so the catalogue is validated like
	OfficeLayoutConstants is.

	@class OfficeKitRegistry
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

-- Furniture restyled by an art override (OfficeConstants.ART_SIZES sizes its proxy and footprint).
local function styled(kind: OfficeTypes.MarkerKind, art: string, x: number, z: number, rotation: number?): KitMarker
	return { kind = kind, x = x, z = z, rotation = rotation, art = art }
end

-- An art-only dressing prop (OfficeConstants.PROP_SIZES). A wall prop sits flush on a wall, facing into the room; a
-- desk-top prop takes its desk's centre and yaw.
local function prop(art: string, x: number, z: number, rotation: number?): KitMarker
	return { kind = "prop", x = x, z = z, rotation = rotation, art = art }
end

local KITS: { Kit } = {
	{
		id = "pods_a",
		roomType = "pods",
		name = "Desk pods",
		size = "L",
		width = 60,
		depth = 44,
		door = { offset = 30, width = 6.8, kind = "solid" },
		markers = {
			-- The spike's open plan: three pods of four desks back to back (each pod's front pair faces, chairs and all,
			-- the front wall, its back pair the back wall), two flush with the side walls by the door and one behind the
			-- left one. A partition pair splits each pod and two of its desks carry a plant.
			at("desk", 5.25, 7.2, 0),
			at("desk", 13.65, 7.2, 0),
			at("desk", 5.25, 14, HALF),
			at("desk", 13.65, 14, HALF),
			at("desk", 46.35, 7.2, 0),
			at("desk", 54.75, 7.2, 0),
			at("desk", 46.35, 14, HALF),
			at("desk", 54.75, 14, HALF),
			at("desk", 5.25, 30, 0),
			at("desk", 13.65, 30, 0),
			at("desk", 5.25, 36.8, HALF),
			at("desk", 13.65, 36.8, HALF),
			prop("partition", 6.45, 10.6, 0),
			prop("partition", 12.45, 10.6, 0),
			prop("deskPlant", 5.25, 7.2, 0),
			prop("deskPlant", 13.65, 14, HALF),
			prop("partition", 47.55, 10.6, 0),
			prop("partition", 53.55, 10.6, 0),
			prop("deskPlant", 46.35, 7.2, 0),
			prop("deskPlant", 54.75, 14, HALF),
			prop("partition", 6.45, 33.4, 0),
			prop("partition", 12.45, 33.4, 0),
			prop("deskPlant", 5.25, 30, 0),
			prop("deskPlant", 13.65, 36.8, HALF),
			-- Two columns mid-room; a stand-up corner (rug and standing corkboard) back right; window bays on the back wall
			-- between it and the back pod; a copier, planter and clock by the door; a shelf and planter on the right wall.
			prop("column", 24, 22, 0),
			prop("column", 36, 22, 0),
			prop("rug", 52, 36.5, 0),
			styled("board", "corkboard", 52, 42, 0),
			prop("copier", 21, 2.69, HALF),
			prop("planter", 38, 3.01, HALF),
			styled("shelf", "shelf", 57.91, 23.5, QUARTER),
			prop("planter", 56.99, 28.5, QUARTER),
			prop("windowBay", 25, 42.465, 0),
			prop("windowBay", 35, 42.465, 0),
			prop("wallClock", 24.5, 0.625, HALF),
			prop("artFrame", 0.635, 22, -QUARTER),
			prop("wasteBin", 18.8, 8, 0),
			at("pile", 22, 8),
			at("pile", 30, 10),
			at("pile", 39, 8),
			at("pile", 24, 14),
			at("pile", 36, 14),
			at("pile", 5, 22),
			at("pile", 13, 22),
			at("pile", 30, 22),
			at("pile", 46, 22),
			at("pile", 52, 22),
			at("pile", 21, 32),
			at("pile", 30, 30),
			at("pile", 30, 38),
			at("pile", 39, 34),
			at("pile", 21, 40),
			at("pile", 50, 33),
			at("item", 27, 4),
			at("item", 33, 15),
			at("item", 9, 22),
			at("item", 42, 26),
			at("item", 25, 35),
			at("item", 45, 40),
			at("item", 56, 33),
			at("patrol", 30, 26),
		},
	},
	{
		id = "pods_b",
		roomType = "pods",
		name = "Desk pods",
		size = "M",
		width = 44,
		depth = 32,
		door = { offset = 22, width = 6.8, kind = "solid" },
		markers = {
			-- Two pods flush with the side walls, the door between them; a stand-up corner (rug and standing corkboard) on
			-- the back wall between a cooler and a planter.
			at("desk", 5.175, 8.6, 0),
			at("desk", 13.425, 8.6, 0),
			at("desk", 5.175, 15.4, HALF),
			at("desk", 13.425, 15.4, HALF),
			at("desk", 30.575, 8.6, 0),
			at("desk", 38.825, 8.6, 0),
			at("desk", 30.575, 15.4, HALF),
			at("desk", 38.825, 15.4, HALF),
			prop("partition", 6.3, 12, 0),
			prop("partition", 12.3, 12, 0),
			prop("deskPlant", 5.175, 8.6, 0),
			prop("deskPlant", 13.425, 15.4, HALF),
			prop("partition", 31.7, 12, 0),
			prop("partition", 37.7, 12, 0),
			prop("deskPlant", 30.575, 8.6, 0),
			prop("deskPlant", 38.825, 15.4, HALF),
			prop("rug", 22, 25, 0),
			styled("board", "corkboard", 22, 30, 0),
			prop("waterCooler", 3, 30.2425, 0),
			prop("planter", 40.92, 28.99, 0),
			at("pile", 22, 9),
			at("pile", 22, 15),
			at("pile", 4, 22),
			at("pile", 13, 22),
			at("pile", 22, 22),
			at("pile", 31, 22),
			at("pile", 40, 22),
			at("pile", 9, 28),
			at("pile", 35, 28),
			at("item", 22, 4),
			at("item", 17, 27),
			at("item", 27, 27),
			at("item", 6, 27),
			at("patrol", 22, 19),
		},
	},
	{
		id = "conference_a",
		roomType = "conference",
		name = "Conference room",
		size = "M",
		width = 32,
		depth = 24,
		door = { offset = 6, width = 6.8, kind = "glass" },
		glass = { from = 10, to = 30 },
		markers = {
			styled("table", "conferenceTable", 16, 12, 0),
			styled("board", "corkboard", 16, 22, 0),
			at("pile", 4, 8),
			at("pile", 4, 15.5),
			at("pile", 28, 8),
			at("pile", 28, 18),
			at("pile", 16, 4),
			at("pile", 20, 18.5),
			at("pile", 24, 4),
			at("pile", 9, 19),
			at("item", 16, 5),
			at("item", 12, 19),
			at("patrol", 24, 13),
			-- Dressing: a screen on the right wall facing the table, a frame opposite, a planter in a corner.
			prop("wallScreen", 31.33, 12, QUARTER),
			prop("artFrame", 0.635, 14, -QUARTER),
			prop("planter", 3.08, 20.99, 0),
		},
	},
	{
		id = "conference_b",
		roomType = "conference",
		name = "Meeting room",
		size = "S",
		width = 22,
		depth = 18,
		door = { offset = 5, width = 6.8, kind = "glass" },
		glass = { from = 9, to = 21 },
		markers = {
			-- The spike's meeting room: the table past the door's swing, a screen on the back wall, a frame on the right and a
			-- planter in the front-right corner. The glass front runs beside the door.
			styled("table", "conferenceTable", 12, 10.5, 0),
			at("pile", 2.5, 9),
			at("pile", 12, 3.5),
			at("pile", 14, 5),
			at("pile", 4, 16),
			at("pile", 11, 16),
			at("item", 10, 5.5),
			at("item", 2, 13),
			at("patrol", 8, 16),
			prop("wallScreen", 10, 17.33, 0),
			prop("artFrame", 21.365, 10, QUARTER),
			prop("planter", 18.92, 3.01, HALF),
		},
	},
	{
		id = "breakout_a",
		roomType = "breakout",
		name = "Breakout lounge",
		size = "M",
		width = 32,
		depth = 26,
		door = { offset = 16, width = 6.8, kind = "solid" },
		markers = {
			-- The spike's breakout: a rug with a turned break table and a sofa on the left wall (a lamp beside it), a second
			-- table with its sofa on the right, two kitchen counters on the back wall, and vending, a cooler and a planter on
			-- the right wall.
			styled("table", "breakTable", 8, 12, QUARTER),
			styled("table", "breakTable", 22, 10.6, 0),
			styled("counter", "kitchenCounter", 11.95, 23.41, 0),
			styled("counter", "kitchenCounter", 20.05, 23.41, 0),
			prop("rug", 8, 12, QUARTER),
			prop("sofa", 2.86, 12, -QUARTER),
			prop("sofa", 22, 15.95, 0),
			prop("floorLamp", 2.4, 6.4, 0),
			prop("vending", 28.665, 20, QUARTER),
			prop("waterCooler", 30.2425, 14.8, QUARTER),
			prop("planter", 28.99, 3.08, QUARTER),
			prop("artFrame", 0.635, 12, -QUARTER),
			prop("wallClock", 16, 25.375, 0),
			at("pile", 6, 3),
			at("pile", 24, 3),
			at("pile", 14, 12),
			at("pile", 3, 21),
			at("pile", 29, 9),
			at("pile", 12, 19.4),
			at("item", 14, 6),
			at("item", 4, 24),
			at("item", 14, 17),
			at("item", 20, 3.5),
			at("rest", 21, 20.4),
			at("patrol", 16, 4),
		},
	},
	{
		id = "storage_a",
		roomType = "storage",
		name = "Storage closet",
		size = "S",
		width = 12,
		depth = 12,
		door = { offset = 4.4, width = 6.8, kind = "solid" },
		markers = {
			-- The spike's storage: two supply cabinets on the back wall, a shelf on the right wall beside the door.
			at("closet", 3.21, 9.225, 0),
			at("closet", 7.53, 9.225, 0),
			styled("shelf", "shelf", 9.91, 3.82, QUARTER),
			prop("sconce", 0.99, 5, -QUARTER),
			at("pile", 2.5, 2.5),
			at("pile", 6.5, 2.5),
			at("pile", 4.5, 5.5),
			at("item", 6, 4.5),
			at("patrol", 5, 3),
		},
	},
	{
		id = "server_a",
		roomType = "server",
		name = "Server room",
		size = "M",
		width = 20,
		depth = 18,
		door = { offset = 10, width = 6.8, kind = "solid" },
		markers = {
			-- The spike's server room: four racks side by side on the back wall (their LedLight glows), a supply cabinet on
			-- the left wall, sconces either side of the racks and a bin on the right wall.
			styled("shelf", "serverRack", 6.4, 15.2, 0),
			styled("shelf", "serverRack", 8.8, 15.2, 0),
			styled("shelf", "serverRack", 11.2, 15.2, 0),
			styled("shelf", "serverRack", 13.6, 15.2, 0),
			at("closet", 2.775, 6, -QUARTER),
			prop("sconce", 3.5, 17.01, 0),
			prop("sconce", 16.5, 17.01, 0),
			prop("wasteBin", 18.02, 15, QUARTER),
			at("pile", 7, 3),
			at("pile", 15, 3),
			at("pile", 10, 10),
			at("pile", 17, 10),
			at("item", 2.5, 15.5),
			at("item", 13, 7),
			at("patrol", 6, 12),
		},
	},
	{
		id = "reception_a",
		roomType = "reception",
		name = "Reception",
		size = "L",
		width = 28,
		depth = 28,
		door = { offset = 14, width = 10, kind = "open" },
		markers = {
			-- The spike's reception, turned so the generator's entrance facade (back wall, x 8..20) and the door face each
			-- other across a clear lobby: the desk in front of the glowing left wall, facing into the room; a rug with a
			-- break table, sofa, lamp, frame and clock on the right; a planter in each corner.
			styled("counter", "receptionDesk", 7, 14, -QUARTER),
			styled("table", "breakTable", 19.5, 14, QUARTER),
			at("cabinet", 6.5, 25.95, 0),
			prop("receptionGlow", 0.8, 14, -QUARTER),
			prop("rug", 21, 14, QUARTER),
			prop("sofa", 25.14, 14, QUARTER),
			prop("floorLamp", 26.18, 20, 0),
			prop("planter", 3.08, 24.99, 0),
			prop("planter", 24.92, 24.99, 0),
			prop("planter", 3.08, 3.01, HALF),
			prop("planter", 24.92, 3.01, HALF),
			prop("artFrame", 27.365, 14, QUARTER),
			prop("wallClock", 27.375, 22, QUARTER),
			at("pile", 10, 3),
			at("pile", 18, 3.5),
			at("pile", 13.3, 14),
			at("pile", 12, 25),
			at("pile", 18, 25),
			at("item", 13.3, 8),
			at("item", 2.5, 21),
			at("patrol", 14, 20),
		},
	},
}

local OfficeKitRegistry = {}

OfficeKitRegistry.KITS = KITS

--[=[
	The kit with this id, if any.
]=]
function OfficeKitRegistry.get(id: string): Kit?
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
function OfficeKitRegistry.ofType(roomType: RoomType): { Kit }
	local found: { Kit } = {}
	for _, kit in KITS do
		if kit.roomType == roomType then
			table.insert(found, kit)
		end
	end
	return found
end

return OfficeKitRegistry
