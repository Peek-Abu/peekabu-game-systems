--!strict
--[=[
	OfficeKitRules: is a hand-authored kit clean? `check` lists every problem: a marker outside the walls
	(furniture by its yawed footprint, point markers within MARKER_MARGIN), two furniture footprints that
	overlap, furniture in the door approach, a desk without a clear chair strip or without room to hide under,
	a missing patrol (or, in a breakout, rest) marker, fewer piles than a dirty room needs, and a pile or item
	marker crowding furniture. Works in the kit's local frame (x along the front wall, z into the room). Pure.

	@class OfficeKitRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

type Kit = OfficeTypes.Kit
type KitMarker = OfficeTypes.KitMarker

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

-- The top slab of a desk, which does not count as free space under it.
local DESK_TOP = 0.3
-- The largest pile's half-size: OfficeLayoutRules keeps piles this far from surface furniture, so kits do too.
local PILE_HALF = 0
for _, style in VacuumConstants.PILE_KINDS do
	PILE_HALF = math.max(PILE_HALF, style.size.X / 2, style.size.Z / 2)
end
-- Touching footprints are fine; this much overlap is not.
local EPSILON = 0.001

-- Furniture markers and their sizes (the same table OfficeLayoutRules uses for its in-walls test, plus plants).
local FURNITURE: { [string]: Vector3 } = {
	desk = OfficeConstants.DESK_SIZE,
	locker = OfficeConstants.LOCKER_SIZE,
	closet = OfficeConstants.CLOSET_SIZE,
	shelf = OfficeConstants.SHELF_SIZE,
	counter = OfficeConstants.COUNTER_SIZE,
	cabinet = OfficeConstants.CABINET_SIZE,
	table = OfficeConstants.TABLE_SIZE,
	board = OfficeConstants.BOARD_SIZE,
	plant = OfficeConstants.PLANT_SIZE,
}
-- Kinds OfficeLayoutRules tests as a footprint; the rest (plants included) it tests as a point.
local FOOTPRINT_IN_WALLS: { [string]: boolean } = {
	desk = true,
	locker = true,
	closet = true,
	shelf = true,
	counter = true,
	cabinet = true,
	table = true,
	board = true,
}

-- The axis-aligned bound of a footprint of `size` (X by Z) centred at x, z and yawed by `rotation`.
local function rect(x: number, z: number, sizeX: number, sizeZ: number, rotation: number): Rect
	local cosine, sine = math.abs(math.cos(rotation)), math.abs(math.sin(rotation))
	local halfX = (sizeX * cosine + sizeZ * sine) / 2
	local halfZ = (sizeX * sine + sizeZ * cosine) / 2
	return { minX = x - halfX, maxX = x + halfX, minZ = z - halfZ, maxZ = z + halfZ }
end

local function footprint(marker: KitMarker): Rect?
	local size = FURNITURE[marker.kind]
	if size == nil then
		return nil
	end
	return rect(marker.x, marker.z, size.X, size.Z, marker.rotation or 0)
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX - EPSILON
		and b.minX < a.maxX - EPSILON
		and a.minZ < b.maxZ - EPSILON
		and b.minZ < a.maxZ - EPSILON
end

local function grow(a: Rect, by: number): Rect
	return { minX = a.minX - by, maxX = a.maxX + by, minZ = a.minZ - by, maxZ = a.maxZ + by }
end

local function insideWalls(kit: Kit, a: Rect, wall: number): boolean
	return a.minX >= wall - EPSILON
		and a.maxX <= kit.width - wall + EPSILON
		and a.minZ >= wall - EPSILON
		and a.maxZ <= kit.depth - wall + EPSILON
end

local OfficeKitRules = {}

--[=[
	Every problem with `kit`; ok when there are none.
]=]
function OfficeKitRules.check(kit: Kit): (boolean, { string })
	local errors: { string } = {}
	local wall = OfficeConstants.WALL_THICKNESS / 2
	local margin = OfficeConstants.MARKER_MARGIN
	local label = `kit "{kit.id}"`

	local door = kit.door
	if door.offset - door.width / 2 < 0 or door.offset + door.width / 2 > kit.width then
		table.insert(errors, `{label}: the door is not on the front wall`)
	end
	local glass = kit.glass
	if glass ~= nil and (glass.from < 0 or glass.to > kit.width or glass.from >= glass.to) then
		table.insert(errors, `{label}: the glass span is not on the front wall`)
	end

	-- Names ("desk 2") in authored order, counts per kind, and the furniture footprints.
	local names: { string } = {}
	local counts: { [string]: number } = {}
	local boxes: { [number]: Rect } = {}
	for index, marker in kit.markers do
		local n = (counts[marker.kind] or 0) + 1
		counts[marker.kind] = n
		names[index] = `{marker.kind} {n} at ({marker.x}, {marker.z})`
		local box = footprint(marker)
		if box ~= nil then
			boxes[index] = box
		end
		local fits: boolean
		if box ~= nil and FOOTPRINT_IN_WALLS[marker.kind] then
			fits = insideWalls(kit, box, wall)
		else
			fits = insideWalls(kit, { minX = marker.x, maxX = marker.x, minZ = marker.z, maxZ = marker.z }, margin)
		end
		if not fits then
			table.insert(errors, `{label}: {names[index]} is outside the walls`)
		end
	end

	-- Furniture does not overlap, and keeps out of the door approach.
	local approach: Rect = {
		minX = door.offset - (door.width + 2) / 2,
		maxX = door.offset + (door.width + 2) / 2,
		minZ = 0,
		maxZ = OfficeConstants.DOOR_APPROACH,
	}
	for index, box in boxes do
		if overlaps(box, approach) then
			table.insert(errors, `{label}: {names[index]} is in the door approach`)
		end
		for other, otherBox in boxes do
			if other > index and overlaps(box, otherBox) then
				table.insert(errors, `{label}: {names[index]} overlaps {names[other]}`)
			end
		end
	end

	-- A desk has room to hide under, and a free strip for its chair on its local +Z side.
	local free = OfficeConstants.DESK_SIZE - Vector3.new(0, DESK_TOP, 0)
	local hug = HideConstants.HUG_FREE_MIN
	if counts.desk ~= nil and (free.X < hug.X or free.Y < hug.Y or free.Z < hug.Z) then
		table.insert(errors, `{label}: the space under a desk is smaller than the hide pose needs`)
	end
	local chairDepth = OfficeConstants.OFFICE_CHAIR_SIZE.Z + OfficeConstants.OFFICE_CHAIR_GAP
	for index, marker in kit.markers do
		if marker.kind == "desk" then
			local yaw = marker.rotation or 0
			local reach = OfficeConstants.DESK_SIZE.Z / 2 + chairDepth / 2
			local strip = rect(
				marker.x + math.sin(yaw) * reach,
				marker.z + math.cos(yaw) * reach,
				OfficeConstants.DESK_SIZE.X,
				chairDepth,
				yaw
			)
			local clear = insideWalls(kit, strip, wall)
			for other, otherBox in boxes do
				if other ~= index and overlaps(strip, otherBox) then
					clear = false
				end
			end
			if not clear then
				table.insert(errors, `{label}: the chair strip of {names[index]} is not clear`)
			end
		end
	end

	-- Harlow's markers, and enough piles for a dirty room.
	if (counts.patrol or 0) < 1 then
		table.insert(errors, `{label}: has no patrol marker`)
	end
	if kit.roomType == "breakout" and (counts.rest or 0) < 1 then
		table.insert(errors, `{label}: a breakout has no rest marker`)
	end
	local piles = counts.pile or 0
	if piles < OfficeConstants.PILES_PER_ROOM.min then
		table.insert(
			errors,
			`{label}: has {piles} pile markers; a dirty room needs {OfficeConstants.PILES_PER_ROOM.min}`
		)
	end

	-- Floor loot keeps clear of furniture.
	for index, marker in kit.markers do
		if marker.kind == "pile" or marker.kind == "item" then
			for other, box in boxes do
				if
					overlaps(
						{ minX = marker.x, maxX = marker.x, minZ = marker.z, maxZ = marker.z },
						grow(box, if marker.kind == "pile" then PILE_HALF else OfficeConstants.SURFACE_ITEM_CLEAR)
					)
				then
					table.insert(errors, `{label}: {names[index]} crowds {names[other]}`)
				end
			end
		end
	end

	return #errors == 0, errors
end

return OfficeKitRules
