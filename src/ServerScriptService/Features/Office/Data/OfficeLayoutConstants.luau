--!strict
--[=[
	OfficeLayoutConstants: the authored Harlow & Finch office (Cleanup Crew spec §1 "authored geometry,
	randomised spawns", §5): seven rooms, their doors, the truck in the loading bay, and every spawn marker,
	in office-local studs (OfficeTypes). Geometry is built from this once (OfficeBuildSystem); each shift's
	spawns are rolled onto its markers (OfficeSpawnUtils).

	Depths from the loading bay: Reception and the open-plan office 1; the break room, Mr. Harlow's office,
	the server room and the archive 2 (deep).

	Static data (spec-exempt): OfficeLayoutRules.spec validates THIS layout, so an edit that disconnects a
	room or strays a marker fails the tests.

	@class OfficeLayoutConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local rooms: { OfficeTypes.Room } = {
	{ id = "bay", name = "Loading bay", minX = 0, minZ = 0, maxX = 40, maxZ = 30 },
	{ id = "lobby", name = "Reception", minX = 0, minZ = 30, maxX = 40, maxZ = 60 },
	{ id = "open", name = "Open-plan office", minX = 40, minZ = 0, maxX = 100, maxZ = 60 },
	{ id = "breakRoom", name = "Break room", minX = 0, minZ = 60, maxX = 30, maxZ = 90 },
	{ id = "manager", name = "Mr. Harlow's office", minX = 30, minZ = 60, maxX = 60, maxZ = 90 },
	{ id = "server", name = "Server room", minX = 60, minZ = 60, maxX = 100, maxZ = 90 },
	{ id = "archive", name = "Archive", minX = 100, minZ = 0, maxX = 130, maxZ = 40 },
}

local doors: { OfficeTypes.Door } = {
	{ a = "bay", b = "lobby", x = 20, z = 30, width = 8 },
	{ a = "bay", b = "open", x = 40, z = 15, width = 8 },
	{ a = "lobby", b = "open", x = 40, z = 45, width = 8 },
	{ a = "lobby", b = "breakRoom", x = 15, z = 60, width = 6 },
	{ a = "open", b = "manager", x = 50, z = 60, width = 6 },
	{ a = "open", b = "server", x = 80, z = 60, width = 6 },
	{ a = "open", b = "archive", x = 100, z = 20, width = 6 },
}

local markers: { OfficeTypes.Marker } = {}

-- Appends one marker per point, numbered from 1 within its room and kind.
local function add(room: string, kind: OfficeTypes.MarkerKind, points: { { number } })
	for index, point in points do
		table.insert(markers, { id = `{room}.{kind}.{index}`, room = room, kind = kind, x = point[1], z = point[2] })
	end
end

add("bay", "spawn", { { 28, 10 }, { 32, 10 }, { 28, 16 }, { 32, 16 } })
add("bay", "item", { { 34, 4 }, { 36, 26 }, { 26, 26 } })

add("lobby", "pile", { { 6, 36 }, { 18, 40 }, { 30, 52 }, { 10, 54 } })
add("lobby", "item", {
	{ 4, 34 },
	{ 14, 34 },
	{ 26, 36 },
	{ 36, 40 },
	{ 8, 46 },
	{ 20, 50 },
	{ 34, 56 },
	{ 4, 56 },
	{ 28, 46 },
})
add("lobby", "desk", { { 22, 44 } })

add("open", "pile", {
	{ 48, 8 },
	{ 62, 14 },
	{ 78, 6 },
	{ 92, 18 },
	{ 55, 30 },
	{ 70, 38 },
	{ 88, 34 },
	{ 50, 50 },
	{ 66, 54 },
	{ 84, 50 },
})
add("open", "item", {
	{ 44, 4 },
	{ 56, 6 },
	{ 70, 4 },
	{ 86, 10 },
	{ 96, 6 },
	{ 46, 22 },
	{ 60, 24 },
	{ 74, 22 },
	{ 94, 28 },
	{ 52, 40 },
	{ 66, 42 },
	{ 78, 40 },
	{ 96, 46 },
	{ 58, 56 },
	{ 74, 56 },
	{ 92, 56 },
	{ 44, 34 },
	{ 72, 32 },
	{ 84, 20 },
	{ 96, 38 },
	{ 44, 56 },
	{ 66, 10 },
})
add("open", "desk", { { 50, 18 }, { 68, 28 }, { 86, 26 }, { 60, 46 }, { 80, 46 } })

add("breakRoom", "pile", { { 6, 66 }, { 20, 80 } })
add("breakRoom", "item", { { 4, 64 }, { 14, 70 }, { 26, 66 }, { 8, 84 }, { 24, 86 }, { 16, 87 } })
add("breakRoom", "locker", { { 4, 78 } })

add("manager", "pile", { { 40, 70 }, { 52, 84 } })
add("manager", "item", { { 34, 64 }, { 46, 66 }, { 56, 72 }, { 36, 84 }, { 48, 86 }, { 56, 64 } })
add("manager", "desk", { { 45, 78 } })

add("server", "pile", { { 66, 70 }, { 80, 78 }, { 94, 66 } })
add("server", "item", { { 64, 64 }, { 74, 66 }, { 88, 70 }, { 70, 86 }, { 84, 86 }, { 96, 84 }, { 90, 62 } })
add("server", "locker", { { 97, 76 } })

add("archive", "pile", { { 106, 8 }, { 118, 20 }, { 124, 34 } })
add("archive", "item", { { 104, 4 }, { 114, 6 }, { 126, 8 }, { 108, 22 }, { 122, 28 }, { 110, 36 }, { 126, 38 } })
add("archive", "desk", { { 112, 30 } })
add("archive", "locker", { { 127, 14 }, { 127, 26 } })

local LAYOUT: OfficeTypes.Layout = {
	startRoom = "bay",
	rooms = rooms,
	doors = doors,
	markers = markers,
	-- The bed (the banking zone) and the time clock, inside the loading bay.
	truck = { minX = 4, minZ = 4, maxX = 16, maxZ = 20, clockX = 24, clockZ = 6 },
}

return table.freeze({
	LAYOUT = LAYOUT,
})
