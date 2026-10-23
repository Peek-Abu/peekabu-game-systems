--!strict
--[=[
	OfficeKitRegistry: the greybox catalogue of hand-authored office kits (stage 1 of the office map rebuild):
	eight rooms across the six room types, as pure data in each kit's local frame (OfficeTypes.Kit). Every kit
	passes OfficeKitRules; the spec also places each one in every facing and mirror and validates it as a layout.
	Aisles are kept at least 4 studs wide for Mr. Harlow. A desk's front (local -Z: knee-hole and chair, the side
	HideSpotUtils and OfficeDecorSystem use) faces the room's open floor. Counts are minimums; the coordinates are
	tuning.

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
		width = 40,
		depth = 32,
		door = { offset = 20, width = 6, kind = "solid" },
		markers = {
			-- Both rows' fronts (and chairs) face the middle aisle: the front row is turned half way, the back row
			-- is not. The front row sits past the door leaf's swing.
			at("desk", 6, 9, HALF),
			at("desk", 20, 9, HALF),
			at("desk", 34, 9, HALF),
			at("desk", 6, 27, 0),
			at("desk", 20, 27, 0),
			at("desk", 34, 27, 0),
			at("plant", 3, 3),
			at("cabinet", 38.4, 1.6, 0),
			at("pile", 13, 30),
			at("pile", 27, 30),
			at("pile", 13, 17.25),
			at("pile", 27, 17.25),
			at("pile", 36, 17.25),
			at("item", 13, 14.2),
			at("item", 27, 14.2),
			at("item", 27, 22),
			at("patrol", 20, 17.25),
			-- Dressing: the copier, planter and bins line the front wall around the door; partitions close off the
			-- back corners behind the back row.
			prop("copier", 9, 2.14, HALF),
			prop("planter", 30, 2.46, HALF),
			prop("wasteBin", 15, 1.43, HALF),
			prop("wasteBin", 25.1, 1.43, HALF),
			prop("artFrame", 20, 31.365, 0),
			prop("partition", 4.5, 30.6, 0),
			prop("partition", 35.5, 30.6, 0),
		},
	},
	{
		id = "pods_b",
		roomType = "pods",
		name = "Desk pods",
		size = "M",
		width = 32,
		depth = 26,
		door = { offset = 6, width = 6, kind = "solid" },
		markers = {
			-- Desks against the side walls, fronts (and chairs) toward the middle; the left pair clears the door.
			at("desk", 3.5, 11, -QUARTER),
			at("desk", 3.5, 20.5, -QUARTER),
			at("desk", 28.5, 9.5, QUARTER),
			at("desk", 28.5, 19, QUARTER),
			styled("board", "corkboard", 16, 24.55, 0),
			at("pile", 16, 10),
			at("pile", 16, 17),
			at("pile", 12.5, 20.5),
			at("pile", 19.5, 20.5),
			at("pile", 22, 3.5),
			at("item", 13, 6.5),
			at("item", 20, 13.5),
			at("patrol", 16, 3),
			-- Dressing: a cooler and a bin on the front wall, a plant on two of the desks.
			prop("waterCooler", 28, 1.21, HALF),
			prop("wasteBin", 13, 1.43, HALF),
			prop("deskPlant", 3.5, 11, -QUARTER),
			prop("deskPlant", 28.5, 9.5, QUARTER),
		},
	},
	{
		id = "conference_a",
		roomType = "conference",
		name = "Conference room",
		size = "M",
		width = 32,
		depth = 24,
		door = { offset = 6, width = 6, kind = "glass" },
		glass = { from = 10, to = 30 },
		markers = {
			styled("table", "conferenceTable", 16, 12, 0),
			styled("board", "corkboard", 16, 22.55, 0),
			at("pile", 4, 8),
			at("pile", 4, 15.5),
			at("pile", 28, 8),
			at("pile", 28, 18),
			at("pile", 16, 4),
			at("pile", 20, 18.5),
			at("item", 16, 5),
			at("item", 12, 19.5),
			at("patrol", 24, 13),
			-- Dressing: a screen on the right wall facing the table, a frame opposite, a planter in a corner.
			prop("wallScreen", 31.33, 12, QUARTER),
			prop("artFrame", 0.635, 14, -QUARTER),
			prop("planter", 2.6, 21.5, 0),
		},
	},
	{
		id = "conference_b",
		roomType = "conference",
		name = "Meeting room",
		size = "S",
		width = 22,
		depth = 18,
		door = { offset = 4, width = 6, kind = "glass" },
		glass = { from = 8, to = 20 },
		markers = {
			styled("table", "conferenceTable", 12, 10, 0),
			at("pile", 2.5, 9),
			at("pile", 4, 15.5),
			at("pile", 19, 15.5),
			at("pile", 12, 3.5),
			at("pile", 12, 16),
			at("item", 14, 4.5),
			at("patrol", 10, 15.5),
			-- Dressing: a screen on the back wall, a frame on the right.
			prop("wallScreen", 11, 17.33, 0),
			prop("artFrame", 21.365, 10, QUARTER),
		},
	},
	{
		id = "breakout_a",
		roomType = "breakout",
		name = "Breakout lounge",
		size = "M",
		width = 30,
		depth = 26,
		door = { offset = 24, width = 6, kind = "solid" },
		markers = {
			styled("counter", "kitchenCounter", 8, 23.9, 0),
			styled("table", "breakTable", 8, 11, 0),
			styled("table", "breakTable", 21, 14, 0),
			at("plant", 27.5, 24),
			at("pile", 4, 18),
			at("pile", 16, 22.5),
			at("pile", 4, 3),
			at("pile", 16, 7),
			at("pile", 28, 10),
			at("item", 9, 18),
			at("item", 20, 21),
			at("item", 27.5, 13),
			at("rest", 22, 24),
			at("patrol", 14, 18),
			-- Dressing: a sofa on the front wall, a vending machine on the right, a cooler and clock on the back wall.
			prop("sofa", 10, 2.31, HALF),
			prop("vending", 27.2, 19.2, QUARTER),
			prop("waterCooler", 24.5, 24.79, 0),
			prop("floorLamp", 1.6, 21, 0),
			prop("wallClock", 18, 25.375, 0),
		},
	},
	{
		id = "storage_a",
		roomType = "storage",
		name = "Storage closet",
		size = "S",
		width = 18,
		depth = 16,
		door = { offset = 9, width = 6, kind = "solid" },
		markers = {
			at("closet", 3, 13.7, 0),
			at("closet", 15, 13.7, 0),
			styled("shelf", "shelf", 9, 14.4, 0),
			at("locker", 1.8, 8, -QUARTER),
			at("locker", 16.2, 8, QUARTER),
			at("pile", 6, 7),
			at("pile", 12, 7),
			at("pile", 9, 10),
			at("pile", 3, 3),
			at("pile", 15, 3),
			at("item", 9, 7.5),
			at("patrol", 9, 3),
			prop("wasteBin", 16.3, 11, 0),
			prop("sconce", 3, 0.99, HALF),
		},
	},
	{
		id = "server_a",
		roomType = "server",
		name = "Server room",
		size = "M",
		width = 28,
		depth = 24,
		door = { offset = 14, width = 6, kind = "solid" },
		markers = {
			-- Server racks along the back wall.
			styled("shelf", "serverRack", 6, 21.75, 0),
			styled("shelf", "serverRack", 14, 21.75, 0),
			styled("shelf", "serverRack", 22, 21.75, 0),
			at("closet", 25.5, 10, QUARTER),
			at("pile", 4, 6),
			at("pile", 4, 15),
			at("pile", 14, 12),
			at("pile", 22, 16),
			at("pile", 24, 4),
			at("pile", 9, 18),
			at("item", 9, 9),
			at("item", 19, 8),
			at("patrol", 14, 16.5),
			-- Dressing: sconces between the racks, a bin by the closet.
			prop("sconce", 10, 23.01, 0),
			prop("sconce", 18, 23.01, 0),
			prop("wasteBin", 26.5, 20, 0),
		},
	},
	{
		id = "reception_a",
		roomType = "reception",
		name = "Reception",
		size = "L",
		width = 36,
		depth = 30,
		door = { offset = 18, width = 10, kind = "open" },
		markers = {
			styled("counter", "receptionDesk", 18, 20, 0),
			at("plant", 3, 3),
			at("plant", 33, 3),
			at("cabinet", 34.4, 27, 0),
			at("pile", 9, 12),
			at("pile", 30, 12),
			at("pile", 8, 26),
			at("pile", 28, 24),
			at("pile", 10, 5),
			at("pile", 26, 5),
			at("item", 18, 12),
			at("item", 8.5, 20),
			at("patrol", 18, 27),
			-- Dressing: a sofa on the left wall, planters in the back-left corner and on the right, a frame behind
			-- the desk and a clock on the left wall.
			prop("sofa", 2.31, 14, -QUARTER),
			prop("planter", 2.53, 27.54, 0),
			prop("planter", 33.54, 17, QUARTER),
			prop("artFrame", 18, 29.365, 0),
			prop("wallClock", 0.625, 22, -QUARTER),
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
