--!strict
--[=[
	OfficeKitRules: is a hand-authored kit clean? `check` lists every problem: a marker outside the walls
	(furniture by its yawed footprint, point markers within MARKER_MARGIN), two furniture footprints that
	overlap, furniture in the door approach (as deep as a swung-open leaf reaches), a desk without a clear chair
	strip on its front (local -Z, the knee-hole side HideSpotUtils and OfficeDecorSystem use) or without room to
	hide under, a missing patrol (or, in a breakout, rest) marker, fewer piles than a dirty room needs, and a pile or item
	marker crowding furniture. Furniture is sized by OfficeLayoutUtils.markerSize, so a marker whose `art` has an
	OfficeConstants.ART_SIZES entry (a conference table, a server rack) takes that art's footprint. `prop` markers
	(art-only dressing, sized by OfficeConstants.PROP_SIZES[art]) count as furniture; a wall-mounted prop
	(PROP_WALL_HEIGHT) hangs above the floor, so it skips the overlap, approach and clearance tests but must lie against
	a wall, and not over the door on the front wall; floor furniture and props, and the window bay (it hangs from 1.5
	up, across the wainscot), keep SHELL.trimClearance off every wall's plaster face so the trim runs behind them; a desk-top prop (PROP_DESK_TOP) must sit at a desk's centre and
	yaw and takes no floor space; a flat prop (a rug, OfficeLayoutUtils.isFlatProp) only has to lie inside the walls,
	since furniture and loot stand on it; a prop without a
	sized `art` is an error. Works in the kit's local frame (x along the front wall, z into the room). Pure.

	@class OfficeKitRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeLayoutUtils = require(ServerScriptService.Features.Office.Utils.OfficeLayoutUtils)
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
	prop = true,
}

-- The axis-aligned bound of a footprint of `size` (X by Z) centred at x, z and yawed by `rotation`.
local function rect(x: number, z: number, sizeX: number, sizeZ: number, rotation: number): Rect
	local cosine, sine = math.abs(math.cos(rotation)), math.abs(math.sin(rotation))
	local halfX = (sizeX * cosine + sizeZ * sine) / 2
	local halfZ = (sizeX * sine + sizeZ * cosine) / 2
	return { minX = x - halfX, maxX = x + halfX, minZ = z - halfZ, maxZ = z + halfZ }
end

-- A prop standing on a desk's top, which takes no floor space.
local function deskTop(marker: KitMarker): boolean
	return marker.kind == "prop" and marker.art ~= nil and OfficeConstants.PROP_DESK_TOP[marker.art] == true
end

-- A prop hung on a wall.
local function wallMounted(marker: KitMarker): boolean
	return marker.kind == "prop" and marker.art ~= nil and OfficeConstants.PROP_WALL_HEIGHT[marker.art] ~= nil
end

-- The footprint of furniture or a prop: its OfficeLayoutUtils.markerSize (art-sized where the art has an ART_SIZES
-- entry), yawed.
local function footprint(marker: KitMarker): Rect?
	local size = OfficeLayoutUtils.markerSize(marker)
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

-- Whether `a` keeps SHELL.trimClearance off the plaster face of all four walls (the wainscot, rail and skirt stand proud of
-- it, so a piece backed flush on a wall would run into them).
local function offTrim(kit: Kit, a: Rect, wall: number): boolean
	local need = OfficeConstants.SHELL.trimClearance - EPSILON
	return a.minX - wall >= need
		and kit.width - wall - a.maxX >= need
		and a.minZ - wall >= need
		and kit.depth - wall - a.maxZ >= need
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

	local doorFrom, doorTo = door.offset - door.width / 2, door.offset + door.width / 2

	-- Names ("desk 2") in authored order, counts per kind, and the furniture footprints.
	local names: { string } = {}
	local counts: { [string]: number } = {}
	local boxes: { [number]: Rect } = {}
	for index, marker in kit.markers do
		local n = (counts[marker.kind] or 0) + 1
		counts[marker.kind] = n
		names[index] = `{marker.kind} {n} at ({marker.x}, {marker.z})`
		local box = footprint(marker)
		if marker.kind == "prop" and box == nil then
			table.insert(errors, `{label}: {names[index]} names no sized art ("{marker.art}")`)
		end
		-- Wall-mounted and desk-top props sit above the floor furniture, and a flat one (a rug) under it: they take no
		-- part in its overlap tests.
		if
			box ~= nil
			and not wallMounted(marker)
			and not deskTop(marker)
			and not OfficeLayoutUtils.isFlatProp(marker)
		then
			boxes[index] = box
		end
		local fits: boolean
		if deskTop(marker) then
			-- It stands on a desk: that desk's centre and yaw.
			fits = false
			for _, other in kit.markers do
				if
					other.kind == "desk"
					and other.x == marker.x
					and other.z == marker.z
					and (other.rotation or 0) == (marker.rotation or 0)
				then
					fits = true
				end
			end
			if not fits then
				table.insert(errors, `{label}: {names[index]} is not on a desk`)
			end
			continue
		elseif box ~= nil and FOOTPRINT_IN_WALLS[marker.kind] then
			fits = insideWalls(kit, box, wall)
		else
			fits = insideWalls(kit, { minX = marker.x, maxX = marker.x, minZ = marker.z, maxZ = marker.z }, margin)
		end
		if not fits then
			table.insert(errors, `{label}: {names[index]} is outside the walls`)
		elseif box ~= nil and wallMounted(marker) then
			-- Its back lies within half a wall plus a stud of a wall line, and not over the door on the front wall.
			local against =
				OfficeLayoutUtils.wallsAgainst({ minX = 0, maxX = kit.width, minZ = 0, maxZ = kit.depth }, box)
			if #against == 0 then
				table.insert(errors, `{label}: {names[index]} is not against a wall`)
			elseif
				table.find(against, "minZ") ~= nil
				and box.minX < doorTo - EPSILON
				and doorFrom < box.maxX - EPSILON
			then
				table.insert(errors, `{label}: {names[index]} hangs over the door`)
			end
		end
		-- Floor furniture and the low window bay stand SHELL.trimClearance off the plaster, clear of the wall trim; the
		-- other wall props hang above the rail and stay flat on it.
		if
			fits
			and box ~= nil
			and (boxes[index] ~= nil or marker.art == "windowBay")
			and not offTrim(kit, box, wall)
		then
			table.insert(errors, `{label}: {names[index]} stands inside the wall trim`)
		end
	end

	-- Furniture does not overlap, and keeps out of the door approach. A solid or glass door's leaf swings into
	-- the room as far as the door is wide, so its approach reaches past the swung leaf.
	local approachDepth = OfficeConstants.DOOR_APPROACH
	if door.kind ~= "open" then
		approachDepth = math.max(approachDepth, door.width + 0.5)
	end
	local approach: Rect = {
		minX = door.offset - (door.width + 2) / 2,
		maxX = door.offset + (door.width + 2) / 2,
		minZ = 0,
		maxZ = approachDepth,
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

	-- A desk has room to hide under, and a free strip for its chair on its front: local -Z, the knee-hole side
	-- (HideSpotUtils' "front = local -Z", OfficeDecorSystem.chairAt's first candidate).
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
				marker.x - math.sin(yaw) * reach,
				marker.z - math.cos(yaw) * reach,
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
