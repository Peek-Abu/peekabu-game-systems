--!strict
--[=[
	OfficeKitRegistry: the greybox catalogue of hand-authored office kits (stage 1 of the office map rebuild):
	eight rooms across the six room types, as pure data in each kit's local frame (OfficeTypes.Kit). Every kit
	passes OfficeKitRules; the spec also places each one in every facing and mirror and validates it as a layout.
	Aisles are kept at least 4 studs wide for Mr. Harlow. Counts are minimums; the coordinates are tuning.

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
			-- Front row's chairs sit behind it (+Z); the back row is turned so its chairs face the middle aisle.
			at("desk", 6, 8, 0),
			at("desk", 20, 8, 0),
			at("desk", 34, 8, 0),
			at("desk", 6, 26.5, HALF),
			at("desk", 20, 26.5, HALF),
			at("desk", 34, 26.5, HALF),
			at("plant", 3, 3),
			at("cabinet", 38.4, 1.6, 0),
			at("pile", 13, 30),
			at("pile", 27, 30),
			at("pile", 13, 17.25),
			at("pile", 27, 17.25),
			at("pile", 36, 17.25),
			at("item", 13, 12),
			at("item", 27, 12),
			at("item", 27, 22),
			at("patrol", 20, 17.25),
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
			at("desk", 3.5, 9.5, QUARTER),
			at("desk", 3.5, 19, QUARTER),
			at("desk", 28.5, 9.5, -QUARTER),
			at("desk", 28.5, 19, -QUARTER),
			at("board", 16, 25.3, 0),
			at("pile", 16, 10),
			at("pile", 16, 17),
			at("pile", 12, 22),
			at("pile", 20, 22),
			at("item", 13, 6.5),
			at("item", 20, 13.5),
			at("patrol", 16, 3),
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
			at("table", 16, 12, 0),
			at("board", 16, 23.3, 0),
			at("pile", 4, 8),
			at("pile", 4, 18),
			at("pile", 28, 8),
			at("pile", 28, 18),
			at("pile", 16, 4),
			at("pile", 16, 20),
			at("item", 16, 5),
			at("item", 16, 19.5),
			at("patrol", 24, 13),
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
			at("table", 13, 10.5, 0),
			at("pile", 4, 9),
			at("pile", 4, 15.5),
			at("pile", 19, 15.5),
			at("pile", 12, 3.5),
			at("pile", 12, 16),
			at("item", 14, 4.5),
			at("patrol", 10, 15.5),
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
			at("counter", 8, 24, 0),
			at("table", 8, 11, 0),
			at("table", 21, 14, 0),
			at("plant", 27, 22),
			at("pile", 4, 18),
			at("pile", 16, 22.5),
			at("pile", 4, 3),
			at("pile", 14, 5),
			at("pile", 28, 10),
			at("item", 9, 18),
			at("item", 20, 21),
			at("item", 28, 16),
			at("rest", 22, 24),
			at("patrol", 14, 18),
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
			at("shelf", 9, 14.4, 0),
			at("locker", 1.8, 8, -QUARTER),
			at("locker", 16.2, 8, QUARTER),
			at("pile", 6, 7),
			at("pile", 12, 7),
			at("pile", 9, 10),
			at("pile", 3, 3),
			at("pile", 15, 3),
			at("item", 9, 7.5),
			at("patrol", 9, 3),
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
			-- Racks are greybox shelves along the back wall.
			at("shelf", 6, 22.4, 0),
			at("shelf", 14, 22.4, 0),
			at("shelf", 22, 22.4, 0),
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
			at("counter", 18, 20, 0),
			at("plant", 3, 3),
			at("plant", 33, 3),
			at("cabinet", 34.4, 27, 0),
			at("pile", 6, 12),
			at("pile", 30, 12),
			at("pile", 8, 26),
			at("pile", 28, 24),
			at("pile", 10, 5),
			at("pile", 26, 5),
			at("item", 18, 12),
			at("item", 10, 20),
			at("patrol", 18, 27),
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
